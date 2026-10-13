import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_search_results.dart';
import 'package:visual_song_book/features/projection/projection_search_widgets.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';


class ProjectionSearchAnchor extends ConsumerWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;

  const ProjectionSearchAnchor({super.key, required this.notifier, required this.returnFocusTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBible = ref.watch(projectionSearchProvider.select((s) => s.isBibleMode));
    final theme = Theme.of(context);
    final color = isBible ? theme.colorScheme.tertiary : theme.colorScheme.primary;

    return ActionChip(
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (ctx) => FullScreenSearchPage(
            notifier: notifier,
            returnFocusTo: returnFocusTo,
          ),
        );
      },
      avatar: Icon(
        isBible ? Icons.menu_book : Icons.library_music,
        size: 16,
        color: color,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Neutral wording — the avatar icon and colour still show which
            // source is active, and the search page has its own Bible/Songs
            // toggle, so "Search Songs"/"Search Bible" was redundant here.
            'Search',
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
      tooltip: 'Search songs and Bible',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen search page — Bible / Songs toggle + results + share
// ─────────────────────────────────────────────────────────────────────────────

class FullScreenSearchPage extends ConsumerStatefulWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;

  const FullScreenSearchPage({super.key, 
    required this.notifier,
    required this.returnFocusTo,
  });

  @override
  ConsumerState<FullScreenSearchPage> createState() => _FullScreenSearchPageState();
}

class _FullScreenSearchPageState extends ConsumerState<FullScreenSearchPage> {
  final SearchController _searchController = SearchController();
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'FullScreenSearchFocus');

  static const Duration _navReadyDelay = Duration(milliseconds: 100);
  bool _navReady = false;
  Timer? _navReadyTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _navReadyTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _selectedIndex.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final newText = _searchController.text;
    ref.read(projectionSearchProvider.notifier).search(newText);
  }

  void _resetNavReady() {
    _navReadyTimer?.cancel();
    if (_navReady) setState(() => _navReady = false);
    _navReadyTimer = Timer(_navReadyDelay, () {
      if (mounted) setState(() => _navReady = true);
    });
  }

  void _scrollToSelected(int index) {
    final searchState = ref.read(projectionSearchProvider);
    if (index < 0 || index >= countSearchResults(searchState)) return;
    if (!_scrollController.hasClients) return;

    // Result rows are a near-constant height, so advancing by a fixed extent
    // keeps the highlighted item in view without needing per-row keys.
    const estimatedItemExtent = 96.0;
    final target = (index * estimatedItemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _pickItem(int index, ProjectionSearchState searchState) {
    final searchRef = ref.read(projectionSearchProvider.notifier);
    final results = composeSearchResults(searchState);
    if (index < 0 || index >= results.length) return;
    if (searchState.isBibleMode) {
      final v = results[index] as BibleVerse;
      widget.notifier.projectVerse(
        v.bookId, v.chapter, v.verse, v.bookName ?? '',
      );
      ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    } else {
      widget.notifier.setSong(results[index] as Song);
    }
    searchRef.clear();
    _searchController.clear();
    if (mounted) Navigator.of(context).pop();
    widget.returnFocusTo.requestFocus();
  }

  KeyEventResult _handleKey(KeyEvent event, ProjectionSearchState searchState) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final totalItems = countSearchResults(searchState);
      if (totalItems > 0) {
        final safeIndex = _selectedIndex.value.clamp(0, totalItems - 1);
        _pickItem(safeIndex, searchState);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!_navReady) return KeyEventResult.ignored;

    final totalItems = countSearchResults(searchState);
    if (totalItems == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = (_selectedIndex.value + 1).clamp(0, totalItems - 1);
      if (next != _selectedIndex.value) {
        setState(() => _selectedIndex.value = next);
        _scrollToSelected(next);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final prev = (_selectedIndex.value - 1).clamp(0, totalItems - 1);
      if (prev != _selectedIndex.value) {
        setState(() => _selectedIndex.value = prev);
        _scrollToSelected(prev);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(projectionSearchProvider);
    final theme = Theme.of(context);

    ref.listen(
      projectionSearchProvider.select((s) => s.query),
      (prev, next) {
        if (prev != next) _resetNavReady();
      },
    );

    ref.listen(projectionSearchProvider, (prev, next) {
      if (prev?.bibleResults != next.bibleResults ||
          prev?.songResults != next.songResults ||
          prev?.exactMatch != next.exactMatch) {
        if (mounted) setState(() => _selectedIndex.value = 0);
      }
    });

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Focus(
          onKeyEvent: (node, event) => _handleKey(event, searchState),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () {
                        ref.read(projectionSearchProvider.notifier).clear();
                        _searchController.clear();
                        if (mounted) Navigator.of(context).pop();
                        widget.returnFocusTo.requestFocus();
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SearchBar(
                        controller: _searchController,
                        focusNode: _focusNode,
                        hintText: searchState.isBibleMode ? 'Search Bible…' : 'Search songs…',
                        trailing: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(projectionSearchProvider.notifier).clear();
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SearchModeToggle(
                      isBibleMode: searchState.isBibleMode,
                      onToggle: (isBible) {
                        ref.read(projectionSearchProvider.notifier).switchModeAndSearch(
                          isBible,
                          _searchController.text,
                        );
                      },
                    ),
                    if (!searchState.isBibleMode)
                      Consumer(
                        builder: (context, ref, child) {
                          final selectedSource = ref.watch(projectionSearchProvider.select((s) => s.selectedSourcePath));
                          final sourcePaths = ref.watch(songListControllerProvider.select((s) => s.sourcePaths));
                          if (sourcePaths.length <= 1) return const SizedBox.shrink();
                          return PopupMenuButton<String?>(
                            icon: Icon(
                              Icons.library_books_outlined,
                              size: 18,
                              color: selectedSource != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
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
                                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
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
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (selectedSource == source.path) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                              )),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Column(
                  children: [
                    if (searchState.isLoading)
                      const LinearProgressIndicator(minHeight: 3)
                    else
                      const SizedBox(height: 3),
                    Expanded(
                      child: ProjectionSearchResultsList(
                        searchState: searchState,
                        selectedIndex: _selectedIndex.value,
                        scrollController: _scrollController,
                        onPick: (index, state) => _pickItem(index, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
