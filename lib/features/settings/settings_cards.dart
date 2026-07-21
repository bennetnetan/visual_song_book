import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: 16),
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
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.settings_overscan,
            title: 'Projection Settings',
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: Text(
              'Prevent Screen Sleep',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Keep the display active during presentation',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
            value: state.keepAwake,
            onChanged: notifier.setKeepAwake,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          SwitchListTile(
            title: Text(
              'Auto-insert Chorus',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Automatically repeat chorus slides between verses',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
            value: state.autoInsertChorus,
            onChanged: notifier.setAutoInsertChorus,
            contentPadding: EdgeInsets.zero,
          ),
          if (isLargeScreen) ...[
            const Divider(height: 24),
            Text(
              'Projection Display Mode',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how the live projection output should be positioned on desktop screens.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'single',
                  label: Text('Single Screen'),
                  icon: Icon(Icons.screenshot_monitor, size: 16),
                ),
                ButtonSegment(
                  value: 'duplicate',
                  label: Text('Duplicate'),
                  icon: Icon(Icons.copy, size: 16),
                ),
                ButtonSegment(
                  value: 'extended',
                  label: Text('Extended'),
                  icon: Icon(Icons.picture_in_picture, size: 16),
                ),
              ],
              selected: {state.projectionMode},
              onSelectionChanged: (val) {
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

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.palette,
            title: 'Appearance',
            color: Colors.purple,
          ),
          const SizedBox(height: 24),
          Text(
            'Application Theme',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light Mode'),
                icon: Icon(Icons.light_mode, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark Mode'),
                icon: Icon(Icons.dark_mode, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.settings_brightness, size: 16),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (val) {
              notifier.setThemeMode(val.first);
            },
            showSelectedIcon: false,
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
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.import_export,
            title: 'Import & Export',
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          Text(
            'Import legacy VSB or MDB files, or manage song database backups.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          if (isImporting) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  importStatus ?? 'Processing...',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Column(
            children: [
              FilledButton.icon(
                onPressed: isImporting ? null : onImportBundled,
                icon: const Icon(Icons.library_add, size: 18),
                label: const Text('Import Pre-installed Songbooks'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isImporting ? null : onImportMdb,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Import VSB / MDB'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isImporting ? null : onImportVsBook,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restore .vsbook'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isExporting || isImporting ? null : onExportVsBook,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Export .vsbook Backup'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChangelogCard extends StatelessWidget {
  const ChangelogCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.history,
            title: 'Changelog',
            color: Colors.amber,
          ),
          SizedBox(height: 24),
          _ChangelogEntry(
            version: 'v1.6.0',
            date: '2026-07-21',
            changes: [
              'Categories simplified — Full Song Book & Injili Song Book replace the dozens of individual imported categories',
              'Unified storage directory — all app data consolidated in ~/.visual_song_book/',
              'Cross-book duplicates eliminated — seeded songs deduplicated by title alone',
              'Sidebar starts minimized — NavigationRail collapsed by default on launch',
              'Seed marker hardened — verifies DB actually has songs before trusting SharedPreferences marker',
            ],
          ),
          const SizedBox(height: 16),
          _ChangelogEntry(
            version: 'v1.5.0',
            date: '2026-07-21',
            changes: [
              'First-launch seeding — Full Song Book & Injili Song Book pre-loaded automatically on fresh install',
              'Centralized AppLogger powered by Dart logging package (structured, level-aware, IDE-friendly)',
              'SetsTab null-check crash fixed — graceful loading indicator when DB resolves before sets list',
              'Strict DB staleness checks — stale selectedSetId auto-cleared when set is deleted externally',
              'Reactive set-items stream — SongSetItems now watched live, eliminating stale-data races',
              '100ms nav-ready dwell timer in search — type to search, pause to navigate with arrow keys',
              'Enter to project highlighted result from search without touching the mouse',
              'Subtle animated keyboard-hint indicator fades in when nav mode is active in search results',
              'Linux window title fixed to "Visual Song Book" with app logo embedded in GTK titlebar',
              'Android per-ABI release APKs (armeabi-v7a, arm64-v8a, x86_64)',
              'Linux AppImage with embedded logo and AppDir integration',
            ],
          ),
          const SizedBox(height: 16),
          _ChangelogEntry(
            version: 'v1.4.2',
            date: '2026-06-26',
            changes: [
              'Multi-monitor detection — projection opens secondary window on multi-display, fullscreen on single',
              'UI polish — subtle hover-only nav arrows, transparent controls, PopScope blocks back gesture in projection',
              'Fixed Positioned/AnimatedOpacity nesting crash in projection output view',
              'Removed redundant CHANGELOG section from About card, consolidated into versioned Changelog card',
              'Removed Bible search back button on mobile (was opening book picker instead of navigating back)',
              'App bar hidden on mobile for History and Sets tabs',
              'Mobile-friendly action buttons for Sets with redesigned layout',
              'Unified Bible app bar font styling with dashboard tabs',
              'Collapsible inline lyrics preview on mobile song list',
              'Slide timeline with auto-scroll to active verse in projection view',
            ],
          ),
          SizedBox(height: 16),
          _ChangelogEntry(
            version: 'v1.4.1',
            date: '2026-06-25',
            changes: [
              'Inline song preview with collapsible lyrics on mobile',
              'Low-opacity slide timeline at bottom of projection output',
              'Drag-and-drop reorder hint above set list',
              'Full-color app icon branding throughout UI',
              'Mobile optimization — hide projection tab, clean up Bible book pickers',
              'High-resolution app icon logo in settings',
            ],
          ),
          SizedBox(height: 16),
          _ChangelogEntry(
            version: 'v1.4.0',
            date: '2026-06-24',
            changes: [
              'Interactive Book and Chapter pop-up navigation dialog matching Bible specs',
              'Subtle inline verse cross-references displayable for active verses',
              'Bible Bookmarks list supported on mobile and desktop via History tab',
              'Overhauled settings cards into clean, responsive Material 3 flat designs',
              'Unified Project actions for Bible, Songs, and Sets with Display settings options',
              'Responsive stacked live preview layout for narrow screen mobile devices',
              'Subtle hover-only display controls in projection output view',
              'Implemented drag-and-drop song sets reordering and inline list search filtering',
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

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.info_outline,
            title: 'About',
            color: Colors.teal,
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
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
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
                const SizedBox(height: 6),
                Chip(
                  label: Text(
                    'v1.6.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
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
        ],
      ),
    );
  }

}
