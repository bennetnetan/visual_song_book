import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupRepository {
  /// Locates the active SQLite database file on disk.
  Future<File> _getDatabaseFile() async {
    final Directory directory;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      directory = await getApplicationSupportDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return File(p.join(directory.path, 'songs_db.sqlite'));
  }

  /// Exports the current database to a [.vsbook] archive file at the specified [targetPath]
  Future<void> exportBackup(String targetPath) async {
    final dbFile = await _getDatabaseFile();
    if (!await dbFile.exists()) {
      throw Exception('Active database file not found on disk.');
    }

    // Read active database file bytes
    final dbBytes = await dbFile.readAsBytes();

    // Create Zip archive
    final archive = Archive();

    // 1. Add SQLite database
    archive.addFile(ArchiveFile('songs.db', dbBytes.length, dbBytes));

    // 2. Add metadata.json
    final metadata = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Visual Song Book',
    };
    final metadataBytes = utf8.encode(json.encode(metadata));
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );

    // Encode Zip file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    if (zipBytes == null) {
      throw Exception('Failed to generate zip backup.');
    }

    // Write to destination
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(zipBytes);
  }
}
