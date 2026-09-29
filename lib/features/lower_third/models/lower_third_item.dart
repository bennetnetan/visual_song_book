import 'package:visual_song_book/core/utils/uuid_generator.dart';

/// A freeform announcement item displayed in the lower thirds carousel.
class LowerThirdItem {
  final String id;
  final String text;
  final bool isEnabled;

  const LowerThirdItem({
    required this.id,
    required this.text,
    this.isEnabled = false,
  });

  LowerThirdItem copyWith({
    String? id,
    String? text,
    bool? isEnabled,
  }) {
    return LowerThirdItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isEnabled': isEnabled,
    };
  }

  factory LowerThirdItem.fromJson(Map<String, dynamic> json) {
    return LowerThirdItem(
      id: (json['id'] as String?) ?? UuidGenerator.generate(),
      text: (json['text'] as String?) ?? '',
      isEnabled: (json['isEnabled'] as bool?) ?? false,
    );
  }

  factory LowerThirdItem.create(String text, {bool isEnabled = false}) {
    return LowerThirdItem(
      id: UuidGenerator.generate(),
      text: text,
      isEnabled: isEnabled,
    );
  }
}
