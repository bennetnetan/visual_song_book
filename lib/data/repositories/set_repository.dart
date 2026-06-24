import 'package:drift/drift.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SetRepository {
  final AppDatabase db;

  SetRepository(this.db);

  Future<List<SongSet>> getAllSets() => db.select(db.songSets).get();

  Stream<List<SongSet>> watchAllSets() => db.select(db.songSets).watch();

  Future<SongSet> createSet(
    String name, {
    String? notes,
    String? occasion,
  }) async {
    final id = await db
        .into(db.songSets)
        .insert(
          SongSetsCompanion.insert(
            name: name,
            notes: Value(notes),
            occasion: Value(occasion),
            createdAt: DateTime.now(),
          ),
        );
    return (db.select(db.songSets)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateSet(
    int setId, {
    String? name,
    String? notes,
    String? occasion,
  }) async {
    await (db.update(db.songSets)..where((t) => t.id.equals(setId))).write(
      SongSetsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        occasion: occasion != null ? Value(occasion) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteSet(int setId) async {
    await (db.delete(
      db.songSetItems,
    )..where((t) => t.setId.equals(setId))).go();
    await (db.delete(db.songSets)..where((t) => t.id.equals(setId))).go();
  }

  Future<List<SongSetItem>> getSetItems(int setId) async {
    return (db.select(db.songSetItems)
          ..where((t) => t.setId.equals(setId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<void> addSongToSet(int setId, int songId, int position) async {
    await db
        .into(db.songSetItems)
        .insert(
          SongSetItemsCompanion.insert(
            setId: setId,
            songId: songId,
            position: position,
          ),
        );
  }

  Future<void> removeSongFromSet(int setId, int songId) async {
    await (db.delete(
      db.songSetItems,
    )..where((t) => t.setId.equals(setId) & t.songId.equals(songId))).go();
  }

  Future<void> reorderSetItems(int setId, List<int> songIds) async {
    await db.transaction(() async {
      for (var i = 0; i < songIds.length; i++) {
        await (db.update(db.songSetItems)..where(
              (t) => t.setId.equals(setId) & t.songId.equals(songIds[i]),
            ))
            .write(SongSetItemsCompanion(position: Value(i)));
      }
    });
  }

  // History

  Future<void> recordSetProjection(int setId, String setName) async {
    await db
        .into(db.setHistory)
        .insert(
          SetHistoryCompanion.insert(
            setId: setId,
            setName: setName,
            accessedAt: DateTime.now(),
          ),
        );
  }

  Future<List<SetHistoryData>> getSetHistory() async {
    return (db.select(db.setHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
          ..limit(50))
        .get();
  }

  Future<void> clearSetHistory() async {
    await db.delete(db.setHistory).go();
  }

  // Bible history

  Future<void> recordBibleProjection(String reference, String passage) async {
    await db
        .into(db.bibleHistory)
        .insert(
          BibleHistoryCompanion.insert(
            reference: reference,
            passage: passage,
            accessedAt: DateTime.now(),
          ),
        );
  }

  Future<List<BibleHistoryData>> getBibleHistory() async {
    return (db.select(db.bibleHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
          ..limit(50))
        .get();
  }

  Future<void> clearBibleHistory() async {
    await db.delete(db.bibleHistory).go();
  }

  Future<int> getSongCountForSet(int setId) async {
    return (db.select(
      db.songSetItems,
    )..where((t) => t.setId.equals(setId))).get().then((r) => r.length);
  }

  // Bookmarks

  Future<List<BibleBookmark>> getBookmarks() async {
    return (db.select(db.bibleBookmarks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ).get();
  }

  Future<void> addBookmark(int bookId, int chapter, int verseNum, String reference, String verseText, String bookName) async {
    await db.into(db.bibleBookmarks).insert(BibleBookmarksCompanion.insert(
      bookId: bookId,
      chapter: chapter,
      verseNum: verseNum,
      reference: reference,
      verseText: verseText,
      bookName: bookName,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> removeBookmark(int id) async {
    await (db.delete(db.bibleBookmarks)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> isBookmarked(int bookId, int chapter, int verseNum) async {
    final rows = await (db.select(db.bibleBookmarks)
      ..where((t) => t.bookId.equals(bookId) & t.chapter.equals(chapter) & t.verseNum.equals(verseNum))
    ).get();
    return rows.isNotEmpty;
  }
}
