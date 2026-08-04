import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/services/app_storage.dart';

final _log = AppLogger.get('LinkedSongbooks');

const _linkedSongbooksKey = 'linked_songbooks';

String _canonicalizePath(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.resolveSymbolicLinksSync();
    }
  } on IOException catch (_) {}
  return path;
}

Future<bool> _isPathAllowed(String path) async {
  String canonical;
  try {
    canonical = File(path).resolveSymbolicLinksSync();
  } on IOException catch (_) {
    canonical = path;
  }
  canonical = p.normalize(canonical);

  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  if (home.isNotEmpty) {
    final homeDir = p.normalize(home);
    if (canonical == homeDir || canonical.startsWith('$homeDir${p.separator}')) return true;
  }

  try {
    final appStorage = await getAppStoragePath();
    final appStorageDir = p.normalize(appStorage);
    if (canonical == appStorageDir || canonical.startsWith('$appStorageDir${p.separator}')) return true;
  } catch (_) {
    // ignore: app storage path not yet initialized
  }

  return false;
}

class LinkedSongbook {
  final String path;
  final String name;
  final DateTime? lastImportedAt;

  const LinkedSongbook({
    required this.path,
    required this.name,
    this.lastImportedAt,
  });

  LinkedSongbook copyWith({DateTime? lastImportedAt}) {
    return LinkedSongbook(
      path: path,
      name: name,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastImportedAt': lastImportedAt?.toIso8601String(),
      };

  factory LinkedSongbook.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'] as String;
    final path = _canonicalizePath(rawPath);
    return LinkedSongbook(
      path: path,
      name: json['name'] as String,
      lastImportedAt: json['lastImportedAt'] != null
          ? DateTime.tryParse(json['lastImportedAt'] as String)
          : null,
    );
  }

  DateTime? get fileLastModified {
    try {
      return File(path).statSync().modified;
    } catch (_) {
      return null;
    }
  }

  bool get fileExists => File(path).existsSync();

  bool get hasChangedSinceLastImport {
    if (lastImportedAt == null) return true;
    final modified = fileLastModified;
    if (modified == null) return false;
    return modified.isAfter(lastImportedAt!);
  }

  bool get isSupportedFormat {
    final lower = path.toLowerCase();
    return lower.endsWith('.vsbook') || lower.endsWith('.vsb');
  }
}

class LinkedSongbooksService extends AutoDisposeAsyncNotifier<List<LinkedSongbook>> {
  static const _prefsKey = 'linked_songbooks';

  @override
  Future<List<LinkedSongbook>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => LinkedSongbook.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to parse linked songbooks: $e');
      return [];
    }
  }

  Future<void> _save(List<LinkedSongbook> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(list.map((e) => e.toJson()).toList()));
    state = AsyncData(list);
  }

  Future<void> add(String path, {String? name}) async {
    final canonical = _canonicalizePath(path);
    if (!await _isPathAllowed(canonical)) {
      _log.warning('Refusing to link disallowed path: $path');
      return;
    }
    final current = state.value ?? [];
    if (current.any((s) => s.path == canonical)) return;
    final bookName = name ?? _nameFromPath(canonical);
    final updated = [...current, LinkedSongbook(path: canonical, name: bookName)];
    await _save(updated);
    _log.info('Linked songbook: $bookName ($canonical)');
  }

  Future<void> remove(String path) async {
    final current = state.value ?? [];
    final updated = current.where((s) => s.path != path).toList();
    await _save(updated);
    _log.info('Unlinked songbook: $path');
  }

  Future<void> markImported(String path) async {
    final current = state.value ?? [];
    final updated = current.map((s) {
      if (s.path == path) return s.copyWith(lastImportedAt: DateTime.now());
      return s;
    }).toList();
    await _save(updated);
  }

  List<LinkedSongbook> getFilesNeedingSync() {
    final current = state.value ?? [];
    return current.where((s) => s.hasChangedSinceLastImport && s.fileExists).toList();
  }

  static String _nameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }
}

final linkedSongbooksProvider =
    AsyncNotifierProvider.autoDispose<LinkedSongbooksService, List<LinkedSongbook>>(
  LinkedSongbooksService.new,
);

/// Syncs all linked songbooks that have changed since last import.
/// Called on app startup after seeding completes.
final linkedSongbooksSyncProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_linkedSongbooksKey);
  if (raw == null) return 0;

  List<LinkedSongbook> linked;
  try {
    final list = json.decode(raw) as List<dynamic>;
    linked = list
        .map((e) => LinkedSongbook.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _log.warning('Failed to parse linked songbooks for sync: $e');
    return 0;
  }

  final needingSync =
      linked.where((s) => s.hasChangedSinceLastImport && s.fileExists).toList();
  if (needingSync.isEmpty) return 0;

  _log.info('Syncing ${needingSync.length} linked songbook(s)...');
  final importer = VsBookImporter(db);
  int synced = 0;

  for (final book in needingSync) {
    if (!await _isPathAllowed(book.path)) {
      _log.warning('Skipping disallowed path during sync: ${book.path}');
      continue;
    }
    final lower = book.path.toLowerCase();
    if (lower.endsWith('.vsbook')) {
      try {
        final result = await importer.reimportSource(book.path);
        if (result.success) {
          synced++;
          _log.info(
            '"${book.name}" synced: ${result.songsImported} songs, '
            '${result.songsAdded} updated.',
          );
        } else {
          _log.warning('"${book.name}" sync failed: ${result.errorMessage}');
        }
      } catch (e) {
        _log.severe('Error syncing "${book.name}"', e);
      }
    } else if (lower.endsWith('.vsb')) {
      _log.warning(
        '"${book.name}" is a .vsb (MDB) file — '
        'direct import on Windows requires mdb-tools. '
        'Please convert to .vsbook format.',
      );
    }
  }

  if (synced > 0) {
    final updatedRaw = prefs.getString(_linkedSongbooksKey);
    if (updatedRaw != null) {
      try {
        final list = json.decode(updatedRaw) as List<dynamic>;
        final now = DateTime.now().toIso8601String();
        final updatedList = list.map((e) {
          final m = e as Map<String, dynamic>;
          final path = m['path'] as String;
          final needsUpdate = needingSync.any((b) => b.path == path);
          if (needsUpdate) m['lastImportedAt'] = now;
          return m;
        }).toList();
        await prefs.setString(_linkedSongbooksKey, json.encode(updatedList));
      } catch (_) {}
    }
    _log.info('Linked songbooks sync complete: $synced file(s) updated.');
  }

  return synced;
});
