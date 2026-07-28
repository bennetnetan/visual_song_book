import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';
import 'package:visual_song_book/features/song_list/widgets/song_list_item.dart';
import 'package:visual_song_book/features/song_list/widgets/song_preview_panel.dart';

class SongsTab extends ConsumerWidget {
  final bool isLargeScreen;

  const SongsTab({super.key, required this.isLargeScreen});

  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildSourceChip(
    BuildContext context, {
    required String label,
    String? subtitle,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  String _getSourceDisplayName(String path) {
    // For file paths, extract just the filename
    if (path.contains('/') || path.contains('\\')) {
      final parts = path.split(RegExp(r'[/\\]'));
      final filename = parts.last;
      // Remove common extensions
      return filename.replaceAll(RegExp(r'\.(vsbook|vsb|mdb)$'), '');
    }
    // For book names (e.g., "Full Song Book"), use as-is
    return path;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(songListControllerProvider);
    final listNotifier = ref.read(songListControllerProvider.notifier);
    final selectedSongId = ref.watch(selectedSongIdProvider);

    final selectedSong = selectedSongId != null
        ? listState.songs.where((s) => s.id == selectedSongId).firstOrNull
        : null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: listNotifier.setQuery,
                                decoration: InputDecoration(
                                  hintText: 'Search title, number, or lyrics...',
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  suffixIcon: listState.query.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => listNotifier.setQuery(''),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<SongSortMode>(
                              icon: const Icon(Icons.sort),
                              tooltip: 'Sort By',
                              onSelected: listNotifier.setSortMode,
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: SongSortMode.byNumber,
                                  child: Row(
                                    children: [
                                      Icon(Icons.format_list_numbered),
                                      SizedBox(width: 8),
                                      Text('Number'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: SongSortMode.byTitle,
                                  child: Row(
                                    children: [
                                      Icon(Icons.sort_by_alpha),
                                      SizedBox(width: 8),
                                      Text('Alphabetical'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: SongSortMode.byKey,
                                  child: Row(
                                    children: [
                                      Icon(Icons.music_note),
                                      SizedBox(width: 8),
                                      Text('By Key'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            _buildCategoryChip(
                              context,
                              label: 'All',
                              selected: listState.selectedCategoryId == -2,
                              onSelected: () => listNotifier.selectCategory(-2),
                            ),
                            ...listState.categories.expand(
                              (cat) => [
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onLongPress: () =>
                                      _confirmDeleteCategory(context, ref, cat),
                                  child: _buildCategoryChip(
                                    context,
                                    label: cat.name,
                                    selected: listState.selectedCategoryId == cat.id,
                                    onSelected: () =>
                                        listNotifier.selectCategory(cat.id),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _buildCategoryChip(
                              context,
                              label: 'Uncategorized',
                              selected: listState.showUncategorizedOnly,
                              onSelected: () => listNotifier.selectCategory(
                                null,
                                uncategorizedOnly: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Source/Songbook filter chips
                      if (listState.sourcePaths.length > 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.library_books_outlined,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              _buildSourceChip(
                                context,
                                label: 'All Books',
                                selected: listState.selectedSourcePath == null,
                                onSelected: () => listNotifier.selectSource(null),
                              ),
                              ...listState.sourcePaths.map(
                                (source) => Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: _buildSourceChip(
                                    context,
                                    label: _getSourceDisplayName(source.path),
                                    subtitle: '${source.count}',
                                    selected: listState.selectedSourcePath == source.path,
                                    onSelected: () => listNotifier.selectSource(source.path),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: listState.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : listState.songs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.library_books_outlined,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No songs found.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => context.push('/song-editor'),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Song Manually'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: 24,
                                ),
                                itemCount: listState.songs.length,
                                itemBuilder: (context, index) {
                                  final song = listState.songs[index];
                                  final isSelected = song.id == selectedSongId;
                                  return SongListItem(
                                    song: song,
                                    isSelected: isSelected,
                                    isLargeScreen: isLargeScreen,
                                    onTap: () {
                                      ref
                                          .read(selectedSongIdProvider.notifier)
                                          .state = song.id;
                                    },
                                    onDoubleTap: () async {
                                      ref
                                          .read(projectionControllerProvider.notifier)
                                          .setSong(song);
                                      await ref
                                          .read(projectionControllerProvider.notifier)
                                          .triggerProjection(context, isLargeScreen);
                                    },
                                    onProjectTap: () async {
                                      ref
                                          .read(projectionControllerProvider.notifier)
                                          .setSong(song);
                                      await ref
                                          .read(projectionControllerProvider.notifier)
                                          .triggerProjection(context, isLargeScreen);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                if (isLargeScreen) ...[
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 4,
                    child: selectedSong != null
                        ? SongPreviewPanel(song: selectedSong)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.library_music_outlined,
                                  size: 72,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a song to preview',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final songCount = await ref
        .read(songRepositoryProvider)
        .getSongCountByCategory(cat.id);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${cat.name}" and all $songCount song(s) in it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(songListControllerProvider.notifier)
                  .deleteCategory(cat.id);
              ref.read(selectedSongIdProvider.notifier).state = null;
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
