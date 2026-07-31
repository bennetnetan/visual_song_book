import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/widgets/bible_mobile_sheet.dart';
import 'package:visual_song_book/features/bible/widgets/bible_reading_widgets.dart';
import 'package:visual_song_book/features/bible/widgets/bible_search_widgets.dart';
import 'package:visual_song_book/features/bible/widgets/bible_sidebar_widgets.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class BibleTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const BibleTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<BibleTab> createState() => _BibleTabState();
}

class _BibleTabState extends ConsumerState<BibleTab> {
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }



    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
        final ctrl = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
          setState(() => _isSearchExpanded = true);
          _searchFocusNode.requestFocus();
        }
      },
      child: Row(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    titleSpacing: 0,
                    toolbarHeight: 80,
                    title: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: _isSearchExpanded
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () {
                                    setState(() => _isSearchExpanded = false);
                                    notifier.clearSearch();
                                    _searchController.clear();
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  },
                                ),
                                Expanded(
                                  child: BibleSearchBar(
                                    query: state.query,
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: notifier.search,
                                    recentSearches: state.recentSearches,
                                    onClearRecent: notifier.clearRecentSearches,
                                    onSuggestionTap: (q) {
                                      _searchController.text = q;
                                      notifier.search(q);
                                      _searchFocusNode.unfocus();
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Text(
                                  'Bible',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  tooltip: 'Search Bible',
                                  onPressed: () {
                                    setState(() => _isSearchExpanded = true);
                                    _searchFocusNode.requestFocus();
                                  },
                                ),
                              ],
                            ),
                    ),
                  ),
                ];
              },
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.query.isEmpty && _isSearchExpanded)
                    BibleSearchSuggestionSection(
                      state: state,
                      notifier: notifier,
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                    ),
                  Expanded(
                  child: state.searchResults.isNotEmpty ||
                          state.exactMatch != null ||
                          state.query.isNotEmpty
                      ? BibleSearchResultsView(
                          results: state.searchResults,
                          exactMatch: state.exactMatch,
                          onSelectExact: () {
                            final v = state.exactMatch;
                            if (v != null) {
                              notifier.navigateToVerse(v.bookId, v.chapter, v.verse);
                              notifier.clearSearch();
                              _searchController.clear();
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _isSearchExpanded = false);
                            }
                          },
                          onProject: (v) => _projectVerse(v),
                          onNavigate: (v) {
                            notifier.navigateToVerse(v.bookId, v.chapter, v.verse);
                            notifier.clearSearch();
                            _searchController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _isSearchExpanded = false);
                          },
                          onBookmark: (v) => notifier.toggleBookmark(v),
                          bookmarkedVerseIds: state.bookmarkedVerseIds,
                          onLoadMore: notifier.loadMore,
                          selectedBookId: state.selectedBookId,
                          selectedChapter: state.selectedChapter,
                          onProjectRange: (startVerse, endVerse) =>
                              _projectVerseRange(startVerse, endVerse),
                        )
                      : state.selectedBookId == null
                          ? BibleEmptyReadingView(
                              lastReadBookId: state.lastReadBookId,
                              lastReadChapter: state.lastReadChapter,
                              lastReadVerse: state.lastReadVerse,
                              books: state.books,
                              onContinueReading: () {
                                if (state.lastReadBookId != null &&
                                    state.lastReadChapter != null) {
                                  notifier.navigateToVerse(
                                    state.lastReadBookId!,
                                    state.lastReadChapter!,
                                    state.lastReadVerse ?? 1,
                                  );
                                }
                              },
                            )
                          : BibleReadingView(
                              verses: state.verses,
                              selectedChapter: state.selectedChapter,
                              bookName: state.books
                                      .where((b) => b.id == state.selectedBookId)
                                      .firstOrNull
                                  ?.name ??
                                  '',
                              onProjectPassage: (chapter, verses) =>
                                  _projectVerse(verses.first),
                              onToggleBookmark: (v) => notifier.toggleBookmark(v),
                              activeVerse: state.activeVerse,
                              onSelectVerse: notifier.selectVerse,
                              bookmarkedVerseIds: state.bookmarkedVerseIds,
                              selectionMode: state.selectionMode,
                              selectedVerseIds: state.selectedVerseIds,
                              onToggleSelectionMode: notifier.toggleSelectionMode,
                              onToggleVerseSelection: notifier.toggleVerseSelection,
                              onSelectAllVerses: notifier.selectAllVerses,
                              fontSize: state.bibleFontSize,
                              useSerifFont: state.useSerifFont,
                              isLoadingVerses: state.isLoadingVerses,
                              isLargeScreen: widget.isLargeScreen,
                              onShowCrossRefs: _showMobileCrossRefs,
                              onFontSizeChanged: notifier.setBibleFontSize,
                            ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isLargeScreen) ...[
            const VerticalDivider(width: 1, thickness: 1),
            const BibleRightSidebar(),
          ],
        ],
      ),
    );
  }

  Future<void> _projectVerse(BibleVerse v) async {
    final state = ref.read(bibleControllerProvider);
    final bookName = state.books
            .where((b) => b.id == v.bookId)
            .firstOrNull
            ?.name ??
        v.bookName ??
        '';
    await ref
        .read(projectionControllerProvider.notifier)
        .projectVerse(v.bookId, v.chapter, v.verse, bookName);
    if (!mounted) return;
    ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    await ref
        .read(projectionControllerProvider.notifier)
        .triggerProjection(context, widget.isLargeScreen);
  }

  Future<void> _projectVerseRange(BibleVerse start, BibleVerse end) async {
    final state = ref.read(bibleControllerProvider);
    final bookName = state.books
            .where((b) => b.id == start.bookId)
            .firstOrNull
            ?.name ??
        start.bookName ??
        '';
    final repo = ref.read(bibleRepositoryProvider);
    final allVerses = await repo.getVerses(start.bookId, start.chapter);
    final rangeVerses = allVerses
        .where((v) => v.verse >= start.verse && v.verse <= end.verse)
        .toList();
    if (rangeVerses.isEmpty) return;
    final slides = rangeVerses
        .map((v) => Verse(
              label: '$bookName ${start.chapter}:${v.verse}',
              text: v.text,
              order: v.verse,
            ))
        .toList();
    ref.read(projectionControllerProvider.notifier).setBiblePassage(
      slides,
      title: '$bookName ${start.chapter}:${start.verse}-${end.verse}',
      bookId: start.bookId,
      chapter: start.chapter,
      bookName: bookName,
    );
    if (!mounted) return;
    ref.read(setRepositoryProvider).recordBibleProjection(
        '$bookName ${start.chapter}:${start.verse}-${end.verse}', rangeVerses.map((v) => v.text).join('\n'));
    await ref
        .read(projectionControllerProvider.notifier)
        .triggerProjection(context, widget.isLargeScreen);
  }

  void _showMobileCrossRefs(BibleVerse verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BibleMobileCrossRefSheet(verse: verse),
    );
  }
}
