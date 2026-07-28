import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

final bibleControllerProvider =
    StateNotifierProvider<BibleController, BibleState>((ref) {
      final repo = ref.watch(bibleRepositoryProvider);
      final setRepo = ref.watch(setRepositoryProvider);
      return BibleController(repo, setRepo);
    });

final _searchBarFocusedProvider = StateProvider<bool>((ref) => false);

class BibleTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const BibleTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<BibleTab> createState() => _BibleTabState();
}

class _BibleTabState extends ConsumerState<BibleTab> {
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();

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
          _searchFocusNode.requestFocus();
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _SearchBar(
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
                if (ref.watch(_searchBarFocusedProvider) && state.query.isEmpty)
                  _buildSuggestionSection(state, notifier),
                Expanded(
                  child: state.searchResults.isNotEmpty ||
                          state.exactMatch != null ||
                          state.query.isNotEmpty
                      ? _SearchResultsView(
                          results: state.searchResults,
                          exactMatch: state.exactMatch,
                          onSelectExact: () {
                            final v = state.exactMatch;
                            if (v != null) {
                              notifier.navigateToVerse(v.bookId, v.chapter, v.verse);
                              notifier.clearSearch();
                              _searchController.clear();
                              FocusManager.instance.primaryFocus?.unfocus();
                            }
                          },
                          onProject: (v) => _projectVerse(v),
                          onNavigate: (v) {
                            notifier.navigateToVerse(v.bookId, v.chapter, v.verse);
                            notifier.clearSearch();
                            _searchController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
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
                          ? _EmptyReadingView(
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
                          : _ReadingView(
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
                            ),
                ),
              ],
            ),
          ),
          if (widget.isLargeScreen) ...[
            const VerticalDivider(width: 1, thickness: 1),
            const _RightSidebar(),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionSection(BibleState state, BibleController notifier) {
    if (state.recentSearches.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'RECENT SEARCHES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.clearRecentSearches();
                    _searchController.clear();
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: state.recentSearches.take(6).map((q) {
                return ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _searchController.text = q;
                    notifier.search(q);
                    _searchFocusNode.unfocus();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildSuggestionChip('Salvation', notifier),
          _buildSuggestionChip('Love', notifier),
          _buildSuggestionChip('Eternal Life', notifier),
          _buildSuggestionChip('Faith', notifier),
          _buildSuggestionChip('Grace', notifier),
          _buildSuggestionChip('Peace', notifier),
          _buildSuggestionChip('Gen 1:1', notifier),
          _buildSuggestionChip('Jn 3:16', notifier),
          _buildSuggestionChip('Ps 23:1', notifier),
          _buildSuggestionChip('Rev 2:1', notifier),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, BibleController notifier) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
      onPressed: () {
        _searchController.text = label;
        notifier.search(label);
        _searchFocusNode.unfocus();
      },
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
      builder: (context) => _MobileCrossRefSheet(verse: verse),
    );
  }
}

// ==================== SEARCH BAR ====================

class _SearchBar extends StatefulWidget {
  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final List<String> recentSearches;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onSuggestionTap;

  const _SearchBar({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.recentSearches,
    required this.onClearRecent,
    required this.onSuggestionTap,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.text = widget.query;
  }

  @override
  void didUpdateWidget(_SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != widget.controller.text) {
      widget.controller.text = widget.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.focusNode.unfocus(),
          textInputAction: TextInputAction.search,
          style: GoogleFonts.inter(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search verses, keywords, or "Jn 3:16"...',
            hintStyle: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

// ==================== EMPTY READING VIEW ====================

class _EmptyReadingView extends StatelessWidget {
  final int? lastReadBookId;
  final int? lastReadChapter;
  final int? lastReadVerse;
  final List<BibleBook> books;
  final VoidCallback? onContinueReading;

  const _EmptyReadingView({
    this.lastReadBookId,
    this.lastReadChapter,
    this.lastReadVerse,
    this.books = const [],
    this.onContinueReading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastBookName = lastReadBookId != null
        ? books.where((b) => b.id == lastReadBookId).firstOrNull?.name
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Select a book',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('or search above',
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            if (lastBookName != null && onContinueReading != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: InkWell(
                  onTap: onContinueReading,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline,
                            color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue Reading',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$lastBookName ${lastReadChapter ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== READING VIEW ====================

class _ReadingView extends StatefulWidget {
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final String bookName;
  final void Function(int chapter, List<BibleVerse> verses) onProjectPassage;
  final ValueChanged<BibleVerse> onToggleBookmark;
  final BibleVerse? activeVerse;
  final ValueChanged<BibleVerse> onSelectVerse;
  final Set<int> bookmarkedVerseIds;
  final bool selectionMode;
  final Set<int> selectedVerseIds;
  final VoidCallback onToggleSelectionMode;
  final ValueChanged<int> onToggleVerseSelection;
  final VoidCallback onSelectAllVerses;
  final double fontSize;
  final bool useSerifFont;
  final bool isLoadingVerses;
  final bool isLargeScreen;
  final ValueChanged<BibleVerse> onShowCrossRefs;

  const _ReadingView({
    this.selectedChapter,
    required this.verses,
    required this.bookName,
    required this.onProjectPassage,
    required this.onToggleBookmark,
    required this.activeVerse,
    required this.onSelectVerse,
    required this.bookmarkedVerseIds,
    required this.selectionMode,
    required this.selectedVerseIds,
    required this.onToggleSelectionMode,
    required this.onToggleVerseSelection,
    required this.onSelectAllVerses,
    required this.fontSize,
    required this.useSerifFont,
    required this.isLoadingVerses,
    required this.isLargeScreen,
    required this.onShowCrossRefs,
  });

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<_ReadingView> {
  final _scrollController = ScrollController();
  final _activeVerseKey = GlobalKey();
  final _verseJumpController = TextEditingController();
  bool _showJumpInput = false;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToActive();
  }

  @override
  void didUpdateWidget(covariant _ReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeVerse?.id != oldWidget.activeVerse?.id) {
      _scheduleScrollToActive();
    }
  }

  void _scheduleScrollToActive() {
    final v = widget.activeVerse;
    if (v == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final currentContext = _activeVerseKey.currentContext;
      if (currentContext != null) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        final index = widget.verses.indexWhere((verse) => verse.id == v.id);
        if (index < 0) return;
        const itemHeight = 60.0;
        final viewportHeight = _scrollController.position.viewportDimension;
        final targetOffset = (index * itemHeight) - (viewportHeight * 0.3);
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _verseJumpController.dispose();
    super.dispose();
  }

  void _jumpToVerse() {
    final num = int.tryParse(_verseJumpController.text);
    if (num == null) return;
    final verse = widget.verses.where((v) => v.verse == num).firstOrNull;
    if (verse != null) {
      widget.onSelectVerse(verse);
    }
    setState(() => _showJumpInput = false);
    _verseJumpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final readingFont = widget.useSerifFont ? 'EB Garamond' : 'Inter';

    return Column(
      children: [
        // Chapter selector + toolbar
        if (widget.selectedChapter != null && widget.verses.isNotEmpty)
          _buildChapterHeader(colorScheme),

        const Divider(height: 1),

        // Selection mode toolbar
        if (widget.selectionMode)
          _buildSelectionToolbar(colorScheme),

        // Verse list
        Expanded(
          child: widget.isLoadingVerses
              ? _buildSkeleton(colorScheme)
              : widget.verses.isEmpty
                  ? Center(
                      child: Text('No verses in this chapter',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    )
                  : _buildVerseList(colorScheme, readingFont),
        ),
      ],
    );
  }

  Widget _buildChapterHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(bibleControllerProvider.notifier).prevChapter(),
                tooltip: 'Previous Chapter',
              );
            },
          ),
          Expanded(
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  backgroundColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                label: Text(
                  '${widget.bookName} ${widget.selectedChapter}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => const _BibleNavigationDialog(),
                ),
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(bibleControllerProvider.notifier).nextChapter(),
                tooltip: 'Next Chapter',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar(ColorScheme colorScheme) {
    final selected = widget.selectedVerseIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onToggleSelectionMode,
            tooltip: 'Exit selection',
          ),
          const SizedBox(width: 8),
          Text(
            '$selected verse${selected == 1 ? '' : 's'} selected',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onSelectAllVerses,
            child: const Text('Select All', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: selected > 0 ? _projectSelectedVerses : null,
            icon: const Icon(Icons.tv, size: 16),
            label: Text('Project ($selected)',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _projectSelectedVerses() {
    final selected = widget.verses
        .where((v) => widget.selectedVerseIds.contains(v.id))
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (selected.isEmpty) return;
    // Use the first verse as the entry point, project the whole chapter
    // from that point. For a proper range, we project the first verse
    // and the controller loads the full chapter.
    widget.onProjectPassage(selected.first.chapter, selected);
  }

  Widget _buildSkeleton(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      itemCount: 12,
      itemBuilder: (context, index) {
        final widths = [0.85, 0.7, 0.9, 0.6, 0.8, 0.75, 0.95, 0.65, 0.8, 0.72, 0.88, 0.55];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: widths[index % widths.length],
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: widths[(index + 3) % widths.length] * 0.7,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerseList(ColorScheme colorScheme, String readingFont) {
    return Stack(
      children: [
        ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 80),
          itemCount: widget.verses.length,
          itemBuilder: (context, index) {
            final v = widget.verses[index];
            final isActive = widget.activeVerse?.id == v.id;
            final isBookmarked = widget.bookmarkedVerseIds.contains(v.verse);
            final isSelected = widget.selectedVerseIds.contains(v.id);

            return Container(
              key: isActive ? _activeVerseKey : null,
              color: isActive
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                      : Colors.transparent,
              child: InkWell(
                onTap: widget.selectionMode
                    ? () => widget.onToggleVerseSelection(v.id)
                    : () => widget.onSelectVerse(v),
                onDoubleTap: widget.selectionMode
                    ? null
                    : () => widget.onProjectPassage(v.chapter, [v]),
                onLongPress: widget.selectionMode
                    ? null
                    : () => _showVerseMenu(context, v),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.selectionMode) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      SizedBox(
                        width: 28,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${v.verse}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: 0.7),
                              height: 1.7,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.text,
                              style: TextStyle(
                                fontFamily: readingFont,
                                fontSize: widget.fontSize,
                                height: 1.65,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 8),
                              _InlineCrossReferences(verse: v),
                            ],
                          ],
                        ),
                      ),
                      if (isActive && !widget.selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: GestureDetector(
                            onTap: () {
                              if (!widget.isLargeScreen) {
                                widget.onShowCrossRefs(v);
                              }
                            },
                            child: Icon(Icons.link,
                                size: 14,
                                color: widget.isLargeScreen
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant),
                          ),
                        ),
                      if (!widget.selectionMode)
                        _VersePopupMenu(
                          verse: v,
                          isBookmarked: isBookmarked,
                          isLargeScreen: widget.isLargeScreen,
                          onProject: () => widget.onProjectPassage(v.chapter, [v]),
                          onBookmark: () => widget.onToggleBookmark(v),
                          onNavigate: () {
                            final container = ProviderScope.containerOf(context);
                            container.read(bibleControllerProvider.notifier).navigateToVerse(v.bookId, v.chapter, v.verse);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Verse jump FAB
        if (widget.verses.length > 30)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showJumpInput)
                  Container(
                    width: 80,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _verseJumpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'V.',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _jumpToVerse(),
                    ),
                  ),
                FloatingActionButton.small(
                  onPressed: () {
                    setState(() => _showJumpInput = !_showJumpInput);
                    if (!_showJumpInput) _verseJumpController.clear();
                  },
                  heroTag: 'verse_jump',
                  child: Icon(_showJumpInput ? Icons.close : Icons.tag),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showVerseMenu(BuildContext context, BibleVerse verse) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox?.localToGlobal(renderBox.size.center(Offset.zero)) ??
        Offset.zero;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          center.dx, center.dy, center.dx + 1, center.dy + 1),
      items: [
        PopupMenuItem(
          value: 'project',
          child: ListTile(
            leading: const Icon(Icons.tv, size: 18),
            title: Text(isLargeScreen ? 'Project' : 'Present',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'navigate',
          child: const ListTile(
            leading: Icon(Icons.open_in_new, size: 18),
            title: Text('Navigate to Verse', style: TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: ListTile(
            leading: Icon(
                ProviderScope.containerOf(context).read(bibleControllerProvider).bookmarkedVerseIds.contains(verse.verse)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                size: 18),
            title: Text(
                ProviderScope.containerOf(context).read(bibleControllerProvider).bookmarkedVerseIds.contains(verse.verse)
                    ? 'Remove Bookmark'
                    : 'Bookmark',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'select',
          child: const ListTile(
            leading: Icon(Icons.checklist, size: 18),
            title: Text('Select Verses', style: TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
      ],
    ).then((action) {
      if (action == 'project') {
        widget.onProjectPassage(verse.chapter, [verse]);
      } else if (action == 'navigate') {
        ProviderScope.containerOf(context).read(bibleControllerProvider.notifier).navigateToVerse(
            verse.bookId, verse.chapter, verse.verse);
      } else if (action == 'bookmark') {
        widget.onToggleBookmark(verse);
      } else if (action == 'select') {
        ProviderScope.containerOf(context).read(bibleControllerProvider.notifier).toggleSelectionMode();
      }
    });
  }
}

// ==================== VERSE POPUP MENU ====================

class _VersePopupMenu extends StatelessWidget {
  final BibleVerse verse;
  final bool isBookmarked;
  final bool isLargeScreen;
  final VoidCallback onProject;
  final VoidCallback onBookmark;
  final VoidCallback onNavigate;

  const _VersePopupMenu({
    required this.verse,
    required this.isBookmarked,
    required this.isLargeScreen,
    required this.onProject,
    required this.onBookmark,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBookmarked)
            Icon(Icons.bookmark, size: 14, color: Theme.of(context).colorScheme.primary),
          Icon(Icons.more_vert,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5)),
        ],
      ),
      onSelected: (action) {
        if (action == 'project') onProject();
        else if (action == 'bookmark') onBookmark();
        else if (action == 'navigate') onNavigate();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'project',
          child: ListTile(
            leading: const Icon(Icons.tv, size: 18),
            title: Text(isLargeScreen ? 'Project' : 'Present',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'navigate',
          child: const ListTile(
            leading: Icon(Icons.open_in_new, size: 18),
            title: Text('Navigate to Verse', style: TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: ListTile(
            leading: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 18),
            title: Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
      ],
    );
  }
}

// ==================== SEARCH RESULTS ====================

class _SearchResultsView extends ConsumerWidget {
  final List<BibleVerse> results;
  final void Function(BibleVerse) onProject;
  final void Function(BibleVerse) onNavigate;
  final void Function(BibleVerse) onBookmark;
  final BibleVerse? exactMatch;
  final VoidCallback? onSelectExact;
  final VoidCallback? onLoadMore;
  final Set<int> bookmarkedVerseIds;
  final int? selectedBookId;
  final int? selectedChapter;
  final void Function(BibleVerse start, BibleVerse end) onProjectRange;

  const _SearchResultsView({
    required this.results,
    required this.onProject,
    required this.onNavigate,
    required this.onBookmark,
    this.exactMatch,
    this.onSelectExact,
    this.onLoadMore,
    this.bookmarkedVerseIds = const {},
    this.selectedBookId,
    this.selectedChapter,
    required this.onProjectRange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final theme = Theme.of(context);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 24),
      children: [
        if (exactMatch != null) ...[
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelectExact,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
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
                              exactMatch!.reference,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '"${exactMatch!.text}"',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.touch_app, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to navigate',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (results.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionTitle(
                title: 'Related Results for "${state.query}"',
                isUppercase: false,
              ),
              Text(
                results.length < state.totalSearchCount
                    ? 'showing ${results.length} of ${state.totalSearchCount} results'
                    : '${results.length} results',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 12),
          ...results.map((v) => _ResultCard(
                verse: v,
                query: state.query,
                onTap: () => onNavigate(v),
                onLongPress: () => _showResultMenu(context, v),
                isBookmarked: bookmarkedVerseIds.contains(v.verse),
                onBookmark: () => onBookmark(v),
                onProject: () => onProject(v),
              )),
          if (results.length < state.totalSearchCount) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(
                  'Show more (${state.totalSearchCount - results.length} remaining)',
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: onLoadMore,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (results.isEmpty && exactMatch == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64.0),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "${state.query}"',
                    style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showResultMenu(BuildContext context, BibleVerse verse) {
    final isVerseBookmarked = bookmarkedVerseIds.contains(verse.verse);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Navigate to Verse'),
              onTap: () {
                Navigator.pop(context);
                onNavigate(verse);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tv),
              title: const Text('Project'),
              onTap: () {
                Navigator.pop(context);
                onProject(verse);
              },
            ),
            ListTile(
              leading: Icon(isVerseBookmarked ? Icons.bookmark : Icons.bookmark_border),
              title: Text(isVerseBookmarked ? 'Remove Bookmark' : 'Bookmark'),
              onTap: () {
                Navigator.pop(context);
                onBookmark(verse);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== RESULT CARD ====================

class _ResultCard extends StatelessWidget {
  final BibleVerse verse;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isBookmarked;
  final VoidCallback? onBookmark;
  final VoidCallback? onProject;

  const _ResultCard({
    required this.verse,
    required this.query,
    required this.onTap,
    this.onLongPress,
    this.isBookmarked = false,
    this.onBookmark,
    this.onProject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                  const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
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
                  if (isBookmarked)
                    Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 8),
              HighlightedText(
                text: verse.text,
                query: query,
                style: GoogleFonts.ebGaramond(
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
                highlightStyle: GoogleFonts.ebGaramond(
                  fontSize: 20,
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
}

// ==================== SECTION TITLE ====================

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isUppercase;

  const _SectionTitle({required this.title, this.isUppercase = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (isUppercase) ...[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          isUppercase ? title.toUpperCase() : title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: isUppercase ? 1.2 : 0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ==================== RIGHT SIDEBAR ====================

class _RightSidebar extends ConsumerWidget {
  const _RightSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(bibleControllerProvider);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.activeVerse != null) ...[
              const _SidebarLabel(title: 'Cross-References'),
              const SizedBox(height: 16),
              if (state.isLoadingCrossReferences)
                const Center(child: CircularProgressIndicator())
              else if (state.activeCrossReferences.isEmpty)
                Text(
                  'No cross references found.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                )
              else
                _CrossReferenceList(references: state.activeCrossReferences),
              const SizedBox(height: 16),
            ],
            const _SidebarLabel(title: 'Bookmarks'),
            const SizedBox(height: 16),
            _BookmarkList(),
          ],
        ),
      ),
    );
  }
}

// ==================== CROSS-REFERENCE LIST (expandable) ====================

class _CrossReferenceList extends StatefulWidget {
  final List<BibleCrossReference> references;
  const _CrossReferenceList({required this.references});

  @override
  State<_CrossReferenceList> createState() => _CrossReferenceListState();
}

class _CrossReferenceListState extends State<_CrossReferenceList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed =
        _showAll ? widget.references : widget.references.take(5).toList();
    final hasMore = widget.references.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayed.map((cr) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  ProviderScope.containerOf(context).read(bibleControllerProvider.notifier).navigateToVerse(
                      cr.toBookId, cr.toChapter, cr.toVerseStart);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cr.reference,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cr.targetText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )),
        if (hasMore)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll ? 'Show less' : 'Show all (${widget.references.length})',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

// ==================== BOOKMARK LIST ====================

class _BookmarkList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setRepo = ref.read(setRepositoryProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    return FutureBuilder<List<BibleBookmark>>(
      future: setRepo.getBookmarks(),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? [];
        if (bookmarks.isEmpty) {
          return Text(
            'No bookmarks yet.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          );
        }
        return Column(
          children: bookmarks
              .take(10)
              .map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => notifier.navigateToVerse(
                          b.bookId, b.chapter, b.verseNum),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark,
                              size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.reference,
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ==================== SIDEBAR LABEL ====================

class _SidebarLabel extends StatelessWidget {
  final String title;
  const _SidebarLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ==================== INLINE CROSS-REFERENCES ====================

class _InlineCrossReferences extends ConsumerWidget {
  final BibleVerse verse;
  const _InlineCrossReferences({required this.verse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);
    final theme = Theme.of(context);

    if (state.isLoadingCrossReferences) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0),
        child: SizedBox(
          height: 12,
          width: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    if (state.activeCrossReferences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CROSS-REFERENCES:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: state.activeCrossReferences.take(6).map((cr) {
              return ActionChip(
                label: Text(
                  cr.reference,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                onPressed: () {
                  notifier.navigateToVerse(
                      cr.toBookId, cr.toChapter, cr.toVerseStart);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ==================== MOBILE CROSS-REF BOTTOM SHEET ====================

class _MobileCrossRefSheet extends ConsumerWidget {
  final BibleVerse verse;
  const _MobileCrossRefSheet({required this.verse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                verse.reference,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                verse.text,
                style: GoogleFonts.ebGaramond(
                  fontSize: 16,
                  height: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'CROSS-REFERENCES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (state.isLoadingCrossReferences)
                const Center(child: CircularProgressIndicator())
              else if (state.activeCrossReferences.isEmpty)
                Text(
                  'No cross references found.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: state.activeCrossReferences.map((cr) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          cr.reference,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        subtitle: Text(
                          cr.targetText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          notifier.navigateToVerse(
                              cr.toBookId, cr.toChapter, cr.toVerseStart);
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== BIBLE NAVIGATION DIALOG ====================

class _BibleNavigationDialog extends ConsumerStatefulWidget {
  const _BibleNavigationDialog();

  @override
  ConsumerState<_BibleNavigationDialog> createState() =>
      _BibleNavigationDialogState();
}

class _BibleNavigationDialogState
    extends ConsumerState<_BibleNavigationDialog> {
  String _tab = 'book';
  int? _tempBookId;
  String _tempBookName = '';
  List<int> _tempChapters = [];
  int? _tempChapter;
  List<int> _tempVerses = [];
  String _bookFilter = '';
  Map<int, int> _tempVerseCounts = {};

  @override
  void initState() {
    super.initState();
    final state = ref.read(bibleControllerProvider);
    _tempBookId = state.selectedBookId;
    if (_tempBookId != null) {
      final bk = state.books.where((b) => b.id == _tempBookId).firstOrNull;
      if (bk != null) {
        _tempBookName = bk.name;
        _tempChapters = state.chapters;
        _tempChapter = state.selectedChapter;
        _tempVerseCounts = state.chapterVerseCounts;
        if (_tempChapter != null) {
          _fetchVersesForInit(_tempBookId!, _tempChapter!);
        }
      }
    }
  }

  void _fetchVersesForInit(int bookId, int chapter) async {
    final verses =
        await ref.read(bibleRepositoryProvider).getVerses(bookId, chapter);
    if (mounted) {
      setState(() {
        _tempVerses = verses.map((v) => v.verse).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bibleControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final otBooks = state.books.where((b) => b.id <= 39).toList();
    final ntBooks = state.books.where((b) => b.id > 39).toList();

    final filteredOt = otBooks
        .where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase()))
        .toList();
    final filteredNt = ntBooks
        .where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'BIBLE NAVIGATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                          child: Text('Book',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                      selected: _tab == 'book',
                      onSelected: (val) {
                        if (val) setState(() => _tab = 'book');
                      },
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _tempBookId == null ? 'Chapter' : _tempBookName,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'chapter',
                      onSelected: _tempBookId == null
                          ? null
                          : (val) {
                              if (val) setState(() => _tab = 'chapter');
                            },
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _tempChapter == null ? 'Verse' : 'Ch $_tempChapter',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'verse',
                      onSelected: (_tempBookId == null || _tempChapter == null)
                          ? null
                          : (val) {
                              if (val) setState(() => _tab = 'verse');
                            },
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
            ),
            if (_tab == 'book')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _bookFilter = val),
                ),
              ),
            Expanded(
              child: _tab == 'book'
                  ? _buildBookSelector(filteredOt, filteredNt, colorScheme)
                  : _tab == 'chapter'
                      ? _buildChapterSelector(colorScheme)
                      : _buildVerseSelector(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSelector(
      List<BibleBook> ot, List<BibleBook> nt, ColorScheme colorScheme) {
    final recentBookIds =
        ref.read(bibleControllerProvider).recentBookIds;
    final recentBooks = recentBookIds
        .map((id) =>
            ref.read(bibleControllerProvider).books.where((b) => b.id == id).firstOrNull)
        .whereType<BibleBook>()
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (recentBooks.isNotEmpty && _bookFilter.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recentBooks.map((b) {
              return ActionChip(
                label: Text(b.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: () => _selectBook(b),
                backgroundColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.3),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (ot.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'OLD TESTAMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.primary,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: ot.length,
            itemBuilder: (context, i) {
              final b = ot[i];
              final isSelected = b.id == _tempBookId;
              return InkWell(
                onTap: () => _selectBook(b),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (nt.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'NEW TESTAMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.primary,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: nt.length,
            itemBuilder: (context, i) {
              final b = nt[i];
              final isSelected = b.id == _tempBookId;
              return InkWell(
                onTap: () => _selectBook(b),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Future<void> _selectBook(BibleBook b) async {
    final chapters =
        await ref.read(bibleRepositoryProvider).getChapters(b.id);
    final verseCounts =
        await ref.read(bibleRepositoryProvider).getChapterVerseCounts(b.id);
    setState(() {
      _tempBookId = b.id;
      _tempBookName = b.name;
      _tempChapters = chapters;
      _tempVerseCounts = verseCounts;
      _tempChapter = null;
      _tempVerses = [];
      _tab = 'chapter';
    });
  }

  Future<void> _selectChapter(int ch) async {
    final verses = await ref
        .read(bibleRepositoryProvider)
        .getVerses(_tempBookId!, ch);
    if (mounted) {
      setState(() {
        _tempChapter = ch;
        _tempVerses = verses.map((v) => v.verse).toList();
        _tab = 'verse';
      });
    }
  }

  Widget _buildChapterSelector(ColorScheme colorScheme) {
    if (_tempBookId == null) {
      return const Center(child: Text('Please select a book first'));
    }

    final displayChapters = _tempChapters.isNotEmpty
        ? _tempChapters
        : List.generate(50, (index) => index + 1);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayChapters.length,
      itemBuilder: (context, i) {
        final ch = displayChapters[i];
        final verseCount = _tempVerseCounts[ch];
        return InkWell(
          onTap: () => _selectChapter(ch),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$ch',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (verseCount != null)
                  Text(
                    '$verseCount',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseSelector(ColorScheme colorScheme) {
    if (_tempBookId == null || _tempChapter == null) {
      return const Center(child: Text('Please select book and chapter first'));
    }

    final displayVerses = _tempVerses.isNotEmpty
        ? _tempVerses
        : List.generate(50, (index) => index + 1);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayVerses.length,
      itemBuilder: (context, i) {
        final v = displayVerses[i];
        return InkWell(
          onTap: () {
            ref
                .read(bibleControllerProvider.notifier)
                .navigateToVerse(_tempBookId!, _tempChapter!, v);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$v',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}
