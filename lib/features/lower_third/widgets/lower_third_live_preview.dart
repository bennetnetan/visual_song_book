import 'package:flutter/material.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
class LowerThirdLivePreview extends StatelessWidget {
  final LowerThirdConfig config;
  final String previewText;
  final bool isEnabled;

  const LowerThirdLivePreview({
    super.key,
    required this.config,
    required this.previewText,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isFloating = config.isFloating;

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          // Centered mock projection lyric
          const Center(
            child: Text(
              'Sample Projected Verse Text\n(Resized above overlay)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Disabled banner indicator
          if (!isEnabled)
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Turn ON switch above to display on screen',
                      style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          // Lower third overlay at bottom
          Positioned(
            left: isFloating ? 24 : 0,
            right: isFloating ? 24 : 0,
            bottom: isFloating ? 10 : 0,
            child: Container(
              height: (config.height * 0.45).clamp(36.0, 68.0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: config.effectiveBackgroundColor,
                borderRadius:
                    isFloating ? BorderRadius.circular(10) : BorderRadius.zero,
                // No border — matches actual borderless overlay
              ),
              alignment: Alignment.center,
              child: Text(
                previewText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: config.textColor,
                  fontFamily: config.fontFamily,
                  fontSize: (config.fontSize * 0.4).clamp(11.0, 24.0),
                  fontWeight: config.fontWeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
