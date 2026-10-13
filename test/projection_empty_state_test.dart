import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/projection/projection_tab.dart';
import 'package:visual_song_book/main.dart';

const _windowChannel = MethodChannel('mixin.one/desktop_multi_window');

/// Regressions for the redesigned empty projection page.
///
/// Two framework assertions are guarded here, both of which shipped in earlier
/// revisions of the empty state:
///   1. nesting a second `Focus` around the projection focus node the parent
///      `ProjectionTab` already owns ("Tried to make a child into a parent of
///      itself"), and
///   2. calling `Navigator.pop()` after picking a history item, even though the
///      empty view is inline in the dashboard rather than a pushed route
///      ("You have popped the last page off of the stack").
void main() {
  Future<AppDatabase> seedDatabase() async {
    final db = AppDatabase.forTesting();
    await SongRepository(db).addSong(
      SongsCompanion.insert(
        songNum: 1,
        title: 'Recorded Hymn',
        body: 'First stanza line one\nSecond stanza line two',
      ),
    );
    return db;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  });

  testWidgets('empty projection tab renders search, history tabs and sets '
      'without a focus-node assertion', (tester) async {
    final testDb = await seedDatabase();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appSeedProvider.overrideWith((ref) async {}),
          bibleDatabaseInitProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProjectionTab(isLargeScreen: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The tab itself mounted — no framework assertion was thrown.
    expect(find.byType(ProjectionTab), findsOneWidget);

    // Search is embedded in the window as a ready-to-type field rather than a
    // chip that opens a popup, so the SearchBar is on screen with its hint.
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Search Bible…'), findsOneWidget);

    // History tabs still sit alongside it. "Songs"/"Bible" also name the search
    // mode chips in the field row, so both matches are expected.
    expect(find.text('Songs'), findsWidgets);
    expect(find.text('Bible'), findsWidgets);
    expect(find.text('Sets'), findsOneWidget);

    // The old navigation buttons are gone.
    expect(find.text('Browse Songs'), findsNothing);
    expect(find.text('Open Bible'), findsNothing);

    // The inline field already has focus so typing can start immediately.
    expect(tester.widget<SearchBar>(find.byType(SearchBar)).focusNode?.hasFocus,
        isTrue);

    await testDb.close();
  });

  testWidgets('empty projection tab renders in the narrow layout',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
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
        child: const MaterialApp(
          home: Scaffold(
            body: ProjectionTab(isLargeScreen: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProjectionTab), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);

    // Narrow screens get an explicit Search / History tab pair rather than a
    // rail, so history is only visible after switching to that tab.
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    // The history panel is behind the tab, not shown alongside search.
    expect(find.text('Songs'), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Songs'), findsWidgets);
    // And the search field is hidden while history is selected.
    expect(find.byType(SearchBar), findsNothing);

    await testDb.close();
  });

  testWidgets('picking a projected song from history projects it without '
      'popping a route', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testDb = await seedDatabase();
    // Mark the song as previously projected so it lands in song history.
    final songs = await SongRepository(testDb).getSongs();
    await SongRepository(testDb).addToHistory(songs.first.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appSeedProvider.overrideWith((ref) async {}),
          bibleDatabaseInitProvider.overrideWith((ref) async {}),
        ],
        // The real router is required: a bare MaterialApp only pops silently,
        // whereas GoRouter asserts "You have popped the last page off of the
        // stack" when the empty state dismisses itself via Navigator.pop().
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Navigate to the Projection tab so the empty state is on screen.
    // Unselected rail destinations use the outlined variant.
    await tester.tap(find.text('Projection'));
    await tester.pumpAndSettle();

    // The empty state shows the previously projected song in Songs history.
    expect(find.text('Recorded Hymn'), findsOneWidget);

    // Selecting it must set the content (auto-projecting it) rather than
    // popping the dashboard route, which would throw a GoRouter assertion in
    // the real app. Assert the app shell survived the tap so a reintroduced
    // pop fails here instead of silently blanking the screen.
    await tester.tap(find.text('Recorded Hymn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // The tab (and therefore the whole route stack) is still mounted.
    expect(find.byType(ProjectionTab), findsOneWidget);
    expect(find.text('Projection Controls'), findsOneWidget);
    // The empty state is gone and the active controls took over.
    expect(find.text('Nothing on screen'), findsNothing);
    expect(find.text('Recorded Hymn'), findsWidgets);

    await testDb.close();
  });

  testWidgets('picking content opens the projector output window automatically',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Record every projector window the controller asks the plugin to create.
    // `createWindow` is the exact call the manual "Open Projector Output
    // Window" button makes, so seeing it from a history/projection pick proves
    // the flow is autonomous rather than button-driven.
    final createdWindows = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (call) async {
        switch (call.method) {
          case 'createWindow':
            createdWindows.add('${call.arguments}');
            return 'proj-window-1';
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

    final testDb = await seedDatabase();
    final songs = await SongRepository(testDb).getSongs();
    await SongRepository(testDb).addToHistory(songs.first.id);

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

    await tester.tap(find.text('Projection'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded Hymn'), findsOneWidget);

    // No window yet — nothing has been projected.
    expect(createdWindows, isEmpty);

    // Picking the history item must project AND open the projector window.
    await tester.tap(find.text('Recorded Hymn'));
    await tester.pump();
    // Let the deferred auto-open microtask and its awaits settle.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      createdWindows,
      isNotEmpty,
      reason: 'the projector output window should open on its own when '
          'content is projected',
    );
    expect(find.text('Nothing on screen'), findsNothing);

    await testDb.close();
  });

  testWidgets('auto-open respects the projector auto-open setting',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdWindows = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (call) async {
        switch (call.method) {
          case 'createWindow':
            createdWindows.add('${call.arguments}');
            return 'proj-window-1';
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

    final testDb = await seedDatabase();
    final songs = await SongRepository(testDb).getSongs();
    await SongRepository(testDb).addToHistory(songs.first.id);

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

    await tester.tap(find.text('Projection'));
    await tester.pumpAndSettle();

    // Operators who want to open the window by hand can turn auto-open off.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Settings is tabbed; the preference lives in the Projection section.
    // Scope the finder to the TabBar so it doesn't hit the navigation rail,
    // which also has a "Projection" destination.
    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Projection'),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll the preference into view and toggle its switch. The label is a
    // sibling of the Switch inside the same Row, so walk up to the Row.
    final autoOpenLabel = find.text('Auto-Open Projector Window');
    await tester.ensureVisible(autoOpenLabel);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(of: autoOpenLabel, matching: find.byType(Row))
            .first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    // Back to the Projection tab and pick content again. Scope to the
    // navigation rail: the settings TabBar also has a "Projection" tab, so an
    // unscoped text find would be ambiguous.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Projection'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recorded Hymn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(createdWindows, isEmpty);
    // Content is still projected, just without a window opening itself.
    expect(find.text('Nothing on screen'), findsNothing);

    await testDb.close();
  });

  testWidgets('typing in the inline field runs a search without opening a popup',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
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

    await tester.tap(find.text('Projection'));
    await tester.pumpAndSettle();

    // Starting in Bible mode: no dialog, the field is already on screen.
    expect(find.byType(SearchBar), findsOneWidget);
    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.focusNode?.hasFocus, isTrue);

    // Switch to song mode through the inline mode chips.
    await tester.tap(find.text('Song'));
    await tester.pumpAndSettle();

    // Type directly into the field. The debounce runs, then results render
    // inside the window itself rather than in a dialog.
    await tester.enterText(find.byType(SearchBar), 'Recorded');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // The empty window is still mounted, so nothing was dismissed.
    expect(find.byType(ProjectionTab), findsOneWidget);
    // Song matches are rendered as cards inline.
    expect(find.byType(Card), findsWidgets);
    // No dialog/popup appeared on top of it.
    expect(find.byType(Dialog), findsNothing);

    await testDb.close();
  });
}
