import 'dart:typed_data';
import 'package:visual_song_book/data/db/songbook_db.dart';

enum ImportSourceType { file, bytes }

class ImportSource {
  final ImportSourceType type;
  final String? filePath;
  final Uint8List? bytes;

  ImportSource.fromFile(this.filePath)
    : type = ImportSourceType.file,
      bytes = null;

  ImportSource.fromBytes(this.bytes)
    : type = ImportSourceType.bytes,
      filePath = null;
}

class ImportResult {
  final bool success;
  final int songsImported;
  final int categoriesImported;
  final String? errorMessage;
  final int songsAdded;
  final int songsAlreadyExisted;
  final List<String> newSongTitles;

  ImportResult({
    required this.success,
    this.songsImported = 0,
    this.categoriesImported = 0,
    this.errorMessage,
    this.songsAdded = 0,
    this.songsAlreadyExisted = 0,
    this.newSongTitles = const [],
  });

  factory ImportResult.success({
    int songs = 0,
    int categories = 0,
    int added = 0,
    int alreadyExisted = 0,
    List<String> newTitles = const [],
  }) {
    return ImportResult(
      success: true,
      songsImported: songs,
      categoriesImported: categories,
      songsAdded: added,
      songsAlreadyExisted: alreadyExisted,
      newSongTitles: newTitles,
    );
  }

  factory ImportResult.failure(String error) {
    return ImportResult(success: false, errorMessage: error);
  }
}

/// Deduplicates a list of [SongsCompanion] entries by the composite key
/// `songNum|LOWER(title)`, keeping the first occurrence of each pair.
///
/// This makes imports resilient to dirty source data where the same song
/// appears more than once (e.g. bundled songbooks with duplicate entries).
///
/// Returns the deduplicated list and the number of duplicates removed.
({List<SongsCompanion> deduplicated, int duplicatesRemoved}) deduplicateSongs(
  List<SongsCompanion> songs,
) {
  final seen = <String>{};
  final deduplicated = <SongsCompanion>[];
  int duplicatesRemoved = 0;

  for (final song in songs) {
    final key =
        '${song.songNum.value}|${song.title.value.toLowerCase().trim()}';
    if (seen.add(key)) {
      deduplicated.add(song);
    } else {
      duplicatesRemoved++;
    }
  }

  return (deduplicated: deduplicated, duplicatesRemoved: duplicatesRemoved);
}

abstract class SongbookImporter {
  /// Unique name of the importer
  String get name;

  /// Whether this platform supports importing from this source
  bool canImport(ImportSource source);

  /// Performs the import and writes to [AppDatabase]
  Future<ImportResult> import(ImportSource source);
}
