import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/utils/search_pattern.dart';
import 'package:visual_song_book/data/db/songbook_db.dart' show AppDatabase, Song, SongsCompanion;
import 'package:visual_song_book/data/repositories/song_repository.dart';

/// Covers the wildcard searching added to the projection search.
///
/// `*` matches any run of characters and `?` exactly one, which is what people
/// expect from a file dialog or a search engine. Any `%`, `_` or `\` the user
/// types must match literally rather than act as a wildcard, otherwise a song
/// title containing an underscore would behave surprising.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  });

  group('buildWildcardLikePattern', () {
    test('* becomes a run-of-characters wildcard', () {
      expect(buildWildcardLikePattern('amaz*'), 'amaz%');
      expect(buildWildcardLikePattern('*'), '%');
    });

    test('? becomes a single-character wildcard', () {
      expect(buildWildcardLikePattern('gr?ce'), 'gr_ce');
      expect(buildWildcardLikePattern('???'), '___');
    });

    test('literal % and _ are escaped so they match as themselves', () {
      expect(buildWildcardLikePattern('100%'), r'100\%');
      expect(buildWildcardLikePattern('a_b'), r'a\_b');
      expect(buildWildcardLikePattern('back\\slash'), r'back\\slash');
    });

    test('plain text passes through untouched', () {
      expect(buildWildcardLikePattern('Amazing Grace'), 'Amazing Grace');
    });

    test('mixed wildcards and literals compose', () {
      expect(buildWildcardLikePattern('amaz*grac_e?'), r'amaz%grac\_e_');
    });
  });

  group('song search', () {
    test('* matches a run of characters and ? exactly one', () async {
      final db = AppDatabase.forTesting();
      final repo = SongRepository(db);
      // Three lengths make the "exactly one character" rule observable:
      // Grac has nothing after, Grace has one, Gracious has more.
      for (final title in ['Grac', 'Grace', 'Gracious']) {
        await repo.addSong(SongsCompanion.insert(
          songNum: title.length,
          title: title,
          body: 'body of $title',
        ));
      }

      Future<Iterable<String>> titles(Future<List<Song>> f) async =>
          (await f).map((s) => s.title);

      // Prefix wildcard: everything starting with Grac.
      expect(await titles(repo.searchSongs('Grac*')),
          unorderedEquals(['Grac', 'Grace', 'Gracious']));

      // Suffix wildcard: ends in "ce".
      expect(await titles(repo.searchSongs('*ce')), ['Grace'],
          reason: 'Gracious does not end in ce');

      // ? requires exactly one character, so 'Grac' (nothing after) is out.
      expect(await titles(repo.searchSongs('Grac?')),
          unorderedEquals(['Grace', 'Gracious']),
          reason: 'Grac has no character for ? to match');

      // Two ? requires at least two characters after Grac, which excludes Grace.
      expect(await titles(repo.searchSongs('Grac??')), ['Gracious']);

      await db.close();
    });

    test('a literal underscore is not a wildcard', () async {
      final db = AppDatabase.forTesting();
      final repo = SongRepository(db);
      await repo.addSong(SongsCompanion.insert(
        songNum: 10,
        title: 'Lord_Almighty',
        body: 'Lyrics',
      ));
      await repo.addSong(SongsCompanion.insert(
        songNum: 11,
        title: 'LordXAlmighty',
        body: 'Lyrics',
      ));

      // Without escaping, _ would also match LordXAlmighty.
      final exactUnderscore = await repo.searchSongs('Lord_Almighty');
      expect(exactUnderscore.length, 1);
      expect(exactUnderscore.first.title, 'Lord_Almighty');

      // ? is the way to match any single character there.
      final anySingle = await repo.searchSongs('Lord?Almighty');
      expect(anySingle.map((s) => s.title),
          unorderedEquals(['Lord_Almighty', 'LordXAlmighty']));

      await db.close();
    });

    test('count and results agree when a wildcard is used', () async {
      final db = AppDatabase.forTesting();
      final repo = SongRepository(db);
      for (var i = 0; i < 6; i++) {
        await repo.addSong(SongsCompanion.insert(
          songNum: i + 1,
          title: 'Verse Song $i',
          body: 'body $i',
        ));
      }
      await repo.addSong(SongsCompanion.insert(
        songNum: 99,
        title: 'Unrelated',
        body: 'other',
      ));

      const q = 'Verse *';
      final total = await repo.countSearchSongs(q);
      final page = await repo.searchSongs(q, limit: 2);
      expect(total, 6, reason: '6 of the 7 songs match');
      expect(page.length, 2);

      // Same query without a wildcard must not over-match.
      expect(await repo.countSearchSongs('Verse Song'), 6);

      await db.close();
    });
  });

  group('bible search', () {
    // BibleDatabase only reads a bundled file, so the generated SQL is checked
    // against a real sqlite table instead. This is the same statement the
    // repository runs, and proves the pattern plus ESCAPE clause behave.
    test('wildcards work in the verse LIKE query', () async {
      final db = sqlite3.sqlite3.openInMemory();
      addTearDown(db.dispose);

      db.execute('CREATE TABLE books (id INTEGER PRIMARY KEY, name TEXT)');
      db.execute('CREATE TABLE verses (id INTEGER PRIMARY KEY, book_id INTEGER, chapter INTEGER, verse INTEGER, text TEXT)');
      db.execute("INSERT INTO books VALUES (1, 'John')");
      // Three lengths so ? and ?? are distinguishable: a space is a character
      // too, so padding text would make the counts ambiguous.
      db.execute("INSERT INTO verses VALUES (1, 1, 1, 1, 'grac')");
      db.execute("INSERT INTO verses VALUES (2, 1, 1, 2, 'grace')");
      db.execute("INSERT INTO verses VALUES (3, 1, 1, 3, 'gracious')");
      db.execute("INSERT INTO verses VALUES (4, 1, 1, 4, 'uneven 50% markup')");
      db.execute("INSERT INTO verses VALUES (5, 1, 1, 5, 'markup rose to 50 coins')");

      String search(String q) {
        final pattern = '%${buildWildcardLikePattern(q)}%';
        final rows = db.select(
          'SELECT v.text FROM verses v JOIN books b ON b.id = v.book_id '
          "WHERE v.text LIKE ? ESCAPE '$likeEscapeChar' "
          'ORDER BY v.book_id, v.chapter, v.verse',
          [pattern],
        );
        return rows.map((r) => (r['text'] as String)).join(' | ');
      }

      // * matches any run, including an empty one.
      expect(search('grac*'), 'grac | grace | gracious');

      // ? needs exactly one character, so the bare "grac" row is excluded.
      expect(search('grac?'), 'grace | gracious');

      // ?? needs two, leaving only "gracious".
      expect(search('grac??'), 'gracious');

      // A literal % typed by the user matches that character rather than
      // behaving as a wildcard.
      expect(search('50%'), 'uneven 50% markup');

      // Contrast with the unescaped form: with % acting as a wildcard, "50%"
      // also matches the row that has no percent sign in it at all. That is
      // the bug the escaping prevents.
      final unescaped = db.select(
        'SELECT COUNT(*) as c FROM verses WHERE text LIKE ?',
        ['%50%%'],
      );
      expect(unescaped.first['c'] as int,
          2, reason: 'both rows containing "50", escaped or not');
      expect(search('50%').contains('coins'), isFalse);

      await Future<void>.value();
    });
  });
}
