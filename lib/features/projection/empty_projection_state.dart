import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:visual_song_book/features/projection/projection_controller.dart';
import 'package:visual_song_book/features/projection/projection_history_panel.dart';
import 'package:visual_song_book/features/projection/projection_search_field.dart';

/// Which panel the narrow (mobile) layout of the empty projection window shows.
/// Wide layouts show both at once, so this only applies below the desktop
/// breakpoint where there is not enough width for a rail beside the search.
enum EmptyProjectionSection { search, history }

final _emptySectionProvider =
    StateProvider<EmptyProjectionSection>((ref) => EmptyProjectionSection.search);

/// The projection tab's empty state: recently projected history plus an inline,
/// already-focused search field ready for typing.
///
/// On wide screens the two sit side by side. On narrow screens an explicit
/// Search / History tab pair chooses between them, since there is no room for
/// both.
class EmptyProjectionState extends ConsumerWidget {
  final ProjectionController notifier;
  final FocusNode returnFocusTo;
  final bool isLargeScreen;

  const EmptyProjectionState({
    super.key,
    required this.notifier,
    required this.returnFocusTo,
    this.isLargeScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: `returnFocusTo` is owned by the parent ProjectionTab's Focus
    // widget, so it must NOT be attached another Focus here (that throws
    // "Tried to make a child into a parent of itself"). We only borrow it to
    // hand focus back on background taps.
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: returnFocusTo.requestFocus,
        child: isLargeScreen
            ? Row(
                children: [
                  // Recently projected history stays in its own rail.
                  ProjectionHistoryPanel(
                    notifier: notifier,
                    returnFocusTo: returnFocusTo,
                    narrow: false,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: InlineProjectionSearch(notifier: notifier),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildSectionTabs(context, ref),
                  const Divider(height: 1),
                  Expanded(
                    child: ref.watch(_emptySectionProvider) ==
                            EmptyProjectionSection.search
                        ? InlineProjectionSearch(notifier: notifier)
                        : ProjectionHistoryPanel(
                            notifier: notifier,
                            returnFocusTo: returnFocusTo,
                            narrow: true,
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Narrow-screen tabs switching between the inline search and the recently
  /// projected history.
  Widget _buildSectionTabs(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final section = ref.watch(_emptySectionProvider);

    Widget tab(EmptyProjectionSection value, String label, IconData icon) {
      final isActive = section == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => ref.read(_emptySectionProvider.notifier).state = value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isActive ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          tab(EmptyProjectionSection.search, 'Search', Icons.search),
          tab(EmptyProjectionSection.history, 'History', Icons.history),
        ],
      ),
    );
  }
}
