import 'package:flutter/material.dart';

import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_state.dart';


class SlideList extends StatefulWidget {
  final ProjectionState state;
  final ProjectionController notifier;

  const SlideList({super.key, required this.state, required this.notifier});

  @override
  State<SlideList> createState() => _SlideListState();
}

class _SlideListState extends State<SlideList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToCurrent();
  }

  @override
  void didUpdateWidget(covariant SlideList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.currentSlideIndex != oldWidget.state.currentSlideIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final idx = widget.state.currentSlideIndex;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const itemHeight = 68.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (idx * itemHeight) - (viewportHeight * 0.3);
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.state.slides.length,
      itemBuilder: (context, index) {
        final slide = widget.state.slides[index];
        final isSelected = index == widget.state.currentSlideIndex;
        final prevSlide = index > 0 ? widget.state.slides[index - 1] : null;
        final isNewSong = slide.songTitle != null &&
            (prevSlide == null || prevSlide.songTitle != slide.songTitle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNewSong)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          slide.songNum != null && slide.songNum! > 0
                              ? '${slide.songTitle} (#${slide.songNum})'
                              : (slide.songTitle ?? ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: ListTile(
                tileColor: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: SlideLabelBadge(
                  label: slide.label,
                  isSelected: isSelected,
                  isBible: widget.state.isBibleMode,
                ),
                title: Text(
                  slide.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                onTap: () => widget.notifier.selectSlide(index),
              ),
            ),
          ],
        );
      },
    );
    }
  }

/// Badge showing the slide label. Bible mode: pill for long references.
/// Song mode: square chip for V1, C, etc.
class SlideLabelBadge extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isBible;

  const SlideLabelBadge({super.key, 
    required this.label,
    required this.isSelected,
    required this.isBible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    if (isBible) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview panel — preview canvas + navigation + settings
// ─────────────────────────────────────────────────────────────────────────────

