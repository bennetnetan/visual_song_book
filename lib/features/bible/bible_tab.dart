import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
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

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // Main reading area
        Expanded(
          child: Column(
            children: [
              // Search bar
              _SearchBar(
                query: state.query,
                onChanged: notifier.search,
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
                            FocusManager.instance.primaryFocus?.unfocus();
                          }
                        },
                        onProject: (v) async {
                          await ref
                              .read(projectionControllerProvider.notifier)
                              .projectVerse(v.bookId, v.chapter, v.verse, v.bookName ?? '');
                          if (!context.mounted) return;
                          ref
                              .read(setRepositoryProvider)
                              .recordBibleProjection(v.reference, v.text);
                          await ref
                              .read(projectionControllerProvider.notifier)
                              .triggerProjection(context, isLargeScreen);
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
                        onProjectPassage: (chapter, verses) async {
                          final v = verses.first;
                          final bookName = state.books
                              .where((b) => b.id == state.selectedBookId)
                              .firstOrNull?.name ?? '';
                          await ref
                              .read(projectionControllerProvider.notifier)
                              .projectVerse(v.bookId, v.chapter, v.verse, bookName);
                          if (!context.mounted) return;
                          ref
                              .read(setRepositoryProvider)
                              .recordBibleProjection(v.reference, v.text);
                          await ref
                              .read(projectionControllerProvider.notifier)
                              .triggerProjection(context, isLargeScreen);
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
                      ),
              ),
            ],
          ),
        ),
        // Right sidebar - cross references & bookmarks (desktop only)
        if (isLargeScreen) ...[
          const VerticalDivider(width: 1, thickness: 1),
          const _RightSidebar(),
        ],
      ],
    );
  }

  Widget _buildSuggestionChip(String label, BibleController notifier) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
      onPressed: () {
        notifier.search(label);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}



class _SearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onFocusChange;

  const _SearchBar({
    required this.query,
    required this.onChanged,
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
          Expanded(
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
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                onSubmitted: (_) => _focusNode.unfocus(),
                textInputAction: TextInputAction.search,
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

  const _ReadingView({
    this.selectedChapter,
    required this.verses,
    required this.bookName,
    required this.onProjectPassage,
    required this.onToggleBookmark,
    required this.activeVerse,
    required this.onSelectVerse,
  });

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<_ReadingView> {
  final _scrollController = ScrollController();
  final _activeVerseKey = GlobalKey();

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
    super.dispose();
  }

  int get _totalItemCount => widget.verses.length;

  void _showNavigationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _BibleNavigationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Chapter selector navigation header
        if (widget.selectedChapter != null && widget.verses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [

                Consumer(
                  builder: (context, ref, child) {
                    return IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        ref.read(bibleControllerProvider.notifier).prevChapter();
                      },
                      tooltip: 'Previous Chapter',
                    );
                  },
                ),
                Expanded(
                  child: Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.15),
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
                      onPressed: () => _showNavigationDialog(context),
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    return IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        ref.read(bibleControllerProvider.notifier).nextChapter();
                      },
                      tooltip: 'Next Chapter',
                    );
                  },
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
                  itemCount: _totalItemCount,
                  itemBuilder: (context, index) {
                    // Verse items
                    if (index < widget.verses.length) {
                      final v = widget.verses[index];
                      final isActive = widget.activeVerse?.id == v.id;
                      return Container(
                        key: isActive ? _activeVerseKey : null,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.text,
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.65,
                                          fontFamily: 'Inter',
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
                                if (isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 4),
                                    child: Icon(Icons.link, size: 14, color: colorScheme.primary),
                                  ),
                                Consumer(
                                  builder: (context, ref, child) {
                                    return FutureBuilder<bool>(
                                      future: ref.read(setRepositoryProvider).isBookmarked(v.bookId, v.chapter, v.verse),
                                      builder: (context, snapshot) {
                                        final isBookmarked = snapshot.data ?? false;
                                        return PopupMenuButton<String>(
                                          icon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isBookmarked)
                                                Icon(Icons.bookmark, size: 14, color: colorScheme.primary),
                                              Icon(Icons.more_vert, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                            ],
                                          ),
                                          onSelected: (action) {
                                            if (action == 'project') {
                                              widget.onProjectPassage(v.chapter, [v]);
                                            } else if (action == 'bookmark') {
                                              widget.onToggleBookmark(v);
                                            }
                                          },
                                          itemBuilder: (context) {
                                             final isLargeScreen = MediaQuery.of(context).size.width >= 900;
                                             return [
                                               PopupMenuItem(
                                                 value: 'project',
                                                 child: ListTile(
                                                   leading: const Icon(Icons.tv, size: 18),
                                                   title: Text(isLargeScreen ? 'Project' : 'Present', style: const TextStyle(fontSize: 13)),
                                                   dense: true,
                                                 ),
                                               ),
                                               PopupMenuItem(
                                                 value: 'bookmark',
                                                 child: ListTile(
                                                   leading: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                                   title: Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark', style: const TextStyle(fontSize: 13)),
                                                   dense: true,
                                                 ),
                                               ),
                                             ];
                                           },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
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
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(center.dx, center.dy, center.dx + 1, center.dy + 1),
      items: [
        PopupMenuItem(
          value: 'project',
          child: ListTile(
            leading: const Icon(Icons.tv, size: 18),
            title: Text(isLargeScreen ? 'Project' : 'Present'),
            dense: true,
          ),
        ),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 24),
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
                        onTap: () {
                          notifier.navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart);
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
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                onPressed: () {
                  notifier.navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart);
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

class _BibleNavigationDialog extends ConsumerStatefulWidget {
  const _BibleNavigationDialog();

  @override
  ConsumerState<_BibleNavigationDialog> createState() => _BibleNavigationDialogState();
}

class _BibleNavigationDialogState extends ConsumerState<_BibleNavigationDialog> {
  String _tab = 'book'; // 'book', 'chapter', or 'verse'
  int? _tempBookId;
  String _tempBookName = '';
  List<int> _tempChapters = [];
  int? _tempChapter;
  List<int> _tempVerses = [];
  String _bookFilter = '';

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
        if (_tempChapter != null) {
          _fetchVersesForInit(_tempBookId!, _tempChapter!);
        }
      }
    }
  }

  void _fetchVersesForInit(int bookId, int chapter) async {
    final verses = await ref.read(bibleRepositoryProvider).getVerses(bookId, chapter);
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

    final filteredOt = otBooks.where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase())).toList();
    final filteredNt = ntBooks.where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase())).toList();

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
                      label: const Center(child: Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'chapter',
                      onSelected: _tempBookId == null ? null : (val) {
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
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'verse',
                      onSelected: (_tempBookId == null || _tempChapter == null) ? null : (val) {
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildBookSelector(List<BibleBook> ot, List<BibleBook> nt, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
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
                    color: isSelected ? colorScheme.primary : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
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
                    color: isSelected ? colorScheme.primary : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
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
    final chapters = await ref.read(bibleRepositoryProvider).getChapters(b.id);
    setState(() {
      _tempBookId = b.id;
      _tempBookName = b.name;
      _tempChapters = chapters;
      _tempChapter = null;
      _tempVerses = [];
      _tab = 'chapter';
    });
  }

  Future<void> _selectChapter(int ch) async {
    final verses = await ref.read(bibleRepositoryProvider).getVerses(_tempBookId!, ch);
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
        return InkWell(
          onTap: () => _selectChapter(ch),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$ch',
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
            ref.read(bibleControllerProvider.notifier).navigateToVerse(_tempBookId!, _tempChapter!, v);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
