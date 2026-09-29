import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_item.dart';
import 'package:visual_song_book/features/projection/projection_appearance_widgets.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';

class LowerThirdSettingsCard extends ConsumerWidget {
  const LowerThirdSettingsCard({super.key});

  static const List<String> availableFonts = [
    'Outfit',
    'Inter',
    'Lora',
    'EBGaramond',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lowerThirdControllerProvider);
    final notifier = ref.read(lowerThirdControllerProvider.notifier);
    final config = state.config;
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  icon: Icons.view_headline_rounded,
                  title: 'Lower Thirds Carousel',
                  subtitle:
                      'Display customizable rotating announcements overlaid at the bottom of the projection.',
                ),
              ),
              Switch(
                value: state.isEnabled,
                onChanged: notifier.setEnabled,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Live Preview ──
          _LowerThirdLivePreview(
            config: config,
            isEnabled: state.isEnabled,
            previewText: state.currentItem?.text ??
                (state.items.isNotEmpty
                    ? state.items.first.text
                    : 'Welcome to our service! We are glad you are here.'),
          ),
          const SizedBox(height: 24),

          // ── SECTION 1: THEME & LAYOUT ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Theme & Layout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore, size: 15),
                label: const Text('Reset Theme to Std'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  notifier.resetThemeSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Theme settings reset to standard defaults.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Display Style (Floating Pill vs Full-width Banner) ──
          const Text(
            'Display Style',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<LowerThirdStyle>(
            segments: const [
              ButtonSegment(
                value: LowerThirdStyle.floatingPill,
                label: Text('Floating Pill'),
                icon: Icon(Icons.rounded_corner, size: 16),
              ),
              ButtonSegment(
                value: LowerThirdStyle.fullWidth,
                label: Text('Full-Width Banner'),
                icon: Icon(Icons.border_bottom, size: 16),
              ),
            ],
            selected: {config.style},
            onSelectionChanged: (selected) {
              notifier.updateConfig(config.copyWith(style: selected.first));
            },
          ),
          const SizedBox(height: 16),

          // ── Background Color ──
          const Text(
            'Background Color',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in ProjectionAppearanceControls.palette)
                _ColorDot(
                  color: color,
                  isSelected:
                      config.backgroundColor.toARGB32() == color.toARGB32(),
                  onTap: () => notifier.updateConfig(
                    config.copyWith(backgroundColor: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Background Opacity Slider ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Background Opacity',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${(config.backgroundOpacity * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: config.backgroundOpacity,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: (val) =>
                notifier.updateConfig(config.copyWith(backgroundOpacity: val)),
          ),
          const SizedBox(height: 12),

          // ── Height & Carousel Interval ──
          // The interval slider is only shown when 2+ items are enabled,
          // because a single item never triggers the carousel timer.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Banner Height',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '${config.height.round()} px',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: config.height.clamp(44.0, 160.0),
                      min: 44.0,
                      max: 160.0,
                      divisions: 29,
                      onChanged: (val) =>
                          notifier.updateConfig(config.copyWith(height: val)),
                    ),
                  ],
                ),
              ),
              if (state.enabledItems.length > 1) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Slide Interval',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${config.intervalSeconds}s',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: config.intervalSeconds.toDouble().clamp(3.0, 60.0),
                        min: 3.0,
                        max: 60.0,
                        divisions: 57,
                        onChanged: (val) => notifier.updateConfig(
                          config.copyWith(intervalSeconds: val.round()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const Divider(height: 32),

          // ── SECTION 2: TEXT & TYPOGRAPHY ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Text & Typography',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt, size: 15),
                label: const Text('Reset Text to Std'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  notifier.resetTextSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Text settings reset to standard defaults.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Text Color ──
          const Text(
            'Text Color',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in ProjectionAppearanceControls.palette)
                _ColorDot(
                  color: color,
                  isSelected:
                      config.textColor.toARGB32() == color.toARGB32(),
                  onTap: () =>
                      notifier.updateConfig(config.copyWith(textColor: color)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Font Family & Size (up to 60px) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Font Family',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final font in availableFonts)
                          ChoiceChip(
                            label: Text(
                              font,
                              style: TextStyle(fontFamily: font),
                            ),
                            selected: config.fontFamily == font,
                            onSelected: (_) => notifier
                                .updateConfig(config.copyWith(fontFamily: font)),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Font Size',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '${config.fontSize.round()} px',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: config.fontSize.clamp(14.0, 60.0),
                      min: 14.0,
                      max: 60.0,
                      divisions: 46,
                      onChanged: (val) =>
                          notifier.updateConfig(config.copyWith(fontSize: val)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 36),

          // ── SECTION 3: ANNOUNCEMENTS CAROUSEL ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Announcements Carousel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.enabledItems.length} active of ${state.items.length} total',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Message'),
                onPressed: () => _showAddEditDialog(context, notifier),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (state.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No announcements added yet. Tap "Add Message" to create one.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.items.length,
              onReorderItem: notifier.reorderItems,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return Material(
                  key: ValueKey(item.id),
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Switch(
                      value: item.isEnabled,
                      onChanged: (_) => notifier.toggleItemEnabled(item.id),
                    ),
                    title: Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.isEnabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        decoration:
                            item.isEnabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => _showAddEditDialog(
                            context,
                            notifier,
                            itemToEdit: item,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          onPressed: () => notifier.deleteItem(item.id),
                        ),
                        const SizedBox(width: 4),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    LowerThirdController notifier, {
    LowerThirdItem? itemToEdit,
  }) {
    final textController = TextEditingController(text: itemToEdit?.text ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(itemToEdit == null ? 'Add Announcement' : 'Edit Announcement'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter announcement text...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                if (itemToEdit == null) {
                  notifier.addItem(text);
                } else {
                  notifier.editItem(itemToEdit.id, text, itemToEdit.isEnabled);
                }
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.white24,
            width: isSelected ? 3.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(Icons.check, color: checkColor, size: 18)
            : null,
      ),
    );
  }
}

class _LowerThirdLivePreview extends StatelessWidget {
  final LowerThirdConfig config;
  final String previewText;
  final bool isEnabled;

  const _LowerThirdLivePreview({
    required this.config,
    required this.previewText,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isFloating = config.isFloating;

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          // Centered mock projection lyric
          const Center(
            child: Text(
              'Sample Projected Verse Text\n(Resized above overlay)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Disabled banner indicator
          if (!isEnabled)
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Turn ON switch above to display on screen',
                      style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          // Lower third overlay at bottom
          Positioned(
            left: isFloating ? 24 : 0,
            right: isFloating ? 24 : 0,
            bottom: isFloating ? 10 : 0,
            child: Container(
              height: (config.height * 0.45).clamp(36.0, 68.0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: config.effectiveBackgroundColor,
                borderRadius:
                    isFloating ? BorderRadius.circular(10) : BorderRadius.zero,
                // No border — matches actual borderless overlay
              ),
              alignment: Alignment.center,
              child: Text(
                previewText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: config.textColor,
                  fontFamily: config.fontFamily,
                  fontSize: (config.fontSize * 0.4).clamp(11.0, 24.0),
                  fontWeight: config.fontWeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
