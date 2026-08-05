import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/features/projection/projection_theme.dart';

void main() {
  group('ProjectionTheme serialization', () {
    test('round-trips image/video links and rotation settings', () {
      const theme = ProjectionTheme(
        textColor: Color(0xFF00897B),
        autoContrastText: true,
        backgroundType: ProjectionBackgroundType.video,
        imageSources: [
          ImageSource('/home/pics/backdrop.jpg'),
          ImageSource('https://example.com/backdrop.png'),
        ],
        videoLinks: ['https://example.com/loop1.mp4', 'https://example.com/loop2.mp4'],
        mediaRotationMode: MediaRotationMode.timed,
        selectedMediaIndex: 1,
      );

      final restored = ProjectionTheme.fromJson(theme.toJson());

      expect(restored.textColor, theme.textColor);
      expect(restored.autoContrastText, isTrue);
      expect(restored.backgroundType, ProjectionBackgroundType.video);
      expect(restored.imageSources, theme.imageSources);
      expect(restored.videoLinks, theme.videoLinks);
      expect(restored.mediaRotationMode, MediaRotationMode.timed);
      expect(restored.selectedMediaIndex, 1);
    });

    test('migrates legacy imagePath into imageSources', () {
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
      expect(restored.imageSources.single.value, '/old/path/photo.jpg');
    });
  });

  group('ImageSource', () {
    test('classifies links vs local paths', () {
      expect(const ImageSource('https://x.com/a.jpg').isLink, isTrue);
      expect(const ImageSource('http://x.com/a.jpg').isLink, isTrue);
      expect(const ImageSource('/local/a.jpg').isLink, isFalse);
    });

    test('display name is the host for links and basename for files', () {
      expect(const ImageSource('https://cdn.example.com/x.jpg').displayName, 'cdn.example.com');
      expect(const ImageSource('/home/pics/photo.jpg').displayName, 'photo.jpg');
    });
  });

  group('resolveMediaIndex', () {
    const theme = ProjectionTheme();

    test('perSlide advances with the slide', () {
      final t = theme.copyWith(
        imageSources: const [
          ImageSource('a'),
          ImageSource('b'),
          ImageSource('c'),
        ],
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
        videoLinks: const ['v1', 'v2'],
        mediaRotationMode: MediaRotationMode.timed,
      );
      expect(
        t.resolveMediaIndex(listLength: 2, slideIndex: 0, mediaCycleIndex: 3),
        1,
      );
    });

    test('manual stays on the selected source', () {
      final t = theme.copyWith(
        videoLinks: const ['v1', 'v2', 'v3'],
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
