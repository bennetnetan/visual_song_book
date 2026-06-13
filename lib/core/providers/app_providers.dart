import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/mdb_tools_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/repositories/backup_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

// Database Provider (hot-swappable when restoring backups)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Song Repository Provider
final songRepositoryProvider = Provider<SongRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SongRepository(db);
});

// Backup Repository Provider
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository();
});

// List of available importers
final importersProvider = Provider<List<SongbookImporter>>((ref) {
  final db = ref.watch(databaseProvider);
  return [
    MdbToolsImporter(db),
    VsBookImporter(db),
  ];
});
