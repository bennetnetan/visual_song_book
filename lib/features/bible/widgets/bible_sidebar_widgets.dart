import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class BibleRightSidebar extends ConsumerWidget {
  const BibleRightSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(bibleControllerProvider);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.activeVerse != null) ...[
              const _BibleSidebarLabel(title: 'Cross-References'),
              const SizedBox(height: 16),
              if (state.isLoadingCrossReferences)
                const Center(child: CircularProgressIndicator())
              else if (state.activeCrossReferences.isEmpty)
                Text(
                  'No cross references found.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                BibleCrossReferenceList(references: state.activeCrossReferences),
              const SizedBox(height: 16),
            ],
            const _BibleSidebarLabel(title: 'Bookmarks'),
            const SizedBox(height: 16),
            const BibleBookmarkList(),
          ],
        ),
      ),
    );
  }
}

class BibleCrossReferenceList extends StatefulWidget {
  final List<BibleCrossReference> references;
  const BibleCrossReferenceList({super.key, required this.references});

  @override
  State<BibleCrossReferenceList> createState() => _BibleCrossReferenceListState();
}

class _BibleCrossReferenceListState extends State<BibleCrossReferenceList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = _showAll ? widget.references : widget.references.take(5).toList();
    final hasMore = widget.references.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayed.map((cr) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  ProviderScope.containerOf(context)
                      .read(bibleControllerProvider.notifier)
                      .navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cr.reference,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cr.targetText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )),
        if (hasMore)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll ? 'Show less' : 'Show all (${widget.references.length})',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

class BibleBookmarkList extends ConsumerWidget {
  const BibleBookmarkList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setRepo = ref.read(setRepositoryProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);

    return FutureBuilder<List<BibleBookmark>>(
      future: setRepo.getBookmarks(),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? [];
        if (bookmarks.isEmpty) {
          return Text(
            'No bookmarks yet.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Column(
          children: bookmarks
              .take(10)
              .map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => notifier.navigateToVerse(b.bookId, b.chapter, b.verseNum),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.reference,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _BibleSidebarLabel extends StatelessWidget {
  final String title;
  const _BibleSidebarLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class BibleInlineCrossReferences extends ConsumerWidget {
  final BibleVerse verse;
  const BibleInlineCrossReferences({super.key, required this.verse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleControllerProvider);
    final notifier = ref.read(bibleControllerProvider.notifier);
    final theme = Theme.of(context);

    if (state.isLoadingCrossReferences) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0),
        child: SizedBox(
          height: 12,
          width: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    if (state.activeCrossReferences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CROSS-REFERENCES:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: state.activeCrossReferences.take(6).map((cr) {
              return ActionChip(
                label: Text(
                  cr.reference,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                onPressed: () {
                  notifier.navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
