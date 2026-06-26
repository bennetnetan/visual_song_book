import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:go_router/go_router.dart';
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
  bool _isHovering = false;

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
    if (!mounted) return;

    setState(() {
      _isSecondaryWindow = true;
    });

    // Request fullscreen once the window is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await windowManager.setFullScreen(true);
      } catch (_) {}
    });

    controller.setWindowMethodHandler((call) async {
      debugPrint('Received IPC method call: ${call.method}');

      if (call.method == 'update_slide') {
        if (!mounted) return null;
        setState(() {
          if (call.arguments['text'] != null) _ipcText = call.arguments['text'] as String;
          if (call.arguments['label'] != null) _ipcLabel = call.arguments['label'] as String;
          if (call.arguments['isBible'] != null) _ipcIsBible = call.arguments['isBible'] as bool;
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

  void _handleClose() {
    ref.read(projectionControllerProvider.notifier).clearSong();
    if (_isSecondaryWindow) {
      _handleManualClose();
    } else if (context.mounted) {
      context.go('/');
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
    final double activeFontSize = state.fontSize;
    final String slideKey = _isSecondaryWindow
        ? 'ipc_${_ipcText.hashCode}'
        : '${state.currentSong?.id}_${state.currentSlideIndex}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        // Tap left half = prev, tap right half = next (for mobile presenters)
        onTapUp: (details) {
          if (!_isSecondaryWindow && state.slides.length > 1) {
            if (details.localPosition.dx < context.size!.width / 2) {
              notifier.prevSlide();
            } else {
              notifier.nextSlide();
            }
          }
        },
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
                event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.space) {
              notifier.nextSlide();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              notifier.prevSlide();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _handleClose();
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

              // Centered slide text for all modes (Bible, song, secondary window)
              SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 64.0,
                      vertical: 48.0,
                    ),
                    child: Center(
                      child: activeText.isNotEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _VerseText(
                                  text: activeText,
                                  key: ValueKey(slideKey),
                                  fontSize: activeFontSize,
                                ),
                                if (activeIsBible && activeLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: _ReferenceLabel(label: activeLabel),
                                  ),
                              ],
                            )
                          : const Text(
                              'Awaiting projection…',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),

              // Close button — subtle, only shows on hover
              Positioned(
                top: 4,
                left: 4,
                child: AnimatedOpacity(
                  opacity: _isHovering ? 0.4 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: _handleClose,
                      tooltip: 'Exit projection (Esc)',
                      splashRadius: 16,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ),
              ),

              // Navigation arrows — very transparent, fade in slightly on hover
              if (state.slides.isNotEmpty)
                IgnorePointer(
                  ignoring: !_isHovering,
                  child: AnimatedOpacity(
                    opacity: _isHovering ? 0.35 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Stack(
                      children: [
                        // Prev arrow — left edge
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                _isSecondaryWindow ? Icons.chevron_left : Icons.chevron_left,
                                size: 36,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('prev');
                                } else {
                                  notifier.prevSlide();
                                }
                              },
                              splashRadius: 22,
                              hoverColor: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        // Next arrow — right edge
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                _isSecondaryWindow ? Icons.chevron_right : Icons.chevron_right,
                                size: 36,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('next');
                                } else {
                                  notifier.nextSlide();
                                }
                              },
                              splashRadius: 22,
                              hoverColor: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        // Font size controls — top-right, even more subtle
                        if (!_isSecondaryWindow)
                          Positioned(
                            top: 0,
                            right: 48,
                            child: SafeArea(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _FontSizeButton(
                                    icon: Icons.text_decrease,
                                    tooltip: 'Smaller font',
                                    onPressed: state.fontSize > 16
                                        ? () => notifier.setFontSize(state.fontSize - 4)
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '${state.fontSize.toInt()}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  _FontSizeButton(
                                    icon: Icons.text_increase,
                                    tooltip: 'Larger font',
                                    onPressed: state.fontSize < 96
                                        ? () => notifier.setFontSize(state.fontSize + 4)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
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
      ),
      ),
    );
  }
}

/// Subtle font-size button used inside projection output.
class _FontSizeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _FontSizeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 14,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      hoverColor: Colors.white.withValues(alpha: 0.08),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
    ),
    );
  }
}

/// Animated verse text with slide-up/fade transition.
class _VerseText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _VerseText({required this.text, super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
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
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: text.isNotEmpty
          ? Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white,
                fontSize: fontSize,
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
                    color: const Color(0xFF00E5CC).withValues(alpha: 0.12),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Teal-coloured reference label shown below a Bible verse.
class _ReferenceLabel extends StatelessWidget {
  final String label;

  const _ReferenceLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        label,
        key: ValueKey('ref_$label'),
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
    );
  }
}

/// Scrollable chapter reference panel with auto-center and edge fades.

