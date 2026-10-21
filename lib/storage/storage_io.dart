import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _storageFile(String key) async {
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/$key');
}

Future<String?> readStoredString(String key) async {
  final file = await _storageFile(key);
  return await file.exists() ? await file.readAsString() : null;
}

Future<void> writeStoredString(String key, String value) async {
  final file = await _storageFile(key);
  await file.writeAsString(value);
}
