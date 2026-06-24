import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/widgets/neomorphic_widgets.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

final selectedSettingsCategoryProvider = StateProvider<String>((ref) => 'General');

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _isImporting = false;
  String? _importStatus;
  bool _isExporting = false;

  Future<void> _importMdb() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() {
      _isImporting = true;
      _importStatus = 'Selecting file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
          _importStatus = null;
        });
        return;
      }

      final path = result.files.single.path!;
      setState(() => _importStatus = 'Running MDB Tools compiler...');

      final importers = ref.read(importersProvider);
      final source = ImportSource.fromFile(path);
      final activeImporter = importers.where((imp) => imp.canImport(source)).firstOrNull;

      if (activeImporter == null) {
        throw Exception(
            'No importer supports this file on this platform. Direct .mdb import requires Desktop platforms with mdb-tools installed.');
      }

      final importResult = await activeImporter.import(source);
      if (importResult.success) {
        final buffer = StringBuffer()
          ..write('Imported ${importResult.songsImported} songs, ${importResult.categoriesImported} categories.');
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(buffer.toString())),
        );
        ref.read(songListControllerProvider.notifier).fetchSongs();
      } else {
        throw Exception(importResult.errorMessage ?? 'Unknown import error');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Import Failed: $e')),
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
      await ref.read(songListControllerProvider.notifier).checkAndImportDefaultSongbooks(force: true);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Bundled songbooks imported successfully.')),
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

  Future<void> _importVsBook() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() {
      _isImporting = true;
      _importStatus = 'Selecting backup...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
          _importStatus = null;
        });
        return;
      }

      final path = result.files.single.path!;
      setState(() => _importStatus = 'Extracting and verifying .vsbook...');

      final importers = ref.read(importersProvider);
      final source = ImportSource.fromFile(path);
      final activeImporter = importers.firstWhere(
        (imp) => imp is VsBookImporter,
      );

      final importResult = await activeImporter.import(source);
      if (importResult.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Restored ${importResult.songsImported} songs.')),
        );
        ref.read(songListControllerProvider.notifier).fetchSongs();
      } else {
        throw Exception(importResult.errorMessage ?? 'Unknown restore error');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Restore Failed: $e')),
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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    if (isLargeScreen) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildMobileLayout() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: NeoShadows.raised(context),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: NeoShadows.raisedSmall(context),
                ),
                child: IconButton(
                  icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
        const ProjectionPreferencesCard(),
        const SizedBox(height: 20),
        const AppearanceCard(),
        const SizedBox(height: 20),
        ImportExportCard(
          isImporting: _isImporting,
          importStatus: _importStatus,
          isExporting: _isExporting,
          onImportMdb: _importMdb,
          onImportBundled: _importBundled,
          onImportVsBook: _importVsBook,
          onExportVsBook: _exportVsBook,
        ),
        const SizedBox(height: 20),
        const _DataSourcesCard(),
        const SizedBox(height: 20),
        const AboutCard(),
        const SizedBox(height: 20),
        const ChangelogCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    final selectedCategory = ref.watch(selectedSettingsCategoryProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Settings Sidebar
        Container(
          width: 280,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              _SidebarItem(
                title: 'General',
                isSelected: selectedCategory == 'General',
                onTap: () => ref.read(selectedSettingsCategoryProvider.notifier).state = 'General',
              ),
              const SizedBox(height: 8),
              _SidebarItem(
                title: 'Display',
                isSelected: selectedCategory == 'Display',
                onTap: () => ref.read(selectedSettingsCategoryProvider.notifier).state = 'Display',
              ),
              const SizedBox(height: 8),
              _SidebarItem(
                title: 'Library',
                isSelected: selectedCategory == 'Library',
                onTap: () => ref.read(selectedSettingsCategoryProvider.notifier).state = 'Library',
              ),
              const SizedBox(height: 8),
              _SidebarItem(
                title: 'Advanced',
                isSelected: selectedCategory == 'Advanced',
                onTap: () => ref.read(selectedSettingsCategoryProvider.notifier).state = 'Advanced',
              ),
              const SizedBox(height: 8),
              _SidebarItem(
                title: 'About',
                isSelected: selectedCategory == 'About',
                onTap: () => ref.read(selectedSettingsCategoryProvider.notifier).state = 'About',
              ),
            ],
          ),
        ),
        // Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedCategory == 'General') ...[
                    const ProjectionPreferencesCard(),
                    const SizedBox(height: 32),
                    ImportExportCard(
                      isImporting: _isImporting,
                      importStatus: _importStatus,
                      isExporting: _isExporting,
                      onImportMdb: _importMdb,
                      onImportBundled: _importBundled,
                      onImportVsBook: _importVsBook,
                      onExportVsBook: _exportVsBook,
                    ),
                  ],
                  if (selectedCategory == 'Display') ...[
                    const AppearanceCard(),
                    const SizedBox(height: 32),
                    const ProjectionPreferencesCard(),
                  ],
                  if (selectedCategory == 'Library') ...[
                    const _DataSourcesCard(isDesktop: true),
                  ],
                  if (selectedCategory == 'Advanced') ...[
                    const _AdvancedSettingsPlaceholder(),
                  ],
                  if (selectedCategory == 'About') ...[
                    const AboutCard(),
                    const SizedBox(height: 32),
                    const ChangelogCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: NeoShadows.insetSmall(context),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: NeoShadows.raisedSmall(context),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _DataSourcesCard extends ConsumerWidget {
  final bool isDesktop;
  const _DataSourcesCard({this.isDesktop = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(songRepositoryProvider);
    final theme = Theme.of(context);

    return NeoRaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.folder_copy,
            title: 'Manage Data Sources',
            accentColor: Colors.red,
          ),
          const SizedBox(height: 8),
          Text(
            'View and manage imported songbooks.',
            style: GoogleFonts.plusJakartaSans(
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
                    child: Text(
                      'No external sources found.',
                      style: GoogleFonts.plusJakartaSans(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
                );
              }
              return Column(
                children: sources.map((source) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: NeoPressedContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.split(Platform.pathSeparator).last,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  source,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DeleteButton(onPressed: () => _confirmDeleteSource(context, ref, source)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (isDesktop) ...[
            const SizedBox(height: 24),
            const _DangerZoneSection(),
          ],
          if (!isDesktop) ...[
            const SizedBox(height: 32),
            const _DangerZoneSection(),
          ],
        ],
      ),
    );
  }

  void _confirmDeleteSource(BuildContext context, WidgetRef ref, String sourcePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text('Are you sure you want to delete all songs imported from:\n\n$sourcePath?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(songRepositoryProvider).deleteSongsBySource(sourcePath);
              ref.read(songListControllerProvider.notifier).fetchSongs();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'DANGER ZONE',
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These actions are irreversible. Proceed with caution.',
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        NeoButton(
          onPressed: () => _confirmDeleteAll(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Remove All Collections',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text('This will wipe all imported songs and categories. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            child: const Text('Wipe Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
    );
  }
}

class _AdvancedSettingsPlaceholder extends StatelessWidget {
  const _AdvancedSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const NeoRaisedCard(
      child: Column(
        children: [
          SectionHeader(icon: Icons.code, title: 'Advanced'),
          SizedBox(height: 24),
          Center(
            child: Text('Advanced developer settings will appear here.'),
          ),
        ],
      ),
    );
  }
}


