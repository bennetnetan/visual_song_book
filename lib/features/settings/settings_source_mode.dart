
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/models/source_mode.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class SourceModeCard extends ConsumerWidget {
  const SourceModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.source,
            title: 'Song Source',
            subtitle: 'Which songbooks are loaded at startup',
          ),
          const SizedBox(height: 16),
          const _SourceModeSelector(),
        ],
      ),
    );
  }
}

class _SourceModeSelector extends ConsumerStatefulWidget {
  const _SourceModeSelector();

  @override
  ConsumerState<_SourceModeSelector> createState() => _SourceModeSelectorState();
}

class _SourceModeSelectorState extends ConsumerState<_SourceModeSelector> {
  SourceMode _currentMode = SourceMode.unified;
  bool _pendingRestart = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('default_source_mode');
    if (saved != null) {
      setState(() => _currentMode = SourceMode.fromString(saved));
    }
  }

  Future<void> _changeMode(SourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_source_mode', mode.name);
    if (mounted) {
      setState(() {
        _currentMode = mode;
        _pendingRestart = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SegmentedButton<SourceMode>(
            segments: const [
              ButtonSegment(
                value: SourceMode.bundled,
                label: Text('Bundled'),
                icon: Icon(Icons.library_books, size: 16),
              ),
              ButtonSegment(
                value: SourceMode.linked,
                label: Text('Linked'),
                icon: Icon(Icons.link, size: 16),
              ),
              ButtonSegment(
                value: SourceMode.unified,
                label: Text('Both'),
                icon: Icon(Icons.layers, size: 16),
              ),
            ],
            selected: {_currentMode},
            showSelectedIcon: false,
            onSelectionChanged: (Set<SourceMode> selection) {
              if (selection.isNotEmpty) {
                _changeMode(selection.first);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _currentMode.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_pendingRestart) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Restart the app to apply this change.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

