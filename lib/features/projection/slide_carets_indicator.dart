import 'package:flutter/material.dart';

/// Renders up and down caret cues at the bottom right of a projected slide.
///
/// • First verse: down arrow caret only (content follows).
/// • Midst of song/passage: both up and down carets (in the middle).
/// • Final verse: up arrow caret only (end of song/passage).
///
/// Both caret slots occupy fixed vertical positions so the indicator does not
/// jump or twitch when navigating between slides.
class SlideCaretsIndicator extends StatelessWidget {
  final bool showUp;
  final bool showDown;
  final Color color;
  final double size;

  const SlideCaretsIndicator({
    super.key,
    required this.showUp,
    required this.showDown,
    required this.color,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!showUp && !showDown) return const SizedBox.shrink();

    final effectiveColor = color.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedOpacity(
          opacity: showUp ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            size: size,
            color: effectiveColor,
          ),
        ),
        AnimatedOpacity(
          opacity: showDown ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: size,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
