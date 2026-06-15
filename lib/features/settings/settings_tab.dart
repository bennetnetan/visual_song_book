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
  bool _isDeletingArchives = false;

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

  Future<void> _deleteArchives() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isDeletingArchives = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isDeletingArchives = false);
        return;
      }

      final archives = result.files.where((f) {
        final name = f.name.toLowerCase();
        return name.endsWith('.vsbook') || name.endsWith('.vsb') || name.endsWith('.mdb');
      }).toList();

      if (archives.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No archive files (.vsbook, .vsb, .mdb) selected.')),
        );
        setState(() => _isDeletingArchives = false);
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Archives'),
          content: Text(
            'Delete ${archives.length} archive file(s) from disk?\n\n'
            '${archives.map((f) => '  • ${f.name}').join('\n')}\n\n'
            'This only removes the files on disk. Songs already imported into the database will not be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isDeletingArchives = false);
        return;
      }
      if (!mounted) return;

      int deleted = 0;
      int failed = 0;
      for (final file in archives) {
        try {
          final diskFile = File(file.path!);
          if (await diskFile.exists()) {
            await diskFile.delete();
            deleted++;
          }
        } catch (_) {
          failed++;
        }
      }

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted archive file(s) from disk.'
              '${failed > 0 ? " $failed failed to delete." : ""}'),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to delete archives: $e')),
      );
    } finally {
      setState(() => _isDeletingArchives = false);
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
            padding: const EdgeInsets.all(24.0),
            children: [
              ImportExportCard(
                isImporting: _isImporting,
                importStatus: _importStatus,
                isExporting: _isExporting,
                onImportMdb: _importMdb,
                onImportVsBook: _importVsBook,
                onExportVsBook: _exportVsBook,
              ),
              const SizedBox(height: 16),
              ManageArchivesCard(
                isDeletingArchives: _isDeletingArchives,
                onDeleteArchives: _deleteArchives,
              ),
              const SizedBox(height: 16),
              const ScreenPreferencesCard(),
              const SizedBox(height: 16),
              const AboutCard(),
            ],
          ),
        ),
      ),
    );
  }
}
