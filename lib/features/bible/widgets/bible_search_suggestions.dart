import 'package:flutter/material.dart';
import 'package:visual_song_book/features/bible/bible_controller.dart';
class BibleSearchSuggestionSection extends StatelessWidget {
  final BibleState state;
  final BibleController notifier;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const BibleSearchSuggestionSection({
    super.key,
    required this.state,
    required this.notifier,
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    if (state.recentSearches.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'RECENT SEARCHES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.clearRecentSearches();
                    searchController.clear();
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: state.recentSearches.take(6).map((q) {
                return ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    searchController.text = q;
                    notifier.search(q);
                    searchFocusNode.unfocus();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildSuggestionChip('Salvation', notifier),
          _buildSuggestionChip('Love', notifier),
          _buildSuggestionChip('Eternal Life', notifier),
          _buildSuggestionChip('Faith', notifier),
          _buildSuggestionChip('Grace', notifier),
          _buildSuggestionChip('Peace', notifier),
          _buildSuggestionChip('Gen 1:1', notifier),
          _buildSuggestionChip('Jn 3:16', notifier),
          _buildSuggestionChip('Ps 23:1', notifier),
          _buildSuggestionChip('Rev 2:1', notifier),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, BibleController notifier) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
      onPressed: () {
        searchController.text = label;
        notifier.search(label);
        searchFocusNode.unfocus();
      },
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

