import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

final activeDashboardTabProvider = StateProvider<int>((ref) => 0);
final selectedSongIdProvider = StateProvider<int?>((ref) => null);

class MainDashboardPage extends ConsumerWidget {
  const MainDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeDashboardTabProvider);
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: !isLargeScreen
          ? AppBar(
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Visual Song Book',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add New Song',
                  onPressed: () => context.push('/song-editor'),
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (isLargeScreen) ...[
            NavigationRail(
              selectedIndex: activeTab,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Song Book',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add New Song',
                  onPressed: () => context.push('/song-editor'),
                ),
              ),
              onDestinationSelected: (index) {
                ref.read(activeDashboardTabProvider.notifier).state = index;
              },
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                  label: Text('Songs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tv_outlined),
                  selectedIcon: Icon(Icons.tv),
                  label: Text('Projection'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child: _buildTabContent(activeTab, isLargeScreen),
          ),
        ],
      ),
      bottomNavigationBar: !isLargeScreen
          ? NavigationBar(
              selectedIndex: activeTab,
              onDestinationSelected: (index) {
                ref.read(activeDashboardTabProvider.notifier).state = index;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                  label: 'Songs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tv_outlined),
                  selectedIcon: Icon(Icons.tv),
                  label: 'Projection',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildTabContent(int tabIndex, bool isLargeScreen) {
    switch (tabIndex) {
      case 0:
        return _SongsTab(isLargeScreen: isLargeScreen);
      case 1:
        return _ProjectionTab(isLargeScreen: isLargeScreen);
      case 2:
        return const _SettingsTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }
}

// ================= SONGS TAB =================

class _SongsTab extends ConsumerWidget {
  final bool isLargeScreen;

  const _SongsTab({required this.isLargeScreen});

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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(songListControllerProvider);
    final listNotifier = ref.read(songListControllerProvider.notifier);
    final selectedSongId = ref.watch(selectedSongIdProvider);

    final selectedSong = selectedSongId != null
        ? listState.songs.where((s) => s.id == selectedSongId).firstOrNull
        : null;

    return Row(
      children: [
        // Left Column: Song List
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: TextField(
                  onChanged: listNotifier.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Search title, number, or lyrics...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                    suffixIcon: listState.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              listNotifier.setQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
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
              // Category Tabs (Horizontal Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildCategoryChip(
                      context,
                      label: 'All',
                      selected: listState.selectedCategoryId == null && !listState.showUncategorizedOnly,
                      onSelected: () => listNotifier.selectCategory(null),
                    ),
                    // Dynamic category chips from DB
                    ...listState.categories.expand((cat) => [
                      const SizedBox(width: 8),
                      GestureDetector(
                        onLongPress: () => _confirmDeleteCategory(context, ref, cat),
                        child: _buildCategoryChip(
                          context,
                          label: cat.name,
                          selected: listState.selectedCategoryId == cat.id,
                          onSelected: () => listNotifier.selectCategory(cat.id),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      context,
                      label: 'Uncategorized',
                      selected: listState.showUncategorizedOnly,
                      onSelected: () => listNotifier.selectCategory(null, uncategorizedOnly: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Song List
              Expanded(
                child: listState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : listState.songs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.library_books_outlined,
                                    size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'No songs found.',
                                  style: TextStyle(
                                      fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
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
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: listState.songs.length,
                            itemBuilder: (context, index) {
                              final song = listState.songs[index];
                              final isSelected = song.id == selectedSongId;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                child: Material(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [
                                                  Theme.of(context).colorScheme.primary,
                                                  Theme.of(context).colorScheme.secondary,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: isSelected
                                            ? null
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          song.songNum.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.onPrimary
                                                : Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      song.title,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        song.author ?? 'Unknown Author',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                              : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    trailing: song.key != null
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                                  : Theme.of(context).colorScheme.secondaryContainer,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                                                    : Colors.transparent,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              song.key!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                          )
                                        : null,
                                    selected: isSelected,
                                    onTap: () {
                                      ref.read(selectedSongIdProvider.notifier).state = song.id;
                                      if (!isLargeScreen) {
                                        _showSongOptionsBottomSheet(context, ref, song);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        // Right Column: Song Preview Panel (Desktop only)
        if (isLargeScreen) ...[
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 4,
            child: selectedSong != null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${selectedSong.songNum}. ${selectedSong.title}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit Song',
                              onPressed: () => context
                                  .push('/song-editor?id=${selectedSong.id}'),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Song',
                              onPressed: () => _confirmDelete(
                                  context, ref, selectedSong.id, selectedSong.title),
                            ),
                          ],
                        ),
                        if (selectedSong.author != null ||
                            selectedSong.key != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            children: [
                              if (selectedSong.author != null)
                                Chip(
                                  avatar: const Icon(Icons.person, size: 16),
                                  label: Text(selectedSong.author!),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                              if (selectedSong.key != null)
                                Chip(
                                  avatar: const Icon(Icons.music_note, size: 16),
                                  label: Text('Key: ${selectedSong.key!}'),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(projectionControllerProvider.notifier)
                                .setSong(selectedSong);
                            ref.read(activeDashboardTabProvider.notifier).state =
                                1; // Go to Projection tab
                          },
                          icon: const Icon(Icons.tv),
                          label: const Text('Send to Projector'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer
                                .withValues(alpha: 0.3),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                                    Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.2),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.menu_book, size: 20, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          'LYRICS PREVIEW',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        selectedSong.body,
                                        style: GoogleFonts.lora(
                                          fontSize: 17,
                                          height: 1.6,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a song to preview',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  void _showSongOptionsBottomSheet(BuildContext context, WidgetRef ref, Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${song.songNum}. ${song.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(song.author ?? 'Unknown Author'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tv),
                title: const Text('Send to Projector'),
                onTap: () {
                  ref.read(projectionControllerProvider.notifier).setSong(song);
                  ref.read(activeDashboardTabProvider.notifier).state = 1;
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Song'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/song-editor?id=${song.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Song', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, song.id, song.title);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, int songId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(songRepositoryProvider).deleteSong(songId);
              ref.read(selectedSongIdProvider.notifier).state = null;
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, Category cat) async {
    final songCount = await ref.read(songRepositoryProvider).getSongCountByCategory(cat.id);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "$cat.name" and all $songCount song(s) in it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(songListControllerProvider.notifier).deleteCategory(cat.id);
              ref.read(selectedSongIdProvider.notifier).state = null;
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ================= PROJECTION TAB =================

class _ProjectionTab extends ConsumerWidget {
  final bool isLargeScreen;

  const _ProjectionTab({required this.isLargeScreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projection Controls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open Projector Output Window',
            onPressed: () async {
              if (kIsWeb) {
                context.push('/projection');
              } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                final window = await WindowController.create(
                  const WindowConfiguration(
                    arguments: 'Projection Output',
                  ),
                );
                await window.show();
                // Give the sub-window engine a moment to spin up and bind IPC handlers, then push the current slide state
                Future.delayed(const Duration(milliseconds: 600), () {
                  ref.read(projectionControllerProvider.notifier).syncCurrentSlide();
                });
              } else {
                // On mobile
                context.push('/projection');
              }
            },
          ),
        ],
      ),
      body: state.currentSong == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No song loaded on the projector.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(activeDashboardTabProvider.notifier).state = 0;
                    },
                    child: const Text('Go Browse Songs'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loaded Song details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.currentSong!.title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Song ${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: notifier.clearSong,
                        icon: const Icon(Icons.close),
                        label: const Text('Clear Screen'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[900],
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Operator panel
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slide List
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            itemCount: state.slides.length,
                            itemBuilder: (context, index) {
                              final slide = state.slides[index];
                              final isSelected = index == state.currentSlideIndex;

                              return Card(
                                elevation: isSelected ? 3 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                                    : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        slide.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    slide.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                  onTap: () => notifier.selectSlide(index),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Control Panel & Preview
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'LIVE PREVIEW',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              // Live Preview Card (looks like projection screen)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Container(
                                          color: Colors.black,
                                          padding: const EdgeInsets.all(24.0),
                                          child: Center(
                                            child: Text(
                                              state.currentSlide?.text ?? '',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                                shadows: const [
                                                  Shadow(
                                                    offset: Offset(1.0, 1.0),
                                                    blurRadius: 3.0,
                                                    color: Color.fromARGB(150, 0, 0, 0),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Navigation buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: notifier.prevSlide,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Previous (←)'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: notifier.nextSlide,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Next (→)'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Live settings quick controls
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: [
                                      // Font Size
                                      Row(
                                        children: [
                                          const Icon(Icons.format_size, size: 20),
                                          const SizedBox(width: 8),
                                          const Text('Font Size'),
                                          Expanded(
                                            child: Slider(
                                              min: 24,
                                              max: 80,
                                              value: state.fontSize,
                                              onChanged: notifier.setFontSize,
                                            ),
                                          ),
                                          Text('${state.fontSize.round()} px'),
                                        ],
                                      ),
                                      // Auto chorus insertion
                                      SwitchListTile(
                                        title: const Text('Auto-insert Chorus'),
                                        subtitle: const Text('Show chorus between verses'),
                                        value: state.autoInsertChorus,
                                        onChanged: notifier.setAutoInsertChorus,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ================= SETTINGS TAB =================

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
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
        type: FileType.any, // Use any because some OS have trouble registering .mdb
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

      // Find compatible importer
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
        ref.read(songListControllerProvider.notifier).fetchSongs(); // Re-trigger load
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
        ref.read(songListControllerProvider.notifier).fetchSongs(); // Re-trigger load
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

      // Append extension if missing
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
    final projectionState = ref.watch(projectionControllerProvider);
    final projectionNotifier = ref.read(projectionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Application Settings')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Importer Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.import_export, size: 28),
                          SizedBox(width: 12),
                          Text('Database Import & Export',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Visual Song Book can import legacy VSB or Microsoft Access MDB files directly, as well as restore portable .vsbook backups.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (_isImporting) ...[
                        Row(
                          children: [
                            const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text(_importStatus ?? 'Processing...'),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isImporting ? null : _importMdb,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Import VSB / MDB File'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isImporting ? null : _importVsBook,
                            icon: const Icon(Icons.settings_backup_restore),
                            label: const Text('Restore .vsbook Backup'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isExporting || _isImporting
                                ? null
                                : _exportVsBook,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Export .vsbook Backup'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Manage Archives
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 28),
                          SizedBox(width: 12),
                          Text('Manage Archives',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Delete exported .vsbook backups or imported .vsb/.mdb source files from disk. Songs already in the database are not affected.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isDeletingArchives ? null : _deleteArchives,
                        icon: _isDeletingArchives
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.delete_outline),
                        label: Text(_isDeletingArchives
                            ? 'Selecting files...'
                            : 'Delete Archive Files'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Screen settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.video_settings, size: 28),
                          SizedBox(width: 12),
                          Text('Screen Preferences',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Prevent Screen Sleep (Wakelock)'),
                        subtitle: const Text(
                            'Keeps the screen awake during projection operator view'),
                        value: projectionState.keepAwake,
                        onChanged: projectionNotifier.setKeepAwake,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Help and info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, size: 28),
                          SizedBox(width: 12),
                          Text('About & Diagnostics',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This application treats SQLite (via Drift) as its source of truth. When importing legacy MDB songbooks, it converts and structures them into the SQLite database. Backups (.vsbook) are platform-independent ZIP files containing the SQLite database and metadata.',
                      ),
                      const SizedBox(height: 16),
                      Text('System Platform: ${kIsWeb ? "Web Browser" : Platform.operatingSystem.toUpperCase()}'),
                      const SizedBox(height: 8),
                      const Text('MDB CLI Helper: mdb-tools (detected)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
