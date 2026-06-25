import 'dart:io';
import 'package:flutter/foundation.dart';
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
  /// True when the current content is a Bible passage (not a song).
  final bool isBibleMode;
  /// Title shown on the projection tab header (book+chapter or song title).
  final String? contentTitle;
  /// Bible passage metadata for chapter-aware navigation.
  final int? bibleBookId;
  final int? bibleChapter;
  final String? bibleBookName;

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
  SharedPreferences? _prefs;
  bool _isLoadingChapter = false;

  ProjectionController(this._songRepository, this._bibleRepo)
    : super(ProjectionState.initial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedFontSize = _prefs?.getDouble('projection_font_size') ?? 40.0;
      final savedKeepAwake = _prefs?.getBool('projection_keep_awake') ?? true;
      final savedAutoChorus = _prefs?.getBool('projection_auto_chorus') ?? true;

      state = state.copyWith(
        fontSize: savedFontSize,
        keepAwake: savedKeepAwake,
        autoInsertChorus: savedAutoChorus,
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

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(16.0, 96.0));
    await _prefs?.setDouble('projection_font_size', state.fontSize);
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
    );
    _syncSecondaryWindow();
  }

  void setSecondaryWindowOpen(bool isOpen) {
    state = state.copyWith(isSecondaryWindowOpen: isOpen);
  }

  void syncCurrentSlide() {
    _syncSecondaryWindow();
  }

  void _syncSecondaryWindow() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    final slide = state.currentSlide;
    final text = slide?.text ?? '';
    final label = slide?.label ?? '';
    final fontSize = state.fontSize;
    final isBible = state.isBibleMode;

    debugPrint('Broadcasting slide update: "$text" label="$label" (Size: $fontSize, bible=$isBible)');

    try {
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();

      for (final controller in controllers) {
        if (controller.windowId == currentWindow.windowId) continue;

        debugPrint('Sending update to window ID: ${controller.windowId}');
        await controller
            .invokeMethod('update_slide', {
              'text': text,
              'label': label,
              'fontSize': fontSize,
              'isBible': isBible,
            })
            .then((result) {
              debugPrint(
                'Update successful for window ${controller.windowId}: $result',
              );
            })
            .catchError((e) {
              debugPrint('Update failed for window ${controller.windowId}: $e');
            });
      }
    } catch (e) {
      debugPrint('Error during secondary window sync: $e');
    }
  }
}

final projectionControllerProvider =
    StateNotifierProvider<ProjectionController, ProjectionState>((ref) {
      final songRepo = ref.watch(songRepositoryProvider);
      final bibleRepo = ref.watch(bibleRepositoryProvider);
      return ProjectionController(songRepo, bibleRepo);
    });
