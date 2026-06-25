/// Standardized map of book abbreviations (3+ chars) to book IDs.
const bibleBookIdMap = <String, int>{
  // Old Testament
  'gen': 1, 'gene': 1, 'genes': 1, 'genesis': 1,
  'exo': 2, 'exod': 2, 'exodus': 2,
  'lev': 3, 'levi': 3, 'leviticus': 3,
  'num': 4, 'numb': 4, 'numbers': 4,
  'deu': 5, 'deut': 5, 'deuteronomy': 5,
  'jos': 6, 'josh': 6, 'joshua': 6,
  'judg': 7, 'judges': 7,
  'rut': 8, 'ruth': 8,
  '1sa': 9, '1sam': 9, '1samuel': 9, '1 samuel': 9,
  '2sa': 10, '2sam': 10, '2samuel': 10, '2 samuel': 10,
  '1ki': 11, '1kin': 11, '1kings': 11, '1 kings': 11,
  '2ki': 12, '2kin': 12, '2kings': 12, '2 kings': 12,
  '1ch': 13, '1chr': 13, '1chron': 13, '1chronicles': 13, '1 chron': 13, '1 chronicles': 13,
  '2ch': 14, '2chr': 14, '2chron': 14, '2chronicles': 14, '2 chron': 14, '2 chronicles': 14,
  'ezr': 15, 'ezra': 15,
  'neh': 16, 'nehemiah': 16,
  'est': 17, 'esth': 17, 'esther': 17,
  'job': 18,
  'ps': 19, 'psa': 19, 'psalm': 19, 'psalms': 19,
  'pro': 20, 'prov': 20, 'proverbs': 20,
  'ecc': 21, 'eccl': 21, 'ecclesiastes': 21,
  'son': 22, 'song': 22, 'songofsolomon': 22, 'song of solomon': 22,
  'isa': 23, 'isai': 23, 'isaiah': 23,
  'jer': 24, 'jere': 24, 'jeremiah': 24,
  'lam': 25, 'lamentations': 25,
  'eze': 26, 'ezek': 26, 'ezekiel': 26,
  'dan': 27, 'dani': 27, 'daniel': 27,
  'hos': 28, 'hosea': 28,
  'joe': 29, 'joel': 29,
  'amo': 30, 'amos': 30,
  'oba': 31, 'obad': 31, 'obadiah': 31,
  'jon': 32, 'jonah': 32,
  'mic': 33, 'micah': 33,
  'nah': 34, 'nahum': 34,
  'hab': 35, 'habakkuk': 35,
  'zep': 36, 'zeph': 36, 'zephaniah': 36,
  'hag': 37, 'haggai': 37,
  'zec': 38, 'zech': 38, 'zechariah': 38,
  'mal': 39, 'malachi': 39,
  // New Testament
  'mat': 40, 'matt': 40, 'mth': 40, 'matthew': 40,
  'mar': 41, 'mark': 41,
  'luk': 42, 'luke': 42,
  'joh': 43, 'john': 43, 'jn': 43,
  'act': 44, 'acts': 44,
  'rom': 45, 'roma': 45, 'romans': 45,
  '1co': 46, '1cor': 46, '1corinthians': 46, '1 corinthians': 46,
  '2co': 47, '2cor': 47, '2corinthians': 47, '2 corinthians': 47,
  'gal': 48, 'galatians': 48,
  'eph': 49, 'ephesians': 49,
  'phi': 50, 'phil': 50, 'philippians': 50,
  'col': 51, 'colossians': 51,
  '1th': 52, '1the': 52, '1thes': 52, '1thess': 52, '1thessalonians': 52, '1 thessalonians': 52,
  '2th': 53, '2the': 53, '2thes': 53, '2thess': 53, '2thessalonians': 53, '2 thessalonians': 53,
  '1ti': 54, '1tim': 54, '1timothy': 54, '1 timothy': 54,
  '2ti': 55, '2tim': 55, '2timothy': 55, '2 timothy': 55,
  'tit': 56, 'titus': 56,
  'phm': 57, 'phile': 57, 'philemon': 57,
  'heb': 58, 'hebrews': 58,
  'jam': 59, 'james': 59,
  '1pe': 60, '1pet': 60, '1peter': 60, '1 peter': 60,
  '2pe': 61, '2pet': 61, '2peter': 61, '2 peter': 61,
  '1jo': 62, '1jn': 62, '1john': 62, '1 john': 62,
  '2jo': 63, '2jn': 63, '2john': 63, '2 john': 63,
  '3jo': 64, '3jn': 64, '3john': 64, '3 john': 64,
  'jude': 65,
  'rev': 66, 'revelation': 66,
};

/// Pattern matching "book chapter:verse" (e.g. "gen 1:1", "1jn 5:4", "rev 2:1").
final _bibleRefPattern = RegExp(
  r"^([1-3]?\s*[a-z]{2,})\s+(\d+)\s*[:–\-]\s*(\d+)$",
  caseSensitive: false,
);

/// Parsed Bible reference result.
class BibleRef {
  final int bookId;
  final int chapter;
  final int verse;

  const BibleRef({
    required this.bookId,
    required this.chapter,
    required this.verse,
  });
}

/// Normalize a search query: lowercase, strip non-alphanumeric/colon/hyphen/space,
/// collapse whitespace.
String normalizeSearchQuery(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9:\s\-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Try to parse a structured Bible reference from [query].
///
/// Matches patterns like "gen 1:1", "Jn 3:16", "1jn 5:4", "ps 23:1".
/// Returns a [BibleRef] if the book abbreviation is recognized, or null.
BibleRef? parseBibleReference(String query) {
  final normalized = normalizeSearchQuery(query);
  final match = _bibleRefPattern.firstMatch(normalized);
  if (match == null) return null;

  final bookPart = match.group(1)!.replaceAll(' ', '');
  final chapter = int.parse(match.group(2)!);
  final verse = int.parse(match.group(3)!);
  final bookId = bibleBookIdMap[bookPart];

  if (bookId == null) return null;
  return BibleRef(bookId: bookId, chapter: chapter, verse: verse);
}
