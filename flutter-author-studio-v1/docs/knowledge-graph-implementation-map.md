# AuthorOS — Knowledge Graph

Universal Story Graph, Phases 1–3

Status: **Implemented.** Read model, traversal, mutation delegation and the Studio UI
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Builds on: Story Graph **Phase 0** (`docs/universal-story-graph-phase-0-integrity.md`)
Design basis: `docs/universal-story-graph-architecture.md` §15 (API), §16 (views), §20 (phases)

---

## 0. What this milestone is

The architecture audit's central finding was that AuthorOS already had a story graph and
needed a way to read it, not a way to store it:

> A future Story Graph does **not** need a new database, a new edge model, a new record
> model, or a new persistence table. […] What is missing is a **read-oriented graph API**
> and the **traversal layer** above `ConnectionEngine` — not storage.

This milestone builds exactly that, and the first UI over it. **No table was added. No
column was added. The schema is untouched at version 9.**

| Phase | Delivered |
|---|---|
| 1 — Core read model | `StoryGraphNode`/`Edge`/`Neighbourhood`/`Subgraph`, `getNode`, `getNodes`, `getEdges`, `getOutgoing`/`IncomingEdges`, `getNeighbours`, `connectionSummary`, `getDerivedEdges`, `inspect` |
| 2 — Traversal and relationship queries | `getSubgraph`, `getProjectGraph`, `findPaths`, and `StoryGraphMutations` as a thin delegation to `ConnectionEngine` |
| 3 — Graph explorer | The Knowledge Graph Studio: five modes, filter rail, Connection Explorer, connection summary, canvas arrangement |

---

## 1. Files

| File | Role |
|---|---|
| `lib/core/story_graph.dart` | Model types and `StoryGraphFilter`. Pure Dart, no Flutter import |
| `lib/core/story_graph_service.dart` | The read model. Owns no storage |
| `lib/core/story_graph_mutations.dart` | Relationship writes, by delegation only |
| `lib/core/story_graph_modes.dart` | The five modes, as data |
| `lib/knowledge_graph/graph_layout.dart` | Radial and layered layout, and `GraphProjection` |
| `lib/knowledge_graph/graph_canvas.dart` | The drawn graph and its palette |
| `lib/knowledge_graph/graph_side_panels.dart` | Filter rail and Connection Explorer |
| `lib/knowledge_graph/knowledge_graph_view.dart` | The Studio |
| `lib/persistence/authoros_database.dart` | **+3 queries**, no schema change |
| `lib/main.dart` | Shell wiring |
| `lib/theme/theme_tokens.dart` | `StudioId.knowledgeGraph` |

---

## 2. Layering

```
KnowledgeGraphView                              lib/knowledge_graph/
        |
StoryGraphService (read)  ·  StoryGraphMutations (write, delegating)
        |
RecordGraph · ConnectionEngine · UniversalRecordInspector · RecordService
        |
DriftConnectedDomainRepository
```

`lib/core/universal_records.dart` already declares itself *"the Universal Records boundary a
future Studio consumes"*. The graph sits **on** that boundary rather than beside it:
`RecordGraph` keeps its one-hop, project-scoped reads and is not replaced.

### 2.1 Repository additions — queries only

```dart
Future<List<AuthorRecord>>            recordsByIds(Iterable<String> ids)
Future<List<ManuscriptNodeReference>> manuscriptNodesByIds(Iterable<String> ids)
Future<List<RecordLink>>              linksForEntities(Iterable<String> ids, {Set<String>? typeIds})
```

§12.2 named batch hydration *"the single most valuable addition"*, and it is: without it a
200-node subgraph issued 200 `recordById` calls, one per edge. `linksForEntities` also
pushes edge-type filtering into SQL, which is what makes excluding `relatedTo` cheap rather
than a post-filter over rows already in memory.

All three chunk their id lists at 400 so a large neighbourhood cannot exceed SQLite's
bound-variable limit, and `linksForEntities` de-duplicates: a link whose two endpoints land
in different chunks matches both.

---

## 3. Two node kinds, one call

Decision D-3 makes two node kinds permanent. The consequence for a read model is concrete
and was previously unhandled anywhere in the tree:

- `RecordService.getRecord` returns `null` for a scene.
- `ConnectionEngine.linkedRecords` silently **drops** manuscript nodes.
- `RecordGraph.related` hydrates through `recordById`, so it drops them too.

A view built on any of those loses half the manuscript spine without saying so.
`StoryGraphNode` is the union, and it carries capability flags rather than pretending the
kinds are alike:

| Field | Record | Manuscript node |
|---|---|---|
| `versioned` | `true` | **`false`** — `manuscript_node_rows` has no version or audit trail |
| `canonStatus` | set | **`null`** — no such column |
| `lifecycleStatus` | set | **`null`** — no such column |
| `deletable` | `true` | `true` **since Phase 0** made the projection reconciling |
| `inspectable` | `true` | **`false`** — `UniversalRecordInspector` resolves records only |

The Connection Explorer renders that honestly: a manuscript node says its detail and history
live in Manuscript Studio, rather than offering history that cannot exist.

---

## 4. The two defaults that make a graph readable

These are the whole difference between a usable view and a hairball, and both are measured
facts about this tree rather than taste:

| Default | Why |
|---|---|
| `includeRelatedTo: false` | `relatedTo` is undirected, wildcard, and **suggested on all ~224 record types**. Left on, it dominates every view it appears in (risk R-16) |
| `includeWildcardEdges: false` | **73 of ~130** connection types permit `*` -> `*`. They are real relationships with no type discipline, so they are drawn quieter and hidden by default (risk R-3) |
| `includeArchived: false`, `includeDeleted: false` | Deletion is soft and edges deliberately survive it (risk R-10). A view that forgot this renders deleted characters as live |

**Naming a type explicitly beats both.** A mode that asks for `plannedFor` means it. This is
load-bearing: `plannedFor`, `fulfilledBy`, `resolvesIn` and `opposes` are all wildcards, and
they are the *only* edges scene-to-plot has (§4.3), so the Plot mode would otherwise have
nothing to draw.

`relatedTo` is itself a wildcard type. Its dedicated switch therefore decides it outright in
both directions — leaving it to fall through to the wildcard rule let the general filter
override the specific opt-in, and the toggle appeared to do nothing. That was a real bug,
found by CI.

Nothing is hidden silently. The rail counts what the filters are costing, and truncation
raises a banner naming the node count.

---

## 5. Modes

A mode is **data**. Nothing branches on a mode id, and adding one is a new const.

| Mode | Root categories | Layout | Depth |
|---|---|---|---|
| Character | `characters` | radial | 1 |
| World | `locations`, `places`, `world` | radial | 2 |
| Plot | `plot` | layered | 2 |
| Manuscript | `manuscript` | layered | 2 |
| Project | *(none — whole project)* | radial | 1 |

`test/story_graph_modes_test.dart` asserts every edge id and category id a mode names
resolves against the **live registries**. Renaming a connection type now fails a test
instead of quietly emptying a view — which is the failure mode a string-keyed mode
descriptor otherwise invites.

---

## 6. Buckets come from `categoryId`

The Connection Explorer groups neighbours into the nine buckets the product describes.
Those are derived from `RecordTypeDefinition.categoryId` — required on every type and
inherited through `baseTypeId` resolution — not from a hardcoded list of type ids. All 21
built-in categories map onto a bucket; `other` exists only as a safety net for a
project-defined category, and a test asserts no built-in category lands there.

| Bucket | Categories |
|---|---|
| Characters | `characters` |
| Locations | `locations`, `places`, `world`, `routes` |
| Events | `timeline`, `history` |
| Plotlines | `plot` |
| Chapters | `manuscript` |
| Research | `research` |
| Maps | `maps` |
| Notes | `reference` |
| Worldbuilding | `lore`, `magic`, `culture`, `religion`, `factions`, `items`, `creatures`, `technology`, `custom` |

---

## 7. Layout

Two deterministic pure functions over a `StorySubgraph`, returning model-space offsets.

**No force-directed simulation.** A physics layout settles somewhere slightly different on
every run: restless to read, impossible to assert on in a widget test, and expensive to
hand-roll given no graph package exists in the dependency set and none may be added.

- **Radial** — concentric rings by hop count, ordered by bucket within a ring so characters
  cluster together. Odd rings are phase-offset so a node does not sit directly behind the
  one in front of it.
- **Layered** — longest-path layering along *directed* edges only, columns centred
  vertically. Undirected edges describe no ordering and must not push a node into a later
  layer. The pass is bounded by node count rather than assuming a DAG, because cycles are
  real in story data — two plot threads can each depend on the other.

`GraphProjection` mirrors Map Studio's `MapProjection`: `toCanvas`/`toModel`, clamped zoom,
and a `fitted` helper that frames the content's midpoint.

---

## 8. Rendering

Nodes are `Positioned` **widgets**; edges are **painted**. Nodes need real hit-testing,
semantics, tooltips and `Key('graph-node-<id>')` for tests. Edges need none of that, and 250
edge widgets would be a great deal of machinery for something nobody focuses or taps.

The stack, and the reason for its order, is Map Studio's:

```
background   grid
edges        CustomPaint — lines, arrowheads, type labels
interaction  GestureDetector, translucent, dragStartBehavior: down
nodes        Positioned widgets — they answer for themselves first
```

Edge rendering carries the distinctions the architecture insists on: a directed edge gets an
arrowhead, an undirected one does not; a wildcard edge is drawn dimmer than a typed one; and
**derived edges are dashed and never solid**, so no reader can mistake an inference for
something the author recorded. Type labels appear only above a zoom threshold, because
below it they overlap into noise.

---

## 9. Derived edges

`getDerivedEdges` returns empty. It exists anyway, because the *shape* is the deliverable:

`DerivedStoryGraphEdge` has **no `id`**. There is nothing to persist one under, so §7.3's
rule — that a derived relationship must never masquerade as a stored link — is structural
rather than a convention someone has to remember. It arrives from a different method,
returning a different type, in a separate collection, and a guardrail test asserts the
absent id.

---

## 10. Writes

`StoryGraphMutations` is a delegation and nothing else. It adds no validation, no id scheme
and no audit entry of its own, because a second relationship system does not get built on
purpose — it gets built by a helper that "just" re-checks one thing, then another, until two
code paths disagree about what a valid edge is.

A guardrail asserts it names `ConnectionEngine` and does not name `validateConnection`,
`registry.resolve`, `putLink` or `putRecordsAndLinks`.

---

## 11. Guardrails

`test/story_graph_architecture_test.dart` carried 21 assertions after Phase 0. Two changed
and five were added.

| Assertion | State |
|---|---|
| `the graph has exactly one persistence system` | **Unchanged and green.** The 12-table set is untouched. This is the proof that no graph storage was added |
| `no second relationship model has appeared in lib/` | **Narrowed.** It rejected any path containing `story_graph`, which was right while the graph was design-only and any such file was premature by definition. It now lists *store* filenames explicitly |
| `no Story Graph UI or service has been implemented` | **Replaced** by `the Story Graph read model owns no storage`. Its job was to stop the graph landing ahead of its design; with the design agreed and Phase 0 shipped, its job becomes proving the graph owns no storage. It scans every graph file for `putRecord`, `putLink`, `putRecordsAndLinks`, `putManuscriptNodes`, `removeManuscriptNodes`, `replaceSnapshot` and `SharedPreferences` |
| *(new)* `the graph delegates every relationship write to ConnectionEngine` | §20's Phase 2 exit criterion, enforced |
| *(new)* `the graph never grows a second traversal model` | No graph file may import `impact_trace` (risk R-6) |
| *(new)* `a graph read never seeds a manuscript` | No graph file may name `ManuscriptStore` or `loadStudio`, keeping risk R-21 confined to Analytics |
| *(new)* `derived edges cannot become RecordLinks` | `DerivedStoryGraphEdge` has no `id` field |
| *(new)* `the graph hides relatedTo and wildcard edges by default` | Risks R-16 and R-3 |
| The 11 Phase 0 lifecycle assertions | **Unchanged.** They pin the node lifecycle this milestone builds on |

---

## 12. Carried risks — stated, not fixed

Phase 0 §14 lists three prerequisites it considered required before Phase 1. None are done.
The graph reads live data, so none of them block it, and all three are recorded rather than
quietly assumed away:

| Risk | Consequence for the graph |
|---|---|
| ~~**R-2 / R-22**~~ — prose and writing sessions not archived | **CLOSED.** The `.authoros` format now carries both — see `docs/archive-completeness.md`. Both entries are optional on import, so archives written before the change still load |
| **R-8** — eight raw validated-write bypasses (one in `world_studio.dart`, seven in `story_codex_service.dart`) | Records written through those paths skipped validation. The graph reads them as-is and cannot tell |
| **R-21** — a dashboard read still seeds manuscript nodes on a cold project | Node existence is evidence of a *read*, not of authorship. A guardrail keeps the graph itself out of that path |

Also carried:

- **R-5** — `PlotService`'s orphaned-scene validation is still dead, because it queries
  `recordsByTypeAndScope(typeId: 'scene')` and scenes are nodes. Phase 0 named
  `manuscriptNodesForProject` as the correct integration point; the Plot and Manuscript
  modes use exactly that read, but `PlotService` itself is unchanged.
- **§4.3** — `scene -> chapter` and `chapter -> book` have no typed edge. Chapter membership
  lives in `ManuscriptNodeReference.extensionData['chapterId']`, which the Manuscript mode
  reads as a **derived** edge, dashed, never as a `RecordLink`.
- **R-6** — `ImpactTraceAnalyzer` is left alone. Absorbing its BFS is a deliberate decision,
  not an import, and a guardrail now says so.
- **R-12** — `ConnectionCardinality` is still declared and never enforced.

---

## 13. Deliberately not in this milestone

- **A global Ctrl-K command palette.** Ctrl-K is Studio-scoped. A global one means wrapping
  `AuthorStudioShell` in `Shortcuts`/`Actions`, which touches focus handling across the
  whole app; the spec itself calls the command something that *"should eventually become"* a
  genuine AuthorOS command. The `connectionSummary` read is the durable part; the palette is
  a second entry point to it.
- **`SearchDestination.knowledgeGraph`.** Adding an enum value makes every exhaustive switch
  over `SearchDestination` a compile error until updated, across several Studios. The graph
  routes *outward* through `searchDestinationForType` today, which is the direction that
  matters; routing *inward* from search results is follow-up.
- **Branch-aware reads.** `StoryGraphService` carries `branchId` so callers can pass it and
  keep working, but it does not filter yet. Overlay support is open question Q-6.
- **Derived-edge providers**, beyond the empty-returning stub that fixes the shape (Phase 5).

---

## 14. Verification

Green on CI at `f31e4c5`, all eight steps:

| Step | Result |
|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **57 issues found, 0 errors** |
| `flutter test` | **1153 tests passed**, 0 failed |
| `flutter build web --release --no-web-resources-cdn` | **`✓ Built build/web`** |

57 is **below** the 60-issue baseline Phase 0 recorded. The first pass over this work added
eight `info` issues — seven `unnecessary_import` and one
`prefer_const_literals_to_create_immutables` — and clearing them took the tree slightly
under where it started rather than adding to the backlog.

The web build matters more than a formality here and is worth naming: the graph is
`CustomPainter`-heavy and Drift runs SQLite as WebAssembly in the browser, so browser-only
breakage is a real failure mode. It passed with no warning naming any graph or canvas file.

Tests added: `story_graph_service_test.dart`, `story_graph_traversal_test.dart`,
`story_graph_modes_test.dart`, `knowledge_graph_view_test.dart`,
`knowledge_graph_canvas_test.dart`, plus the extended `story_graph_architecture_test.dart`.

No Flutter SDK was available in the authoring environment, so every number here comes from
CI (`.github/workflows/dart.yml`, Flutter 3.44.9) rather than a local run. Seven CI rounds
were needed to get here; the two defects worth recording are in §4 (`relatedTo` overriding
its own switch) and §12 (a canvas appearing inside the graph it describes).
