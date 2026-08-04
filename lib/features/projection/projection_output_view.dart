import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:go_router/go_router.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/win32_window_helper.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class ProjectionOutputView extends ConsumerStatefulWidget {
  const ProjectionOutputView({super.key});

  @override
  ConsumerState<ProjectionOutputView> createState() =>
      _ProjectionOutputViewState();
}

class _ProjectionOutputViewState extends ConsumerState<ProjectionOutputView>
    with SingleTickerProviderStateMixin {
  String _ipcText = '';
  String _ipcLabel = '';
  bool _ipcIsBible = false;
  double? _ipcFontSize;
  List<String> _ipcSlideLabels = const [];
  int _ipcCurrentIndex = 0;
  bool _isSecondaryWindow = false;
  late AnimationController _fadeController;
  late final FocusNode _focusNode;
  bool _isClosing = false;
  bool _isHovering = false;
  int _originalWindowStyle = 0;
  bool _isGoingFullscreen = false;
  VoidCallback? _focusListener; // re-asserts fullscreen on window focus gain

  double _baseFontSize = 40.0;
  bool _pinchActive = false;
  Offset _panStartOffset = Offset.zero;
  double _panDeltaX = 0.0;

  /// True on Android and iOS — used to select mobile-friendly UI variants
  /// (always-visible controls rather than hover-gated desktop controls).
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode(debugLabel: 'ProjectionOutputFocus');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeController.forward();

    // On Mobile/Web, hide the status/navigation bar for a fully immersive experience
    if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }

    // Only the dedicated projection engine is a "secondary window". The main
    // window also renders this view on the /projection route (small desktop
    // windows, web, or when the secondary window fails to open) — in that case
    // it must NOT claim the IPC channel (which would clobber the main window's
    // handler), go fullscreen, or hide its chrome.
    final isProjectionEngine = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
        ref.read(isProjectionWindowProvider);

    if (isProjectionEngine) {
      _setupSecondaryWindowChannel();

      // ── Windows: kick off decoration-strip as early as possible (before
      // the first frame) so the title bar flash is minimised. The call is
      // fire-and-forget here; _setupSecondaryWindowChannel will repeat it
      // once the window handle is reliably available.
      if (Platform.isWindows) {
        enterBorderlessFullscreenCurrentWindow().then((style) {
          if (style != 0 && mounted) {
            _originalWindowStyle = style;
            debugPrint('Early Win32 decoration strip succeeded (style=$style).');
          }
        }).catchError((_) {});
      }

      // On Windows, re-assert borderless fullscreen whenever the projection
      // window regains focus. This handles accidental drags, ALT+TAB
      // sequences, and display-configuration changes that drop fullscreen.
      if (Platform.isWindows) {
        _focusListener = () {
          if (_focusNode.hasFocus && _originalWindowStyle != 0) {
            // Re-apply borderless fullscreen style + position.
            // Use a microtask to avoid calling Win32 inside the focus
            // notification itself (can cause re-entrant Win32 calls).
            Future.microtask(() => _goFullscreenOnBestDisplay(isReAssertion: true));
          }
        };
        _focusNode.addListener(_focusListener!);
      }
    }
  }

  void _setupSecondaryWindowChannel() async {
    final controller = await WindowController.fromCurrentEngine();
    if (!mounted) return;

    setState(() {
      _isSecondaryWindow = true;
    });

    // Request fullscreen + move to screen 2 once the window is ready.
    // Defer with Timer.run to avoid calling Win32 SetWindowPos inside
    // Flutter's frame lifecycle, which causes scheduler reentrancy errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer.run(() {
        if (!mounted) return;
        _goFullscreenOnBestDisplay();
      });
    });

    controller.setWindowMethodHandler((call) async {
      if (call.method == 'update_slide') {
        if (!mounted) return null;
        setState(() {
          _isClosing = false;
          if (call.arguments['text'] != null) _ipcText = call.arguments['text'] as String;
          if (call.arguments['label'] != null) _ipcLabel = call.arguments['label'] as String;
          if (call.arguments['isBible'] != null) _ipcIsBible = call.arguments['isBible'] as bool;
          if (call.arguments['fontSize'] != null) {
            _ipcFontSize = (call.arguments['fontSize'] as num).toDouble();
          }
          if (call.arguments['slideLabels'] != null) {
            _ipcSlideLabels =
                (call.arguments['slideLabels'] as List).cast<String>();
          }
          if (call.arguments['currentIndex'] != null) {
            _ipcCurrentIndex = (call.arguments['currentIndex'] as num).toInt();
          }
        });
      } else if (call.method == 'go_fullscreen') {
        // Only enter fullscreen if we haven't already — prevents double
        // fullscreen from both the init path and the controller's fallback IPC.
        if (!_isGoingFullscreen && _originalWindowStyle == 0) {
          await _goFullscreenOnBestDisplay();
        }
      }
      return 'OK';
    });

    // Notify main window that secondary window is ready to receive updates.
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final controllers = await WindowController.getAll();
        final currentWindow = await WindowController.fromCurrentEngine();
        for (final c in controllers) {
          if (c.windowId == currentWindow.windowId) continue;
          await c.invokeMethod('secondary_window_ready');
        }
        break; // Success
      } catch (e) {
        debugPrint('Secondary window ready notification attempt $attempt failed: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Enters borderless fullscreen automatically when window opens.
  /// On re-assertion (after focus regain), we only re-apply the size/position
  /// without overwriting [_originalWindowStyle] so the exit-restore stays valid.
  Future<void> _goFullscreenOnBestDisplay({bool isReAssertion = false}) async {
    if (_isGoingFullscreen) return; // Guard against concurrent calls
    _isGoingFullscreen = true;
    try {
      if (Platform.isWindows) {
        try {
          if (!isReAssertion) {
            // First call: strip decorations AND save original style.
            _originalWindowStyle = await enterBorderlessFullscreenCurrentWindow();
            if (_originalWindowStyle != 0) {
              debugPrint('Projection window entered borderless fullscreen via Win32 API.');
            } else {
              // Fallback to maximized if borderless fullscreen failed.
              await maximizeCurrentWindow();
              debugPrint('Projection window maximized (borderless fullscreen failed).');
            }
          } else if (_originalWindowStyle != 0) {
            // Re-assertion: style already stripped; just reposition the window
            // to fill the monitor (handles resolution changes / dragged windows).
            await enterBorderlessFullscreenCurrentWindow();
            debugPrint('Projection window re-asserted borderless fullscreen.');
          }
        } catch (e) {
          debugPrint('_goFullscreenOnBestDisplay error: $e');
        }
      }
    } finally {
      _isGoingFullscreen = false;
    }
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

  void onWindowClose() async {
    await _handleManualClose();
  }

  void _handleClose() {
    ref.read(projectionControllerProvider.notifier).clearSong();
    if (_isSecondaryWindow) {
      _handleManualClose();
    } else if (context.mounted) {
      context.go('/');
    }
  }

  void _notifyClosed() async {
    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      for (final c in controllers) {
        if (c.windowId == currentWindow.windowId) continue;
        await c.invokeMethod('secondary_window_closed');
      }
    } catch (_) {}
  }

  Future<void> _handleManualClose() async {
    if (_isClosing) return;
    _isClosing = true;

    // Restore window style before closing so the hide/cleanup is clean
    if (_originalWindowStyle != 0) {
      exitBorderlessFullscreenCurrentWindow(_originalWindowStyle);
      _originalWindowStyle = 0;
    }

    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      for (final c in controllers) {
        if (c.windowId == currentWindow.windowId) continue;
        await c.invokeMethod('close_secondary_window');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_focusListener != null) {
      _focusNode.removeListener(_focusListener!);
    }
    _focusNode.dispose();
    _fadeController.dispose();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    // Restore window style if we were in borderless fullscreen
    if (_originalWindowStyle != 0) {
      exitBorderlessFullscreenCurrentWindow(_originalWindowStyle);
      _originalWindowStyle = 0;
    }
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (_isSecondaryWindow) {
        _notifyClosed();
      }
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
    final double activeFontSize = _isSecondaryWindow
        ? (_ipcFontSize ?? state.fontSize)
        : state.fontSize;
    final String slideKey = _isSecondaryWindow
        ? 'ipc_${_ipcText.hashCode}'
        : '${state.currentSong?.id}_${state.currentSlideIndex}';

    // Slide list length/position. In the secondary engine the projection
    // controller is never populated, so we use the values relayed over IPC.
    final int slideCount = _isSecondaryWindow
        ? _ipcSlideLabels.length
        : state.slides.length;
    final int slideIndex = _isSecondaryWindow
        ? _ipcCurrentIndex
        : state.currentSlideIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Tap left half = prev, tap right half = next (for mobile presenters)
        onTapUp: (details) {
          _focusNode.requestFocus();
          if (!_isSecondaryWindow && state.slides.length > 1) {
            if (details.localPosition.dx < context.size!.width / 2) {
              notifier.prevSlide();
            } else {
              notifier.nextSlide();
            }
          }
        },
        // Pinch-to-zoom (scale font size) + Pan to swipe left/right (unified implementation to prevent gestures conflicts)
        onScaleStart: (details) {
          _baseFontSize = activeFontSize;
          _pinchActive = false;
          _panStartOffset = details.localFocalPoint;
          _panDeltaX = 0.0;
        },
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            _pinchActive = true;
            final newSize = (_baseFontSize * details.scale).clamp(16.0, 160.0);
            notifier.setFontSize(newSize);
          } else if (details.pointerCount == 1) {
            _panDeltaX = details.localFocalPoint.dx - _panStartOffset.dx;
          }
        },
        onScaleEnd: (details) {
          if (!_pinchActive) {
            // Check horizontal swipe gesture threshold
            if (_panDeltaX.abs() > 60.0) {
              if (_panDeltaX < 0) {
                if (_isSecondaryWindow) {
                  _sendNavigateToMain('next');
                } else {
                  notifier.nextSlide();
                }
              } else {
                if (_isSecondaryWindow) {
                  _sendNavigateToMain('prev');
                } else {
                  notifier.prevSlide();
                }
              }
            }
          }
        },
        child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.pageDown ||
                event.logicalKey == LogicalKeyboardKey.space) {
              if (_isSecondaryWindow) {
                _sendNavigateToMain('next');
              } else {
                notifier.nextSlide();
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.pageUp) {
              if (_isSecondaryWindow) {
                _sendNavigateToMain('prev');
              } else {
                notifier.prevSlide();
              }
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

              // Centered slide text + Bible reference tightly attached 20px below
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64.0,
                    vertical: 48.0,
                  ),
                  child: Center(
                    child: activeText.isNotEmpty
                        ? VerseText(
                            text: activeText,
                            referenceLabel: activeIsBible ? activeLabel : null,
                            key: ValueKey(slideKey),
                            fontSize: activeFontSize,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // Close button:
              //   • Desktop  — fades in on hover (subtle, out-of-the-way)
              //   • Mobile   — always visible at low opacity so the audience
              //                presenter can tap to exit at any time
              Positioned(
                top: 4,
                left: 4,
                child: AnimatedOpacity(
                  opacity: _isMobile ? 0.45 : (_isHovering ? 0.4 : 0.0),
                  duration: const Duration(milliseconds: 300),
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: _handleClose,
                      tooltip: 'Exit projection (Esc)',
                      splashRadius: 20,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                ),
              ),

              // Navigation arrows:
              //   • Desktop  — hover-gated (hidden until mouse moves over)
              //   • Mobile   — always visible at low opacity, always interactive,
              //                with larger hit-targets for touch
              if (slideCount > 0)
                IgnorePointer(
                  // Mobile: always interactive. Desktop: gate on hover.
                  ignoring: _isMobile ? false : !_isHovering,
                  child: AnimatedOpacity(
                    opacity: _isMobile ? 0.38 : (_isHovering ? 0.35 : 0.0),
                    duration: const Duration(milliseconds: 400),
                    child: Stack(
                      children: [
                        // Prev arrow — left edge
                        Positioned(
                          left: _isMobile ? 0 : 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_left,
                                size: _isMobile ? 44 : 36,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('prev');
                                } else {
                                  notifier.prevSlide();
                                }
                              },
                              splashRadius: _isMobile ? 32 : 22,
                              padding: _isMobile
                                  ? const EdgeInsets.all(12)
                                  : const EdgeInsets.all(8),
                              hoverColor: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        // Next arrow — right edge
                        Positioned(
                          right: _isMobile ? 0 : 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_right,
                                size: _isMobile ? 44 : 36,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('next');
                                } else {
                                  notifier.nextSlide();
                                }
                              },
                              splashRadius: _isMobile ? 32 : 22,
                              padding: _isMobile
                                  ? const EdgeInsets.all(12)
                                  : const EdgeInsets.all(8),
                              hoverColor: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        // Font size controls — desktop only (top-right, hover-gated).
                        // Mobile has its own always-visible font bar below.
                        if (!_isSecondaryWindow && !_isMobile)
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

              // Mobile-only: always-visible bottom bar with a slide-count chip.
              // Font controls removed in favor of pinch-to-zoom.
              if (_isMobile && !_isSecondaryWindow && state.slides.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Slide position indicator  e.g. "3 / 12"
                          Text(
                            '${state.currentSlideIndex + 1} / ${state.slides.length}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Slide indicator dots / timeline:
              //   • Secondary desktop window — dot row, hover-gated
              //   • Desktop main  — text timeline, hover-gated but always faintly visible
              //   • Mobile        — text timeline hidden (replaced by bottom bar above)
              if (slideCount > 0 && !(_isMobile && !_isSecondaryWindow))
                Positioned(
                  bottom: _isSecondaryWindow ? 96 : 14,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isSecondaryWindow
                        ? (_isHovering ? 0.4 : 0.0)
                        : (_isHovering ? 0.65 : 0.18),
                    duration: const Duration(milliseconds: 300),
                    child: _isSecondaryWindow
                        ? _SlideIndicator(
                            count: slideCount,
                            current: slideIndex,
                          )
                        : _SlideTextTimeline(
                            slides: state.slides,
                            current: state.currentSlideIndex,
                          ),
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

/// Creative horizontal timeline displaying short labels for verses/slides
class _SlideTextTimeline extends StatefulWidget {
  final List<dynamic> slides;
  final int current;

  const _SlideTextTimeline({required this.slides, required this.current});

  @override
  State<_SlideTextTimeline> createState() => _SlideTextTimelineState();
}

class _SlideTextTimelineState extends State<_SlideTextTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SlideTextTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      const itemWidth = 80.0;
      const horizontalMargin = 8.0; // 4.0 on left, 4.0 on right
      const totalItemWidth = itemWidth + horizontalMargin;

      // Center of the active item
      final centerOfItem = (widget.current * totalItemWidth) + (totalItemWidth / 2);

      // Get the width of the scroll view viewport
      final double viewportWidth = _scrollController.position.viewportDimension;
      final maxScroll = _scrollController.position.maxScrollExtent;

      final targetOffset = (centerOfItem - (viewportWidth / 2)).clamp(0.0, maxScroll);

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scroll to current on first build to center the initial slide
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());

    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 80.0;
        const totalItemWidth = 88.0; // 80 + 8
        final double horizontalPadding = (constraints.maxWidth - totalItemWidth) / 2;

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding > 0 ? horizontalPadding : 32.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.slides.length, (index) {
              final isActive = index == widget.current;
              final slide = widget.slides[index];

              String shortLabel = slide.label;
              if (shortLabel.toLowerCase().startsWith('verse')) {
                final parts = shortLabel.split(' ');
                shortLabel = parts.length > 1 ? 'V${parts[1]}' : 'Verse';
              } else if (shortLabel.toLowerCase().startsWith('chorus')) {
                shortLabel = 'Chorus';
              } else if (shortLabel.toLowerCase().startsWith('refrain')) {
                shortLabel = 'Ref';
              } else {
                // For Bible references, e.g. "Genesis 1:1" -> "v1" or "1"
                final colonIdx = shortLabel.lastIndexOf(':');
                if (colonIdx != -1) {
                  shortLabel = 'v${shortLabel.substring(colonIdx + 1)}';
                }
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: itemWidth,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF00E5CC).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00E5CC).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF00E5CC) : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}


/// Scrollable chapter reference panel with auto-center and edge fades.
