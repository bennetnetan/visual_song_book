import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';

/// Whether the sets bottom sheet is currently open.
///
/// Kept in a provider (rather than local widget state) because the button and
/// the sheet live in different widget trees.
final setsDrawerOpenProvider = StateProvider<bool>((ref) => false);

/// Button that opens the [showProjectionSetsDrawer] bottom sheet.
class ProjectionSetsButton extends ConsumerWidget {
  final SetsState setsState;

  const ProjectionSetsButton({super.key, required this.setsState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;
    if (setObj == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.playlist_play, size: 18),
          label: Text('SET: ${setObj.name} (${setsState.setItems.length} songs)'),
          onPressed: () =>
              showProjectionSetsDrawer(context, ref, setsState),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: theme.colorScheme.primary),
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Shows the selected set as a modal bottom sheet: track number, title, key and
/// any per-song notes, and tapping a song projects it (which also opens the
/// projector window automatically).
void showProjectionSetsDrawer(
  BuildContext context,
  WidgetRef ref,
  SetsState setsState,
) {
  ref.read(setsDrawerOpenProvider.notifier).state = true;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.playlist_play, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    setsState.sets
                        .where((s) => s.id == setsState.selectedSetId)
                        .firstOrNull
                        ?.name ?? 'Set',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${setsState.setItems.length} songs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: setsState.setItems.length,
                itemBuilder: (context, i) {
                  final item = setsState.setItems[i];
                  final song = setsState.availableSongs
                      .where((s) => s.id == item.songId)
                      .firstOrNull;
                  if (song == null) return const SizedBox.shrink();

                  final projectionState = ref.read(projectionControllerProvider);
                  final isCurrentSong = projectionState.currentSong?.id == song.id;
                  final keyText = item.key ?? song.key;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: isCurrentSong
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCurrentSong
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w500,
                        color: isCurrentSong ? Theme.of(context).colorScheme.primary : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item.notes != null && item.notes!.isNotEmpty
                        ? Text(
                            '📝 ${item.notes!}',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: keyText != null && keyText.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              keyText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      // Auto-projection is triggered inside setSong.
                      ref.read(projectionControllerProvider.notifier).setSong(song);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() => ref.read(setsDrawerOpenProvider.notifier).state = false);
}
