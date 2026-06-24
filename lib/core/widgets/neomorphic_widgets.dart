import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:google_fonts/google_fonts.dart';

class NeoShadows {
  static List<BoxShadow> raised(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(6, 6),
          blurRadius: 12,
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
          offset: const Offset(-4, -4),
          blurRadius: 10,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        offset: const Offset(6, 6),
        blurRadius: 12,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.6),
        offset: const Offset(-6, -6),
        blurRadius: 12,
      ),
    ];
  }

  static List<BoxShadow> raisedSmall(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          offset: const Offset(-3, -3),
          blurRadius: 6,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        offset: const Offset(4, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.5),
        offset: const Offset(-4, -4),
        blurRadius: 8,
      ),
    ];
  }

  static List<BoxShadow> inset(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(5, 5),
          blurRadius: 10,
          inset: true,
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
          offset: const Offset(-3, -3),
          blurRadius: 8,
          inset: true,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        offset: const Offset(4, 4),
        blurRadius: 8,
        inset: true,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.5),
        offset: const Offset(-4, -4),
        blurRadius: 8,
        inset: true,
      ),
    ];
  }

  static List<BoxShadow> insetSmall(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(3, 3),
          blurRadius: 6,
          inset: true,
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          offset: const Offset(-2, -2),
          blurRadius: 5,
          inset: true,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        offset: const Offset(3, 3),
        blurRadius: 6,
        inset: true,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.4),
        offset: const Offset(-3, -3),
        blurRadius: 6,
        inset: true,
      ),
    ];
  }

}

class NeoRaisedCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? color;

  const NeoRaisedCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(24),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? Theme.of(context).colorScheme.surface;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: NeoShadows.raised(context),
      ),
      child: child,
    );
  }
}

class NeoPressedContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? color;

  const NeoPressedContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? Theme.of(context).colorScheme.surface;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: NeoShadows.inset(context),
      ),
      child: child,
    );
  }
}

class NeoButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;
  final double borderRadius;
  final EdgeInsets padding;
  final String? tooltip;

  const NeoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = false,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.tooltip,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  List<BoxShadow> _buildShadows(bool pressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isPrimary) {
      if (pressed) {
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(4, 4),
            blurRadius: 8,
            inset: true,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            offset: const Offset(-4, -4),
            blurRadius: 8,
            inset: true,
          ),
        ];
      }
      if (isDark) {
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
        ];
      }
      return [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          offset: const Offset(6, 6),
          blurRadius: 12,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.3),
          offset: const Offset(-6, -6),
          blurRadius: 12,
        ),
      ];
    }

    if (pressed) {
      return NeoShadows.insetSmall(context);
    }
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          offset: const Offset(-3, -3),
          blurRadius: 6,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        offset: const Offset(6, 6),
        blurRadius: 12,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.6),
        offset: const Offset(-6, -6),
        blurRadius: 12,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final fgColor = widget.isPrimary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: _isHovered && widget.onPressed != null
                ? Border.all(
                    color: widget.isPrimary
                        ? Colors.white.withValues(alpha: 0.5)
                        : theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: _buildShadows(_isPressed),
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.plusJakartaSans(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.onPressed != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        verticalOffset: 16,
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: theme.colorScheme.onInverseSurface,
          fontSize: 13,
        ),
        child: button,
      );
    }

    return button;
  }
}

class NeoToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const NeoToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 28,
        decoration: BoxDecoration(
          color: value
              ? theme.colorScheme.primary
              : (isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                    inset: true,
                  ),
                ]
              : NeoShadows.insetSmall(context),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
              left: value ? 30.0 : 4.0,
              top: 4.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeoSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const NeoSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        inactiveTrackColor: theme.colorScheme.surface,
        thumbColor: theme.colorScheme.surface,
        overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        thumbShape: const _NeoThumbShape(),
        trackShape: const _NeoTrackShape(),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _NeoThumbShape extends SliderComponentShape {
  const _NeoThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final isDark = sliderTheme.thumbColor!.computeLuminance() < 0.5;

    final paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;

    if (isDark) {
      final shadowPaint1 = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(3, 3), 12, shadowPaint1);

      final shadowPaint2 = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center + const Offset(-2, -2), 12, shadowPaint2);
    } else {
      final shadowPaint1 = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(4, 4), 12, shadowPaint1);

      final shadowPaint2 = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(-4, -4), 12, shadowPaint2);
    }

    canvas.drawCircle(center, 12, paint);

    final dotPaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }
}

class _NeoTrackShape extends SliderTrackShape {
  const _NeoTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));

    final double fraction = (thumbCenter.dx - rect.left) / rect.width;

    final Color trackBg = (sliderTheme.inactiveTrackColor ?? const Color(0xFFE8EAF0));
    final Color trackFill = (sliderTheme.activeTrackColor ?? Colors.blue).withValues(alpha: 0.3);

    // Draw background track
    final bgPaint = Paint()..color = trackBg;
    canvas.drawRRect(rrect, bgPaint);

    // Inset shadow effect
    final shadowPaint1 = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect, shadowPaint1);

    // Draw filled portion (left of thumb)
    if (fraction > 0) {
      final fillRect = Rect.fromLTWH(rect.left, rect.top, rect.width * fraction, rect.height);
      final fillRRect = RRect.fromRectAndRadius(fillRect, const Radius.circular(999));
      final fillPaint = Paint()..color = trackFill;
      canvas.drawRRect(fillRRect, fillPaint);
    }
  }
}

class NeoSegmentedControl<T> extends StatelessWidget {
  final Map<T, Widget> children;
  final T groupValue;
  final ValueChanged<T> onValueChanged;

  const NeoSegmentedControl({
    super.key,
    required this.children,
    required this.groupValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeoShadows.insetSmall(context),
      ),
      child: Row(
        children: children.entries.map((entry) {
          final isSelected = entry.key == groupValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onValueChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    child: entry.value,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
