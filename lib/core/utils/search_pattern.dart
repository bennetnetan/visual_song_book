/// Wildcard helpers for search.
///
/// SQLite's `LIKE` already understands `%` (any run of characters) and `_`
/// (exactly one character), but asking a church operator to type those is a
/// poor interface — `*` and `?` are the conventional wildcards people know from
/// file dialogs and search engines. This translates the friendly form into a
/// LIKE pattern, escaping anything the user typed that LIKE would otherwise
/// treat as a wildcard.
///
///   "amaz*"     -> %amaz%     (substring match, same as before)
///   "amaz*grac" -> %amaz%grac%
///   "gra?e"     -> %gra_e%
///   "100%"      -> %100\%%    (a literal percent sign, not a wildcard)
library;

/// Escape character used in the generated LIKE patterns. It must be a single
/// character and must not appear literally in the escaped text.
const String likeEscapeChar = '\\';

/// Converts [query] into the middle of a SQL `LIKE` pattern.
///
/// Wildcards understood:
/// - `*` any run of characters (including none)
/// - `?` exactly one character
///
/// Any `%`, `_` or `\` the user typed is escaped so it matches literally
/// instead of being interpreted. All other characters pass through unchanged.
///
/// Pair this with `LIKE ? ESCAPE '\'`, or drift's `like(pattern,
/// escapeChar: likeEscapeChar)`.
String buildWildcardLikePattern(String query) {
  final buffer = StringBuffer();

  for (final rune in query.runes) {
    final char = String.fromCharCode(rune);
    switch (char) {
      case '*':
        buffer.write('%');
      case '?':
        buffer.write('_');
      case likeEscapeChar:
      case '%':
      case '_':
        // Escaped so a literal character matches as itself.
        buffer.write('$likeEscapeChar$char');
      default:
        buffer.write(char);
    }
  }

  return buffer.toString();
}

/// Whether [query] contains any wildcard the user explicitly typed.
///
/// Used to skip the substring wrapping when the query already ends in `*`,
/// so "amaz*" does not become "%amaz%%" (which is harmless but pointless) and
/// hints can be tailored.
bool hasExplicitWildcard(String query) => query.contains('*') || query.contains('?');
