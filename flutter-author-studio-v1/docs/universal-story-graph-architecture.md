# AuthorOS — Universal Story Graph

Architecture Audit & Master Design

Status: Design and audit only — no Story Graph implementation exists or is authorised by this document
Audited: August 21, 2026
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes (§0)
Audit basis: `flutter-author-studio-v1` at merge commit `864f99d`, **re-verified against `main` at `4f83201`** — see §0
Superseded decisions: **D-1 and D-2 are REVERSED** — see §0
Verification baseline: 595 tests passing, 55 analyzer issues (0 errors), clean working tree

---

## 0. Amendments since the audit

This audit was written against `864f99d`. `main` has since advanced to `5c6bf05`,
absorbing five parallel milestones. Two audit findings and two decisions are superseded.
Everything else in this document was re-verified against the merged tree and still holds.

### Re-verification against `4f83201`

Every quantitative claim in this document was re-derived from the merged tree on
August 21, 2026, not carried forward. `main` moved twice during the pass — five
milestones at `5c6bf05`, then Manuscript Studio Phase 2 and the research-panel migration
at `4f83201`. Results are against the later tree.

| Claim | At `864f99d` | At `5c6bf05` | Verdict |
|---|---|---|---|
| Tables | 11 | **12** (`writing_session_rows`) | Corrected |
| Schema version | 8 | **9** | Corrected |
| Record types | 222 | **224** — `project` (manuscript), `event` (timeline) | Corrected |
| Categories | 21 | 21 | Holds |
| Connection types | 127 | **130** — `childOf`, `locatedAt`, `references` | Corrected |
| Wildcard `*` → `*` edges | 70 | **73** — all three new edges are wildcards | Corrected; **R-3 worsens** |
| Fully typed edges | 54 | 54 | Holds |
| Cardinality | all `manyToMany`, never enforced | unchanged | **R-12 holds** |
| Archive entries | 10 | 10 | Holds — see R-22 |
| `putManuscriptNodes` upsert-only | yes | yes | **R-1 holds** |
| `ManuscriptNodeReference` has no `status` | yes | yes | **R-1 holds** |
| Raw bypasses in production | `world_studio.dart:270`, `story_codex_service.dart:88` | unchanged | **R-8 holds** |
| Analytics writes no graph truth | yes | yes | Holds — pinned by test |
| `ProjectResearchStore` migration deferred | yes | **no — it landed** | **R-4 CLOSED**, see below |
| FK + `PRAGMA foreign_keys = ON` | yes | yes | **I-1 holds** |

Two milestones were checked specifically for a second graph system:

- **Map Studio Phase 2** (`map_domain.dart`, `map_service.dart`, `map_studio_view.dart`,
  ~4,100 lines) is built entirely on `RecordService`, `ConnectionEngine`,
  `UniversalSearchService`, `SafeDeleteService` and `VersionAuditService`. Its own header
  states that "every map, place, region and marker is an ordinary Universal Record".
  **Invariant I-13 holds** — no second persistence, no second edge model.
- **Writing Session History** adds a table but no node — see the findings below.

### Findings corrected

| § | Said | Now |
|---|---|---|
| §3.2, §5, §8, §14, I-12 | `WritingSession` is **NOT PRESENT** | **Present.** `lib/core/writing_session.dart`, `lib/writing_session_recorder.dart`, and a 12th table, `writing_session_rows`. **Invariant I-12 holds**: the table has no foreign key into `connected_entities`, no registered record type, and no connection type takes a session as an endpoint. `chapterId`/`sceneId` are nullable soft pointers, not edges. Sessions are history, and a guardrail test now pins them there |
| §2.2 | 11 tables | **12** — `writing_session_rows` added |
| §3.2, §5, §13 | **Map Region is NOT PRESENT** — no type, no area geometry | **Wrong on both counts since Map Studio Phase 2.** Regions are ordinary records of the **existing `region` location type** (`MapTypes.region`), deliberately excluded from Map Studio's place types so it stays a Map concept of its own. Area geometry now exists as a record field — `MapFields.geometry`, stored as `{kind, points}` and clamped to the map extent. The §6 verdict for `Location → Map Region` changes from **NOT CURRENTLY SUPPORTED** to **SUPPORTED NOW** |
| §8, §11.3, §14, R-4 | Research is split between records and `ProjectResearchStore`, and the migration is deferred | **The migration has landed.** A Research Studio (`lib/research_service.dart`, `lib/research_studio_view.dart`) builds on `research-entry` records, and `lib/migrations/research_panel_migration.dart` converts legacy panel references into them. `ProjectResearchStore` moved to `lib/migrations/research_panel_store.dart` as a **read-only legacy input** — the blob is never rewritten, and a separate `.migrated` marker key records completion, so a migration bug cannot corrupt the only copy of the author's data. Unmigratable references (empty title, creation failure) are reported as typed skips rather than silently dropped. **R-4 is closed.** Its guardrail is rewritten to assert the invariant that replaced it |

### Decisions reversed

**D-1 (scenes become `AuthorRecord`s) and D-2 (version coalescing) are withdrawn.**

D-2 existed only to absorb the version churn that D-1 would have created by putting prose
into `AuthorRecord.fields`. **With D-1 withdrawn, D-2 has no problem left to solve** and is
withdrawn with it. Coalescing may still be worth having on its own merits one day; it is
not needed now, and nothing should be built for it.

### Decision D-3 — scenes and chapters remain manuscript-domain nodes

Taken August 21, 2026, superseding D-1.

Scenes and chapters stay `ManuscriptNodeReference`s. The Story Graph's job is to provide a
**unified read model over heterogeneous domains**, not to force every entity into one
persistence abstraction.

The trade-off, stated honestly:

- **Gains.** No migration. Manuscript Studio keeps its architecture. Five parallel builds
  stay unblocked. Far smaller blast radius.
- **Costs.** Two node kinds persist, so every graph read path must handle both — invariant
  I-14 becomes permanent rather than transitional. R-1 (ghost nodes) and R-2 (prose outside
  the archive) are no longer fixed structurally by a migration; each needs its own targeted
  fix. R-5 (`scene`/`chapter` record types shadowing nodes) stays open, and those registered
  types remain unused.

R-1 and R-2 keep their CRITICAL rank. Under D-3 they are addressed by the integrity
milestone below rather than by a migration.

**Two node kinds are an accepted architectural reality, not a defect to remove.** Phase 0
must not try to eliminate the second kind — it exists to make the manuscript kind *safe*:
a reliable node lifecycle, no ghost nodes, no structure pointing at absent prose. Any
future graph read model handles both kinds permanently and by design.

### The graph boundary

D-3 raises a question the audit answered only case by case, and the writing-session
discovery (§0) settled it in general. Rather than ruling on each new subsystem as it
arrives, the boundary is:

| In the story graph | Outside it |
|---|---|
| Manuscript entities (scenes, chapters) | Writing sessions |
| Characters | Audit history |
| Locations and world entities | Version history |
| Plot | Activity history |
| Timeline | |
| Research | |
| Map entities, where appropriate | |
| Relationships between all of the above | |

The test is **participation, not proximity**. Everything on the left is a thing the story
is *made of*, and can be an endpoint of a `RecordLink`. Everything on the right is a record
of *what happened to* the story — it may reference graph entities by id, and it may be
read alongside them, but it is never a node and never an edge endpoint.

`writing_session_rows` is the worked example: it carries `chapterId` and `sceneId`, so it
sits close to the graph, but they are nullable soft pointers with no foreign key into
`connected_entities`. Proximity without participation. That is the shape every
historical or operational subsystem should take, and invariant I-16 holds it there.

### Applied: book presentation is outside the boundary (Book Studio Phase 1)

The boundary above was first applied to a new subsystem by Book Studio Phase 1
(`docs/book-studio-phase-1-implementation-map.md`).

Book presentation data — trim size, margins, typography, chapter design, and the
front and back matter an author switches on — fails the participation test
outright. No `RecordLink` will ever want a copyright page as the endpoint of
`appearsIn`, `occursAt` or `mentionedIn`. A trim size is not a thing the story is
made of.

It is therefore **outside the graph and outside the database**: `BookProject` is
persisted as a JSON blob at `author_studio.book_studio.{projectId}`, the same
mechanism the prose itself uses. The registered-but-never-instantiated `book`
record type (§3.3) stays uninstantiated; instantiating it would have quietly
resurrected withdrawn decision D-1.

Two further consequences worth recording:

- Making these records would have put "Copyright (c) 2026" into the `author_search`
  FTS index beside characters and locations, and written a `record_version_rows`
  entry every time a margin moved — reopening exactly the churn problem D-2 was
  withdrawn for.
- **Parts** are the one structural addition, and they are modelled as ordering
  metadata rather than nodes: `BookPart.startsAtChapterId` holds a stable chapter
  id in `connected_entities`. That keeps R-1 from worsening — no new node kind on
  an upsert-only table that cannot delete — while staying forward-compatible: when
  the graph gains `contains`/`partOf` edges (§4.3), the anchor id becomes an edge
  with no change to the book model.

Table count and schema version are unchanged at **12** and **9**; the archive
entry count is unchanged at **10**. Book settings being outside the archive is the
same gap as R-2, not a new one.

### Applied again: cover art is an asset, not a node (Book Studio Phase 2)

EPUB export needed cover art, which is the first binary an author attaches to a
book. It gets a table — `book_asset_rows` — and the reasoning is worth recording
because it is the first addition to the audited table set since writing sessions.

It passes the same test writing sessions did, in the same direction: **proximity
without participation**. A cover carries a `projectId`, so it sits close to the
graph, but it is never the endpoint of a `RecordLink`, nothing traverses to it,
and no creative record depends on it. It is an authored asset.

The reason it is in the database at all, rather than beside the rest of the
book's settings, is not architectural preference but a storage ceiling: those
settings are a shared-preferences blob, and shared preferences on the web is
`localStorage` — roughly five megabytes for the whole origin, shared with the
author's prose. A cover is hundreds of kilobytes of binary. Keeping it there
risks failing to save, or crowding out the manuscript.

Table count moves **12 → 13** and schema version **9 → 10**. The addition is
declared in `_auditedTables` with its rationale, as that test requires. Graph
truth is unchanged: no new node kind, no new edge table, and `record_link_rows`
remains the only edge table.

The archive entry count is still **10**. Cover bytes join book settings and scene
prose outside the `.authoros` archive — the same gap as R-2, now slightly wider.

### Phase plan superseded

§20's Phase 0 was written for D-1 and no longer applies. The live plan is:

```
Phase 0  Manuscript graph integrity and node lifecycle   <- directive issued
Phase 1  Universal Story Graph read API
Phase 2  Graph traversal and relationship queries
Phase 3  Story Graph Studio / visualisation
Phase 4  Cross-Studio intelligence and advanced features
```

The Phase 0 directive supersedes `docs/story-graph-phase-0-directive.md`, which was written
for D-1. Read §20 below as historical rationale, not as the plan.

---

## 1. Executive Summary

**AuthorOS already has a story graph.** It is not called that, it has no viewer, and no
service exposes it as a graph — but the persistence layer, the type system, the edge
registry, the traversal primitives, the history model and the archive format are all in
place and all in use by five Studios today.

The finding that matters most for planning:

> A future Story Graph does **not** need a new database, a new edge model, a new record
> model, or a new persistence table. Every graph edge the product needs is already
> expressible as a `RecordLink`, and the type registry already declares 127 connection
> types over 222 record types. What is missing is a **read-oriented graph API** and the
> **traversal layer** above `ConnectionEngine` — not storage.

What the audit proves is present:

| Capability | State |
|---|---|
| Canonical node model (`AuthorRecord`) | Present, project/series/book/branch scoped, versioned, audited, exported |
| Canonical edge model (`RecordLink`) | Present, typed, directed/undirected, metadata-bearing, versioned, audited, exported |
| Edge type registry | Present — 127 built-in connection types, project-extensible |
| Node type registry | Present — 222 built-in record types, inheritance-capable, project-extensible |
| Referential integrity | **Enforced at the SQLite level** (`PRAGMA foreign_keys = ON` + FK on both endpoints) |
| Project isolation on writes | Enforced in `ConnectionEngine` and `RecordService`, **not** in the schema |
| Single-node graph read | Present — `UniversalRecordInspector` returns incoming, outgoing, references, history, scope, validation |
| Multi-hop traversal | **Absent** in production. A disconnected BFS prototype exists (`ImpactTraceAnalyzer`) with no callers |
| Graph search | **Absent** — the FTS index covers title/body/tags only; no edge is indexed |
| Story Graph UI | **NOT PRESENT** — confirmed by search across `lib/` and `test/` |
| Analytics as a pure consumer | Holds for records, links, versions and audit events. One qualification: a cold read seeds manuscript nodes (R-21) |

What the audit proves is missing or at risk:

1. **Manuscript nodes are second-class graph citizens.** Scenes and chapters exist as
   `ManuscriptNodeReference` rows — no lifecycle status, no version, no audit trail, and
   **never deleted** (`putManuscriptNodes` is upsert-only). Deleting a scene in Manuscript
   Studio leaves a permanent ghost node, its links and its search-index entry behind.
   This is the single highest graph risk in the tree — and the one **decision D-1 exists
   to close.**
2. **Type compatibility is largely nominal.** 70 of 127 connection types accept
   `*` → `*`. Every relationship pair tested is "supported", but for 12 of the 27 pairs
   tested the *only* support is a wildcard edge with no semantics.
3. **Cardinality is declared and never enforced.** All 127 types are `manyToMany`;
   `ConnectionCardinality` appears nowhere outside its own model and JSON codec.
4. **Real creative data lives outside the canonical graph** — manuscript scene *content*,
   the Research side-panel (`ProjectResearchStore`), the legacy timeline store, and the
   visual-planning board are all in `SharedPreferences` and none of them are in the
   archive. D-1 brings the prose in; the other three stay out and stay open.
5. **There is no writing-session history system.** `WritingSession` does not exist
   anywhere in `lib/`. Directive item 8 assumes one; it is **NOT PRESENT**.

The recommended shape is a **read-only `StoryGraphService`** that delegates to the
existing repository and `ConnectionEngine`, owns no storage, and treats derived edges as
a separately-typed, never-persisted overlay. Phases are proposed in §20.

### Decision D-1 — scenes and chapters become `AuthorRecord`s *(WITHDRAWN — see §0)*

Taken August 21, 2026, resolving what this audit raised as its largest open question.

Manuscript nodes stop being a second node kind. `scene` and `chapter` — already
registered record types (§3.3) — become the real, instantiated ones, and
`ManuscriptNodeReference` is retired.

The decision reaches further than it first appears, because it closes both CRITICAL
risks and two MEDIUM ones at their root rather than patching them:

| Resolves | How |
|---|---|
| **R-1** manuscript nodes never deletable (CRITICAL) | Records have `status` and a soft-delete path |
| **R-2** prose outside the graph and the archive (CRITICAL) | Prose in `fields` is exported by `records.jsonl` |
| **R-5** `scene`/`chapter` type shadowing (HIGH) | One meaning of "scene". `PlotService`'s orphaned-scene check starts working |
| **R-14** scene prose unsearchable (MEDIUM) | The FTS body is `fields_json` |
| **R-15** versions exclude relationships *(partially)* | Scenes gain version history they never had |
| Missing `scene → chapter` / `chapter → book` edges (§4.3) | Containment becomes a typed edge between two records |

It also makes **R-21 more urgent, not less** — see §20 Phase 0. The migration itself is
tractable for one specific reason: `connected_entities` already holds both node kinds
under one id space, so **preserving ids means every existing `RecordLink` survives the
migration untouched.**

Full design, costs and sequencing: §20 Phase 0. New questions it opens: §19.

### Decision D-2 — manuscript version churn is handled by coalescing *(WITHDRAWN with D-1 — see §0)*

Taken August 21, 2026, resolving what D-1 opened as Q-1 and unblocking Phase 0.

Prose in `fields` means `RecordService.updateRecord` snapshots the whole scene on every
autosave. Rather than exclude prose from the snapshot or add a second write path,
**consecutive versions of the same entity are collapsed inside a time window**, so a
writing session yields a handful of snapshots instead of hundreds. "Restore this scene to
yesterday" keeps working, there is one write path, and no schema change is needed.

The rule that makes it safe: **only `AuditChangeType.updated` coalesces.** Every other
change type — `created`, `renamed`, `archived`, `restored`, `deleted`, `duplicated`,
`statusChanged`, `templateChanged`, `scopeChanged`, `branchChanged`, and all four
`connection*` types — always appends. `_classifyChange` already routes a title edit to
`renamed` and a status edit to `statusChanged`, so the only thing that collapses is a run
of pure field-content edits. That is precisely the autosave case and nothing else.

Consequences to hold in view, because coalescing changes behaviour for **every** record
type, not just scenes:

- `getRecordVersionCount`, `HistoryInspection.versionCount` and the version count
  `SafeDeleteService` reports all become "snapshots retained", not "edits made". Anything
  presenting them as an edit tally needs its wording revisited.
- `_insertVersion` currently uses `.insert()`. Coalescing needs a replace path that keeps
  the existing version id — which keeps the `previousVersionId` chain intact — and
  replaces its paired audit event, whose id is derived as `audit-<versionId>`.
- The `sequence` counter in version metadata must not double-increment on a coalesced
  write.

Full specification and sequencing: §20 Phase 0, step 1.

---

## 2. Current Architecture

### 2.1 Layering

```
                     Studios (Character, World, Timeline, Plot, Codex, Manuscript)
                                        |
        +-------------------+-----------+-----------+--------------------+
        |                   |                       |                    |
  CharacterService    WorldService           TimelineService        PlotService
  StoryCodexService                                                       |
        +-------------------+-----------+-----------+--------------------+
                                        |
              RecordService  |  ConnectionEngine  |  UniversalSearchService
              UniversalRecordInspector | SafeDeleteService | VersionAuditService
              BranchService | LegacyReferenceMigrationService
                                        |
                        DriftConnectedDomainRepository
                                        |
                       AuthorOsDatabase (drift/SQLite, schema v8)
```

Aggregation-only consumers sit beside the Studios and own no storage:
`WorldBoardService`, `AnalyticsService`, `ContinuityAnalyzer`,
`WorldContinuityIntelligence`, `CodexContinuityIntelligence`.

### 2.2 Persistence

One app-wide database, `authoros_creative`, instantiated once as a global
(`authorOsDatabase` / `authorOsRepository`, `lib/persistence/authoros_database.dart:1445`).
**All projects share one database file.** Project separation is a service-layer concern,
not a storage-layer one.

Schema version 8. Tables:

| Table | Role |
|---|---|
| `connected_entities` | Identity table — every node id, its `kind` (`record` / `manuscriptNode`) and scope |
| `author_record_rows` | Canonical nodes (`AuthorRecord`) |
| `manuscript_node_rows` | Manuscript nodes (`ManuscriptNodeReference`) — chapters and scenes |
| `record_link_rows` | **The single edge table** (`RecordLink`) |
| `record_type_definition_rows` | Project-scoped custom node types |
| `connection_type_definition_rows` | Project-scoped custom edge types |
| `story_branch_rows` | Story branches |
| `branch_record_overlay_rows` | Per-branch node overrides |
| `branch_link_overlay_rows` | Per-branch edge overrides |
| `record_version_rows` | Immutable version snapshots |
| `audit_event_rows` | Immutable audit trail |
| `author_search` (FTS5 virtual) | Full-text index over title / body / tags |

`beforeOpen` sets `PRAGMA foreign_keys = ON`, `journal_mode = WAL`,
`synchronous = FULL` (`authoros_database.dart:324-327`).

`record_link_rows.source_id` and `.target_id` both carry
`REFERENCES connected_entities(id)`. Combined with the pragma, **the database itself
rejects a dangling link**. This is a stronger guarantee than most graph layers start with.

### 2.3 The node model — `AuthorRecord`

`lib/core/connected_domain.dart`

| Field | Graph meaning |
|---|---|
| `id` | Node identity (also the `connected_entities` key) |
| `typeId` | Node label, resolved against `RecordTypeRegistry` |
| `scopeType` / `scopeId` | Ownership scope (`library`/`universe`/`series`/`project`/`book`/`branch`/`manuscript`) |
| `projectId`, `seriesId`, `bookId`, `branchId` | Scope coordinates |
| `canonStatus` | `canon` / `draft` / `proposed` / `deprecated` / `nonCanon` / `alternate` |
| `status` | Lifecycle: `active` / `archived` / `deleted` (soft) |
| `templateId` / `templateVersion` | Template provenance |
| `revision` | Monotonic per-record counter |
| `fields` | Typed field map, schema from the resolved type definition |
| `tags` | Free tags, indexed for search |
| `extensionData` | Studio-specific escape hatch |

### 2.4 The edge model — `RecordLink`

| Field | Graph meaning |
|---|---|
| `id` | Deterministic: `link-` + base64url(`scopeId\|sourceId\|typeId\|targetId`) when created via `ConnectionEngine` |
| `sourceId` / `targetId` | Endpoints — **either kind of node** (record or manuscript node) |
| `typeId` | Edge label, resolved against `ConnectionTypeRegistry` |
| `scopeId` | Project the edge belongs to |
| `direction` | `directed` / `undirected`, must match the type definition |
| `label` | Display override |
| `metadata` | Validated against the type's `metadataFields` |
| `revision` | Monotonic |

The deterministic id makes `connect()` idempotent for a given
(project, source, type, target) tuple — re-connecting returns the existing link
(`connection_engine.dart:68-74`).

### 2.5 The type system

`RecordTypeDefinition` supports single inheritance via `baseTypeId`, with
`RecordTypeRegistry._resolve` walking and merging the chain (cycle-detected).
`isTemplateCompatible` answers template/type compatibility.

`ConnectionTypeDefinition` declares `sourceTypeIds`, `targetTypeIds`, `direction`,
`cardinality`, `metadataFields`, `temporalSupport`. `permits()` accepts the literal
wildcard `'*'` on either side.

Both registries accept project-scoped additions loaded from the database
(`RecordService.registry()` / `.connectionRegistry()`), so **a future graph never needs to
hard-code a type list**.

---

## 3. Record Inventory

222 built-in record types across 21 categories. Every built-in type carries
`builtIn: true`, `permissions: {editableDefinition: false}` and a `sourcePackId`
(`authoros-core`, `authoros-world-core`).

Scope, versioning, audit, search and export behave **identically for every record type** —
they are properties of `AuthorRecord` and of `RecordService`, not of the type. Rather than
repeat five identical columns 222 times, the invariant is stated once:

> **Every `AuthorRecord`, of every type, is project-scopable, searchable, versioned,
> audited and archive-exported.** No built-in record type opts out.

The exceptions are not record types at all — they are the non-record stores in §11.

### 3.1 Graph-relevant types

| Record type ID | Category | Base type | Fields | Existing connections (typed, non-wildcard) | Used by Studio |
|---|---|---|---|---|---|
| `character` | characters | `general-lore` | 170 | `appearsIn`, `mentionedIn`, `friendOf`, `enemyOf`, `alliedWith`, `rivalOf`, `partnerOf`, `parentOf`, `guardianOf`, `mentors`, `protects`, `employs`, `trusts`, `distrusts`, `memberOf`, `livesIn`, `bornIn`, `worksIn`, `visits`, `controls`, `owns`, `uses`, `carries`, `knows`, `pursues`, `hasArc`, + 7 `*At`/location types | Character Studio |
| `chapter` | manuscript | `general-lore` | 7 | target of `appearsIn`, `mentionedIn` | *(record type unused — see §3.3)* |
| `scene` | manuscript | `general-lore` | 7 | target of `appearsIn`, `mentionedIn`; source of `occursAt`, `involves` | Plot Studio (validation only) |
| `book` | manuscript | `general-lore` | 7 | target of `appearsIn`, `mentionedIn` | — |
| `series` | manuscript | `general-lore` | 7 | wildcard only | — |
| `plot-thread` | plot | `general-lore` | 7 | target of `pursues`, `hasArc` | Plot Studio |
| `plot-record` (+ 30 plot types) | plot | varies | varies | `appearsIn`, `occursAt`, + 11 plot edges (all wildcard) | Plot Studio |
| `timeline-event` | timeline | `timeline-record` | 18 | `occursAt`, `involves` | Timeline Studio |
| `timeline` (+ 27 timeline types) | timeline | `timeline-record` | 18 | as above | Timeline Studio |
| `world` | world | `general-lore` | 44 | full spatial set (`locatedIn`, `contains`, `adjacentTo`, …) | World Studio |
| `location` (+ 37 location types) | locations | `general-lore` | 44 | 16 typed spatial edges | World Studio |
| `map` (+ 9 map types) | maps | `general-lore` | 16 | `maps` → spatial | World Studio |
| `map-marker` | maps | `general-lore` | 16 | `onMap` → map; `represents` → `*` | World Studio |
| `travel-route` (+ 10 route types) | routes | `general-lore` | 17 | `routeFrom`, `routeTo` → spatial | World Studio |
| `research-entry` | research | `general-lore` | 7 | `documents` → `*` | Story Codex |
| `research` (alias) | research | `research-entry` | 7 | as above | Story Codex |
| `author-note` | reference | `general-lore` | 7 | wildcard only | Story Codex |
| `reference`, `glossary-term`, `document` | reference | `general-lore` | 7 | `documents` → `*` | Story Codex |
| `general-lore` | lore | *(root)* | 7 | `relatedTo`, `mentionedIn` | Story Codex |
| `faction` | factions | `general-lore` | 19 | `memberOf`, `controls`, `alliedWith`, `enemyOf` | World Studio |
| `item` | items | `general-lore` | 17 | `owns`, `uses`, `carries`, `createdBy`, `locatedIn` | World Studio |
| `historical-event` | history | `general-lore` | 17 | `occursAt`, `involves`, `caused`, `resultedIn` | Story Codex |

Category totals: characters 15, creatures 6, culture 7, custom 3, factions 8, history 5,
items 6, locations 38, lore 9, magic 5, manuscript 4, maps 10, places 1, plot 38,
reference 5, religion 2, research 2, routes 11, technology 2, timeline 29, world 16.

### 3.2 Types the directive names that are **NOT PRESENT**

| Requested | Status |
|---|---|
| "Notes" as a distinct graph type | **NOT PRESENT** as a first-class type. `author-note` exists as a bare `general-lore` child with no note-specific fields. The Research side-panel's notes are not records at all (§11.2). |
| "Map Region" | **NOT PRESENT**. There is no `map-region` type. Regions are modelled as *location* types (`region`, `district`, `province`, `territory`) linked to a `map` via `maps`. A map marker carries `x`/`y` scalars only — there is no area/polygon geometry anywhere. |
| `WritingSession` / writing-session history | **NOT PRESENT**. No class, table, store or key. Analytics derives no session data. |
| Cross-project / universe-level records in practice | Type system allows `RecordScopeType.universe` / `series`; **no service creates them**. Every Studio writes `scopeType: project`. |

### 3.3 Dead and shadow definitions

- `built_in_record_types.dart:196` defines `_world` and `:243` defines `_location`. Neither
  is in `BuiltInRecordTypes.definitions` — `WorldRecordTypes.definitions` supplies the live
  `world` and `location` types instead. These two constants are unreachable and, if ever
  added to the list, would throw `Record type ids must be unique`.
- The `scene`, `chapter`, `book` **record types are registered but never instantiated by
  any Studio.** `ManuscriptStore` writes chapters and scenes as `ManuscriptNodeReference`
  rows, not records. `PlotService` queries `recordsByTypeAndScope(typeId: 'scene', …)`
  (`plot_service.dart:416`) and will therefore always find zero scenes in a project whose
  scenes came from Manuscript Studio. Its `orphaned-scene` validation is currently
  unreachable.

  **Under decision D-1 these stop being shadow definitions and become the target.** They
  are currently bare `general-lore` children with seven inherited fields and no
  manuscript semantics; Phase 0 gives them real field definitions (§20).

---

## 4. Connection Inventory

127 built-in connection types. Every one is `manyToMany`. 117 directed, 10 undirected.
101 declare `temporalSupport`. Packs: `authoros-world-core` 33, `authoros-core` 32,
`authoros-codex-core` 27, `authoros-timeline-core` 23, `authoros-character-core` 12.

**Project scope**: every edge carries `scopeId`; `ConnectionEngine` fixes it to the
service's project.
**Deletion behaviour**: `disconnect()` **hard-deletes** the row and appends a
`connectionRemoved` audit event. There is no soft-deleted edge state.
**Archive behaviour**: archiving a node does **not** touch its edges. Edges to archived
nodes remain live and traversable.

### 4.1 EXISTING AND GRAPH-READY

Typed on both endpoints, semantically meaningful, already written by a Studio.

| Connection ID | Source | Target | Direction | Reverse label | Metadata | Used by |
|---|---|---|---|---|---|---|
| `appearsIn` | character, 12 world types, 31 plot types | scene, chapter, book | directed | Features | — | Character Studio, World Studio, Plot Studio |
| `mentionedIn` | character | scene, chapter, book | directed | Mentions | — | Character Studio |
| `friendOf`, `enemyOf`, `alliedWith`, `rivalOf`, `partnerOf` | character | character | **undirected** | *(self-inverse)* | 11 fields incl. `strength`, `trust`, `secret` | Character Studio |
| `parentOf`, `guardianOf`, `mentors`, `protects`, `employs`, `trusts`, `distrusts` | character | character | directed | Child of / Ward of / Student of / … | as above | Character Studio |
| `memberOf` | character | faction, organisation | directed | Has member | `rank`, `joinedDate`, `leftDate`, `status` | Character Studio |
| `livesIn`, `bornIn`, `worksIn`, `visits` | character | 47 spatial types | directed | Has resident / Birthplace of / … | — | Character Studio |
| `currentlyAt`, `previouslyAt`, `homeAt`, `safehouseAt`, `favouriteLocation`, `forbiddenFrom`, `fromLocation` | character | 47 spatial types | directed | Current location of / … | 10 world fields | World Studio |
| `owns`, `uses`, `carries` | character, faction, organisation | item, artefact, weapon, technology | directed | Owned by / Used by / Carried by | — | Character Studio |
| `controls` | character, faction, organisation, government | spatial, faction, resource | directed | Controlled by | — | World Studio |
| `locatedIn` | 47 spatial + item, artefact, faction | 47 spatial | directed | Contains | — | **World Studio hierarchy** |
| `inside`, `outside`, `surrounds`, `crosses`, `passesThrough`, `above`, `below`, `northOf`, `southOf`, `accessibleFrom`, `inaccessibleFrom` | spatial | spatial | directed | *(paired)* | 10 world fields | World Studio |
| `adjacentTo`, `borders`, `near`, `farFrom` | spatial | spatial | **undirected** | *(self-inverse)* | 10 world fields | World Studio |
| `maps` | 9 map types | 47 spatial | directed | Mapped by | — | `WorldService.createMap` |
| `onMap` | map-marker | 9 map types | directed | Has marker | — | `WorldService.createMapMarker` |
| `routeFrom`, `routeTo` | 11 route types | 47 spatial | directed | Starts/Ends route | — | `WorldService.createRoute` |
| `occursAt` | 27 timeline types, historical-event, scene, 31 plot types | 47 spatial | directed | Hosts event | — | Timeline Studio |
| `involves` | 27 timeline types, historical-event, scene | character, faction, organisation | directed | Involved in | — | Timeline Studio |
| `pursues` | character, faction, plotline, story, world | goal, plot-thread | directed | Pursued by | — | Character Studio |
| `hasArc` | character, story, plotline, relationship | 8 arc types | directed | Character arc for | — | Character Studio |

### 4.2 EXISTING BUT LIMITED

Real, usable, but carrying a restriction a Story Graph must plan around.

| Connection ID | Source | Target | Limitation |
|---|---|---|---|
| `knows` | character | `*` | Target wildcard. Rich `knowledgeState` metadata, but no type discipline — a character can "know" a map marker. |
| `represents` | map-marker | `*` | Target wildcard. This is the *only* edge tying a marker to what it depicts, so a graph cannot type-check marker targets. |
| `documents` | codex-entry, research-entry, reference | `*` | Target wildcard. **This is the entire Research→anything relationship story.** All four research relationships the directive asks about (§6) reduce to this one wildcard edge. |
| `partOf` / `contains` | `*` | `*` | The natural containment edge for chapter→book and scene→chapter is completely untyped. |
| `relatedTo` | `*` | `*` | Undirected catch-all. Suggested on every one of the 222 record types. Will dominate any unfiltered graph view. |
| The 70 wildcard edges | `*` | `*` | Listed in full below. Semantically meaningful names with no type enforcement whatsoever. |

The 70 `*` → `*` edge types: `after`, `associatedWith`, `before`, `belongsTo`, `caused`,
`causedBy`, `causes`, `changed`, `changedBordersOf`, `changedDuring`, `changes`,
`concurrentWith`, `confirmedIn`, `connectedTo`, `contains`, `contradicts`, `covers`,
`created`, `createdBy`, `dependsOn`, `depictedIn`, `depicts`, `destroyed`, `during`,
`established`, `explainedIn`, `follows`, `foreshadowedIn`, `founded`, `foundedBy`,
`fulfilledBy`, `governedBy`, `hasCulture`, `hasStake`, `headquartersAt`, `influences`,
`inspired`, `introduced`, `introducedIn`, `knownFor`, `leadsTo`, `lost`, `motivatedBy`,
`occursDuring`, `opposes`, `originatedFrom`, `overlaps`, `ownedBy`, `paidOffBy`, `partOf`,
`participatedIn`, `plannedFor`, `practices`, `precedes`, `presentAt`, `relatedTo`,
`repeats`, `requires`, `resolvesIn`, `resultedIn`, `revealedIn`, `ruledBy`, `rules`,
`signed`, `speaks`, `supports`, `tookPlaceIn`, `usedBy`, `witnessed`, `worships`.

### 4.3 MISSING

Relationships the product needs that the architecture cannot express **with type
discipline** today. *(Recorded only — not to be added in this milestone.)*

| Needed relationship | Why the current architecture falls short |
|---|---|
| `scene` → `chapter` containment | No typed edge. Chapter membership currently lives in `ManuscriptNodeReference.extensionData['chapterId']` — an untyped string in a JSON blob, invisible to the edge table. |
| `chapter` → `book` containment | Same. No manuscript spine exists as edges at all. |
| `scene` → `plot-thread` | Only wildcard (`plannedFor`, `fulfilledBy`, `resolvesIn` are all `*`→`*`). Plot Studio's own `orphaned-scene` check depends on these. |
| `scene` → `timeline-event` | Only wildcard. |
| `character` → `timeline-event` | Only wildcard — the reverse (`involves`) is typed, the forward direction is not. |
| Research → character/plot/location/timeline | Only `documents` (`research-entry` → `*`). No typed research edge exists. |
| `map-marker` → `location` | Only `represents` (`map-marker` → `*`). |
| Map **region** membership | No region node type and no area geometry — see §3.2. |
| Any cardinality constraint | `ConnectionCardinality` is declared on all 127 types as `manyToMany` and is **never read** outside the model's own JSON codec. `oneToOne`/`oneToMany`/`manyToOne` are inexpressible in practice. |

---

## 5. Future Story Graph Model

Built strictly from what §3 and §4 prove exists.

### NODES

| Node | Backing entity | Present? |
|---|---|---|
| Character | `AuthorRecord[typeId=character]` | Yes |
| Scene | `ManuscriptNodeReference[nodeType=scene]` **→ `AuthorRecord[typeId=scene]` (D-1)** | Yes — today a manuscript node, **not** a record. Becomes a record in Phase 0 |
| Chapter | `ManuscriptNodeReference[nodeType=chapter]` **→ `AuthorRecord[typeId=chapter]` (D-1)** | Same |
| Book / Series | `AuthorRecord[book\|series]` | Type registered, never instantiated |
| Plot Thread | `AuthorRecord[plot-thread]` + 30 sibling plot types | Yes |
| Timeline Event | `AuthorRecord[timeline-event]` + 27 sibling types | Yes |
| Location | `AuthorRecord[location]` + 37 sibling spatial types | Yes |
| World / Universe | `AuthorRecord[world\|universe\|planet\|…]` | Yes |
| Map | `AuthorRecord[map]` + 9 sibling map types | Yes |
| Map Marker | `AuthorRecord[map-marker]` | Yes |
| Route | `AuthorRecord[travel-route]` + 10 sibling types | Yes |
| Faction / Item / Culture / Religion / Magic System | `AuthorRecord[…]` | Yes |
| Research | `AuthorRecord[research-entry\|research]` | Yes — but see §11.2, the Research *panel* is elsewhere |
| Map Region | — | **Future requirement** — no type, no geometry |
| Writing Session | — | **Future requirement** — nothing exists |

Two node *kinds*, not one, is the load-bearing fact:

```
connected_entities
  ├── kind = 'record'          → author_record_rows        (versioned, audited, soft-deletable, scoped)
  └── kind = 'manuscriptNode'  → manuscript_node_rows      (no version, no audit, no status, never deleted)
```

Any graph read model must render both and must not assume they behave alike.

**Decision D-1 collapses this to one kind.** After Phase 0 every graph node is an
`AuthorRecord`, `connected_entities.kind` is uniformly `record`, and the asymmetry above
disappears. Until then, Phase 1 must still handle both — a read model written as if
manuscript nodes did not exist would be wrong on every project that has not migrated.

### RELATIONSHIPS

One edge kind: `RecordLink`. Typed by `ConnectionTypeDefinition`. Three tiers, from §4:
graph-ready typed edges, wildcard edges, and branch-overlay edges
(`BranchLinkOverlay`, visible only in a branch view).

### ATTRIBUTES

- **Node attributes** — `AuthorRecord.fields` (schema from the resolved type),
  `tags`, `canonStatus`, `status`, `revision`, `templateId`.
- **Edge attributes** — `RecordLink.metadata`, validated against
  `ConnectionTypeDefinition.metadataFields`. Three metadata vocabularies exist:
  character (`strength`, `trust`, `secret`, `mutuality`, …),
  world (`startDate`, `endDate`, `distance`, `travelTime`, `difficulty`, `danger`, …),
  timeline (`offset`, `unit`, `description`),
  codex (`strength`, `confidence`, `private`, `secret`, `context`, `source`, …).
- **Temporal attributes** — 101 of 127 types set `temporalSupport: true`, and the world
  and codex metadata sets carry `startDate`/`endDate`. **A future graph can already ask
  "who lived here in year X"** without new storage.

### EVENTS

`AuditEvent` — 15 change types, including four edge-specific ones
(`connectionAdded`, `connectionRemoved`, `connectionMetadataChanged`,
`connectionTypeChanged`). Every graph mutation already emits one. A graph activity feed
needs no new event source; `WorldBoardService._recentActivity` already consumes this.

### SCOPES

`RecordScopeType`: `library`, `universe`, `series`, `project`, `book`, `branch`,
`manuscript`. Plus the orthogonal `branchId` overlay dimension and `CanonStatus`.

A graph view is therefore addressed by a **triple**: (project, branch-or-canon,
canon-status filter) — not by project alone.

---

## 6. Canonical Relationship Pattern — Support Matrix

Every answer below is machine-derived from
`BuiltInConnectionTypes.definitions[].permits(source, target)`, run against the live
registry, and then split by whether the permitting edge is typed or wildcard.

Legend:
- **SUPPORTED NOW** — a typed, non-wildcard edge exists *and* a Studio writes it today.
- **SUPPORTED WITH EXISTING CONNECTION ENGINE** — a typed edge exists; no Studio writes it,
  but `ConnectionEngine.connect()` would accept it unchanged.
- **SUPPORTED BUT REQUIRES TYPE REGISTRATION** — only wildcard edges permit it. It works,
  but with no semantics; a typed connection type would need registering for discipline.
- **NOT CURRENTLY SUPPORTED** — the endpoint is not a graph node at all.

| Relationship | Verdict | Evidence |
|---|---|---|
| Character → Scene | **SUPPORTED NOW** | `appearsIn`, `mentionedIn`; written by `CharacterService.getCharacterScenes` consumers and `LegacyConnectionSliceAdapter` |
| Character → Character | **SUPPORTED NOW** | 12 typed edges; `CharacterService.getCharacterRelationships` |
| Character → Location | **SUPPORTED NOW** | 12 typed edges; `CharacterService.getCharacterLocations` |
| Character → Plot | **SUPPORTED NOW** | `pursues`, `hasArc`; `CharacterService.getCharacterThreads` |
| Character → Timeline Event | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Forward direction is wildcard-only. The *reverse* (`involves`: timeline-event → character) is typed and is what `CharacterService.getCharacterTimeline` actually reads |
| Scene → Chapter | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Wildcard-only (`partOf`, `contains`). Truth today is `extensionData['chapterId']`, not an edge |
| Scene → Location | **SUPPORTED WITH EXISTING CONNECTION ENGINE** | `occursAt` names `scene` explicitly in `sourceTypeIds`; no Studio writes it |
| Scene → Timeline Event | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Wildcard-only |
| Scene → Plot | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Wildcard-only (`plannedFor`, `fulfilledBy`, `resolvesIn`, `appearsIn` reverse). `PlotService` validation depends on these |
| Research → Character | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | `documents` (`research-entry` → `*`) only |
| Research → Plot | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Same |
| Research → Location | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Same |
| Research → Timeline Event | **SUPPORTED BUT REQUIRES TYPE REGISTRATION** | Same |
| Location → Location | **SUPPORTED NOW** | 16 typed spatial edges; drives `WorldService.hierarchy()` |
| Location → Map Region | **NOT CURRENTLY SUPPORTED** | No `map-region` node type exists (§3.2). `Map → Location` via `maps` **is** SUPPORTED NOW |

Nothing in this table is UNKNOWN: each row was resolved against the registry, not inferred.

---

## 7. Explicit vs Derived Relationships

The distinction is real and already load-bearing. It must never blur.

### 7.1 Explicit — persisted as `RecordLink`

Created through `ConnectionEngine.connect()` or `RecordService.createRecord/updateRecord(links: …)`.
Validated, deterministically identified, versioned, audited, exported, FK-protected.

```
Kali ──[relatedTo, undirected, metadata{strength:4, secret:true}]──> Vincenzo
       stored as record_link_rows.id = link-<base64url(project|kali|relatedTo|vincenzo)>
```

### 7.2 Derived — computed, never stored

Four derivation mechanisms exist today. **None of them writes a link.**

| Derived relationship | Computed by | Input | Persisted? |
|---|---|---|---|
| Character *appears in* manuscript | `AnalyticsService._countCharactersReferenced` (`analytics_service.dart`) | Case-insensitive substring match of `record.title` against concatenated scene `content` | **No** — returns an `int`, nothing more |
| World hierarchy (parent/child/ancestors) | `WorldHierarchy` in `lib/core/world_domain.dart` | Filters live `locatedIn`/`contains` links into a tree | **No** — but its *inputs* are explicit links, so this is a projection, not an inference |
| Characters sharing scenes | `ImpactTraceAnalyzer.characterRelationships` | BFS over caller-supplied `TraceLink`s | **No** — and it has **no production callers** (§18, R-6) |
| Legacy name references | `LegacyReferenceMigrationService.resolve()` | Name/alias matching against project records | **No** — `resolve()` is read-only and returns a `LegacyMigrationCandidate` with a confidence and resolution state |

The one place derivation *can* become persistence is deliberate, guarded and explicit:

- `LegacyReferenceMigrationService.migrate()` writes a resolved reference into the owning
  record's `_legacyMigration.stableReferences` field — **an author-initiated migration
  action, not a background inference**, and it stores a stable *field*, not a link.
- `LegacyConnectionSliceAdapter.migrateCharacterScene()` converts a legacy
  `SceneRelationship` (or, failing that, an inferred `StoryCodexEntry.mentions` entry) into
  a real `appearsIn` link — but it is gated behind
  `AuthorOsFeatureFlags.connectedDomain`, which is
  `bool.fromEnvironment('AUTHOROS_CONNECTED_DOMAIN', defaultValue: false)` — **off by
  default** — and it stamps the result with
  `extensionData: {'legacySource': 'SceneRelationship'}` and, when inferred,
  `metadata: {'inferredFrom': 'StoryCodexEntry.mentions'}`.

That provenance stamping is the pattern the Story Graph should inherit: **if a derived
relationship is ever promoted, the resulting link must carry its derivation in
`extensionData`, and promotion must be an explicit author action.**

### 7.3 Rule for the future graph

> A derived edge is a **view-layer object with its own type**, never a `RecordLink`. It
> must be visually and structurally distinguishable in every API response and every view.
> The graph read model must return explicit and derived edges in **separate collections**,
> never merged into one list.

---

## 8. Graph-Safe Data Sources — Who Owns Each Edge

| Graph edge / datum | Source of truth | Owning system | Persisted |
|---|---|---|---|
| Character ↔ Character relationship | `RecordLink` | `ConnectionEngine` via `CharacterService` | Yes |
| Character → Scene appearance (explicit) | `RecordLink[appearsIn\|mentionedIn]` | `ConnectionEngine` | Yes |
| Character → Scene appearance (derived) | Scene `content` text | `AnalyticsService` (read-only consumer) | **No** |
| Character → Location | `RecordLink[livesIn\|bornIn\|worksIn\|visits\|currentlyAt\|…]` | `ConnectionEngine` via `CharacterService`/`WorldService` | Yes |
| Plot membership | `AuthorRecord[plot-*]` + `RecordLink[pursues\|hasArc\|appearsIn]` | `PlotService` | Yes |
| Timeline event | `AuthorRecord[timeline-*]` | `TimelineService` | Yes |
| Timeline ordering (`before`/`after`/`during`) | `RecordLink` + `fields.start`/`end`/`precision` | `TimelineService` | Yes |
| Location hierarchy | `RecordLink[locatedIn\|contains]`, projected by `WorldHierarchy` | `WorldService` | Yes (edges); tree is derived |
| Map ↔ mapped area | `RecordLink[maps]` | `WorldService.createMap` | Yes |
| Marker ↔ map, marker ↔ subject | `RecordLink[onMap]`, `RecordLink[represents]` | `WorldService.createMapMarker` | Yes |
| **Marker coordinates (`x`, `y`)** | `AuthorRecord[map-marker].fields` | **Map/World Studio — map-owned** | Yes |
| Route endpoints | `RecordLink[routeFrom\|routeTo]` + `fields.startId`/`endId` | `WorldService.createRoute` | Yes (duplicated in both places) |
| Research connection | `RecordLink[documents]` | `ConnectionEngine` via Story Codex | Yes |
| **Research side-panel items** | `SharedPreferences['author_studio.research_panel.<projectId>']` | `ProjectResearchStore` — **outside the graph** | Yes, but not in the graph or the archive |
| Scene → Chapter membership | `ManuscriptNodeReference.extensionData['chapterId']` | `ManuscriptStore` — **not an edge** | Yes, as an untyped JSON string |
| Scene / chapter title, order, status | `ManuscriptNodeReference` (projected from `SharedPreferences`) | `ManuscriptStore` | Yes (projection) |
| **Scene content (the prose)** | `SharedPreferences['author_studio.manuscript_studio.<projectId>']` | `ManuscriptStore` — **outside the graph** | Yes, but not in the graph or the archive |
| Word / chapter / scene counts | Recomputed from manuscript content | `ManuscriptStore` → `AnalyticsService` (consumer) | **No** |
| Manuscript node seeding on first read | Starter-project template | `ManuscriptStore.loadStudio`, reached via `AnalyticsService`/`WorldBoardService` | Yes — **a read that writes nodes**, see R-21 |
| Version history | `RecordVersionRows` | `VersionAuditService` | Yes |
| Activity feed | `AuditEventRows` | `VersionAuditService` | Yes |
| Writing statistics / sessions | — | **NOT PRESENT** | — |

Answering the directive's question directly:

> **Which system owns the truth for each graph edge?**
> For every *explicit* edge in AuthorOS: `ConnectionEngine`, backed by
> `record_link_rows`, with `VersionAuditService` owning its history. There is exactly one
> owner and exactly one table. The Studios are callers, not owners. Analytics, World
> Board and the Continuity engines are **consumers only** — none of them writes a link.
>
> The one qualification: Analytics and World Board can *create manuscript nodes* as a side
> effect of reading a never-opened manuscript (R-21). They still never create an edge.

---

## 9. Project Isolation Audit

### 9.1 Where isolation is enforced

| Layer | Enforcement | Reference |
|---|---|---|
| Schema | **None.** One database, one edge table, no project column constraint on links beyond `scope_id` | `authoros_database.dart` |
| `ConnectionEngine.connect()` | Resolves `entityProjectId` for **both** endpoints; throws `Connection endpoints must exist in <scopeId>` if either differs | `connection_engine.dart:41-45` |
| `ConnectionEngine.connections/outgoing/incoming` | `_requireEntity` throws unless the entity's project matches | `connection_engine.dart:229-233` |
| `ConnectionEngine.updateConnection/disconnect` | Rejects links whose `scopeId` differs | `connection_engine.dart:113,206` |
| `RecordService._validateLinks` | Rejects `link.scopeId != projectId`, links not referencing the record, **and** links whose either endpoint resolves to a different project (`Link … crosses project boundaries`) | `record_service.dart:377-397` |
| `RecordService.getRecord` | `_belongsToProject` gate on every read | `record_service.dart:352` |
| `UniversalSearchService` | Throws if the filter's project differs; `_matches` re-checks every hit | `universal_search.dart:36-46,159` |
| `ConnectionEngine.linkedRecords` | Silently drops linked records from other projects | `connection_engine.dart:196-198` |

### 9.2 The directive's test case

```
Project A: Character A     Project B: Character B
```

`ConnectionEngine(scopeId: 'project-a').connect(sourceId: 'char-a', targetId: 'char-b', …)`
resolves `entityProjectId('char-b') == 'project-b' != 'project-a'` and throws
`StateError('Connection endpoints must exist in project-a.')`.

**The architecture prevents the cross-project link on every supported write path.**
Cross-project relationships are *not* supported, and this audit adds nothing to change that.

### 9.3 Gaps

1. **Raw repository writes bypass every check above.**
   `DriftConnectedDomainRepository.putLink()` and `.putRecordsAndLinks()` perform no
   project validation. One production caller exists:
   `world_studio.dart:270` uses `putRecordsAndLinks` on the legacy-record-type migration
   path, skipping validation, connection-type compatibility, versioning **and** audit.
2. **`_belongsToProject` is permissive by design.** It accepts a match on `projectId`
   *or* `scopeId` *or* `fields['projectId']` *or* `fields['_codex.projectId']`
   (`record_service.dart:352-356`) to tolerate legacy records. A record with a stale
   `fields['projectId']` could read as belonging to two projects.
3. **Nothing in the schema stops it.** Isolation is a service-layer invariant only. A
   future Story Graph that reads the repository directly — rather than through
   `ConnectionEngine` — would inherit no protection.

---

## 10. Versioning / History Audit

Current behaviour, documented and unchanged by this milestone.

| Operation | `AuthorRecord` | `RecordLink`s | Versions | Audit | Graph visibility |
|---|---|---|---|---|---|
| **Edit** | `revision + 1`, `updatedAt` set; scope, type and ownership **immutable** (update throws otherwise) | Untouched unless passed in `links:` | New `RecordVersion` with a full JSON snapshot, chained by `previousVersionId` | `updated` / `renamed` / `statusChanged` / `templateChanged`, classified by `_classifyChange` | Unchanged |
| **Archive** | `status = archived` via `updateRecord` | **Untouched — edges stay live** | New version | `archived` | Node still traversable; edges still resolve. `WorldBoardService`/`AnalyticsService` filter it out; the search index keeps it with `lifecycle_status = 'archived'` |
| **Restore** | `status = active` | Untouched | New version | `restored` | Restored |
| **Delete** | `status = deleted` — **soft only. No production code path physically deletes a record.** | **Untouched — edges to a deleted node remain live and traversable** | New version | `deleted` | Node still in the edge table and still in the FTS index (filterable by `lifecycle_status`). `RecordService.searchRecords` excludes it; `UniversalSearchService` does not unless `lifecycleStatus` is filtered |
| **Duplicate** | New id, `status = active`, fields/tags copied, `extensionData['duplicatedFrom']` stamped | **Not copied — the duplicate is created with zero edges** | New version for the new record | `duplicated` with `{duplicatedFrom}` | Duplicate appears as an isolated node |
| **Restore version** | Fields/scope/canon restored from snapshot; `revision` continues forward from *current* | `changeScope` and `restoreVersion` both call `putRecordWithHistory(links: const [])` — existing links are validated against the restored record but **not rewritten** | New version | `restored` with `{restoredVersionId}` | Unchanged |
| **Disconnect** | — | **Row hard-deleted** | New version (snapshot of the removed link) | `connectionRemoved` | Edge disappears; its history remains |

Manuscript nodes are the exception to all of the above: `putManuscriptNodes` writes no
version and no audit event, and `ManuscriptNodeReference` has no `status` field. They can
be neither archived nor deleted (§18, R-1).

### Risks (documented, not fixed)

- **Soft-deleted nodes stay in the graph.** Any future graph read that does not filter
  `AuthorRecordStatus.deleted` will render deleted characters and their edges. There is no
  cascade, no tombstone edge state, and no "deleted" marker on the link.
- **Duplication silently drops the graph position.** Duplicating a well-connected character
  yields an orphan. `SafeDeleteService` warns about many things; nothing warns about this.
- **Version snapshots do not include edges.** `RecordVersion.snapshot` is `record.toJson()`.
  Restoring a version restores fields, never relationships. A graph "time travel" view
  cannot be built from record versions alone — it would have to replay
  `connectionAdded`/`connectionRemoved` audit events.
- **`SafeDeleteService` treats any edge as blocking.** Non-zero incoming *or* outgoing
  connections set `SafeDeleteDisposition.blocked`. For a graph-connected project this means
  effectively nothing is ever physically deletable — which is safe, and worth stating
  plainly before anyone designs a graph-driven delete flow.

---

## 11. Backup / Export Audit

### 11.1 What the archive preserves

`AuthorOsArchiveService` (`lib/archive/authoros_archive.dart`) writes a zip with a
canonical-JSON manifest, per-entry SHA-256 checksums and a content fingerprint, and
re-validates the whole snapshot through `InMemoryConnectedDomainRepository` on both export
and import.

| Archive entry | Covers | Directive item |
|---|---|---|
| `data/records.jsonl` | Every `AuthorRecord` | **Records — yes** |
| `data/links.jsonl` | Every `RecordLink` | **RecordLinks — yes** |
| `data/manuscript-nodes.jsonl` | Every `ManuscriptNodeReference` | Chapter/scene *identity* only |
| `data/record-types.jsonl` | Custom node types | — |
| `data/connection-types.jsonl` | Custom edge types | — |
| `data/branches.jsonl`, `branch-record-overlays.jsonl`, `branch-link-overlays.jsonl` | Branch model | — |
| `data/versions.jsonl` | All `RecordVersion`s | — |
| `data/audit-events.jsonl` | All `AuditEvent`s | — |

By record type, all inside `records.jsonl`: **Research records — yes**
(`research-entry`/`research`). **Map records — yes** (`map`, `map-marker` incl. `x`/`y`,
routes). **Timeline records — yes.** **Plot records — yes.**
**Character relationships — yes** (they are links).

Import is strict: unknown paths, manifest mismatches, checksum failures, absolute or
`..` paths, symlinks, oversized entries and fingerprint mismatches all throw.

### 11.2 What exists **outside** the canonical graph

Nothing in this list is in the archive. All of it is real author-created data.

| Data | Store | Key | Severity |
|---|---|---|---|
| **Manuscript prose (scene `content`)** | `ManuscriptStore` | `author_studio.manuscript_studio.<projectId>` and legacy `author_studio.manuscript.<projectId>` | **CRITICAL** |
| **Research side-panel items** | `ProjectResearchStore` (`main.dart:1659`) | `author_studio.research_panel.<projectId>` | **HIGH** |
| Legacy timeline state (eras, sequences, events) | `TimelineStore` (`timeline.dart:300`) | `author_studio.project.<projectId>.timeline` | MEDIUM |
| Visual planning board | `VisualPlanningStore` | `author_studio.project.<projectId>.visual_planning` | MEDIUM |
| Starter project + onboarding | `OnboardingStore` | `author_studio.starter_project`, `author_studio.onboarding_complete` | MEDIUM |
| Author profile | `AuthorProfileStore` | `author_studio.profiles`, `author_studio.profile.*` | LOW |
| Theme, reading rhythm | `ThemePersistence`, `ReadingRhythmStore` | `author_studio.theme*`, `…reading_rhythm` | LOW — application setting, correctly outside |
| Sync queue / cursor | `SyncStore` | `author_studio.sync.*` | LOW — operational, correctly outside |
| Backup health | `BackupHealth` | `author_studio.backup_*` | LOW — operational, correctly outside |

`docs/persisted-data-inventory.md` already classifies these; this audit confirms the
classification still holds and that none of the "Creative corpus" entries have migrated.

### 11.3 The Research migration issue

Confirmed exactly as the directive describes, and **left in place**.

`ProjectResearchStore` (`lib/main.dart:1659-1702`) persists a
`Map<ResearchTab, List<ResearchReference>>` as JSON in `SharedPreferences` under
`author_studio.research_panel.<projectId>`. A `ResearchReference` is
`{title, detail, tag}` — no id, no record type, no scope, no links, no version, no audit.

The consequences for a Story Graph:

- These items **cannot be graph nodes.** They have no stable identity to link to.
- They are **not in the archive.** A restore loses them silently.
- They are **invisible to Universal Search.**
- `AnalyticsService.researchItemCount` counts `research-entry`/`research` **records**, not
  panel items — so the Analytics research count and the Research panel can disagree
  completely, and today usually will (records: created via Story Codex; panel: created via
  the side panel).

Migrating them to `research-entry` records is the obvious fix. It is **explicitly deferred**
by this milestone and is proposed as Story Graph Phase 2 groundwork in §20. Guardrail test
`story_graph_architecture_test.dart` asserts the deferral is deliberate, so that a future
migration is a conscious decision rather than an accident.

---

## 12. Search / Discovery Audit

### 12.1 What Universal Search can find today

`UniversalSearchService` over the `author_search` FTS5 table.

| Question | Answer |
|---|---|
| Find **records** by text? | **Yes.** Title, `fields` JSON body and tags are indexed. Prefix-matched, AND-joined, ranked |
| Find **manuscript nodes**? | **Yes**, by title — but the indexed body is `extensionData`, so **scene prose is not searchable** |
| Find **branch records**? | Yes — overlays are indexed under a synthetic `branch-record:<b64>:<b64>` entity id |
| Filter by type / series / book / branch / canon status / lifecycle status? | Yes — all are `UNINDEXED` FTS columns plus a `_matches` post-filter |
| Route a hit to the right Studio? | Yes — `searchDestinationForType` / `SearchNavigationTarget` |
| Find **relationships**? | **No.** No link, edge type, edge label or edge metadata is indexed anywhere |
| Find **connected records** (traverse from a hit)? | **No, not from search.** `UniversalRecordInspector.searchAndInspect` searches, then inspects each hit one node deep — but that is N+1 point lookups, not graph search |

### 12.2 What a Story Graph explorer would additionally require

Stated as requirements, not implemented:

1. **A neighbour-expansion read path.** `repository.backlinks(entityId)` already returns
   both directions in one query; `outgoingLinks`/`incomingLinks` split it. A
   breadth-limited expansion needs only to batch these.
2. **Batch node hydration.** Today `linkedRecords` issues one `recordById` per edge. A
   subgraph of 200 nodes would issue 200 queries. An `recordsByIds(Iterable<String>)`
   repository method is the single most valuable addition — and it is a *query*, not a
   schema change.
3. **Manuscript-node hydration in the same call.** `entityTypeId` already falls back to
   `manuscriptNodeById`; a graph read must do the same or half the manuscript spine
   disappears.
4. **Edge-type filtering at the query level.** `relatedTo` alone will swamp any view.
   `record_link_rows.type_id` is a plain column — a `WHERE type_id IN (…)` filter needs no
   migration.
5. **Optional: an edge-aware search index.** Only if "find the relationship, not the
   record" becomes a product requirement. Deferred — it *would* be a new persistence
   concern and must not be undertaken casually.

---

## 13. World Board / Map Relationship Audit

Read-only. Map Studio unmodified. Phase 3 not started.

| Relationship | State | Mechanism |
|---|---|---|
| World → Location | **Exists** | `locatedIn` / `contains`, both typed over 47 spatial types |
| Location → Location (hierarchy) | **Exists** | Same edges, projected into a tree by `WorldHierarchy` (`core/world_domain.dart`). `WorldService.attachToParent` rejects self-parenting, non-spatial endpoints and cycles |
| Location → Location (spatial relations) | **Exists** | 16 typed edges: `above`, `below`, `northOf`, `southOf`, `adjacentTo`, `borders`, `near`, `farFrom`, `inside`, `outside`, `surrounds`, `crosses`, `passesThrough`, `accessibleFrom`, `inaccessibleFrom`, `locatedIn` |
| Map → Location | **Exists** | `maps` (9 map types → 47 spatial), written by `WorldService.createMap` |
| Map Marker → Map | **Exists** | `onMap`, written by `WorldService.createMapMarker` |
| Map Marker → *anything* | **Exists but untyped** | `represents` (`map-marker` → `*`) |
| Marker coordinates | **Map-owned record fields** | `x`, `y`, `label`, `icon`, `category`, `visibility` on the `map-marker` record. Not edges, not geometry |
| Route → Location | **Exists** | `routeFrom` / `routeTo` (11 route types → 47 spatial), plus duplicated `startId`/`endId` fields |
| Character → Location | **Exists** | 12 typed edges (§4.1) |
| Timeline Event → Location | **Exists** | `occursAt` (27 timeline types + `historical-event` + `scene` + 31 plot types → spatial) |
| Timeline Event → Map | **Wildcard only** | No typed edge |
| **Map Region** | **NOT PRESENT** | No node type, no polygon/area geometry, no region membership edge |

World Board itself is a pure consumer: `WorldBoardService` reads
`WorldService`, `TimelineService`, `PlotService`, `ManuscriptStore` and
`VersionAuditService` and writes nothing. Its own doc comment states the rule the graph
should keep: *"every number it reports has to come back from one of those services."*

**Known limitation, already self-declared:** `UniversalRecordInspector` lists
`ReferenceKind.map` under `unsupportedReferenceKinds` with the note *"Map markers do not
yet have a canonical shared reference projection."* A Story Graph inherits that gap.

---

## 14. Analytics Relationship Audit

`AnalyticsService` owns no storage and persists nothing. Its own header states it:
*"Analytics is reproducible from source data: nothing calculated here is persisted, and
calculating never mutates a source record."* The audit confirms it — there is no write
call anywhere in the file.

| Metric | Classification | Source |
|---|---|---|
| `characterCount` | **DIRECT RECORD DATA** | `recordsByTypeAndScope(typeId: 'character')`, minus deleted |
| `timelineEventCount` | **DIRECT RECORD DATA** | `TimelineService.query.all()`, minus deleted |
| `plotRecordCount` | **DIRECT RECORD DATA** | `PlotService.query.all()`, minus deleted |
| `researchItemCount` | **DIRECT RECORD DATA** | `research-entry` + `research` records — **not** the Research panel (§11.3) |
| `charactersWithProfiles` | **DERIVED FROM RECORDS** | Any populated field beyond `identity.displayName`/`identity.fullName` |
| `activePlotThreadCount`, `completedPlotThreadCount` | **DERIVED FROM RECORDS** | `fields['plotStatus']` semantics mirrored from Plot Studio |
| `manuscriptStatus` | **DERIVED FROM RECORDS** | Folded from chapter statuses |
| **`charactersWithRelationships`** | **DERIVED FROM RECORD LINKS** | `CharacterService.getCharacterRelationships` → 10 relationship edge types, per character |
| **`charactersReferencedInManuscript`** | **DERIVED FROM MANUSCRIPT CONTENT** | Case-insensitive substring of `record.title` in concatenated scene `content` |
| `totalWordCount`, `chapterCount`, `sceneCount`, `chaptersByStatus`, `longestChapter`, `shortestChapter` | **DERIVED FROM MANUSCRIPT CONTENT** | `ManuscriptStore.loadStudio` |
| `targetWordCount`, `progressTowardTarget`, `wordsRemaining` | **DIRECT RECORD DATA** (project) + derived ratios | `StarterProject.wordGoal` |
| *Anything* **DERIVED FROM WRITING SESSION HISTORY** | **NOT PRESENT** | No writing-session system exists (§3.2) |

**Verdict: Analytics owns no graph truth.** It writes no record, no link, no version and
no audit event — confirmed by test, not just by the file's own claim.

**One correction to that claim, found by the guardrail test.** `AnalyticsService`'s own
header says *"calculating never mutates a source record"*. That is true of records — and
not the whole story. `getSummary()` calls `_loadManuscript()` → `ManuscriptStore.loadStudio()`,
which on a project whose manuscript has never been opened seeds a starter manuscript and
calls `saveStudio()` — which calls `putManuscriptNodes()`. **Opening the Analytics
dashboard on a fresh project therefore creates chapter and scene nodes in
`connected_entities` and `manuscript_node_rows`.** The effect is confined to manuscript
nodes, is idempotent after the first read, and `WorldBoardService.load()` shares it
verbatim. It is recorded as risk R-21 and pinned by test (§21).

The one metric that needs watching is `charactersReferencedInManuscript`. It is a genuine
derived relationship — the exact `Character --appears_in--> Scene` case the directive
raises — computed by naive substring match. It is **correctly not persisted**, but it is
also **fragile**: a character named "Will" matches every occurrence of the word "will".
Any future derived-relationship engine must not adopt this heuristic as-is.

---

## 15. Future Story Graph API — Design Only

No implementation. Names chosen to match the architecture actually found, not a generic
graph vocabulary. **Read-only in Phases 1–3.**

Proposed surface: `StoryGraphService({required String projectId, required
DriftConnectedDomainRepository repository, String? branchId})` — mirroring the constructor
shape every existing service uses.

| Method | Why needed | Delegates to | R/W | Returns |
|---|---|---|---|---|
| `getNode(String id)` | A graph view must render both record and manuscript-node kinds through one call. Nothing does this today — `RecordService.getRecord` returns `null` for manuscript nodes | `repository.recordById` → falls back to `repository.manuscriptNodeById`; project-checked via `entityProjectId` | **Read** | `StoryGraphNode?` — a union carrying `id`, `kind`, `typeId`, `title`, `projectId`, `canonStatus`, `lifecycleStatus`, and `versioned`/`deletable` capability flags so callers cannot assume manuscript nodes behave like records |
| `getEdges(String nodeId)` | Both directions in one query is what every graph view needs first | `ConnectionEngine.connections` (which enforces project scope via `_requireEntity`) | **Read** | `List<StoryGraphEdge>` |
| `getOutgoingEdges(String nodeId)` / `getIncomingEdges(String nodeId)` | Direction matters for rendering arrows and for inverse labels | `ConnectionEngine.outgoing` / `.incoming` | **Read** | `List<StoryGraphEdge>` |
| `getNeighbours(String nodeId, {Set<String>? edgeTypeIds, Set<String>? nodeTypeIds, bool includeArchived = false, bool includeDeleted = false})` | One-hop expansion is the core explorer interaction. Filters are mandatory, not optional — `relatedTo` is suggested on all 222 types and would swamp an unfiltered view | `getEdges` + batched node hydration | **Read** | `StoryGraphNeighbourhood` — centre node, edges, hydrated neighbours, and a `truncated` flag |
| `getSubgraph(String rootId, {int depth = 2, …filters, int maxNodes = 250})` | Character/plot/world views are all bounded subgraphs. Depth **and** node cap are both required — the wildcard edge density makes an unbounded walk unsafe | Repeated `getNeighbours`, deduplicating by id | **Read** | `StorySubgraph` — nodes, edges, `depthReached`, `truncated` |
| `getProjectGraph({…filters, int maxNodes})` | The whole-project view of §16 | `repository.recordsByProject` + a single link sweep | **Read** | `StorySubgraph` |
| `findPaths(String fromId, String toId, {int maxDepth = 4, int maxPaths = 10})` | "How is Kali connected to the Iron Compact?" is the question a graph answers that no current screen can | Bounded bidirectional search over `getEdges` | **Read** | `List<StoryGraphPath>` |
| `getDerivedEdges(String nodeId)` | Keeps §7.3 structurally true: derived edges arrive in a **separate call returning a different type**, so they can never be mistaken for links | A derived-edge provider registry (Phase 5); initially returns empty | **Read** | `List<DerivedStoryGraphEdge>` — carries `derivation`, `confidence`, and `promotable`, and has **no `id`**, so it is not persistable by construction |
| `getNodeHistory(String nodeId)` | Version/audit panel in the inspector | `VersionAuditService.getVersionHistory` / `.getAuditHistory` | **Read** | `HistoryInspection` *(reuse the existing type)* |
| `inspect(String nodeId)` | The detail panel. **Already implemented** — the graph must call it, not reimplement it | `UniversalRecordInspector.inspectRecord` | **Read** | `UniversalRecordInspection` *(existing type)* |

Deliberately **not** proposed for Phases 1–3:

- No `connect` / `disconnect` / `createNode`. Writes stay on `ConnectionEngine` and
  `RecordService`. When Phase 2 adds relationship management, it should be a thin
  delegation (`StoryGraphMutations`) that adds **no validation of its own** — duplicating
  validation is how a second relationship system gets built by accident.
- No graph-specific persistence of any kind.
- No caching layer until profiling proves one is needed; a stale graph cache is a
  correctness bug, not a performance win.

Required repository additions (queries only, **no schema change**):

```
Future<List<AuthorRecord>>            recordsByIds(Iterable<String> ids)
Future<List<ManuscriptNodeReference>> manuscriptNodesByIds(Iterable<String> ids)
Future<List<RecordLink>>              linksForEntities(Iterable<String> ids, {Set<String>? typeIds})
```

These replace the current per-edge N+1 pattern in `ConnectionEngine.linkedRecords`.

---

## 16. Future Graph View Design — No UI Implementation

Concepts only. Each names its root, its edge filter and its known gap.

| View | Root | Nodes | Edge filter | Known gap |
|---|---|---|---|---|
| **Project Graph** | Project | All records + manuscript nodes | All, with a type-filter panel; `relatedTo` off by default | Node count is unbounded — needs the `maxNodes` cap and type filtering from the first sketch |
| **Character Graph** | One `character` | Characters, factions, locations, items, plot threads, scenes | The 12 character-relationship edges + `memberOf`, `owns`/`uses`/`carries`, `livesIn`/`bornIn`/`worksIn`/`visits`, `appearsIn`/`mentionedIn`, `pursues`/`hasArc` | Character → timeline-event is wildcard-only; the typed edge runs the other way (`involves`) |
| **Plot Graph** | One plot record | Plot thread → scenes → characters → timeline events | `pursues`, `hasArc`, `appearsIn`, plus the wildcard plot edges (`plannedFor`, `fulfilledBy`, `resolvesIn`, `paidOffBy`, `causes`, `opposes`, …) | Scene → plot is **entirely wildcard**; and scenes are manuscript nodes, not the `scene` records `PlotService` queries (§3.3) |
| **World Graph** | One `world` or `location` | Locations, regions-as-locations, maps, markers, routes, characters, events | The 16 spatial edges + `maps`, `onMap`, `represents`, `routeFrom`/`routeTo`, `occursAt`, character-location edges | No map-region node; marker `x`/`y` are map-owned and must be rendered by Map Studio, never re-derived by the graph |
| **Research Graph** | One `research-entry` | Research → any documented entity | `documents` | Wildcard target; and the Research **panel** items are not nodes at all (§11.3) |
| **Timeline Graph** | One `timeline` or `timeline-event` | Events → characters → locations → plot | `occursAt`, `involves`, `before`/`after`/`during`/`overlaps`/`concurrentWith`/`causedBy` | The ordering edges are all wildcard; real ordering also lives in `fields.start`/`end`/`precision`, so the view must reconcile edges with field data |

Cross-cutting requirements for every view:

- **Explicit and derived edges must be visually distinct.** Same rule as §7.3, at the
  presentation layer.
- **Branch and canon status must be visible**, not silently applied. A graph that hides
  `draft` nodes without saying so is a continuity hazard.
- **Archived and soft-deleted nodes are hidden by default and revealable** — they remain in
  the edge table (§10) and pretending otherwise misrepresents the data.
- **Every node opens `UniversalRecordInspector`.** The detail panel already exists; the
  graph should not grow a second one.

---

## 17. Graph Consistency Rules (Future Invariants)

Each rule is marked with whether the architecture already enforces it.

| # | Invariant | Status |
|---|---|---|
| I-1 | **No dangling `RecordLink`s.** Both endpoints must exist in `connected_entities` | **ENFORCED** — FK on both columns + `PRAGMA foreign_keys = ON`; `_validateState` re-checks on every snapshot import |
| I-2 | **No cross-project links.** Both endpoints resolve to the same project | **ENFORCED on validated write paths** (`ConnectionEngine`, `RecordService`). **NOT enforced** on raw `putLink`/`putRecordsAndLinks` (§9.3) |
| I-3 | **One edge per (project, source, type, target).** | **ENFORCED** for `ConnectionEngine.connect` via the deterministic link id — a repeat connect returns the existing link. **Not enforced** for raw writes |
| I-4 | **Edge endpoints must satisfy the connection type.** | **ENFORCED** via `ConnectionTypeRegistry.validateConnection` — but 70 of 127 types permit `*` → `*`, so enforcement is real yet mostly vacuous (§4.2) |
| I-5 | **Edge direction must match its type.** | **ENFORCED** — both `ConnectionEngine` and `RecordService._validateLinks` reject a mismatch |
| I-6 | **Edge metadata must match the type's `metadataFields`.** Unknown keys and missing required keys rejected | **ENFORCED** — `_validateMetadata` |
| I-7 | **Archived nodes remain historically addressable.** | **ENFORCED** — archive is a status change; versions, audit events and edges all survive |
| I-8 | **Deleted nodes have deterministic link behaviour.** | **PARTIAL** — deletion is soft and edges are deliberately preserved, which is deterministic. But no consumer contract says so, and no filter is applied by default. **Future requirement:** the graph read model must exclude `deleted` nodes unless explicitly asked |
| I-9 | **Derived relationships must never masquerade as persisted links.** | **HOLDS TODAY** by construction (§7). **Future requirement:** enforce structurally — derived edges returned by a different method, in a different type, with no `id` |
| I-10 | **Analytics must not become an independent source of graph truth.** | **HOLDS** for records, links, versions and audit events — pinned by test. **PARTIAL** for nodes: reading Analytics can seed manuscript nodes (R-21). **Future requirement:** seeding moves out of the read path |
| I-11 | **Map coordinates remain map-owned data.** | **HOLDS TODAY** — `x`/`y` are `map-marker` record fields written only by `WorldService.createMapMarker`. **Future requirement:** the graph reads them, never writes them |
| I-12 | **Writing sessions remain analytics-history data.** | **LIVE and HOLDING** — the system now exists (§0). `writing_session_rows` has no FK into `connected_entities`, no record type, and no connection type takes a session as an endpoint. Pinned by test |
| I-13 | **One edge table.** No second relationship model, ever | **HOLDS** — `record_link_rows` is the only edge table. **At risk**: `ImpactTraceAnalyzer`'s `TraceLink` and `ManuscriptScene.relationships` are both parallel edge shapes already in the tree (§18) |
| I-14 | **Manuscript-node edges must tolerate a non-record endpoint.** | **Permanent under D-3** (was transitional under the withdrawn D-1). `entityTypeId` already falls back to `nodeType`, but `RecordService.getRecord` returns `null` and `ConnectionEngine.linkedRecords` silently drops manuscript nodes. Phase 0 removes the need |
| I-15 | **The graph owns no storage.** | **Future requirement** — the defining constraint of the whole design |
| I-16 | **Historical and operational data never participates in the graph.** Writing sessions, audit history, version history and activity history may reference graph entities by id, but must never be a node, a record type, or an edge endpoint | **HOLDS** — generalises I-12 from writing sessions to the whole class. The test is participation, not proximity: a soft id reference is fine, a foreign key into `connected_entities` is not. See "The graph boundary" in §0 |

---

## 18. Architectural Risks

| # | Risk | Rank | Detail | Evidence |
|---|---|---|---|---|
| R-1 | **Manuscript nodes are never deleted** *(closed by D-1, Phase 0)* | **CRITICAL** | `putManuscriptNodes` is upsert-only with no reconciliation. Deleting a scene in Manuscript Studio leaves the `manuscript_node_rows` row, its `connected_entities` row, every link pointing at it, and its FTS entry — permanently. `ManuscriptNodeReference` has no `status` field, so it cannot even be soft-deleted. A Story Graph would render ghost scenes with no way to remove them | `authoros_database.dart:445-456`; `manuscript_store.dart:666-694`; `connected_domain.dart:167-191` |
| R-2 | **Manuscript prose is outside the canonical graph and outside the archive** *(closed by D-1, Phase 0)* | **CRITICAL** | Scene `content` lives only in `SharedPreferences`. The archive preserves scene *identity* and never the writing. A restore from archive returns a fully-connected graph of empty scenes | `manuscript_store.dart:552-694`; `authoros_archive.dart` entry list |
| R-3 | **Type compatibility is largely nominal** | **HIGH** | 70 of 127 connection types are `*` → `*`. Of 27 relationship pairs tested, 12 have **no** typed edge — including every Research relationship, both manuscript containment edges, and scene→plot. Validation runs and always passes, giving false confidence | Registry dump, §4.2/§4.3 |
| R-4 | **Research data is duplicated across two incompatible systems** *(CLOSED — migrated on `main`, see §0)* | ~~HIGH~~ | `ProjectResearchStore` (SharedPreferences, no ids) vs `research-entry` records (graph, archived, searchable). `AnalyticsService.researchItemCount` counts only the latter, so the dashboard and the panel routinely disagree | `main.dart:1659`; `analytics_service.dart` `researchTypeIds` |
| R-5 | **`scene`/`chapter` record types shadow manuscript nodes** *(closed by D-1, Phase 0)* | **HIGH** | Both are registered types *and* manuscript node kinds. `PlotService` queries `recordsByTypeAndScope(typeId: 'scene')` and will always find zero, silently disabling its `orphaned-scene` validation. A graph that treats "scene" as one thing will be wrong half the time | `plot_service.dart:416`; `manuscript_store.dart:685` |
| R-6 | **A second graph traversal model already exists in the tree** | **MEDIUM** | `ImpactTraceAnalyzer` implements depth-limited BFS and shared-scene inference over its own `TraceEntity`/`TraceLink` types, unrelated to `AuthorRecord`/`RecordLink`. It has **no production callers** — only `test/impact_trace_test.dart`. Left unaddressed, it is the most likely seed of a duplicate relationship system | `lib/impact_trace.dart`; caller search |
| R-7 | **`ManuscriptScene.relationships` is a third relationship shape** *(closed by D-1, Phase 0 step 7)* | **MEDIUM** | `SceneRelationship {id, type, targetId, label, metadata}` persists scene-local edges in SharedPreferences. `LegacyConnectionSliceAdapter` can convert them to `RecordLink`s, but that path is behind `AUTHOROS_CONNECTED_DOMAIN`, **off by default** — so these edges exist and are invisible to the graph | `manuscript_store.dart:85-133`; `legacy_connection_slice.dart:6-10` |
| R-8 | **Validated-write bypass in World Studio** | **MEDIUM** | `world_studio.dart:270` calls `repository.putRecordsAndLinks` directly on the legacy-type path, skipping record validation, connection compatibility, project-boundary checks, versioning and audit | `world_studio.dart:270` |
| R-9 | **Duplication drops all relationships** | **MEDIUM** | `RecordService.duplicateRecord` copies fields and tags but creates the duplicate with zero links, and nothing warns the author | `record_service.dart:176-215` |
| R-10 | **Soft-deleted nodes remain fully traversable** | **MEDIUM** | Deletion sets `status = deleted`; every edge survives, and the FTS row survives with `lifecycle_status = 'deleted'`. Any graph read that forgets the filter renders deleted characters as live | `record_service.dart:167-172`; `_indexEntity` |
| R-11 | **Project isolation has no schema backing** | **MEDIUM** | One database for all projects; isolation lives entirely in service-layer checks. Raw repository access inherits none of it, and `_belongsToProject` deliberately accepts four different project signals | §9.3 |
| R-12 | **`ConnectionCardinality` is declared and never enforced** | **MEDIUM** | All 127 types are `manyToMany`; the enum appears nowhere outside its own model and JSON codec. Any future "one home location per character" rule has nothing to build on | Registry dump; grep of `cardinality` |
| R-13 | **Search cannot see relationships** | **MEDIUM** | The FTS index covers title, `fields` JSON and tags. No edge, edge type or edge metadata is indexed. A graph explorer's search box cannot answer "find the mentor relationship" | `_createSearchIndex`, `_indexEntity` |
| R-14 | **Scene prose is not searchable** *(closed by D-1, Phase 0)* | **MEDIUM** | Manuscript nodes are indexed with `body = extensionData`, and the prose is not in `extensionData` | `_putManuscriptNode` |
| R-15 | **Version snapshots exclude relationships** | **MEDIUM** | `RecordVersion.snapshot` is `record.toJson()`. Restoring a version restores fields, never edges. Graph time-travel would have to replay audit events instead | `version_audit_service.dart` `forRecord` |
| R-16 | **`relatedTo` will dominate every graph view** | **MEDIUM** | Wildcard, undirected, and suggested on all 222 record types. Without a default-off filter, the Project Graph degenerates into a hairball | `built_in_record_types.dart:189` and registry dump |
| R-17 | **`SafeDeleteService` blocks on any edge** | **LOW** | Any incoming *or* outgoing connection sets `blocked`. Correct and conservative, but it means physical deletion is effectively unreachable in a connected project — worth knowing before designing a graph delete flow | `safe_delete_service.dart:105-113` |
| R-18 | **Dead type definitions** | **LOW** | `_world` and `_location` in `built_in_record_types.dart` are unreachable; adding them to the list would throw on duplicate ids | `built_in_record_types.dart:196,243` |
| R-19 | **Route endpoints stored twice** | **LOW** | `routeFrom`/`routeTo` links *and* `fields.startId`/`endId`. Nothing keeps them in sync | `world_service.dart:555-580` |
| R-22 | **Writing sessions are not in the archive** | **MEDIUM** | `writing_session_rows` is the twelfth table, but `AuthorOsArchiveService` still writes the same ten entries. A project exported and re-imported loses its entire writing history — every daily total, streak and longitudinal metric. Correctly *outside* the graph per I-16, but backup is a separate concern from graph membership, and this is a real data-loss path | `authoros_archive.dart` entry list vs `@DriftDatabase` tables |
| R-21 | **Reading Analytics or World Board writes graph nodes** | **MEDIUM** | `getSummary()` / `load()` → `ManuscriptStore.loadStudio()` seeds and saves a starter manuscript when none exists, and `saveStudio` projects chapter and scene nodes into `connected_entities` and `manuscript_node_rows`. A dashboard read thus creates graph nodes. Idempotent after the first read and confined to manuscript nodes — but it means "open the dashboard" and "create nodes" are the same action, and combined with R-1 those nodes can never be removed. **Decision D-1 raises this to a Phase 0 blocker**: once scenes are records, the same read would write a version and an audit event per seeded node, manufacturing history for content the author never typed | `analytics_service.dart` `_loadManuscript`; `world_board_service.dart` `_loadManuscript`; `manuscript_store.dart:622-647` |
| R-20 | **Derived character-in-manuscript match is naive** | **LOW** | Case-insensitive substring of the character title against scene text. "Will" matches the auxiliary verb. Correctly not persisted, but must not be reused as-is by a derived-relationship engine | `analytics_service.dart` `_countCharactersReferenced` |

Nothing in this table is fixed by this milestone.

---

## 19. Open Questions

> **Resolved.** *"Are scenes and chapters going to become `AuthorRecord`s, or stay
> manuscript nodes?"* — answered August 21, 2026: **they become records.** See decision
> D-1 in §1 and Phase 0 in §20. *"Should `chapterId` become a real edge?"* — yes, as part
> of the same migration. Both questions are closed; the questions below replace them.

> **Also resolved.** *"How is manuscript version churn handled?"* — answered August 21,
> 2026: **coalescing inside a time window, for `updated` changes only.** See decision D-2
> in §1 and Phase 0 step 1 in §20. Phase 0 is no longer blocked.

1. **Q-2 — Does scene ordering stay a field, or become graph structure?** `order` as an
   integer field is simple and matches today's model. Ordering by edge is more graph-native
   but makes an insert an O(n) rewrite. Recommendation: keep the field; ordering is
   sequence data, not a relationship.
3. **Do the 70 wildcard connection types get tightened?** Tightening improves the graph's
   semantics but is a breaking change for any project that already used them loosely.
   Registry-level deprecation may be the only safe route.
4. **Where does the Research panel go?** Migrating `ProjectResearchStore` to
   `research-entry` records is the obvious answer, but the panel's items have no ids —
   migration must synthesise them, and that is a one-way door.
5. **Should `ImpactTraceAnalyzer` be deleted or absorbed?** It is unused and it is the
   likeliest accidental seed of a second graph. Absorbing its BFS into `getSubgraph` and
   deleting the file would be cleaner than leaving it.
6. **Does the graph need branch awareness in Phase 1, or later?** `BranchService` and the
   overlay tables exist, and `UniversalRecordInspector` already resolves per branch.
   Deferring branch support is possible but retrofitting it is expensive.
7. **What is the node budget for a graph view?** No project in the tree is large enough to
   measure. 222 types × wildcard edges suggests the cap matters more than the layout.
8. **Is a writing-session system planned at all?** The directive assumes one exists. It
   does not. If it is coming, deciding now that it is *history data, not graph data*
   (I-12) prevents it becoming a node type by default.
9. **Does cardinality get enforced?** If "one home location per character" is ever a
   product rule, `ConnectionCardinality` needs to become real — a validation change, not a
   schema change.

---

## 20. Recommended Implementation Phases

Design only. No phase is authorised by this document.

### Phase 0 — Migrate scenes and chapters to `AuthorRecord` *(SUPERSEDED — written for the withdrawn D-1; see §0)*

Not a Story Graph phase; the prerequisite that makes the rest coherent. Building a graph
read model over an entity kind that cannot be deleted would bake ghost nodes into the
product (R-1), and building it over two node kinds would double every traversal path.

**Why it is tractable.** `connected_entities` already holds records and manuscript nodes
in one id space, and `record_link_rows` references *that* table, not either concrete
table. **Preserve the ids and every existing `RecordLink` survives with zero rewriting** —
no link migration, no id remapping, no re-validation of edges. The migration flips
`connected_entities.kind` from `manuscriptNode` to `record`, inserts an
`author_record_rows` row, and deletes the `manuscript_node_rows` row. Note it is a
**swap, not a dual-write**: `ConnectedDomainTransaction` explicitly rejects an id that is
both a record and a manuscript node, and that check should stay.

**Field definitions to add.** `scene` and `chapter` are currently bare `general-lore`
children with seven inherited fields. From `ManuscriptScene` and `ManuscriptChapter`:

| Type | Fields to define |
|---|---|
| `scene` | `content`, `order`, `status`, `pov`, `location`, `timeLabel`, `notes` |
| `chapter` | `order`, `status`, `summary`, `prompt`, `pov` |

`chapterId` and `linkedChapterIds` do **not** become fields — they become typed edges,
which is the entire point (§4.3). Registering a typed `partOf` for `scene → chapter` and
`chapter → book` gives the manuscript a real spine and retires two wildcard dependencies.

**Version churn — resolved by D-2, and it lands first.** `RecordService.updateRecord`
writes a full JSON snapshot plus an audit event on *every* update, and manuscript editing
is autosave-frequency. Coalescing collapses consecutive `updated` versions of the same
entity inside a time window; every other change type always appends. Specification:

| Aspect | Rule |
|---|---|
| Eligible change type | `AuditChangeType.updated` **only** |
| Coalesce when | Same `entityId`, same `branchId`, same `source`, previous version is `updated`, and the new timestamp is within the window of the previous version's `createdAt` |
| Window | Configurable on `VersionAuditService`; default 5 minutes |
| On coalesce | Keep the existing version id and its `previousVersionId`; replace `snapshot`, `createdAt` and `summary`; increment a `coalescedCount` in metadata; leave `sequence` unchanged |
| Paired audit event | Replaced in lockstep — its id is derived as `audit-<versionId>`, so it follows the version id |
| Never coalesce | `created`, `renamed`, `archived`, `restored`, `deleted`, `duplicated`, `statusChanged`, `templateChanged`, `scopeChanged`, `branchChanged`, and all four `connection*` types |

`_insertVersion` uses `.insert()` today, so this needs a replace path on the repository —
not an upsert on a new id, which would break the chain.

**Sequencing within the phase.**

1. Implement D-2 coalescing, standalone and fully tested, **before anything else**. It
   changes version behaviour for every record type, so it should land and be verified on
   its own rather than tangled into the migration.
2. Define the `scene` / `chapter` fields and register typed `partOf`.
3. Move `ManuscriptStore`'s source of truth from the `SharedPreferences` blob to records.
   Leave the blob as a read-only migration input, then retire it. **Do not dual-write** —
   dual-writing recreates exactly the duplication this decision removes.
4. Migrate existing `manuscript_node_rows`, preserving ids.
5. Fix **R-21 first or alongside** — this decision makes it worse, not better. Today a
   cold Analytics read seeds manuscript nodes, which carry no versions and no audit. After
   D-1 the same read would seed *records*, each with a version and an audit event, so
   opening a dashboard would write history for content the author never typed. Seeding
   must move out of the read path before scenes become records.
6. Retire `ManuscriptNodeReference`, `manuscript_node_rows`, the `entityTypeId` fallback to
   `nodeType`, and invariant I-14.
7. Convert `ManuscriptScene.relationships` (R-7) into real `RecordLink`s as part of the
   same migration — with both endpoints now records, the conversion is no longer blocked
   on the `AUTHOROS_CONNECTED_DOMAIN` flag.

**What the guardrail tests will do.** Dropping `manuscript_node_rows` fails the
"exactly one persistence system" test in `story_graph_architecture_test.dart`. That is
intended: the test pins the audited table set so a change to it is a conscious act. Update
the expected set and this document together, in the same commit.

*Exit criterion:* one node kind. `connected_entities.kind` is uniformly `record`, prose
round-trips through `.authoros` export and import, a deleted scene is soft-deleted rather
than orphaned, and `PlotService`'s orphaned-scene validation returns real findings.

### Phase 1 — Core graph read model
`StoryGraphNode` / `StoryGraphEdge` / `StorySubgraph` types; `getNode`, `getEdges`,
`getOutgoingEdges`, `getIncomingEdges`, `getNeighbours`. The three batch repository queries
from §15. Read-only. No UI.
*Exit criterion:* a one-hop neighbourhood of any node, with archived/deleted filtered by
default. If Phase 0 has landed, one node kind; if it is still in flight, both — a read
model that assumes only records would be wrong on every unmigrated project.

### Phase 2 — Relationship management
`StoryGraphMutations` as a thin delegation to `ConnectionEngine` — creating, retyping,
re-metadata-ing and removing edges. **No new validation.** Groundwork for the Research
migration (R-4) belongs here, as a deliberate, author-visible action.
*Exit criterion:* every mutation path produces the same audit trail as calling
`ConnectionEngine` directly.

### Phase 3 — Graph explorer
The first UI. Project and Character graphs. Type filters mandatory, `relatedTo` off by
default, node cap enforced, `UniversalRecordInspector` as the detail panel.
*Exit criterion:* no second inspector, no second record model, no new table.

### Phase 4 — Cross-Studio integration
"Open in graph" from Character, World, Timeline, Plot and Codex Studios. World, Plot,
Timeline and Research graph views. Map markers rendered from map-owned coordinates,
never re-derived.
*Exit criterion:* Map Studio and World Board unchanged; graph reads, Studios own.

### Phase 5 — Derived relationship engine
`getDerivedEdges` with real providers. Candidates: character-in-scene text references
(replacing R-20's substring match with something defensible), shared-scene co-occurrence
(absorbing `ImpactTraceAnalyzer`), unresolved legacy references. Every derived edge is
visually distinct, separately typed, and promotable only by explicit author action with
provenance stamped into `extensionData`.
*Exit criterion:* not one derived edge reaches `record_link_rows` without an author
pressing a button.

### Phase 6 — Advanced graph analysis
`findPaths`, orphan detection, cluster and centrality views, continuity gaps surfaced
through the graph. Consumes; never writes.

### Phase 7 — Web deep-linking and sharing
Deep links to a node or subgraph. Depends on the graph read model being stable and on
scope/canon filters being explicit in the URL.

### Phase 8 — Export / presentation
Graph images and printable relationship maps. The `.authoros` archive already carries the
full graph; this phase adds presentation formats only, and must not introduce a second
serialisation of nodes or edges.

> Phases 1–4 need **no schema migration**. Phase 0 might. That ordering is deliberate.

---

## 21. Guardrail Tests

`test/story_graph_architecture_test.dart` encodes the invariants this document depends on,
so a future change that violates one fails loudly rather than silently. It asserts:

1. **One graph persistence system** — `record_link_rows` is the only edge table; the
   database declares exactly the 11 audited tables.
2. **The graph uses the existing `RecordLink`** — `ConnectionEngine.connect` writes to that
   table and nowhere else.
3. **No duplicate relationship model** — no second edge table, and no new
   `*_link*`/`*_edge*`/`*_graph*` persistence file has appeared.
4. **Project isolation** — a cross-project connect throws, and the endpoints stay unlinked.
5. **Analytics never owns graph truth** — a full `getSummary()` leaves records, links,
   versions and audit events unchanged, and the manuscript-node seeding of R-21 is pinned
   as one-time rather than recurring.
6. **Map remains map-owned** — marker coordinates are `map-marker` record fields, reached
   through `WorldService`, not edge data.
7. **`WritingSession` remains absent** — nothing named `WritingSession` exists in `lib/`;
   if it is added, this test forces the "history data, not graph data" decision (I-12) to
   be made consciously.
8. **Research lives in records, and the legacy panel blob is never rewritten** — the
   deferred-migration assertion was replaced when the migration landed. It now pins the
   invariant that survived it: research is reachable as graph nodes, `documents` can still
   attach a research entry to anything, and the legacy store stays a read-only migration
   input in `lib/migrations/`.
9. **No Story Graph UI has been implemented** — no `StoryGraphService`, `StoryGraphView`,
   or equivalent exists in `lib/`.
10. **The edge table refuses a dangling link** — `PRAGMA foreign_keys` is on, and a raw
    insert naming absent endpoints is rejected by the database (invariant I-1).

Assertion 1 is deliberately brittle against decision D-1: retiring `manuscript_node_rows`
in Phase 0 will fail it, which is the point — the audited table set should not change
without someone updating this document in the same commit.

These are architecture tests, not feature tests: ten assertions covering the boundaries
this document relies on, rather than a speculative suite. They pass against the audited
tree, and one of them — the Analytics guardrail — found R-21 while being written.
