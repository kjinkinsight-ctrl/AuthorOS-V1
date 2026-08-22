# AuthorOS — Universal Story Graph

Phase 1 — Bounded Read Model

Status: implemented
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Directive: Universal Story Graph Phase 1 — Bounded Read Model (locked build directive)
Next milestone: Universal Story Graph Phase 2 — Interactive Graph Explorer

---

## 1. Purpose

Phase 1 builds the canonical, read-only, project-scoped API that answers structural
questions about a project's story:

- What nodes exist in this project?
- What relationships exist between them?
- What is one hop from this node?
- What is reachable from it within a bound?
- Was the answer truncated?
- What is the shortest path between two nodes?
- Does any of it stay inside this project? (Always. By construction.)

It adds no truth. Everything it returns is assembled from records, manuscript nodes and
relationships that already existed.

## 2. Architectural position

```text
        Existing AuthorOS persistence
                     |
        +------------+------------+
        |                         |
   AuthorRecord            ManuscriptNodeReference
   (+ RecordLink)          (scenes, chapters)
        |                         |
        +------------+------------+
                     |
          UniversalStoryGraphService
             (Phase 1 read model)
                     |
        +------------+------------+
        |            |            |
      Nodes        Edges      Traversal
                     |
                     v
             Phase 2 Explorer UI
```

The service is a reader of `DriftConnectedDomainRepository` — the same repository
`RecordGraph`, `RecordService` and `ConnectionEngine` use. It is not a database, a store,
a cache, a writer, or a second source of truth.

## 3. Existing systems reused

| System | How Phase 1 uses it |
|---|---|
| `DriftConnectedDomainRepository` | The only data source. Every read goes through it. |
| `RecordGraph` | Left intact. Phase 1 does not wrap, replace or duplicate it; it reuses `RelationshipDirection` and mirrors its project-membership and soft-delete rules exactly. |
| `ConnectionEngine` | Remains the sole authority that *writes* relationships. Phase 1 only reads what it wrote. |
| `ManuscriptStore` | Remains the owner of scenes, chapters and prose. Phase 1 reads the manuscript node projection it already writes. |
| `RecordId` / `RelationshipId` | Reused as node and edge identity. No second identity system. |
| `CanonStatus`, `AuthorRecordStatus` | Reused as-is; no parallel lifecycle or canon model. |

One repository method was added — `manuscriptNodesByProject` — plus three `COUNT`
helpers. They are reads on existing tables using the existing `manuscript_nodes_project`
index. No table, column, index or migration was added.

## 4. Node model

`StoryGraphNode` presents both persistence shapes as one vocabulary:

| Field | Meaning |
|---|---|
| `id` | `RecordId` — the same string `connected_entities.id` holds |
| `kind` | `record` or `manuscript` |
| `projectId` | The project the read was scoped to |
| `label` | Display title. Never identity |
| `typeId` | Record type id, or `'scene'` / `'chapter'` |
| `lifecycle` | `active` / `archived` / `deleted` |
| `canonStatus` | `CanonStatus`, or `null` where the domain has no canon concept |
| `metadata` | Unmodifiable display/filter hints |

`kind` exists because of D-3, not in spite of it. A consumer reads it when it needs to
route navigation or render a manuscript node distinctly, and otherwise ignores it.

## 5. Edge model

`StoryGraphEdge` is a read projection of an existing `RecordLink` — id, source, target,
type id, project scope, label, direction, metadata. There is no second persistence edge
type and no way to write one.

## 6. Manuscript node integration

This is the gap Phase 1 existed to close. `RecordGraph` resolves `AuthorRecord`s only, so
before this milestone a graph reader could see characters and locations but not the scenes
and chapters they appear in — half the story, on a decision that makes the split
permanent.

The service resolves an id against both kinds, in the order the persistence layer already
uses (`entityProjectId`, `entityTypeId`, `relationshipEndpoint` all do the same): record
first, then manuscript node. Nothing was promoted, duplicated or migrated. A scene is
still a `ManuscriptNodeReference` and is still absent from `author_record_rows` — a
guardrail test pins that.

## 7. Project isolation

Enforced in the service, never by a caller filtering afterwards:

- The service cannot be constructed without a `projectId`.
- There is no all-projects, global or unscoped read.
- A record is admitted only if it passes the same membership disjunction `RecordGraph`
  applies; a manuscript node only if `node.projectId` matches.
- A relationship is admitted only if `link.scopeId` matches, so a foreign relationship
  naming an in-project endpoint cannot be stepped across.
- A foreign or unknown id resolves to `null` — deliberately the same answer, so the
  result never reveals that another project's record exists.

## 8. Traversal semantics

Breadth-first, iterative, with a visited set.

- `maxDepth: 0` — origin only. `1` — origin plus direct neighbours. `2` — plus theirs.
- Cycles terminate: `A → B → C → A` yields three nodes, each expanded once.
- Ordering is deterministic — depth ascending, then node identity ascending. Frontiers are
  sorted before expansion and relationships are read in identity order, so the same graph
  always produces the same result. Nothing depends on hash iteration or query completion
  order.
- The origin is always included when visible, even if a filter would exclude it: the
  caller named it explicitly.

## 9. Bounds

`StoryGraphTraversalOptions` carries `maxDepth` (default 2) and `maxNodes` (default 250).
There is no unlimited value and no way to express one. A negative depth throws
`ArgumentError` — it is a programmer error, never a synonym for unlimited.

The bounds are a safety mechanism, not a display preference. AuthorOS contains 73 wildcard
`*` → `*` relationship definitions, so the reach of a traversal is not predictable from
the entity types involved.

## 10. Truncation

First-class, never silent. `StoryGraphBounds` reports `isComplete` / `isTruncated` and the
reasons — `nodeBudget`, `depthLimit`, or both.

This is what lets Phase 2 render "48 of 512" instead of implying "these are all the
connections". A consumer that silently truncates tells the author two things are
unconnected when the truth is "not within depth 2", which is worse than showing nothing.

Depth truncation is deliberately **conservative** — see §18.

A traversal that stops on the node budget reports only `nodeBudget`, never both reasons.
It stopped before the depth bound could be tested, so claiming the depth bound also
applied would be a guess rather than a reading.

## 11. Shortest path

Breadth-first and unweighted, so the first route found is a shortest one; ties break by
node identity then relationship identity, so the result is reproducible.

`StoryGraphPath` enforces its own invariant at construction: `nodes.length ==
edges.length + 1`, and every edge must actually join its neighbours in the sequence. An
invalid path cannot be built and handed to a consumer.

"No path" is a value, not an exception: `StoryGraphPathFailure` distinguishes
`originInaccessible`, `destinationInaccessible` and `unreachableWithinBounds`, and a
failure carries the bounds the search ran under.

## 12. Filtering

`StoryGraphFilter` filters on node kind, type id, relationship type id, lifecycle and
canon status. Every set is inclusive and an empty set means "any" — the convention
`RecordGraph.related` already set. Lifecycle defaults to active + archived, so
soft-deleted records stay out unless asked for.

Filtering never produces a dangling edge. `StoryGraphSnapshot` enforces coherence at
construction: an edge is retained only when both of its endpoints are in the node set.

## 13. Deterministic ordering

Nodes sort by identity, edges by identity, neighbours by node then edge, traversal by
depth then identity. Manuscript nodes are read ordered by id rather than title, because
two scenes may share a title and ids never collide.

## 14. WritingSession exclusion

A writing session is not a node, cannot be an edge endpoint, and cannot be traversed to.
This is structural rather than defensive: `writing_session_rows` has no foreign key into
`connected_entities`, so a session has no entity row to resolve, no registered record
type, and no connection type will take it as an endpoint. The graph reads entity-backed
rows, so there is nothing to exclude.

The boundary the graph keeps: **participation, not proximity.** A session carries
`chapterId` and `sceneId`, and is still history — a record of what happened *to* the
story, not a thing the story is made of. Audit history and version history sit on the same
side of that line.

## 15. Immutability

Nodes, edges, snapshots, traversals and paths are immutable after construction, and their
collections and metadata maps are unmodifiable. A consumer — a canvas, a panel, a future
analytics reader — cannot alter canonical state by mutating what it was handed, and a
test proves the attempt throws.

## 16. Persistence and schema impact

| | |
|---|---|
| Database changed | No |
| Schema version | Unchanged — 9 |
| Tables added | None |
| Indexes added | None |
| Migrations added | None |
| Repository methods added | 4 reads (`manuscriptNodesByProject`, 3 counts) |

## 17. Performance

- **Origin-anchored reads** resolve nodes and relationships lazily, memoised for the
  lifetime of a single call. Query count is bounded by the node budget, not by project
  size. The memo is not a cache in the architectural sense: it never outlives the call,
  so it cannot go stale or become a second source of truth.
- **Project-wide snapshots** use the existing bulk repository reads
  (`recordsByProject`, `manuscriptNodesByProject`, `linksByScope`) — three queries, not a
  per-node loop.
- **Totals** are counted in the database rather than materialised.
- A one-hop query never triggers a project-wide read.

## 18. Limitations

These are real and deliberate. None of them is a defect to work around inside Phase 2.

1. **Phase 0 was directed but never executed, so R-1 and R-2 remain open.**
   `putManuscriptNodes` is still upsert-only and `ManuscriptNodeReference` still has no
   status column, so a scene deleted in Manuscript Studio can leave a ghost manuscript
   node that the graph will faithfully report as a live node. Phase 1 is built so this
   cannot corrupt it — see §19 — but Phase 1 cannot fix it. **This is the most important
   open risk under the graph.**
2. **Project-wide enumeration is narrower than admission.** `recordsByProject` matches
   `projectId OR scopeId`, while membership admits records whose only signal is
   `fields['projectId']` or `fields['_codex.projectId']`. Such a record is reachable by
   traversal but absent from a project-wide snapshot. The inconsistency predates this
   milestone; it is recorded here rather than silently patched, because narrowing or
   widening either rule affects existing Studios.
3. **Depth truncation is conservative.** The check asks whether the final frontier still
   had unexplored in-project relationships; it does not resolve the far endpoints, so it
   can report a depth limit for neighbours a filter would have excluded anyway.
   Over-reporting is the safe direction: it makes a consumer say "there may be more",
   where under-reporting would let it claim a bounded view was the whole answer.
4. **A bounded path search cannot distinguish "unconnected" from "beyond the bound".**
   Distinguishing them would require an unbounded traversal. The failure result carries
   the bounds so a consumer can say which it means.
5. **Manuscript nodes have no archived or deleted state**, because the domain has none.
   They are always `active` while they exist. A lifecycle filter therefore cannot select
   or exclude them by state.
6. **Totals exclude soft-deleted records.** A caller that deliberately admits deleted
   nodes can see a snapshot count exceeding the totals.
7. **Direction governs traversal, not edge visibility.** A snapshot shows every admitted
   relationship between the nodes it reached, including ones the direction filter would
   not have walked. This keeps the rendered subgraph honest about what relationships
   exist.
8. **Branch overlays are not applied.** `branch_record_overlay_rows` and
   `branch_link_overlay_rows` exist, and the read model does not project them. The graph
   reads base state. Branch-aware projection is deferred and not designed here.

## 19. No prose assumption

The graph must never assume that a node's existence means its content exists.

A manuscript node says *this scene participates in the story structure*. It says nothing
about whether the scene has been written, whether its prose survived an archive round
trip, or whether Manuscript Studio can still load it. The read model therefore carries no
prose, no body text and no word count, and never loads the manuscript to prove graph
membership. Given limitation §18.1, this is not a stylistic choice — it is what keeps a
ghost node a display problem rather than a crash.

## 20. Phase 2 contract

Phase 2 can rely on being able to:

| Need | API |
|---|---|
| Load a bounded project graph | `getSnapshot({origin, options})` |
| Locate and inspect a node | `getNode(RecordId)` |
| Inspect one hop | `getNeighbours(id, direction:, filter:)` |
| Traverse to bounded depth | `traverse(origin, options:)` |
| Find a path | `findPath(from, to, options:)` |
| Filter nodes and relationships | `StoryGraphFilter` |
| Know when a result was truncated | `StoryGraphBounds` on every bounded result |
| Show "N of M" honestly | `getTotals()` |
| Distinguish the two node kinds | `StoryGraphNodeKind` |
| Handle an unresolvable reference | `null` from `getNode`; absent from traversal |

Phase 2 must **not** need to know database tables, manuscript node storage or
`AuthorRecord` storage, nor implement BFS, visited sets, project isolation, edge coherence
or truncation detection. All of that is here.

Measured against the Phase 2 directive's six-point precondition: items 1–5 are delivered.
Item 6 — *"a node whose entity no longer exists is returned as an explicit
unavailable/deleted node, never a silent omission"* — is **partially** delivered. A
soft-deleted `AuthorRecord` is returned with `lifecycle: deleted` when a filter admits it.
A manuscript ghost node (§18.1) is indistinguishable from a live one, because the domain
provides nothing to distinguish it with. Phase 2 should render the lifecycle it is given
and must not infer absence from silence.

## 21. Explicitly not implemented

Phase 1 does not provide, and did not build:

- UI of any kind — no view, panel, canvas, pan, zoom, layout or minimap
- visualisation or graph layout algorithms
- graph editing, relationship creation or deletion
- automatic entity linking or AI relationship discovery
- knowledge-graph intelligence or graph analytics beyond traversal and path primitives
- community sharing, public graphs, shared worlds or cloud graph storage
- branch-aware graph projection
- a graph cache, graph table, graph database or second graph engine
- any change to Map, Plot, Timeline, Research, World Board or Manuscript Studio

The next milestone is **Universal Story Graph Phase 2 — Interactive Graph Explorer**,
which consumes this API and must not recreate it.
