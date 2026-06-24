import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/mdb_tools_importer.dart';
import 'package:visual_song_book/data/importers/vsb_importer.dart';
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
  Timer? _debounceTimer;

  SongListController(this._repository) : super(SongListState.initial()) {
    _init();
    checkAndImportDefaultSongbooks();
  }

  /// Automatically imports bundled default songbooks on first launch (empty DB).
  /// Extracts each .vsb from Flutter assets to a temp file and imports via MdbToolsImporter.
  /// On mobile/web (where mdb-tools is unavailable), this is silently skipped.
  Future<void> checkAndImportDefaultSongbooks({bool force = false}) async {
    try {
      // Only run when the database is completely empty, unless forced
      if (!force) {
        final songs = await _repository.getSongs();
        if (songs.isNotEmpty) return;
      }

      const bundledSongbooks = [
        'assets/songbooks/Full Song Book.vsb',
        'assets/songbooks/Injili Song Book.vsb',
      ];

      final importer = MdbToolsImporter(_repository.db);

      // MdbToolsImporter only works on desktop platforms with mdb-tools installed
      final testSource = ImportSource.fromFile('test.vsb');
      if (!importer.canImport(testSource)) return;

      state = state.copyWith(
        isLoading: true,
        error: 'Loading default song books...',
      );

      final tempDir = await getTemporaryDirectory();
      int totalImported = 0;

      for (final assetPath in bundledSongbooks) {
        try {
          // Load asset bytes
          final byteData = await rootBundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List();

          // Write to a temp file so MdbToolsImporter (which uses mdb-export CLI) can read it
          final fileName = assetPath.split('/').last;
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);

          final source = ImportSource.fromFile(tempFile.path);
          if (importer.canImport(source)) {
            // Extract book name from asset path to use as category name
            // e.g. "assets/songbooks/Injili Song Book.vsb" -> "Injili Song Book"
            final bookName = fileName
                .replaceAll('.vsb', '')
                .replaceAll('.mdb', '');
            final result = await importer.import(
              source,
              overrideCategoryName: bookName,
            );
            if (result.success) totalImported += result.songsImported;
          }

          // Clean up temp file
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {
          // Skip individual files that fail — don't abort the whole process
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
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final songListControllerProvider =
    StateNotifierProvider<SongListController, SongListState>((ref) {
      final repo = ref.watch(songRepositoryProvider);
      return SongListController(repo);
    });
