import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart' show setsControllerProvider;


// ---------------------------------------------------------------------------
// Shared header note: this file was extracted from projection_tab.dart when
// the projection feature was split into focused modules. Keep new widgets in
// their own file here rather than growing any single file past ~500 lines.
// ---------------------------------------------------------------------------
/// Persists the set-navigator collapsed/expanded state across widget-tree
/// rebuilds (the panel moves between the large-screen Row and the small-screen
/// Column, which would otherwise reset local widget state and reopen the panel
/// on every rebuild).
final _setNavigatorExpandedProvider = StateProvider<bool>((ref) => false);

class SetNavigatorPanel extends ConsumerStatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const SetNavigatorPanel({super.key, required this.state, required this.notifier});

  @override
  ConsumerState<SetNavigatorPanel> createState() => _SetNavigatorPanelState();
}

class _SetNavigatorPanelState extends ConsumerState<SetNavigatorPanel> {
  // Expanded state is now in _setNavigatorExpandedProvider so it survives
  // widget-tree moves (large ↔ small screen layout changes).

  @override
  Widget build(BuildContext context) {
    final setsState = ref.watch(setsControllerProvider);
    final bool isExpanded = ref.watch(_setNavigatorExpandedProvider);
    final theme = Theme.of(context);

    // Only show when a set is selected and has items
    if (setsState.selectedSetId == null || setsState.setItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;
    if (setObj == null) return const SizedBox.shrink();

    // Determine which song is currently on screen
    final currentSongId = widget.state.currentSong?.id;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Header bar
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ref.read(_setNavigatorExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.playlist_play,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SET: ${setObj.name}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${setsState.setItems.length} songs',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Song list
          if (isExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
                itemCount: setsState.setItems.length,
                itemBuilder: (ctx, i) {
                  final item = setsState.setItems[i];
                  final song = setsState.availableSongs
                      .where((s) => s.id == item.songId)
                      .firstOrNull;
                  if (song == null) return const SizedBox.shrink();

                  final isActive = song.id == currentSongId;
                  final setKey = item.key ?? song.key;

                  return GestureDetector(
                    onTap: () => widget.notifier.setSong(song),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Position number
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          // Song title
                          Expanded(
                            child: Text(
                              song.title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Key badge
                          if (setKey != null && setKey.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                setKey,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          // Playing indicator
                          if (isActive)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.play_arrow,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search mode toggle — Bible / Song chips (replaces SegmentedButton to avoid
// rebuild loops inside SearchAnchor.viewTrailing)
// ─────────────────────────────────────────────────────────────────────────────

