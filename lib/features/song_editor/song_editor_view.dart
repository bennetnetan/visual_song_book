import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';

class SongEditorView extends ConsumerStatefulWidget {
  final int? songId;

  const SongEditorView({super.key, this.songId});

  @override
  ConsumerState<SongEditorView> createState() => _SongEditorViewState();
}

class _SongEditorViewState extends ConsumerState<SongEditorView> {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _titleController = TextEditingController();
  final _keyController = TextEditingController();
  final _authorController = TextEditingController();
  final _copyrightController = TextEditingController();
  final _bodyController = TextEditingController();

  int? _selectedCategoryId;
  bool _isLoading = false;
  List<Category> _categories = [];
  Song? _originalSong;

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(() => setState(() {}));
    _loadCategoriesAndSong();
  }

  Future<void> _loadCategoriesAndSong() async {
    setState(() => _isLoading = true);
    final repo = ref.read(songRepositoryProvider);

    try {
      _categories = await repo.getCategories();

      if (widget.songId != null) {
        final song = await repo.getSongById(widget.songId!);
        if (song != null) {
          _originalSong = song;
          _numberController.text = song.songNum.toString();
          _titleController.text = song.title;
          _keyController.text = song.key ?? '';
          _authorController.text = song.author ?? '';
          _copyrightController.text = song.copyright ?? '';
          _bodyController.text = song.body;
          _selectedCategoryId = song.categoryId;
        }
      } else {
        // Auto-suggest next song number
        final songs = await repo.getSongs();
        if (songs.isNotEmpty) {
          _numberController.text = (songs.last.songNum + 1).toString();
        } else {
          _numberController.text = '1';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    _keyController.dispose();
    _authorController.dispose();
    _copyrightController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(songRepositoryProvider);

    final number = int.parse(_numberController.text.trim());
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final musicKey = _keyController.text.trim();
    final author = _authorController.text.trim();
    final copyright = _copyrightController.text.trim();

    final cleanKey = musicKey.isEmpty ? null : musicKey;
    final cleanAuthor = author.isEmpty ? null : author;
    final cleanCopyright = copyright.isEmpty ? null : copyright;

    try {
      if (widget.songId != null && _originalSong != null) {
        final updated = SongsCompanion(
          id: drift.Value(_originalSong!.id),
          songNum: drift.Value(number),
          title: drift.Value(title),
          body: drift.Value(body),
          key: drift.Value(cleanKey),
          author: drift.Value(cleanAuthor),
          copyright: drift.Value(cleanCopyright),
          categoryId: drift.Value(_selectedCategoryId),
          modified: drift.Value(DateTime.now()),
        );
        await repo.updateSong(updated);
      } else {
        final inserted = SongsCompanion.insert(
          songNum: number,
          title: title,
          body: body,
          key: drift.Value(cleanKey),
          author: drift.Value(cleanAuthor),
          copyright: drift.Value(cleanCopyright),
          categoryId: drift.Value(_selectedCategoryId),
          modified: drift.Value(DateTime.now()),
        );
        await repo.addSong(inserted);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.songId != null ? 'Song updated!' : 'Song added!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.songId != null;
    final lyricsCharCount = _bodyController.text.length;

    if (_isLoading && _categories.isEmpty && _originalSong == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Song' : 'New Song',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
              children: [
                // ── Identification Card ──────────────────────────────
                _SectionCard(
                  icon: Icons.tag_rounded,
                  title: 'Identification',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _numberController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
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
                            controller: _titleController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration('Title'),
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
                ),

                const SizedBox(height: 16),

                // ── Metadata Card ────────────────────────────────────
                _SectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Metadata',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _keyController,
                            decoration: _fieldDecoration(
                              'Key',
                              hint: 'e.g., G, C min',
                              prefix: const Icon(Icons.music_note_outlined, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCategoryId,
                            decoration: _fieldDecoration('Category'),
                            borderRadius: BorderRadius.circular(14),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Uncategorized'),
                              ),
                              ..._categories.map((c) => DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(c.name),
                                  ))
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCategoryId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _authorController,
                            decoration: _fieldDecoration(
                              'Author',
                              prefix: const Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _copyrightController,
                            decoration: _fieldDecoration(
                              'Copyright',
                              prefix: const Icon(Icons.copyright_outlined, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Lyrics Card ──────────────────────────────────────
                _SectionCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Lyrics',
                  trailing: Text(
                    '$lyricsCharCount chars',
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
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: TextFormField(
                        controller: _bodyController,
                        maxLines: 20,
                        keyboardType: TextInputType.multiline,
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'VERSE 1\nAmazing grace, how sweet the sound...\n\nCHORUS\nPraise the Lord...\n\nVERSE 2\n...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined, size: 16,
                              color: Theme.of(context).colorScheme.secondary),
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
                ),

                const SizedBox(height: 32),

                // ── Save Button ──────────────────────────────────────
                FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Song'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A reusable titled section card for grouping form fields.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
