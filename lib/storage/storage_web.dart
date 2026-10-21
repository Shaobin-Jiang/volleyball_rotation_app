import 'dart:js_interop';

@JS('window.localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

Future<String?> readStoredString(String key) async {
  return _localStorage.getItem(key);
}

Future<void> writeStoredString(String key, String value) async {
  _localStorage.setItem(key, value);
}
