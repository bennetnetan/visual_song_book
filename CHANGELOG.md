# Changelog

All notable changes to Visual Song Book are documented here. Newest first.

## [2.5.0] - 2026-11-01

### Features
- **Songbooks** — `.vsb` / `.mdb` Access files can be imported with the converter bundled in each desktop and mobile build; Android uses its bundled Java reader and iOS embeds Node Mobile.
- **Linked songbooks** — linking a book imports it immediately, and detected changes sync without waiting for an app restart.

### Bug Fixes
- **Linked songbooks** — fixed change detection and sync handling for linked files, including clearer errors when a file cannot be read.

### Build
- Added an unsigned iOS build to CI and packaged the iOS conversion runtime and JavaScript dependencies with the app.

## [2.4.0] - 2026-10-13

### Features
- **Projection** — the projector window now opens by itself when content is projected. Picking a history item, searching, or projecting from the song book, Bible or Sets opens it with no manual step; toggleable in Settings → Projection
- **Projection** — output is placed on the second screen and fullscreened natively on Windows, Linux and macOS. `desktop_multi_window` hardcodes its child window on the primary display, so each runner now prefers a non-primary monitor
- **Projection** — redesigned empty page: search is embedded in the window as a focused field instead of a chip that opens a dialog, with results rendered in place
- **Projection** — Songs / Bible / Sets history tabs of already-projected items, each with its own accent colour, plus a Sets bottom sheet showing track, key and notes
- **Projection** — explicit Search / History tabs on narrow screens, where there is no room for a rail beside the field
- **Search** — `*` matches any run of characters and `?` exactly one. A literal `%`, `_` or `\` is escaped so it matches as itself
- **Search** — song and verse results are paged 10 at a time with a "Load more" button, so a common word in a large songbook no longer loads every match at once

### Bug Fixes
- **Projection** — the space bar and Enter now work while typing in the search field. The slide-advance shortcuts were consuming keys meant for the text field
- **Projection** — replacing the search popup fixes a crash where selecting a history item popped the dashboard's only route
- **Projection** — fixed an `Expanded` placed directly under a `GestureDetector` in the active controls
- **Sets** — duplicating, JSON-importing or plain-text-importing a set lost the selection, because `selectSet` validated against a stream list that had not emitted the new set yet
- **Settings** — `SettingsCard` painted its background on a `Container`, hiding ListTile ink splashes; the background moved to a `Material`

### Internal
- Split `projection_tab.dart` (3368 lines), `settings_cards.dart`, `settings_tab.dart`, `projection_appearance_widgets.dart`, the bible search widgets and `projection_controller.dart` into focused modules
- Windows installer (`installer/windows/setup.iss`) with a welcome/licence/location/finish wizard and a VC++ runtime check
- Fixed CI artifact paths, which pointed at directories Flutter does not write to, so Windows, macOS and the installer were never published

## [2.3.0] - 2026-09-29

### Features
- **Lower thirds** — new live announcement carousel overlay rendered directly on the projection screen
- **Lower thirds** — full-width banner and floating pill display styles, custom background colour & opacity, right-to-left scrolling marquee ticker for long text
- **Lower thirds** — hidden on mobile; banner background matches the projection background; border removed
- **Lower thirds** — master toggle defaults OFF; all sample announcements default to OFF; Full-Width Banner is the default display style
- **Sets** — import plain-text set lists pasted from the clipboard (supports the app's own copy format)
- **Sets** — auto-version duplicate and re-imported sets that share an existing name (e.g. "Sunday Service (v2)")
- **Sets** — simplified sharing format; copy-to-clipboard button replaces the direct WhatsApp option in the share menu
- **Projection** — projection window stays alive on close instead of being destroyed and re-created
- **Appearance** — user-adjustable app font size slider in Appearance settings

### Bug Fixes
- **Projection** — debounced focus listener to prevent infinite fullscreen re-assertion loop
- **Projection** — second-monitor detection via `EnumDisplayMonitors` FFI; skips fullscreen on single-monitor setups
- **Projection** — search changed from full-screen page to a centred dialog
- **Lower thirds** — background colour picker now correctly applies the selected colour to the banner (no alpha-blend corruption)
- **Lower thirds** — wrap `ReorderableListView` item `ListTile` in `Material` to silence ink-splash assertion
- **Bible** — wrap `ListTile` in `Material` to silence ink-splash assertion
- **Linked songbooks** — fixed unique-constraint failure when syncing multiple linked books simultaneously

## [2.2.2] - 2026-09-01

### Bug Fixes
- **Projection window** — added second-monitor detection via `EnumDisplayMonitors` FFI so the projection window automatically moves to an external display instead of fullscreening on the primary screen
- **Projection window** — added retry logic for `desktop_multi_window` plugin channel initialization; falls back to Win32-only fullscreen if IPC fails
- **Projection window** — fixed infinite re-assertion loop caused by `setWindowPos` triggering focus changes; added 500ms debounce cooldown on focus listener
- **Projection window** — removed early `enterBorderlessFullscreenCurrentWindow()` call from `initState` that triggered Win32 `SetWindowPos` during widget build phase, causing focus assertion cascades
- **Projection window** — skipped fullscreen on single-monitor setups to prevent covering the controls; projection stays in windowed mode when no second display is detected

## [2.2.1] - 2026-09-01

### Bug Fixes
- **Projection search** — changed from fullscreen page to centered dialog for better UX
- **Projection search** — resolved focus conflicts; search text is now editable after opening
- **Projection search** — simplified keyboard navigation (arrow up/down only, removed left/right)
- **Settings** — disabled default checkmark icon on selected source mode SegmentedButton
- **Build** — upgraded Gradle to 9.1.0 for Java 25 compatibility
- **Build** — fixed AppImage script path in `package_appimage.sh`

## [2.2.0] - 2026-08-18

### Features
- **Projection search** — replaced SearchAnchor with a dedicated full-screen search page
- **Sharing** — defaulted to system-native share sheet on all platforms; added WhatsApp-first share flow, projection search in empty state, and Bible multi-verse sharing
- **Presentation** — added song separation banners in slide list, in-presentation mobile set song list sheet, and updated mobile button labels
- **Sets** — implemented Duplicate Set, per-song performance notes, service date scheduling, and quick-project actions; added song count badge, relative dates, swipe-to-delete, and larger drag touch targets

### Bug Fixes
- **Settings** — fixed Application Theme label stacking above SegmentedButton in AppearanceCard
- **Sets** — improved wording, dialog actions, empty state, and mobile AppBar

### Dependencies
- Upgraded `share_plus` to 12.0.2

## [2.1.0] - 2026-08-06

### UI/UX
- **Settings — professional redesign across all four tabs** (Appearance, Projection, Data Sources, System)
  - Replaced multi-column side-by-side card grids with a centered, single-column layout constrained to 800 px max-width — eliminates unequal column heights and empty voids on wide screens.
  - `SectionHeader` redesigned: removed chunky coloured icon box, replaced with a slim all-caps label + small inline icon and optional subtitle.
  - `SettingsCard` tightened: thinner border (30 % opacity), 20 px symmetric padding, 12 px corner radius.
  - `AppearanceCard`: theme toggle now sits inline (label left, SegmentedButton right); font size shown as `## pt` beside the label.
  - `ImportExportCard`: replaced three full-width mega-buttons with compact `_ActionRow` widgets (icon + description left, action button right).
  - `AboutCard`: compact horizontal layout — 52 px logo + text block instead of a centred hero.
  - `ProjectionPreferencesCard`: manual `Row + Switch` replaces `SwitchListTile` for consistent padding.
- Footer moved into the System tab scroll area — no longer floats as a separate panel.

### Bug Fixes
- Projection search keyboard focus restored after overlay closes — arrow key navigation now always works without clicking the screen first.
- Set Navigator list now expands and scrolls correctly (replaced `AnimatedContainer` with `AnimatedSize`).

## [2.0.0] - 2026-08-05

### Features
- Settings restructured into tabbed sections: **Appearance**, **Projection**, **Data Sources**, **System**.
- **System tab** — live diagnostics card: database connection status with info-icon tooltip, storage path with copy-to-clipboard, real-time SQLite file sizes.
- **Maintenance card** — warning-dialog protected actions to clear logs/history, re-verify Bible databases, or reset app settings.
- Bible reader: active verse options menu, subtle selection colours, increased verse spacing.
- Cross-references displayed at the top of the sidebar with auto-scroll.
- Default Bible font changed to Lora at 19 pt; font size adjustable via slider in Appearance settings.
- Bible font family preference persisted and migrated from legacy serif boolean setting.

### Performance
- First-run JSON parsing (22 MB bundled songbook) offloaded to a background isolate via `compute()` — eliminates UI freeze on splash screen.
- Bible chapter scroll replaced lazy `ListView.builder` with `SingleChildScrollView + Column` so `Scrollable.ensureVisible` always has a valid element context — fixes erratic cross-reference and search-result navigation.

### Fixes / Hygiene
- Removed `google_fonts` dependency; restored bundled font assets.
- Fixed missing `layout_utils` import in `bible_reading_widgets.dart`.
- `DropdownButtonFormField` updated to use `initialValue` instead of deprecated `value`.
- All Dart analyzer issues resolved (zero warnings/errors).

## [1.9.0] - 2026-08-04

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
