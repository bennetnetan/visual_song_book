import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/services/share_service.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';

class SetDetail extends ConsumerStatefulWidget {
  final SongSet setObj;
  final List<SongSetItem> items;
  final List<Song> availableSongs;
  final int selectedSetId;
  final void Function(int songId, {String? key}) onAddSong;
  final ValueChanged<int> onRemoveSong;
  final VoidCallback onProject;
  final VoidCallback onShareJson;
  final ValueChanged<String> onRename;

  const SetDetail({
    super.key,
    required this.setObj,
    required this.items,
    required this.availableSongs,
    required this.selectedSetId,
    required this.onAddSong,
    required this.onRemoveSong,
    required this.onProject,
    required this.onShareJson,
    required this.onRename,
  });

  @override
  ConsumerState<SetDetail> createState() => _SetDetailState();
}

class _SetDetailState extends ConsumerState<SetDetail> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditSetDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: widget.setObj.name);
    final occasionCtrl = TextEditingController(text: widget.setObj.occasion ?? '');
    DateTime selectedDate = widget.setObj.createdAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Set Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Set Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: occasionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Occasion',
                  hintText: 'e.g. Sunday Morning, Youth, Easter',
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
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(setsControllerProvider.notifier).updateSetDetails(
                        widget.setObj.id,
                        name: newName,
                        occasion: occasionCtrl.text.trim().isNotEmpty ? occasionCtrl.text.trim() : null,
                        createdAt: selectedDate,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemNotesDialog(SongSetItem item, Song song) {
    final notesCtrl = TextEditingController(text: item.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notes for "${song.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Performance / Worship Notes',
                hintText: 'e.g. Capo 2, skip verse 3, acoustic intro, solo after chorus',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (item.notes != null && item.notes!.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(setsControllerProvider.notifier).updateSongNotesInSet(
                      widget.selectedSetId,
                      item.songId,
                      null,
                    );
                Navigator.pop(ctx);
              },
              child: Text(
                'Clear Notes',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newNotes = notesCtrl.text.trim();
              ref.read(setsControllerProvider.notifier).updateSongNotesInSet(
                    widget.selectedSetId,
                    item.songId,
                    newNotes.isNotEmpty ? newNotes : null,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddSongKeyDialog(Song song) async {
    final notifier = ref.read(setsControllerProvider.notifier);
    final topKeys = await notifier.getTopUsedKeysForSong(song.id);
    final lastKeys = await notifier.getLastUsedKeysForSong(song.id);

    if (!mounted) return;

    final textCtrl = TextEditingController(text: song.key ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add "${song.title}" to Set'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key (e.g., C, G, Eb, F#m)',
                  hintText: 'Enter musical key',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              if (song.key != null && song.key!.isNotEmpty) ...[
                Text('Original Song Key:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                ActionChip(
                  label: Text(song.key!),
                  onPressed: () {
                    textCtrl.text = song.key!;
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (topKeys.isNotEmpty) ...[
                Text('Top Keys Used in Sets:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: topKeys.map((k) => ActionChip(
                    label: Text(k),
                    onPressed: () {
                      textCtrl.text = k;
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (lastKeys.isNotEmpty) ...[
                Text('Last Keys Used in Sets:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: lastKeys.map((k) => ActionChip(
                    label: Text(k),
                    backgroundColor: Theme.of(ctx).colorScheme.secondaryContainer,
                    onPressed: () {
                      textCtrl.text = k;
                    },
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onAddSong(song.id, key: null);
              Navigator.pop(ctx);
            },
            child: const Text('Add (no key)'),
          ),
          TextButton(
            onPressed: () {
              final selectedKey = textCtrl.text.trim();
              widget.onAddSong(
                song.id,
                key: selectedKey.isNotEmpty ? selectedKey : null,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add to Set'),
          ),
        ],
      ),
    );
  }

  void _showKeySelectorDialog(SongSetItem item, Song song) async {
    final notifier = ref.read(setsControllerProvider.notifier);
    final topKeys = await notifier.getTopUsedKeysForSong(item.songId);
    final lastKeys = await notifier.getLastUsedKeysForSong(item.songId);

    if (!mounted) return;

    final textCtrl = TextEditingController(text: item.key ?? song.key ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Key for "${song.title}"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key (e.g., C, G, Eb, F#m)',
                  hintText: 'Enter musical key',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              if (song.key != null && song.key!.isNotEmpty) ...[
                Text('Original Song Key:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                ActionChip(
                  label: Text(song.key!),
                  onPressed: () {
                    textCtrl.text = song.key!;
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (topKeys.isNotEmpty) ...[
                Text('Top Keys Used in Sets:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: topKeys.map((k) => ActionChip(
                    label: Text(k),
                    onPressed: () {
                      textCtrl.text = k;
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (lastKeys.isNotEmpty) ...[
                Text('Last Keys Used in Sets:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: lastKeys.map((k) => ActionChip(
                    label: Text(k),
                    backgroundColor: Theme.of(ctx).colorScheme.secondaryContainer,
                    onPressed: () {
                      textCtrl.text = k;
                    },
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.updateSongKeyInSet(widget.selectedSetId, item.songId, null);
              Navigator.pop(ctx);
            },
            child: Text(
              'Clear Key',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newKey = textCtrl.text.trim();
              notifier.updateSongKeyInSet(
                widget.selectedSetId,
                item.songId,
                newKey.isNotEmpty ? newKey : null,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySetList(BuildContext context) async {
    try {
      final textString = await ref.read(setsControllerProvider.notifier).getSetPlainText(widget.setObj.id);
      await Clipboard.setData(ClipboardData(text: textString));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set list copied to clipboard!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy: $e')),
        );
      }
    }
  }

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose where to share this set list'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final textString = await ref.read(setsControllerProvider.notifier).getSetPlainText(widget.setObj.id);
                    await ShareService.shareText(textString);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to share: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Copy formatted set list to paste in WhatsApp or messages'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copySetList(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export for Another Device'),
                subtitle: const Text('Save a file with full lyrics — importable on other devices'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onShareJson();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemSongIds = widget.items.map((i) => i.songId).toSet();
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    final query = _searchQuery.trim().toLowerCase();
    final filteredSongs = widget.availableSongs.where((song) {
      if (query.isEmpty) return true;
      return song.title.toLowerCase().contains(query) ||
          song.songNum.toString() == query ||
          (song.key != null && song.key!.toLowerCase().contains(query)) ||
          song.body.toLowerCase().contains(query);
    }).toList();

    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.setObj.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Semantics(
          label: 'Edit Set Details',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit Set Details',
            onPressed: () => _showEditSetDialog(context),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
          ),
        ),
      ],
    );

    final subtitleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.setObj.occasion != null && widget.setObj.occasion!.isNotEmpty) ...[
          Text(
            widget.setObj.occasion!,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),
        ],
        Text(
          '${widget.items.length} songs',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );

    final songsInSetColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Songs in Set',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hold and drag the handle to reorder songs',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.items.isEmpty
              ? Center(
                  child: Text(
                    'No songs yet',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: widget.items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    ref.read(setsControllerProvider.notifier).reorderSongs(
                      widget.selectedSetId,
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final song = widget.availableSongs
                        .where((s) => s.id == item.songId)
                        .firstOrNull;
                    return Card(
                      key: ValueKey(item.id),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        dense: true,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                color: Colors.transparent,
                                child: Icon(
                                  Icons.drag_handle,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          song?.title ?? 'Unknown',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: song != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Song ${song.songNum}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _showKeySelectorDialog(item, song),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.key != null && item.key!.isNotEmpty
                                                ? theme.colorScheme.primaryContainer
                                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: item.key == null || item.key!.isEmpty
                                                ? Border.all(
                                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.key != null && item.key!.isNotEmpty
                                                    ? 'Key: ${item.key}'
                                                    : 'Set Key',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: item.key != null && item.key!.isNotEmpty
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: item.key != null && item.key!.isNotEmpty
                                                      ? theme.colorScheme.onPrimaryContainer
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.edit,
                                                size: 8,
                                                color: item.key != null && item.key!.isNotEmpty
                                                    ? theme.colorScheme.onPrimaryContainer
                                                    : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => _showItemNotesDialog(item, song),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.notes != null && item.notes!.isNotEmpty
                                                ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7)
                                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                            border: item.notes == null || item.notes!.isEmpty
                                                ? Border.all(
                                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.sticky_note_2_outlined,
                                                size: 9,
                                                color: item.notes != null && item.notes!.isNotEmpty
                                                    ? theme.colorScheme.onTertiaryContainer
                                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                item.notes != null && item.notes!.isNotEmpty
                                                    ? 'Notes'
                                                    : '+ Note',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: item.notes != null && item.notes!.isNotEmpty
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: item.notes != null && item.notes!.isNotEmpty
                                                      ? theme.colorScheme.onTertiaryContainer
                                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: InkWell(
                                        onTap: () => _showItemNotesDialog(item, song),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📝 ',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            Expanded(
                                              child: Text(
                                                item.notes!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (item.key == null || item.key!.isEmpty)
                                    FutureBuilder<List<List<String>>>(
                                      future: Future.wait([
                                        ref.read(setsControllerProvider.notifier).getTopUsedKeysForSong(item.songId),
                                        ref.read(setsControllerProvider.notifier).getLastUsedKeysForSong(item.songId),
                                      ]),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) return const SizedBox.shrink();
                                        final top = snapshot.data![0];
                                        final last = snapshot.data![1];
                                        final suggestions = <String>{...top, ...last}.take(3).toList();
                                        if (suggestions.isEmpty) return const SizedBox.shrink();

                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Suggestions: ',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                ),
                                              ),
                                              Wrap(
                                                spacing: 4,
                                                children: suggestions.map((k) => InkWell(
                                                  onTap: () {
                                                    ref.read(setsControllerProvider.notifier).updateSongKeyInSet(
                                                      widget.selectedSetId,
                                                      item.songId,
                                                      k,
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      k,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                )).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              )
                            : null,
                        trailing: Semantics(
                          label: 'Remove Song',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: theme.colorScheme.error.withValues(alpha: 0.7),
                            ),
                            onPressed: () => widget.onRemoveSong(item.songId),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    final allSongsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Song Library',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search title, number, lyrics...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? Semantics(
                      label: 'Clear Search',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    )
                  : null,
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: filteredSongs.isEmpty
              ? Center(
                  child: Text(
                    'No matching songs',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filteredSongs.length,
                  itemBuilder: (context, index) {
                    final song = filteredSongs[index];
                    final inSet = itemSongIds.contains(song.id);
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          song.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                            : Semantics(
                                label: 'Add Song',
                                button: true,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => _showAddSongKeyDialog(song),
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    final headerPadding = isLargeScreen
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: headerPadding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget,
                    const SizedBox(height: 2),
                    subtitleWidget,
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Copy Set List',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy Set List',
                      onPressed: widget.items.isEmpty ? null : () => _copySetList(context),
                    ),
                  ),
                  Semantics(
                    label: 'Share Set',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share Set',
                      onPressed: widget.items.isEmpty ? null : () => _showShareMenu(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isLargeScreen)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.tv, size: 18),
                      label: const Text('Project Set'),
                      onPressed: widget.items.isEmpty ? null : widget.onProject,
                    )
                  else
                    FilledButton.tonal(
                      onPressed: widget.items.isEmpty ? null : widget.onProject,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.slideshow, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Start Presentation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isLargeScreen
              ? Row(
                  children: [
                    Expanded(child: songsInSetColumn),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: allSongsColumn),
                  ],
                )
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: 'Songs in Set'),
                          Tab(text: 'Add Songs'),
                        ],
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            songsInSetColumn,
                            allSongsColumn,
                          ],
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
