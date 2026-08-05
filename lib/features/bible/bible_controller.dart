import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';
import 'package:visual_song_book/features/bible/bible_state.dart';

export 'package:visual_song_book/features/bible/bible_state.dart' show BibleState;

class BibleController extends StateNotifier<BibleState> {
  final BibleRepository _repo;
  final SetRepository _setRepo;

  static const _recentBooksKey = 'bible_recent_books';
  static const _recentSearchesKey = 'bible_recent_searches';
  static const _fontSizeKey = 'bible_font_size';
  static const _readingFontKey = 'bible_reading_font';
  static const _lastReadBookKey = 'bible_last_read_book';
  static const _lastReadChapterKey = 'bible_last_read_chapter';
  static const _lastReadVerseKey = 'bible_last_read_verse';
  static const _maxRecentBooks = 5;
  static const _maxRecentSearches = 8;

  BibleController(this._repo, this._setRepo) : super(BibleState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final books = await _repo.getBooks();
    final prefs = await SharedPreferences.getInstance();
    final recentBookIds = prefs.getStringList(_recentBooksKey)?.map(int.parse).toList() ?? [];
    final recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    final fontSize = prefs.getDouble(_fontSizeKey) ?? 15.0;
    final readingFontFamily =
        prefs.getString(_readingFontKey) ?? kBibleReadingFontDefault;
    final lastReadBook = prefs.getInt(_lastReadBookKey);
    final lastReadChapter = prefs.getInt(_lastReadChapterKey);
    final lastReadVerse = prefs.getInt(_lastReadVerseKey);

    if (mounted) {
      state = state.copyWith(
        books: books,
        isLoaded: true,
        isLoading: false,
        recentBookIds: recentBookIds,
        recentSearches: recentSearches,
        bibleFontSize: fontSize,
        readingFontFamily: readingFontFamily,
        lastReadBookId: () => lastReadBook,
        lastReadChapter: () => lastReadChapter,
        lastReadVerse: () => lastReadVerse,
      );

      final hasLastRead =
          lastReadBook != null &&
          lastReadChapter != null &&
          books.any((b) => b.id == lastReadBook);
      if (hasLastRead) {
        // Leave the reader empty so the "Continue Reading" card is visible.
        return;
      }

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
      selectionMode: false,
      selectedVerseIds: {},
      isLoadingVerses: true,
    );
    final chapters = await _repo.getChapters(bookId);
    final verseCounts = await _repo.getChapterVerseCounts(bookId);
    await _addRecentBook(bookId);
    if (mounted) {
      state = state.copyWith(
        chapters: chapters,
        chapterVerseCounts: verseCounts,
        isLoadingVerses: false,
      );
    }
  }

  Future<void> selectChapter(int chapter) async {
    state = state.copyWith(
      selectedChapter: () => chapter,
      query: '',
      activeVerse: () => null,
      activeCrossReferences: [],
      selectionMode: false,
      selectedVerseIds: {},
      isLoadingVerses: true,
    );
    final bookId = state.selectedBookId;
    if (bookId == null) return;
    final verses = await _repo.getVerses(bookId, chapter);
    final bookmarked = await _setRepo.getBookmarkedVerseIdsForChapter(bookId, chapter);
    if (mounted) {
      state = state.copyWith(
        verses: verses,
        bookmarkedVerseIds: bookmarked,
        isLoadingVerses: false,
        lastReadBookId: () => bookId,
        lastReadChapter: () => chapter,
      );
    }
    await _persistLastRead(bookId, chapter);
  }

  Future<void> selectVerse(BibleVerse verse) async {
    state = state.copyWith(
      activeVerse: () => verse,
      isLoadingCrossReferences: true,
      activeCrossReferences: [],
      lastReadBookId: () => verse.bookId,
      lastReadChapter: () => verse.chapter,
      lastReadVerse: () => verse.verse,
    );
    final refs = await _repo.getCrossReferences(verse.bookId, verse.chapter, verse.verse);
    if (mounted) {
      state = state.copyWith(
        activeCrossReferences: refs,
        isLoadingCrossReferences: false,
      );
    }
    await _persistLastRead(verse.bookId, verse.chapter, verse.verse);
  }

  Future<void> _persistLastRead(int bookId, int chapter, [int? verse]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadBookKey, bookId);
    await prefs.setInt(_lastReadChapterKey, chapter);
    if (verse != null) {
      await prefs.setInt(_lastReadVerseKey, verse);
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

    BibleVerse? exact;
    final ref = parseBibleReference(normalized);
    if (ref != null) {
      exact = await _repo.getVerseByRef(ref.bookId, ref.chapter, ref.verse);
    }

    if (exact != null && mounted) {
      state = state.copyWith(exactMatch: () => exact);
    }

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

    if (query.trim().isNotEmpty) {
      await _addRecentSearch(query.trim());
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
      selectionMode: false,
      selectedVerseIds: {},
      bookmarkedVerseIds: {},
      chapterVerseCounts: {},
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

  // --- Selection mode ---

  void toggleSelectionMode() {
    if (state.selectionMode) {
      state = state.copyWith(selectionMode: false, selectedVerseIds: {});
    } else {
      state = state.copyWith(selectionMode: true);
    }
  }

  void toggleVerseSelection(int verseId) {
    final current = Set<int>.from(state.selectedVerseIds);
    if (current.contains(verseId)) {
      current.remove(verseId);
    } else {
      current.add(verseId);
    }
    state = state.copyWith(selectedVerseIds: current);
  }

  void selectAllVerses() {
    state = state.copyWith(
      selectedVerseIds: state.verses.map((v) => v.id).toSet(),
    );
  }

  // --- Bookmarks (batch) ---

  Future<void> toggleBookmark(BibleVerse verse) async {
    final isMarked = state.bookmarkedVerseIds.contains(verse.verse);
    if (isMarked) {
      await _setRepo.removeBookmarkByVerse(verse.bookId, verse.chapter, verse.verse);
    } else {
      await _setRepo.addBookmark(
        verse.bookId, verse.chapter, verse.verse,
        verse.reference, verse.text, verse.bookName ?? '',
      );
    }

    final bookId = state.selectedBookId;
    final chapter = state.selectedChapter;
    if (bookId != null && chapter != null) {
      final bookmarked = await _setRepo.getBookmarkedVerseIdsForChapter(bookId, chapter);
      if (mounted) state = state.copyWith(bookmarkedVerseIds: bookmarked);
    }
  }

  // --- Reading settings ---

  Future<void> setBibleFontSize(double size) async {
    state = state.copyWith(bibleFontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  Future<void> setReadingFontFamily(String family) async {
    if (!kBibleReadingFonts.contains(family)) return;
    state = state.copyWith(readingFontFamily: family);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readingFontKey, family);
  }

  // --- Recent books ---

  Future<void> _addRecentBook(int bookId) async {
    final current = List<int>.from(state.recentBookIds);
    current.remove(bookId);
    current.insert(0, bookId);
    final trimmed = current.take(_maxRecentBooks).toList();
    state = state.copyWith(recentBookIds: trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentBooksKey, trimmed.map((id) => id.toString()).toList());
  }

  // --- Recent searches ---

  Future<void> _addRecentSearch(String query) async {
    final current = List<String>.from(state.recentSearches);
    current.remove(query);
    current.insert(0, query);
    final trimmed = current.take(_maxRecentSearches).toList();
    state = state.copyWith(recentSearches: trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, trimmed);
  }

  Future<void> clearRecentSearches() async {
    state = state.copyWith(recentSearches: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}

final bibleControllerProvider =
    StateNotifierProvider<BibleController, BibleState>((ref) {
      final repo = ref.watch(bibleRepositoryProvider);
      final setRepo = ref.watch(setRepositoryProvider);
      return BibleController(repo, setRepo);
    });
