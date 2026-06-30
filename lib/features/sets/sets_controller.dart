import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/utils/uuid_generator.dart';
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

  Future<void> renameSet(int setId, String newName) async {
    await _repo.updateSet(setId, name: newName);
    // Refresh sets list & details
    if (state.selectedSetId == setId) {
      selectSet(setId);
    }
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

  Future<void> reorderSongs(int setId, int oldIndex, int newIndex) async {
    final list = List<SongSetItem>.from(state.setItems);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final songIds = list.map((i) => i.songId).toList();
    await _repo.reorderSetItems(setId, songIds);

    final items = await _repo.getSetItems(setId);
    if (mounted) state = state.copyWith(setItems: items);
  }

  // === Share/Export Logic ===

  Future<String> getSetJsonString(int setId) async {
    final setObj = state.sets.where((s) => s.id == setId).firstOrNull;
    if (setObj == null) throw Exception('Set not found');

    final items = await _repo.getSetItems(setId);
    final itemsListJson = <Map<String, dynamic>>[];

    for (final item in items) {
      final song = state.availableSongs.where((s) => s.id == item.songId).firstOrNull;
      if (song != null) {
        itemsListJson.add({
          'position': item.position,
          'notes': item.notes,
          'song': {
            'title': song.title,
            'body': song.body,
            'songNum': song.songNum,
            'key': song.key,
            'author': song.author,
          }
        });
      }
    }

    final data = {
      'uuid': setObj.uuid ?? UuidGenerator.generate(),
      'name': setObj.name,
      'notes': setObj.notes,
      'occasion': setObj.occasion,
      'createdAt': setObj.createdAt.toIso8601String(),
      'items': itemsListJson,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> getSetPlainText(int setId) async {
    final setObj = state.sets.where((s) => s.id == setId).firstOrNull;
    if (setObj == null) throw Exception('Set not found');

    final items = await _repo.getSetItems(setId);
    final buffer = StringBuffer();

    buffer.writeln('=== SET LIST: ${setObj.name} ===');
    if (setObj.occasion != null && setObj.occasion!.isNotEmpty) {
      buffer.writeln('Occasion: ${setObj.occasion}');
    }
    buffer.writeln('Date: ${setObj.createdAt.toLocal().toString().split('.')[0]}');
    if (setObj.notes != null && setObj.notes!.isNotEmpty) {
      buffer.writeln('Notes: ${setObj.notes}');
    }
    buffer.writeln('========================================\n');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final song = state.availableSongs.where((s) => s.id == item.songId).firstOrNull;
      if (song != null) {
        final numberText = song.songNum > 0 ? ' (#${song.songNum})' : '';
        buffer.writeln('${i + 1}. ${song.title}$numberText');
      }
    }

    return buffer.toString();
  }

  // === Import Logic ===

  Future<void> importSetFromJson(String content) async {
    try {
      final Map<String, dynamic> data = jsonDecode(content);
      
      final uuid = data['uuid'] as String? ?? UuidGenerator.generate();
      final originalName = data['name'] as String? ?? 'Imported Set';
      final notes = data['notes'] as String?;
      final occasion = data['occasion'] as String?;
      final createdAtStr = data['createdAt'] as String?;
      final createdAt = createdAtStr != null 
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) 
          : DateTime.now();

      var targetUuid = uuid;
      var targetName = originalName;

      // Deduplicate UUID in the background to ensure uniqueness
      final existingSet = await _repo.getSetByUuid(targetUuid);
      if (existingSet != null) {
        targetUuid = UuidGenerator.generate();
        targetName = "$originalName (Imported)";
      }

      // Create the set list
      final newSet = await _repo.createSetWithUuid(
        name: targetName,
        uuid: targetUuid,
        notes: notes,
        occasion: occasion,
        createdAt: createdAt,
      );

      final items = data['items'] as List<dynamic>? ?? [];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final pos = item['position'] as int? ?? i;
        final songData = item['song'] as Map<String, dynamic>?;
        if (songData == null) continue;

        final title = songData['title'] as String? ?? 'Untitled';
        final body = songData['body'] as String? ?? '';
        final songNum = songData['songNum'] as int? ?? 0;
        final key = songData['key'] as String?;
        final author = songData['author'] as String?;

        // Resolve the song (get existing or create new custom song)
        final matchedSongId = await _resolveSongForImport(
          title: title,
          body: body,
          songNum: songNum,
          key: key,
          author: author,
        );

        // Add the resolved song to the newly created set
        await _repo.addSongToSet(newSet.id, matchedSongId, pos);
      }
      
      // Select the newly imported set in the UI
      selectSet(newSet.id);
    } catch (e) {
      print('Error importing set: $e');
      rethrow;
    }
  }

  Future<int> _resolveSongForImport({
    required String title,
    required String body,
    required int songNum,
    String? key,
    String? author,
  }) async {
    // 1. Check if song already exists with this title (case insensitive)
    final allSongs = state.availableSongs;
    final match = allSongs.where((s) => s.title.trim().toLowerCase() == title.trim().toLowerCase()).firstOrNull;
    if (match != null) {
      return match.id;
    }

    // 2. Otherwise, create a new custom song
    final finalNum = songNum > 0 ? songNum : (9000 + allSongs.length);
    final id = await _songRepo.addSong(
      SongsCompanion.insert(
        title: title,
        body: body,
        songNum: finalNum,
        key: Value(key),
        author: Value(author),
        isActive: const Value(true),
      ),
    );
    return id;
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
