import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';
import 'package:visual_song_book/data/models/verse.dart';
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
    final double activeFontSize = state.fontSize;
    final String slideKey = _isSecondaryWindow
        ? 'ipc_${_ipcText.hashCode}'
        : '${state.currentSong?.id}_${state.currentSlideIndex}';

    return GestureDetector(
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
              notifier.clearSong();
              if (!_isSecondaryWindow && context.mounted) {
                Navigator.of(context).pop();
              }
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

              // Bible mode: full chapter on left, current verse on right
              if (activeIsBible && !_isSecondaryWindow)
                SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _ChapterReferencePanel(
                          slides: state.slides,
                          currentIndex: state.currentSlideIndex,
                          onSelectVerse: (i) => notifier.selectSlide(i),
                        ),
                      ),
                      Container(
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 48,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _VerseText(
                                  text: activeText,
                                  key: ValueKey(slideKey),
                                  fontSize: activeFontSize,
                                ),
                                if (activeLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: _ReferenceLabel(label: activeLabel),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Song mode / secondary window: centered slide text
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
                      ),
                    ),
                  ),
                ),

              // Minimalist controls for primary window (mobile/web/desktop)
              if (!_isSecondaryWindow) ...[
                // Close button — top-left corner, very small
                Positioned(
                  top: 4,
                  left: 4,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white30, size: 16),
                      onPressed: () {
                        notifier.clearSong();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      tooltip: 'Exit projection (Esc)',
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ),
                // Prev button — bottom-left corner
                if (state.slides.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 4,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white30, size: 20),
                        onPressed: notifier.prevSlide,
                        tooltip: 'Previous slide',
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ),
                // Next button — bottom-right corner
                if (state.slides.length > 1)
                  Positioned(
                    bottom: 8,
                    right: 4,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
                        onPressed: notifier.nextSlide,
                        tooltip: 'Next slide',
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ),
              ],

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
class _ChapterReferencePanel extends StatefulWidget {
  final List<Verse> slides;
  final int currentIndex;
  final ValueChanged<int> onSelectVerse;

  const _ChapterReferencePanel({
    required this.slides,
    required this.currentIndex,
    required this.onSelectVerse,
  });

  @override
  State<_ChapterReferencePanel> createState() => _ChapterReferencePanelState();
}

class _ChapterReferencePanelState extends State<_ChapterReferencePanel> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtTop = true;
  bool _isAtBottom = false;

  @override
  void didUpdateWidget(covariant _ChapterReferencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients || widget.slides.isEmpty) return;
    final proportion = widget.currentIndex / widget.slides.length;
    final target = proportion * _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                setState(() {
                  _isAtTop = _scrollController.offset <= 0;
                  _isAtBottom = _scrollController.offset >= _scrollController.position.maxScrollExtent;
                });
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 28, 12, 28),
              itemCount: widget.slides.length,
              itemBuilder: (context, index) {
                final verse = widget.slides[index];
                final isCurrent = index == widget.currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: GestureDetector(
                    onTap: () => widget.onSelectVerse(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF00E5CC).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isCurrent
                            ? Border.all(
                                color: const Color(0xFF00E5CC).withValues(alpha: 0.25),
                                width: 0.5,
                              )
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${verse.order}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFF00E5CC)
                                    : Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              verse.text,
                              style: TextStyle(
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                fontSize: 12,
                                fontFamily: 'Outfit',
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Top edge fade — subtle at chapter start
          if (!_isAtTop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Bottom edge fade — chapter-end visual cue
          if (!_isAtBottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 40,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // End-of-chapter marker when scrolled to bottom
          if (_isAtBottom && widget.slides.isNotEmpty)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5CC).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'End of Chapter ${widget.slides.last.label.split(':').first.split(' ').lastOrNull ?? ''}',
                      style: TextStyle(
                        color: const Color(0xFF00E5CC).withValues(alpha: 0.5),
                        fontSize: 9,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Start-of-chapter marker when scrolled to top
          if (_isAtTop && widget.slides.isNotEmpty)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    widget.slides.first.label.split(':').firstOrNull ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.12),
                      fontSize: 10,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
