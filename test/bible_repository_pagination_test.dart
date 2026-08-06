import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/bible_db.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleDatabase bibleDb;
  late BibleRepository repo;

  setUpAll(() async {
    // Copies the bundled KJV asset into app storage (or reuses an existing
    // copy) — same path the app itself uses on desktop.
    bibleDb = BibleDatabase();
    await bibleDb.ensureInitialized();
    repo = BibleRepository(bibleDb);
  });

  tearDownAll(() => bibleDb.close());

  test('searchVersesPaginated respects limit and offset', () async {
    const limit = 5;

    final page1 = await repo.searchVersesPaginated('God', limit, 0);
    final page2 = await repo.searchVersesPaginated('God', limit, limit);

    expect(page1, hasLength(limit));
    expect(page2, hasLength(limit));

    // Distinct pages — offsets never overlap.
    final page1Ids = page1.map((v) => v.id).toSet();
    final page2Ids = page2.map((v) => v.id).toSet();
    expect(page1Ids.intersection(page2Ids), isEmpty);
  });

  test('results are ordered by book, chapter, verse', () async {
    final rows = await repo.searchVersesPaginated('the', 20, 0);
    expect(rows.length, 20);

    for (var i = 1; i < rows.length; i++) {
      final prev = rows[i - 1];
      final curr = rows[i];
      final isOrdered =
          curr.bookId > prev.bookId ||
          (curr.bookId == prev.bookId &&
              (curr.chapter > prev.chapter ||
                  (curr.chapter == prev.chapter && curr.verse >= prev.verse)));
      expect(isOrdered, isTrue,
          reason: 'Expected ${curr.bookId}:${curr.chapter}:${curr.verse} '
              'to come after ${prev.bookId}:${prev.chapter}:${prev.verse}');
    }
  });

  test('paginating through the full result set returns every match once',
      () async {
    const limit = 100;
    final all = <int>[];
    var offset = 0;

    while (true) {
      final page = await repo.searchVersesPaginated('Jesus', limit, offset);
      if (page.isEmpty) break;
      all.addAll(page.map((v) => v.id));
      offset += limit;
      if (all.length > 10000) break; // safety valve
    }

    expect(all, isNotEmpty);
    expect(all.toSet().length, all.length, reason: 'duplicate rows across pages');
  });

  test('empty query returns no results', () async {
    expect(await repo.searchVersesPaginated('   ', 5, 0), isEmpty);
  });
}
