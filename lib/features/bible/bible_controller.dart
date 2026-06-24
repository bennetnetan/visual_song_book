import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class BibleState {
  final List<BibleBook> books;
  final int? selectedBookId;
  final List<int> chapters;
  final int? selectedChapter;
  final List<BibleVerse> verses;
  final List<BibleVerse> searchResults;
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
    state = state.copyWith(query: query, searchResults: []);
    if (query.trim().isEmpty) return;
    final results = await _repo.searchVerses(query);
    if (mounted) state = state.copyWith(searchResults: results);
  }

  void clearSelection() {
    state = state.copyWith(
      selectedBookId: () => null,
      selectedChapter: () => null,
      chapters: [],
      verses: [],
      searchResults: [],
      query: '',
      activeVerse: () => null,
      activeCrossReferences: [],
    );
  }
}
