# Visual Song Book — Code Review & Improvement Plan

Scope: the `lib/` directory plus `pubspec.yaml` (no `test/` or platform folders were provided), ~28k lines of Dart across a Flutter + Riverpod + Drift desktop/mobile app for church song projection, with a bundled KJV Bible, set-building, and songbook import (.vsb/.vsbook/mdb-tools). App is on version 2.2.0, targeting Dart SDK `^3.12.1` — a genuinely current toolchain, not a stale one.

Overall impression first, so the rest of this doc reads in context: this is a **well above average** hobby/small-team codebase. Migrations are handled correctly, SQL is parameterized everywhere, subprocess calls use argument lists (not shell strings), soft-deletes and provenance tracking are thoughtful, and the file-watching/sync logic has real production-grade edge-case handling (debounce, polling fallback for cloud drives, broken-watcher recovery). The issues below are about pushing a good codebase to a *great* one, not rescuing a bad one.

Checkboxes are there so you can track progress directly in this file.

---

## 1. Confirmed bugs (fix these first)

- [ ] **`SongRepository.getSongCountsByCategory()` returns wrong data.** In `lib/data/repositories/song_repository.dart`:
  ```dart
  return {
    for (var row in result)
      row.read(db.songs.categoryId)!: row.read(db.songs.id)!,
  };
  ```
  The query aggregates with `db.songs.id.count()`, but the map is built by reading `db.songs.id` (the raw column), not the count expression. Under `GROUP BY`, that raw read returns whatever id SQLite happens to associate with the group — not the count. Anywhere this map feeds a "songs per category" badge or chart, the number shown is not the count. Fix: `row.read(db.songs.id.count())!`.

- [ ] **Silent empty catch blocks swallow real failures.**
  - `settings_tab.dart:884` and `:900` — `catch (_) {}`
  - `vsbook_importer.dart:767` — `catch (_) { ... }`
  Worth opening each of these specifically: if they're guarding a genuinely optional/best-effort step, add a one-line log via `AppLogger` so failures are at least visible in diagnostics; if they can hide a real import/settings failure from the user, surface it.

- [ ] **`_db.updateLinkedSongbookByPath` call in `linked_songbooks_watcher.dart` builds a companion in an odd way:**
  ```dart
  const LinkedSongbookRegistryCompanion(
    lastImportedAt: Value.absent(),
  ).copyWith(lastImportedAt: Value(DateTime.now())),
  ```
  This works, but constructing a companion with an absent value just to immediately override it via `copyWith` is confusing and easy to break during a refactor. Simplify to `LinkedSongbookRegistryCompanion(lastImportedAt: Value(DateTime.now()))`.

---

## 2. Architecture & state management

- [ ] **Mixed Riverpod styles, on an otherwise up-to-date Riverpod.** `pubspec.yaml` pins `flutter_riverpod: ^3.4.2`, which is current (3.4.3 is the latest release as of writing) — so this isn't a version-currency problem. It's a style/API-surface one: the app uses classic `Provider`/`StateProvider`/`StreamProvider`/`StateNotifier` (18 usages) throughout, plus an explicit `import 'package:flutter_riverpod/legacy.dart'` in `app_providers.dart`. In Riverpod 3.x, that `legacy` import exists specifically to quarantine the old `StateProvider`/`StateNotifierProvider` APIs the package is steering people away from in favor of `Notifier`/`AsyncNotifier` (optionally via `@riverpod` codegen). None of the newer codegen annotations are used anywhere. This isn't broken, but every provider here is hand-wired and boilerplate-heavy, and the explicit `legacy` import is Riverpod telling you where the deprecation pressure will eventually land. If you plan to keep evolving this app, migrating incrementally to `riverpod_generator` (`@riverpod` functions/classes) will cut boilerplate and give you compile-time-checked provider dependencies — no rush, but worth doing before `legacy` becomes a bigger liability than it is today.

- [ ] **Duplicated filter-building logic in `SongRepository`.** `searchSongs`, `watchSongsByCategory`, and `watchSongsFiltered` each re-implement the same `sourceMode`/`sourcePath` `Expression<bool>` construction almost verbatim (3x). Extract a private helper:
  ```dart
  Expression<bool> _sourceFilter({String? sourcePath, SourceMode? sourceMode}) { ... }
  ```
  and `&`-combine it at each call site. Cuts ~40 lines and removes a class of "fixed it in one place, forgot the other two" bugs.

- [ ] **God-widgets / oversized build methods.** A few files have grown past the point where a single person can hold the whole widget in their head:
  - `projection_tab.dart` — 2,161 lines, 16 classes in one file; `_LivePreviewPanel.build()` alone spans ~426 lines (681–1107).
  - `settings_cards.dart` — 1,365 lines, 15 classes.
  - `set_detail.dart` — 1,131 lines in a single `ConsumerStatefulWidget`.
  - `projection_output_view.dart` — 1,203 lines.
  None of these are "wrong," but at this size, hot-reload gets slower, diffs get noisy, and it's easy to introduce regressions in unrelated UI when touching one section. Recommend splitting by responsibility, e.g. `projection_tab.dart` → `projection_tab.dart` (shell) + `live_preview_panel.dart` + `slide_list.dart` + `set_navigator_panel.dart` + `fullscreen_search_page.dart`, each in `features/projection/widgets/`.

- [ ] **No dedicated domain/service layer between controllers and repositories for cross-cutting rules.** E.g. dedup logic (`deduplicateSongs`) lives inside `vsb_importer.dart` and is reused by `mdb_tools_importer.dart` via import — fine — but as more importers are added, consider a shared `import/` service module so every importer (existing or future) gets dedup, provenance tagging, and category-mapping "for free" instead of re-implementing per importer.

---

## 3. Error handling, observability & production readiness

- [ ] **No crash/error reporting integration.** `AppLogger` routes everything through `dart:developer` (`developer.log`), which is only visible while attached to a debugger/DevTools. In `kReleaseMode`, only `WARNING`+ are even logged, and none of it leaves the device. For a desktop app you ship to churches (who will not be running `flutter logs` when something breaks), you currently have **no way to learn about crashes in the wild**. Recommend either:
  - A lightweight opt-in local crash log (write `SEVERE` records to a rotating file under app storage, surfaced in Settings → "Send diagnostics" / "Copy last error log" for support requests), and/or
  - A crash reporter (Sentry has a solid Flutter SDK) gated behind an explicit, visible opt-in toggle in Settings given the church-data-privacy context.

- [ ] **Inconsistent async error surfacing.** Most repository/service methods either throw or return an `ImportResult`/similar result object — this pattern is good — but it's not applied uniformly. Worth an explicit convention doc (even a short section at the top of `app_logger.dart` or a new `ERRORS.md`): "repositories throw; importers/services return typed Result objects; UI never shows a raw exception string to the user."

- [ ] **User-facing error strings leak internals.** `mdb_tools_importer.dart`: `ImportResult.failure('Error during import: $e')` puts the raw Dart exception (which can include file paths, stack info, or driver-specific text) directly into a string a non-technical user will see in a dialog. Fine for a log; for the UI, prefer a friendly message plus a "details" expander that shows `$e`.

---

## 4. Data layer specifics

- [ ] **`Songs.body` is capped at 1 MB in the schema comment** ("Capped at 1 MB to prevent memory exhaustion") but the migration note at `schemaVersion` step `from < 8` says *"body length cap is enforced at the Dart layer for existing rows; CHECK constraint is applied only on new database creation."* That means databases created before v8 have no DB-level guarantee, only whatever Dart-layer validation exists at insert time. Worth confirming (and if missing, adding) that every insert/update path — including all four importers — actually enforces this cap before writing, since the DB itself won't catch it for those older schemas.

- [ ] **`History` pruning does two round-trips.** `addToHistory()` inserts, then does a `SELECT ... LIMIT 100 OFFSET 50` and deletes anything beyond 50. This is correct but does more work than necessary; a single `DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY accessed_at DESC LIMIT 50)` (or a Drift equivalent) would be one round trip and one transaction. Minor, but this runs on every song play.

- [ ] **Bible full-text search is `LIKE '%term%'` over ~31k verses**, explicitly pushed to a background isolate via `compute()` to avoid janking the UI (good mitigation) — but a `%prefix%` `LIKE` can't use an index, so it's a full table scan every keystroke-driven search. At 31k rows this is probably fine today, but if search-as-you-type debouncing isn't already tight, or if you ever expand to multiple translations (multiplying row count), consider SQLite FTS5 for the `verses` table. Worth checking now while it's a nice-to-have rather than later as a fire drill.

- [ ] **No apparent connection pooling concern, but two separate DB engines (Drift/NativeDatabase for `songs_db.sqlite`, raw `sqlite3` for the Bible DB) are both opened per app instance** including for the secondary projection window process (`desktop_multi_window` spawns a fresh engine). Confirm the projection window doesn't unnecessarily reopen/duplicate the Bible DB copy step — `ensureInitialized()` guards against re-copying assets, but each new engine still pays the "check for `cross_references` table" query cost. Low priority, just worth a look given how deliberate the rest of the startup sequencing is.

---

## 5. UI/UX and cross-cutting concerns

- [ ] **No localization (`intl`) in the codebase.** All ~213 `Text('...')` string literals are hardcoded English. If this app is only ever going to be English-language for its target churches, that's a legitimate product decision — but if there's any chance of serving Spanish-, Portuguese-, French-, or Korean-speaking congregations (common for song-projection software), retrofitting `intl`/ARB files after 200+ strings are already scattered across 60 files is a much bigger job than doing it now via `flutter gen-l10n`.

- [ ] **Minimal accessibility support.** Only 3 explicit `Semantics(...)` usages across the entire UI layer. Flutter's Material widgets give you a baseline for free, but a full-screen projection app used in a live church service — where the operator may be under time pressure, using assistive tech, or working the booth from a screen reader — benefits a lot from explicit semantic labels on icon-only buttons (search, play/project, add-to-set), and from testing with TalkBack/VoiceOver/Narrator at least once.

- [ ] **Heuristic scan found several `await` calls followed by `context` usage without a clear `mounted` guard nearby** (4 hits, concentrated in a couple of files — worth a manual pass over `settings_tab.dart` and `set_detail.dart` specifically, since those have the most async-then-context flows: showing snackbars, dialogs, or navigation after an `await`). This is a classic Flutter footgun — using `BuildContext` after an `await` where the widget may have been disposed mid-flight causes exceptions in production that are hard to reproduce locally. Enable the `use_build_context_synchronously` lint (it's on by default in `flutter_lints`/`very_good_analysis`) if it isn't already, and let the analyzer find every instance rather than relying on grep.

- [ ] **~30 hardcoded `Color(0x...)`/`Colors.*` literals scattered across widget files** (`song_list_item.dart`, `editor_cards.dart`, `settings_tab.dart`, `settings_cards.dart`, `set_list.dart`, `set_detail.dart`) alongside what looks like a proper `app_theme.dart`. Worth an audit to see which of these should be pulling from `Theme.of(context).colorScheme` instead — inconsistent light/dark mode behavior is the most common symptom when a few widgets bypass the theme.

---

## 6. Testing & verification

- [ ] **No `test/` directory was included in this archive**, so it's impossible to know from this review alone what unit/widget test coverage currently exists. Given the codebase quality elsewhere, there may already be tests that simply weren't in the zip — but if there genuinely are none yet, the highest-leverage places to start are:
  1. `SongRepository` / `SetRepository` — pure Drift logic, cheap to test against `AppDatabase.forTesting()` (already exists in the codebase — good sign this pattern is anticipated).
  2. The importers (`mdb_tools_importer.dart`, `vsb_importer.dart`, `vsbook_importer.dart`, `bundled_json_importer.dart`) — these have complex parsing/dedup logic that's exactly the kind of thing that silently regresses.
  3. `verse_parser.dart` and `bible_search_utils.dart` — small, pure, and load-bearing for a core feature.
  4. `getSongCountsByCategory()` specifically — a test would have caught the bug in section 1 immediately.

- [ ] **`AppDatabase.forTesting()` exists but its usage outside this zip is unknown.** If there isn't already a CI job running `flutter test` + `flutter analyze` on every push, that's the single highest-ROI process change available — it would have caught the count-aggregation bug and would catch future `mounted`/lint regressions automatically.

---

## 7. Dependencies (from `pubspec.yaml`)

Good news first: nothing here is stale. `flutter_riverpod ^3.4.2`, `flutter_lints ^6.0.0`, `drift ^2.31.0`, `go_router ^17.4.0`, and `file_picker ^11.0.3` are all current major/minor lines, and the `environment: sdk: ^3.12.1` constraint targets a recent Dart SDK rather than something years old. A few things worth flagging beyond "is it current":

- [ ] **`desktop_multi_window: ^0.3.0` is a structural dependency, not an incidental one — and it's a small, single-maintainer package.** The entire secondary-window projection architecture (`ProjectionOutputView`, the Win32 fullscreen placement helper, IPC between windows) is built on top of this plugin. It only ships 6 releases across roughly 4 years of history and modest download numbers on pub.dev. That's not a reason to drop it — there's no obviously more mature alternative for Flutter multi-window desktop support — but it is a concentration-of-risk point: if it stops being maintained or ships a breaking native-side change, a meaningful chunk of this app's core value proposition (drive a second-screen projection output) is affected. Consider vendoring/forking it internally (or at minimum pinning tightly and tracking its issue tracker) rather than treating it as a routine dependency you'd `flutter pub upgrade --major-versions` without checking the changelog line by line.
- [ ] **`fvp ^0.37.3`** is one minor version behind the latest (`0.38.0` at time of writing) — trivial, will resolve automatically on the next `pub upgrade`, not worth a special action beyond normal maintenance.
- [ ] **No `analysis_options.yaml` was included**, so it's unclear which specific lint set is actually active beyond the `flutter_lints: ^6.0.0` dev dependency declaration. `flutter_lints` 6.x does include `use_build_context_synchronously` by default, which is good — but worth confirming the file hasn't disabled it or other useful rules, since Section 5's `context`-after-`await` findings would be caught automatically if that lint is live and its warnings are actually being addressed rather than suppressed.
- [ ] **No `test/` directory or dependency issues to report there** — `flutter_test` is present as a dev dependency, consistent with `AppDatabase.forTesting()` existing in the code (Section 6), so the scaffolding for tests is already in place; it's just a question of whether tests were written against it.

## 8. Smaller polish items

- [ ] `win32_window_helper.dart` (500 lines) is Windows-specific FFI/Win32 code for multi-monitor fullscreen placement — inherently fragile across Windows versions/multi-DPI setups. Worth a comment block at the top listing which Windows versions/monitor configurations have actually been tested, so future contributors know the known-good envelope versus untested territory.
- [ ] `_parseMdbDateTime` in `mdb_tools_importer.dart` assumes US-style `M/D/YY` dates from the legacy MDB export; if any source files come from a different locale's Access install, this will silently misparse day/month. A comment noting the assumption (or a fallback heuristic) would save a future debugging session.
- [ ] Consider extracting the `deduplicateSongs` "kept ${dedupedSongs.length} unique entries" log-message pattern and the two-pass "snapshot before / compare after" diffing logic in `mdb_tools_importer.dart` into a shared helper, since `vsbook_importer.dart` (771 lines) almost certainly needs the same comparison for its own import-summary UI.

---

## Suggested priority order

1. Fix the `getSongCountsByCategory()` bug and the two silent `catch (_) {}` blocks (Section 1) — small, safe, real correctness wins.
2. Add the `use_build_context_synchronously` lint and clear its findings (Section 5).
3. Stand up even a minimal test suite around repositories + importers, and wire it into CI if it isn't already (Section 6) — this is what prevents regressions on everything else on this list.
4. Add a crash/error-reporting path for release builds (Section 3) — you're currently flying blind on real-world failures.
5. Split the largest widget files (Section 2) opportunistically, as you touch them — not worth a dedicated refactor sprint on its own.
6. Localization and accessibility (Section 5) — decide deliberately whether these are in scope for your user base, then act early rather than retrofitting later.

---

*Note: this review is based on the `lib/` source plus `pubspec.yaml`. A full picture would still benefit from `analysis_options.yaml` (to see which lints are actually enforced) and the `test/` directory. Happy to go deeper on any single section above if you share those or point me at specific files to focus on.*
