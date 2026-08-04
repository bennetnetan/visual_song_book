/// Classifies the first command-line argument of a spawned engine and decides
/// whether it is a projection window.
///
/// `desktop_multi_window` launches each secondary window as a fresh engine
/// with its own args. The main window spawns the projection engine with
/// `'Projection Output:<mode>'`; the mode tells the secondary engine whether it
/// should auto-place + fullscreen on a second display (`extended`) or stay a
/// normal decorated window on the primary display (`single`). The legacy bare
/// `'multi_window'` arg is treated as a projection window with the default
/// `extended` mode.
class ProjectionWindowArgs {
  const ProjectionWindowArgs(this.isProjectionWindow, this.mode);

  /// Whether the current process is a projection window (secondary engine).
  final bool isProjectionWindow;

  /// Window placement mode. `'extended'` (default) auto-fullscreens on a
  /// secondary screen; `'single'` keeps a decorated window on the primary
  /// display. Other values are passed through unchanged for future modes.
  final String mode;
}

ProjectionWindowArgs parseProjectionWindowArgs(String? firstArg) {
  if (firstArg == null) return const ProjectionWindowArgs(false, 'extended');
  if (firstArg == 'multi_window') {
    return const ProjectionWindowArgs(true, 'extended');
  }
  if (firstArg.startsWith('Projection Output')) {
    final mode = firstArg.contains(':')
        ? firstArg.substring(firstArg.indexOf(':') + 1)
        : 'extended';
    return ProjectionWindowArgs(true, mode);
  }
  return const ProjectionWindowArgs(false, 'extended');
}
