import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/models/projection_mode.dart';
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
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: accentColor,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
            subtitle: 'Theme, fonts, and reading experience',
          ),
          const SizedBox(height: 20),
          // ── Theme row ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Application Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        )),
                    const SizedBox(height: 2),
                    Text('Light, dark, or follow the OS',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 15),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 15),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_brightness, size: 15),
                    label: Text('System'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (val) => notifier.setThemeMode(val.first),
                showSelectedIcon: false,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // ── Bible Font ─────────────────────────────────────────
          Text('Bible Reading Font',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 4),
          Text(
            'Typeface for scripture text in the Bible reader.',
            style: TextStyle(
                fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: bibleState.readingFontFamily,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4)),
              ),
            ),
            items: kBibleReadingFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Row(
                  children: [
                    Text(_fontLabel(font),
                        style: TextStyle(
                            fontSize: 14,
                            fontFamily: font,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('— for the LORD is good.',
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: font,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (font) {
              if (font != null) bibleNotifier.setReadingFontFamily(font);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // ── Bible Font Size ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bible Font Size',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('Adjust scripture text size.',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                '${bibleState.bibleFontSize.toStringAsFixed(0)} pt',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: bibleState.bibleFontSize,
            min: 14,
            max: 36,
            divisions: 11,
            label: bibleState.bibleFontSize.toStringAsFixed(0),
            onChanged: (value) => bibleNotifier.setBibleFontSize(value),
          ),
        ],
      ),
    );
  }

  String _fontLabel(String font) => switch (font) {
        'EBGaramond' => 'EB Garamond',
        'Lora' => 'Lora',
        'Inter' => 'Inter',
        _ => font,
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
            subtitle: 'Import songs or manage database backups',
          ),
          if (isImporting) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  importStatus ?? 'Processing...',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.library_add_outlined,
            label: 'Import Pre-installed Songbooks',
            description: 'Add bundled songbook files distributed with the app',
            onPressed: isImporting ? null : onImportBundled,
            isPrimary: true,
          ),
          const Divider(height: 24),
          _ActionRow(
            icon: Icons.file_upload_outlined,
            label: 'Import from File',
            description: 'Load a .vsbook or .mdb file from your filesystem',
            onPressed: isImporting ? null : onImportFile,
          ),
          const Divider(height: 24),
          _ActionRow(
            icon: Icons.backup_outlined,
            label: 'Export Backup',
            description: 'Save a .vsbook archive of your entire library',
            onPressed: isExporting || isImporting ? null : onExportVsBook,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: onPressed == null
                      ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        isPrimary
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Import', style: TextStyle(fontSize: 12)),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: const Text('Go', style: TextStyle(fontSize: 12)),
              ),
      ],
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
            subtitle: 'Release notes and recent updates',
          ),
          const SizedBox(height: 20),
          ...recentEntries
              .take(_showOlder ? recentEntries.length : 1)
              .map((entry) => Padding(
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
              icon: const Icon(Icons.expand_more, size: 16),
              label: Text(
                'Show ${recentEntries.length - 1} more entries',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.primary),
              ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visual Song Book',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Song management, Bible reader & live projection for church worship teams.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'v2.0.0',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'by BenjaNetan',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.source,
            title: 'Song Source',
            subtitle: 'Which songbooks are loaded at startup',
          ),
          const SizedBox(height: 16),
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
            subtitle: 'Auto-sync .vsbook files from Google Drive or shared folders',
          ),
          const SizedBox(height: 16),
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
    final result = await FilePicker.pickFiles(
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
