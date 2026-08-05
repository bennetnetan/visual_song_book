import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

enum _SettingsSectionId {
  appearance,
  projection,
  dataSources,
  system,
}

class _SettingsSection {
  final _SettingsSectionId id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _SettingsSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const _appearanceSection = _SettingsSection(
  id: _SettingsSectionId.appearance,
  label: 'Appearance',
  icon: Icons.palette_outlined,
  selectedIcon: Icons.palette,
);

const _projectionSection = _SettingsSection(
  id: _SettingsSectionId.projection,
  label: 'Projection',
  icon: Icons.slideshow_outlined,
  selectedIcon: Icons.slideshow,
);

const _dataSourcesSection = _SettingsSection(
  id: _SettingsSectionId.dataSources,
  label: 'Data Sources',
  icon: Icons.folder_copy_rounded,
  selectedIcon: Icons.folder_copy,
);

const _systemSection = _SettingsSection(
  id: _SettingsSectionId.system,
  label: 'System',
  icon: Icons.settings_suggest_rounded,
  selectedIcon: Icons.settings_suggest,
);

const List<_SettingsSection> _settingsSections = [
  _appearanceSection,
  _projectionSection,
  _dataSourcesSection,
  _systemSection,
];

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _isImporting = false;
  String? _importStatus;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return DefaultTabController(
      length: _settingsSections.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: isLargeScreen ? 0 : kToolbarHeight,
          title: isLargeScreen ? null : const Text('Settings'),
          bottom: TabBar(
            isScrollable: false,
            tabs: _settingsSections
                .map(
                  (s) => Tab(text: s.label),
                )
                .toList(),
          ),
        ),
        body: _buildSectionContent(theme),
      ),
    );
  }

  Widget _buildSectionContent(ThemeData theme) {
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return TabBarView(
      children: [
        _buildAppearanceContent(isLargeScreen),
        _buildProjectionContent(isLargeScreen),
        _buildDataSourcesContent(theme, isLargeScreen),
        _buildSystemContent(theme),
      ],
    );
  }

  Widget _buildAppearanceContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Column(
        children: const [
          AppearanceCard(),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProjectionContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Column(
        children: const [
          ProjectionAppearanceCard(),
          SizedBox(height: 24),
          ProjectionPreferencesCard(),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDataSourcesContent(ThemeData theme, bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Column(
        children: [
          const SourceModeCard(),
          const SizedBox(height: 16),
          const LinkedSongbooksCard(),
          const SizedBox(height: 16),
          ImportExportCard(
            isImporting: _isImporting,
            importStatus: _importStatus,
            isExporting: _isExporting,
            onImportFile: _importFile,
            onImportBundled: _importBundled,
            onExportVsBook: _exportVsBook,
          ),
          const SizedBox(height: 16),
          const _DataSourcesCard(),
          const SizedBox(height: 16),
          const _SongCollectionsCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSystemContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const AboutCard(),
          const SizedBox(height: 16),
          const ChangelogCard(),
          const SizedBox(height: 32),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Future<void> _importFile() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() {
      _isImporting = true;
      _importStatus = 'Selecting file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
          _importStatus = null;
        });
        return;
      }

      final path = result.files.single.path!;
      final lower = path.toLowerCase();

      setState(() => _importStatus = 'Importing...');

      final importers = ref.read(importersProvider);
      final source = ImportSource.fromFile(path);

      if (lower.endsWith('.vsbook')) {
        final importer = importers.firstWhere((imp) => imp is VsBookImporter);
        final importResult = await importer.import(source);
        if (importResult.success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Imported ${importResult.songsImported} songs.')),
          );
          ref.read(songListControllerProvider.notifier).fetchSongs();
        } else {
          throw Exception(importResult.errorMessage ?? 'Unknown import error');
        }
      } else {
        final activeImporter = importers
            .where((imp) => imp.canImport(source))
            .firstOrNull;
        if (activeImporter == null) {
          throw Exception(
            'No importer supports this file. Direct .mdb import requires '
            'desktop platforms with mdb-tools installed.',
          );
        }
        final importResult = await activeImporter.import(source);
        if (importResult.success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${importResult.songsImported} songs, '
                '${importResult.categoriesImported} categories.',
              ),
            ),
          );
          ref.read(songListControllerProvider.notifier).fetchSongs();
        } else {
          throw Exception(importResult.errorMessage ?? 'Unknown import error');
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      setState(() {
        _isImporting = false;
        _importStatus = null;
      });
    }
  }

  Future<void> _importBundled() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() {
      _isImporting = true;
      _importStatus = 'Importing bundled songbooks...';
    });

    try {
      await ref
          .read(songListControllerProvider.notifier)
          .reimportBundledSongbooks();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Bundled songbooks imported successfully.'),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to import bundled books: $e')),
      );
    } finally {
      setState(() {
        _isImporting = false;
        _importStatus = null;
      });
    }
  }

  Future<void> _exportVsBook() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isExporting = true);

    try {
      final String? targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: 'songbook_backup.vsbook',
        type: FileType.any,
      );

      if (targetPath == null) {
        setState(() => _isExporting = false);
        return;
      }

      final cleanPath = targetPath.toLowerCase().endsWith('.vsbook')
          ? targetPath
          : '$targetPath.vsbook';

      final backupRepo = ref.read(backupRepositoryProvider);
      await backupRepo.exportBackup(cleanPath);

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Backup exported to: $cleanPath')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Export Failed: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Visual Song Book v2.0.0',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Made by BenjaNetan',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Sources Card
class _DataSourcesCard extends ConsumerWidget {
  const _DataSourcesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(songRepositoryProvider);
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.folder_copy_rounded,
            title: 'Manage Data Sources',
          ),
          const SizedBox(height: 8),
          Text(
            'View and remove imported songbook collections.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<String>>(
            future: repo.getDistinctSourcePaths(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final sources = snapshot.data ?? [];
              if (sources.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No external sources found.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: sources.map((source) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
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
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.library_books_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        source.split(Platform.pathSeparator).last,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        source,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: theme.colorScheme.error,
                        tooltip: 'Remove collection',
                        onPressed: () =>
                            _confirmDeleteSource(context, ref, source),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const _DangerZoneSection(),
        ],
      ),
    );
  }

  void _confirmDeleteSource(
    BuildContext context,
    WidgetRef ref,
    String sourcePath,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete all songs imported from:\n\n$sourcePath?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(songRepositoryProvider)
                  .deleteSongsBySource(sourcePath);
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

// Song Collections (categories) card
class _SongCollectionsCard extends ConsumerStatefulWidget {
  const _SongCollectionsCard();

  @override
  ConsumerState<_SongCollectionsCard> createState() =>
      _SongCollectionsCardState();
}

class _SongCollectionsCardState extends ConsumerState<_SongCollectionsCard> {
  StreamSubscription<List<Category>>? _sub;
  List<Category> _categories = const [];
  Map<int, int> _counts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(songRepositoryProvider);
    _sub = repo.watchCategories().listen((categories) async {
      final counts = <int, int>{};
      for (final category in categories) {
        counts[category.id] = await repo.getSongCountByCategory(category.id);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _counts = counts;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.collections_bookmark_outlined,
            title: 'Song Collections',
          ),
          const SizedBox(height: 8),
          Text(
            'Collections group songs into categories. Deleting a collection '
            'keeps its songs — they become Uncategorized.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No collections yet. Create one from the Songs tab.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _categories.map((category) {
                final count = _counts[category.id] ?? 0;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
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
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '$count song${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: theme.colorScheme.error,
                      tooltip: 'Delete collection',
                      onPressed: () => _confirmDelete(context, category),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete collection "${category.name}"'),
        content: Text(
          'Its ${_counts[category.id] ?? 0} songs will be kept and moved to '
          'Uncategorized. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(songRepositoryProvider)
                  .deleteCategory(category.id);
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Danger Zone
class _DangerZoneSection extends ConsumerWidget {
  const _DangerZoneSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These actions are irreversible. Please proceed with extreme caution.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _confirmDeleteAll(context, ref),
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Remove All Collections'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.6)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will wipe all imported songs and categories. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(songRepositoryProvider)
                  .deleteAllSongs();
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );
  }
}
