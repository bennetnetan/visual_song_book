import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/repositories/backup_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    },
  );

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vsbook_roundtrip');
    dbPath = '${tempDir.path}/songs.db';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('.vsbook export → import round-trip preserves modified and is_active',
      () async {
    final originalModified = DateTime(2024, 5, 6, 7, 8, 9);

    // 1. Seed a file-backed database at a known path.
    final srcDb = AppDatabase.withExecutor(NativeDatabase(File(dbPath)));
    await srcDb.songs.insertOne(
      SongsCompanion.insert(
        songNum: 1,
        title: 'Round Trip Song',
        body: 'V1\nIntro',
        modified: drift.Value(originalModified),
        isActive: const drift.Value(false),
      ),
    );
    await srcDb.songs.insertOne(
      SongsCompanion.insert(songNum: 2, title: 'Active Song', body: 'V1'),
    );
    await srcDb.close();

    // 2. Export a .vsbook backup through the real BackupRepository.
    final backupPath = '${tempDir.path}/songbook_backup.vsbook';
    await BackupRepository().exportBackup(backupPath, databasePath: dbPath);
    final backupBytes = File(backupPath).readAsBytesSync();

    // 3. Import it into a fresh in-memory database.
    final dstDb = AppDatabase.forTesting();
    try {
      final importer = VsBookImporter(dstDb);
      final result = await importer.import(ImportSource.fromBytes(backupBytes));
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.songsImported, 2);

      final songs = await dstDb.select(dstDb.songs).get();
      expect(songs.length, 2);

      final restored = songs.singleWhere((s) => s.songNum == 1);
      expect(restored.title, 'Round Trip Song');
      // Drift stores DateTime as unix-seconds INTEGER; the importer's int
      // path converts it back, so the timestamp survives the round-trip.
      expect(restored.modified, originalModified);
      expect(restored.isActive, isFalse);

      final active = songs.singleWhere((s) => s.songNum == 2);
      expect(active.isActive, isTrue);
    } finally {
      await dstDb.close();
    }
  });
}
