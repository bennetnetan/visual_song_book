import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/core/utils/verse_parser.dart';

void main() {
  group('VerseParser Tests', () {
    test('Parse empty body returns empty list', () {
      final result = VerseParser.parse('');
      expect(result, isEmpty);
    });

    test('Parse single verse without chorus', () {
      const body = 'This is line 1\nThis is line 2';
      final result = VerseParser.parse(body);

      expect(result, hasLength(1));
      expect(result[0].label, 'V1');
      expect(result[0].text, 'This is line 1\nThis is line 2');
      expect(result[0].isChorus, isFalse);
    });

    test('Parse multiple verses and chorus', () {
      const body = '''
Fear not, little flock,
from the cross to the throne.

CHORUS
Only believe, only believe,
All things are possible.

Fear not, little flock,
He goeth ahead.
''';

      final result = VerseParser.parse(body);

      expect(result, hasLength(3));
      
      // Verse 1
      expect(result[0].label, 'V1');
      expect(result[0].text, 'Fear not, little flock,\nfrom the cross to the throne.');
      expect(result[0].isChorus, isFalse);

      // Chorus
      expect(result[1].label, 'C');
      expect(result[1].text, 'Only believe, only believe,\nAll things are possible.');
      expect(result[1].isChorus, isTrue);

      // Verse 2
      expect(result[2].label, 'V2');
      expect(result[2].text, 'Fear not, little flock,\nHe goeth ahead.');
      expect(result[2].isChorus, isFalse);
    });

    test('Build slide sequence with autoInsertChorus', () {
      final parsed = VerseParser.parse('''
V1 Text

CHORUS
Chorus Text

V2 Text
''');

      final sequence = VerseParser.buildSlideSequence(parsed, autoInsertChorus: true);

      // Expected sequence: V1 -> Chorus -> V2 -> Chorus
      expect(sequence, hasLength(4));
      expect(sequence[0].label, 'V1');
      expect(sequence[1].label, 'C');
      expect(sequence[2].label, 'V2');
      expect(sequence[3].label, 'C');
    });

    test('Build slide sequence without autoInsertChorus', () {
      final parsed = VerseParser.parse('''
V1 Text

CHORUS
Chorus Text

V2 Text
''');

      final sequence = VerseParser.buildSlideSequence(parsed, autoInsertChorus: false);

      // Expected sequence: V1 -> Chorus -> V2 (exact order as entered)
      expect(sequence, hasLength(3));
      expect(sequence[0].label, 'V1');
      expect(sequence[1].label, 'C');
      expect(sequence[2].label, 'V2');
    });
  });
}
