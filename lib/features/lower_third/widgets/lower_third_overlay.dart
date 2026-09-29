import 'package:flutter/material.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';

/// Projection overlay displaying freeform announcements in a customizable lower third carousel.
///
/// [projectionBackground] — the representative base colour of the projection
/// background (e.g. `projTheme.backgroundBaseColor`). When provided, the banner
/// background is derived from this colour rather than a fixed black, so the
/// overlay visually belongs to the same world as the slide content behind it.
class LowerThirdOverlay extends StatelessWidget {
  final LowerThirdState state;

  /// Optional: the projection background's representative colour. When supplied
  /// and the user hasn't selected a custom background color, the banner tints
  /// itself to match, creating visual continuity with the slide.
  final Color? projectionBackground;

  /// Scale factor for embedded previews (e.g. 0.45 for the 16:9 monitor on ProjectionTab).
  final double previewScale;

  const LowerThirdOverlay({
    super.key,
    required this.state,
    this.projectionBackground,
    this.previewScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.hasActiveItem) {
      return const SizedBox.shrink();
    }

    final item = state.currentItem!;
    final config = state.config;
    final isFloating = config.isFloating;

    final outerMargin = isFloating
        ? EdgeInsets.symmetric(
            horizontal: 40.0 * previewScale,
            vertical: 16.0 * previewScale,
          )
        : EdgeInsets.zero;

    final borderRadius = isFloating
        ? BorderRadius.circular(16.0 * previewScale)
        : BorderRadius.zero;

    // Derive the banner colour. If the user picked a specific background color,
    // honor it directly. If it's the default background color, harmonize with
    // the slide backdrop when available.
    final Color bannerColor;
    if (config.backgroundColor != const Color(0xFF0A1A18)) {
      bannerColor = config.effectiveBackgroundColor;
    } else if (projectionBackground != null) {
      bannerColor = Color.alphaBlend(
        projectionBackground!.withValues(alpha: 0.72),
        Colors.black,
      ).withValues(alpha: config.backgroundOpacity);
    } else {
      bannerColor = config.effectiveBackgroundColor;
    }

    final shadows = isFloating
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20.0 * previewScale,
              offset: Offset(0, 6.0 * previewScale),
            ),
          ]
        : <BoxShadow>[];

    final effectiveHeight =
        (config.height * previewScale).clamp(20.0, 300.0);
    final effectiveFontSize =
        (config.fontSize * previewScale).clamp(9.0, 60.0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: outerMargin,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isFloating ? (1100.0 * previewScale) : double.infinity,
                minHeight: effectiveHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: borderRadius,
                  // No border — the overlay integrates seamlessly with the slide.
                  boxShadow: shadows,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0 * previewScale,
                  vertical: 8.0 * previewScale,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    if (config.animation == LowerThirdAnimation.slide) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    }
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${item.id}_${config.style}_${config.height.round()}_${effectiveFontSize.round()}_${config.textColor.toARGB32()}_${config.fontFamily}',
                    ),
                    child: _MarqueeText(
                      text: item.text,
                      style: TextStyle(
                        color: config.textColor,
                        fontFamily: config.fontFamily,
                        fontSize: effectiveFontSize,
                        fontWeight: config.fontWeight,
                        height: 1.25,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders announcement text on a single line.
///
/// - If the text fits within the available width it is displayed centered.
/// - If the text is wider than the available space it scrolls continuously
///   from right to left (ticker/marquee style). The text starts fully off
///   the right edge, travels left at [_speed] px/s, and loops seamlessly
///   once it has left the left edge.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// Scroll speed in logical pixels per second.
  static const double _speed = 60.0;

  /// Blank gap appended after the text before the loop restarts (px).
  static const double _gap = 80.0;

  // Cache the last layout parameters to avoid restarting unnecessarily.
  double _lastTextWidth = 0;
  double _lastContainerWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        // Loop: when the animation completes, restart from 0.
        if (status == AnimationStatus.completed && mounted) {
          _controller.forward(from: 0.0);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      // Reset cached sizes so the marquee restarts cleanly for new content.
      _controller.stop();
      _lastTextWidth = 0;
      _lastContainerWidth = 0;
    }
  }

  /// Configures and starts the animation controller for the given layout.
  void _startMarquee(double textWidth, double containerWidth) {
    // Skip if nothing changed to avoid restarting on every rebuild.
    if (_lastTextWidth == textWidth &&
        _lastContainerWidth == containerWidth &&
        _controller.isAnimating) {
      return;
    }

    _lastTextWidth = textWidth;
    _lastContainerWidth = containerWidth;

    // The text travels its full width plus a gap before the loop restarts.
    final totalTravel = textWidth + _gap;
    final durationMs = ((totalTravel / _speed) * 1000).round();

    _controller.duration = Duration(milliseconds: durationMs);
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;

        // Measure the single-line text width using TextPainter.
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        final isOverflowing = textWidth > containerWidth;

        if (!isOverflowing) {
          // Text fits — stop any running animation and show it centered.
          if (_controller.isAnimating) _controller.stop();
          return Center(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          );
        }

        // Text overflows — kick off the marquee after the first frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startMarquee(textWidth, containerWidth);
        });

        // Total scroll distance per loop: full text width + gap.
        final totalTravel = textWidth + _gap;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // At _controller.value == 0 the text starts with its left edge
              // at the container's right edge (fully off screen to the right).
              // At _controller.value == 1 it has moved left by totalTravel,
              // placing it fully off screen to the left → seamless loop.
              final dx = containerWidth - _controller.value * totalTravel;

              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      },
    );
  }
}
