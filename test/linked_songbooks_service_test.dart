import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
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

  group('LinkedSongbook file status', () {
    test('recognizes supported formats without regard to case', () {
      for (final path in ['Hymns.vsbook', 'Hymns.VSB', 'Hymns.MDB']) {
        expect(
          LinkedSongbook(path: path, name: 'Hymns').isSupportedFormat,
          isTrue,
          reason: path,
        );
      }
      expect(
        LinkedSongbook(path: 'Hymns.zip', name: 'Hymns').isSupportedFormat,
        isFalse,
      );
    });

    test('treats unimported and newer files as needing sync', () {
      final tempDir = Directory.systemTemp.createTempSync('linked_status_');
      final file = File('${tempDir.path}/hymns.vsbook')..writeAsStringSync('x');
      try {
        final modified = file.statSync().modified;
        expect(
          LinkedSongbook(path: file.path, name: 'Hymns').hasChangedSinceLastImport,
          isTrue,
        );
        expect(
          LinkedSongbook(
            path: file.path,
            name: 'Hymns',
            lastImportedAt: modified.subtract(const Duration(seconds: 1)),
          ).hasChangedSinceLastImport,
          isTrue,
        );
        expect(
          LinkedSongbook(
            path: file.path,
            name: 'Hymns',
            lastImportedAt: modified.add(const Duration(seconds: 1)),
          ).hasChangedSinceLastImport,
          isFalse,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
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

  group('add() path validation', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() => container.dispose());

    Future<LinkedSongbooksService> service() async {
      await container.read(linkedSongbooksProvider.future);
      return container.read(linkedSongbooksProvider.notifier);
    }

    test('rejects a path outside the allowed directories', () async {
      final notifier = await service();
      await notifier.add('/tmp/evil.vsbook');

      final linked = await container.read(linkedSongbooksProvider.future);
      expect(linked, isEmpty);
      expect(await db.getAllLinkedSongbooks(), isEmpty);
    });

    test('rejects null/empty and unparseable paths', () async {
      final notifier = await service();
      await notifier.add('');
      await notifier.add('   ');

      expect(await db.getAllLinkedSongbooks(), isEmpty);
    });

    test('accepts a path that points to an existing file', () async {
      // Create a temp file so _isPathAllowed (File.existsSync) passes.
      final tempDir = Directory.systemTemp.createTempSync('vsb_link_test_');
      final testFile = File('${tempDir.path}${Platform.pathSeparator}hymns.vsbook');
      testFile.writeAsStringSync('dummy');
      final allowedPath = testFile.path;

      try {
        final notifier = await service();
        await notifier.add(allowedPath);

        final linked = await container.read(linkedSongbooksProvider.future);
        final linkedPaths = linked.map((b) => b.path).toList();
        expect(linkedPaths, contains(allowedPath));
        expect(await db.getAllLinkedSongbooks(), hasLength(1));

        // Duplicate add is ignored.
        await notifier.add(allowedPath);
        expect(await db.getAllLinkedSongbooks(), hasLength(1));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
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
