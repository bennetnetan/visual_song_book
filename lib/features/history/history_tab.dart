import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/history/history_controller.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';
import 'package:visual_song_book/features/song_list/widgets/song_list_item.dart';

final _selectedHistoryTabProvider = StateProvider<HistoryTabType>(
  (ref) => HistoryTabType.songs,
);

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final selectedTab = ref.watch(_selectedHistoryTabProvider);
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: isLargeScreen ? null : 0,
          title: isLargeScreen
              ? const Text(
                  'Recent Activity',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                )
              : null,
          actions: [
            if (!state.isLoading && _canClear(selectedTab, state))
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear history',
                onPressed: () => _confirmClearHistory(context, ref, selectedTab),
              ),
          ],
          bottom: TabBar(
            onTap: (i) => ref.read(_selectedHistoryTabProvider.notifier).state = HistoryTabType.values[i],
            isScrollable: false,
            tabs: const [
              Tab(text: 'Songs'),
              Tab(text: 'Sets'),
              Tab(text: 'Bible'),
              Tab(text: 'Bookmarks'),
            ],
          ),
        ),
        body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, ref, selectedTab),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, HistoryTabType tab) {
    final state = ref.watch(historyControllerProvider);
    final selectedSongId = ref.watch(selectedSongIdProvider);

    switch (tab) {
      case HistoryTabType.songs:
        return state.songs.isEmpty
            ? _emptyState(context, 'song')
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: state.songs.length,
                itemBuilder: (context, index) {
                  final song = state.songs[index];
                  return SongListItem(
                    song: song,
                    isSelected: song.id == selectedSongId,
                    onTap: () {
                      ref.read(selectedSongIdProvider.notifier).state = song.id;
                      ref.read(activeDashboardTabProvider.notifier).state = 0;
                    },
                  );
                },
              );
      case HistoryTabType.sets:
        return state.sets.isEmpty
            ? _emptyState(context, 'set')
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: state.sets.length,
                itemBuilder: (context, index) {
                  final item = state.sets[index];
                  return ListTile(
                    leading: const Icon(Icons.queue_music_outlined),
                    title: Text(item.setName),
                    subtitle: Text(_formatDate(item.accessedAt)),
                    onTap: () {
                      ref.read(setsControllerProvider.notifier).selectSet(item.setId);
                      ref.read(activeDashboardTabProvider.notifier).state = 1;
                    },
                  );
                },
              );
      case HistoryTabType.bible:
        return state.bible.isEmpty
            ? _emptyState(context, 'bible')
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: state.bible.length,
                itemBuilder: (context, index) {
                  final item = state.bible[index];
                  return ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(item.reference),
                    subtitle: Text(_formatDate(item.accessedAt)),
                    onTap: () async {
                      final repo = ref.read(bibleRepositoryProvider);
                      final notifier = ref.read(bibleControllerProvider.notifier);
                      final colonIdx = item.reference.lastIndexOf(':');
                      String bookChapter;
                      int? verseNum;
                      if (colonIdx > 0) {
                        bookChapter = item.reference.substring(0, colonIdx);
                        verseNum = int.tryParse(item.reference.substring(colonIdx + 1));
                      } else {
                        bookChapter = item.reference;
                      }
                      final spaceIdx = bookChapter.lastIndexOf(' ');
                      if (spaceIdx > 0) {
                        final bookName = bookChapter.substring(0, spaceIdx);
                        final chapterNum = int.tryParse(bookChapter.substring(spaceIdx + 1));
                        if (chapterNum != null) {
                          final book = await repo.getBookByName(bookName);
                          if (book != null) {
                            if (verseNum != null) {
                              await notifier.navigateToVerse(book.id, chapterNum, verseNum);
                            } else {
                              await notifier.selectBook(book.id);
                              await notifier.selectChapter(chapterNum);
                            }
                            ref.read(activeDashboardTabProvider.notifier).state = 2;
                          }
                        }
                      }
                    },
                  );
                },
              );
      case HistoryTabType.bookmarks:
        return state.bookmarks.isEmpty
            ? _emptyState(context, 'bookmark')
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: state.bookmarks.length,
                itemBuilder: (context, index) {
                  final item = state.bookmarks[index];
                  return ListTile(
                    leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                    title: Text(item.reference),
                    subtitle: Text(item.verseText, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () {
                        ref.read(setRepositoryProvider).removeBookmark(item.id);
                      },
                    ),
                    onTap: () async {
                      final repo = ref.read(bibleRepositoryProvider);
                      final notifier = ref.read(bibleControllerProvider.notifier);
                      final book = await repo.getBookByName(item.bookName);
                      if (book != null) {
                        await notifier.navigateToVerse(book.id, item.chapter, item.verseNum);
                        ref.read(activeDashboardTabProvider.notifier).state = 2;
                      }
                    },
                  );
                },
              );
    }
  }

  bool _canClear(HistoryTabType tab, HistoryState state) {
    switch (tab) {
      case HistoryTabType.songs:
        return state.songs.isNotEmpty;
      case HistoryTabType.sets:
        return state.sets.isNotEmpty;
      case HistoryTabType.bible:
        return state.bible.isNotEmpty;
      case HistoryTabType.bookmarks:
        return false;
    }
  }

  String _clearLabel(HistoryTabType tab) {
    switch (tab) {
      case HistoryTabType.songs:
        return 'song';
      case HistoryTabType.sets:
        return 'set';
      case HistoryTabType.bible:
        return 'Bible passage';
      case HistoryTabType.bookmarks:
        return '';
    }
  }

  Future<void> _clearHistory(WidgetRef ref, HistoryTabType tab) {
    final notifier = ref.read(historyControllerProvider.notifier);
    switch (tab) {
      case HistoryTabType.songs:
        return notifier.clearSongHistory();
      case HistoryTabType.sets:
        return notifier.clearSetHistory();
      case HistoryTabType.bible:
        return notifier.clearBibleHistory();
      case HistoryTabType.bookmarks:
        return Future.value();
    }
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    WidgetRef ref,
    HistoryTabType tab,
  ) async {
    final label = _clearLabel(tab);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history'),
        content: Text('Clear all $label history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clearHistory(ref, tab);
    }
  }

  Widget _emptyState(BuildContext context, String type) {
    final icon = type == 'set'
        ? Icons.queue_music_outlined
        : type == 'bible'
        ? Icons.menu_book_outlined
        : type == 'bookmark'
        ? Icons.bookmark_outline
        : Icons.history;
    final label = type == 'set'
        ? 'Sets'
        : type == 'bible'
        ? 'Bible passages'
        : type == 'bookmark'
        ? 'Bookmarks'
        : 'Songs';
    final message = type == 'bookmark'
        ? 'No bookmarks saved yet.'
        : 'No $label projected yet.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
