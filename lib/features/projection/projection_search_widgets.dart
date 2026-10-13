import 'package:flutter/material.dart';



class SearchModeToggle extends StatelessWidget {
  final bool isBibleMode;
  final ValueChanged<bool> onToggle;

  const SearchModeToggle({super.key, required this.isBibleMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bibleColor = theme.colorScheme.tertiary;
    final songColor = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModeChip(
          label: 'Bible',
          icon: Icons.menu_book,
          isSelected: isBibleMode,
          selectedColor: bibleColor,
          onTap: () { if (!isBibleMode) onToggle(true); },
        ),
        const SizedBox(width: 6),
        ModeChip(
          label: 'Song',
          icon: Icons.library_music,
          isSelected: !isBibleMode,
          selectedColor: songColor,
          onTap: () { if (isBibleMode) onToggle(false); },
        ),
      ],
    );
  }
}

class ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const ModeChip({super.key, 
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.7)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared search results rendering
//
// The empty projection window embeds search inline (ready to type), while the
// projection controls open the same search in a dialog. Both render their
// results through the helpers below so behaviour and styling stay identical.
// ─────────────────────────────────────────────────────────────────────────────

