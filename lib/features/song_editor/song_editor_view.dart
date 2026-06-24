import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:visual_song_book/core/providers/app_providers.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/features/song_editor/widgets/editor_cards.dart';

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
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
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
                IdentificationCard(
                  numberController: _numberController,
                  titleController: _titleController,
                  fieldDecoration: _fieldDecoration,
                ),
                const SizedBox(height: 16),
                MetadataCard(
                  keyController: _keyController,
                  authorController: _authorController,
                  copyrightController: _copyrightController,
                  selectedCategoryId: _selectedCategoryId,
                  categories: _categories,
                  onCategoryChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                  },
                  fieldDecoration: _fieldDecoration,
                ),
                const SizedBox(height: 16),
                LivePreviewCard(lyrics: _bodyController.text),
                const SizedBox(height: 16),
                LyricsCard(
                  charCount: lyricsCharCount,
                  bodyController: _bodyController,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Song'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    textStyle: const TextStyle(fontFamily: 'Outfit',
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
