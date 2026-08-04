import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
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
  final List<({String path, int count})> sourcePaths;
  final String? selectedSourcePath;
  final SourceMode selectedSourceMode;
  final bool isLoading;
  final String? error;
  final SongSortMode sortMode;

  SongListState({
    required this.query,
    required this.selectedCategoryId,
    required this.showUncategorizedOnly,
    required this.songs,
    required this.categories,
    required this.sourcePaths,
    this.selectedSourcePath,
    this.selectedSourceMode = SourceMode.unified,
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
    List<({String path, int count})>? sourcePaths,
    String? selectedSourcePath,
    bool? clearSourcePath = false,
    SourceMode? selectedSourceMode,
    bool? clearSourceMode = false,
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
      sourcePaths: sourcePaths ?? this.sourcePaths,
      selectedSourcePath: clearSourcePath == true
          ? null
          : (selectedSourcePath ?? this.selectedSourcePath),
      selectedSourceMode: clearSourceMode == true
          ? SourceMode.unified
          : (selectedSourceMode ?? this.selectedSourceMode),
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
      sourcePaths: [],
      selectedSourcePath: null,
      selectedSourceMode: SourceMode.unified,
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
  }

  /// Re-imports the bundled songbooks (useful for debugging / manual re-seed).
  Future<void> reimportBundledSongbooks() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final importer = BundledJsonImporter(_repository.db);
      const bundledBooks = [
        ('assets/songbooks/data/full_song_book.json', 'Full Song Book'),
        ('assets/songbooks/data/injili_song_book.json', 'Injili Song Book'),
      ];
      for (final (asset, name) in bundledBooks) {
        await importer.importFromAsset(asset, bookName: name);
      }
      state = state.copyWith(isLoading: false);
      fetchSongs();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

    // Watch all songs to refresh search queries and source paths when database changes
    _dbChangesSub = _repository.watchSongs().listen((_) {
      _loadSourcePaths();
      if (state.query.isNotEmpty) {
        fetchSongs();
      }
    });

    // Load source paths
    _loadSourcePaths();
  }

  Future<void> _loadSourcePaths() async {
    try {
      final paths = await _repository.getSourcePathCounts();
      state = state.copyWith(sourcePaths: paths);
    } catch (_) {
      // Source paths are optional - don't fail if the query doesn't work
    }
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
        state.showUncategorizedOnly == uncategorizedOnly) {
      return;
    }
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

  /// Sets the selected source path filter (null = all sources)
  void selectSource(String? sourcePath) {
    if (state.selectedSourcePath == sourcePath) return;
    state = state.copyWith(
      selectedSourcePath: sourcePath,
      clearSourcePath: sourcePath == null,
    );
    fetchSongs();
  }

  /// Sets the source mode filter (bundled, linked, or unified)
  void setSourceMode(SourceMode mode) {
    if (state.selectedSourceMode == mode) return;
    state = state.copyWith(selectedSourceMode: mode);
    fetchSongs();
  }

  Future<void> deleteCategory(int categoryId) async {
    await _repository.deleteCategory(categoryId);
    if (state.selectedCategoryId == categoryId) {
      selectCategory(-2);
    } else {
      fetchSongs();
    }
  }

  Future<void> fetchSongs() async {
    state = state.copyWith(isLoading: true);
    try {
      _songsSub?.cancel();

      // If there's a search query, search across all songs (ignoring category tab briefly, or filtering it)
      if (state.query.isNotEmpty) {
        final results = await _repository.searchSongs(
          state.query,
          sourcePath: state.selectedSourcePath,
          sourceMode: state.selectedSourceMode,
        );

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
          stream = _repository.watchSongsByCategory(
            null,
            sourcePath: state.selectedSourcePath,
            sourceMode: state.selectedSourceMode,
          );
        } else if (state.selectedCategoryId != null &&
            state.selectedCategoryId != -2) {
          stream = _repository.watchSongsByCategory(
            state.selectedCategoryId,
            sourcePath: state.selectedSourcePath,
            sourceMode: state.selectedSourceMode,
          );
        } else {
          stream = _repository.watchSongsFiltered(
            sourcePath: state.selectedSourcePath,
            sourceMode: state.selectedSourceMode,
          );
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
          if (a.key == null && b.key == null) {
            return a.songNum.compareTo(b.songNum);
          }
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
