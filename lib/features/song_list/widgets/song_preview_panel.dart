import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';

class SongPreviewPanel extends ConsumerWidget {
  final Song song;

  const SongPreviewPanel({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${song.songNum}. ${song.title}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Song',
                onPressed: () => context
                    .push('/song-editor?id=${song.id}'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Song',
                onPressed: () => _confirmDelete(
                    context, ref, song.id, song.title),
              ),
            ],
          ),
          if (song.author != null ||
              song.key != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                if (song.author != null)
                  Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text(song.author!),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                if (song.key != null)
                  Chip(
                    avatar: const Icon(Icons.music_note, size: 16),
                    label: Text('Key: ${song.key!}'),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(projectionControllerProvider.notifier)
                  .setSong(song);
              ref.read(activeDashboardTabProvider.notifier).state =
                  1;
            },
            icon: const Icon(Icons.tv),
            label: const Text('Send to Projector'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainer
                  .withValues(alpha: 0.3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'LYRICS PREVIEW',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          song.body,
                          style: GoogleFonts.lora(
                            fontSize: 17,
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, int songId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(songRepositoryProvider).deleteSong(songId);
              ref.read(selectedSongIdProvider.notifier).state = null;
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
