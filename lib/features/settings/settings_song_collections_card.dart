import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

class SongCollectionsCard extends ConsumerStatefulWidget {
  const SongCollectionsCard({super.key});

  @override
  ConsumerState<SongCollectionsCard> createState() =>
      _SongCollectionsCardState();
}

class _SongCollectionsCardState extends ConsumerState<SongCollectionsCard> {
  StreamSubscription<List<Category>>? _sub;
  List<Category> _categories = const [];
  Map<int, int> _counts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(songRepositoryProvider);
    _sub = repo.watchCategories().listen((categories) async {
      final counts = <int, int>{};
      for (final category in categories) {
        counts[category.id] = await repo.getSongCountByCategory(category.id);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _counts = counts;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.collections_bookmark_outlined,
            title: 'Song Collections',
            subtitle: 'Categories grouping your songs. Deleting a category keeps songs as Uncategorized.',
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No collections yet. Create one from the Songs tab.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _categories.map((category) {
                final count = _counts[category.id] ?? 0;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '$count song${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: theme.colorScheme.error,
                      tooltip: 'Delete collection',
                      onPressed: () => _confirmDelete(context, category),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete collection "${category.name}"'),
        content: Text(
          'Its ${_counts[category.id] ?? 0} songs will be kept and moved to '
          'Uncategorized. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(songRepositoryProvider)
                  .deleteCategory(category.id);
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Danger Zone
