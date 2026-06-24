import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/features/history/history_controller.dart';
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Recent Activity',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            onTap: (i) => ref.read(_selectedHistoryTabProvider.notifier).state = HistoryTabType.values[i],
            isScrollable: false,
            tabs: const [
              Tab(text: 'Songs'),
              Tab(text: 'Sets'),
              Tab(text: 'Bible'),
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
                  );
                },
              );
    }
  }

  Widget _emptyState(BuildContext context, String type) {
    final icon = type == 'set'
        ? Icons.queue_music_outlined
        : type == 'bible'
        ? Icons.menu_book_outlined
        : Icons.history;
    final label = type == 'set'
        ? 'Sets'
        : type == 'bible'
        ? 'Bible passages'
        : 'Songs';
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
            'No $label projected yet.',
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
