
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/history/history_controller.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_sets_drawer.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart' show setsControllerProvider;

/// Provider for the active history tab in projection view
final _projectionHistoryTabProvider =
    StateProvider<HistoryTabType>((ref) => HistoryTabType.songs);

/// Recently projected items in the projection tab's empty state: Songs, Bible,
/// Sets and Bookmarks, each tab carrying its own accent colour.
///
/// [narrow] switches between the desktop rail (fixed 280px column) and the
/// narrow-screen layout that fills the window.
class ProjectionHistoryPanel extends ConsumerWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;
  final bool narrow;

  const ProjectionHistoryPanel({
    super.key,
    required this.notifier,
    required this.returnFocusTo,
    required this.narrow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyControllerProvider);
    final selectedTab = ref.watch(_projectionHistoryTabProvider);
    final setsState = ref.watch(setsControllerProvider);

    final content = Column(
      children: [
        _buildTabsBar(context, ref, selectedTab),
        const Divider(height: 1),
        Expanded(
          child: _buildContent(context, ref, historyState, selectedTab, setsState),
        ),
        if (setsState.selectedSetId != null && setsState.setItems.isNotEmpty)
          ProjectionSetsButton(setsState: setsState),
      ],
    );

    if (narrow) return content;
    return SizedBox(width: 280, child: content);
  }

  // One accent hue per tab: Songs = primary, Bible = tertiary, Sets =
  // secondary. The search toggle already uses primary/tertiary for
  // songs/bible, so the colour language stays consistent across the page.
  Widget _buildTabsBar(BuildContext context, WidgetRef ref, HistoryTabType selectedTab) {
    final theme = Theme.of(context);
    final songAccent = theme.colorScheme.primary;
    final bibleAccent = theme.colorScheme.tertiary;
    final setAccent = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          HistoryTabButton(
            label: 'Songs',
            icon: Icons.music_note,
            isSelected: selectedTab == HistoryTabType.songs,
            onTap: () => ref.read(_projectionHistoryTabProvider.notifier).state = HistoryTabType.songs,
            count: ref.watch(historyControllerProvider.select((s) => s.songs.length)),
            accentColor: songAccent,
          ),
          HistoryTabButton(
            label: 'Bible',
            icon: Icons.menu_book,
            isSelected: selectedTab == HistoryTabType.bible,
            onTap: () => ref.read(_projectionHistoryTabProvider.notifier).state = HistoryTabType.bible,
            count: ref.watch(historyControllerProvider.select((s) => s.bible.length)),
            accentColor: bibleAccent,
          ),
          HistoryTabButton(
            label: 'Sets',
            icon: Icons.playlist_play,
            isSelected: selectedTab == HistoryTabType.sets,
            onTap: () => ref.read(_projectionHistoryTabProvider.notifier).state = HistoryTabType.sets,
            count: ref.watch(historyControllerProvider.select((s) => s.sets.length)),
            accentColor: setAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HistoryState historyState,
    HistoryTabType tab,
    SetsState setsState,
  ) {
    final theme = Theme.of(context);

    switch (tab) {
      case HistoryTabType.songs:
        return historyState.songs.isEmpty
            ? _emptyState(context, 'song', Icons.library_music_outlined)
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: historyState.songs.length,
                itemBuilder: (context, index) {
                  final song = historyState.songs[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.music_note, size: 18, color: theme.colorScheme.primary),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: song.songNum > 0
                        ? Text('#${song.songNum}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant))
                        : null,
                    onTap: () {
                      // setSong triggers auto-projection, which swaps this
                      // empty view for the active projection controls.
                      notifier.setSong(song);
                    },
                  );
                },
              );
      case HistoryTabType.bible:
        return historyState.bible.isEmpty
            ? _emptyState(context, 'bible', Icons.menu_book_outlined)
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: historyState.bible.length,
                itemBuilder: (context, index) {
                  final item = historyState.bible[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.menu_book, size: 18, color: theme.colorScheme.tertiary),
                    title: Text(
                      item.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      item.passage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onTap: () async {
                      final repo = ref.read(bibleRepositoryProvider);
                      final bibleNav = ref.read(bibleControllerProvider.notifier);
                      final colonIdx = item.reference.lastIndexOf(':');
                      String bookChapter;
                      int? verseNum;
                      if (colonIdx > 0) {
                        bookChapter = item.reference.substring(0, colonIdx);
                        verseNum = int.tryParse(item.reference.substring(colonIdx + 1));
                      } else {
                        bookChapter = item.reference;
                      }
                      final spaceIdx = bookChapter.lastIndexOf(' ');
                      if (spaceIdx > 0) {
                        final bookName = bookChapter.substring(0, spaceIdx);
                        final chapterNum = int.tryParse(bookChapter.substring(spaceIdx + 1));
                        if (chapterNum != null) {
                          final book = await repo.getBookByName(bookName);
                          if (book != null) {
                            if (verseNum != null) {
                              await bibleNav.navigateToVerse(book.id, chapterNum, verseNum);
                            } else {
                              await bibleNav.selectBook(book.id);
                              await bibleNav.selectChapter(chapterNum);
                            }
                            // Project the verse (auto-projection triggered
                            // inside projectVerse).
                            notifier.projectVerse(
                              book.id, chapterNum, verseNum ?? 1, bookName,
                            );
                          }
                        }
                      }
                    },
                  );
                },
              );
      case HistoryTabType.sets:
        return historyState.sets.isEmpty
            ? _emptyState(context, 'set', Icons.queue_music_outlined)
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: historyState.sets.length,
                itemBuilder: (context, index) {
                  final item = historyState.sets[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.playlist_play, size: 18, color: theme.colorScheme.primary),
                    title: Text(
                      item.setName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(_formatDate(item.accessedAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    onTap: () {
                      // Selecting keeps the set navigator in sync, and
                      // projectSongSet triggers auto-projection.
                      ref.read(setsControllerProvider.notifier).selectSet(item.setId);
                      final setObj = setsState.sets
                          .where((s) => s.id == item.setId)
                          .firstOrNull;
                      final items = setsState.setItems;
                      if (setObj == null || items.isEmpty) return;
                      notifier.projectSongSet(
                        setObj.id,
                        setObj.name,
                        items,
                      );
                    },
                  );
                },
              );
      case HistoryTabType.bookmarks:
        return historyState.bookmarks.isEmpty
            ? _emptyState(context, 'bookmark', Icons.bookmark_outline)
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: historyState.bookmarks.length,
                itemBuilder: (context, index) {
                  final item = historyState.bookmarks[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.bookmark, size: 18, color: theme.colorScheme.primary),
                    title: Text(item.reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(item.verseText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    onTap: () async {
                      final repo = ref.read(bibleRepositoryProvider);
                      final bibleNav = ref.read(bibleControllerProvider.notifier);
                      final book = await repo.getBookByName(item.bookName);
                      if (book != null) {
                        await bibleNav.navigateToVerse(book.id, item.chapter, item.verseNum);
                        notifier.projectVerse(
                          book.id, item.chapter, item.verseNum, item.bookName,
                        );
                      }
                    },
                  );
                },
              );
    }
  }

  Widget _emptyState(BuildContext context, String type, IconData icon) {
    final theme = Theme.of(context);
    final label = type == 'set'
        ? 'Sets'
        : type == 'bible'
        ? 'Bible passages'
        : type == 'bookmark'
        ? 'Bookmarks'
        : 'Songs';
    final message = type == 'bookmark'
        ? 'No bookmarks saved yet.'
        : 'No $label projected yet.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Accent-coloured pill for one of the history tabs (Songs / Bible / Sets).
class HistoryTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int count;

  /// Accent colour for this tab. The three history tabs each get their own hue
  /// so they read apart at a glance — a soft tint when idle and a saturated
  /// one when selected.
  final Color accentColor;

  const HistoryTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.count,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isSelected ? 0.20 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentColor.withValues(alpha: isSelected ? 0.55 : 0.14),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            // Transparent so the container's accent tint shows through.
            backgroundColor: Colors.transparent,
            foregroundColor: accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          // mainAxisSize.min keeps the row from demanding its full constraint,
          // and the Flexible label ellipsizes instead of overflowing when the
          // three history tabs are squeezed into a narrow viewport.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isSelected ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
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
