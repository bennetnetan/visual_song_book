/// How the projection output window is placed.
///
/// `extended` (default) auto-fullscreens on a secondary display; `single`
/// keeps a normal decorated window on the primary display; `duplicate` is a
/// reserved mode for mirroring the output and is not implemented yet.
enum ProjectionMode {
  single,
  duplicate,
  extended;

  const ProjectionMode();

  static ProjectionMode fromWireName(String value) {
    return ProjectionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ProjectionMode.extended,
    );
  }
}
