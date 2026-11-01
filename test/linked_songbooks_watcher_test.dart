import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/data/services/linked_songbooks_watcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LinkedSongbooksWatcher watcher;
  late Directory tempDir;

  Uint8List buildVsbook({required String title, required String body}) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('metadata.json', '{}'))
      ..addFile(
        ArchiveFile.string(
          'songs.json',
          jsonEncode([
            {'song_num': 1, 'title': title, 'body': body, 'source_song_id': 1},
          ]),
        ),
      );
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  setUp(() async {
    db = AppDatabase.forTesting();
    tempDir = Directory.systemTemp.createTempSync('linked_watcher_test_');
    watcher = LinkedSongbooksWatcher(
      db,
      pollingInterval: const Duration(milliseconds: 30),
      debounceDuration: const Duration(minutes: 1),
    );
  });

  tearDown(() async {
    watcher.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('polling reimports changed songbooks and records success', () async {
    final path = '${tempDir.path}/hymns.vsbook';
    File(
      path,
    ).writeAsBytesSync(buildVsbook(title: 'Hymn', body: 'Original words'));
    await db.insertLinkedSongbook(
      LinkedSongbookRegistryCompanion.insert(path: path, name: 'Hymns'),
    );
    final registered = (await db.getAllLinkedSongbooks()).single;
    watcher.startWatching([LinkedSongbook.fromRegistry(registered)]);
    final eventFuture = watcher.syncEvents.first.timeout(
      const Duration(seconds: 5),
    );

    File(
      path,
    ).writeAsBytesSync(buildVsbook(title: 'Hymn', body: 'Updated words'));
    File(
      path,
    ).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));

    final event = await eventFuture;
    expect(event.success, isTrue, reason: event.error);
    expect(event.bookName, 'Hymns');

    final song = (await db.select(db.songs).get()).single;
    expect(song.body, 'Updated words');
    expect(song.sourcePath, path);
    expect((await db.getLinkedSongbookByPath(path))!.lastImportedAt, isNotNull);
  });

  test('failed reimport leaves the previous import time for retry', () async {
    final path = '${tempDir.path}/broken.vsbook';
    File(path).writeAsStringSync('not a zip');
    final previousImport = DateTime(2024, 1, 1);
    await db.insertLinkedSongbook(
      LinkedSongbookRegistryCompanion.insert(
        path: path,
        name: 'Broken',
        lastImportedAt: Value(previousImport),
      ),
    );
    final registered = (await db.getAllLinkedSongbooks()).single;
    watcher.startWatching([LinkedSongbook.fromRegistry(registered)]);
    final eventFuture = watcher.syncEvents.first.timeout(
      const Duration(seconds: 5),
    );

    File(path).writeAsStringSync('still not a zip');
    File(
      path,
    ).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));

    final event = await eventFuture;
    expect(event.success, isFalse);
    expect(event.error, isNotNull);
    expect(
      (await db.getLinkedSongbookByPath(path))!.lastImportedAt,
      previousImport,
    );
  });
}
