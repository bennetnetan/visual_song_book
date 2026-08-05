import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        SegmentedButton<ProjectionBackgroundType>(
          segments: const [
            ButtonSegment(
              value: ProjectionBackgroundType.gradient,
              label: Text('Gradient'),
              icon: Icon(Icons.gradient, size: 16),
            ),
            ButtonSegment(
              value: ProjectionBackgroundType.solid,
              label: Text('Color Block'),
              icon: Icon(Icons.format_color_fill, size: 16),
            ),
            ButtonSegment(
              value: ProjectionBackgroundType.image,
              label: Text('Image'),
              icon: Icon(Icons.image, size: 16),
            ),
          ],
          selected: {theme.backgroundType},
          onSelectionChanged: (val) =>
              onChanged(theme.copyWith(backgroundType: val.first)),
          showSelectedIcon: false,
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
            imagePath: theme.imagePath,
            onChanged: (path) => onChanged(theme.copyWith(imagePath: () => path)),
          ),
        },
      ],
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
    final bool useImage = theme.backgroundType ==
            ProjectionBackgroundType.image &&
        theme.imagePath != null &&
        !kIsWeb;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: theme.backgroundType == ProjectionBackgroundType.gradient
              ? RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: theme.gradientColors.isNotEmpty
                      ? theme.gradientColors
                      : const [Color(0xFF0A1A18), Color(0xFF000000)],
                )
              : null,
          color: theme.backgroundType == ProjectionBackgroundType.solid
              ? theme.solidColor
              : null,
          image: useImage
              ? DecorationImage(
                  image: FileImage(File(theme.imagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (useImage)
              ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
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

class _ImageBackgroundEditor extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onChanged;

  const _ImageBackgroundEditor({
    required this.imagePath,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.tonalIcon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
            );
            if (result == null || result.files.single.path == null) return;
            onChanged(result.files.single.path);
          },
          icon: const Icon(Icons.add_photo_alternate, size: 18),
          label: Text(
            imagePath == null ? 'Choose Image' : 'Change Image',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
        ),
        if (imagePath != null) ...[
          const SizedBox(height: 8),
          Text(
            imagePath!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remove image'),
          ),
        ],
      ],
    );
  }
}
