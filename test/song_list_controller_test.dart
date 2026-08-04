import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<bool> waitFor(bool Function() predicate,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return predicate();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SongRepository repo;
  late SongListController controller;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = SongRepository(db);
    controller = SongListController(repo);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('selectCategory filters songs; deleteCategory reassigns them to uncategorized',
      () async {
    final catId = await repo.addCategory(
      CategoriesCompanion.insert(id: const drift.Value(1), name: 'Youth'),
    );
    await repo.addSong(
      SongsCompanion.insert(
        songNum: 1,
        title: 'Song A',
        body: 'lyrics',
        categoryId: drift.Value(catId),
      ),
    );
    await repo.addSong(
      SongsCompanion.insert(songNum: 2, title: 'Song B', body: 'lyrics'),
    );
    await settle();
    await settle();

    // Both songs visible under "All".
    expect(controller.state.songs.length, 2);

    // Filter by category → only the assigned song shows.
    controller.selectCategory(catId);
    final filtered = await waitFor(
      () => controller.state.selectedCategoryId == catId &&
          controller.state.songs.length == 1,
    );
    expect(filtered, isTrue);
    expect(controller.state.songs.single.title, 'Song A');

    // Delete category → song moved to Uncategorized, view back to All.
    await controller.deleteCategory(catId);
    final reset = await waitFor(
      () =>
          controller.state.selectedCategoryId == -2 &&
          controller.state.songs.length == 2,
    );
    expect(reset, isTrue);

    final allSongs = await repo.getSongs();
    expect(allSongs.every((s) => s.categoryId == null), isTrue);
  });

  test('deleteCategory keeps uncategorized songs untouched', () async {
    final catId = await repo.addCategory(
      CategoriesCompanion.insert(id: const drift.Value(2), name: 'Choir'),
    );
    await repo.addSong(
      SongsCompanion.insert(
        songNum: 10,
        title: 'Keep Me',
        body: 'lyrics',
        categoryId: drift.Value(catId),
      ),
    );
    await settle();
    await settle();

    await controller.deleteCategory(catId);
    await settle();
    await settle();

    final allSongs = await repo.getSongs();
    expect(allSongs.length, 1);
    expect(allSongs.single.title, 'Keep Me');
    expect(allSongs.single.categoryId, isNull);

    final categories = await repo.getCategories();
    expect(categories, isEmpty);
  });
}
