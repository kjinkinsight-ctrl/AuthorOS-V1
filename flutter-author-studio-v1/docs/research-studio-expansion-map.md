# Research Studio — Expansion Implementation Map

Status: implemented, pending review
Audited: August 21, 2026
Scope: the Research workspace over the existing Universal Record domain

## 1. What the audit found

The task brief described this milestone as an expansion of a completed
"Research Studio Phase 1". The repository does not contain one. Before this
change, `lib/` had **no Research Studio, no research service, no research
view, and no research tests**. What existed was:

| Surface | State before this milestone |
|---|---|
| `research-entry` record type | Present, but a bare `_children` entry in `built_in_record_types.dart` — a name and a category, inheriting `general-lore` and nothing else |
| `research` alias type | Present as a `_selectableAlias` for `research-entry` |
| Story Codex | Offers a `research` category (`story_codex_domain.dart`) and can create research records by hand |
| Analytics | Counts `research-entry` + `research` as `researchItemCount` |
| Universal Search | Routes both type ids to `SearchDestination.storyCodex` |
| `documents` connection type | Permits `research-entry` as a source to any target |
| Manuscript Studio | A `SharedPreferences`-backed research side panel (see §7) |
| Navigation | No Research section in the shell |
| Theme Engine | No `StudioId.research` |

So the honest description of the work: Research had a canonical record type
but no workspace. This milestone builds the workspace **on that existing type**
rather than introducing a new one.

## 2. Persistence architecture

Unchanged and canonical. Everything Research Studio reads or writes is an
`AuthorRecord` or a `RecordLink` in the AuthorOS Drift database, reached
through `RecordService`, `ConnectionEngine`, `UniversalSearchService`,
`VersionAuditService`, and `UniversalRecordInspector`.

No `ResearchDatabase`, `ResearchTable`, `ResearchStore`, or
`ResearchRepository` exists. Research Studio writes nothing to
`SharedPreferences`. `test/research_architecture_test.dart` enforces all of
this against the shipped source.

`research-entry` keeps its id, its `research` category, and its `general-lore`
base. The only change is that it now *declares* the fields Research Studio
needs instead of leaving them undeclared:

| Concern | Mechanism |
|---|---|
| Title | `AuthorRecord.title` (mirrored into the `name` field, as every type does) |
| Summary / notes | `summary`, `notes` — inherited from `general-lore` |
| Tags | `AuthorRecord.tags` |
| Created / updated | `AuthorRecord.createdAt` / `updatedAt` |
| Kind (Source / Note / Reference) | `researchKind` — `singleChoice` |
| Category | `researchCategory` — `singleChoice`, the twelve author-facing subjects |
| Status | `researchStatus` — `singleChoice` |
| Important / favourite | `researchImportant` — `boolean` |
| Source link / citation | `sourceUrl` (`url`), `citation` (`shortText`) |
| Archived | `AuthorRecordStatus.archived` — the shared record lifecycle |

Records written before this milestone carry none of the new fields. They stay
valid (every new field is optional) and read back as the type's declared
defaults — `Note` / `Other` / `New` / not important. That path is covered by
*a research-entry written before this milestone still validates*.

### Categories: why a field, not the type category

`RecordTypeDefinition.categoryId` is a **type** taxonomy (`research`, `lore`,
`plot`), shared by every record of that type. The author-facing categories in
the brief — World, History, Geography, … — vary *per record*, so `categoryId`
cannot express them. They are stored as a canonical `singleChoice` field on
the record instead. No parallel category store was created.

### Status: why `Archived` is not a stored option

`researchStatus` holds New / In Progress / Reviewed / Verified.
`Archived` is deliberately absent, because archiving is already an
`AuthorRecordStatus` transition owned by `RecordService`. Storing it twice
would give one concept two sources of truth. `ResearchService.statusOf` reads
the lifecycle first and the field second, so the author sees the five states
the brief asked for while only four are persisted.

## 3. Search, filtering, sorting

**Search** delegates to `UniversalSearchService.searchAll`, which queries the
existing `author_search` FTS index, then keeps the research hits. The index
already stores each record's title, its JSON-encoded fields, and its tags, so
title, summary, notes, category, kind, and tag matches all fall out of the one
query. FTS matching is case-insensitive. No second index exists.

**Filtering** is read-derived from the already-loaded records: shelves
(All / Sources / Notes / References / Important / Recently updated), category,
status, and tag. **Sorting** is likewise client-side —
`ResearchQueryService.sorted` over recently updated, recently created,
alphabetical, category, and importance. No new query infrastructure, index,
cache, or background worker was added.

## 4. Connections

`ResearchService.connect` calls the existing `ConnectionEngine`; no new
relationship system exists. The shared `documents` connection type already
allowed `research-entry → *`; its source list now spreads
`ResearchRecordTypes.recordTypeIds` so the `research` alias is permitted too —
the same pattern `appearsIn` already uses for `PlotRecordTypes.recordTypeIds`.
`relatedTo` (`*` ↔ `*`) and `partOf` (`*` → `*`) work unchanged.

That means research can connect to characters, plot records, timeline events,
world records, and manuscript chapters/scenes today, because those are all
Universal Records and `documents` targets `*`. Endpoints are still validated
for project scope by both `ConnectionEngine` and `RecordService`.

## 5. Theme Engine

`ResearchStudioView` nests `StudioThemeScope(studio: StudioId.research)` inside
the shell scope and resolves every colour, text style, and radius through it,
falling back to `Theme.of(context)` when pumped without a scope. `StudioId`
gained a `research` constant — a token id, not an architecture change. No
`ThemeData`, `Colors.*`, or `Color(0x…)` appears in the new code, enforced by
*no hard-coded colours exist in the new Research Studio code*.

## 6. Navigation

`StudioSection.research` was added to the shell. The section list is duplicated
in two places in `main.dart` (`_AuthorStudioShellState.storySections` and
`_SidebarNavigation.storySections`); both were updated, and the navigation test
opens the Studio through the real sidebar rather than constructing it directly.

## 7. Manuscript Studio research side panel — findings

**Not touched, not migrated, not deleted.** The findings:

1. **What it stores.** `ProjectResearchStore` in `main.dart` writes
   `author_studio.research_panel.{projectId}` — a JSON map keyed by
   `ResearchTab` (`research` / `notes` / `timeline`), each holding a list of
   `ResearchReference` with three string fields: `title`, `detail`, `tag`.
   No URLs, ids, or record references.
2. **Could user data exist there?** Yes. The panel ships in the Manuscript
   Studio layout, writes on every add or remove, and nothing has ever cleared
   the key. Any author who pinned a reference has data in it today.
3. **Can Universal Records represent it?** Yes, completely.
   `title → AuthorRecord.title`, `detail → summary`, and `tag` maps onto
   `researchKind` or a record tag. The `timeline` tab is the only wrinkle: its
   entries are free text about chronology, not timeline records, so they would
   migrate as research entries rather than as `timeline-*` records.
4. **Is a migration required?** **Yes, and it is not in this milestone.**

   This matters more than it looks: the panel's key is *not* covered by the
   archive, sync, or backup subsystems — `BackupHealthStore` tracks only its
   own four keys, and nothing in `lib/archive`, `lib/sync`, or
   `lib/migrations` reads `author_studio.research_panel.*`. Until a migration
   lands, that data exists only in device preferences and is absent from
   project archives.

   `docs/persisted-data-inventory.md` already lists the key with a 2.0
   destination of "research records and links". Its owner name and field list
   were stale (it named a `ResearchReferenceStore` and URL/location fields);
   both are corrected in this change.

   `test/research_architecture_test.dart` guards the panel: it fails if
   `ProjectResearchStore` or its key disappears from `main.dart`, so the old
   system cannot be dropped silently without a migration landing beside it.
   It also fails if any Research Studio file reads that key.

**Recommended migration shape** (next milestone, not this one):

- Read `author_studio.research_panel.{projectId}` once per project.
- Create one `research-entry` per `ResearchReference`, with
  `researchKind` derived from the tab, `summary` from `detail`, and an
  `extensionData` breadcrumb naming the source key and tab.
- Mark the key migrated rather than deleting it, for one support window.
- Replace the panel body with a read-only view over canonical research
  records, keeping its place in the Manuscript layout.
- Add legacy fixtures alongside the existing ones in `test/fixtures/`.

## 8. Known limitations

- **Connections are read-only in the UI.** The detail pane lists a record's
  connections; creating one is a service-level API this milestone did not put
  behind a control. `ResearchService.connect` is tested directly.
- **`documents` uses exact type-id matching.** `ConnectionTypeDefinition`
  matches source types by exact id (with `*` as wildcard), not by template
  compatibility. Any future research subtype would need adding to the
  `documents` source list — or the registry taught to resolve inheritance.
- **Analytics counts the same two type ids as before.** That stays correct
  precisely because no new research subtype was introduced. Introducing one
  later means updating `AnalyticsService.researchTypeIds` in the same change.
- **Research still routes to the Story Codex in Universal Search.**
  `searchDestinationForType` maps `research-entry` to
  `SearchDestination.storyCodex`. Repointing it at Research Studio means
  adding a `SearchDestination` value and updating every studio's navigation
  switch, which is outside this milestone's scope.
- **Entry ids are positional** (`research-1`, `research-2`, …), matching the
  convention the other studios use in this codebase.
