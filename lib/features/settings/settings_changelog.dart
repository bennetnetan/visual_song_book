
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

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
        version: 'v2.5.0',
        date: '2026-11-01',
        changes: [
          'Songbooks: import .vsb / .mdb Access files using the converter bundled with desktop and mobile builds',
          'Linked songbooks: import immediately when linked and sync detected changes without restarting',
          'iOS: bundle Node Mobile and converter dependencies; add an unsigned iOS build to CI',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v2.4.0',
        date: '2026-10-13',
        changes: [
          'Projection: projector window opens by itself when content is projected — no manual button',
          'Projection: output is placed and fullscreened on the second screen by the platform (Windows, Linux, macOS)',
          'Projection: redesigned empty page with search in the window instead of a popup, plus Songs/Bible/Sets history',
          'Projection: history tabs colour-coded; Search/History tabs on narrow screens',
          'Search: * matches any run of characters, ? exactly one; literal % and _ are escaped',
          'Search: results paged 10 at a time with "Load more" so broad queries stay manageable',
          'Search: space bar and Enter now work while typing in the search field',
          'Sets: fixed duplicating and importing a set losing the selection',
          'Windows: installer with a proper wizard, VC++ runtime check, and release builds for all platforms',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v2.3.0',
        date: '2026-09-29',
        changes: [
          'Lower thirds: new live announcement carousel overlay for projection',
          'Lower thirds: full-width banner & floating pill styles, custom background colour/opacity, scrolling ticker',
          'Lower thirds: hidden on mobile; matches projection background; no border',
          'Lower thirds: master toggle and all announcements default OFF; Full-Width Banner is default style',
          'Sets: import plain-text set lists copied from clipboard',
          'Sets: auto-version duplicates and re-imported sets with the same name',
          'Sets: simplified sharing format; copy button replaces direct WhatsApp option',
          'Projection: keep window alive on close instead of destroying it',
          'Projection: second-monitor detection; skip fullscreen on single-monitor setups',
          'Appearance: user-adjustable app font size slider',
          'Linked songbooks: fixed unique-constraint failure when syncing multiple books',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v2.2.2',
        date: '2026-09-01',
        changes: [
          'Projection window: second-monitor detection via EnumDisplayMonitors FFI',
          'Projection window: retry logic for desktop_multi_window channel init',
          'Projection window: fixed infinite re-assertion loop from SetWindowPos focus cascades',
          'Projection window: skip fullscreen on single-monitor setups',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v2.2.0',
        date: '2026-08-18',
        changes: [
          'Projection search: dedicated full-screen search page replaces SearchAnchor',
          'Sharing: system-native share sheet with WhatsApp-first flow and Bible multi-verse sharing',
          'Presentation: song separation banners in slide list; mobile set song list sheet',
          'Sets: Duplicate Set, performance notes, service date scheduling, quick-project actions',
          'Sets: song count badge, relative dates, swipe-to-delete, larger drag touch targets',
        ],
      ),
      const _ChangelogEntryWidget(
        version: 'v2.1.0',
        date: '2026-08-06',
        changes: [
          'Settings: professional redesign across all four tabs with centered single-column layout (max-width 800)',
          'SectionHeader replaced with slim all-caps label + icon — removes chunky coloured icon boxes',
          'ImportExportCard: compact action rows replace full-width mega-buttons',
          'AboutCard: horizontal compact layout with logo inline',
          'Projection search focus restored after overlay closes — arrow key navigation always works',
          'Set Navigator list now expands and scrolls correctly',
          'Footer moved into the System tab scroll area',
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

