import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import 'package:go_router/go_router.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/projection/projection_appearance_widgets.dart';
import 'package:visual_song_book/features/projection/projection_media_backgrounds.dart';
import 'package:visual_song_book/features/projection/projection_preview.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/widgets/lower_third_overlay.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';

final _log = AppLogger.get('ProjectionOutputView');

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
  int _ipcCurrentIndex = 0;
  ProjectionTheme _ipcTheme = const ProjectionTheme();
  LowerThirdState _ipcLowerThirdState = LowerThirdState.initial();
  bool _isSecondaryWindow = false;
  late final FocusNode _focusNode;
  bool _isClosing = false;
  bool _isHovering = false;
  bool _isCloseHovered = false;

  double _baseFontSize = 40.0;
  bool _pinchActive = false;
  Offset _panStartOffset = Offset.zero;
  double _panDeltaX = 0.0;

  /// Advances the media background every tick when timed rotation is on.
  int _mediaCycleIndex = 0;
  Timer? _mediaTimer;

  /// Whether the projection is currently locked to portrait orientation.
  /// Defaults to false so behaviour matches the historic landscape lock.
  bool _isPortraitMode = false;

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

    if (isProjectionEngine) {
      _initializeProjectionEngine();
    }
  }

  Future<void> _initializeProjectionEngine() async {
    // Initialize window_manager for the projection engine so we can control
    // fullscreen state when Dart-side IPC asks for it.
    //
    // NOTE: window_manager is only registered in secondary engines on Linux
    // (the runner registers plugins there). On Windows and macOS the native
    // runner already places + fullscreens the projection window, so this
    // init is best-effort: it typically throws/fails there, which is expected.
    // The timeout guarantees we never block the IPC channel setup on platforms
    // where window_manager is unavailable.
    try {
      await windowManager.ensureInitialized().timeout(
            const Duration(seconds: 2),
          );
      await windowManager.setTitle('Visual Song Book - Projection');
    } catch (e) {
      _log.fine('window_manager unavailable in projection engine (expected on '
          'Windows/macOS): $e');
    }
    _setupSecondaryWindowChannel();
  }

  void _setupSecondaryWindowChannel() async {
    WindowController? controller;
    try {
      controller = await WindowController.fromCurrentEngine();
    } catch (e) {
      // desktop_multi_window plugin channel may not be ready yet in the
      // secondary engine. Retry with increasing delays.
      _log.warning('WindowController.fromCurrentEngine failed (attempting retry): $e');
      for (var attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        try {
          controller = await WindowController.fromCurrentEngine();
          break;
        } catch (e2) {
          _log.warning('Retry $attempt failed: $e2');
        }
      }
      if (controller == null) {
        _log.severe('Failed to get WindowController after retries. IPC disabled.');
        return;
      }
    }
    if (!mounted) return;

    setState(() {
      _isSecondaryWindow = true;
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
          if (args['currentIndex'] != null) {
            _ipcCurrentIndex = (args['currentIndex'] as num).toInt();
          }
          if (args['slideTheme'] != null) {
            _ipcTheme = ProjectionTheme.fromJson(
              Map<String, dynamic>.from(args['slideTheme'] as Map),
            );
          }
        });
      } else if (call.method == 'update_lower_third') {
        if (!mounted) return null;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _ipcLowerThirdState = LowerThirdState.fromJson(args);
        });
      } else if (call.method == 'go_fullscreen') {
        if (!mounted) return null;
        _log.fine('Received go_fullscreen IPC, entering fullscreen...');
        try {
          await windowManager.setFullScreen(true).timeout(
                const Duration(seconds: 2),
              );
          _log.fine('Successfully entered fullscreen mode');
        } catch (e, st) {
          _log.fine('Fullscreen IPC skipped (window_manager unavailable?): $e',
              e, st);
        }
      } else if (call.method == 'set_window_bounds') {
        if (!mounted) return null;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _log.fine('Received set_window_bounds IPC: $args');
        try {
          final left = (args['left'] as num?)?.toDouble() ?? 0;
          final top = (args['top'] as num?)?.toDouble() ?? 0;
          final width = (args['width'] as num?)?.toDouble() ?? 800;
          final height = (args['height'] as num?)?.toDouble() ?? 600;
          await windowManager.setPosition(Offset(left, top)).timeout(
                const Duration(seconds: 2),
              );
          await windowManager.setSize(Size(width, height)).timeout(
                const Duration(seconds: 2),
              );
          _log.fine(
              'Positioned window at ($left, $top) with size ${width}x$height');
        } catch (e, st) {
          _log.fine('set_window_bounds IPC skipped (window_manager '
              'unavailable?): $e', e, st);
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

  void _showMobileSetPlaylistSheet(BuildContext context, WidgetRef ref) {
    final setsState = ref.read(setsControllerProvider);
    final projectionState = ref.read(projectionControllerProvider);
    final theme = Theme.of(context);
    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;

    if (setObj == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.playlist_play, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      setObj.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${setsState.setItems.length} songs',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: setsState.setItems.length,
                  itemBuilder: (context, i) {
                    final item = setsState.setItems[i];
                    final song = setsState.availableSongs
                        .where((s) => s.id == item.songId)
                        .firstOrNull;
                    if (song == null) return const SizedBox.shrink();

                    // Check if current slide belongs to this song
                    final currentSlide = projectionState.currentSlide;
                    final isCurrentSong = currentSlide?.songTitle == song.title;
                    final keyText = item.key ?? song.key;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrentSong
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrentSong
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentSong ? theme.colorScheme.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.notes != null && item.notes!.isNotEmpty
                          ? Text(
                              '📝 ${item.notes!}',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: keyText != null && keyText.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                keyText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        // Jump to first slide of this song in the projected sequence
                        final slideIdx = projectionState.slides.indexWhere(
                          (v) => v.songTitle == song.title,
                        );
                        if (slideIdx >= 0) {
                          ref.read(projectionControllerProvider.notifier).selectSlide(slideIdx);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggles the mobile projection between landscape and portrait full-screen.
  /// Mobile only: desktop projection windows manage their own size/fullscreen.
  Future<void> _toggleOrientation() async {
    final goPortrait = !_isPortraitMode;
    setState(() => _isPortraitMode = goPortrait);
    await SystemChrome.setPreferredOrientations(goPortrait
        ? [DeviceOrientation.portraitUp]
        : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  /// Opens a floating appearance sheet (mobile only) with a live preview that
  /// reflows for portrait/landscape, a commit button, and restore defaults.
  void _openProjectionAppearance() {
    if (_isSecondaryWindow) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProjectionAppearanceSheet(),
    );
  }

  Future<void> _sendNavigateToMain(String action) async {
    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      for (final c in controllers) {
        if (c.windowId == currentWindow.windowId) continue;
        await c.invokeMethod('navigate_slide', {'action': action});
      }
    } catch (e, st) {
      // ignore: non-critical IPC navigation
      _log.fine('Failed to send IPC navigation request to secondary window: $e', e, st);
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
    } catch (e, st) {
      // ignore: non-critical IPC close notification
      _log.fine('Failed to notify main window of secondary window close: $e', e, st);
    }
  }

  Future<void> _handleManualClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      for (final c in controllers) {
        if (c.windowId == currentWindow.windowId) continue;
        await c.invokeMethod('close_secondary_window');
      }
    } catch (e, st) {
      // ignore: non-critical IPC close request
      _log.fine('Failed to request secondary window close via IPC: $e', e, st);
    }
  }

  /// Starts (or stops) the background rotation timer so it tracks the active
  /// theme. Idempotent — safe to call from every build.
  void _syncMediaTimer(ProjectionTheme theme) {
    final needsTimer =
        theme.mediaRotationMode == MediaRotationMode.timed &&
        (theme.imagePaths.length > 1 || theme.videoPaths.length > 1);
    if (needsTimer && _mediaTimer == null) {
      _mediaTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() => _mediaCycleIndex++);
      });
    } else if (!needsTimer && _mediaTimer != null) {
      _mediaTimer!.cancel();
      _mediaTimer = null;
    }
  }

  @override
  void dispose() {
    _mediaTimer?.cancel();
    _mediaTimer = null;
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

    // The secondary engine receives its theme over IPC (its controller state
    // is never populated); every other window reads the live provider.
    final ProjectionTheme projTheme = _isSecondaryWindow
        ? _ipcTheme
        : ref.watch(projectionThemeProvider);

    final LowerThirdState lowerThirdState = _isSecondaryWindow
        ? _ipcLowerThirdState
        : ref.watch(lowerThirdControllerProvider);

    final double lowerThirdClearance = (lowerThirdState.isEnabled && lowerThirdState.hasActiveItem)
        ? (lowerThirdState.config.height.clamp(lowerThirdState.config.fontSize + 24.0, 300.0) +
            (lowerThirdState.config.isFloating ? 24.0 : 12.0))
        : 0.0;

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

    final int activeSlideIndex = _isSecondaryWindow
        ? _ipcCurrentIndex
        : state.currentSlideIndex;

    // Keep the timed-rotation timer in step with the active theme.
    _syncMediaTimer(projTheme);

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
        // Pinch-to-zoom (scale font size) + swipe left/right (unified
        // implementation to prevent gesture conflicts). Pinch is detected by
        // pointer count (>= 2), never by the float `scale` value, so a single-
        // finger swipe cannot accidentally trigger a font change.
        onScaleStart: (details) {
          _baseFontSize = activeFontSize;
          _pinchActive = false;
          _panStartOffset = details.localFocalPoint;
          _panDeltaX = 0.0;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount >= 2) {
            _pinchActive = true;
            final newSize = (_baseFontSize * details.scale).clamp(16.0, 160.0);
            notifier.setFontSize(newSize);
          } else if (!_pinchActive) {
            _panDeltaX = details.localFocalPoint.dx - _panStartOffset.dx;
          }
        },
        onScaleEnd: (details) {
          if (_pinchActive) {
            notifier.persistFontSize();
          } else {
            // Horizontal swipe → previous / next slide (songs AND Bible).
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
              // Themed background — radial gradient, solid color block,
              // image (file or cached link), or looping video. Defaults to
              // the historical teal-to-black gradient.
              _ProjectionBackground(
                theme: projTheme,
                slideIndex: activeSlideIndex,
                mediaCycleIndex: _mediaCycleIndex,
              ),

              // Centered slide text + Bible reference tightly attached 20px below
              SafeArea(
                child: Padding(
                  // Keep outer padding lean (especially in landscape, where the
                  // screen height is small) so the text auto-fit has maximum
                  // room and pinch-zoom stays responsive. Portrait mode uses
                  // slimmer side padding so lyrics span more of the screen.
                  padding: EdgeInsets.only(
                    left: _isPortraitMode ? 20.0 : 40.0,
                    right: _isPortraitMode ? 20.0 : 40.0,
                    top: 24.0,
                    // Reserve room for the mobile bottom control bar so the
                    // auto-fit never tucks text behind it. Portrait mode's
                    // bar is taller (buttons + slide counter).
                    bottom: (_isMobile &&
                            !_isSecondaryWindow &&
                            state.slides.isNotEmpty
                        ? (_isPortraitMode ? 100.0 : 40.0)
                        : 24.0) + lowerThirdClearance,
                  ),
                  child: Center(
                    child: activeText.isNotEmpty
                        ? VerseText(
                            text: activeText,
                            referenceLabel: activeIsBible ? activeLabel : null,
                            key: ValueKey(slideKey),
                            fontSize: activeFontSize,
                            color: projTheme.effectiveTextColor,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // Lower Thirds Carousel overlay
              LowerThirdOverlay(
                state: lowerThirdState,
                projectionBackground: projTheme.backgroundBaseColor,
              ),

              // Close button:
              //   • Desktop  — appears only while the cursor hovers the
              //                button itself (strictly hover-gated)
              //   • Mobile   — always visible at low opacity so the audience
              //                presenter can tap to exit at any time
              Positioned(
                top: 4,
                left: 4,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isCloseHovered = true),
                  onExit: (_) => setState(() => _isCloseHovered = false),
                  // A generous hit target around the icon so the button is
                  // easy to reach without being visible until hovered.
                  child: AnimatedOpacity(
                    opacity: _isMobile
                        ? 0.45
                        : (_isCloseHovered ? 0.9 : 0.0),
                    duration: const Duration(milliseconds: 300),
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _handleClose,
                        tooltip: 'Exit projection (Esc)',
                        splashRadius: 20,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Appearance, orientation + set playlist controls — mobile only, top-right.
              if (_isMobile)
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedOpacity(
                    opacity: 0.55,
                    duration: const Duration(milliseconds: 300),
                    child: SafeArea(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final setsState = ref.watch(setsControllerProvider);
                              if (setsState.selectedSetId == null || setsState.setItems.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(
                                  Icons.playlist_play,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => _showMobileSetPlaylistSheet(context, ref),
                                tooltip: 'Songs in Set',
                                splashRadius: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.palette,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _openProjectionAppearance,
                            tooltip: 'Projection appearance',
                            splashRadius: 20,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isPortraitMode
                                  ? Icons.crop_landscape
                                  : Icons.crop_portrait,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _toggleOrientation,
                            tooltip: _isPortraitMode
                                ? 'Switch to landscape'
                                : 'Switch to portrait',
                            splashRadius: 20,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Navigation arrows — mobile fullscreen only.
              // Desktop projection screens stay clean: the operator navigates
              // from the main window (buttons / keyboard), so no overlay arrows.
              // In portrait mode the side arrows are hidden and replaced by
              // prev/next buttons above the bottom slide counter.
              if (slideCount > 0 && _isMobile && !_isPortraitMode)
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

              // Mobile-only: always-visible bottom controls — slide-count chip
              // and (in portrait) prev/next buttons. No dark bar behind them;
              // they float over the projection background.
              if (_isMobile && !_isSecondaryWindow && state.slides.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Portrait mode: prev/next buttons just above the
                        // slide counter (black circles, white chevrons).
                        if (_isPortraitMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _PortraitNavButton(
                                  icon: Icons.chevron_left,
                                  onPressed: notifier.prevSlide,
                                ),
                                _PortraitNavButton(
                                  icon: Icons.chevron_right,
                                  onPressed: notifier.nextSlide,
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            '${state.currentSlideIndex + 1} / ${state.slides.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              letterSpacing: 0.5,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 6,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

/// Circular prev/next button used in the portrait bottom bar (black circle,
/// white chevron) so it matches the dark presentation background.
class _PortraitNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _PortraitNavButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, size: 32, color: Colors.white),
        onPressed: onPressed,
        tooltip: icon == Icons.chevron_left
            ? 'Previous slide'
            : 'Next slide',
        splashRadius: 24,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      ),
    );
  }
}

/// Themed backdrop behind the slide text — a radial gradient, a solid color
/// block, a local image file, or a local looping video. Falls back to the
/// default gradient when a media source is unavailable (e.g. a deleted file).
class _ProjectionBackground extends StatelessWidget {
  final ProjectionTheme theme;
  final int slideIndex;
  final int mediaCycleIndex;

  const _ProjectionBackground({
    required this.theme,
    required this.slideIndex,
    required this.mediaCycleIndex,
  });

  int _resolveIndex(List<Object?> paths) => theme.resolveMediaIndex(
    listLength: paths.length,
    slideIndex: slideIndex,
    mediaCycleIndex: mediaCycleIndex,
  );

  @override
  Widget build(BuildContext context) {
    switch (theme.backgroundType) {
      case ProjectionBackgroundType.solid:
        return ColoredBox(color: theme.solidColor);
      case ProjectionBackgroundType.image:
        // Local file paths are only producible off-web; empty on web.
        if (kIsWeb || theme.imagePaths.isEmpty) {
          return const _DefaultProjectionBackground();
        }
        final paths = theme.imagePaths;
        final path = paths[_resolveIndex(paths)];
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _DefaultProjectionBackground(),
            ),
            const _DarkScrim(),
          ],
        );
      case ProjectionBackgroundType.video:
        if (kIsWeb || theme.videoPaths.isEmpty) {
          return const _DefaultProjectionBackground();
        }
        final paths = theme.videoPaths;
        final path = paths[_resolveIndex(paths)];
        return ProjectionVideoBackground(
          key: ValueKey('video_bg_$path'),
          path: path,
        );
      case ProjectionBackgroundType.gradient:
        if (theme.gradientColors.isEmpty) {
          return const _DefaultProjectionBackground();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: theme.gradientColors,
            ),
          ),
        );
    }
  }
}

/// Semi-transparent black layer that keeps lyrics readable over bright media.
class _DarkScrim extends StatelessWidget {
  const _DarkScrim();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.black.withValues(alpha: 0.35));
  }
}

/// The default teal-to-black radial gradient (matches historic projection).
class _DefaultProjectionBackground extends StatelessWidget {
  const _DefaultProjectionBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF0A1A18), Color(0xFF000000)],
        ),
      ),
    );
  }
}

/// Floating projection-appearance options (mobile). Edits a staged theme
/// locally so the preview can be reviewed before committing; the projection
/// behind the sheet only updates on commit.
class ProjectionAppearanceSheet extends ConsumerStatefulWidget {
  const ProjectionAppearanceSheet({super.key});

  @override
  ConsumerState<ProjectionAppearanceSheet> createState() =>
      _ProjectionAppearanceSheetState();
}

class _ProjectionAppearanceSheetState
    extends ConsumerState<ProjectionAppearanceSheet> {
  late ProjectionTheme _staged = ref.read(projectionThemeProvider);

  void _commit() {
    ref.read(projectionThemeProvider.notifier).setTheme(_staged);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final Widget controls = SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProjectionAppearanceControls(
        theme: _staged,
        onChanged: (value) => setState(() => _staged = value),
      ),
    );

    // Reflow so the preview stays visible in both orientations: preview on
    // top in portrait, on the side in landscape.
    final Widget content = isLandscape
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  child: ProjectionPreview(theme: _staged),
                ),
              ),
              Expanded(child: controls),
            ],
          )
        : Column(
            children: [
              ProjectionPreview(theme: _staged),
              const SizedBox(height: 8),
              Expanded(child: controls),
            ],
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        // mainAxisSize.max (default): the content flexes to whatever height
        // the draggable sheet currently allows, so it never overflows.
        child: Column(
          children: [
            Expanded(child: content),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _staged = const ProjectionTheme();
                  }),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restore Defaults'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _commit,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Commit Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable chapter reference panel with auto-center and edge fades.
