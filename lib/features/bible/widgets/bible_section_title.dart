import 'package:flutter/material.dart';
class BibleSectionTitle extends StatelessWidget {
  final String title;
  final bool isUppercase;

  const BibleSectionTitle({super.key, required this.title, this.isUppercase = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (isUppercase) ...[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          isUppercase ? title.toUpperCase() : title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: isUppercase ? 1.2 : 0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
