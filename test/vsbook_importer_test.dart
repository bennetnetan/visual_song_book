import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';

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
  late VsBookImporter importer;

  setUp(() {
    db = AppDatabase.forTesting();
    importer = VsBookImporter(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Builds a `.vsbook` archive containing a sqlite `songs.db` (the format the
  /// backup/export produces) plus `metadata.json`.
  Uint8List buildVsbookWithSqlite(List<Map<String, Object?>> rows) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('metadata.json', '{"version":1}'));

    final tempDir = Directory.systemTemp.createTempSync('vsbook_test');
    final dbPath = '${tempDir.path}/songs.db';
    final dbFile = sqlite3.open(dbPath);
    try {
      dbFile.execute('''
        CREATE TABLE songs (
          song_num INTEGER,
          title TEXT,
          key TEXT,
          body TEXT,
          modified INTEGER,
          search TEXT,
          copyright TEXT,
          author TEXT,
          category_id INTEGER,
          source_song_id INTEGER,
          source_path TEXT,
          source_format TEXT,
          is_active INTEGER DEFAULT 1
        )
      ''');
      final insert = dbFile.prepare(
        'INSERT INTO songs (song_num, title, key, body, modified, search, '
        'copyright, author, category_id, source_song_id, source_path, '
        'source_format, is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      );
      for (final row in rows) {
        insert.execute([
          row['song_num'],
          row['title'],
          row['key'],
          row['body'],
          row['modified'],
          row['search'],
          row['copyright'],
          row['author'],
          row['category_id'],
          row['source_song_id'],
          row['source_path'],
          row['source_format'],
          row['is_active'],
        ]);
      }
      insert.dispose();
    } finally {
      dbFile.dispose();
    }

    final dbBytes = File(dbPath).readAsBytesSync();
    tempDir.deleteSync(recursive: true);

    archive.addFile(ArchiveFile('songs.db', dbBytes.length, dbBytes));
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  test('imports songs with INTEGER (unix) modified timestamps', () async {
    final bytes = buildVsbookWithSqlite([
      {
        'song_num': 1,
        'title': 'Test Song',
        'body': 'V1\nIntro',
        'modified': 1700000000,
        'search': 'test song',
        'is_active': 1,
      },
      {
        'song_num': 2,
        'title': 'Inactive Song',
        'body': 'V1\nChorus',
        'modified': null,
        'search': 'inactive song',
        'is_active': 0,
      },
    ]);

    final result = await importer.import(ImportSource.fromBytes(bytes));
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.songsImported, 2);

    final songs = await db.select(db.songs).get();
    expect(songs.length, 2);

    final active = songs.singleWhere((s) => s.songNum == 1);
    expect(active.title, 'Test Song');
    expect(active.modified, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    expect(active.isActive, isTrue);

    final inactive = songs.singleWhere((s) => s.songNum == 2);
    expect(inactive.modified, isNull);
    expect(inactive.isActive, isFalse);
  });

  test('imports songs with ISO-8601 STRING modified timestamps', () async {
    final bytes = buildVsbookWithSqlite([
      {
        'song_num': 3,
        'title': 'String Date Song',
        'body': 'V1\nVerse',
        'modified': '2024-01-01T00:00:00.000',
        'search': 'string date',
        'is_active': 1,
      },
    ]);

    final result = await importer.import(ImportSource.fromBytes(bytes));
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.songsImported, 1);

    final songs = await db.select(db.songs).get();
    final song = songs.singleWhere((s) => s.songNum == 3);
    expect(song.modified, DateTime.parse('2024-01-01T00:00:00.000'));
  });

  test('reimportSource syncs two linked books with overlapping titles', () async {
    final book1Bytes = buildVsbookWithSqlite([
      {
        'song_num': 1,
        'title': 'Amazing Grace',
        'body': 'V1\nBody A',
        'source_song_id': 1,
        'is_active': 1,
      },
      {
        'song_num': 2,
        'title': 'Book1 Unique',
        'body': 'V1\nOnly in book1',
        'source_song_id': 2,
        'is_active': 1,
      },
    ]);

    final book2Bytes = buildVsbookWithSqlite([
      {
        'song_num': 1,
        'title': 'Amazing Grace',
        'body': 'V1\nBody B from book2',
        'source_song_id': 1,
        'is_active': 1,
      },
      {
        'song_num': 5,
        'title': 'Book2 Unique',
        'body': 'V1\nOnly in book2',
        'source_song_id': 2,
        'is_active': 1,
      },
    ]);

    final tempDir = Directory.systemTemp.createTempSync('vsbook_multi');
    final book1Path = '${tempDir.path}/book1.vsbook';
    final book2Path = '${tempDir.path}/book2.vsbook';
    File(book1Path).writeAsBytesSync(book1Bytes);
    File(book2Path).writeAsBytesSync(book2Bytes);

    final r1 = await importer.reimportSource(book1Path);
    expect(r1.success, isTrue, reason: r1.errorMessage);

    final r2 = await importer.reimportSource(book2Path);
    expect(r2.success, isTrue, reason: r2.errorMessage);

    final songs = await (db.select(db.songs)
          ..where((t) => t.isActive.equals(true)))
        .get();

    expect(songs.length, 3, reason: 'Should have 3 active songs total');

    final amazing = songs.where((s) => s.title == 'Amazing Grace').toList();
    expect(amazing.length, 1, reason: 'Only one Amazing Grace should exist');
    expect(amazing.first.body, 'V1\nBody B from book2');
    expect(amazing.first.sourcePath, book2Path);

    expect(songs.any((s) => s.title == 'Book1 Unique' && s.sourcePath == book1Path), isTrue);
    expect(songs.any((s) => s.title == 'Book2 Unique' && s.sourcePath == book2Path), isTrue);

    tempDir.deleteSync(recursive: true);
  });
}
