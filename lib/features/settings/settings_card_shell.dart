
import 'package:flutter/material.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(12));
    return Container(
      margin: EdgeInsets.zero,
      // The background lives on a Material, not on a DecoratedBox: ListTile
      // and SwitchListTile rows inside this card paint their ink splashes on
      // the nearest Material ancestor, so a coloured Container would hide
      // them (Flutter's "ListTile background color or ink splashes may be
      // invisible" assertion). The border stays on the transparent Container
      // so the card looks exactly the same.
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: accentColor,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

