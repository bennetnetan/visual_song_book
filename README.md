# Visual Song Book

> A premium, cross-platform church hymnal management, Bible reader, and live projection app built with Flutter.

![Visual Song Book](assets/images/logo.png)

---

## Overview

**Visual Song Book** is a desktop-first (with mobile support) application designed for church worship teams and audio-visual operators. It provides a clean, fast interface for managing a songbook database, reading and searching the King James Version Bible with cross-references, managing song sets for services, and projecting lyrics or Bible passages to a secondary screen — all in a single, polished app.

The app uses **SQLite via Drift** as its main database and a bundled **KJV Bible SQLite** database (with cross-references from openbible.info) for read-only scripture access. Legacy Microsoft Access `.mdb` songbook files and portable `.vsbook` backup archives are supported for import.

---

## Features

### 🎵 Song Management
- Full **CRUD** for songs: title, number, key, author, copyright, category, and lyrics body
- Category filtering (General, Kiswahili, Uncategorized) with live search across title, number, and lyrics
- Verse/chorus structure parser — the app understands `CHORUS` and `VERSE N` blocks
- Auto-suggest next song number on create

### 📖 Bible Reader
- Full **King James Version** with all 66 books, chapter navigation, and verse display
- **Full-text search** across the entire Bible with projections from results
- **Cross-references** (344,799 entries from openbible.info) — tap any verse to see related passages; tap a cross-ref to navigate directly
- **Bookmarks** — save verses for quick access; tapping a bookmark navigates to the exact verse
- Right sidebar combines cross-references and bookmarks in a scrollable panel
- Search bar with clear button, suggestion chips, and query highlighting

### 📂 Song Sets
- Create, rename, reorder, and delete **song sets** for services or events
- **Drag-to-reorder** songs within a set via `ReorderableListView`
- Project an entire set as a continuous slide sequence

### 📽️ Live Projection
- **Desktop (Windows / Linux / macOS)**: Opens a dedicated secondary window on any connected screen using `desktop_multi_window`. Operator controls stay in the main window; lyrics appear full-screen in the projection window
- **Mobile / Tablet**: Push to `/projection` route in immersive sticky fullscreen mode (`SystemUiMode.immersiveSticky`)
- **Bible projection**: Project individual verses or full chapters with scripture reference displayed below the text
- **Unified search**: Inline search bar and SearchAnchor overlay share state — search Bible or songs directly from the projection tab with structured reference parsing ("Jn 3:16"), BEST MATCH cards, query highlighting, and paginated results
- **Chapter-aware navigation** in Bible mode: advancing past the last verse auto-loads the next chapter (handles book boundaries); chapter stepper buttons in the controls panel
- Keyboard navigation: **Arrow keys** and **Space** to advance slides, **Escape** to clear
- Swipe gestures on mobile: swipe left = next slide, swipe right = previous
- **Auto-insert Chorus** mode: automatically repeats the chorus between each verse during projection
- Adjustable font size (24–80 px) with real-time IPC sync to the projection window
- Wakelock support to prevent the screen from sleeping during a service

### 📜 History
- **Three sub-tabs**: Songs | Sets | Bible — each records projection history independently
- Tracks what was projected and when, for service wrap-up logs

### 📥 Import & Export
- **Legacy VSB / MDB import**: Reads Microsoft Access `.mdb` files via the `mdb-tools` CLI (Linux/macOS) and imports all songs and categories into SQLite
- **`.vsbook` backup**: Platform-independent ZIP archive containing the SQLite database. Supports both export (backup) and import (restore)

### 🎨 Design
- Dark mode by default — optimised for a dim operator environment
- Material 3 design system with a premium **Teal M3** colour scheme (`FlexColorScheme`)
- Custom **Outfit** font for UI chrome, **Lora** for lyrics preview, **Roboto Mono** for the lyrics editor
- Cinematic projection screen: radial gradient background, text drop-shadow and teal glow, animated slide transitions
- Branded launcher icons and native splash screen across all platforms

---

## Architecture

```
lib/
├── core/
│   ├── providers/         # Riverpod providers (DB, importers, settings, UI state)
│   ├── utils/             # Verse parser, helpers
│   └── widgets/           # Shared widgets (neomorphic cards, etc.)
├── data/
│   ├── db/                # Drift SQLite schema & DAOs (songbook_db.dart, bible_db.dart)
│   ├── importers/         # MDB, VSB, .vsbook importers
│   ├── models/            # Shared data models (Verse, etc.)
│   └── repositories/      # SongRepository, SetRepository, BibleRepository
├── features/
│   ├── bible/             # Bible reader tab (controller, repository, utils, UI)
│   ├── history/           # History tab with Songs/Sets/Bible sub-tabs
│   ├── projection/        # ProjectionController + ProjectionOutputView + tab + search provider
│   ├── sets/              # Song sets tab (controller, UI)
│   ├── settings/          # Settings tab
│   ├── song_editor/       # SongEditorView (create / edit)
│   └── song_list/         # MainDashboardPage, SongsTab, song widgets
├── routing/
│   └── app_router.dart    # GoRouter config (main + projection window routes)
└── main.dart              # App entry point, theme setup, window init
```

**State management**: `flutter_riverpod` with `riverpod_annotation` code generation  
**Database**: `drift` (type-safe SQLite) + `drift_flutter` + `sqlite3_flutter_libs`  
**Routing**: `go_router`  
**Multi-window IPC**: `desktop_multi_window` via `WindowMethodChannel('projection_channel')`

---

## Getting Started

### Prerequisites

| Tool | Notes |
|---|---|
| Flutter ≥ 3.32 | `flutter --version` |
| Dart SDK ≥ 3.12 | Included with Flutter |
| `mdb-tools` (optional) | Required for `.mdb` import on Linux/macOS — `sudo apt install mdb-tools` |

### Running the app

```bash
# Get dependencies
flutter pub get

# Run on Linux desktop (recommended for full multi-window support)
flutter run -d linux

# Run on Android
flutter run -d android

# Run on Windows
flutter run -d windows
```

### Running tests

```bash
flutter test
```

### Regenerating database code (after schema changes)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Regenerating launcher icons / splash screen

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Projection Window Architecture

On **desktop**, the projection window runs as a separate Dart Isolate (spawned by `desktop_multi_window`). Standard Riverpod state does **not** automatically cross Isolate boundaries, so the app uses lightweight IPC:

```
Main window                          Projection window
────────────────                     ─────────────────────────────
ProjectionController (Riverpod)  →   WindowMethodChannel('projection_channel')
  .selectSlide(index)                  → setState({ text, fontSize })
  .setFontSize(size)
```

The projection window listens on `WindowMethodChannel` and renders whatever text+fontSize it receives, independently of the main window's Riverpod tree.

---

## Supported Platforms

| Platform | Song CRUD | Projection (secondary window) | MDB Import |
|---|---|---|---|
| Linux | ✅ | ✅ Multi-window | ✅ (mdb-tools) |
| Windows | ✅ | ✅ Multi-window | ⚠️ (requires mdb-tools port) |
| macOS | ✅ | ✅ Multi-window | ✅ (mdb-tools via Homebrew) |
| Android | ✅ | ✅ Fullscreen immersive | ❌ |
| iOS | ✅ | ✅ Fullscreen immersive | ❌ |

---

## Changelog

### v1.3.0 (2026-06-25)
- **Unified search infrastructure**: Extracted `bible_search_utils.dart` (book ID map, reference parser, query normalizer) shared between Bible reader and projection
- **Projection search overhaul**: Replaced two duplicated search implementations with a single `ProjectionSearchController` (Riverpod `StateNotifier`) featuring 300ms debounce, structured Bible reference parsing ("Gen 1:1" → BEST MATCH), query highlighting via `HighlightedText`, paginated Bible results with "Show more", loading/error states, and projection history recording
- **Feature parity**: Projection search now matches the Bible tab — BEST MATCH card, testament labels, result count display, and the same `HighlightedText` widget
- **`projection_search_provider.dart`**: New unified Riverpod provider for all projection search state (Bible + Song modes)
- **`HighlightedText` made public**: Reusable highlighted text widget previously private to `bible_tab.dart`

### v1.2.0 (2026-06-24)
- **Bible Reader**: Full KJV with book nav, chapter chips, full-text search, cross-references (344k from openbible.info), verse bookmarks, right sidebar with combined cross-refs + bookmarks panel
- **Song Sets**: Create, rename, reorder (drag), delete song sets; project entire sets as slide sequences
- **History sub-tabs**: Songs | Sets | Bible — independent projection history per category
- **Bible projection**: Chapter-aware navigation — verse up/down auto-advances across chapters and books; chapter stepper controls in projection tab
- **Projection output**: Scripture reference displayed centered below verse text (moved from bottom-right corner)
- **Schema v3**: BibleBookmarks, BibleHistory, SetHistory drift tables with migration
- **Infrastructure**: BibleRepository, SetRepository, bundled KJV SQLite with cross-references, `activeDashboardTabProvider` moved to shared providers

### v1.1.0 (2026-06-13)
- **Branding**: AI-generated app icon (hymnal + cross + music notes, teal gradient); native splash screen with dark teal background
- **UI Polish**: Premium card-grouped song editor, cinematic projection view with Outfit font and radial gradient, lyric preview using Lora serif, animated slide dot indicators
- **Projection**: Swipe gestures on mobile, slide transition animations (fade + slide), teal glow on operator preview screen
- **Navigation**: Upgraded to Material 3 `NavigationBar` on mobile, `NavigationRail` with brand logo header on desktop
- **Global theme**: `FlexSubThemesData` with rounded inputs (r16), cards (r20), dialogs (r24)

### v1.0.0 (Initial Release)
- Drift SQLite database with Songs and Categories tables
- Full song CRUD via `SongEditorView`
- Verse/chorus parser with `autoInsertChorus` mode
- Multi-window desktop projection via `desktop_multi_window` IPC
- Mobile fullscreen projection via `SystemUiMode.immersiveSticky`
- Legacy `.mdb` import via `mdb-tools` CLI
- `.vsbook` portable backup (ZIP) export and restore
- `FlexColorScheme` Teal M3 dark theme, `go_router` navigation

---

## License

Private — not published to pub.dev.
