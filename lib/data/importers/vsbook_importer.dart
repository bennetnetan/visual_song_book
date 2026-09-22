import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

/// Drift stores `DateTime` columns as INTEGER unix-seconds by default, but
/// older `.vsbook` exports (and JSON payloads) may carry ISO-8601 strings.
/// Accept both so imports never crash on a `String`/`int` type mismatch.
DateTime? _parseModified(Object? value) {
  if (value is int) {
    final ms = value > 1_000_000_000_000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Reads a Drift `bool` column (stored as INTEGER 0/1) from a raw sqlite row.
/// Returns `Value.absent()` when the column is missing so the schema default
/// (active) applies instead of forcibly re-activating a soft-deleted song.
Value<bool> _parseIsActive(Object? value) {
  if (value is int) return Value(value == 1);
  if (value is bool) return Value(value);
  return const Value<bool>.absent();
}

final _log = AppLogger.get('VsBookImporter');

class VsBookImporter implements SongbookImporter {
  final AppDatabase db;

  VsBookImporter(this.db);

  @override
  String get name => 'VSBook Portable Importer';

  @override
  bool canImport(ImportSource source) {
    if (source.type == ImportSourceType.file && source.filePath != null) {
      final lower = source.filePath!.toLowerCase();
      return lower.endsWith('.vsbook') || lower.endsWith('.vsb') || lower.endsWith('.mdb');
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

        // .vsb / .mdb are Microsoft Access databases — convert on the fly
        // using the bundled Node.js mdb-reader script (no mdb-tools needed).
        final lower = file.path.toLowerCase();
        if (lower.endsWith('.vsb') || lower.endsWith('.mdb')) {
          final converted = await _convertMdbToVsbook(file.path);
          if (converted == null) {
            return ImportResult.failure(
              'Failed to convert .vsb/.mdb file. '
              'Ensure Node.js is installed and the converter script is present.',
            );
          }
          bytes = converted;
        } else {
          bytes = await file.readAsBytes();
        }
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
        return ImportResult.failure(
          'Invalid .vsbook format: missing metadata.json',
        );
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
        'Invalid .vsbook format: no SQLite database or JSON songs file found.',
      );
    } catch (e) {
      return ImportResult.failure(
        'Import failed. Please check the file and try again.',
        technicalDetails: '$e',
      );
    }
  }

  Future<ImportResult> _importFromSqliteFile(ArchiveFile dbFile) async {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(
      tempDir.path,
      'temp_import_${DateTime.now().millisecondsSinceEpoch}.db',
    );
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
            categoryCompanions.add(
              CategoriesCompanion.insert(id: Value(id), name: name),
            );
          }
        }
      } catch (e, st) {
        // Table categories might not exist or be empty, skip it
        _log.fine('Failed to read categories from temporary .vsbook database: $e', e, st);
      }

      // Read Songs
      final List<SongsCompanion> songCompanions = [];
      final songRows = tempDb.select('''
        SELECT song_num, title, key, body, modified, search, copyright, author, category_id, source_song_id, source_path, source_format, is_active 
        FROM songs
      ''');

      for (final row in songRows) {
        final songNum = row['song_num'] as int?;
        final title = row['title'] as String?;
        final body = row['body'] as String?;

        if (songNum == null || title == null || body == null) continue;

        final key = row['key'] as String?;
        final parsedModified = _parseModified(row['modified']);
        final search = row['search'] as String?;
        final copyright = row['copyright'] as String?;
        final author = row['author'] as String?;
        final categoryId = row['category_id'] as int?;
        final sourceSongId = row['source_song_id'] as int?;
        final sourcePath = row['source_path'] as String?;
        final sourceFormat = row['source_format'] as String?;

        songCompanions.add(
          SongsCompanion.insert(
            songNum: songNum,
            title: title,
            body: body,
            key: Value(key),
            modified: Value(parsedModified),
            search: Value(search),
            copyright: Value(copyright),
            author: Value(author),
            categoryId: categoryId != null
                ? Value(categoryId)
                : const Value<int?>.absent(),
            isActive: _parseIsActive(row['is_active']),
            sourceSongId: Value(sourceSongId),
            sourcePath: Value(sourcePath),
            sourceFormat: Value(sourceFormat),
          ),
        );
      }

      // Snapshot existing songs before clearing, for comparison
      final preExisting = await (db.select(
        db.songs,
      )..orderBy([(t) => OrderingTerm.asc(t.songNum)])).get();
      final preExistingKeys = preExisting
          .map((s) => '${s.songNum}|${s.title.toLowerCase().trim()}')
          .toSet();

      // Deduplicate source data to survive unique index on (LOWER(title), song_num)
      final dedupResult = deduplicateSongs(songCompanions);
      final dedupedSongs = dedupResult.deduplicated;
      if (dedupResult.duplicatesRemoved > 0) {
        _log.info(
          'Deduplicated ${dedupResult.duplicatesRemoved} duplicate songs from .vsbook import '
          '(kept ${dedupedSongs.length} unique entries).',
        );
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
          batch.insertAllOnConflictUpdate(db.songs, dedupedSongs);
        });
      });

      // Compare imported songs against what existed before
      final newSongTitles = <String>[];
      int alreadyExisted = 0;
      for (final companion in dedupedSongs) {
        final key =
            '${companion.songNum.value}|${companion.title.value.toLowerCase().trim()}';
        if (preExistingKeys.contains(key)) {
          alreadyExisted++;
        } else {
          newSongTitles.add(companion.title.value);
        }
      }

      return ImportResult.success(
        songs: dedupedSongs.length,
        categories: categoryCompanions.length,
        added: newSongTitles.length,
        alreadyExisted: alreadyExisted,
        newTitles: newSongTitles,
      );
    } finally {
      tempDb?.dispose();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Non-destructive reimport: replaces only songs whose [sourcePath] matches
  /// [filePath]. Other songs and categories are left untouched.
  Future<ImportResult> reimportSource(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult.failure('File not found: $filePath');
      }

      // .vsb / .mdb are Microsoft Access databases — convert on the fly
      Uint8List bytes;
      final lower = filePath.toLowerCase();
      if (lower.endsWith('.vsb') || lower.endsWith('.mdb')) {
        final converted = await _convertMdbToVsbook(filePath);
        if (converted == null) {
          return ImportResult.failure(
            'Failed to convert .vsb/.mdb file. '
            'Ensure Node.js is installed.',
          );
        }
        bytes = converted;
      } else {
        bytes = await file.readAsBytes();
      }
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? dbFile;
      ArchiveFile? songsJsonFile;
      ArchiveFile? categoriesJsonFile;

      for (final entry in archive) {
        final filename = entry.name.toLowerCase();
        if (filename == 'songs.db' || filename == 'songs_db.sqlite') {
          dbFile = entry;
        } else if (filename == 'songs.json') {
          songsJsonFile = entry;
        } else if (filename == 'categories.json') {
          categoriesJsonFile = entry;
        }
      }

      if (dbFile != null) {
        return await _reimportFromSqliteFile(dbFile, filePath);
      }
      if (songsJsonFile != null) {
        return await _reimportFromJsonFiles(
          songsJsonFile, categoriesJsonFile, filePath,
        );
      }

      return ImportResult.failure(
        'No SQLite database or JSON songs file found in $filePath',
      );
    } catch (e) {
      return ImportResult.failure(
        'Reimport failed. Please check the file and try again.',
        technicalDetails: '$e',
      );
    }
  }

  Future<ImportResult> _reimportFromSqliteFile(
    ArchiveFile dbFile,
    String sourceFilePath,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(
      tempDir.path,
      'temp_reimport_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    final tempFile = File(tempDbPath);
    await tempFile.writeAsBytes(dbFile.content as List<int>);

    sqlite3.Database? tempDb;
    try {
      tempDb = sqlite3.sqlite3.open(tempDbPath);

      final List<CategoriesCompanion> categoryCompanions = [];
      try {
        final categoryRows = tempDb.select('SELECT id, name FROM categories');
        for (final row in categoryRows) {
          final id = row['id'] as int?;
          final name = row['name'] as String?;
          if (id != null && name != null) {
            categoryCompanions.add(
              CategoriesCompanion.insert(id: Value(id), name: name),
            );
          }
        }
      } catch (e, st) {
        _log.fine('Failed to read categories from temporary .vsbook database: $e', e, st);
      }

      final List<SongsCompanion> songCompanions = [];
      final songRows = tempDb.select('''
        SELECT song_num, title, key, body, modified, search, copyright, author, 
               category_id, source_song_id, source_path, source_format, is_active 
        FROM songs
      ''');

      for (final row in songRows) {
        final songNum = row['song_num'] as int?;
        final title = row['title'] as String?;
        final body = row['body'] as String?;
        if (songNum == null || title == null || body == null) continue;

        songCompanions.add(
          SongsCompanion.insert(
            songNum: songNum,
            title: title,
            body: body,
            key: Value(row['key'] as String?),
            modified: Value(_parseModified(row['modified'])),
            search: Value(row['search'] as String?),
            copyright: Value(row['copyright'] as String?),
            author: Value(row['author'] as String?),
            categoryId: row['category_id'] != null
                ? Value(row['category_id'] as int)
                : const Value<int?>.absent(),
            isActive: _parseIsActive(row['is_active']),
            sourceSongId: Value(row['source_song_id'] as int?),
            sourcePath: Value(sourceFilePath),
            sourceFormat: const Value('vsbook_linked'),
          ),
        );
      }

      // Deduplicate source data to survive unique index on (LOWER(title), song_num)
      final dedupResult = deduplicateSongs(songCompanions);
      final dedupedSongs = dedupResult.deduplicated;
      if (dedupResult.duplicatesRemoved > 0) {
        _log.info(
          'Deduplicated ${dedupResult.duplicatesRemoved} duplicate songs from .vsbook reimport '
          '(kept ${dedupedSongs.length} unique entries).',
        );
      }

      await _upsertSongs(sourceFilePath, dedupedSongs);

      return ImportResult.success(
        songs: dedupedSongs.length,
        categories: categoryCompanions.length,
        added: dedupedSongs.length,
      );
    } finally {
      tempDb?.dispose();
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  Future<ImportResult> _reimportFromJsonFiles(
    ArchiveFile songsFile,
    ArchiveFile? categoriesFile,
    String sourceFilePath,
  ) async {
    final songsContent = utf8.decode(songsFile.content as List<int>);
    final List<dynamic> songsJson = json.decode(songsContent) as List<dynamic>;

    final List<CategoriesCompanion> categoryCompanions = [];
    if (categoriesFile != null) {
      final categoriesContent = utf8.decode(
        categoriesFile.content as List<int>,
      );
      final List<dynamic> categoriesJson =
          json.decode(categoriesContent) as List<dynamic>;
      for (final item in categoriesJson) {
        final id = item['id'] as int?;
        final name = item['name'] as String?;
        if (id != null && name != null) {
          categoryCompanions.add(
            CategoriesCompanion.insert(id: Value(id), name: name),
          );
        }
      }
    }

    final List<SongsCompanion> songCompanions = [];
    for (final item in songsJson) {
      final songNum = item['song_num'] as int?;
      final title = item['title'] as String?;
      final body = item['body'] as String?;
      if (songNum == null || title == null || body == null) continue;

      songCompanions.add(
        SongsCompanion.insert(
          songNum: songNum,
          title: title,
          body: body,
          key: Value(item['key'] as String?),
          modified: Value(_parseModified(item['modified'])),
          search: Value(item['search'] as String?),
          copyright: Value(item['copyright'] as String?),
          author: Value(item['author'] as String?),
          categoryId: item['category_id'] != null
              ? Value(item['category_id'] as int)
              : const Value<int?>.absent(),
          sourceSongId: Value(item['source_song_id'] as int?),
          sourcePath: Value(sourceFilePath),
          sourceFormat: const Value('vsbook_linked'),
        ),
      );
    }

    // Deduplicate source data to survive unique index on (LOWER(title), song_num)
    final dedupResult = deduplicateSongs(songCompanions);
    final dedupedSongs = dedupResult.deduplicated;
    if (dedupResult.duplicatesRemoved > 0) {
      _log.info(
        'Deduplicated ${dedupResult.duplicatesRemoved} duplicate songs from .vsbook reimport '
        '(kept ${dedupedSongs.length} unique entries).',
      );
    }

    await db.transaction(() async {
      for (final category in categoryCompanions) {
        await db.into(db.categories).insertOnConflictUpdate(category);
      }

      await _upsertSongs(sourceFilePath, dedupedSongs);
    });

    return ImportResult.success(
      songs: dedupedSongs.length,
      categories: categoryCompanions.length,
      added: dedupedSongs.length,
    );
  }

  Future<ImportResult> _importFromJsonFiles(
    ArchiveFile songsFile,
    ArchiveFile? categoriesFile,
  ) async {
    final songsContent = utf8.decode(songsFile.content as List<int>);
    final List<dynamic> songsJson = json.decode(songsContent) as List<dynamic>;

    final List<CategoriesCompanion> categoryCompanions = [];
    if (categoriesFile != null) {
      final categoriesContent = utf8.decode(
        categoriesFile.content as List<int>,
      );
      final List<dynamic> categoriesJson =
          json.decode(categoriesContent) as List<dynamic>;
      for (final item in categoriesJson) {
        final id = item['id'] as int?;
        final name = item['name'] as String?;
        if (id != null && name != null) {
          categoryCompanions.add(
            CategoriesCompanion.insert(id: Value(id), name: name),
          );
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
      final parsedModified = _parseModified(item['modified']);
      final search = item['search'] as String?;
      final copyright = item['copyright'] as String?;
      final author = item['author'] as String?;
      final categoryId = item['category_id'] as int?;
      final sourceSongId = item['source_song_id'] as int?;
      final sourcePath = item['source_path'] as String?;
      final sourceFormat = item['source_format'] as String?;

      songCompanions.add(
        SongsCompanion.insert(
          songNum: songNum,
          title: title,
          body: body,
          key: Value(key),
          modified: Value(parsedModified),
          search: Value(search),
          copyright: Value(copyright),
          author: Value(author),
          categoryId: categoryId != null
              ? Value(categoryId)
              : const Value<int?>.absent(),
          sourceSongId: Value(sourceSongId),
          sourcePath: Value(sourcePath),
          sourceFormat: Value(sourceFormat),
        ),
      );
    }

    // Snapshot existing songs before clearing, for comparison
    final preExisting = await (db.select(
      db.songs,
    )..orderBy([(t) => OrderingTerm.asc(t.songNum)])).get();
    final preExistingKeys = preExisting
        .map((s) => '${s.songNum}|${s.title.toLowerCase().trim()}')
        .toSet();

    // Deduplicate source data to survive unique index on (LOWER(title), song_num)
    final dedupResult = deduplicateSongs(songCompanions);
    final dedupedSongs = dedupResult.deduplicated;
    if (dedupResult.duplicatesRemoved > 0) {
      _log.info(
        'Deduplicated ${dedupResult.duplicatesRemoved} duplicate songs from .vsbook import '
        '(kept ${dedupedSongs.length} unique entries).',
      );
    }

    await db.transaction(() async {
      await db.delete(db.history).go();
      await db.delete(db.songs).go();
      await db.delete(db.categories).go();

      for (final category in categoryCompanions) {
        await db.into(db.categories).insertOnConflictUpdate(category);
      }

      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.songs, dedupedSongs);
      });
    });

    // Compare imported songs against what existed before
    final newSongTitles = <String>[];
    int alreadyExisted = 0;
    for (final companion in dedupedSongs) {
      final key =
          '${companion.songNum.value}|${companion.title.value.toLowerCase().trim()}';
      if (preExistingKeys.contains(key)) {
        alreadyExisted++;
      } else {
        newSongTitles.add(companion.title.value);
      }
    }

    return ImportResult.success(
      songs: dedupedSongs.length,
      categories: categoryCompanions.length,
      added: newSongTitles.length,
      alreadyExisted: alreadyExisted,
      newTitles: newSongTitles,
    );
  }

  Future<void> _upsertSongs(
    String sourceFilePath,
    List<SongsCompanion> companions,
  ) async {
    final currentSourceExisting = await (db.select(db.songs)
          ..where((t) => t.sourcePath.equals(sourceFilePath))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    final allActive = await (db.select(db.songs)
          ..where((t) => t.isActive.equals(true)))
        .get();

    final bySourceSongIdInFile = <int, Song>{};
    final byTitleNum = <String, Song>{};
    for (final song in currentSourceExisting) {
      if (song.sourceSongId != null) {
        bySourceSongIdInFile[song.sourceSongId!] = song;
      }
    }
    for (final song in allActive) {
      final key = '${song.title.toLowerCase().trim()}|${song.songNum}';
      byTitleNum[key] = song;
    }

    final toUpdate = <SongsCompanion>[];
    final toInsert = <SongsCompanion>[];
    final incomingTitleNums = <String>{};
    final incomingSourceIds = <int?>{};

    for (final companion in companions) {
      final title = companion.title.value;
      final songNum = companion.songNum.value;
      final key = '${title.toLowerCase().trim()}|$songNum';
      incomingTitleNums.add(key);

      final sourceId = companion.sourceSongId.value;
      incomingSourceIds.add(sourceId);

      Song? match;
      if (sourceId != null && bySourceSongIdInFile.containsKey(sourceId)) {
        match = bySourceSongIdInFile[sourceId];
      } else if (byTitleNum.containsKey(key)) {
        match = byTitleNum[key];
      }

      if (match != null) {
        toUpdate.add(companion.copyWith(id: Value(match.id)));
      } else {
        toInsert.add(companion);
      }
    }

    final toDelete = currentSourceExisting.where((s) {
      final key = '${s.title.toLowerCase().trim()}|${s.songNum}';
      return !incomingTitleNums.contains(key);
    }).toList();

    await db.transaction(() async {
      for (final song in toDelete) {
        await (db.delete(db.songs)..where((t) => t.id.equals(song.id))).go();
      }

      for (final song in toUpdate) {
        await db.update(db.songs).replace(song);
      }

      if (toInsert.isNotEmpty) {
        await db.batch((batch) {
          batch.insertAllOnConflictUpdate(db.songs, toInsert);
        });
      }
    });
  }

  /// Converts a .vsb/.mdb (Microsoft Access) file to a .vsbook ZIP archive
  /// in-memory by shelling out to the bundled Node.js mdb-reader script.
  ///
  /// Returns the converted ZIP bytes, or null on failure.
  Future<Uint8List?> _convertMdbToVsbook(String mdbPath) async {
    try {
      // Find the converter script relative to the project root.
      // In development: tools/convert_vsb_to_vsbook.mjs
      // In packaged builds: tools/convert_vsb_to_vsbook.mjs
      final scriptDir = _findProjectRoot();
      if (scriptDir == null) {
        _log.warning('Cannot find project root for MDB converter');
        return null;
      }

      final scriptPath = '$scriptDir/tools/convert_vsb_to_vsbook.mjs';
      final scriptFile = File(scriptPath);
      if (!await scriptFile.exists()) {
        _log.warning('MDB converter script not found at $scriptPath');
        return null;
      }

      // Output to a temp .vsbook file
      final tempDir = Directory.systemTemp.createTempSync('vsb_convert_');
      final outputPath = '${tempDir.path}/converted.vsbook';

      _log.info('Converting MDB to .vsbook: $mdbPath');
      final result = await Process.run(
        'node',
        [scriptPath, mdbPath, outputPath],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _log.warning('MDB converter failed: ${result.stderr}');
        _cleanupTempDir(tempDir);
        return null;
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        _log.warning('MDB converter produced no output file');
        _cleanupTempDir(tempDir);
        return null;
      }

      final bytes = await outputFile.readAsBytes();
      _cleanupTempDir(tempDir);
      _log.info('MDB conversion successful (${bytes.length} bytes)');
      return bytes;
    } catch (e, st) {
      _log.severe('Error converting MDB file', e, st);
      return null;
    }
  }

  /// Tries to locate the project root by walking up from the current
  /// directory looking for pubspec.yaml.
  String? _findProjectRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  void _cleanupTempDir(Directory dir) {
    try {
      dir.deleteSync(recursive: true);
    } catch (e, st) {
      _log.fine('Best-effort temp dir cleanup failed', e, st);
    }
  }
}
