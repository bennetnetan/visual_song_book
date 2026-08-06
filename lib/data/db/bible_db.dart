import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/sqlite3.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/services/app_storage.dart';

final _log = AppLogger.get('BibleDatabase');

class _BibleQueryRequest {
  final String path;
  final String sql;
  final List<Object?> params;

  _BibleQueryRequest(this.path, this.sql, this.params);
}

List<Map<String, dynamic>> _runReadonlyQuery(_BibleQueryRequest request) {
  final db = sqlite3.open(request.path, mode: OpenMode.readOnly);
  try {
    final resultSet = db.select(request.sql, request.params);
    final columns = resultSet.columnNames;
    final result = <Map<String, dynamic>>[];
    for (final Row row in resultSet) {
      final map = <String, dynamic>{};
      for (var i = 0; i < columns.length; i++) {
        // ignore: collection_methods_unrelated_type
        map[columns[i]] = row[i];
      }
      result.add(map);
    }
    return result;
  } finally {
    db.dispose();
  }
}

class BibleDatabase {
  Database? _db;
  String? _dbPath;

  Future<void> ensureInitialized() async {
    if (_db != null) return;

    final dbPath = await getAppStorageFilePath('kjv_bible.sqlite');
    _dbPath = dbPath;

    final file = File(dbPath);
    bool shouldCopy = false;
    if (!await file.exists()) {
      shouldCopy = true;
    } else {
      try {
        final tempDb = sqlite3.open(dbPath);
        final tables = tempDb.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cross_references'",
        );
        tempDb.dispose();
        if (tables.isEmpty) {
          shouldCopy = true;
        }
      } catch (e, st) {
        _log.warning('Failed to validate existing Bible DB, re-copying: $e', e, st);
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      _log.info('Copying bundled KJV Bible database to app storage...');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e, st) {
          _log.warning('Failed to delete stale Bible DB before re-copy: $e', e, st);
        }
      }
      final data = await rootBundle.load('assets/databases/kjv_bible.sqlite');
      await file.writeAsBytes(data.buffer.asUint8List());
      _log.info('Bible database copy complete.');
    }

    _db = sqlite3.open(dbPath);
    try {
      final legacy = _db!.select(
        "SELECT COUNT(*) FROM books WHERE name LIKE 'Revelation%' AND name != 'Revelation'",
      );
      if ((legacy.first.values.first as int) > 0) {
        _db!.execute(
          "UPDATE books SET name = 'Revelation' WHERE name LIKE 'Revelation%'",
        );
        _log.info('Migrated legacy "Revelation of John" book name in place.');
      }
    } catch (e, st) {
      _log.fine('Legacy Revelation name check skipped: $e', e, st);
    }
  }

  Database get db {
    if (_db == null) {
      throw StateError(
        'BibleDatabase not initialized. Call ensureInitialized() first.',
      );
    }
    return _db!;
  }

  List<Map<String, dynamic>> query(
    String sql, [
    List<Object?> params = const [],
  ]) {
    final resultSet = db.select(sql, params);
    final columns = resultSet.columnNames;
    final result = <Map<String, dynamic>>[];
    for (final Row row in resultSet) {
      final map = <String, dynamic>{};
      for (var i = 0; i < columns.length; i++) {
        // ignore: collection_methods_unrelated_type
        map[columns[i]] = row[i];
      }
      result.add(map);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> queryAsync(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    await ensureInitialized();
    final path = _dbPath;
    if (path == null) {
      return query(sql, params);
    }
    // Run the query on a background isolate using a fresh read-only
    // connection so LIKE scans across 31k verses don't jank the UI thread.
    return compute(_runReadonlyQuery, _BibleQueryRequest(path, sql, params));
  }

  void close() {
    _db?.dispose();
    _db = null;
    _dbPath = null;
  }
}
