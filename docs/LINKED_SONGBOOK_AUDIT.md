# Linked Songbook Separation — Case Audit

Date: 2026-08-04
Scope: How the app currently handles multiple song sources (bundled, linked, imported, manual) and where separation breaks down.

---

## Executive Summary

The app currently loads **all song sources into a single SQLite database** with no runtime isolation. A user who chooses “Link Songbook Files” on first launch still gets the pre-installed songbooks seeded automatically. There is no way to view “only linked songs” or “only bundled songs” without manually filtering by source path. If a linked file becomes unavailable, the last-imported snapshot remains in the database with no dedicated cache or fallback.

---

## Current Flow (Cold Start)

```
main.dart
  ├── appSeedProvider (SeedingService.seedIfNeeded)
  │     ├── Checks SharedPreferences: bundled_seed_version
  │     ├── If not seeded → imports assets/songbooks/Full Song Book.json
  │     └── If not seeded → imports assets/songbooks/Injili Song Book.json
  │
  └── linkedSongbooksSyncProvider (LinkedSongbooksService)
        ├── Reads SharedPreferences: linked_songbooks
        ├── For each linked entry:
        │     ├── hasChangedSinceLastImport() → statSync on file
        │     └── If changed → reimportSource() (delete sourcePath rows + reinsert)
        └── Done
```

**Result:** Both bundled and linked songs end up in the same `songs` table. The user sees a unified list.

---

## Onboarding Flow

```
OnboardingPage
  ├── Page 1: Welcome
  ├── Page 2: Choose Your Experience
  │     ├── Card 1: "Use Pre-installed Songbooks"
  │     │     └── _nextPage() → proceeds to preferences
  │     │
  │     └── Card 2: "Link Songbook Files"
  │           ├── _linkSongbookFiles() → FilePicker + LinkedSongbooksService.add()
  │           └── _nextPage() → proceeds to preferences
  │
  └── Page 3: Quick Setup (theme, projection mode)
```

**Problem:** Both cards execute their side-effects but neither stores a preference. Card 1 does not prevent Card 2’s logic from running (and vice versa in subsequent launches, because seeding is idempotent and linked sync runs unconditionally).

---

## Song List Display

```
SongsTab
  ├── Search bar
  ├── Category filter
  ├── Sort menu
  ├── Source filter chips (only if sourcePaths.length > 1)
  │     ├── "All Books" (default)
  │     ├── "Full Song Book" (bundled)
  │     ├── "Injili Song Book" (bundled)
  │     └── "/path/to/linked.vsbook" (linked)
  │
  └── SongListItem (no source indicator)
```

**Problem:** 
- Default is “All Books” — linked and bundled are mixed.
- Source chips show file paths, which are user-unfriendly (e.g., `/home/user/Documents/songs.vsbook`).
- No visual distinction in song rows.

---

## Data Isolation Audit

| Concern | Current State | Risk |
|---|---|---|
| Linked songs visible when user chose “bundled only” | Yes — seeded unconditionally | User sees unwanted data |
| Bundled songs visible when user chose “linked only” | Yes — seeded unconditionally | User sees unwanted data |
| Linked file deleted → data loss | Partial — last import remains in DB | If user clears app data, all linked songs are lost |
| Duplicate titles across sources | Silent — both appear in list | User doesn’t know they’re duplicates |
| Same songNum, different content | Constraint error or silent overwrite | Data corruption or crash |
| Local edits to linked songs | Saved to DB, but reimport overwrites them | User edits lost on sync |

---

## Gaps by User Scenario

### Scenario A: “I only want my linked songbooks”
- **Expected:** No bundled songs appear.
- **Actual:** Bundled songs are seeded on first launch regardless.
- **Gap:** No `SourceMode` preference.

### Scenario B: “I want bundled songs, but I also link one file”
- **Expected:** Both appear, clearly labeled.
- **Actual:** Both appear, but indistinguishable in the song list.
- **Gap:** No source indicator in `SongListItem`.

### Scenario C: “I linked a file, then deleted it from disk”
- **Expected:** App still works, shows the last-imported songs.
- **Actual:** App works (songs remain in DB), but `hasChangedSinceLastImport` throws on every startup (unhandled `statSync` on missing file). No explicit “serving from cache” message.
- **Gap:** No cache layer; `statSync` error handling is silent.

### Scenario D: “I edited a linked song locally, then the file changed on disk”
- **Expected:** My local edit is preserved; I’m asked what to do with the incoming change.
- **Actual:** Reimport deletes all songs for that `sourcePath` and reinserts from the file. Local edits are lost.
- **Gap:** No merge strategy; no conflict detection.

### Scenario E: “I have two songbooks with the same song number but different songs”
- **Expected:** App shows both, lets me pick which one to keep.
- **Actual:** If the unique index is enabled, the second insert fails with `UNIQUE constraint failed`. If the index is disabled, both rows exist but the user can’t tell they’re duplicates.
- **Gap:** No variant detection or resolution UI.

---

## Root Causes

| Root Cause | Affected Scenarios |
|---|---|
| No `SourceMode` preference | A, B |
| Unconditional seeding + sync on startup | A, B |
| Single shared database for all sources | B, C, D, E |
| No local cache for linked files | C |
| Reimport uses delete-all + insert (no merge) | D |
| No title-similarity detection | E |
| No visual source indicator | B |

---

## Recommended Fixes (Summary)

| Fix | Addresses | Effort |
|---|---|---|
| Add `SourceMode` enum + preference | A, B | 30 min |
| Gate seeding + sync on `SourceMode` | A, B | 20 min |
| Add source indicator to `SongListItem` | B | 20 min |
| Add `linked_songbook_cache` table + service | C | 60 min |
| Implement merge service for reimports | D | 45 min |
| Add variant detector + review screen | E | 60 min |
| Update onboarding + settings UI | A, B | 40 min |

**Total estimated effort:** ~4.5 hours across 6 phases.

---

## Decision Log

| Decision | Rationale |
|---|---|
| Keep single database (no per-source DB files) | Simpler queries, preserves existing features (search, sets, history), works on mobile |
| Use virtual source filtering instead of physical separation | Minimal schema change, no migration risk, reversible |
| Cache linked songs in `linked_songbook_cache` table | Provides fallback without architectural change; survives DB clears if we later move to per-profile |
| Soft-delete removed songs instead of hard-delete | Preserves history references; user can recover if merge was wrong |
| Local edits always win over incoming linked changes | Prevents surprise data loss; variant review handles title conflicts |
| Unique index on `(LOWER(title), songNum)` stays enforced | Enforces data quality; variant review resolves legitimate cross-source duplicates |

---

## References

- Plan document: `docs/LINKED_SONGBOOK_SEPARATION.md`
- Audit report: `docs/AUDIT_REPORT.md`
- Execution plan: `docs/AUDIT_EXECUTION_PLAN.md`
- Linked songbook service: `lib/data/services/linked_songbooks_service.dart`
- Seeding service: `lib/data/services/seeding_service.dart`
- Onboarding: `lib/features/onboarding/onboarding_page.dart`
- Song list: `lib/features/song_list/songs_tab.dart`
- Song item: `lib/features/song_list/widgets/song_list_item.dart`
