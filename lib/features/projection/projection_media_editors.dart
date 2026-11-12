
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';
import 'package:visual_song_book/features/projection/projection_media_controls.dart';
class ImageBackgroundEditor extends StatelessWidget {
  final ProjectionTheme theme;
  final ValueChanged<ProjectionTheme> onChanged;

  const ImageBackgroundEditor({super.key, 
    required this.theme,
    required this.onChanged,
  });

  Future<void> _pickFromDisk(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final path = result.single.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web projection cannot load local files'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (theme.imagePaths.contains(path)) return;
    if (theme.imagePaths.length >= kMaxMediaSources) return;
    onChanged(theme.copyWith(imagePaths: [...theme.imagePaths, path]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MediaSourceList<String>(
          sources: theme.imagePaths,
          iconFor: (_) => Icons.folder,
          titleFor: fileNameOf,
          subtitleFor: (path) => path,
          onRemove: (path) => onChanged(
            theme.copyWith(
              imagePaths: theme.imagePaths
                  .where((e) => e != path)
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: theme.imagePaths.length >= kMaxMediaSources
                  ? null
                  : () => _pickFromDisk(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose image from disk'),
            ),
          ],
        ),
        if (theme.imagePaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.imagePaths.length,
            onModeChanged: (m) =>
                onChanged(theme.copyWith(mediaRotationMode: m)),
            onIndexChanged: (i) =>
                onChanged(theme.copyWith(selectedMediaIndex: i)),
          ),
        ],
      ],
    );
  }
}

class VideoBackgroundEditor extends StatelessWidget {
  final ProjectionTheme theme;
  final ValueChanged<ProjectionTheme> onChanged;

  const VideoBackgroundEditor({super.key, 
    required this.theme,
    required this.onChanged,
  });

  Future<void> _pickFromDisk(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result.isEmpty) return;
    final path = result.single.path;
    if (path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web projection cannot load local files'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (theme.videoPaths.contains(path)) return;
    if (theme.videoPaths.length >= kMaxMediaSources) return;
    onChanged(theme.copyWith(videoPaths: [...theme.videoPaths, path]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MediaSourceList<String>(
          sources: theme.videoPaths,
          iconFor: (_) => Icons.play_circle_outline,
          titleFor: fileNameOf,
          subtitleFor: (path) => path,
          onRemove: (path) => onChanged(
            theme.copyWith(
              videoPaths: theme.videoPaths
                  .where((e) => e != path)
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: theme.videoPaths.length >= kMaxMediaSources
                  ? null
                  : () => _pickFromDisk(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose video from disk'),
            ),
          ],
        ),
        if (theme.videoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          MediaRotationControls(
            mode: theme.mediaRotationMode,
            selectedIndex: theme.selectedMediaIndex,
            sourceCount: theme.videoPaths.length,
            onModeChanged: (m) =>
                onChanged(theme.copyWith(mediaRotationMode: m)),
            onIndexChanged: (i) =>
                onChanged(theme.copyWith(selectedMediaIndex: i)),
          ),
        ],
      ],
    );
  }
}

/// Renders the list of configured media sources (up to three) with a remove
/// button per entry.
class MediaSourceList<T> extends StatelessWidget {
  final List<T> sources;
  final IconData Function(T source) iconFor;
  final String Function(T source) titleFor;
  final String Function(T source) subtitleFor;
  final ValueChanged<T> onRemove;

  const MediaSourceList({super.key, 
    required this.sources,
    required this.iconFor,
    required this.titleFor,
    required this.subtitleFor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No media added yet. Add up to $kMaxMediaSources below.',
          style: TextStyle(
            fontSize: 12,
            color: appTheme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < sources.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: Icon(iconFor(sources[i]), size: 20),
              title: Text(
                titleFor(sources[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                subtitleFor(sources[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove',
                onPressed: () => onRemove(sources[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rotation behaviour selector (per-slide / timed / manual) plus a manual
/// index picker when [MediaRotationMode.manual] is active.
