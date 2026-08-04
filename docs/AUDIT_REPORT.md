# Visual Song Book — Multi-Expert Audit

Source: independent review by data, architecture, security, build, QA, UI/UX, and performance experts.
Date: 2026-08-04.
Scope: full `lib/`, `docs/`, platform configs, and test suite.
Baseline: `flutter analyze` clean, `flutter test` 44 pass, git `main` at `8874148`.

---

## Executive Summary

The application is in **good health**. All 18 pre-existing analyzer issues have been resolved, the full test suite passes (44/44), and the major remediation items from the prior audit plan (data-layer type safety, Bible continue-reading, projection window classification, live history refresh, category feature, search load-more, dead-code removal) are complete. The remaining findings are **quality-of-life improvements** and **preventive hardening** — none are show-stoppers, but together they raise maintainability, testability, and platform robustness before the next release.

---

## 1. Data Layer & Persistence (Database Expert)

### D1 — `getSongCountByCategory` loads every song ID just to count them  `MAJOR`

**File:** `lib/data/repositories/son_repository.dart:154-159`

**Root cause:** The method runs `SELECT id FROM songs WHERE categoryId = ? AND isActive = 1`, maps every row to an `int`, then returns `ids.length`. SQLite can count on the server side in O(1) instead of transferring N rows.

**Fix:**
```dart
Future<int> getSongCountByCategory(int categoryId) async {
  final result = await (db.selectOnly(db.songs)
    ..addColumns([db.songs.id.count()])
    ..where(db.songs.categoryId.equals(categoryId) & db.songs.isActive.equals(true))
  ).getSingle();
  return result.read(db.songs.id) ?? 0;
}
```

**Verify:** `flutter test` stays green; no change to public API.

---

### D2 — `modified` timestamps on re-import lose sub-second precision  `MINOR`

**File:** `lib/data/importers/vsbook_importer.dart:16`

**Root cause:** `_parseModified` treats `int` as unix-*seconds* (`DateTime.fromMillisecondsSinceEpoch(value * 1000)`). If a `.vsbook` stores true unix-*milliseconds* (some tools do), the date shifts by 3 orders of magnitude. The bundled-JSON importer (`bundled_json_importer.dart:74`) stores `DateTime.now()` which Drift persists as unix-seconds — consistent within the app, but a `.vsbook` exported by another tool might differ.

**Fix:** Accept both seconds and milliseconds by detecting magnitude:
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

**Verify:** Export a `.vsbook`, re-import, inspect `modified` — should round-trip within 1 s.

---

### D3 — No database-level `UNIQUE` constraint on `(songNum, title)`  `MINOR`

**File:** `lib/data/db/songbook_db.dart:16-38`

**Root cause:** Deduplication during seeding is done in Dart (see `bundled_json_importer.dart:90-108`). A race condition or a future importer could insert duplicates that the Dart layer misses.

**Fix:** Add a unique index on `(LOWER(title), songNum)` in `songbook_db.dart` and bump `schemaVersion` to 7 with a migration. For existing duplicates, keep the lowest `id`.

**Verify:** `dart run build_runner build`; attempt to insert a duplicate — should throw `DriftUniqueConstraintException`.

---

## 2. Architecture & State Management (Software Architect)

### A1 — `ProjectionController` mixes debug logging with domain logic  `MINOR`

**File:** `lib/features/projection/projection_controller.dart` (throughout)

**Root cause:** The controller uses `debugPrint(...)` for status messages (lines 414, 423, 431, 463, 510, 537, 541, 553, 572, 579, 610). `AppLogger` is already wired (`core/utils/app_logger.dart`) and used elsewhere in the app.

**Fix:** Replace all `debugPrint` calls in `ProjectionController` with `_log.fine(...)` / `_log.warning(...)` / `_log.severe(...)`. Add a private logger at the top:
```dart
final _log = AppLogger.get('ProjectionController');
```

**Verify:** `flutter analyze` clean; run app and verify logging output appears in `flutter logs` / IDE console at appropriate levels.

---

### A2 — `_syncSecondaryWindowWithRetry` retries blind for 3 seconds  `MINOR`

**File:** `lib/features/projection/projection_controller.dart:506-514`

**Root cause:** The retry loop sleeps 300 ms × 10 = 3 s regardless of whether the secondary window has died. If the window is gone, this delays the UI update and wastes CPU.

**Fix:** Bail early if the window is confirmed dead:
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

**Verify:** Close the secondary window mid-sync — main window should update state within ~300 ms, not 3 s.

---

### A3 — Empty catch blocks swallow unexpected errors  `INFO`

**Files:** `projection_controller.dart:163`, `linked_songbooks_service.dart:205`, `projection_output_view.dart:204`

**Root cause:** Several `catch (_) {}` blocks silently swallow all errors. While intentional for some non-critical paths, they make production debugging impossible.

**Fix:** Add a comment explaining why the error is intentionally ignored, or route to `_log.fine('ignored: $e')`.

**Verify:** `flutter analyze` no `avoid_dynamic_calls` or `empty_catches` warnings (already clean).

---

## 3. Security (Security Expert)

### S1 — No input-length limits on song title / body  `MINOR`

**File:** `lib/data/db/songbook_db.dart:19-21` (schema) and `song_editor_view.dart`

**Root cause:** `title` is capped at 200 chars, but `body` (lyrics) has no length limit. A malicious or accidental multi-MB payload would be stored and streamed into memory on every render.

**Fix:**
1. Add `withLength(max: 1_000_000)` to `body` in `songbook_db.dart` (generous cap; typical hymn < 10 KB).
2. Bump schema version + migration.
3. Optionally truncate in `SongEditorView` before save.

**Verify:** `flutter test` green; try to save a 10 MB body — should be rejected or truncated.

---

### S2 — Linked songbook paths are user-controlled filesystem strings  `MAJOR`

**File:** `lib/data/services/linked_songbooks_service.dart:49-57`

**Root cause:** `LinkedSongbook.fileLastModified` calls `File(path).statSync()` and `fileExists` calls `File(path).existsSync()` without any path sanitization. A symlink or a path like `../../etc/passwd` would be followed. On desktop, this is low risk (user explicitly picks the file via `FilePicker`), but the path is persisted and later re-read on every sync check.

**Fix:**
1. Store only the canonical absolute path (resolve symlinks via `File(path).resolveSymbolicLinks()`).
2. Add an opt-in sandbox: only allow paths under the app storage directory or the user's home directory.
3. Validate `isSupportedFormat` before every `statSync()` call.

**Verify:** Link a symlink to `/etc/passwd`; `fileExists` should return true but `hasChangedSinceLastImport` should not throw; sync should not follow the symlink content.

---

## 4. Build, Release & Platform (Build/Release Engineer)

### B1 — macOS deployment target is 11.0; minimum is unspecified for Windows/Linux  `MINOR`

**Files:** `macos/Runner/Configs/AppInfo.xcconfig` (already 11.0), no equivalent for Windows/Linux.

**Root cause:** Windows has no declared minimum OS version; Linux AppImage `AppDir` doesn't specify a GLIBC requirement. A user on an older distro or Windows 8 would get cryptic runtime failures.

**Fix:**
1. Windows: add `MINIMUM_WINDOWS_VERSION` in `CMakeLists.txt` or `windows/runner/Runner.rc`.
2. Linux AppImage: set `X-AppImage-Build-Number` and document the GLIBC 2.29+ requirement in `docs/song_book_plus/README.md`.
3. Document all three in a `SUPPORTED_PLATFORMS.md`.

**Verify:** `flutter build macos --release` still succeeds; AppImage builds on a fresh Ubuntu 22.04 VM.

---

### B2 — Android release signing is unconfigured  `MAJOR` (deferred — awaiting product owner)

**File:** `android/app/build.gradle.kts`

**Root cause:** `signingConfigs.getByName("debug")` is used for release builds; `applicationId` is still `com.example.visual_song_book`.

**Fix:** Needs keystore + application ID from product owner (already noted in REMEDIATION_PLAN.md Phase 4c). No code change until decision is made.

---

## 5. Testing (QA Engineer)

### T1 — No test for `.vsbook` round-trip preserving `is_active`  `MAJOR`

**File:** `test/vsbook_importer_test.dart` (existing), `test/backup_repository_test.dart` (existing)

**Root cause:** The existing tests cover `modified` parsing but do not assert that soft-deleted songs (`is_active = 0`) survive an export → import cycle.

**Fix:** Add a test:
1. Create a song, soft-delete it (`isActive = false`).
2. Export `.vsbook`.
3. Import into a fresh in-memory DB.
4. Assert the song exists and `isActive == false`.

**Verify:** `flutter test` +1 pass.

---

### T2 — No test for `parseProjectionWindowArgs` edge cases  `MINOR`

**File:** `test/projection_window_args_test.dart` (existing)

**Root cause:** Existing 7 tests cover the happy path, legacy `multi_window`, and unknown args. Missing: empty string, malformed string (`'Projection Output'` with no colon), and `'Projection Output:duplicate'` (future mode).

**Fix:** Add 3 parameterized cases.

**Verify:** `flutter test` +3 pass.

---

### T3 — No integration test for projection window lifecycle  `MINOR`

**Root cause:** The secondary-window open/close/reuse flow (`ProjectionController.openProjectorWindow` + `onWindowsChanged`) is runtime-verified only.

**Fix:** Add a headless integration test using `Process.start` to launch a second engine and verify IPC handshake, or add a dedicated `test/projection_lifecycle_test.dart` that mocks `WindowController`.

**Verify:** `flutter test` green; runtime on Linux still required for end-to-end.

---

## 6. UI / UX (Frontend Expert)

### U1 — No accessibility labels on icon-only buttons  `MINOR`

**Files:** `lib/features/settings/settings_cards.dart:852-857` (unlink icon button), `projection_tab.dart` (chevron buttons, dot indicators), `set_detail.dart` (drag handles).

**Root cause:** `IconButton` and `ReorderableDragStartListener` widgets lack `tooltip` and `semanticLabel`.

**Fix:** Add `tooltip: 'Unlink songbook'`, `semanticLabel: 'Unlink ${book.name}'` to icon buttons; add `Semantics` widgets around drag handles.

**Verify:** Enable TalkBack / VoiceOver and navigate settings and set detail screens — all actions should be announced.

---

### U2 — Hard-coded color strings bypass theme  `INFO`

**File:** `lib/features/settings/settings_cards.dart:657`

**Root cause:** The About page chip uses `theme.colorScheme.surfaceContainerHigh` which is fine, but `Colors.red`, `Colors.orange`, `Colors.green` appear in `LinkedSongbooksCard` without using the theme's `colorScheme.error` / `colorScheme.tertiary`.

**Fix:** Replace `Colors.red` → `theme.colorScheme.error`, `Colors.orange` → `theme.colorScheme.tertiary`, `Colors.green` → `theme.colorScheme.primary` (or another semantic color).

**Verify:** Switch to light theme — all status colors remain legible.

---

## 7. Performance (Performance Engineer)

### P1 — Full-table `count()` on every category card render  `MINOR`

**File:** `lib/data/repositories/song_repository.dart:154-159` (already addressed in D1)

**Root cause:** Even after D1 is fixed, `getSongCountByCategory` is called for every category in the settings list. If there are 50 categories, this is 50 sequential queries.

**Fix:** Load all counts in a single query:
```dart
Future<Map<int, int>> getSongCountsByCategory() async {
  final result = await (db.selectOnly(db.songs)
    ..addColumns([db.songs.categoryId, db.songs.id.count()])
    ..where(db.songs.isActive.equals(true))
    ..groupBy([db.songs.categoryId])
  ).get();
  return {for (var row in result) row.read(db.songs.categoryId)!: row.read(db.songs.id)!};
}
```

**Verify:** Settings → Song Collections opens instantly with 50+ categories.

---

### P2 — `watchSongs()` + `watchSongsFiltered()` create separate streams  `MINOR`

**File:** `lib/data/repositories/song_repository.dart:20-25, 88-99`

**Root cause:** `SongListController._init()` subscribes to `watchSongs()` (all songs) AND the UI queries `watchSongsFiltered()` or `watchSongsByCategory()`. Every DB write triggers two independent `SELECT *` queries.

**Fix:** Collapse into a single `watchSongs()` stream and filter in Dart, or add an index on `(isActive, categoryId, songNum)` so the filtered queries are covered.

**Verify:** Insert 1000 songs; monitor SQLite query log (`sqlite3_trace`) — should see one watch query, not two.

---

## 8. Summary of Recommended Actions

| ID | Severity | Area | Effort | Action |
|---|---|---|---|---|
| D1 | MAJOR | Data | 5 min | Replace `getSongCountByCategory` with `COUNT(*)` |
| D2 | MINOR | Data | 10 min | Accept both seconds and milliseconds in `_parseModified` |
| D3 | MINOR | Data | 20 min | Add unique index on `(title, songNum)` |
| A1 | MINOR | Arch | 15 min | Replace `debugPrint` with `AppLogger` |
| A2 | MINOR | Arch | 10 min | Early-exit `_syncSecondaryWindowWithRetry` when window is null |
| A3 | INFO | Arch | 5 min | Comment empty catch blocks |
| S1 | MINOR | Security | 15 min | Cap `body` length; add migration |
| S2 | MAJOR | Security | 30 min | Canonicalize linked-songbook paths |
| B1 | MINOR | Build | 20 min | Document OS minimums |
| B2 | MAJOR | Build | — | Awaiting product owner decision |
| T1 | MAJOR | Tests | 20 min | Round-trip `is_active` preservation test |
| T2 | MINOR | Tests | 10 min | Edge-case `parseProjectionWindowArgs` tests |
| T3 | MINOR | Tests | 2 h | Projection lifecycle integration test |
| U1 | MINOR | UI/UX | 30 min | Accessibility labels on icon buttons |
| U2 | INFO | UI/UX | 10 min | Theme-consistent colors in settings |
| P1 | MINOR | Perf | 20 min | Batch category count query |
| P2 | MINOR | Perf | 30 min | Single watch stream or DB index |

**Total estimated effort:** ~6 hours of focused engineering.

**Recommended next step:** tackle the two MAJOR items first (D1, S2), then the MAJOR test gap (T1). The remaining MINOR items can be batched into a single "polish" phase.

---

*Audit completed by multi-expert review of the `8874148` baseline.*
