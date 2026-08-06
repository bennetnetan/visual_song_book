import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/widgets/bible_reading_widgets.dart';

BibleVerse _verse(int id, String text) => BibleVerse(
      id: id,
      bookId: 1,
      chapter: 1,
      verse: id,
      text: text,
      bookName: 'Genesis',
    );

Widget _wrap(BibleReadingView view) => MaterialApp(home: Scaffold(body: view));

void main() {
  BibleReadingView buildView({required String fontFamily}) {
    return BibleReadingView(
      selectedChapter: 1,
      verses: [
        _verse(1, 'In the beginning God created the heaven and the earth.'),
        _verse(2, 'And the earth was without form, and void.'),
      ],
      bookName: 'Genesis',
      onProjectPassage: (_, _) {},
      onToggleBookmark: (_) {},
      activeVerse: null,
      onSelectVerse: (_) {},
      bookmarkedVerseIds: const {},
      selectionMode: false,
      selectedVerseIds: const {},
      onToggleSelectionMode: () {},
      onToggleVerseSelection: (_) {},
      onSelectAllVerses: () {},
      fontSize: 16,
      readingFontFamily: fontFamily,
      isLoadingVerses: false,
      isLargeScreen: true,
      onShowCrossRefs: (_) {},
    );
  }

  testWidgets('verse text uses the configured reading font family',
      (tester) async {
    await tester.pumpWidget(_wrap(buildView(fontFamily: 'EBGaramond')));

    final textWidget = tester.widget<Text>(
      find.text('In the beginning God created the heaven and the earth.'),
    );
    expect(textWidget.style?.fontFamily, 'EBGaramond');

    final secondText = tester.widget<Text>(
      find.text('And the earth was without form, and void.'),
    );
    expect(secondText.style?.fontFamily, 'EBGaramond');
  });

  testWidgets('reading font change is reflected on rebuild', (tester) async {
    await tester.pumpWidget(_wrap(buildView(fontFamily: 'Inter')));

    var textWidget = tester.widget<Text>(
      find.text('In the beginning God created the heaven and the earth.'),
    );
    expect(textWidget.style?.fontFamily, 'Inter');

    await tester.pumpWidget(_wrap(buildView(fontFamily: 'EBGaramond')));

    textWidget = tester.widget<Text>(
      find.text('In the beginning God created the heaven and the earth.'),
    );
    expect(textWidget.style?.fontFamily, 'EBGaramond');
  });
}
