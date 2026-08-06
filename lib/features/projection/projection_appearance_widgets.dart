import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

final _log = AppLogger.get('ProjectionAppearance');

/// Reusable projection appearance controls (slide text color + background
/// style). Shared by the Settings card and the mobile floating sheet so both
/// stay in sync. The whole configuration is emitted via [onChanged].
class ProjectionAppearanceControls extends StatelessWidget {
  final ProjectionTheme theme;
  final ValueChanged<ProjectionTheme> onChanged;

  const ProjectionAppearanceControls({
    super.key,
    required this.theme,
    required this.onChanged,
  });

  static const List<Color> palette = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF00E5CC),
    Color(0xFF0A1A18),
    Color(0xFF0D47A1),
    Color(0xFF4A148C),
    Color(0xFFB71C1C),
    Color(0xFFF57F17),
    Color(0xFF2E7D32),
    Color(0xFFF48FB1),
    Color(0xFF795548),
    Color(0xFF37474F),
  ];

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Slide text color ──
        const Text(
          'Slide Text Color',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Auto text color',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: const Text(
            'Pick a readable color automatically from the background',
            style: TextStyle(fontSize: 12),
          ),
          value: theme.autoContrastText,
          onChanged: (value) =>
              onChanged(theme.copyWith(autoContrastText: value)),
        ),
        if (!theme.autoContrastText) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in palette)
                _ColorSwatch(
                  color: color,
                  selected: theme.textColor == color,
                  onTap: () =>
                      onChanged(theme.copyWith(textColor: () => color)),
                ),
            ],
          ),
        ],

        const Divider(height: 32),

        // ── Background style ──
        const Text(
          'Background Style',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The backdrop behind the projected lyrics.',
          style: TextStyle(
            fontSize: 12,
            color: appTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ProjectionBackgroundType.values)
              _BackgroundTypeChip(
                type: type,
                selected: theme.backgroundType == type,
                onTap: () =>
                    onChanged(theme.copyWith(backgroundType: type)),
              ),
          ],
        ),
        const SizedBox(height: 16),

        switch (theme.backgroundType) {
          ProjectionBackgroundType.gradient => _GradientColorEditor(
            colors: theme.gradientColors,
            palette: palette,
            onChanged: (colors) =>
                onChanged(theme.copyWith(gradientColors: colors)),
          ),
          ProjectionBackgroundType.solid => _SolidColorEditor(
            color: theme.solidColor,
            palette: palette,
            onChanged: (color) => onChanged(theme.copyWith(solidColor: color)),
          ),
          ProjectionBackgroundType.image => _ImageBackgroundEditor(
            theme: theme,
            onChanged: onChanged,
          ),
          ProjectionBackgroundType.video => _VideoBackgroundEditor(
            theme: theme,
            onChanged: onChanged,
          ),
        },
      ],
    );
  }
}

/// A selectable background-style chip (Wrap-based so it never overflows the
/// narrow mobile sheet).
class _BackgroundTypeChip extends StatelessWidget {
  final ProjectionBackgroundType type;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundTypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  static (IconData, String) _meta(ProjectionBackgroundType type) {
    return switch (type) {
      ProjectionBackgroundType.gradient => (Icons.gradient, 'Gradient'),
      ProjectionBackgroundType.solid => (Icons.format_color_fill, 'Color Block'),
      ProjectionBackgroundType.image => (Icons.image, 'Image'),
      ProjectionBackgroundType.video => (Icons.movie, 'Video'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _meta(type);
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

/// Live preview of a [ProjectionTheme]: background + a sample line of lyrics
/// in the effective text color.
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
          backdrop = const _DefaultPreviewGradient();
        } else {
          backdrop = Stack(
            fit: StackFit.expand,
            children: [
              _PreviewImage(path: path),
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
          backdrop = const _DefaultPreviewGradient();
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
class _DefaultPreviewGradient extends StatelessWidget {
  const _DefaultPreviewGradient();

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
class _PreviewImage extends StatelessWidget {
  final String path;

  const _PreviewImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _DefaultPreviewGradient(),
    );
  }
}

/// Fullscreen looping (muted) video backdrop for a local video file. Used by
/// both the projection output and the appearance preview. Rendered with
/// [video_player] (official backend on mobile, the fvp backend on desktop).
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

class _ImageBackgroundEditor extends StatelessWidget {
  final ProjectionTheme theme;
  final ValueChanged<ProjectionTheme> onChanged;

  const _ImageBackgroundEditor({
    required this.theme,
    required this.onChanged,
  });

  Future<void> _pickFromDisk(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web projection cannot load local files'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (theme.imagePaths.contains(path)) return;
    if (theme.imagePaths.length >= kMaxMediaSources) return;
    onChanged(theme.copyWith(imagePaths: [...theme.imagePaths, path]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaSourceList<String>(
          sources: theme.imagePaths,
          iconFor: (_) => Icons.folder,
          titleFor: fileNameOf,
          subtitleFor: (path) => path,
          onRemove: (path) => onChanged(
            theme.copyWith(
              imagePaths: theme.imagePaths
                  .where((e) => e != path)
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: theme.imagePaths.length >= kMaxMediaSources
                  ? null
                  : () => _pickFromDisk(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose image from disk'),
            ),
          ],
        ),
        if (theme.imagePaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.imagePaths.length,
            onModeChanged: (m) =>
                onChanged(theme.copyWith(mediaRotationMode: m)),
            onIndexChanged: (i) =>
                onChanged(theme.copyWith(selectedMediaIndex: i)),
          ),
        ],
      ],
    );
  }
}

class _VideoBackgroundEditor extends StatelessWidget {
  final ProjectionTheme theme;
  final ValueChanged<ProjectionTheme> onChanged;

  const _VideoBackgroundEditor({
    required this.theme,
    required this.onChanged,
  });

  Future<void> _pickFromDisk(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web projection cannot load local files'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (theme.videoPaths.contains(path)) return;
    if (theme.videoPaths.length >= kMaxMediaSources) return;
    onChanged(theme.copyWith(videoPaths: [...theme.videoPaths, path]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaSourceList<String>(
          sources: theme.videoPaths,
          iconFor: (_) => Icons.play_circle_outline,
          titleFor: fileNameOf,
          subtitleFor: (path) => path,
          onRemove: (path) => onChanged(
            theme.copyWith(
              videoPaths: theme.videoPaths
                  .where((e) => e != path)
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: theme.videoPaths.length >= kMaxMediaSources
                  ? null
                  : () => _pickFromDisk(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose video from disk'),
            ),
          ],
        ),
        if (theme.videoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.videoPaths.length,
            onModeChanged: (m) =>
                onChanged(theme.copyWith(mediaRotationMode: m)),
            onIndexChanged: (i) =>
                onChanged(theme.copyWith(selectedMediaIndex: i)),
          ),
        ],
      ],
    );
  }
}

/// Renders the list of configured media sources (up to three) with a remove
/// button per entry.
class _MediaSourceList<T> extends StatelessWidget {
  final List<T> sources;
  final IconData Function(T source) iconFor;
  final String Function(T source) titleFor;
  final String Function(T source) subtitleFor;
  final ValueChanged<T> onRemove;

  const _MediaSourceList({
    required this.sources,
    required this.iconFor,
    required this.titleFor,
    required this.subtitleFor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No media added yet. Add up to $kMaxMediaSources below.',
          style: TextStyle(
            fontSize: 12,
            color: appTheme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < sources.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: Icon(iconFor(sources[i]), size: 20),
              title: Text(
                titleFor(sources[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                subtitleFor(sources[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove',
                onPressed: () => onRemove(sources[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rotation behaviour selector (per-slide / timed / manual) plus a manual
/// index picker when [MediaRotationMode.manual] is active.
class _MediaRotationControls extends StatelessWidget {
  final MediaRotationMode mode;
  final int selectedIndex;
  final int sourceCount;
  final ValueChanged<MediaRotationMode> onModeChanged;
  final ValueChanged<int> onIndexChanged;

  const _MediaRotationControls({
    required this.mode,
    required this.selectedIndex,
    required this.sourceCount,
    required this.onModeChanged,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Background rotation',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in MediaRotationMode.values)
              ChoiceChip(
                avatar: Icon(_modeIcon(m), size: 16),
                label: Text(_modeLabel(m)),
                selected: mode == m,
                onSelected: (_) => onModeChanged(m),
                showCheckmark: false,
              ),
          ],
        ),
        if (mode == MediaRotationMode.manual) ...[
          const SizedBox(height: 8),
          Text(
            'Show source',
            style: TextStyle(
              fontSize: 12,
              color: appTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < sourceCount; i++)
                ChoiceChip(
                  label: Text('${i + 1}'),
                  selected: selectedIndex == i,
                  onSelected: (_) => onIndexChanged(i),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ],
    );
  }

  static IconData _modeIcon(MediaRotationMode mode) {
    return switch (mode) {
      MediaRotationMode.perSlide => Icons.view_carousel_outlined,
      MediaRotationMode.timed => Icons.timer_outlined,
      MediaRotationMode.manual => Icons.touch_app_outlined,
    };
  }

  static String _modeLabel(MediaRotationMode mode) {
    return switch (mode) {
      MediaRotationMode.perSlide => 'Per slide',
      MediaRotationMode.timed => 'Timed',
      MediaRotationMode.manual => 'Manual',
    };
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkColor = ThemeData.estimateBrightnessForColor(color) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected ? Icon(Icons.check, color: checkColor, size: 18) : null,
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Color> palette;
  final ValueChanged<Color> onChanged;

  const _ColorPickerRow({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in palette)
              _ColorSwatch(
                color: color,
                selected: color == selected,
                onTap: () => onChanged(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _GradientColorEditor extends StatelessWidget {
  final List<Color> colors;
  final List<Color> palette;
  final ValueChanged<List<Color>> onChanged;

  const _GradientColorEditor({
    required this.colors,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = colors.isNotEmpty ? colors.first : Colors.black;
    final end = colors.length > 1 ? colors.last : start;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColorPickerRow(
          label: 'Center color',
          selected: start,
          palette: palette,
          onChanged: (c) => onChanged([c, end]),
        ),
        const SizedBox(height: 12),
        _ColorPickerRow(
          label: 'Edge color',
          selected: end,
          palette: palette,
          onChanged: (c) => onChanged([start, c]),
        ),
      ],
    );
  }
}

class _SolidColorEditor extends StatelessWidget {
  final Color color;
  final List<Color> palette;
  final ValueChanged<Color> onChanged;

  const _SolidColorEditor({
    required this.color,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ColorPickerRow(
      label: 'Fill color',
      selected: color,
      palette: palette,
      onChanged: onChanged,
    );
  }
}
