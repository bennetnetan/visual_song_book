# Linked Songbook Separation — Audit & Implementation Plan

Date: 2026-08-04
Branch: fix/audit-remediation (post Phase 8 baseline)

---

## 1. Current-State Audit

### 1.1 How sources enter the app today

| Source | Entry point | DB table | `sourcePath` | `sourceFormat` |
|---|---|---|---|---|
| Bundled JSON | `SeedingService.seedIfNeeded()` on cold start | `songs` | `"Full Song Book"` / `"Injili Song Book"` | `"bundled_json"` |
| `.vsb` import | `MdbToolsImporter` via file picker | `songs` | absolute `.vsb` path | `"vsb"` |
| Linked `.vsbook` | `VsBookImporter.reimportSource()` on startup + manual link | `songs` | absolute `.vsbook` path | `"vsbook_linked"` |
| Manual add | `SongEditorView` | `songs` | `null` | `null` |

All sources share the **same `songs` table** in the **same `AppDatabase`**. The only “separation” is logical via `sourcePath`/`sourceFormat`.

### 1.2 What the user sees today

- **Onboarding** (`onboarding_page.dart:195-238`): Page 2 offers two cards:
  - “Use Pre-installed Songbooks” → seeds bundled JSON, then goes to preferences
  - “Link Songbook Files” → opens file picker, links selected files, then preferences
- **Selection is not sticky**: Both paths always execute their side-effects; there is no stored preference. “Link Songbook Files” only links but does **not** skip seeding. The seed is idempotent, so duplicates are silently skipped.
- **Song list** (`songs_tab.dart`): Shows a unified list. Source filter chips appear only when `sourcePaths.length > 1`.
- **Song rows** (`song_list_item.dart`): No visual indicator of origin.
- **Settings** (`settings_cards.dart:696-989`): `LinkedSongbooksCard` shows linked files with sync status. `_DataSourcesCard` shows per-source delete buttons. No “default source” preference exists.

### 1.3 Problems identified

| # | Problem | Impact |
|---|---|---|
| P1 | No first-launch preference | User gets both bundled + linked songs mixed, even if they only wanted one |
| P2 | No absolute separation | Linked songs share the same namespace as local songs; `getSongCountByCategory` counts them together |
| P3 | Linked failure = data loss risk | If the linked file is deleted/moved, the app only has what was last imported; no persistent local fallback |
| P4 | No merge strategy | Re-importing a linked file with new categories/songs replaces the old batch; additions are not merged into existing categories |
| P5 | Conflict blindness | Same `songNum` with different content across sources → silent overwrite or constraint error |
| P6 | Title variants invisible | Two songs with near-identical titles (e.g., “Amazing Grace” vs “Amazing Grace (Reprise)”) from different sources appear as separate entries with no indication they might be related |
| P7 | No “source of truth” concept | Users cannot designate “this linked file is my master, don’t edit locally” vs “I edit locally, sync is backup” |

---

## 2. Proposed Model

### 2.1 Source of Truth modes

Add a `SourceMode` enum stored in `SharedPreferences`:

```dart
enum SourceMode {
  bundled,    // Use only pre-installed songbooks; linked files are ignored on startup
  linked,     // Use only linked files; bundled seed is skipped
  unified,    // Show both (current default behavior)
}
```

Key: `default_source_mode` in `SharedPreferences`.

### 2.2 Virtual source separation

Instead of a separate database, use **virtual source isolation** at the query layer:

- Add `sourceMode` filter to `SongListController`:
  - `SourceMode.bundled` → `WHERE sourceFormat IN ('bundled_json', 'vsb') AND sourcePath IS NOT NULL`
  - `SourceMode.linked` → `WHERE sourceFormat = 'vsbook_linked'`
  - `SourceMode.unified` → no filter (current behavior)
- Add a segmented control in `SongsTab` header: “Bundled / Linked / All”
- Persist the selected segment in `SongListState.selectedSourceMode`

### 2.3 Linked-songbook local cache

Introduce a **shadow cache** for linked songbooks:

- Table `linked_songbook_cache(sourcePath TEXT PRIMARY KEY, cachedAt DATETIME, songsJson TEXT, categoriesJson TEXT)`
- On every successful `reimportSource`, write the full song/category JSON to this cache
- On startup, if `hasChangedSinceLastImport` returns `false` **or** the file is missing, load from cache instead
- Cache is refreshed on every successful sync
- This gives us: “if the link fails, we have a local working version”

### 2.4 Merge strategy for re-imports

When `reimportSource` runs, use a **three-way merge** instead of delete-all:

1. **Incoming songs** (from the linked file)
2. **Existing cached songs** (from previous import of the same file)
3. **Local songs** (manually edited songs with the same `sourcePath`)

Merge rules:

| Scenario | Action |
|---|---|
| Song exists in incoming + cache, unchanged | No-op |
| Song exists in incoming + cache, modified in file | Update from incoming |
| Song exists in incoming + cache, modified locally | Keep local, flag as conflict |
| Song exists only in incoming | Insert |
| Song exists only in cache (deleted from file) | Soft-delete (`isActive = false`) |
| New category in incoming | Insert category |
| Category renamed in incoming | Update category name |

### 2.5 Conflict detection for similar titles

Add a **variant detector** that runs after every import/sync:

```dart
class SongVariant {
  final String titleA;
  final String titleB;
  final int songNumA;
  final int songNumB;
  final String sourcePathA;
  final String sourcePathB;
  final double similarity; // 0.0 - 1.0
}
```

Algorithm:
1. Normalize titles: lowercase, trim, remove parenthetical suffixes `(Reprise)`, `(Live)`, etc.
2. Compute Levenshtein distance or use `similar_text` package
3. Group songs where `similarity > 0.85` and `sourcePath` differs
4. Present grouped variants in a review screen

### 2.6 Conflict resolution UI

A new screen: `VariantReviewScreen`

```
┌─────────────────────────────────────┐
│  Resolve Song Variants              │
│  3 potential duplicates found       │
├─────────────────────────────────────┤
│                                     │
│  Title: Amazing Grace               │
│  ┌──────────────┐ ┌──────────────┐  │
│  │ #289          │ │ #12           │  │
│  │ Full Song Book│ │ Injili Song   │  │
│  │              │ │ Book          │  │
│  │ [Keep Both]  │ │ [Keep Both]  │  │
│  │ [Keep Left]  │ │ [Keep Right] │  │
│  └──────────────┘ └──────────────┘  │
│                                     │
│  [Accept All Left] [Accept All Right]│
│  [Skip All]                          │
└─────────────────────────────────────┘
```

### 2.7 First-launch experience redesign

**Page 1 (Welcome)** — unchanged.

**Page 2 (Choose Source)** — replace the two cards with a single segmented choice:

```
┌─────────────────────────────────────┐
│  Choose Your Song Source            │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 📚 Pre-installed Songbooks   │    │
│  │ Full Song Book & Injili Song │    │
│  │ Book are ready to use        │    │
│  │                             │    │
│  │ [Select Pre-installed]      │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔗 Link Your Own Songbooks   │    │
│  │ Connect .vsbook files from   │    │
│  │ Google Drive or local storage│    │
│  │                             │    │
│  │ [Link Files]                │    │
│  └─────────────────────────────┘    │
│                                     │
│  You can change this later in       │
│  Settings > Library > Source Mode   │
└─────────────────────────────────────┘
```

After selection:
- `bundled` → seed bundled, skip linked sync, show Songs tab
- `linked` → skip seeding, open file picker, link files, show Songs tab with linked-only filter

### 2.8 Settings additions

In **Settings > Library**, add:

**Source Mode Card:**
```
┌─────────────────────────────────────┐
│  Song Source                         │
│                                     │
│  Current: Pre-installed Songbooks    │
│                                     │
│  [Change Source Mode]                │
│                                     │
│  This determines which songs are     │
│  loaded on startup. Linked files are │
│  only loaded when "Linked" is active.│
└─────────────────────────────────────┘
```

`Change Source Mode` opens a dialog with the same three options as onboarding.

**Data Sources Card** (existing `_DataSourcesCard`) — add:
- “Export local cache” button (exports the `linked_songbook_cache` table as JSON)
- “Clear local cache” button (deletes cache rows for broken links)

---

## 3. Data Model Changes

### 3.1 New table: `linked_songbook_cache`

```dart
class LinkedSongbookCaches extends Table {
  TextColumn get sourcePath => text()();
  DateTimeColumn get cachedAt => dateTime()();
  TextColumn get songsJson => text()();
  TextColumn get categoriesJson => text()();
  
  @override
  Set<Column> get primaryKey => {sourcePath};
}
```

Schema version bump: 9 → 10.

Migration:
```dart
if (from < 10) {
  await m.createTable(linkedSongbookCaches);
}
```

### 3.2 New SharedPreferences keys

| Key | Type | Purpose |
|---|---|---|
| `default_source_mode` | `String` (`'bundled'`, `'linked'`, `'unified'`) | First-launch source preference |
| `source_mode_override` | `String` or `null` | Per-session override (resets on app restart) |
| `linked_cache_version` | `int` | Bump to invalidate all caches |

### 3.3 New enum

```dart
enum SourceMode { bundled, linked, unified }
```

---

## 4. Implementation Plan

### Phase 0 — Baseline (5 min)
- Verify `flutter analyze` clean, `flutter test` 44/44 pass
- Confirm branch: `fix/audit-remediation`

### Phase 1 — First-launch source preference (30 min)

**Files:**
- `lib/features/onboarding/onboarding_page.dart`
- `lib/core/providers/app_providers.dart`
- `lib/main.dart`
- `lib/data/services/seeding_service.dart`

**Changes:**
1. Add `SourceMode` enum to a new `lib/core/models/source_mode.dart`
2. Add `default_source_mode` preference handling
3. Rewrite onboarding page 2:
   - If `default_source_mode` is already set, skip page 2
   - Otherwise show the two cards; on tap, store the preference and proceed
4. Modify `main.dart` startup:
   - Read `default_source_mode`
   - If `bundled` → run `appSeedProvider`, skip `linkedSongbooksSyncProvider`
   - If `linked` → skip `appSeedProvider`, run `linkedSongbooksSyncProvider`
   - If `unified` or `null` → run both (current behavior)
5. Add “Change Source Mode” to Settings > Library

### Phase 2 — Virtual source filtering (40 min)

**Files:**
- `lib/features/song_list/song_list_controller.dart`
- `lib/features/song_list/songs_tab.dart`
- `lib/features/song_list/widgets/song_list_item.dart`
- `lib/data/repositories/song_repository.dart`

**Changes:**
1. Add `SourceMode` filter to `SongListState`:
   - `selectedSourceMode` (default: `unified`)
   - Persist to `SharedPreferences` key `song_list_source_mode`
2. Update `watchSongsFiltered` to accept `SourceMode`:
   ```dart
   Stream<List<Song>> watchSongsFiltered({SourceMode? sourceMode}) {
     return (db.select(db.songs)
           ..where((t) {
             Expression<bool> expr = t.isActive.equals(true);
             if (sourceMode == SourceMode.bundled) {
               expr = expr & t.sourcePath.isNotNull() & t.sourceFormat.equals('bundled_json');
             } else if (sourceMode == SourceMode.linked) {
               expr = expr & t.sourceFormat.equals('vsbook_linked');
             }
             return expr;
           })
           ..orderBy([(t) => OrderingTerm.asc(t.songNum)]))
       .watch();
   }
   ```
3. Add segmented control in `SongsTab` AppBar:
   - Three segments: “All”, “Bundled”, “Linked”
   - Hidden when `sourcePaths.length <= 1` or on mobile if space is tight
4. Add subtle source indicator to `SongListItem`:
   - Small `Container` (4x4 dp) with color based on `sourceFormat`
   - `bundled_json` → `theme.colorScheme.primary`
   - `vsbook_linked` → `theme.colorScheme.tertiary`
   - `vsb` → `theme.colorScheme.secondary`
   - `null` → `theme.colorScheme.outline`

### Phase 3 — Linked songbook local cache (60 min)

**Files:**
- `lib/data/db/songbook_db.dart` (new table)
- `lib/data/services/linked_songbook_cache_service.dart` (new)
- `lib/data/importers/vsbook_importer.dart`
- `lib/data/services/linked_songbooks_service.dart`

**Changes:**
1. Add `LinkedSongbookCaches` table, bump schema to 10
2. Create `LinkedSongbookCacheService`:
   - `Future<void> saveCache(String sourcePath, List<Song> songs, List<Category> categories)`
   - `Future<List<Song>?> loadSongs(String sourcePath)`
   - `Future<List<Category>?> loadCategories(String sourcePath)`
   - `Future<void> clearCache(String sourcePath)`
3. Modify `VsBookImporter.reimportSource`:
   - After successful import, serialize `songCompanions` + `categoryCompanions` to JSON
   - Call `cacheService.saveCache(sourceFilePath, ...)`
4. Modify `LinkedSongbooksService.hasChangedSinceLastImport`:
   - If file is missing, return `false` (don’t try to sync)
   - In `syncLinkedSongbooks`, if file is missing but cache exists, log: “Source file missing, serving from local cache”
5. Add cache management UI in Settings > Library > Linked Songbooks:
   - “Cache Status: 2 sources cached (1.2 MB)”
   - “Clear Cache” button

### Phase 4 — Merge strategy for re-imports (45 min)

**Files:**
- `lib/data/importers/vsbook_importer.dart`
- `lib/data/services/linked_songbook_merge_service.dart` (new)

**Changes:**
1. Create `LinkedSongbookMergeService`:
   ```dart
   class MergeResult {
     final int inserted;
     final int updated;
     final int softDeleted;
     final int conflicts;
     final List<SongVariant> variants;
   }
   
   Future<MergeResult> merge({
     required String sourcePath,
     required List<SongsCompanion> incoming,
     required List<CategoriesCompanion> incomingCategories,
   })
   ```
2. Merge algorithm:
   - Load existing songs for `sourcePath` into a `Map<(songNum, titleLower), Song>`
   - For each incoming song:
     - If key matches existing → compare `modified`, `body`, `search`, `copyright`, `author`
     - If all fields match → no-op
     - If incoming is newer → update
     - If local is newer → flag as conflict, keep local
     - If no match → insert
   - For categories: upsert by `id`
3. Update `VsBookImporter.reimportSource` to call `merge()` instead of delete-all + insert
4. Add merge stats to `ImportResult`:
   ```dart
   class ImportResult {
     final int songsMerged;
     final int songsUpdated;
     final int songsSoftDeleted;
     final int conflicts;
     // ... existing fields
   }
   ```

### Phase 5 — Variant detection & resolution UI (60 min)

**Files:**
- `lib/data/repositories/song_repository.dart` (new method)
- `lib/features/song_list/widgets/variant_review_screen.dart` (new)
- `lib/features/settings/settings_cards.dart` (link to review screen)

**Changes:**
1. Add `findPotentialVariants()` to `SongRepository`:
   - Query all songs where `sourcePath` differs
   - Normalize titles: `toLowerCase().trim().replaceAll(RegExp(r'\(.*?\)'), '')`
   - Compute similarity using `Levenshtein` or `similar_text`
   - Return `List<SongVariant>` where `similarity > 0.85`
2. Create `VariantReviewScreen`:
   - `ListView` of `VariantGroup` widgets
   - Each group shows 2-4 song cards side by side
   - Actions per song: “Keep”, “Keep Both”, “Merge”
   - “Accept All Left” / “Accept All Right” bulk actions
3. Add entry point in Settings > Library:
   - Button: “Review Song Variants (3 found)”
4. After resolution, update the winning song(s) and mark the loser as `isActive = false` or delete

### Phase 6 — Mobile landing page adjustments (20 min)

**Files:**
- `lib/features/onboarding/onboarding_page.dart`
- `lib/features/song_list/songs_tab.dart`

**Changes:**
1. Onboarding: on mobile, show source choice as a bottom sheet instead of cards
2. SongsTab: on mobile, show source mode as a `SegmentedButton` in the SliverAppBar (compact)
3. When `sourceMode != unified`, show a banner: `"Showing [Bundled/Linked] songs only. Change in Settings > Library > Source Mode."`

### Phase 7 — Tests (30 min)

**New tests:**
- `test/source_mode_test.dart` — SourceMode enum serialization, preference persistence
- `test/linked_cache_service_test.dart` — save/load/clear cache with in-memory DB
- `test/song_variant_detector_test.dart` — similarity threshold, normalization
- `test/merge_service_test.dart` — insert/update/soft-delete/conflict scenarios
- Update `test/populate_db_test.dart` — verify no duplicate inserts when both bundled + linked are active

### Phase 8 — Documentation (15 min)

**New docs:**
- `docs/LINKED_SONGBOOK_SEPARATION.md` — this plan document
- `docs/SOURCE_MODE.md` — user-facing docs on the three source modes
- Update `README.md` — mention source mode preference
- Update `docs/song_book_plus/README.md` — same

---

## 5. File Manifest

| File | Action | Phase |
|---|---|---|
| `lib/core/models/source_mode.dart` | New | 1 |
| `lib/features/onboarding/onboarding_page.dart` | Modify | 1, 6 |
| `lib/core/providers/app_providers.dart` | Modify | 1 |
| `lib/main.dart` | Modify | 1 |
| `lib/data/services/seeding_service.dart` | Modify | 1 |
| `lib/features/song_list/song_list_controller.dart` | Modify | 2 |
| `lib/features/song_list/songs_tab.dart` | Modify | 2, 6 |
| `lib/features/song_list/widgets/song_list_item.dart` | Modify | 2 |
| `lib/data/repositories/song_repository.dart` | Modify | 2, 5 |
| `lib/data/db/songbook_db.dart` | Modify | 3 |
| `lib/data/services/linked_songbook_cache_service.dart` | New | 3 |
| `lib/data/importers/vsbook_importer.dart` | Modify | 3, 4 |
| `lib/data/services/linked_songbook_merge_service.dart` | New | 4 |
| `lib/features/song_list/widgets/variant_review_screen.dart` | New | 5 |
| `lib/features/settings/settings_cards.dart` | Modify | 5, 6 |
| `test/source_mode_test.dart` | New | 7 |
| `test/linked_cache_service_test.dart` | New | 7 |
| `test/song_variant_detector_test.dart` | New | 7 |
| `test/merge_service_test.dart` | New | 7 |
| `docs/LINKED_SONGBOOK_SEPARATION.md` | New | 8 |
| `docs/SOURCE_MODE.md` | New | 8 |

---

## 6. Open Questions

| # | Question | Options | Recommendation |
|---|---|---|---|
| Q1 | Should `SourceMode` be a global app preference or per-user-profile? | Global (SharedPreferences) vs per-profile (DB table) | Global for now; per-profile can be added later with accounts |
| Q2 | When switching from `unified` to `bundled`, what happens to linked songs in the DB? | Keep them (hidden) vs soft-delete them | Keep them (hidden) — user might switch back |
| Q3 | Cache invalidation strategy: time-based or hash-based? | Time (24 h) vs hash (mtime + size) | Hash-based: cache is valid if `mtime` and `size` match the linked file |
| Q4 | Variant resolution: should the user be forced to resolve before proceeding? | Mandatory vs optional | Optional — auto-keep both by default, user can review later |
| Q5 | Should “linked” mode disable manual song creation? | Yes (linked = read-only mirror) vs No (allow local edits) | No — allow local edits; they sync to cache but not to the linked file (which is read-only) |
| Q6 | Merge conflict: local edit vs incoming change — which wins? | Local always wins vs Incoming always wins vs Ask user | Local always wins; flag for variant review if titles diverge |
| Q7 | Should the unique index on `(LOWER(title), songNum)` be relaxed? | Keep strict vs allow duplicates from different sources | Keep strict — dedup + variant review handles cross-source duplicates |

---

## 7. Execution Order

```
Phase 1 (SourceMode + onboarding) → Phase 2 (virtual filtering) → 
Phase 3 (local cache) → Phase 4 (merge) → Phase 5 (variants) → 
Phase 6 (mobile) → Phase 7 (tests) → Phase 8 (docs)
```

Each phase is a separate commit. Rollback via `git revert <phase-commit>`.

Gate criteria per phase:
- `flutter analyze` → 0 issues
- `flutter test` → green (baseline 44 pass; target 55+ after new tests)

---

## 8. Alternatives Considered

| Alternative | Pros | Cons | Verdict |
|---|---|---|---|
| **Separate database per linked file** | True isolation; easy to drop/replace | Breaks cross-source search, sets, history; complex migration | Rejected — too disruptive |
| **SQLite attached database** | Single query surface; can attach/detach | Drift doesn’t support ATTACH out of the box; schema sync pain | Rejected — framework friction |
| **Virtual source filtering (chosen)** | Minimal schema change; preserves existing queries; works on mobile | Still one DB file; conflict resolution is app-level logic | Accepted — best trade-off |
| **Disable unique index** | No import failures | Allows real duplicates; degrades data quality over time | Rejected — we enforce uniqueness + provide merge tools |
