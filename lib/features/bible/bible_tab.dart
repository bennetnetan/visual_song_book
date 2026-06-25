import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/widgets/neomorphic_widgets.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

final bibleControllerProvider =
    StateNotifierProvider<BibleController, BibleState>((ref) {
      final repo = ref.watch(bibleRepositoryProvider);
      return BibleController(repo);
    });

final _searchBarFocusedProvider = StateProvider<bool>((ref) => false);

class BibleTab extends ConsumerWidget {
  final bool isLargeScreen;

  const BibleTab({super.key, required this.isLargeScreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    return Scaffold(
      body: !state.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : !isLargeScreen && state.selectedBookId == null
          // Mobile: full-screen book picker when no book is selected
          ? _BookPicker(books: state.books, onSelect: notifier.selectBook)
          // Desktop layout or mobile with book selected
          : Row(
              children: [
          // Main reading area
                Expanded(
                  child: Column(
                    children: [
                      // Search bar
                      _SearchBar(
                        query: state.query,
                        onChanged: notifier.search,
                        showBackButton: !isLargeScreen && state.selectedBookId != null,
                        onBack: notifier.clearSelection,
                        onFocusChange: (focused) =>
                            ref.read(_searchBarFocusedProvider.notifier).state = focused,
                      ),
                      // Suggested searches when search bar is focused and empty
                      if (ref.watch(_searchBarFocusedProvider) && state.query.isEmpty)
                        Padding(
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
                        ),
                      // Content area
                      Expanded(
                        child: state.searchResults.isNotEmpty || state.exactMatch != null || state.query.isNotEmpty
                            ? _SearchResultsView(
                                results: state.searchResults,
                                exactMatch: state.exactMatch,
                                onSelectExact: () {
                                  final v = state.exactMatch;
                                  if (v != null) {
                                    ref
                                        .read(bibleControllerProvider.notifier)
                                        .navigateToVerse(v.bookId, v.chapter, v.verse);
                                    ref
                                        .read(bibleControllerProvider.notifier)
                                        .clearSearch();
                                  }
                                },
                                onProject: (v) {
                                  ref
                                      .read(projectionControllerProvider.notifier)
                                      .projectVerse(v.bookId, v.chapter, v.verse, v.bookName ?? '');
                                  ref
                                      .read(setRepositoryProvider)
                                      .recordBibleProjection(v.reference, v.text);
                                  ref.read(activeDashboardTabProvider.notifier).state = 4;
                                },
                                onLoadMore: () => ref.read(bibleControllerProvider.notifier).loadMore(),
                              )
                            : state.selectedBookId == null
                            ? _EmptyReadingView()
                            : _ReadingView(
                                verses: state.verses,
                                selectedChapter: state.selectedChapter,
                                bookName: state.books
                                    .where((b) => b.id == state.selectedBookId)
                                    .firstOrNull?.name ?? '',
                                onProjectPassage: (chapter, verses) {
                                  final v = verses.first;
                                  final bookName = state.books
                                      .where((b) => b.id == state.selectedBookId)
                                      .firstOrNull?.name ?? '';
                                  ref
                                      .read(projectionControllerProvider.notifier)
                                      .projectVerse(v.bookId, v.chapter, v.verse, bookName);
                                  ref
                                      .read(setRepositoryProvider)
                                      .recordBibleProjection(v.reference, v.text);
                                  ref.read(activeDashboardTabProvider.notifier).state = 4;
                                },
                                onToggleBookmark: (v) {
                                  final setRepo = ref.read(setRepositoryProvider);
                                  setRepo.isBookmarked(v.bookId, v.chapter, v.verse).then((isMarked) {
                                    if (isMarked) {
                                      setRepo.getBookmarks().then((marks) {
                                        final existing = marks.firstWhere(
                                          (m) => m.bookId == v.bookId && m.chapter == v.chapter && m.verseNum == v.verse,
                                          orElse: () => BibleBookmark(id: -1, bookId: 0, chapter: 0, verseNum: 0, reference: '', verseText: '', bookName: '', createdAt: DateTime.now()),
                                        );
                                        if (existing.id != -1) setRepo.removeBookmark(existing.id);
                                      });
                                    } else {
                                      setRepo.addBookmark(
                                        v.bookId, v.chapter, v.verse,
                                        v.reference, v.text, v.bookName ?? '',
                                      );
                                    }
                                  });
                                },
                                activeVerse: state.activeVerse,
                                onSelectVerse: notifier.selectVerse,
                                activeCrossReferences: state.activeCrossReferences,
                                isLoadingCrossReferences: state.isLoadingCrossReferences,
                                onNavigateToRef: (bookId, chapter, verse) =>
                                    notifier.navigateToVerse(bookId, chapter, verse),
                              ),
                      ),
                    ],
                  ),
                ),
                // Right sidebar - cross references & bookmarks (desktop only)
                if (isLargeScreen) ...[                  const VerticalDivider(width: 1, thickness: 1),
                  const _RightSidebar(),
                ],
              ],
            ),
    );
  }

  Widget _buildSuggestionChip(String label, BibleController notifier) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
      onPressed: () => notifier.search(label),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _BookPicker extends StatelessWidget {
  final List<BibleBook> books;
  final ValueChanged<int> onSelect;

  const _BookPicker({required this.books, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'SELECT A BOOK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(book.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      book.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final bool showBackButton;
  final VoidCallback? onBack;
  final ValueChanged<bool>? onFocusChange;

  const _SearchBar({
    required this.query,
    required this.onChanged,
    this.showBackButton = false,
    this.onBack,
    this.onFocusChange,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      widget.onFocusChange?.call(_focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(_SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            NeoButton(
              onPressed: widget.onBack,
              padding: const EdgeInsets.all(10),
              borderRadius: 999,
              child: const Icon(Icons.arrow_back, size: 20),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search verses, keywords...',
                  hintStyle: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
                  suffixIcon: widget.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _controller.clear();
                            widget.onChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Select a book', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('or search above', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _ReadingView extends StatefulWidget {
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final String bookName;
  final void Function(int chapter, List<BibleVerse> verses) onProjectPassage;
  final ValueChanged<BibleVerse> onToggleBookmark;
  final BibleVerse? activeVerse;
  final ValueChanged<BibleVerse> onSelectVerse;
  final List<BibleCrossReference> activeCrossReferences;
  final bool isLoadingCrossReferences;
  final void Function(int bookId, int chapter, int verse) onNavigateToRef;

  const _ReadingView({
    this.selectedChapter,
    required this.verses,
    required this.bookName,
    required this.onProjectPassage,
    required this.onToggleBookmark,
    required this.activeVerse,
    required this.onSelectVerse,
    this.activeCrossReferences = const [],
    this.isLoadingCrossReferences = false,
    required this.onNavigateToRef,
  });

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<_ReadingView> {
  final _scrollController = ScrollController();

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
    final index = widget.verses.indexWhere((verse) => verse.id == v.id);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const itemHeight = 60.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (index * itemHeight) - (viewportHeight * 0.3);
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

  bool get _showCrossRefSection => widget.activeCrossReferences.isNotEmpty;

  int get _totalItemCount {
    if (!_showCrossRefSection) return widget.verses.length;
    return widget.verses.length + 1 + widget.activeCrossReferences.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Chapter title
        if (widget.selectedChapter != null && widget.verses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bookName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chapter ${widget.selectedChapter}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        // Verse list + cross-references
        Expanded(
          child: widget.verses.isEmpty
              ? Center(
                  child: Text('Select a chapter', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: _totalItemCount,
                  itemBuilder: (context, index) {
                    // Verse items
                    if (index < widget.verses.length) {
                      final v = widget.verses[index];
                      final isActive = widget.activeVerse?.id == v.id;
                      return Container(
                        color: isActive
                            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelectVerse(v),
                          onDoubleTap: () => widget.onProjectPassage(v.chapter, [v]),
                          onLongPress: () => _showVerseMenu(context, v, widget.onProjectPassage, widget.onToggleBookmark),
                          onSecondaryTap: () => _showVerseMenu(context, v, widget.onProjectPassage, widget.onToggleBookmark),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${v.verse}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isActive ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.7),
                                        height: 1.7,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    v.text,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.65,
                                      fontFamily: 'Inter',
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 4),
                                    child: Icon(Icons.link, size: 14, color: colorScheme.primary),
                                  ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                  onSelected: (action) {
                                    if (action == 'project') {
                                      widget.onProjectPassage(v.chapter, [v]);
                                    } else if (action == 'bookmark') {
                                      widget.onToggleBookmark(v);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'project', child: ListTile(leading: Icon(Icons.tv, size: 18), title: Text('Project', style: TextStyle(fontSize: 13)), dense: true)),
                                    const PopupMenuItem(value: 'bookmark', child: ListTile(leading: Icon(Icons.bookmark_border, size: 18), title: Text('Bookmark', style: TextStyle(fontSize: 13)), dense: true)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Cross-reference section header
                    if (index == widget.verses.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 16),
                            _SectionTitle(title: 'Cross-References'),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    }

                    // Cross-reference items
                    final xrefIndex = index - widget.verses.length - 1;
                    if (xrefIndex < widget.activeCrossReferences.length) {
                      final cr = widget.activeCrossReferences[xrefIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => widget.onNavigateToRef(cr.toBookId, cr.toChapter, cr.toVerseStart),
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cr.reference,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cr.targetText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  static void _showVerseMenu(
    BuildContext context,
    BibleVerse verse,
    void Function(int chapter, List<BibleVerse> verses) onProject,
    void Function(BibleVerse) onBookmark,
  ) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox?.localToGlobal(renderBox.size.center(Offset.zero)) ?? Offset.zero;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(center.dx, center.dy, center.dx + 1, center.dy + 1),
      items: [
        const PopupMenuItem(value: 'project', child: ListTile(leading: Icon(Icons.tv, size: 18), title: Text('Project'), dense: true)),
        const PopupMenuItem(value: 'bookmark', child: ListTile(leading: Icon(Icons.bookmark_border, size: 18), title: Text('Bookmark'), dense: true)),
      ],
    ).then((action) {
      if (action == 'project') {
        onProject(verse.chapter, [verse]);
      } else if (action == 'bookmark') {
        onBookmark(verse);
      }
    });
  }
}

class _SearchResultsView extends ConsumerWidget {
  final List<BibleVerse> results;
  final void Function(BibleVerse) onProject;
  final BibleVerse? exactMatch;
  final VoidCallback? onSelectExact;
  final VoidCallback? onLoadMore;

  const _SearchResultsView({
    required this.results,
    required this.onProject,
    this.exactMatch,
    this.onSelectExact,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        if (exactMatch != null) ...[
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
                onTap: onSelectExact,
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.touch_app, size: 14, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to navigate',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white38,
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
                onTap: () => onProject(v),
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
                  Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "${state.query}"',
                    style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

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

class _ResultCard extends StatelessWidget {
  final BibleVerse verse;
  final String query;
  final VoidCallback onTap;

  const _ResultCard({required this.verse, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                ],
              ),
              const SizedBox(height: 8),
              _HighlightedText(
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

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    int start = 0;
    int indexOfQuery;

    while ((indexOfQuery = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfQuery > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfQuery), style: style));
      }
      spans.add(TextSpan(text: text.substring(indexOfQuery, indexOfQuery + query.length), style: highlightStyle));
      start = indexOfQuery + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RightSidebar extends ConsumerWidget {
  const _RightSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);
    final setRepo = ref.read(setRepositoryProvider);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cross-References section
            if (state.activeVerse != null) ...[
              _SidebarLabel(title: 'Cross-References'),
              const SizedBox(height: 16),
              if (state.isLoadingCrossReferences)
                const Center(child: CircularProgressIndicator())
              else if (state.activeCrossReferences.isEmpty)
                Text(
                  'No cross references found.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                )
              else
                ...state.activeCrossReferences.take(5).map((cr) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => notifier.navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart),
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
              const SizedBox(height: 16),
            ],

            // Bookmarks section
            _SidebarLabel(title: 'Bookmarks'),
            const SizedBox(height: 16),
            FutureBuilder<List<BibleBookmark>>(
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
                  children: bookmarks.take(5).map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => notifier.navigateToVerse(b.bookId, b.chapter, b.verseNum),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.reference,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
