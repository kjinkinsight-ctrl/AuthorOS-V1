# AUTHOROS — UNIVERSAL STORY GRAPH

Phase 0 — Manuscript Graph Integrity & Node Lifecycle

Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Supersedes: `story-graph-phase-0-directive.md` (written for the withdrawn D-1)
Source findings: `docs/universal-story-graph-architecture.md`, including its §0 amendments

You are working in `flutter-author-studio-v1/`.

---

## Why this comes first

The Story Graph will eventually sit above the existing record/link system. The manuscript
graph is not yet safe to build on:

- Deleted scenes leave ghost manuscript nodes.
- Ghost nodes retain links and search-index entries.
- An archive can restore graph structure pointing at scenes whose prose is gone.
- `getSummary()` and other read paths create manuscript nodes on cold projects.
- Two competing concepts for scenes and chapters coexist: manuscript nodes, and registered
  `AuthorRecord` types that are effectively unused.

Building the graph on this makes those inconsistencies permanent.

**This is a preparation and integrity milestone.** Do not build the Story Graph.

---

## HARD RULES

### DO NOT

- Do not build the Story Graph, a graph viewer, or `StoryGraphService`.
- Do not create a new graph model, database, graph table, or traversal API.
- Do not convert scenes or chapters into `AuthorRecord`s unless the existing architecture
  proves it is required. **Decision D-3 says they stay manuscript-domain nodes.**
- Do not begin Universal Story Graph Phase 1.
- Do not create any of: `StoryGraphNode`, `StoryGraphEdge`, `GraphRepository`,
  `GraphDatabase`, `GraphTable`, `GraphCache`, `GraphIndex`, `GraphViewer`, `GraphCanvas`,
  `GraphTraversalService`.
- Do not duplicate `AuthorRecord`, `RecordLink`, `ConnectionEngine`,
  `UniversalSearchService`, or `ManuscriptStore`.
- Do not create a second persistence system, search index, or validation system.
- Do not start Map Phase 3, Community, publishing, or further Analytics features.
- Do not introduce AI functionality.
- Do not weaken existing tests to make this milestone pass.
- Do not modify unrelated completed Studios except where required for manuscript graph
  integrity.

### AT THE END

Do not commit. Do not push. Leave the working tree ready for manual review.

---

## 1. First: full repository audit

Audit before changing anything: `ManuscriptStore`, `ManuscriptNodeReference`,
`putManuscriptNodes`, manuscript node creation / update / deletion paths, chapter deletion,
scene deletion, project deletion, project archive, project restore, backup/export,
import/restore, `ConnectionEngine`, `RecordService`, `UniversalSearchService`,
`VersionAuditService`, `WorldBoardService`, `AnalyticsService`, `PlotService`, Manuscript
Studio, Story Codex, every use of manuscript node ids and references, and every raw
`putLink` / `putRecordsAndLinks` path.

**Do not assume the architecture report is correct.** It was written against `864f99d` and
`main` has since advanced to `5c6bf05` — its §0 records the amendments already known.
Verify every finding against the current repository, and report anything else that has
drifted.

---

## 2. Critical objective

Establish a reliable lifecycle for manuscript graph nodes. The invariants to reach:

> A manuscript node must never survive after the manuscript entity it represents has been
> permanently deleted.
>
> A manuscript node must never remain connected to deleted manuscript entities.

Use the existing persistence architecture. No second persistence system is permitted.

---

## 3. Manuscript node ownership

Determine and document exactly: which manuscript entities produce graph nodes, how their
ids are generated, how those ids map back to `ManuscriptStore` entities, which project owns
each node, which links are generated from those nodes, and which indexes contain them.

Do not create a new ownership model unless absolutely necessary.

---

## 4. Deletion lifecycle

Implement the smallest correct lifecycle that prevents ghost nodes. When a chapter or scene
is deleted:

1. Remove or update its manuscript node.
2. Remove links owned by that manuscript node where appropriate.
3. Remove stale search-index references.
4. Preserve legitimate history, version and audit information per the existing architecture.
5. Do not delete unrelated records or links.

Do not perform project-wide graph cleanup where a targeted deletion suffices.

Note for the implementer: `putManuscriptNodes` is upsert-only today and
`ManuscriptNodeReference` has no `status` field. Whether the lifecycle is deletion or a
status field is a design choice this milestone must make and justify.

---

## 5. Project archive / restore

Audit what happens to manuscript prose, manuscript nodes, manuscript links,
`AuthorRecord`s, `RecordLink`s, and `SharedPreferences` manuscript data.

The known risk: **an archive can restore graph structure without restoring the prose that
structure represents.** Verify it, identify the smallest safe correction, implement it only
if clearly within Phase 0 scope, and otherwise document it as required follow-up.

Do not redesign the archive system in this milestone.

> The future Story Graph must never assume that graph structure means manuscript content
> exists.

---

## 6. Cold-project / starter-manuscript side effect

Investigate `AnalyticsService.getSummary()` → `ManuscriptStore.loadStudio()` → starter
manuscript seeding.

Determine whether it is intentional, whether it is safe, whether it should remain, whether
`AnalyticsService` should be able to trigger seeding at all, whether `WorldBoardService`
does the same, and whether any other read path does.

**Do not automatically refactor completed Analytics or World Board code.** If changing it
would destabilise completed milestones, document the issue and propose the smallest future
correction. The requirement is to make the side effect explicit and stop the future Story
Graph from relying on it.

---

## 7. Raw repository bypass audit

Find every production use of `putLink`, `putRecordsAndLinks`, and direct repository
mutation. Pay particular attention to `world_studio.dart`.

For each bypass, determine whether it is legitimate. For every unsafe one: route it through
the existing canonical service, or document exactly why it cannot yet be changed. Do not
redesign the repository and do not add a second validation system.

---

## 8. Project isolation

Establish and test: manuscript nodes cannot cross projects; manuscript links cannot cross
projects; deleting an entity in Project A cannot affect Project B; restoring Project A
cannot create nodes in Project B; graph queries cannot return another project's nodes.

Use existing project identifiers and validation. Do not invent a new isolation mechanism.

---

## 9. Search index integrity

Determine how manuscript nodes enter and leave the FTS index. Test CREATE → searchable;
UPDATE → search reflects it; DELETE → no longer searchable; RESTORE → searchable again
where appropriate.

Do not create another search index.

---

## 10. Versioning / audit

Determine how deletion interacts with `VersionAuditService`, version snapshots, record
history and manuscript history. Do not destroy history merely to remove an active node.

Keep the distinction explicit: **active graph state** vs **historical / audit state**.

---

## 11. Scene / chapter architecture decision

**Do not convert scenes or chapters into `AuthorRecord`s.** Formally document decision D-3:
scenes and chapters remain manuscript-domain entities.

Explain: why this preserves the Manuscript Studio architecture; why converting now would be
a much larger migration; how the future Story Graph can consume them as graph entities
regardless; and what would need to change if they were later promoted.

This decision can be revisited.

---

## 12. PlotService investigation

Investigate `PlotService` queries for `typeId: scene`, `chapter`, `book`. Verify whether
they are genuinely dead because Manuscript Studio stores those entities separately.

Do not repair `PlotService` unless the fix is required for graph integrity. Document the
finding and recommend the correct future integration point.

---

## 13. Tests

Cover: scene deletion removes its active manuscript node; chapter deletion likewise;
deleted nodes retain no active graph links; unrelated nodes untouched; project isolation;
search-index removal; search-index restoration; archive/restore behaviour; cold-project
behaviour; repeated deletion; deletion followed by recreation; version/audit preservation;
and the raw persistence bypasses found in §7.

Add architecture guardrails where useful. **Tests must prove behaviour, not inspect
implementation text.**

`test/story_graph_architecture_test.dart` already holds ten guardrails. Extend it rather
than starting a parallel file, and keep its assertions and
`docs/universal-story-graph-architecture.md` updated in the same commit.

---

## 14. Regression protection

Run the full suite. These completed areas must remain intact: Analytics, Writing Session
History, World Board, Research Studio, Map Studio, Plot Studio, Timeline Studio, Character
Studio, Manuscript Studio, Story Codex, Theme Engine, Web Application, Startup Experience.

---

## 15. Validation

```
flutter test
flutter analyze
flutter build web --release
git diff --check
```

Compare analyzer output against baseline. **No new analyzer issues are acceptable.**

If Windows verification is unavailable, say so explicitly rather than omitting it.

---

## 16. Documentation

Create `docs/universal-story-graph-phase-0-integrity.md` covering: audit findings;
manuscript node lifecycle; deletion behaviour; archive/restore findings; cold-project side
effects; raw repository bypasses; search-index lifecycle; project isolation; version/audit
behaviour; the scene/chapter architecture decision; the `PlotService` finding; remaining
risks; and the deferred work required before Story Graph Phase 1.

---

## 17. Final report

Return: files created, modified, deleted; exact architecture changes; deletion lifecycle;
archive/restore findings; cold-project findings; raw persistence bypass findings;
search-index findings; project-isolation results; scene/chapter decision; `PlotService`
findings; tests added; full test result; analyzer result; web build result; Windows result;
`git diff --check` result; remaining limitations; and the recommended Phase 1 starting
point.

---

## STOP CONDITION

**STOP after Phase 0.** Do not start Universal Story Graph Phase 1, a graph viewer,
traversal APIs, or Story Graph UI.

Do not commit. Do not push. Leave the working tree ready for manual review.
