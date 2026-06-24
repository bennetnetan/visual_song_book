import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';

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
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isLargeScreen || state.selectedSetId == null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Set',
              onPressed: () => _showCreateDialog(context, ref),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : isLargeScreen
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _SetList(
                    sets: state.sets,
                    selectedId: state.selectedSetId,
                    onSelect: notifier.selectSet,
                    onCreate: () => _showCreateDialog(context, ref),
                    onDelete: (id) =>
                        _confirmDelete(context, ref, id, state.sets),
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
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
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
                      : _buildSetDetail(state, notifier, ref),
                ),
              ],
            )
          // Mobile: single-column — list or detail
          : state.selectedSetId == null
          ? _SetList(
              sets: state.sets,
              selectedId: state.selectedSetId,
              onSelect: notifier.selectSet,
              onCreate: () => _showCreateDialog(context, ref),
              onDelete: (id) =>
                  _confirmDelete(context, ref, id, state.sets),
            )
          : _buildSetDetail(state, notifier, ref),
    );
  }

  Widget _buildSetDetail(SetsState state, SetsController notifier, WidgetRef ref) {
    return _SetDetail(
      setObj: notifier.selectedSet!,
      items: state.setItems,
      availableSongs: state.availableSongs,
      selectedSetId: state.selectedSetId!,
      onAddSong: (songId) => notifier.addSongToSet(
        state.selectedSetId!,
        songId,
      ),
      onRemoveSong: (songId) => notifier.removeSongFromSet(
        state.selectedSetId!,
        songId,
      ),
      onProject: () async {
        await ref
            .read(projectionControllerProvider.notifier)
            .projectSongSet(
              state.selectedSetId!,
              state.setItems,
            );
        ref
            .read(setRepositoryProvider)
            .recordSetProjection(
              state.selectedSetId!,
              notifier.selectedSet!.name,
            );
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
                ref
                    .read(setsControllerProvider.notifier)
                    .createSet(
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
    final set = sets.where((s) => s.id == id).firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Set'),
        content: Text('Delete "${set?.name ?? ''}" and all its songs?'),
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

class _SetList extends StatelessWidget {
  final List<SongSet> sets;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<int> onDelete;

  const _SetList({
    required this.sets,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Set'),
            onPressed: onCreate,
          ),
        ),
        Expanded(
          child: sets.isEmpty
              ? const Center(child: Text('No sets yet'))
              : ListView.builder(
                  itemCount: sets.length,
                  itemBuilder: (context, index) {
                    final set = sets[index];
                    final isSelected = set.id == selectedId;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      title: Text(
                        set.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: set.occasion != null && set.occasion!.isNotEmpty
                          ? Text(
                              set.occasion!,
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onDelete(set.id),
                      ),
                      onTap: () => onSelect(set.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SetDetail extends ConsumerWidget {
  final SongSet setObj;
  final List<SongSetItem> items;
  final List<Song> availableSongs;
  final int selectedSetId;
  final ValueChanged<int> onAddSong;
  final ValueChanged<int> onRemoveSong;
  final VoidCallback onProject;

  const _SetDetail({
    required this.setObj,
    required this.items,
    required this.availableSongs,
    required this.selectedSetId,
    required this.onAddSong,
    required this.onRemoveSong,
    required this.onProject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemSongIds = items.map((i) => i.songId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setObj.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (setObj.occasion != null && setObj.occasion!.isNotEmpty)
                      Text(
                        setObj.occasion!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      '${items.length} songs',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.tv, size: 18),
                label: const Text('Project All'),
                onPressed: items.isEmpty ? null : onProject,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Songs in Set',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                'No songs yet',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: items.length,
                              onReorderItem: (oldIndex, newIndex) {},
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final song = availableSongs
                                    .where((s) => s.id == item.songId)
                                    .firstOrNull;
                                return Card(
                                  key: ValueKey(item.id),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    title: Text(
                                      song?.title ?? 'Unknown',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: song != null
                                        ? Text(
                                            'Song ${song.songNum}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          )
                                        : null,
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          onRemoveSong(item.songId),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'All Songs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: availableSongs.isEmpty
                          ? const Center(child: Text('No songs in library'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: availableSongs.length,
                              itemBuilder: (context, index) {
                                final song = availableSongs[index];
                                final inSet = itemSongIds.contains(song.id);
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      song.title,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Song ${song.songNum}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: inSet
                                        ? Icon(
                                            Icons.check,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 18,
                                            ),
                                            onPressed: () => onAddSong(song.id),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
