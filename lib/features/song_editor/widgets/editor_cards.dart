import 'package:flutter/material.dart';

import 'package:visual_song_book/core/utils/verse_parser.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/song_editor/widgets/section_card.dart';

class IdentificationCard extends StatelessWidget {
  final TextEditingController numberController;
  final TextEditingController titleController;
  final InputDecoration Function(String, {String? hint, Widget? prefix})
  fieldDecoration;

  const IdentificationCard({
    super.key,
    required this.numberController,
    required this.titleController,
    required this.fieldDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.tag_rounded,
      title: 'Identification',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  'Song Number',
                  prefix: const Icon(Icons.tag, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Must be an integer';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: titleController,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration('Title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MetadataCard extends StatelessWidget {
  final TextEditingController keyController;
  final TextEditingController authorController;
  final TextEditingController copyrightController;
  final int? selectedCategoryId;
  final List<Category> categories;
  final ValueChanged<int?> onCategoryChanged;
  final InputDecoration Function(String, {String? hint, Widget? prefix})
  fieldDecoration;

  const MetadataCard({
    super.key,
    required this.keyController,
    required this.authorController,
    required this.copyrightController,
    required this.selectedCategoryId,
    required this.categories,
    required this.onCategoryChanged,
    required this.fieldDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Metadata',
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: keyController,
                decoration: fieldDecoration(
                  'Key',
                  hint: 'e.g., G, C min',
                  prefix: const Icon(Icons.music_note_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: selectedCategoryId,
                decoration: fieldDecoration('Category'),
                borderRadius: BorderRadius.circular(14),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: authorController,
                decoration: fieldDecoration(
                  'Author',
                  prefix: const Icon(Icons.person_outline, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: copyrightController,
                decoration: fieldDecoration(
                  'Copyright',
                  prefix: const Icon(Icons.copyright_outlined, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LyricsCard extends StatelessWidget {
  final int charCount;
  final TextEditingController bodyController;

  const LyricsCard({
    super.key,
    required this.charCount,
    required this.bodyController,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.menu_book_rounded,
      title: 'Lyrics',
      trailing: Text(
        '$charCount chars',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: TextFormField(
            controller: bodyController,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 14,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
                  'VERSE 1\nAmazing grace, how sweet the sound...\n\nCHORUS\nPraise the Lord...\n\nVERSE 2\n...',
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Song lyrics cannot be empty';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Separate verses with a blank line. Start a block with "CHORUS" or "VERSE N" to label it.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LivePreviewCard extends StatelessWidget {
  final String lyrics;

  const LivePreviewCard({super.key, required this.lyrics});

  @override
  Widget build(BuildContext context) {
    final parsedVerses = VerseParser.parse(lyrics);
    final slides = VerseParser.buildSlideSequence(parsedVerses);

    return SectionCard(
      icon: Icons.preview_rounded,
      title: 'Projection Preview',
      children: [
        if (slides.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Type some lyrics to see a preview.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: slides.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              slide.label,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Center(
                              child: Text(
                                slide.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
