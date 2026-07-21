import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';

void main() {
  group('normalizeSearchQuery', () {
    test('lowercases input', () {
      expect(normalizeSearchQuery('GENESIS'), 'genesis');
    });

    test('strips special characters except colons/hyphens', () {
      expect(normalizeSearchQuery('Gen. 1:1!'), 'gen 1:1');
    });

    test('collapses whitespace', () {
      expect(normalizeSearchQuery('  gen   1:1  '), 'gen 1:1');
    });

    test('preserves colons and hyphens', () {
      expect(normalizeSearchQuery('gen 1:1'), 'gen 1:1');
    });

    test('handles empty string', () {
      expect(normalizeSearchQuery(''), '');
    });

    test('handles numbers', () {
      expect(normalizeSearchQuery('1jn 5:4'), '1jn 5:4');
    });
  });

  group('parseBibleReference', () {
    test('parses simple reference "gen 1:1"', () {
      final ref = parseBibleReference('gen 1:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 1);
      expect(ref.chapter, 1);
      expect(ref.verse, 1);
    });

    test('parses full book name "genesis 1:1"', () {
      final ref = parseBibleReference('genesis 1:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 1);
      expect(ref.chapter, 1);
      expect(ref.verse, 1);
    });

    test('parses prefixed book "1jn 5:4"', () {
      final ref = parseBibleReference('1jn 5:4');
      expect(ref, isNotNull);
      expect(ref!.bookId, 62);
      expect(ref.chapter, 5);
      expect(ref.verse, 4);
    });

    test('parses "ps 23:1"', () {
      final ref = parseBibleReference('ps 23:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 19);
      expect(ref.chapter, 23);
      expect(ref.verse, 1);
    });

    test('parses "rev 2:1"', () {
      final ref = parseBibleReference('rev 2:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 66);
      expect(ref.chapter, 2);
      expect(ref.verse, 1);
    });

    test('parses "jn 3:16" (short John)', () {
      final ref = parseBibleReference('jn 3:16');
      expect(ref, isNotNull);
      expect(ref!.bookId, 43);
      expect(ref.chapter, 3);
      expect(ref.verse, 16);
    });

    test('parses "1 samuel 1:1" (spaced prefix)', () {
      final ref = parseBibleReference('1 samuel 1:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 9);
      expect(ref.chapter, 1);
      expect(ref.verse, 1);
    });

    test('parses case-insensitive "GEN 1:1"', () {
      final ref = parseBibleReference('GEN 1:1');
      expect(ref, isNotNull);
      expect(ref!.bookId, 1);
    });

    test('does not parse em-dash separator (not in regex)', () {
      expect(parseBibleReference('gen 1–1'), isNull);
    });

    test('returns null for unrecognized book', () {
      expect(parseBibleReference('xyz 1:1'), isNull);
    });

    test('returns null for plain text', () {
      expect(parseBibleReference('hello world'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseBibleReference(''), isNull);
    });

    test('returns null for partial reference', () {
      expect(parseBibleReference('gen 1'), isNull);
    });
  });
}
