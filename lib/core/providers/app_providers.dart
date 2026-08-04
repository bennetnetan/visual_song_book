import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/data/db/bible_db.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/mdb_tools_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/repositories/backup_repository.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

// Re-export so app only needs to import app_providers.dart for seeding.
export 'package:visual_song_book/data/services/seeding_service.dart'
    show seedingServiceProvider, appSeedProvider, SeedingService;

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

// Set Repository Provider
final setRepositoryProvider = Provider<SetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SetRepository(db);
});

// Bible Database Provider (singleton, read-only)
final bibleDatabaseProvider = Provider<BibleDatabase>((ref) {
  final db = BibleDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Bible Repository Provider
final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  final db = ref.watch(bibleDatabaseProvider);
  return BibleRepository(db);
});

// Backup Repository Provider
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository();
});

// Active dashboard tab provider
final activeDashboardTabProvider = StateProvider<int>((ref) => 0);

// List of available importers
final importersProvider = Provider<List<SongbookImporter>>((ref) {
  final db = ref.watch(databaseProvider);
  return [MdbToolsImporter(db), VsBookImporter(db)];
});

// Provider to identify if the current process is the secondary projection window
final isProjectionWindowProvider = Provider<bool>((ref) => false);

// Projection window placement mode passed from the main window at creation time:
// 'extended' (default) = place on a second display and go fullscreen;
// 'single' = normal decorated window on the primary display, no auto-move.
final projectionWindowModeProvider = Provider<String>((ref) => 'extended');

// Onboarding state — true when the user has completed the first-launch wizard
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});
