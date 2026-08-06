import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';

/// The kind of background rendered behind projected slides.
enum ProjectionBackgroundType { gradient, solid, image, video }

/// How the up-to-three media backgrounds (images/videos) cycle during
/// projection.
enum MediaRotationMode {
  /// Advance to the next source every time the slide changes.
  perSlide,

  /// Auto-advance through the sources on a timer.
  timed,

  /// Always show the single source picked in the appearance UI.
  manual,
}

/// Maximum number of media sources per background type.
const int kMaxMediaSources = 3;

/// Basename of a local file path, used for display in the media editors.
String fileNameOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final last = normalized.substring(normalized.lastIndexOf('/') + 1);
  return last.isEmpty ? path : last;
}

final _log = AppLogger.get('ProjectionTheme');

/// Appearance configuration for the projection output (slide text color and
/// background). Persisted in SharedPreferences and applied live in
/// [ProjectionOutputView].
class ProjectionTheme {
  /// Slide text color. `null` means the default white.
  final Color? textColor;

  /// When true the slide text color is derived from the background's
  /// luminance so lyrics stay readable on any backdrop.
  final bool autoContrastText;

  /// Which background style is shown behind the slides.
  final ProjectionBackgroundType backgroundType;

  /// Stop colors used by the radial gradient background.
  final List<Color> gradientColors;

  /// Fill color used by the solid ("color block") background.
  final Color solidColor;

  /// Up to [kMaxMediaSources] local image file paths (chosen with the file
  /// picker). Playback of copyrighted media is the operator's responsibility.
  final List<String> imagePaths;

  /// Up to [kMaxMediaSources] local video file paths (chosen with the file
  /// picker). Played muted and looping on the projector.
  final List<String> videoPaths;

  /// How the media sources cycle during projection.
  final MediaRotationMode mediaRotationMode;

  /// Active source index used when [mediaRotationMode] is
  /// [MediaRotationMode.manual].
  final int selectedMediaIndex;

  const ProjectionTheme({
    this.textColor,
    this.autoContrastText = false,
    this.backgroundType = ProjectionBackgroundType.gradient,
    this.gradientColors = const <Color>[
      Color(0xFF0A1A18),
      Color(0xFF000000),
    ],
    this.solidColor = const Color(0xFF000000),
    this.imagePaths = const <String>[],
    this.videoPaths = const <String>[],
    this.mediaRotationMode = MediaRotationMode.manual,
    this.selectedMediaIndex = 0,
  });

  ProjectionTheme copyWith({
    Color? Function()? textColor,
    bool? autoContrastText,
    ProjectionBackgroundType? backgroundType,
    List<Color>? gradientColors,
    Color? solidColor,
    List<String>? imagePaths,
    List<String>? videoPaths,
    MediaRotationMode? mediaRotationMode,
    int? selectedMediaIndex,
  }) {
    return ProjectionTheme(
      textColor: textColor != null ? textColor() : this.textColor,
      autoContrastText: autoContrastText ?? this.autoContrastText,
      backgroundType: backgroundType ?? this.backgroundType,
      gradientColors: gradientColors ?? this.gradientColors,
      solidColor: solidColor ?? this.solidColor,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPaths: videoPaths ?? this.videoPaths,
      mediaRotationMode: mediaRotationMode ?? this.mediaRotationMode,
      selectedMediaIndex: selectedMediaIndex ?? this.selectedMediaIndex,
    );
  }

  /// The colour applied to slide text. When [autoContrastText] is enabled the
  /// colour is derived from the background's luminance so the lyrics stay
  /// readable on any backdrop.
  Color get effectiveTextColor {
    final base = textColor ?? Colors.white;
    if (!autoContrastText) return base;
    final brightness = ThemeData.estimateBrightnessForColor(
      backgroundBaseColor,
    );
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  /// Representative colour of the background used for contrast estimation.
  /// Image/video backdrops render under a dark scrim, so they always assume
  /// dark.
  Color get backgroundBaseColor {
    return switch (backgroundType) {
      ProjectionBackgroundType.solid => solidColor,
      ProjectionBackgroundType.gradient => _averageColor(gradientColors),
      ProjectionBackgroundType.image ||
      ProjectionBackgroundType.video => const Color(0xFF000000),
    };
  }

  /// Resolves the index of the media source that should be shown for
  /// [slideIndex] (advanced every [mediaCycleIndex] ticks for timed mode).
  int resolveMediaIndex({
    required int listLength,
    required int slideIndex,
    required int mediaCycleIndex,
  }) {
    if (listLength <= 0) return 0;
    final i = switch (mediaRotationMode) {
      MediaRotationMode.perSlide => slideIndex % listLength,
      MediaRotationMode.timed => mediaCycleIndex % listLength,
      MediaRotationMode.manual => selectedMediaIndex,
    };
    return i.clamp(0, listLength - 1);
  }

  static Color _averageColor(List<Color> colors) {
    if (colors.isEmpty) return Colors.black;
    if (colors.length == 1) return colors.first;
    var r = 0.0, g = 0.0, b = 0.0;
    for (final c in colors) {
      r += c.r;
      g += c.g;
      b += c.b;
    }
    return Color.from(
      alpha: 1.0,
      red: r / colors.length,
      green: g / colors.length,
      blue: b / colors.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'textColor': textColor?.toARGB32(),
      'autoContrastText': autoContrastText,
      'backgroundType': backgroundType.index,
      'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
      'solidColor': solidColor.toARGB32(),
      'imagePaths': imagePaths,
      'videoPaths': videoPaths,
      'mediaRotationMode': mediaRotationMode.index,
      'selectedMediaIndex': selectedMediaIndex,
    };
  }

  factory ProjectionTheme.fromJson(Map<String, dynamic> json) {
    // Migrate pre-link-removal keys (`imageSources`/`videoLinks`) and the
    // legacy single `imagePath` field into the local-path lists.
    final rawImagePaths = (json['imagePaths'] as List?) ??
        (json['imageSources'] as List?) ??
        const <dynamic>[];
    final legacyImagePath = json['imagePath'] as String?;
    final imagePaths = <String>[
      for (final v in rawImagePaths) v.toString(),
      if (rawImagePaths.isEmpty && legacyImagePath != null) legacyImagePath,
    ];
    final rawVideoPaths = (json['videoPaths'] as List?) ??
        (json['videoLinks'] as List?) ??
        const <dynamic>[];
    final videoPaths = <String>[
      for (final v in rawVideoPaths) v.toString(),
    ];
    return ProjectionTheme(
      textColor: json['textColor'] != null
          ? Color(json['textColor'] as int)
          : null,
      autoContrastText: json['autoContrastText'] as bool? ?? false,
      backgroundType: ProjectionBackgroundType.values[
          (json['backgroundType'] as int?) ?? 0],
      gradientColors: ((json['gradientColors'] as List?) ?? const <dynamic>[])
          .map((v) => Color(v as int))
          .toList(),
      solidColor: Color((json['solidColor'] as int?) ?? 0xFF000000),
      imagePaths: imagePaths,
      videoPaths: videoPaths,
      mediaRotationMode: MediaRotationMode.values[
          (json['mediaRotationMode'] as int?) ?? 0],
      selectedMediaIndex: (json['selectedMediaIndex'] as int?) ?? 0,
    );
  }
}

/// Persists and exposes the projection appearance settings.
class ProjectionThemeNotifier extends StateNotifier<ProjectionTheme> {
  ProjectionThemeNotifier() : super(const ProjectionTheme()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('projection_theme');
      if (raw != null) {
        state = ProjectionTheme.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (e, st) {
      // ignore: missing or corrupt prefs on first launch
      _log.fine('Failed to load projection theme from preferences: $e', e, st);
    }
  }

  Future<void> _persist(ProjectionTheme theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('projection_theme', jsonEncode(theme.toJson()));
    } catch (e, st) {
      // ignore: missing prefs on first launch
      _log.fine('Failed to persist projection theme to preferences: $e', e, st);
    }
  }

  /// Applies a complete theme. Used by the Settings card (live preview) and
  /// the floating appearance sheet (commit of a staged configuration).
  Future<void> setTheme(ProjectionTheme theme) => _persist(theme);

  void reset() => _persist(const ProjectionTheme());
}

final projectionThemeProvider =
    StateNotifierProvider<ProjectionThemeNotifier, ProjectionTheme>(
      (ref) => ProjectionThemeNotifier(),
    );
