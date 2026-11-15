import 'package:web/web.dart' as web;

String? webStorageGet(String key) => web.window.localStorage.getItem(key);
void webStorageRemove(String key) => web.window.localStorage.removeItem(key);
void webRedirect(String url) => web.window.location.href = url;

/// Colours the browser / iOS status-bar strip to match the app background,
/// so there's no tinted band above the app.
void webSetThemeColor(String hex) {
  final metas = web.document.querySelectorAll('meta[name="theme-color"]');
  if (metas.length == 0) {
    final m = web.document.createElement('meta') as web.HTMLMetaElement;
    m.name = 'theme-color';
    m.content = hex;
    web.document.head?.append(m);
    return;
  }
  for (var i = 0; i < metas.length; i++) {
    (metas.item(i) as web.Element).setAttribute('content', hex);
  }
  web.document.body?.style.setProperty('background-color', hex);
}
