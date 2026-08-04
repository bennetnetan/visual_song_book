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

class _ProjectionOutputViewState extends ConsumerState<ProjectionOutputView> {
  String _ipcText = '';
  String _ipcLabel = '';
  bool _ipcIsBible = false;
  double? _ipcFontSize;
  List<String> _ipcSlideLabels = const [];
  bool _isSecondaryWindow = false;
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

    // 'single' mode opens a normal decorated window on the primary display —
    // no auto-fullscreen, no placement, no decoration stripping.
    final isExtendedMode =
        ref.read(projectionWindowModeProvider) != 'single';

    if (isProjectionEngine) {
      _setupSecondaryWindowChannel();

      // ── Windows: kick off decoration-strip as early as possible (before
      // the first frame) so the title bar flash is minimised. The call is
      // fire-and-forget here; _setupSecondaryWindowChannel will repeat it
      // once the window handle is reliably available.
      if (Platform.isWindows && isExtendedMode) {
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
      if (Platform.isWindows && isExtendedMode) {
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
    // Skipped in 'single' mode (normal decorated window on the primary display).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer.run(() {
        if (!mounted) return;
        if (ref.read(projectionWindowModeProvider) != 'single') {
          _goFullscreenOnBestDisplay();
        }
      });
    });

    controller.setWindowMethodHandler((call) async {
      if (call.method == 'update_slide') {
        if (!mounted) return null;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _isClosing = false;
          if (args['text'] != null) _ipcText = args['text'] as String;
          if (args['label'] != null) _ipcLabel = args['label'] as String;
          if (args['isBible'] != null) _ipcIsBible = args['isBible'] as bool;
          if (args['fontSize'] != null) {
            _ipcFontSize = (args['fontSize'] as num).toDouble();
          }
          if (args['slideLabels'] != null) {
            _ipcSlideLabels =
                (args['slideLabels'] as List).cast<String>();
          }
        });
      } else if (call.method == 'go_fullscreen') {
        // Only enter fullscreen if we haven't already — prevents double
        // fullscreen from both the init path and the controller's fallback IPC.
        // Skipped in 'single' mode.
        if (!_isGoingFullscreen &&
            _originalWindowStyle == 0 &&
            ref.read(projectionWindowModeProvider) != 'single') {
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
    } catch (_) {
      // ignore: non-critical IPC navigation
    }
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
    } catch (_) {
      // ignore: non-critical IPC close notification
    }
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
    } catch (_) {
      // ignore: non-critical IPC close request
    }
  }

  @override
  void dispose() {
    if (_focusListener != null) {
      _focusNode.removeListener(_focusListener!);
    }
    _focusNode.dispose();
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
          if (_pinchActive) {
            notifier.persistFontSize();
          } else {
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

              // Navigation arrows — mobile fullscreen only.
              // Desktop projection screens stay clean: the operator navigates
              // from the main window (buttons / keyboard), so no overlay arrows.
              if (slideCount > 0 && _isMobile)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: 0.38,
                    duration: const Duration(milliseconds: 400),
                    child: Stack(
                      children: [
                        // Prev arrow — left edge
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_left,
                                size: 44,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('prev');
                                } else {
                                  notifier.prevSlide();
                                }
                              },
                              splashRadius: 32,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        // Next arrow — right edge
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_right,
                                size: 44,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isSecondaryWindow) {
                                  _sendNavigateToMain('next');
                                } else {
                                  notifier.nextSlide();
                                }
                              },
                              splashRadius: 32,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Font size controls — desktop only (top-right, hover-gated).
              // Mobile uses pinch-to-zoom instead.
              if (!_isSecondaryWindow && !_isMobile)
                Positioned(
                  top: 0,
                  right: 48,
                  child: SafeArea(
                    child: IgnorePointer(
                      ignoring: !_isHovering,
                      child: AnimatedOpacity(
                        opacity: _isHovering ? 0.4 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FontSizeButton(
                              icon: Icons.text_decrease,
                              tooltip: 'Smaller font',
                              onPressed: state.fontSize > 16
                                  ? () {
                                      notifier.setFontSize(state.fontSize - 4);
                                      notifier.persistFontSize();
                                    }
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
                              onPressed: state.fontSize < 160
                                  ? () {
                                      notifier.setFontSize(state.fontSize + 4);
                                      notifier.persistFontSize();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
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

              // Position indicator — mobile fullscreen only (bottom bar above).
              // Hidden on desktop (Linux / macOS / Windows) so the projection
              // screen shows lyrics alone.
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

/// Scrollable chapter reference panel with auto-center and edge fades.
