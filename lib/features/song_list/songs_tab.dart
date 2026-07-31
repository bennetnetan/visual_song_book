import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';
import 'package:visual_song_book/features/song_list/widgets/song_list_item.dart';
import 'package:visual_song_book/features/song_list/widgets/song_preview_panel.dart';

class SongsTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const SongsTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<SongsTab> {
  bool _isSearching = false;
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final listState = ref.watch(songListControllerProvider);
    final listNotifier = ref.read(songListControllerProvider.notifier);
    final selectedSongId = ref.watch(selectedSongIdProvider);

    final selectedSong = selectedSongId != null
        ? listState.songs.where((s) => s.id == selectedSongId).firstOrNull
        : null;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverAppBar(
                          pinned: true,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          leading: _isSearching
                              ? IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () {
                                    setState(() => _isSearching = false);
                                    ref.read(songListControllerProvider.notifier).setQuery('');
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  },
                                )
                              : null,
                          titleSpacing: _isSearching ? 0 : 16,
                          title: _isSearching
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: TextField(
                                    focusNode: _searchFocusNode,
                                    onChanged: listNotifier.setQuery,
                                    decoration: InputDecoration(
                                      hintText: 'Search title, number, or lyrics...',
                                      hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
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
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    Hero(
                                      tag: 'app_logo_songs',
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        ),
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          width: 24,
                                          height: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Song Book',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                          actions: _isSearching
                              ? []
                              : [
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    tooltip: 'Search Songs',
                                    onPressed: () {
                                      setState(() => _isSearching = true);
                                      _searchFocusNode.requestFocus();
                                    },
                                  ),
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
                                  const AddMenuButton(isExpanded: false),
                                  const SizedBox(width: 8),
                                ],
                          bottom: listState.sourcePaths.length > 1
                              ? PreferredSize(
                                  preferredSize: const Size.fromHeight(48),
                                  child: SingleChildScrollView(
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
                                )
                              : const PreferredSize(
                                  preferredSize: Size.fromHeight(8),
                                  child: SizedBox(height: 8),
                                ),
                        ),
                      ];
                    },
                    body: listState.isLoading
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
                                    isLargeScreen: widget.isLargeScreen,
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
                                          .triggerProjection(context, widget.isLargeScreen);
                                    },
                                    onProjectTap: () async {
                                      ref
                                          .read(projectionControllerProvider.notifier)
                                          .setSong(song);
                                      await ref
                                          .read(projectionControllerProvider.notifier)
                                          .triggerProjection(context, widget.isLargeScreen);
                                    },
                                  );
                                },
                              ),
                  ),
                ),
                if (widget.isLargeScreen) ...[
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
    );
  }
}
