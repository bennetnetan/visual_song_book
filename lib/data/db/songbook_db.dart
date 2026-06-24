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
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  // Provenance / Round-trip tracking
  IntColumn get sourceSongId => integer().nullable()();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get sourceFormat => text().nullable()();
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

@DriftDatabase(tables: [Categories, Songs, SongBooks, History])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.withExecutor(QueryExecutor executor) : super(executor);

  /// In-memory database for use in unit/widget tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  // driftDatabase automatically selects the right path on all platforms
  // (App Support directory on desktop, App Documents directory on mobile)
  return driftDatabase(name: 'songs_db');
}
