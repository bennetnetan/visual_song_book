import 'dart:io';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/routing/app_router.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.isNotEmpty && (args.first == 'multi_window' || args.first == 'Projection Output')) {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();
    }
    runApp(
      const ProviderScope(
        child: MyApp(isProjectionWindow: true),
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
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool isProjectionWindow;

  const MyApp({super.key, this.isProjectionWindow = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Visual Song Book',
      debugShowCheckedModeBanner: false,

      // Premium styling using Teal M3 scheme
      theme: FlexThemeData.light(
        scheme: FlexScheme.tealM3,
        useMaterial3: true,
        fontFamily: 'Inter',
        subThemesData: const FlexSubThemesData(
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 16.0,
          cardRadius: 20.0,
          dialogRadius: 24.0,
          navigationRailUseIndicator: true,
        ),
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.tealM3,
        useMaterial3: true,
        fontFamily: 'Inter',
        subThemesData: const FlexSubThemesData(
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 16.0,
          cardRadius: 20.0,
          dialogRadius: 24.0,
          navigationRailUseIndicator: true,
        ),
      ),
      themeMode: themeMode,

      // Routing
      routerConfig: isProjectionWindow ? projectionRouter : appRouter,
    );
  }
}
