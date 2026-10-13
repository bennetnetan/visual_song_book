
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

class DangerZoneCard extends ConsumerWidget {
  const DangerZoneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Danger Zone',
              color: theme.colorScheme.error,
              subtitle: 'These actions are irreversible. Proceed with caution.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _confirmDeleteAll(context, ref),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Remove All Collections'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.6)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will wipe all imported songs and categories. This action cannot be undone.',
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
                  .deleteAllSongs();
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );
  }
}

