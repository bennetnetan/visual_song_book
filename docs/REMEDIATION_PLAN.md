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

**Web decision — requires product call.** The app's data layer is native `sqlite3`
(`songbook_db.dart:152`, `bible_db.dart`); web needs a WASM sqlite backend
(`drift_flutter`'s `driftDatabase` is the intended path — note `drift_flutter` is already a
dependency but unused). Options:
- **A. Drop web (recommended):** delete `web/`, remove the README `web/` mention,
  drop `flutter_launcher_icons.web` + `flutter_native_splash.web` config. Smallest correct
  outcome; app remains Linux/Windows/Android-first.
- **B. Invest in web:** switch DB open to `drift_flutter.driftDatabase()` with a web
  backend, bundle sqlite3 WASM, verify all `kIsWeb` guards, then scaffold a real
  `web/index.html` + valid `manifest.json`. Substantial effort.

**Google Fonts bundling (applies regardless of web decision):**
`GoogleFonts.plusJakartaSans` (~60 uses in `settings_tab.dart`, `settings_cards.dart`,
`neomorphic_widgets.dart`) and `GoogleFonts.ebGaramond` (`bible_search_widgets.dart:338,499`,
`bible_mobile_sheet.dart:47`) are runtime-fetched and fail offline / on Android release
(no INTERNET permission) / macOS (no network entitlement).
1. Add the two TTF families to `assets/fonts/` and declare them in `pubspec.yaml` fonts
   (weight 400/500/600/700 as used).
2. Replace `GoogleFonts.plusJakartaSans(...)` → `TextStyle(fontFamily: 'PlusJakartaSans', ...)`
   and `GoogleFonts.ebGaramond(...)` → `TextStyle(fontFamily: 'EBGaramond', ...)` preserving
   args (mechanical; a small helper `AppFonts` avoids repetition). Requires downloading the
   font files (user-provided or from Google Fonts).
3. Add `<uses-permission android:name="android.permission.INTERNET"/>` to the main Android
   manifest only if runtime fetching is kept (not needed once bundled).

**Verify:** `flutter build apk --release` + Linux release run offline → correct fonts, no
fallback.

### 4c. Release signing + app identity (MAJOR #14)

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

1. Rewrite `test/populate_db_test.dart`: in-memory Drift (`NativeDatabase.memory()`) + temp
   dirs via `getTemporaryDirectory()`; no `~/Documents` paths. If a dev DB seeding flow is
   still wanted, extract it to `tool/seed_dev_db.dart`.
2. Add `.github/workflows/ci.yml`: `flutter pub get`, `dart format --set-exit-if-changed`
   (optional), `flutter analyze`, `flutter test`, `flutter build linux --release`
   (job-level matrix later).

**Verify:** `flutter test` passes on a clean checkout without touching `~/Documents`;
CI runs green on the fix branch.

---

## Phase 5 — Projection: secondary-window controls + close leak (MAJOR #7 & #9)

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

1. `history_controller.dart:57-61`: replace the one-shot `getSetHistory()`/`getBibleHistory()`
   with stream-based watches (`watchSetHistory`/`watchBibleHistory` — add to repos if
   missing), matching the live songs path (`watchHistory` at line 54), so new projections
   appear without restart.
2. `history_tab.dart`: add "Clear" actions (with confirm dialog) on Songs / Sets / Bible
   sub-tabs wired to the already-existing `clearSongHistory` / `clearSetHistory` /
   `clearBibleHistory`.

**Verify:** project a set → History/Sets shows it immediately; clearing empties each tab.

---

## Phase 7 — Complete the category feature (MAJOR #11)

**Root cause:** categories can be created/assigned but `selectCategory`/`deleteCategory`
(`song_list_controller.dart:157,186`) have no UI callers; `selectedCategoryId` is never set.

**Fix:**
1. Songs tab: category filter chips / dropdown bound to `selectCategory` (drive the existing
   branches at `song_list_controller.dart:208-234`, incl. "Uncategorized only").
2. Dashboard collections: a delete action (with confirm) calling `deleteCategory`; decide
   reassignment or cascade for its songs (confirm desired behavior during implementation).

**Verify:** create collection → assign songs → filter by it → delete it.

---

## Phase 8 — Projection search load-more + `projectionMode` behavior (MAJOR #13 & #8)

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

1. Web: invest (option B) or drop (option A)? — **P4b**
2. macOS: disable sandbox (recommended) or move storage into the container? — **P4a**
3. Application ID / org for all platforms — **P4c**
4. Category deletion: reassign songs or cascade-delete them? — **P7**
5. `projectionMode` "duplicate": full mirroring or gated/deferred? — **P8**
6. License type (if any) — **P10**
7. Font files for Plus Jakarta Sans / EB Garamond (bundling) — **P4b**
