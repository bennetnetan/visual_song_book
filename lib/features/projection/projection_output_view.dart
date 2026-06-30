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
  double? _ipcFontSize;
  bool _isSecondaryWindow = false;
  late AnimationController _fadeController;
  late final FocusNode _focusNode;
  bool _isClosing = false;
  bool _isHovering = false;

  double _baseFontSize = 40.0;
  bool _pinchActive = false;
  Offset _panStartOffset = Offset.zero;
  double _panDeltaX = 0.0;

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
    }

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _setupSecondaryWindowChannel();
      if (!Platform.isLinux) {
        windowManager.addListener(this);
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
          _isClosing = false;
          if (call.arguments['text'] != null) _ipcText = call.arguments['text'] as String;
          if (call.arguments['label'] != null) _ipcLabel = call.arguments['label'] as String;
          if (call.arguments['isBible'] != null) _ipcIsBible = call.arguments['isBible'] as bool;
          if (call.arguments['fontSize'] != null) {
            _ipcFontSize = (call.arguments['fontSize'] as num).toDouble();
          }
        });
        debugPrint('Updated secondary window text: "$_ipcText" label: "$_ipcLabel" fontSize: $_ipcFontSize');
      }
      return 'OK';
    });

    // Notify main window that secondary window is ready to receive updates.
    // We retry a few times because immediately after window creation (or during
    // hot restart), the plugin channels might not be fully registered yet,
    // throwing MissingPluginException.
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final controllers = await WindowController.getAll();
        final currentWindow = await WindowController.fromCurrentEngine();
        for (final c in controllers) {
          if (c.windowId == currentWindow.windowId) continue;
          await c.invokeMethod('secondary_window_ready');
          debugPrint('Notified main window (ID: ${c.windowId}) that secondary window is ready.');
        }
        break; // Success
      } catch (e) {
        debugPrint('Failed to send secondary_window_ready signal: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
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

  @override
  void onWindowClose() async {
    if (!Platform.isLinux) {
      await _handleManualClose();
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

    if (Platform.isLinux) {
      // On Linux, calling windowManager.close() or hide() from the secondary
      // window crashes the app because window_manager targets the main window's
      // GTK handle. Instead, we ask the main window to hide us via IPC — the
      // main window uses WindowController.hide() which is safe.
      try {
        final controllers = await WindowController.getAll();
        final currentWindow = await WindowController.fromCurrentEngine();
        for (final c in controllers) {
          if (c.windowId == currentWindow.windowId) continue;
          await c.invokeMethod('close_secondary_window');
        }
      } catch (_) {}
    } else {
      // On Windows/macOS, window_manager is scoped to this window correctly.
      try {
        await windowManager.hide();
      } catch (_) {}
      _notifyClosed();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _fadeController.dispose();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!Platform.isLinux) {
        windowManager.removeListener(this);
      }
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
          if (details.pointerCount > 1) {
            _pinchActive = true;
            final newSize = (_baseFontSize * details.scale).clamp(16.0, 160.0);
            notifier.setFontSize(newSize);
          } else {
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
                                Expanded(
                                  child: Center(
                                    child: _VerseText(
                                      text: activeText,
                                      key: ValueKey(slideKey),
                                      fontSize: activeFontSize,
                                    ),
                                  ),
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

              // Slide indicator dots or timeline at the bottom — subtle, always visible at low opacity on main controls
              if (state.slides.isNotEmpty)
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
                            count: state.slides.length,
                            current: state.currentSlideIndex,
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


/// Animated verse text with slide-up/fade transition and auto-fit to container size.
class _VerseText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _VerseText({required this.text, super.key, required this.fontSize});

  double _calculateDefaultFontSize(String text, Size size) {
    if (text.isEmpty) return 40.0;

    // Available bounds inside padding
    final double availWidth = (size.width - 24).clamp(100.0, 10000.0);
    final double availHeight = (size.height - 24).clamp(100.0, 10000.0);

    // Estimate line count and max characters per line if we wrap text
    final List<String> paragraphs = text.split('\n');
    int totalEstimatedLines = 0;
    int maxCharsPerLine = 0;

    // We assume standard wrapping occurs at around 45 characters per line on a typical presentation screen
    const int wrapThreshold = 45;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= wrapThreshold) {
        totalEstimatedLines += 1;
        if (trimmed.length > maxCharsPerLine) {
          maxCharsPerLine = trimmed.length;
        }
      } else {
        // Estimate how many wrapped lines this paragraph will create
        final int wrappedCount = (trimmed.length / wrapThreshold).ceil();
        totalEstimatedLines += wrappedCount;
        maxCharsPerLine = wrapThreshold;
      }
    }

    if (totalEstimatedLines == 0) totalEstimatedLines = 1;
    if (maxCharsPerLine == 0) maxCharsPerLine = 10;

    // Calculate max font size based on lines height
    // Outfit font height is approx 1.35. Let's use 1.45 for layout safety
    final double sizeByHeight = availHeight / (totalEstimatedLines * 1.45);

    // Calculate max font size based on characters width in longest line
    // Outfit width is approx 0.55 * fontSize
    final double sizeByWidth = availWidth / (maxCharsPerLine * 0.55);

    // Get the limiting constraint
    double baseSize = sizeByHeight < sizeByWidth ? sizeByHeight : sizeByWidth;

    // Clamp to a reasonable baseline range
    return baseSize.clamp(20.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Calculate the base fitted size
        final double baseFontSize = _calculateDefaultFontSize(text, size);
        
        // Treat 40.0 as the baseline setting. Scale factor is (fontSize / 40.0)
        final double scaleFactor = fontSize / 40.0;
        final double finalFontSize = (baseFontSize * scaleFactor).clamp(14.0, 180.0);

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
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: finalFontSize,
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
      },
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

