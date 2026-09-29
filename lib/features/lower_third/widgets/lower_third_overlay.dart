import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';

/// Projection overlay displaying freeform announcements in a customizable lower third carousel.
class LowerThirdOverlay extends StatelessWidget {
  final LowerThirdState state;

  const LowerThirdOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.hasActiveItem) {
      return const SizedBox.shrink();
    }

    final item = state.currentItem!;
    final config = state.config;
    final isFloating = config.isFloating;

    final outerMargin = isFloating
        ? const EdgeInsets.symmetric(horizontal: 40, vertical: 16)
        : EdgeInsets.zero;

    final borderRadius = isFloating
        ? BorderRadius.circular(16)
        : BorderRadius.zero;

    final border = isFloating
        ? Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1.0,
          )
        : Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
          );

    final shadows = isFloating
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ]
        : <BoxShadow>[];

    final effectiveHeight =
        config.height.clamp(config.fontSize + 24.0, 300.0);

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
                maxWidth: isFloating ? 1100 : double.infinity,
                minHeight: effectiveHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: config.effectiveBackgroundColor,
                  borderRadius: borderRadius,
                  border: border,
                  boxShadow: shadows,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
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
                    key: ValueKey(item.id),
                    child: _MarqueeText(
                      text: item.text,
                      style: TextStyle(
                        color: config.textColor,
                        fontFamily: config.fontFamily,
                        fontSize: config.fontSize,
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

/// Renders single-line announcement text. When text is longer than the available
/// space, it smoothly scrolls from right to left so the full message can be read.
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

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _scrollController;
  Timer? _stepTimer;
  bool _isScrolling = false;
  int _cycleId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _cycleId++;
    _stepTimer?.cancel();
    _stepTimer = null;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _cycleId++;
      _stepTimer?.cancel();
      _stepTimer = null;
      _isScrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  void _triggerScrollLoop(double overflowWidth) {
    if (_isScrolling) return;
    _isScrolling = true;
    final int currentCycle = _cycleId;

    _stepTimer?.cancel();
    _stepTimer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted || currentCycle != _cycleId) return;

      if (_scrollController.hasClients) {
        final scrollDistance = overflowWidth + 36.0;
        final durationMs =
            ((scrollDistance / 48.0) * 1000).round().clamp(1200, 50000);

        try {
          await _scrollController.animateTo(
            scrollDistance,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.linear,
          );
        } catch (_) {
          return;
        }
      }
      if (!mounted || currentCycle != _cycleId) return;

      _stepTimer = Timer(const Duration(milliseconds: 1800), () async {
        if (!mounted || currentCycle != _cycleId) return;

        if (_scrollController.hasClients) {
          try {
            await _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
            );
          } catch (_) {
            return;
          }
        }
        if (!mounted || currentCycle != _cycleId) return;

        _isScrolling = false;
        if (mounted) {
          _triggerScrollLoop(overflowWidth);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Measure single-line text width
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        final isOverflowing = textWidth > availableWidth;

        if (!isOverflowing) {
          return Center(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: widget.style,
              maxLines: 1,
            ),
          );
        }

        // Text exceeds space: start right-to-left scrolling
        final overflowWidth = textWidth - availableWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _triggerScrollLoop(overflowWidth);
          }
        });

        // Subtle gradient mask at left & right edges for television-style ticker
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.02, 0.98, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}
