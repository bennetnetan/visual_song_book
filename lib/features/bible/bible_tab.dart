import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

final bibleControllerProvider =
    StateNotifierProvider<BibleController, BibleState>((ref) {
      final repo = ref.watch(bibleRepositoryProvider);
      return BibleController(repo);
    });

class BibleTab extends ConsumerWidget {
  final bool isLargeScreen;

  const BibleTab({super.key, required this.isLargeScreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    return Scaffold(
      body: !state.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : !isLargeScreen && state.selectedBookId == null
          // Mobile: full-screen book picker when no book is selected
          ? _BookPicker(books: state.books, onSelect: notifier.selectBook)
          // Desktop layout or mobile with book selected
          : Row(
              children: [
                // Left navigation pane - books list (desktop only)
                if (isLargeScreen) ...[
                  _BookNav(
                    books: state.books,
                    selectedId: state.selectedBookId,
                    onSelect: notifier.selectBook,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                ],
                // Main reading area
                Expanded(
                  child: Column(
                    children: [
                      // Search bar
                      _SearchBar(
                        query: state.query,
                        onChanged: notifier.search,
                        showBackButton: !isLargeScreen && state.selectedBookId != null,
                        onBack: notifier.clearSelection,
                      ),
                      // Content area
                      Expanded(
                        child: state.searchResults.isNotEmpty
                            ? _SearchResultsView(
                                results: state.searchResults,
                                onProject: (v) {
                                  ref
                                      .read(projectionControllerProvider.notifier)
                                      .setBiblePassage(
                                        [Verse(label: v.reference, text: v.text, order: 1)],
                                        title: v.reference,
                                        bookId: v.bookId,
                                        chapter: v.chapter,
                                        bookName: v.bookName,
                                      );
                                  ref
                                      .read(setRepositoryProvider)
                                      .recordBibleProjection(v.reference, v.text);
                                  ref.read(activeDashboardTabProvider.notifier).state = 4;
                                },
                              )
                            : state.selectedBookId == null
                            ? _EmptyReadingView()
                            : _ReadingView(
                                chapters: state.chapters,
                                selectedChapter: state.selectedChapter,
                                verses: state.verses,
                                bookName: state.books
                                    .where((b) => b.id == state.selectedBookId)
                                    .firstOrNull?.name ?? '',
                                onSelectChapter: notifier.selectChapter,
                                onProjectPassage: (chapter, verses) {
                                  final bookName = state.books
                                      .where((b) => b.id == state.selectedBookId)
                                      .firstOrNull?.name ?? '';
                                  final passageTitle = verses.length == 1
                                      ? '$bookName $chapter:${verses.first.verse}'
                                      : '$bookName $chapter';
                                  final slides = verses
                                      .map((v) => Verse(
                                            label: '$bookName $chapter:${v.verse}',
                                            text: v.text,
                                            order: v.verse,
                                          ))
                                      .toList();
                                  ref
                                      .read(projectionControllerProvider.notifier)
                                      .setBiblePassage(
                                        slides,
                                        title: passageTitle,
                                        bookId: state.selectedBookId,
                                        chapter: chapter,
                                        bookName: bookName,
                                      );
                                  ref
                                      .read(setRepositoryProvider)
                                      .recordBibleProjection(
                                        '$bookName $chapter',
                                        '${verses.first.verse}-${verses.last.verse}',
                                      );
                                  ref.read(activeDashboardTabProvider.notifier).state = 4;
                                },
                                onToggleBookmark: (v) {
                                  final setRepo = ref.read(setRepositoryProvider);
                                  setRepo.isBookmarked(v.bookId, v.chapter, v.verse).then((isMarked) {
                                    if (isMarked) {
                                      setRepo.getBookmarks().then((marks) {
                                        final existing = marks.firstWhere(
                                          (m) => m.bookId == v.bookId && m.chapter == v.chapter && m.verseNum == v.verse,
                                          orElse: () => BibleBookmark(id: -1, bookId: 0, chapter: 0, verseNum: 0, reference: '', verseText: '', bookName: '', createdAt: DateTime.now()),
                                        );
                                        if (existing.id != -1) setRepo.removeBookmark(existing.id);
                                      });
                                    } else {
                                      setRepo.addBookmark(
                                        v.bookId, v.chapter, v.verse,
                                        v.reference, v.text, v.bookName ?? '',
                                      );
                                    }
                                  });
                                },
                                activeVerse: state.activeVerse,
                                onSelectVerse: notifier.selectVerse,
                              ),
                      ),
                    ],
                  ),
                ),
                // Right sidebar - cross references & bookmarks (desktop only)
                if (isLargeScreen) ...[                  const VerticalDivider(width: 1, thickness: 1),
                  const _RightSidebar(),
                ],
              ],
            ),
    );
  }
}

class _BookPicker extends StatelessWidget {
  final List<BibleBook> books;
  final ValueChanged<int> onSelect;

  const _BookPicker({required this.books, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'SELECT A BOOK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(book.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      book.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookNav extends StatelessWidget {
  final List<BibleBook> books;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _BookNav({required this.books, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'BOOKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final isSelected = book.id == selectedId;
                return Material(
                  color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(book.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        book.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final bool showBackButton;
  final VoidCallback? onBack;

  const _SearchBar({
    required this.query,
    required this.onChanged,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(showBackButton ? 4 : 20, 16, 20, 4),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              tooltip: 'Back to books',
            ),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              controller: query.isNotEmpty
                  ? TextEditingController.fromValue(TextEditingValue(text: query))
                  : null,
              decoration: InputDecoration(
                hintText: 'Search scripture, topics...',
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => onChanged(''),
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Select a book', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('or search above', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _ReadingView extends StatelessWidget {
  final List<int> chapters;
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final String bookName;
  final ValueChanged<int> onSelectChapter;
  final void Function(int chapter, List<BibleVerse> verses) onProjectPassage;
  final ValueChanged<BibleVerse> onToggleBookmark;
  final BibleVerse? activeVerse;
  final ValueChanged<BibleVerse> onSelectVerse;

  const _ReadingView({
    required this.chapters,
    required this.selectedChapter,
    required this.verses,
    required this.bookName,
    required this.onSelectChapter,
    required this.onProjectPassage,
    required this.onToggleBookmark,
    required this.activeVerse,
    required this.onSelectVerse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Chapter selector
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final ch = chapters[index];
              final isSelected = ch == selectedChapter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('$ch', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                  selected: isSelected,
                  onSelected: (_) => onSelectChapter(ch),
                  selectedColor: colorScheme.primary,
                  checkmarkColor: colorScheme.onPrimary,
                  labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimary : null),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
        // Chapter title
        if (selectedChapter != null && verses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chapter $selectedChapter',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.tv, size: 18),
                  label: const Text('Project'),
                  onPressed: () => onProjectPassage(selectedChapter!, verses),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        // Verse list
        Expanded(
          child: verses.isEmpty
              ? Center(
                  child: Text('Select a chapter', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: verses.length,
                  itemBuilder: (context, index) {
                    final v = verses[index];
                    final isActive = activeVerse?.id == v.id;
                    return Material(
                      color: isActive
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelectVerse(v),
                        onDoubleTap: () => onProjectPassage(v.chapter, [v]),
                        onLongPress: () => _showVerseMenu(context, v, onProjectPassage, onToggleBookmark),
                        onSecondaryTap: () => _showVerseMenu(context, v, onProjectPassage, onToggleBookmark),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${v.verse}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.7),
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  v.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.65,
                                    fontFamily: 'Inter',
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, right: 4),
                                  child: Icon(Icons.link, size: 14, color: colorScheme.primary),
                                ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                onSelected: (action) {
                                  if (action == 'project') {
                                    onProjectPassage(v.chapter, [v]);
                                  } else if (action == 'bookmark') {
                                    onToggleBookmark(v);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'project', child: ListTile(leading: Icon(Icons.tv, size: 18), title: Text('Project', style: TextStyle(fontSize: 13)), dense: true)),
                                  const PopupMenuItem(value: 'bookmark', child: ListTile(leading: Icon(Icons.bookmark_border, size: 18), title: Text('Bookmark', style: TextStyle(fontSize: 13)), dense: true)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static void _showVerseMenu(
    BuildContext context,
    BibleVerse verse,
    void Function(int chapter, List<BibleVerse> verses) onProject,
    void Function(BibleVerse) onBookmark,
  ) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox?.localToGlobal(renderBox.size.center(Offset.zero)) ?? Offset.zero;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(center.dx, center.dy, center.dx + 1, center.dy + 1),
      items: [
        const PopupMenuItem(value: 'project', child: ListTile(leading: Icon(Icons.tv, size: 18), title: Text('Project'), dense: true)),
        const PopupMenuItem(value: 'bookmark', child: ListTile(leading: Icon(Icons.bookmark_border, size: 18), title: Text('Bookmark'), dense: true)),
      ],
    ).then((action) {
      if (action == 'project') {
        onProject(verse.chapter, [verse]);
      } else if (action == 'bookmark') {
        onBookmark(verse);
      }
    });
  }
}

class _SearchResultsView extends StatelessWidget {
  final List<BibleVerse> results;
  final ValueChanged<BibleVerse> onProject;

  const _SearchResultsView({required this.results, required this.onProject});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final v = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(v.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(v.text, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.tv, size: 20),
              tooltip: 'Project',
              onPressed: () => onProject(v),
            ),
          ),
        );
      },
    );
  }
}

class _RightSidebar extends ConsumerWidget {
  const _RightSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);
    final setRepo = ref.read(setRepositoryProvider);

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cross-References section
          if (state.activeVerse != null) ...[
            _SidebarSectionHeader(
              icon: Icons.link,
              title: 'CROSS-REFERENCES',
              theme: theme,
            ),
            const Divider(height: 1),
            if (state.isLoadingCrossReferences)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (state.activeCrossReferences.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No cross references found for this verse.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              Expanded(
                flex: 2,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: state.activeCrossReferences.length,
                  itemBuilder: (context, index) {
                    final cr = state.activeCrossReferences[index];
                    return InkWell(
                      onTap: () => notifier.navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cr.reference,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cr.targetText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
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
          // Bookmarks section
          _SidebarSectionHeader(
            icon: Icons.bookmark,
            title: 'BOOKMARKS',
            theme: theme,
          ),
          const Divider(height: 1),
          Expanded(
            flex: state.activeVerse != null ? 3 : 1,
            child: FutureBuilder<List<BibleBookmark>>(
              future: setRepo.getBookmarks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No bookmarks yet.\nTap ⋮ on a verse to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                }
                final bookmarks = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final b = bookmarks[index];
                    return InkWell(
                      onTap: () {
                        notifier.navigateToVerse(b.bookId, b.chapter, b.verseNum);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.reference,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.verseText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeData theme;

  const _SidebarSectionHeader({
    required this.icon,
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
