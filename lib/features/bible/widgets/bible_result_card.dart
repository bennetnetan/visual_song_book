import 'package:flutter/material.dart';
import 'package:visual_song_book/core/widgets/shared_bible_widgets.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';
class BibleResultCard extends StatelessWidget {
  final BibleVerse verse;
  final String query;
  final String fontFamily;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isBookmarked;

  const BibleResultCard({
    super.key,
    required this.verse,
    required this.query,
    required this.fontFamily,
    required this.onTap,
    this.onLongPress,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    verse.reference,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    verse.bookId <= 39 ? 'Old Testament' : 'New Testament',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (isBookmarked)
                    Icon(Icons.bookmark,
                        size: 14, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 8),
              HighlightedText(
                text: verse.text,
                query: query,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
                highlightStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 20,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

