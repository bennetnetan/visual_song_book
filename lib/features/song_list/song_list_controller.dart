import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

class SongListState {
  final String query;
  final int? selectedCategoryId; // null means "All" or "Uncategorized" depending on boolean, let's use -1 for uncategorized
  final bool showUncategorizedOnly;
  final List<Song> songs;
  final List<Category> categories;
  final bool isLoading;
  final String? error;

  SongListState({
    required this.query,
    required this.selectedCategoryId,
    required this.showUncategorizedOnly,
    required this.songs,
    required this.categories,
    required this.isLoading,
    required this.error,
  });

  SongListState copyWith({
    String? query,
    int? selectedCategoryId,
    bool? showUncategorizedOnly,
    List<Song>? songs,
    List<Category>? categories,
    bool? isLoading,
    String? error,
  }) {
    return SongListState(
      query: query ?? this.query,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      showUncategorizedOnly: showUncategorizedOnly ?? this.showUncategorizedOnly,
      songs: songs ?? this.songs,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  factory SongListState.initial() {
    return SongListState(
      query: '',
      selectedCategoryId: null,
      showUncategorizedOnly: false,
      songs: [],
      categories: [],
      isLoading: true,
      error: null,
    );
  }
}

class SongListController extends StateNotifier<SongListState> {
  final SongRepository _repository;
  StreamSubscription<List<Category>>? _categoriesSub;
  StreamSubscription<List<Song>>? _songsSub;
  Timer? _debounceTimer;

  SongListController(this._repository) : super(SongListState.initial()) {
    _init();
  }

  void _init() {
    // Watch categories to keep them up to date in the UI
    _categoriesSub = _repository.watchCategories().listen((categoriesList) {
      state = state.copyWith(categories: categoriesList);
      fetchSongs();
    }, onError: (err) {
      state = state.copyWith(error: err.toString());
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
    if (state.selectedCategoryId == categoryId && state.showUncategorizedOnly == uncategorizedOnly) return;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      showUncategorizedOnly: uncategorizedOnly,
    );
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
        } else if (state.selectedCategoryId != null) {
          filtered = results.where((s) => s.categoryId == state.selectedCategoryId).toList();
        }

        state = state.copyWith(songs: filtered, isLoading: false);
      } else {
        // No search query: listen to direct streams for real-time updates when editing/adding songs
        state = state.copyWith(isLoading: false);
        if (state.showUncategorizedOnly) {
          _songsSub = _repository.watchSongsByCategory(null).listen((songsList) {
            state = state.copyWith(songs: songsList);
          });
        } else if (state.selectedCategoryId != null) {
          _songsSub = _repository.watchSongsByCategory(state.selectedCategoryId).listen((songsList) {
            state = state.copyWith(songs: songsList);
          });
        } else {
          _songsSub = _repository.watchSongs().listen((songsList) {
            state = state.copyWith(songs: songsList);
          });
        }
      }
    } catch (e) {
      state = state.copyWith(songs: [], isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _songsSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final songListControllerProvider = StateNotifierProvider<SongListController, SongListState>((ref) {
  final repo = ref.watch(songRepositoryProvider);
  return SongListController(repo);
});
