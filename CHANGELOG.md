# Changelog

All notable changes to Visual Song Book are documented here. Newest first.

## [1.8.0] - 2026-08-04

- Projection mode — extended (secondary window) or single (in-window on primary display).
- Reopening projection reuses the hidden window — no duplicate engines.
- Bible projection: load more verses for long passages.
- Projection screen cleanup — position indicator and nav arrows hidden on desktop, kept on mobile fullscreen.
- Font-size cap unified (16–160); pinch-zoom persists once when the gesture ends.
- Search: Enter/click projects the keyboard-highlighted result.
- History: set and Bible entries refresh live and can be cleared; Continue Reading survives restart.
- Categories: filter songs by collection; deleting a category keeps its songs (moved to Uncategorized).
- `.vsbook` import no longer crashes on modified timestamps; deleted songs stay deleted.
- Hygiene: dead code and unused dependencies removed, explicit lint rules, macOS target 11.0, CI with hermetic tests.

## [1.7.1] - 2026-07-31

- Fixed projection crash caused by background enumeration on Windows.
- Eliminated title bar flash on secondary projection screen (Windows).
- Improved Enter-key interaction and responsiveness for search results.
- Improved projection UI and controls visibility on Android/touch devices.

## [1.7.0] - 2026-07-28

- Settings restructured into 4 categories: Appearance, Projection, Library, About.
- Borderless fullscreen projection on Windows via Win32 FFI (title bar + taskbar hidden).
- Mobile/desktop layout split — phone/tablet gets simplified single-column layout.
- Linked songbooks — link `.vsbook` files from Google Drive or shared folders with auto-sync.
- Source filter on songs tab — filter by songbook/source with counts.
- First-launch onboarding wizard for initial setup.
- Auto-chorus toggle moved inline next to Clear Screen in projection header.
- Import from File button — auto-detects `.mdb` vs `.vsbook` format.
- Changelog now expandable — shows latest 2 entries by default.
- Fixed Win32 fullscreen scheduler reentrancy crash (deferred via `Timer.run`).

## [1.6.0+2] - 2026-07-21

- Keyboard-scrolled search items now stay visible — replaced fixed-height scroll math with `Scrollable.ensureVisible`.
- Keyboard navigation hint moved above search results so it is always visible, not hidden below the list.

## [1.6.0] - 2026-07-21

- Categories simplified — Full Song Book & Injili Song Book replace the dozens of individual imported categories.
- Unified storage directory — all app data consolidated in `.visual_song_book/`.
- Cross-book duplicates eliminated — seeded songs deduplicated by title alone.
- Sidebar starts minimized — NavigationRail collapsed by default on launch.
- Seed marker hardened — verifies DB actually has songs before trusting SharedPreferences marker.
- AppImage OS bar icon — icons embedded in hicolor theme paths with correct `StartupWMClass`.

## [1.5.0] - 2026-07-21

- First-launch seeding — Full Song Book & Injili Song Book pre-loaded automatically on fresh install.
- Centralized AppLogger powered by Dart `logging` package (structured, level-aware, IDE-friendly).
- SetsTab null-check crash fixed — graceful loading indicator when DB resolves before sets list.
- Strict DB staleness checks — stale `selectedSetId` auto-cleared when set is deleted externally.
- Reactive set-items stream — `SongSetItems` now watched live, eliminating stale-data races.
- 100ms nav-ready dwell timer in search — type to search, pause to navigate with arrow keys.
- Enter to project highlighted result from search without touching the mouse.
- Subtle animated keyboard-hint indicator fades in when nav mode is active in search results.
- Linux window title fixed to "Visual Song Book" with app logo embedded in GTK titlebar.
- Android per-ABI release APKs (armeabi-v7a, arm64-v8a, x86_64).
- Linux AppImage with embedded logo and AppDir integration.

## [1.4.2] - 2026-06-26

- Multi-monitor detection — projection opens secondary window on multi-display, fullscreen on single.
- UI polish — subtle hover-only nav arrows, transparent controls, `PopScope` blocks back gesture in projection.
- Fixed `Positioned`/`AnimatedOpacity` nesting crash in projection output view.
- Removed redundant CHANGELOG section from About card, consolidated into versioned Changelog card.
- Removed Bible search back button on mobile (was opening book picker instead of navigating back).
- App bar hidden on mobile for History and Sets tabs.
- Mobile-friendly action buttons for Sets with redesigned layout.
- Unified Bible app bar font styling with dashboard tabs.
- Collapsible inline lyrics preview on mobile song list.
- Slide timeline with auto-scroll to active verse in projection view.

## [1.4.1] - 2026-06-25

- Inline song preview with collapsible lyrics on mobile.
- Low-opacity slide timeline at bottom of projection output.
- Drag-and-drop reorder hint above set list.
- Full-color app icon branding throughout UI.
- Mobile optimization — hide projection tab, clean up Bible book pickers.
- High-resolution app icon logo in settings.

## [1.4.0] - 2026-06-24

- Interactive Book and Chapter pop-up navigation dialog matching Bible specs.
- Subtle inline verse cross-references displayable for active verses.
- Bible Bookmarks list supported on mobile and desktop via History tab.
- Overhauled settings cards into clean, responsive Material 3 flat designs.
- Unified Project actions for Bible, Songs, and Sets with Display settings options.
- Responsive stacked live preview layout for narrow screen mobile devices.
- Subtle hover-only display controls in projection output view.
- Implemented drag-and-drop song sets reordering and inline list search filtering.

## [1.3.0] - 2026-06-25

- Unified search infrastructure: extracted `bible_search_utils.dart` (book ID map, reference parser, query normalizer) shared between Bible reader and projection.
- Projection search overhaul: replaced two duplicated search implementations with a single `ProjectionSearchController` (Riverpod `StateNotifier`) featuring 300ms debounce, structured Bible reference parsing ("Gen 1:1" → BEST MATCH), query highlighting via `HighlightedText`, paginated Bible results with "Show more", loading/error states, and projection history recording.
- Feature parity: projection search now matches the Bible tab — BEST MATCH card, testament labels, result count display, and the same `HighlightedText` widget.
- New unified Riverpod provider for all projection search state (Bible + Song modes).
- `HighlightedText` made public — reusable highlighted text widget previously private to `bible_tab.dart`.

## [1.2.0] - 2026-06-24

- Bible Reader: full KJV with book nav, chapter chips, full-text search, cross-references (344k from openbible.info), verse bookmarks, right sidebar with combined cross-refs + bookmarks panel.
- Song Sets: create, rename, reorder (drag), delete song sets; project entire sets as slide sequences.
- History sub-tabs: Songs | Sets | Bible — independent projection history per category.
- Bible projection: chapter-aware navigation — verse up/down auto-advances across chapters and books; chapter stepper controls in projection tab.
- Projection output: scripture reference displayed centered below verse text (moved from bottom-right corner).
- Schema v3: `BibleBookmarks`, `BibleHistory`, `SetHistory` drift tables with migration.
- Infrastructure: `BibleRepository`, `SetRepository`, bundled KJV SQLite with cross-references, `activeDashboardTabProvider` moved to shared providers.

## [1.1.0] - 2026-06-13

- Branding: AI-generated app icon (hymnal + cross + music notes, teal gradient); native splash screen with dark teal background.
- UI polish: premium card-grouped song editor, cinematic projection view with Outfit font and radial gradient, lyric preview using Lora serif, animated slide dot indicators.
- Projection: swipe gestures on mobile, slide transition animations (fade + slide), teal glow on operator preview screen.
- Navigation: upgraded to Material 3 `NavigationBar` on mobile, `NavigationRail` with brand logo header on desktop.
- Global theme: `FlexSubThemesData` with rounded inputs (r16), cards (r20), dialogs (r24).

## [1.0.0] - Initial Release

- Drift SQLite database with Songs and Categories tables.
- Full song CRUD via `SongEditorView`.
- Verse/chorus parser with `autoInsertChorus` mode.
- Multi-window desktop projection via `desktop_multi_window` IPC.
- Mobile fullscreen projection via `SystemUiMode.immersiveSticky`.
- Legacy `.mdb` import via `mdb-tools` CLI.
- `.vsbook` portable backup (ZIP) export and restore.
- `FlexColorScheme` Teal M3 dark theme, `go_router` navigation.
