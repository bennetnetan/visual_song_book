import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

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
        if (importResult.songsAdded > 0) {
          buffer.write(' ${importResult.songsAdded} new,');
        }
        if (importResult.songsAlreadyExisted > 0) {
          buffer.write(' ${importResult.songsAlreadyExisted} already existed,');
        }
        if (importResult.newSongTitles.length <= 5) {
          for (final title in importResult.newSongTitles) {
            buffer.write('\n  • $title');
          }
        } else if (importResult.newSongTitles.isNotEmpty) {
          buffer.write('\n  ${importResult.newSongTitles.length} new songs added');
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(buffer.toString()),
            duration: const Duration(seconds: 8),
          ),
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
        final buffer = StringBuffer()
          ..write('Restored ${importResult.songsImported} songs, ${importResult.categoriesImported} categories.');
        if (importResult.songsAdded > 0) {
          buffer.write(' ${importResult.songsAdded} new,');
        }
        if (importResult.songsAlreadyExisted > 0) {
          buffer.write(' ${importResult.songsAlreadyExisted} already existed,');
        }
        if (importResult.newSongTitles.length <= 5) {
          for (final title in importResult.newSongTitles) {
            buffer.write('\n  • $title');
          }
        } else if (importResult.newSongTitles.isNotEmpty) {
          buffer.write('\n  ${importResult.newSongTitles.length} new songs added');
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(buffer.toString()),
            duration: const Duration(seconds: 8),
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Application Settings')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ImportExportCard(
                isImporting: _isImporting,
                importStatus: _importStatus,
                isExporting: _isExporting,
                onImportMdb: _importMdb,
                onImportVsBook: _importVsBook,
                onExportVsBook: _exportVsBook,
              ),
              const SizedBox(height: 20),
              _DataSourcesCard(),
              const SizedBox(height: 20),
              const ProjectionPreferencesCard(),
              const SizedBox(height: 20),
              const AppearanceCard(),
              const SizedBox(height: 20),
              const AboutCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataSourcesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(songRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.source_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Manage Data Sources',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'View and manage songs based on their import source. This is useful for removing old collections before pushing updates.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: repo.getDistinctSourcePaths(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sources = snapshot.data ?? [];
                if (sources.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No external sources found.', style: TextStyle(fontStyle: FontStyle.italic)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(source, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteSource(context, ref, source),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
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
