import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';


class ProjectionHeader extends StatelessWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const ProjectionHeader({super.key, required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBible = state.isBibleMode;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isBible
                ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBible ? Icons.menu_book : Icons.music_note,
                size: 14,
                color: isBible
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                isBible ? 'Bible' : 'Song',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isBible
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.contentTitle ??
                    state.currentSong?.title ??
                    (state.slides.isNotEmpty ? state.slides.first.label : 'Untitled'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isBible && state.currentSong != null)
                Text(
                  'Song #${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              if (isBible)
                Text(
                  'Chapter ${state.bibleChapter ?? '?'} — ${state.slides.length} verse${state.slides.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
            ],
          ),
        ),
        if (!isBible && state.currentSong != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AutoChorusToggle(
              value: state.autoInsertChorus,
              onChanged: notifier.setAutoInsertChorus,
            ),
          ),
        if (state.hasContent)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, size: 18),
              tooltip: 'Share',
              onPressed: notifier.shareCurrentSlide,
            ),
          ),
        if (isLargeScreen)
          Consumer(
            builder: (context, ref, _) {
              final ltState = ref.watch(lowerThirdControllerProvider);
              final ltNotifier =
                  ref.read(lowerThirdControllerProvider.notifier);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.view_headline,
                    size: 16,
                    color: ltState.isEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    ltState.isEnabled ? 'Lower Third: ON' : 'Lower Third: OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: ltState.isEnabled ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: ltState.isEnabled,
                  onSelected: (_) => ltNotifier.toggleEnabled(),
                ),
              );
            },
          ),
        ElevatedButton.icon(
          onPressed: notifier.clearSong,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Clear Screen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-chorus toggle chip — shown inline next to Clear Screen for songs
// ─────────────────────────────────────────────────────────────────────────────

class AutoChorusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AutoChorusToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Auto-insert chorus between verses',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.repeat : Icons.repeat_one,
                size: 14,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Chorus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide list — works for both songs and Bible passages
// ─────────────────────────────────────────────────────────────────────────────
