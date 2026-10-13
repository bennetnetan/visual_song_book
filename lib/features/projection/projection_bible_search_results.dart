// Bible-search result rows, kept separate from the song rows so each list stays
// a manageable size. Both are dispatched from ProjectionSearchResultsList.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_search_results.dart';

/// Renders paged Bible verse results, with an exact reference match first.
class BibleSearchResults extends ConsumerWidget {
  final ProjectionSearchState searchState;
  final int selectedIndex;
  final ScrollController? scrollController;
  final void Function(int index, ProjectionSearchState state) onPick;

  const BibleSearchResults({
    super.key,
    required this.searchState,
    required this.selectedIndex,
    required this.onPick,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final results = composeSearchResults(searchState);

    if (results.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    final hasMore =
        searchState.bibleResults.length < searchState.totalBibleCount;
    final itemCount = hasMore ? results.length + 1 : results.length;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: TextButton.icon(
                onPressed: searchState.isLoading
                    ? null
                    : () => ref
                        .read(projectionSearchProvider.notifier)
                        .loadMoreBible(),
                icon: searchState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load more results'),
              ),
            ),
          );
        }

        final v = results[index] as BibleVerse;
        final isExact = v == searchState.exactMatch;
        final isSelected = index == selectedIndex;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                  : isExact
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2.0 : (isExact ? 1.5 : 1),
            ),
          ),
          child: ListTile(
            tileColor: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.30)
                : isExact
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isExact
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book,
                size: 16,
                color: isExact
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
              ),
            ),
            title: HighlightedText(
              text: v.reference,
              query: searchState.query,
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
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            // Three lines is enough to recognise the passage without a card so
            // tall it hides the rest of the results.
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: HighlightedText(
                text: v.text,
                query: searchState.query,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                highlightStyle: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  tooltip: 'Share verse',
                  onPressed: () =>
                      shareSearchItem(context, v, searchState),
                ),
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        Icon(Icons.keyboard_return,
                            size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Enter',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.present_to_all,
                      size: 16,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
            onTap: () => onPick(index, searchState),
          ),
        );
      },
    );
  }
}
