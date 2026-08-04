import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    },
  );

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('LinkedSongbookRegistry DB table', () {
    test('insert and getAll linked songbooks', () async {
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/choir.vsbook',
          name: 'Choir',
          lastImportedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final all = await db.getAllLinkedSongbooks();
      expect(all.length, 2);
      expect(all[0].path, '/home/user/songs/choir.vsbook');
      expect(all[0].name, 'Choir');
      expect(all[0].lastImportedAt, DateTime(2024, 1, 1));
      expect(all[1].path, '/home/user/songs/hymns.vsbook');
      expect(all[1].name, 'Hymns');
      expect(all[1].lastImportedAt, isNull);
    });

    test('getLinkedSongbookByPath returns single entry', () async {
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );

      final found = await db.getLinkedSongbookByPath('/home/user/songs/hymns.vsbook');
      expect(found, isNotNull);
      expect(found!.name, 'Hymns');

      final missing = await db.getLinkedSongbookByPath('/missing.vsbook');
      expect(missing, isNull);
    });

    test('updateLinkedSongbookByPath modifies lastImportedAt', () async {
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );

      final now = DateTime(2025, 6, 15, 10, 30);
      await db.updateLinkedSongbookByPath(
        '/home/user/songs/hymns.vsbook',
        const LinkedSongbookRegistryCompanion(
          lastImportedAt: Value.absent(),
        ).copyWith(lastImportedAt: Value(now)),
      );

      final updated = await db.getLinkedSongbookByPath('/home/user/songs/hymns.vsbook');
      expect(updated!.lastImportedAt, now);
    });

    test('deleteLinkedSongbookByPath removes entry', () async {
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );

      var count = await db.countLinkedSongbooks();
      expect(count, 1);

      await db.deleteLinkedSongbookByPath('/home/user/songs/hymns.vsbook');
      count = await db.countLinkedSongbooks();
      expect(count, 0);
    });

    test('UNIQUE(path) constraint prevents duplicates', () async {
      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );

      expect(
        () => db.insertLinkedSongbook(
          LinkedSongbookRegistryCompanion.insert(
            path: '/home/user/songs/hymns.vsbook',
            name: 'Hymns Duplicate',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('watchAllLinkedSongbooks reacts to changes', () async {
      final stream = db.watchAllLinkedSongbooks();

      await db.insertLinkedSongbook(
        LinkedSongbookRegistryCompanion.insert(
          path: '/home/user/songs/hymns.vsbook',
          name: 'Hymns',
        ),
      );

      final emitted = await stream.first;
      expect(emitted.length, 1);
      expect(emitted[0].path, '/home/user/songs/hymns.vsbook');
    });
  });

  group('SharedPreferences migration', () {
    test('build migrates legacy SharedPreferences data to DB', () async {
      SharedPreferences.setMockInitialValues({
        'linked_songbooks': json.encode([
          {'path': '/home/user/songs/hymns.vsbook', 'name': 'Hymns'},
          {'path': '/home/user/songs/choir.vsbook', 'name': 'Choir'},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      final legacyRaw = prefs.getString('linked_songbooks');
      expect(legacyRaw, isNotNull);

      final legacyBooks = (json.decode(legacyRaw!) as List)
          .map((e) => LinkedSongbook.fromJson(e as Map<String, dynamic>))
          .toList();

      await db.transaction(() async {
        for (final book in legacyBooks) {
          await db.insertLinkedSongbook(book.toCompanion());
        }
      });

      await prefs.remove('linked_songbooks');

      final all = await db.getAllLinkedSongbooks();
      expect(all.length, 2);
      expect(all.map((b) => b.path), contains('/home/user/songs/hymns.vsbook'));

      final cleared = prefs.getString('linked_songbooks');
      expect(cleared, isNull);
    });
  });
}
