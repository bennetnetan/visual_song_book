# Audit Execution Plan

Source: `docs/AUDIT_REPORT.md` (17 findings, 2026-08-04).
Baseline: git `8874148`, `flutter analyze` clean, `flutter test` 44 pass.
Gate per phase: `flutter analyze` + `flutter test` must stay green.
Branch: `fix/audit-remediation` (create if missing).

---

## Phase 0 — Baseline verification (5 min)

1. `git checkout -b fix/audit-remediation` (skip if already on it)
2. Confirm `flutter analyze` reports **no issues**.
3. Confirm `flutter test` reports **44 pass**.
4. Record current commit: `git log --oneline -1` → should be `8874148`.

---

## Phase 1 — MAJOR: Data & Security (30 min)

### 1a. D1 — `getSongCountByCategory` full-table count (5 min)

**File:** `lib/data/repositories/song_repository.dart:154-159`

Replace the row-fetching + `.length` with a server-side `COUNT(*)`:
```dart
Future<int> getSongCountByCategory(int categoryId) async {
  final result = await (db.selectOnly(db.songs)
    ..addColumns([db.songs.id.count()])
    ..where(db.songs.categoryId.equals(categoryId) & db.songs.isActive.equals(true))
  ).getSingle();
  return result.read(db.songs.id) ?? 0;
}
```

Verify: callers unchanged (returns `Future<int>`); `flutter test` green.

---

### 1b. S2 — Linked-songbook path canonicalization (25 min)

**File:** `lib/data/services/linked_songbooks_service.dart`

1. Add a helper:
```dart
String _canonicalizePath(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.resolveSymbolicLinksSync();
    }
  } on IOException catch (_) {}
  return path;
}
```

2. Call `_canonicalizePath(path)` inside `add()` before creating `LinkedSongbook` (line 101) and inside `reimportSource`/`_save` paths where paths are persisted or re-read.

3. In `hasChangedSinceLastImport`, guard `statSync()` with a try/catch that returns `false` on any IO exception (symlink loops, permission errors).

4. Add a private `_isPathAllowed(String path)` that rejects paths outside `HOME` and app storage; log a warning and skip disallowed paths during sync.

Verify: link a symlink → app starts without throwing; sync skips it gracefully.

---

## Phase 2 — MINOR: Data layer hardening (30 min)

### 2a. D2 — `_parseModified` accepts milliseconds too (10 min)

**File:** `lib/data/importers/vsbook_importer.dart:14-22`

Update:
```dart
DateTime? _parseModified(Object? value) {
  if (value is int) {
    final ms = value > 1_000_000_000_000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}
```

Verify: export `.vsbook` → re-import → `modified` round-trips within 1 s.

---

### 2b. D3 — Unique index on `(title, songNum)` (20 min)

**File:** `lib/data/db/songbook_db.dart`

1. Add:
```dart
@override
Set<Column> get primaryKey => {id};

static const _uniqueIdx = '''CREATE UNIQUE INDEX IF NOT EXISTS idx_songs_title_num
  ON songs (LOWER(title), songNum) WHERE is_active = 1''';
```

2. Bump `schemaVersion` from `6` to `7`.

3. Add migration:
```dart
if (from < 7) {
  await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_songs_title_num ON songs (LOWER(title), songNum) WHERE is_active = 1');
}
```

4. Run `dart run build_runner build --delete-conflicting-outputs`.

Verify: attempt duplicate insert → throws `DriftUniqueConstraintException`.

---

## Phase 3 — Architecture cleanup (30 min)

### 3a. A1 — Replace `debugPrint` with `AppLogger` (15 min)

**File:** `lib/features/projection/projection_controller.dart`

1. Add `final _log = AppLogger.get('ProjectionController');` after imports.
2. Replace every `debugPrint(...)` with the appropriate level:
   - informational → `_log.fine(...)`
   - warnings → `_log.warning(...)`
   - errors → `_log.severe(...)`
3. Remove unused `dart:developer` import if `debugPrint` was the only consumer.

---

### 3b. A2 — Early-exit `_syncSecondaryWindowWithRetry` (5 min)

**File:** `lib/features/projection/projection_controller.dart:506-514`

```dart
Future<void> _syncSecondaryWindowWithRetry() async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (_secondaryWindow == null) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (await _syncSecondaryWindow()) {
      _log.fine('Secondary window synced on attempt $attempt');
      return;
    }
  }
  _log.warning('Secondary window sync timed out after 10 attempts.');
}
```

---

### 3c. A3 — Comment empty `catch` blocks (10 min)

**Files:** `projection_controller.dart:163`, `linked_songbooks_service.dart:205`, `projection_output_view.dart:204`, plus any others found by `rg "catch \(_\)" lib/`.

Add `// ignore: empty_catches` or a one-line comment explaining the intentional swallow (e.g. `// Non-critical: ignore missing prefs on first launch`).

---

## Phase 4 — Security hardening (15 min)

### 4a. S1 — Cap `body` length (15 min)

**File:** `lib/data/db/songbook_db.dart:21`

Change:
```dart
TextColumn get body => text().withLength(max: 1_000_000)();
```

Bump `schemaVersion` to `8`; add migration:
```dart
if (from < 8) {
  // Recreate body column with max length (Drift does not support ALTER COLUMN)
  await customStatement('ALTER TABLE songs DROP COLUMN body');
  await customStatement('ALTER TABLE songs ADD COLUMN body TEXT NOT NULL DEFAULT \'\'');
}
```

*Fallback:* if the ALTER approach is risky, skip the migration and add a runtime check in `SongEditorView._save()` that truncates to 1 MB before insert. Document the cap in the schema comment.

---

## Phase 5 — Performance (30 min)

### 5a. P1 — Batch category counts (15 min)

**File:** `lib/data/repositories/song_repository.dart`

Add:
```dart
Future<Map<int, int>> getSongCountsByCategory() async {
  final result = await (db.selectOnly(db.songs)
    ..addColumns([db.songs.categoryId, db.songs.id.count()])
    ..where(db.songs.isActive.equals(true))
    ..groupBy([db.songs.categoryId])
  ).get();
  return {
    for (var row in result)
      row.read(db.songs.categoryId)!: row.read(db.songs.id)!,
  };
}
```

Update `SongListController._loadSourcePaths` → also load category counts. Update `SongListState` to carry `Map<int,int> categoryCounts` and expose `getSongCountByCategory` as a derived getter (or keep the old method as a wrapper for backward compatibility).

---

### 5b. P2 — Single watch stream or DB index (15 min)

**Option A (quick):** Add a covering index:
```dart
// In songbook_db.dart migration from < 9:
await customStatement('CREATE INDEX IF NOT EXISTS idx_songs_active_category ON songs (is_active, categoryId, songNum)');
```

**Option B (proper):** Refactor `SongListController._init` to subscribe only to `watchSongs()` and derive category/source filters in Dart. Out of scope for this pass if index solves it.

Recommend Option A first; measure with `EXPLAIN QUERY PLAN`.

---

## Phase 6 — UI/UX polish (40 min)

### 6a. U1 — Accessibility labels on icon buttons (30 min)

**Files:** `lib/features/settings/settings_cards.dart`, `lib/features/sets/widgets/set_detail.dart`, `lib/features/projection/projection_tab.dart`

- Add `tooltip` and `semanticLabel` to every `IconButton` (unlink, drag handles, chevrons, dot indicators).
- Wrap non-button icon-only tap targets in `Semantics(label: ..., button: true, child: ...)`.

---

### 6b. U2 — Theme-consistent colors (10 min)

**File:** `lib/features/settings/settings_cards.dart:657-658, 787-802`

Replace:
- `Colors.red` → `theme.colorScheme.error`
- `Colors.orange` → `theme.colorScheme.tertiary`
- `Colors.green` → `theme.colorScheme.primary`

Verify in both light and dark themes.

---

## Phase 7 — Test coverage (30 min)

### 7a. T1 — `is_active` round-trip test (20 min)

**File:** `test/vsbook_importer_test.dart` or new `test/backup_roundtrip_test.dart`

1. Insert a song, soft-delete it.
2. Export `.vsbook` via `BackupRepository`.
3. Create fresh `AppDatabase.forTesting()`.
4. Import the `.vsbook`.
5. Assert song count == 1 and `isActive == false`.

---

### 7b. T2 — Edge-case `parseProjectionWindowArgs` (10 min)

**File:** `test/projection_window_args_test.dart`

Add cases:
- `''` → not projection, `extended`
- `'Projection Output'` (no colon) → projection, `extended`
- `'Projection Output:duplicate'` → projection, `duplicate`
- `'Projection Output:single'` → projection, `single`

---

## Phase 8 — Build & docs (20 min)

### 8a. B1 — Document OS minimums (20 min)

1. Create `docs/SUPPORTED_PLATFORMS.md`:
   - Linux: Ubuntu 22.04+ / GLIBC 2.29+
   - Windows: Windows 10+
   - macOS: 11.0+
   - Android: API 21+
   - iOS: 12.0+
2. Update `docs/song_book_plus/README.md` Supported Platforms table with minimum versions.
3. Update `README.md` Building section to mention `--build-name` / `--build-number`.

---

## Execution order

```
Phase 0 → Phase 1 (D1, S2) → Phase 2 (D2, D3) → Phase 3 (A1, A2, A3)
  → Phase 4 (S1) → Phase 5 (P1, P2) → Phase 6 (U1, U2) → Phase 7 (T1, T2)
  → Phase 8 (B1)
```

Deferred / awaiting product owner: **B2** (Android signing), **T3** (projection lifecycle integration test, 2 h).

---

## Gate criteria

- `flutter analyze` → **0 issues**
- `flutter test` → **green** (target: 47+ pass after new tests)
- `dart run build_runner build` → completes without error (Phase 2b only)

---

## Rollback

Each phase is a single commit. To rollback a broken phase:
```bash
git revert <phase-commit>
```
