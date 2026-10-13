import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/services/share_service.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_bible_search_results.dart';
import 'package:visual_song_book/features/projection/projection_song_search_results.dart';


/// Composed result list for the current search state.
/// Bible mode puts an exact reference match first, then the text-search hits.
List<dynamic> composeSearchResults(ProjectionSearchState state) {
  if (!state.isBibleMode) return state.songResults;
  return <dynamic>[
    if (state.exactMatch != null) state.exactMatch!,
    ...state.bibleResults,
  ];
}

/// Number of results currently presented to the user.
int countSearchResults(ProjectionSearchState state) {
  if (!state.isBibleMode) return state.songResults.length;
  return (state.exactMatch != null ? 1 : 0) + state.bibleResults.length;
}

/// Shares a search result, reporting failures through [context]'s snackbar.
Future<void> shareSearchItem(
  BuildContext context,
  dynamic item,
  ProjectionSearchState state,
) async {
  try {
    if (state.isBibleMode && item is BibleVerse) {
      final text = '📖 ${item.reference}\n\n${item.text}';
      await ShareService.shareText(text);
    } else if (!state.isBibleMode && item is Song) {
      final buffer = StringBuffer();
      buffer.writeln('🎵 ${item.title}');
      if (item.songNum > 0) buffer.writeln('Song #${item.songNum}');
      if (item.key != null && item.key!.isNotEmpty) buffer.writeln('Key: ${item.key}');
      buffer.writeln('');
      buffer.writeln(item.body);
      await ShareService.shareText(buffer.toString());
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }
}

/// Renders the current search results.
///
/// [selectedIndex] is highlighted and shows the "press Enter" affordance;
/// [onPick] projects the item at that index; [onShare] shares it.
class ProjectionSearchResultsList extends ConsumerWidget {
  final ProjectionSearchState searchState;
  final int selectedIndex;
  final ScrollController? scrollController;
  final void Function(int index, ProjectionSearchState state) onPick;

  const ProjectionSearchResultsList({
    super.key,
    required this.searchState,
    required this.selectedIndex,
    required this.onPick,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = searchState.query;

    if (searchState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed: ${searchState.error}',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searchState.isBibleMode ? Icons.menu_book : Icons.library_music,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                    searchState.isBibleMode
                    ? 'Type a verse, reference, or words — "amaz*", "gr?ce"'
                    : 'Type a song title or lyric — "*" matches anything, "?" one character',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (searchState.isBibleMode) {
      return BibleSearchResults(
        searchState: searchState,
        selectedIndex: selectedIndex,
        scrollController: scrollController,
        onPick: onPick,
      );
    }
    return SongSearchResults(
      searchState: searchState,
      selectedIndex: selectedIndex,
      scrollController: scrollController,
      onPick: onPick,
    );
  }
}