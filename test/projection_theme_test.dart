import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

void main() {
  group('ProjectionTheme serialization', () {
    test('round-trips local image/video paths and rotation settings', () {
      const theme = ProjectionTheme(
        textColor: Color(0xFF00897B),
        autoContrastText: true,
        backgroundType: ProjectionBackgroundType.video,
        imagePaths: ['/home/pics/backdrop.jpg', 'C:\\pics\\backdrop2.png'],
        videoPaths: ['/home/videos/loop1.mp4', '/home/videos/loop2.mp4'],
        mediaRotationMode: MediaRotationMode.timed,
        selectedMediaIndex: 1,
      );

      final restored = ProjectionTheme.fromJson(theme.toJson());

      expect(restored.textColor, theme.textColor);
      expect(restored.autoContrastText, isTrue);
      expect(restored.backgroundType, ProjectionBackgroundType.video);
      expect(restored.imagePaths, theme.imagePaths);
      expect(restored.videoPaths, theme.videoPaths);
      expect(restored.mediaRotationMode, MediaRotationMode.timed);
      expect(restored.selectedMediaIndex, 1);
    });

    test('migrates legacy imagePath into imagePaths', () {
      final restored = ProjectionTheme.fromJson(const {
        'textColor': null,
        'autoContrastText': false,
        'backgroundType': 2,
        'gradientColors': [0xFF0A1A18, 0xFF000000],
        'solidColor': 0xFF000000,
        'imagePath': '/old/path/photo.jpg',
        'videoLinks': [],
      });

      expect(restored.backgroundType, ProjectionBackgroundType.image);
      expect(restored.imagePaths.single, '/old/path/photo.jpg');
    });

    test('migrates pre-link-removal imageSources/videoLinks keys', () {
      final restored = ProjectionTheme.fromJson(const {
        'textColor': null,
        'autoContrastText': false,
        'backgroundType': 2,
        'gradientColors': [0xFF0A1A18, 0xFF000000],
        'solidColor': 0xFF000000,
        'imageSources': ['/a.jpg', '/b.png'],
        'videoLinks': ['/v1.mp4'],
      });

      expect(restored.imagePaths, ['/a.jpg', '/b.png']);
      expect(restored.videoPaths, ['/v1.mp4']);
    });
  });

  group('fileNameOf', () {
    test('returns the basename for posix and windows paths', () {
      expect(fileNameOf('/home/pics/photo.jpg'), 'photo.jpg');
      expect(fileNameOf('C:\\pics\\photo.jpg'), 'photo.jpg');
    });
  });

  group('resolveMediaIndex', () {
    const theme = ProjectionTheme();

    test('perSlide advances with the slide', () {
      final t = theme.copyWith(
        imagePaths: const ['a', 'b', 'c'],
        mediaRotationMode: MediaRotationMode.perSlide,
      );
      expect(
        t.resolveMediaIndex(listLength: 3, slideIndex: 0, mediaCycleIndex: 0),
        0,
      );
      expect(
        t.resolveMediaIndex(listLength: 3, slideIndex: 1, mediaCycleIndex: 0),
        1,
      );
      expect(
        t.resolveMediaIndex(listLength: 3, slideIndex: 5, mediaCycleIndex: 0),
        2,
      );
    });

    test('timed advances with the cycle counter', () {
      final t = theme.copyWith(
        videoPaths: const ['v1', 'v2'],
        mediaRotationMode: MediaRotationMode.timed,
      );
      expect(
        t.resolveMediaIndex(listLength: 2, slideIndex: 0, mediaCycleIndex: 3),
        1,
      );
    });

    test('manual stays on the selected source', () {
      final t = theme.copyWith(
        videoPaths: const ['v1', 'v2', 'v3'],
        mediaRotationMode: MediaRotationMode.manual,
        selectedMediaIndex: 1,
      );
      expect(
        t.resolveMediaIndex(listLength: 3, slideIndex: 7, mediaCycleIndex: 9),
        1,
      );
    });

    test('clamps to the list bounds and handles empty lists', () {
      const t = ProjectionTheme(
        mediaRotationMode: MediaRotationMode.manual,
        selectedMediaIndex: 5,
      );
      expect(t.resolveMediaIndex(listLength: 2, slideIndex: 0, mediaCycleIndex: 0), 1);
      expect(t.resolveMediaIndex(listLength: 0, slideIndex: 0, mediaCycleIndex: 0), 0);
    });
  });
}
