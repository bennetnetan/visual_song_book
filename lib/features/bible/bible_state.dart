import 'package:visual_song_book/features/bible/bible_repository.dart';

const List<String> kBibleReadingFonts = ['EBGaramond', 'Lora', 'Inter'];
const String kBibleReadingFontDefault = 'Lora';

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
  final bool isLoadingVerses;
  final BibleVerse? activeVerse;
  final List<BibleCrossReference> activeCrossReferences;
  final bool isLoadingCrossReferences;

  // Batch bookmarks for current chapter
  final Set<int> bookmarkedVerseIds;

  // Multi-verse selection for projection
  final bool selectionMode;
  final Set<int> selectedVerseIds;

  // Reading customization
  final double bibleFontSize;
  final String readingFontFamily;

  // Recent books (book IDs)
  final List<int> recentBookIds;

  // Last read position
  final int? lastReadBookId;
  final int? lastReadChapter;
  final int? lastReadVerse;

  // Chapter verse counts (keyed by chapter number)
  final Map<int, int> chapterVerseCounts;

  // Recent search queries
  final List<String> recentSearches;

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
    this.isLoadingVerses = false,
    this.activeVerse,
    required this.activeCrossReferences,
    required this.isLoadingCrossReferences,
    this.bookmarkedVerseIds = const {},
    this.selectionMode = false,
    this.selectedVerseIds = const {},
    this.bibleFontSize = 19.0,
    this.readingFontFamily = kBibleReadingFontDefault,
    this.recentBookIds = const [],
    this.lastReadBookId,
    this.lastReadChapter,
    this.lastReadVerse,
    this.chapterVerseCounts = const {},
    this.recentSearches = const [],
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
    bool? isLoadingVerses,
    BibleVerse? Function()? activeVerse,
    List<BibleCrossReference>? activeCrossReferences,
    bool? isLoadingCrossReferences,
    Set<int>? bookmarkedVerseIds,
    bool? selectionMode,
    Set<int>? selectedVerseIds,
    double? bibleFontSize,
    String? readingFontFamily,
    List<int>? recentBookIds,
    int? Function()? lastReadBookId,
    int? Function()? lastReadChapter,
    int? Function()? lastReadVerse,
    Map<int, int>? chapterVerseCounts,
    List<String>? recentSearches,
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
      isLoadingVerses: isLoadingVerses ?? this.isLoadingVerses,
      activeVerse: activeVerse != null
          ? activeVerse()
          : this.activeVerse,
      activeCrossReferences: activeCrossReferences ?? this.activeCrossReferences,
      isLoadingCrossReferences: isLoadingCrossReferences ?? this.isLoadingCrossReferences,
      bookmarkedVerseIds: bookmarkedVerseIds ?? this.bookmarkedVerseIds,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedVerseIds: selectedVerseIds ?? this.selectedVerseIds,
      bibleFontSize: bibleFontSize ?? this.bibleFontSize,
      readingFontFamily: readingFontFamily ?? this.readingFontFamily,
      recentBookIds: recentBookIds ?? this.recentBookIds,
      lastReadBookId: lastReadBookId != null
          ? lastReadBookId()
          : this.lastReadBookId,
      lastReadChapter: lastReadChapter != null
          ? lastReadChapter()
          : this.lastReadChapter,
      lastReadVerse: lastReadVerse != null
          ? lastReadVerse()
          : this.lastReadVerse,
      chapterVerseCounts: chapterVerseCounts ?? this.chapterVerseCounts,
      recentSearches: recentSearches ?? this.recentSearches,
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
    isLoadingVerses: false,
    activeVerse: null,
    activeCrossReferences: [],
    isLoadingCrossReferences: false,
    bookmarkedVerseIds: const {},
    selectionMode: false,
    selectedVerseIds: const {},
    bibleFontSize: 15.0,
    readingFontFamily: kBibleReadingFontDefault,
    recentBookIds: const [],
    lastReadBookId: null,
    lastReadChapter: null,
    lastReadVerse: null,
    chapterVerseCounts: const {},
    recentSearches: const [],
  );
}
