import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

/// Platform-agnostic importer that reads pre-exported JSON songbook data from
/// Flutter assets. This works on every platform (Android, iOS, desktop, web)
/// without needing `mdb-tools` or any external CLI.
class BundledJsonImporter implements SongbookImporter {
  final AppDatabase db;

  BundledJsonImporter(this.db);

  @override
  String get name => 'Bundled JSON Importer';

  @override
  bool canImport(ImportSource source) {
    // This importer is used via importFromAsset(), not the generic import() path.
    return false;
  }

  @override
  Future<ImportResult> import(ImportSource source) async {
    return ImportResult.failure(
      'Use importFromAsset() instead for bundled JSON imports.',
    );
  }

  /// Imports a songbook from a pre-bundled Flutter asset JSON file.
  /// [assetPath] is the asset key, e.g. 'assets/songbooks/data/full_song_book.json'.
  /// [bookName] is a human-readable name used as the source path and fallback category.
  Future<ImportResult> importFromAsset(
    String assetPath, {
    required String bookName,
  }) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;

      final List<dynamic> songsJson = data['songs'] as List<dynamic>? ?? [];

      if (songsJson.isEmpty) {
        return ImportResult.failure('JSON file contains no songs.');
      }

      // Determine book-level category id (1 = Full Song Book, 2 = Injili Song Book)
      final int bookCategoryId = bookName == 'Injili Song Book' ? 2 : 1;
      await db.into(db.categories).insertOnConflictUpdate(
        CategoriesCompanion.insert(id: Value(bookCategoryId), name: bookName),
      );

      // Build song companions
      final songCompanions = <SongsCompanion>[];
      for (final item in songsJson) {
        final songNum = item['song_num'] as int?;
        final title = item['title'] as String?;
        final body = item['body'] as String?;

        if (songNum == null || title == null || body == null) continue;

        final key = item['key'] as String?;
        final author = item['author'] as String?;
        final copyright = item['copyright'] as String?;
        final search = item['search'] as String?;

        songCompanions.add(
          SongsCompanion.insert(
            songNum: songNum,
            title: title.trim(),
            body: body,
            key: Value(key),
            modified: Value(DateTime.now()),
            search: Value(search),
            copyright: Value(copyright),
            author: Value(author),
            categoryId: Value(bookCategoryId),
            sourceSongId: Value(songNum),
            sourcePath: Value(bookName),
            sourceFormat: const Value('bundled_json'),
          ),
        );
      }

      // Snapshot existing songs to detect duplicates.
      // Keyed by title (lowercase, trimmed) so cross-book duplicates with
      // different song numbers are still caught. Also updated during insertion
      // to handle within-file duplicate titles.
      final preExistingTitles = (await (db.select(db.songs)
                  ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
              .get())
          .map((s) => s.title.toLowerCase().trim())
          .toSet();

      final seenThisBatch = <String>{};

      // Insert data
      await db.transaction(() async {
        for (final song in songCompanions) {
          final titleKey = song.title.value.toLowerCase().trim();
          // Skip if already in DB from a previous seed
          if (preExistingTitles.contains(titleKey)) continue;
          // Skip if already inserted earlier in this same batch
          if (!seenThisBatch.add(titleKey)) continue;

          await db.into(db.songs).insert(song);
        }
      });

      // Calculate stats
      final newSongTitles = <String>[];
      int alreadyExisted = 0;
      for (final companion in songCompanions) {
        final titleKey = companion.title.value.toLowerCase().trim();
        if (preExistingTitles.contains(titleKey) || !seenThisBatch.contains(titleKey)) {
          alreadyExisted++;
        } else {
          newSongTitles.add(companion.title.value);
        }
      }

      return ImportResult.success(
        songs: songCompanions.length,
        categories: 1,
        added: newSongTitles.length,
        alreadyExisted: alreadyExisted,
        newTitles: newSongTitles,
      );
    } catch (e) {
      return ImportResult.failure('Error importing bundled JSON: $e');
    }
  }
}
