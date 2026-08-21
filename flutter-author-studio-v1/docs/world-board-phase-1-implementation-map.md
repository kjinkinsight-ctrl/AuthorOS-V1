# World Board Phase 1 — Personal World Foundation

## Repository reality discovered

Audited before writing any code.

| Area | What actually exists |
| --- | --- |
| Projects | **AuthorOS is single-project.** `OnboardingStore` persists exactly one `StarterProject` under `author_studio.starter_project`. The Projects Studio (`_ProjectsStudioView` in `lib/main.dart`) shows a hardcoded demo list (`Ash and Lanterns`, `City of Quiet Bridges`) and is **not** a project store. |
| Manuscripts | `ManuscriptStore` + `ManuscriptProjectSummary` own word, chapter, and scene counts, persisted in SharedPreferences per project. One manuscript per project. |
| Characters | Project-scoped `AuthorRecord`s of type `character`. `CharacterService` owns creation and connections; it has no list-all method, so `CharacterBoardView` reads `repository.recordsByTypeAndScope(typeId: 'character', ...)` directly. |
| World | `WorldService.worldRecords()` returns the whole World domain — locations, cosmic bodies, maps, routes, markers — as Universal Records. A real world model already exists. |
| Timeline | `TimelineService.query.all()` over `timeline-record` types. Completed Timeline Studio. |
| Plot | `PlotService.query.all()` over `plot-record` types. Completed Plot Studio. |
| Progress / goals | `StarterProject.wordGoal` plus `ManuscriptProjectSummary.progressAgainst()`. **There is no goal persistence system** beyond the project's word goal. |
| Statistics | `StatisticsStudioView` already derives words/goal/progress from `ManuscriptStore`. |
| Activity | `VersionAuditService.getAuditHistory()` over the shared audit trail. No separate activity log exists. |
| Navigation | `StudioSection` enum + `StudioSectionData` extension in `lib/main.dart`; a `WORKSPACE` group and a `STORY` group, both listed twice (`_AuthorStudioShellState` and `_DesktopNavigation`). Sections are addressed by identity via `sections.indexOf(...)`, not by hardcoded index. |
| Theme Engine | `ThemeEngine → ResolvedTheme → StudioThemeScope`. Studios read `scope.color(ThemeColorRef.…)` / `scope.text(ThemeTextRole.…)`. `StudioId` carries per-Studio overrides; `ThemeRegistry.standard()` currently registers none. |
| Persistence | One Drift database (`AuthorOsDatabase`, schema v8) behind `DriftConnectedDomainRepository`. Views take an optional `repository` and tests inject an in-memory one. |
| Studio conventions | Studios define their own destination enum (`CharacterWorkspaceDestination`, `SearchDestination`) and the shell maps it onto `StudioSection`. Studios never import `main.dart`. |

**No World Board infrastructure existed.** Nothing named `world_board` was present in `lib/`, `test/`, or `docs/`.

## Files created

- `lib/world_board/world_board_models.dart`
- `lib/world_board/world_board_service.dart`
- `lib/world_board/world_board_sections.dart`
- `lib/world_board/world_board_view.dart`
- `test/world_board_service_test.dart`
- `test/world_board_view_test.dart`
- `test/world_board_navigation_test.dart`
- `docs/world-board-phase-1-implementation-map.md`

## Files modified

- `lib/main.dart` — one enum member, one label, one icon, the section added to both workspace-group lists, two imports, and one routing arm.
- `lib/theme/theme_tokens.dart` — one line: `StudioId.worldBoard`.

## Files deleted

None.

## Existing services reused

| Section | Source | Reused, not rebuilt |
| --- | --- | --- |
| Projects | `StarterProject` handed in by the shell | The shell already owns the active project. |
| Manuscript | `ManuscriptStore.loadStudio()` | Seeded exactly as `StatisticsStudioView` seeds it, so both screens report the same word count. |
| Characters | `repository.recordsByTypeAndScope(typeId: 'character')` | Identical to the Characters Studio's own query, so the counts can never disagree. |
| Worlds | `WorldService.worldRecords(includeArchived: false)` | No second world model was introduced. |
| Timelines | `TimelineService.query.all()` | Timeline Studio's own query service. |
| Plot | `PlotService.query.all()` | Plot Studio's own query service. |
| Activity | `VersionAuditService.getAuditHistory()` | The shared audit trail; no activity log was created. |
| Progress | `StarterProject.wordGoal` + manuscript word count | The only goal information that exists. No goal store was built. |

## New World Board architecture

```text
Existing services            Aggregation                Presentation
─────────────────            ───────────                ────────────
ManuscriptStore      ┐
repository (records) │
WorldService         ├──►  WorldBoardService  ──►  WorldBoardSnapshot  ──►  WorldBoardView
TimelineService      │        (read only)                                     ├─ WorldBoardHeader
PlotService          │                                                        ├─ metric grid
VersionAuditService  ┘                                                        ├─ WorldBoardProjectPanel
                                                                              ├─ WorldBoardRelationshipMap
                                                                              └─ WorldBoardActivityPanel
```

- `world_board_models.dart` is plain Dart: sections, metrics, branches, activity, project context, formatting. It owns no storage and declares no record type.
- `world_board_service.dart` is the thin orchestration layer. Every figure it returns comes back from a service that already owns that domain.
- `world_board_sections.dart` and `world_board_view.dart` are presentation only.

The board follows the repository's directory convention for multi-file subsystems (`lib/theme/`, `lib/core/`, `lib/sync/`) rather than the single-file convention used by the smaller Studios.

## Navigation changes

- `StudioSection.worldBoard`, label `World Board`, icon `Icons.hub_outlined` — a hub of connections, deliberately distinct from World Studio's `Icons.public_outlined` globe.
- Placed in the existing `WORKSPACE` group directly after `Dashboard`. The `STORY` group is untouched.
- The navigation rail itself was not redesigned; the section joins the two existing group lists.
- The board never names `StudioSection`. It emits `WorldBoardDestination`, and `_SectionView` maps it, exactly as it already does for `CharacterWorkspaceDestination` and `SearchDestination`.

## Data sources

Every number on the board is read from a live service. Nothing is fabricated to make the UI look populated.

- **Projects** — `1`. That is the honest count: AuthorOS persists one project.
- **Manuscript** — word count as the headline, `N chapters · M scenes` beneath.
- **Characters / Worlds / Timelines / Plot** — record counts, with deleted records excluded exactly as each Studio excludes them.
- **Current project** — title, type, genre, words against goal, percent, words remaining.
- **Relationship map** — up to three real record titles per branch, most recently updated first, plus `+N more`.
- **Recent activity** — up to six audit entries, newest first, with the summary the owning service wrote.

## Theme integration

- Every colour and type style resolves through `StudioThemeScope`. There is no `ThemeData(...)`, no `Colors.*`, no `Color(0x...)`, and no `Theme.of(context)` anywhere in `lib/world_board/`. A test enforces this against the source.
- The view nests a `StudioThemeScope` carrying `StudioId.worldBoard`, so a future theme can accent the board without any widget below reaching for a colour of its own. A test proves an override reaches the rendered surface.
- Verified rendering under light, dark, system, high contrast, and reduced intensity. All five transformations are the engine's; the board only renders their result.

## Empty states

Every category has a headline, a body, and a way into the Studio that fills it.

| Category | Empty state |
| --- | --- |
| Projects | No project yet — Create a project to open your AuthorOS world. |
| Manuscript | No manuscript yet — Start drafting in Manuscript Studio. |
| Characters | No characters yet — Build your cast in Characters Studio. |
| Worlds | No world yet — Your world-building workspace will live here. |
| Timelines | No timeline yet — Start organising your story chronology. |
| Plot | No plot records yet — Build your story structure in Plot Studio. |
| Activity | No activity yet. Anything you change in a Studio shows up here. |

An empty tile shows its empty headline instead of a confident `0`, and an empty branch on the relationship map offers a button into the owning Studio.

## Privacy

The board reads only local, project-scoped author data. It has no notion of sharing, publishing, profiles, or any outward-facing surface, and no code path that could produce one. `WorldBoardSnapshot` is a private-world model; a Community layer would need a separate, explicitly shared model — never this one.

## Limitations

1. **Projects is `1` by construction.** Until AuthorOS persists more than one project, a project count is not a meaningful metric. The tile is honest rather than impressive.
2. **Worlds counts the whole World domain** — locations, maps, routes, markers — because that is what `WorldService` defines as a world record. There is no separate "world" entity to count.
3. **No interactive graph.** The relationship view is a one-level tree of cards and connector rules. The graph belongs to Phase 2.
4. **Opening the board can migrate a legacy manuscript.** `ManuscriptStore.loadStudio()` writes when it migrates legacy storage — the same behaviour the Statistics Studio already has. Reusing it was preferred over building a second manuscript read path.
5. **One error state, not six.** A failure in any source shows one retry card, matching the Timeline and Plot Studios rather than inventing a per-section failure model.
6. **The shell cannot inject a repository into a Studio.** This is pre-existing (see below) and limits how far a shell-level widget test can drive the board.

## Pre-existing issues found

Two were observed against the Timeline Studio as it stood at the start of this
milestone and have since been **resolved by the Timeline Studio reconciliation
pass** that landed concurrently (`16813f9`), not by this work:

- ~~`test/timeline_studio_view_test.dart` — 3 tests timing out after 10 minutes
  each.~~ **Resolved.** The cause was diagnosed here: the tests constructed
  `TimelineStudioView(project: ...)` with no `repository`, so the view fell back
  to the production `authorOsRepository`, whose `drift_flutter` connection never
  opens inside `flutter_test`. (Mocking `path_provider` is not sufficient — the
  background isolate still hangs.) The reconciled test file injects an in-memory
  repository, which is exactly that fix.
- ~~`_SectionView` renders non-manuscript Studios inside a
  `SingleChildScrollView`, so a section using `Expanded` inside a `Column` gets
  unbounded constraints.~~ **No longer reproduces.** Verified by mounting the
  reconciled `TimelineStudioView` inside an unbounded `SingleChildScrollView`:
  no exception. The World Board is a self-measuring column regardless, which is
  the right shape for that host.

Still open, and untouched:

- **`_ProjectsStudioView` and the Dashboard's "Ideas" tile contain hardcoded demo values.**
- **`tool/storage_benchmark.dart` has analyzer errors** (`isar_community` is not a dependency).

## Verification

Run against the merged tree, after the Timeline Studio reconciliation landed.

| Check | Result |
| --- | --- |
| `flutter test` | **557 passed, 0 failed** |
| World Board tests specifically | 48 passed (24 service/architecture, 17 view/theme/empty-state, 7 navigation) |
| `flutter analyze` | 77 issues, **0 from `lib/world_board/`**; every remaining issue pre-exists in `tool/`, `test/`, and other Studios |
| `flutter build web --release` | passed |
| `flutter build windows --release` | passed |
| `git diff --check` | clean |

The pre-work baseline was 494 passed / 3 failed.

## Future architecture — roadmap

### Phase 1 — Personal World Foundation *(this milestone)*
The private board, its aggregation layer, real counts, project context, a one-level relationship view, recent activity, and empty states.

### Phase 2 — Interactive World Map
Turn the relationship tree into a real graph: pan, zoom, select, and traverse between projects, manuscripts, characters, worlds, timelines, and plots. Needs a layout engine and hit-testing; the data relationships Phase 1 established are the input.

### Phase 3 — World & Universe Integration
Surface the World domain in depth — locations, factions, cultures, magic systems, lore — and the connections between them, using the existing `ConnectionEngine` rather than a new relationship store.

### Phase 4 — Progress & Goals
Writing goals, milestones, deadlines, completion, and streaks. **This is the phase that may need a goal persistence system**; Phase 1 deliberately built none.

### Phase 5 — Advanced Story Intelligence
Cross-reference characters, scenes, timeline, and plot for continuity. `ContinuityAnalyzer` and `UniversalRecordInspector` already exist and should be the engine.

### Phase 6 — Author Dashboard
Fold the board, statistics, and progress into one complete personal command centre, and decide what remains of the current Dashboard.

### Phase 7 — Community Layer
Only after the private board is stable. Author profiles, optional public projects, achievements, challenges, shared statistics, activity.

**Privacy must be foundational.** The split is architectural, not a setting:

```text
PRIVATE AUTHOR DATA          OPTIONALLY SHARED DATA
        │                              │
        ▼                              ▼
  MY AUTHOROS WORLD            AUTHOROS COMMUNITY
```

These are two data layers, never one. A manuscript must never become public merely because Community exists; sharing must be an explicit, per-item, author-controlled act, and the shared model must be a separate type from `WorldBoardSnapshot`.

## Decisions made

- Reused every existing service rather than adding query methods to them, so the board changed no completed Studio.
- Matched the Characters Studio's record query exactly, so a character count can never differ between two screens.
- Kept `WorldBoardDestination` in the board and the `StudioSection` mapping in the shell, following the existing Character and Story Codex convention instead of importing `main.dart`.
- Added `StudioId.worldBoard` (one line) so the board is themeable by identity. It is inert until a theme defines overrides for it.
- Reported `1` project rather than inventing a project roster.
- Showed empty headlines instead of zeros, so a new world reads as an invitation rather than a failure.
