import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';

class BibleState {
  final List<BibleBook> books;
  final int? selectedBookId;
  final List<int> chapters;
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final List<BibleVerse> searchResults;
  final int totalSearchCount;
  final int searchOffset;
  final BibleVerse? exactMatch;
  final String query;
  final bool isLoaded;
  final bool isLoading;
  final BibleVerse? activeVerse;
  final List<BibleCrossReference> activeCrossReferences;
  final bool isLoadingCrossReferences;

  BibleState({
    required this.books,
    this.selectedBookId,
    required this.chapters,
    this.selectedChapter,
    required this.verses,
    required this.searchResults,
    this.totalSearchCount = 0,
    this.searchOffset = 0,
    this.exactMatch,
    required this.query,
    required this.isLoaded,
    required this.isLoading,
    this.activeVerse,
    required this.activeCrossReferences,
    required this.isLoadingCrossReferences,
  });

  BibleState copyWith({
    List<BibleBook>? books,
    int? Function()? selectedBookId,
    List<int>? chapters,
    int? Function()? selectedChapter,
    List<BibleVerse>? verses,
    List<BibleVerse>? searchResults,
    int? totalSearchCount,
    int? searchOffset,
    BibleVerse? Function()? exactMatch,
    String? query,
    bool? isLoaded,
    bool? isLoading,
    BibleVerse? Function()? activeVerse,
    List<BibleCrossReference>? activeCrossReferences,
    bool? isLoadingCrossReferences,
  }) {
    return BibleState(
      books: books ?? this.books,
      selectedBookId: selectedBookId != null
          ? selectedBookId()
          : this.selectedBookId,
      chapters: chapters ?? this.chapters,
      selectedChapter: selectedChapter != null
          ? selectedChapter()
          : this.selectedChapter,
      verses: verses ?? this.verses,
      searchResults: searchResults ?? this.searchResults,
      totalSearchCount: totalSearchCount ?? this.totalSearchCount,
      searchOffset: searchOffset ?? this.searchOffset,
      exactMatch: exactMatch != null ? exactMatch() : this.exactMatch,
      query: query ?? this.query,
      isLoaded: isLoaded ?? this.isLoaded,
      isLoading: isLoading ?? this.isLoading,
      activeVerse: activeVerse != null
          ? activeVerse()
          : this.activeVerse,
      activeCrossReferences: activeCrossReferences ?? this.activeCrossReferences,
      isLoadingCrossReferences: isLoadingCrossReferences ?? this.isLoadingCrossReferences,
    );
  }

  factory BibleState.initial() => BibleState(
    books: [],
    chapters: [],
    verses: [],
    searchResults: [],
    totalSearchCount: 0,
    searchOffset: 0,
    exactMatch: null,
    query: '',
    isLoaded: false,
    isLoading: true,
    activeVerse: null,
    activeCrossReferences: [],
    isLoadingCrossReferences: false,
  );
}



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
}
