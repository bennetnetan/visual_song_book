import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/projection/empty_projection_state.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_header.dart';
import 'package:visual_song_book/features/projection/projection_live_preview.dart';
import 'package:visual_song_book/features/projection/projection_search_page.dart';
import 'package:visual_song_book/features/projection/projection_set_navigator.dart';
import 'package:visual_song_book/features/projection/projection_slide_list.dart';

class ProjectionTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const ProjectionTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<ProjectionTab> createState() => _ProjectionTabState();
}

class _ProjectionTabState extends ConsumerState<ProjectionTab> {
  late final FocusNode _projectionFocus;

  @override
  void initState() {
    super.initState();
    _projectionFocus = FocusNode(debugLabel: 'ProjectionControlsFocus');
  }

  @override
  void dispose() {
    _projectionFocus.dispose();
    super.dispose();
  }

  /// Whether the keyboard is currently captured by a text field.
  ///
  /// Without this check the projection slide shortcuts (space, arrows, page
  /// up/down, escape) fire while the operator is typing in the projection
  /// search. An ancestor that consumes the key prevents the focused field from
  /// receiving it, so the space bar appeared dead and the arrows advanced the
  /// slide instead of moving the caret.
  ///
  /// Walks up from the focused node rather than testing one widget, because
  /// focus can land on the editable's internal node or on a text field.
  bool get _isTextEditing {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;

    var found = false;
    focusContext.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is EditableText || widget is TextField) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  KeyEventResult _handleProjectionKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Let the focused text field own the keyboard.
    if (_isTextEditing) {
      return KeyEventResult.ignored;
    }

    final notifier = ref.read(projectionControllerProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        notifier.nextSlide();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.pageUp:
        notifier.prevSlide();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        notifier.clearSong();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

@override
  Widget build(BuildContext context) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Scaffold(
        appBar: AppBar(
            title: const Text('Projection Controls'),
            actions: [
              if (widget.isLargeScreen)
                Consumer(
                  builder: (context, ref, _) {
                    final ltState = ref.watch(lowerThirdControllerProvider);
                    final ltNotifier =
                        ref.read(lowerThirdControllerProvider.notifier);
                    return IconButton(
                      icon: Icon(
                        ltState.isEnabled
                            ? Icons.view_headline
                            : Icons.view_headline_outlined,
                        color: ltState.isEnabled
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: ltState.isEnabled
                          ? 'Lower Thirds Carousel: Active (tap to turn off)'
                          : 'Lower Thirds Carousel: Off (tap to turn on)',
                      onPressed: ltNotifier.toggleEnabled,
                    );
                  },
                ),
              Semantics(
                label: 'Open Projector Output Window',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open Projector Output Window',
                  onPressed: () async {
                    if (kIsWeb) {
                      context.push('/projection');
                    } else if (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS) {
                      await ref.read(projectionControllerProvider.notifier).openProjectorWindow();
                    } else {
                      context.push('/projection');
                    }
                  },
                ),
              ),
              // Search moves to the app bar once something is on screen: the
              // empty window already embeds the field, and mid-projection the
              // controls need the vertical space the old top bar used to take.
              Semantics(
                label: 'Search songs and Bible',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search songs and Bible',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) => FullScreenSearchPage(
                        notifier: ref.read(projectionControllerProvider.notifier),
                        returnFocusTo: _projectionFocus,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Focus(
            focusNode: _projectionFocus,
            autofocus: true,
            onKeyEvent: _handleProjectionKeys,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _projectionFocus.requestFocus(),
              child: !state.hasContent
              ? EmptyProjectionState(
                  notifier: notifier,
                  returnFocusTo: _projectionFocus,
                  isLargeScreen: widget.isLargeScreen,
                )
              // A Column provides the Flex ancestor the Expanded below needs
              // (a GestureDetector will not do).
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            ProjectionHeader(state: state, notifier: notifier),
                            const Divider(height: 32),
                            // Main body: slide list + live preview
                            Expanded(
                              child: widget.isLargeScreen
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left column: slide list + set navigator
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: SlideList(
                                                  state: state,
                                                  notifier: notifier,
                                                ),
                                              ),
                                              SetNavigatorPanel(
                                                state: state,
                                                notifier: notifier,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 3,
                                          child: LivePreviewPanel(
                                            state: state,
                                            notifier: notifier,
                                            projectionFocus: _projectionFocus,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        LivePreviewPanel(
                                          state: state,
                                          notifier: notifier,
                                          projectionFocus: _projectionFocus,
                                        ),
                                        const SizedBox(height: 12),
                                        SetNavigatorPanel(
                                          state: state,
                                          notifier: notifier,
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: SlideList(
                                            state: state,
                                            notifier: notifier,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — guides user to Songs or Bible
// ─────────────────────────────────────────────────────────────────────────────
