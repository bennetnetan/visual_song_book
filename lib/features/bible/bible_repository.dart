import 'package:visual_song_book/data/db/bible_db.dart';

class BibleBook {
  final int id;
  final String name;
  BibleBook({required this.id, required this.name});
}

class BibleVerse {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String? bookName;

  BibleVerse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.bookName,
  });

  String get reference => '$bookName $chapter:$verse';
}

class BibleCrossReference {
  final int id;
  final int toBookId;
  final int toChapter;
  final int toVerseStart;
  final int toVerseEnd;
  final int votes;
  final String targetBookName;
  final String targetText;

  BibleCrossReference({
    required this.id,
    required this.toBookId,
    required this.toChapter,
    required this.toVerseStart,
    required this.toVerseEnd,
    required this.votes,
    required this.targetBookName,
    required this.targetText,
  });

  String get reference {
    if (toVerseStart == toVerseEnd) {
      return '$targetBookName $toChapter:$toVerseStart';
    } else {
      return '$targetBookName $toChapter:$toVerseStart-$toVerseEnd';
    }
  }
}

class BibleRepository {
  final BibleDatabase _db;

  BibleRepository(this._db);

  Future<List<BibleBook>> getBooks() async {
    final rows = await _db.queryAsync('SELECT id, name FROM books ORDER BY id');
    return rows
        .map((r) => BibleBook(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  Future<List<int>> getChapters(int bookId) async {
    final rows = await _db.queryAsync(
      'SELECT DISTINCT chapter FROM verses WHERE book_id = ? ORDER BY chapter',
      [bookId],
    );
    return rows.map((r) => r['chapter'] as int).toList();
  }

  Future<List<BibleVerse>> getVerses(int bookId, int chapter) async {
    final rows = await _db.queryAsync(
      '''
      SELECT v.id, v.book_id, v.chapter, v.verse, v.text, b.name as book_name
      FROM verses v
      JOIN books b ON b.id = v.book_id
      WHERE v.book_id = ? AND v.chapter = ?
      ORDER BY v.verse
    ''',
      [bookId, chapter],
    );
    return rows
        .map(
          (r) => BibleVerse(
            id: r['id'] as int,
            bookId: r['book_id'] as int,
            chapter: r['chapter'] as int,
            verse: r['verse'] as int,
            text: r['text'] as String,
            bookName: r['book_name'] as String,
          ),
        )
        .toList();
  }

  Future<List<BibleVerse>> searchVerses(String query) async {
    if (query.trim().isEmpty) return [];
    final like = '%${query.trim()}%';
    final rows = await _db.queryAsync(
      '''
      SELECT v.id, v.book_id, v.chapter, v.verse, v.text, b.name as book_name
      FROM verses v
      JOIN books b ON b.id = v.book_id
      WHERE v.text LIKE ?
      ORDER BY v.book_id, v.chapter, v.verse
      LIMIT 50
    ''',
      [like],
    );
    return rows
        .map(
          (r) => BibleVerse(
            id: r['id'] as int,
            bookId: r['book_id'] as int,
            chapter: r['chapter'] as int,
            verse: r['verse'] as int,
            text: r['text'] as String,
            bookName: r['book_name'] as String,
          ),
        )
        .toList();
  }

  Future<BibleVerse?> getVerseByRef(int bookId, int chapter, int verse) async {
    final rows = await _db.queryAsync(
      '''
      SELECT v.id, v.book_id, v.chapter, v.verse, v.text, b.name as book_name
      FROM verses v
      JOIN books b ON b.id = v.book_id
      WHERE v.book_id = ? AND v.chapter = ? AND v.verse = ?
    ''',
      [bookId, chapter, verse],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return BibleVerse(
      id: r['id'] as int,
      bookId: r['book_id'] as int,
      chapter: r['chapter'] as int,
      verse: r['verse'] as int,
      text: r['text'] as String,
      bookName: r['book_name'] as String,
    );
  }

  Future<List<BibleCrossReference>> getCrossReferences(
    int bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await _db.queryAsync(
      '''
      SELECT cr.id, cr.to_book_id, cr.to_chapter, cr.to_verse_start, cr.to_verse_end, cr.votes,
             b.name as target_book_name,
             GROUP_CONCAT(v.text, ' ') as target_text
      FROM cross_references cr
      LEFT JOIN books b ON b.id = cr.to_book_id
      LEFT JOIN verses v ON v.book_id = cr.to_book_id AND v.chapter = cr.to_chapter AND v.verse >= cr.to_verse_start AND v.verse <= cr.to_verse_end
      WHERE cr.from_book_id = ? AND cr.from_chapter = ? AND cr.from_verse = ?
      GROUP BY cr.id
      ORDER BY cr.votes DESC
      LIMIT 15
      ''',
      [bookId, chapter, verse],
    );
    return rows
        .map(
          (r) => BibleCrossReference(
            id: r['id'] as int,
            toBookId: r['to_book_id'] as int,
            toChapter: r['to_chapter'] as int,
            toVerseStart: r['to_verse_start'] as int,
            toVerseEnd: r['to_verse_end'] as int,
            votes: r['votes'] as int,
            targetBookName: r['target_book_name'] as String? ?? '',
            targetText: r['target_text'] as String? ?? '',
          ),
        )
        .toList();
  }
}
