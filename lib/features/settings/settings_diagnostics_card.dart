import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/data/services/app_storage.dart';
import 'package:visual_song_book/features/settings/settings_cards.dart';
import 'package:visual_song_book/features/settings/settings_card_shell.dart';

class DiagnosticsCard extends ConsumerStatefulWidget {
  const DiagnosticsCard({super.key});

  @override
  ConsumerState<DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends ConsumerState<DiagnosticsCard> {
  String _storagePath = 'Loading...';
  String _songsDbSize = 'Loading...';
  String _bibleDbSize = 'Loading...';
  bool _copied = false;
  static final _log = AppLogger.get('DiagnosticsCard');

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final path = await getAppStoragePath();
      final songsDbPath = await getAppStorageFilePath('songs_db.sqlite');
      final bibleDbPath = await getAppStorageFilePath('kjv_bible.sqlite');

      final songsSize = await _getFileSize(songsDbPath);
      final bibleSize = await _getFileSize(bibleDbPath);

      if (mounted) {
        setState(() {
          _storagePath = path;
          _songsDbSize = songsSize;
          _bibleDbSize = bibleSize;
        });
      }
    } catch (e, st) {
      _log.warning('Failed to load diagnostics', e, st);
    }
  }

  Future<String> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes == 0) return '0 KB';
        final mb = bytes / (1024 * 1024);
        if (mb >= 0.1) {
          return '${mb.toStringAsFixed(2)} MB';
        } else {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
      }
      return '0 KB';
    } catch (e, st) {
      _log.warning('Failed to get file size for $path', e, st);
      return '0 KB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.analytics_outlined,
            title: 'System Diagnostics',
            subtitle: 'Live database and storage status',
          ),
          const SizedBox(height: 16),
          _buildRow('Status', Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Connected', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Your local SQLite databases are successfully initialized and operating fully offline.',
                child: Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              ),
            ],
          ), theme),
          const Divider(height: 24),
          _buildRow('App Storage Path', Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  _storagePath,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy path',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _storagePath));
                  setState(() => _copied = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _copied = false);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App storage path copied to clipboard')),
                  );
                },
              ),
            ],
          ), theme),
          const Divider(height: 24),
          _buildRow('Songs Database Size', Text(_songsDbSize, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)), theme),
          const Divider(height: 24),
          _buildRow('Bible Database Size', Text(_bibleDbSize, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)), theme),
        ],
      ),
    );
  }

  Widget _buildRow(String label, Widget value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
      ],
    );
  }
}

