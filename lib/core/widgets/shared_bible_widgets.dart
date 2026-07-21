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

        // Count estimated wrapped lines to check for height overflow
        final double availHeight = (size.height - 48).clamp(100.0, 10000.0);
        final List<String> paragraphs = text.split('\n');
        int totalLines = 0;
        const int wrapThreshold = 45;

        for (final paragraph in paragraphs) {
          final trimmed = paragraph.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.length <= wrapThreshold) {
            totalLines += 1;
          } else {
            totalLines += (trimmed.length / wrapThreshold).ceil();
          }
        }
        if (totalLines == 0) totalLines = 1;

        // Calculate height needed at targetSize
        final double heightNeeded = totalLines * targetSize * 1.45;
        if (heightNeeded > availHeight) {
          // Scale down to fit the available height
          targetSize = availHeight / (totalLines * 1.45);
        }

        final double finalFontSize = targetSize.clamp(18.0, 180.0);

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
              ? Column(
                  key: ValueKey('verse_$text'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
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
                    if (referenceLabel != null && referenceLabel!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ReferenceLabel(
                        label: referenceLabel!,
                        fontSize: (finalFontSize * 0.45).clamp(20.0, 48.0),
                      ),
                    ],
                  ],
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
