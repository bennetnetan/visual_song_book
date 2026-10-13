import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/widgets/bible_result_card.dart';
import 'package:visual_song_book/features/bible/widgets/bible_section_title.dart';
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
    final readingFont = state.readingFontFamily;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
          24, 10, 24, MediaQuery.of(context).padding.bottom + 24),
      children: [
        if (exactMatch != null) ...[
          _buildBestMatchCard(theme, readingFont),
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
                fontFamily: readingFont,
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
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBestMatchCard(ThemeData theme, String readingFont) {
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
                        style: TextStyle(
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
                        style: TextStyle(
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
                  style: TextStyle(
                    fontFamily: readingFont,
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
                      style: TextStyle(
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
        BibleSectionTitle(
          title: 'Related Results for "${state.query}"',
          isUppercase: false,
        ),
        Text(
          results.length < state.totalSearchCount
              ? 'showing ${results.length} of ${state.totalSearchCount} results'
              : '${results.length} results',
          style: TextStyle(
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
            if (kIsWeb || !Platform.isAndroid)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Navigate to Verse'),
                  onTap: () {
                    Navigator.pop(context);
                    onNavigate(verse);
                  },
                ),
              ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.tv),
                title: const Text('Project'),
                onTap: () {
                  Navigator.pop(context);
                  onProject(verse);
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(isVerseBookmarked ? Icons.bookmark : Icons.bookmark_border),
                title: Text(isVerseBookmarked ? 'Remove Bookmark' : 'Bookmark'),
                onTap: () {
                  Navigator.pop(context);
                  onBookmark(verse);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

