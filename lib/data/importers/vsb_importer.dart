import 'dart:typed_data';

enum ImportSourceType { file, bytes }

class ImportSource {
  final ImportSourceType type;
  final String? filePath;
  final Uint8List? bytes;

  ImportSource.fromFile(this.filePath)
      : type = ImportSourceType.file,
        bytes = null;

  ImportSource.fromBytes(this.bytes)
      : type = ImportSourceType.bytes,
        filePath = null;
}

class ImportResult {
  final bool success;
  final int songsImported;
  final int categoriesImported;
  final String? errorMessage;

  ImportResult({
    required this.success,
    this.songsImported = 0,
    this.categoriesImported = 0,
    this.errorMessage,
  });

  factory ImportResult.success({int songs = 0, int categories = 0}) {
    return ImportResult(
      success: true,
      songsImported: songs,
      categoriesImported: categories,
    );
  }

  factory ImportResult.failure(String error) {
    return ImportResult(
      success: false,
      errorMessage: error,
    );
  }
}

abstract class SongbookImporter {
  /// Unique name of the importer
  String get name;

  /// Whether this platform supports importing from this source
  bool canImport(ImportSource source);

  /// Performs the import and writes to [AppDatabase]
  Future<ImportResult> import(ImportSource source);
}
