
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_font_scale_provider.dart';
import 'package:visual_song_book/core/providers/theme_provider.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_state.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final bibleState = ref.watch(bibleControllerProvider);
    final bibleNotifier = ref.read(bibleControllerProvider.notifier);
    final appFontScale = ref.watch(appFontScaleProvider);
    final appFontScaleNotifier = ref.read(appFontScaleProvider.notifier);
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.palette,
            title: 'Appearance',
            subtitle: 'Theme, fonts, and reading experience',
          ),
          const SizedBox(height: 20),
          // ── App Font Size ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Font Size',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Scale all text in the app (helpful on small screens).',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${(appFontScale * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.text_decrease,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: appFontScale,
                  min: AppFontScaleNotifier.minScale,
                  max: AppFontScaleNotifier.maxScale,
                  divisions: 8,
                  label: '${(appFontScale * 100).toStringAsFixed(0)}%',
                  onChanged: (value) => appFontScaleNotifier.setScale(value),
                ),
              ),
              Icon(Icons.text_increase,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 16),
          // ── Theme row ──────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Application Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  )),
              const SizedBox(height: 2),
              Text('Light, dark, or follow the OS',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 15),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 15),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_brightness, size: 15),
                      label: Text('System'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (val) => notifier.setThemeMode(val.first),
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // ── Bible Font ─────────────────────────────────────────
          Text('Bible Reading Font',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 4),
          Text(
            'Typeface for scripture text in the Bible reader.',
            style: TextStyle(
                fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: bibleState.readingFontFamily,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4)),
              ),
            ),
            items: kBibleReadingFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Row(
                  children: [
                    Text(_fontLabel(font),
                        style: TextStyle(
                            fontSize: 14,
                            fontFamily: font,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('— for the LORD is good.',
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: font,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (font) {
              if (font != null) bibleNotifier.setReadingFontFamily(font);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // ── Bible Font Size ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bible Font Size',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('Adjust scripture text size.',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                '${bibleState.bibleFontSize.toStringAsFixed(0)} pt',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: bibleState.bibleFontSize,
            min: 14,
            max: 36,
            divisions: 11,
            label: bibleState.bibleFontSize.toStringAsFixed(0),
            onChanged: (value) => bibleNotifier.setBibleFontSize(value),
          ),
        ],
      ),
    );
  }

  String _fontLabel(String font) => switch (font) {
        'EBGaramond' => 'EB Garamond',
        'Lora' => 'Lora',
        'Inter' => 'Inter',
        _ => font,
      };
}

/// Configures the live projection appearance: slide text color, background
/// style (gradient / color block / image), and auto-contrast text.
