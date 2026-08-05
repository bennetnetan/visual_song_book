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
  final String? referenceLabel;
  final double fontSize;

  const VerseText({
    required this.text,
    this.referenceLabel,
    super.key,
    this.fontSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);

        // Use the user's chosen font size directly as a base.
        // Multiply by 1.35 to map to an appropriate presentation size (e.g. 40 -> 54px).
        double targetSize = fontSize * 1.35;

        // Auto-fit: measure the REAL wrapped height with TextPainter and shrink
        // the font until text + reference label fit the available bounds. This
        // replaces the old character-count estimate, which underestimated the
        // wrapped line count in portrait (text overflowed) and overestimated it
        // in landscape (text rendered smaller than necessary).
        final double availHeight = (size.height - 8).clamp(1.0, 10000.0);
        final double availWidth = size.width.clamp(1.0, 10000.0);

        double finalFontSize = targetSize;
        while (finalFontSize > 18.0) {
          final double referenceHeight =
              (referenceLabel != null && referenceLabel!.isNotEmpty)
                  ? 20.0 + (finalFontSize * 0.45).clamp(20.0, 48.0)
                  : 0.0;
          final TextPainter tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: finalFontSize,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: 0.3,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: availWidth);

          if (tp.height + referenceHeight <= availHeight) break;
          finalFontSize -= 2;
        }
        finalFontSize = finalFontSize.clamp(18.0, 180.0);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          // Override the default Stack layout builder so the child is NOT given
          // tight constraints equal to the full parent height. Using Align lets
          // the Column measure its own intrinsic size (text + 20px + reference)
          // and sit centred — keeping the reference exactly 20px below the text.
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
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
              ? UnconstrainedBox(
                  key: ValueKey('verse_$text'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        // Re-apply the width constraint so text wraps correctly
                        constraints: BoxConstraints(maxWidth: size.width),
                        child: Text(
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
                        ),
                      ),
                      if (referenceLabel != null && referenceLabel!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        ReferenceLabel(
                          label: referenceLabel!,
                          fontSize: (finalFontSize * 0.45).clamp(20.0, 48.0),
                        ),
                      ],
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
