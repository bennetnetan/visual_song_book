import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_tab.dart' show HighlightedText;
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';

class ProjectionTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const ProjectionTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<ProjectionTab> createState() => _ProjectionTabState();
}

class _ProjectionTabState extends ConsumerState<ProjectionTab> {
  late final FocusNode _focusNode;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ProjectionTabFocus');
    _searchController = TextEditingController();
    _setupMainWindowHandler();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupMainWindowHandler() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler((call) async {
        if (call.method == 'navigate_slide') {
          final action = call.arguments['action'] as String?;
          final notifier = ref.read(projectionControllerProvider.notifier);
          if (action == 'prev') {
            notifier.prevSlide();
          } else if (action == 'next') {
            notifier.nextSlide();
          }
        }
        return 'OK';
      });
    } catch (_) {}
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
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

  void _onSearchQueryChanged(String query) {
    ref.read(projectionSearchProvider.notifier).search(query);
  }

  void _projectBibleResult(BibleVerse verse) {
    final notifier = ref.read(projectionControllerProvider.notifier);
    notifier.projectVerse(verse.bookId, verse.chapter, verse.verse, verse.bookName ?? '');
    ref.read(setRepositoryProvider).recordBibleProjection(verse.reference, verse.text);
    ref.read(projectionSearchProvider.notifier).clear();
    _searchController.clear();
  }

  void _projectSongResult(Song song) {
    final notifier = ref.read(projectionControllerProvider.notifier);
    notifier.setSong(song);
    ref.read(projectionSearchProvider.notifier).clear();
    _searchController.clear();
  }

  void _onSearchModeChanged(bool isBible) {
    ref.read(projectionSearchProvider.notifier).toggleMode(isBible);
    _searchController.clear();
  }

  Widget _buildSearchResults() {
    final state = ref.watch(projectionSearchProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.query.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Search failed',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 4),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isBibleMode) {
      return _buildBibleSearchResults(state, theme);
    } else {
      return _buildSongSearchResults(state, theme);
    }
  }

  Widget _buildBibleSearchResults(ProjectionSearchState state, ThemeData theme) {
    final hasExact = state.exactMatch != null;
    final hasResults = state.bibleResults.isNotEmpty;
    final hasMore = state.bibleResults.length < state.totalBibleCount;

    if (!hasExact && !hasResults && state.query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No results found for "${state.query}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // BEST MATCH card
        if (hasExact) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF022C22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _projectBibleResult(state.exactMatch!),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BEST MATCH',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.exactMatch!.reference,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.present_to_all, size: 18),
                            tooltip: 'Project',
                            color: theme.colorScheme.primary,
                            onPressed: () => _projectBibleResult(state.exactMatch!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '"${state.exactMatch!.text}"',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.touch_app, size: 14, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to project',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Regular results
        if (hasResults) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Related Results',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                state.bibleResults.length < state.totalBibleCount
                    ? 'showing ${state.bibleResults.length} of ${state.totalBibleCount} results'
                    : '${state.bibleResults.length} results',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          ...state.bibleResults.map((v) => _buildBibleResultCard(v, state.query, theme)),
          if (hasMore) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                icon: state.isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more, size: 18),
                label: Text(
                  'Show more (${state.totalBibleCount - state.bibleResults.length} remaining)',
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(projectionSearchProvider.notifier).loadMoreBible(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildBibleResultCard(BibleVerse verse, String query, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _projectBibleResult(verse),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    verse.reference,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('\u2022',
                      style: TextStyle(color: Colors.grey, fontSize: 10)),
                  const SizedBox(width: 8),
                  Text(
                    verse.bookId <= 39 ? 'Old Testament' : 'New Testament',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.present_to_all, size: 18),
                    tooltip: 'Project',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _projectBibleResult(verse),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              HighlightedText(
                text: verse.text,
                query: query,
                style: GoogleFonts.ebGaramond(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
                highlightStyle: GoogleFonts.ebGaramond(
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongSearchResults(ProjectionSearchState state, ThemeData theme) {
    if (state.songResults.isEmpty && state.query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No songs found for "${state.query}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.songResults.length,
      itemBuilder: (context, index) {
        final song = state.songResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${song.songNum}'),
            ),
            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(song.key != null ? 'Key: ${song.key}' : ''),
            trailing: IconButton(
              icon: const Icon(Icons.present_to_all, size: 20),
              tooltip: 'Project',
              onPressed: () => _projectSongResult(song),
            ),
            onTap: () => _projectSongResult(song),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(projectionControllerProvider);
    final searchState = ref.watch(projectionSearchProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Projection Controls'),
            actions: [
              _ProjectionSearchAnchor(notifier: notifier),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open Projector Output Window',
                onPressed: () async {
                  if (kIsWeb) {
                    context.push('/projection');
                  } else if (Platform.isWindows ||
                      Platform.isLinux ||
                      Platform.isMacOS) {
                    final window = await WindowController.create(
                      const WindowConfiguration(arguments: 'Projection Output'),
                    );
                    await window.show();
                    Future.delayed(const Duration(milliseconds: 600), () {
                      ref
                          .read(projectionControllerProvider.notifier)
                          .syncCurrentSlide();
                    });
                  } else {
                    context.push('/projection');
                  }
                },
              ),
            ],
          ),
          body: !state.hasContent
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
                      // Search bar
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(value: true, label: Text('Bible', style: TextStyle(fontSize: 12))),
                                  ButtonSegment(value: false, label: Text('Song', style: TextStyle(fontSize: 12))),
                                ],
                                selected: {searchState.isBibleMode},
                                onSelectionChanged: (value) {
                                  _onSearchModeChanged(value.first);
                                },
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: searchState.isBibleMode ? 'Search Bible…' : 'Search songs…',
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    suffixIcon: searchState.query.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              ref.read(projectionSearchProvider.notifier).clear();
                                              _searchController.clear();
                                            },
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          )
                                        : null,
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                  controller: _searchController,
                                  onChanged: _onSearchQueryChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (searchState.query.isNotEmpty) const SizedBox(height: 8),
                      // Main body: search results or slide list + live preview
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: searchState.query.isNotEmpty
                                  ? _buildSearchResults()
                                  : _SlideList(state: state, notifier: notifier),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _LivePreviewPanel(state: state, notifier: notifier),
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
                    (state.currentSong?.title ?? 'Untitled'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isBible && state.currentSong != null)
                Text(
                  'Song ${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
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
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
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
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              currentSlide?.text ?? '',
                              key: ValueKey(
                                  '${state.currentSlideIndex}_${currentSlide?.label}'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                color: Colors.white,
                                fontSize: 18,
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
                      ),
                      // Scripture reference overlay at bottom-right of preview
                      if (state.isBibleMode && currentSlide != null)
                        Positioned(
                          bottom: 6,
                          right: 8,
                          child: Text(
                            currentSlide.label,
                            style: const TextStyle(
                              fontSize: 7,
                              color: Color(0xFF00E5CC),
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
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

        // Song-only settings (chorus toggle doesn't apply to Bible)
        if (!state.isBibleMode)
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
              padding: const EdgeInsets.all(12.0),
              child: SwitchListTile(
                title: const Text('Auto-insert Chorus'),
                subtitle: const Text('Show chorus between verses'),
                value: state.autoInsertChorus,
                onChanged: notifier.setAutoInsertChorus,
              ),
            ),
          ),
      ],
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
    ref.read(projectionSearchProvider.notifier).search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(projectionSearchProvider);

    return SearchAnchor(
      searchController: _searchController,
      builder: (context, controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search Songs or Bible',
          onPressed: () => controller.openView(),
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
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Bible', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: false,
                label: Text('Song', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {searchState.isBibleMode},
            onSelectionChanged: (value) {
              ref.read(projectionSearchProvider.notifier).toggleMode(value.first);
              _searchController.clear();
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
      suggestionsBuilder: (context, controller) {
        if (searchState.isLoading) {
          return [
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ];
        }

        final query = _searchController.text;
        if (query.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  searchState.isBibleMode ? 'Search Bible…' : 'Search songs…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ];
        }

        if (searchState.error != null) {
          return [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Search failed: ${searchState.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ];
        }

        if (searchState.isBibleMode) {
          if (searchState.bibleResults.isEmpty) {
            return [const ListTile(title: Text('No results found'))];
          }
          return searchState.bibleResults.map((v) => ListTile(
                title: Text(v.reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(v.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.present_to_all, size: 18),
                onTap: () {
                  widget.notifier.projectVerse(
                    v.bookId,
                    v.chapter,
                    v.verse,
                    v.bookName ?? '',
                  );
                  ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
                  ref.read(projectionSearchProvider.notifier).clear();
                  controller.closeView(null);
                },
              ));
        } else {
          if (searchState.songResults.isEmpty) {
            return [const ListTile(title: Text('No results found'))];
          }
          return searchState.songResults.map((s) => ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${s.songNum}', style: const TextStyle(fontSize: 10)),
                ),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s.key != null ? 'Key: ${s.key}' : ''),
                trailing: const Icon(Icons.present_to_all, size: 18),
                onTap: () {
                  widget.notifier.setSong(s);
                  ref.read(projectionSearchProvider.notifier).clear();
                  controller.closeView(null);
                },
              ));
        }
      },
    );
  }
}
