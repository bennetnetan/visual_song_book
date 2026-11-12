import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/features/lower_third/widgets/lower_third_settings_card.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/settings/settings_danger_zone_card.dart';
import 'package:visual_song_book/features/settings/settings_data_sources_card.dart';
import 'package:visual_song_book/features/settings/settings_diagnostics_card.dart';
import 'package:visual_song_book/features/settings/settings_maintenance_card.dart';
import 'package:visual_song_book/features/settings/settings_song_collections_card.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = 'v${info.version}');
    });
  }

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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppearanceCard(),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectionContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProjectionAppearanceCard(),
              const SizedBox(height: 20),
              const ProjectionPreferencesCard(),
              if (isLargeScreen) ...[
                const SizedBox(height: 20),
                const LowerThirdSettingsCard(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataSourcesContent(ThemeData theme, bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SourceModeCard(),
              const SizedBox(height: 20),
              const LinkedSongbooksCard(),
              const SizedBox(height: 20),
              ImportExportCard(
                isImporting: _isImporting,
                importStatus: _importStatus,
                isExporting: _isExporting,
                onImportFile: _importFile,
                onImportBundled: _importBundled,
                onExportVsBook: _exportVsBook,
              ),
              const SizedBox(height: 20),
              const DataSourcesCard(),
              const SizedBox(height: 20),
              const SongCollectionsCard(),
              const SizedBox(height: 20),
              const DangerZoneCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemContent(ThemeData theme) {
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AboutCard(),
              const SizedBox(height: 20),
              const DiagnosticsCard(),
              const SizedBox(height: 20),
              const MaintenanceCard(),
              const SizedBox(height: 20),
              const ChangelogCard(),
              const SizedBox(height: 32),
              _buildFooter(theme),
            ],
          ),
        ),
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
      final result = await FilePicker.pickFiles(type: FileType.any);

      if (result.isEmpty || result.single.path == null) {
        setState(() {
          _isImporting = false;
          _importStatus = null;
        });
        return;
      }

      final path = result.single.path!;
      final lower = path.toLowerCase();

      setState(() => _importStatus = 'Importing...');

      final importers = ref.read(importersProvider);
      final source = ImportSource.fromFile(path);

      if (lower.endsWith('.vsbook')) {
        final confirmed = await _confirmFullImport();
        if (!confirmed) return;

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

  Future<bool> _confirmFullImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace existing library?'),
        content: const Text(
          'Importing a .vsbook replaces your current library: existing songs, '
          'categories, and all play history will be permanently deleted. '
          'Consider exporting a backup first.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace Library'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
      final backupRepo = ref.read(backupRepositoryProvider);
      final bytes = await backupRepo.exportBackupBytes();

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: 'songbook_backup.vsbook',
        bytes: bytes,
      );

      if (uri == null) {
        setState(() => _isExporting = false);
        return;
      }

      final path = uri.toFilePath();
      final cleanPath = path.toLowerCase().endsWith('.vsbook')
          ? path
          : '$path.vsbook';

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
                'Visual Song Book${_appVersion.isNotEmpty ? ' $_appVersion' : ''}',
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
