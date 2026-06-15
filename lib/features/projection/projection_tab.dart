import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';

class ProjectionTab extends ConsumerWidget {
  final bool isLargeScreen;

  const ProjectionTab({super.key, required this.isLargeScreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectionControllerProvider);
    final notifier = ref.read(projectionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projection Controls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open Projector Output Window',
            onPressed: () async {
              if (kIsWeb) {
                context.push('/projection');
              } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                final window = await WindowController.create(
                  const WindowConfiguration(
                    arguments: 'Projection Output',
                  ),
                );
                await window.show();
                Future.delayed(const Duration(milliseconds: 600), () {
                  ref.read(projectionControllerProvider.notifier).syncCurrentSlide();
                });
              } else {
                context.push('/projection');
              }
            },
          ),
        ],
      ),
      body: state.currentSong == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No song loaded on the projector.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(activeDashboardTabProvider.notifier).state = 0;
                    },
                    child: const Text('Go Browse Songs'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.currentSong!.title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Song ${state.currentSong!.songNum} • Key: ${state.currentSong!.key ?? 'None'}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: notifier.clearSong,
                        icon: const Icon(Icons.close),
                        label: const Text('Clear Screen'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[900],
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            itemCount: state.slides.length,
                            itemBuilder: (context, index) {
                              final slide = state.slides[index];
                              final isSelected = index == state.currentSlideIndex;
                              return Card(
                                elevation: isSelected ? 3 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                                    : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        slide.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    slide.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                  onTap: () => notifier.selectSlide(index),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'LIVE PREVIEW',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Container(
                                          color: Colors.black,
                                          padding: const EdgeInsets.all(24.0),
                                          child: Center(
                                            child: Text(
                                              state.currentSlide?.text ?? '',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                                shadows: const [
                                                  Shadow(
                                                    offset: Offset(1.0, 1.0),
                                                    blurRadius: 3.0,
                                                    color: Color.fromARGB(150, 0, 0, 0),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: notifier.prevSlide,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Previous (←)'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: notifier.nextSlide,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Next (→)'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.format_size, size: 20),
                                          const SizedBox(width: 8),
                                          const Text('Font Size'),
                                          Expanded(
                                            child: Slider(
                                              min: 24,
                                              max: 80,
                                              value: state.fontSize,
                                              onChanged: notifier.setFontSize,
                                            ),
                                          ),
                                          Text('${state.fontSize.round()} px'),
                                        ],
                                      ),
                                      SwitchListTile(
                                        title: const Text('Auto-insert Chorus'),
                                        subtitle: const Text('Show chorus between verses'),
                                        value: state.autoInsertChorus,
                                        onChanged: notifier.setAutoInsertChorus,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
