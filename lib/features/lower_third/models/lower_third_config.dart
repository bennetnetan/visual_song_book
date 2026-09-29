import 'package:flutter/material.dart';

/// Presentation display style for the lower thirds overlay.
enum LowerThirdStyle {
  /// Spans edge-to-edge across the bottom of the projection screen.
  fullWidth,

  /// Floating card / pill with rounded corners and horizontal padding.
  floatingPill,
}

/// Transition animation between carousel items.
enum LowerThirdAnimation {
  fade,
  slide,
}

/// Appearance and behavior configuration for the lower thirds carousel.
class LowerThirdConfig {
  final LowerThirdStyle style;
  final double height;
  final Color backgroundColor;
  final double backgroundOpacity;
  final Color textColor;
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final int intervalSeconds;
  final LowerThirdAnimation animation;

  const LowerThirdConfig({
    this.style = LowerThirdStyle.floatingPill,
    this.height = 64.0,
    this.backgroundColor = const Color(0xFF0A1A18),
    this.backgroundOpacity = 0.88,
    this.textColor = Colors.white,
    this.fontFamily = 'Outfit',
    this.fontSize = 20.0,
    this.fontWeight = FontWeight.w600,
    this.intervalSeconds = 8,
    this.animation = LowerThirdAnimation.fade,
  });

  bool get isFloating => style == LowerThirdStyle.floatingPill;

  Color get effectiveBackgroundColor =>
      backgroundColor.withValues(alpha: backgroundOpacity.clamp(0.0, 1.0));

  LowerThirdConfig copyWith({
    LowerThirdStyle? style,
    double? height,
    Color? backgroundColor,
    double? backgroundOpacity,
    Color? textColor,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    int? intervalSeconds,
    LowerThirdAnimation? animation,
  }) {
    return LowerThirdConfig(
      style: style ?? this.style,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      animation: animation ?? this.animation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style.index,
      'height': height,
      'backgroundColor': backgroundColor.toARGB32(),
      'backgroundOpacity': backgroundOpacity,
      'textColor': textColor.toARGB32(),
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontWeight': fontWeight.value,
      'intervalSeconds': intervalSeconds,
      'animation': animation.index,
    };
  }

  factory LowerThirdConfig.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['fontWeight'] as int?;
    final resolvedWeight = rawWeight != null
        ? FontWeight.values.firstWhere(
            (w) => w.value == rawWeight,
            orElse: () => FontWeight.w600,
          )
        : FontWeight.w600;

    return LowerThirdConfig(
      style: LowerThirdStyle.values[(json['style'] as int?) ?? 1],
      height: (json['height'] as num?)?.toDouble() ?? 64.0,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : const Color(0xFF0A1A18),
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.88,
      textColor: json['textColor'] != null
          ? Color(json['textColor'] as int)
          : Colors.white,
      fontFamily: (json['fontFamily'] as String?) ?? 'Outfit',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20.0,
      fontWeight: resolvedWeight,
      intervalSeconds: (json['intervalSeconds'] as int?) ?? 8,
      animation: LowerThirdAnimation.values[(json['animation'] as int?) ?? 0],
    );
  }
}
