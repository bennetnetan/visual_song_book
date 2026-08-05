import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visual_song_book/features/projection/image_link_cache.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

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
        Text(
          'Slide Text Color',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Auto text color',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Pick a readable color automatically from the background',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
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
        Text(
          'Background Style',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The backdrop behind the projected lyrics.',
          style: GoogleFonts.plusJakartaSans(
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
        final source = _activeSource(
          theme.imageSources,
          theme,
          listLength: theme.imageSources.length,
        );
        if (source == null) {
          backdrop = const _DefaultPreviewGradient();
        } else {
          backdrop = Stack(
            fit: StackFit.expand,
            children: [
              _PreviewImage(source: source),
              ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            ],
          );
        }
      case ProjectionBackgroundType.video:
        final url = _activeLink(
          theme.videoLinks,
          theme,
          listLength: theme.videoLinks.length,
        );
        if (url == null || kIsWeb) {
          backdrop = const _DefaultPreviewGradient();
        } else {
          backdrop = ProjectionVideoBackground(url: url);
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

  static ImageSource? _activeSource(
    List<ImageSource> sources,
    ProjectionTheme theme, {
    required int listLength,
  }) {
    if (sources.isEmpty) return null;
    final i = theme.resolveMediaIndex(
      listLength: listLength,
      slideIndex: 0,
      mediaCycleIndex: 0,
    );
    return sources[i];
  }

  static String? _activeLink(
    List<String> links,
    ProjectionTheme theme, {
    required int listLength,
  }) {
    if (links.isEmpty) return null;
    final i = theme.resolveMediaIndex(
      listLength: listLength,
      slideIndex: 0,
      mediaCycleIndex: 0,
    );
    return links[i];
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

/// Renders an image source (local file or cached/remote link) in a preview.
class _PreviewImage extends StatelessWidget {
  final ImageSource source;

  const _PreviewImage({required this.source});

  @override
  Widget build(BuildContext context) {
    if (!source.isLink) {
      return Image.file(File(source.value), fit: BoxFit.cover);
    }
    if (kIsWeb) {
      return Image.network(source.value, fit: BoxFit.cover);
    }
    return FutureBuilder<File?>(
      future: ImageLinkCache.cachedFile(source.value),
      builder: (context, snapshot) {
        final cached = snapshot.data;
        if (cached != null) {
          return Image.file(cached, fit: BoxFit.cover);
        }
        return Image.network(source.value, fit: BoxFit.cover);
      },
    );
  }
}

/// Fullscreen looping (muted) video backdrop for remote links. Used by both
/// the projection output and the appearance preview.
class ProjectionVideoBackground extends StatefulWidget {
  final String url;

  /// Whether a dark scrim is layered over the video.
  final bool showScrim;

  const ProjectionVideoBackground({
    super.key,
    required this.url,
    this.showScrim = true,
  });

  @override
  State<ProjectionVideoBackground> createState() =>
      _ProjectionVideoBackgroundState();
}

class _ProjectionVideoBackgroundState extends State<ProjectionVideoBackground> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open(widget.url);
  }

  @override
  void didUpdateWidget(covariant ProjectionVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _open(widget.url);
    }
  }

  Future<void> _open(String url) async {
    try {
      await _player.setVolume(0.0);
      await _player.setPlaylistMode(PlaylistMode.loop);
      await _player.open(Media(url));
    } catch (_) {
      // ignore: unplayable link — show the empty backdrop
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
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
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final source = ImageSource(result.files.single.path!);
    if (theme.imageSources.contains(source)) return;
    if (theme.imageSources.length >= kMaxMediaSources) return;
    onChanged(
      theme.copyWith(imageSources: [...theme.imageSources, source]),
    );
  }

  Future<void> _addLink(BuildContext context) async {
    final url = await _promptForLink(context, title: 'Add Image Link');
    if (url == null) return;
    final source = ImageSource(url);
    if (theme.imageSources.contains(source)) return;
    if (theme.imageSources.length >= kMaxMediaSources) return;
    onChanged(
      theme.copyWith(imageSources: [...theme.imageSources, source]),
    );
    // Cache now so projection doesn't refetch on every frame.
    if (ImageLinkCache.isSupported) {
      try {
        await ImageLinkCache.ensureCached(url);
      } catch (_) {
        // ignore: the link may still render via NetworkImage
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaSourceList<ImageSource>(
          sources: theme.imageSources,
          iconFor: (s) => s.isLink ? Icons.link : Icons.folder,
          titleFor: (s) => s.displayName,
          subtitleFor: (s) => s.value,
          onRemove: (s) => onChanged(
            theme.copyWith(
              imageSources: theme.imageSources
                  .where((e) => e.value != s.value)
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
              onPressed: theme.imageSources.length >= kMaxMediaSources
                  ? null
                  : () => _pickFromDisk(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose from disk'),
            ),
            FilledButton.tonalIcon(
              onPressed: theme.imageSources.length >= kMaxMediaSources
                  ? null
                  : () => _addLink(context),
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Add Image Link'),
            ),
          ],
        ),
        if (ImageLinkCache.isSupported) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await ImageLinkCache.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image link cache cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.cleaning_services, size: 18),
            label: const Text('Clear image cache'),
          ),
        ],
        if (theme.imageSources.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.imageSources.length,
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

  Future<void> _addLink(BuildContext context) async {
    final url = await _promptForLink(context, title: 'Add Video Link');
    if (url == null) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video links must be http(s) URLs'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (theme.videoLinks.contains(url)) return;
    if (theme.videoLinks.length >= kMaxMediaSources) return;
    onChanged(theme.copyWith(videoLinks: [...theme.videoLinks, url]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaSourceList<String>(
          sources: theme.videoLinks,
          iconFor: (_) => Icons.play_circle_outline,
          titleFor: (url) {
            try {
              return Uri.parse(url).host;
            } catch (_) {
              return url;
            }
          },
          subtitleFor: (url) => url,
          onRemove: (url) => onChanged(
            theme.copyWith(
              videoLinks: theme.videoLinks
                  .where((e) => e != url)
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
              onPressed: theme.videoLinks.length >= kMaxMediaSources
                  ? null
                  : () => _addLink(context),
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Add Video Link'),
            ),
          ],
        ),
        if (theme.videoLinks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.videoLinks.length,
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
          style: GoogleFonts.plusJakartaSans(
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
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                subtitleFor(sources[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 11),
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
        Text(
          'Background rotation',
          style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
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

/// Asks the user for a media link and returns it (or null when cancelled).
Future<String?> _promptForLink(
  BuildContext context, {
  required String title,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://example.com/media.mp4',
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  );
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
          style: GoogleFonts.plusJakartaSans(
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
