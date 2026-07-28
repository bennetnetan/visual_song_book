import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class BibleSearchBar extends StatefulWidget {
  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final List<String> recentSearches;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onSuggestionTap;

  const BibleSearchBar({
    super.key,
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.recentSearches,
    required this.onClearRecent,
    required this.onSuggestionTap,
  });

  @override
  State<BibleSearchBar> createState() => _BibleSearchBarState();
}

class _BibleSearchBarState extends State<BibleSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.text = widget.query;
  }

  @override
  void didUpdateWidget(BibleSearchBar oldWidget) {
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

class BibleSearchSuggestionSection extends StatelessWidget {
  final BibleState state;
  final BibleController notifier;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const BibleSearchSuggestionSection({
    super.key,
    required this.state,
    required this.notifier,
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
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
                    searchController.clear();
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
                    searchController.text = q;
                    notifier.search(q);
                    searchFocusNode.unfocus();
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
        searchController.text = label;
        notifier.search(label);
        searchFocusNode.unfocus();
      },
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class BibleSearchResultsView extends ConsumerWidget {
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

  const BibleSearchResultsView({
    super.key,
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
      padding: EdgeInsets.fromLTRB(
          24, 10, 24, MediaQuery.of(context).padding.bottom + 24),
      children: [
        if (exactMatch != null) ...[
          _buildBestMatchCard(theme),
          const SizedBox(height: 20),
        ],
        if (results.isNotEmpty) ...[
          _buildResultsHeader(state, theme),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 12),
          ...results.map((v) => BibleResultCard(
                verse: v,
                query: state.query,
                onTap: () => onNavigate(v),
                onLongPress: () => _showResultMenu(context, v),
                isBookmarked: bookmarkedVerseIds.contains(v.verse),
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
                    style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBestMatchCard(ThemeData theme) {
    return Container(
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
    );
  }

  Widget _buildResultsHeader(BibleState state, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BibleSectionTitle(
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

class BibleResultCard extends StatelessWidget {
  final BibleVerse verse;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isBookmarked;

  const BibleResultCard({
    super.key,
    required this.verse,
    required this.query,
    required this.onTap,
    this.onLongPress,
    this.isBookmarked = false,
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
                  const Text('•',
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
                  if (isBookmarked)
                    Icon(Icons.bookmark,
                        size: 14, color: theme.colorScheme.primary),
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

class _BibleSectionTitle extends StatelessWidget {
  final String title;
  final bool isUppercase;

  const _BibleSectionTitle({required this.title, this.isUppercase = true});

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
