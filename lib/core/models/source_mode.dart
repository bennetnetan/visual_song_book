enum SourceMode {
  bundled,
  linked,
  unified;

  const SourceMode();

  String get label {
    switch (this) {
      case SourceMode.bundled:
        return 'Pre-installed Songbooks';
      case SourceMode.linked:
        return 'Linked Songbook Files';
      case SourceMode.unified:
        return 'Both';
    }
  }

  String get description {
    switch (this) {
      case SourceMode.bundled:
        return 'Use the built-in Full Song Book and Injili Song Book';
      case SourceMode.linked:
        return 'Use only your own linked .vsbook files';
      case SourceMode.unified:
        return 'Use both pre-installed and linked songbooks';
    }
  }

  static SourceMode fromString(String value) {
    return SourceMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => SourceMode.unified,
    );
  }
}
