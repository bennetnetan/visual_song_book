import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseUpdate {
  final String version;
  final String title;
  final String notes;
  final Uri releaseUrl;

  const ReleaseUpdate({
    required this.version,
    required this.title,
    required this.notes,
    required this.releaseUrl,
  });
}

class ReleaseUpdateService {
  static final _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/bennetnetan/visual_song_book/releases/latest',
  );

  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfo;

  ReleaseUpdateService({
    http.Client? client,
    Future<PackageInfo> Function()? packageInfo,
  }) : _client = client ?? http.Client(),
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform;

  Future<ReleaseUpdate?> checkForUpdate() async {
    final response = await _client
        .get(
          _latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Visual-Song-Book',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Release check failed (${response.statusCode}).');
    }

    final release = jsonDecode(response.body) as Map<String, dynamic>;
    if (release['draft'] == true || release['prerelease'] == true) return null;

    final tag = release['tag_name'] as String?;
    final url = release['html_url'] as String?;
    if (tag == null || url == null) {
      throw const FormatException('GitHub release is missing its tag or URL.');
    }

    final currentVersion = (await _packageInfo()).version;
    if (_compareVersions(tag, currentVersion) <= 0) return null;

    return ReleaseUpdate(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      title: release['name'] as String? ?? tag,
      notes: release['body'] as String? ?? '',
      releaseUrl: Uri.parse(url),
    );
  }

  void close() => _client.close();

  static int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var i = 0; i < 3; i++) {
      final comparison = leftParts[i].compareTo(rightParts[i]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final parts = normalized.split(RegExp(r'[+\-]')).first.split('.');
    return List<int>.generate(3, (index) {
      if (index >= parts.length) return 0;
      return int.tryParse(parts[index]) ?? 0;
    });
  }
}
