import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/importers/vsbook_importer.dart';
import 'package:visual_song_book/data/services/linked_songbooks_service.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class LinkedSongbooksCard extends ConsumerWidget {
  const LinkedSongbooksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedAsync = ref.watch(linkedSongbooksProvider);
    final theme = Theme.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.sync,
            title: 'Linked Songbooks',
            subtitle: 'Auto-sync .vsbook files from Google Drive or shared folders',
          ),
          const SizedBox(height: 16),
          linkedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading: $e'),
            data: (linked) {
              if (linked.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No linked songbooks yet.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "Link File" to get started.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: linked.map((book) {
                  final exists = book.fileExists;
                  final needsSync = book.hasChangedSinceLastImport;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: exists
                              ? (needsSync
                                    ? theme.colorScheme.tertiary.withValues(alpha: 0.1)
                                    : theme.colorScheme.primary.withValues(alpha: 0.1))
                              : theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          exists
                              ? (needsSync
                                    ? Icons.sync
                                    : Icons.check_circle_outline)
                              : Icons.error_outline,
                          size: 20,
                          color: exists
                              ? (needsSync ? theme.colorScheme.tertiary : theme.colorScheme.primary)
                              : theme.colorScheme.error,
                        ),
                      ),
                      title: Text(
                        book.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.path,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!exists)
                            Text(
                              'File not found',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (needsSync)
                            const Text(
                              'Changes detected — will sync on next startup',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (book.lastImportedAt != null)
                            Text(
                              'Last synced: ${_formatDate(book.lastImportedAt!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                      trailing: Semantics(
                        label: 'Unlink',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.link_off, size: 20),
                          color: theme.colorScheme.error,
                          tooltip: 'Unlink',
                          onPressed: () => _unlink(context, ref, book),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _linkFile(context, ref),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Link File'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              if (linkedAsync.hasValue && linkedAsync.value!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _syncAll(context, ref),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _linkFile(BuildContext context, WidgetRef ref) async {
    try {
      // .vsb/.mdb files are auto-converted to .vsbook on import.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vsbook', 'vsb', 'mdb'],
      );
      if (result.isEmpty || result.single.path == null) return;
      final path = result.single.path!;
      final name = result.single.name;

      // Check if already linked
      final existing = ref.read(linkedSongbooksProvider).value ?? [];
      if (existing.any((s) => s.path == path)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" is already linked.')),
          );
        }
        return;
      }

      // Check file exists
      if (!File(path).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.error,
              content: Text('File not found: $name'),
            ),
          );
        }
        return;
      }

      // Link it
      await ref.read(linkedSongbooksProvider.notifier).add(path, name: name);

      // Import immediately so the linked source can be used without a restart.
      final importer = VsBookImporter(ref.read(databaseProvider));
      final importResult = await importer.reimportSource(path);
      if (importResult.success) {
        await ref.read(linkedSongbooksProvider.notifier).markImported(path);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              importResult.success
                  ? 'Linked "$name" and imported ${importResult.songsImported} songs.'
                  : 'Linked "$name", but import failed: ${importResult.errorMessage}',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Failed to link file: $e'),
          ),
        );
      }
    }
  }

  void _unlink(BuildContext context, WidgetRef ref, LinkedSongbook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Songbook'),
        content: Text('Remove "${book.name}" from linked songbooks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(linkedSongbooksProvider.notifier)
                  .remove(book.path);
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final linked = ref.read(linkedSongbooksProvider).value ?? [];
    final needsSync = linked
        .where((b) => b.hasChangedSinceLastImport && b.fileExists)
        .toList();
    if (needsSync.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All linked songbooks are up to date.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Syncing ${needsSync.length} songbook(s)...')),
      );
    }

    for (final book in needsSync) {
      final file = File(book.path);
      if (!file.existsSync()) continue;

      final ext = book.path.toLowerCase();
      if (ext.endsWith('.vsbook') || ext.endsWith('.vsb') || ext.endsWith('.mdb')) {
        final db = ref.read(databaseProvider);
        final importer = VsBookImporter(db);
        final result = await importer.reimportSource(book.path);
        if (result.success) {
          await ref
              .read(linkedSongbooksProvider.notifier)
              .markImported(book.path);
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync complete.')));
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
