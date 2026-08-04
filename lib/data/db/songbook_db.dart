import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:visual_song_book/data/services/app_storage.dart';

part 'songbook_db.g.dart';

class Categories extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withLength(max: 100)();

  @override
  Set<Column> get primaryKey => {id};
}

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songNum => integer()();
  TextColumn get title => text().withLength(max: 200)();
  TextColumn get key => text().nullable().withLength(max: 100)();
  TextColumn get body => text().withLength(max: 1_000_000)(); // Capped at 1 MB to prevent memory exhaustion
  DateTimeColumn get modified => dateTime().nullable()();
  TextColumn get search => text().nullable()(); // Normalized search text
  TextColumn get copyright => text().nullable().withLength(max: 200)();
  TextColumn get author => text().nullable().withLength(max: 200)();

  // References Categories(id)
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  // Provenance / Round-trip tracking
  IntColumn get sourceSongId => integer().nullable()();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get sourceFormat => text().nullable()();

  // Soft-delete: songs can be deactivated without removing data
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class LinkedSongbookRegistry extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get name => text().withLength(max: 200)();
  DateTimeColumn get lastImportedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => ['UNIQUE(path)'];
}

class SongBooks extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text().withLength(max: 100)();
  IntColumn get startingNumber => integer().nullable()();
  IntColumn get endingNumber => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().references(Songs, #id)();
  DateTimeColumn get accessedAt => dateTime()();
}

class SongSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get notes => text().nullable()();
  TextColumn get occasion => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get uuid => text().nullable()();
}

class SongSetItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId => integer().references(SongSets, #id)();
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();
  TextColumn get key => text().nullable().withLength(max: 100)();
}

class SetHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId => integer().references(SongSets, #id)();
  TextColumn get setName => text().withLength(max: 200)();
  DateTimeColumn get accessedAt => dateTime()();
}

class BibleHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reference => text().withLength(max: 100)();
  TextColumn get passage => text()();
  DateTimeColumn get accessedAt => dateTime()();
}

class BibleBookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()();
  IntColumn get chapter => integer()();
  IntColumn get verseNum => integer()();
  TextColumn get reference => text()();
  TextColumn get verseText => text()();
  TextColumn get bookName => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    Categories,
    LinkedSongbookRegistry,
    Songs,
    SongBooks,
    History,
    SongSets,
    SongSetItems,
    SetHistory,
    BibleHistory,
    BibleBookmarks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.withExecutor(super.executor);

  /// In-memory database for use in unit/widget tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 10;

  // Linked songbooks helpers

  Future<List<LinkedSongbookRegistryData>> getAllLinkedSongbooks() =>
      (select(linkedSongbookRegistry)..orderBy([(t) => OrderingTerm.asc(t.path)])).get();

  Stream<List<LinkedSongbookRegistryData>> watchAllLinkedSongbooks() =>
      (select(linkedSongbookRegistry)..orderBy([(t) => OrderingTerm.asc(t.path)])).watch();

  Future<LinkedSongbookRegistryData?> getLinkedSongbookByPath(String path) =>
      (select(linkedSongbookRegistry)..where((t) => t.path.equals(path))).getSingleOrNull();

  Future<int> insertLinkedSongbook(LinkedSongbookRegistryCompanion entry) =>
      into(linkedSongbookRegistry).insert(entry);

  Future<int> updateLinkedSongbookByPath(String path, LinkedSongbookRegistryCompanion entry) =>
      (update(linkedSongbookRegistry)..where((t) => t.path.equals(path))).write(entry);

  Future<int> deleteLinkedSongbookByPath(String path) =>
      (delete(linkedSongbookRegistry)..where((t) => t.path.equals(path))).go();

  Future<int> countLinkedSongbooks() async =>
      (await select(linkedSongbookRegistry).get()).length;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.database.customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_songs_title_num ON songs (LOWER(title), song_num) WHERE is_active = 1');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_songs_active_category ON songs (is_active, category_id, song_num)');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(songSets);
        await m.createTable(songSetItems);
        await m.createTable(setHistory);
        await m.createTable(bibleHistory);
      }
      if (from < 3) {
        await m.createTable(bibleBookmarks);
      }
      if (from < 4) {
        await m.addColumn(songs, songs.isActive);
      }
      if (from < 5) {
        await m.addColumn(songSets, songSets.uuid);
      }
      if (from < 6) {
        await m.addColumn(songSetItems, songSetItems.key);
      }
      if (from < 7) {
        await m.database.customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_songs_title_num ON songs (LOWER(title), song_num) WHERE is_active = 1');
      }
      if (from < 8) {
        // body length cap is enforced at the Dart layer for existing rows;
        // CHECK constraint is applied only on new database creation.
      }
      if (from < 9) {
        await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_songs_active_category ON songs (is_active, category_id, song_num)');
      }
      if (from < 10) {
        await m.createTable(linkedSongbookRegistry);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbPath = await getAppStorageFilePath('songs_db.sqlite');
    return NativeDatabase(File(dbPath));
  });
}
