import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ImportExportCard extends StatelessWidget {
  final bool isImporting;
  final String? importStatus;
  final bool isExporting;
  final VoidCallback onImportMdb;
  final VoidCallback onImportVsBook;
  final VoidCallback onExportVsBook;

  const ImportExportCard({
    super.key,
    required this.isImporting,
    required this.importStatus,
    required this.isExporting,
    required this.onImportMdb,
    required this.onImportVsBook,
    required this.onExportVsBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.import_export,
              iconBackground: theme.colorScheme.primaryContainer,
              iconColor: theme.colorScheme.onPrimaryContainer,
              title: 'Import & Export',
            ),
            const SizedBox(height: 8),
            Text(
              'Import legacy VSB or MDB files, or restore .vsbook backups.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            if (isImporting) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(importStatus ?? 'Processing...',
                      style: TextStyle(color: theme.colorScheme.primary)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionButton(
                  onPressed: isImporting ? null : onImportMdb,
                  icon: Icons.folder_open,
                  label: 'Import VSB / MDB',
                ),
                _ActionButton(
                  onPressed: isImporting ? null : onImportVsBook,
                  icon: Icons.settings_backup_restore,
                  label: 'Restore .vsbook',
                ),
                _ActionButton(
                  onPressed: isExporting || isImporting ? null : onExportVsBook,
                  icon: Icons.cloud_upload,
                  label: 'Export .vsbook',
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectionPreferencesCard extends ConsumerWidget {
  const ProjectionPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.video_settings,
              iconBackground: theme.colorScheme.secondaryContainer,
              iconColor: theme.colorScheme.onSecondaryContainer,
              title: 'Projection Preferences',
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prevent Screen Sleep',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Keeps the display awake'),
              value: state.keepAwake,
              onChanged: notifier.setKeepAwake,
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-insert Chorus',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Repeat chorus between verses'),
              value: state.autoInsertChorus,
              onChanged: notifier.setAutoInsertChorus,
            ),
            const Divider(height: 32),
            const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.format_size, size: 20, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: state.fontSize,
                    min: 16,
                    max: 96,
                    divisions: 16,
                    label: '${state.fontSize.round()}pt',
                    onChanged: notifier.setFontSize,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${state.fontSize.round()}pt',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.palette_outlined,
              iconBackground: theme.colorScheme.secondaryContainer,
              iconColor: theme.colorScheme.onSecondaryContainer,
              title: 'Appearance',
            ),
            const SizedBox(height: 20),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings),
                  label: Text('System'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                notifier.setThemeMode(selected.first);
              },
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }
}

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.info_outline,
              iconBackground: theme.colorScheme.tertiaryContainer,
              iconColor: theme.colorScheme.onTertiaryContainer,
              title: 'About',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Platform',
              value: kIsWeb ? 'Web' : Platform.operatingSystem.toUpperCase(),
            ),
            const SizedBox(height: 6),
            const _InfoRow(label: 'MDB Support', value: 'mdb-tools helper'),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool outlined;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
