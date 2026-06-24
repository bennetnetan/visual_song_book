import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/mdb_tools_importer.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

void main() {
  test('populate database with default songbooks', () async {
    final dbPath = '/home/benjanetan/Documents/songs_db.sqlite';
    print('Opening database at: $dbPath');

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      print('Database file does not exist, creating empty file...');
      await dbFile.create(recursive: true);
    }

    final executor = NativeDatabase(dbFile);
    final database = AppDatabase.withExecutor(executor);
    final importer = MdbToolsImporter(database);

    final filesToImport = [
      'assets/songbooks/Full Song Book.vsb',
      'assets/songbooks/Injili Song Book.vsb',
    ];

    int totalSongs = 0;

    for (final filePath in filesToImport) {
      print('Importing: $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        print('Error: File $filePath does not exist!');
        continue;
      }

      final source = ImportSource.fromFile(filePath);
      expect(importer.canImport(source), isTrue);

      try {
        final result = await importer.import(source);
        if (result.success) {
          totalSongs += result.songsImported;
          print('Successfully imported $filePath: ${result.songsImported} songs, ${result.categoriesImported} categories.');
        } else {
          print('Failed to import $filePath: ${result.errorMessage}');
        }
      } catch (e) {
        print('Exception during import of $filePath: $e');
      }
    }

    // Verify songs are in DB
    final allSongs = await database.select(database.songs).get();
    print('Total songs now in database: ${allSongs.length}');

    await database.close();
    print('Database populated and closed successfully!');
  });
}
