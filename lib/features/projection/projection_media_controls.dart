
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
class MediaRotationControls extends StatelessWidget {
  final MediaRotationMode mode;
  final int selectedIndex;
  final int sourceCount;
  final ValueChanged<MediaRotationMode> onModeChanged;
  final ValueChanged<int> onIndexChanged;

  const MediaRotationControls({super.key, 
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

class AppearanceColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const AppearanceColorSwatch({super.key, 
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

class ColorPickerRow extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Color> palette;
  final ValueChanged<Color> onChanged;

  const ColorPickerRow({super.key, 
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
              AppearanceColorSwatch(
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

class GradientColorEditor extends StatelessWidget {
  final List<Color> colors;
  final List<Color> palette;
  final ValueChanged<List<Color>> onChanged;

  const GradientColorEditor({super.key, 
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
        ColorPickerRow(
          label: 'Center color',
          selected: start,
          palette: palette,
          onChanged: (c) => onChanged([c, end]),
        ),
        const SizedBox(height: 12),
        ColorPickerRow(
          label: 'Edge color',
          selected: end,
          palette: palette,
          onChanged: (c) => onChanged([start, c]),
        ),
      ],
    );
  }
}

class SolidColorEditor extends StatelessWidget {
  final Color color;
  final List<Color> palette;
  final ValueChanged<Color> onChanged;

  const SolidColorEditor({super.key, 
    required this.color,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ColorPickerRow(
      label: 'Fill color',
      selected: color,
      palette: palette,
      onChanged: onChanged,
    );
  }
}
