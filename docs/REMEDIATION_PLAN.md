# Visual Song Book — Audit Remediation Plan

Source: multi-expert audit (data layer, projection, UI, build/release), Aug 2026.
Scope: resolve every finding ranked critical/major/minor. Phases are ordered by risk
and dependency. Each item lists files, approach, and how to verify.

Gate for every phase: run `flutter analyze` and `flutter test` and keep them green.
Work on a dedicated branch; commit per phase.

---

## Phase 0 — Baseline

- Capture pre-fix state:
  ```bash
  flutter analyze --no-pub   # record current info count
  flutter test --no-pub      # record current pass/fail
  ```
- Create branch `fix/audit-remediation`.
- Fix the broken `web/manifest.json` 0-byte file is tracked in git — see P4b for decision.

---

## Phase 1 — Data layer: `.vsbook` import is broken (CRITICAL #1)

**Root cause:** Drift stores `DateTime` as INTEGER unix-seconds, but `vsbook_importer.dart`
casts `row['modified'] as String?` (line 142, restore path) and
`DateTime.tryParse(row['modified'] as String)` (line 320, linked reimport path). Any song
with a timestamp throws `type 'int' is not a subtype of type 'String?'`. Every seeded song
has `modified: DateTime.now()` (`bundled_json_importer.dart:74`).

**Fix:**
1. Add a shared helper (private to the file, or in `core/utils/`):
   ```dart
   DateTime? _parseModified(Object? value) {
     if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
     if (value is String) return DateTime.tryParse(value);
     return null;
   }
   ```
2. Use it at line 142-153 and line 318-322 (replace both `as String` casts).
3. Preserve `is_active` on restore: add `is_active` to both SELECTs
   (lines 130, 302) and pass
   `isActive: Value((row['is_active'] as int?) == 1)` (Drift bool → 0/1).
4. Confirm no other importer casts `modified` (VSB and bundled-JSON importers).

**Verify:** round-trip test — seed songs → export `.vsbook` → restore → songs present,
soft-deleted songs stay inactive. Manual: Settings → Import `.vsbook`, and linked-songbook
reimport via `reimportSource`.

---

## Phase 2 — Bible "Continue Reading" is dead (CRITICAL #2)

**Root cause:** `lastReadBookId/Chapter/Verse` exist in `bible_state.dart:36-38` and are read
by `bible_tab.dart:191-204` / `bible_reading_widgets.dart`, but nothing ever writes them.

**Fix (`lib/features/bible/bible_controller.dart`):**
1. Add prefs keys `bible_last_read_book`, `bible_last_read_chapter`, `bible_last_read_verse`.
2. Add a private `_persistLastRead()` called from `selectChapter` (and `navigateToVerse`):
   set state `lastRead*` and write the 3 prefs keys.
3. Hydrate in `_init()` (lines 26-48): read the 3 keys; if a saved reading exists, navigate
   there instead of the current hardcoded Genesis 1:1 (line 44-47). Genesis 1:1 stays the
   fallback for first launch.

**Verify:** read Genesis 2:5 → restart app → empty-state "Continue reading" card shows
"Genesis 2:5" and resumes on tap.

---

## Phase 3 — Projection: main-window `/projection` misclassification (CRITICAL #3)

**Root cause:** `projection_output_view.dart:69-100` runs `_setupSecondaryWindowChannel()` for
every desktop window. In the main window (route `/projection`, reached on small screens /
web / when `openProjectorWindow()` returns false) this blanks the screen, fullscreens the
main window, and clobbers the main window's IPC handler.

**Fix:**
1. Wrap the desktop block (lines 69-100) with the existing gate used everywhere else:
   ```dart
   if (!kIsWeb && ref.read(isProjectionWindowProvider) &&
       (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) { ... }
   ```
   This includes `_setupSecondaryWindowChannel()`, the early Win32 borderless call
   (lines 77-84), and the focus re-assert listener (lines 89-99).
2. With the gate in place, `_isSecondaryWindow` stays `false` in the main window, so
   rendering falls back to controller state and `setWindowMethodHandler` is never called
   (main handler survives).

**Verify:** on Linux desktop, set a small window size and trigger projection → main window
stays in place, slides render, no fullscreen. On Windows, secondary-window keyboard/swipe
navigation still works after visiting the route.

---

## Phase 4 — Platform & build

### 4a. macOS sandbox breaks everything (CRITICAL #4)

**Root cause:** `macos/Runner/Release.entitlements` and `DebugProfile.entitlements` enable
`com.apple.security.app-sandbox` but omit `files.user-selected.read-write` and
`network.client`; storage at `~/.visual_song_book` (`app_storage.dart:17-23`) is outside the
sandbox container.

**Fix (recommended: disable sandbox):**
1. Both entitlements files: set `com.apple.security.app-sandbox` to `false` (or remove the
   key). The app is a desktop-first offline tool; sandboxing provides little value here.
2. Add `com.apple.security.network.client` = `true` to both (for Google Fonts until P4b
   bundles them) and `com.apple.security.files.user-selected.read-write` = `true`
   (file_picker import/export).
3. Remove the unused `com.apple.security.network.server` grant in DebugProfile.
4. Alternative (keep sandbox): relocate storage to the container via
   `getApplicationSupportDirectory()` on macOS + add the two entitlements above. Higher risk;
   only pursue if distribution requires sandboxing.

**Verify:** `flutter build macos --release`, run, import/export a `.vsbook`, verify DBs are
created and fonts load.

### 4b. Web platform + runtime Google Fonts (CRITICAL #5 & #6)

**Status:** ✅ Google Fonts bundling done (commit `b60aba4`). ⏸️ Web platform **deferred**
(product decision, 2026-08-04): web is not scaffolded (`flutter create --platforms web` never run;
`web/index.html` missing, `manifest.json` 0-byte), and a real port spans 18 `dart:io` files
(importers, backups, projection, `app_storage.dart`), a `bible_db.dart` rewrite off raw `sqlite3`
FFI, gating desktop-only features (secondary-window projection, linked-file import, backups),
plus `sqlite3.wasm`/`drift_worker.js` assets and OPFS/IndexedDB persistence — all unverifiable in
a browser on the Linux host. The `drift_flutter` dependency stays for a future web effort.

**Web decision — requires product call.** The app's data layer is native `sqlite3`
(`songbook_db.dart:152`, `bible_db.dart`); web needs a WASM sqlite backend
(`drift_flutter`'s `driftDatabase` is the intended path — note `drift_flutter` is already a
dependency but unused). Options:
- **A. Drop web:** delete `web/`, remove the README `web/` mention, drop
  `flutter_launcher_icons.web` + `flutter_native_splash.web` config. Smallest correct outcome.
- **B. Invest in web (deferred):** switch DB open to `drift_flutter.driftDatabase()` with a web
  backend, bundle sqlite3 WASM, verify all `kIsWeb` guards, then scaffold a real
  `web/index.html` + valid `manifest.json`. Substantial effort.

**Google Fonts bundling — DONE (commit `b60aba4`):**
`GoogleFonts.plusJakartaSans` (40 uses in `settings_tab.dart`, `settings_cards.dart`,
`neomorphic_widgets.dart`) and `GoogleFonts.ebGaramond` (5 uses in `bible_search_widgets.dart`,
`bible_mobile_sheet.dart`) were runtime-fetched and fail offline / on Android release
(no INTERNET permission) / macOS (no network entitlement).
1. ✅ Downloaded static TTFs (byte-exact vs google_fonts' expected SHA-256 hashes) for every
   weight/style used: `PlusJakartaSans-{Regular,Italic,Medium,SemiBold,Bold}.ttf` and
   `EBGaramond-{Regular,Medium,Bold}.ttf` → `assets/fonts/`.
2. ✅ Declared them in `pubspec.yaml` fonts. Because files are named exactly
   `Family-Variant.ttf`, google_fonts auto-loads them from the asset manifest
   (`_findFamilyWithVariantAssetPath`) — no call-site replacement needed.
3. ✅ Set `GoogleFonts.config.allowRuntimeFetching = false` in `main()` — any used-but-unbundled
   variant now throws loudly instead of silently hitting the network.
4. (Not needed once fonts are bundled.)

**Verify:** `flutter analyze` clean of new issues; `flutter test` 30 pass; `flutter build bundle`
shows all 8 new TTFs in `AssetManifest.bin`.

### 4c. Release signing + app identity (MAJOR #14)

**Status:** ⏸️ DEFERRED (product decision, 2026-08-04) — needs the application ID / org from
the product owner; nothing can ship in this phase without it.

1. Android: replace `signingConfigs.getByName("debug")` (`build.gradle.kts:32`) with a real
   release keystore (env vars / `keystore.properties`); bump `applicationId` and
   `android:label` away from `com.example.visual_song_book`.
2. Update bundle IDs/names: `macos/Runner/Configs/AppInfo.xcconfig`,
   `ios/Runner.xcodeproj/project.pbxproj` (3 `PRODUCT_BUNDLE_IDENTIFIER`),
   `windows/runner/Runner.rc` (CompanyName/ProductName/Copyright),
   `linux/CMakeLists.txt` (`APPLICATION_ID`).
3. **Needs user input:** desired application ID / organization (e.g. `com.benjanetan.visualsongbook`).

**Verify:** `keytool -printcert` on built APK shows release key; bundle IDs unique per
platform.

### 4d. Non-hermetic test + CI (MAJOR #15 & #16)

**Status:** ✅ DONE (commit `8493856`).

1. ✅ Rewrote `test/populate_db_test.dart`: in-memory Drift (`AppDatabase.forTesting()` →
   `NativeDatabase.memory()`), imports the bundled `.vsb` assets directly; no `~/Documents`
   writes. A dev seeding flow already exists as `tool/seed_database.dart` (raw sqlite3 +
   `mdb-export`).
2. ✅ Added `.github/workflows/ci.yml`: `flutter pub get`, `dart format --set-exit-if-changed`
   (non-blocking for now), `flutter analyze`, `flutter test` (installs `mdbtools`), and
   `flutter build linux --release`.

**Verify:** `flutter test` passes on a clean checkout without touching `~/Documents`;
CI runs green on the fix branch.

> Note: an old run of `populate_db_test.dart` left a stray `~/Documents/songs_db.sqlite`
> on the dev machine (safe to delete; the app itself stores under `~/.visual_song_book`).

---

## Phase 5 — Projection: secondary-window controls + close leak (MAJOR #7 & #9)

**Status:** ✅ DONE (commits `e923383` [5b], `a2bfe75` [5a]). Runtime verify still pending on a
Linux/Windows box (open projector window → chevrons/dots render and navigate; open/close 5× →
single hidden engine).

### 5a. In-window controls are dead in the secondary engine

**Root cause:** the secondary engine never receives the slide list (`state.slides == []`),
so chevrons (`projection_output_view.dart:458-563`) and dot indicator (`:598-618`) never
render.

**Fix:** extend the `update_slide` IPC payload (currently `{text,label,fontSize}`) with
`slideLabels` (list of slide labels) and `currentIndex`. In `projection_output_view.dart`
maintain a local `List<String> _slideLabels` + `int _localIndex` (updated in the
`update_slide` handler at lines 121-141); render chevrons/dots from these when
`_isSecondaryWindow` (they already route navigation back through `navigate_slide` IPC).
Main window keeps using controller state.

**Verify:** open projector window on Linux → in-window chevrons and `n/ total` dots render;
clicking navigates both windows in sync.

### 5b. Close leaks a hidden engine

**Status:** ✅ DONE (commit `e923383`).

**Root cause:** `close_secondary_window` handler hides the window then nulls
`_secondaryWindow` (`projection_controller.dart:503-515`); the hidden engine survives and the
next open creates a fresh one. `desktop_multi_window` has no `close()`, only `hide()`.

**Fix:** keep the reference after `hide()` (remove `_secondaryWindow = null;` at line 513) so
`openProjectorWindow()`'s existing "show existing hidden window" path (lines 387-398) reuses
it. Native X-close is already handled reactively by `onWindowsChanged` (lines 523-534), which
nullyfies stale refs. Optionally register the currently-dead `onWindowClose()`.

**Verify:** open/close projector 5× → `ps`/task manager shows a single hidden engine, not 5.

---

## Phase 6 — History: live refresh + clear affordances (MAJOR #10 & #12)

**Status:** ✅ DONE.

1. `history_controller.dart:57-61`: replace the one-shot `getSetHistory()`/`getBibleHistory()`
   with stream-based watches (`watchSetHistory`/`watchBibleHistory` — add to repos if
   missing), matching the live songs path (`watchHistory` at line 54), so new projections
   appear without restart.
2. `history_tab.dart`: add "Clear" actions (with confirm dialog) on Songs / Sets / Bible
   sub-tabs wired to the already-existing `clearSongHistory` / `clearSetHistory` /
   `clearBibleHistory`.

**Verify:** project a set → History/Sets shows it immediately; clearing empties each tab.

**Done:** `watchSetHistory`/`watchBibleHistory` added to `set_repository.dart`; controller
now subscribes streams for all four sources (songs, sets, bible, bookmarks) and the redundant
manual `copyWith` resets in the clear methods were dropped (streams now drive the refresh);
`history_tab.dart` gained a contextual AppBar "Clear history" action (delete icon) on the
Songs/Sets/Bible tabs (shown only when the list is non-empty) behind a confirm dialog wired to
`clearSongHistory`/`clearSetHistory`/`clearBibleHistory`. New `test/history_controller_test.dart`
(2 tests: live refresh + clear for sets/bible; new projections appear without manual refresh).
`flutter analyze` baseline unchanged (18), `flutter test` 32 pass.

---

## Phase 7 — Complete the category feature (MAJOR #11)

**Status:** ✅ DONE.

**Root cause:** categories can be created/assigned but `selectCategory`/`deleteCategory`
(`song_list_controller.dart:157,186`) have no UI callers; `selectedCategoryId` is never set.

**Fix:**
1. Songs tab: category filter chips / dropdown bound to `selectCategory` (drive the existing
   branches at `song_list_controller.dart:208-234`, incl. "Uncategorized only").
2. Dashboard collections: a delete action (with confirm) calling `deleteCategory`; decide
   reassignment or cascade for its songs (confirm desired behavior during implementation).

**Verify:** create collection → assign songs → filter by it → delete it.

**Decided:** deleting a collection reassigns its songs to Uncategorized (songs kept). ✅

**Done:** Songs tab AppBar gained a "Filter by Collection" dropdown (checked items:
All Collections / Uncategorized / each category) wired to `selectCategory`; Settings →
Library gained a "Song Collections" card listing categories with song counts and a delete
button (confirm dialog) calling `deleteCategory`. `deleteCategory` in `song_repository.dart`
now sets `categoryId = null` on its songs instead of hard-deleting them; the controller reset
bug (`copyWith(selectedCategoryId: null)` was a no-op) fixed by calling `selectCategory(-2)`.
New `test/song_list_controller_test.dart` (2 tests). Analyze baseline unchanged (18),
`flutter test` 34 pass.

---

## Phase 8 — Projection search load-more + `projectionMode` behavior (MAJOR #13 & #8)

**Status:** ✅ DONE.

1. `projection_tab.dart`: in the Bible results list, render a "Load more" button when
   `searchState.bibleResults.length < searchState.totalBibleCount`, calling the existing
   `loadMoreBible` (`projection_search_provider.dart:401`).
2. `projectionMode` (`single` / `duplicate` / `extended`) is stored but never read. Make it
   behavioral:
   - `extended` (default): current behavior — place on second display + fullscreen.
   - `single`: open a normal decorated window on the primary display, no auto-move.
   - `duplicate`: project the same output on a second mirrored window (second window
     receiving the same `update_slide`). Full mirroring is the most complex piece; if too
     large, implement `single` vs `extended` first and gate `duplicate` with a
     "coming soon" note rather than a dead option.

**Verify:** switching the setting in Appearance → Projection changes window placement;
broad search query shows a working "Load more".

**Decided:** implement `single` vs `extended`; gate `duplicate` as "coming soon". ✅

**Done:** "Load more results" button appended to the Bible result list when
`bibleResults.length < totalBibleCount`, wired to `loadMoreBible` (spinner while loading).
`projectionMode` is now behavioral: the mode is passed to the secondary engine via the window
arguments (`Projection Output:<mode>`), parsed in `main.dart` and exposed through a new
`projectionWindowModeProvider`. The secondary window only auto-fullscreens / strips
decorations in `extended` mode; `_placeOnSecondScreenAndFullscreen` is skipped in `single`
mode (normal decorated window on the primary display). Unsupported/legacy `duplicate` values
fall back to `extended` on load, and the settings + onboarding selectors reject `duplicate`
with a "coming soon" snackbar. New `test/projection_search_test.dart` (2 tests). Analyze
baseline unchanged (18), `flutter test` 36 pass. Runtime verify (window placement) pending a
Linux/Windows desktop box.

---

## Phase 9 — Hygiene: dead code, deps, minor bugs

**Dead code removal (verify zero references before deleting):**
- `ProjectionController.syncCurrentSlide()` (`projection_controller.dart:540`).
- `_fadeController` + its `forward()`/dispose (real transitions live in `VerseText`'s
  `AnimatedSwitcher`).
- `Win32WindowHelper.getActiveWindowHandle()` / `fullscreenWindow()` (`win32_window_helper.dart`).
- `appFontSizeProvider` + `AppFontSizeNotifier` (`appearance_provider.dart`) — no consumers.
- `lib/core/widgets/neomorphic_widgets.dart` (~200 lines, zero external use) — unless it's
  slated to become a design system.
- `SongBooks` table (`songbook_db.dart:40-49`): drop requires a Drift `schemaVersion` bump +
  migration + regenerate (`build_runner`). Do last and add a migration test; alternatively
  keep the table and document it as reserved.
- `activate/deactivateSongsBySource` + `getDeactivatedSongs` (`song_repository.dart:137-157`)
  unless a "restore deactivated songs" screen is added (see P7).
- Migrate `sets_controller.dart` off legacy `DebugLogger`; remove the file.

**Minor behavior fixes:**
- Auto-chorus toggle pollutes history: `setAutoInsertChorus` re-projects via `setSong`
  which calls `addToHistory` (`projection_controller.dart:177`). Refactor so the re-project
  skips history.
- `_advanceChapter` never records Bible history → call `recordBibleProjection`.
- `projectSongSet` doesn't set `contentTitle` (header falls back to "V1") and writes no
  per-song history → set `contentTitle` to set name; record set + member songs.
- `viewOnSubmitted` always projects `songs.first` ignoring keyboard highlight
  (`projection_tab.dart:1393-1405`) → use `_selectedIndex`.
- Font-size cap parity: steppers cap at 96, pinch zoom allows 160 → unify to one max.
- Pinch zoom writes SharedPreferences per gesture tick → debounce/flush on gesture end.

**Unused dependencies (`pubspec.yaml`):** remove `cupertino_icons`, `riverpod_annotation`,
`drift_flutter` (unless P4b option B adopted), `screen_retriever`, `riverpod_generator`
(keep `riverpod_generator`/`build_runner` only if codegen is reintroduced).

**Verify:** `flutter analyze` clean, `flutter test` green, app smoke-tested on Linux.

---

## Phase 10 — Docs, scripts, release metadata

1. Consolidate AppImage tooling: make the documented `scripts/package_appimage.sh` the single
   entry point (or document root `build_appimage.sh`), remove the hardcoded
   `/home/benjanetan/Code/flutter` path, fix the non-existent
   `linux/runner/resources/my_application.png` reference, align output name/location. Update
   README build section accordingly.
2. `docs/song_book_plus/README.md`: remove false `riverpod_annotation` / `drift_flutter`
   claims, sync changelog to v1.7.1 and feature list to reality.
3. Versioning: adopt `--build-number`/`--build-name` in build scripts so Android
   versionCode/iOS CFBundleVersion don't stay at 1; add a root `CHANGELOG.md`; add a `LICENSE`
   (user decision on license type); remove tracked `temp_fonts/Inter.zip`.
4. `analysis_options.yaml`: replace the stock template with explicit lint rules
   (`flutter_lints` current, optional `recommended` set), fix anything it surfaces.
5. macOS deployment target (`project.pbxproj:474/556/606`) 10.15 → 11.0 (optional).

**Verify:** fresh AppImage build succeeds; `flutter analyze` clean; version/CHANGELOG consistent.

---

## Phase 11 — Test coverage for fixed areas

Prioritize regression tests for the criticals:
- `.vsbook` round-trip (modified int/string parsing, `is_active` preservation).
- Bible `lastRead*` persistence/hydration.
- Projection output-view window-classification gate (unit-test the gate decision).
- History live-refresh (stream-based reads).
- Category filter/delete controller paths.
- Hermetic DB seeding.

---

## Decisions needed from the product owner

1. Web: invest (option B) or drop (option A)? — **P4b** ✅ DECIDED 2026-08-04: defer web
   (neither drop nor invest now); keep `drift_flutter` dep for a future effort.
2. macOS: disable sandbox (recommended) or move storage into the container? — **P4a** ✅ DECIDED
   (disable sandbox, commit `fdbe94d`)
3. Application ID / org for all platforms — **P4c** ⏸️ DEFERRED 2026-08-04 (awaiting product owner)
4. Category deletion: reassign songs or cascade-delete them? — **P7** ✅ DECIDED (reassign to
   Uncategorized, commit in Phase 7)
5. `projectionMode` "duplicate": full mirroring or gated/deferred? — **P8** ✅ DECIDED
   (implement single vs extended, gate duplicate as "coming soon")
6. License type (if any) — **P10**
7. Font files for Plus Jakarta Sans / EB Garamond (bundling) — **P4b** ✅ DONE (commit `b60aba4`)
