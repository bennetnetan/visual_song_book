import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/core/theme/app_theme.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/core/utils/projection_window_args.dart';

import 'package:visual_song_book/data/services/app_storage.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/features/onboarding/onboarding_page.dart';
import 'package:visual_song_book/routing/app_router.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();


  // Linux the fvp backend (bundled FFmpeg) handles local files — no system
  // libmpv dependency, so packaged builds (AppImage) work on clean machines.

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

    // Eagerly copy/open the bundled Bible DB at startup (first run copies
    // ~29 MB) so it never blocks the first Bible search. Shown behind the
    // first-run setup splash below.
    final bibleInitAsync = isProjectionWindow
        ? const AsyncValue<void>.data(null)
        : ref.watch(bibleDatabaseInitProvider);
    final seedAsync = isProjectionWindow
        ? const AsyncValue<void>.data(null)
        : ref.watch(appSeedProvider);

    // Check onboarding state for non-projection windows
    final onboardingAsync = isProjectionWindow
        ? const AsyncValue.data(true)
        : ref.watch(hasCompletedOnboardingProvider);

    final lightTheme = buildAppTheme(Brightness.light);
    final darkTheme = buildAppTheme(Brightness.dark);

    final Widget app;
    // First-run setup: the bundled songbook seed and Bible DB copy can take
    // 5-15s on low-end devices. Show progress instead of a frozen screen.
    if (!isProjectionWindow &&
        (seedAsync.isLoading || bibleInitAsync.isLoading)) {
      app = MaterialApp(
        title: 'Visual Song Book',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const _FirstRunSplash(),
      );
    } else {
      app = onboardingAsync.when(
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
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, _) => MaterialApp.router(
          title: 'Visual Song Book',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: isProjectionWindow ? projectionRouter : appRouter,
        ),
      );
    }

    return _LifecycleGuard(child: app);
  }
}

/// Wraps the app so the read-only Bible database handle is released when the
/// OS detaches from the engine (app backgrounding/kill on Android, window
/// close on desktop), letting SQLite flush any pending state.
class _LifecycleGuard extends ConsumerStatefulWidget {
  final Widget child;

  const _LifecycleGuard({required this.child});

  @override
  ConsumerState<_LifecycleGuard> createState() => _LifecycleGuardState();
}

class _LifecycleGuardState extends ConsumerState<_LifecycleGuard> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onDetach: () {
      ref.read(bibleDatabaseProvider).close();
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FirstRunSplash extends StatelessWidget {
  const _FirstRunSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 96,
                height: 96,
              ),
              const SizedBox(height: 24),
              Text(
                'Preparing your song library…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'First launch can take a minute.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
