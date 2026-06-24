import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class ProjectionOutputView extends ConsumerStatefulWidget {
  const ProjectionOutputView({super.key});

  @override
  ConsumerState<ProjectionOutputView> createState() =>
      _ProjectionOutputViewState();
}

class _ProjectionOutputViewState extends ConsumerState<ProjectionOutputView>
    with SingleTickerProviderStateMixin, WindowListener {
  String _ipcText = '';
  String _ipcLabel = '';
  bool _ipcIsBible = false;
  bool _isSecondaryWindow = false;
  late AnimationController _fadeController;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeController.forward();

    // On Mobile/Web, hide the status/navigation bar for a fully immersive experience
    if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _setupSecondaryWindowChannel();
      windowManager.addListener(this);
      if (Platform.isLinux) {
        windowManager.setPreventClose(true);
      }
    }
  }

  void _setupSecondaryWindowChannel() async {
    final controller = await WindowController.fromCurrentEngine();
    controller.setWindowMethodHandler((call) async {
      debugPrint('Received IPC method call: ${call.method}');

      if (call.method == 'update_slide') {
        if (!mounted) return null;
        setState(() {
          _isSecondaryWindow = true;
          _ipcText = call.arguments['text'] ?? '';
          _ipcLabel = call.arguments['label'] ?? '';
          _ipcIsBible = call.arguments['isBible'] ?? false;
        });
        debugPrint('Updated secondary window text: "$_ipcText" label: "$_ipcLabel"');
      }
      return 'OK';
    });
  }

  Future<void> _sendNavigateToMain(String action) async {
    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      for (final c in controllers) {
        if (c.windowId == currentWindow.windowId) continue;
        await c.invokeMethod('navigate_slide', {'action': action});
      }
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    if (Platform.isLinux) {
      await _handleManualClose();
    } else {
      await windowManager.close();
    }
  }

  Future<void> _handleManualClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      await windowManager.hide();
    } catch (_) {}

    try {
      windowManager.removeListener(this);
    } catch (_) {}

    // Wait for the graphics pipeline/engine to finish pending render calls before close
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('Error during manual close on Linux: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    final String activeText = _isSecondaryWindow
        ? _ipcText
        : (state.currentSlide?.text ?? '');
    final String activeLabel = _isSecondaryWindow
        ? _ipcLabel
        : (state.currentSlide?.label ?? '');
    final bool activeIsBible = _isSecondaryWindow
        ? _ipcIsBible
        : state.isBibleMode;
    // Font size is fixed at 40pt for consistent projection output
    const double activeFontSize = 40.0;
    final String slideKey = _isSecondaryWindow
        ? 'ipc_${_ipcText.hashCode}'
        : '${state.currentSong?.id}_${state.currentSlideIndex}';

    return GestureDetector(
      // Swipe left = next, swipe right = prev (for tablet/mobile presenters)
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          notifier.nextSlide();
        } else if (details.primaryVelocity! > 300) {
          notifier.prevSlide();
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.space) {
              notifier.nextSlide();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              notifier.prevSlide();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              notifier.clearSong();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle radial gradient background for cinematic depth
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0xFF0A1A18), // very dark teal center
                      Color(0xFF000000), // pure black edges
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),

              // Main slide text with animated transitions + reference below
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64.0,
                    vertical: 48.0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                child: child,
                              ),
                            );
                          },
                          child: activeText.isNotEmpty
                              ? Text(
                                  activeText,
                                  key: ValueKey(slideKey),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontSize: activeFontSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                    letterSpacing: 0.3,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 2),
                                        blurRadius: 12,
                                        color: Colors.black.withValues(alpha: 0.8),
                                      ),
                                      Shadow(
                                        offset: const Offset(0, 0),
                                        blurRadius: 30,
                                        color: const Color(
                                          0xFF00E5CC,
                                        ).withValues(alpha: 0.12),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('blank_slide')),
                        ),
                        // Bible reference below verse text
                        if (activeIsBible && activeLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                activeLabel,
                                key: ValueKey('ref_$activeLabel'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF00E5CC).withValues(alpha: 0.85),
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 8,
                                      color: Colors.black.withValues(alpha: 0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Navigation arrows for secondary window (desktop projector)
              if (_isSecondaryWindow && state.slides.isNotEmpty)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_circle_left,
                          size: 48,
                          color: Colors.white54,
                        ),
                        onPressed: () => _sendNavigateToMain('prev'),
                        splashRadius: 28,
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 48),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_circle_right,
                          size: 48,
                          color: Colors.white54,
                        ),
                        onPressed: () => _sendNavigateToMain('next'),
                        splashRadius: 28,
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                ),

              // Slide indicator dots at the bottom
              if (state.slides.isNotEmpty)
                Positioned(
                  bottom: _isSecondaryWindow ? 96 : 20,
                  left: 0,
                  right: 0,
                  child: _SlideIndicator(
                    count: state.slides.length,
                    current: state.currentSlideIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small dot indicators showing slide position — like a presentation slideshow
class _SlideIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _SlideIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? const Color(0xFF00E5CC)
                : Colors.white.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}
