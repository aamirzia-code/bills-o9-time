import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import '../db.dart';
import 'backup_codec.dart';
import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart';
import 'sync_config.dart';

enum CloudKind { none, google, dropbox }

String cloudName(CloudKind k) => switch (k) {
      CloudKind.google => 'Google Drive',
      CloudKind.dropbox => 'Dropbox',
      CloudKind.none => 'Not connected',
    };

class RemoteMeta {
  final String id;
  final String rev;
  final DateTime modified;
  final int? size;
  const RemoteMeta(this.id, this.rev, this.modified, this.size);
}

class CloudError implements Exception {
  final String message;
  final bool authExpired;
  CloudError(this.message, {this.authExpired = false});
  @override
  String toString() => message;
}

String _randomToken(int bytes) {
  final r = Random.secure();
  return base64Url
      .encode(List<int>.generate(bytes, (_) => r.nextInt(256)))
      .replaceAll('=', '');
}

void _check(http.Response r, String what) {
  if (r.statusCode >= 200 && r.statusCode < 300) return;
  if (r.statusCode == 401) {
    throw CloudError('Sign-in expired. Reconnect to continue.',
        authExpired: true);
  }
  throw CloudError('$what failed (${r.statusCode}).');
}

/// Shared settings access for sign-in data (kept out of backups).
class SyncStore {
  final _db = AppDb.instance;
  Future<String?> get(String k) => _db.getSetting('sync_$k');
  Future<void> set(String k, String? v) => _db.setSetting('sync_$k', v ?? '');
  Future<String?> getNonEmpty(String k) async {
    final v = await get(k);
    return (v == null || v.isEmpty) ? null : v;
  }
}

abstract class CloudProvider {
  CloudKind get kind;

  /// Opens the provider's sign-in page (web). Returns via oauth.html.
  Future<void> startSignIn({bool silent = false, String? loginHint});

  /// Completes sign-in from the values oauth.html saved.
  Future<void> finishSignIn(Map<String, String> result);

  /// True when an access token is ready to use (refreshing if possible).
  Future<bool> ensureToken();

  Future<String?> accountEmail();
  Future<RemoteMeta?> meta();

  /// Writes the single backup file (overwrites). Returns the new revision.
  Future<String> upload(Uint8List bytes);
  Future<Uint8List> download();
  Future<void> forget();
}

// ------------------------------------------------------------- Google Drive

/// Stores the backup in the hidden app-data folder of the user's own Drive
/// (scope drive.appdata: the app can't see any other files).
class GoogleDriveProvider implements CloudProvider {
  final SyncStore store;
  GoogleDriveProvider(this.store);

  @override
  CloudKind get kind => CloudKind.google;

  static const _scope =
      'https://www.googleapis.com/auth/drive.appdata openid email';

  String? _token;

  Future<Map<String, String>> _h() async =>
      {'Authorization': 'Bearer ${_token ?? await store.get('g_token')}'};

  @override
  Future<void> startSignIn({bool silent = false, String? loginHint}) async {
    final state = 'google:${_randomToken(12)}';
    await store.set('state', state);
    final q = {
      'client_id': SyncConfig.googleClientId,
      'redirect_uri': SyncConfig.redirectUri(),
      'response_type': 'token',
      'scope': _scope,
      'include_granted_scopes': 'true',
      'state': state,
      if (silent) 'prompt': 'none',
      if (!silent) 'prompt': 'select_account',
      if (loginHint != null && loginHint.isNotEmpty) 'login_hint': loginHint,
    };
    webRedirect(Uri.https('accounts.google.com', '/o/oauth2/v2/auth', q)
        .toString());
  }

  @override
  Future<void> finishSignIn(Map<String, String> r) async {
    final token = r['access_token'];
    if (token == null || token.isEmpty) {
      throw CloudError(r['error'] == 'access_denied'
          ? 'Google sign-in was cancelled.'
          : 'Google sign-in failed (${r['error'] ?? 'no token'}).',
          authExpired: r['error'] == 'interaction_required' ||
              r['error'] == 'login_required' ||
              r['error'] == 'consent_required');
    }
    final secs = int.tryParse(r['expires_in'] ?? '') ?? 3600;
    _token = token;
    await store.set('g_token', token);
    await store.set('g_exp',
        DateTime.now().add(Duration(seconds: secs - 60)).toIso8601String());
  }

  @override
  Future<bool> ensureToken() async {
    final exp = DateTime.tryParse(await store.get('g_exp') ?? '');
    final tok = await store.getNonEmpty('g_token');
    if (tok != null && exp != null && exp.isAfter(DateTime.now())) {
      _token = tok;
      return true;
    }
    return false;
  }

  @override
  Future<String?> accountEmail() async {
    final r = await http.get(
        Uri.https('www.googleapis.com', '/oauth2/v3/userinfo'),
        headers: await _h());
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map)['email'] as String?;
  }

  @override
  Future<RemoteMeta?> meta() async {
    final r = await http.get(
      Uri.https('www.googleapis.com', '/drive/v3/files', {
        'spaces': 'appDataFolder',
        'q': "name='${BackupCodec.fileName}' and trashed=false",
        'fields': 'files(id,modifiedTime,size)',
        'pageSize': '10',
      }),
      headers: await _h(),
    );
    _check(r, 'Checking Google Drive');
    final files = (jsonDecode(r.body) as Map)['files'] as List? ?? const [];
    if (files.isEmpty) return null;
    final f = files.first as Map;
    final mod = f['modifiedTime'] as String;
    return RemoteMeta(f['id'] as String, mod, DateTime.parse(mod),
        int.tryParse('${f['size']}'));
  }

  @override
  Future<String> upload(Uint8List bytes) async {
    var id = (await meta())?.id;
    if (id == null) {
      final c = await http.post(
        Uri.https('www.googleapis.com', '/drive/v3/files', {'fields': 'id'}),
        headers: {...await _h(), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': BackupCodec.fileName,
          'parents': ['appDataFolder'],
          'mimeType': 'application/octet-stream',
        }),
      );
      _check(c, 'Creating the backup file');
      id = (jsonDecode(c.body) as Map)['id'] as String;
    }
    final r = await http.patch(
      Uri.https('www.googleapis.com', '/upload/drive/v3/files/$id',
          {'uploadType': 'media', 'fields': 'id,modifiedTime'}),
      headers: {...await _h(), 'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    _check(r, 'Uploading to Google Drive');
    return (jsonDecode(r.body) as Map)['modifiedTime'] as String;
  }

  @override
  Future<Uint8List> download() async {
    final m = await meta();
    if (m == null) throw CloudError('No backup found in Google Drive.');
    final r = await http.get(
        Uri.https('www.googleapis.com', '/drive/v3/files/${m.id}',
            {'alt': 'media'}),
        headers: await _h());
    _check(r, 'Downloading from Google Drive');
    return r.bodyBytes;
  }

  @override
  Future<void> forget() async {
    _token = null;
    await store.set('g_token', null);
    await store.set('g_exp', null);
  }
}

// ------------------------------------------------------------- Dropbox

/// Stores the backup in Apps/Bills O9 Time in the user's Dropbox.
/// PKCE sign-in gives a refresh token, so daily sync needs no re-login.
class DropboxProvider implements CloudProvider {
  final SyncStore store;
  DropboxProvider(this.store);

  @override
  CloudKind get kind => CloudKind.dropbox;

  String? _token;
  static const _path = '/${BackupCodec.fileName}';

  Future<Map<String, String>> _h() async =>
      {'Authorization': 'Bearer ${_token ?? await store.get('d_token')}'};

  @override
  Future<void> startSignIn({bool silent = false, String? loginHint}) async {
    final verifier = _randomToken(48);
    final challenge = base64Url
        .encode(crypto.sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = 'dropbox:${_randomToken(12)}';
    await store.set('state', state);
    await store.set('d_verifier', verifier);
    webRedirect(Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': SyncConfig.dropboxAppKey,
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'redirect_uri': SyncConfig.redirectUri(),
      'state': state,
    }).toString());
  }

  Future<void> _saveToken(Map j) async {
    _token = j['access_token'] as String;
    await store.set('d_token', _token);
    final secs = (j['expires_in'] as num?)?.toInt() ?? 14400;
    await store.set('d_exp',
        DateTime.now().add(Duration(seconds: secs - 60)).toIso8601String());
    if (j['refresh_token'] != null) {
      await store.set('d_refresh', j['refresh_token'] as String);
    }
  }

  @override
  Future<void> finishSignIn(Map<String, String> r) async {
    final code = r['code'];
    if (code == null || code.isEmpty) {
      throw CloudError(r['error'] == 'access_denied'
          ? 'Dropbox sign-in was cancelled.'
          : 'Dropbox sign-in failed (${r['error'] ?? 'no code'}).');
    }
    final res = await http.post(
      Uri.https('api.dropboxapi.com', '/oauth2/token'),
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'code_verifier': await store.get('d_verifier') ?? '',
        'client_id': SyncConfig.dropboxAppKey,
        'redirect_uri': SyncConfig.redirectUri(),
      },
    );
    _check(res, 'Dropbox sign-in');
    await _saveToken(jsonDecode(res.body) as Map);
    await store.set('d_verifier', null);
  }

  @override
  Future<bool> ensureToken() async {
    final exp = DateTime.tryParse(await store.get('d_exp') ?? '');
    final tok = await store.getNonEmpty('d_token');
    if (tok != null && exp != null && exp.isAfter(DateTime.now())) {
      _token = tok;
      return true;
    }
    final refresh = await store.getNonEmpty('d_refresh');
    if (refresh == null) return false;
    final res = await http.post(
      Uri.https('api.dropboxapi.com', '/oauth2/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': SyncConfig.dropboxAppKey,
      },
    );
    if (res.statusCode != 200) return false;
    await _saveToken(jsonDecode(res.body) as Map);
    return true;
  }

  @override
  Future<String?> accountEmail() async {
    final r = await http.post(
      Uri.https('api.dropboxapi.com', '/2/users/get_current_account'),
      headers: {...await _h(), 'Content-Type': 'application/json'},
      body: 'null',
    );
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map)['email'] as String?;
  }

  @override
  Future<RemoteMeta?> meta() async {
    final r = await http.post(
      Uri.https('api.dropboxapi.com', '/2/files/get_metadata'),
      headers: {...await _h(), 'Content-Type': 'application/json'},
      body: jsonEncode({'path': _path}),
    );
    if (r.statusCode == 409) return null; // not found
    _check(r, 'Checking Dropbox');
    final j = jsonDecode(r.body) as Map;
    return RemoteMeta(j['id'] as String, j['rev'] as String,
        DateTime.parse(j['server_modified'] as String), j['size'] as int?);
  }

  @override
  Future<String> upload(Uint8List bytes) async {
    final r = await http.post(
      Uri.https('content.dropboxapi.com', '/2/files/upload'),
      headers: {
        ...await _h(),
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg':
            jsonEncode({'path': _path, 'mode': 'overwrite', 'mute': true}),
      },
      body: bytes,
    );
    _check(r, 'Uploading to Dropbox');
    return (jsonDecode(r.body) as Map)['rev'] as String;
  }

  @override
  Future<Uint8List> download() async {
    final r = await http.post(
      Uri.https('content.dropboxapi.com', '/2/files/download'),
      headers: {
        ...await _h(),
        'Dropbox-API-Arg': jsonEncode({'path': _path}),
      },
    );
    if (r.statusCode == 409) throw CloudError('No backup found in Dropbox.');
    _check(r, 'Downloading from Dropbox');
    return r.bodyBytes;
  }

  @override
  Future<void> forget() async {
    _token = null;
    for (final k in ['d_token', 'd_exp', 'd_refresh', 'd_verifier']) {
      await store.set(k, null);
    }
  }
}
