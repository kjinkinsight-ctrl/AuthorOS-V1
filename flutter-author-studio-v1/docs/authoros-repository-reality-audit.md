# AuthorOS Repository Reality Audit

> **AUDIT ONLY.** No source file, test, asset, configuration, schema, or dependency
> was created, modified, renamed, or deleted while producing this document. This
> file is the sole repository change.

---

## Audit Date

2026-08-21

---

## Repository / Branch / Commit

| Item | Value |
|---|---|
| Repository | `kjinkinsight-ctrl/AuthorOS-V1` |
| Branch audited | `claude/authoros-repository-audit-xv1trv` |
| Commit | `88fbdce0186d1f332d7f36bd99ac9a08105a5c5a` |
| Commit subject | `feat(sync): write project saves to sync_records` |
| Working tree before audit | **Clean** (`git status --porcelain` returned no output) |
| Total commits in history | 29 |
| Branches present | `main`, `claude/authoros-repository-audit-xv1trv` (local + remote for both) |

### Repository layout

The repository root is **not** a Flutter project. It contains two independent products:

```
/                                   <- repo root (no pubspec.yaml)
├── NEXT.md                         <- vision / roadmap narrative (17 KB)
├── .github/workflows/              <- dart.yml, generator-generic-ossf-slsa3-publish.yml
├── flutter-author-studio-v1/       <- THE AUTHOROS FLUTTER APPLICATION (120 MB)
└── indiauthors-platform/           <- separate Next.js + Fastify marketing/licensing platform (540 KB)
```

Everything referred to as "AuthorOS the application" in this audit lives in
`flutter-author-studio-v1/`. Paths below are relative to that directory unless
stated otherwise.

### Scale of the application

| Metric | Value |
|---|---|
| Dart files in `lib/` | 77 |
| Lines of Dart in `lib/` | 63,421 |
| Largest file | `lib/persistence/authoros_database.g.dart` (9,115 — generated) |
| Largest hand-written file | `lib/main.dart` (5,634) |
| Test files | 51 `*_test.dart` + 10 fixtures |
| Lines of Dart in `test/` | 18,797 |
| `test()` / `testWidgets()` declarations | **453** |

`lib/` has only six subdirectories — `archive`, `core`, `migrations`,
`persistence`, `sync`, `theme`. There is no `lib/features/`, no per-studio
package structure, and no map, community, analytics, progression, or AI
directory. Most studio UI lives in a handful of very large top-level files.

---

## Executive Summary

**AuthorOS is a real, substantial, working Flutter application — roughly 63k lines
of production Dart with 453 tests — but it is materially smaller and differently
shaped than the roadmap documents imply.**

The five findings that matter most:

1. **Map Studio does not exist.** Not partially, not as a stub, not behind a flag.
   There is no `MapStudio` class, no `map_studio.dart`, no map canvas, no map
   editor, no terrain system, no overlay system, no world simulation, and no map
   export. Git history confirms **no map source file has ever existed in this
   repository**. Map Studio is text in `NEXT.md` and one section of the master
   plan. The six-phase Map plan referenced in the audit brief (Phase 1 Foundation
   → Phase 6 Presentation/Export) **does not appear anywhere in this repository
   in any form** — the repository's own master plan describes Map Studio as *two*
   levels (annotation, then creation), not six phases.

2. **Community does not exist.** Zero implementation in the Flutter app and zero
   in the platform project. The literal word "community" appears exactly once in
   the platform (`product-discovery.ts:143`, inside a *future ideas* roadmap
   summary string) and in the master plan under `M8` as an explicitly *optional*
   milestone. No author profiles, no sharing, no discovery, no following, no
   community statistics.

3. **The Theme Engine is fully built, fully tested, and completely disconnected.**
   All eight named classes exist (`ThemeEngine`, `ThemeRegistry`, `ThemeResolver`,
   `ThemePersistence`, `ResolvedTheme`, `AuthorOsTheme`, `StudioThemeScope`,
   `ThemeDefinition`) with 64 passing-by-construction tests across two test files.
   **Nothing in `lib/` outside `lib/theme/` imports any of it.** The only importers
   are `test/theme_engine_test.dart` and `test/theme_flutter_adapter_test.dart`.
   The running app themes itself from a completely separate `AppThemePreset` /
   `_buildThemeData()` implementation inside `lib/main.dart`. Phase 1 is real;
   **Phase 2 shell integration has not happened.**

4. **"Universal Records" exists under entirely different class names.** None of
   `RecordId`, `RelationshipId`, `RelationshipValidator`, `RecordGraph`, or
   `UniversalRecordsRepository` exist. What *does* exist is a mature equivalent:
   `AuthorRecord`, `RecordLink`, `ConnectionTypeRegistry.validateConnection()`,
   `ConnectedDomainSnapshot`, `DriftConnectedDomainRepository`, plus real
   `RecordService` and `ConnectionEngine` classes, 23 built-in record types and
   34 connection types, all persisted to SQLite via Drift. Judged by capability
   this is implemented; judged by the exact class list in the brief, it is not.

5. **Two parallel architectures run side by side.** A modern record/graph/Drift
   stack (Character Studio, World Studio, Story Codex) coexists with a legacy
   JSON-blob-in-SharedPreferences stack (Timeline, Plot, Projects, Notes, Ideas,
   Research). In two cases the modern domain service is fully built and **has no
   UI consumer at all**: `PlotService` (722 lines) and `TimelineService` (785
   lines) are imported by nothing in the app — the Plot and Timeline navigation
   items render the older SharedPreferences views instead.

Additional material findings: **CI has never passed** — all 8 workflow runs since
the workflow was created have failed, including the current HEAD commit; one
1,642-line World Studio implementation (`lib/world_studio.dart`) is fully
orphaned; a dead `lib/main.authorstudio.backup.dart` remains in the tree; the
"Ctrl+K" command palette and the "Alerts" badge in the top bar are cosmetic only;
and the login screen performs no authentication.

**On AI specifically:** the absence of AI is not a gap. `NEXT.md` §9 is titled
*"AI-FREE IS ACTUALLY A FEATURE"* and states the AI-free posture is an intentional
differentiator. AI should be recorded as an explicit non-goal, not as missing work.

---

## What Is Actually Built

These systems have real code, real UI, real persistence, and are reachable by a user.

| System | Evidence |
|---|---|
| **Application shell** | `AuthorStudioShell` (`main.dart:1195`), 15-section `StudioSection` enum, desktop + mobile navigation, top bar, focus mode |
| **Navigation** | `_DesktopNavigation` (`main.dart:1662`), `_MobileNavigation` (`main.dart:1871`), `_SectionView` router (`main.dart:1936`) — every one of the 15 sections resolves to a real widget |
| **Persistence (Drift/SQLite)** | `lib/persistence/authoros_database.dart` + 9,115-line generated `.g.dart`; 12 tables incl. `AuthorRecordRows`, `RecordLinkRows`, `RecordVersionRows`, `AuditEventRows`, branch overlays |
| **Record / Connection system** | `RecordService` (464), `ConnectionEngine` (247), `RecordTypeRegistry`, `ConnectionTypeRegistry`, 23 built-in record types, 34 connection types |
| **Character Studio** | `lib/character_studio.dart` (2,816) → `CharacterBoardView`, wired to `CharacterService` + `RecordService` + Drift; Ctrl/Cmd+S save shortcut; completion indicator |
| **World Studio** | `lib/world_workspace.dart` (5,235) → `WorldWorkspace`, backed by `WorldService` (1,505) + Drift; 7 world record types (world, location, faction, culture, religion, …) with deep field sets |
| **Story Codex** | `lib/story_codex_workspace.dart` (4,009) → `StoryCodexWorkspace`, backed by `StoryCodexService` (1,428) + Drift |
| **Manuscript Studio** | `lib/manuscript_studio.dart` (2,322) → `ManuscriptStudioView`, `ManuscriptStore` (795, Drift-backed); real keyboard shortcuts (Ctrl+Shift+N new scene, Ctrl+Shift+C new chapter, Ctrl+F find, Ctrl+Enter save) |
| **Chapter & scene management** | `ChapterStudioView` (`release_destinations.dart:1023`) plus scene CRUD inside Manuscript Studio |
| **PDF export** | `lib/manuscript_export.dart` (486) — `ManuscriptPdfExporter`, `NativeExportFileSaver`, real `package:pdf` output and native save dialog |
| **Portable archive** | `lib/archive/authoros_archive.dart` (371) — `AuthorOsArchiveService`, export/import with manifest schema at `docs/schemas/authoros-archive-manifest-v1.schema.json` |
| **Backup health** | `lib/backup_health.dart` (583) — `BackupRecoverySimulator`, `BackupHealthStore`, `BackupHealthView` |
| **Continuity engine** | `lib/continuity.dart` (1,049), `continuity_actions.dart`, `world_continuity.dart`, `codex_continuity.dart` — warnings, severities, and one-click fix actions |
| **Version history / audit** | `core/version_audit.dart`, `core/version_audit_service.dart`, `RecordVersionRows`, `AuditEventRows` |
| **Branching** | `core/branch_domain.dart`, `branch_engine.dart`, `branch_service.dart`, branch overlay tables |
| **Safe delete** | `core/safe_delete.dart`, `safe_delete_service.dart` |
| **Universal search** | `core/universal_search.dart` → `UniversalSearchService`, consumed by 8 files; `SearchStudioView` in nav |
| **Theme Engine (as a library)** | `lib/theme/` — all 8 named classes present and tested (see Theme Engine Status for the integration caveat) |
| **Supabase sync** | `lib/supabase_service.dart`, `lib/sync/sync_store.dart`, `project_sync.dart`, `project_sync_service.dart`; `supabase/schema.sql` with `projects` + `sync_records` tables |
| **Onboarding / first-run wizard** | `lib/onboarding.dart` (1,234) — `FirstRunProjectWizard`, `OnboardingStore` |
| **Welcome / opening page** | `lib/welcome_page.dart` (747) — `WelcomePage` with 6 tiles + Quick Start row |
| **Focus mode** | `focus-mode-toggle` in `_TopBar`, `minimalFocusMode` threaded into `_SectionView` and Manuscript Studio |
| **Settings** | `SettingsStudioView` (`release_destinations.dart:2600`) — theme selection, Google sign-in, logout, reading rhythm |

---

## What Is Partially Built

| System | What exists | What is missing |
|---|---|---|
| **Theme Engine** | Complete engine, registry, resolver, persistence, Flutter adapter, `StudioThemeScope`, 64 tests | **Zero production consumers.** `MaterialApp` uses `main.dart`'s separate `AppThemePreset`. Phase 2 shell integration not done. Only 2 themes (light/dark) in each of the two systems. |
| **Plot Studio** | `PlotService` (722) + `PlotRecordTypes` (761) with plotline/arc/beat field definitions; `VisualPlanningView` Kanban UI with `SceneStatus` lanes and `StructureOverlay` (three-act, hero's journey) | The two halves are not connected. `PlotService` is imported by **no other file in `lib/`**. The Plot nav item renders `VisualPlanningView`, which persists to SharedPreferences via `VisualPlanningStore`. No Plot Board proper, no Story Grid, no Beat Sheets. |
| **Timeline Studio** | `_TimelineStudioView` (`main.dart:2381`, ~1,550 lines) with events, eras, sequences, filters, sorting, pagination, continuity integration; separate `TimelineService` (785) + `timeline_record_types.dart` | Same split as Plot: the UI uses `TimelineStore` (SharedPreferences JSON) from `lib/timeline.dart`; `TimelineService` is imported only by `continuity_actions.dart` and itself. Timeline is not on the record/Drift stack. |
| **Login / Users** | `ProfileSetupScreen` with profile card, "Continue with selected profile", "Create new profile", "Reset app state" | **Single profile only** — one name + one email in SharedPreferences keys `author_studio.profile.name` / `.email`. No multi-user list, no "Continue with Email", no "Use Password", no "Add New User", no password field. The screen performs **no authentication** — `_login()` just sets `profileComplete = true`. Google sign-in exists but lives in **Settings**, not on the login screen. |
| **Research Studio** | `_ResearchSidePanel` (`main.dart:2161`) with `ResearchTab {research, notes, timeline}`, pinned references, `ProjectResearchStore` | Not a studio — it is a 260px side panel inside Manuscript Studio only, not a navigation destination. `ResearchReference` carries only `title`/`detail`/`tag`. No sources model, no citations, no bibliography. |
| **Writing statistics** | `StatisticsStudioView` — word count, goal progress bar, words remaining, stat tiles | Single-project snapshot only. No history, no streaks, no heatmap, no session tracking, no charts. |
| **Word goals** | `project.wordGoal` set in onboarding, consumed by statistics and manuscript | Project-level target only. No daily goals, no per-chapter goals, no goal history. |
| **Writing sprint timer** | Real `Timer.periodic` countdown from 15:00 in `ManuscriptStudioView`, rendered as a badge | **Display-only.** Starts only if `startSprint` was passed from onboarding. No start/pause/reset/configure control anywhere in the studio UI. |
| **Story Library / Projects** | `_ProjectsStudioView` (`main.dart:3981`, ~600 lines) — project records, author profile | SharedPreferences-backed, separate from the record system. |
| **Backup & Export** | Archive service, backup health, PDF export | PDF is the only export format. No DOCX, EPUB, or Markdown export. |
| **Cloud sync** | `ProjectSyncService` with offline queue, flush-on-sign-in, `sync_records` table | Projects only. Records, worlds, characters, codex, timeline, and plot do not sync. |

---

## What Is Planned Only

Present in documentation with **no implementation whatsoever**:

| System | Where it is planned |
|---|---|
| **Map Studio** (all of it) | `NEXT.md` §4 (lines 247–322); `docs/authoros-2-master-plan.md` §11.9 (two levels: annotation, then creation) and milestone `M6` |
| **Community / Author profiles / Sharing / Discovery / Following / Community statistics** | `NEXT.md` §11 "Community Stats" (lines 606–647), §10 writer leaderboards; master plan `M8` — explicitly *"optional World community"* |
| **Progression / Achievements / Rewards / Badges** | Master plan `M8` (streaks, milestones); `docs/cross-system-integration-phase-1-implementation-map.md:280` lists "Progression Phase 3" as future |
| **Analytics beyond a word counter** | `NEXT.md` §10 "The Writer's Dashboard"; master plan `M8` (heat maps, sessions) |
| **Book Studio** | `NEXT.md` §8; master plan §11.10 and `M7` |
| **Visual Studio / World Board** | `NEXT.md` §5; master plan §11.8 and `M5` |
| **Relationship Studio / Lineage Canvas** | `NEXT.md` §6; master plan §11.7 and `M5` |
| **Series Studio / Universe scope** | `NEXT.md` "And I would add one more thing"; master plan `M4` |
| **Author Journey** | Master plan §11.12, `M8` |
| **Expansion Packs** | Referenced as future in both theme-engine implementation maps |
| **Rich text editing** | Not planned in detail; current editor is a plain `TextEditingController` + `TextField` |

---

## What Was Not Found

Neither implementation nor meaningful planning evidence:

- **Story Grid** — zero hits repository-wide.
- **Beat Sheets** — one hit only, in the dead file `lib/main.authorstudio.backup.dart:448`, inside a description string.
- **Story Arcs as a first-class system** — `arcNames` appears only as seed strings in `lib/timeline.dart`; `hasArc` exists as one of the 34 connection types, but there is no arc studio, model, or view.
- **Command Palette** — the string `Ctrl+K` appears once (`main.dart:1447`) as a decorative `shortcut:` label on a button that navigates to the Search section. There is no `Shortcuts`/`CallbackShortcuts` binding for it anywhere.
- **Notifications** — no notification system. `main.dart:1452` renders a bell icon with a **hardcoded** `badge: '3'` that navigates to the Backup section. The only other hit is a settings switch icon.
- **World simulation** — zero hits.
- **Map export / sharing** — zero implementation hits.
- **AI (any form)** — zero implementation. **This is intentional**: `NEXT.md` §9 declares AI-free a product feature.
- **Multiple user profiles** — storage holds exactly one name and one email.
- **Followers** — zero hits repository-wide.

---

## Visible Application Navigation

Source of truth: `StudioSection` enum (`main.dart:1137`), `StudioSectionData` extension (`main.dart:1155`), `_DesktopNavigation` (`main.dart:1662`), `_SectionView` (`main.dart:1936`).

There are exactly **15** navigation items in **three groups**.

### Group: WORKSPACE

| Label | Icon | Destination widget | Exists | Functional | Notes |
|---|---|---|---|---|---|
| Dashboard | `space_dashboard_outlined` | `_DashboardView` (`main.dart:5121`) | ✓ | ✓ | Real, ~400 lines, navigates to other sections |
| Search | `search_outlined` | `SearchStudioView` | ✓ | ✓ | Backed by `UniversalSearchService` |
| Statistics | `bar_chart_outlined` | `StatisticsStudioView` | ✓ | ~ | Word count + goal progress only |
| Backup | `backup_outlined` | `BackupHealthView` | ✓ | ✓ | Real health metrics + recovery simulation |
| Projects | `folder_copy_outlined` | `_ProjectsStudioView` | ✓ | ✓ | SharedPreferences-backed |
| Ideas | `lightbulb_outline` | `RecordStudioView(collection: 'ideas')` | ✓ | ✓ | Generic record list, 4 categories |
| Manuscript | `menu_book_outlined` | `ManuscriptStudioView` + `_ResearchSidePanel` | ✓ | ✓ | Deepest studio; special-cased layout |

### Group: STORY

| Label | Icon | Destination widget | Exists | Functional | Notes |
|---|---|---|---|---|---|
| Chapters | `chrome_reader_mode_outlined` | `ChapterStudioView` | ✓ | ✓ | |
| Characters | `groups_outlined` | `CharacterBoardView` | ✓ | ✓ | Drift + record system; cross-navigates to 5 destinations |
| Story Codex | `auto_stories_outlined` | `StoryCodexWorkspace` | ✓ | ✓ | Drift + record system |
| World | `public_outlined` | `WorldWorkspace` | ✓ | ✓ | Drift + record system; largest studio file |
| Plot | `route_outlined` | `VisualPlanningView` | ✓ | ~ | Kanban board, SharedPreferences; **not** `PlotService` |
| Timeline | `timeline_outlined` | `_TimelineStudioView` | ✓ | ✓ | Rich UI, SharedPreferences; **not** `TimelineService` |
| Notes | `sticky_note_2_outlined` | `_NotesStudioView` | ✓ | ✓ | ~470 lines |

### Standalone

| Label | Icon | Destination widget | Exists | Functional | Notes |
|---|---|---|---|---|---|
| Settings | `settings_outlined` | `SettingsStudioView` | ✓ | ✓ | Theme, Google sign-in, logout, reading rhythm |

**No navigation item is a placeholder, disabled, or dead.** All 15 resolve to real, rendering widgets. The gaps are in *which* implementation a label points at (Plot, Timeline), not in whether a destination exists.

### Top bar actions (`_TopBar`, `main.dart:1427`)

| Control | Behaviour | Verdict |
|---|---|---|
| Search + `Ctrl+K` label | Navigates to Search section | **Shortcut label is cosmetic** — no key binding exists |
| Alerts, badge `3` | Navigates to Backup section | **Badge is hardcoded**; no notification system |
| Theme | Navigates to Settings | Real |
| Profile | Navigates to Settings | Real |
| Focus / Exit focus | Toggles `minimalFocusMode` | Real |

### Direct answers

1. **Is there currently a visible Map Studio icon?** — **No.** `StudioSection` has no map member.
2. **Does clicking it open a real Map Studio?** — N/A; no icon, and no Map Studio code exists.
3. **Is there currently a visible Community icon?** — **No.**
4. **Does clicking it open a real Community system?** — N/A; no icon, no code.
5. **Is there currently a visible Character Studio?** — **Yes** — label "Characters" → `CharacterBoardView`. Real and functional.
6. **Is there currently a visible World Studio?** — **Yes** — label "World" → `WorldWorkspace`. Real and functional.
7. **Is there currently a visible Timeline Studio?** — **Yes** — label "Timeline" → `_TimelineStudioView`. Real and functional (legacy persistence).
8. **Is there currently a visible Plot Studio?** — **Yes, by label.** "Plot" → `VisualPlanningView`, a scene Kanban board. It is *not* the Plot Studio described in `plot-studio-phase-1-implementation-map.md`, whose `PlotService` has no UI.
9. **Is there currently a visible Manuscript Studio?** — **Yes** — label "Manuscript" → `ManuscriptStudioView`. The most complete studio in the app.

---

## Current Startup Flow

Traced through `main()` (`main.dart:26`) → `AuthorStudioApp` → `_AuthorStudioAppState` (189) → `_OnboardingBootstrap` → `_OnboardingBootstrapState` (939).

```
COLD LAUNCH
  └─ WidgetsFlutterBinding.ensureInitialized()
  └─ AppSupabase.initialize()          (5s timeout; app continues if unavailable)
  └─ runApp(AuthorStudioApp)
       └─ _loadThemeSelection()        (SharedPreferences; spinner while loading)
       │    NOTE: accent is force-reset to 'default' on every launch
       └─ MaterialApp(theme: _buildThemeData())   <- main.dart's AppThemePreset, NOT lib/theme/
            └─ _OnboardingBootstrap._loadStartupState()
                 └─ loads saved project + stored profile name/email
                 └─ sets profileComplete = false  <- UNCONDITIONALLY, every launch
                      ↓
            ┌────────────────────────────────────────────┐
            │ 1. WelcomePage        (if showWelcome)     │  <- OPENING PAGE COMES FIRST
            │    6 tiles + Quick Start row               │
            └────────────────────────────────────────────┘
                      ↓ (any tile sets welcomeDismissed = true and a target section)
            ┌────────────────────────────────────────────┐
            │ 2. ProfileSetupScreen (if !profileComplete)│  <- LOGIN COMES SECOND
            │    "Login / Profile Selection"             │
            │    • Continue with selected profile        │
            │    • Create new profile                    │
            │    • Reset app state                       │
            └────────────────────────────────────────────┘
                      ↓
            ┌────────────────────────────────────────────┐
            │ 3. FirstRunProjectWizard (if project null) │
            └────────────────────────────────────────────┘
                      ↓
            ┌────────────────────────────────────────────┐
            │ 4. AuthorStudioShell  (WORKSPACE)          │
            │    opens welcomeTarget section if set      │
            └────────────────────────────────────────────┘
```

### Per-scenario behaviour

| Scenario | Actual behaviour |
|---|---|
| **A. Cold launch** | Supabase init → theme load (spinner) → Welcome page → Profile selection → (wizard if no project) → Shell |
| **B. Existing user** | Stored name/email are read and shown on the profile card, **but `profileComplete` is hardcoded to `false` in `_loadStartupState()`** (`main.dart:970`). The `author_studio.profile_setup_complete` key is written by `_completeProfile()` and `_login()` but **never read at startup**. Result: a returning user must click through the profile screen on *every* launch. |
| **C. New user** | Welcome page shows "Welcome to / Author OS" (no name) → profile screen shows "No profile is selected yet. Create a profile to begin." → create profile → wizard → Shell |
| **D. Login** | `_login()` sets `profileComplete = true` and reloads the saved project. **No credential check, no password, no Supabase call.** It is a local gate, not authentication. |
| **E. Profile creation** | `_completeProfile(name, email)` writes three SharedPreferences keys and flips `profileComplete`. Display name + email only; no password, no avatar, no per-profile data partition. |
| **F. Opening page** | `WelcomePage` renders **before** login. Actions: Open Project, New Project, Recent Projects, Templates, Worlds, Settings, plus Quick Start (New Project, Create Character, Build World, New Manuscript, Open Timeline, Continue Writing). Each maps to a `StudioSection` via `_openFromWelcome()`. |
| **G. Workspace entry** | `AuthorStudioShell` with `initialSection: welcomeTarget`; `welcomeDismissed` prevents bouncing back to the welcome page. |

**Logout** (`_logoutToProfileSelection`, `main.dart:1037`) clears `profile_setup_complete`, calls `AppSupabase.signOut()`, and returns to profile selection while *retaining* the stored name/email.

---

## Intended Startup Flow

As specified by the repository owner:

```
launch
  └─ Login / Select User
       ├─ select a user → continue
       ├─ Continue with Email
       ├─ Use Password
       └─ Add New User
             └─ Create Your Profile
                    └─ Start Your Adventure
                           ↓
                     Opening Page
                           ↓
                       Workspace
```

### CURRENT vs INTENDED

| # | Aspect | Intended | Current | Gap |
|---|---|---|---|---|
| 1 | **Order** | Login → Profile → Opening → Workspace | **Opening → Login → Wizard → Workspace** | **Inverted.** Welcome page renders before login. |
| 2 | **Select a user** | List of users to choose from | Single profile card | Multi-profile storage does not exist |
| 3 | **Continue with Email** | Dedicated email path | Absent | Not implemented |
| 4 | **Use Password** | Password authentication | Absent — no password field or check anywhere | Not implemented |
| 5 | **Add New User** | Adds an *additional* user | "Create new profile" **overwrites** the single stored profile | Semantics differ |
| 6 | **Create Your Profile** | Named step | `ProfileSetupScreen` create mode (name + email) | Closest match; exists |
| 7 | **Start Your Adventure** | Named CTA leading to Opening Page | Absent — no such string in the repository | Not implemented |
| 8 | **Opening Page** | After profile creation | Exists, but appears **first** | Reposition required |
| 9 | **Session persistence** | Returning user recognised | `profileComplete` forced false every launch | Returning users re-authenticate every time |
| 10 | **Project wizard** | Not in the intended flow | `FirstRunProjectWizard` sits between login and workspace | Extra step |

---

## Theme Engine Status

🟡 **PARTIALLY IMPLEMENTED — Phase 1 complete and tested; Phase 2 (shell integration) not done.**

| Item | Exists | Location | Integrated into app |
|---|---|---|---|
| `ThemeEngine` | ✓ | `lib/theme/theme_engine.dart:18` (129 lines) | **✗** |
| `ThemeRegistry` | ✓ | `lib/theme/theme_registry.dart:11` (184) | **✗** |
| `ThemeResolver` | ✓ | `lib/theme/theme_resolver.dart:14` (152) | **✗** |
| `ThemePersistence` | ✓ | `lib/theme/theme_persistence.dart:101` (187) | **✗** |
| `ResolvedTheme` | ✓ | `lib/theme/resolved_theme.dart:15` (83) | **✗** |
| `AuthorOsTheme` | ✓ | `lib/theme/flutter/authoros_theme.dart:17` (278) | **✗** |
| `StudioThemeScope` | ✓ | `lib/theme/flutter/authoros_theme.dart:219` | **✗** — never installed by any shell |
| `ThemeDefinition` / `AuthorOsThemeMode` | ✓ | `lib/theme/theme_definition.dart:93` / `:13` | **✗** |
| `theme_tokens.dart` | ✓ | 223 lines | **✗** |
| **MaterialApp integration** | **✗** | `main.dart:361` uses `_buildThemeData()` from `AppThemePreset` | — |
| Tests | ✓ | `theme_engine_test.dart` (48 tests) + `theme_flutter_adapter_test.dart` (16 tests) = **64** | — |

**Proof of disconnection:** `grep -rn "import.*theme/" lib/ test/ | grep -v "^lib/theme/"` returns **only test files**. Not one production file outside `lib/theme/` imports the engine.

### Current theme selection behaviour (what the user actually gets)

- Settings → theme picker calls `onThemeChanged(themeId, accentId)` (`release_destinations.dart:3456`).
- That reaches `_handleThemeChanged` → `_updateThemeSelection` (`main.dart:262`), which **discards the accent**: `_accentId = 'default'` unconditionally.
- `_loadThemeSelection()` also force-writes `'default'` back to the accent key on every launch.
- Available themes: **2** (`light`, `dark`) via `AppThemePreset`. The unused `ThemeRegistry` also defines exactly 2 (`_lightTheme`, `_darkTheme`).
- Net effect: **theme selection works; accent selection is inert; per-studio theming does not exist in the running app.**

---

## Universal Records Status

🟡 **PARTIALLY IMPLEMENTED — the capability exists and is strong; the named API in the brief does not.**

### Named classes from the brief

| Class | Exists | Actual equivalent |
|---|---|---|
| `RecordId` | **✗** | Plain `String id` on `AuthorRecord` |
| `RelationshipId` | **✗** | Plain `String linkId` on `RecordLink` |
| `RelationshipValidator` | **✗** | `ConnectionTypeRegistry.validateConnection()` (`core/connection_types.dart:118`), called from 5 sites; plus `RecordValidator` (`core/record_validation.dart:45`) |
| `RecordGraph` | **✗** | `ConnectedDomainSnapshot` (`core/connected_domain.dart:277`) |
| `UniversalRecordsRepository` | **✗** | `InMemoryConnectedDomainRepository` (`connected_domain.dart:353`) + `DriftConnectedDomainRepository` (`persistence/authoros_database.dart:440`) |
| `ConnectionEngine` integration | **✓** | `core/connection_engine.dart:10`; consumed by 8 files |
| `RecordService` integration | **✓** | `core/record_service.dart:11`; consumed by 14 files |

### Capability inventory

| Item | Status | Detail |
|---|---|---|
| Core record model | ✓ | `AuthorRecord` with `AuthorRecordStatus {active, archived, deleted}` |
| Typed links | ✓ | `RecordLink` with `RecordLinkDirection {directed, undirected}` |
| Built-in record types | ✓ | **23** — 7 general (`general-lore`, `world`, `location`, `faction`, `culture`, `religion`, …), 7 world, 3 character, 3 plot, 3 timeline |
| Built-in connection types | ✓ | **34** — `memberOf`, `livesIn`, `controls`, `locatedIn`, `owns`, `uses`, `appearsIn`, `mentionedIn`, `bornIn`, `worksIn`, `visits`, `carries`, `pursues`, `hasArc`, `knows`, … many with typed attributes (rank, joinedDate, status, knowledgeState) |
| Custom record types | ✓ | `RecordTypeRegistry`, `PlotService.registerCustomType()`, `WorldTemplateRegistry` |
| Persistence | ✓ | Drift/SQLite — `AuthorRecordRows`, `RecordLinkRows`, `RecordTypeDefinitionRows`, `ConnectionTypeDefinitionRows` |
| Versioning + audit | ✓ | `RecordVersionRows`, `AuditEventRows`, `VersionAuditService` |
| Branching | ✓ | `StoryBranchRows`, `BranchRecordOverlayRows`, `BranchLinkOverlayRows`, `BranchService` |
| Safe delete | ✓ | `SafeDeleteService` |
| Search | ✓ | `UniversalSearchService` |
| Transactions | ✓ | `ConnectedDomainTransaction` |
| Tests | ✓ | `record_service_test` (5), `record_types_test` (5), `record_inspector_test` (15), `connection_engine_test` (1), `connection_types_test` (2), `connected_domain_test` (5), `branch_*` (10), `safe_delete_service_test` (7), `version_audit_*` (10), `universal_search_test` (9), `authoros_database_test` (7), `cross_system_integration_test` (17) |

**Verdict on "Is Universal Records Phase 1 actually implemented?"**
By capability: **yes** — a working universal record + typed-relationship + persistence + versioning + branching layer is live and consumed by Character Studio, World Studio, and Story Codex. By the literal class list in the brief: **no** — five of the seven named types do not exist under those names. The likely explanation is that the brief's naming comes from a design document that was implemented under different names, not that the work is missing. **Timeline and Plot are the two systems still outside this layer.**

---

## Manuscript Studio Status

🟢 **IMPLEMENTED** — the most complete studio in the application.

| Aspect | Status |
|---|---|
| Core | ✓ `lib/manuscript_studio.dart` (2,322), `lib/manuscript_store.dart` (795) |
| UI | ✓ `ManuscriptStudioView`, wired at `main.dart:1965` with a special full-height layout |
| Navigation | ✓ "Manuscript" in WORKSPACE group |
| Persistence | ✓ Drift (`ManuscriptNodeRows`) via `ManuscriptStore` |
| Tests | ✓ `manuscript_studio_test` (1), `manuscript_store_test` (4), `manuscript_export_test` (4) |
| Integration | ✓ Research side panel, continuity warnings, character cross-navigation, PDF export |
| Docs | ~ Covered in master plan §11.2; no dedicated implementation map |

Real features: chapter/scene CRUD, scene metadata (POV, location, time, notes), word count, search/find, focus mode, PDF export, and genuine keyboard shortcuts (`Ctrl+Shift+N`, `Ctrl+Shift+C`, `Ctrl+F`, `Ctrl+Enter` — `manuscript_studio.dart:1250`).

**Gaps:** the editor is a plain `TextEditingController` + `TextField` — **no rich text** (no bold/italic/styles). The sprint timer is display-only. Export is PDF-only.

---

## Character Studio Status

🟢 **IMPLEMENTED**

| Aspect | Status |
|---|---|
| Core | ✓ `lib/character_studio.dart` (2,816), `lib/character_service.dart` (355), `core/character_record_types.dart` (457), `core/character_presentation.dart` (100) |
| UI | ✓ `CharacterBoardView` (`character_studio.dart:522`) |
| Navigation | ✓ "Characters" in STORY group |
| Persistence | ✓ Drift via `RecordService` / `CharacterService` |
| Tests | ✓ `character_studio_test` (2), `character_workspace_test` (8), `character_domain_test` (6) + fixture |
| Integration | ✓ `CharacterWorkspaceDestination` cross-navigates to manuscript, timeline, codex, world, plot |
| Docs | ✓ `docs/character-studio-implementation-map.md`, `docs/m26-character-studio-deep-character-system.md` |

Character profiles ✓ (3 record type templates + custom templates, completion indicator, Ctrl/Cmd+S autosave-flush).
Character relationships ✓ via `RecordLink` / `ConnectionEngine` (`knows`, `memberOf`, `pursues`, …).
Character↔Timeline integration ~ — cross-navigation exists and `TimelineService` understands character records, but the *live* Timeline UI is on the separate SharedPreferences store, so links are not surfaced there.

---

## World Studio Status

🟢 **IMPLEMENTED** (with one orphaned duplicate — see Duplicate findings)

| Aspect | Status |
|---|---|
| Core | ✓ `lib/world_workspace.dart` (5,235), `lib/world_service.dart` (1,505), `core/world_record_types.dart` (780), `core/world_domain.dart` (317), `lib/world_continuity.dart` (304) |
| UI | ✓ `WorldWorkspace` (`world_workspace.dart:71`), wired at `main.dart:2059` |
| Navigation | ✓ "World" in STORY group |
| Persistence | ✓ Drift via `WorldService` → `RecordService` |
| Tests | ✓ `world_workspace_test` (23), `world_phase2_test` (24), `world_service_test` (6), `world_continuity_test` (11), `world_studio_test` (6 — tests the *orphaned* file) + fixture |
| Integration | ✓ Cross-navigation to 7 destinations; continuity engine |
| Docs | ✓ `docs/world-studio-implementation-map.md`, `docs/world-studio-phase-1-implementation-map.md` |

World records ✓ · Locations ✓ · Factions ✓ · Lore ✓ (`general-lore`) · Cultures ✓ · Religions ✓ · World relationships ✓ (`RecordLink`).
**Items** ~ — `owns`/`carries`/`uses` connection types exist and location fields cover `naturalResources`, but there is no dedicated *item* record type among the 7 world types.
Location records are deep: `terrain`, `climate`, `elevation`, `population`, `flora`, `fauna`, `weather`, `seasons`, `hazards`, `naturalPhenomena`, `architecture`, `infrastructure`, `economy`, `transportation`, and a `MapMarker` field. **Note:** `MapMarker` here is a *data field on a location record*, not a map rendering system.

---

## Timeline Studio Status

🟡 **PARTIALLY IMPLEMENTED — rich UI on the legacy stack; a complete modern service with no UI.**

| Aspect | Status |
|---|---|
| Core (live) | ✓ `lib/timeline.dart` (465) — `TimelineEvent`, `TimelineEra`, `TimelineSequence`, `TimelineStore` |
| Core (unwired) | ✓ `lib/timeline_service.dart` (785), `core/timeline_record_types.dart` (330), `lib/timeline_domain.dart` (195) |
| UI | ✓ `_TimelineStudioView` (`main.dart:2381`, ~1,550 lines) |
| Navigation | ✓ "Timeline" in STORY group |
| Persistence | 🟡 **SharedPreferences JSON** (`author_studio.project.<id>.timeline`) — *not* Drift |
| Tests | ✓ `timeline_test` (5), `timeline_domain_test` (8) + fixture |
| Integration | ~ Continuity engine ✓; record system ✗ for the live UI |
| Docs | ✓ `docs/timeline-studio-phase-1-implementation-map.md` |

Live UI is genuinely capable: 10 event types, 4 statuses, 4 importance levels, eras, sequences, 4 filters, chronological/narrative sorting, 30-per-page pagination, and continuity actions that can create missing characters/locations.

**The gap:** `TimelineService` — the Drift/record-backed implementation the phase-1 doc describes — is imported only by `continuity_actions.dart` and itself. The Timeline the user sees is the older one.

---

## Plot Studio Status

🟡 **PARTIALLY IMPLEMENTED — the widest split between domain and UI in the codebase.**

| Aspect | Status |
|---|---|
| Core (unwired) | ✓ `lib/plot_service.dart` (722) — `PlotService`, `PlotQueryService`, `PlotRecordDraft`, `PlotValidationIssue`, `PlotViewItem`; `core/plot_record_types.dart` (761) — 3 types with `plotStatus`, `planningOrder`, `narrativeOrder`, `chronologicalOrder`, `dependencies`, `openingState`, `closingState`, `goal`, `conflict`, `outcome`, `plotlineType`, `priority` |
| Core (live) | ✓ `lib/visual_planning.dart` (653) — `PlanningScene`, `VisualPlanningState`, `VisualPlanningStore` |
| UI | 🟡 `VisualPlanningView` — Kanban with `SceneStatus {backlog, outlining, drafting, revised, finalDraft}` and `StructureOverlay {none, threeAct, heroesJourney}` |
| Navigation | ✓ "Plot" in STORY group → `VisualPlanningView` |
| Persistence | 🟡 SharedPreferences for the live UI; Drift for the unwired service |
| Tests | ✓ `plot_service_test` (8) + fixture, `visual_planning_test` (2) |
| Integration | **✗ for `PlotService`** — imported by no other file in `lib/` |
| Docs | ✓ `docs/plot-studio-phase-1-implementation-map.md` |

**Plot Board** ~ (the Kanban is the closest thing) · **Story Grid** ⚪ absent · **Beat Sheets** ⚪ absent · **Story Arcs** ~ (`hasArc` connection type + `arcNames` seed strings only).

`PlotService` is the single largest piece of finished, tested, unreachable code in the repository.

---

## Map Studio Status

🔵 **PLANNED ONLY — no implementation of any kind, and none has ever existed.**

### Search results (whole repository, excluding `dist/` build artifacts)

| Term | Implementation files | Notes |
|---|---|---|
| `MapStudio` | **0** | — |
| `map_studio` | **0** | — |
| `Map Studio` | 0 code / **7 docs** | `authoros-2-master-plan.md`, 5 other implementation maps, `NEXT.md` |
| `map_editor` | **0** | — |
| `map editor` | 0 code / 3 docs | All three say it is *explicitly out of scope* |
| `MapCanvas` | **0** | — |
| `MapNode` | **0** | — |
| `MapOverlay` | **0** | — |
| `MapMarker` | 3 code | **A field on the `location` record type**, not a map system (`core/world_record_types.dart`, `world_service.dart`, `world_workspace.dart`) |
| `terrain` | 3 code | **A text field on the `location` record type** (`world_record_types.dart`, `world_workspace.dart`, orphaned `world_studio.dart`) |
| `world simulation` / `WorldSimulation` | **0** | — |
| `map export` | 0 code / 1 doc | Master plan only |

### Explicit scope exclusions already written into the repository

- `docs/world-studio-phase-1-implementation-map.md:168` — *"No graphical map editor, simulation, AI generation, graph visualization, 3D globe…"*
- `docs/world-studio-phase-1-implementation-map.md:176` — *"…must not begin an interactive map editor implicitly."*
- `docs/world-studio-implementation-map.md:22` — *"No polished World Studio UI or interactive map editor was added."*
- `docs/cross-system-foundation-implementation-map.md:465` — *"No Inspector UI, Story Inspector, graph editor, map editor…"*

### Git history

`git log --all --pretty=format: --name-only | sort -u` filtered for map-related names returns **only** `mipmap-*/ic_launcher.png` (Android icons) and `*-implementation-map.md` (documentation filenames). **No Map Studio source file has ever been committed to this repository, on any branch, in any commit.** No Dart file has ever been deleted from the Flutter app.

### Required Map Phase Table

**Important:** the six-phase structure below comes from the audit brief. **It does not exist in this repository.** The repository's own `docs/authoros-2-master-plan.md` §11.9 describes Map Studio as **two levels** — (1) map *annotation*, (2) map *creation* — with annotation shipping first, and schedules it at milestone `M6`. The six phases are recorded here as asked, marked against reality.

| Map Phase | Planned | Implemented | UI | Tests | Status |
|---|---|---|---|---|---|
| Phase 1 — Foundation | ~ (not as "Phase 1"; loosely covered by master plan §11.9 level 1 + `M6`) | — | — | — | 🔵 PLANNED ONLY |
| Phase 2 — Visual Map Editor | ~ (master plan §11.9 level 2; explicitly deferred in 4 docs) | — | — | — | 🔵 PLANNED ONLY |
| Phase 3 — Terrain, Assets & Visual Styling | ~ (`NEXT.md` §4 "Terrain" lines 279–306) | — | — | — | 🔵 PLANNED ONLY |
| Phase 4 — Story / Character / Timeline Overlays | ~ (`NEXT.md` line 318 "Map → Location → Character → Scene → Timeline Event") | — | — | — | 🔵 PLANNED ONLY |
| Phase 5 — Advanced World Simulation | — (zero hits repository-wide) | — | — | — | ⚪ NOT FOUND |
| Phase 6 — Presentation, Export & Sharing | ~ (master plan `M6` "annotation release") | — | — | — | 🔵 PLANNED ONLY |

**Actual user-visible Map functionality today: none.**

---

## Community Status

🔵 **PLANNED ONLY — architecture-only at best; closer to a single roadmap sentence.**

Classification against the brief's options: **not** architecture-only in any rigorous sense, **not** backend-only, **not** UI-only, **not** partially integrated, **not** fully integrated. There is **no Community artifact of any kind** in either project.

### Search results

| Term | Result |
|---|---|
| `Community` / `community` in `lib/` | **0 implementation hits.** All apparent matches are in `research/*.md` competitive-research files, a theme test string, and `tool/storage_benchmark.dart` |
| `AuthorProfile` | 3 hits — `main.dart` `AuthorProfileSummary` (a **local** author name/email holder used by PDF export), `manuscript_export.dart`, one doc |
| `social` | 0 in `lib/`; only research docs and `release_destinations.dart` (unrelated word usage) |
| `follower` | **0 repository-wide** |
| `following` | 2 — one search test, one master-plan sentence |
| `public project` | 1 — documentation only |
| `public world` | **0 repository-wide** |
| `community` in `indiauthors-platform` | **1** — `apps/api/src/domain/product-discovery.ts:143`, inside a `future_ideas` roadmap summary string: *"Future cloud extensions, community surfaces, and premium service options."* |
| `social` in `indiauthors-platform` | **0** |

**Note:** `product-discovery.ts` / `apps/site/app/explore/` are **product** discovery (a marketing feature catalogue and roadmap API), **not** social discovery. They are unrelated to Community.

### Planning evidence

- `docs/authoros-2-master-plan.md` `M8` — *"Author Journey and **optional** World community"*: local sessions/heatmaps/streaks, privacy controls, *opt-in* aggregated metrics, and visibility modes gated on *"only if identity and moderation are ready."*
- `NEXT.md` §11 "Community Stats" (lines 606–647) — "Today on AuthorOS", "Writing Around the World", leaderboards. Vision narrative.
- Both theme-engine implementation maps list "Community features" under explicitly-out-of-scope future work.

### Git history

No community, social, profile-sharing, or following source file has ever been committed on any branch.

---

## Analytics Status

🟡 **MINIMALLY IMPLEMENTED**

| Aspect | Status |
|---|---|
| Writing analytics | 🟡 `StatisticsStudioView` — current word count, `wordGoal` progress bar, words remaining, stat tiles. No time series, no sessions, no streaks, no heatmap, no charts. |
| Project statistics | 🟡 Per-project word count only |
| Author statistics | ⚪ Not found |
| Progress tracking | 🟡 Goal progress bar; `reading_rhythm.dart` (57) provides `ReadingRhythmPreset {compact, standard, immersive}` — a reading-density setting, not analytics |
| Persistence | ✓ Derived from `ManuscriptStore` (Drift) at render time; nothing is recorded historically |
| Tests | ~ `reading_rhythm_test` (5); no dedicated statistics test |
| Navigation | ✓ "Statistics" section is visible and functional |

There is no analytics *engine*. The Statistics section computes a live word count and compares it to a target. Everything in `NEXT.md` §10 (The Writer's Dashboard) is unbuilt.

---

## Progression Status

⚪ **NOT FOUND (as implementation) / 🔵 PLANNED ONLY (as intent)**

| Aspect | Status |
|---|---|
| Achievements | ⚪ 2 hits, both documentation (`authoros-2-master-plan.md`, `cross-system-integration-phase-1-implementation-map.md`) |
| Writing goals | 🟡 `project.wordGoal` only — a single project-level target |
| Progression | ⚪ 10 hits, all either research docs or the unrelated word "progression" in plot fixtures |
| Rewards / Badges | ⚪ `_badge(...)` in the codebase is a **UI chip helper** (e.g. the sprint countdown badge and the hardcoded `'3'` alert badge), not a reward system |
| Persistence | ⚪ None |
| Tests | ⚪ None |
| Navigation | ⚪ No entry point |

`docs/cross-system-integration-phase-1-implementation-map.md:280` explicitly lists "Progression Phase 3" among **future** work.

---

## AI Status

⚪ **NOT FOUND — and this is an intentional product decision, not a gap.**

`NEXT.md` §9 (lines 533–552) is titled **"AI-FREE IS ACTUALLY A FEATURE"** and states:

> *"AuthorOS doesn't need to write your book for you. It gives you the tools to write it yourself. That becomes a differentiator. And it means we can build incredibly sophisticated tools without needing generative AI."*

| Aspect | Status |
|---|---|
| AI architecture | ⚪ None |
| AI writing assistance | ⚪ None |
| AI tools | ⚪ None |
| AI provider abstraction | ⚪ None |
| Dependencies | ⚪ No AI/LLM package in `pubspec.yaml` |

Searches for `openai`, `anthropic`, `llm`, `gpt`, and standalone `ai` across `lib/` returned only false positives (`.map(`, `completion` as in *character profile completion percentage*, `replaceAllMapped`).

`docs/world-studio-phase-1-implementation-map.md:168` independently confirms the stance: *"No graphical map editor, simulation, **AI generation**…"*

**Recommendation:** record AI as an explicit non-goal in the master status table rather than as missing work.

---

## Duplicate / Dead Architecture Findings

*Reported only. Nothing was deleted or modified.*

### 1. Three separate `ThemeData` builders

| Location | Status |
|---|---|
| `lib/main.dart:243` `_buildThemeData()` | **LIVE** — this is what the app uses |
| `lib/theme/flutter/authoros_theme.dart:52` `AuthorOsTheme.toThemeData()` | Built + tested, **never called by the app** |
| `lib/main.authorstudio.backup.dart:21` | Dead file |

### 2. Dead backup file

`lib/main.authorstudio.backup.dart` (838 lines) — imported by nothing, referenced by nothing. Contains an older shell, an older `ThemeData`, and the only "Beat sheets, arcs, and planning connections" string in the repository. It still compiles as part of the package.

### 3. Fully orphaned World Studio

`lib/world_studio.dart` (1,642 lines) — `WorldStudioService`, `WorldStudioWorkspace`, `WorldStudioView`, `WorldTemplateRegistry`, `WorldRecordTemplate`, `WorldRecordDraft`, plus dialogs. **Not imported by any file in `lib/`.** Its only importer is `test/world_studio_test.dart` (6 tests). Superseded by `world_workspace.dart`, which is what navigation actually renders. Two independent World Studio implementations exist in the tree; one is unreachable but still tested.

### 4. Effectively-dead Story Codex view

`lib/story_codex.dart` (1,080 lines) — `StoryCodexView`, `CodexEntryView`, editor and connection dialogs. Re-exported by `release_destinations.dart:17`, but `StoryCodexView` is referenced only by the **orphaned** `world_studio.dart:911` and two test files. The live Codex is `StoryCodexWorkspace` (`story_codex_workspace.dart`). Two independent Story Codex implementations.

### 5. Two parallel persistence architectures

| Drift / SQLite | SharedPreferences JSON blobs |
|---|---|
| `character_service`, `character_studio`, `continuity_actions`, `core/branch_service`, `core/connection_engine`, `core/record_inspector`, `core/record_service`, `core/safe_delete_service`, `core/universal_search`, `core/version_audit_service`, `manuscript_store`, `migrations/legacy_reference_migration`, `plot_service`, `story_codex`, `story_codex_service`, `story_codex_workspace`, `timeline_service`, `world_service`, `world_studio`, `world_workspace` | `backup_health`, `main` (profile, theme, projects, notes, ideas, research), `manuscript_export`, `manuscript_store`, `onboarding`, `reading_rhythm`, `release_destinations`, `sync/sync_store`, `theme/flutter/authoros_theme`, `theme/theme_persistence`, `timeline`, `visual_planning` |

`manuscript_store.dart` appears in both — it is the one component bridging the two.

### 6. Two record/relationship vocabularies

The modern `AuthorRecord` + `RecordLink` + `ConnectionTypeRegistry` stack coexists with legacy shapes such as `StoryCodexEntry.relationships` (a `Map<String, String>` in `release_destinations.dart:96`). `lib/migrations/` (`legacy_reference_migration.dart`, `legacy_reference_adapters.dart`, `legacy_reference_models.dart`, `legacy_connection_slice.dart`) exists specifically to bridge them, and is tested — so this is a *managed* duplication, not an accident.

### 7. Finished services with no UI consumer

| Service | Lines | Imported by (in `lib/`) |
|---|---|---|
| `PlotService` | 722 | **nothing** |
| `TimelineService` | 785 | `continuity_actions.dart` only |
| Entire `lib/theme/` engine | ~1,300 | **nothing outside `lib/theme/`** |

### 8. Unused dependency

`isar_community`, `isar_community_generator`, `isar_community_flutter_libs` are in `dev_dependencies`, and `tool/libisar.dll` + `tool/storage_benchmark.dart` remain — evidence of an Isar storage evaluation superseded by Drift. The Linux/Windows plugin registrants were regenerated for `isar_community_flutter_libs` in commit `3ef69d4`, so this still affects builds.

### 9. Cosmetic UI affordances

- `Ctrl+K` label (`main.dart:1447`) with no key binding — no command palette exists.
- Hardcoded `badge: '3'` on the Alerts button (`main.dart:1452`) — no notification system exists.
- Accent selection in Settings is collected, passed, and then **discarded** (`main.dart:264`).

### 10. Dead startup preference

`author_studio.profile_setup_complete` is written by `_completeProfile()` and `_login()` but never read — `_loadStartupState()` hardcodes `profileComplete = false`. Every launch requires re-passing the profile screen.

### 11. Build artifacts committed to the repository

`dist/` contains two full Windows builds (`AuthorStudio-1.0.0-windows-x64/` and `IndieAuthorOS-1.0.0-windows-x64/`) plus their `.zip` archives — two differently-named packagings of the same product. This is the bulk of the 120 MB directory size.

### 12. Legacy product still in history

Commit `6d52f8c` deleted an entire prior HTML/CSS/JS implementation (`index.html`, `js/modules/{manuscript,characters,world,plot,timeline,chapters,notes,ideas,projects,search,settings,statistics}.js`, `css/*`). That generation's module list closely matches today's `StudioSection` enum — useful lineage context, no longer present in the tree.

---

## Git History Findings

| System | Exists in history? | Committed? | Later deleted? | Docs only? | Other branch? |
|---|---|---|---|---|---|
| **Map Studio** | **No** | No | No | **Yes** | No |
| **Community** | **No** | No | No | **Yes** | No |
| **Analytics** | Partly (word-count statistics) | Yes | No | Mostly | No |
| **Progression** | **No** | No | No | **Yes** | No |
| **Theme Engine** | Yes | Yes (`lib/theme/`) | No | Phase 2 integration is docs-only | No |
| **Universal Records** | Yes (under other names) | Yes | No | Brief's class names are docs-only | No |
| **Startup / Login** | Yes | Yes | No | Intended flow is docs-only | No |

Supporting evidence:

- Only **two** branches exist (`main`, `claude/authoros-repository-audit-xv1trv`) and they point at the same commit. **There is no hidden work on another branch.**
- `git log --all --diff-filter=D --name-only` shows **no Dart file has ever been deleted** from `flutter-author-studio-v1/`. Nothing was built and removed.
- The only large deletion in history is the pre-Flutter HTML/JS app at `6d52f8c`.
- Repository lineage: commit `64e5f7c` merges from `github.com/kjinkinsight-ctrl/Indie-Author-OS`; `85016a7` is "Initial AuthorOS commit"; `60cb323` is "feat(world): rebuild World Studio on the Universal Record workspace" — which is when `world_workspace.dart` superseded `world_studio.dart`, explaining orphan #3.
- Commits `96329e8` ("g"), `66c7328` ("y"), `ca15674` ("latest app upgrades"), `5022e4a` ("commit all changes") are bulk checkpoints, so per-feature attribution before `85016a7` is unreliable.

---

## Test Evidence

### Totals

| Metric | Value |
|---|---|
| Test files | 51 (+10 fixtures) |
| `test()` / `testWidgets()` declarations | **453** |
| `group()` blocks | 28 |
| Lines of test code | 18,797 |
| **Tests executed during this audit** | **0 — Flutter/Dart SDK is not installed in this environment** |

`which flutter` and `which dart` both return not-found. Running `flutter test`, `flutter analyze`, or `flutter build web --release` was impossible. Installing the SDK or running `pub get` would have modified the tree and was therefore out of scope. **No test result in this document is an observed pass — all test counts are static declaration counts.**

### Tests by subsystem

| Subsystem | Files | Tests |
|---|---|---|
| Theme Engine | `theme_engine_test`, `theme_flutter_adapter_test`, `settings_theme_test` | 48 + 16 + 10 = **74** |
| World Studio | `world_workspace_test`, `world_phase2_test`, `world_service_test`, `world_continuity_test`, `world_studio_test` | 23+24+6+11+6 = **70** |
| Story Codex | `story_codex_workspace_test`, `story_codex_phase2_test`, `story_codex_phase1_test`, `story_codex_service_test`, `story_codex_widget_test`, `codex_continuity_test` | 31+21+6+6+2+7 = **73** |
| Records / core | `record_inspector_test`, `record_service_test`, `record_types_test`, `connected_domain_test`, `connection_engine_test`, `connection_types_test`, `template_engine_test`, `universal_search_test`, `safe_delete_service_test` | 15+5+5+5+1+2+2+9+7 = **51** |
| Cross-system | `cross_system_integration_test` | **17** |
| Continuity | `continuity_test`, `continuity_actions_test`, `impact_trace_test` | 12+8+3 = **23** |
| Branching | `branch_service_test`, `branch_engine_test` | 5+5 = **10** |
| Versioning | `version_audit_service_test`, `version_audit_model_test` | 9+1 = **10** |
| Character Studio | `character_workspace_test`, `character_domain_test`, `character_studio_test` | 8+6+2 = **16** |
| Timeline | `timeline_domain_test`, `timeline_test` | 8+5 = **13** |
| Plot | `plot_service_test`, `visual_planning_test` | 8+2 = **10** |
| Manuscript | `manuscript_store_test`, `manuscript_export_test`, `manuscript_studio_test` | 4+4+1 = **9** |
| Migration | `legacy_reference_migration_test`, `legacy_fixture_contract_test` | 10+5 = **15** |
| Persistence / archive | `authoros_database_test`, `authoros_archive_test`, `backup_health_test` | 7+6+5 = **18** |
| Sync | `project_sync_test`, `project_sync_service_test`, `sync_store_test` | 3+3+3 = **9** |
| Shell / startup | `widget_test`, `welcome_page_test`, `reading_rhythm_test` | 24+6+5 = **35** |

### Coverage gaps relevant to this audit

- **Map Studio: 0 tests** (nothing to test).
- **Community: 0 tests.**
- **Progression / Achievements: 0 tests.**
- **Analytics: 0 dedicated tests.**
- Theme Engine is the **most-tested subsystem in the repository (74 tests) while being entirely unused by the application** — the tests validate a library, not the product's behaviour.
- `world_studio_test.dart` (6 tests) is the only thing keeping the orphaned `world_studio.dart` alive.

---

## Build Evidence

### Local verification

**Not possible.** No Flutter or Dart SDK in this environment. Per the audit constraints, no package was installed and no command that would modify the tree was run.

Three stale marker files exist at the app root from a previous machine, each containing only `exit_code=0`:
`flutter_version.exit.txt`, `flutter_devices.exit.txt`, `flutter_build_windows.exit.txt`. These indicate a Windows build succeeded on the author's machine at some past point; they carry no date, commit, or output and are **not** evidence for the current commit.

### CI evidence — every run has failed

`.github/workflows/dart.yml` on the repository root.

| Run | Commit | Subject | Conclusion |
|---|---|---|---|
| 8 | `88fbdce` | feat(sync): write project saves to sync_records | **failure** |
| 7 | `3ef69d4` | feat(profile): liquid aurora | **failure** |
| 6 | `96329e8` | g | **failure** |
| 5 | `66c7328` | y | **failure** |
| 4 | `ca15674` | latest app upgrades | **failure** |
| 3 | `64e5f7c` | Merge branch 'main' | **failure** |
| 2 | `e3ffcaf` | Merge PR #2 | **failure** |
| 1 | `93c97ac` | Create dart.yml | **failure** |

**8 of 8 runs failed, including the commit this audit covers.** Every run completed in ~3–4 seconds. Job logs have expired (HTTP 404), so the failure text could not be retrieved.

**Most likely cause (inference, clearly labelled as such — not verified against logs):** the workflow is GitHub's stock Dart template. It runs `dart pub get`, `dart analyze`, and `dart test` **from the repository root**, but the repository root has **no `pubspec.yaml`** (confirmed: `ls pubspec.yaml` → no such file). The Flutter project is one directory down in `flutter-author-studio-v1/`. A ~4-second failure is consistent with `dart pub get` failing immediately. The workflow also uses `dart test` rather than `flutter test`, which cannot run this project's widget tests even if the path were corrected. The template's own comment acknowledges this: *"Note that Flutter projects will want to change this to 'flutter test'."*

**Conclusion: there is no green build or green test evidence anywhere in this repository for any commit.** The 453 tests may well pass locally, but nothing in the repository demonstrates it.

---

## Known Uncertainties

1. **No test run was performed.** All test figures are static counts of `test(`/`testWidgets(` declarations. Actual pass/fail state at commit `88fbdce` is unknown.
2. **No analyzer run was performed.** Dead code, unused imports, and type errors in unreachable files (`main.authorstudio.backup.dart`, `world_studio.dart`) would surface under `flutter analyze` but were not checked.
3. **CI failure cause is inferred, not confirmed.** Logs returned HTTP 404 (expired). The root-`pubspec.yaml` reasoning is strong but unverified.
4. **`.exit.txt` marker files** prove nothing about the current commit.
5. **Runtime behaviour was not observed.** The startup flow is traced from source; the app was never launched. A widget whose code path looks reachable could still fail at runtime.
6. **`showWelcome`** is a constructor parameter on `AuthorStudioApp`; production `main()` uses the default (`true`). Tests pass `false`. If a launch configuration overrides it, the welcome page would be skipped.
7. **Some very large files were sampled, not read line by line** — notably `world_workspace.dart` (5,235), `story_codex_workspace.dart` (4,009), and `release_destinations.dart` (3,763). A small feature buried inside one of them could have been missed. Map and Community were verified by exhaustive keyword search plus git history, so those conclusions are not affected.
8. **`docs/` location.** The brief specified `docs/authoros-repository-reality-audit.md`. There is no `docs/` directory at the repository root; all AuthorOS documentation lives in `flutter-author-studio-v1/docs/`. This file was placed there to match the existing convention and to avoid creating a new top-level directory. Move it if the root was intended.
9. **`indiauthors-platform` was audited only for Community-related concerns**, as that is the only audited system it could plausibly host. Its licensing, entitlement, catalog, and download subsystems were not assessed.
10. **Hardcoded Supabase credentials.** `lib/supabase_service.dart:10-11` contains a default project URL and anon/publishable key in source. Supabase publishable keys are designed to be client-visible and this is normal practice when RLS is enforced — but `supabase/schema.sql` was not audited for row-level-security policies, so whether that assumption holds here is unverified. Flagged for the owner's awareness only.

---

## Required Master Status Table

Legend: ✓ confirmed · ~ partial · — absent · ? uncertain

| System | Core | UI | Persistence | Tests | Integrated | Status |
|---|---|---|---|---|---|---|
| Foundation | ✓ | ✓ | ✓ | ✓ | ✓ | 🟢 IMPLEMENTED |
| Theme Engine | ✓ | — | ✓ | ✓ | **—** | 🟡 PARTIAL (Phase 1 only; not wired to the app) |
| Universal Records | ✓ | ✓ | ✓ | ✓ | ~ | 🟡 PARTIAL (capability yes; brief's class names no; Plot + Timeline outside it) |
| Manuscript Studio | ✓ | ✓ | ✓ | ✓ | ✓ | 🟢 IMPLEMENTED (plain text editor only) |
| Character Studio | ✓ | ✓ | ✓ | ✓ | ✓ | 🟢 IMPLEMENTED |
| World Studio | ✓ | ✓ | ✓ | ✓ | ✓ | 🟢 IMPLEMENTED (+1 orphaned duplicate) |
| Timeline Studio | ✓ | ✓ | ~ | ✓ | ~ | 🟡 PARTIAL (rich UI on legacy store; `TimelineService` unwired) |
| Plot Studio | ✓ | ~ | ~ | ✓ | **—** | 🟡 PARTIAL (`PlotService` has no UI consumer) |
| Map Studio | — | — | — | — | — | 🔵 PLANNED ONLY |
| Research Studio | ~ | ~ | ✓ | — | ~ | 🟡 PARTIAL (side panel only; not a studio) |
| Login / Users | ~ | ✓ | ~ | ✓ | ~ | 🟡 PARTIAL (single profile; no authentication) |
| Community | — | — | — | — | — | 🔵 PLANNED ONLY |
| Analytics | ~ | ✓ | ~ | — | ~ | 🟡 PARTIAL (word count + goal bar only) |
| Progression | — | — | — | — | — | ⚪ NOT FOUND (planned in docs) |
| AI | — | — | — | — | — | ⚪ NOT FOUND — **intentional non-goal** (`NEXT.md` §9) |

### Supplementary system inventory

| System | Status | Evidence |
|---|---|---|
| Application Shell | 🟢 | `AuthorStudioShell`, 15 sections |
| Navigation | 🟢 | Desktop + mobile, all destinations real |
| Storage / Persistence | 🟢 | Drift/SQLite + SharedPreferences (dual) |
| Project Management | 🟢 | `_ProjectsStudioView` |
| Story Library | 🟡 | Projects list; no library/series concept |
| Settings | 🟢 | `SettingsStudioView` |
| Backup & Export | 🟢 | Archive + backup health + PDF (PDF-only) |
| Notifications | ⚪ | Hardcoded `'3'` badge; no system |
| Command Palette | ⚪ | Cosmetic `Ctrl+K` label; no binding |
| Chapter Management | 🟢 | `ChapterStudioView` |
| Scene Management | 🟢 | In Manuscript Studio |
| Rich Text Editor | ⚪ | Plain `TextField` |
| Word Goals | 🟡 | Project-level `wordGoal` only |
| Writing Statistics | 🟡 | Snapshot only |
| Writing Sprint Timer | 🟡 | Real countdown, no controls |
| Focus Mode | 🟢 | `focus-mode-toggle` |
| Plot Board | 🟡 | Kanban via `VisualPlanningView` |
| Story Grid | ⚪ | Zero hits |
| Beat Sheets | ⚪ | One string in a dead file |
| Story Arcs | 🟡 | `hasArc` connection type only |
| Character Profiles | 🟢 | 3 templates + custom |
| Character Relationships | 🟢 | `RecordLink` / `ConnectionEngine` |
| Character↔Timeline | 🟡 | Cross-nav only; live Timeline is off-stack |
| World Records | 🟢 | 7 deep world types |
| Locations / Factions / Lore | 🟢 | Built-in record types |
| Items | 🟡 | Connection types only; no item record type |
| World Relationships | 🟢 | `RecordLink` |
| Research Records / Sources / Notes / References | 🟡 | Notes ✓ (own section); references ~ (title/detail/tag); sources ⚪ |
| Opening / Welcome Page | 🟢 | `WelcomePage` (position in flow is wrong) |
| User Preferences / Session | 🟡 | SharedPreferences; session not persisted across launches |
| Multiple User Profiles | ⚪ | Single profile only |

---

## Answer To The Original Confusion

Answered strictly from repository contents, not from any roadmap.

### "Should I currently see a Map Studio icon?"

**No.** There is no Map Studio icon, and there should not be one. `StudioSection` (`main.dart:1137`) has no map member, so no icon is rendered. There is no Map Studio code to open — no `MapStudio` class, no map file, no map canvas, no terrain system, no overlays, no simulation, no export. Git history confirms no map source file has ever been committed on any branch. **If you are seeing a Map Studio icon, it is not coming from this commit of this repository.**

### "Should I currently see a Community icon?"

**No.** Same situation. No Community icon, no Community code, no Community backend, in either the Flutter app or the platform project. The word "community" survives in one roadmap summary string in the platform's *future ideas* lane and in the master plan's explicitly *optional* `M8` milestone.

### "For every Studio we previously planned, which ones should I actually see right now?"

**You should see exactly 15 navigation items — and only these.**

**WORKSPACE:** Dashboard · Search · Statistics · Backup · Projects · Ideas · Manuscript
**STORY:** Chapters · Characters · Story Codex · World · Plot · Timeline · Notes
**STANDALONE:** Settings

| Planned Studio | Should you see it now? | What you actually get |
|---|---|---|
| Manuscript Studio | **YES** | "Manuscript" → full studio, most complete in the app |
| Character Studio | **YES** | "Characters" → `CharacterBoardView`, record-backed |
| World Studio | **YES** | "World" → `WorldWorkspace`, record-backed |
| Story Codex | **YES** | "Story Codex" → `StoryCodexWorkspace`, record-backed |
| Timeline Studio | **YES** | "Timeline" → rich UI, but on the legacy SharedPreferences store |
| Plot Studio | **YES, by label** | "Plot" → a scene Kanban board, **not** the `PlotService` Plot Studio |
| Research Studio | **NO — not as a studio** | A side panel inside Manuscript only |
| **Map Studio** | **NO** | Does not exist |
| **Community** | **NO** | Does not exist |
| **Visual Studio / World Board** | **NO** | Planned only |
| **Relationship Studio / Lineage Canvas** | **NO** | Planned only (the *data* exists via `RecordLink`; no canvas) |
| **Book Studio** | **NO** | Planned only |
| **Series Studio** | **NO** | Planned only |
| **Author Journey / Progression** | **NO** | Planned only |
| **Analytics dashboard** | **PARTIALLY** | "Statistics" exists — word count + goal bar, nothing more |

**The single most useful correction:** the roadmap describes a product with roughly a dozen studios. The application has six real ones (Manuscript, Characters, Story Codex, World, Plot-as-Kanban, Timeline) plus supporting sections. Map Studio and Community are the two largest items that exist purely as prose.

---

## Recommended Next Build Order

Based **only** on what is actually present. Ordered so that each step closes a gap the repository already paid for, before any new surface area is added.

### Tier 0 — Make the truth visible (hours, not days)

1. **Fix CI.** Point `dart.yml` at `flutter-author-studio-v1/` and switch to `flutter test` / `flutter analyze`. Nothing below can be trusted until one build is green. This is the single highest-leverage change in the repository: 453 tests exist and **zero** are known to pass.
2. **Establish a baseline.** Record the first `flutter test` and `flutter analyze` result in the repository so future audits have ground truth.

### Tier 1 — Cash in work already finished but unreachable

3. **Wire the Theme Engine into the shell (Theme Engine Phase 2).** ~1,300 lines and 74 tests are already written and unused. Replace `main.dart`'s `AppThemePreset` / `_buildThemeData()` with `ThemeEngine` + `ThemePersistence`, install `StudioThemeScope` in `AuthorStudioShell`, and delete the duplicate path. Also fixes the inert accent selector.
4. **Wire `PlotService` to a UI.** 722 lines + 761 lines of record types, fully tested, consumed by nothing. Either back `VisualPlanningView` with it or build the Plot Board the phase-1 doc describes.
5. **Migrate Timeline Studio onto `TimelineService`.** The UI is already good; moving it off SharedPreferences onto the record/Drift stack brings Timeline into the connection engine and makes character↔timeline links real.

### Tier 2 — Fix the flow the owner actually asked about

6. **Reorder startup to Login → Profile → Opening Page → Workspace.** Currently inverted. This is a reordering of existing screens, not new construction.
7. **Read `author_studio.profile_setup_complete` at startup.** One-line-class fix; stops returning users re-passing the profile screen every launch.
8. **Decide what "Login" means.** Today it authenticates nothing, and Google sign-in is buried in Settings. Either promote real Supabase auth to the login screen, or rename the screen to "Select Profile" so it stops implying security it does not provide.
9. **Multi-profile storage**, if genuinely wanted. Required before "Select User", "Add New User", or "Continue with Email" can mean anything. This is real new work — the current store holds one name and one email.

### Tier 3 — Repay debt before adding surface area

10. **Resolve the duplicates.** Decide the fate of `world_studio.dart` (1,642 orphaned lines + 6 tests), `story_codex.dart` (1,080 lines), and `main.authorstudio.backup.dart` (838 dead lines). Roughly 3,500 lines of unreachable code currently ship in the package.
11. **Converge persistence.** Pick Drift as the single record store and migrate Projects, Notes, Ideas, and Research off SharedPreferences. `lib/migrations/` already provides the pattern.
12. **Drop the unused Isar dependency**, or document why it stays.
13. **Remove `dist/` from version control.** Two committed Windows builds dominate the repository's size.

### Tier 4 — Honest small wins

14. **Make the sprint timer controllable** (start/pause/reset). The countdown already works; it just has no button.
15. **Either build the command palette or drop the `Ctrl+K` label**; either build notifications or drop the hardcoded `'3'` badge. Both currently promise features that do not exist.
16. **Add a second export format** (DOCX or EPUB). PDF export is solid and the pattern is established.

### Tier 5 — Genuinely new systems (only after Tiers 0–3)

17. **Analytics / progress tracking** — needs a session-recording layer that does not exist; unlocks streaks, heatmaps, goals, and progression together.
18. **Map Studio Phase 1 (annotation)** — greenfield. Follow the repository's own two-level plan (annotate an imported image first, link markers to existing `location` records), not a six-phase plan that exists nowhere in this repository. `location` records already carry `terrain` and `MapMarker` fields, which is a real starting point.
19. **Community** — greenfield, and the master plan itself gates it on identity and moderation being ready. Correctly last.

**On AI:** no build order entry. `NEXT.md` §9 makes AI-free an intentional differentiator. Treat it as a non-goal unless the owner explicitly reverses that decision.

---

## Audit Boundary Statement

This audit made **no** functional change to AuthorOS. No source file, test, asset, configuration file, dependency, schema, platform file, or branch was created, modified, renamed, or deleted. No commit and no push was made as part of producing this document. No package was installed and no command that would alter the working tree was executed.

The repository owner decides what gets built next.
