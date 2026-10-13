// Song-search result rows, kept separate from the Bible rows so each list stays
// a manageable size. Both are dispatched from ProjectionSearchResultsList.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_search_results.dart';

/// Renders paged song results.
class SongSearchResults extends ConsumerWidget {
  final ProjectionSearchState searchState;
  final int selectedIndex;
  final ScrollController? scrollController;
  final void Function(int index, ProjectionSearchState state) onPick;

  const SongSearchResults({
    super.key,
    required this.searchState,
    required this.selectedIndex,
    required this.onPick,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final songs = searchState.songResults;

    if (songs.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    // Songs are paged exactly like Bible verses so a broad query in a big
    // songbook stays manageable and readable instead of dumping hundreds of
    // matches at once.
    final hasMore = songs.length < searchState.totalSongCount;
    final itemCount = hasMore ? songs.length + 1 : songs.length;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == songs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: TextButton.icon(
                onPressed: searchState.isLoading
                    ? null
                    : () => ref
                        .read(projectionSearchProvider.notifier)
                        .loadMoreSongs(),
                icon: searchState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(
                  'Load more songs (${searchState.totalSongCount - songs.length} more)',
                ),
              ),
            ),
          );
        }

        final s = songs[index];
        final isSelected = index == selectedIndex;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: ListTile(
            tileColor: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${s.songNum}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            title: HighlightedText(
              text: s.title,
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
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  if (s.key != null && s.key!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Key: ${s.key}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      s.body.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  tooltip: 'Share song',
                  onPressed: () =>
                      shareSearchItem(context, s, searchState),
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
