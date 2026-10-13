import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/services/app_storage.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class MaintenanceCard extends ConsumerWidget {
  const MaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.build_circle_outlined,
            title: 'Maintenance',
            subtitle: 'Reset, re-verify, and purge temporary state',
          ),
          const SizedBox(height: 20),
          _buildActionItem(
            icon: Icons.history_rounded,
            title: 'Clear Projection History',
            description: 'Wipes recent song, set list, and scripture projections. Does not delete actual songs or sets.',
            onPressed: () => _confirmClearHistory(context, ref),
            buttonLabel: 'Clear',
            theme: theme,
          ),
          const Divider(height: 24),
          _buildActionItem(
            icon: Icons.refresh_rounded,
            title: 'Re-verify Bible Assets',
            description: 'Closes and safely re-copies the default 29MB Bible database if you experience search issues.',
            onPressed: () => _confirmReverifyBible(context, ref),
            buttonLabel: 'Verify',
            theme: theme,
          ),
          const Divider(height: 24),
          _buildActionItem(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Factory Reset Settings',
            description: 'Resets font sizes, themes, and sources to defaults. Triggers the onboarding sequence on next start.',
            onPressed: () => _confirmResetSettings(context, ref),
            buttonLabel: 'Reset',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
    required String buttonLabel,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          ),
          child: Text(buttonLabel, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will permanently delete your projection history (recently shown songs, Bible passages, and set lists). This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final db = ref.read(databaseProvider);
              await db.customStatement('DELETE FROM history');
              await db.customStatement('DELETE FROM set_history');
              await db.customStatement('DELETE FROM bible_history');
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Projection history cleared successfully')),
              );
            },
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }

  void _confirmReverifyBible(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-verify Bible Database'),
        content: const Text(
          'This will close the connection, delete the local KJV Bible SQLite file, and re-copy it fresh from app assets. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final scMessenger = ScaffoldMessenger.of(context);
              try {
                final bibleDb = ref.read(bibleDatabaseProvider);
                bibleDb.close();
                final path = await getAppStorageFilePath('kjv_bible.sqlite');
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();
                }
                await bibleDb.ensureInitialized();
                scMessenger.showSnackBar(
                  const SnackBar(content: Text('Bible database successfully re-verified and copied.')),
                );
              } catch (e) {
                scMessenger.showSnackBar(
                  SnackBar(content: Text('Error re-verifying Bible database: $e')),
                );
              }
            },
            child: const Text('Re-verify'),
          ),
        ],
      ),
    );
  }

  void _confirmResetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset Preferences'),
        content: const Text(
          'This will restore all app settings (font sizes, presentation preferences, and theme choices) to their factory defaults. This will trigger the onboarding flow on the next restart. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final scMessenger = ScaffoldMessenger.of(context);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                scMessenger.showSnackBar(
                  const SnackBar(content: Text('All settings reset to defaults. Please restart the app.')),
                );
              } catch (e) {
                scMessenger.showSnackBar(
                  SnackBar(content: Text('Error resetting settings: $e')),
                );
              }
            },
            child: const Text('Reset Preferences'),
          ),
        ],
      ),
    );
  }
}
