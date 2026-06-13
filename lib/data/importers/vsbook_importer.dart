import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

class VsBookImporter implements SongbookImporter {
  final AppDatabase db;

  VsBookImporter(this.db);

  @override
  String get name => 'VSBook Portable Importer';

  @override
  bool canImport(ImportSource source) {
    if (source.type == ImportSourceType.file && source.filePath != null) {
      return source.filePath!.toLowerCase().endsWith('.vsbook');
    }
    if (source.type == ImportSourceType.bytes && source.bytes != null) {
      return true;
    }
    return false;
  }

  @override
  Future<ImportResult> import(ImportSource source) async {
    try {
      Uint8List bytes;
      if (source.type == ImportSourceType.file) {
        if (source.filePath == null) {
          return ImportResult.failure('No file path provided.');
        }
        final file = File(source.filePath!);
        if (!await file.exists()) {
          return ImportResult.failure('Backup file not found.');
        }
        bytes = await file.readAsBytes();
      } else {
        if (source.bytes == null) {
          return ImportResult.failure('No bytes provided.');
        }
        bytes = source.bytes!;
      }

      // Decode the ZIP archive
      final archive = ZipDecoder().decodeBytes(bytes);

      // We look for sqlite database file or JSON files in the zip
      ArchiveFile? dbFile;
      ArchiveFile? songsJsonFile;
      ArchiveFile? categoriesJsonFile;
      ArchiveFile? metadataJsonFile;

      for (final file in archive) {
        final filename = file.name.toLowerCase();
        if (filename == 'songs.db' || filename == 'songs_db.sqlite') {
          dbFile = file;
        } else if (filename == 'songs.json') {
          songsJsonFile = file;
        } else if (filename == 'categories.json') {
          categoriesJsonFile = file;
        } else if (filename == 'metadata.json') {
          metadataJsonFile = file;
        }
      }

      if (metadataJsonFile == null) {
        return ImportResult.failure('Invalid .vsbook format: missing metadata.json');
      }

      // 1. Process via SQLite if dbFile exists
      if (dbFile != null) {
        return await _importFromSqliteFile(dbFile);
      }

      // 2. Process via JSON if json files exist
      if (songsJsonFile != null) {
        return await _importFromJsonFiles(songsJsonFile, categoriesJsonFile);
      }

      return ImportResult.failure(
          'Invalid .vsbook format: no SQLite database or JSON songs file found.');
    } catch (e) {
      return ImportResult.failure('Error importing .vsbook: $e');
    }
  }

  Future<ImportResult> _importFromSqliteFile(ArchiveFile dbFile) async {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'temp_import_${DateTime.now().millisecondsSinceEpoch}.db');
    final tempFile = File(tempDbPath);
    await tempFile.writeAsBytes(dbFile.content as List<int>);

    sqlite3.Database? tempDb;
    try {
      // Open the temporary database using raw sqlite3 library
      tempDb = sqlite3.sqlite3.open(tempDbPath);

      // Read Categories
      final List<CategoriesCompanion> categoryCompanions = [];
      try {
        final categoryRows = tempDb.select('SELECT id, name FROM categories');
        for (final row in categoryRows) {
          final id = row['id'] as int?;
          final name = row['name'] as String?;
          if (id != null && name != null) {
            categoryCompanions.add(CategoriesCompanion.insert(
              id: Value(id),
              name: name,
            ));
          }
        }
      } catch (_) {
        // Table categories might not exist or be empty, skip it
      }

      // Read Songs
      final List<SongsCompanion> songCompanions = [];
      final songRows = tempDb.select('''
        SELECT song_num, title, key, body, modified, search, copyright, author, category_id, source_song_id, source_path, source_format 
        FROM songs
      ''');

      for (final row in songRows) {
        final songNum = row['song_num'] as int?;
        final title = row['title'] as String?;
        final body = row['body'] as String?;

        if (songNum == null || title == null || body == null) continue;

        final key = row['key'] as String?;
        final modifiedStr = row['modified'] as String?;
        final search = row['search'] as String?;
        final copyright = row['copyright'] as String?;
        final author = row['author'] as String?;
        final categoryId = row['category_id'] as int?;
        final sourceSongId = row['source_song_id'] as int?;
        final sourcePath = row['source_path'] as String?;
        final sourceFormat = row['source_format'] as String?;

        final parsedModified = modifiedStr != null ? DateTime.tryParse(modifiedStr) : null;

        songCompanions.add(SongsCompanion.insert(
          songNum: songNum,
          title: title,
          body: body,
          key: Value(key),
          modified: Value(parsedModified),
          search: Value(search),
          copyright: Value(copyright),
          author: Value(author),
          categoryId: categoryId != null ? Value(categoryId) : const Value<int?>.absent(),
          sourceSongId: Value(sourceSongId),
          sourcePath: Value(sourcePath),
          sourceFormat: Value(sourceFormat),
        ));
      }

      // Insert into our active database
      await db.transaction(() async {
        await db.delete(db.history).go();
        await db.delete(db.songs).go();
        await db.delete(db.categories).go();

        for (final category in categoryCompanions) {
          await db.into(db.categories).insertOnConflictUpdate(category);
        }

        await db.batch((batch) {
          batch.insertAll(db.songs, songCompanions);
        });
      });

      return ImportResult.success(
        songs: songCompanions.length,
        categories: categoryCompanions.length,
      );
    } finally {
      tempDb?.dispose();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<ImportResult> _importFromJsonFiles(
      ArchiveFile songsFile, ArchiveFile? categoriesFile) async {
    final songsContent = utf8.decode(songsFile.content as List<int>);
    final List<dynamic> songsJson = json.decode(songsContent) as List<dynamic>;

    final List<CategoriesCompanion> categoryCompanions = [];
    if (categoriesFile != null) {
      final categoriesContent = utf8.decode(categoriesFile.content as List<int>);
      final List<dynamic> categoriesJson = json.decode(categoriesContent) as List<dynamic>;
      for (final item in categoriesJson) {
        final id = item['id'] as int?;
        final name = item['name'] as String?;
        if (id != null && name != null) {
          categoryCompanions.add(CategoriesCompanion.insert(
            id: Value(id),
            name: name,
          ));
        }
      }
    }

    final List<SongsCompanion> songCompanions = [];
    for (final item in songsJson) {
      final songNum = item['song_num'] as int?;
      final title = item['title'] as String?;
      final body = item['body'] as String?;

      if (songNum == null || title == null || body == null) continue;

      final key = item['key'] as String?;
      final modifiedStr = item['modified'] as String?;
      final search = item['search'] as String?;
      final copyright = item['copyright'] as String?;
      final author = item['author'] as String?;
      final categoryId = item['category_id'] as int?;
      final sourceSongId = item['source_song_id'] as int?;
      final sourcePath = item['source_path'] as String?;
      final sourceFormat = item['source_format'] as String?;

      final parsedModified = modifiedStr != null ? DateTime.tryParse(modifiedStr) : null;

      songCompanions.add(SongsCompanion.insert(
        songNum: songNum,
        title: title,
        body: body,
        key: Value(key),
        modified: Value(parsedModified),
        search: Value(search),
        copyright: Value(copyright),
        author: Value(author),
        categoryId: categoryId != null ? Value(categoryId) : const Value<int?>.absent(),
        sourceSongId: Value(sourceSongId),
        sourcePath: Value(sourcePath),
        sourceFormat: Value(sourceFormat),
      ));
    }

    await db.transaction(() async {
      await db.delete(db.history).go();
      await db.delete(db.songs).go();
      await db.delete(db.categories).go();

      for (final category in categoryCompanions) {
        await db.into(db.categories).insertOnConflictUpdate(category);
      }

      await db.batch((batch) {
        batch.insertAll(db.songs, songCompanions);
      });
    });

    return ImportResult.success(
      songs: songCompanions.length,
      categories: categoryCompanions.length,
    );
  }
}
