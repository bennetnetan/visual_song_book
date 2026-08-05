import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/projection/projection_output_view.dart';

void main() {
  // Match production text metrics (the app uses Inter); otherwise
  // flutter_test substitutes the ultra-wide "Ahem" font, which turns any
  // near-full-width row into a false-positive overflow.
  setUpAll(() async {
    final loader = FontLoader('Inter');
    loader.addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    loader.addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    await loader.load();
  });

  // The sheet must flex to whatever height the draggable bottom sheet allows
  // (it opens around half the screen) and reflow for portrait/landscape
  // without any RenderFlex overflow.
  Future<void> pumpSheet(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: 355, // simulate a half-height bottom sheet
                child: const ProjectionAppearanceSheet(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('appearance sheet renders without overflow in portrait',
      (tester) async {
    await pumpSheet(tester, const Size(400, 800));

    expect(find.text('Commit Changes'), findsOneWidget);
    expect(find.text('Restore Defaults'), findsOneWidget);
    expect(find.text('Slide Text Color'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance sheet renders without overflow in landscape',
      (tester) async {
    await pumpSheet(tester, const Size(800, 400));

    expect(find.text('Commit Changes'), findsOneWidget);
    expect(find.text('Restore Defaults'), findsOneWidget);
    expect(find.text('Slide Text Color'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
