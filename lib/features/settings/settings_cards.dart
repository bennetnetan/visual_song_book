import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';

class ImportExportCard extends StatelessWidget {
  final bool isImporting;
  final String? importStatus;
  final bool isExporting;
  final VoidCallback onImportMdb;
  final VoidCallback onImportVsBook;
  final VoidCallback onExportVsBook;

  const ImportExportCard({
    super.key,
    required this.isImporting,
    required this.importStatus,
    required this.isExporting,
    required this.onImportMdb,
    required this.onImportVsBook,
    required this.onExportVsBook,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.import_export, size: 28),
                SizedBox(width: 12),
                Text('Database Import & Export',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Visual Song Book can import legacy VSB or Microsoft Access MDB files directly, as well as restore portable .vsbook backups.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (isImporting) ...[
              Row(
                children: [
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(importStatus ?? 'Processing...'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: isImporting ? null : onImportMdb,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Import VSB / MDB File'),
                ),
                ElevatedButton.icon(
                  onPressed: isImporting ? null : onImportVsBook,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Restore .vsbook Backup'),
                ),
                ElevatedButton.icon(
                  onPressed: isExporting || isImporting ? null : onExportVsBook,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Export .vsbook Backup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ManageArchivesCard extends StatelessWidget {
  final bool isDeletingArchives;
  final VoidCallback onDeleteArchives;

  const ManageArchivesCard({
    super.key,
    required this.isDeletingArchives,
    required this.onDeleteArchives,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.archive_outlined, size: 28),
                SizedBox(width: 12),
                Text('Manage Archives',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Delete exported .vsbook backups or imported .vsb/.mdb source files from disk. Songs already in the database are not affected.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isDeletingArchives ? null : onDeleteArchives,
              icon: isDeletingArchives
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              label: Text(isDeletingArchives
                  ? 'Selecting files...'
                  : 'Delete Archive Files'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenPreferencesCard extends ConsumerWidget {
  const ScreenPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionState = ref.watch(projectionControllerProvider);
    final projectionNotifier = ref.read(projectionControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.video_settings, size: 28),
                SizedBox(width: 12),
                Text('Screen Preferences',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Prevent Screen Sleep (Wakelock)'),
              subtitle: const Text(
                  'Keeps the screen awake during projection operator view'),
              value: projectionState.keepAwake,
              onChanged: projectionNotifier.setKeepAwake,
            ),
          ],
        ),
      ),
    );
  }
}

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 28),
                SizedBox(width: 12),
                Text('About & Diagnostics',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This application treats SQLite (via Drift) as its source of truth. When importing legacy MDB songbooks, it converts and structures them into the SQLite database. Backups (.vsbook) are platform-independent ZIP files containing the SQLite database and metadata.',
            ),
            const SizedBox(height: 16),
            Text('System Platform: ${kIsWeb ? "Web Browser" : Platform.operatingSystem.toUpperCase()}'),
            const SizedBox(height: 8),
            const Text('MDB CLI Helper: mdb-tools (detected)'),
          ],
        ),
      ),
    );
  }
}
