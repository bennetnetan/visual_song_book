import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_search_widgets.dart';
import 'package:visual_song_book/features/projection/projection_search_results.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';


class InlineProjectionSearch extends ConsumerStatefulWidget {
  final ProjectionController notifier;

  const InlineProjectionSearch({super.key, required this.notifier});

  @override
  ConsumerState<InlineProjectionSearch> createState() =>
      _InlineProjectionSearchState();
}

class _InlineProjectionSearchState
    extends ConsumerState<InlineProjectionSearch> {
  final SearchController _searchController = SearchController();
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'InlineProjectionSearch');

  static const Duration _navReadyDelay = Duration(milliseconds: 100);
  bool _navReady = false;
  Timer? _navReadyTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    // The window opens ready for input — no extra tap needed to start typing.
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
    ref.read(projectionSearchProvider.notifier).search(_searchController.text);
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

  /// Projects the picked item. Picking already auto-opens the projector window,
  /// which swaps this empty view for the active controls.
  void _pickItem(int index, ProjectionSearchState searchState) {
    final searchRef = ref.read(projectionSearchProvider.notifier);
    final results = composeSearchResults(searchState);
    if (index < 0 || index >= results.length) return;

    if (searchState.isBibleMode) {
      final v = results[index] as BibleVerse;
      widget.notifier.projectVerse(
        v.bookId,
        v.chapter,
        v.verse,
        v.bookName ?? '',
      );
      ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    } else {
      widget.notifier.setSong(results[index] as Song);
    }

    searchRef.clear();
    _searchController.clear();
  }

  KeyEventResult _handleKey(KeyEvent event, ProjectionSearchState s) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Enter projects the highlighted result as soon as results exist.
    final totalItems = countSearchResults(s);
    if (totalItems > 0 && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
      _pickItem(_selectedIndex.value, s);
      return KeyEventResult.handled;
    }

    if (!_navReady) return KeyEventResult.ignored;
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

    return Focus(
      // Wraps the field *and* the results, so Enter projects the highlighted
      // row while the operator is still typing. A Focus around only the
      // results would not sit above the text field and would never see the
      // keystroke.
      onKeyEvent: (node, event) => _handleKey(event, searchState),
      child: Column(
        children: [
          // Search field row: an always-visible, pre-focused text field plus
          // the mode toggle and the songbook filter, so switching source never
          // means closing and reopening a popup.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  focusNode: _focusNode,
                  hintText: searchState.isBibleMode
                      ? 'Search Bible…'
                      : 'Search songs…',
                  // A single-line field consumes Enter itself, so an ancestor
                  // Focus never sees it. Hooking onSubmitted is the reliable
                  // way to make Enter project the highlighted row.
                  onSubmitted: (_) => _pickItem(
                    _selectedIndex.value,
                    searchState,
                  ),
                  leading: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(projectionSearchProvider.notifier).clear();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                    final selectedSource = ref.watch(projectionSearchProvider
                        .select((s) => s.selectedSourcePath));
                    final sourcePaths = ref.watch(songListControllerProvider
                        .select((s) => s.sourcePaths));
                    if (sourcePaths.length <= 1) {
                      return const SizedBox.shrink();
                    }
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
                        ref
                            .read(projectionSearchProvider.notifier)
                            .setSourceFilter(value);
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
                                Icon(Icons.check,
                                    size: 16, color: theme.colorScheme.primary),
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
                                  Expanded(
                                    child: Text(source.path,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(
                                    '${source.count}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (selectedSource == source.path) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.check,
                                        size: 16,
                                        color: theme.colorScheme.primary),
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
        // Loading indicator + results, below the field.
        Expanded(
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
    );
  }
}

