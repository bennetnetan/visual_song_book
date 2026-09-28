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
  final Map<int, int> songCounts;
  final bool isLoading;

  SetsState({
    required this.sets,
    this.selectedSetId,
    required this.setItems,
    required this.availableSongs,
    this.songCounts = const {},
    required this.isLoading,
  });

  SetsState copyWith({
    List<SongSet>? sets,
    int? Function()? selectedSetId,
    List<SongSetItem>? setItems,
    List<Song>? availableSongs,
    Map<int, int>? songCounts,
    bool? isLoading,
  }) {
    return SetsState(
      sets: sets ?? this.sets,
      selectedSetId: selectedSetId != null
          ? selectedSetId()
          : this.selectedSetId,
      setItems: setItems ?? this.setItems,
      availableSongs: availableSongs ?? this.availableSongs,
      songCounts: songCounts ?? this.songCounts,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory SetsState.initial() => SetsState(
        sets: [],
        setItems: [],
        availableSongs: [],
        songCounts: const {},
        isLoading: true,
      );
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
    _setsSub = _repo.watchAllSets().listen((sets) async {
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

      final counts = <int, int>{};
      for (final s in sets) {
        counts[s.id] = await _repo.getSongCountForSet(s.id);
      }

      state = state.copyWith(sets: sets, songCounts: counts, isLoading: false);
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
        final updatedCounts = Map<int, int>.from(state.songCounts);
        updatedCounts[setId] = items.length;
        state = state.copyWith(setItems: items, songCounts: updatedCounts);
      }
    });
  }

  void clearSelection() {
    _log.info('clearSelection (was ${state.selectedSetId})');
    _itemsSub?.cancel();
    _itemsSub = null;
    state = state.copyWith(selectedSetId: () => null, setItems: []);
  }

  Future<void> createSet(
    String name, {
    String? notes,
    String? occasion,
    DateTime? createdAt,
  }) async {
    final newSet = await _repo.createSet(
      name,
      notes: notes,
      occasion: occasion,
    );
    if (createdAt != null) {
      await _repo.updateSet(newSet.id, createdAt: createdAt);
    }
  }

  Future<void> duplicateSet(int setId, {String? newName}) async {
    final original = state.sets.where((s) => s.id == setId).firstOrNull;
    final nameToUse = newName ?? (original != null
        ? generateNextVersionName('${original.name} (Copy)')
        : null);
    final duplicated = await _repo.duplicateSet(setId, newName: nameToUse);
    selectSet(duplicated.id);
  }

  String generateNextVersionName(String name) {
    final existingNames = state.sets.map((s) => s.name.trim()).toSet();
    return resolveNextVersionName(name, existingNames);
  }

  static String resolveNextVersionName(String name, Set<String> existingNames) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'Imported Set';

    // If no existing set has this name (case-insensitive), return as-is
    final hasCollision = existingNames.any(
      (existing) => existing.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (!hasCollision) {
      return trimmedName;
    }

    // Check if name ends with copy pattern like " (Copy)" or " (Copy 2)"
    final copyRegex = RegExp(r'^(.*?)\s*\(Copy(?:\s*(\d+))?\)$', caseSensitive: false);
    // Check if name ends with version pattern like " (v2)" or " (2)"
    final versionRegex = RegExp(r'^(.*?)\s*\(v?(\d+)\)$', caseSensitive: false);

    String baseName;
    int startVersion;
    bool isCopyStyle = false;

    final copyMatch = copyRegex.firstMatch(trimmedName);
    final versionMatch = versionRegex.firstMatch(trimmedName);

    if (copyMatch != null) {
      baseName = copyMatch.group(1)!.trim();
      final numStr = copyMatch.group(2);
      startVersion = numStr != null ? (int.tryParse(numStr) ?? 1) + 1 : 2;
      isCopyStyle = true;
    } else if (versionMatch != null) {
      baseName = versionMatch.group(1)!.trim();
      final numStr = versionMatch.group(2);
      startVersion = numStr != null ? (int.tryParse(numStr) ?? 1) + 1 : 2;
    } else {
      baseName = trimmedName;
      startVersion = 2;
    }

    int version = startVersion;
    while (true) {
      final candidate = isCopyStyle
          ? '$baseName (Copy $version)'
          : '$baseName (v$version)';

      final collides = existingNames.any(
        (existing) => existing.trim().toLowerCase() == candidate.toLowerCase(),
      );
      if (!collides) {
        return candidate;
      }
      version++;
    }
  }

  Future<void> deleteSet(int setId) async {
    if (state.selectedSetId == setId) clearSelection();
    await _repo.deleteSet(setId);
  }

  Future<void> renameSet(int setId, String newName) async {
    await _repo.updateSet(setId, name: newName);
  }

  Future<void> updateSetDetails(
    int setId, {
    String? name,
    String? notes,
    String? occasion,
    DateTime? createdAt,
  }) async {
    await _repo.updateSet(
      setId,
      name: name,
      notes: notes,
      occasion: occasion,
      createdAt: createdAt,
    );
  }

  Future<void> addSongToSet(int setId, int songId, {String? key, String? notes}) async {
    final currentCount = state.setItems.length;
    await _repo.addSongToSet(setId, songId, currentCount, key: key, notes: notes);
  }

  Future<void> updateSongKeyInSet(int setId, int songId, String? key) async {
    await _repo.updateSetItemKey(setId, songId, key);
  }

  Future<void> updateSongNotesInSet(int setId, int songId, String? notes) async {
    await _repo.updateSetItemNotes(setId, songId, notes);
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

    // Header: name
    buffer.writeln(setObj.name);

    // Subtitle line: occasion · date
    final datePart = '${setObj.createdAt.toLocal().day} '
        '${_monthAbbr(setObj.createdAt.month)} '
        '${setObj.createdAt.year}';
    final subtitleParts = <String>[
      if (setObj.occasion != null && setObj.occasion!.isNotEmpty) setObj.occasion!,
      datePart,
    ];
    buffer.writeln(subtitleParts.join(' · '));

    if (setObj.notes != null && setObj.notes!.isNotEmpty) {
      buffer.writeln(setObj.notes);
    }

    buffer.writeln();

    // Numbered song list
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final song = state.availableSongs.where((s) => s.id == item.songId).firstOrNull;
      if (song != null) {
        final numberText = song.songNum > 0 ? ' (#${song.songNum})' : '';
        final keyText = item.key != null && item.key!.isNotEmpty ? ' [Key: ${item.key}]' : '';
        buffer.writeln('${i + 1}. ${song.title}$numberText$keyText');
      }
    }

    return buffer.toString().trimRight();
  }

  static String _monthAbbr(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  // === Import Logic ===

  Future<void> importSetFromJson(String content) async {
    final trimmed = content.trim();
    if (!trimmed.startsWith('{')) {
      return importSetFromPlainText(trimmed);
    }

    try {
      final Map<String, dynamic> data = jsonDecode(trimmed);
      
      final uuid = data['uuid'] as String? ?? UuidGenerator.generate();
      final originalName = data['name'] as String? ?? 'Imported Set';
      final notes = data['notes'] as String?;
      final occasion = data['occasion'] as String?;
      final createdAtStr = data['createdAt'] as String?;
      final createdAt = createdAtStr != null 
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) 
          : DateTime.now();

      var targetUuid = uuid;
      var targetName = generateNextVersionName(originalName);

      // Deduplicate UUID in the background to ensure uniqueness
      final existingSet = await _repo.getSetByUuid(targetUuid);
      if (existingSet != null) {
        targetUuid = UuidGenerator.generate();
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

  Future<void> importSetFromPlainText(String content) async {
    try {
      final rawLines = content.split('\n');
      final lines = rawLines.map((l) => l.trim()).toList();

      String setName = 'Imported Set';
      String? occasion;
      DateTime? createdAt;
      final notesLines = <String>[];
      final songItems = <_ParsedSongItem>[];

      // Regex matching numbered lines, e.g. "1. Amazing Grace (#123) [Key: G]"
      final songLineRegex = RegExp(r'^\s*\[?(\d+)[\.\)\]]\s*(.+)$');
      final keyRegex = RegExp(r'\[Key:\s*([^\]]+)\]|\(Key:\s*([^\)]+)\)|\bKey:\s*([A-Ga-g][#b]?[m]?\b)', caseSensitive: false);
      final songNumRegex = RegExp(r'\(#(\d+)\)|\[#(\d+)\]|#(\d+)');

      int firstSongLineIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;
        if (songLineRegex.hasMatch(line)) {
          firstSongLineIndex = i;
          break;
        }
      }

      if (firstSongLineIndex == -1) {
        // No numbered prefix found; treat non-empty lines as potential song lines
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isNotEmpty && !line.startsWith('===') && !line.startsWith('---')) {
            firstSongLineIndex = i;
            break;
          }
        }
      }

      if (firstSongLineIndex == -1) {
        throw Exception('No songs found in the pasted text.');
      }

      // 1. Parse metadata lines before the first song line
      final metadataLines = <String>[];
      for (var i = 0; i < firstSongLineIndex; i++) {
        final line = lines[i];
        if (line.isEmpty || line.startsWith('===') || line.startsWith('---')) continue;
        metadataLines.add(line);
      }

      if (metadataLines.isNotEmpty) {
        // First metadata line is usually the set name
        var first = metadataLines[0];
        first = first
            .replaceFirst(RegExp(r'^===?\s*(SET LIST:\s*|SET:\s*)?', caseSensitive: false), '')
            .replaceFirst(RegExp(r'\s*===?$'), '')
            .trim();
        if (first.isNotEmpty) {
          setName = first;
        }

        // Subsequent lines: occasion · date, notes, etc.
        for (var i = 1; i < metadataLines.length; i++) {
          final mLine = metadataLines[i];
          if (mLine.toLowerCase().startsWith('occasion:')) {
            occasion = mLine.substring(9).trim();
          } else if (mLine.toLowerCase().startsWith('date:')) {
            createdAt = _parseDateString(mLine.substring(5).trim());
          } else if (mLine.toLowerCase().startsWith('notes:')) {
            notesLines.add(mLine.substring(6).trim());
          } else if (mLine.contains('·')) {
            final parts = mLine.split('·').map((p) => p.trim()).toList();
            for (final part in parts) {
              final parsedDate = _parseDateString(part);
              if (parsedDate != null) {
                createdAt = parsedDate;
              } else if (part.isNotEmpty) {
                occasion = part;
              }
            }
          } else {
            final parsedDate = _parseDateString(mLine);
            if (parsedDate != null && createdAt == null) {
              createdAt = parsedDate;
            } else {
              notesLines.add(mLine);
            }
          }
        }
      }

      // 2. Parse song lines
      for (var i = firstSongLineIndex; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty || line.startsWith('===') || line.startsWith('---')) continue;

        String rawContent = line;
        final match = songLineRegex.firstMatch(line);
        if (match != null) {
          rawContent = match.group(2)!.trim();
        }

        // Extract key
        String? itemKey;
        final keyMatch = keyRegex.firstMatch(rawContent);
        if (keyMatch != null) {
          itemKey = (keyMatch.group(1) ?? keyMatch.group(2) ?? keyMatch.group(3))?.trim();
          rawContent = rawContent.replaceRange(keyMatch.start, keyMatch.end, '').trim();
        }

        // Extract song number
        int songNum = 0;
        final numMatch = songNumRegex.firstMatch(rawContent);
        if (numMatch != null) {
          songNum = int.tryParse(numMatch.group(1) ?? numMatch.group(2) ?? numMatch.group(3) ?? '0') ?? 0;
          rawContent = rawContent.replaceRange(numMatch.start, numMatch.end, '').trim();
        }

        // Clean up remaining title
        final cleanTitle = rawContent
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceFirst(RegExp(r'^[-–—]\s*'), '')
            .trim();

        if (cleanTitle.isNotEmpty || songNum > 0) {
          songItems.add(_ParsedSongItem(
            title: cleanTitle.isNotEmpty ? cleanTitle : 'Song $songNum',
            songNum: songNum,
            key: itemKey,
          ));
        }
      }

      if (songItems.isEmpty) {
        throw Exception('Could not find any songs in the provided text.');
      }

      // Create new set
      final targetUuid = UuidGenerator.generate();
      final targetName = generateNextVersionName(setName);
      final newSet = await _repo.createSetWithUuid(
        name: targetName,
        uuid: targetUuid,
        notes: notesLines.isNotEmpty ? notesLines.join('\n') : null,
        occasion: occasion,
        createdAt: createdAt ?? DateTime.now(),
      );

      // Resolve and add songs
      for (var pos = 0; pos < songItems.length; pos++) {
        final item = songItems[pos];
        final matchedSongId = await _resolveSongForPlainTextImport(
          title: item.title,
          songNum: item.songNum,
          key: item.key,
        );
        await _repo.addSongToSet(newSet.id, matchedSongId, pos, key: item.key);
      }

      selectSet(newSet.id);
    } catch (e) {
      _log.severe('Error importing plain text set', e);
      rethrow;
    }
  }

  Future<int> _resolveSongForPlainTextImport({
    required String title,
    required int songNum,
    String? key,
  }) async {
    final allSongs = state.availableSongs;

    // 1. Try to find by song number first if available
    if (songNum > 0) {
      final matchByNum = allSongs.where((s) => s.songNum == songNum).firstOrNull;
      if (matchByNum != null) {
        return matchByNum.id;
      }
    }

    // 2. Try exact title match (case insensitive)
    final trimmedTitle = title.trim().toLowerCase();
    final matchByTitle = allSongs.where((s) => s.title.trim().toLowerCase() == trimmedTitle).firstOrNull;
    if (matchByTitle != null) {
      return matchByTitle.id;
    }

    // 3. Try partial title match
    final matchPartial = allSongs.where((s) {
      final sTitle = s.title.trim().toLowerCase();
      return sTitle.contains(trimmedTitle) || trimmedTitle.contains(sTitle);
    }).firstOrNull;
    if (matchPartial != null) {
      return matchPartial.id;
    }

    // 4. Otherwise create a custom song placeholder
    final finalNum = songNum > 0 ? songNum : (9000 + allSongs.length);
    final id = await _songRepo.addSong(
      SongsCompanion.insert(
        title: title,
        body: '',
        songNum: finalNum,
        key: Value(key),
        isActive: const Value(true),
      ),
    );
    return id;
  }

  static DateTime? _parseDateString(String input) {
    final trimmed = input.trim();
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    // Matches e.g. "28 Sep 2026" or "28 September 2026"
    final regex = RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final monthStr = match.group(2)!.toLowerCase();
      final year = int.tryParse(match.group(3)!);

      const months = {
        'jan': 1, 'january': 1,
        'feb': 2, 'february': 2,
        'mar': 3, 'march': 3,
        'apr': 4, 'april': 4,
        'may': 5,
        'jun': 6, 'june': 6,
        'jul': 7, 'july': 7,
        'aug': 8, 'august': 8,
        'sep': 9, 'september': 9,
        'oct': 10, 'october': 10,
        'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };

      final month = months[monthStr];
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
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

class _ParsedSongItem {
  final String title;
  final int songNum;
  final String? key;

  _ParsedSongItem({
    required this.title,
    required this.songNum,
    this.key,
  });
}
