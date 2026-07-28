import 'dart:io';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/services/app_storage.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise logging — ALL levels in debug, WARNING+ in release.
  AppLogger.init(level: kReleaseMode ? Level.WARNING : Level.ALL);
  final log = AppLogger.get('Main');
  log.info('App starting (args: $args)');

  // Pre-warm the unified app storage path so LazyDatabase resolves instantly.
  getAppStoragePath(); // fire-and-forget — result is cached for all subsequent calls

  if (args.isNotEmpty &&
      (args.first == 'multi_window' || args.first == 'Projection Output')) {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // window_manager is not registered in secondary (desktop_multi_window)
      // engines, so guard every call with a try-catch.
      try {
        await windowManager.ensureInitialized();
        await windowManager.setFullScreen(true);
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      } catch (_) {}

      try {
        final displays = await screenRetriever.getAllDisplays();
        final prefs = await SharedPreferences.getInstance();
        final mode = prefs.getString('projection_mode') ?? 'extended';

        Display? targetDisplay;
        if (mode == 'extended' && displays.length > 1) {
          targetDisplay = displays[1];
        } else {
          targetDisplay = displays[0];
        }

        await windowManager.setBounds(
          Rect.fromLTWH(
            targetDisplay.visiblePosition?.dx ?? 0,
            targetDisplay.visiblePosition?.dy ?? 0,
            targetDisplay.size.width,
            targetDisplay.size.height,
          ),
        );

        if (mode == 'single' || mode == 'duplicate') {
          await windowManager.setAlwaysOnTop(true);
        }
      } catch (_) {}
    }
    runApp(
      ProviderScope(
        overrides: [
          isProjectionWindowProvider.overrideWithValue(true),
        ],
        child: const MyApp(isProjectionWindow: true),
      ),
    );
    return;
  }

  // Initialize desktop window manager options
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 780),
      minimumSize: Size(800, 600),
      center: true,
      title: 'Visual Song Book',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        // Wire SeedingService with the app database so first-launch seeding works.
        seedingServiceProvider.overrideWith(
          (ref) => SeedingService(ref.watch(databaseProvider)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool isProjectionWindow;

  const MyApp({super.key, this.isProjectionWindow = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Trigger bundled-songbook seeding on every cold start.
    // SeedingService is a no-op after the first successful seed.
    if (!isProjectionWindow) {
      ref.watch(appSeedProvider);
      ref.watch(linkedSongbooksSyncProvider);
    }

    return MaterialApp.router(
      title: 'Visual Song Book',
      debugShowCheckedModeBanner: false,

      // Premium styling using Teal M3 scheme
      theme: FlexThemeData.light(
        scheme: FlexScheme.tealM3,
        useMaterial3: true,
        fontFamily: 'Inter',
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 1,
        subThemesData: const FlexSubThemesData(
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 16.0,
          cardRadius: 16.0,
          cardElevation: 0,
          dialogRadius: 20.0,
          dialogElevation: 0,
          bottomSheetElevation: 0,
          navigationBarElevation: 0,
          navigationRailElevation: 0,
          navigationRailUseIndicator: true,
          appBarScrolledUnderElevation: 0,
          elevatedButtonElevation: 0,
          popupMenuElevation: 2,
        ),
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.tealM3,
        useMaterial3: true,
        fontFamily: 'Inter',
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 2,
        subThemesData: const FlexSubThemesData(
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 16.0,
          cardRadius: 16.0,
          cardElevation: 0,
          dialogRadius: 20.0,
          dialogElevation: 0,
          bottomSheetElevation: 0,
          navigationBarElevation: 0,
          navigationRailElevation: 0,
          navigationRailUseIndicator: true,
          appBarScrolledUnderElevation: 0,
          elevatedButtonElevation: 0,
          popupMenuElevation: 2,
        ),
      ),
      themeMode: themeMode,

      // Routing
      routerConfig: isProjectionWindow ? projectionRouter : appRouter,
    );
  }
}
