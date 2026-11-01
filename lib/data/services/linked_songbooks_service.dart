import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';

final _log = AppLogger.get('LinkedSongbooks');

String _canonicalizePath(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.resolveSymbolicLinksSync();
    }
  } on IOException catch (e, st) {
    _log.fine('Failed to resolve symbolic links for $path: $e', e, st);
  }
  return path;
}

Future<bool> _isPathAllowed(String path) async {
  // Allow any path that points to an existing file.
  // The old check restricted links to $USERPROFILE or app storage,
  // which silently rejected files on other drives, network shares,
  // or external media — a common use case for church worship teams.
  try {
    if (!File(path).existsSync()) {
      _log.warning('Path does not exist: $path');
      return false;
    }
    return true;
  } catch (e, st) {
    _log.fine('Path check failed for $path: $e', e, st);
    return false;
  }
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

  factory LinkedSongbook.fromRegistry(LinkedSongbookRegistryData registry) {
    return LinkedSongbook(
      path: registry.path,
      name: registry.name,
      lastImportedAt: registry.lastImportedAt,
    );
  }

  LinkedSongbookRegistryCompanion toCompanion() {
    return LinkedSongbookRegistryCompanion.insert(
      path: path,
      name: name,
      lastImportedAt: Value(lastImportedAt),
    );
  }

  DateTime? get fileLastModified {
    try {
      return File(path).statSync().modified;
    } catch (e, st) {
      _log.fine('Failed to stat file $path: $e', e, st);
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
    return lower.endsWith('.vsbook') ||
        lower.endsWith('.vsb') ||
        lower.endsWith('.mdb');
  }
}

class LinkedSongbooksService extends AsyncNotifier<List<LinkedSongbook>> {
  static const _prefsKey = 'linked_songbooks';

  @override
  Future<List<LinkedSongbook>> build() async {
    final db = ref.watch(databaseProvider);
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to migrate from SharedPreferences
    final legacyRaw = prefs.getString(_prefsKey);
    final dbCount = await db.countLinkedSongbooks();

    if (dbCount == 0 && legacyRaw != null) {
      try {
        final list = json.decode(legacyRaw) as List<dynamic>;
        final legacyBooks = list
            .map((e) => LinkedSongbook.fromJson(e as Map<String, dynamic>))
            .toList();

        await db.transaction(() async {
          for (final book in legacyBooks) {
            await db.insertLinkedSongbook(book.toCompanion());
          }
        });

        await prefs.remove(_prefsKey);
        _log.info('Migrated ${legacyBooks.length} linked songbook(s) from SharedPreferences to database.');
      } catch (e) {
        _log.warning('Failed to migrate linked songbooks from SharedPreferences: $e');
      }
    }

    final registries = await db.getAllLinkedSongbooks();
    return registries.map(LinkedSongbook.fromRegistry).toList();
  }

  Future<void> _refresh() async {
    final db = ref.watch(databaseProvider);
    final registries = await db.getAllLinkedSongbooks();
    state = AsyncData(registries.map(LinkedSongbook.fromRegistry).toList());
  }

  Future<void> add(String path, {String? name}) async {
    final canonical = _canonicalizePath(path);
    if (!await _isPathAllowed(canonical)) {
      _log.warning('Refusing to link disallowed path: $path');
      return;
    }

    final current = state.value ?? [];
    if (current.any((s) => s.path == canonical)) return;

    final db = ref.watch(databaseProvider);
    final bookName = name ?? _nameFromPath(canonical);

    await db.insertLinkedSongbook(
      LinkedSongbookRegistryCompanion.insert(
        path: canonical,
        name: bookName,
      ),
    );

    await _refresh();
    _log.info('Linked songbook: $bookName ($canonical)');
  }

  Future<void> remove(String path) async {
    final canonical = _canonicalizePath(path);
    if (!await _isPathAllowed(canonical)) {
      _log.warning('Refusing to unlink disallowed path: $path');
      return;
    }

    final db = ref.watch(databaseProvider);
    await db.deleteLinkedSongbookByPath(canonical);
    await _refresh();
    _log.info('Unlinked songbook: $canonical');
  }

  Future<void> markImported(String path) async {
    final db = ref.watch(databaseProvider);
    await db.updateLinkedSongbookByPath(
      path,
      const LinkedSongbookRegistryCompanion(
        lastImportedAt: Value.absent(),
      ).copyWith(lastImportedAt: Value(DateTime.now())),
    );
    await _refresh();
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
  final prefs = await SharedPreferences.getInstance();

  // Check if user has chosen a source mode that excludes linked songbooks
  final sourceModeStr = prefs.getString('default_source_mode');
  if (sourceModeStr == SourceMode.bundled.name) {
    _log.fine('Source mode is "bundled" — skipping linked songbook sync.');
    return 0;
  }

  // Await the provider so its legacy SharedPreferences migration completes
  // before we inspect the database registry.
  final linked = await ref.watch(linkedSongbooksProvider.future);
  if (linked.isEmpty) return 0;

  final db = ref.watch(databaseProvider);
  final needingSync =
      linked.where((s) => s.hasChangedSinceLastImport && s.fileExists).toList();
  if (needingSync.isEmpty) return 0;

  _log.info('Syncing ${needingSync.length} linked songbook(s)...');
  final importer = VsBookImporter(db);
  int synced = 0;
  final syncedPaths = <String>[];

  for (final book in needingSync) {
    if (!await _isPathAllowed(book.path)) {
      _log.warning('Skipping disallowed path during sync: ${book.path}');
      continue;
    }
    final lower = book.path.toLowerCase();
    if (lower.endsWith('.vsbook') || lower.endsWith('.vsb') || lower.endsWith('.mdb')) {
      try {
        _log.info('Syncing "${book.name}" (${book.path})...');
        final result = await importer.reimportSource(book.path);
        if (result.success) {
          synced++;
          syncedPaths.add(book.path);
          _log.info(
            '"${book.name}" synced: ${result.songsImported} songs, '
            '${result.songsAdded} updated.',
          );
        } else {
          _log.warning('"${book.name}" sync failed: ${result.errorMessage}');
        }
      } catch (e, st) {
        _log.severe('Error syncing "${book.name}"', e, st);
      }
    } else {
      _log.warning('Unsupported format for "${book.name}": $lower');
    }
  }

  // Only update lastImportedAt for files that actually synced —
  // otherwise failed files will appear up-to-date on next startup
  // and never be retried.
  if (syncedPaths.isNotEmpty) {
    final now = DateTime.now();
    for (final path in syncedPaths) {
      await db.updateLinkedSongbookByPath(
        path,
        const LinkedSongbookRegistryCompanion(
          lastImportedAt: Value.absent(),
        ).copyWith(lastImportedAt: Value(now)),
      );
    }
    _log.info('Linked songbooks sync complete: $synced file(s) updated.');
  }

  return synced;
});
