
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/models/projection_mode.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class ProjectionPreferencesCard extends ConsumerWidget {
  const ProjectionPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);
    final theme = Theme.of(context);
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.settings_overscan,
            title: 'Projection Settings',
            subtitle: 'Configure display behaviour and output mode',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prevent Screen Sleep',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep the display active during presentation',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.keepAwake,
                onChanged: notifier.setKeepAwake,
              ),
            ],
          ),
          if (isLargeScreen) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Open Projector Window',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start projecting as soon as you pick a song, '
                        'history item or Bible passage',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.autoOpenProjector,
                  onChanged: notifier.setAutoOpenProjector,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Display Mode',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How the live projection output is positioned on desktop screens.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ProjectionMode>(
              segments: const [
                ButtonSegment(
                  value: ProjectionMode.single,
                  label: Text('Single Screen'),
                  icon: Icon(Icons.screenshot_monitor, size: 16),
                ),
                ButtonSegment(
                  value: ProjectionMode.duplicate,
                  label: Text('Duplicate'),
                  icon: Icon(Icons.copy, size: 16),
                ),
                ButtonSegment(
                  value: ProjectionMode.extended,
                  label: Text('Extended'),
                  icon: Icon(Icons.picture_in_picture, size: 16),
                ),
              ],
              selected: {state.projectionMode},
              onSelectionChanged: (val) {
                if (val.first == ProjectionMode.duplicate) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Duplicate projection is coming soon. '
                          'Single Screen and Extended are available now.',
                        ),
                      ),
                    );
                  return;
                }
                notifier.setProjectionMode(val.first);
              },
              showSelectedIcon: false,
            ),
          ],
        ],
      ),
    );
  }
}

