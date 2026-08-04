import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/bible_db.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';

class FakeBibleRepository extends BibleRepository {
  FakeBibleRepository() : super(BibleDatabase());

  static final List<BibleVerse> allVerses = List.generate(
    12,
    (i) => BibleVerse(
      id: i + 1,
      bookId: 1,
      chapter: 1,
      verse: i + 1,
      text: 'verse ${i + 1}',
      bookName: 'Genesis',
    ),
  );

  @override
  Future<BibleVerse?> getVerseByRef(int bookId, int chapter, int verse) async =>
      null;

  @override
  Future<int> countSearchResults(String query) async => allVerses.length;

  @override
  Future<List<BibleVerse>> searchVersesPaginated(
    String query,
    int limit,
    int offset,
  ) async {
    final start = offset.clamp(0, allVerses.length);
    final end = (offset + limit).clamp(0, allVerses.length);
    return allVerses.sublist(start, end);
  }
}

class FakeSongRepository extends SongRepository {
  FakeSongRepository(super.db);

  @override
  Future<List<Song>> searchSongs(
    String query, {
    String? sourcePath,
  }) async =>
      const [];
}

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
  late ProjectionSearchController controller;

  setUp(() {
    db = AppDatabase.forTesting();
    controller = ProjectionSearchController(
      FakeBibleRepository(),
      FakeSongRepository(db),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('bible search loads first page then loadMoreBible appends the rest',
      () async {
    controller.search('love');

    final firstPage = await waitFor(
      () =>
          controller.state.bibleResults.length == 10 &&
          controller.state.totalBibleCount == 12 &&
          controller.state.bibleOffset == 10 &&
          !controller.state.isLoading,
    );
    expect(firstPage, isTrue);

    await controller.loadMoreBible();

    final allLoaded = await waitFor(
      () =>
          controller.state.bibleResults.length == 12 &&
          controller.state.bibleOffset == 12 &&
          !controller.state.isLoading,
    );
    expect(allLoaded, isTrue);
    expect(controller.state.bibleResults.last.text, 'verse 12');
  });

  test('loadMoreBible is a no-op when results already cover the total',
      () async {
    controller.switchModeAndSearch(true, 'love');

    final firstPage = await waitFor(
      () => controller.state.bibleResults.length == 10,
    );
    expect(firstPage, isTrue);

    // Offset 10 of 12 → two more loadable. Load once fully, then second
    // call should fetch nothing (offset == total).
    await controller.loadMoreBible();
    final done = await waitFor(
      () => controller.state.bibleOffset == 12,
    );
    expect(done, isTrue);

    final before = controller.state.bibleResults.length;
    await controller.loadMoreBible();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state.bibleResults.length, before);
  });
}
