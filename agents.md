# Visual Song Book — Agent Guide

> **Project**: Flutter desktop-first app for church worship teams — songbook management, KJV Bible reader, live projection to a secondary screen.
> **Version**: 2.2.0 · **Dart SDK**: ^3.12.1 · **License**: MIT

---

## Quick Reference

| What | Where |
|---|---|
| Entry point | `lib/main.dart` |
| Router | `lib/routing/app_router.dart` (GoRouter) |
| Theme | `lib/core/theme/app_theme.dart` (FlexColorScheme, Teal M3) |
| Database schema | `lib/data/db/songbook_db.dart` (Drift, schema v10) |
| Bible DB | `lib/data/db/bible_db.dart` (raw sqlite3, read-only) |
| Providers | `lib/core/providers/app_providers.dart` |
| CI | `.github/workflows/ci.yml` |

---

## Architecture

### State Management — Riverpod
- **Pattern**: `StateNotifier` + `StateNotifierProvider` per feature (legacy Riverpod API).
- Each feature has a `*_controller.dart` (logic) and a `*_state.dart` or inline state class.
- Controllers depend on repository providers, not the database directly.
- Global providers (database, repos, tab state) live in `lib/core/providers/app_providers.dart`.

### Database — Drift (SQLite ORM)
- `AppDatabase` in `lib/data/db/songbook_db.dart` — songs, categories, sets, history, bookmarks.
- Schema version 10 with incremental migrations in `onUpgrade`.
- Hot-swappable via Riverpod `Provider` (backup restore replaces the provider).
- Bible DB is a separate read-only sqlite3 file (`kjv_bible.sqlite`), opened via `BibleDatabase` with background-isolate queries (`compute()`).

### Feature Layout
```
lib/features/
├── bible/          Bible reader (controller, repository, search utils, widgets/)
├── history/        History tab (songs, sets, bible sub-tabs)
├── onboarding/     First-launch wizard
├── projection/     Controller, output view, search provider, theme, IPC
├── sets/           Song sets (controller, tab, widgets/)
├── settings/       Tabbed settings (Appearance, Projection, Data Sources, System)
├── song_editor/    Create/edit songs
└── song_list/      Main dashboard, song list, sidebar
```

### Multi-Window Projection
- Desktop: `desktop_multi_window` spawns a secondary engine with args `'Projection Output:<mode>'`.
- IPC between main ↔ secondary via `WindowController.invokeMethod` / `setWindowMethodHandler`.
- `main.dart` detects projection window args and runs a stripped-down `MaterialApp.router` with `projectionRouter`.

**Auto-projection to the second screen (PowerPoint-style):**
- Setting any content (`setSong`, `setBiblePassage`, `projectVerse`/`_loadChapter`, `projectSongSet`) calls `_triggerAutoProjection()`, which opens the projector window automatically. Only fires on desktop, in `ProjectionMode.extended`, and **only when a non-primary display is connected** (checked via `screen_retriever`), so single-display users keep control of their screen.
- **Native placement is the primary mechanism** because `desktop_multi_window` hardcodes its child window origin/size (Win32: `origin(10,10)`/`800x600`; macOS: `NSRect(0,0,800,600)`), which always lands on the primary display:
  - **Windows** — `windows/runner/flutter_window.cpp` `OnSecondaryWindowCreated()` enumerates monitors with `EnumDisplayMonitors`, prefers a non-primary one, and fills it via `SetWindowPos`.
  - **Linux** — `linux/runner/my_application.cc` `on_window_created()` uses `gdk_display_get_monitor`/`gdk_monitor_get_geometry` to move the window before `gtk_window_fullscreen`.
  - **macOS** — `macos/Runner/MainFlutterWindow.swift` registers `FlutterMultiWindowPlugin.setOnWindowCreatedCallback` (from `AppDelegate.applicationDidFinishLaunching`) to pick a non-primary `NSScreen` and fill it borderless. `window_manager` is **not** registered in secondary engines here, so the native path is the only reliable one.
- **Dart-side IPC is a secondary mechanism**: `set_window_bounds` + `go_fullscreen` are forwarded to the secondary engine. It only succeeds on Linux (the only runner that calls `fl_register_plugins` in secondary engines); calls are wrapped in try/catch **with a 2s timeout** so they fail safely on Windows/macOS.
- If no second display is detected, auto-projection is skipped and the operator can still use the manual "Open Projector Output Window" button in the Projection controls app bar.

### Projection feature layout
`lib/features/projection/` is split into focused modules — keep new widgets in
their own file here rather than growing any single file past ~500 lines:

| File | Contents |
|---|---|
| `projection_tab.dart` | `ProjectionTab` shell, app bar, focus + slide-key handling |
| `empty_projection_state.dart` | empty-window layout and the narrow Search/History tabs |
| `projection_history_panel.dart` | recently projected Songs/Bible/Sets/Bookmarks, `HistoryTabButton` |
| `projection_slide_list.dart` | slide list and slide-label badges |
| `projection_live_preview.dart` | live preview panel and lower-third overlay |
| `projection_header.dart` | header row, mode badge, clear + auto-chorus toggles |
| `projection_set_navigator.dart` | set navigator panel |
| `projection_search_field.dart` | `InlineProjectionSearch` |
| `projection_search_page.dart` | search chip anchor + full-screen search dialog |
| `projection_search_widgets.dart` | `SearchModeToggle`, `ModeChip` |
| `projection_search_results.dart` | result dispatch + `composeSearchResults`/`countSearchResults`/`shareSearchItem` |
| `projection_bible_search_results.dart` | Bible verse result rows |
| `projection_song_search_results.dart` | song result rows |
| `projection_sets_drawer.dart` | sets bottom sheet + button |
| `projection_output_view.dart` | secondary-window output view |
| `projection_controller.dart` | projection state + IPC orchestration |
| `projection_appearance_widgets.dart` | appearance controls |

### Routing
- **GoRouter** with 3 routes: `/` (dashboard), `/projection`, `/song-editor`.
- Projection window has its own `projectionRouter` (single `/projection` route).
- Tab state managed by `activeDashboardTabProvider` (StateProvider<int>), not the router.

---

## Key Conventions

### Code Style
- **Linter**: `flutter_lints` + custom rules in `analysis_options.yaml`.
- Single quotes (`prefer_single_quotes`), no `late` unless necessary, `ColoredBox`/`DecoratedBox` over raw `Container`.
- All imports use `package:visual_song_book/...` (no relative imports).
- Generated files: `*.g.dart` excluded from analysis.

### Naming
- Files: `snake_case.dart` (e.g., `bible_controller.dart`).
- Classes: `PascalCase` (e.g., `BibleController`, `ProjectionState`).
- Providers: `camelCaseProvider` (e.g., `songRepositoryProvider`, `bibleControllerProvider`).
- Feature providers are exported from the feature's top-level file or the controller file.

### File Organization
- One feature = one directory under `lib/features/`.
- Widgets go in `widgets/` subdirectory when >1 widget per feature.
- Data layer: `data/db/` (schema), `data/repositories/` (queries), `data/services/` (app-level), `data/importers/` (file import).
- Core: `core/utils/` (parsers, helpers), `core/widgets/` (shared UI), `core/models/` (enums).

### Testing
- Tests in `test/` — flat directory, `*_test.dart` naming.
- `AppDatabase.forTesting()` creates an in-memory SQLite DB.
- CI: `flutter analyze` → `flutter test` → platform builds (Linux, Windows, macOS).

---

## Database Tables (Drift)

| Table | Purpose |
|---|---|
| `Songs` | Song library (title, body, number, key, author, category, source, soft-delete) |
| `Categories` | Song collections (Full Song Book, Injili Song Book, user-created) |
| `SongBooks` | Songbook metadata (title, number range) |
| `SongSets` | Service planning sets (name, notes, occasion, date, UUID) |
| `SongSetItems` | Songs in a set (position, per-song key, notes) |
| `History` | Recently projected songs (last 50) |
| `SetHistory` | Recently projected sets |
| `BibleHistory` | Recently projected Bible passages |
| `BibleBookmarks` | Saved Bible verses |
| `LinkedSongbookRegistry` | Linked `.vsbook` files for auto-sync |

---

## Importers

| Importer | Format | Notes |
|---|---|---|
| `BundledJsonImporter` | JSON asset | First-launch seeding (Full Song Book + Injili Song Book) |
| `MdbToolsImporter` | `.mdb` | Legacy Access DB via `mdb-tools` CLI (Linux only) |
| `VsBookImporter` | `.vsbook` ZIP | Backup archive with songs + sets |
| `VsbImporter` | — | Base class: defines `SongbookImporter` interface, `ImportSource`, `ImportResult` |

---

## Known Issues & Troubleshooting

### Build Issues
- **Linux**: Requires `mdb-tools` for `.mdb` import. Install via `sudo apt-get install mdb-tools`.
- **Windows**: Win32 fullscreen uses FFI. If projection crashes, check `lib/core/utils/win32_window_helper.dart`.
- **First launch**: Can take 5-15s on low-end devices while seeding bundled songbooks (~22 MB JSON parsing) and copying Bible DB (~29 MB). A splash screen shows progress.

### Runtime Issues
- **Projection window not opening**: On Linux, the secondary window can't close itself (would crash). It asks the main window to close it via IPC.
- **Projection opens on the wrong screen**: Placement is native per-runner. Check `OnSecondaryWindowCreated` (Windows), `on_window_created` (Linux), or `MainFlutterWindow.placeProjectionWindowOnSecondScreen` (macOS). Auto-projection also requires ≥2 displays in `Settings → Projection → Extended` mode; with one display it is intentionally skipped.
- **Stale set selection**: If a set is deleted externally, `SetsController` auto-clears stale `selectedSetId` to prevent crashes.
- **Bible DB validation**: On startup, the app checks if `cross_references` table exists. If missing, it re-copies the bundled DB.
- **Seed marker drift**: If DB file is recreated while SharedPreferences still says 'seeded', the app detects empty DB and re-seeds.

### Platform-Specific
- **Android**: Uses debug signing by default. Configure keystore for release builds.
- **macOS**: Minimum version 11.0 (Big Sur).
- **Web**: No projection window support (uses in-app fullscreen instead).

### Debugging
- **Logging**: All logs use `AppLogger` (`dart:logging` package). In debug mode, all levels print. In release, only WARNING+.
- **Test DB**: Use `AppDatabase.forTesting()` for in-memory SQLite in tests.
- **Bible queries**: Run on background isolate via `compute()` to avoid UI jank on 31k verse scans.

### Adding a New Provider
1. Define the provider in feature file or `lib/core/providers/app_providers.dart`
2. Follow naming convention: `camelCaseProvider`
3. Use `Provider` for singletons, `StateNotifierProvider` for stateful controllers
4. Export from feature's top-level file if needed

### Projection System
- **Background types**: Gradient, solid color, image, video
- **Media rotation**: Per-slide, timed, manual modes
- **IPC**: Main window ↔ secondary via `desktop_multi_window`
- **Theme sync**: `ProjectionThemeNotifier` persists appearance settings
- **Auto-project**: Content setters (`setSong`, `setBiblePassage`, `projectVerse`, `projectSongSet`) auto-open the projector window on the second screen. Gated on `ProjectionMode.extended` + an existing non-primary display — see "Multi-Window Projection" above.
- **Empty projection page**: search is embedded in the body of the window as a focused `SearchBar` (`InlineProjectionSearch`) rather than a chip in a top bar that opens a dialog. Results render in place, with the Bible/Songs mode chips and the songbook filter beside the field. On wide screens the recently projected history keeps its own rail; on narrow screens an explicit Search / History tab pair (`EmptyProjectionSection`) decides what fills the window. Sets are reachable through `showProjectionSetsDrawer`.
- **Search while projecting**: once content is on screen the controls app bar carries a search action that opens the full-screen dialog; a compact search shortcut also sits in the live-preview header.
- **Result rendering is shared** by the inline search and the dialog: `ProjectionSearchResultsList` plus `composeSearchResults` / `countSearchResults` / `shareSearchItem`. Add new result behaviour there, not in either widget.
- **Chunked results**: both modes page their results `ProjectionSearchState.pageSize` (10) at a time via `LIMIT/OFFSET`, then append on `loadMoreBible()` / `loadMoreSongs()`. Without this a common word in a large songbook matched every song and loaded every body at once. `HighlightedText.maxLines` caps preview text (3 lines for verse text, 2 for titles) so long passages stay readable.
- **Search**: results are debounced 250 ms and cached per query string per mode; pressing Enter projects the highlighted row (via `SearchBar.onSubmitted` — an ancestor `Focus` never sees Enter because a single-line field consumes it), ↑/↓ move the selection. When querying songs directly use `SongRepository.searchSongs(limit:, offset:)` together with `countSearchSongs`; both share `_searchPredicate` so a count can never drift from the results it pages.
- **Keyboard ownership**: `ProjectionTab._handleProjectionKeys` owns space / arrows / page up-down / escape for slide navigation, but bails out whenever a text field has focus (`_isTextEditing`). Without that guard an ancestor consuming the key stops the focused field from ever receiving it, so the inline search could not accept a space bar and the arrows advanced slides instead of moving the caret. If you add another keyboard shortcut to the projection controls, add the same guard first.

---

## Common Tasks

### Adding a new Drift table
1. Define the table class in `lib/data/db/songbook_db.dart`.
2. Add it to the `@DriftDatabase(tables: [...])` list.
3. Bump `schemaVersion` and add migration logic in `onUpgrade`.
4. Run `dart run build_runner build` to regenerate `songbook_db.g.dart`.
5. Create a repository class in `lib/data/repositories/` if needed.
6. Add a Riverpod provider in `lib/core/providers/app_providers.dart`.

### Adding a new feature tab
1. Create directory under `lib/features/your_feature/`.
2. Add controller + state, tab widget, and any sub-widgets.
3. Add a `GoRoute` in `lib/routing/app_router.dart` if navigable.
4. Add a `NavigationRailDestination` / `NavigationDestination` in `lib/features/song_list/main_dashboard_page.dart`.
5. Add the tab case to `_buildTabContent()`.

### Running the app
```bash
flutter pub get
flutter run -d linux       # or -d windows, -d macos
flutter run -d chrome      # web (no projection window support)
```

### Building
```bash
flutter build linux --release
flutter build windows --release
flutter build macos --release
flutter build apk --release
./scripts/package_appimage.sh   # Linux AppImage
```

**Windows builds cannot be produced on Linux.** Flutter compiles Windows
binaries with MSVC, so `flutter build windows` exits with "only supported on
Windows hosts". Desktop release artifacts are therefore built by CI.

### Releases & the Windows installer
Releases are produced by `.github/workflows/ci.yml` when a `v*.*.*` tag is
pushed (`git tag v2.3.0 && git push --tags`):

| Job | Runner | Produces |
|---|---|---|
| `build` | linux/windows/macos | per-platform archive (tar/zip) |
| `windows-installer` | windows-latest | Inno Setup `.exe` installer |
| `release` | ubuntu-latest | Android APK, then publishes everything to the GitHub Release |

Notes:
- Each archive is created on the runner that built it. A macOS `.app` is full
  of symlinks in `Frameworks/`, so rezipping it on Linux would break them.
- Real output paths are `build/linux/x64/release/bundle`,
  `build/windows/x64/runner/Release` and
  `build/macos/Build/Products/Release/Runner.app` (Xcode target is `Runner`).
  The CI verifies these exist before packaging, so a Flutter layout change
  fails the build instead of publishing an empty release.
- The installer script is `installer/windows/setup.iss`. It is a full wizard
  (Welcome → MIT licence → all-users/per-user → install location → Start Menu
  → install → finish with a "Launch now" checkbox), not a silent extract.
- `dist/` (installer output) and `installer/windows/redist/` (the VC++
  redistributable CI downloads before compiling) are git-ignored.
- Flutter's Windows bundle does not include `msvcp140.dll`; the installer
  detects the VC++ runtime from the registry and installs the bundled
  `vc_redist.x64.exe` silently when missing, and continues (with a log) if
  that step fails.
- To compile the installer locally on Windows:
  `ISCC.exe /DMyAppVersion=<x.y.z> installer\windows\setup.iss`

### Running tests
```bash
flutter test
```

---

## Environment Setup

### Prerequisites
- **Flutter**: Stable channel (3.x+)
- **Dart SDK**: ^3.12.1
- **Linux**: `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev mdbtools`
- **Windows**: Visual Studio 2022 with C++ desktop development workload
- **macOS**: Xcode 14+ with CocoaPods

### First-Time Setup
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Generate Drift code
flutter run -d linux  # or -d windows, -d macos
```

### Code Generation
After modifying Drift tables in `lib/data/db/songbook_db.dart`:
```bash
dart run build_runner build --delete-conflicting-outputs
```
This regenerates `songbook_db.g.dart`.

---

## Asset Management

| Directory | Contents |
|---|---|
| `assets/fonts/` | Inter, Outfit, Lora, EBGaramond font families |
| `assets/images/` | App logo (`logo.png`) |
| `assets/songbooks/` | Bundled songbook JSON files |
| `assets/databases/` | KJV Bible SQLite database (~29 MB) |

### Adding Fonts
1. Place `.ttf` files in `assets/fonts/`
2. Add font family declaration in `pubspec.yaml` under `flutter.fonts`
3. Reference via `fontFamily: 'FamilyName'` in widgets

---

## Platform Notes

| Platform | Min Version | Notes |
|---|---|---|
| Android | API 21 | Per-ABI APKs |
| iOS | 13.0 | |
| macOS | 11.0 | |
| Windows | 10 (1809+) | Win32 fullscreen via FFI |
| Linux | Ubuntu 20.04 / GLIBC 2.29 | Needs `mdb-tools` for `.mdb` import |

---

## Dependencies (Key)

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management (legacy StateNotifier API) |
| `drift` / `drift_flutter` | SQLite ORM |
| `sqlite3` / `sqlite3_flutter_libs` | Bible DB (read-only, background isolate) |
| `go_router` | Navigation |
| `flex_color_scheme` | Theming (Teal M3 scheme) |
| `desktop_multi_window` | Projection window IPC |
| `window_manager` | Desktop window control |
| `wakelock_plus` | Keep screen awake during projection |
| `video_player` / `fvp` | Video playback |
| `csv` / `archive` | Import/export |
| `shared_preferences` | Settings persistence |
| `share_plus` | System share sheet |
| `url_launcher` | External links |
| `logging` | Centralized app logging (AppLogger) |
| `flutter_inset_shadow` | Shadow effects |
| `path_provider` | Platform-specific paths |

---

## Data Storage

| Platform | Path |
|---|---|
| Linux / macOS / Windows | `~/.visual_song_book/` |
| Android / iOS | `<app-docs>/VisualSongBook/` |

Contents: `songs_db.sqlite`, `kjv_bible.sqlite`
