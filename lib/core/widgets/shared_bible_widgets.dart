import 'package:flutter/material.dart';

/// Highlights matching substrings in [text] against [query] with [highlightStyle].
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    int start = 0;
    int indexOfQuery;

    while ((indexOfQuery = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfQuery > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfQuery), style: style));
      }
      spans.add(TextSpan(text: text.substring(indexOfQuery, indexOfQuery + query.length), style: highlightStyle));
      start = indexOfQuery + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Animated verse text with slide-up/fade transition and auto-fit to container size.
class VerseText extends StatelessWidget {
  final String text;
  final double fontSize;

  const VerseText({required this.text, super.key, required this.fontSize});

  double _calculateDefaultFontSize(String text, Size size) {
    if (text.isEmpty) return 40.0;

    final double availWidth = (size.width - 24).clamp(100.0, 10000.0);
    final double availHeight = (size.height - 24).clamp(100.0, 10000.0);

    final List<String> paragraphs = text.split('\n');
    int totalEstimatedLines = 0;
    int maxCharsPerLine = 0;

    const int wrapThreshold = 45;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= wrapThreshold) {
        totalEstimatedLines += 1;
        if (trimmed.length > maxCharsPerLine) {
          maxCharsPerLine = trimmed.length;
        }
      } else {
        final int wrappedCount = (trimmed.length / wrapThreshold).ceil();
        totalEstimatedLines += wrappedCount;
        maxCharsPerLine = wrapThreshold;
      }
    }

    if (totalEstimatedLines == 0) totalEstimatedLines = 1;
    if (maxCharsPerLine == 0) maxCharsPerLine = 10;

    final double sizeByHeight = availHeight / (totalEstimatedLines * 1.45);
    final double sizeByWidth = availWidth / (maxCharsPerLine * 0.55);

    double baseSize = sizeByHeight < sizeByWidth ? sizeByHeight : sizeByWidth;

    return baseSize.clamp(20.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);

        final double baseFontSize = _calculateDefaultFontSize(text, size);

        final double scaleFactor = fontSize / 40.0;
        final double finalFontSize = (baseFontSize * scaleFactor).clamp(14.0, 180.0);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
          child: text.isNotEmpty
              ? Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: finalFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 12,
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 30,
                        color: const Color(0xFF00E5CC).withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Teal-coloured reference label shown below a Bible verse.
class ReferenceLabel extends StatelessWidget {
  final String label;
  final double fontSize;

  const ReferenceLabel({required this.label, super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        label,
        key: ValueKey('ref_$label'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF00E5CC).withValues(alpha: 0.85),
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 8,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
