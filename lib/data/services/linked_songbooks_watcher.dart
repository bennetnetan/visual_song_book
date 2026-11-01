import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';

final _log = AppLogger.get('LinkedSongbooksWatcher');

/// Polling interval for cloud-synced files (Google Drive, Dropbox, etc.).
/// These providers often modify files through temp paths that don't trigger
/// OS file events, so polling is the only reliable detection method.
const _defaultPollingInterval = Duration(minutes: 5);

/// Debounce window to avoid re-importing the same file multiple times in
/// quick succession (e.g. a file write that triggers multiple OS events).
const _defaultDebounceDuration = Duration(seconds: 3);

/// Monitors linked .vsbook files for changes and auto-syncs them.
///
/// Uses two complementary strategies:
/// - **FileSystemEntity.watch()** for instant detection of local file edits
/// - **Periodic polling** as fallback for cloud-synced folders where OS events
///   don't fire reliably
///
/// When a change is detected, the file is reimported via [VsBookImporter]
/// and Drift streams automatically propagate the update to the UI.
/// Event emitted when an auto-sync completes, for UI notification.
class LinkedSyncEvent {
  final String bookName;
  final int songsImported;
  final int songsUpdated;
  final bool success;
  final String? error;

  const LinkedSyncEvent({
    required this.bookName,
    this.songsImported = 0,
    this.songsUpdated = 0,
    this.success = true,
    this.error,
  });
}

class LinkedSongbooksWatcher {
  final AppDatabase _db;
  final Duration _pollingInterval;
  final Duration _debounceDuration;
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  Timer? _pollTimer;
  final Map<String, DateTime> _lastModifiedCache = {};
  final Map<String, Timer> _debounceTimers = {};

  /// Stream of sync events for UI notification.
  final _syncEventsController = StreamController<LinkedSyncEvent>.broadcast();
  Stream<LinkedSyncEvent> get syncEvents => _syncEventsController.stream;

  LinkedSongbooksWatcher(
    this._db, {
    Duration? pollingInterval,
    Duration? debounceDuration,
  }) : _pollingInterval = pollingInterval ?? _defaultPollingInterval,
       _debounceDuration = debounceDuration ?? _defaultDebounceDuration;

  /// Start watching all currently linked songbooks.
  /// Call this after the app seed completes.
  void startWatching(List<LinkedSongbook> linkedBooks) {
    _log.info('Starting watcher for ${linkedBooks.length} linked songbook(s)');

    // Cache initial modification times
    for (final book in linkedBooks) {
      _cacheLastModified(book);
      _setupFileSystemWatcher(book);
    }

    updateWatchedFiles(linkedBooks);
  }

  /// Update the set of watched files (call when linked books change).
  void updateWatchedFiles(List<LinkedSongbook> linkedBooks) {
    final currentPaths = linkedBooks.map((b) => b.path).toSet();

    // Remove watchers for files no longer linked
    final pathsToRemove = _watchers.keys
        .where((path) => !currentPaths.contains(path))
        .toList();
    for (final path in pathsToRemove) {
      _watchers[path]?.cancel();
      _watchers.remove(path);
      _lastModifiedCache.remove(path);
      _debounceTimers[path]?.cancel();
      _debounceTimers.remove(path);
    }

    // Add watchers for newly linked files
    for (final book in linkedBooks) {
      if (!_watchers.containsKey(book.path)) {
        _cacheLastModified(book);
        _setupFileSystemWatcher(book);
      }
    }

    // `updateWatchedFiles` is the entry point used by the app provider.
    // Keep polling active even when no file-system watcher could be created
    // (common for cloud-synced folders and files added after startup).
    if (linkedBooks.isNotEmpty) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Stop all watchers and polling. Call on app dispose.
  void dispose() {
    _log.info('Disposing linked songbooks watcher');
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _lastModifiedCache.clear();
    _syncEventsController.close();
  }

  // ── FileSystemEntity.watch() ──────────────────────────────────────────

  void _setupFileSystemWatcher(LinkedSongbook book) {
    final file = File(book.path);
    if (!file.existsSync()) {
      _log.fine('Skipping watcher for missing file: ${book.path}');
      return;
    }

    try {
      final watcher = file.watch();
      _watchers[book.path] = watcher.listen(
        (event) {
          // Only react to modify events (not delete/create)
          if (event.type == FileSystemEvent.modify ||
              event.type == FileSystemEvent.move) {
            _log.info(
              'File system event for "${book.name}": ${event.type}',
            );
            _debouncedReimport(book);
          }
        },
        onError: (error) {
          _log.warning('File watcher error for "${book.name}": $error');
          // Remove the broken watcher — polling will still catch changes
          _watchers[book.path]?.cancel();
          _watchers.remove(book.path);
        },
      );
      _log.fine('Watching file: ${book.path}');
    } catch (e) {
      _log.warning('Failed to set up file watcher for "${book.name}": $e');
    }
  }

  // ── Periodic polling ──────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) => _pollForChanges());
    _log.fine('Polling started (interval: ${_pollingInterval.inMinutes} min)');
  }

  Future<void> _pollForChanges() async {
    final allLinked = await _db.getAllLinkedSongbooks();
    final linkedBooks =
        allLinked.map(LinkedSongbook.fromRegistry).toList();

    for (final book in linkedBooks) {
      if (!book.fileExists) continue;
      if (!book.isSupportedFormat) continue;

      final currentModified = book.fileLastModified;
      if (currentModified == null) continue;

      final cached = _lastModifiedCache[book.path];
      if (cached != null && !currentModified.isAfter(cached)) continue;

      // File has been modified since last check
      _log.info(
        'Poll detected change in "${book.name}" '
        '(modified: $currentModified, was: $cached)',
      );
      _cacheLastModified(book);
      await _reimportFile(book);
    }
  }

  // ── Reimport logic ────────────────────────────────────────────────────

  void _debouncedReimport(LinkedSongbook book) {
    _debounceTimers[book.path]?.cancel();
    _debounceTimers[book.path] = Timer(_debounceDuration, () async {
      _debounceTimers.remove(book.path);

      // Update cache
      _cacheLastModified(book);

      // Check if the file actually changed (not just a metadata touch)
      final currentModified = book.fileLastModified;
      if (currentModified == null) return;

      await _reimportFile(book);
    });
  }

  Future<void> _reimportFile(LinkedSongbook book) async {
    _log.info('Auto-syncing "${book.name}"...');

    try {
      final importer = VsBookImporter(_db);
      final result = await importer.reimportSource(book.path);

      if (result.success) {
        // Update lastImportedAt so polling doesn't re-trigger
        await _db.updateLinkedSongbookByPath(
          book.path,
          LinkedSongbookRegistryCompanion(
            lastImportedAt: Value(DateTime.now()),
          ),
        );
        _log.info(
          'Auto-synced "${book.name}": '
          '${result.songsImported} songs, ${result.songsAdded} updated.',
        );
        _syncEventsController.add(LinkedSyncEvent(
          bookName: book.name,
          songsImported: result.songsImported,
          songsUpdated: result.songsAdded,
        ));
      } else {
        _log.warning(
          'Auto-sync failed for "${book.name}": ${result.errorMessage}',
        );
        _syncEventsController.add(LinkedSyncEvent(
          bookName: book.name,
          success: false,
          error: result.errorMessage,
        ));
      }
    } catch (e, st) {
      _log.severe('Error auto-syncing "${book.name}"', e, st);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _cacheLastModified(LinkedSongbook book) {
    final modified = book.fileLastModified;
    if (modified != null) {
      _lastModifiedCache[book.path] = modified;
    }
  }
}

/// Provider that creates and manages the [LinkedSongbooksWatcher].
///
/// Starts watching after the app seed completes and linked books are loaded.
/// Disposes on app shutdown.
final linkedSongbooksWatcherProvider = Provider<LinkedSongbooksWatcher>((ref) {
  final db = ref.watch(databaseProvider);
  final watcher = LinkedSongbooksWatcher(db);

  ref.onDispose(watcher.dispose);

  return watcher;
});

/// Provider that starts the watcher once seeding and linked book loading
/// are complete. Watches [linkedSongbooksProvider] and forwards changes
/// to the watcher.
final linkedSongbooksWatcherInitProvider = Provider<void>((ref) {
  final watcher = ref.watch(linkedSongbooksWatcherProvider);
  final linkedAsync = ref.watch(linkedSongbooksProvider);

  linkedAsync.whenData((linkedBooks) {
    if (linkedBooks.isEmpty) return;
    // updateWatchedFiles handles both initial setup and subsequent changes
    watcher.updateWatchedFiles(linkedBooks);
  });
});
