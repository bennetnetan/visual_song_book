import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_state.dart';
import 'package:visual_song_book/features/projection/projection_appearance_widgets.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
          style: const TextStyle(
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
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text(
              'Prevent Screen Sleep',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'Keep the display active during presentation',
              style: TextStyle(fontSize: 12),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how the live projection output should be positioned on desktop screens.',
              style: TextStyle(
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
    final bibleState = ref.watch(bibleControllerProvider);
    final bibleNotifier = ref.read(bibleControllerProvider.notifier);
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.palette,
            title: 'Appearance',
          ),
          const SizedBox(height: 24),
          const Text(
            'Application Theme',
            style: TextStyle(
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
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Bible Reading Font',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the typeface for scripture text in the Bible reader and search.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: bibleState.readingFontFamily,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            items: kBibleReadingFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Row(
                  children: [
                    Text(
                      _fontLabel(font),
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '— for the LORD is good.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: font,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (font) {
              if (font != null) bibleNotifier.setReadingFontFamily(font);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Bible Font Size',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the text size for scripture in the Bible reader and search.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: bibleState.bibleFontSize,
                  min: 14,
                  max: 36,
                  divisions: 11,
                  label: bibleState.bibleFontSize.toStringAsFixed(0),
                  onChanged: (value) => bibleNotifier.setBibleFontSize(value),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  bibleState.bibleFontSize.toStringAsFixed(0),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fontLabel(String font) => switch (font) {
    'EBGaramond' => 'EB Garamond',
    'Lora'       => 'Lora',
    'Inter'      => 'Inter',
    _            => font,
  };
}

/// Configures the live projection appearance: slide text color, background
/// style (gradient / color block / image), and auto-contrast text.
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
          ),
          const SizedBox(height: 24),
          ProjectionAppearanceControls(
            theme: theme,
            onChanged: notifier.setTheme,
          ),
          const Divider(height: 32),

          // ── Preview ──
          const Text(
            'Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ProjectionPreview(theme: theme),

          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text(
                'Restore Defaults',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
          ),
          const SizedBox(height: 12),
          Text(
            'Import songs from files or manage database backups.',
            style: TextStyle(
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
                  style: TextStyle(
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
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isImporting ? null : onImportFile,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Import from File (.vsbook / .mdb)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: isExporting || isImporting ? null : onExportVsBook,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Export Backup (.vsbook)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
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
    final recentEntries = [
      const _ChangelogEntryWidget(
        version: 'v2.0.0',
        date: '2026-08-05',
        changes: [
          'Settings restructured into tabbed sections: Appearance, Projection, Data Sources, System',
          'Bible reader UI refinements: active verse options, subtle selection colors, increased verse spacing',
          'Cross-references displayed at top of sidebar with auto-scroll',
          'Continue Reading button redesigned to filled button style',
          'Verse options menu restricted to active verse only',
          'Default Bible font changed to Lora at 19pt with adjustable font size slider in settings',
          'Legacy Bible serif font preference migrated to new font family setting',
          'Removed google_fonts dependency and restored bundled font usage',
          'Fixed missing imports and analyzer errors across Bible and settings modules',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v1.9.0',
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
      const _ChangelogEntryWidget(
        version: 'v1.7.1',
        date: '2026-07-31',
        changes: [
          'Fixed projection crash caused by background enumeration on Windows',
          'Eliminated title bar flash on secondary projection screen (Windows)',
          'Improved Enter-key interaction and responsiveness for search results',
          'Improved projection UI and controls visibility on Android/touch devices',
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
          ),
          const SizedBox(height: 24),
          ...recentEntries.take(_showOlder ? recentEntries.length : 1).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ChangelogEntryWidget(
                  version: entry.version,
                  date: entry.date,
                  changes: entry.changes,
                  expanded: _showOlder || entry == recentEntries.first,
                ),
              )),
          if (!_showOlder && recentEntries.length > 1)
            TextButton.icon(
              onPressed: () => setState(() => _showOlder = true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text('Show ${recentEntries.length - 1} more entries'),
            ),
        ],
      ),
    );
  }
}

class _ChangelogEntryWidget extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;
  final bool expanded;

  const _ChangelogEntryWidget({
    required this.version,
    required this.date,
    required this.changes,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleChanges = expanded ? changes : changes.take(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                version,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...visibleChanges.map(
          (change) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    change,
                    style: TextStyle(
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
                const Text(
                  'Visual Song Book',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: const Text(
                     'v2.0.0',
                    style: TextStyle(
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
          Center(
            child: Text(
              'Song management, KJV Bible reader, and live projection '
              'for church worship teams. Import from various formats, '
              'organize song sets, and project lyrics to external screens.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Made by BenjaNetan',
              style: TextStyle(
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
// Source Mode Card — choose which song sources to load on startup
// ─────────────────────────────────────────────────────────────────────────────
class SourceModeCard extends ConsumerWidget {
  const SourceModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.source,
            title: 'Song Source',
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which songs to load on startup. '
            'This setting determines whether bundled songbooks, linked files, or both are loaded.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          const _SourceModeSelector(),
        ],
      ),
    );
  }
}

class _SourceModeSelector extends ConsumerStatefulWidget {
  const _SourceModeSelector();

  @override
  ConsumerState<_SourceModeSelector> createState() => _SourceModeSelectorState();
}

class _SourceModeSelectorState extends ConsumerState<_SourceModeSelector> {
  SourceMode _currentMode = SourceMode.unified;

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('default_source_mode');
    if (saved != null) {
      setState(() => _currentMode = SourceMode.fromString(saved));
    }
  }

  Future<void> _changeMode(SourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_source_mode', mode.name);
    setState(() => _currentMode = mode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Source mode changed to "${mode.label}". '
            'Restart the app to apply.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SegmentedButton<SourceMode>(
          segments: const [
            ButtonSegment(
              value: SourceMode.bundled,
              label: Text('Bundled'),
              icon: Icon(Icons.library_books, size: 16),
            ),
            ButtonSegment(
              value: SourceMode.linked,
              label: Text('Linked'),
              icon: Icon(Icons.link, size: 16),
            ),
            ButtonSegment(
              value: SourceMode.unified,
              label: Text('Both'),
              icon: Icon(Icons.layers, size: 16),
            ),
          ],
          selected: {_currentMode},
          onSelectionChanged: (Set<SourceMode> selection) {
            if (selection.isNotEmpty) {
              _changeMode(selection.first);
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          _currentMode.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
          ),
          const SizedBox(height: 8),
          Text(
            'Link .vsbook files from Google Drive or shared folders. '
            'The app checks for changes on startup and reimports automatically.',
            style: TextStyle(
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
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "Link File" to get started.',
                          style: TextStyle(
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
                      borderRadius: BorderRadius.circular(16),
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
                          borderRadius: BorderRadius.circular(12),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.path,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!exists)
                            Text(
                              'File not found',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (needsSync)
                            const Text(
                              'Changes detected — will sync on next startup',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (book.lastImportedAt != null)
                            Text(
                              'Last synced: ${_formatDate(book.lastImportedAt!)}',
                              style: const TextStyle(
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
