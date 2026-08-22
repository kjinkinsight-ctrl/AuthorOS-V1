# AuthorOS — Universal Story Graph

Phase 0 — Manuscript Graph Integrity & Node Lifecycle

Status: **Integrity milestone complete. No Story Graph implementation exists or is authorised.**
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Audit basis: `main` at `c9ae671` (PR #22), re-verified from the working tree — not carried forward
Baseline before this milestone: 1073 tests passing, 60 analyzer issues, clean tree

---

## 1. What this milestone changed, in one paragraph

The manuscript node projection was **upsert-only**. A chapter or scene removed from a
manuscript kept its node, its links and its search-index row for the life of the database,
and — because `record_link_rows` has a foreign key into `connected_entities` — the node
could not be removed afterwards even deliberately. Phase 0 makes the projection
**reconciling** and makes node removal **link-safe**. Nothing else about the architecture
changed: no new store, no new model, no graph code.

---

## 2. Audit findings, re-verified

The master audit was written against `864f99d`. Several of its findings have since been
overtaken by merged work. Verified against the current tree:

| Finding | Audit said | Verified now |
|---|---|---|
| R-1 — manuscript nodes are never deleted | CRITICAL, no removal path exists | **Partly closed already.** Manuscript Studio Phase 2 added `ManuscriptService.deleteScene` / `deleteChapter`, which disconnect through `ConnectionEngine`, append deletion history, and call a `removeManuscriptNodes` repository primitive that the audit does not mention. **The remaining hole was the projection**, not the service — see §3 |
| R-1 (second half) | — | **New finding.** `removeManuscriptNodes` threw `SqliteException(787): FOREIGN KEY constraint failed` whenever the node still had an edge. The primitive could not honour its own doc comment. Reproduced, then fixed |
| R-2 — prose is outside the archive | CRITICAL | **Holds.** The archive writes ten data entries including `data/manuscript-nodes.jsonl`; scene prose lives only in `SharedPreferences` and is in none of them |
| R-5 — `scene`/`chapter` record types shadow nodes | HIGH | **Holds.** `plot_service.dart:416` queries `recordsByTypeAndScope(typeId: 'scene')`, which returns zero because scenes are nodes. Now pinned by a test |
| R-8 — validated-write bypass in World Studio | MEDIUM, two sites | **Understated.** `world_studio.dart:270` holds, but `story_codex_service.dart` has **seven** raw writes (`:88`, `:509`, `:542`, `:596`, `:617`, `:1241`, `:1269`), not one |
| R-21 — reading Analytics writes graph nodes | MEDIUM | **Holds, and is now pinned by a test.** `AnalyticsService.getSummary()` on a cold project seeds and saves a starter manuscript, creating nodes. `WorldBoardService` no longer calls `loadStudio` directly — it consumes `AnalyticsService` since the World Board analytics integration merged — so the side effect is now reached indirectly. `release_destinations.dart:399` and `:843` are two further `loadStudio` callers the audit does not list |
| R-22 — writing sessions are not in the archive | MEDIUM | **Holds.** Twelve tables, ten archive entries |
| I-1 — FK + `PRAGMA foreign_keys = ON` | holds | **Holds**, and is precisely what made the ghost node unremovable |

---

## 3. Manuscript node ownership

- **Which entities produce nodes.** Chapters and scenes, and nothing else.
  `ManuscriptStore.manuscriptNodesFor(manuscript)` is the whole projection.
- **Id generation.** The node id *is* the chapter or scene id from the manuscript summary.
  There is no separate node identity to drift out of sync.
- **Mapping back.** By that same id: `repository.manuscriptNodeById(id)` ↔
  `manuscript.sceneById(id)` / `chapterById(id)`.
- **Project ownership.** `ManuscriptNodeReference.projectId`, taken from
  `manuscript.projectId`. One manuscript per project, keyed by
  `author_studio.manuscript_studio.<projectId>`.
- **Single write path.** `putManuscriptNodes` has exactly one production caller,
  `ManuscriptStore.saveStudio`. That is why reconciling there closes the hole completely.
- **Links.** Nodes are ordinary `connected_entities` rows, so any `RecordLink` may take one
  as an endpoint. Nodes own no link type of their own.
- **Indexes.** One row per node in the shared `author_search` FTS table under
  `entity_kind = 'manuscriptNode'`.

---

## 4. The deletion lifecycle

**Design choice: deletion, not a status field.** `ManuscriptNodeReference` gains no
`status`. Reasons: the manuscript summary in `SharedPreferences` is already the source of
truth for which scenes exist, so a status field would be a second, weaker answer to a
question already answered; soft-deleted nodes would stay traversable, which is exactly
R-10's complaint about records; and the historical record of the deletion already exists in
version and audit history, which is where history belongs. Active graph state and
historical state stay distinct — §10 of the directive.

Two layers, deliberately:

1. **`ManuscriptService.deleteScene` / `deleteChapter`** — the *domain* event. Disconnects
   every edge through `ConnectionEngine` (audited), appends deletion history, then removes
   the node. Unchanged by this milestone; it was already correct.
2. **`ManuscriptStore.saveStudio`** — the *projection* sync, new in this milestone. After
   writing the projection it retires any node of that project the projection no longer
   contains. No audit event: syncing a derived view is not a domain event, and the domain
   event is already audited by layer 1.

`removeManuscriptNodes` now deletes the node's edges inside its transaction before deleting
the entity row, so it can no longer fail against its own foreign key. For layer 1 this is a
no-op — the edges are already gone — and a safety net everywhere else.

Scope is targeted, never project-wide: only nodes absent from the projection are touched.
Connected records themselves are never deleted.

---

## 5. Archive / restore

`AuthorOsArchiveService` writes ten entries: records, manuscript nodes, links, record
types, connection types, branches, three overlay sets, versions and audit events.

**The risk is confirmed and is not fixed here.** Manuscript prose lives in
`SharedPreferences`, which the archive does not touch. A restore therefore rebuilds a fully
connected graph of chapters and scenes whose text is gone. Writing session history
(`writing_session_rows`) is likewise absent — a project exported and re-imported loses its
entire writing history.

Both are real data-loss paths, both are larger than Phase 0, and the directive says not to
redesign the archive in this milestone. **Deferred, and required before Story Graph
Phase 1**, because the graph must never assume structure implies content.

---

## 6. Cold-project seeding

Confirmed and now pinned by a test rather than fixed: `AnalyticsService.getSummary()` on a
project with no manuscript seeds a starter manuscript and saves it, which creates nodes. A
dashboard read and a graph write are the same action.

It is idempotent after the first read and confined to manuscript nodes, so it is not
corrupting. It is left alone deliberately — changing it is Analytics work, and the
directive forbids destabilising completed milestones for this. Phase 0's obligation was to
make it **explicit**, which the test now does: if the behaviour changes, the test fails and
the decision is visible.

`WorldBoardService` no longer reaches `loadStudio` directly. `release_destinations.dart`
does, in two places, and should be reviewed when this is corrected.

---

## 7. Raw repository bypasses

| Site | Verdict |
|---|---|
| `manuscript_store.dart` — `putManuscriptNodes`, `removeManuscriptNodes` | **Legitimate.** The store owns the projection; this is its persistence layer, not a bypass |
| `manuscript_service.dart` — `appendHistory`, `removeManuscriptNodes` | **Legitimate.** The canonical service, after audited disconnection |
| `world_studio.dart:270` — `putRecordsAndLinks` | **Unsafe, unchanged.** Skips validation, compatibility, project-boundary checks, versioning and audit. Routing it through `RecordService` touches completed World Studio behaviour and is out of Phase 0 scope. **Deferred** |
| `story_codex_service.dart` — seven raw `putRecord` / `putRecordsAndLinks` calls | **Unsafe, unchanged, and worse than recorded.** Same exposure. **Deferred** |
| `migrations/legacy_connection_slice.dart` | **Legitimate.** A migration adapter behind `AUTHOROS_CONNECTED_DOMAIN`, off by default |

None of these create manuscript nodes, so none can produce the ghost this milestone fixed.
They remain the largest validation gap in the tree and should be closed before the graph
treats their output as trustworthy.

---

## 8. Project isolation

Verified by test, not by inspection: retiring nodes in project A leaves project B's nodes
untouched, and `manuscriptNodesForProject` returns only the queried project's nodes. The
new read primitive filters on `projectId`, and reconciliation is scoped to the saved
manuscript's own project, so a save can only ever retire its own nodes.

No new isolation mechanism was introduced — this uses the existing `projectId` column.
R-11 still holds architecturally: isolation lives in the service layer, not the schema.

---

## 9. Search index

Nodes enter the index through `_indexEntity` inside `_putManuscriptNode`, and now leave it
through `removeManuscriptNodes`. Tested end to end: create → searchable; retire → not
searchable; recreate → searchable again. No second index was created.

---

## 10. Versioning and audit

Deletion does not destroy history. `_appendDeletionHistory` builds its entry from the
in-memory node and writes it through `VersionAuditService`; `record_version_rows` and
`audit_event_rows` carry no foreign key into `connected_entities`, so history survives its
subject. A test asserts that after a scene is deleted its node is gone **and** its version
history is not.

---

## 11. Decision D-3 — scenes and chapters stay manuscript-domain nodes

Formally recorded. Scenes and chapters are not converted into `AuthorRecord`s.

- **Why this preserves Manuscript Studio.** Prose stays in the manuscript store, editing
  stays synchronous and local, and nothing about the editor's persistence changes.
- **Why converting now would be larger.** Every scene would become a record with fields,
  versions and audit events; the seeding path in §6 would manufacture version history for
  content the author never typed; five completed milestones read the manuscript.
- **How the future graph consumes them anyway.** Nodes are already `connected_entities`
  rows, already valid `RecordLink` endpoints, already in the shared search index. A graph
  read model handles two node kinds by design.
- **What would have to change to promote them later.** A migration of node ids into record
  ids, a home for prose that is not `SharedPreferences`, and a version-coalescing strategy
  for per-keystroke churn — the withdrawn D-2.

Two node kinds are an accepted reality, not a defect. Phase 0 made the manuscript kind
*safe*; it did not try to remove it.

---

## 12. PlotService

`plot_service.dart:416` queries `recordsByTypeAndScope(typeId: 'scene')` for its
`orphaned-scene` validation. Under D-3 that returns zero rows always, so the rule never
fires. Confirmed by test.

Not repaired here: it is not required for graph integrity, and repairing it means deciding
how Plot reads manuscript nodes — a genuine integration design. **Recommended future
integration point:** `repository.manuscriptNodesForProject(projectId)`, filtered to
`nodeType == 'scene'`, which this milestone added for reconciliation and which is exactly
the read Plot needs.

---

## 13. Remaining risks

1. **Prose is still outside the archive (R-2).** Restore yields empty scenes. Blocks any
   graph claim that a node implies content.
2. **Writing session history is not archived (R-22).** Real data loss on export/import.
3. **Raw validated-write bypasses (R-8).** One in World Studio, seven in Story Codex.
4. **A dashboard read still writes nodes (R-21).** Pinned, not fixed.
5. **`PlotService` scene validation is dead (R-5).**
6. **Project isolation has no schema backing (R-11).** Raw repository access inherits none
   of the service-layer checks.
7. **`ManuscriptStudio.dispose()` saves an in-memory snapshot** through the store. It is
   now reconciling, so it cannot leave a ghost — but a stale snapshot could still recreate
   a node deleted moments earlier through another route. Not observed; worth a look when
   the editor's save path is next touched.

---

## 14. Required before Story Graph Phase 1

- Get prose and writing sessions into the archive, or state plainly that a restored project
  is structure-only.
- Close the raw write bypasses, or accept that records from those paths are unvalidated.
- Decide whether a read may write. Until then the graph must treat node existence as
  evidence of a read, not of authorship.

**Story Graph Phase 1 has not been started.** No `StoryGraphService`, node, edge,
repository, cache, index, traversal API, viewer or canvas exists in the tree, and the
guardrail test in `test/story_graph_architecture_test.dart` fails if one appears.
