import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/features/projection/projection_tab.dart';
import 'package:visual_song_book/features/settings/settings_tab.dart';
import 'package:visual_song_book/features/song_list/songs_tab.dart';

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
        return SongsTab(isLargeScreen: isLargeScreen);
      case 1:
        return ProjectionTab(isLargeScreen: isLargeScreen);
      case 2:
        return const SettingsTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }
}
