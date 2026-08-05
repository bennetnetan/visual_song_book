import 'dart:io';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/core/utils/projection_window_args.dart';

import 'package:visual_song_book/data/services/app_storage.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/features/onboarding/onboarding_page.dart';
import 'package:visual_song_book/routing/app_router.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // All fonts used via GoogleFonts.* are bundled in assets/fonts; never
  // fetch them at runtime (throws loudly if a used variant is missing).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Video player backend (libmpv on desktop, platform players on mobile).
  MediaKit.ensureInitialized();

  // Initialise logging — ALL levels in debug, WARNING+ in release.
  AppLogger.init(level: kReleaseMode ? Level.WARNING : Level.ALL);
  final log = AppLogger.get('Main');
  log.info('App starting (args: $args)');

  // Pre-warm the unified app storage path so LazyDatabase resolves instantly.
  getAppStoragePath(); // fire-and-forget — result is cached for all subsequent calls

  // Classify the process args: desktop_multi_window spawns each secondary
  // window as a fresh engine with its own args. The projection engine is
  // launched with 'Projection Output:<mode>' (see ProjectionController).
  // NOTE: window_manager and screen_retriever plugins are NOT registered in
  // desktop_multi_window secondary engines. Any calls to them will fail
  // silently. The secondary window handles its own fullscreen via
  // ProjectionOutputView._goFullscreenOnBestDisplay() using Win32 APIs.
  final windowArgs = parseProjectionWindowArgs(args.isNotEmpty ? args.first : null);
  if (windowArgs.isProjectionWindow) {
    runApp(
      ProviderScope(
        overrides: [
          isProjectionWindowProvider.overrideWithValue(true),
          projectionWindowModeProvider.overrideWithValue(windowArgs.mode),
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

    // Check onboarding state for non-projection windows
    final onboardingAsync = isProjectionWindow
        ? const AsyncValue.data(true)
        : ref.watch(hasCompletedOnboardingProvider);

    final lightTheme = FlexThemeData.light(
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
    );

    final darkTheme = FlexThemeData.dark(
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
    );

    return onboardingAsync.when(
      data: (completed) {
        if (!completed) {
          return MaterialApp(
            title: 'Visual Song Book',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            home: const OnboardingPage(),
          );
        }
        return MaterialApp.router(
          title: 'Visual Song Book',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: isProjectionWindow ? projectionRouter : appRouter,
        );
      },
      loading: () => MaterialApp(
        title: 'Visual Song Book',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => MaterialApp.router(
        title: 'Visual Song Book',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        routerConfig: isProjectionWindow ? projectionRouter : appRouter,
      ),
    );
  }
}
