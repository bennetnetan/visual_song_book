import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';

/// Search state for the projection view (Bible + Song unified).
class ProjectionSearchState {
  final String query;
  final bool isBibleMode;
  final bool isLoading;
  final String? error;

  // Bible-specific
  final List<BibleVerse> bibleResults;
  final int totalBibleCount;
  final int bibleOffset;
  final BibleVerse? exactMatch;

  // Song-specific
  final List<Song> songResults;

  const ProjectionSearchState({
    this.query = '',
    this.isBibleMode = true,
    this.isLoading = false,
    this.error,
    this.bibleResults = const [],
    this.totalBibleCount = 0,
    this.bibleOffset = 0,
    this.exactMatch,
    this.songResults = const [],
  });

  ProjectionSearchState copyWith({
    String? query,
    bool? isBibleMode,
    bool? isLoading,
    String? Function()? error,
    List<BibleVerse>? bibleResults,
    int? totalBibleCount,
    int? bibleOffset,
    BibleVerse? Function()? exactMatch,
    List<Song>? songResults,
  }) {
    return ProjectionSearchState(
      query: query ?? this.query,
      isBibleMode: isBibleMode ?? this.isBibleMode,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      bibleResults: bibleResults ?? this.bibleResults,
      totalBibleCount: totalBibleCount ?? this.totalBibleCount,
      bibleOffset: bibleOffset ?? this.bibleOffset,
      exactMatch: exactMatch != null ? exactMatch() : this.exactMatch,
      songResults: songResults ?? this.songResults,
    );
  }
}

/// Controller for the unified projection search.
///
/// Handles both Bible and Song searches with a 300 ms debounce.
/// Bible mode supports structured reference parsing ("Gen 1:1")
/// and paginated results.
class ProjectionSearchController extends StateNotifier<ProjectionSearchState> {
  final BibleRepository _bibleRepo;
  final SongRepository _songRepo;
  Timer? _debounce;
  int _activeRequestId = 0;

  ProjectionSearchController(this._bibleRepo, this._songRepo)
      : super(const ProjectionSearchState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Atomically switch mode and start a new search instantly (0ms delay).
  void switchModeAndSearch(bool isBible, String query) {
    _debounce?.cancel();
    _activeRequestId++;
    final requestId = _activeRequestId;
    final trimmed = query.trim();

    state = state.copyWith(
      query: query,
      isBibleMode: isBible,
      isLoading: trimmed.isNotEmpty,
      error: () => null,
    );

    if (trimmed.isEmpty) {
      state = state.copyWith(
        bibleResults: [],
        totalBibleCount: 0,
        bibleOffset: 0,
        exactMatch: () => null,
        songResults: [],
        isLoading: false,
      );
      return;
    }

    // Instant 0ms execution for mode toggles!
    _searchNow(query, requestId);
  }

  /// Set the search mode (true = Bible, false = Song).
  void toggleMode(bool isBible) {
    switchModeAndSearch(isBible, state.query);
  }

  /// Called on every keystroke. Debounces 250 ms before executing.
  void search(String query) {
    if (state.query == query) return;
    state = state.copyWith(query: query, error: () => null);
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      _activeRequestId++;
      state = state.copyWith(
        bibleResults: [],
        totalBibleCount: 0,
        bibleOffset: 0,
        exactMatch: () => null,
        songResults: [],
        isLoading: false,
      );
      return;
    }

    _activeRequestId++;
    final requestId = _activeRequestId;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchNow(query, requestId);
    });
  }

  Future<void> _searchNow(String query, int requestId) async {
    if (requestId != _activeRequestId) return;
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      if (state.isBibleMode) {
        await _performBibleSearch(query, requestId);
      } else {
        await _performSongSearch(query, requestId);
      }
    } catch (e) {
      if (mounted && requestId == _activeRequestId) {
        state = state.copyWith(
          isLoading: false,
          error: () => e.toString(),
        );
      }
    }
  }

  Future<void> _performBibleSearch(String query, int requestId) async {
    final normalized = normalizeSearchQuery(query);
    if (requestId != _activeRequestId) return;

    if (normalized.isEmpty) {
      if (mounted && requestId == _activeRequestId) {
        state = state.copyWith(
          bibleResults: [],
          totalBibleCount: 0,
          bibleOffset: 0,
          exactMatch: () => null,
          songResults: [],
          isLoading: false,
        );
      }
      return;
    }

    // Try structured reference parsing
    final ref = parseBibleReference(normalized);
    BibleVerse? exact;
    if (ref != null) {
      exact = await _bibleRepo.getVerseByRef(ref.bookId, ref.chapter, ref.verse);
    }
    if (requestId != _activeRequestId) return;

    // Full-text search
    final total = await _bibleRepo.countSearchResults(normalized);
    if (requestId != _activeRequestId) return;

    final results = await _bibleRepo.searchVersesPaginated(normalized, 10, 0);
    if (!mounted || requestId != _activeRequestId) return;

    final filtered = results.where((v) => v.id != exact?.id).toList();
    state = state.copyWith(
      bibleResults: filtered,
      totalBibleCount: total,
      bibleOffset: filtered.length,
      exactMatch: () => exact,
      songResults: [],
      isLoading: false,
    );
  }

  Future<void> _performSongSearch(String query, int requestId) async {
    final results = await _songRepo.searchSongs(query);
    if (mounted && requestId == _activeRequestId) {
      state = state.copyWith(
        songResults: results,
        bibleResults: [],
        totalBibleCount: 0,
        exactMatch: () => null,
        isLoading: false,
      );
    }
  }

  /// Load the next page of Bible results (10 more).
  Future<void> loadMoreBible() async {
    if (state.isLoading) return;
    final normalized = normalizeSearchQuery(state.query);
    if (normalized.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final results = await _bibleRepo.searchVersesPaginated(
        normalized,
        10,
        state.bibleOffset,
      );
      if (!mounted) return;
      final exact = state.exactMatch;
      final filtered = results.where((v) => v.id != exact?.id).toList();
      if (filtered.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        bibleResults: [...state.bibleResults, ...filtered],
        bibleOffset: state.bibleOffset + filtered.length,
        isLoading: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: () => e.toString(),
        );
      }
    }
  }

  /// Clear active search query and results while preserving current isBibleMode.
  void clear() {
    _debounce?.cancel();
    state = ProjectionSearchState(isBibleMode: state.isBibleMode);
  }
}

final projectionSearchProvider =
    StateNotifierProvider<ProjectionSearchController, ProjectionSearchState>(
        (ref) {
  final bibleRepo = ref.watch(bibleRepositoryProvider);
  final songRepo = ref.watch(songRepositoryProvider);
  return ProjectionSearchController(bibleRepo, songRepo);
});
