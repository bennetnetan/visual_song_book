import 'dart:math';

/// A simple, lightweight, RFC4122 v4 compliant UUID generator in pure Dart.
/// Avoids external library dependencies for lighter builds.
class UuidGenerator {
  static final Random _random = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version to 4 (random)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC4122 (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
