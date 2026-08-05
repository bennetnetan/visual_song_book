import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class BibleNavigationDialog extends ConsumerStatefulWidget {
  const BibleNavigationDialog({super.key});

  @override
  ConsumerState<BibleNavigationDialog> createState() => _BibleNavigationDialogState();
}

class _BibleNavigationDialogState extends ConsumerState<BibleNavigationDialog> {
  String _tab = 'book';
  int? _tempBookId;
  String _tempBookName = '';
  List<int> _tempChapters = [];
  int? _tempChapter;
  List<int> _tempVerses = [];
  String _bookFilter = '';
  Map<int, int> _tempVerseCounts = {};

  @override
  void initState() {
    super.initState();
    final state = ref.read(bibleControllerProvider);
    _tempBookId = state.selectedBookId;
    if (_tempBookId != null) {
      final bk = state.books.where((b) => b.id == _tempBookId).firstOrNull;
      if (bk != null) {
        _tempBookName = bk.name;
        _tempChapters = state.chapters;
        _tempChapter = state.selectedChapter;
        _tempVerseCounts = state.chapterVerseCounts;
        if (_tempChapter != null) {
          _fetchVersesForInit(_tempBookId!, _tempChapter!);
        }
      }
    }
  }

  void _fetchVersesForInit(int bookId, int chapter) async {
    final verses = await ref.read(bibleRepositoryProvider).getVerses(bookId, chapter);
    if (mounted) {
      setState(() {
        _tempVerses = verses.map((v) => v.verse).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bibleControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final otBooks = state.books.where((b) => b.id <= 39).toList();
    final ntBooks = state.books.where((b) => b.id > 39).toList();

    final filteredOt = otBooks
        .where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase()))
        .toList();
    final filteredNt = ntBooks
        .where((b) => b.name.toLowerCase().contains(_bookFilter.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'BIBLE NAVIGATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                          child: Text('Book',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      selected: _tab == 'book',
                      onSelected: (val) {
                        if (val) setState(() => _tab = 'book');
                      },
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _tempBookId == null ? 'Chapter' : _tempBookName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'chapter',
                      onSelected: _tempBookId == null
                          ? null
                          : (val) {
                              if (val) setState(() => _tab = 'chapter');
                            },
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _tempChapter == null ? 'Verse' : 'Ch $_tempChapter',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _tab == 'verse',
                      onSelected: (_tempBookId == null || _tempChapter == null)
                          ? null
                          : (val) {
                              if (val) setState(() => _tab = 'verse');
                            },
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
            ),
            if (_tab == 'book')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search books...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _bookFilter = val),
                ),
              ),
            Expanded(
              child: _tab == 'book'
                  ? _buildBookSelector(filteredOt, filteredNt, colorScheme)
                  : _tab == 'chapter'
                      ? _buildChapterSelector(colorScheme)
                      : _buildVerseSelector(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSelector(List<BibleBook> ot, List<BibleBook> nt, ColorScheme colorScheme) {
    final recentBookIds = ref.read(bibleControllerProvider).recentBookIds;
    final recentBooks = recentBookIds
        .map((id) => ref.read(bibleControllerProvider).books.where((b) => b.id == id).firstOrNull)
        .whereType<BibleBook>()
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (recentBooks.isNotEmpty && _bookFilter.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recentBooks.map((b) {
              return ActionChip(
                label: Text(b.name,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: () => _selectBook(b),
                backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (ot.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'OLD TESTAMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.primary,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: ot.length,
            itemBuilder: (context, i) {
              final b = ot[i];
              final isSelected = b.id == _tempBookId;
              return _BookGridItem(
                name: b.name,
                isSelected: isSelected,
                onTap: () => _selectBook(b),
                colorScheme: colorScheme,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (nt.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'NEW TESTAMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.primary,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: nt.length,
            itemBuilder: (context, i) {
              final b = nt[i];
              final isSelected = b.id == _tempBookId;
              return _BookGridItem(
                name: b.name,
                isSelected: isSelected,
                onTap: () => _selectBook(b),
                colorScheme: colorScheme,
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Future<void> _selectBook(BibleBook b) async {
    final chapters = await ref.read(bibleRepositoryProvider).getChapters(b.id);
    final verseCounts = await ref.read(bibleRepositoryProvider).getChapterVerseCounts(b.id);
    setState(() {
      _tempBookId = b.id;
      _tempBookName = b.name;
      _tempChapters = chapters;
      _tempVerseCounts = verseCounts;
      _tempChapter = null;
      _tempVerses = [];
      _tab = 'chapter';
    });
  }

  Future<void> _selectChapter(int ch) async {
    final verses = await ref.read(bibleRepositoryProvider).getVerses(_tempBookId!, ch);
    if (mounted) {
      setState(() {
        _tempChapter = ch;
        _tempVerses = verses.map((v) => v.verse).toList();
        _tab = 'verse';
      });
    }
  }

  Widget _buildChapterSelector(ColorScheme colorScheme) {
    if (_tempBookId == null) {
      return const Center(child: Text('Please select a book first'));
    }

    final displayChapters =
        _tempChapters.isNotEmpty ? _tempChapters : List.generate(50, (index) => index + 1);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayChapters.length,
      itemBuilder: (context, i) {
        final ch = displayChapters[i];
        final verseCount = _tempVerseCounts[ch];
        return InkWell(
          onTap: () => _selectChapter(ch),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$ch',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (verseCount != null)
                  Text(
                    '$verseCount',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseSelector(ColorScheme colorScheme) {
    if (_tempBookId == null || _tempChapter == null) {
      return const Center(child: Text('Please select book and chapter first'));
    }

    final displayVerses =
        _tempVerses.isNotEmpty ? _tempVerses : List.generate(50, (index) => index + 1);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayVerses.length,
      itemBuilder: (context, i) {
        final v = displayVerses[i];
        return InkWell(
          onTap: () {
            ref.read(bibleControllerProvider.notifier).navigateToVerse(_tempBookId!, _tempChapter!, v);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$v',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _BookGridItem({
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
