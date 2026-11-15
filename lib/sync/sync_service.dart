import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../db.dart';
import '../notifications.dart';
import 'backup_codec.dart';
import 'cloud_providers.dart';
import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart';
import 'sync_config.dart';

/// Keeps one encrypted backup file in the user's own cloud storage in step
/// with this device: after changes (debounced) and once a day on open.
class SyncService extends ChangeNotifier {
  SyncService(this.app);

  final AppState app;
  final _db = AppDb.instance;
  final store = SyncStore();

  CloudKind kind = CloudKind.none;
  String? email;
  DateTime? lastSync;
  DateTime? remoteSavedAt;
  bool busy = false;
  String? error;
  String? status;

  /// Sign-in expired; a tap on "Reconnect" fixes it.
  bool needsSignIn = false;

  /// First connection found an existing backup: restore it or overwrite it?
  bool choiceNeeded = false;

  bool _hasPass = false;
  bool get hasPassphrase => _hasPass;
  bool _dirty = false;
  bool _suppress = false;
  bool _ready = false;
  Timer? _debounce;

  static bool get cloudAvailable => kIsWeb;

  CloudProvider? get provider => switch (kind) {
        CloudKind.google => GoogleDriveProvider(store),
        CloudKind.dropbox => DropboxProvider(store),
        CloudKind.none => null,
      };

  CloudProvider _providerFor(CloudKind k) => k == CloudKind.google
      ? GoogleDriveProvider(store)
      : DropboxProvider(store);

  Future<void> init() async {
    final k = await store.get('kind');
    kind = CloudKind.values.firstWhere((e) => e.name == k,
        orElse: () => CloudKind.none);
    email = await store.getNonEmpty('email');
    lastSync = DateTime.tryParse(await store.get('last') ?? '');
    _hasPass = (await store.getNonEmpty('pass')) != null;
    _dirty = (await store.get('dirty')) == '1';
    choiceNeeded = (await store.get('choice')) == '1';
    _ready = true;
    app.addListener(_onAppChanged);
    notifyListeners();
    final handled = await _handleSignInResult();
    if (!handled) await autoSync();
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onAppChanged() {
    if (!_ready || _suppress) return;
    if (!_dirty) {
      _dirty = true;
      store.set('dirty', '1');
    }
    if (kind == CloudKind.none) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 15), () => sync());
  }

  // ------------------------------------------------------------ passphrase

  Future<String?> _pass() => store.getNonEmpty('pass');

  Future<void> setPassphrase(String p) async {
    await store.set('pass', p);
    _hasPass = true;
    notifyListeners();
    if (kind != CloudKind.none && !choiceNeeded) {
      _dirty = true;
      await store.set('dirty', '1');
      await sync();
    }
  }

  // ------------------------------------------------------------ connect

  Future<void> connect(CloudKind k) async {
    error = null;
    await store.set('pending', k.name);
    await _providerFor(k).startSignIn();
  }

  Future<void> reconnect() async {
    if (kind == CloudKind.none) return;
    await store.set('pending', kind.name);
    await provider!.startSignIn(loginHint: email);
  }

  Future<void> disconnect() async {
    await provider?.forget();
    kind = CloudKind.none;
    email = null;
    needsSignIn = false;
    choiceNeeded = false;
    for (final k in ['kind', 'email', 'rev', 'choice', 'last', 'pending']) {
      await store.set(k, null);
    }
    lastSync = null;
    notifyListeners();
  }

  /// Picks up the result that oauth.html left after a sign-in redirect.
  Future<bool> _handleSignInResult() async {
    if (!kIsWeb) return false;
    final raw = webStorageGet('b9_oauth');
    if (raw == null) return false;
    webStorageRemove('b9_oauth');
    final pendingName = await store.get('pending');
    await store.set('pending', null);
    final Map<String, String> r;
    try {
      r = (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry('$k', '${v ?? ''}'));
    } catch (_) {
      return false;
    }
    final expected = await store.get('state');
    final k = CloudKind.values.firstWhere((e) => e.name == pendingName,
        orElse: () => CloudKind.none);
    if (k == CloudKind.none || r['state'] != expected) return false;

    busy = true;
    notifyListeners();
    try {
      final p = _providerFor(k);
      await p.finishSignIn(r);
      final wasConnected = kind == k;
      kind = k;
      needsSignIn = false;
      await store.set('kind', k.name);
      email = await p.accountEmail() ?? email;
      await store.set('email', email);
      busy = false;
      if (!wasConnected) {
        await store.set('rev', null);
      }
      await sync();
    } on CloudError catch (e) {
      if (e.authExpired && kind == k) {
        needsSignIn = true;
      } else {
        error = e.message;
      }
    } catch (e) {
      error = 'Sign-in failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
    return true;
  }

  // ------------------------------------------------------------ sync

  /// Daily check when the app opens.
  Future<void> autoSync() async {
    if (kind == CloudKind.none) return;
    final due = lastSync == null ||
        DateTime.now().difference(lastSync!) > const Duration(hours: 20);
    if (!due && !_dirty) return;
    final p = provider!;
    if (!await p.ensureToken()) {
      // Google gives short sessions in the browser: try a quiet re-sign-in
      // at most every 6 hours, otherwise show "Reconnect".
      if (kind == CloudKind.google) {
        final last = DateTime.tryParse(await store.get('silent_at') ?? '');
        if (last == null ||
            DateTime.now().difference(last) > const Duration(hours: 6)) {
          await store.set('silent_at', DateTime.now().toIso8601String());
          await store.set('pending', kind.name);
          await p.startSignIn(silent: true, loginHint: email);
          return;
        }
      }
      needsSignIn = true;
      notifyListeners();
      return;
    }
    await sync();
  }

  Future<bool> sync({bool force = false}) async {
    final p = provider;
    if (p == null || busy) return false;
    final pass = await _pass();
    if (pass == null) {
      error = 'Set a backup passphrase to start syncing.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    status = 'Syncing…';
    notifyListeners();
    try {
      if (!await p.ensureToken()) {
        needsSignIn = true;
        return false;
      }
      needsSignIn = false;
      final meta = await p.meta();
      remoteSavedAt = meta?.modified;
      final storedRev = await store.getNonEmpty('rev');

      if (meta != null && storedRev == null && !force) {
        // First time on this device and a backup already exists.
        choiceNeeded = true;
        await store.set('choice', '1');
        return false;
      }
      if (meta != null && storedRev != null && meta.rev != storedRev && !_dirty) {
        await _pull(p, pass, meta.rev);
      } else if (meta == null || _dirty || force || meta.rev != storedRev) {
        await _push(p, pass);
      }
      lastSync = DateTime.now();
      await store.set('last', lastSync!.toIso8601String());
      status = null;
      return true;
    } on CloudError catch (e) {
      if (e.authExpired) {
        needsSignIn = true;
      } else {
        error = e.message;
      }
      return false;
    } on WrongPassphrase catch (e) {
      error = '$e Enter the passphrase you used on your other device.';
      return false;
    } catch (e) {
      error = 'Sync failed: $e';
      return false;
    } finally {
      busy = false;
      status = null;
      notifyListeners();
    }
  }

  Future<void> _push(CloudProvider p, String pass) async {
    final bytes = await BackupCodec.encode(await _db.exportData(), pass);
    final rev = await p.upload(bytes);
    await store.set('rev', rev);
    _dirty = false;
    await store.set('dirty', '0');
  }

  Future<void> _pull(CloudProvider p, String pass, String rev) async {
    final data = await BackupCodec.decode(await p.download(), pass);
    await _restore(data);
    await store.set('rev', rev);
  }

  Future<void> _restore(Map<String, dynamic> data) async {
    _suppress = true;
    try {
      await _db.importData(data);
      await app.load();
      await Notifier.instance.rescheduleAll(app.activeBills);
    } finally {
      _suppress = false;
    }
    _dirty = false;
    await store.set('dirty', '0');
  }

  /// Answer to "a backup already exists".
  Future<bool> resolveChoice({required bool useCloud}) async {
    choiceNeeded = false;
    await store.set('choice', null);
    if (!useCloud) return sync(force: true);
    final p = provider;
    final pass = await _pass();
    if (p == null || pass == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final meta = await p.meta();
      if (meta == null) {
        busy = false;
        return sync(force: true);
      }
      await _pull(p, pass, meta.rev);
      lastSync = DateTime.now();
      await store.set('last', lastSync!.toIso8601String());
      return true;
    } on WrongPassphrase catch (e) {
      error = '$e Enter the passphrase you used on your other device.';
      choiceNeeded = true;
      await store.set('choice', '1');
      return false;
    } on CloudError catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ file backup

  /// The encrypted backup as bytes, for saving to any storage.
  Future<(String, Uint8List)> exportFile() async {
    final pass = await _pass();
    if (pass == null) throw StateError('Set a backup passphrase first.');
    final bytes = await BackupCodec.encode(await _db.exportData(), pass);
    final name =
        'bills-o9-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.b9';
    return (name, bytes);
  }

  /// Replaces this device's data with a backup file.
  Future<void> importFile(List<int> bytes, String passphrase) async {
    final data = await BackupCodec.decode(bytes, passphrase);
    await _restore(data);
    if (kind != CloudKind.none) {
      _dirty = true;
      await store.set('dirty', '1');
      unawaited(sync());
    }
  }

  String describeLastSync() {
    if (lastSync == null) return 'Not synced yet';
    final d = lastSync!;
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return 'Last synced ${sameDay ? 'today' : DateFormat('d MMM').format(d)}, ${DateFormat('h:mm a').format(d)}';
  }

  static bool providerReady(CloudKind k) => switch (k) {
        CloudKind.google => SyncConfig.googleReady,
        CloudKind.dropbox => SyncConfig.dropboxReady,
        CloudKind.none => false,
      };
}
