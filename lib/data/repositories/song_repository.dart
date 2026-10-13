import 'package:drift/drift.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
import 'package:visual_song_book/core/utils/search_pattern.dart';
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

  Expression<bool> _sourceFilter(Songs t, {String? sourcePath, SourceMode? sourceMode}) {
    Expression<bool> filter = t.isActive.equals(true);
    if (sourceMode == SourceMode.bundled) {
      filter = filter & t.sourcePath.isNotNull() & t.sourcePath.isNotIn(['']);
    } else if (sourceMode == SourceMode.linked) {
      filter = filter & t.sourceFormat.equals('vsbook_linked');
    }
    if (sourcePath != null) {
      filter = filter & t.sourcePath.equals(sourcePath);
    }
    return filter;
  }

  /// The search predicate, shared by `searchSongs` and `countSearchSongs`
  /// so the count can never drift from the results it pages.
  ///
  /// Supports `*` (any run of characters) and `?` (exactly one character)
  /// via [buildWildcardLikePattern]; typing `%` or `_` matches those
  /// characters literally.
  Expression<bool> _searchPredicate(Songs t, String query, String? sourcePath, SourceMode? sourceMode) {
    final trimmed = query.trim();
    // Wrapped in %...% so a plain word still matches a substring, which is what
    // operators expect before they learn about the wildcards.
    final matchPattern = '%${buildWildcardLikePattern(trimmed)}%';
    final songNumInt = int.tryParse(trimmed);

    Expression<bool> searchExpr = t.title.lower().like(matchPattern, escapeChar: likeEscapeChar) |
        t.body.lower().like(matchPattern, escapeChar: likeEscapeChar) |
        t.author.lower().like(matchPattern, escapeChar: likeEscapeChar) |
        t.search.lower().like(matchPattern, escapeChar: likeEscapeChar);

    if (songNumInt != null) {
      searchExpr = searchExpr | t.songNum.equals(songNumInt);
    }

    return _sourceFilter(t, sourcePath: sourcePath, sourceMode: sourceMode) & searchExpr;
  }

  /// Counts rows matching [query] without loading them.
  Future<int> _searchSongsForCount(
    String query, {
    String? sourcePath,
    SourceMode? sourceMode,
  }) async {
    if (query.trim().isEmpty) {
      final countQuery = db.selectOnly(db.songs)
        ..addColumns([db.songs.id.count()])
        ..where(_sourceFilter(db.songs, sourcePath: sourcePath, sourceMode: sourceMode));
      final row = await countQuery.getSingle();
      return row.read(db.songs.id.count()) ?? 0;
    }

    final countQuery = db.selectOnly(db.songs)
      ..addColumns([db.songs.id.count()])
      ..where(_searchPredicate(db.songs, query, sourcePath, sourceMode));
    final row = await countQuery.getSingle();
    return row.read(db.songs.id.count()) ?? 0;
  }

  /// Searches active songs by title, body, author, or song number.
  ///
  /// [limit] / [offset] page the results. They default to `null` (return
  /// everything) so existing callers keep working unchanged, but the search UI
  /// passes them: a broad term in a large songbook can otherwise match every
  /// song and pull every body into memory at once.
  Future<List<Song>> searchSongs(
    String query, {
    String? sourcePath,
    SourceMode? sourceMode,
    int? limit,
    int? offset,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getSongs();
    }

    final statement = db.select(db.songs)
      ..where((t) => _searchPredicate(t, query, sourcePath, sourceMode))
      ..orderBy([(t) => OrderingTerm.asc(t.songNum)]);

    if (limit != null) {
      statement.limit(limit, offset: offset);
    }

    return statement.get();
  }

  /// Total number of songs matching [query], for paging search results.
  Future<int> countSearchSongs(String query, {String? sourcePath, SourceMode? sourceMode}) async {
    // Reuse the search predicate so the count can never drift from the
    // results it pages.
    final results = await _searchSongsForCount(
      query,
      sourcePath: sourcePath,
      sourceMode: sourceMode,
    );
    return results;
  }

  /// Watches active songs in a specific category
  Stream<List<Song>> watchSongsByCategory(int? categoryId, {String? sourcePath, SourceMode? sourceMode}) {
    if (categoryId == null) {
      return (db.select(db.songs)
            ..where((t) {
              Expression<bool> expr = _sourceFilter(t, sourcePath: sourcePath, sourceMode: sourceMode) & t.categoryId.isNull();
              return expr;
            })
            ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
          .watch();
    }
    return (db.select(db.songs)
          ..where((t) {
            Expression<bool> expr = _sourceFilter(t, sourcePath: sourcePath, sourceMode: sourceMode) & t.categoryId.equals(categoryId);
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
        .watch();
  }

  /// Watches all active songs, optionally filtered by source path and source mode
  Stream<List<Song>> watchSongsFiltered({String? sourcePath, SourceMode? sourceMode}) {
    return (db.select(db.songs)
          ..where((t) {
            Expression<bool> expr = _sourceFilter(t, sourcePath: sourcePath, sourceMode: sourceMode);
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

  Future<int> getSongCountByCategory(int categoryId) async {
    final result = await (db.selectOnly(db.songs)
          ..addColumns([db.songs.id.count()])
          ..where(db.songs.categoryId.equals(categoryId) & db.songs.isActive.equals(true)))
        .getSingle();
    return result.read(db.songs.id.count()) ?? 0;
  }

  Future<Map<int, int>> getSongCountsByCategory() async {
    final result = await (db.selectOnly(db.songs)
          ..addColumns([db.songs.categoryId, db.songs.id.count()])
          ..where(db.songs.isActive.equals(true))
          ..groupBy([db.songs.categoryId])
    ).get();
    return {
      for (var row in result)
        row.read(db.songs.categoryId)!: row.read(db.songs.id.count())!,
    };
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

    await db.customStatement('''
      DELETE FROM history 
      WHERE id NOT IN (
        SELECT id FROM history ORDER BY accessed_at DESC LIMIT 50
      )
    ''');
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
