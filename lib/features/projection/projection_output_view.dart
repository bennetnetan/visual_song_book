import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:google_fonts/google_fonts.dart';
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
  double _ipcFontSize = 40.0;
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
          _ipcFontSize = (call.arguments['fontSize'] as num?)?.toDouble() ?? 40.0;
        });
        debugPrint('Updated secondary window text: "$_ipcText"');
      }
      return 'OK';
    });
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

    final String activeText =
        _isSecondaryWindow ? _ipcText : (state.currentSlide?.text ?? '');
    final double activeFontSize =
        _isSecondaryWindow ? _ipcFontSize : state.fontSize;
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

              // Main slide text with animated transitions
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 64.0, vertical: 48.0),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: activeText.isNotEmpty
                          ? Text(
                              activeText,
                              key: ValueKey(slideKey),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
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
                                    color: const Color(0xFF00E5CC)
                                        .withValues(alpha: 0.12),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('blank_slide'),
                            ),
                    ),
                  ),
                ),
              ),

              // Subtle slide indicator dots at the bottom (secondary window / main window only)
              if (!_isSecondaryWindow && state.slides.isNotEmpty)
                Positioned(
                  bottom: 20,
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
