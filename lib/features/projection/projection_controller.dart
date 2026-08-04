import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/core/utils/verse_parser.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/models/verse.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ProjectionState {
  final Song? currentSong;
  final List<Verse> slides;
  final int currentSlideIndex;
  final bool keepAwake;
  final double fontSize;
  final bool autoInsertChorus;
  final bool isSecondaryWindowOpen;
  final bool isBibleMode;
  final String? contentTitle;
  final int? bibleBookId;
  final int? bibleChapter;
  final String? bibleBookName;
  final String projectionMode; // 'single', 'duplicate', 'extended'

  ProjectionState({
    this.currentSong,
    required this.slides,
    required this.currentSlideIndex,
    required this.keepAwake,
    required this.fontSize,
    required this.autoInsertChorus,
    required this.isSecondaryWindowOpen,
    required this.isBibleMode,
    this.contentTitle,
    this.bibleBookId,
    this.bibleChapter,
    this.bibleBookName,
    required this.projectionMode,
  });

  ProjectionState copyWith({
    Song? Function()? currentSong,
    List<Verse>? slides,
    int? currentSlideIndex,
    bool? keepAwake,
    double? fontSize,
    bool? autoInsertChorus,
    bool? isSecondaryWindowOpen,
    bool? isBibleMode,
    String? Function()? contentTitle,
    int? Function()? bibleBookId,
    int? Function()? bibleChapter,
    String? Function()? bibleBookName,
    String? projectionMode,
  }) {
    return ProjectionState(
      currentSong: currentSong != null ? currentSong() : this.currentSong,
      slides: slides ?? this.slides,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      keepAwake: keepAwake ?? this.keepAwake,
      fontSize: fontSize ?? this.fontSize,
      autoInsertChorus: autoInsertChorus ?? this.autoInsertChorus,
      isSecondaryWindowOpen:
          isSecondaryWindowOpen ?? this.isSecondaryWindowOpen,
      isBibleMode: isBibleMode ?? this.isBibleMode,
      contentTitle: contentTitle != null ? contentTitle() : this.contentTitle,
      bibleBookId: bibleBookId != null ? bibleBookId() : this.bibleBookId,
      bibleChapter: bibleChapter != null ? bibleChapter() : this.bibleChapter,
      bibleBookName: bibleBookName != null ? bibleBookName() : this.bibleBookName,
      projectionMode: projectionMode ?? this.projectionMode,
    );
  }

  factory ProjectionState.initial() {
    return ProjectionState(
      currentSong: null,
      slides: [],
      currentSlideIndex: 0,
      keepAwake: true,
      fontSize: 40.0,
      autoInsertChorus: true,
      isSecondaryWindowOpen: false,
      isBibleMode: false,
      contentTitle: null,
      bibleBookId: null,
      bibleChapter: null,
      bibleBookName: null,
      projectionMode: 'extended',
    );
  }

  Verse? get currentSlide {
    if (slides.isEmpty ||
        currentSlideIndex < 0 ||
        currentSlideIndex >= slides.length) {
      return null;
    }
    return slides[currentSlideIndex];
  }

  bool get hasContent => slides.isNotEmpty;
}

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
      final savedMode = _prefs?.getString('projection_mode') ?? 'extended';

      state = state.copyWith(
        fontSize: savedFontSize,
        keepAwake: savedKeepAwake,
        autoInsertChorus: savedAutoChorus,
        projectionMode: savedMode,
      );

      if (state.keepAwake) {
        WakelockPlus.enable();
      }
    } catch (_) {}
  }

  void setSong(Song song) {
    final parsedVerses = VerseParser.parse(song.body);
    final sequence = VerseParser.buildSlideSequence(
      parsedVerses,
      autoInsertChorus: state.autoInsertChorus,
    );

    state = state.copyWith(
      currentSong: () => song,
      slides: sequence,
      currentSlideIndex: 0,
      isBibleMode: false,
      contentTitle: () => song.title,
    );

    _songRepository.addToHistory(song.id);
    _syncSecondaryWindow();
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
    _prefs?.setDouble('projection_font_size', clamped);
    _syncSecondaryWindow();
  }

  Future<void> setAutoInsertChorus(bool value) async {
    state = state.copyWith(autoInsertChorus: value);
    await _prefs?.setBool('projection_auto_chorus', value);

    if (state.currentSong != null) {
      setSong(state.currentSong!);
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

  Future<void> setProjectionMode(String mode) async {
    state = state.copyWith(projectionMode: mode);
    await _prefs?.setString('projection_mode', mode);
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
  }

  void goToNextChapter() => _advanceChapter(1);
  void goToPrevChapter() => _advanceChapter(-1);

  Future<void> projectSongSet(int setId, List<SongSetItem> items) async {
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
          slides.addAll(sequence);
        }
      }
    }

    if (slides.isEmpty) return;
    state = state.copyWith(
      currentSong: () => null,
      slides: slides,
      currentSlideIndex: 0,
      isBibleMode: false,
    );
    _syncSecondaryWindow();
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
      debugPrint('Already in the process of creating a projector window. Ignoring request.');
      return false;
    }

    // If we already have a tracked secondary window from this session,
    // just show it and sync.
    if (_secondaryWindow != null) {
      try {
        await _secondaryWindow!.show();
        debugPrint('Showing existing projector window: ${_secondaryWindow!.windowId}');
        state = state.copyWith(isSecondaryWindowOpen: true);
        // Re-assert fullscreen after a hide/show cycle (Windows restores the
        // original window style on manual close).
        _placeOnSecondScreenAndFullscreen();
        _syncSecondaryWindow();
        return true;
      } catch (e) {
        debugPrint('Tracked secondary window is dead: $e. Will create a new one.');
        _secondaryWindow = null;
      }
    }

    _isCreatingWindow = true;
    try {
      // Always create a fresh window. We do NOT use WindowController.getAll()
      // to find existing windows because it returns stale handles from
      // previous app sessions whose channels are unregistered.
      final window = await WindowController.create(
        const WindowConfiguration(arguments: 'Projection Output'),
      );
      await window.show();
      _secondaryWindow = window;
      debugPrint('Created new projector window: ${window.windowId}');

      state = state.copyWith(isSecondaryWindowOpen: true);

      // Auto-place on second screen and go fullscreen.
      // We send an IPC message to the new window and handle it in
      // _ProjectionOutputViewState._setupSecondaryWindowChannel().
      // This is now triggered on the 'secondary_window_ready' handshake.

      // Do NOT start syncing immediately — the secondary window's IPC handler
      // is not registered yet. Instead, wait for the 'secondary_window_ready'
      // signal from the secondary window (handled in _setupMainWindowHandler).

      return true;
    } catch (e) {
      debugPrint('Failed to open projector window: $e');
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
    try {
      await _secondaryWindow!.invokeMethod('go_fullscreen', {});
      debugPrint('Sent go_fullscreen IPC to secondary window.');
    } catch (e) {
      debugPrint('_placeOnSecondScreenAndFullscreen: $e');
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

  Future<void> _syncSecondaryWindowWithRetry() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (await _syncSecondaryWindow()) {
        debugPrint('Secondary window synced on attempt $attempt');
        break;
      }
    }
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
        debugPrint('Main window received IPC call: ${call.method}');
        if (call.method == 'navigate_slide') {
          final action = call.arguments['action'] as String?;
          if (action == 'prev') {
            prevSlide();
          } else if (action == 'next') {
            nextSlide();
          }
        } else if (call.method == 'secondary_window_closed') {
          debugPrint('Secondary window reported closed.');
          _secondaryWindow = null;
          setSecondaryWindowOpen(false);
        } else if (call.method == 'secondary_window_ready') {
          debugPrint('Secondary window reported ready. Placing and syncing current slide...');
          _placeOnSecondScreenAndFullscreen();
          _syncSecondaryWindowWithRetry();
        } else if (call.method == 'close_secondary_window') {
          // On Linux, the secondary window can't close itself via window_manager
          // (it would crash), so it asks us to do it via WindowController.hide().
          // We keep the reference after hiding so openProjectorWindow() can
          // re-show the same hidden engine instead of leaking a new one per
          // close. Native X-close is handled by onWindowsChanged below.
          debugPrint('Main window received request to close secondary window.');
          if (_secondaryWindow != null) {
            try {
              await _secondaryWindow!.hide();
            } catch (e) {
              debugPrint('Failed to hide secondary window: $e');
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
            debugPrint('Secondary window was natively closed. Updating state.');
            _secondaryWindow = null;
            state = state.copyWith(isSecondaryWindowOpen: false);
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Failed to register main window IPC handler: $e');
    }
  }

  void syncCurrentSlide() {
    _syncSecondaryWindow();
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
      });
      return true;
    } catch (e) {
      debugPrint('Sync failed for window ${_secondaryWindow!.windowId}: $e');
      // During startup, the channel might not be registered yet.
      // Do not clear _secondaryWindow here; let the retry mechanism handle it.
      // Actual window closure is handled by onWindowsChanged and IPC.
      return false;
    }
  }
}

final projectionControllerProvider =
    StateNotifierProvider<ProjectionController, ProjectionState>((ref) {
      final songRepo = ref.watch(songRepositoryProvider);
      final bibleRepo = ref.watch(bibleRepositoryProvider);
      return ProjectionController(songRepo, bibleRepo, ref);
    });
