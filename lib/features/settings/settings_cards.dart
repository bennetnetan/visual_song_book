import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/widgets/neomorphic_widgets.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? accentColor;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: (accentColor ?? iconColor ?? theme.colorScheme.primary)
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        NeoPressedContainer(
          padding: const EdgeInsets.all(8),
          borderRadius: 999,
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ProjectionPreferencesCard extends ConsumerWidget {
  const ProjectionPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);
    final theme = Theme.of(context);

    return NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.settings_overscan,
            title: 'Projection Preferences',
            accentColor: Colors.blue,
          ),
          const SizedBox(height: 24),
          _PreferenceToggle(
            title: 'Prevent Screen Sleep',
            subtitle: 'Keeps the display awake',
            value: state.keepAwake,
            onChanged: notifier.setKeepAwake,
          ),
          const _Divider(),
          _PreferenceToggle(
            title: 'Auto-insert Chorus',
            subtitle: 'Repeat chorus between verses',
            value: state.autoInsertChorus,
            onChanged: notifier.setAutoInsertChorus,
          ),
          const _Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Presentation Skills',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configure transitions, effects, and presentation behavior.',
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.palette,
            title: 'Appearance',
            iconColor: Colors.purple,
            accentColor: Colors.purple,
          ),
          const SizedBox(height: 24),
          // Theme Selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              NeoSegmentedControl<ThemeMode>(
                groupValue: themeMode,
                onValueChanged: (value) => notifier.setThemeMode(value),
                children: const {
                  ThemeMode.light: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.light_mode, size: 16),
                      SizedBox(width: 4),
                      Text('Light'),
                    ],
                  ),
                  ThemeMode.dark: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dark_mode, size: 16),
                      SizedBox(width: 4),
                      Text('Dark'),
                    ],
                  ),
                  ThemeMode.system: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_brightness, size: 16),
                      SizedBox(width: 4),
                      Text('System'),
                    ],
                  ),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ImportExportCard extends StatelessWidget {
  final bool isImporting;
  final String? importStatus;
  final bool isExporting;
  final VoidCallback onImportMdb;
  final VoidCallback onImportBundled;
  final VoidCallback onImportVsBook;
  final VoidCallback onExportVsBook;

  const ImportExportCard({
    super.key,
    required this.isImporting,
    required this.importStatus,
    required this.isExporting,
    required this.onImportMdb,
    required this.onImportBundled,
    required this.onImportVsBook,
    required this.onExportVsBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.import_export,
            title: 'Import & Export',
            accentColor: Colors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            'Import legacy VSB or MDB files, or restore .vsbook backups.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          if (isImporting) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  importStatus ?? 'Processing...',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Column(
            children: [
              NeoButton(
                onPressed: isImporting ? null : onImportBundled,
                isPrimary: true,
                tooltip: 'Import pre-installed songbooks into your library',
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_add, size: 20),
                    SizedBox(width: 8),
                    Text('Import Bundled Books'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      onPressed: isImporting ? null : onImportMdb,
                      tooltip: 'Import songs from legacy VSB or MDB files',
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 20),
                          SizedBox(width: 8),
                          Text('Import VSB / MDB'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoButton(
                      onPressed: isImporting ? null : onImportVsBook,
                      tooltip: 'Restore songs from a .vsbook backup file',
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restore, size: 20),
                          SizedBox(width: 8),
                          Text('Import .vsbook'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NeoButton(
                onPressed: isExporting || isImporting ? null : onExportVsBook,
                tooltip: 'Export your entire library as a .vsbook backup',
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 20),
                    SizedBox(width: 8),
                    Text('Export .vsbook'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        NeoToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(
        height: 1,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class ChangelogCard extends StatelessWidget {
  const ChangelogCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.history,
            title: 'Changelog',
            accentColor: Colors.amber,
          ),
          SizedBox(height: 24),
          _ChangelogEntry(
            version: 'v1.1.0',
            date: '2026-05-15',
            changes: [
              'Revamped Settings page with neumorphic dark-mode-safe shadows',
              'Projection window opens borderless fullscreen on second monitor',
              'New about section with app info',
              'Hover outlines and tooltips on all interactive buttons',
              'Reorganized import/export button layout',
            ],
          ),
          SizedBox(height: 16),
          _ChangelogEntry(
            version: 'v1.0.0',
            date: '2026-03-01',
            changes: [
              'Initial release',
              'Song library management with categories',
              'VSB and MDB file import',
              'Multi-window projection output',
              'Backup and restore via .vsbook files',
              'Dark and light theme support',
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangelogEntry extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                version,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...changes.map(
          (change) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    change,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.info_outline,
            title: 'About',
            accentColor: Colors.teal,
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        offset: const Offset(4, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Visual Song Book',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: NeoShadows.insetSmall(context),
                  ),
                  child: Text(
                    'v1.1.0+2',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'A premium church hymnal management & live projection app. '
            'Manage your song library, import from various formats, '
            'and project lyrics with style.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Built with Flutter & Riverpod',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
