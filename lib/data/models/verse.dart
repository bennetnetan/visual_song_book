class Verse {
  final String label; // e.g., "V1", "C", "B", "V2"
  final String text;
  final int order; // The physical order in the song source
  final String? songTitle;
  final int? songNum;

  Verse({
    required this.label,
    required this.text,
    required this.order,
    this.songTitle,
    this.songNum,
  });

  bool get isChorus => label == 'C' || label.toUpperCase().startsWith('CHORUS');

  Verse copyWith({
    String? label,
    String? text,
    int? order,
    String? songTitle,
    int? songNum,
  }) {
    return Verse(
      label: label ?? this.label,
      text: text ?? this.text,
      order: order ?? this.order,
      songTitle: songTitle ?? this.songTitle,
      songNum: songNum ?? this.songNum,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'text': text,
    'order': order,
    'songTitle': songTitle,
    'songNum': songNum,
  };

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
    label: json['label'] as String,
    text: json['text'] as String,
    order: json['order'] as int,
    songTitle: json['songTitle'] as String?,
    songNum: json['songNum'] as int?,
  );
}
