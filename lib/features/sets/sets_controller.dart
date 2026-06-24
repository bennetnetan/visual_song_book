import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

class SetsState {
  final List<SongSet> sets;
  final int? selectedSetId;
  final List<SongSetItem> setItems;
  final List<Song> availableSongs;
  final bool isLoading;

  SetsState({
    required this.sets,
    this.selectedSetId,
    required this.setItems,
    required this.availableSongs,
    required this.isLoading,
  });

  SetsState copyWith({
    List<SongSet>? sets,
    int? Function()? selectedSetId,
    List<SongSetItem>? setItems,
    List<Song>? availableSongs,
    bool? isLoading,
  }) {
    return SetsState(
      sets: sets ?? this.sets,
      selectedSetId: selectedSetId != null
          ? selectedSetId()
          : this.selectedSetId,
      setItems: setItems ?? this.setItems,
      availableSongs: availableSongs ?? this.availableSongs,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory SetsState.initial() =>
      SetsState(sets: [], setItems: [], availableSongs: [], isLoading: true);
}

class SetsController extends StateNotifier<SetsState> {
  final SetRepository _repo;
  final SongRepository _songRepo;
  StreamSubscription<List<SongSet>>? _setsSub;

  SetsController(this._repo, this._songRepo) : super(SetsState.initial()) {
    _init();
  }

  void _init() {
    _setsSub = _repo.watchAllSets().listen((sets) {
      state = state.copyWith(sets: sets, isLoading: false);
    });
    _songRepo.watchAllSongs().listen((songs) {
      state = state.copyWith(availableSongs: songs);
    });
  }

  void selectSet(int setId) {
    state = state.copyWith(selectedSetId: () => setId);
    _repo.getSetItems(setId).then((items) {
      if (mounted) state = state.copyWith(setItems: items);
    });
  }

  void clearSelection() {
    state = state.copyWith(selectedSetId: () => null, setItems: []);
  }

  Future<void> createSet(String name, {String? notes, String? occasion}) async {
    await _repo.createSet(name, notes: notes, occasion: occasion);
  }

  Future<void> deleteSet(int setId) async {
    if (state.selectedSetId == setId) clearSelection();
    await _repo.deleteSet(setId);
  }

  Future<void> addSongToSet(int setId, int songId) async {
    final currentCount = state.setItems.length;
    await _repo.addSongToSet(setId, songId, currentCount);
    final items = await _repo.getSetItems(setId);
    if (mounted) state = state.copyWith(setItems: items);
  }

  Future<void> removeSongFromSet(int setId, int songId) async {
    await _repo.removeSongFromSet(setId, songId);
    final items = await _repo.getSetItems(setId);
    if (mounted) state = state.copyWith(setItems: items);
  }

  SongSet? get selectedSet {
    if (state.selectedSetId == null) return null;
    return state.sets.where((s) => s.id == state.selectedSetId).firstOrNull;
  }

  @override
  void dispose() {
    _setsSub?.cancel();
    super.dispose();
  }
}
