@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volleyball_rotation_app/storage/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'volleyball_storage_test',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => directory.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test('missing native data returns null', () async {
    expect(await readStoredString(rosterStorageKey), isNull);
  });

  test('existing native JSON files remain readable and writable', () async {
    final file = File('${directory.path}/volleyball_player_roster.json');
    const roster = '{"playerNames":["A","B","C","D","E","F"]}';
    await file.writeAsString(roster);
    expect(await readStoredString(rosterStorageKey), roster);

    const positions = '{"rotationIndex":2,"players":[2,3,4,5,0,1]}';
    await writeStoredString(positionsStorageKey, positions);
    expect(
      await File(
        '${directory.path}/volleyball_rotation_positions.json',
      ).readAsString(),
      positions,
    );
    expect(await file.readAsString(), roster);
  });
}
