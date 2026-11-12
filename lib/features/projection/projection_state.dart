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

  /// When true, up/down caret cues appear at the bottom right of projected
  /// slides (down on first slide, both in middle, up on last slide).
  final bool showContinuationCarets;

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
    this.showContinuationCarets = true,
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
    bool? showContinuationCarets,
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
      showContinuationCarets:
          showContinuationCarets ?? this.showContinuationCarets,
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
      showContinuationCarets: true,
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

  /// Whether the current slide has a preceding slide in the same song or chapter.
  bool get hasPrevInSong {
    if (slides.isEmpty || currentSlideIndex <= 0 || currentSlideIndex >= slides.length) {
      return false;
    }
    if (isBibleMode) return true;
    final current = slides[currentSlideIndex];
    final prev = slides[currentSlideIndex - 1];
    return current.songTitle == null || prev.songTitle == current.songTitle;
  }

  /// Whether the current slide has a subsequent slide in the same song or chapter.
  bool get hasNextInSong {
    if (slides.isEmpty || currentSlideIndex < 0 || currentSlideIndex >= slides.length - 1) {
      return false;
    }
    if (isBibleMode) return true;
    final current = slides[currentSlideIndex];
    final next = slides[currentSlideIndex + 1];
    return current.songTitle == null || next.songTitle == current.songTitle;
  }

  /// Caret visibility for bottom-right indicators.
  bool get showUpCaret => showContinuationCarets && hasPrevInSong;
  bool get showDownCaret => showContinuationCarets && hasNextInSong;

  /// Whether the current slide is the concluding slide of the current song or chapter.
  bool get isEndSlide {
    if (slides.isEmpty || currentSlideIndex < 0 || currentSlideIndex >= slides.length) {
      return false;
    }
    return !hasNextInSong;
  }

  /// Whether the current slide is the end of a song within a multi-song set.
  bool get isEndOfSongInSet {
    if (isBibleMode || slides.isEmpty) return false;
    if (currentSlideIndex < 0 || currentSlideIndex >= slides.length - 1) return false;
    final current = slides[currentSlideIndex];
    final next = slides[currentSlideIndex + 1];
    return current.songTitle != null &&
        next.songTitle != null &&
        current.songTitle != next.songTitle;
  }

  /// The title of the next song in the queued set, if available.
  String? get nextSongTitle {
    if (isEndOfSongInSet) {
      return slides[currentSlideIndex + 1].songTitle;
    }
    return null;
  }

  /// Operator-facing alert text explaining the end-slide change.
  String? get endNotificationText {
    if (!isEndSlide) return null;
    if (isBibleMode) {
      final book = bibleBookName ?? '';
      final ch = bibleChapter != null ? ' $bibleChapter' : '';
      return 'End of $book$ch'.trim();
    }
    if (isEndOfSongInSet) {
      final next = nextSongTitle;
      return next != null ? 'End of song — Next: $next' : 'End of song';
    }
    if (currentSlideIndex == slides.length - 1) {
      final isSet = slides.any((s) => s.songTitle != null && s.songTitle != slides.first.songTitle);
      return isSet ? 'End of set' : 'End of song';
    }
    return 'End of song';
  }
}
