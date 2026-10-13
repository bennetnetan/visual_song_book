import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';


import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/history/history_controller.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/lower_third/widgets/lower_third_overlay.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_search_provider.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/services/share_service.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';
import 'package:visual_song_book/features/sets/sets_tab.dart' show setsControllerProvider;
import 'package:visual_song_book/features/song_list/song_list_controller.dart';

/// Persists the set-navigator collapsed/expanded state across widget-tree rebuilds
/// (the panel moves between large-screen Row and small-screen Column, which would
/// otherwise reset local widget state and reopen the panel on every rebuild).
final _setNavigatorExpandedProvider = StateProvider<bool>((ref) => false);

// Provider for the active history tab in projection view
final _projectionHistoryTabProvider = StateProvider<HistoryTabType>((ref) => HistoryTabType.songs);

// Provider for the sets drawer visibility
final _setsDrawerOpenProvider = StateProvider<bool>((ref) => false);


class ProjectionTab extends ConsumerStatefulWidget {
  final bool isLargeScreen;

  const ProjectionTab({super.key, required this.isLargeScreen});

  @override
  ConsumerState<ProjectionTab> createState() => _ProjectionTabState();
}

class _ProjectionTabState extends ConsumerState<ProjectionTab> {
  late final FocusNode _projectionFocus;

  @override
  void initState() {
    super.initState();
    _projectionFocus = FocusNode(debugLabel: 'ProjectionControlsFocus');
  }

  @override
  void dispose() {
    _projectionFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleProjectionKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final notifier = ref.read(projectionControllerProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        notifier.nextSlide();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.pageUp:
        notifier.prevSlide();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        notifier.clearSong();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

@override
  Widget build(BuildContext context) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Scaffold(
        appBar: AppBar(
            title: const Text('Projection Controls'),
            actions: [
              if (widget.isLargeScreen)
                Consumer(
                  builder: (context, ref, _) {
                    final ltState = ref.watch(lowerThirdControllerProvider);
                    final ltNotifier =
                        ref.read(lowerThirdControllerProvider.notifier);
                    return IconButton(
                      icon: Icon(
                        ltState.isEnabled
                            ? Icons.view_headline
                            : Icons.view_headline_outlined,
                        color: ltState.isEnabled
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: ltState.isEnabled
                          ? 'Lower Thirds Carousel: Active (tap to turn off)'
                          : 'Lower Thirds Carousel: Off (tap to turn on)',
                      onPressed: ltNotifier.toggleEnabled,
                    );
                  },
                ),
              Semantics(
                label: 'Open Projector Output Window',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open Projector Output Window',
                  onPressed: () async {
                    if (kIsWeb) {
                      context.push('/projection');
                    } else if (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS) {
                      await ref.read(projectionControllerProvider.notifier).openProjectorWindow();
                    } else {
                      context.push('/projection');
                    }
                  },
                ),
              ),
              // Search moves to the app bar once something is on screen: the
              // empty window already embeds the field, and mid-projection the
              // controls need the vertical space the old top bar used to take.
              Semantics(
                label: 'Search songs and Bible',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search songs and Bible',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) => _FullScreenSearchPage(
                        notifier: ref.read(projectionControllerProvider.notifier),
                        returnFocusTo: _projectionFocus,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Focus(
            focusNode: _projectionFocus,
            autofocus: true,
            onKeyEvent: _handleProjectionKeys,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _projectionFocus.requestFocus(),
              child: !state.hasContent
              ? _EmptyProjectionState(
                  notifier: notifier,
                  returnFocusTo: _projectionFocus,
                  isLargeScreen: widget.isLargeScreen,
                )
              // A Column provides the Flex ancestor the Expanded below needs
              // (a GestureDetector will not do).
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            _ProjectionHeader(state: state, notifier: notifier),
                            const Divider(height: 32),
                            // Main body: slide list + live preview
                            Expanded(
                              child: widget.isLargeScreen
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left column: slide list + set navigator
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: _SlideList(
                                                  state: state,
                                                  notifier: notifier,
                                                ),
                                              ),
                                              _SetNavigatorPanel(
                                                state: state,
                                                notifier: notifier,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 3,
                                          child: _LivePreviewPanel(
                                            state: state,
                                            notifier: notifier,
                                            projectionFocus: _projectionFocus,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _LivePreviewPanel(
                                          state: state,
                                          notifier: notifier,
                                          projectionFocus: _projectionFocus,
                                        ),
                                        const SizedBox(height: 12),
                                        _SetNavigatorPanel(
                                          state: state,
                                          notifier: notifier,
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: _SlideList(
                                            state: state,
                                            notifier: notifier,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — guides user to Songs or Bible
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyProjectionState extends ConsumerWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;
  final bool isLargeScreen;

  const _EmptyProjectionState({
    required this.notifier,
    required this.returnFocusTo,
    this.isLargeScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyControllerProvider);
    final selectedHistoryTab = ref.watch(_projectionHistoryTabProvider);

    // NOTE: `returnFocusTo` is owned by the parent ProjectionTab's Focus
    // widget, so it must NOT be attached another Focus here (that throws
    // "Tried to make a child into a parent of itself"). We only borrow it to
    // hand focus back on background taps.
    //
    // The search lives in the body of the window, already focused, instead of
    // in a bar across the top that only opened a popup.
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: returnFocusTo.requestFocus,
        child: isLargeScreen
            ? Row(
                children: [
                  // Recently projected history stays in its own rail.
                  _buildHistorySidebar(
                      context, ref, historyState, selectedHistoryTab),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _InlineProjectionSearch(notifier: notifier),
                  ),
                ],
              )
            // Narrow screens: results replace the history the moment there is
            // a query, and the history returns once the search is cleared.
            : _InlineProjectionSearch(
                notifier: notifier,
                idleContent: _buildNarrowHistory(context, ref),
              ),
      ),
    );
  }

  /// Body shown beside the inline search on wide screens: recently projected
  /// history in a rail on the left. On narrow screens the inline search takes
  /// over the whole window while a query is active, and the history tabs return
  /// once the query is cleared.
  Widget _buildNarrowHistory(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyControllerProvider);
    final selectedHistoryTab = ref.watch(_projectionHistoryTabProvider);
    final setsState = ref.watch(setsControllerProvider);

    return Column(
      children: [
        _buildHistoryTabsBar(context, ref, selectedHistoryTab),
        const Divider(height: 1),
        Expanded(
          child: _buildHistoryContent(context, ref, historyState, selectedHistoryTab),
        ),
        if (setsState.selectedSetId != null && setsState.setItems.isNotEmpty)
          _buildSetsButton(context, ref, setsState),
      ],
    );
  }

  Widget _buildHistorySidebar(BuildContext context, WidgetRef ref, HistoryState historyState, HistoryTabType selectedTab) {
    final setsState = ref.watch(setsControllerProvider);
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          // History tabs
          _buildHistoryTabsBar(context, ref, selectedTab),
          const Divider(height: 1),
          // History content
          Expanded(
            child: _buildHistoryContent(context, ref, historyState, selectedTab),
          ),
          // Sets button at bottom of sidebar
          if (setsState.selectedSetId != null && setsState.setItems.isNotEmpty)
            _buildSetsButton(context, ref, setsState),
        ],
      ),
    );
  }

  Widget _buildHistoryTabsBar(BuildContext context, WidgetRef ref, HistoryTabType selectedTab) {
    final theme = Theme.of(context);
    // One accent hue per tab: Songs = primary, Bible = tertiary, Sets =
    // secondary. The existing search toggle already uses primary/tertiary for
    // songs/bible, so the colour language stays consistent across the page.
    final songAccent = theme.colorScheme.primary;
    final bibleAccent = theme.colorScheme.tertiary;
    final setAccent = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _HistoryTabButton(
            label: 'Songs',
            icon: Icons.music_note,
            isSelected: selectedTab == HistoryTabType.songs,
            onTap: () => ref.read(_projectionHistoryTabProvider.notifier).state = HistoryTabType.songs,
            count: ref.watch(historyControllerProvider.select((s) => s.songs.length)),
            accentColor: songAccent,
          ),
          _HistoryTabButton(
            label: 'Bible',
            icon: Icons.menu_book,
            isSelected: selectedTab == HistoryTabType.bible,
            onTap: () => ref.read(_projectionHistoryTabProvider.notifier).state = HistoryTabType.bible,
            count: ref.watch(historyControllerProvider.select((s) => s.bible.length)),
            accentColor: bibleAccent,
          ),
          if (isLargeScreen)
            _HistoryTabButton(
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

  Widget _buildHistoryContent(BuildContext context, WidgetRef ref, HistoryState historyState, HistoryTabType tab) {
    final theme = Theme.of(context);
    // Cached set state so the Sets history tab can project without a pop —
    // this list is inline in the dashboard, not a modal route.
    final setsState = ref.watch(setsControllerProvider);

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
                      ref.read(projectionControllerProvider.notifier).setSong(song);
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
                      final notifier = ref.read(bibleControllerProvider.notifier);
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
                              await notifier.navigateToVerse(book.id, chapterNum, verseNum);
                            } else {
                              await notifier.selectBook(book.id);
                              await notifier.selectChapter(chapterNum);
                            }
                            // Project the verse (auto-projection triggered inside projectVerse)
                            ref.read(projectionControllerProvider.notifier).projectVerse(
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
                      final setObj = historyState.sets.isEmpty
                          ? null
                          : setsState.sets
                              .where((s) => s.id == item.setId)
                              .firstOrNull;
                      final items = setsState.setItems;
                      if (setObj == null || items.isEmpty) return;
                      ref.read(projectionControllerProvider.notifier).projectSongSet(
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
                      final notifier = ref.read(bibleControllerProvider.notifier);
                      final book = await repo.getBookByName(item.bookName);
                      if (book != null) {
                        await notifier.navigateToVerse(book.id, item.chapter, item.verseNum);
                        ref.read(projectionControllerProvider.notifier).projectVerse(
                          book.id, item.chapter, item.verseNum, item.bookName,
                        );
                      }
                    },
                  );
                },
              );
    }
  }

  Widget _buildSetsButton(BuildContext context, WidgetRef ref, SetsState setsState) {
    final theme = Theme.of(context);
    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;
    if (setObj == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.playlist_play, size: 18),
          label: Text('SET: ${setObj.name} (${setsState.setItems.length} songs)'),
          onPressed: () => _showSetsDrawer(context, ref, setsState),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: theme.colorScheme.primary),
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  void _showSetsDrawer(BuildContext context, WidgetRef ref, SetsState setsState) {
    ref.read(_setsDrawerOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.playlist_play, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      setsState.sets
                          .where((s) => s.id == setsState.selectedSetId)
                          .firstOrNull
                          ?.name ?? 'Set',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${setsState.setItems.length} songs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: setsState.setItems.length,
                  itemBuilder: (context, i) {
                    final item = setsState.setItems[i];
                    final song = setsState.availableSongs
                        .where((s) => s.id == item.songId)
                        .firstOrNull;
                    if (song == null) return const SizedBox.shrink();

                    final projectionState = ref.read(projectionControllerProvider);
                    final isCurrentSong = projectionState.currentSong?.id == song.id;
                    final keyText = item.key ?? song.key;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrentSong
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrentSong
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentSong ? Theme.of(context).colorScheme.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.notes != null && item.notes!.isNotEmpty
                          ? Text(
                              '📝 ${item.notes!}',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: keyText != null && keyText.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                keyText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(projectionControllerProvider.notifier).setSong(song);
                        // Auto-projection triggered inside setSong
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => ref.read(_setsDrawerOpenProvider.notifier).state = false);
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

class _HistoryTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int count;

  /// Accent colour for this tab. The three history tabs (Songs / Bible / Sets)
  /// each get their own hue so they read apart at a glance on the projection
  /// controls — a soft tint when idle and a saturated one when selected.
  final Color accentColor;

  const _HistoryTabButton({
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                color: isSelected
                    ? accentColor
                    : theme.colorScheme.onSurfaceVariant,
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
                    color: isSelected
                        ? accentColor
                        : theme.colorScheme.onSurfaceVariant,
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
                    color: isSelected
                        ? accentColor
                        : theme.colorScheme.onSurfaceVariant,
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

// ─────────────────────────────────────────────────────────────────────────────
// Header row — title, mode badge, clear button
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectionHeader extends StatelessWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _ProjectionHeader({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBible = state.isBibleMode;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isBible
                ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBible ? Icons.menu_book : Icons.music_note,
                size: 14,
                color: isBible
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                isBible ? 'Bible' : 'Song',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isBible
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.contentTitle ??
                    state.currentSong?.title ??
                    (state.slides.isNotEmpty ? state.slides.first.label : 'Untitled'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isBible && state.currentSong != null)
                Text(
                  'Song #${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              if (isBible)
                Text(
                  'Chapter ${state.bibleChapter ?? '?'} — ${state.slides.length} verse${state.slides.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
            ],
          ),
        ),
        if (!isBible && state.currentSong != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AutoChorusToggle(
              value: state.autoInsertChorus,
              onChanged: notifier.setAutoInsertChorus,
            ),
          ),
        if (state.hasContent)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, size: 18),
              tooltip: 'Share',
              onPressed: notifier.shareCurrentSlide,
            ),
          ),
        if (isLargeScreen)
          Consumer(
            builder: (context, ref, _) {
              final ltState = ref.watch(lowerThirdControllerProvider);
              final ltNotifier =
                  ref.read(lowerThirdControllerProvider.notifier);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.view_headline,
                    size: 16,
                    color: ltState.isEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    ltState.isEnabled ? 'Lower Third: ON' : 'Lower Third: OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: ltState.isEnabled ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: ltState.isEnabled,
                  onSelected: (_) => ltNotifier.toggleEnabled(),
                ),
              );
            },
          ),
        ElevatedButton.icon(
          onPressed: notifier.clearSong,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Clear Screen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-chorus toggle chip — shown inline next to Clear Screen for songs
// ─────────────────────────────────────────────────────────────────────────────

class _AutoChorusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutoChorusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Auto-insert chorus between verses',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.repeat : Icons.repeat_one,
                size: 14,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Chorus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide list — works for both songs and Bible passages
// ─────────────────────────────────────────────────────────────────────────────

class _SlideList extends StatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _SlideList({required this.state, required this.notifier});

  @override
  State<_SlideList> createState() => _SlideListState();
}

class _SlideListState extends State<_SlideList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToCurrent();
  }

  @override
  void didUpdateWidget(covariant _SlideList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.currentSlideIndex != oldWidget.state.currentSlideIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final idx = widget.state.currentSlideIndex;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const itemHeight = 68.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (idx * itemHeight) - (viewportHeight * 0.3);
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.state.slides.length,
      itemBuilder: (context, index) {
        final slide = widget.state.slides[index];
        final isSelected = index == widget.state.currentSlideIndex;
        final prevSlide = index > 0 ? widget.state.slides[index - 1] : null;
        final isNewSong = slide.songTitle != null &&
            (prevSlide == null || prevSlide.songTitle != slide.songTitle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNewSong)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          slide.songNum != null && slide.songNum! > 0
                              ? '${slide.songTitle} (#${slide.songNum})'
                              : (slide.songTitle ?? ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: ListTile(
                tileColor: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: _SlideLabelBadge(
                  label: slide.label,
                  isSelected: isSelected,
                  isBible: widget.state.isBibleMode,
                ),
                title: Text(
                  slide.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                onTap: () => widget.notifier.selectSlide(index),
              ),
            ),
          ],
        );
      },
    );
    }
  }

/// Badge showing the slide label. Bible mode: pill for long references.
/// Song mode: square chip for V1, C, etc.
class _SlideLabelBadge extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isBible;

  const _SlideLabelBadge({
    required this.label,
    required this.isSelected,
    required this.isBible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    if (isBible) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview panel — preview canvas + navigation + settings
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreviewPanel extends ConsumerWidget {
  final ProjectionState state;
  final ProjectionController notifier;
  final FocusNode projectionFocus;

  const _LivePreviewPanel({
    required this.state,
    required this.notifier,
    required this.projectionFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSlide = state.currentSlide;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;
    final ltState = ref.watch(lowerThirdControllerProvider);
    final projTheme = ref.watch(projectionThemeProvider);

    final double mobileClearance = (ltState.isEnabled && ltState.hasActiveItem)
        ? ((ltState.config.height * 0.35).clamp(20.0, 70.0) +
            (ltState.config.isFloating ? 10.0 : 4.0))
        : 0.0;

    final double desktopClearance = (ltState.isEnabled && ltState.hasActiveItem)
        ? ((ltState.config.height * 0.45).clamp(24.0, 90.0) +
            (ltState.config.isFloating ? 12.0 : 6.0))
        : 0.0;

    if (!isLargeScreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isBibleMode && currentSlide != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    currentSlide.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Previous Chapter',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: notifier.goToPrevChapter,
                      tooltip: 'Previous Chapter',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ch. ${state.bibleChapter ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Next Chapter',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: notifier.goToNextChapter,
                      tooltip: 'Next Chapter',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 12.0,
                        right: 12.0,
                        top: 12.0,
                        bottom: 12.0 + mobileClearance,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  currentSlide?.text ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Color.fromARGB(150, 0, 0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (state.isBibleMode && currentSlide != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                currentSlide.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF00E5CC),
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    LowerThirdOverlay(
                      state: ltState,
                      projectionBackground: projTheme.backgroundBaseColor,
                      previewScale: 0.35,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE PREVIEW',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
             _ProjectionSearchAnchor(notifier: notifier, returnFocusTo: projectionFocus),
          ],
        ),
        const SizedBox(height: 12),

        // Scripture reference + chapter stepper (Bible mode only)
        if (state.isBibleMode && currentSlide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  currentSlide.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Previous Chapter',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: notifier.goToPrevChapter,
                    tooltip: 'Previous Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  'Ch. ${state.bibleChapter ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Semantics(
                  label: 'Next Chapter',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: notifier.goToNextChapter,
                    tooltip: 'Next Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

        // 16:9 preview canvas
        Expanded(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                          bottom: 16.0 + desktopClearance,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    currentSlide?.text ?? '',
                                    textAlign: TextAlign.center,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Color.fromARGB(150, 0, 0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (state.isBibleMode && currentSlide != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentSlide.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF00E5CC),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      LowerThirdOverlay(
                        state: ltState,
                        projectionBackground: projTheme.backgroundBaseColor,
                        previewScale: 0.45,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Slide / Verse counter
        Center(
          child: Text(
            state.isBibleMode
                ? 'Verse ${state.currentSlideIndex + 1} of ${state.slides.length}'
                : 'Slide ${state.currentSlideIndex + 1} of ${state.slides.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Navigation buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.prevSlide : null,
                icon: const Icon(Icons.arrow_back),
                label: Text(state.isBibleMode ? 'Previous (←)' : 'Previous (←)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.nextSlide : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(state.isBibleMode ? 'Next (→)' : 'Next (→)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Font size controls
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Decrease Font Size',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: state.fontSize > 16
                        ? () {
                            notifier.setFontSize(state.fontSize - 4);
                            notifier.persistFontSize();
                          }
                        : null,
                    tooltip: 'Decrease (${state.fontSize - 4})',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${state.fontSize.toInt()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Increase Font Size',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: state.fontSize < 160
                        ? () {
                            notifier.setFontSize(state.fontSize + 4);
                            notifier.persistFontSize();
                          }
                        : null,
                    tooltip: 'Increase (${state.fontSize + 4})',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set Navigator Panel — shows set songs and allows jumping to any song in set
// ─────────────────────────────────────────────────────────────────────────────

class _SetNavigatorPanel extends ConsumerStatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const _SetNavigatorPanel({required this.state, required this.notifier});

  @override
  ConsumerState<_SetNavigatorPanel> createState() => _SetNavigatorPanelState();
}

class _SetNavigatorPanelState extends ConsumerState<_SetNavigatorPanel> {
  // Expanded state is now in _setNavigatorExpandedProvider so it survives
  // widget-tree moves (large ↔ small screen layout changes).

  @override
  Widget build(BuildContext context) {
    final setsState = ref.watch(setsControllerProvider);
    final bool isExpanded = ref.watch(_setNavigatorExpandedProvider);
    final theme = Theme.of(context);

    // Only show when a set is selected and has items
    if (setsState.selectedSetId == null || setsState.setItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final setObj = setsState.sets
        .where((s) => s.id == setsState.selectedSetId)
        .firstOrNull;
    if (setObj == null) return const SizedBox.shrink();

    // Determine which song is currently on screen
    final currentSongId = widget.state.currentSong?.id;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Header bar
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ref.read(_setNavigatorExpandedProvider.notifier).state = !isExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.playlist_play,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SET: ${setObj.name}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${setsState.setItems.length} songs',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Song list
          if (isExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
                itemCount: setsState.setItems.length,
                itemBuilder: (ctx, i) {
                  final item = setsState.setItems[i];
                  final song = setsState.availableSongs
                      .where((s) => s.id == item.songId)
                      .firstOrNull;
                  if (song == null) return const SizedBox.shrink();

                  final isActive = song.id == currentSongId;
                  final setKey = item.key ?? song.key;

                  return GestureDetector(
                    onTap: () => widget.notifier.setSong(song),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Position number
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          // Song title
                          Expanded(
                            child: Text(
                              song.title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Key badge
                          if (setKey != null && setKey.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                setKey,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          // Playing indicator
                          if (isActive)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.play_arrow,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search mode toggle — Bible / Song chips (replaces SegmentedButton to avoid
// rebuild loops inside SearchAnchor.viewTrailing)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchModeToggle extends StatelessWidget {
  final bool isBibleMode;
  final ValueChanged<bool> onToggle;

  const _SearchModeToggle({required this.isBibleMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bibleColor = theme.colorScheme.tertiary;
    final songColor = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeChip(
          label: 'Bible',
          icon: Icons.menu_book,
          isSelected: isBibleMode,
          selectedColor: bibleColor,
          onTap: () { if (!isBibleMode) onToggle(true); },
        ),
        const SizedBox(width: 6),
        _ModeChip(
          label: 'Song',
          icon: Icons.library_music,
          isSelected: !isBibleMode,
          selectedColor: songColor,
          onTap: () { if (isBibleMode) onToggle(false); },
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.7)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared search results rendering
//
// The empty projection window embeds search inline (ready to type), while the
// projection controls open the same search in a dialog. Both render their
// results through the helpers below so behaviour and styling stay identical.
// ─────────────────────────────────────────────────────────────────────────────

/// Composed result list for the current search state.
/// Bible mode puts an exact reference match first, then the text-search hits.
List<dynamic> composeSearchResults(ProjectionSearchState state) {
  if (!state.isBibleMode) return state.songResults;
  return <dynamic>[
    if (state.exactMatch != null) state.exactMatch!,
    ...state.bibleResults,
  ];
}

/// Number of results currently presented to the user.
int countSearchResults(ProjectionSearchState state) {
  if (!state.isBibleMode) return state.songResults.length;
  return (state.exactMatch != null ? 1 : 0) + state.bibleResults.length;
}

/// Shares a search result, reporting failures through [context]'s snackbar.
Future<void> shareSearchItem(
  BuildContext context,
  dynamic item,
  ProjectionSearchState state,
) async {
  try {
    if (state.isBibleMode && item is BibleVerse) {
      final text = '📖 ${item.reference}\n\n${item.text}';
      await ShareService.shareText(text);
    } else if (!state.isBibleMode && item is Song) {
      final buffer = StringBuffer();
      buffer.writeln('🎵 ${item.title}');
      if (item.songNum > 0) buffer.writeln('Song #${item.songNum}');
      if (item.key != null && item.key!.isNotEmpty) buffer.writeln('Key: ${item.key}');
      buffer.writeln('');
      buffer.writeln(item.body);
      await ShareService.shareText(buffer.toString());
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }
}

/// Renders the current search results.
///
/// [selectedIndex] is highlighted and shows the "press Enter" affordance;
/// [onPick] projects the item at that index; [onShare] shares it.
class ProjectionSearchResultsList extends ConsumerWidget {
  final ProjectionSearchState searchState;
  final int selectedIndex;
  final ScrollController? scrollController;
  final void Function(int index, ProjectionSearchState state) onPick;

  const ProjectionSearchResultsList({
    super.key,
    required this.searchState,
    required this.selectedIndex,
    required this.onPick,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = searchState.query;

    if (searchState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed: ${searchState.error}',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searchState.isBibleMode ? Icons.menu_book : Icons.library_music,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                searchState.isBibleMode
                    ? 'Type a verse or reference, e.g. "John 3:16"'
                    : 'Type a song title or lyric to project',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (searchState.isBibleMode) {
      return _buildBibleResults(context, ref, searchState, theme);
    }
    return _buildSongResults(context, ref, searchState, theme);
  }

  Widget _buildBibleResults(
    BuildContext context,
    WidgetRef ref,
    ProjectionSearchState searchState,
    ThemeData theme,
  ) {
    final results = composeSearchResults(searchState);

    if (results.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    final hasMore = searchState.bibleResults.length < searchState.totalBibleCount;
    final itemCount = hasMore ? results.length + 1 : results.length;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: TextButton.icon(
                onPressed: searchState.isLoading
                    ? null
                    : () => ref
                        .read(projectionSearchProvider.notifier)
                        .loadMoreBible(),
                icon: searchState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load more results'),
              ),
            ),
          );
        }

        final v = results[index] as BibleVerse;
        final isExact = v == searchState.exactMatch;
        final isSelected = index == selectedIndex;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                  : isExact
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2.0 : (isExact ? 1.5 : 1),
            ),
          ),
          child: ListTile(
            tileColor: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.30)
                : isExact
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isExact
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book,
                size: 16,
                color: isExact
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
              ),
            ),
            title: HighlightedText(
              text: v.reference,
              query: searchState.query,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              highlightStyle: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: HighlightedText(
                text: v.text,
                query: searchState.query,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                highlightStyle: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  tooltip: 'Share verse',
                  onPressed: () =>
                      shareSearchItem(context, v, searchState),
                ),
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_return,
                            size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Enter',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.present_to_all,
                      size: 16,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
            onTap: () => onPick(index, searchState),
          ),
        );
      },
    );
  }

  Widget _buildSongResults(
    BuildContext context,
    WidgetRef ref,
    ProjectionSearchState searchState,
    ThemeData theme,
  ) {
    final songs = searchState.songResults;

    if (songs.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final s = songs[index];
        final isSelected = index == selectedIndex;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: ListTile(
            tileColor: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${s.songNum}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            title: HighlightedText(
              text: s.title,
              query: searchState.query,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              highlightStyle: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  if (s.key != null && s.key!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Key: ${s.key}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      s.body.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  tooltip: 'Share song',
                  onPressed: () =>
                      shareSearchItem(context, s, searchState),
                ),
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_return,
                            size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Enter',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.present_to_all,
                      size: 16,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
            onTap: () => onPick(index, searchState),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Search Anchor — opens full-screen search with Bible / Songs toggle
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Inline search for the empty projection window
//
// Unlike the anchor above, this one is always on screen and already focused,
// so the operator can start typing a song or verse immediately instead of
// opening a popup first. Results appear directly underneath the field.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineProjectionSearch extends ConsumerStatefulWidget {
  final ProjectionController notifier;

  /// Shown in place of the search results while there is no query. Used by the
  /// narrow layout to keep the history tabs reachable; left null on wide
  /// screens, where the history lives in its own rail.
  final Widget? idleContent;

  const _InlineProjectionSearch({required this.notifier, this.idleContent});

  @override
  ConsumerState<_InlineProjectionSearch> createState() =>
      _InlineProjectionSearchState();
}

class _InlineProjectionSearchState
    extends ConsumerState<_InlineProjectionSearch> {
  final SearchController _searchController = SearchController();
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'InlineProjectionSearch');

  static const Duration _navReadyDelay = Duration(milliseconds: 100);
  bool _navReady = false;
  Timer? _navReadyTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    // The window opens ready for input — no extra tap needed to start typing.
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _navReadyTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _selectedIndex.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    ref.read(projectionSearchProvider.notifier).search(_searchController.text);
  }

  void _resetNavReady() {
    _navReadyTimer?.cancel();
    if (_navReady) setState(() => _navReady = false);
    _navReadyTimer = Timer(_navReadyDelay, () {
      if (mounted) setState(() => _navReady = true);
    });
  }

  void _scrollToSelected(int index) {
    final searchState = ref.read(projectionSearchProvider);
    if (index < 0 || index >= countSearchResults(searchState)) return;
    if (!_scrollController.hasClients) return;

    // Result rows are a near-constant height, so advancing by a fixed extent
    // keeps the highlighted item in view without needing per-row keys.
    const estimatedItemExtent = 96.0;
    final target = (index * estimatedItemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Projects the picked item. Picking already auto-opens the projector window,
  /// which swaps this empty view for the active controls.
  void _pickItem(int index, ProjectionSearchState searchState) {
    final searchRef = ref.read(projectionSearchProvider.notifier);
    final results = composeSearchResults(searchState);
    if (index < 0 || index >= results.length) return;

    if (searchState.isBibleMode) {
      final v = results[index] as BibleVerse;
      widget.notifier.projectVerse(
        v.bookId,
        v.chapter,
        v.verse,
        v.bookName ?? '',
      );
      ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    } else {
      widget.notifier.setSong(results[index] as Song);
    }

    searchRef.clear();
    _searchController.clear();
  }

  KeyEventResult _handleKey(KeyEvent event, ProjectionSearchState s) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Enter projects the highlighted result as soon as results exist.
    final totalItems = countSearchResults(s);
    if (totalItems > 0 && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
      _pickItem(_selectedIndex.value, s);
      return KeyEventResult.handled;
    }

    if (!_navReady) return KeyEventResult.ignored;
    if (totalItems == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = (_selectedIndex.value + 1).clamp(0, totalItems - 1);
      if (next != _selectedIndex.value) {
        setState(() => _selectedIndex.value = next);
        _scrollToSelected(next);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final prev = (_selectedIndex.value - 1).clamp(0, totalItems - 1);
      if (prev != _selectedIndex.value) {
        setState(() => _selectedIndex.value = prev);
        _scrollToSelected(prev);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(projectionSearchProvider);
    final theme = Theme.of(context);

    ref.listen(
      projectionSearchProvider.select((s) => s.query),
      (prev, next) {
        if (prev != next) _resetNavReady();
      },
    );

    ref.listen(projectionSearchProvider, (prev, next) {
      if (prev?.bibleResults != next.bibleResults ||
          prev?.songResults != next.songResults ||
          prev?.exactMatch != next.exactMatch) {
        if (mounted) setState(() => _selectedIndex.value = 0);
      }
    });

    return Column(
      children: [
        // Search field row: an always-visible, pre-focused text field plus the
        // mode toggle and the songbook filter, so switching source never
        // means closing and reopening a popup.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
              child: SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                hintText: searchState.isBibleMode
                    ? 'Search Bible…'
                    : 'Search songs…',
                  leading: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(projectionSearchProvider.notifier).clear();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SearchModeToggle(
                isBibleMode: searchState.isBibleMode,
                onToggle: (isBible) {
                  ref.read(projectionSearchProvider.notifier).switchModeAndSearch(
                    isBible,
                    _searchController.text,
                  );
                },
              ),
              if (!searchState.isBibleMode)
                Consumer(
                  builder: (context, ref, child) {
                    final selectedSource = ref.watch(projectionSearchProvider
                        .select((s) => s.selectedSourcePath));
                    final sourcePaths = ref.watch(songListControllerProvider
                        .select((s) => s.sourcePaths));
                    if (sourcePaths.length <= 1) {
                      return const SizedBox.shrink();
                    }
                    return PopupMenuButton<String?>(
                      icon: Icon(
                        Icons.library_books_outlined,
                        size: 18,
                        color: selectedSource != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Filter by songbook',
                      onSelected: (value) {
                        ref
                            .read(projectionSearchProvider.notifier)
                            .setSourceFilter(value);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              const Icon(Icons.all_inclusive, size: 16),
                              const SizedBox(width: 8),
                              const Text('All Books'),
                              if (selectedSource == null) ...[
                                const Spacer(),
                                Icon(Icons.check,
                                    size: 16, color: theme.colorScheme.primary),
                              ],
                            ],
                          ),
                        ),
                        ...sourcePaths.map((source) => PopupMenuItem<String?>(
                              value: source.path,
                              child: Row(
                                children: [
                                  const Icon(Icons.book_outlined, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(source.path,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(
                                    '${source.count}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (selectedSource == source.path) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.check,
                                        size: 16,
                                        color: theme.colorScheme.primary),
                                  ],
                                ],
                              ),
                            )),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Loading indicator + results, below the field.
        Expanded(
          child: Column(
            children: [
              if (searchState.isLoading)
                const LinearProgressIndicator(minHeight: 3)
              else
                const SizedBox(height: 3),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) => _handleKey(event, searchState),
                  child: (widget.idleContent != null &&
                          searchState.query.trim().isEmpty &&
                          !searchState.isLoading)
                      ? widget.idleContent!
                      : ProjectionSearchResultsList(
                          searchState: searchState,
                          selectedIndex: _selectedIndex.value,
                          scrollController: _scrollController,
                          onPick: (index, state) => _pickItem(index, state),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectionSearchAnchor extends ConsumerWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;

  const _ProjectionSearchAnchor({required this.notifier, required this.returnFocusTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBible = ref.watch(projectionSearchProvider.select((s) => s.isBibleMode));
    final theme = Theme.of(context);
    final color = isBible ? theme.colorScheme.tertiary : theme.colorScheme.primary;

    return ActionChip(
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (ctx) => _FullScreenSearchPage(
            notifier: notifier,
            returnFocusTo: returnFocusTo,
          ),
        );
      },
      avatar: Icon(
        isBible ? Icons.menu_book : Icons.library_music,
        size: 16,
        color: color,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Neutral wording — the avatar icon and colour still show which
            // source is active, and the search page has its own Bible/Songs
            // toggle, so "Search Songs"/"Search Bible" was redundant here.
            'Search',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.search, size: 14, color: color),
        ],
      ),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.zero,
      tooltip: 'Search songs and Bible',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen search page — Bible / Songs toggle + results + share
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenSearchPage extends ConsumerStatefulWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;

  const _FullScreenSearchPage({
    required this.notifier,
    required this.returnFocusTo,
  });

  @override
  ConsumerState<_FullScreenSearchPage> createState() => _FullScreenSearchPageState();
}

class _FullScreenSearchPageState extends ConsumerState<_FullScreenSearchPage> {
  final SearchController _searchController = SearchController();
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'FullScreenSearchFocus');

  static const Duration _navReadyDelay = Duration(milliseconds: 100);
  bool _navReady = false;
  Timer? _navReadyTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _navReadyTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _selectedIndex.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final newText = _searchController.text;
    ref.read(projectionSearchProvider.notifier).search(newText);
  }

  void _resetNavReady() {
    _navReadyTimer?.cancel();
    if (_navReady) setState(() => _navReady = false);
    _navReadyTimer = Timer(_navReadyDelay, () {
      if (mounted) setState(() => _navReady = true);
    });
  }

  void _scrollToSelected(int index) {
    final searchState = ref.read(projectionSearchProvider);
    if (index < 0 || index >= countSearchResults(searchState)) return;
    if (!_scrollController.hasClients) return;

    // Result rows are a near-constant height, so advancing by a fixed extent
    // keeps the highlighted item in view without needing per-row keys.
    const estimatedItemExtent = 96.0;
    final target = (index * estimatedItemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _pickItem(int index, ProjectionSearchState searchState) {
    final searchRef = ref.read(projectionSearchProvider.notifier);
    final results = composeSearchResults(searchState);
    if (index < 0 || index >= results.length) return;
    if (searchState.isBibleMode) {
      final v = results[index] as BibleVerse;
      widget.notifier.projectVerse(
        v.bookId, v.chapter, v.verse, v.bookName ?? '',
      );
      ref.read(setRepositoryProvider).recordBibleProjection(v.reference, v.text);
    } else {
      widget.notifier.setSong(results[index] as Song);
    }
    searchRef.clear();
    _searchController.clear();
    if (mounted) Navigator.of(context).pop();
    widget.returnFocusTo.requestFocus();
  }

  KeyEventResult _handleKey(KeyEvent event, ProjectionSearchState searchState) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final totalItems = countSearchResults(searchState);
      if (totalItems > 0) {
        final safeIndex = _selectedIndex.value.clamp(0, totalItems - 1);
        _pickItem(safeIndex, searchState);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!_navReady) return KeyEventResult.ignored;

    final totalItems = countSearchResults(searchState);
    if (totalItems == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = (_selectedIndex.value + 1).clamp(0, totalItems - 1);
      if (next != _selectedIndex.value) {
        setState(() => _selectedIndex.value = next);
        _scrollToSelected(next);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final prev = (_selectedIndex.value - 1).clamp(0, totalItems - 1);
      if (prev != _selectedIndex.value) {
        setState(() => _selectedIndex.value = prev);
        _scrollToSelected(prev);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(projectionSearchProvider);
    final theme = Theme.of(context);

    ref.listen(
      projectionSearchProvider.select((s) => s.query),
      (prev, next) {
        if (prev != next) _resetNavReady();
      },
    );

    ref.listen(projectionSearchProvider, (prev, next) {
      if (prev?.bibleResults != next.bibleResults ||
          prev?.songResults != next.songResults ||
          prev?.exactMatch != next.exactMatch) {
        if (mounted) setState(() => _selectedIndex.value = 0);
      }
    });

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Focus(
          onKeyEvent: (node, event) => _handleKey(event, searchState),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () {
                        ref.read(projectionSearchProvider.notifier).clear();
                        _searchController.clear();
                        if (mounted) Navigator.of(context).pop();
                        widget.returnFocusTo.requestFocus();
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SearchBar(
                        controller: _searchController,
                        focusNode: _focusNode,
                        hintText: searchState.isBibleMode ? 'Search Bible…' : 'Search songs…',
                        trailing: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(projectionSearchProvider.notifier).clear();
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _SearchModeToggle(
                      isBibleMode: searchState.isBibleMode,
                      onToggle: (isBible) {
                        ref.read(projectionSearchProvider.notifier).switchModeAndSearch(
                          isBible,
                          _searchController.text,
                        );
                      },
                    ),
                    if (!searchState.isBibleMode)
                      Consumer(
                        builder: (context, ref, child) {
                          final selectedSource = ref.watch(projectionSearchProvider.select((s) => s.selectedSourcePath));
                          final sourcePaths = ref.watch(songListControllerProvider.select((s) => s.sourcePaths));
                          if (sourcePaths.length <= 1) return const SizedBox.shrink();
                          return PopupMenuButton<String?>(
                            icon: Icon(
                              Icons.library_books_outlined,
                              size: 18,
                              color: selectedSource != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            tooltip: 'Filter by songbook',
                            onSelected: (value) {
                              ref.read(projectionSearchProvider.notifier).setSourceFilter(value);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String?>(
                                value: null,
                                child: Row(
                                  children: [
                                    const Icon(Icons.all_inclusive, size: 16),
                                    const SizedBox(width: 8),
                                    const Text('All Books'),
                                    if (selectedSource == null) ...[
                                      const Spacer(),
                                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                              ),
                              ...sourcePaths.map((source) => PopupMenuItem<String?>(
                                value: source.path,
                                child: Row(
                                  children: [
                                    const Icon(Icons.book_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(source.path, overflow: TextOverflow.ellipsis)),
                                    Text(
                                      '${source.count}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (selectedSource == source.path) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                                    ],
                                  ],
                                ),
                              )),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Column(
                  children: [
                    if (searchState.isLoading)
                      const LinearProgressIndicator(minHeight: 3)
                    else
                      const SizedBox(height: 3),
                    Expanded(
                      child: ProjectionSearchResultsList(
                        searchState: searchState,
                        selectedIndex: _selectedIndex.value,
                        scrollController: _scrollController,
                        onPick: (index, state) => _pickItem(index, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
