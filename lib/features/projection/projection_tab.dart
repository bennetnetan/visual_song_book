import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

/// Persists the set-navigator collapsed/expanded state across widget-tree rebuilds
/// (the panel moves between large-screen Row and small-screen Column, which would
/// otherwise reset local widget state and reopen the panel on every rebuild).
final _setNavigatorExpandedProvider = StateProvider<bool>((ref) => false);


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

  KeyEventResult _handleProjectionKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
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
              IconButton(
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
              ? _EmptyProjectionState(
                  onGoSongs: () {
                    ref.read(activeDashboardTabProvider.notifier).state = 0;
                  },
                  onGoBible: () {
                    ref.read(activeDashboardTabProvider.notifier).state = 2;
                  },
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      _ProjectionHeader(state: state, notifier: notifier),
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
                                          child: _SlideList(state: state, notifier: notifier),
                                        ),
                                        _SetNavigatorPanel(
                                          state: state,
                                          notifier: notifier,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: _LivePreviewPanel(state: state, notifier: notifier),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _LivePreviewPanel(state: state, notifier: notifier),
                                  const SizedBox(height: 12),
                                  _SetNavigatorPanel(
                                    state: state,
                                    notifier: notifier,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _SlideList(state: state, notifier: notifier),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
              ),
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — guides user to Songs or Bible
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyProjectionState extends StatelessWidget {
  final VoidCallback onGoSongs;
  final VoidCallback onGoBible;

  const _EmptyProjectionState({required this.onGoSongs, required this.onGoBible});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 72,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              'Nothing on screen',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Project a song or Bible passage to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.music_note, size: 18),
                    label: const Text('Browse Songs'),
                    onPressed: onGoSongs,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.menu_book, size: 18),
                    label: const Text('Open Bible'),
                    onPressed: onGoBible,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: Use ↑ ↓ ← → or Space to navigate slides.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header row — title, mode badge, clear button
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectionHeader extends StatelessWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _ProjectionHeader({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBible = state.isBibleMode;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isBible
                ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBible ? Icons.menu_book : Icons.music_note,
                size: 14,
                color: isBible
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                isBible ? 'Bible' : 'Song',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isBible
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.contentTitle ??
                    state.currentSong?.title ??
                    (state.slides.isNotEmpty ? state.slides.first.label : 'Untitled'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isBible && state.currentSong != null)
                Text(
                  'Song #${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              if (isBible)
                Text(
                  'Chapter ${state.bibleChapter ?? '?'} — ${state.slides.length} verse${state.slides.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
            ],
          ),
        ),
        if (!isBible && state.currentSong != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AutoChorusToggle(
              value: state.autoInsertChorus,
              onChanged: notifier.setAutoInsertChorus,
            ),
          ),
        ElevatedButton.icon(
          onPressed: notifier.clearSong,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Clear Screen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[900],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-chorus toggle chip — shown inline next to Clear Screen for songs
// ─────────────────────────────────────────────────────────────────────────────

class _AutoChorusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutoChorusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Auto-insert chorus between verses',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.repeat : Icons.repeat_one,
                size: 14,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Chorus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
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
// Slide list — works for both songs and Bible passages
// ─────────────────────────────────────────────────────────────────────────────

class _SlideList extends StatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _SlideList({required this.state, required this.notifier});

  @override
  State<_SlideList> createState() => _SlideListState();
}

class _SlideListState extends State<_SlideList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToCurrent();
  }

  @override
  void didUpdateWidget(covariant _SlideList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.currentSlideIndex != oldWidget.state.currentSlideIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final idx = widget.state.currentSlideIndex;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const itemHeight = 68.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (idx * itemHeight) - (viewportHeight * 0.3);
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.state.slides.length,
      itemBuilder: (context, index) {
        final slide = widget.state.slides[index];
        final isSelected = index == widget.state.currentSlideIndex;
        return Card(
          elevation: isSelected ? 3 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: _SlideLabelBadge(
                label: slide.label,
                isSelected: isSelected,
                isBible: widget.state.isBibleMode,
              ),
              title: Text(
                slide.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              onTap: () => widget.notifier.selectSlide(index),
            ),
          );
        },
      );
    }
  }

/// Badge showing the slide label. Bible mode: pill for long references.
/// Song mode: square chip for V1, C, etc.
class _SlideLabelBadge extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isBible;

  const _SlideLabelBadge({
    required this.label,
    required this.isSelected,
    required this.isBible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    if (isBible) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview panel — preview canvas + navigation + settings
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreviewPanel extends StatelessWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _LivePreviewPanel({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSlide = state.currentSlide;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    if (!isLargeScreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isBibleMode && currentSlide != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    currentSlide.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: notifier.goToPrevChapter,
                    tooltip: 'Previous Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ch. ${state.bibleChapter ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: notifier.goToNextChapter,
                    tooltip: 'Next Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  currentSlide?.text ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Color.fromARGB(150, 0, 0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (state.isBibleMode && currentSlide != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                currentSlide.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF00E5CC),
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE PREVIEW',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            _ProjectionSearchAnchor(notifier: notifier),
          ],
        ),
        const SizedBox(height: 12),

        // Scripture reference + chapter stepper (Bible mode only)
        if (state.isBibleMode && currentSlide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  currentSlide.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: notifier.goToPrevChapter,
                  tooltip: 'Previous Chapter',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  'Ch. ${state.bibleChapter ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: notifier.goToNextChapter,
                  tooltip: 'Next Chapter',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        // 16:9 preview canvas
        Expanded(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    currentSlide?.text ?? '',
                                    textAlign: TextAlign.center,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Color.fromARGB(150, 0, 0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (state.isBibleMode && currentSlide != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentSlide.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF00E5CC),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Slide / Verse counter
        Center(
          child: Text(
            state.isBibleMode
                ? 'Verse ${state.currentSlideIndex + 1} of ${state.slides.length}'
                : 'Slide ${state.currentSlideIndex + 1} of ${state.slides.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Navigation buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.prevSlide : null,
                icon: const Icon(Icons.arrow_back),
                label: Text(state.isBibleMode ? 'Previous (←)' : 'Previous (←)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.nextSlide : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(state.isBibleMode ? 'Next (→)' : 'Next (→)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Font size controls
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: state.fontSize > 16
                      ? () => notifier.setFontSize(state.fontSize - 4)
                      : null,
                  tooltip: 'Decrease (${state.fontSize - 4})',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${state.fontSize.toInt()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: state.fontSize < 96
                      ? () => notifier.setFontSize(state.fontSize + 4)
                      : null,
                  tooltip: 'Increase (${state.fontSize + 4})',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set Navigator Panel — shows set songs and allows jumping to any song in set
// ─────────────────────────────────────────────────────────────────────────────

class _SetNavigatorPanel extends ConsumerStatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _SetNavigatorPanel({required this.state, required this.notifier});

  @override
  ConsumerState<_SetNavigatorPanel> createState() => _SetNavigatorPanelState();
}

class _SetNavigatorPanelState extends ConsumerState<_SetNavigatorPanel> {
  // Expanded state is now in _setNavigatorExpandedProvider so it survives
  // widget-tree moves (large ↔ small screen layout changes).

  @override
  Widget build(BuildContext context) {
    final setsState = ref.watch(setsControllerProvider);
    final bool isExpanded = ref.watch(_setNavigatorExpandedProvider);
    final theme = Theme.of(context);

    // Only show when a set is selected and has items
    if (setsState.selectedSetId == null || setsState.setItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;
    if (setObj == null) return const SizedBox.shrink();

    // Determine which song is currently on screen
    final currentSongId = widget.state.currentSong?.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ref.read(_setNavigatorExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.playlist_play,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SET: ${setObj.name}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${setsState.setItems.length} songs',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Song list
          if (isExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
                itemCount: setsState.setItems.length,
                itemBuilder: (ctx, i) {
                  final item = setsState.setItems[i];
                  final song = setsState.availableSongs
                      .where((s) => s.id == item.songId)
                      .firstOrNull;
                  if (song == null) return const SizedBox.shrink();

                  final isActive = song.id == currentSongId;
                  final setKey = item.key ?? song.key;

                  return GestureDetector(
                    onTap: () => widget.notifier.setSong(song),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Position number
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          // Song title
                          Expanded(
                            child: Text(
                              song.title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Key badge
                          if (setKey != null && setKey.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                setKey,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          // Playing indicator
                          if (isActive)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.play_arrow,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search mode toggle — Bible / Song chips (replaces SegmentedButton to avoid
// rebuild loops inside SearchAnchor.viewTrailing)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchModeToggle extends StatelessWidget {
  final bool isBibleMode;
  final ValueChanged<bool> onToggle;

  const _SearchModeToggle({required this.isBibleMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bibleColor = Color(0xFF00E5CC);
    final songColor = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeChip(
          label: 'Bible',
          icon: Icons.menu_book,
          isSelected: isBibleMode,
          selectedColor: bibleColor,
          onTap: () { if (!isBibleMode) onToggle(true); },
        ),
        const SizedBox(width: 6),
        _ModeChip(
          label: 'Song',
          icon: Icons.library_music,
          isSelected: !isBibleMode,
          selectedColor: songColor,
          onTap: () { if (isBibleMode) onToggle(false); },
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.7)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Search Anchor — global search with toggle (Bible / Songs)
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectionSearchAnchor extends ConsumerStatefulWidget {
  final ProjectionController notifier;

  const _ProjectionSearchAnchor({required this.notifier});

  @override
  ConsumerState<_ProjectionSearchAnchor> createState() =>
      _ProjectionSearchAnchorState();
}

class _ProjectionSearchAnchorState extends ConsumerState<_ProjectionSearchAnchor> {
  final SearchController _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final newText = _searchController.text;
    ref.read(projectionSearchProvider.notifier).search(newText);
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (context, controller) {
        return Consumer(
          builder: (context, ref, child) {
            final isBible = ref.watch(projectionSearchProvider.select((s) => s.isBibleMode));
            final theme = Theme.of(context);
            final color = isBible ? const Color(0xFF00E5CC) : theme.colorScheme.primary;

            return ActionChip(
              onPressed: () => controller.openView(),
              avatar: Icon(
                isBible ? Icons.menu_book : Icons.library_music,
                size: 16,
                color: color,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBible ? 'Search Bible' : 'Search Songs',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.search, size: 14, color: color),
                ],
              ),
              backgroundColor: color.withValues(alpha: 0.15),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.zero,
              tooltip: isBible ? 'Search Bible' : 'Search Songs',
            );
          },
        );
      },
      viewLeading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          ref.read(projectionSearchProvider.notifier).clear();
          _searchController.closeView(null);
        },
      ),
      viewTrailing: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Consumer(
            builder: (context, ref, child) {
              final isBibleMode = ref.watch(projectionSearchProvider.select((s) => s.isBibleMode));
              return _SearchModeToggle(
                isBibleMode: isBibleMode,
                onToggle: (isBible) {
                  ref.read(projectionSearchProvider.notifier).switchModeAndSearch(
                    isBible,
                    _searchController.text,
                  );
                },
              );
            },
          ),
        ),
        if (!ref.watch(projectionSearchProvider.select((s) => s.isBibleMode)))
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer(
              builder: (context, ref, child) {
                final selectedSource = ref.watch(projectionSearchProvider.select((s) => s.selectedSourcePath));
                final sourcePaths = ref.watch(songListControllerProvider.select((s) => s.sourcePaths));
                if (sourcePaths.length <= 1) return const SizedBox.shrink();
                return PopupMenuButton<String?>(
                  icon: Icon(
                    Icons.library_books_outlined,
                    size: 18,
                    color: selectedSource != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Filter by songbook',
                  onSelected: (value) {
                    ref.read(projectionSearchProvider.notifier).setSourceFilter(value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          const Icon(Icons.all_inclusive, size: 16),
                          const SizedBox(width: 8),
                          const Text('All Books'),
                          if (selectedSource == null) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                    ...sourcePaths.map((source) => PopupMenuItem<String?>(
                      value: source.path,
                      child: Row(
                        children: [
                          const Icon(Icons.book_outlined, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(source.path, overflow: TextOverflow.ellipsis)),
                          Text(
                            '${source.count}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (selectedSource == source.path) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                          ],
                        ],
                      ),
                    )),
                  ],
                );
              },
            ),
          ),
      ],
      suggestionsBuilder: (context, controller) {
        return [
          _SuggestionsList(
            controller: controller,
            notifier: widget.notifier,
          ),
        ];
      },
    );
  }
}

class _SuggestionsList extends ConsumerStatefulWidget {
  final SearchController controller;
  final ProjectionController notifier;

  const _SuggestionsList({
    required this.controller,
    required this.notifier,
  });

  @override
  ConsumerState<_SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends ConsumerState<_SuggestionsList> {
  int _selectedIndex = 0;
  final Map<int, GlobalKey> _itemKeys = {};
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'SearchSuggestionsFocus');

  GlobalKey _itemKey(int index) =>
      _itemKeys.putIfAbsent(index, () => GlobalKey(debugLabel: 'result_$index'));

  // ── Nav-ready dwell timer ─────────────────────────────────────────────────
  // After the user stops typing for [_navReadyDelay], navigation mode
  // activates: Up/Down/Left/Right scroll the results list, Enter projects the
  // highlighted item. The moment any character is typed the query changes,
  // which resets the timer and exits nav mode so typing continues normally.
  static const Duration _navReadyDelay = Duration(milliseconds: 100);
  bool _navReady = false;
  Timer? _navReadyTimer;

  @override
  void dispose() {
    _navReadyTimer?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Called whenever the search query changes (user typed a character).
  /// Resets nav mode and restarts the dwell timer.
  void _resetNavReady() {
    _navReadyTimer?.cancel();
    if (_navReady) setState(() => _navReady = false);
    _navReadyTimer = Timer(_navReadyDelay, () {
      if (mounted) setState(() => _navReady = true);
    });
  }

  /// Scrolls so the selected item is visible.
  void _scrollToSelected(int index) {
    final key = _itemKeys[index];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Projects the item at [index] and closes the search view.
  void _pickItem(int index, ProjectionSearchState searchState) {
    final searchRef = ref.read(projectionSearchProvider.notifier);
    if (searchState.isBibleMode) {
      final results = [
        if (searchState.exactMatch != null) searchState.exactMatch!,
        ...searchState.bibleResults,
      ];
      if (index >= results.length) return;
      final v = results[index];
      widget.notifier.projectVerse(
        v.bookId, v.chapter, v.verse, v.bookName ?? '',
      );
      ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    } else {
      final songs = searchState.songResults;
      if (index >= songs.length) return;
      widget.notifier.setSong(songs[index]);
    }
    searchRef.clear();
    widget.controller.closeView(null);
  }

  KeyEventResult _handleKey(KeyEvent event, ProjectionSearchState searchState) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // ── Enter/Return always projects immediately — even before _navReady fires.
    // This lets quick typists hit Enter right after their last keystroke without
    // waiting for the 100 ms dwell timer. We check Enter first, before the
    // _navReady gate which only gates arrow navigation (to avoid fighting the
    // text-field cursor movement while the user is still typing).
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final int totalItems = searchState.isBibleMode
          ? (searchState.exactMatch != null ? 1 : 0) + searchState.bibleResults.length
          : searchState.songResults.length;
      if (totalItems > 0) {
        // Clamp selected index in case results changed since last interaction.
        final safeIndex = _selectedIndex.clamp(0, totalItems - 1);
        _pickItem(safeIndex, searchState);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // ── If nav mode is not yet active, pass everything through so the text
    // field can handle cursor movement and character input normally. ──────────
    if (!_navReady) return KeyEventResult.ignored;

    final int totalItems = searchState.isBibleMode
        ? (searchState.exactMatch != null ? 1 : 0) + searchState.bibleResults.length
        : searchState.songResults.length;

    if (totalItems == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      final next = (_selectedIndex + 1).clamp(0, totalItems - 1);
      if (next != _selectedIndex) {
        setState(() => _selectedIndex = next);
        _scrollToSelected(next);
      }
      // Consume — do NOT propagate to the projection screen.
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      final prev = (_selectedIndex - 1).clamp(0, totalItems - 1);
      if (prev != _selectedIndex) {
        setState(() => _selectedIndex = prev);
        _scrollToSelected(prev);
      }
      return KeyEventResult.handled;
    }

    // Any other key (printable characters, backspace, etc.) is ignored so it
    // bubbles to the text field — typing continues as normal and will trigger
    // the query-change listener which resets nav mode.
    return KeyEventResult.ignored;
  }


  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(projectionSearchProvider);
    final theme = Theme.of(context);

    // When the query changes (user typed) → reset nav-ready dwell timer.
    // Nav mode re-activates 100 ms after the last keystroke.
    ref.listen(
      projectionSearchProvider.select((s) => s.query),
      (prev, next) {
        if (prev != next) _resetNavReady();
      },
    );

    // When results change → reset selection to first item.
    ref.listen(projectionSearchProvider, (prev, next) {
      if (prev?.bibleResults != next.bibleResults ||
          prev?.songResults != next.songResults ||
          prev?.exactMatch != next.exactMatch) {
        if (mounted) setState(() => _selectedIndex = 0);
      }
    });

    if (searchState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final query = searchState.query;
    if (query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            searchState.isBibleMode ? 'Search Bible…' : 'Search songs…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (searchState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed: ${searchState.error}',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    Widget list;

    if (searchState.isBibleMode) {
      final results = [
        if (searchState.exactMatch != null) searchState.exactMatch!,
        ...searchState.bibleResults,
      ];
      if (results.isEmpty) {
        list = const ListTile(title: Text('No results found'));
      } else {
        list = ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final v = results[index];
            final isExact = v == searchState.exactMatch;
            final isSelected = index == _selectedIndex;
            return Card(
              key: _itemKey(index),
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : isExact
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 2.0 : (isExact ? 1.5 : 1),
                ),
              ),
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.30)
                  : isExact
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                      : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isExact ? theme.colorScheme.primary : const Color(0xFF00E5CC)).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 16,
                    color: isExact ? theme.colorScheme.primary : const Color(0xFF00E5CC),
                  ),
                ),
                title: HighlightedText(
                  text: v.reference,
                  query: query,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  highlightStyle: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: HighlightedText(
                    text: v.text,
                    query: query,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    highlightStyle: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                trailing: isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_return, size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 3),
                            Text('Enter', style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.present_to_all,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                onTap: () => _pickItem(index, searchState),
              ),
            );
          },
        );
      }
    } else {
      if (searchState.songResults.isEmpty) {
        list = const ListTile(title: Text('No results found'));
      } else {
        list = ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: searchState.songResults.length,
          itemBuilder: (context, index) {
            final s = searchState.songResults[index];
            final isSelected = index == _selectedIndex;
            return Card(
              key: _itemKey(index),
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                  : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '#${s.songNum}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                title: HighlightedText(
                  text: s.title,
                  query: query,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  highlightStyle: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      if (s.key != null && s.key!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Key: ${s.key}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          s.body.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_return, size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 3),
                            Text('Enter', style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.present_to_all,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                onTap: () => _pickItem(index, searchState),
              ),
            );
          },
        );
      }
    }

    // Wrap the list in a Focus widget that intercepts arrow-key navigation
    // and Enter-to-project — events are consumed here and never reach the
    // projection screen's Focus node (the SearchAnchor overlay is a separate
    // route on top of the main view).
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKey(event, searchState),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle nav-ready indicator — fades in once dwell timer fires,
          // fades out instantly when the user resumes typing.
          AnimatedOpacity(
            opacity: _navReady && !searchState.isLoading && searchState.query.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard, size: 12,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '↑ ↓ navigate  ·  ↵ project',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          list,
        ],
      ),
    );

  }
}
