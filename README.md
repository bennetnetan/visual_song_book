# Visual Song Book

> Song management, KJV Bible reader, and live projection for church worship teams.

![Logo](assets/images/logo.png)

---

## Overview

**Visual Song Book** is a desktop-first application for worship teams and AV operators. It provides songbook management, Bible reading with cross-references, song sets for service planning, and live projection to a secondary screen — all in one app.

---

## Features

- **Song Management** — full CRUD with category filtering, verse/chorus parsing, and auto-numbering
- **KJV Bible Reader** — full-text search, cross-references (344k entries), bookmarks
- **Song Sets** — drag-to-reorder sets for services, assign musical keys, project entire sets
- **Live Projection** — dedicated secondary window (desktop) or fullscreen mode (mobile), adjustable font size, slide transitions, auto-insert chorus
- **Unified Search** — search Bible or songs directly from the projection tab with structured reference parsing
- **History** — tracks projected songs, sets, and Bible passages
- **Import** — legacy `.mdb` (via mdb-tools), `.vsbook` backup archives, bundled JSON songbooks
- **Export** — set sharing (JSON), database backup (`.vsbook`)
- **Linked Songbooks** — link `.vsbook` files from Google Drive or shared folders for automatic sync

---

## Project Structure

```
lib/
├── core/
│   ├── providers/          # Riverpod providers (database, importers, theme, state)
│   ├── utils/              # Verse parser, app logger, layout utils, Win32 helpers
│   └── widgets/            # Shared UI components (bible widgets, settings cards)
├── data/
│   ├── db/                 # Drift SQLite schema & migrations (songs, sets, bible)
│   ├── importers/          # MDB, VSB, bundled JSON, .vsbook importers
│   ├── models/             # Shared data models
│   ├── repositories/       # SongRepository, SetRepository, BackupRepository
│   └── services/           # AppStorage (unified data directory), SeedingService, LinkedSongbooksService
├── features/
│   ├── bible/              # Bible reader tab (repository, search, UI)
│   ├── history/            # History tab (Songs / Sets / Bible sub-tabs)
│   ├── onboarding/         # First-launch setup wizard
│   ├── projection/         # Projection controller, output view, search provider
│   ├── sets/               # Song sets (controller, tab, widgets)
│   ├── settings/           # Settings tab (Appearance, Projection, Library, About)
│   ├── song_editor/        # Song creation / editing view
│   └── song_list/          # Main dashboard, song list, navigation sidebar
├── routing/
│   └── app_router.dart     # GoRouter config (main + projection window routes)
├── main.dart               # App entry point, theme, window init, seeding
└── ...platform configs     # android/, ios/, linux/, windows/, macos/, web/
```

**Stack**: Flutter + Dart · Riverpod (state) · Drift (SQLite ORM) · GoRouter (routing) · desktop_multi_window (IPC)

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

# Desktop (Linux)
flutter build linux --release
./scripts/package_appimage.sh          # → build/Visual_Song_Book-*.AppImage

# Android per-ABI
# versionCode comes from --build-number; pass an explicit --build-name and
# --build-number so they don't stay at 1 between releases.
flutter build apk --split-per-abi --release \
  --build-name 1.8.0 --build-number 12

# Run
flutter run -d linux
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

Current: **v2.2.0** — see About → Changelog in the app for full history.

### v2.2.0 Changes
- Full-screen projection search page replaces SearchAnchor
- System-native share sheet with WhatsApp-first flow and Bible multi-verse sharing
- Song separation banners in slide list and mobile set song list sheet
- Duplicate Set, performance notes, service date scheduling, and quick-project actions
- Song count badge, relative dates, swipe-to-delete, and larger drag touch targets in sets

---

Made by BenjaNetan
