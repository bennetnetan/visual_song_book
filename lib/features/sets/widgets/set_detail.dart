import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';

class SetDetail extends ConsumerStatefulWidget {
  final SongSet setObj;
  final List<SongSetItem> items;
  final List<Song> availableSongs;
  final int selectedSetId;
  final ValueChanged<int> onAddSong;
  final ValueChanged<int> onRemoveSong;
  final VoidCallback onProject;
  final VoidCallback onShareJson;
  final VoidCallback onShareText;
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
    required this.onShareText,
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

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.setObj.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Set'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Set Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.onRename(newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Share as App Format (.json)'),
                subtitle: const Text('Includes lyrics, metadata — importable on other devices'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onShareJson();
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Share as Plain Text (.txt)'),
                subtitle: const Text('Export full printable lyrics of all songs'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onShareText();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy as App Format (JSON)'),
                subtitle: const Text('Copy JSON data of the set to clipboard'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final jsonString = await ref.read(setsControllerProvider.notifier).getSetJsonString(widget.setObj.id);
                    await Clipboard.setData(ClipboardData(text: jsonString));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('JSON data copied to clipboard!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to copy JSON: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy Plain Text Lyrics'),
                subtitle: const Text('Copy lyrics of all songs in set to clipboard'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final textString = await ref.read(setsControllerProvider.notifier).getSetPlainText(widget.setObj.id);
                    await Clipboard.setData(ClipboardData(text: textString));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Plain text lyrics copied to clipboard!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to copy lyrics: $e')),
                      );
                    }
                  }
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

    final query = _searchQuery.trim().toLowerCase();
    final filteredSongs = widget.availableSongs.where((song) {
      if (query.isEmpty) return true;
      return song.title.toLowerCase().contains(query) ||
          song.songNum.toString() == query ||
          (song.key != null && song.key!.toLowerCase().contains(query)) ||
          song.body.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.setObj.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Rename Set',
                          onPressed: () => _showRenameDialog(context),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(left: 8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (widget.setObj.occasion != null && widget.setObj.occasion!.isNotEmpty)
                      Text(
                        widget.setObj.occasion!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '${widget.items.length} songs',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Set',
                onPressed: widget.items.isEmpty ? null : () => _showShareMenu(context),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.tv, size: 18),
                label: const Text('Project All'),
                onPressed: widget.items.isEmpty ? null : widget.onProject,
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: widget.items.length,
                              onReorder: (oldIndex, newIndex) {
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
                                    leading: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    title: Text(
                                      song?.title ?? 'Unknown',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: song != null
                                        ? Text(
                                            'Song ${song.songNum}',
                                            style: const TextStyle(fontSize: 11),
                                          )
                                        : null,
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        size: 18,
                                        color: theme.colorScheme.error.withValues(alpha: 0.7),
                                      ),
                                      onPressed: () => widget.onRemoveSong(item.songId),
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
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
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 18,
                                            ),
                                            onPressed: () => widget.onAddSong(song.id),
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
