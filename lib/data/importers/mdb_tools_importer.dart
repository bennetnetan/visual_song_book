import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

class MdbToolsImporter implements SongbookImporter {
  final AppDatabase db;

  MdbToolsImporter(this.db);

  @override
  String get name => 'MDB Tools CLI Importer';

  @override
  bool canImport(ImportSource source) {
    // Only supported on desktop platforms where we can run processes
    // and if the file path is provided and ends with .mdb or .vsb.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (source.type == ImportSourceType.file && source.filePath != null) {
        final path = source.filePath!.toLowerCase();
        return path.endsWith('.mdb') || path.endsWith('.vsb');
      }
    }
    return false;
  }

  @override
  Future<ImportResult> import(ImportSource source) async {
    if (source.filePath == null) {
      return ImportResult.failure('No file path provided.');
    }

    final file = File(source.filePath!);
    if (!await file.exists()) {
      return ImportResult.failure('Source file does not exist.');
    }

    try {
      // 1. Export Categories CSV
      final categoriesResult = await Process.run('mdb-export', [file.path, 'Categories']);
      if (categoriesResult.exitCode != 0) {
        return ImportResult.failure(
            'Failed to export Categories table: ${categoriesResult.stderr}');
      }

      // 2. Export Songs CSV
      final songsResult = await Process.run('mdb-export', [file.path, 'Songs']);
      if (songsResult.exitCode != 0) {
        return ImportResult.failure(
            'Failed to export Songs table: ${songsResult.stderr}');
      }

      // 3. Parse CSVs
      // mdb-export uses \r\r\n (double CR) within quoted multiline fields
      // and \r\n as the record separator. Normalise everything to \n so the
      // CSV parser can handle multiline body text correctly.
      final rawCategories = _normalizeMdbCsv(categoriesResult.stdout as String);
      final rawSongs = _normalizeMdbCsv(songsResult.stdout as String);

      const csvConverter = CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false, // keep all values as strings; we parse manually
      );

      final categoriesRows = csvConverter.convert(rawCategories);
      final songsRows = csvConverter.convert(rawSongs);

      if (categoriesRows.isEmpty || songsRows.isEmpty) {
        return ImportResult.failure('Exported tables contain no data.');
      }

      // 4. Map and Insert Categories
      // MDB Schema: ID, Name
      // First row is header
      final categoriesHeader = categoriesRows.first.map((e) => e.toString().toUpperCase()).toList();
      final idIndex = categoriesHeader.indexOf('ID');
      final nameIndex = categoriesHeader.indexOf('NAME');

      if (idIndex == -1 || nameIndex == -1) {
        return ImportResult.failure('Invalid Categories table header.');
      }

      final List<CategoriesCompanion> categoryCompanions = [];
      for (int i = 1; i < categoriesRows.length; i++) {
        final row = categoriesRows[i];
        if (row.length <= idIndex || row.length <= nameIndex) continue;

        final id = int.tryParse(row[idIndex].toString());
        final name = row[nameIndex].toString().trim();

        if (id != null && name.isNotEmpty) {
          categoryCompanions.add(CategoriesCompanion.insert(
            id: Value(id),
            name: name,
          ));
        }
      }

      // 5. Map and Insert Songs
      // MDB Schema: SongID, SongNum, Title, Key, Body, Modified, Search, Copyright, Author, CategoryId
      final songsHeader = songsRows.first.map((e) => e.toString().toUpperCase()).toList();
      final songIdIndex = songsHeader.indexOf('SONGID');
      final songNumIndex = songsHeader.indexOf('SONGNUM');
      final titleIndex = songsHeader.indexOf('TITLE');
      final keyIndex = songsHeader.indexOf('KEY');
      final bodyIndex = songsHeader.indexOf('BODY');
      final modifiedIndex = songsHeader.indexOf('MODIFIED');
      final searchIndex = songsHeader.indexOf('SEARCH');
      final copyrightIndex = songsHeader.indexOf('COPYRIGHT');
      final authorIndex = songsHeader.indexOf('AUTHOR');
      final categoryIdIndex = songsHeader.indexOf('CATEGORYID');

      if (songNumIndex == -1 || titleIndex == -1 || bodyIndex == -1) {
        return ImportResult.failure('Invalid Songs table header. Missing required fields.');
      }

      final List<SongsCompanion> songCompanions = [];
      for (int i = 1; i < songsRows.length; i++) {
        final row = songsRows[i];
        if (row.length <= songNumIndex || row.length <= titleIndex || row.length <= bodyIndex) {
          continue;
        }

        final songNum = int.tryParse(row[songNumIndex].toString()) ?? 0;
        final title = row[titleIndex].toString().trim();
        final body = row[bodyIndex].toString().trim();

        if (title.isEmpty || body.isEmpty) continue;

        final rawSongId = songIdIndex != -1 ? int.tryParse(row[songIdIndex].toString()) : null;
        final key = keyIndex != -1 ? row[keyIndex]?.toString().trim() : null;
        final modifiedStr = modifiedIndex != -1 ? row[modifiedIndex]?.toString().trim() : null;
        final search = searchIndex != -1 ? row[searchIndex]?.toString().trim() : null;
        final copyright = copyrightIndex != -1 ? row[copyrightIndex]?.toString().trim() : null;
        final author = authorIndex != -1 ? row[authorIndex]?.toString().trim() : null;
        final rawCategoryId = categoryIdIndex != -1 ? int.tryParse(row[categoryIdIndex].toString()) : null;

        // Clean values
        final parsedModified = _parseMdbDateTime(modifiedStr);
        final cleanedKey = key == 'null' || key == '' ? null : key;
        final cleanedCopyright = copyright == 'null' || copyright == '' ? null : copyright;
        final cleanedAuthor = author == 'null' || author == '' ? null : author;
        final cleanedSearch = search == 'null' || search == '' ? null : search;

        // Map Category ID (Treat 0 as null since 0 means uncategorized)
        final categoryIdValue = (rawCategoryId == null || rawCategoryId == 0)
            ? const Value<int?>.absent()
            : Value<int?>(rawCategoryId);

        songCompanions.add(SongsCompanion.insert(
          songNum: songNum,
          title: title,
          body: body,
          key: Value(cleanedKey),
          modified: Value(parsedModified),
          search: Value(cleanedSearch),
          copyright: Value(cleanedCopyright),
          author: Value(cleanedAuthor),
          categoryId: categoryIdValue,
          sourceSongId: Value(rawSongId),
          sourcePath: Value(file.path),
          sourceFormat: const Value('vsb'),
        ));
      }

      // Execute in a transaction for maximum speed and integrity
      await db.transaction(() async {
        // Clear existing tables to prevent duplicate keys on full re-import
        // Or we could upsert. Since this is an import of a legacy file, we clear first
        await db.delete(db.history).go();
        await db.delete(db.songs).go();
        await db.delete(db.categories).go();

        // Insert categories
        for (final companion in categoryCompanions) {
          await db.into(db.categories).insertOnConflictUpdate(companion);
        }

        // Insert songs
        await db.batch((batch) {
          batch.insertAll(db.songs, songCompanions);
        });
      });

      if (songCompanions.isEmpty) {
        return ImportResult.failure(
          'No songs could be parsed from the file. '
          'The Songs table may be empty, or the CSV format is not recognised. '
          'Parsed ${songsRows.length - 1} raw rows, 0 valid songs.',
        );
      }

      return ImportResult.success(
        songs: songCompanions.length,
        categories: categoryCompanions.length,
      );
    } catch (e) {
      return ImportResult.failure('Error during import: $e');
    }
  }

  /// Normalises line endings from mdb-export output.
  ///
  /// mdb-export on Linux uses \r\r\n (double CR + LF) at the end of each
  /// line inside a quoted multiline field, and \r\n as the record separator.
  /// Normalise to bare \n so that [CsvToListConverter(eol: '\n')] can parse
  /// the file correctly without breaking on the embedded newlines in lyrics.
  String _normalizeMdbCsv(String raw) {
    return raw
        .replaceAll('\r\r\n', '\n') // double-CR within quoted lyrics
        .replaceAll('\r\n', '\n')   // standard CRLF record separator
        .replaceAll('\r', '\n');    // any stray lone CR
  }

  /// Parses date format "10/24/12 17:46:23" into DateTime
  DateTime? _parseMdbDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') return null;
    try {
      final parts = dateStr.split(' ');
      if (parts.isEmpty) return null;

      final dateParts = parts[0].split('/');
      if (dateParts.length != 3) return null;

      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      // Handle 2-digit years
      if (year < 70) {
        year += 2000;
      } else if (year < 100) {
        year += 1900;
      }

      int hour = 0;
      int minute = 0;
      int second = 0;

      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        if (timeParts.length >= 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        }
        if (timeParts.length >= 3) {
          second = int.parse(timeParts[2]);
        }
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }
}
