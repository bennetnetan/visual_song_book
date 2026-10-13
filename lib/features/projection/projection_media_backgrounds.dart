import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';


final _log = AppLogger.get('ProjectionAppearanceBackgrounds');
class ProjectionVideoBackground extends StatefulWidget {
  final String path;

  /// Whether a dark scrim is layered over the video.
  final bool showScrim;

  const ProjectionVideoBackground({
    super.key,
    required this.path,
    this.showScrim = true,
  });

  @override
  State<ProjectionVideoBackground> createState() =>
      _ProjectionVideoBackgroundState();
}

class _ProjectionVideoBackgroundState extends State<ProjectionVideoBackground> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _init();
  }

  @override
  void didUpdateWidget(covariant ProjectionVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller.dispose();
      _controller = VideoPlayerController.file(File(widget.path));
      _failed = false;
      _init();
    }
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0.0);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (e, st) {
      // ignore: unplayable file — show a plain black backdrop
      _log.fine('Failed to initialize projection video background: $e', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    if (_failed) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    if (!value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFF000000),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }
    final videoSize = value.size;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(_controller),
          ),
        ),
        if (widget.showScrim)
          ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
      ],
    );
  }
}

