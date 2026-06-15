import 'package:drift/drift.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SongRepository {
  final AppDatabase db;

  SongRepository(this.db);

  // === Songs ===

  /// Fetches all songs, ordered by song number
  Future<List<Song>> getSongs() {
    return (db.select(db.songs)..orderBy([(t) => OrderingTerm.asc(t.songNum)])).get();
  }

  /// Watches all songs, ordered by song number
  Stream<List<Song>> watchSongs() {
    return (db.select(db.songs)..orderBy([(t) => OrderingTerm.asc(t.songNum)])).watch();
  }

  /// Searches songs by title, body, author, or song number
  Future<List<Song>> searchSongs(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getSongs();
    }

    final matchQuery = '%${trimmed.toLowerCase()}%';
    final songNumInt = int.tryParse(trimmed);

    final statement = db.select(db.songs)
      ..where((t) {
        Expression<bool> expr = t.title.lower().like(matchQuery) |
            t.body.lower().like(matchQuery) |
            t.author.lower().like(matchQuery) |
            t.search.lower().like(matchQuery);

        if (songNumInt != null) {
          expr = expr | t.songNum.equals(songNumInt);
        }
        return expr;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.songNum)]);

    return statement.get();
  }

  /// Watches songs in a specific category
  Stream<List<Song>> watchSongsByCategory(int? categoryId) {
    if (categoryId == null) {
      return (db.select(db.songs)
            ..where((t) => t.categoryId.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
          .watch();
    }
    return (db.select(db.songs)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .watch();
  }

  Future<Song?> getSongById(int id) {
    return (db.select(db.songs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> addSong(SongsCompanion companion) {
    return db.into(db.songs).insert(companion);
  }

  Future<bool> updateSong(SongsCompanion companion) {
    return db.update(db.songs).replace(companion);
  }

  Future<int> deleteSong(int id) {
    return (db.delete(db.songs)..where((t) => t.id.equals(id))).go();
  }

  // === Categories ===

  Future<List<Category>> getCategories() {
    return (db.select(db.categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Stream<List<Category>> watchCategories() {
    return (db.select(db.categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<int> addCategory(CategoriesCompanion companion) {
    return db.into(db.categories).insertOnConflictUpdate(companion);
  }

  Future<int> getSongCountByCategory(int categoryId) {
    return (db.select(db.songs)..where((t) => t.categoryId.equals(categoryId)))
        .map((row) => row.id)
        .get()
        .then((ids) => ids.length);
  }

  Future<void> deleteCategory(int categoryId) async {
    await db.transaction(() async {
      await (db.delete(db.songs)..where((t) => t.categoryId.equals(categoryId))).go();
      await (db.delete(db.categories)..where((t) => t.id.equals(categoryId))).go();
    });
  }

  // === Source Management ===

  /// Fetches distinct source paths from the songs table
  Future<List<String>> getDistinctSourcePaths() async {
    final query = db.selectOnly(db.songs, distinct: true)..addColumns([db.songs.sourcePath]);
    final result = await query.get();
    return result
        .map((row) => row.read(db.songs.sourcePath))
        .where((path) => path != null)
        .cast<String>()
        .toList();
  }

  /// Deletes all songs associated with a specific source path
  Future<int> deleteSongsBySource(String sourcePath) {
    return (db.delete(db.songs)..where((t) => t.sourcePath.equals(sourcePath))).go();
  }

  // === History ===

  /// Adds a song to the history. Keeps only the last 50 accessed items.
  Future<void> addToHistory(int songId) async {
    final now = DateTime.now();
    await db.into(db.history).insert(
          HistoryCompanion.insert(
            songId: songId,
            accessedAt: now,
          ),
        );

    // Prune history to keep only the latest 50 entries
    final oldEntries = await (db.select(db.history)
          ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
          ..limit(100, offset: 50))
        .get();

    if (oldEntries.isNotEmpty) {
      final oldIds = oldEntries.map((e) => e.id).toList();
      await (db.delete(db.history)..where((t) => t.id.isIn(oldIds))).go();
    }
  }

  /// Watches history and maps rows to the corresponding [Song] objects, returning latest first
  Stream<List<Song>> watchHistory() {
    final query = db.select(db.history).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.history.songId)),
    ]);
    query.orderBy([OrderingTerm.desc(db.history.accessedAt)]);
    
    // Group by songId to show each song only once in the history list
    return query.watch().map((rows) {
      final seenSongIds = <int>{};
      final List<Song> distinctSongs = [];
      for (final row in rows) {
        final song = row.readTable(db.songs);
        if (!seenSongIds.contains(song.id)) {
          seenSongIds.add(song.id);
          distinctSongs.add(song);
        }
      }
      return distinctSongs;
    });
  }

  Future<void> clearHistory() {
    return db.delete(db.history).go();
  }
}
