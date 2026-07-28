import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/bible/bible_search_utils.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cache entry types
// ─────────────────────────────────────────────────────────────────────────────

/// Cached result set for a single Bible query.
class _BibleCacheEntry {
  final List<BibleVerse> results;
  final int total;
  final BibleVerse? exactMatch;

  const _BibleCacheEntry({
    required this.results,
    required this.total,
    this.exactMatch,
  });
}

/// Cached result set for a single Song query.
class _SongCacheEntry {
  final List<Song> results;

  const _SongCacheEntry({required this.results});
}

// ─────────────────────────────────────────────────────────────────────────────
// Search state
// ─────────────────────────────────────────────────────────────────────────────

/// Search state for the projection view (Bible + Song unified).
class ProjectionSearchState {
  final String query;
  final bool isBibleMode;
  final bool isLoading;
  final String? error;
  final String? selectedSourcePath;

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
    this.selectedSourcePath,
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
    String? selectedSourcePath,
    bool? clearSourcePath = false,
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
      selectedSourcePath: clearSourcePath == true
          ? null
          : (selectedSourcePath ?? this.selectedSourcePath),
      bibleResults: bibleResults ?? this.bibleResults,
      totalBibleCount: totalBibleCount ?? this.totalBibleCount,
      bibleOffset: bibleOffset ?? this.bibleOffset,
      exactMatch: exactMatch != null ? exactMatch() : this.exactMatch,
      songResults: songResults ?? this.songResults,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

/// Controller for the unified projection search.
///
/// ### Result caching
/// Results for both Bible and Song modes are cached separately, keyed by the
/// normalised query string. When the user switches between Bible and Song mode
/// with the **same query**, cached results are restored instantly — no loading
/// spinner, no database round-trip. Cache entries are evicted whenever the
/// query string changes (a new debounce cycle starts), so stale data is never
/// shown for a different query.
///
/// ### Debounce & request cancellation
/// Keystrokes are debounced 250 ms before executing. Mode toggles bypass the
/// debounce entirely. An `_activeRequestId` counter ensures that only the most
/// recent async search can commit its results to state.
class ProjectionSearchController extends StateNotifier<ProjectionSearchState> {
  final BibleRepository _bibleRepo;
  final SongRepository _songRepo;
  Timer? _debounce;
  int _activeRequestId = 0;

  // Dual-mode result cache — each keyed by normalised query string.
  // Entries survive mode switches so going back to a mode with the same
  // query string never triggers a redundant DB call.
  final Map<String, _BibleCacheEntry> _bibleCache = {};
  final Map<String, _SongCacheEntry> _songCache = {};

  /// Maximum number of distinct query strings to keep in each cache.
  /// Oldest entries are evicted first (insertion-order Map).
  static const int _maxCacheSize = 20;

  ProjectionSearchController(this._bibleRepo, this._songRepo)
      : super(const ProjectionSearchState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Atomically switch mode and restore from cache or fetch instantly (0 ms).
  void switchModeAndSearch(bool isBible, String query) {
    _debounce?.cancel();
    _activeRequestId++;
    final requestId = _activeRequestId;
    final trimmed = query.trim();

    // Update mode immediately so UI reflects the switch right away.
    state = state.copyWith(
      query: query,
      isBibleMode: isBible,
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

    // ── Cache hit: restore results instantly, no loading state ──────────────
    final cacheKey = _cacheKey(trimmed, isBible);
    if (isBible) {
      final hit = _bibleCache[cacheKey];
      if (hit != null) {
        state = state.copyWith(
          bibleResults: hit.results,
          totalBibleCount: hit.total,
          bibleOffset: hit.results.length,
          exactMatch: () => hit.exactMatch,
          songResults: [],
          isLoading: false,
        );
        return; // ← instant, no async work needed
      }
    } else {
      final hit = _songCache[cacheKey];
      if (hit != null) {
        state = state.copyWith(
          songResults: hit.results,
          bibleResults: [],
          totalBibleCount: 0,
          exactMatch: () => null,
          isLoading: false,
        );
        return; // ← instant, no async work needed
      }
    }

    // ── Cache miss: fetch from DB ────────────────────────────────────────────
    state = state.copyWith(isLoading: true);
    _searchNow(query, requestId);
  }

  /// Convenience alias — switch mode using the current query.
  void toggleMode(bool isBible) {
    switchModeAndSearch(isBible, state.query);
  }

  /// Called on every keystroke. Debounces 250 ms before executing.
  /// Invalidates the cache for the old query when the query string changes.
  void search(String query) {
    if (state.query == query) return;

    // Evict cache entries for the previous query — they are no longer relevant
    // to the text the user is currently typing.
    _evictQuery(state.query.trim());

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
    state = state.copyWith(isLoading: true);
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchNow(query, requestId);
    });
  }

  /// Clear active search query and results while preserving current isBibleMode.
  void clear() {
    _debounce?.cancel();
    // Keep the cache — clearing the view doesn't mean the results are stale.
    state = ProjectionSearchState(isBibleMode: state.isBibleMode);
  }

  /// Sets the selected source path filter for song searches (null = all sources).
  /// Clears the song cache since results are now filtered differently.
  void setSourceFilter(String? sourcePath) {
    if (state.selectedSourcePath == sourcePath) return;
    state = state.copyWith(
      selectedSourcePath: sourcePath,
      clearSourcePath: sourcePath == null,
    );
    // Clear song cache since source filter changed
    _songCache.clear();
    // Re-run the current search if in song mode
    if (!state.isBibleMode && state.query.trim().isNotEmpty) {
      _activeRequestId++;
      final requestId = _activeRequestId;
      state = state.copyWith(isLoading: true);
      _performSongSearch(state.query, requestId);
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Normalised cache key: lower-cased trimmed query, mode-agnostic.
  /// We key on query only (not mode) so both caches share the same key space
  /// and lookups don't need to include the mode flag.
  String _cacheKey(String trimmed, bool isBible) {
    // Include mode in the key so bible and song caches are independent.
    return '${isBible ? 'b' : 's'}:${trimmed.toLowerCase()}';
  }

  /// Remove both Bible and Song cache entries for [trimmed] query.
  void _evictQuery(String trimmed) {
    if (trimmed.isEmpty) return;
    _bibleCache.remove(_cacheKey(trimmed, true));
    _songCache.remove(_cacheKey(trimmed, false));
  }

  /// Evict the oldest entry if the cache exceeds [_maxCacheSize].
  void _trimCache<V>(Map<String, V> cache) {
    while (cache.length > _maxCacheSize) {
      cache.remove(cache.keys.first);
    }
  }

  Future<void> _searchNow(String query, int requestId) async {
    // Bail immediately if superseded before we even start.
    if (requestId != _activeRequestId) return;

    try {
      // Capture the mode at the moment this search begins — state.isBibleMode
      // could change between await points if the user switches modes again.
      final isBible = state.isBibleMode;
      if (isBible) {
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

    // Safety net: if we are still the active request but isLoading is stuck
    // true (sub-method bailed via a guard and forgot to clear), force-clear.
    if (mounted && requestId == _activeRequestId && state.isLoading) {
      state = state.copyWith(isLoading: false);
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

    // ── Write to cache ───────────────────────────────────────────────────────
    final key = _cacheKey(query.trim(), true);
    _bibleCache[key] = _BibleCacheEntry(
      results: filtered,
      total: total,
      exactMatch: exact,
    );
    _trimCache(_bibleCache);

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
    final results = await _songRepo.searchSongs(
      query,
      sourcePath: state.selectedSourcePath,
    );
    if (!mounted || requestId != _activeRequestId) return;

    // ── Write to cache ───────────────────────────────────────────────────────
    final key = _cacheKey(query.trim(), false);
    _songCache[key] = _SongCacheEntry(results: results);
    _trimCache(_songCache);

    state = state.copyWith(
      songResults: results,
      bibleResults: [],
      totalBibleCount: 0,
      exactMatch: () => null,
      isLoading: false,
    );
  }

  /// Load the next page of Bible results (10 more).
  /// Also updates the cached entry so further mode switches include the
  /// additional pages.
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

      final combined = [...state.bibleResults, ...filtered];

      // ── Update cache with the enlarged result list ───────────────────────
      final key = _cacheKey(state.query.trim(), true);
      _bibleCache[key] = _BibleCacheEntry(
        results: combined,
        total: state.totalBibleCount,
        exactMatch: exact,
      );

      state = state.copyWith(
        bibleResults: combined,
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
}

final projectionSearchProvider =
    StateNotifierProvider<ProjectionSearchController, ProjectionSearchState>(
        (ref) {
  final bibleRepo = ref.watch(bibleRepositoryProvider);
  final songRepo = ref.watch(songRepositoryProvider);
  return ProjectionSearchController(bibleRepo, songRepo);
});
