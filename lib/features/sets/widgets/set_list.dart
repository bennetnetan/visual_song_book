import 'package:flutter/material.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SetList extends StatelessWidget {
  final List<SongSet> sets;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<int> onDelete;
  final VoidCallback onImport;

  const SetList({
    super.key,
    required this.sets,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onDelete,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Set'),
                  onPressed: onCreate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.file_upload, size: 18),
                  label: const Text('Import Set'),
                  onPressed: onImport,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 56,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sets yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "New Set" above to build your first service plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Set'),
                          onPressed: onCreate,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sets.length,
                  itemBuilder: (context, index) {
                    final setObj = sets[index];
                    final isSelected = setObj.id == selectedId;
                    return Card(
                      elevation: 0,
                      color: isSelected
                          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        selected: isSelected,
                        title: Text(
                          setObj.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: setObj.occasion != null && setObj.occasion!.isNotEmpty
                            ? Text(
                                setObj.occasion!,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error.withValues(alpha: 0.8),
                          ),
                          tooltip: 'Delete set',
                          onPressed: () => onDelete(setObj.id),
                        ),
                        onTap: () => onSelect(setObj.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
