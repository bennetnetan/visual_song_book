
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/projection/projection_media_controls.dart';
import 'package:visual_song_book/features/projection/projection_media_editors.dart';

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
                AppearanceColorSwatch(
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
              BackgroundTypeChip(
                type: type,
                selected: theme.backgroundType == type,
                onTap: () =>
                    onChanged(theme.copyWith(backgroundType: type)),
              ),
          ],
        ),
        const SizedBox(height: 16),

        switch (theme.backgroundType) {
          ProjectionBackgroundType.gradient => GradientColorEditor(
            colors: theme.gradientColors,
            palette: palette,
            onChanged: (colors) =>
                onChanged(theme.copyWith(gradientColors: colors)),
          ),
          ProjectionBackgroundType.solid => SolidColorEditor(
            color: theme.solidColor,
            palette: palette,
            onChanged: (color) => onChanged(theme.copyWith(solidColor: color)),
          ),
          ProjectionBackgroundType.image => ImageBackgroundEditor(
            theme: theme,
            onChanged: onChanged,
          ),
          ProjectionBackgroundType.video => VideoBackgroundEditor(
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
class BackgroundTypeChip extends StatelessWidget {
  final ProjectionBackgroundType type;
  final bool selected;
  final VoidCallback onTap;

  const BackgroundTypeChip({super.key, 
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
