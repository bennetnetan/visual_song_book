import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';
import 'package:visual_song_book/features/bible/bible_state.dart';

export 'package:visual_song_book/features/bible/bible_state.dart' show BibleState;

class BibleController extends StateNotifier<BibleState> {
  final BibleRepository _repo;

  BibleController(this._repo) : super(BibleState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final books = await _repo.getBooks();
    if (mounted) {
      state = state.copyWith(books: books, isLoaded: true, isLoading: false);
      final genesis = books.where((b) => b.name.toLowerCase() == 'genesis').firstOrNull;
      if (genesis != null) {
        await navigateToVerse(genesis.id, 1, 1);
      }
    }
  }

  Future<void> selectBook(int bookId) async {
    state = state.copyWith(
      selectedBookId: () => bookId,
      selectedChapter: () => null,
      verses: [],
      query: '',
      activeVerse: () => null,
      activeCrossReferences: [],
    );
    final chapters = await _repo.getChapters(bookId);
    if (mounted) state = state.copyWith(chapters: chapters);
  }

  Future<void> selectChapter(int chapter) async {
    state = state.copyWith(
      selectedChapter: () => chapter,
      query: '',
      activeVerse: () => null,
      activeCrossReferences: [],
    );
    final bookId = state.selectedBookId;
    if (bookId == null) return;
    final verses = await _repo.getVerses(bookId, chapter);
    if (mounted) state = state.copyWith(verses: verses);
  }

  Future<void> selectVerse(BibleVerse verse) async {
    state = state.copyWith(
      activeVerse: () => verse,
      isLoadingCrossReferences: true,
      activeCrossReferences: [],
    );
    final refs = await _repo.getCrossReferences(verse.bookId, verse.chapter, verse.verse);
    if (mounted) {
      state = state.copyWith(
        activeCrossReferences: refs,
        isLoadingCrossReferences: false,
      );
    }
  }

  Future<void> navigateToVerse(int bookId, int chapter, int verse) async {
    await selectBook(bookId);
    await selectChapter(chapter);
    final v = await _repo.getVerseByRef(bookId, chapter, verse);
    if (v != null && mounted) {
      await selectVerse(v);
    }
  }

  Future<void> search(String query) async {
    final normalized = normalizeSearchQuery(query);
    state = state.copyWith(
      query: query,
      searchResults: [],
      totalSearchCount: 0,
      searchOffset: 0,
      exactMatch: () => null,
    );
    if (normalized.isEmpty) return;

    // Try structured reference: "gen 1:1", "1jn 5:4", "jn 3:16", "ps 23:1", "rev 2:1"
    BibleVerse? exact;
    final ref = parseBibleReference(normalized);
    if (ref != null) {
      exact = await _repo.getVerseByRef(ref.bookId, ref.chapter, ref.verse);
    }

    if (exact != null && mounted) {
      state = state.copyWith(exactMatch: () => exact);
    }

    // Full-text search — count all matches, then load first page
    final total = await _repo.countSearchResults(normalized);
    final results = await _repo.searchVersesPaginated(normalized, 10, 0);
    if (mounted) {
      final filtered = results.where((v) => v.id != exact?.id).toList();
      state = state.copyWith(
        searchResults: filtered,
        totalSearchCount: total,
        searchOffset: filtered.length,
      );
    }
  }

  Future<void> loadMore() async {
    final normalized = normalizeSearchQuery(state.query);
    if (normalized.isEmpty) return;
    final results = await _repo.searchVersesPaginated(normalized, 10, state.searchOffset);
    if (!mounted) return;
    final exact = state.exactMatch;
    final filtered = results.where((v) => v.id != exact?.id).toList();
    if (filtered.isEmpty) return;
    state = state.copyWith(
      searchResults: [...state.searchResults, ...filtered],
      searchOffset: state.searchOffset + filtered.length,
    );
  }

  void clearSearch() {
    state = state.copyWith(
      query: '',
      searchResults: [],
      totalSearchCount: 0,
      searchOffset: 0,
      exactMatch: () => null,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedBookId: () => null,
      selectedChapter: () => null,
      chapters: [],
      verses: [],
      searchResults: [],
      totalSearchCount: 0,
      searchOffset: 0,
      exactMatch: () => null,
      query: '',
      activeVerse: () => null,
      activeCrossReferences: [],
    );
  }

  Future<void> nextChapter() async {
    final bookId = state.selectedBookId;
    final chapter = state.selectedChapter;
    if (bookId == null || chapter == null) return;

    final nextChapter = chapter + 1;
    if (state.chapters.contains(nextChapter)) {
      await selectChapter(nextChapter);
    } else {
      final currentIdx = state.books.indexWhere((b) => b.id == bookId);
      final nextIdx = currentIdx + 1;
      if (nextIdx >= 0 && nextIdx < state.books.length) {
        final nextBook = state.books[nextIdx];
        await selectBook(nextBook.id);
        await selectChapter(1);
      }
    }
  }

  Future<void> prevChapter() async {
    final bookId = state.selectedBookId;
    final chapter = state.selectedChapter;
    if (bookId == null || chapter == null) return;

    final prevChapter = chapter - 1;
    if (state.chapters.contains(prevChapter)) {
      await selectChapter(prevChapter);
    } else {
      final currentIdx = state.books.indexWhere((b) => b.id == bookId);
      final prevIdx = currentIdx - 1;
      if (prevIdx >= 0 && prevIdx < state.books.length) {
        final prevBook = state.books[prevIdx];
        await selectBook(prevBook.id);
        final chs = await _repo.getChapters(prevBook.id);
        if (chs.isNotEmpty) {
          await selectChapter(chs.last);
        }
      }
    }
  }
}
