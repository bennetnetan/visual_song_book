
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/projection/projection_appearance_widgets.dart';
import 'package:visual_song_book/features/projection/projection_preview.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class ProjectionAppearanceCard extends ConsumerWidget {
  const ProjectionAppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(projectionThemeProvider);
    final notifier = ref.read(projectionThemeProvider.notifier);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.slideshow,
            title: 'Projection Appearance',
            subtitle: 'Background, font colour, and live preview',
          ),
          const SizedBox(height: 20),
          ProjectionPreview(theme: theme),
          const SizedBox(height: 20),
          ProjectionAppearanceControls(
            theme: theme,
            onChanged: notifier.setTheme,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore Defaults'),
            ),
          ),
        ],
      ),
    );
  }
}

