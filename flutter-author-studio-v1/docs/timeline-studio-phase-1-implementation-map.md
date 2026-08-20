# Timeline Studio Phase 1 Implementation Map

## Temporal architecture

Timeline Studio uses Universal Records as its only persistence model. `TimelineService` is a domain facade over `RecordService`, `ConnectionEngine`, `BranchService`, `UniversalSearchService`, `VersionAuditService`, `UniversalRecordInspector`, and `SafeDeleteService`. It does not create a Timeline database, relationship store, search index, history store, inspector, or branch implementation.

The existing `timeline.dart` model remains a legacy UI adapter backed by `SharedPreferences`. Phase 1 adds the canonical Universal Record domain without replacing the current graphical view. A later adapter can migrate or project legacy UI state through `TimelineService`.

## Record catalogue

`TimelineRecordTypes` registers a `timeline-record` base and data-driven children for Timeline, Era, Age, Historical Period, Event, Event Group, Date, Date Range, Milestone, Turning Point, Historical Record, War, Battle, Disaster, Political Event, Birth, Death, Discovery, Invention, Founding, Destruction, Migration, Journey, Relationship Event, Character Event, World Event, and Custom Event.

Projects use only the types they need. Project-scoped custom types may extend `timeline-record` through `TimelineService.registerCustomType`.

## Event model

All event subtypes inherit universal identity fields plus:

- event type, summary, description, notes, tags
- structured start, end, duration, and calendar representations
- precision, status, importance, and scope
- relative date metadata
- narrative-time metadata distinct from world time
- Universal Record canon, branch, series, and book ownership

Structured temporal objects are stored as Universal Record table rows. This keeps values data-driven and compatible with shared field validation.

## Date model

`TimelineDate` represents calendar ID, era, signed year, month, day, time, optional time zone, precision, approximation, and display format. It supports exact, approximate, range, relative, and unknown precision without assuming Gregorian rules.

Unknown and partial dates omit unsupported components. Relative dates use a stable anchor record ID, relation, signed offset, unit, and author-facing description. The service never invents an exact date from a relative statement.

## Calendar architecture

`TimelineCalendar` defines months and lengths, week labels, year length, era names, epoch metadata, formatting, year-zero behavior, year direction, and deterministic conversion metadata. Calendar definitions are project-level Universal Records of type `calendar-definition`.

Ordinal conversion is deterministic and supports year zero, calendars without year zero, signed years, and backwards-counting years. It is deliberately not an astronomical simulation.

## Multiple calendars

An event has one canonical start/end representation and may carry any number of validated alternate `dateRepresentations`. Every representation references a calendar by stable ID. The event is not duplicated.

## Temporal relationships

Timeline uses shared `RecordLink` rows. Phase 1 provides before, after, during, contains, overlaps, concurrent with, caused by, leads to, follows, precedes, repeats, occurs at, associated with, and cross-system impact/reference verbs.

Two compatibility corrections were required in the shared registry:

- `contains` and `leadsTo` now permit non-spatial records.
- existing `involves` and `occursAt` definitions recognize every data-driven Timeline subtype, because connection validation currently matches exact type IDs rather than record-type inheritance.

No Timeline-specific relationship persistence was introduced.

## Hierarchy and groups

Hierarchy is expressed only with connections, typically `contains` or `partOf`. Timeline, Era, Period, Event Group, Event, Book, Chapter, War, and Battle can therefore be composed in any project-defined structure. Event groups are ordinary shared records and do not own copied events.

## Character integration

Characters remain Character Studio records. Timeline records connect to stable Character IDs using shared verbs such as `involves`, `participatedIn`, `witnessed`, `changedDuring`, and `presentAt`. Birth and death are event records rather than duplicated Character fields.

`ageAt` derives age from canonical birth/event dates in the same calendar and does not persist redundant age values.

## World integration

Locations, cities, regions, nations, buildings, factions, governments, and other World records remain World Studio records. Timeline uses `occursAt`, `tookPlaceIn`, `changed`, `founded`, `destroyed`, and `changedBordersOf` links.

## Codex integration

Lore, traditions, religions, political systems, magic, myths, cultures, and historical knowledge remain Story Codex records. Timeline links them with `established`, `created`, `introduced`, `caused`, and `relatedTo`.

## Faction integration

Governments, houses, organisations, guilds, clans, military groups, and rebels use existing shared records. Events and factions connect with `involves`, `participatedIn`, `founded`, `lost`, and `signed`.

## Manuscript and narrative time

Series, Book, Chapter, and Scene remain shared manuscript records. Timeline links use `revealedIn`, `depictedIn`, `occursDuring`, `covers`, and `relatedTo`.

World time is stored in canonical start/end fields. Narrative time is a separate structured row that can identify flashback, flash-forward, memory, historical account, prophecy, vision, or nonlinear reveal metadata without changing the event's canonical date.

## Canon and branches

Canonical Timeline records use normal Universal Record canon states. Alternate history, what-if, alternate ending, alternate universe, deleted timeline, and draft timeline variants use `BranchService` overlays. Overrides are sparse and never mutate canonical records. Branch-created events use branch scope and non-canon status.

## Search

`searchTimeline` delegates to `UniversalSearchService` and filters results through record-type inheritance. Names, descriptions, aliases, types, structured date text, tags, canon/branch metadata, and connected records use the shared index and references. Every `timeline-*` subtype routes to Timeline Studio in universal search navigation.

## Inspector and audit

`inspectTimelineRecord` delegates to `UniversalRecordInspector`, exposing identity, dates and fields, connections, references, version history, template compatibility, scope, canon, branch, validation, and safe-delete dependencies.

Every create, update, lifecycle mutation, connection, and branch overlay uses `VersionAuditService` through the shared services. There is no Timeline history implementation.

## Safe delete

`analyzeDelete` delegates to `SafeDeleteService`. Incoming/outgoing links, manuscript references, branch overlays, versions, and audit entries are reported across Character, World, Faction, Codex, Manuscript, future Plot, and other Timeline records. Phase 1 performs no physical deletion.

## Validation

Shared `RecordValidation` enforces schema, ownership, template, and field constraints. Timeline validation adds:

- missing or invalid calendars
- invalid month/day/year-zero values
- end before start
- broken relative anchors
- alternate calendar representation validation
- project isolation
- circular before/precedes/caused-by dependency detection

ConnectionEngine and BranchService continue to reject broken endpoints, cross-project links, invalid connection metadata, and invalid branch ownership.

## Query engine

`TimelineQueryService` provides project-scoped queries for:

- events between dates
- events involving Character, Location, or Faction
- events in Book or Chapter
- events before, after, or overlapping another event
- events in Branch
- events by canon state, tag, or exact type
- optional series/book/branch/canon/tag/type filtering

Queries read only the current project or requested branch. Exact date comparisons use calendar ordinals and never infer missing dates.

## Future UI models

Phase 1 includes view models for timeline lanes, event cards, period headers, date markers, and relationship markers. Lane `kind` supports Character, Location, Faction, Plot, and Branch lanes without creating lane records.

The interactive Timeline UI, drag and drop, graphical calendar designer, Gantt views, AI generation, automated pacing, 3D timelines, community features, marketplace, and premium features remain out of scope.

## Fixture and tests

`TimelineDomainFixture` contains stable IDs for one project context, one series, one book, a main timeline, multiple eras and events, characters, locations, a faction, Codex records, chapters, scenes, a flashback, one branch, and a branch-created alternate event.

Focused tests cover:

- catalogue inheritance and legacy adapter regression
- event create/update/read and project persistence
- custom calendars, year-zero rules, backwards years, ranges, and multiple calendars
- relative dates and calculated age
- hierarchy and event groups through shared connections
- Character, World, Codex, Faction, and Manuscript integration
- universal search, inspector, version/audit, branch overlays, and safe delete
- query filters and temporal ordering
- archive export/import
- project, series, book, and branch isolation
- invalid ranges and circular temporal dependencies

## Remaining Timeline work

Phase 2 may add a UI adapter over this service, legacy `TimelineStore` migration, interactive multi-lane rendering, calendar management screens, richer relation editing, and database-native range indexes if project-scale profiling demonstrates a need. Plot Studio Phase 1 is intentionally not started by this implementation.
