import 'package:flutter/material.dart';
class BibleSearchBar extends StatefulWidget {
  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final List<String> recentSearches;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onSuggestionTap;

  const BibleSearchBar({
    super.key,
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.recentSearches,
    required this.onClearRecent,
    required this.onSuggestionTap,
  });

  @override
  State<BibleSearchBar> createState() => _BibleSearchBarState();
}

class _BibleSearchBarState extends State<BibleSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.text = widget.query;
  }

  @override
  void didUpdateWidget(BibleSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != widget.controller.text) {
      widget.controller.text = widget.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.focusNode.unfocus(),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search verses, keywords, or "Jn 3:16"...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

