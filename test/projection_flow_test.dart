import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/projection/projection_output_view.dart';
import 'package:visual_song_book/main.dart';

const _windowChannel = MethodChannel('mixin.one/desktop_multi_window');

void main() {
  Future<AppDatabase> seedDatabase() async {
    final db = AppDatabase.forTesting();
    await SongRepository(db).addSong(
      SongsCompanion.insert(
        songNum: 1,
        title: 'Integration Hymn',
        body:
            'First stanza line one\n'
            'First stanza line two\n'
            '\n'
            'Second stanza line one',
      ),
    );
    return db;
  }

  testWidgets('selecting a song and projecting shows slides with keyboard nav',
      (tester) async {
    // The projector-window plugin channel is not backed by a real platform in
    // widget tests. Simulate a failed secondary-window launch so the app falls
    // back to pushing the in-app /projection route.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (call) async {
        switch (call.method) {
          case 'createWindow':
            throw PlatformException(code: 'unsupported');
          case 'getWindowDefinition':
            return {'windowId': 'main-window', 'windowArgument': ''};
          case 'getAllWindows':
            return <dynamic>[];
          default:
            return null;
        }
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowChannel, null);
    });

    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testDb = await seedDatabase();

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
    await tester.pump(const Duration(milliseconds: 400));

    // The seeded song appears in the list.
    expect(find.text('Integration Hymn'), findsOneWidget);
    await tester.tap(find.text('Integration Hymn'));
    // Single-tap must outlast the double-tap gesture timeout to win the arena.
    await tester.pump(const Duration(milliseconds: 400));

    // Desktop layout shows the preview panel with the projector button.
    expect(find.text('Send to Projector'), findsOneWidget);
    await tester.tap(find.text('Send to Projector'));
    await tester.pumpAndSettle();

    // Projection view shows slide 1.
    expect(find.byType(ProjectionOutputView), findsOneWidget);
    expect(
      find.text('First stanza line one\nFirst stanza line two'),
      findsOneWidget,
    );

    // Arrow-right advances to slide 2.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Second stanza line one'), findsOneWidget);

    // Arrow-left returns to slide 1.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      find.text('First stanza line one\nFirst stanza line two'),
      findsOneWidget,
    );

    // Escape closes the projection and returns to the dashboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Send to Projector'), findsWidgets);

    await testDb.close();
  });
}
