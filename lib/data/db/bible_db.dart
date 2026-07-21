import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/sqlite3.dart';
import 'package:visual_song_book/data/services/app_storage.dart';

class BibleDatabase {
  Database? _db;

  Future<void> ensureInitialized() async {
    if (_db != null) return;

    final dbPath = await getAppStorageFilePath('kjv_bible.sqlite');

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
      } catch (e) {
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final data = await rootBundle.load('assets/databases/kjv_bible.sqlite');
      await file.writeAsBytes(data.buffer.asUint8List());
    }

    _db = sqlite3.open(dbPath);
    try {
      _db!.execute("UPDATE books SET name = 'Revelation' WHERE name LIKE 'Revelation%'");
    } catch (_) {}
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
    return resultSet.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < columns.length; i++) {
        map[columns[i]] = row[i];
      }
      return map;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> queryAsync(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    await ensureInitialized();
    return query(sql, params);
  }

  void close() {
    _db?.dispose();
    _db = null;
  }
}
