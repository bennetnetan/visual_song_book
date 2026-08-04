import 'package:drift/drift.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SongRepository {
  final AppDatabase db;

  SongRepository(this.db);

  // === Songs (only active songs are shown by default) ===

  /// Fetches all active songs, ordered by song number
  Future<List<Song>> getSongs() {
    return (db.select(db.songs)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .get();
  }

  /// Watches all active songs, ordered by song number
  Stream<List<Song>> watchSongs() {
    return (db.select(db.songs)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .watch();
  }

  /// Searches active songs by title, body, author, or song number
  Future<List<Song>> searchSongs(String query, {String? sourcePath}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getSongs();
    }

    final matchQuery = '%${trimmed.toLowerCase()}%';
    final songNumInt = int.tryParse(trimmed);

    final statement = db.select(db.songs)
      ..where((t) {
        Expression<bool> activeFilter = t.isActive.equals(true);

        if (sourcePath != null) {
          activeFilter = activeFilter & t.sourcePath.equals(sourcePath);
        }

        Expression<bool> searchExpr =
            t.title.lower().like(matchQuery) |
            t.body.lower().like(matchQuery) |
            t.author.lower().like(matchQuery) |
            t.search.lower().like(matchQuery);

        if (songNumInt != null) {
          searchExpr = searchExpr | t.songNum.equals(songNumInt);
        }
        return activeFilter & searchExpr;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.songNum)]);

    return statement.get();
  }

  /// Watches active songs in a specific category
  Stream<List<Song>> watchSongsByCategory(int? categoryId, {String? sourcePath}) {
    if (categoryId == null) {
      return (db.select(db.songs)
            ..where((t) {
              Expression<bool> expr = t.isActive.equals(true) & t.categoryId.isNull();
              if (sourcePath != null) {
                expr = expr & t.sourcePath.equals(sourcePath);
              }
              return expr;
            })
            ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
          .watch();
    }
    return (db.select(db.songs)
          ..where((t) {
            Expression<bool> expr = t.isActive.equals(true) & t.categoryId.equals(categoryId);
            if (sourcePath != null) {
              expr = expr & t.sourcePath.equals(sourcePath);
            }
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .watch();
  }

  /// Watches all active songs, optionally filtered by source path
  Stream<List<Song>> watchSongsFiltered({String? sourcePath}) {
    return (db.select(db.songs)
          ..where((t) {
            Expression<bool> expr = t.isActive.equals(true);
            if (sourcePath != null) {
              expr = expr & t.sourcePath.equals(sourcePath);
            }
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .watch();
  }

  Future<Song?> getSongById(int id) {
    return (db.select(
      db.songs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> addSong(SongsCompanion companion) {
    return db.into(db.songs).insert(companion);
  }

  Future<bool> updateSong(SongsCompanion companion) {
    return db.update(db.songs).replace(companion);
  }

  /// Hard-delete a song permanently
  Future<int> deleteSong(int id) {
    return (db.delete(db.songs)..where((t) => t.id.equals(id))).go();
  }

  // === Soft Delete / Reactivate ===

  /// Soft-delete a song (mark as inactive, keep data)
  Future<void> deactivateSong(int id) async {
    await (db.update(db.songs)..where((t) => t.id.equals(id))).write(
      const SongsCompanion(isActive: Value(false)),
    );
  }

  /// Re-activate a previously soft-deleted song
  Future<void> activateSong(int id) async {
    await (db.update(db.songs)..where((t) => t.id.equals(id))).write(
      const SongsCompanion(isActive: Value(true)),
    );
  }

  /// Soft-delete all songs from a source path (mark as inactive)
  Future<void> deactivateSongsBySource(String sourcePath) async {
    await (db.update(db.songs)..where((t) => t.sourcePath.equals(sourcePath))).write(
      const SongsCompanion(isActive: Value(false)),
    );
  }

  /// Re-activate all songs from a source path
  Future<void> activateSongsBySource(String sourcePath) async {
    await (db.update(db.songs)..where((t) => t.sourcePath.equals(sourcePath))).write(
      const SongsCompanion(isActive: Value(true)),
    );
  }

  /// Returns all inactive (soft-deleted) songs
  Future<List<Song>> getDeactivatedSongs() {
    return (db.select(db.songs)
          ..where((t) => t.isActive.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .get();
  }

  // === Categories ===

  Future<List<Category>> getCategories() {
    return (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Stream<List<Category>> watchCategories() {
    return (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<int> addCategory(CategoriesCompanion companion) {
    return db.into(db.categories).insertOnConflictUpdate(companion);
  }

  Future<int> getSongCountByCategory(int categoryId) {
    return (db.select(db.songs)
          ..where((t) => t.categoryId.equals(categoryId) & t.isActive.equals(true)))
        .map((row) => row.id)
        .get()
        .then((ids) => ids.length);
  }

  Future<void> deleteCategory(int categoryId) async {
    await db.transaction(() async {
      await (db.update(
        db.songs,
      )..where((t) => t.categoryId.equals(categoryId))).write(
        const SongsCompanion(categoryId: Value(null)),
      );
      await (db.delete(
        db.categories,
      )..where((t) => t.id.equals(categoryId))).go();
    });
  }

  // === Source Management ===

  /// Fetches distinct source paths from the songs table
  Future<List<String>> getDistinctSourcePaths() async {
    final query = db.selectOnly(db.songs, distinct: true)
      ..addColumns([db.songs.sourcePath]);
    final result = await query.get();
    return result
        .map((row) => row.read(db.songs.sourcePath))
        .where((path) => path != null)
        .cast<String>()
        .toList();
  }

  /// Returns distinct source paths with song counts, ordered by count descending
  Future<List<({String path, int count})>> getSourcePathCounts() async {
    final query = db.selectOnly(db.songs)
      ..addColumns([db.songs.sourcePath, db.songs.id.count()])
      ..where(db.songs.isActive.equals(true) & db.songs.sourcePath.isNotNull())
      ..groupBy([db.songs.sourcePath])
      ..orderBy([OrderingTerm.desc(db.songs.id.count())]);
    final result = await query.get();
    return result
        .map((row) {
          final path = row.read(db.songs.sourcePath)!;
          final count = row.read(db.songs.id.count())!;
          return (path: path, count: count);
        })
        .toList();
  }

  /// Hard-deletes all songs associated with a specific source path
  Future<int> deleteSongsBySource(String sourcePath) {
    return (db.delete(
      db.songs,
    )..where((t) => t.sourcePath.equals(sourcePath))).go();
  }

  /// Deletes ALL songs and categories (danger zone wipe)
  Future<void> deleteAllSongs() async {
    await db.transaction(() async {
      await db.delete(db.songs).go();
      await db.delete(db.categories).go();
    });
  }

  // === History ===

  /// Adds a song to the history. Keeps only the last 50 accessed items.
  Future<void> addToHistory(int songId) async {
    final now = DateTime.now();
    await db
        .into(db.history)
        .insert(HistoryCompanion.insert(songId: songId, accessedAt: now));

    // Prune history to keep only the latest 50 entries
    final oldEntries =
        await (db.select(db.history)
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

  /// Watches all active songs (alias for watchSongs used by Sets controller)
  Stream<List<Song>> watchAllSongs() => watchSongs();
}
