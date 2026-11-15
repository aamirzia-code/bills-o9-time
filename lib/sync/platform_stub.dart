// iOS / Android: no browser storage or redirects.
String? webStorageGet(String key) => null;
void webStorageRemove(String key) {}
void webRedirect(String url) =>
    throw UnsupportedError('Cloud sign-in runs in the web app');

void webSetThemeColor(String hex) {}
