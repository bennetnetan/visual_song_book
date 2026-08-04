import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
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
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(24), child: child),
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
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

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
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
                if (val.first == 'duplicate') {
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
  final VoidCallback onImportFile;
  final VoidCallback onImportBundled;
  final VoidCallback onExportVsBook;

  const ImportExportCard({
    super.key,
    required this.isImporting,
    required this.importStatus,
    required this.isExporting,
    required this.onImportFile,
    required this.onImportBundled,
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
            'Import songs from files or manage database backups.',
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isImporting ? null : onImportFile,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Import from File (.vsbook / .mdb)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isExporting || isImporting ? null : onExportVsBook,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Export Backup (.vsbook)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChangelogCard extends StatefulWidget {
  const ChangelogCard({super.key});

  @override
  State<ChangelogCard> createState() => _ChangelogCardState();
}

class _ChangelogCardState extends State<ChangelogCard> {
  bool _showOlder = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final recentEntries = [
      const _ChangelogEntry(
        version: 'v1.8.0',
        date: '2026-08-04',
        changes: [
          'Projection mode — extended (secondary window) or single (in-window on primary display)',
          'Reopening projection reuses the hidden window — no duplicate engines',
          'Bible projection: load more verses for long passages',
          'Projection screen cleanup — position indicator and nav arrows hidden on desktop, kept on mobile fullscreen',
          'Font-size cap unified (16–160); pinch-zoom persists once when the gesture ends',
          'Search: Enter/click projects the keyboard-highlighted result',
          'History: set and Bible entries refresh live and can be cleared; Continue Reading survives restart',
          'Categories: filter songs by collection; deleting a category keeps its songs (moved to Uncategorized)',
          '.vsbook import no longer crashes on modified timestamps; deleted songs stay deleted',
          'Hygiene: dead code and unused dependencies removed, explicit lint rules, macOS target 11.0, CI with hermetic tests',
        ],
      ),
      const _ChangelogEntry(
        version: 'v1.7.1',
        date: '2026-07-31',
        changes: [
          'Fixed projection crash caused by background enumeration on Windows',
          'Eliminated title bar flash on secondary projection screen (Windows)',
          'Improved Enter-key interaction and responsiveness for search results',
          'Improved projection UI and controls visibility on Android/touch devices',
        ],
      ),
      const _ChangelogEntry(
        version: 'v1.7.0',
        date: '2026-07-28',
        changes: [
          'Settings restructured into 4 categories: Appearance, Projection, Library, About',
          'Borderless fullscreen projection on Windows via Win32 FFI (title bar + taskbar hidden)',
          'Mobile/desktop layout split — phone/tablet gets simplified single-column layout',
          'Linked songbooks — link .vsbook files from Google Drive or shared folders with auto-sync',
          'Source filter on songs tab — filter by songbook/source with counts',
          'First-launch onboarding wizard for initial setup',
          'Auto-chorus toggle moved inline next to Clear Screen in projection header',
          'Import from File button — auto-detects .mdb vs .vsbook format',
          'Changelog now expandable — shows latest 2 entries by default',
          'Fixed Win32 fullscreen scheduler reentrancy crash (deferred via Timer.run)',
        ],
      ),
      const _ChangelogEntry(
        version: 'v1.6.0+2',
        date: '2026-07-21',
        changes: [
          'Keyboard-scrolled search items now stay visible — replaced fixed-height scroll math with Scrollable.ensureVisible',
          'Keyboard navigation hint moved above search results so it is always visible, not hidden below the list',
        ],
      ),
      const _ChangelogEntry(
        version: 'v1.6.0',
        date: '2026-07-21',
        changes: [
          'Categories simplified — Full Song Book & Injili Song Book replace the dozens of individual imported categories',
          'Unified storage directory — all app data consolidated in .visual_song_book/',
          'Cross-book duplicates eliminated — seeded songs deduplicated by title alone',
          'Sidebar starts minimized — NavigationRail collapsed by default on launch',
          'Seed marker hardened — verifies DB actually has songs before trusting SharedPreferences marker',
          'AppImage OS bar icon — icons embedded in hicolor theme paths with correct StartupWMClass',
        ],
      ),
    ];

    final olderEntries = [
      const _ChangelogEntry(
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
      const _ChangelogEntry(
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
      const _ChangelogEntry(
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
      const _ChangelogEntry(
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
    ];

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.history,
            title: 'Changelog',
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          ...recentEntries,
          if (_showOlder) ...olderEntries,
          if (olderEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _showOlder = !_showOlder),
              child: Row(
                children: [
                  Icon(
                    _showOlder ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showOlder
                        ? 'Hide older versions'
                        : 'Show ${olderEntries.length} older versions',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    'v1.8.0',
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
            'Song management, KJV Bible reader, and live projection '
            'for church worship teams. Import from various formats, '
            'organize song sets, and project lyrics to external screens.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Made by BenjaNetan',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked Songbooks Card — manage .vsbook files synced via cloud storage
// ─────────────────────────────────────────────────────────────────────────────
class LinkedSongbooksCard extends ConsumerWidget {
  const LinkedSongbooksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedAsync = ref.watch(linkedSongbooksProvider);
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.sync,
            title: 'Linked Songbooks',
            color: Colors.cyan,
          ),
          const SizedBox(height: 8),
          Text(
            'Link .vsbook files from Google Drive or shared folders. '
            'The app checks for changes on startup and reimports automatically.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          linkedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading: $e'),
            data: (linked) {
              if (linked.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No linked songbooks yet.',
                          style: GoogleFonts.plusJakartaSans(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "Link File" to get started.',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: linked.map((book) {
                  final exists = book.fileExists;
                  final needsSync = book.hasChangedSinceLastImport;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: exists
                              ? (needsSync
                                    ? theme.colorScheme.tertiary.withValues(alpha: 0.1)
                                    : theme.colorScheme.primary.withValues(alpha: 0.1))
                              : theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          exists
                              ? (needsSync
                                    ? Icons.sync
                                    : Icons.check_circle_outline)
                              : Icons.error_outline,
                          size: 20,
                          color: exists
                              ? (needsSync ? theme.colorScheme.tertiary : theme.colorScheme.primary)
                              : theme.colorScheme.error,
                        ),
                      ),
                      title: Text(
                        book.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.path,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!exists)
                            Text(
                              'File not found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (needsSync)
                            Text(
                              'Changes detected — will sync on next startup',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (book.lastImportedAt != null)
                            Text(
                              'Last synced: ${_formatDate(book.lastImportedAt!)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                      trailing: Semantics(
                        label: 'Unlink',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.link_off, size: 20),
                          color: theme.colorScheme.error,
                          tooltip: 'Unlink',
                          onPressed: () => _unlink(context, ref, book),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _linkFile(context, ref),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Link File'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (linkedAsync.hasValue && linkedAsync.value!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _syncAll(context, ref),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _linkFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vsbook', 'vsb'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final name = result.files.single.name;
    await ref.read(linkedSongbooksProvider.notifier).add(path, name: name);
  }

  void _unlink(BuildContext context, WidgetRef ref, LinkedSongbook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Songbook'),
        content: Text('Remove "${book.name}" from linked songbooks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(linkedSongbooksProvider.notifier)
                  .remove(book.path);
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final linked = ref.read(linkedSongbooksProvider).value ?? [];
    final needsSync = linked
        .where((b) => b.hasChangedSinceLastImport && b.fileExists)
        .toList();
    if (needsSync.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All linked songbooks are up to date.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Syncing ${needsSync.length} songbook(s)...')),
      );
    }

    for (final book in needsSync) {
      final file = File(book.path);
      if (!file.existsSync()) continue;

      final ext = book.path.toLowerCase();
      if (ext.endsWith('.vsbook')) {
        final db = ref.read(databaseProvider);
        final importer = VsBookImporter(db);
        final result = await importer.reimportSource(book.path);
        if (result.success) {
          await ref
              .read(linkedSongbooksProvider.notifier)
              .markImported(book.path);
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync complete.')));
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
