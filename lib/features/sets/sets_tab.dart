import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';
import 'package:visual_song_book/features/sets/widgets/set_list.dart';
import 'package:visual_song_book/features/sets/widgets/set_detail.dart';

final setsControllerProvider = StateNotifierProvider<SetsController, SetsState>(
  (ref) {
    final repo = ref.watch(setRepositoryProvider);
    final songRepo = ref.watch(songRepositoryProvider);
    return SetsController(repo, songRepo);
  },
);

class SetsTab extends ConsumerWidget {
  final bool isLargeScreen;

  const SetsTab({super.key, required this.isLargeScreen});

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'vsbset'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final content = await file.readAsString();

        await ref.read(setsControllerProvider.notifier).importSetFromJson(content);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set list imported successfully!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing set list: $e')),
        );
      }
    }
  }

  Future<void> _handleShareJson(
    BuildContext context,
    WidgetRef ref,
    int setId,
    String setName,
  ) async {
    try {
      final jsonString = await ref.read(setsControllerProvider.notifier).getSetJsonString(setId);
      final sanitizedName = setName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Set List (.json)',
        fileName: '${sanitizedName}_set.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsString(jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set list exported successfully!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _handleShareText(
    BuildContext context,
    WidgetRef ref,
    int setId,
    String setName,
  ) async {
    try {
      final textString = await ref.read(setsControllerProvider.notifier).getSetPlainText(setId);
      final sanitizedName = setName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Plain Text Lyrics (.txt)',
        fileName: '${sanitizedName}_lyrics.txt',
        type: FileType.any,
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsString(textString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lyrics exported successfully!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setsControllerProvider);
    final notifier = ref.read(setsControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: !isLargeScreen && state.selectedSetId == null
          ? null
          : AppBar(
              leading: !isLargeScreen && state.selectedSetId != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: notifier.clearSelection,
                    )
                  : null,
              title: Text(
                !isLargeScreen && state.selectedSetId != null
                    ? notifier.selectedSet?.name ?? 'Set'
                    : 'Sets',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              actions: const [],
            ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : isLargeScreen
              ? Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: SetList(
                        sets: state.sets,
                        selectedId: state.selectedSetId,
                        onSelect: notifier.selectSet,
                        onCreate: () => _showCreateDialog(context, ref),
                        onDelete: (id) => _confirmDelete(context, ref, id, state.sets),
                        onImport: () => _handleImport(context, ref),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: state.selectedSetId == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.playlist_play,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Select a set or create one',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildSetDetail(context, state, notifier, ref),
                    ),
                  ],
                )
              // Mobile: single-column — list or detail
              : state.selectedSetId == null
                  ? SetList(
                      sets: state.sets,
                      selectedId: state.selectedSetId,
                      onSelect: notifier.selectSet,
                      onCreate: () => _showCreateDialog(context, ref),
                      onDelete: (id) => _confirmDelete(context, ref, id, state.sets),
                      onImport: () => _handleImport(context, ref),
                    )
                  : _buildSetDetail(context, state, notifier, ref),
    );
  }

  Widget _buildSetDetail(
    BuildContext context,
    SetsState state,
    SetsController notifier,
    WidgetRef ref,
  ) {
    final currentSet = notifier.selectedSet!;
    return SetDetail(
      setObj: currentSet,
      items: state.setItems,
      availableSongs: state.availableSongs,
      selectedSetId: state.selectedSetId!,
      onAddSong: (songId, {key}) => notifier.addSongToSet(state.selectedSetId!, songId, key: key),
      onRemoveSong: (songId) => notifier.removeSongFromSet(state.selectedSetId!, songId),
      onRename: (newName) => notifier.renameSet(state.selectedSetId!, newName),
      onShareJson: () => _handleShareJson(context, ref, state.selectedSetId!, currentSet.name),
      onShareText: () => _handleShareText(context, ref, state.selectedSetId!, currentSet.name),
      onProject: () async {
        await ref.read(projectionControllerProvider.notifier).projectSongSet(
              state.selectedSetId!,
              state.setItems,
            );
        if (!context.mounted) return;
        ref.read(setRepositoryProvider).recordSetProjection(
              state.selectedSetId!,
              notifier.selectedSet!.name,
            );
        await ref.read(projectionControllerProvider.notifier).triggerProjection(context, isLargeScreen);
      },
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final occasionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Set Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: occasionCtrl,
              decoration: const InputDecoration(
                labelText: 'Occasion (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(setsControllerProvider.notifier).createSet(
                      nameCtrl.text.trim(),
                      occasion: occasionCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
    List<SongSet> sets,
  ) {
    final setObj = sets.where((s) => s.id == id).firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Set'),
        content: Text('Delete "${setObj?.name ?? ''}" and all its songs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(setsControllerProvider.notifier).deleteSet(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
