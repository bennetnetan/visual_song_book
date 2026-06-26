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

      final List<dynamic> categoriesJson = data['categories'] as List<dynamic>? ?? [];
      final List<dynamic> songsJson = data['songs'] as List<dynamic>? ?? [];

      if (songsJson.isEmpty) {
        return ImportResult.failure('JSON file contains no songs.');
      }

      // Build category companions
      final categoryCompanions = <CategoriesCompanion>[];
      for (final item in categoriesJson) {
        final id = item['id'] as int?;
        final name = item['name'] as String?;
        if (id != null && name != null && name.isNotEmpty) {
          categoryCompanions.add(
            CategoriesCompanion.insert(id: Value(id), name: name),
          );
        }
      }

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
        final categoryId = item['category_id'] as int?;

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
            categoryId: categoryId != null
                ? Value(categoryId)
                : const Value<int?>.absent(),
            sourceSongId: Value(songNum),
            sourcePath: Value(bookName),
            sourceFormat: const Value('bundled_json'),
          ),
        );
      }

      // Snapshot existing songs to detect duplicates
      final preExisting = await (db.select(db.songs)
            ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
          .get();
      final preExistingKeys = preExisting
          .map((s) => '${s.songNum}|${s.title.toLowerCase().trim()}')
          .toSet();

      // Insert data
      await db.transaction(() async {
        for (final category in categoryCompanions) {
          await db.into(db.categories).insertOnConflictUpdate(category);
        }

        for (final song in songCompanions) {
          final key =
              '${song.songNum.value}|${song.title.value.toLowerCase().trim()}';
          if (!preExistingKeys.contains(key)) {
            await db.into(db.songs).insert(song);
          }
        }
      });

      // Calculate stats
      final newSongTitles = <String>[];
      int alreadyExisted = 0;
      for (final companion in songCompanions) {
        final key =
            '${companion.songNum.value}|${companion.title.value.toLowerCase().trim()}';
        if (preExistingKeys.contains(key)) {
          alreadyExisted++;
        } else {
          newSongTitles.add(companion.title.value);
        }
      }

      return ImportResult.success(
        songs: songCompanions.length,
        categories: categoryCompanions.length,
        added: newSongTitles.length,
        alreadyExisted: alreadyExisted,
        newTitles: newSongTitles,
      );
    } catch (e) {
      return ImportResult.failure('Error importing bundled JSON: $e');
    }
  }
}
