/// Public OAuth identifiers (not secrets). Set them at build time with
/// --dart-define, or paste them here.
class SyncConfig {
  static const googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  static const dropboxAppKey =
      String.fromEnvironment('DROPBOX_APP_KEY', defaultValue: '');

  static bool get googleReady => googleClientId.isNotEmpty;
  static bool get dropboxReady => dropboxAppKey.isNotEmpty;

  /// e.g. https://aamirzia-code.github.io/bills-o9-time/oauth.html
  static String redirectUri() {
    final b = Uri.base;
    final dir = b.path.substring(0, b.path.lastIndexOf('/') + 1);
    return '${b.origin}${dir}oauth.html';
  }
}
