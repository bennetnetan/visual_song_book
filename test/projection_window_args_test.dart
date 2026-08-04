import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/core/utils/projection_window_args.dart';

void main() {
  test('null args → not a projection window, default extended mode', () {
    final parsed = parseProjectionWindowArgs(null);
    expect(parsed.isProjectionWindow, isFalse);
    expect(parsed.mode, 'extended');
  });

  test('unrelated args → not a projection window', () {
    for (final arg in ['', '--device-id=foo', 'visual_song_book', 'debug']) {
      final parsed = parseProjectionWindowArgs(arg);
      expect(parsed.isProjectionWindow, isFalse, reason: 'arg: $arg');
      expect(parsed.mode, 'extended');
    }
  });

  test('legacy multi_window arg → projection window with default mode', () {
    final parsed = parseProjectionWindowArgs('multi_window');
    expect(parsed.isProjectionWindow, isTrue);
    expect(parsed.mode, 'extended');
  });

  test('Projection Output:extended → projection window in extended mode', () {
    final parsed = parseProjectionWindowArgs('Projection Output:extended');
    expect(parsed.isProjectionWindow, isTrue);
    expect(parsed.mode, 'extended');
  });

  test('Projection Output:single → projection window in single mode', () {
    final parsed = parseProjectionWindowArgs('Projection Output:single');
    expect(parsed.isProjectionWindow, isTrue);
    expect(parsed.mode, 'single');
  });

  test('bare Projection Output (no colon) → projection window, default mode',
      () {
    final parsed = parseProjectionWindowArgs('Projection Output');
    expect(parsed.isProjectionWindow, isTrue);
    expect(parsed.mode, 'extended');
  });

  test('future modes pass through unchanged', () {
    final parsed = parseProjectionWindowArgs('Projection Output:duplicate');
    expect(parsed.isProjectionWindow, isTrue);
    expect(parsed.mode, 'duplicate');
  });
}
