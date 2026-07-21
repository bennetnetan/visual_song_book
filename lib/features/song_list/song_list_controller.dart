import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/bundled_json_importer.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

enum SongSortMode { byNumber, byTitle, byKey }

class SongListState {
  final String query;
  final int?
  selectedCategoryId; // null means "All" or "Uncategorized" depending on boolean, let's use -1 for uncategorized
  final bool showUncategorizedOnly;
  final List<Song> songs;
  final List<Category> categories;
  final bool isLoading;
  final String? error;
  final SongSortMode sortMode;

  SongListState({
    required this.query,
    required this.selectedCategoryId,
    required this.showUncategorizedOnly,
    required this.songs,
    required this.categories,
    required this.isLoading,
    required this.error,
    required this.sortMode,
  });

  SongListState copyWith({
    String? query,
    int? selectedCategoryId,
    bool? showUncategorizedOnly,
    List<Song>? songs,
    List<Category>? categories,
    bool? isLoading,
    String? error,
    SongSortMode? sortMode,
  }) {
    return SongListState(
      query: query ?? this.query,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      showUncategorizedOnly:
          showUncategorizedOnly ?? this.showUncategorizedOnly,
      songs: songs ?? this.songs,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  factory SongListState.initial() {
    return SongListState(
      query: '',
      selectedCategoryId: -2, // -2 for All
      showUncategorizedOnly: false,
      songs: [],
      categories: [],
      isLoading: true,
      error: null,
      sortMode: SongSortMode.byNumber,
    );
  }
}

class SongListController extends StateNotifier<SongListState> {
  final SongRepository _repository;
  StreamSubscription<List<Category>>? _categoriesSub;
  StreamSubscription<List<Song>>? _songsSub;
  StreamSubscription<List<Song>>? _dbChangesSub;
  Timer? _debounceTimer;

  SongListController(this._repository) : super(SongListState.initial()) {
    _init();
    checkAndImportDefaultSongbooks();
  }

  /// Automatically imports bundled default songbooks on first launch (empty DB).
  /// Uses pre-exported JSON files from Flutter assets — works on ALL platforms
  /// (Android, iOS, desktop, web) without needing any external tools.
  Future<void> checkAndImportDefaultSongbooks({bool force = false}) async {
    try {
      // Only run when the database is completely empty, unless forced
      if (!force) {
        final songs = await _repository.getSongs();
        if (songs.isNotEmpty) return;
      }

      const bundledBooks = [
        {
          'asset': 'assets/songbooks/data/full_song_book.json',
          'name': 'Full Song Book',
        },
        {
          'asset': 'assets/songbooks/data/injili_song_book.json',
          'name': 'Injili Song Book',
        },
      ];

      final importer = BundledJsonImporter(_repository.db);

      state = state.copyWith(
        isLoading: true,
        error: 'Loading default song books...',
      );

      int totalImported = 0;

      for (final book in bundledBooks) {
        try {
          final result = await importer.importFromAsset(
            book['asset']!,
            bookName: book['name']!,
          );
          if (result.success) totalImported += result.songsAdded;
        } catch (_) {
          // Skip individual books that fail — don't abort the whole process
        }
      }

      state = state.copyWith(isLoading: false, error: null);
      if (totalImported > 0) fetchSongs();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: null);
    }
  }

  void _init() {
    // Watch categories to keep them up to date in the UI
    _categoriesSub = _repository.watchCategories().listen(
      (categoriesList) {
        state = state.copyWith(categories: categoriesList);
        fetchSongs();
      },
      onError: (err) {
        state = state.copyWith(error: err.toString());
      },
    );

    // Watch all songs to refresh search queries when database changes
    _dbChangesSub = _repository.watchSongs().listen((_) {
      if (state.query.isNotEmpty) {
        fetchSongs();
      }
    });
  }

  /// Sets the search query with a short debounce to avoid querying SQLite on every keystroke
  void setQuery(String newQuery) {
    if (state.query == newQuery) return;
    state = state.copyWith(query: newQuery);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      fetchSongs();
    });
  }

  /// Sets the selected category
  void selectCategory(int? categoryId, {bool uncategorizedOnly = false}) {
    if (state.selectedCategoryId == categoryId &&
        state.showUncategorizedOnly == uncategorizedOnly)
      return;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      showUncategorizedOnly: uncategorizedOnly,
    );
    fetchSongs();
  }

  /// Sets the sort mode
  void setSortMode(SongSortMode mode) {
    if (state.sortMode == mode) return;
    state = state.copyWith(sortMode: mode);
    fetchSongs();
  }

  Future<void> deleteCategory(int categoryId) async {
    await _repository.deleteCategory(categoryId);
    if (state.selectedCategoryId == categoryId) {
      state = state.copyWith(selectedCategoryId: null);
    }
    fetchSongs();
  }

  Future<void> fetchSongs() async {
    state = state.copyWith(isLoading: true);
    try {
      _songsSub?.cancel();

      // If there's a search query, search across all songs (ignoring category tab briefly, or filtering it)
      if (state.query.isNotEmpty) {
        final results = await _repository.searchSongs(state.query);

        // Filter search results locally based on selected category if necessary
        List<Song> filtered = results;
        if (state.showUncategorizedOnly) {
          filtered = results.where((s) => s.categoryId == null).toList();
        } else if (state.selectedCategoryId != null &&
            state.selectedCategoryId != -2) {
          filtered = results
              .where((s) => s.categoryId == state.selectedCategoryId)
              .toList();
        }

        // Apply manual sorting to search results
        _sortList(filtered);

        state = state.copyWith(songs: filtered, isLoading: false);
      } else {
        // No search query: listen to direct streams for real-time updates when editing/adding songs
        state = state.copyWith(isLoading: false);

        Stream<List<Song>> stream;
        if (state.showUncategorizedOnly) {
          stream = _repository.watchSongsByCategory(null);
        } else if (state.selectedCategoryId != null &&
            state.selectedCategoryId != -2) {
          stream = _repository.watchSongsByCategory(state.selectedCategoryId);
        } else {
          stream = _repository.watchSongs();
        }

        _songsSub = stream.listen((songsList) {
          final sortedList = List<Song>.from(songsList);
          _sortList(sortedList);
          state = state.copyWith(songs: sortedList);
        });
      }
    } catch (e) {
      state = state.copyWith(songs: [], isLoading: false, error: e.toString());
    }
  }

  void _sortList(List<Song> list) {
    switch (state.sortMode) {
      case SongSortMode.byNumber:
        list.sort((a, b) => a.songNum.compareTo(b.songNum));
        break;
      case SongSortMode.byTitle:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SongSortMode.byKey:
        list.sort((a, b) {
          if (a.key == null && b.key == null)
            return a.songNum.compareTo(b.songNum);
          if (a.key == null) return 1;
          if (b.key == null) return -1;
          return a.key!.compareTo(b.key!);
        });
        break;
    }
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _songsSub?.cancel();
    _dbChangesSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final songListControllerProvider =
    StateNotifierProvider<SongListController, SongListState>((ref) {
      final repo = ref.watch(songRepositoryProvider);
      return SongListController(repo);
    });
