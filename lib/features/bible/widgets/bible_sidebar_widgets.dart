import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
import 'package:visual_song_book/features/bible/bible_repository.dart';

class BibleRightSidebar extends StatefulWidget {
  const BibleRightSidebar({super.key});

  @override
  State<BibleRightSidebar> createState() => _BibleRightSidebarState();
}

class _BibleRightSidebarState extends State<BibleRightSidebar> {
  final _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollToTopIfNeeded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTopIfNeeded() {
    final state = ProviderScope.containerOf(context).read(bibleControllerProvider);
    if (state.activeVerse != null && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final state = ref.watch(bibleControllerProvider);
        final crossRefs = state.activeCrossReferences;
        final hasCrossRefs = state.activeVerse != null && crossRefs.isNotEmpty;
        final isLoadingCrossRefs = state.isLoadingCrossReferences;

        return Container(
          width: 280,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (state.activeVerse != null) ...[
                        const _SectionLabel(title: 'Cross-References'),
                        const SizedBox(height: 12),
                        if (isLoadingCrossRefs)
                          const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.8)),
                          ))
                        else if (!hasCrossRefs)
                          Text(
                            'No cross references found.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          )
                        else
                          ...crossRefs.take(8).map((cr) => _CrossRefTile(cr: cr)),
                        const SizedBox(height: 20),
                      ],
                      const _SectionLabel(title: 'Bookmarks'),
                      const SizedBox(height: 12),
                      const BibleBookmarkList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

class _CrossRefTile extends StatelessWidget {
  final BibleCrossReference cr;
  const _CrossRefTile({required this.cr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        ProviderScope.containerOf(context)
            .read(bibleControllerProvider.notifier)
            .navigateToVerse(cr.toBookId, cr.toChapter, cr.toVerseStart);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_right_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cr.reference,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    cr.targetText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.4,
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          );
        }
        return Column(
          children: bookmarks
              .take(10)
              .map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => notifier.navigateToVerse(b.bookId, b.chapter, b.verseNum),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_border, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.reference,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
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
