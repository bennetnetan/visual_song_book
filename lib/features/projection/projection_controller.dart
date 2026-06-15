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
import 'package:wakelock_plus/wakelock_plus.dart';

class ProjectionState {
  final Song? currentSong;
  final List<Verse> slides;
  final int currentSlideIndex;
  final bool keepAwake;
  final double fontSize;
  final bool autoInsertChorus;
  final bool isSecondaryWindowOpen;

  ProjectionState({
    this.currentSong,
    required this.slides,
    required this.currentSlideIndex,
    required this.keepAwake,
    required this.fontSize,
    required this.autoInsertChorus,
    required this.isSecondaryWindowOpen,
  });

  ProjectionState copyWith({
    Song? Function()? currentSong,
    List<Verse>? slides,
    int? currentSlideIndex,
    bool? keepAwake,
    double? fontSize,
    bool? autoInsertChorus,
    bool? isSecondaryWindowOpen,
  }) {
    return ProjectionState(
      currentSong: currentSong != null ? currentSong() : this.currentSong,
      slides: slides ?? this.slides,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      keepAwake: keepAwake ?? this.keepAwake,
      fontSize: fontSize ?? this.fontSize,
      autoInsertChorus: autoInsertChorus ?? this.autoInsertChorus,
      isSecondaryWindowOpen: isSecondaryWindowOpen ?? this.isSecondaryWindowOpen,
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
    );
  }

  Verse? get currentSlide {
    if (slides.isEmpty || currentSlideIndex < 0 || currentSlideIndex >= slides.length) {
      return null;
    }
    return slides[currentSlideIndex];
  }
}

class ProjectionController extends StateNotifier<ProjectionState> {
  final SongRepository _songRepository;
  SharedPreferences? _prefs;

  ProjectionController(this._songRepository) : super(ProjectionState.initial()) {
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

      // Apply initial keep awake state
      if (state.keepAwake) {
        WakelockPlus.enable();
      }
    } catch (_) {
      // Ignore shared_prefs loading errors in stubs/tests
    }
  }

  /// Sets the current song and parses its verses
  void setSong(Song song) {
    // Parse verses
    final parsedVerses = VerseParser.parse(song.body);
    // Build sequence
    final sequence = VerseParser.buildSlideSequence(
      parsedVerses,
      autoInsertChorus: state.autoInsertChorus,
    );

    state = state.copyWith(
      currentSong: () => song,
      slides: sequence,
      currentSlideIndex: 0,
    );

    // Record song to history in repository
    _songRepository.addToHistory(song.id);
    _syncSecondaryWindow();
  }

  /// Clears the current projection (shows blank screen)
  void clearSong() {
    state = state.copyWith(
      currentSong: () => null,
      slides: [],
      currentSlideIndex: 0,
    );
    _syncSecondaryWindow();
  }

  /// Moves to the next slide
  void nextSlide() {
    if (state.slides.isEmpty) return;
    if (state.currentSlideIndex < state.slides.length - 1) {
      state = state.copyWith(currentSlideIndex: state.currentSlideIndex + 1);
      _syncSecondaryWindow();
    }
  }

  /// Moves to the previous slide
  void prevSlide() {
    if (state.slides.isEmpty) return;
    if (state.currentSlideIndex > 0) {
      state = state.copyWith(currentSlideIndex: state.currentSlideIndex - 1);
      _syncSecondaryWindow();
    }
  }

  /// Jumps directly to slide index
  void selectSlide(int index) {
    if (index >= 0 && index < state.slides.length) {
      state = state.copyWith(currentSlideIndex: index);
      _syncSecondaryWindow();
    }
  }

  /// Adjusts the display font size
  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(16.0, 96.0));
    await _prefs?.setDouble('projection_font_size', state.fontSize);
    _syncSecondaryWindow();
  }

  /// Toggles whether chorus is automatically inserted between verses
  Future<void> setAutoInsertChorus(bool value) async {
    state = state.copyWith(autoInsertChorus: value);
    await _prefs?.setBool('projection_auto_chorus', value);
    
    // Rebuild sequence if a song is currently loaded
    if (state.currentSong != null) {
      setSong(state.currentSong!);
    }
  }

  /// Toggles screen keep-awake lock status
  Future<void> setKeepAwake(bool value) async {
    state = state.copyWith(keepAwake: value);
    await _prefs?.setBool('projection_keep_awake', value);

    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  /// Sets whether the secondary output window is currently active/open
  void setSecondaryWindowOpen(bool isOpen) {
    state = state.copyWith(isSecondaryWindowOpen: isOpen);
  }

  /// Manually triggers synchronization of the current slide to the secondary window.
  void syncCurrentSlide() {
    _syncSecondaryWindow();
  }

  void _syncSecondaryWindow() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    final slide = state.currentSlide;
    final text = slide?.text ?? '';
    final fontSize = state.fontSize;

    debugPrint('Broadcasting slide update: "$text" (Size: $fontSize)');

    try {
      // Get all open windows
      final controllers = await WindowController.getAll();
      final currentWindow = await WindowController.fromCurrentEngine();
      
      // We want to send to all OTHER windows.
      for (final controller in controllers) {
        if (controller.windowId == currentWindow.windowId) continue; 
        
        debugPrint('Sending update to window ID: ${controller.windowId}');
        await controller.invokeMethod('update_slide', {
          'text': text,
          'fontSize': fontSize,
        }).then((result) {
          debugPrint('Update successful for window ${controller.windowId}: $result');
        }).catchError((e) {
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
  final repo = ref.watch(songRepositoryProvider);
  return ProjectionController(repo);
});
