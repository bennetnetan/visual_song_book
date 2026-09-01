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
- Secondary window goes fullscreen via Win32 FFI on Windows, GTK on Linux.

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
- **Search**: Opens as centered dialog (`showDialog`), not fullscreen page. Uses `SearchBar` with keyboard navigation (arrow keys + Enter)
- **Focus management**: Search dialog returns focus to `returnFocusTo` widget on close

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
