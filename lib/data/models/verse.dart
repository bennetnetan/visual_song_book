class Verse {
  final String label; // e.g., "V1", "C", "B", "V2"
  final String text;
  final int order; // The physical order in the song source

  Verse({required this.label, required this.text, required this.order});

  bool get isChorus => label == 'C' || label.toUpperCase().startsWith('CHORUS');

  Map<String, dynamic> toJson() => {
    'label': label,
    'text': text,
    'order': order,
  };

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
    label: json['label'] as String,
    text: json['text'] as String,
    order: json['order'] as int,
  );
}
