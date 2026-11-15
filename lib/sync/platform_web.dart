import 'package:web/web.dart' as web;

String? webStorageGet(String key) => web.window.localStorage.getItem(key);
void webStorageRemove(String key) => web.window.localStorage.removeItem(key);
void webRedirect(String url) => web.window.location.href = url;
