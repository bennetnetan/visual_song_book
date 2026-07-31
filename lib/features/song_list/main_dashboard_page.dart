import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_tab.dart';
import 'package:visual_song_book/features/history/history_tab.dart';
import 'package:visual_song_book/features/projection/projection_tab.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart';
import 'package:visual_song_book/features/settings/settings_tab.dart';
import 'package:visual_song_book/features/song_list/songs_tab.dart';

final selectedSongIdProvider = StateProvider<int?>((ref) => null);
final isSidebarExpandedProvider = StateProvider<bool>((ref) => false);

class MainDashboardPage extends ConsumerWidget {
  const MainDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeDashboardTabProvider);
    final isExpanded = ref.watch(isSidebarExpandedProvider);
    final layoutMode = getLayoutMode(context);
    final isLargeScreen = layoutMode == LayoutMode.desktop;
    final isMobilePlat = isMobilePlatformCheck();
    final hideProjection = isMobilePlat || !isLargeScreen;

    int getSelectedIndex(int tabIdx) {
      if (!hideProjection) return tabIdx;
      if (tabIdx <= 3) return tabIdx;
      if (tabIdx == 5) return 4;
      return 0;
    }

    int getActualTabIndex(int selectedIdx) {
      if (!hideProjection) return selectedIdx;
      if (selectedIdx <= 3) return selectedIdx;
      if (selectedIdx == 4) return 5;
      return 0;
    }

    if (hideProjection && activeTab == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeDashboardTabProvider.notifier).state = 0;
      });
    }

    final tabTitles = [
      'Song Book',
      'Sets',
      'Bible',
      'Recent Activity',
      'Projection',
      'Settings',
    ];
    final currentTitle = tabTitles[activeTab];

    return Scaffold(
      appBar: !isLargeScreen && activeTab != 0 && activeTab != 2
          ? AppBar(
              centerTitle: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'app_logo',
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
                  Text(
                    currentTitle,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (isLargeScreen) ...[
            NavigationRail(
              extended: isExpanded,
              selectedIndex: getSelectedIndex(activeTab),
              labelType: isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isExpanded) const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(isExpanded ? Icons.menu_open : Icons.menu),
                            onPressed: () {
                              ref.read(isSidebarExpandedProvider.notifier).state =
                                  !isExpanded;
                            },
                          ),
                          if (isExpanded) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Visual Book',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      AddMenuButton(isExpanded: isExpanded),
                    ],
                  ),
                ),
              ),
              onDestinationSelected: (index) {
                ref.read(activeDashboardTabProvider.notifier).state = getActualTabIndex(index);
              },
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                  label: Text('Songs'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.playlist_add_check_outlined),
                  selectedIcon: Icon(Icons.playlist_add_check),
                  label: Text('Sets'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('Bible'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('History'),
                ),
                if (!hideProjection)
                  const NavigationRailDestination(
                    icon: Icon(Icons.tv_outlined),
                    selectedIcon: Icon(Icons.tv),
                    label: Text('Projection'),
                  ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(child: _buildTabContent(activeTab, isLargeScreen)),
        ],
      ),
      bottomNavigationBar: !isLargeScreen
          ? NavigationBar(
              selectedIndex: getSelectedIndex(activeTab),
              onDestinationSelected: (index) {
                ref.read(activeDashboardTabProvider.notifier).state = getActualTabIndex(index);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note),
                  label: 'Songs',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.playlist_add_check_outlined),
                  selectedIcon: Icon(Icons.playlist_add_check),
                  label: 'Sets',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Bible',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History',
                ),
                if (!hideProjection)
                  const NavigationDestination(
                    icon: Icon(Icons.tv_outlined),
                    selectedIcon: Icon(Icons.tv),
                    label: 'Projection',
                  ),
                const NavigationDestination(
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
        return SetsTab(isLargeScreen: isLargeScreen);
      case 2:
        return BibleTab(isLargeScreen: isLargeScreen);
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
}

class AddMenuButton extends ConsumerWidget {
  final bool isExpanded;
  const AddMenuButton({this.isExpanded = true});

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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                final repo = ref.read(songRepositoryProvider);
                await repo.addCategory(
                  CategoriesCompanion.insert(
                    id: drift.Value(
                      DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    ),
                    name: name,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
