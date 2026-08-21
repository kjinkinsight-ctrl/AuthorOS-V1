# AUTHOROS — UNIVERSAL STORY GRAPH

Phase 2 — Interactive Graph Explorer

Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Scope decision taken here: **D-4** — the Explorer is project-scoped by default (§2)
Depends on: `docs/story-graph-phase-0-integrity-directive.md`, Phase 1 (see §1)
Source findings: `docs/universal-story-graph-architecture.md`, including its §0 amendments

You are working in `flutter-author-studio-v1/`.

---

## What Phase 2 is

Phase 1 produces a bounded, project-scoped **read model** over the graph. Phase 2 turns
that read model into a usable visual exploration experience for the author.

That is the whole of it. Phase 2 is a **consumer**. It adds a canvas, a panel, filters,
traversal controls and navigation back into the owning Studios. It adds no truth.

> Phase 2 renders the graph. It never becomes the graph.

---

## 1. PRECONDITION — verify before writing any code

**The repository does not currently contain Phase 1.** Verify this yourself before
starting; do not take this directive's word for it.

At the time of writing:

| Expected | Actual |
|---|---|
| `lib/core/story_graph.dart` | **absent** |
| `lib/core/story_graph_service.dart` | **absent** |
| `test/story_graph_phase1_test.dart` | **absent** |
| `docs/universal-story-graph-phase-0-integrity.md` | **absent** — Phase 0 was directed but not executed |
| A depth-bounded traversal API | **absent** |

What does exist is **`lib/core/record_graph.dart`** — `RecordGraph`, reached through
`UniversalRecordsRepository.graph`. It is project-scoped and it excludes soft-deleted
records, but it is **one hop only**: `related()`, `outgoingRelationships()`,
`incomingRelationships()`, `relationships()`. There is no depth, no visited-set, no node
budget, no shortest path, and it reads `AuthorRecord`s only — it cannot see
`ManuscriptNodeReference`s at all.

Also note: `test/story_graph_architecture_test.dart` contains a guardrail named
**`no Story Graph UI or service has been implemented`** which fails the moment
`StoryGraphView`, `StoryGraphPanel`, `StoryGraphNode` or `StoryGraphEdge` appears in
`lib/`. That guardrail is doing its job. See §14.

### The API Phase 2 requires from Phase 1

Do not start Phase 2 until the canonical read source provides all of the following.
If it does not, **stop and report** — do not build the missing half inside the Explorer.

1. **Both node kinds.** A unified node view over `AuthorRecord` **and**
   `ManuscriptNodeReference` (D-3 makes two kinds permanent). Every node exposes: id,
   kind, type id, title, owning domain/Studio, status, and whether its underlying entity
   is still resolvable.
2. **Bounded traversal.** Traversal from an origin node to a caller-supplied depth, with
   a hard node/edge budget, a visited set, and an explicit truncation signal the UI can
   render. Unbounded traversal must not be expressible.
3. **Neighbours.** Depth-1 neighbours of a node, direction-aware.
4. **Shortest path.** Between two nodes, bounded, returning the node and edge sequence, and
   returning "no path within bound" as a value rather than an exception.
5. **Project totals.** Node count and edge count for the current project, without
   materialising the whole graph into the UI layer.
6. **Unresolvable references.** A node whose entity no longer exists is returned as an
   explicit unavailable/deleted node, never as a silent omission and never as a crash.

If Phase 1 delivers less than this, Phase 2 is not ready. Say so and stop.

---

## 2. Decision D-4 — the Explorer is project-scoped

Record this decision formally in the Phase 2 documentation.

```text
AuthorOS
   ↓
Current Project
   ↓
Universal Story Graph
   ↓
Interactive Explorer
```

The Explorer reads **the current project only**. There is no all-projects graph, no
cross-project view, and no scope selector. A user must not be able to open a graph
containing every project they have ever created.

This is not only a performance decision. It preserves a clean future boundary:

```text
PRIVATE                          LATER — COMMUNITY
Project Story Graph              Shared World Graph
        ↓                                ↓
Interactive Explorer             Public / Community Explorer
        ↓                                ↓
Author's Studios                 Profiles / Shared Worlds / Maps
```

A shared or public graph scope, if it ever exists, is a separate surface. It must not be
introduced by widening this one. Do not add a scope parameter "for later".

---

## HARD RULES

### DO NOT

- Do not create a new database, table, migration, or schema version.
- Do not create a new node model, edge model, or relationship model.
- Do not persist graph state, graph layout, node positions, or viewport state to the
  database. (Ephemeral in-memory view state is fine. See §9 for the one narrow exception.)
- Do not create a second graph cache, graph index, or graph store. The Phase 1 service is
  the **only** read source.
- Do not read `DriftConnectedDomainRepository`, `AuthorOsDatabase`, `ManuscriptStore` or
  `record_link_rows` directly from Explorer code. Everything goes through Phase 1.
- Do not create, edit, or delete records, relationships, or manuscript nodes. **The
  Explorer is read-only.** No collaborative graph editing, no drag-to-connect.
- Do not create relationships automatically or infer them.
- Do not add AI relationship discovery, AI suggestions, or any AI functionality.
- Do not add community sharing, public profiles, leaderboards, cloud graph, or sync.
- Do not replace, wrap, or migrate any existing Studio model.
- Do not promote scenes or chapters into Universal Records. **D-3 stands.**
- Do not make `WritingSession` a node. Sessions are history, not graph truth — the
  guardrail in `test/story_graph_architecture_test.dart` pins this and must keep passing.
- Do not give Map Studio its own graph or model, and do not make the Story Graph
  responsible for map rendering. Map entities are consumed as ordinary graph
  entities/relationships **when available**, and nothing more. Map Studio Phase 3 is
  in flight; do not touch it.
- Do not build a second graph engine of any kind.
- Do not start Phase 3, Community, publishing, or further Analytics features.
- Do not weaken, skip, or delete existing tests to make this milestone pass. §14 governs
  the one guardrail that must legitimately change.
- Do not modify unrelated completed Studios except for the navigation hooks in §7.

### AT THE END

Do not commit. Do not push. Leave the working tree ready for manual review.

---

## 3. Placement — and one correction

The Explorer's **model** belongs in core. The Explorer's **UI** does not.

`lib/core/` is currently Flutter-free: **zero of its files import `package:flutter`**, and
`lib/core/universal_records.dart` states the dependency direction explicitly —
*core → storage → services → studios*, and *"nothing imports Flutter directly"*. Map
Studio is pinned to the same rule by `test/map_architecture_test.dart`.

A pan/zoom canvas cannot be written without Flutter. So the split is:

```text
lib/core/story_graph_explorer/     ← pure Dart. NO package:flutter import.
    explorer_state.dart              view state, selection, origin, depth
    explorer_filters.dart            filter model + predicates
    explorer_layout.dart             layout math, viewport, fit-to-view, hit-testing
    explorer_view_model.dart         composes Phase 1 reads into renderable output

lib/story_graph_view.dart          ← Flutter widgets. Sibling of map_studio_view.dart,
                                      plot_studio_view.dart, research_studio_view.dart.
```

If the widget layer grows past one file, use `lib/story_graph/` — matching the existing
`lib/world_board/` precedent — not `lib/core/`.

**Everything decidable without Flutter must live in core and be unit-testable without a
widget pump.** Filtering, traversal shaping, depth handling, fit-to-view arithmetic and
hit-testing are model concerns, not paint concerns. If a rule can only be tested by
pumping a widget, it is in the wrong layer.

Add an architecture assertion that `lib/core/story_graph_explorer/` contains no
`package:flutter/` import.

---

## 4. Interactive graph canvas

Build a canvas supporting:

- Pan
- Zoom (with sane min/max bounds; the author must never lose the graph off-screen)
- Fit-to-view
- Node selection
- Edge selection
- Hover information
- Focus selected node
- Reset view

Requirements:

- Selection state is single-source. A node and an edge cannot both be "the selection".
- Hover must not mutate selection.
- Reset view returns the viewport to a defined initial state, not to an arbitrary
  previous one.
- Fit-to-view fits the **currently visible** node set, after filters, not the whole graph.
- Rendering must not be O(all project records). See §9.

Use Flutter's existing painting primitives. Do not add a graph-rendering package, a
layout package, or a physics engine dependency without justifying it in the final report
and confirming it builds on web, Android and Windows.

---

## 5. Graph Explorer panel

A panel showing:

- Current project
- Node count
- Edge count
- Selected node details
- Relationship details for a selected edge
- Connected-node list for the selection
- Depth controls

Counts are the project totals from Phase 1 (§1.5). Where the rendered view is a bounded
subgraph, the panel must make the distinction visible — *"showing 48 of 512 nodes"* — and
never present the rendered subset as though it were the whole graph.

The connected-node list is navigable: selecting an entry selects that node on the canvas.

---

## 6. Filters and traversal

### 6.1 Filters

- Node type
- Studio / domain
- Relationship type
- Canon / certainty status **where the underlying entity actually exposes it** — do not
  invent the field, and do not add it to entities that lack it
- Connected-only / isolated nodes
- Search (title match, project-scoped)

Filters are inclusive and composable. An empty filter set means "any", matching the
existing `RecordGraph.related()` convention. Filters must be applied in the model layer
(§3), never inside a widget's `build()`.

Filtering must never widen the result set beyond the traversal bound, and must never be
implemented by fetching everything and then discarding.

### 6.2 Traversal controls

- Start from selected node (the **origin**)
- Depth 1 / 2 / 3+, with a hard maximum
- Neighbours
- Shortest path between two selected nodes
- Focus subgraph (re-root the view on the selection)

All of it goes through the Phase 1 bounded traversal API. The Explorer supplies the bound;
it does not implement traversal. If the Explorer contains a BFS, a DFS, or a visited set,
the boundary has been crossed — move it into Phase 1 or stop.

When traversal truncates, say so in the UI. Silent truncation is a correctness bug: the
author will read "no connection" where the real answer is "not within depth 2".

---

## 7. Author-friendly navigation

Selecting a graph node must offer a way to open the real AuthorOS object in its owning
Studio.

Reuse the existing navigation contract. Do not invent a second one:

- `SearchDestination` and `SearchNavigationTarget` — `lib/core/search_models.dart`
- `StudioSection` and its `onNavigate` plumbing — `lib/main.dart`

Precedents to follow rather than reinvent: `WorldBoardDestination`,
`CharacterWorkspaceDestination`, and the `SearchDestination` switch already wired in the
shell.

Rules:

- A node whose Studio destination is unknown offers no navigation action — it must not
  offer a dead one.
- A node whose entity is unresolvable (§8) offers no navigation action and says why.
- Manuscript nodes navigate to Manuscript Studio via the existing manuscript path. If the
  current plumbing cannot address a specific scene or chapter, navigate to the closest
  correct place and **report the limitation** — do not add a new deep-link mechanism.
- Adding a `StudioSection` value and its label/icon entries is expected. Rewiring other
  Studios' navigation is not.

The Explorer is exposed through the existing AuthorOS shell — a `StudioSection`, themed
through `StudioThemeScope` / `StudioId` (`lib/theme/theme_tokens.dart`). It is **not** a
separate application, a separate window, or a second graph surface.

---

## 8. Visual states

Every state below must be distinguishable:

| State | Meaning |
|---|---|
| Selected | The current selection |
| Origin | The node traversal started from |
| Connected | Reachable from the origin within the current depth |
| Filtered | Excluded by the active filters |
| Isolated | No relationships in scope |
| Unavailable / deleted | The reference resolves to no live entity |
| Manuscript-domain | The D-3 second node kind, visibly distinct |

**No state may be conveyed by colour alone** (§10). Each needs a second channel — shape,
border, icon, label, or opacity paired with a text affordance.

Unavailable nodes are shown, not hidden. A dangling reference the author can see is a
problem they can fix; one that is silently dropped is a problem they never learn about.

---

## 9. Performance safeguards

- **Do not render an unbounded graph by default.** Opening the Explorer on a large
  project must not attempt to lay out every node.
- Choose and document a default: a sensible origin (or an explicit empty state prompting
  the author to pick one) and a default depth. Justify the choice.
- Use the Phase 1 bounded traversal API for every read. Node and edge budgets are
  enforced there, not here.
- Do not build a second graph cache or store. Ephemeral per-frame view state is fine;
  a durable parallel copy of the graph is not.
- The Phase 1 service stays the canonical read source.
- Traversal and filtering happen off the build path. `build()` renders already-computed
  state.
- Repeated identical reads within one interaction should not re-query per frame. If you
  memoise, memoise **within the view model's lifetime**, keyed by the query — and say so
  in the documentation. That is the only caching permitted, and it is not a store.

State the tested ceiling in the final report: the node/edge count at which the canvas
stays interactive, and what happens beyond it.

---

## 10. Accessibility

- Keyboard navigation: move between nodes, select, change depth, focus, reset — reachable
  without a pointer.
- Semantic labels on every interactive element. A node's semantic label carries its
  title, type and state, not just its title.
- Tooltips on controls and on nodes.
- Accessible node information: everything the canvas conveys visually is available as
  text somewhere reachable.
- **No information conveyed solely by colour** — this applies to §8 states, to edges, and
  to the truncation and unavailable indicators.
- Respect the platform's reduced-motion setting for any animated transition.

Test the keyboard path and the semantics, not just the pointer path.

---

## 11. Boundary — what Phase 2 does not do

Restated as a checklist because the boundary is the point of this milestone. **No:**

- new database
- new graph tables
- new edge model
- graph persistence
- automatic relationship creation
- AI relationship discovery
- community sharing
- public profiles
- leaderboards
- cloud graph
- collaborative graph editing
- replacing existing Studio models
- promoting scenes/chapters into Universal Records
- `WritingSession` nodes
- Map Studio's own graph/model
- a second graph engine

If a requirement in §4–§10 appears to need one of these, the requirement is wrong. Stop
and report rather than crossing the line.

---

## 12. Tests

Name them `test/story_graph_phase2_*.dart`. Cover:

**Model (no widget pump):**

- Filters: each filter type, composition, empty set means any, no filter widens the set.
- Depth: 1, 2, 3+, and the hard maximum enforced.
- Truncation is surfaced as a value the UI can render.
- Shortest path: found, not found within bound, path to self.
- Isolated nodes, connected-only.
- Search filtering is project-scoped.
- Both node kinds appear (D-3): records **and** manuscript nodes.
- Unresolvable references become explicit unavailable nodes; no crash, no silent drop.
- Fit-to-view and reset-view arithmetic.
- Project isolation: an Explorer opened on Project A can never surface a Project B node,
  through any filter, depth, path or search input.

**Widget:**

- Selection, hover-does-not-select, edge selection.
- Focus subgraph re-roots the view.
- Panel counts match the service, and the "showing N of M" distinction is rendered.
- Navigation to the owning Studio fires the existing destination contract.
- A node with no known destination offers no navigation action.
- Keyboard navigation reaches and selects nodes.
- Semantic labels carry title, type and state.

**Architecture:**

- `lib/core/story_graph_explorer/` imports no `package:flutter/`.
- The Explorer does not import `AuthorOsDatabase`, `DriftConnectedDomainRepository` or
  `ManuscriptStore`.
- No new table, no schema version change.
- No write path: the Explorer calls no create/update/delete on records or relationships.
- No second traversal implementation in the Explorer layer.

**Tests must prove behaviour, not inspect implementation text**, except where the
assertion *is* an architectural boundary.

---

## 13. Regression protection

Run the full suite. These must remain intact: Analytics, Writing Session History, World
Board, Research Studio, Map Studio, Plot Studio, Timeline Studio, Character Studio,
Manuscript Studio, Story Codex, Theme Engine, Web Application, Startup Experience.

Map Studio Phase 3 is in flight on its own branch. Do not modify Map Studio. If the
Explorer needs something from it, consume it through the canonical graph API or record
the gap as follow-up.

---

## 14. The `no Story Graph UI` guardrail

`test/story_graph_architecture_test.dart` asserts that no `StoryGraphView`,
`StoryGraphPanel`, `StoryGraphWorkspace`, `StoryGraphNode`, `StoryGraphEdge` or
`StoryGraphService` exists in `lib/`. Phase 2 makes that assertion false **by design**.

- **Do not delete the test.** Do not weaken it to `skip`. Do not rename symbols to evade it.
- **Rewrite it into the invariant that replaces it** — the same treatment R-4 received
  when the research migration landed. The replacement asserts what is now true and still
  forbidden: the Explorer exists, and it has no second store, no second edge model, no
  write path, and no direct database access.
- Update `docs/universal-story-graph-architecture.md` in the same commit, per its own
  §13 instruction. A guardrail change is an architectural decision and must be recorded
  as one.

Every other guardrail in that file must still pass unchanged — in particular the single
persistence system, the project isolation, the writing-sessions-are-not-graph-truth, the
map-coordinates-stay-record-fields and the dangling-link assertions.

---

## 15. Validation

```
flutter test
flutter analyze
flutter build web --release
git diff --check
```

Compare analyzer output against baseline. **No new analyzer issues are acceptable.**

The canvas must be verified on more than one form factor — a narrow window must not
produce an unusable Explorer. If Windows or Android verification is unavailable, say so
explicitly rather than omitting it.

---

## 16. Documentation

Create `docs/universal-story-graph-phase-2-explorer.md` covering: what was built; the
core/UI split and why (§3); decision **D-4** and its future community boundary (§2); the
exact Phase 1 API consumed; the default origin and depth and their justification; the
filter model; the traversal controls; the visual-state vocabulary and its non-colour
channel for each state; the navigation contract and any Studio it cannot yet address;
the performance ceiling measured; the memoisation used, if any, and why it is not a
store; the accessibility surface; the guardrail rewritten in §14 and why; remaining
limitations; and the recommended Phase 3 starting point.

---

## 17. Final report

Return: files created, modified, deleted; the Phase 1 API surface consumed; confirmation
that no table, migration, schema version, node model or edge model was added;
confirmation that the Explorer holds no write path and no direct database access; the
default origin/depth choice; the measured performance ceiling and behaviour beyond it;
the visual-state vocabulary with its non-colour channels; the accessibility surface and
what was tested; the navigation destinations wired and any that could not be; the §14
guardrail rewrite; tests added; full test result; analyzer result vs baseline; web build
result; multi-form-factor result; Windows/Android result or an explicit statement that it
was unavailable; `git diff --check` result; remaining limitations; and the recommended
Phase 3 starting point.

---

## STOP CONDITION

**STOP after Phase 2.** Do not start Phase 3, a shared or community graph, graph editing,
graph persistence, relationship inference, or any AI feature.

Do not commit. Do not push. Leave the working tree ready for manual review.
