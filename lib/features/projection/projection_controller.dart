import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:visual_song_book/core/models/projection_mode.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/services/share_service.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/core/utils/verse_parser.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/projection/projection_state.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

final _log = AppLogger.get('ProjectionController');

class ProjectionController extends StateNotifier<ProjectionState> {
  final SongRepository _songRepository;
  final BibleRepository _bibleRepo;
  final Ref ref;
  SharedPreferences? _prefs;
  bool _isLoadingChapter = false;
  StreamSubscription<void>? _windowsChangedSubscription;

  /// The secondary projector window we created in THIS session.
  /// We never rely on WindowController.getAll() to rediscover windows because
  /// it can return stale handles from previous app runs.
  WindowController? _secondaryWindow;

  ProjectionController(this._songRepository, this._bibleRepo, this.ref)
    : super(ProjectionState.initial()) {
    // Skip plugin-dependent initialization in secondary windows where
    // SharedPreferences, WakelockPlus, etc. are not registered.
    if (!ref.read(isProjectionWindowProvider)) {
      _loadSettings();
    }
    _setupMainWindowHandler();

    // Push appearance changes to an open projector window immediately.
    // Theme sync otherwise only happens on slide navigation, so changing
    // colors in Settings wouldn't reach an already-open PC projector window.
    ref.listen(projectionThemeProvider, (_, _) {
      _syncSecondaryWindow();
    });

    ref.listen(lowerThirdControllerProvider, (_, _) {
      _syncSecondaryLowerThird();
    });
  }

  @override
  void dispose() {
    _windowsChangedSubscription?.cancel();
    _secondaryWindow = null;
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedFontSize = _prefs?.getDouble('projection_font_size') ?? 40.0;
      final savedKeepAwake = _prefs?.getBool('projection_keep_awake') ?? true;
      final savedAutoChorus = _prefs?.getBool('projection_auto_chorus') ?? true;
      // Auto-opening the projector window is on by default: operators expect
      // projection to start the moment they pick content.
      final savedAutoOpen = _prefs?.getBool('projection_auto_open') ?? true;
      final savedShowCarets =
          _prefs?.getBool('projection_show_carets') ?? true;
      final savedMode = _prefs?.getString('projection_mode') ?? 'extended';
      // 'duplicate' is not implemented yet — fall back to 'extended'.
      final effectiveMode =
          (savedMode == ProjectionMode.single.name ||
                  savedMode == ProjectionMode.extended.name)
              ? ProjectionMode.fromWireName(savedMode)
              : ProjectionMode.extended;

      state = state.copyWith(
        fontSize: savedFontSize,
        keepAwake: savedKeepAwake,
        autoInsertChorus: savedAutoChorus,
        autoOpenProjector: savedAutoOpen,
        showContinuationCarets: savedShowCarets,
        projectionMode: effectiveMode,
      );

      if (state.keepAwake) {
        WakelockPlus.enable();
      }
    } catch (e, st) {
      // ignore: missing prefs on first launch
      _log.fine('Failed to load projection settings from preferences: $e', e, st);
    }
  }

  void setSong(Song song) => _setSong(song);

  void _setSong(Song song, {bool recordHistory = true}) {
    final parsedVerses = VerseParser.parse(song.body);
    final sequence = VerseParser.buildSlideSequence(
      parsedVerses,
      autoInsertChorus: state.autoInsertChorus,
    );
    final taggedSequence = sequence.map((v) => v.copyWith(
      songTitle: song.title,
      songNum: song.songNum,
    )).toList();

    state = state.copyWith(
      currentSong: () => song,
      slides: taggedSequence,
      currentSlideIndex: 0,
      isBibleMode: false,
      contentTitle: () => song.title,
    );

    // Re-projection triggered by a settings toggle (e.g. auto-chorus) must
    // not pollute the history with a duplicate entry.
    if (recordHistory) {
      _songRepository.addToHistory(song.id);
    }
    _syncSecondaryWindow();
    _triggerAutoProjection();
  }

  void clearSong() {
    state = state.copyWith(
      currentSong: () => null,
      slides: [],
      currentSlideIndex: 0,
      isBibleMode: false,
      contentTitle: () => null,
      bibleBookId: () => null,
      bibleChapter: () => null,
      bibleBookName: () => null,
    );
    _syncSecondaryWindow();
  }

  void nextSlide() {
    if (state.slides.isEmpty) return;
    if (state.currentSlideIndex < state.slides.length - 1) {
      state = state.copyWith(currentSlideIndex: state.currentSlideIndex + 1);
      _syncSecondaryWindow();
    } else if (state.isBibleMode && !_isLoadingChapter) {
      _advanceChapter(1);
    }
  }

  void prevSlide() {
    if (state.slides.isEmpty) return;
    if (state.currentSlideIndex > 0) {
      state = state.copyWith(currentSlideIndex: state.currentSlideIndex - 1);
      _syncSecondaryWindow();
    } else if (state.isBibleMode && !_isLoadingChapter) {
      _advanceChapter(-1);
    }
  }

  void selectSlide(int index) {
    if (index >= 0 && index < state.slides.length) {
      state = state.copyWith(currentSlideIndex: index);
      _syncSecondaryWindow();
    }
  }

  void setFontSize(double size) {
    final clamped = size.clamp(16.0, 160.0);
    if (state.fontSize == clamped) return;
    state = state.copyWith(fontSize: clamped);
    _syncSecondaryWindow();
  }

  /// Persists the current font size. Kept separate from [setFontSize] so
  /// pinch-to-zoom gestures don't write SharedPreferences on every frame;
  /// callers flush once when the gesture ends.
  Future<void> persistFontSize() async {
    await _prefs?.setDouble('projection_font_size', state.fontSize);
  }

  Future<void> setAutoInsertChorus(bool value) async {
    state = state.copyWith(autoInsertChorus: value);
    await _prefs?.setBool('projection_auto_chorus', value);

    if (state.currentSong != null) {
      _setSong(state.currentSong!, recordHistory: false);
    }
  }

  Future<void> setKeepAwake(bool value) async {
    state = state.copyWith(keepAwake: value);
    await _prefs?.setBool('projection_keep_awake', value);

    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  Future<void> setProjectionMode(ProjectionMode mode) async {
    state = state.copyWith(projectionMode: mode);
    await _prefs?.setString('projection_mode', mode.name);
    // Switching to a multi-screen mode with auto-open enabled should start
    // projecting immediately, mirroring "Show On" in PowerPoint.
    _triggerAutoProjection();
  }

  /// Toggles whether picking content to project opens the projector window
  /// automatically. On by default so the operator never opens it by hand.
  Future<void> setAutoOpenProjector(bool enabled) async {
    state = state.copyWith(autoOpenProjector: enabled);
    await _prefs?.setBool('projection_auto_open', enabled);
    if (enabled && state.slides.isNotEmpty) {
      _triggerAutoProjection();
    }
  }

  /// Toggles whether up/down continuation carets appear at the bottom right
  /// of projected slides.
  Future<void> setShowContinuationCarets(bool enabled) async {
    state = state.copyWith(showContinuationCarets: enabled);
    await _prefs?.setBool('projection_show_carets', enabled);
    _syncSecondaryWindow();
  }

  /// Project a list of Bible verses. [title] is the passage heading shown in
  /// the control tab (e.g. "John 3" or "Romans 8:28").
  /// Pass [bookId], [chapter], and [bookName] to enable chapter-aware
  /// navigation (auto-advance to next/prev chapter at verse boundaries).
  void setBiblePassage(List<Verse> slides, {String? title, int? bookId, int? chapter, String? bookName}) {
    final heading = title ?? (slides.isNotEmpty ? slides.first.label : 'Bible');
    state = state.copyWith(
      currentSong: () => null,
      slides: slides,
      currentSlideIndex: 0,
      isBibleMode: true,
      contentTitle: () => heading,
      bibleBookId: () => bookId,
      bibleChapter: () => chapter,
      bibleBookName: () => bookName,
    );
    _syncSecondaryWindow();
    _triggerAutoProjection();
  }

  Future<void> _loadChapter(int bookId, int chapter, {int? targetVerse}) async {
    _isLoadingChapter = true;
    try {
      final verses = await _bibleRepo.getVerses(bookId, chapter);
      final bookName = verses.isNotEmpty ? verses.first.bookName ?? '' : '';
      final slides = verses.map((v) => Verse(
        label: '$bookName $chapter:${v.verse}',
        text: v.text,
        order: v.verse,
      )).toList();
      final targetIndex = targetVerse != null
          ? verses.indexWhere((v) => v.verse == targetVerse)
          : 0;
      if (mounted) {
        state = state.copyWith(
          currentSong: () => null,
          slides: slides,
          currentSlideIndex: targetIndex >= 0 ? targetIndex : 0,
          isBibleMode: true,
          contentTitle: () => '$bookName $chapter',
          bibleBookId: () => bookId,
          bibleChapter: () => chapter,
          bibleBookName: () => bookName,
        );
        _syncSecondaryWindow();
        _triggerAutoProjection();
      }
    } finally {
      _isLoadingChapter = false;
    }
  }

  Future<void> projectVerse(int bookId, int chapter, int verse, String bookName) {
    return _loadChapter(bookId, chapter, targetVerse: verse);
  }

  Future<int?> _lastVerse(int bookId, int chapter) async {
    final verses = await _bibleRepo.getVerses(bookId, chapter);
    return verses.isNotEmpty ? verses.last.verse : null;
  }

  Future<void> _advanceChapter(int direction) async {
    final bookId = state.bibleBookId;
    final chapter = state.bibleChapter;
    if (bookId == null || chapter == null) return;

    final nextChapter = chapter + direction;
    final chapters = await _bibleRepo.getChapters(bookId);
    if (chapters.contains(nextChapter)) {
      final targetVerse = direction < 0 ? await _lastVerse(bookId, nextChapter) : null;
      await _loadChapter(bookId, nextChapter, targetVerse: targetVerse);
    } else {
      final books = await _bibleRepo.getBooks();
      final currentIdx = books.indexWhere((b) => b.id == bookId);
      final nextIdx = currentIdx + direction;
      if (nextIdx < 0 || nextIdx >= books.length) return;
      final nextBook = books[nextIdx];
      final nextChapters = await _bibleRepo.getChapters(nextBook.id);
      if (nextChapters.isEmpty) return;
      final targetChapter = direction > 0 ? nextChapters.first : nextChapters.last;
      final targetVerse = direction < 0 ? await _lastVerse(nextBook.id, targetChapter) : null;
      await _loadChapter(nextBook.id, targetChapter, targetVerse: targetVerse);
    }
    _recordChapterHistory();
  }

  void _recordChapterHistory() {
    final bookName = state.bibleBookName;
    final chapter = state.bibleChapter;
    if (bookName == null || chapter == null) return;
    ref
        .read(setRepositoryProvider)
        .recordBibleProjection('$bookName $chapter', state.currentSlide?.text ?? '');
  }

  void goToNextChapter() => _advanceChapter(1);
  void goToPrevChapter() => _advanceChapter(-1);

  Future<void> projectSongSet(
    int setId,
    String setName,
    List<SongSetItem> items,
  ) async {
    if (items.isEmpty) return;

    final slides = <Verse>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final song = await _songRepository.getSongById(item.songId);
      if (song != null) {
        final parsedVerses = VerseParser.parse(song.body);
        final sequence = VerseParser.buildSlideSequence(
          parsedVerses,
          autoInsertChorus: state.autoInsertChorus,
        );
        if (sequence.isNotEmpty) {
          final taggedSequence = sequence.map((v) => v.copyWith(
            songTitle: song.title,
            songNum: song.songNum,
          )).toList();
          slides.addAll(taggedSequence);
        }
        _songRepository.addToHistory(song.id);
      }
    }

    if (slides.isEmpty) return;
    state = state.copyWith(
      currentSong: () => null,
      slides: slides,
      currentSlideIndex: 0,
      isBibleMode: false,
      contentTitle: () => setName,
    );
    ref.read(setRepositoryProvider).recordSetProjection(setId, setName);
    _syncSecondaryWindow();
    _triggerAutoProjection();
  }

  bool _isCreatingWindow = false;

  /// Opens a native projector window on a second display (if available).
  /// Returns true if a secondary window was created; false if the caller
  /// should open the projection fullscreen on the current screen instead.
  Future<bool> openProjectorWindow() async {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return false;

    // Guard against concurrent initialization races.
    if (_isCreatingWindow) {
      _log.warning('Already in the process of creating a projector window. Ignoring request.');
      return false;
    }

    // If we already have a tracked secondary window from this session,
    // just show it and sync.
    if (_secondaryWindow != null) {
      try {
        await _secondaryWindow!.show();
        _log.fine('Showing existing projector window: ${_secondaryWindow!.windowId}');
        state = state.copyWith(isSecondaryWindowOpen: true);
        // Re-assert fullscreen after a hide/show cycle (Windows restores the
        // original window style on manual close).
        _placeOnSecondScreenAndFullscreen();
        _syncSecondaryWindow();
        _syncSecondaryLowerThird();
        return true;
      } catch (e) {
        _log.warning('Tracked secondary window is dead: $e. Will create a new one.');
        _secondaryWindow = null;
      }
    }

    _isCreatingWindow = true;
    try {
      // Always create a fresh window. We do NOT use WindowController.getAll()
      // to find existing windows because it returns stale handles from
      // previous app sessions whose channels are unregistered.
      final window = await WindowController.create(
        WindowConfiguration(
          arguments: 'Projection Output:${state.projectionMode.name}',
        ),
      );
      await window.show();
      _secondaryWindow = window;
      _log.fine('Created new projector window: ${window.windowId}');

      state = state.copyWith(isSecondaryWindowOpen: true);

      // Immediately position on secondary screen and go fullscreen.
      // We also send IPC as a backup when secondary window signals ready.
      await _placeOnSecondScreenAndFullscreen();

      // Do NOT start syncing immediately — the secondary window's IPC handler
      // is not registered yet. Instead, wait for the 'secondary_window_ready'
      // signal from the secondary window (handled in _setupMainWindowHandler).

      return true;
    } catch (e) {
      _log.warning('Failed to open projector window: $e');
      return false;
    } finally {
      _isCreatingWindow = false;
    }
  }

  /// Moves the secondary window to the second screen (if one is connected)
  /// and enters fullscreen automatically.
  /// NOTE: The secondary window now triggers fullscreen itself during init,
  /// so this method is only kept as a fallback re-trigger via IPC.
  Future<void> _placeOnSecondScreenAndFullscreen() async {
    if (_secondaryWindow == null) return;
    // In 'single' mode the window stays a normal decorated window on the
    // primary display — no auto-move and no fullscreen.
    if (state.projectionMode == ProjectionMode.single) return;

    // Use screen_retriever to find secondary display and send bounds via IPC
    if (!(kIsWeb || Platform.isAndroid || Platform.isIOS)) {
      try {
        final displays = await screenRetriever.getAllDisplays();
        _log.fine('Found ${displays.length} display(s)');
        for (final d in displays) {
          _log.fine('Display: ${d.name}, id: ${d.id}, size: ${d.size}, pos: ${d.visiblePosition}');
        }

        // Find a non-primary display (position != 0,0), or use the first if only one exists
        Display? targetDisplay;
        if (displays.length > 1) {
          targetDisplay = displays.firstWhere(
            (d) => d.visiblePosition != null && (d.visiblePosition!.dx != 0 || d.visiblePosition!.dy != 0),
            orElse: () => displays.first,
          );
        } else if (displays.isNotEmpty) {
          targetDisplay = displays.first;
        }

        if (targetDisplay != null) {
          final pos = targetDisplay.visiblePosition ?? Offset.zero;
          final size = targetDisplay.size;
          _log.fine('Targeting display: ${targetDisplay.name} (id: ${targetDisplay.id}), pos: $pos, size: $size');
          // Send display bounds to secondary window via IPC so it can position itself
          await _secondaryWindow!.invokeMethod('set_window_bounds', {
            'left': pos.dx,
            'top': pos.dy,
            'width': size.width,
            'height': size.height,
          });
          _log.fine('Sent set_window_bounds IPC to secondary window: ${pos.dx}, ${pos.dy}, ${size.width}x${size.height}');
        }
      } catch (e, st) {
        _log.warning('Failed to detect displays via screen_retriever: $e', e, st);
      }
    }

    try {
      await _secondaryWindow!.invokeMethod('go_fullscreen', {});
      _log.fine('Sent go_fullscreen IPC to secondary window.');
    } catch (e) {
      _log.warning('_placeOnSecondScreenAndFullscreen: $e');
    }
  }

  Future<void> triggerProjection(BuildContext context, bool isLargeScreen) async {
    if (kIsWeb) {
      if (context.mounted) context.push('/projection');
      return;
    }

    if (isLargeScreen && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final opened = await openProjectorWindow();
      if (opened) {
        ref.read(activeDashboardTabProvider.notifier).state = 4;
        return;
      }
    }

    if (context.mounted) {
      context.push('/projection');
    }
  }

  /// Opens the projector window automatically whenever projection content is
  /// set — the "PowerPoint behaviour" the app needs so operators never drag
  /// the output to the projector by hand, and never press the manual button.
  ///
  /// Fires from every content entry point (`setSong`, `setBiblePassage`,
  /// `_loadChapter`/`projectVerse`, `projectSongSet`), which covers history
  /// items, search picks, the song book and the Bible tab. The window is
  /// placed and fullscreened natively by the platform runner (see
  /// `_placeOnSecondScreenAndFullscreen` and the runner code), which prefers a
  /// non-primary display when one is connected.
  ///
  /// Deliberately mode-agnostic: both `extended` and `single` open a window;
  /// the mode only decides placement/fullscreen. Operators who prefer to open
  /// it themselves can turn it off via `projection_auto_open`.
  void _triggerAutoProjection() {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    if (!state.autoOpenProjector) return;

    // Already projecting — don't spawn a duplicate window.
    if (state.isSecondaryWindowOpen) return;

    // An explicit projection is already creating the window (e.g. SongsTab
    // calling setSong then triggerProjection). Let that one win.
    if (_isCreatingWindow) return;

    // Never run this inside the secondary projection engine itself.
    if (ref.read(isProjectionWindowProvider)) return;

    // Defer so the caller's state update settles first and so a concurrent
    // explicit `triggerProjection` can claim the creation guard.
    Future.microtask(() async {
      if (!state.autoOpenProjector) return;
      if (state.isSecondaryWindowOpen || _isCreatingWindow) return;

      try {
        final opened = await openProjectorWindow();
        if (opened) {
          _log.fine('Auto-projection opened the projector output window.');
          // Surface the projection controls so the operator sees the new state.
          ref.read(activeDashboardTabProvider.notifier).state = 4;
        }
      } catch (e) {
        _log.warning('Auto-projection failed: $e');
      }
    });
  }

  void setSecondaryWindowOpen(bool isOpen) {
    state = state.copyWith(isSecondaryWindowOpen: isOpen);
  }

  void _setupMainWindowHandler() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    if (ref.read(isProjectionWindowProvider)) return;

    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler((call) async {
        _log.fine('Main window received IPC call: ${call.method}');
        if (call.method == 'navigate_slide') {
          final action = call.arguments['action'] as String?;
          if (action == 'prev') {
            prevSlide();
          } else if (action == 'next') {
            nextSlide();
          }
        } else if (call.method == 'secondary_window_closed') {
          _log.fine('Secondary window reported closed.');
          _secondaryWindow = null;
          setSecondaryWindowOpen(false);
        } else if (call.method == 'secondary_window_ready') {
          _log.fine('Secondary window reported ready. Placing and syncing current slide...');
          _placeOnSecondScreenAndFullscreen();
          _syncSecondaryWindow();
          _syncSecondaryLowerThird();
        } else if (call.method == 'close_secondary_window') {
          // On Linux, the secondary window can't close itself via window_manager
          // (it would crash), so it asks us to do it via WindowController.hide().
          // We keep the reference after hiding so openProjectorWindow() can
          // re-show the same hidden engine instead of leaking a new one per
          // close. Native X-close is handled by onWindowsChanged below.
          _log.fine('Main window received request to close secondary window.');
          if (_secondaryWindow != null) {
            try {
              await _secondaryWindow!.hide();
            } catch (e) {
              _log.warning('Failed to hide secondary window: $e');
            }
          }
          setSecondaryWindowOpen(false);
        }
        return 'OK';
      });

      // Also listen for native window close events (e.g. user presses X on the
      // secondary GTK window). onWindowsChanged fires whenever any window is
      // created or destroyed, so we check if the secondary window is gone.
      _windowsChangedSubscription = onWindowsChanged.listen((_) async {
        if (!state.isSecondaryWindowOpen || _secondaryWindow == null) return;
        try {
          final allControllers = await WindowController.getAll();
          final hasOurs = allControllers.any((c) => c.windowId == _secondaryWindow!.windowId);
          if (!hasOurs) {
            _log.fine('Secondary window was natively closed. Updating state.');
            _secondaryWindow = null;
            state = state.copyWith(isSecondaryWindowOpen: false);
          }
        } catch (e, st) {
          // ignore: missing prefs on first launch
          _log.fine('Failed to check secondary window status after window change: $e', e, st);
        }
      });
    } catch (e) {
      _log.severe('Failed to register main window IPC handler: $e');
    }
  }

  /// Sends the current slide to the secondary projector window.
  /// Returns true if the window was updated successfully.
  Future<bool> _syncSecondaryWindow() async {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return false;
    if (!state.isSecondaryWindowOpen || _secondaryWindow == null) return false;

    final slide = state.currentSlide;
    final text = slide?.text ?? '';
    final label = slide?.label ?? '';
    final fontSize = state.fontSize;
    final isBible = state.isBibleMode;
    final projTheme = ref.read(projectionThemeProvider);

    try {
      await _secondaryWindow!.invokeMethod('update_slide', {
        'text': text,
        'label': label,
        'fontSize': fontSize,
        'isBible': isBible,
        // Slide list + position so the secondary engine can render its own
        // in-window navigation (chevrons/dots) — its ProjectionController
        // state is never populated.
        'slideLabels': state.slides.map((v) => v.label).toList(),
        'currentIndex': state.currentSlideIndex,
        // Appearance settings so the secondary engine renders the same
        // background + text color as the main projection.
        'slideTheme': projTheme.toJson(),
        // Caret cues for verse/song/chapter boundary indicators.
        'showUpCaret': state.showUpCaret,
        'showDownCaret': state.showDownCaret,
      });
      return true;
    } catch (e) {
      _log.warning('Sync failed for window ${_secondaryWindow!.windowId}: $e');
      // During startup, the channel might not be registered yet.
      // Do not clear _secondaryWindow here; let the retry mechanism handle it.
      // Actual window closure is handled by onWindowsChanged and IPC.
      return false;
    }
  }

  /// Sends the current lower third carousel state to the secondary projector window.
  Future<void> _syncSecondaryLowerThird() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    if (!state.isSecondaryWindowOpen || _secondaryWindow == null) return;

    try {
      final ltState = ref.read(lowerThirdControllerProvider);
      await _secondaryWindow!.invokeMethod('update_lower_third', ltState.toJson());
    } catch (e, st) {
      _log.fine('Failed to sync lower third over IPC: $e', e, st);
    }
  }

  /// Shares the current slide text using the system-native share sheet.
  Future<void> shareCurrentSlide() async {
    final slide = state.currentSlide;
    if (slide == null) return;

    final buffer = StringBuffer();
    if (state.isBibleMode) {
      buffer.writeln('📖 ${slide.label}');
      buffer.writeln('');
    } else if (state.currentSong != null) {
      final song = state.currentSong!;
      buffer.writeln('🎵 ${song.title}');
      if (song.songNum > 0) buffer.writeln('Song #${song.songNum}');
      if (song.key != null && song.key!.isNotEmpty) buffer.writeln('Key: ${song.key}');
      buffer.writeln('');
    }
    buffer.writeln(slide.text);

    await ShareService.shareText(buffer.toString());
  }
}

final projectionControllerProvider =
    StateNotifierProvider<ProjectionController, ProjectionState>((ref) {
      final songRepo = ref.watch(songRepositoryProvider);
      final bibleRepo = ref.watch(bibleRepositoryProvider);
      return ProjectionController(songRepo, bibleRepo, ref);
    });
