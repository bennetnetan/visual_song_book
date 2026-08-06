import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/main.dart';

void main() {
  testWidgets('first launch shows the onboarding wizard', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': false});
    final testDb = AppDatabase.forTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appSeedProvider.overrideWith((ref) async {}),
          bibleDatabaseInitProvider.overrideWith((ref) async {}),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Welcome page.
    expect(find.text('Visual Song Book'), findsWidgets);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Advance to the source selection page.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Song Source'), findsOneWidget);
    expect(find.text('Pre-installed Songbooks'), findsOneWidget);
    expect(find.text('Link Your Own Songbooks'), findsOneWidget);

    // Pick the bundled source → preferences page.
    await tester.tap(find.text('Pre-installed Songbooks'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Setup'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await testDb.close();
  });

  testWidgets('completing onboarding marks the flag and shows the dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': false});
    final testDb = AppDatabase.forTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appSeedProvider.overrideWith((ref) async {}),
          bibleDatabaseInitProvider.overrideWith((ref) async {}),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-installed Songbooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);

    // App shell is now shown.
    expect(find.text('Songs'), findsWidgets);

    await testDb.close();
  });

  testWidgets('Skip button completes onboarding immediately', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': false});
    final testDb = AppDatabase.forTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appSeedProvider.overrideWith((ref) async {}),
          bibleDatabaseInitProvider.overrideWith((ref) async {}),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(find.text('Songs'), findsWidgets);

    await testDb.close();
  });
}
