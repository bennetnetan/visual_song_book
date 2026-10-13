import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/projection/projection_media_backgrounds.dart';
class ProjectionPreview extends StatelessWidget {
  final ProjectionTheme theme;

  const ProjectionPreview({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final Widget backdrop;
    switch (theme.backgroundType) {
      case ProjectionBackgroundType.gradient:
        backdrop = DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: theme.gradientColors.isNotEmpty
                  ? theme.gradientColors
                  : const [Color(0xFF0A1A18), Color(0xFF000000)],
            ),
          ),
        );
      case ProjectionBackgroundType.solid:
        backdrop = ColoredBox(color: theme.solidColor);
      case ProjectionBackgroundType.image:
        final path = _activePath(
          theme.imagePaths,
          theme,
          listLength: theme.imagePaths.length,
        );
        if (path == null) {
          backdrop = const DefaultPreviewGradient();
        } else {
          backdrop = Stack(
            fit: StackFit.expand,
            children: [
              PreviewImage(path: path),
              ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            ],
          );
        }
      case ProjectionBackgroundType.video:
        final path = _activePath(
          theme.videoPaths,
          theme,
          listLength: theme.videoPaths.length,
        );
        if (path == null || kIsWeb) {
          backdrop = const DefaultPreviewGradient();
        } else {
          backdrop = ProjectionVideoBackground(path: path);
        }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            backdrop,
            Center(
              child: Text(
                'Sample lyrics',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  color: theme.effectiveTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _activePath(
    List<String> paths,
    ProjectionTheme theme, {
    required int listLength,
  }) {
    if (paths.isEmpty) return null;
    final i = theme.resolveMediaIndex(
      listLength: listLength,
      slideIndex: 0,
      mediaCycleIndex: 0,
    );
    return paths[i];
  }
}

/// Static teal-to-black gradient used by the preview fallback.
class DefaultPreviewGradient extends StatelessWidget {
  const DefaultPreviewGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF0A1A18), Color(0xFF000000)],
        ),
      ),
    );
  }
}

/// Renders a local image file in a preview. Falls back to the default
/// gradient if the file no longer exists.
class PreviewImage extends StatelessWidget {
  final String path;

  const PreviewImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const DefaultPreviewGradient(),
    );
  }
}

/// Fullscreen looping (muted) video backdrop for a local video file. Used by
/// both the projection output and the appearance preview. Rendered with
/// [video_player] (official backend on mobile, the fvp backend on desktop).
