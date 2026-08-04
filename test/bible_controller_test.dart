import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/data/db/bible_db.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class FakeBibleRepository extends BibleRepository {
  FakeBibleRepository() : super(BibleDatabase());

  static final books = [
    BibleBook(id: 1, name: 'Genesis'),
    BibleBook(id: 2, name: 'Exodus'),
  ];

  static BibleVerse buildVerse(int id, int bookId, int chapter, int verse) =>
      BibleVerse(
        id: id,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        text: 'Verse text $id',
        bookName: bookId == 1 ? 'Genesis' : 'Exodus',
      );

  @override
  Future<List<BibleBook>> getBooks() async => books;

  @override
  Future<List<int>> getChapters(int bookId) async => [1, 2];

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter) async => [
        buildVerse(1, bookId, chapter, 1),
        buildVerse(2, bookId, chapter, 2),
      ];

  @override
  Future<Map<int, int>> getChapterVerseCounts(int bookId) async =>
      {1: 2, 2: 2};

  @override
  Future<List<BibleCrossReference>> getCrossReferences(
    int bookId,
    int chapter,
    int verse,
  ) async =>
      [];

  @override
  Future<BibleVerse?> getVerseByRef(int bookId, int chapter, int verse) async =>
      buildVerse(1, bookId, chapter, verse);
}

class FakeSetRepository extends SetRepository {
  FakeSetRepository(super.db);

  @override
  Future<Set<int>> getBookmarkedVerseIdsForChapter(int bookId, int chapter) async =>
      {};
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  test('persists lastRead on chapter selection', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = BibleController(FakeBibleRepository(), FakeSetRepository(db));
    await settle();
    await settle();

    // No saved reading yet → boots into Genesis 1:1 and records it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('bible_last_read_book'), 1);
    expect(prefs.getInt('bible_last_read_chapter'), 1);

    await controller.selectChapter(2);
    expect(prefs.getInt('bible_last_read_book'), 1);
    expect(prefs.getInt('bible_last_read_chapter'), 2);
    expect(controller.state.lastReadBookId, 1);
    expect(controller.state.lastReadChapter, 2);

    controller.dispose();
  });

  test('hydrates lastRead on launch and keeps reader empty for Continue card',
      () async {
    SharedPreferences.setMockInitialValues({
      'bible_last_read_book': 2,
      'bible_last_read_chapter': 5,
      'bible_last_read_verse': 3,
    });
    final controller = BibleController(FakeBibleRepository(), FakeSetRepository(db));
    await settle();
    await settle();

    final state = controller.state;
    expect(state.lastReadBookId, 2);
    expect(state.lastReadChapter, 5);
    expect(state.lastReadVerse, 3);
    // With a saved reading we show the empty "Continue Reading" view instead
    // of auto-jumping straight into a chapter.
    expect(state.selectedBookId, isNull);

    controller.dispose();
  });
}
