import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/features/projection/projection_preview_glow.dart';
import 'package:visual_song_book/features/projection/projection_state.dart';
import 'package:visual_song_book/features/projection/slide_carets_indicator.dart';

void main() {
  group('SlideCaretsIndicator widget', () {
    testWidgets('renders down arrow only on first slide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SlideCaretsIndicator(
              showUp: false,
              showDown: true,
              color: Colors.white,
            ),
          ),
        ),
      );

      final upIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_up_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      final downIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_down_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );

      expect(upIcon.opacity, equals(0.0));
      expect(downIcon.opacity, equals(1.0));
    });

    testWidgets('renders both carets in the middle of a song/passage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SlideCaretsIndicator(
              showUp: true,
              showDown: true,
              color: Colors.white,
            ),
          ),
        ),
      );

      final upIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_up_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      final downIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_down_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );

      expect(upIcon.opacity, equals(1.0));
      expect(downIcon.opacity, equals(1.0));
    });

    testWidgets('renders up arrow only on final slide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SlideCaretsIndicator(
              showUp: true,
              showDown: false,
              color: Colors.white,
            ),
          ),
        ),
      );

      final upIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_up_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      final downIcon = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_down_rounded),
          matching: find.byType(AnimatedOpacity),
        ),
      );

      expect(upIcon.opacity, equals(1.0));
      expect(downIcon.opacity, equals(0.0));
    });

    testWidgets('renders nothing when both are false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SlideCaretsIndicator(
              showUp: false,
              showDown: false,
              color: Colors.white,
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });
  });

  group('ProjectionState continuation and boundary logic', () {
    test('single song: down on first, both in middle, up on last', () {
      final slides = [
        Verse(label: 'V1', text: 'Verse 1 text', order: 1, songTitle: 'Song A'),
        Verse(label: 'C', text: 'Chorus text', order: 2, songTitle: 'Song A'),
        Verse(label: 'V2', text: 'Verse 2 text', order: 3, songTitle: 'Song A'),
      ];

      var state = ProjectionState.initial().copyWith(slides: slides, currentSlideIndex: 0);

      // Slide 0: First verse
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isFalse);
      expect(state.isEndSlide, isFalse);
      expect(state.endNotificationText, isNull);

      // Slide 1: Middle (Chorus)
      state = state.copyWith(currentSlideIndex: 1);
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isFalse);
      expect(state.endNotificationText, isNull);

      // Slide 2: Final verse
      state = state.copyWith(currentSlideIndex: 2);
      expect(state.showDownCaret, isFalse);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isTrue);
      expect(state.isEndOfSongInSet, isFalse);
      expect(state.endNotificationText, equals('End of song'));
    });

    test('multi-song set: boundary transitions between songs and at set end', () {
      final slides = [
        // Song A (2 slides)
        Verse(label: 'V1', text: 'Song A v1', order: 1, songTitle: 'Song A'),
        Verse(label: 'V2', text: 'Song A v2', order: 2, songTitle: 'Song A'),
        // Song B (2 slides)
        Verse(label: 'V1', text: 'Song B v1', order: 1, songTitle: 'Song B'),
        Verse(label: 'V2', text: 'Song B v2', order: 2, songTitle: 'Song B'),
      ];

      var state = ProjectionState.initial().copyWith(slides: slides, currentSlideIndex: 0);

      // Song A, Slide 0: First slide of Song A
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isFalse);
      expect(state.isEndSlide, isFalse);

      // Song A, Slide 1: Last slide of Song A (Next song is Song B!)
      state = state.copyWith(currentSlideIndex: 1);
      expect(state.showDownCaret, isFalse);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isTrue);
      expect(state.isEndOfSongInSet, isTrue);
      expect(state.nextSongTitle, equals('Song B'));
      expect(state.endNotificationText, equals('End of song — Next: Song B'));

      // Song B, Slide 2: First slide of Song B
      state = state.copyWith(currentSlideIndex: 2);
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isFalse);
      expect(state.isEndSlide, isFalse);

      // Song B, Slide 3: Last slide of Song B & set end
      state = state.copyWith(currentSlideIndex: 3);
      expect(state.showDownCaret, isFalse);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isTrue);
      expect(state.isEndOfSongInSet, isFalse);
      expect(state.endNotificationText, equals('End of set'));
    });

    test('Bible mode: verse boundary and end of chapter', () {
      final slides = [
        Verse(label: 'Psalm 23:1', text: 'The Lord is my shepherd...', order: 1),
        Verse(label: 'Psalm 23:2', text: 'He maketh me to lie down...', order: 2),
        Verse(label: 'Psalm 23:3', text: 'He restoreth my soul...', order: 3),
      ];

      var state = ProjectionState.initial().copyWith(
        isBibleMode: true,
        bibleBookName: () => 'Psalm',
        bibleChapter: () => 23,
        slides: slides,
        currentSlideIndex: 0,
      );

      // Verse 1
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isFalse);
      expect(state.isEndSlide, isFalse);

      // Verse 2
      state = state.copyWith(currentSlideIndex: 1);
      expect(state.showDownCaret, isTrue);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isFalse);

      // Verse 3 (End of chapter)
      state = state.copyWith(currentSlideIndex: 2);
      expect(state.showDownCaret, isFalse);
      expect(state.showUpCaret, isTrue);
      expect(state.isEndSlide, isTrue);
      expect(state.endNotificationText, equals('End of Psalm 23'));
    });

    test('respects showContinuationCarets toggle', () {
      final slides = [
        Verse(label: 'V1', text: 'Verse 1', order: 1, songTitle: 'Song A'),
        Verse(label: 'V2', text: 'Verse 2', order: 2, songTitle: 'Song A'),
      ];

      final state = ProjectionState.initial().copyWith(
        slides: slides,
        currentSlideIndex: 0,
        showContinuationCarets: false,
      );

      expect(state.showDownCaret, isFalse);
      expect(state.showUpCaret, isFalse);
    });
  });

  group('ProjectionPreviewGlow widget', () {
    testWidgets('shows amber glow and notification banner on end slide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProjectionPreviewGlow(
              isEndSlide: true,
              notificationText: 'End of song — Next: Song B',
              child: SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );

      expect(find.text('End of song — Next: Song B'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);

      // Fast-forward 4 seconds to test auto-dismiss
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.pump(const Duration(milliseconds: 300));

      final bannerOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('End of song — Next: Song B'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(bannerOpacity.opacity, equals(0.0));
    });

    testWidgets('does not show banner when not an end slide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProjectionPreviewGlow(
              isEndSlide: false,
              notificationText: null,
              child: SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
    });
  });
}
