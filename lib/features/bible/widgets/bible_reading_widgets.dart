import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/services/share_service.dart';
import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/widgets/bible_navigation_dialog.dart';
import 'package:visual_song_book/features/bible/widgets/bible_sidebar_widgets.dart';

class BibleEmptyReadingView extends StatelessWidget {
  final int? lastReadBookId;
  final int? lastReadChapter;
  final int? lastReadVerse;
  final List<BibleBook> books;
  final VoidCallback? onContinueReading;

  const BibleEmptyReadingView({
    super.key,
    this.lastReadBookId,
    this.lastReadChapter,
    this.lastReadVerse,
    this.books = const [],
    this.onContinueReading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastBookName = lastReadBookId != null
        ? books.where((b) => b.id == lastReadBookId).firstOrNull?.name
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Select a book',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('or search above',
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            if (lastBookName != null && onContinueReading != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onContinueReading,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'Continue Reading $lastBookName ${lastReadChapter ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BibleReadingView extends StatefulWidget {
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final String bookName;
  final void Function(int chapter, List<BibleVerse> verses) onProjectPassage;
  final ValueChanged<BibleVerse> onToggleBookmark;
  final BibleVerse? activeVerse;
  final ValueChanged<BibleVerse> onSelectVerse;
  final Set<int> bookmarkedVerseIds;
  final bool selectionMode;
  final Set<int> selectedVerseIds;
  final VoidCallback onToggleSelectionMode;
  final ValueChanged<int> onToggleVerseSelection;
  final VoidCallback onSelectAllVerses;
  final double fontSize;
  final String readingFontFamily;
  final bool isLoadingVerses;
  final bool isLargeScreen;
  final ValueChanged<BibleVerse> onShowCrossRefs;
  final ValueChanged<double>? onFontSizeChanged;

  const BibleReadingView({
    super.key,
    this.selectedChapter,
    required this.verses,
    required this.bookName,
    required this.onProjectPassage,
    required this.onToggleBookmark,
    required this.activeVerse,
    required this.onSelectVerse,
    required this.bookmarkedVerseIds,
    required this.selectionMode,
    required this.selectedVerseIds,
    required this.onToggleSelectionMode,
    required this.onToggleVerseSelection,
    required this.onSelectAllVerses,
    required this.fontSize,
    required this.readingFontFamily,
    required this.isLoadingVerses,
    required this.isLargeScreen,
    required this.onShowCrossRefs,
    this.onFontSizeChanged,
  });

  @override
  State<BibleReadingView> createState() => _BibleReadingViewState();
}

class _BibleReadingViewState extends State<BibleReadingView> {
  final _scrollController = ScrollController();
  final _activeVerseKey = GlobalKey();
  final _verseJumpController = TextEditingController();
  bool _showJumpInput = false;
  double _baseFontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToActive();
  }

  @override
  void didUpdateWidget(covariant BibleReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeVerse?.id != oldWidget.activeVerse?.id) {
      _scheduleScrollToActive();
    }
  }

  void _scheduleScrollToActive() {
    final v = widget.activeVerse;
    if (v == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final currentContext = _activeVerseKey.currentContext;
      if (currentContext != null && _scrollController.hasClients) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _verseJumpController.dispose();
    super.dispose();
  }

  void _jumpToVerse() {
    final num = int.tryParse(_verseJumpController.text);
    if (num == null) return;
    final verse = widget.verses.where((v) => v.verse == num).firstOrNull;
    if (verse != null) {
      widget.onSelectVerse(verse);
    }
    setState(() => _showJumpInput = false);
    _verseJumpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final readingFont = widget.readingFontFamily;

    return Column(
      children: [
        if (widget.selectedChapter != null && widget.verses.isNotEmpty)
          _buildChapterHeader(colorScheme),
        const Divider(height: 1),
        if (widget.selectionMode) _buildSelectionToolbar(colorScheme),
        Expanded(
          child: widget.isLoadingVerses
              ? _buildSkeleton(colorScheme)
              : widget.verses.isEmpty
                  ? Center(
                      child: Text('No verses in this chapter',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    )
                  : _buildVerseList(colorScheme, readingFont),
        ),
      ],
    );
  }

  Widget _buildChapterHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(bibleControllerProvider.notifier).prevChapter(),
                tooltip: 'Previous Chapter',
              );
            },
          ),
          Expanded(
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.15),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                label: Text(
                  '${widget.bookName} ${widget.selectedChapter}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => const BibleNavigationDialog(),
                ),
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(bibleControllerProvider.notifier).nextChapter(),
                tooltip: 'Next Chapter',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar(ColorScheme colorScheme) {
    final selected = widget.selectedVerseIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onToggleSelectionMode,
            tooltip: 'Exit selection',
          ),
          const SizedBox(width: 8),
          Text(
            '$selected verse${selected == 1 ? '' : 's'} selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onSelectAllVerses,
            child: const Text('Select All', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: selected > 0 ? _shareSelectedVerses : null,
            icon: const Icon(Icons.share_outlined, size: 16),
            label: Text('Share ($selected)', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: selected > 0 ? _projectSelectedVerses : null,
            icon: const Icon(Icons.tv, size: 16),
            label: Text('Project ($selected)', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedVerses() async {
    final container = ProviderScope.containerOf(context);
    final text = await container
        .read(bibleControllerProvider.notifier)
        .getSelectedPassageText();
    if (text.isEmpty) return;
    await ShareService.shareText(text);
  }

  void _projectSelectedVerses() {
    final selected = widget.verses
        .where((v) => widget.selectedVerseIds.contains(v.id))
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (selected.isEmpty) return;
    widget.onProjectPassage(selected.first.chapter, selected);
  }

  Widget _buildSkeleton(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      itemCount: 12,
      itemBuilder: (context, index) {
        final widths = [0.85, 0.7, 0.9, 0.6, 0.8, 0.75, 0.95, 0.65, 0.8, 0.72, 0.88, 0.55];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: widths[index % widths.length],
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: widths[(index + 3) % widths.length] * 0.7,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerseList(ColorScheme colorScheme, String readingFont) {
    return Stack(
      children: [
        GestureDetector(
          onScaleStart: (details) {
            _baseFontSize = widget.fontSize;
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final newSize = (_baseFontSize * details.scale).clamp(12.0, 96.0);
              widget.onFontSizeChanged?.call(newSize);
            }
          },
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).padding.bottom + 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.verses.map((v) {
            final isActive = widget.activeVerse?.id == v.id;
            final isBookmarked = widget.bookmarkedVerseIds.contains(v.verse);
            final isSelected = widget.selectedVerseIds.contains(v.id);

             return ColoredBox(
               key: isActive ? _activeVerseKey : null,
               color: isActive
                   ? colorScheme.primaryContainer.withValues(alpha: 0.12)
                   : isSelected
                       ? colorScheme.primaryContainer.withValues(alpha: 0.06)
                       : Colors.transparent,
               child: InkWell(
                 onTap: widget.selectionMode
                     ? () => widget.onToggleVerseSelection(v.id)
                     : () => widget.onSelectVerse(v),
                 onDoubleTap: widget.selectionMode
                     ? null
                     : () => widget.onProjectPassage(v.chapter, [v]),
                 onLongPress: widget.selectionMode || !isActive
                     ? null
                     : () => _showVerseMenu(context, v),
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       if (widget.selectionMode) ...[
                         Padding(
                           padding: const EdgeInsets.only(top: 2),
                           child: Icon(
                             isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                             size: 18,
                             color: isSelected
                                 ? colorScheme.primary
                                 : colorScheme.onSurfaceVariant,
                           ),
                         ),
                         const SizedBox(width: 8),
                       ],
                       SizedBox(
                         width: 28,
                         child: Align(
                           alignment: Alignment.centerLeft,
                           child: Text(
                             '${v.verse}',
                             style: TextStyle(
                               fontSize: 11,
                               fontWeight: FontWeight.w600,
                               color: isActive
                                   ? colorScheme.primary
                                   : colorScheme.primary.withValues(alpha: 0.7),
                               height: 1.7,
                             ),
                           ),
                         ),
                       ),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               v.text,
                               style: TextStyle(
                                 fontFamily: readingFont,
                                 fontSize: widget.fontSize,
                                 height: 1.65,
                                 color: colorScheme.onSurface,
                               ),
                             ),
                             if (isActive) ...[
                               const SizedBox(height: 10),
                               BibleInlineCrossReferences(verse: v),
                             ],
                           ],
                         ),
                       ),
                       if (isActive && !widget.selectionMode)
                         Padding(
                           padding: const EdgeInsets.only(top: 2, right: 4),
                           child: GestureDetector(
                             onTap: () {
                               if (!widget.isLargeScreen) {
                                 widget.onShowCrossRefs(v);
                               }
                             },
                             child: Icon(Icons.link,
                                 size: 14,
                                 color: widget.isLargeScreen
                                     ? colorScheme.primary
                                     : colorScheme.onSurfaceVariant),
                           ),
                         ),
                       if (isActive && !widget.selectionMode)
                         BibleVersePopupMenu(
                           verse: v,
                           isBookmarked: isBookmarked,
                           isLargeScreen: widget.isLargeScreen,
                           onProject: () => widget.onProjectPassage(v.chapter, [v]),
                           onBookmark: () => widget.onToggleBookmark(v),
                           onNavigate: () {
                             ProviderScope.containerOf(context)
                                 .read(bibleControllerProvider.notifier)
                                 .navigateToVerse(v.bookId, v.chapter, v.verse);
                           },
                         ),
                     ],
                   ),
                 ),
               ),
             );
          }).toList(),
            ),
          ),
        ),
        if (widget.verses.length > 30)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showJumpInput)
                  Container(
                    width: 80,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _verseJumpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'V.',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _jumpToVerse(),
                    ),
                  ),
                FloatingActionButton.small(
                  onPressed: () {
                    setState(() => _showJumpInput = !_showJumpInput);
                    if (!_showJumpInput) _verseJumpController.clear();
                  },
                  heroTag: 'verse_jump',
                  child: Icon(_showJumpInput ? Icons.close : Icons.tag),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showVerseMenu(BuildContext context, BibleVerse verse) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox?.localToGlobal(renderBox.size.center(Offset.zero)) ??
        Offset.zero;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;
    final container = ProviderScope.containerOf(context);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(center.dx, center.dy, center.dx + 1, center.dy + 1),
      items: [
        PopupMenuItem(
          value: 'project',
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: const Icon(Icons.tv, size: 18),
              title: Text(isLargeScreen ? 'Project' : 'Present',
                  style: const TextStyle(fontSize: 13)),
              dense: true,
            ),
          ),
        ),
        if (kIsWeb || !Platform.isAndroid)
          PopupMenuItem(
            value: 'navigate',
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(Icons.open_in_new, size: 18),
                title: Text('Navigate to Verse', style: TextStyle(fontSize: 13)),
                dense: true,
              ),
            ),
          ),
        PopupMenuItem(
          value: 'bookmark',
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(
                  ProviderScope.containerOf(context).read(bibleControllerProvider).bookmarkedVerseIds.contains(verse.verse)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 18),
              title: Text(
                  ProviderScope.containerOf(context).read(bibleControllerProvider).bookmarkedVerseIds.contains(verse.verse)
                      ? 'Remove Bookmark'
                      : 'Bookmark',
                  style: const TextStyle(fontSize: 13)),
              dense: true,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.share_outlined, size: 18),
              title: Text('Share Verse', style: TextStyle(fontSize: 13)),
              dense: true,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'select',
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.checklist, size: 18),
              title: Text('Select Verses', style: TextStyle(fontSize: 13)),
              dense: true,
            ),
          ),
        ),
      ],
    ).then((action) async {
      if (action == 'project') {
        widget.onProjectPassage(verse.chapter, [verse]);
      } else if (action == 'navigate') {
        container
            .read(bibleControllerProvider.notifier)
            .navigateToVerse(verse.bookId, verse.chapter, verse.verse);
      } else if (action == 'bookmark') {
        widget.onToggleBookmark(verse);
      } else if (action == 'share') {
        final text = '📖 ${verse.reference}\n\n${verse.text}';
        await ShareService.shareText(text);
      } else if (action == 'select') {
        container
            .read(bibleControllerProvider.notifier)
            .toggleSelectionMode();
      }
    });
  }
}

class BibleVersePopupMenu extends StatelessWidget {
  final BibleVerse verse;
  final bool isBookmarked;
  final bool isLargeScreen;
  final VoidCallback onProject;
  final VoidCallback onBookmark;
  final VoidCallback onNavigate;

  const BibleVersePopupMenu({
    super.key,
    required this.verse,
    required this.isBookmarked,
    required this.isLargeScreen,
    required this.onProject,
    required this.onBookmark,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBookmarked)
            Icon(Icons.bookmark,
                size: 14, color: Theme.of(context).colorScheme.primary),
          Icon(Icons.more_vert,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        ],
      ),
      onSelected: (action) {
        if (action == 'project') {
          onProject();
        } else if (action == 'share') {
          final text = '📖 ${verse.reference}\n\n${verse.text}';
          ShareService.shareText(text);
        } else if (action == 'bookmark') {
          onBookmark();
        } else if (action == 'navigate') {
          onNavigate();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'project',
          child: ListTile(
            leading: const Icon(Icons.tv, size: 18),
            title: Text(isLargeScreen ? 'Project' : 'Present',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        if (kIsWeb || !Platform.isAndroid)
          const PopupMenuItem(
            value: 'navigate',
            child: ListTile(
              leading: Icon(Icons.open_in_new, size: 18),
              title: Text('Navigate to Verse', style: TextStyle(fontSize: 13)),
              dense: true,
            ),
          ),
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share_outlined, size: 18),
            title: Text('Share Verse', style: TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: ListTile(
            leading: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, size: 18),
            title: Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                style: const TextStyle(fontSize: 13)),
            dense: true,
          ),
        ),
      ],
    );
  }
}
