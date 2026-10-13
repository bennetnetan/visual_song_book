/// Immutable snapshot of what is currently being projected.
///
/// Split out of projection_controller.dart, which holds only the behaviour.
library;

import 'package:visual_song_book/core/models/projection_mode.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/models/verse.dart';

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
  final ProjectionMode projectionMode;

  /// When true, selecting any content to project (a history item, a search
  /// pick, or a song/set from the song book) automatically opens the projector
  /// window — the same result as pressing "Open Projector Output Window".
  /// Defaults to true so operators never open it by hand.
  final bool autoOpenProjector;

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
    this.autoOpenProjector = true,
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
    ProjectionMode? projectionMode,
    bool? autoOpenProjector,
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
      autoOpenProjector: autoOpenProjector ?? this.autoOpenProjector,
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
      projectionMode: ProjectionMode.extended,
      autoOpenProjector: true,
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
