import 'package:visual_song_book/features/bible/bible_repository.dart';

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
