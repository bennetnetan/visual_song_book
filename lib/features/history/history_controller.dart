import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

class HistoryState {
  final List<Song> history;
  final bool isLoading;

  HistoryState({required this.history, required this.isLoading});

  HistoryState copyWith({List<Song>? history, bool? isLoading}) {
    return HistoryState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryController extends StateNotifier<HistoryState> {
  final SongRepository _repository;

  HistoryController(this._repository) : super(HistoryState(history: [], isLoading: true)) {
    _init();
  }

  void _init() {
    _repository.watchHistory().listen((historyList) {
      state = state.copyWith(history: historyList, isLoading: false);
    });
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
  }
}

final historyControllerProvider = StateNotifierProvider<HistoryController, HistoryState>((ref) {
  final repo = ref.watch(songRepositoryProvider);
  return HistoryController(repo);
});
