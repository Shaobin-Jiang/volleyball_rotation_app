@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volleyball_rotation_app/main.dart';
import 'package:volleyball_rotation_app/storage/storage.dart';

@JS('window.localStorage')
external _BrowserStorage get _storage;

@JS('Storage.prototype')
external JSObject get _storagePrototype;

extension type _BrowserStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void removeItem(String key);
}

void main() {
  setUp(() {
    _storage.removeItem(rosterStorageKey);
    _storage.removeItem(positionsStorageKey);
  });

  tearDown(() {
    _storage.removeItem(rosterStorageKey);
    _storage.removeItem(positionsStorageKey);
  });

  testWidgets('roster and rotation layouts survive app recreation', (
    tester,
  ) async {
    expect(await readStoredString(rosterStorageKey), isNull);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'Player ${i + 1}');
    }
    await tester.tap(find.text('Open Rotation Board'));
    await tester.pumpAndSettle();
    expect(find.text('Rotation 1 of 6'), findsOneWidget);
    expect(
      (jsonDecode(_storage.getItem(rosterStorageKey)!) as Map)['playerNames'],
      List.generate(6, (i) => 'Player ${i + 1}'),
    );

    await tester.tap(find.text('Forward Rotation'));
    await tester.pumpAndSettle();
    final saved = jsonDecode(_storage.getItem(positionsStorageKey)!) as Map;
    expect(saved['rotationIndex'], 1);
    expect(saved['players'], [1, 2, 3, 4, 5, 0]);
    expect((saved['offsets'] as Map).keys, containsAll(['0', '1']));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(
      fields.map((field) => field.controller!.text),
      List.generate(6, (i) => 'Player ${i + 1}'),
    );
    await tester.tap(find.text('Open Rotation Board'));
    await tester.pumpAndSettle();
    expect(find.text('Rotation 2 of 6'), findsOneWidget);
    expect(jsonDecode(_storage.getItem(positionsStorageKey)!), saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid stored JSON reports an error and keeps entry usable', (
    tester,
  ) async {
    await writeStoredString(rosterStorageKey, 'invalid JSON');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Could not load saved player roster.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed browser writes report an error and keep the board usable',
    (tester) async {
      final original = _storagePrototype.getProperty<JSAny?>('setItem'.toJS);
    void failWrite(String key, String value) {
      throw StateError('Storage quota exceeded');
    }

    _storagePrototype.setProperty('setItem'.toJS, failWrite.toJS);
      addTearDown(() {
        _storagePrototype.setProperty('setItem'.toJS, original);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: RotationPage(playerNames: ['A', 'B', 'C', 'D', 'E', 'F']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not save rotations.'), findsOneWidget);
      await tester.tap(find.text('Forward Rotation'));
      await tester.pumpAndSettle();
      expect(find.text('Rotation 2 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
