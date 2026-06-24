import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/features/history/history_controller.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';
import 'package:visual_song_book/features/song_list/widgets/song_list_item.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final selectedSongId = ref.watch(selectedSongIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recent Activity',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          if (state.history.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearHistory(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your history is empty.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Songs you project will appear here.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: state.history.length,
                  itemBuilder: (context, index) {
                    final song = state.history[index];
                    return SongListItem(
                      song: song,
                      isSelected: song.id == selectedSongId,
                      onTap: () {
                        ref.read(selectedSongIdProvider.notifier).state = song.id;
                      },
                    );
                  },
                ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear your recent song history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyControllerProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
