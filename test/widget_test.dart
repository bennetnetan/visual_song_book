import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/main.dart';

void main() {
  testWidgets('Dashboard renders app shell and navigation',
      (WidgetTester tester) async {
    final testDb = AppDatabase.forTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          hasCompletedOnboardingProvider.overrideWith((ref) => true),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();

    // The app shell renders synchronously — verify navigation tabs appear.
    // On the 800x600 test viewport (< 900) the bottom nav bar is used.
    expect(find.text('Songs'), findsWidgets);
    expect(find.text('Projection'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // While Drift streams haven't resolved, the loading spinner is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await testDb.close();
  });
}
