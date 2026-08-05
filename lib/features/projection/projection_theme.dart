import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The kind of background rendered behind projected slides.
enum ProjectionBackgroundType { gradient, solid, image }

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

  /// Absolute path of the image used by the image background.
  final String? imagePath;

  const ProjectionTheme({
    this.textColor,
    this.autoContrastText = false,
    this.backgroundType = ProjectionBackgroundType.gradient,
    this.gradientColors = const <Color>[
      Color(0xFF0A1A18),
      Color(0xFF000000),
    ],
    this.solidColor = const Color(0xFF000000),
    this.imagePath,
  });

  ProjectionTheme copyWith({
    Color? Function()? textColor,
    bool? autoContrastText,
    ProjectionBackgroundType? backgroundType,
    List<Color>? gradientColors,
    Color? solidColor,
    String? Function()? imagePath,
  }) {
    return ProjectionTheme(
      textColor: textColor != null ? textColor() : this.textColor,
      autoContrastText: autoContrastText ?? this.autoContrastText,
      backgroundType: backgroundType ?? this.backgroundType,
      gradientColors: gradientColors ?? this.gradientColors,
      solidColor: solidColor ?? this.solidColor,
      imagePath: imagePath != null ? imagePath() : this.imagePath,
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
  /// Image backdrops render under a dark scrim, so they always assume dark.
  Color get backgroundBaseColor {
    return switch (backgroundType) {
      ProjectionBackgroundType.solid => solidColor,
      ProjectionBackgroundType.gradient => _averageColor(gradientColors),
      ProjectionBackgroundType.image => const Color(0xFF000000),
    };
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
      'imagePath': imagePath,
    };
  }

  factory ProjectionTheme.fromJson(Map<String, dynamic> json) {
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
      imagePath: json['imagePath'] as String?,
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
    } catch (_) {
      // ignore: missing or corrupt prefs on first launch
    }
  }

  Future<void> _persist(ProjectionTheme theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('projection_theme', jsonEncode(theme.toJson()));
    } catch (_) {
      // ignore: missing prefs on first launch
    }
  }

  void setTextColor(Color? color) =>
      _persist(state.copyWith(textColor: () => color));

  void setAutoContrast(bool value) =>
      _persist(state.copyWith(autoContrastText: value));

  void setBackgroundType(ProjectionBackgroundType type) =>
      _persist(state.copyWith(backgroundType: type));

  void setGradientColors(List<Color> colors) =>
      _persist(state.copyWith(gradientColors: colors));

  void setSolidColor(Color color) =>
      _persist(state.copyWith(solidColor: color));

  void setImagePath(String? path) =>
      _persist(state.copyWith(imagePath: () => path));

  void reset() => _persist(const ProjectionTheme());
}

final projectionThemeProvider =
    StateNotifierProvider<ProjectionThemeNotifier, ProjectionTheme>(
      (ref) => ProjectionThemeNotifier(),
    );
