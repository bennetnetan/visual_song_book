import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/core/utils/uuid_generator.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

final _log = AppLogger.get('SetsController');

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
  StreamSubscription<List<Song>>? _songsSub;
  StreamSubscription<List<SongSetItem>>? _itemsSub;

  SetsController(this._repo, this._songRepo) : super(SetsState.initial()) {
    _init();
  }

  void _init() {
    _setsSub = _repo.watchAllSets().listen((sets) {
      _log.fine('Sets stream update: ${sets.length} set(s). '
          'selectedSetId=${state.selectedSetId}');
      
      // Strict check: if state.selectedSetId is no longer present in DB sets list, clear stale selection
      final bool hasSelectedSet = state.selectedSetId != null && sets.any((s) => s.id == state.selectedSetId);
      if (state.selectedSetId != null && !hasSelectedSet) {
        _log.warning(
          'selectedSetId=${state.selectedSetId} no longer exists in DB sets. Clearing stale selection.',
        );
        clearSelection();
      }

      state = state.copyWith(sets: sets, isLoading: false);
    });

    _songsSub = _songRepo.watchAllSongs().listen((songs) {
      _log.fine('Songs stream update: ${songs.length} song(s).');
      state = state.copyWith(availableSongs: songs);
    });
  }

  void selectSet(int setId) {
    _log.info('selectSet($setId)');
    
    // Strict check: Ensure setId exists in sets list before setting
    final exists = state.sets.any((s) => s.id == setId);
    if (!exists && state.sets.isNotEmpty) {
      _log.warning('Attempted to select set $setId which does not exist in loaded DB sets.');
      clearSelection();
      return;
    }

    state = state.copyWith(selectedSetId: () => setId);
    _itemsSub?.cancel();
    _itemsSub = _repo.watchSetItems(setId).listen((items) {
      _log.fine('Set items updated reactively for set $setId: ${items.length} item(s).');
      if (mounted && state.selectedSetId == setId) {
        state = state.copyWith(setItems: items);
      }
    });
  }

  void clearSelection() {
    _log.info('clearSelection (was ${state.selectedSetId})');
    _itemsSub?.cancel();
    _itemsSub = null;
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
  }

  Future<void> addSongToSet(int setId, int songId, {String? key}) async {
    final currentCount = state.setItems.length;
    await _repo.addSongToSet(setId, songId, currentCount, key: key);
  }

  Future<void> updateSongKeyInSet(int setId, int songId, String? key) async {
    await _repo.updateSetItemKey(setId, songId, key);
  }

  Future<List<String>> getLastUsedKeysForSong(int songId) async {
    return _repo.getLastUsedKeysForSong(songId);
  }

  Future<List<String>> getTopUsedKeysForSong(int songId) async {
    return _repo.getTopUsedKeysForSong(songId);
  }

  Future<void> removeSongFromSet(int setId, int songId) async {
    await _repo.removeSongFromSet(setId, songId);
  }

  Future<void> reorderSongs(int setId, int oldIndex, int newIndex) async {
    final list = List<SongSetItem>.from(state.setItems);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final songIds = list.map((i) => i.songId).toList();
    await _repo.reorderSetItems(setId, songIds);
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
          'key': item.key,
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
        final keyText = item.key != null && item.key!.isNotEmpty ? ' [Key: ${item.key}]' : '';
        buffer.writeln('${i + 1}. ${song.title}$numberText$keyText');
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
        targetName = '$originalName (Imported)';
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
        final itemKey = item['key'] as String?;
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
        await _repo.addSongToSet(newSet.id, matchedSongId, pos, key: itemKey);
      }
      
      // Select the newly imported set in the UI
      selectSet(newSet.id);
    } catch (e) {
      _log.severe('Error importing set', e);
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
    _songsSub?.cancel();
    _itemsSub?.cancel();
    super.dispose();
  }
}
