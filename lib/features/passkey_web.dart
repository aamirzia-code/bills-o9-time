import 'dart:js_interop';

@JS('b9Passkey')
external _Passkey? get _passkey;

extension type _Passkey(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> available();
  external JSPromise<JSString?> register();
  external JSPromise<JSBoolean> verify(JSString id);
}

Future<bool> passkeyAvailable() async {
  final p = _passkey;
  if (p == null) return false;
  return (await p.available().toDart).toDart;
}

Future<String?> passkeyRegister() async {
  final p = _passkey;
  if (p == null) return null;
  return (await p.register().toDart)?.toDart;
}

Future<bool> passkeyVerify(String id) async {
  final p = _passkey;
  if (p == null) return false;
  return (await p.verify(id.toJS).toDart).toDart;
}
