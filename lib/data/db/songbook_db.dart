import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';

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
  TextColumn get body => text()(); // The full lyrics
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
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
    },
  );
}

QueryExecutor _openConnection() {
  // driftDatabase automatically selects the right path on all platforms
  // (App Support directory on desktop, App Documents directory on mobile)
  return driftDatabase(name: 'songs_db');
}
