import 'package:drift/drift.dart';
import 'package:visual_song_book/core/utils/uuid_generator.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SetRepository {
  final AppDatabase db;

  SetRepository(this.db);

  Future<List<SongSet>> getAllSets() => (db.select(db.songSets)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

  Stream<List<SongSet>> watchAllSets() => (db.select(db.songSets)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<SongSet?> getSetByUuid(String uuid) =>
      (db.select(db.songSets)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  Future<SongSet> createSet(
    String name, {
    String? notes,
    String? occasion,
  }) async {
    final generatedUuid = UuidGenerator.generate();
    final id = await db
        .into(db.songSets)
        .insert(
          SongSetsCompanion.insert(
            name: name,
            notes: Value(notes),
            occasion: Value(occasion),
            createdAt: DateTime.now(),
            uuid: Value(generatedUuid),
          ),
        );
    return (db.select(db.songSets)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<SongSet> createSetWithUuid({
    required String name,
    required String uuid,
    String? notes,
    String? occasion,
    DateTime? createdAt,
  }) async {
    final id = await db
        .into(db.songSets)
        .insert(
          SongSetsCompanion.insert(
            name: name,
            uuid: Value(uuid),
            notes: Value(notes),
            occasion: Value(occasion),
            createdAt: createdAt ?? DateTime.now(),
          ),
        );
    return (db.select(db.songSets)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<SongSet> duplicateSet(int setId, {String? newName}) async {
    final original = await (db.select(db.songSets)..where((t) => t.id.equals(setId))).getSingleOrNull();
    if (original == null) throw Exception('Original set not found');

    final items = await getSetItems(setId);
    final targetName = newName ?? '${original.name} (Copy)';
    final newUuid = UuidGenerator.generate();

    return db.transaction(() async {
      final newSet = await createSetWithUuid(
        name: targetName,
        uuid: newUuid,
        notes: original.notes,
        occasion: original.occasion,
        createdAt: DateTime.now(),
      );

      for (final item in items) {
        await db.into(db.songSetItems).insert(
              SongSetItemsCompanion.insert(
                setId: newSet.id,
                songId: item.songId,
                position: item.position,
                key: Value(item.key),
                notes: Value(item.notes),
              ),
            );
      }

      return newSet;
    });
  }

  Future<void> updateSet(
    int setId, {
    String? name,
    String? notes,
    String? occasion,
    DateTime? createdAt,
  }) async {
    await (db.update(db.songSets)..where((t) => t.id.equals(setId))).write(
      SongSetsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        occasion: occasion != null ? Value(occasion) : const Value.absent(),
        createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteSet(int setId) async {
    await db.transaction(() async {
      await (db.delete(
        db.songSetItems,
      )..where((t) => t.setId.equals(setId))).go();
      await (db.delete(db.songSets)..where((t) => t.id.equals(setId))).go();
    });
  }

  Future<List<SongSetItem>> getSetItems(int setId) async {
    return (db.select(db.songSetItems)
          ..where((t) => t.setId.equals(setId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Stream<List<SongSetItem>> watchSetItems(int setId) {
    return (db.select(db.songSetItems)
          ..where((t) => t.setId.equals(setId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<void> addSongToSet(int setId, int songId, int position, {String? key, String? notes}) async {
    await db
        .into(db.songSetItems)
        .insert(
          SongSetItemsCompanion.insert(
            setId: setId,
            songId: songId,
            position: position,
            key: Value(key),
            notes: Value(notes),
          ),
        );
  }

  Future<void> updateSetItemKey(int setId, int songId, String? key) async {
    await (db.update(db.songSetItems)
          ..where((t) => t.setId.equals(setId) & t.songId.equals(songId)))
        .write(
      SongSetItemsCompanion(
        key: Value(key),
      ),
    );
  }

  Future<void> updateSetItemNotes(int setId, int songId, String? notes) async {
    await (db.update(db.songSetItems)
          ..where((t) => t.setId.equals(setId) & t.songId.equals(songId)))
        .write(
      SongSetItemsCompanion(
        notes: Value(notes),
      ),
    );
  }

  Future<List<String>> getLastUsedKeysForSong(int songId, {int limit = 3}) async {
    final query = db.select(db.songSetItems).join([
      innerJoin(db.songSets, db.songSets.id.equalsExp(db.songSetItems.setId)),
    ])
      ..where(db.songSetItems.songId.equals(songId) & db.songSetItems.key.isNotNull())
      ..orderBy([OrderingTerm.desc(db.songSets.createdAt)]);

    final rows = await query.get();
    final keys = <String>[];
    for (final row in rows) {
      final key = row.readTable(db.songSetItems).key;
      if (key != null && !keys.contains(key)) {
        keys.add(key);
        if (keys.length >= limit) break;
      }
    }
    return keys;
  }

  Future<List<String>> getTopUsedKeysForSong(int songId, {int limit = 3}) async {
    final items = await (db.select(db.songSetItems)
          ..where((t) => t.songId.equals(songId) & t.key.isNotNull()))
        .get();

    final freq = <String, int>{};
    for (final item in items) {
      final key = item.key;
      if (key != null) {
        freq[key] = (freq[key] ?? 0) + 1;
      }
    }

    final sortedKeys = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

    return sortedKeys.take(limit).toList();
  }

  Future<void> removeSongFromSet(int setId, int songId) async {
    await (db.delete(
      db.songSetItems,
    )..where((t) => t.setId.equals(setId) & t.songId.equals(songId))).go();
  }

  Future<void> reorderSetItems(int setId, List<int> songIds) async {
    await db.transaction(() async {
      await db.batch((batch) {
        for (var i = 0; i < songIds.length; i++) {
          batch.update(
            db.songSetItems,
            SongSetItemsCompanion(position: Value(i)),
            where: (t) =>
                t.setId.equals(setId) & t.songId.equals(songIds[i]),
          );
        }
      });
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

  Stream<List<SetHistoryData>> watchSetHistory() {
    return (db.select(db.setHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
          ..limit(50))
        .watch();
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

  Stream<List<BibleHistoryData>> watchBibleHistory() {
    return (db.select(db.bibleHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.accessedAt)])
          ..limit(50))
        .watch();
  }

  Future<void> clearBibleHistory() async {
    await db.delete(db.bibleHistory).go();
  }

  Future<int> getSongCountForSet(int setId) async {
    final countExp = countAll();
    final query = db.selectOnly(db.songSetItems)
      ..addColumns([countExp])
      ..where(db.songSetItems.setId.equals(setId));
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  // Bookmarks

  Future<List<BibleBookmark>> getBookmarks() async {
    return (db.select(db.bibleBookmarks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ).get();
  }

  Stream<List<BibleBookmark>> watchBookmarks() {
    return (db.select(db.bibleBookmarks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ).watch();
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

  Future<Set<int>> getBookmarkedVerseIdsForChapter(int bookId, int chapter) async {
    final rows = await (db.select(db.bibleBookmarks)
      ..where((t) => t.bookId.equals(bookId) & t.chapter.equals(chapter))
    ).get();
    return rows.map((r) => r.verseNum).toSet();
  }

  Future<BibleBookmark?> getBookmarkByVerse(int bookId, int chapter, int verseNum) async {
    final rows = await (db.select(db.bibleBookmarks)
      ..where((t) => t.bookId.equals(bookId) & t.chapter.equals(chapter) & t.verseNum.equals(verseNum))
    ).get();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> removeBookmarkByVerse(int bookId, int chapter, int verseNum) async {
    await (db.delete(db.bibleBookmarks)
      ..where((t) => t.bookId.equals(bookId) & t.chapter.equals(chapter) & t.verseNum.equals(verseNum))
    ).go();
  }
}
