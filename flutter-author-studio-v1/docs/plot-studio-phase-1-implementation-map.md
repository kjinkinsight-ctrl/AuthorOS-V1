# Plot Studio Phase 1 Implementation Map

## Scope

Plot Studio Phase 1 is the story architecture domain layer. It adds Plot-owned
Universal Record definitions, a service facade, reusable queries, warning-only
creative validation, branch support, future UI view models, and a cross-system
fixture. It does not add a Plot database, a second graph, or a polished UI.

## Architecture

`PlotService` is a facade over the existing shared infrastructure:

- `RecordService` creates, updates, archives, restores, and duplicates records.
- `ConnectionEngine` owns every relationship and stable-ID link.
- `RecordValidation` performs shared schema and scope validation.
- `RecordTypeRegistry` and `TemplateEngine` resolve built-in and custom types.
- `BranchService` provides sparse inherited, overridden, created, and hidden states.
- `UniversalSearchService` uses the shared FTS index.
- `UniversalRecordInspector` exposes identity, references, connections, history,
  template, scope, Canon, branch, validation, and safe-delete information.
- `VersionAuditService` captures record, connection, and branch changes.
- `SafeDeleteService` analyzes dependencies and keeps deletion non-physical.

The implementation introduces no persistence table or schema migration. Plot
records use the existing `AuthorRecordRows`; links use `RecordLinkRows`; custom
types use `RecordTypeDefinitionRows`; history and branches use their existing
shared tables.

## Ownership

Plot Studio owns only Plot-specific records. Character Studio remains the owner
of Characters, World Studio remains the owner of World records, Story Codex
remains the owner of Codex knowledge, Timeline Studio remains the owner of
Timeline records, and Manuscript Studio remains the owner of chapters and scenes.
Plot references those records through stable Universal Record IDs.

## Record Types

`PlotRecordTypes` registers an abstract `plot-record` base and these concrete,
data-driven types:

- Story, Act, Sequence, Plot, Plotline, and Subplot
- Arc, Character Arc, Relationship Arc, World Arc, Political Arc, Romance Arc,
  and Mystery Arc
- Conflict, Goal, Motivation, Obstacle, and Stake
- Turning Point, Beat, Arc Beat, Story Event, Reveal, Foreshadowing, and Payoff
- Set Piece, Climax, Resolution, Scene Plan, and Chapter Plan

Specialized arcs inherit the generic Arc model. Subplot inherits Plotline, Arc
Beat inherits Beat, and Climax and Resolution inherit Turning Point. Project
custom types extend `plot-record` through persisted `RecordTypeDefinition` data;
no UI list is hard-coded.

## Story Hierarchy

Hierarchy is represented by `contains` and `partOf` connections. The default
Series to Book to Act to Sequence to Chapter to Scene hierarchy can coexist with
Story to Plotline to Arc to Beat and Character to Character Arc to Arc Beat.
No universal parent hierarchy is enforced. Custom structures can use the same
open connection types.

## Acts And Sequences

Acts inherit name, summary, description, purpose, status, ordering, dependencies,
scope, Canon, and branch metadata. Act-specific fields include opening and closing
state. Plotlines, arcs, beats, chapters, and scenes are connections rather than
duplicated records.

Sequences add goal, conflict, and outcome. Characters, locations, plotlines,
arcs, beats, chapters, scenes, and Timeline references use shared connections.

## Plotlines

Plotlines support summary, purpose, description, priority, status, start, target
resolution, actual resolution, tags, Canon, and branch metadata. Built-in type
values are main, subplot, character, romance, mystery, political, world,
conflict, investigation, survival, quest, and custom. Characters, locations,
factions, Codex records, Timeline events, chapters, scenes, and other Manuscript
references remain stable-ID connections.

## Arcs

The generic Arc model includes beginning state, desired end state, current state,
free-form progression, and resolution. Goals, conflicts, turning points, beats,
and consequences are links, so no fixed arc formula is imposed.

Character Arc adds starting state, goal, motivation, false belief, internal and
external conflict, truth, transformation, and ending state. `hasArc` connects a
Character to a Character Arc; `contains` connects the arc to Arc Beats; and
`appearsIn` connects Arc Beats to Scenes. Character data is not copied.

Relationship Arc stores initial relationship, free-form progression, and final
state. Attraction, trust, conflict, betrayal, separation, reconciliation, and
commitment can be progression entries or connected beats involving the original
Character records.

World Arc represents story progression affecting locations, factions,
governments, cultures, magic systems, political systems, wars, and societies.
The affected World records remain World Studio records.

## Beats And Order

Beats support type, summary, purpose, description, status, importance, tags, and
consequence. Plotline, arc, Character, location, Timeline event, chapter, scene,
conflict, goal, and stakes associations are shared links.

Planning order, narrative order, and chronological order are separate numeric
fields on the Plot base. No code equates scene order with Timeline order.

## Goals, Motivations, Obstacles, Stakes, And Conflicts

Goals include owner, success condition, failure condition, deadline, and status.
Owners can be Characters, factions, plotlines, stories, or World records.
`pursues`, `motivatedBy`, `opposes`, and `hasStake` express the graph.

Motivation types include survival, love, revenge, freedom, power, belonging,
duty, protection, truth, redemption, fear, ambition, and custom.

Obstacles include type, source, target, escalation, resolution, and consequence.
Stake categories include personal, emotional, relationship, physical, moral,
political, social, world, existential, and custom; none is mandatory.

Conflict types include Character versus Character, Self, Society, Nature,
System, Supernatural, Faction, World, and custom. Conflicts support source,
target, escalation, outcome, consequences, motivations, stakes, and turning
points without duplicating endpoint records.

## Turning Points And Templates

Turning Point types include inciting incident, first major decision, midpoint,
reversal, crisis, climax, resolution, and custom. Connections locate them in
Characters, plotlines, arcs, Timeline events, chapters, and scenes.

`PlotStructureTemplates` provides configurable Three Act, Five Act, Hero's
Journey, Save the Cat, Seven Point, Snowflake, and Custom definitions. These are
starter data, not validation rules. Snowflake is marked hierarchical; Custom has
no prescribed stages.

## Reveals And Knowledge

Reveal records store the secret, revealed information, recipient, revealer,
intended reveal point, actual reveal point, and status. Author knowledge,
Character knowledge, and reader knowledge are separate fields. Character
knowledge is structured per Character and can represent knowledge, suspicion,
misinformation, forgetting, discovery, betrayal, mystery, and dramatic irony.

## Foreshadowing And Payoffs

Foreshadowing stores the plant plus Character and reader awareness. `leadsTo`
connects it to a Reveal and `paidOffBy` connects it to a Payoff. Payoffs store
setup, payoff content, expected timing, and actual timing. Related plotlines,
Characters, reveals, chapters, and scenes are links.

Validation warns about unresolved setups, missing payoffs, missing setup links,
and pending reveals. These warnings never block ordinary authoring.

## Consequences And Dependencies

`causes` and `changes` model Decision to Event and Event changes to Character,
Relationship, World, or Plotline. `dependsOn`, `leadsTo`, `paidOffBy`, `opposes`,
`motivatedBy`, and `hasStake` prepare the dependency graph foundation. The service
detects prohibited dependency cycles, but Phase 1 does not implement a visual
graph editor.

## Integrations

Character integration uses `hasArc`, `contains`, `appearsIn`, `involves`, and
general Plot links. Character Studio remains the source of Character identity.

World and Codex integration uses stable IDs and shared links such as `relatedTo`,
`changes`, and `causes`. Plot records may reference locations, factions,
governments, cultures, religion, magic, history, secrets, and artifacts without
copying their data.

Timeline integration uses `occursDuring`, `depicts`, `causes`, and other shared
temporal relationships. Timeline-linked queries inspect backlinks and do not
duplicate Timeline records.

Manuscript integration uses `plannedFor`, `fulfilledBy`, `appearsIn`, and
`resolvesIn` for scenes and chapters. Manuscript content remains owned by
Manuscript Studio.

## Query Service

`PlotQueryService` provides:

- beats by book, chapter, scene, plotline, arc, and Character
- unresolved plotlines, arcs, setups, and missing payoffs
- pending reveals, active conflicts, active goals, and completed goals
- Character Arc and World Arc progression
- branch-specific, Canon-only, and Timeline-linked Plot records
- future view-model items with independent planning, narrative, and chronology

Primary type queries use indexed `recordsByTypeAndScope`. Relationship queries
use indexed backlinks and direct record lookup. Normal Plot queries do not load
the entire database. Branch resolution delegates to the existing BranchService,
which currently resolves a project snapshot to apply sparse overlays.

## Search And Inspector

`searchPlot` delegates to Universal Search and filters results through the record
type registry. Names, summaries, descriptions, tags, typed fields, Canon, book,
series, project, and branch metadata remain in the shared search path.

`inspectPlotRecord` delegates to UniversalRecordInspector. No Plot-specific
inspector exists.

## Version, Delete, And Validation

All record, connection, and branch mutations flow through RecordService,
ConnectionEngine, BranchService, and VersionAuditService. No Plot history service
exists.

Safe-delete analysis includes incoming and outgoing connections, references,
branches, versions, audit events, and affected records. Plot exposes analysis but
does not physically delete records.

Shared RecordValidation detects schema, scope, template, and project errors.
Plot validation adds warnings for broken dependency references, orphaned and
unfulfilled beats, orphaned scenes, unresolved plotlines and arcs, missing setups
and payoffs, pending reveals, missing climax and resolution, duplicate narrative
positions, and circular dependencies. Creative warnings are non-blocking.

## Branch Architecture

Plot uses BranchService sparse overlays. Canon, Draft, Proposed, Deprecated,
Non-Canon, and Alternate are Canon statuses on records. Branch records resolve as
inherited, overridden, branch-created, or hidden. Overrides never mutate the
canonical record and do not clone the full Plot. Branch kinds support What If,
alternate Timeline, alternate ending, alternate universe, and draft; alternate
choice, romance, death, and conflict are represented by named branch records and
the same sparse mechanism.

## Fixture And Tests

`plot_phase_1_fixture.dart` creates a Series, Book, three Acts, three Sequences,
three Characters, a main plot and two subplots, Character/Relationship/World
arcs, mechanics records, World/Codex records, Timeline events including a
flashback, chapters, and scenes. All links use stable Universal Record IDs.

`plot_service_test.dart` covers the record catalogue, structural templates,
custom types, story structure, mechanics, knowledge states, cross-system links,
queries, shared search/inspection/audit/safe-delete/validation, sparse branches,
database reopen, archive restore, and project/book/branch isolation.

## Future UI

`PlotViewKind` and `PlotViewItem` prepare Plot Tree, Beat Board, Arc Lane,
Plotline Lane, Character Arc Lane, Timeline Overlay, Chapter Map, Scene Map, and
Dependency Graph views. Phase 1 deliberately does not implement polished boards,
drag-and-drop editing, graph rendering, AI generation or diagnosis, automatic
restructuring, sharing, marketplace, monetisation, or premium features.