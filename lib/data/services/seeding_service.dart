import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/bundled_json_importer.dart';

final _log = AppLogger.get('SeedingService');

/// Key stored in SharedPreferences once the bundled songbooks have been
/// imported on first launch. Incrementing the seed version forces a re-seed
/// on the next cold start (useful when the bundled JSON is updated).
const _seedVersionKey = 'bundled_seed_version';
const _currentSeedVersion = 1;
const _defaultSourceModeKey = 'default_source_mode';

/// Pre-bundled songbooks to import on first launch.
/// Each entry: (assetPath, humanReadableBookName)
const _bundledSongbooks = [
  ('assets/songbooks/data/full_song_book.json', 'Full Song Book'),
  ('assets/songbooks/data/injili_song_book.json', 'Injili Song Book'),
];

class SeedingService {
  final AppDatabase db;

  SeedingService(this.db);

  /// Runs the first-launch seed if it has not been done yet (or if the seed
  /// version has been bumped). Safe to call on every cold start — the
  /// [_seedVersionKey] guard makes it a no-op after the first successful run.
  Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has chosen a source mode that excludes bundled songbooks
    final sourceModeStr = prefs.getString(_defaultSourceModeKey);
    if (sourceModeStr == SourceMode.linked.name) {
      _log.fine('Source mode is "linked" — skipping bundled seed.');
      return;
    }

    int seeded = prefs.getInt(_seedVersionKey) ?? 0;

    if (seeded >= _currentSeedVersion) {
      // Double-check the database actually has songs. This catches the case
      // where the DB file was recreated (e.g. after switching to a new storage
      // path) while the SharedPreferences marker still says "seeded".
      final count = await (db.select(db.songs)..where((t) => t.isActive.equals(true)))
          .get()
          .then((rows) => rows.length);
      if (count > 0) {
        _log.fine('Bundled songbooks already seeded (version $seeded). Skipping.');
        return;
      }
      _log.warning(
        'Seed marker v$seeded found but DB is empty. Re-seeding...',
      );
      // Reset the marker so the seeding logic below runs.
      seeded = 0;
    }

    _log.info('First launch — seeding bundled songbooks (seed v$_currentSeedVersion)...');

    final importer = BundledJsonImporter(db);
    int totalAdded = 0;

    for (final (assetPath, bookName) in _bundledSongbooks) {
      try {
        _log.info('Seeding "$bookName" from $assetPath...');
        final result = await importer.importFromAsset(assetPath, bookName: bookName);
        if (result.success) {
          _log.info(
            '"$bookName" seeded: ${result.songsAdded} added, '
            '${result.songsAlreadyExisted} already existed.',
          );
          totalAdded += result.songsAdded;
        } else {
          _log.warning('"$bookName" seed failed: ${result.errorMessage}');
        }
      } catch (e, st) {
        _log.severe('Unexpected error seeding "$bookName"', e, st);
      }
    }

    // Mark as seeded so this never runs again (unless seed version bumps).
    await prefs.setInt(_seedVersionKey, _currentSeedVersion);
    _log.info('Seeding complete. $totalAdded songs added in total.');
  }
}

/// Riverpod provider for [SeedingService].
final seedingServiceProvider = Provider<SeedingService>((ref) {
  // We need the AppDatabase instance — import it lazily to avoid a circular
  // dependency with app_providers.dart.
  throw UnimplementedError(
    'seedingServiceProvider must be overridden in ProviderScope overrides '
    'with an actual SeedingService instance.',
  );
});

/// FutureProvider that triggers the seed on app startup.
/// Watch this from the root widget so seeding begins immediately.
final appSeedProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(seedingServiceProvider);
  await service.seedIfNeeded();
});
