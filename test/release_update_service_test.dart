import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:visual_song_book/data/services/release_update_service.dart';

void main() {
  PackageInfo installedVersion(String version) => PackageInfo(
    appName: 'Visual Song Book',
    packageName: 'visual_song_book',
    version: version,
    buildNumber: '1',
  );

  Map<String, Object?> release({
    String tag = 'v2.6.0',
    bool draft = false,
    bool prerelease = false,
  }) => {
    'tag_name': tag,
    'name': 'Visual Song Book $tag',
    'body': 'Release notes',
    'html_url':
        'https://github.com/bennetnetan/visual_song_book/releases/tag/$tag',
    'draft': draft,
    'prerelease': prerelease,
  };

  ReleaseUpdateService serviceFor({
    required Map<String, Object?> response,
    required String currentVersion,
    int statusCode = 200,
  }) => ReleaseUpdateService(
    client: MockClient(
      (_) async => http.Response(jsonEncode(response), statusCode),
    ),
    packageInfo: () async => installedVersion(currentVersion),
  );

  group('ReleaseUpdateService', () {
    test('returns the release when its version is newer', () async {
      final service = serviceFor(response: release(), currentVersion: '2.5.9');
      addTearDown(service.close);

      final update = await service.checkForUpdate();

      expect(update?.version, '2.6.0');
      expect(update?.title, 'Visual Song Book v2.6.0');
      expect(update?.notes, 'Release notes');
      expect(update?.releaseUrl.host, 'github.com');
    });

    test('returns null when the installed version is current', () async {
      final service = serviceFor(
        response: release(tag: 'v2.5.0'),
        currentVersion: '2.5.0',
      );
      addTearDown(service.close);

      expect(await service.checkForUpdate(), isNull);
    });

    test('ignores draft and prerelease releases', () async {
      for (final flags in [
        {'draft': true},
        {'prerelease': true},
      ]) {
        final service = serviceFor(
          response: release(
            draft: flags['draft'] == true,
            prerelease: flags['prerelease'] == true,
          ),
          currentVersion: '2.5.0',
        );
        addTearDown(service.close);

        expect(await service.checkForUpdate(), isNull);
      }
    });

    test('reports GitHub API failures', () async {
      final service = serviceFor(
        response: release(),
        currentVersion: '2.5.0',
        statusCode: 503,
      );
      addTearDown(service.close);

      expect(service.checkForUpdate(), throwsException);
    });
  });
}
