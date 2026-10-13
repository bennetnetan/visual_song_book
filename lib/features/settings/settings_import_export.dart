
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class ImportExportCard extends StatelessWidget {
  final bool isImporting;
  final String? importStatus;
  final bool isExporting;
  final VoidCallback onImportFile;
  final VoidCallback onImportBundled;
  final VoidCallback onExportVsBook;

  const ImportExportCard({
    super.key,
    required this.isImporting,
    required this.importStatus,
    required this.isExporting,
    required this.onImportFile,
    required this.onImportBundled,
    required this.onExportVsBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.import_export,
            title: 'Import & Export',
            subtitle: 'Import songs or manage database backups',
          ),
          if (isImporting) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  importStatus ?? 'Processing...',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.library_add_outlined,
            label: 'Import Pre-installed Songbooks',
            description: 'Add bundled songbook files distributed with the app',
            onPressed: isImporting ? null : onImportBundled,
            isPrimary: true,
          ),
          const Divider(height: 24),
          _ActionRow(
            icon: Icons.file_upload_outlined,
            label: 'Import from File',
            description: 'Load a .vsbook or .mdb file from your filesystem',
            onPressed: isImporting ? null : onImportFile,
          ),
          const Divider(height: 24),
          _ActionRow(
            icon: Icons.backup_outlined,
            label: 'Export Backup',
            description: 'Save a .vsbook archive of your entire library',
            onPressed: isExporting || isImporting ? null : onExportVsBook,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: onPressed == null
                      ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        isPrimary
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Import', style: TextStyle(fontSize: 12)),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: const Text('Go', style: TextStyle(fontSize: 12)),
              ),
      ],
    );
  }
}

