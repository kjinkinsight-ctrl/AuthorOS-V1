# AUTHOROS — NEXT DIRECTIVE

Story Graph Phase 0 — Scenes and Chapters Become Records

Source: `docs/universal-story-graph-architecture.md` (audit, August 21, 2026)
Decisions this directive implements: **D-1** (scenes and chapters become `AuthorRecord`s), **D-2** (version churn handled by coalescing)
Baseline at time of writing: 605 tests passing, 55 analyzer issues (0 errors), `flutter build web --release` succeeds

---

## Objective

Retire `ManuscriptNodeReference`. Make `scene` and `chapter` — record types that are
already registered but have never been instantiated — the real ones, so that AuthorOS has
exactly **one node kind** and one meaning of "a scene".

This is the prerequisite for every later Story Graph phase. **Do not build the Story
Graph in this milestone.** No `StoryGraphService`, no traversal layer, no graph UI. This
directive prepares the ground; Phase 1 builds on it.

The migration is tractable for one specific reason, and the whole plan depends on it:

> `connected_entities` already holds records and manuscript nodes in a single id space,
> and `record_link_rows` references *that* table rather than either concrete table.
> **Preserve the ids and every existing `RecordLink` survives the migration untouched** —
> no link rewriting, no id remapping, no edge re-validation.

---

## 1. HARD RULES

### DO NOT

- Do not build the Story Graph itself — no `StoryGraphService`, `StoryGraphView`,
  `StoryGraphNode`, `StoryGraphEdge`, traversal layer or graph UI.
- Do not create a second graph system. Everything builds on `AuthorRecord` + `RecordLink`
  + `ConnectionEngine`.
- Do not create a second relationship model, a second edge table, or a second record model.
- Do not dual-write scenes to both `SharedPreferences` and records. Dual-writing recreates
  exactly the duplication this milestone removes.
- Do not change record ids during migration. Ids are the reason links survive.
- Do not rewrite, delete or re-validate existing `RecordLink` rows.
- Do not migrate `ProjectResearchStore` — the Research migration stays deferred.
- Do not modify Map Studio, World Board or Analytics beyond the single seeding fix in §3.
- Do not start Map Phase 3, Community, or publishing.
- Do not introduce AI functionality.
- Do not add speculative APIs for later phases.

### MOST IMPORTANT

Order matters more than speed. §2 (coalescing) must land and be verified **on its own**
before any migration work begins, because it changes version behaviour for every record
type in the product. §3 must land before scenes become records, because after D-1 the
existing bug manufactures revision history for prose nobody typed.

If any step proves larger than expected, **stop and report** rather than carrying a
half-migration forward. A tree where some projects have record-scenes and others have
node-scenes is worse than either end state.

---

## 2. STEP 1 — Implement version coalescing (decision D-2)

Land this first, as its own commit, fully tested, before touching the manuscript.

### Specification

| Aspect | Rule |
|---|---|
| Eligible change type | `AuditChangeType.updated` **only** |
| Coalesce when | Same `entityId`, same `branchId`, same `source`; the previous version's `changeType` is also `updated`; and the new timestamp falls within the window of the previous version's `createdAt` |
| Window | Configurable on `VersionAuditService`; default 5 minutes |
| On coalesce | Keep the existing version id **and** its `previousVersionId`. Replace `snapshot`, `createdAt`, `summary`. Increment `coalescedCount` in metadata. Leave `sequence` unchanged |
| Paired audit event | Replaced in lockstep. Its id derives as `audit-<versionId>`, so it follows the version id automatically |
| Never coalesce | `created`, `renamed`, `archived`, `restored`, `deleted`, `duplicated`, `statusChanged`, `templateChanged`, `scopeChanged`, `branchChanged`, and all four `connection*` types |

### Implementation notes

- `DriftConnectedDomainRepository._insertVersion` uses `.insert()`. Coalescing needs a
  **replace** path that updates the existing row in place. Do not insert under a new id
  and delete the old one — that breaks the `previousVersionId` chain for any version that
  pointed at it.
- `VersionAuditService._build` already fetches `latestVersion` to compute `sequence`. That
  is the natural place to decide whether this write coalesces.
- `_appendHistory` validates that the audit event matches its version. Keep that check
  intact on the replace path.
- Branch history must coalesce independently of canonical history — `latestVersion` is
  already branch-filtered; do not widen it.

### Expected impact on existing tests

Most existing version tests use `renamed`, `restored`, `created` or `statusChanged`
change types, which never coalesce — `_classifyChange` routes a title edit to `renamed`
and a status edit to `statusChanged`, so only runs of pure field-content edits collapse.
The suite is therefore expected to pass unchanged.

**If any test's version count changes, do not simply adjust the assertion.** Report which
test, what the count was, what it became, and why — a changed count either confirms
coalescing is working on a genuine run of `updated` edits, or reveals the rule is too
broad. Both need a human decision.

### Tests to add

- A run of `updated` edits inside the window produces one retained version, with the
  original id, an intact `previousVersionId`, and `coalescedCount` reflecting the run.
- The same run spanning the window boundary produces two versions.
- `created` → `updated` → `updated` produces two versions, never one.
- `renamed` between two `updated` edits breaks the run into three versions.
- A coalesced version's audit event is replaced, not duplicated — audit and version
  counts stay equal.
- Branch and canonical histories coalesce independently.
- The final snapshot after coalescing equals the latest record state, so
  `restoreVersion` still restores the right content.

---

## 3. STEP 2 — Move manuscript seeding out of the read path (risk R-21)

Land this before scenes become records.

`AnalyticsService.getSummary()` and `WorldBoardService.load()` both call
`ManuscriptStore.loadStudio()`, which on a project with no saved manuscript seeds a
starter manuscript and calls `saveStudio()` — writing nodes into `connected_entities` and
`manuscript_node_rows`. Today those nodes carry no version and no audit trail. **After
D-1 the same read would create records, each with a version and an audit event** — the
dashboard would fabricate revision history for prose the author never wrote.

Required: reading a project must never create manuscript entities. Seeding belongs to an
explicit action — project creation, or opening Manuscript Studio — not to a dashboard
render.

Constraints:

- `AnalyticsService` and `WorldBoardService` must keep reporting the same numbers for a
  project whose manuscript **has** been seeded. Their existing tests should pass unchanged.
- A project with no manuscript must read as empty (zero words, zero chapters, "Not
  started"), not error.
- Do not change what either service computes. This is about the write, not the maths.

Add a test asserting that a full `getSummary()` and a full `WorldBoardService.load()` on
an unseeded project leave `connected_entities`, `manuscript_node_rows` and
`author_record_rows` untouched.

Then update `test/story_graph_architecture_test.dart`: the Analytics guardrail currently
documents the seeding as expected one-time behaviour. Once fixed, tighten it to assert
**no** node creation, and update the R-21 entry in the master document to closed.

---

## 4. STEP 3 — Define the `scene` and `chapter` record types

They are currently bare `general-lore` children with seven inherited fields and no
manuscript semantics. Give them real definitions, drawn from `ManuscriptScene` and
`ManuscriptChapter`:

| Type | Fields |
|---|---|
| `scene` | `content`, `order`, `status`, `pov`, `location`, `timeLabel`, `notes` |
| `chapter` | `order`, `status`, `summary`, `prompt`, `pov` |

- `content` is `richText` or `longText` — it carries the prose, and putting it in `fields`
  is what brings the manuscript into the archive and the FTS index.
- `status` must use the same vocabulary as `ManuscriptNodeStatus` (`planned`, `draft`,
  `revising`, `complete`) so Analytics' `chaptersByStatus` keeps working unchanged.
- `order` stays an integer field, per open question Q-2 — ordering is sequence data, not a
  relationship.
- `chapterId` and `linkedChapterIds` do **not** become fields. See §5.

Keep `book` and `series` as they are. They are out of scope for this milestone.

---

## 5. STEP 4 — Register typed containment edges

Chapter membership currently lives in `ManuscriptNodeReference.extensionData['chapterId']`
— an untyped string in a JSON blob, invisible to the edge table. Promote it:

- Register a typed connection permitting `scene → chapter` and `chapter → book`.
- `partOf` already exists but is `*` → `*`. Either narrow it or register a manuscript-
  specific type; state which you chose and why in the final report.
- Once the edge exists, **retire the `chapterId` field**. Do not keep both — duplicated
  truth is the problem being solved.
- `linkedChapterIds` becomes `relatedTo` edges between chapters.

This closes two entries in the master document's §4.3 MISSING table.

---

## 6. STEP 5 — Move `ManuscriptStore`'s source of truth to records

- Records become authoritative for scene and chapter identity, ordering, status and prose.
- The `SharedPreferences` blob (`author_studio.manuscript_studio.<projectId>`) becomes a
  **read-only migration input**, then is retired.
- The legacy plain-text key (`author_studio.manuscript.<projectId>`) keeps its existing
  fallback role during migration and is retired with it.
- `ManuscriptProjectSummary` may remain as an in-memory view assembled from records —
  Analytics and World Board both depend on its shape, and keeping it avoids touching them.

Do not dual-write. When records become authoritative, the blob stops being written.

---

## 7. STEP 6 — Migrate existing manuscript nodes

Schema version 9. For each row in `manuscript_node_rows`:

1. Insert an `author_record_rows` row **with the same id**, `typeId` from `nodeType`,
   `scopeType: project`, `projectId` from the node, `status: active`,
   `canonStatus: canon`, fields populated from the node's `extensionData` plus prose from
   the `SharedPreferences` blob where available.
2. Flip `connected_entities.kind` from `manuscriptNode` to `record`.
3. Delete the `manuscript_node_rows` row.
4. Re-index the entity so the FTS body carries prose rather than `extensionData`.

Critical constraints:

- **Ids never change.** Every `RecordLink` pointing at a scene or chapter must remain
  valid without being touched.
- This is a **swap, not a dual-write**: `ConnectedDomainTransaction` explicitly rejects an
  id that is both a record and a manuscript node. Keep that check — it is what guarantees
  the swap is complete.
- The migration must be idempotent and safe to resume. A container dying mid-migration
  must not leave a project half-converted.
- Verify FK integrity after migration: `PRAGMA foreign_key_check` must return nothing.

---

## 8. STEP 7 — Convert `SceneRelationship` to `RecordLink`s (risk R-7)

`ManuscriptScene.relationships` is a third relationship shape, persisted in
`SharedPreferences` and invisible to the graph. `LegacyConnectionSliceAdapter` can already
convert them, but it is gated behind `AuthorOsFeatureFlags.connectedDomain`, which is off
by default.

With both endpoints now records, the conversion is no longer blocked. Convert as part of
the same migration:

- Map each `SceneRelationship` to the appropriate typed connection.
- Stamp provenance into `extensionData`, exactly as the existing adapter does
  (`{'legacySource': 'SceneRelationship'}`).
- Where a relationship cannot be resolved to a real record, **do not invent a link.**
  Report it as unresolved and leave it out.
- Retire the feature flag once the path is unconditional.

---

## 9. STEP 8 — Retire the second node kind

Once every project is migrated:

- Delete `ManuscriptNodeReference` and `manuscript_node_rows`.
- Remove the `entityTypeId` fallback to `nodeType` and the `entityProjectId` equivalent.
- Remove `SearchEntityKind.manuscriptNode` handling from `UniversalSearchService`.
- Remove `putManuscriptNodes` and `_putManuscriptNode`.
- Remove `manuscript-nodes.jsonl` from the archive format, or keep it emitted-empty for
  backward compatibility — **state which, and why, in the final report.** Archive
  compatibility is a one-way door.
- Retire invariant **I-14** from the master document.

---

## 10. STEP 9 — Update the guardrails and the master document together

`test/story_graph_architecture_test.dart` assertion 1 pins the audited table set. Dropping
`manuscript_node_rows` will fail it. **That is intentional** — the test exists so the table
set cannot change without someone noticing.

In the same commit:

- Update the expected table set.
- Tighten the Analytics guardrail per §3.
- Update `docs/universal-story-graph-architecture.md`: close R-1, R-2, R-5, R-7, R-14 and
  R-21; retire I-14; update §5 NODES and the §2.2 table list; mark Phase 0 complete.

Do not update the document in a separate commit. The test and the document are a pair.

---

## 11. TEST REQUIREMENTS

Add tests that prove the migration, not tests that restate it:

- **Links survive.** A scene with inbound `appearsIn` links from characters migrates, and
  every link is still valid, still resolves, and was never rewritten.
- **Deletion works.** A migrated scene can be soft-deleted, and it disappears from default
  graph reads — the R-1 case that motivated the whole decision.
- **Prose round-trips.** Export a migrated project to `.authoros`, import it into a fresh
  database, and the prose comes back — the R-2 case.
- **Prose is searchable.** `UniversalSearchService` finds a scene by a phrase in its body.
- **One node kind.** After migration `connected_entities.kind` is uniformly `record`.
- **Idempotent.** Running the migration twice changes nothing the second time.
- **`PlotService` orphaned-scene validation returns real findings**, having been
  unreachable before.
- Coalescing tests per §2.

Do not write hundreds of speculative tests. Prove the properties above.

---

## 12. FINAL VERIFICATION

Run and record:

```
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build web --release
git diff --check
PRAGMA foreign_key_check   (against a migrated database)
```

Record: baseline, final test count, analyzer count, build result, pre-existing failures,
files created, modified, deleted.

Fix anything that breaks because of this work. Do not fix unrelated pre-existing problems.

Flutter 3.44.9 is the pinned SDK (`.metadata`, `.github/workflows/dart.yml`). If it is not
on the runner, install that exact revision rather than a newer one.

---

## 13. FINAL REPORT

Return:

- Coalescing implementation and any version-count changes in existing tests
- Seeding fix and its effect on Analytics / World Board
- `scene` / `chapter` type definitions
- Containment edge chosen, and why
- Source-of-truth migration
- Node migration results — projects migrated, links preserved, FK integrity
- `SceneRelationship` conversion, including anything left unresolved
- What was retired
- Archive compatibility decision
- Risks closed, and any new ones found
- Tests, analyzer, web build, working-tree status

---

## STOP CONDITION

When one node kind exists, prose round-trips through export and import, a deleted scene is
soft-deleted rather than orphaned, and the guardrails and master document have been
updated together:

**STOP.** Phase 1 is a separate directive.
