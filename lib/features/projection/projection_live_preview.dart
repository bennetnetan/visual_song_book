import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:visual_song_book/core/utils/layout_utils.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/lower_third/widgets/lower_third_overlay.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_state.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/projection/projection_search_page.dart';


class LivePreviewPanel extends ConsumerWidget {
  final ProjectionState state;
  final ProjectionController notifier;
  final FocusNode projectionFocus;

  const LivePreviewPanel({super.key, 
    required this.state,
    required this.notifier,
    required this.projectionFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSlide = state.currentSlide;
    final isLargeScreen = getLayoutMode(context) == LayoutMode.desktop;
    final ltState = ref.watch(lowerThirdControllerProvider);
    final projTheme = ref.watch(projectionThemeProvider);

    final double mobileClearance = (ltState.isEnabled && ltState.hasActiveItem)
        ? ((ltState.config.height * 0.35).clamp(20.0, 70.0) +
            (ltState.config.isFloating ? 10.0 : 4.0))
        : 0.0;

    final double desktopClearance = (ltState.isEnabled && ltState.hasActiveItem)
        ? ((ltState.config.height * 0.45).clamp(24.0, 90.0) +
            (ltState.config.isFloating ? 12.0 : 6.0))
        : 0.0;

    if (!isLargeScreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isBibleMode && currentSlide != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    currentSlide.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Previous Chapter',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: notifier.goToPrevChapter,
                      tooltip: 'Previous Chapter',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ch. ${state.bibleChapter ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Next Chapter',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: notifier.goToNextChapter,
                      tooltip: 'Next Chapter',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 12.0,
                        right: 12.0,
                        top: 12.0,
                        bottom: 12.0 + mobileClearance,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  currentSlide?.text ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Color.fromARGB(150, 0, 0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (state.isBibleMode && currentSlide != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                currentSlide.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF00E5CC),
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    LowerThirdOverlay(
                      state: ltState,
                      projectionBackground: projTheme.backgroundBaseColor,
                      previewScale: 0.35,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE PREVIEW',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
             ProjectionSearchAnchor(notifier: notifier, returnFocusTo: projectionFocus),
          ],
        ),
        const SizedBox(height: 12),

        // Scripture reference + chapter stepper (Bible mode only)
        if (state.isBibleMode && currentSlide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  currentSlide.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Previous Chapter',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: notifier.goToPrevChapter,
                    tooltip: 'Previous Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  'Ch. ${state.bibleChapter ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Semantics(
                  label: 'Next Chapter',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: notifier.goToNextChapter,
                    tooltip: 'Next Chapter',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

        // 16:9 preview canvas
        Expanded(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [Color(0xFF0A1A18), Color(0xFF000000)],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                          bottom: 16.0 + desktopClearance,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey('${state.currentSlideIndex}_${currentSlide?.label}'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    currentSlide?.text ?? '',
                                    textAlign: TextAlign.center,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Color.fromARGB(150, 0, 0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (state.isBibleMode && currentSlide != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentSlide.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF00E5CC),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      LowerThirdOverlay(
                        state: ltState,
                        projectionBackground: projTheme.backgroundBaseColor,
                        previewScale: 0.45,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Slide / Verse counter
        Center(
          child: Text(
            state.isBibleMode
                ? 'Verse ${state.currentSlideIndex + 1} of ${state.slides.length}'
                : 'Slide ${state.currentSlideIndex + 1} of ${state.slides.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Navigation buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.prevSlide : null,
                icon: const Icon(Icons.arrow_back),
                label: Text(state.isBibleMode ? 'Previous (←)' : 'Previous (←)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.slides.isNotEmpty ? notifier.nextSlide : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(state.isBibleMode ? 'Next (→)' : 'Next (→)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Font size controls
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Decrease Font Size',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: state.fontSize > 16
                        ? () {
                            notifier.setFontSize(state.fontSize - 4);
                            notifier.persistFontSize();
                          }
                        : null,
                    tooltip: 'Decrease (${state.fontSize - 4})',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${state.fontSize.toInt()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Increase Font Size',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: state.fontSize < 160
                        ? () {
                            notifier.setFontSize(state.fontSize + 4);
                            notifier.persistFontSize();
                          }
                        : null,
                    tooltip: 'Increase (${state.fontSize + 4})',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set Navigator Panel — shows set songs and allows jumping to any song in set
// ─────────────────────────────────────────────────────────────────────────────

