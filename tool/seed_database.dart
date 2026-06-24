// ignore_for_file: avoid_print
//
// Standalone database seeder — does NOT import Flutter or the app package.
// Uses only pure-Dart packages (sqlite3, csv) and dart:io.
//
// Run from the project root with:
//   dart run tool/seed_database.dart
//
// Requirements:
//   - mdb-export (mdb-tools) must be on PATH
//   - SQLite3 native library must be available (it's bundled via sqlite3_flutter_libs
//     on the target device, but on the dev machine install: sudo apt install libsqlite3-dev)

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const _dbPath = '/home/benjanetan/Documents/songs_db.sqlite';

const _vsbFiles = [
  'assets/songbooks/Full Song Book.vsb',
  'assets/songbooks/Injili Song Book.vsb',
];

Future<void> main() async {
  print('=== Visual Song Book — Database Seeder ===');
  print('Database : $_dbPath');
  print('');

  // --- Open / create database -------------------------------------------
  final db = sqlite3.open(_dbPath);
  _ensureSchema(db);

  int grandTotal = 0;

  for (final relPath in _vsbFiles) {
    final filePath = '${Directory.current.path}/$relPath';
    final file = File(filePath);
    if (!file.existsSync()) {
      print('ERROR: File not found: $filePath');
      continue;
    }

    print('Importing: $relPath');
    final (songs, cats) = await _importVsb(db, filePath);
    grandTotal += songs;
    print('  ✓ $songs songs, $cats categories\n');
  }

  // --- Summary -----------------------------------------------------------
  final songCount = db.select('SELECT COUNT(*) AS c FROM Songs').first['c'];
  final catCount  = db.select('SELECT COUNT(*) AS c FROM Categories').first['c'];
  print('=== Seeding Complete ===');
  print('Songs in database      : $songCount');
  print('Categories in database : $catCount');
  print('Songs inserted this run: $grandTotal');

  db.dispose();
  print('\nDatabase closed. Done!');
}

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------
void _ensureSchema(Database db) {
  db.execute('PRAGMA journal_mode=WAL;');
  db.execute('PRAGMA foreign_keys=ON;');
  db.execute('''
    CREATE TABLE IF NOT EXISTS Categories (
      id   INTEGER PRIMARY KEY,
      name TEXT NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS Songs (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      songNum      INTEGER NOT NULL,
      title        TEXT NOT NULL,
      key          TEXT,
      body         TEXT NOT NULL,
      modified     INTEGER,
      search       TEXT,
      copyright    TEXT,
      author       TEXT,
      categoryId   INTEGER REFERENCES Categories(id),
      sourceSongId INTEGER,
      sourcePath   TEXT,
      sourceFormat TEXT
    );
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS SongBooks (
      id             INTEGER PRIMARY KEY,
      title          TEXT NOT NULL,
      startingNumber INTEGER,
      endingNumber   INTEGER
    );
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS History (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      songId     INTEGER NOT NULL REFERENCES Songs(id),
      accessedAt INTEGER NOT NULL
    );
  ''');
}

// ---------------------------------------------------------------------------
// VSB Import
// ---------------------------------------------------------------------------
Future<(int songs, int cats)> _importVsb(Database db, String filePath) async {
  // Export Categories
  final catResult = await Process.run('mdb-export', [filePath, 'Categories']);
  if (catResult.exitCode != 0) {
    print('  ERROR exporting Categories: ${catResult.stderr}');
    return (0, 0);
  }

  // Export Songs
  final songResult = await Process.run('mdb-export', [filePath, 'Songs']);
  if (songResult.exitCode != 0) {
    print('  ERROR exporting Songs: ${songResult.stderr}');
    return (0, 0);
  }

  final rawCats  = _normalizeCsv(catResult.stdout as String);
  final rawSongs = _normalizeCsv(songResult.stdout as String);

  const csv = CsvToListConverter(eol: '\n', shouldParseNumbers: false);
  final catRows  = csv.convert(rawCats);
  final songRows = csv.convert(rawSongs);

  if (catRows.length < 2 || songRows.length < 2) {
    print('  WARNING: exported tables appear empty.');
    return (0, 0);
  }

  // --- Categories --------------------------------------------------------
  final catHeader = catRows.first.map((e) => e.toString().toUpperCase()).toList();
  final catIdIdx   = catHeader.indexOf('ID');
  final catNameIdx = catHeader.indexOf('NAME');

  // Existing categories keyed by lower-case name
  final existingCats = <String, int>{};
  for (final row in db.select('SELECT id, name FROM Categories')) {
    existingCats[(row['name'] as String).toLowerCase().trim()] = row['id'] as int;
  }
  int maxCatId = (db.select('SELECT MAX(id) AS m FROM Categories').first['m'] as int?) ?? 0;

  final catIdMap = <int, int>{}; // imported id → db id

  if (catIdIdx != -1 && catNameIdx != -1) {
    for (int i = 1; i < catRows.length; i++) {
      final row = catRows[i];
      if (row.length <= catIdIdx || row.length <= catNameIdx) continue;
      final rawId = int.tryParse(row[catIdIdx].toString());
      final name  = row[catNameIdx].toString().trim();
      if (rawId == null || name.isEmpty) continue;

      final key = name.toLowerCase();
      if (existingCats.containsKey(key)) {
        catIdMap[rawId] = existingCats[key]!;
      } else {
        maxCatId++;
        catIdMap[rawId] = maxCatId;
        existingCats[key] = maxCatId;
        db.execute('INSERT OR IGNORE INTO Categories(id, name) VALUES (?, ?)', [maxCatId, name]);
      }
    }
  }

  // --- Songs -------------------------------------------------------------
  // Delete previously imported songs from this file (idempotent re-runs)
  final toDelete = db.select('SELECT id FROM Songs WHERE sourcePath = ?', [filePath]);
  for (final row in toDelete) {
    final sid = row['id'] as int;
    db.execute('DELETE FROM History WHERE songId = ?', [sid]);
  }
  db.execute('DELETE FROM Songs WHERE sourcePath = ?', [filePath]);

  final songHeader = songRows.first.map((e) => e.toString().toUpperCase()).toList();
  final songIdIdx    = songHeader.indexOf('SONGID');
  final songNumIdx   = songHeader.indexOf('SONGNUM');
  final titleIdx     = songHeader.indexOf('TITLE');
  final keyIdx       = songHeader.indexOf('KEY');
  final bodyIdx      = songHeader.indexOf('BODY');
  final modifiedIdx  = songHeader.indexOf('MODIFIED');
  final searchIdx    = songHeader.indexOf('SEARCH');
  final copyrightIdx = songHeader.indexOf('COPYRIGHT');
  final authorIdx    = songHeader.indexOf('AUTHOR');
  final catIdSongIdx = songHeader.indexOf('CATEGORYID');

  if (songNumIdx == -1 || titleIdx == -1 || bodyIdx == -1) {
    print('  ERROR: Songs CSV header is missing required columns.');
    print('  Header: $songHeader');
    return (0, 0);
  }

  final stmt = db.prepare('''
    INSERT INTO Songs
      (songNum, title, key, body, modified, search, copyright, author,
       categoryId, sourceSongId, sourcePath, sourceFormat)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');

  int inserted = 0;
  db.execute('BEGIN');
  try {
    for (int i = 1; i < songRows.length; i++) {
      final row = songRows[i];
      if (row.length <= songNumIdx || row.length <= titleIdx || row.length <= bodyIdx) continue;

      final songNum = int.tryParse(row[songNumIdx].toString()) ?? 0;
      final title   = row[titleIdx].toString().trim();
      final body    = row[bodyIdx].toString().trim();
      if (title.isEmpty || body.isEmpty) continue;

      final rawSongId  = songIdIdx != -1 ? int.tryParse(row[songIdIdx].toString()) : null;
      final keyVal     = _clean(keyIdx, row);
      final modified   = _parseMdbDate(modifiedIdx != -1 ? row[modifiedIdx]?.toString() : null);
      final search     = _clean(searchIdx, row);
      final copyright  = _clean(copyrightIdx, row);
      final author     = _clean(authorIdx, row);
      final rawCatId   = catIdSongIdx != -1 ? int.tryParse(row[catIdSongIdx].toString()) : null;
      final mappedCatId = (rawCatId != null && rawCatId != 0) ? catIdMap[rawCatId] : null;

      stmt.execute([
        songNum, title, keyVal, body,
        modified?.millisecondsSinceEpoch,
        search, copyright, author,
        mappedCatId, rawSongId, filePath, 'vsb',
      ]);
      inserted++;
    }
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    print('  ERROR during batch insert: $e');
    stmt.dispose();
    return (0, 0);
  }
  stmt.dispose();

  return (inserted, catIdMap.length);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _normalizeCsv(String raw) => raw
    .replaceAll('\r\r\n', '\n')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');

String? _clean(int idx, List<dynamic> row) {
  if (idx == -1 || idx >= row.length) return null;
  final v = row[idx]?.toString().trim();
  if (v == null || v.isEmpty || v == 'null') return null;
  return v;
}

DateTime? _parseMdbDate(String? s) {
  if (s == null || s.isEmpty || s == 'null') return null;
  try {
    final parts = s.split(' ');
    final dateParts = parts[0].split('/');
    if (dateParts.length != 3) return null;
    final month = int.parse(dateParts[0]);
    final day   = int.parse(dateParts[1]);
    int year    = int.parse(dateParts[2]);
    if (year < 70) year += 2000;
    else if (year < 100) year += 1900;
    int h = 0, m = 0, sec = 0;
    if (parts.length > 1) {
      final t = parts[1].split(':');
      if (t.length >= 2) { h = int.parse(t[0]); m = int.parse(t[1]); }
      if (t.length >= 3)   sec = int.parse(t[2]);
    }
    return DateTime(year, month, day, h, m, sec);
  } catch (_) {
    return null;
  }
}
