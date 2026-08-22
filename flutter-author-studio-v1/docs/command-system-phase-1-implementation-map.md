# Command System Phase 1 Implementation Map

## Scope

Phase 1 is the author's navigation layer over the whole application: one text
field that reads a phrase, answers it from the live record graph, and takes the
author to whatever it found. It adds a deterministic grammar, an executor over
the existing query surfaces, a confirmable action layer, a command palette bound
to Cmd/Ctrl+K, and the Command Console page that replaces the legacy Search
section.

It does not add a database, a table, a search index, a second edge model, or any
generative AI.

## Why it exists

AuthorOS already had a story graph. Every Studio writes `AuthorRecord`s and typed
`RecordLink`s through one persistence layer, 224 record types and 130 connection
types are registered, and the Story Graph exposes traversal. What it did
not have was a way for the author to *ask* it anything.

The one cross-cutting surface, the "Universal Search" section, was legacy:
`SearchStudioView` loaded a few `SharedPreferences` stores into memory and
substring-matched them. It never touched `UniversalSearchService`, the full-text
index, the record graph, or navigation — and its load path called
`ManuscriptStore.loadStudio`, which *writes*. The connections existed in the data
and were invisible in the product.

## Architecture

The Command System is a facade over shared infrastructure, in the same shape as
Plot Studio Phase 1:

- `RecordTypeRegistry` and `ConnectionTypeRegistry` supply the vocabulary.
- `UniversalSearchService` answers the text half of every query.
- `DriftConnectedDomainRepository` supplies records, manuscript nodes and links.
- `PlotQueryService` answers the story-status questions Plot Studio already owns.
- `RecordService` and `PlotService.validatePlot` supply the conflict report.
- `RecordService`, `ConnectionEngine`, `ManuscriptService.connectNode` and the
  Studios' own create methods are the only write paths.
- `SearchNavigationTarget` and `searchDestinationForType` route every result.

```
  phrase ─► CommandGrammar ─► CommandQuery ─► CommandService ─► CommandResult
            lib/core/          lib/core/       lib/              rows + chips
```

### Layering

`lib/core/` may not import Flutter or a Studio, so the grammar and the query model
live there and the executor does not. `CommandService` reaches `PlotService`, and
`CommandActionService` reaches five Studio services, so both sit at the service
layer beside `plot_service.dart`.

## The grammar

`CommandGrammar.parse` is a pure function of a phrase and a `CommandVocabulary`.
It never throws and never fails: a phrase it cannot read becomes
`CommandQuery.freeText`, which the executor runs as an ordinary full-text search.

The vocabulary is **derived at run time**, not written down:

- **Subjects** come from `RecordTypeRegistry.definitions`. Each definition
  contributes its id and its name, singular and plural. A subject resolves to a
  *family* — the inheritance closure computed with
  `RecordTypeRegistry.isTemplateCompatible` — so "characters" covers every type
  that inherits `character`, including a project's own.
- **Categories** are subjects too, inflected from both their singular and plural
  forms so that "character" and "characters" can never resolve differently.
- **Relations** come from `ConnectionTypeRegistry.definitions`. The id, the
  `displayName` and the `inverseLabel` all become phrases, which makes every edge
  speakable from either end. Verb forms — "appear in", "appears in", "appearing
  in" — are generated from the head verb rather than listed.
- **Manuscript kinds** register `scene` and `chapter`, which are
  `ManuscriptNodeReference`s rather than records. This is the one place the
  Command System declares the two node kinds.

Two types that share a display name merge rather than compete: `event` and
`timeline-event` are both called "Event", so "events" searches both.

The only hardcoded words are English function words — `show`, `all`, `with no`,
`before`, `on the map` — plus four everyday aliases (`plot thread`, `story
thread`, `storyline`, `world record`) that name an existing *category* rather
than a list of types, so a new plot type is covered automatically.

### Reading itself back

Every recognised run of words becomes a `CommandTerm`, rendered as a chip under
the input. A rule-based parser is only trustworthy if the author can see how
their words were read, so the chips are part of the feature rather than a debug
affordance. Words the parser did not use are shown as ignored.

## Execution

`CommandService.execute` dispatches on the parsed query:

| Question | Answered by |
|---|---|
| `Show me Kali` | anchor resolution, then the entity and everything around it |
| `Show everything connected to Kali` | the link index, spanning records and nodes |
| `Show all unresolved plot threads` | the `plotStatus` rule from `plot_service.dart`, plus `PlotQueryService.unresolvedSetups` |
| `Show characters appearing in Chapter 20` | the chapter node **and its scenes**, filtered to the character family and the `appearsIn` edge |
| `Show all events occurring before Chapter 15` | each record's earliest manuscript position, against the chapter's `order` |
| `Show every location on the map used in Book 1` | `MapFields.mapId` for placement, `bookId` for scope |
| `Show research connected to House Noxmere` | the link index, filtered to the research family |
| `Show canon conflicts` | record validation, `PlotService.validatePlot`, canon-status contradictions across edges, and edges pointing at entities that are gone |
| `Show characters not yet assigned to a plot` | absence of any edge into the plot family |
| `Show scenes with no location` | no location edge **and** no location named in the scene's prose field |
| `Show timeline events with no chapter` | absence of any edge to a chapter node |

Three decisions are worth recording:

**Both node kinds, always — through the Story Graph.** Scenes and chapters are
`ManuscriptNodeReference`s, not records, and a navigation layer that showed only
one kind would be lying about the story. `StoryGraphNode` already renders both,
and `StoryGraphService.getNeighbours` already traverses across them, so the
executor composes those rather than walking the link table itself.

*(An earlier draft of this milestone hand-rolled that traversal, because
`RecordGraph.related` resolves far endpoints with `recordById` and silently drops
anything that is not a record. The Story Graph read layer landed first and made
the hand-rolled version redundant.)*

**A chapter question means its scenes.** Characters appear in scenes, not
chapters. `_Workspace.anchorScope` expands a chapter anchor to the chapter and
every scene that names it, or "characters appearing in Chapter 20" would return
nothing while looking correct.

**Reading never writes.** Manuscript nodes come from
the graph's projection of `manuscript_node_rows`, never
`ManuscriptStore.loadStudio`, which seeds and reconciles the projection as a side
effect. A navigation query must not change the project.

Links are loaded once per command with `linksByScope` and indexed in memory.
"Characters not yet assigned to a plot" touches every character; per-record
`backlinks` calls would make it quadratic.

## Actions

`link` and `create` parse like any other command and then stop. They become a
`CommandActionPreview` — a sentence naming exactly what would change, with both
endpoints already resolved — and nothing is written until
`CommandActionService.apply(confirmed: true)`. The two-step shape follows
`ContinuityActionService.createForRecommendation`.

Writes route to the code that owns them: `ConnectionEngine.connect` for
record-to-record edges, `ManuscriptService.connectNode` when one endpoint is a
scene or chapter (it owns the direction rule), and each Studio's own create
method for new records, so a created character arrives with Character Studio's
template and fields rather than as a bare record.

A command is refused, with a reason, when a name matches nothing, an endpoint is
ambiguous, a record would link to itself, the pair is already connected that way,
a duplicate record would be created, or no connection type joins the two kinds.

**Relationship type is asked, not guessed.** 73 of the 130 connection types
accept any endpoints, so a permitted match says very little. Only a type that
names both kinds specifically, and is the only one that does, is chosen
automatically; otherwise the author picks from the offered types.

## Surface

- `CommandPalette` — Cmd/Ctrl+K from any Studio. The layer sits above the section
  switcher in `AuthorStudioShell`, so Manuscript Studio's own bindings still work
  and the key still arrives. The top bar has advertised `Ctrl+K` since before
  anything listened for it; it now opens the palette.
- `CommandConsole` — the shared body: input, "Understood as" chips, grouped
  results, disambiguation, and the action proposal card.
- `SearchStudioView` renders the same console as a full page. Its legacy
  in-memory search and the two widgets that supported it are gone.

Results navigate through the contract that already existed:
`SearchNavigationTarget` → `searchDestinationForType` → `studioSectionFor` →
`StudioSection`.

## Ownership

The Command System owns no records, no connections and no storage. Every Studio
remains the owner of its own domain; this is a read model over all of them, and a
narrow, confirmable write path into their existing create and connect methods.

## Tests

| File | Pins |
|---|---|
| `test/command_grammar_test.dart` | all eleven author phrases parse to the expected query; nonsense degrades to search; number is never load-bearing; a type registered at run time becomes speakable |
| `test/command_service_test.dart` | each phrase end-to-end against a seeded database, by exact id, including the negative queries and both node kinds; reading writes nothing |
| `test/command_actions_test.dart` | preparing writes nothing; declining writes nothing; confirming writes the edge *and* its version and audit event; duplicates, self-links and unknown names are refused |
| `test/command_console_test.dart` | chips render; a result navigates to the owning Studio; an action asks first; Ctrl+K and Cmd+K open the palette, including from Manuscript Studio |
| `test/command_architecture_test.dart` | the grammar imports no Flutter and no Studio; no command file declares a store; actions never bypass the engines; the executor never loads the manuscript; nothing reaches the network; the vocabulary stays derived |

`test/story_graph_architecture_test.dart` continues to pass unchanged: no file
path contains `story_graph`, none of the reserved `StoryGraph*` symbols appear in
`lib/`, `ImpactTraceAnalyzer` gains no caller, no table is added, and every edge
is still a `RecordLink` written by `ConnectionEngine`.

## What the graph settles, and what this adds

Two rules come from `StoryGraphService` rather than from here, and are better for
it:

- **Wildcard edges.** 73 of the ~130 connection types permit any endpoints, so a
  graph *view* hides them by default or they swamp the picture. A command is the
  opposite case: an author who types "everything connected to Kali" means
  everything, so the executor opts them back in — and naming a relationship
  narrows it again, because an explicit edge type beats both noise switches.
- **What is not a node.** A knowledge canvas references graph entities and is read
  alongside them, but it is an arrangement *of* the story rather than a thing the
  story is made of. `kNonGraphRecordTypeIds` excludes it, so it can never appear
  as a command result.

Phase 0 (manuscript node lifecycle integrity) shipped before this milestone, so
the ghost-node caveat an earlier draft of this document carried no longer
applies: `saveStudio` reconciles the projection, and node removal is link-safe.
