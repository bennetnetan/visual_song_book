// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/mdb_tools_importer.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';

void main() {
  // Skip the entire group on platforms without the mdbtools CLI.
  // Using a group-level skip stops the test body from executing (not just
  // marks it skipped), which prevents `expect` calls inside from failing
  // on Windows where `MdbToolsImporter.canImport` always returns false.
  final isMdbPlatform = Platform.isLinux || Platform.isMacOS;

  group(
    'MdbToolsImporter',
    skip: isMdbPlatform
        ? null
        : 'mdbtools CLI is only available on Linux/macOS',
    () {
      test('populate in-memory database with default songbooks', () async {
        // Hermetic: no ~/Documents or other user-directory writes. The importer
        // only writes through the drift executor, so an in-memory DB is enough.
        final database = AppDatabase.forTesting();
        addTearDown(database.close);
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

          final result = await importer.import(source);
          if (result.success) {
            totalSongs += result.songsImported;
            print(
              'Successfully imported $filePath: '
              '${result.songsImported} songs, '
              '${result.categoriesImported} categories.',
            );
          } else {
            print('Failed to import $filePath: ${result.errorMessage}');
          }
        }

        // Verify songs are in DB
        final allSongs = await database.select(database.songs).get();
        print(
          'Total songs now in database: ${allSongs.length} '
          '(Imported this session: $totalSongs)',
        );
        expect(allSongs, isNotEmpty);
      });
    },
  );
}
