import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';
import 'package:visual_song_book/features/sets/widgets/set_list.dart';
import 'package:visual_song_book/features/sets/widgets/set_detail.dart';

final _log = AppLogger.get('SetsTab');

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
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Set List'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final result = await FilePicker.pickFiles(
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
                },
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose File (.json, .vsbset)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Paste Set Format (JSON)',
                  hintText: '{\n  "name": "...",\n  "items": [...]\n}',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final pasted = textCtrl.text.trim();
              if (pasted.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(setsControllerProvider.notifier).importSetFromJson(pasted);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Set list imported successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error importing set list: $e')),
                  );
                }
              }
            },
            child: const Text('Import Text'),
          ),
        ],
      ),
    );
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

      final path = await FilePicker.saveFile(
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


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setsControllerProvider);
    final notifier = ref.read(setsControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [],
        // Hide the toolbar height on large screens where the AppBar adds no value
        toolbarHeight: isLargeScreen && state.selectedSetId == null ? 0 : kToolbarHeight,
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
                        songCounts: state.songCounts,
                        selectedId: state.selectedSetId,
                        onSelect: notifier.selectSet,
                        onCreate: () => _showCreateDialog(context, ref),
                        onDelete: (id) => _confirmDelete(context, ref, id, state.sets),
                        onDuplicate: (id) => _handleDuplicate(context, ref, id, state.sets),
                        onProject: (id) => _quickProject(context, ref, id, state),
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
                      songCounts: state.songCounts,
                      selectedId: state.selectedSetId,
                      onSelect: notifier.selectSet,
                      onCreate: () => _showCreateDialog(context, ref),
                      onDelete: (id) => _confirmDelete(context, ref, id, state.sets),
                      onDuplicate: (id) => _handleDuplicate(context, ref, id, state.sets),
                      onProject: (id) => _quickProject(context, ref, id, state),
                      onImport: () => _handleImport(context, ref),
                    )
                  : _buildSetDetail(context, state, notifier, ref),
    );
  }

  Future<void> _quickProject(
    BuildContext context,
    WidgetRef ref,
    int setId,
    SetsState state,
  ) async {
    final setObj = state.sets.where((s) => s.id == setId).firstOrNull;
    if (setObj == null) return;
    final repo = ref.read(setRepositoryProvider);
    final items = await repo.getSetItems(setId);
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot project an empty set. Add songs first.')),
        );
      }
      return;
    }
    await ref.read(projectionControllerProvider.notifier).projectSongSet(
          setId,
          setObj.name,
          items,
        );
    if (!context.mounted) return;
    await ref.read(projectionControllerProvider.notifier).triggerProjection(context, isLargeScreen);
  }

  void _handleDuplicate(
    BuildContext context,
    WidgetRef ref,
    int setId,
    List<SongSet> sets,
  ) {
    final setObj = sets.where((s) => s.id == setId).firstOrNull;
    final nameCtrl = TextEditingController(
      text: setObj != null ? '${setObj.name} (Copy)' : 'Set (Copy)',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Set'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'New Set Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty) {
                await ref.read(setsControllerProvider.notifier).duplicateSet(
                      setId,
                      newName: newName,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Set duplicated as "$newName"')),
                  );
                }
              }
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetDetail(
    BuildContext context,
    SetsState state,
    SetsController notifier,
    WidgetRef ref,
  ) {
    final currentSet = notifier.selectedSet;
    if (currentSet == null) {
      _log.warning(
        '_buildSetDetail: selectedSetId=${state.selectedSetId} but '
        'selectedSet resolved to null (sets not yet loaded). '
        'Showing loader.',
      );
      return const Center(child: CircularProgressIndicator());
    }
    return SetDetail(
      setObj: currentSet,
      items: state.setItems,
      availableSongs: state.availableSongs,
      selectedSetId: state.selectedSetId!,
      onAddSong: (songId, {key}) => notifier.addSongToSet(state.selectedSetId!, songId, key: key),
      onRemoveSong: (songId) => notifier.removeSongFromSet(state.selectedSetId!, songId),
      onRename: (newName) => notifier.renameSet(state.selectedSetId!, newName),
      onShareJson: () => _handleShareJson(context, ref, state.selectedSetId!, currentSet.name),
      onProject: () async {
        await ref.read(projectionControllerProvider.notifier).projectSongSet(
              state.selectedSetId!,
              notifier.selectedSet!.name,
              state.setItems,
            );
        if (!context.mounted) return;
        await ref.read(projectionControllerProvider.notifier).triggerProjection(context, isLargeScreen);
      },
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final occasionCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Set'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Set Name',
                  hintText: 'e.g. Sunday Morning Service',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: occasionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Occasion (optional)',
                  hintText: 'e.g. Youth, Communion, Christmas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Date',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Change Date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ref.read(setsControllerProvider.notifier).createSet(
                        nameCtrl.text.trim(),
                        occasion: occasionCtrl.text.trim().isNotEmpty ? occasionCtrl.text.trim() : null,
                        createdAt: selectedDate,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(setsControllerProvider.notifier).deleteSet(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
