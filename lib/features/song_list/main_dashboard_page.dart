import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/history/history_tab.dart';
import 'package:visual_song_book/features/projection/projection_tab.dart';
import 'package:visual_song_book/features/settings/settings_tab.dart';
import 'package:visual_song_book/features/song_list/songs_tab.dart';

final activeDashboardTabProvider = StateProvider<int>((ref) => 0);
final selectedSongIdProvider = StateProvider<int?>((ref) => null);
final isSidebarExpandedProvider = StateProvider<bool>((ref) => true);

class MainDashboardPage extends ConsumerWidget {
  const MainDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeDashboardTabProvider);
    final isExpanded = ref.watch(isSidebarExpandedProvider);
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: !isLargeScreen
          ? AppBar(
              title: Row(
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF00BFA5), // Teal primary
                            Color(0xFF00796B), // Teal secondary
                          ],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Song Book',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: const [
                _AddMenuButton(),
                SizedBox(width: 8),
              ],
            )
          : null,
      body: Row(
        children: [
          if (isLargeScreen) ...[
            NavigationRail(
              extended: isExpanded,
              selectedIndex: activeTab,
              labelType: isExpanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isExpanded) const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(isExpanded ? Icons.menu_open : Icons.menu),
                          onPressed: () {
                            ref.read(isSidebarExpandedProvider.notifier).state = !isExpanded;
                          },
                        ),
                        if (isExpanded) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Visual Book',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _AddMenuButton(isExpanded: isExpanded),
                  ],
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
                  icon: Icon(Icons.playlist_add_check_outlined),
                  selectedIcon: Icon(Icons.playlist_add_check),
                  label: Text('Sets'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('Bible'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('History'),
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
              selectedIndex: [0, 3, 4, 5].contains(activeTab) 
                  ? [0, 3, 4, 5].indexOf(activeTab) 
                  : 0,
              onDestinationSelected: (index) {
                final mappedIndices = [0, 3, 4, 5];
                ref.read(activeDashboardTabProvider.notifier).state = mappedIndices[index];
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                  label: 'Songs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History',
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
        return SongsTab(isLargeScreen: isLargeScreen);
      case 1:
        return _buildPlaceholderTab('Sets & Service Planning');
      case 2:
        return _buildPlaceholderTab('Bible & Scriptures');
      case 3:
        return const HistoryTab();
      case 4:
        return ProjectionTab(isLargeScreen: isLargeScreen);
      case 5:
        return const SettingsTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This feature is coming soon in a future update!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _AddMenuButton extends ConsumerWidget {
  final bool isExpanded;
  const _AddMenuButton({this.isExpanded = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return isExpanded
            ? FilledButton.icon(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add New'),
              )
            : IconButton.filledTonal(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.add),
                tooltip: 'Add New',
              );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.music_note_outlined),
          onPressed: () => context.push('/song-editor'),
          child: const Text('Add New Song'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.library_books_outlined),
          onPressed: () => _showAddCollectionDialog(context, ref),
          child: const Text('Create New Collection'),
        ),
      ],
    );
  }

  void _showAddCollectionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g., Youth Hymnal',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                final repo = ref.read(songRepositoryProvider);
                await repo.addCategory(CategoriesCompanion.insert(
                  id: drift.Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
                  name: name,
                ));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
