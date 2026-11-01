# Visual Song Book

> Song management, KJV Bible reader, and live projection for church worship teams.

![Logo](assets/images/logo.png)

---

## Overview

**Visual Song Book** is a desktop-first application for worship teams and AV operators. It provides songbook management, Bible reading with cross-references, song sets for service planning, and live projection to a secondary screen — all in one app.

---

## Features

- **Song Management** — full CRUD with category filtering, verse/chorus parsing, auto-numbering, and soft-delete
- **KJV Bible Reader** — full-text search, cross-references (344k entries), bookmarks, chapter-aware navigation
- **Song Sets** — drag-to-reorder sets for services, assign musical keys, duplicate sets, project entire sets
- **Live Projection** — dedicated secondary window (desktop) or fullscreen mode (mobile), adjustable font size, slide transitions, auto-insert chorus
- **Unified Search** — search Bible or songs directly from the projection tab with structured reference parsing
- **History** — tracks projected songs, sets, and Bible passages
- **Import** — legacy `.vsb` / `.mdb` Access songbooks, `.vsbook` backup archives, bundled JSON songbooks
- **Export** — set sharing (JSON), database backup (`.vsbook`)
- **Linked Songbooks** — link `.vsbook` files from Google Drive or shared folders for automatic sync
- **Onboarding** — first-launch setup wizard for initial configuration

---

## Project Structure

```
lib/
├── core/
│   ├── models/             # Enums (ProjectionMode, SourceMode)
│   ├── providers/          # Riverpod providers (database, importers, theme, state)
│   ├── services/           # ShareService (system share sheet)
│   ├── theme/              # FlexColorScheme theming (app_theme.dart)
│   ├── utils/              # AppLogger, VerseParser, LayoutUtils, Win32 helpers
│   └── widgets/            # Shared UI components (bible widgets)
├── data/
│   ├── db/                 # Drift SQLite schema & migrations (songs, sets, bible)
│   ├── importers/          # MDB, VSB, bundled JSON, .vsbook importers
│   ├── models/             # Shared data models (Verse)
│   ├── repositories/       # SongRepository, SetRepository, BackupRepository
│   └── services/           # AppStorage, SeedingService, LinkedSongbooksService
├── features/
│   ├── bible/              # Bible reader tab (repository, search, UI)
│   ├── history/            # History tab (Songs / Sets / Bible sub-tabs)
│   ├── onboarding/         # First-launch setup wizard
│   ├── projection/         # Projection controller, output view, search provider
│   ├── sets/               # Song sets (controller, tab, widgets)
│   ├── settings/           # Settings tab (Appearance, Projection, Data Sources, System)
│   ├── song_editor/        # Song creation / editing view
│   └── song_list/          # Main dashboard, song list, navigation sidebar
├── routing/
│   └── app_router.dart     # GoRouter config (main + projection window routes)
├── main.dart               # App entry point, theme, window init, seeding
└── ...platform configs     # android/, ios/, linux/, windows/, macos/, web/

# Other directories:
tools/                      # export_vsb_to_json.py/.sh (utility scripts)
tool/                       # seed_database.dart, inspect_bible.dart (dev tools)
scripts/                    # package_appimage.sh (Linux packaging)
```

**Stack**: Flutter + Dart · Riverpod (state) · Drift (SQLite ORM) · GoRouter (routing) · desktop_multi_window (IPC) · FlexColorScheme (theming) · logging (centralized logging)

---

## Data Storage

All app data is stored in a single unified directory:

| Platform | Path |
|---|---|
| Linux / macOS / Windows | `~/.visual_song_book/` |
| Android / iOS | `<app-docs>/VisualSongBook/` |

Contents:
- `songs_db.sqlite` — song library, sets, categories, history
- `kjv_bible.sqlite` — KJV Bible text with cross-references

---

## Building

```bash
flutter pub get
npm ci --omit=dev                     # PowerShell: npm.cmd ci --omit=dev

# Desktop (Linux)
flutter build linux --release
./scripts/package_appimage.sh          # → build/Visual_Song_Book-*.AppImage

# Desktop (Windows)
flutter build windows --release

# Desktop (macOS)
flutter build macos --release

# iOS (first build downloads the bundled Node Mobile framework)
flutter build ios --release --no-codesign

# Android per-ABI
# versionCode comes from --build-number; pass an explicit --build-name and
# --build-number so they don't stay at 1 between releases.
flutter build apk --split-per-abi --release \
  --build-name 1.8.0 --build-number 12

# Run
flutter run -d linux       # or -d windows, -d macos, -d chrome
```

## Supported Platforms

| Platform | Minimum Version |
|---|---|
| Android | API 21 (Android 5.0 Lollipop) |
| iOS | 13.0 |
| macOS | 11.0 (Big Sur) |
| Windows | Windows 10 (1809+) |
| Linux | Ubuntu 20.04 / GLIBC 2.29 |

See [docs/SUPPORTED_PLATFORMS.md](docs/SUPPORTED_PLATFORMS.md) for details.

---

## Version

Current: **v2.5.0** — see About → Changelog in the app for full history.

### v2.5.0 Changes
- Self-contained `.vsb` / `.mdb` Access songbook conversion on desktop, Android, and iOS
- Linked songbooks import when linked and sync detected file changes without an app restart
- iOS conversion runtime and dependencies are bundled in the app; iOS builds are checked by CI

### v2.4.0 Changes
- Projection opens automatically: picking a song, Bible passage or set opens the projector window without any manual button
- Projection output is placed and fullscreened on the second screen by each platform (Windows, Linux, macOS)
- Redesigned empty projection page: search embedded in the window (no popup) with Songs/Bible/Sets history tabs and a Sets sheet
- Wildcard search: `*` matches any run of characters, `?` exactly one; literal `%` and `_` are escaped
- Search results paged 10 at a time with "Load more", keeping broad queries manageable
- Fixed the space bar and Enter while typing in the search field
- Fixed duplicating or importing a set losing the selection
- Windows installer with a real wizard, VC++ runtime check, and release builds for all platforms

### v2.3.0 Changes
- Lower thirds live announcement carousel overlay for projection (full-width banner + floating pill styles)
- Lower thirds defaults: master toggle OFF, all announcements OFF, Full-Width Banner default style
- Sets: clipboard import of plain-text set lists; auto-versioning of duplicate/re-imported sets
- Sets: simplified sharing format; copy button in share menu
- Projection window stays alive on close; second-monitor detection and single-monitor safety
- Appearance: user-adjustable app font size slider

---

Made by BenjaNetan
