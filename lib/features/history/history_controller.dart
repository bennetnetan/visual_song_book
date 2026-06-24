import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

enum HistoryTabType { songs, sets, bible }

class HistoryState {
  final List<Song> songs;
  final List<SetHistoryData> sets;
  final List<BibleHistoryData> bible;
  final bool isLoading;

  HistoryState({
    required this.songs,
    required this.sets,
    required this.bible,
    required this.isLoading,
  });

  HistoryState copyWith({
    List<Song>? songs,
    List<SetHistoryData>? sets,
    List<BibleHistoryData>? bible,
    bool? isLoading,
  }) {
    return HistoryState(
      songs: songs ?? this.songs,
      sets: sets ?? this.sets,
      bible: bible ?? this.bible,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryController extends StateNotifier<HistoryState> {
  final SongRepository _songRepository;
  final SetRepository _setRepository;

  HistoryController(this._songRepository, this._setRepository)
    : super(HistoryState(songs: [], sets: [], bible: [], isLoading: true)) {
    _init();
  }

  void _init() {
    _songRepository.watchHistory().listen((historyList) {
      state = state.copyWith(songs: historyList, isLoading: false);
    });
    _setRepository.getSetHistory().then((setHistory) {
      state = state.copyWith(sets: setHistory);
    });
    _setRepository.getBibleHistory().then((bibleHistory) {
      state = state.copyWith(bible: bibleHistory);
    });
  }

  Future<void> clearSongHistory() async {
    await _songRepository.clearHistory();
  }

  Future<void> clearSetHistory() async {
    await _setRepository.clearSetHistory();
    state = state.copyWith(sets: []);
  }

  Future<void> clearBibleHistory() async {
    await _setRepository.clearBibleHistory();
    state = state.copyWith(bible: []);
  }
}

final historyControllerProvider =
    StateNotifierProvider<HistoryController, HistoryState>((ref) {
      final songRepo = ref.watch(songRepositoryProvider);
      final setRepo = ref.watch(setRepositoryProvider);
      return HistoryController(songRepo, setRepo);
    });
