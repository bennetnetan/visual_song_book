import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists remote image backgrounds on disk so links are fetched once and
/// reused until the cache is cleared (matching the "cache as long as needed"
/// requirement for image backgrounds).
class ImageLinkCache {
  static Directory? _cacheDir;

  /// True when the platform can store a local cache (desktop + mobile).
  static bool get isSupported => !kIsWeb;

  static String _fileName(String url) =>
      '${url.hashCode.toRadixString(16)}.img';

  /// Synchronous probe — resolves to the cached file only if it already
  /// exists. Never downloads.
  static Future<File?> cachedFile(String url) async {
    final dir = await _resolveCacheDir();
    if (dir == null) return null;
    final file = File(p.join(dir.path, _fileName(url)));
    return file.existsSync() ? file : null;
  }

  /// Downloads [url] into the cache (if not already present) and returns the
  /// resulting file. Throws on HTTP errors so callers can surface them.
  static Future<File> ensureCached(String url) async {
    final dir = await _resolveCacheDir();
    if (dir == null) {
      throw UnsupportedError('Image caching is not supported on this platform');
    }
    final file = File(p.join(dir.path, _fileName(url)));
    if (file.existsSync()) return file;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download image: HTTP ${response.statusCode}',
          uri: request.uri,
        );
      }
      await response.pipe(file.openWrite());
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Deletes every cached image link. Projection falls back to fetching the
  /// link again (or the gradient) until the image is re-added.
  static Future<void> clear() async {
    final dir = await _resolveCacheDir();
    if (dir == null || !dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // ignore: best-effort cache wipe
    }
  }

  static Future<Directory?> _resolveCacheDir() async {
    if (!isSupported) return null;
    if (_cacheDir != null) return _cacheDir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'image_link_cache'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _cacheDir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }
}
