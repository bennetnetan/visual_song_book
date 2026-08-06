import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'projection_keep_awake': false,
      'projection_auto_chorus': false,
      'projection_mode': 'extended',
      'projection_font_size': 40.0,
    });
  });

  test('projectSongSet builds slides across songs and records set history',
      () async {
    final db = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() {
      container.dispose();
      db.close();
    });

    final songRepo = SongRepository(db);
    final setRepo = SetRepository(db);

    final songA = await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 1,
        title: 'Song A',
        body: 'First line of A\nSecond line of A',
      ),
    );
    final songB = await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 2,
        title: 'Song B',
        body: 'CHORUS\nChorus line of B\n\nVerse one of B',
      ),
    );

    final set = await setRepo.createSet('Set One');
    await setRepo.addSongToSet(set.id, songA, 0);
    await setRepo.addSongToSet(set.id, songB, 1);
    final items = await setRepo.getSetItems(set.id);
    expect(items.length, 2);

    final controller = container.read(projectionControllerProvider.notifier);
    await controller.projectSongSet(set.id, 'Set One', items);

    // Slides from both songs are concatenated into one projection.
    expect(controller.state.slides, isNotEmpty);
    expect(controller.state.slides.length, greaterThanOrEqualTo(3));
    expect(controller.state.slides.first.text, contains('First line of A'));
    expect(controller.state.isBibleMode, isFalse);
    expect(controller.state.currentSong, isNull);
    expect(controller.state.contentTitle, 'Set One');
    expect(controller.state.currentSlideIndex, 0);

    // Set projection is recorded in set history.
    final history = await setRepo.getSetHistory();
    expect(history.map((h) => h.setId), contains(set.id));
    expect(history.map((h) => h.setName), contains('Set One'));
  });

  test('projectSongSet with empty items is a no-op', () async {
    final db = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() {
      container.dispose();
      db.close();
    });

    final controller = container.read(projectionControllerProvider.notifier);
    await controller.projectSongSet(999, 'Empty Set', []);

    expect(controller.state.slides, isEmpty);
  });

  test('setSong parses verses into slides and records song history', () async {
    final db = AppDatabase.forTesting();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() {
      container.dispose();
      db.close();
    });

    final songRepo = SongRepository(db);
    final songId = await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 7,
        title: 'Hymn',
        body: 'CHORUS\nOnly believe\n\nPraise be to God on high',
      ),
    );
    final song = await songRepo.getSongById(songId);
    expect(song, isNotNull);

    final controller = container.read(projectionControllerProvider.notifier);
    controller.setSong(song!);

    await settle();
    // C, V2, then a trailing auto-inserted chorus.
    expect(controller.state.slides.length, 3);
    expect(controller.state.slides[0].text, 'Only believe');
    expect(controller.state.slides[0].label, 'C');
    expect(controller.state.slides[1].text, 'Praise be to God on high');
    expect(controller.state.slides[1].label, 'V1');
    expect(controller.state.slides[2].text, 'Only believe');
    expect(controller.state.slides[2].label, 'C');
    expect(controller.state.currentSong?.id, songId);
    expect(controller.state.isBibleMode, isFalse);

    final history = await db.select(db.history).get();
    expect(history.map((h) => h.songId), contains(songId));
  });
}
