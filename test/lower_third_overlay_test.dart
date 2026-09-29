import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_item.dart';
import 'package:visual_song_book/features/lower_third/widgets/lower_third_overlay.dart';

void main() {
  testWidgets('LowerThirdOverlay does not render when disabled', (tester) async {
    final state = LowerThirdState.initial().copyWith(isEnabled: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LowerThirdOverlay(state: state),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(LowerThirdOverlay), findsOneWidget);
    expect(find.text(state.items.first.text), findsNothing);
  });

  testWidgets('LowerThirdOverlay renders active item text with custom styling', (tester) async {
    final state = LowerThirdState(
      isEnabled: true,
      items: [
        LowerThirdItem(id: '1', text: 'Welcome to Church!'),
      ],
      activeIndex: 0,
      config: const LowerThirdConfig(
        style: LowerThirdStyle.floatingPill,
        fontSize: 22.0,
        textColor: Colors.amber,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LowerThirdOverlay(state: state),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to Church!'), findsOneWidget);
    final textWidget = tester.widget<Text>(find.text('Welcome to Church!'));
    expect(textWidget.style?.color, Colors.amber);
    expect(textWidget.style?.fontSize, 22.0);
  });

  testWidgets('LowerThirdOverlay renders fullWidth banner style without overflow', (tester) async {
    final state = LowerThirdState(
      isEnabled: true,
      items: [
        LowerThirdItem(id: '1', text: 'Special Service Tonight at 6 PM'),
      ],
      activeIndex: 0,
      config: const LowerThirdConfig(
        style: LowerThirdStyle.fullWidth,
        height: 80.0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LowerThirdOverlay(state: state),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Special Service Tonight at 6 PM'), findsOneWidget);
  });

  testWidgets('LowerThirdOverlay activates scrolling marquee for text longer than space',
      (tester) async {
    const longText =
        'This is an exceptionally long announcement message that clearly exceeds standard screen width so it scrolls right to left across the screen.';
    final state = LowerThirdState(
      isEnabled: true,
      items: [
        LowerThirdItem(id: '1', text: longText),
      ],
      activeIndex: 0,
      config: const LowerThirdConfig(
        style: LowerThirdStyle.floatingPill,
        fontSize: 30.0,
      ),
    );

    // Constrained screen size to guarantee text overflow
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LowerThirdOverlay(state: state),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Marquee uses ClipRect + AnimatedBuilder (Transform.translate driven by AnimationController)
    expect(find.byType(ClipRect), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);
    expect(find.text(longText), findsOneWidget);
  });
}
