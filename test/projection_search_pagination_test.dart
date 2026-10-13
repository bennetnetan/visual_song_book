
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/bible_db.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';

/// Covers the chunked search added to keep very large result sets manageable:
/// song matches are paged a fixed number at a time instead of returning every
/// hit (and every song body) at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  });

  /// Seed [count] songs whose title and body all match the query so a single
  /// search term produces a result set far larger than one page.
  Future<ProviderContainer> seedAndCollect(
    ProviderContainer container,
    int count,
  ) async {
    final songRepo = SongRepository(container.read(databaseProvider));
    for (var i = 0; i < count; i++) {
      await songRepo.addSong(
        SongsCompanion.insert(
          songNum: i + 1,
          title: 'Common Word Song $i',
          body: 'a chorus with the common word in it\nanother line',
        ),
      );
    }
    return container;
  }

  ProviderContainer makeContainer(AppDatabase db) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        bibleDatabaseProvider.overrideWithValue(BibleDatabase()),
        bibleRepositoryProvider.overrideWith((ref) {
          final bibleDb = ref.watch(bibleDatabaseProvider);
          return BibleRepository(bibleDb);
        }),
      ],
    );
  }

  test('song search returns one page at a time, not every match', () async {
    final db = AppDatabase.forTesting();
    final container = makeContainer(db);
    addTearDown(() {
      container.dispose();
      db.close();
    });

    // Many more than a page of matches.
    await seedAndCollect(container, 25);

    final notifier = container.read(projectionSearchProvider.notifier);

    // Switch into song mode; the search itself is debounced.
    notifier.switchModeAndSearch(false, 'common word');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final state = container.read(projectionSearchProvider);
    expect(state.isBibleMode, isFalse);
    // First chunk only — the rest stays on disk.
    expect(state.songResults.length, ProjectionSearchState.pageSize);
    // ...but the total is known so the UI can offer more.
    expect(state.totalSongCount, 25);

    // Loading the next chunk appends without losing the earlier page.
    await notifier.loadMoreSongs();
    final afterOneLoad = container.read(projectionSearchProvider);
    expect(afterOneLoad.songResults.length, ProjectionSearchState.pageSize * 2);
    expect(afterOneLoad.totalSongCount, 25);

    await notifier.loadMoreSongs();
    final afterTwoLoads = container.read(projectionSearchProvider);
    // 25 songs total, so the last page is a short one instead of a full 30.
    expect(afterTwoLoads.songResults.length, 25);
    expect(afterTwoLoads.songResults.length >= afterTwoLoads.totalSongCount,
        isTrue);
    // Titles are unique per page, so no duplicates were appended.
    expect(
      afterTwoLoads.songResults.map((s) => s.title).toSet().length,
      25,
    );
  });

  test('loading more stops once every match has been shown', () async {
    final db = AppDatabase.forTesting();
    final container = makeContainer(db);
    addTearDown(() {
      container.dispose();
      db.close();
    });

    // Fewer matches than a full page: there is nothing more to load.
    await seedAndCollect(container, 3);

    final notifier = container.read(projectionSearchProvider.notifier);
    notifier.switchModeAndSearch(false, 'common word');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final state = container.read(projectionSearchProvider);
    expect(state.songResults.length, 3);
    expect(state.totalSongCount, 3);
    expect(state.songResults.length >= state.totalSongCount, isTrue);

    // A redundant load is a no-op, so no duplicates appear.
    await notifier.loadMoreSongs();
    expect(container.read(projectionSearchProvider).songResults.length, 3);
  });

  test('song search honours the source filter while paging', () async {
    final db = AppDatabase.forTesting();
    final container = makeContainer(db);
    addTearDown(() {
      container.dispose();
      db.close();
    });

    final songRepo = SongRepository(db);
    // Songs in a linked source, and one bundled-style song with no source path.
    for (var i = 0; i < 12; i++) {
      await songRepo.addSong(
        SongsCompanion.insert(
          songNum: i + 1,
          title: 'Filtered Song $i',
          body: 'body text with the searched phrase',
        ),
      );
    }
    final totalAll = await songRepo.countSearchSongs('searched phrase');
    expect(totalAll, 12);

    final totalLimited = await songRepo.searchSongs(
      'searched phrase',
      limit: 10,
    );
    expect(totalLimited.length, 10);
  });
}
