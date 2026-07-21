import 'package:visual_song_book/data/models/verse.dart';

class VerseParser {
  /// Parses raw song body text into a list of [Verse] objects.
  static List<Verse> parse(String body) {
    if (body.trim().isEmpty) return [];

    // Split by double newlines (handling Windows \r\n and Unix \n)
    final regex = RegExp(r'(?:\r?\n){2,}');
    final paragraphs = body.split(regex);

    final List<Verse> verses = [];
    int verseCounter = 1;

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;

      final lines = paragraph.split(RegExp(r'\r?\n'));
      if (lines.isEmpty) continue;

      final firstLine = lines.first.trim().toUpperCase();

      if (firstLine == 'CHORUS' || firstLine.startsWith('CHORUS:')) {
        // It's a chorus! Strip the first line and use the rest as text.
        final text = lines.skip(1).join('\n').trim();
        verses.add(Verse(label: 'C', text: text, order: i + 1));
      } else if (RegExp(r'^(VERSE\s*\d+|V\d+)(:)?$').hasMatch(firstLine) || firstLine == 'VERSE') {
        // It's a regular verse with a header. Strip the first line and use the rest as text.
        final text = lines.skip(1).join('\n').trim();
        final numberMatch = RegExp(r'\d+').firstMatch(firstLine);
        final numVal = numberMatch != null ? int.parse(numberMatch.group(0)!) : verseCounter;
        verses.add(
          Verse(label: 'V$numVal', text: text, order: i + 1),
        );
        if (numberMatch == null) {
          verseCounter++;
        } else {
          verseCounter = numVal + 1;
        }
      } else {
        // It's a regular verse.
        verses.add(
          Verse(label: 'V$verseCounter', text: paragraph, order: i + 1),
        );
        verseCounter++;
      }
    }

    return verses;
  }

  /// Builds a sequence of slides for projection.
  /// If a chorus exists, it is automatically repeated between verses if requested.
  static List<Verse> buildSlideSequence(
    List<Verse> verses, {
    bool autoInsertChorus = true,
  }) {
    if (verses.isEmpty) return [];

    final List<Verse> sequence = [];
    final chorus = verses.firstWhere(
      (v) => v.isChorus,
      orElse: () => Verse(label: '', text: '', order: -1),
    );

    final hasChorus = chorus.order != -1;

    for (int i = 0; i < verses.length; i++) {
      final current = verses[i];

      // If we are auto-inserting chorus and this is not the chorus itself
      if (autoInsertChorus && hasChorus && !current.isChorus) {
        // If it's a verse and we already added a slide and the last slide wasn't the chorus,
        // insert the chorus first (except if this is the very first slide of the song and chorus is later).
        if (sequence.isNotEmpty && !sequence.last.isChorus) {
          sequence.add(chorus);
        }
      }

      sequence.add(current);
    }

    // Optional: if the last slide is a verse and we want to end on chorus
    if (autoInsertChorus &&
        hasChorus &&
        sequence.isNotEmpty &&
        !sequence.last.isChorus) {
      sequence.add(chorus);
    }

    return sequence;
  }
}
