# AUTHOROS — UNIVERSAL STORY GRAPH

Phase 2 — Explorer Gap Closure

Status: **rewritten against `main` at `d1b74c8`**
Supersedes: the original Phase 2 directive, written when no Story Graph existed
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes
Scope decision: **D-4** — the Explorer is project-scoped (§2)

You are working in `flutter-author-studio-v1/`.

---

## 0. Why this document was rewritten

The original Phase 2 directive specified an Interactive Graph Explorer to be built
on a Phase 1 read model that did not yet exist. Both halves have since shipped:

| Merged | What it delivered |
|---|---|
| **#29** — Story Graph Phase 0 | Manuscript node lifecycle. Retires nodes whose scene or chapter is gone, and fixes the edge foreign key that made a connected node undeletable. **R-1 is closed.** |
| **#35** — Knowledge Graph, Story Graph Phases 1–3 | `lib/core/story_graph.dart`, `story_graph_service.dart`, `story_graph_modes.dart`, `story_graph_mutations.dart`, and the `lib/knowledge_graph/` studio — canvas, layout, side panels, canvas persistence. |

So the milestone is no longer "build the Explorer". It is **close the gaps between
what the shipped studio does and what Phase 2 specified**. This document is that
gap list, verified against the merged tree rather than assumed.

**Do not rebuild what exists.** Do not create a second graph view, a second read
model, or a second canvas. Every item below is a change to the studio that is
already there.

---

## 1. Verified state — what is already done

Checked against `lib/knowledge_graph/` and `lib/core/story_graph_service.dart` at
`d1b74c8`. **Do not redo any of this.**

| Phase 2 requirement | Status | Evidence |
|---|---|---|
| Pan | **Done** | `onPan` / drag handlers in `graph_canvas.dart` |
| Zoom | **Done** | `_zoomControls`, keys `graph-zoom-in` / `graph-zoom-out`, `projection.zoom` |
| Node selection | **Done** | `_selectedId`, `onNodeTap`, `graph-node-<id>` keys |
| Focus / re-root subgraph | **Done** | click-to-refocus Connection Explorer |
| Filters | **Done** | filter rail, and it states what it hides |
| Truncation surfaced | **Partly** | `graph-truncation-notice` renders "Showing the first N nodes" — see §3.1 |
| Open in owning Studio | **Done** | `onNavigate`, `SearchNavigationTarget`, `searchDestinationForType`, `onOpenInStudio` |
| Tooltips on nodes | **Done** | `Tooltip` around the node chip |
| Node semantics | **Partly** | `Semantics(button:, selected:, label: '<title>, <typeId>')` — see §3.4 |
| Bounded reads | **Done** | `kStoryGraphDefaultMaxNodes = 250`, `truncated` on subgraph and neighbourhood |
| Canvas persistence | **Done** | positions and entity ids stored as an ordinary record, never edges |

The original directive's §7 called for author-friendly navigation into the owning
Studio and treated it as unbuilt. **It is built.** It reuses the existing
`SearchDestination` contract exactly as specified. Nothing to do there.

---

## 2. Boundary — unchanged and still binding

The shipped studio respects the graph boundary. Keep it that way.

### DO NOT

- Do not add a database, table, migration, or schema version.
- Do not add a second node model, edge model, read model, service, or canvas.
- Do not persist graph structure. Canvas arrangement persists as an ordinary
  record holding positions and entity ids; **edges are never persisted there**,
  and that must stay true.
- Do not widen `story_graph_mutations.dart`. Whatever write surface it already
  has is the write surface; this milestone adds none.
- Do not add automatic relationship creation, relationship inference, or any AI
  feature.
- Do not add community sharing, public profiles, shared worlds, or a cloud graph.
- Do not add collaborative graph editing.
- Do not promote scenes or chapters into `AuthorRecord`s. **D-3 stands.**
- Do not make `WritingSession` a node.
- Do not give Map Studio its own graph, and do not make the Story Graph
  responsible for map rendering.
- Do not remove the project scope. **D-4 stands**: the Explorer reads the current
  project only. A shared or public graph is a separate future surface, never a
  widening of this one.
- Do not weaken or delete a guardrail in `story_graph_architecture_test.dart` to
  make a change pass.

### AT THE END

Do not commit. Do not push. Leave the working tree ready for manual review.

---

## 3. The gaps — what this milestone builds

Ordered by value to the author, not by implementation cost.

### 3.1 Truncation tells the author how much is missing

**Current:** the notice reads *"Showing the first N nodes. Filter down to see the
rest."* It is honest that the view is partial, which is the important half, and it
is already better than silent truncation.

**Gap:** it never says how much "the rest" is. Forty-eight of fifty reads the same
as forty-eight of five thousand, and those call for completely different author
decisions.

**Build:** a project totals read on `StoryGraphService` — node count and edge count
for the current project, counted in the database rather than by materialising
records — and render "Showing 48 of 512". `findPaths` already proves the service
can answer a question the studio does not ask; this is the same shape.

Counts must match what a default read would show: exclude soft-deleted records, and
count both node kinds.

### 3.2 Fit-to-view and reset view

**Current:** pan and zoom exist. Neither has a way back.

**Gap:** an author who pans far or zooms deep has no recovery except reloading the
studio. Verified absent — no `fitTo*`, no `resetView`.

**Build:** *Fit to view* frames the **currently visible** node set, after filters,
not the whole project graph. *Reset view* returns to a defined initial projection,
not to an arbitrary earlier one. Both sit with the existing zoom controls and take
the same tooltip and key treatment (`graph-fit-to-view`, `graph-reset-view`).

### 3.3 Edge selection and hover

**Current:** nodes are selectable. Relationships are drawn but inert — no
`onEdgeTap`, no `selectedEdge`, no `MouseRegion` anywhere in the studio.

**Gap:** the relationship *is* the story information. "How is Kali connected to
Endovier" is answered by the edge, and today the author cannot select one to find
out.

**Build:**

- Edge selection, showing the relationship's type, label, direction and endpoints
  in the side panel.
- Hover information on nodes and edges. **Hover must not mutate selection** — it
  is a preview, not a click.
- Selection stays single-source: a node and an edge cannot both be "the selection".

### 3.4 Semantic labels carry state, not just identity

**Current:** `Semantics(button: true, selected: isSelected, label: '<title>, <typeId>')`.
Good foundation — the node is a button, and selection is exposed.

**Gap:** the label stops at identity. A screen-reader user hears "Kali, character"
and learns nothing about what the canvas is showing them visually: whether the node
is canon, archived, the traversal origin, isolated, manuscript-domain, or an
unavailable reference.

**Build:** extend the label to carry the states in §3.5. No `semanticLabel` exists
anywhere in the studio today; this is the accessibility gap that matters most,
because it is where visual and non-visual users get different information.

### 3.5 Visual states, each with a non-colour channel

**Gap:** the state vocabulary is incomplete and leans on colour.

**Build:** every state below must be distinguishable, and **none may be conveyed by
colour alone** — each needs a second channel (shape, border, icon, label, or
opacity paired with a text affordance), and each must appear in the semantic label:

| State | Meaning |
|---|---|
| Selected | the current selection |
| Origin | the node the current subgraph was rooted at |
| Connected | reachable from the origin within the current depth |
| Filtered | excluded by the active filters |
| Isolated | no relationships in scope |
| Unavailable | the reference resolves to no live entity |
| Manuscript-domain | the D-3 second node kind, visibly distinct |

Unavailable nodes are **shown, not hidden**. Phase 0 closed the ghost-node hole
that created most of them, but an archive restore can still produce structure
whose entity is absent. A dangling reference the author can see is a problem they
can fix; one silently dropped is a problem they never learn about.

### 3.6 Keyboard navigation

**Current:** `Ctrl`/`Cmd`-K toggles search. That is the whole keyboard surface, and
the code says so — a comment records that a wider binding was left out of that
milestone deliberately.

**Gap:** the canvas cannot be operated without a pointer. Move between nodes,
select, focus, change depth, zoom, fit, reset — none is reachable from the
keyboard.

**Build:** keyboard traversal of the visible node set with a visible focus
indicator, plus keyboard access to select, focus, reset and zoom. Keep it
Studio-scoped, as the existing `Shortcuts`/`Actions` block already is; do not wrap
the shell.

### 3.7 Author-controlled depth

**Current:** depth is fixed per mode — `depth: _mode.defaultDepth`.

**Gap:** the four modes are a good default frame, but the author cannot ask "one
more hop" without changing mode, which changes everything else too.

**Build:** a depth control (1 / 2 / 3+, to the bound the service already enforces)
that re-reads through the existing bounded traversal. The Explorer supplies the
bound; it must not implement traversal. If the studio grows a BFS or a visited set,
the boundary has been crossed — stop.

### 3.8 Surface shortest path

**Current:** `StoryGraphService.findPaths` exists and is **not called from the
studio**. A shipped capability with no way to reach it.

**Gap:** "how are these two connected" is one of the questions a story graph is
most useful for.

**Build:** select two nodes, show the path between them, and render "no path within
this depth" as a distinct answer from "not connected" — the search is bounded, and
conflating those two tells the author something false.

---

## 4. Tests

Extend the existing files — `knowledge_graph_view_test.dart`,
`knowledge_graph_canvas_test.dart`, `story_graph_service_test.dart` — rather than
starting parallel ones.

Cover, at minimum:

- Totals: counts exclude soft-deleted records, count both node kinds, and the
  notice renders "N of M".
- Fit-to-view frames the filtered set, not the project.
- Reset view returns to the defined initial projection.
- Edge selection shows relationship detail; hover does not change selection;
  node and edge selection are mutually exclusive.
- Semantic labels carry state for each of the seven states in §3.5.
- Every §3.5 state is distinguishable without colour.
- Keyboard: reach a node, select it, focus it, change depth, reset — no pointer.
- Depth control re-reads through the bounded service and never traverses locally.
- Shortest path: found, and "none within bound" reported distinctly.
- Project isolation still holds through every new control.
- No new write path: the studio still mutates nothing beyond the existing canvas
  arrangement record.

Tests must prove behaviour, not inspect implementation text, except where the
assertion *is* an architectural boundary.

---

## 5. Regression protection

Run the full suite. `main` is green at `d1b74c8`; that is the baseline.

Every guardrail in `story_graph_architecture_test.dart` must still pass —
particularly the single persistence system, project isolation,
writing-sessions-are-not-graph-truth, map-coordinates-stay-record-fields, and the
dangling-link assertions. If one fails, an architectural decision was made, and
`docs/universal-story-graph-architecture.md` must be updated alongside it in the
same commit.

Map Studio Phase 3 is in flight on its own branch. Do not modify Map Studio.

---

## 6. Validation

```
flutter test
flutter analyze
flutter build web --release
git diff --check
```

Compare analyzer output against baseline. **No new analyzer issues are acceptable.**

Verify the canvas on more than one form factor — a narrow window must not produce
an unusable Explorer. Verify the keyboard path on a real build, not only in tests.
If Windows or Android verification is unavailable, say so explicitly rather than
omitting it.

---

## 7. Documentation

Update `docs/universal-story-graph-architecture.md` with anything that changes an
architectural claim, and write `docs/universal-story-graph-phase-2-gap-closure.md`
covering: what was closed and what was left; the totals read and its cost; the
visual-state vocabulary with the non-colour channel for each state; the
accessibility surface and what was tested on a real build; the keyboard map; the
depth control and the bound it respects; and any gap in §3 deliberately not closed,
with the reason.

---

## 8. Final report

Return: files modified; each §3 gap and whether it was closed; confirmation that no
table, migration, schema change, second read model, second canvas or new write path
was added; the totals implementation and its query cost; the visual-state vocabulary
with non-colour channels; the keyboard map; tests added; full test result; analyzer
result vs baseline; web build result; multi-form-factor result; Windows/Android
result or an explicit statement that it was unavailable; `git diff --check` result;
and anything left open.

---

## STOP CONDITION

**STOP after closing these gaps.** Do not start a shared or community graph, graph
editing beyond what already exists, relationship inference, or any AI feature.

If a gap in §3 turns out to be already closed, say so and skip it — do not rebuild
it to match this document. This directive was written from a verified read of the
merged tree, but the tree moves.

Do not commit. Do not push. Leave the working tree ready for manual review.
