# AuthorOS 2.0 Master Feature and Architecture Plan

> ## 🔒 This plan now operates inside the Architecture Lock
>
> As of **August 22, 2026**, the principles this plan describes are no longer
> proposals to be honoured where convenient. They are locked constraints, stated
> in the [**AuthorOS Architecture Lock**](architecture/authoros-architecture-lock.md)
> and governed by the precedence rule in
> [**ADR-0006**](architecture/ADR-0006-architectural-precedence.md):
>
> **When a new feature conflicts with an established AuthorOS architectural
> principle, the feature must adapt to the architecture — the architecture must
> not be weakened to accommodate the feature.**
>
> Read the lock before this plan. Where the two differ, the lock wins — including
> where this plan is merely silent. Section 22 below records what the lock adds.
>
> The current tree's compliance is measured in the
> [Architecture Compliance Audit](authoros-architecture-compliance-audit.md),
> and new feature work is paused until Steps 3–6 of the lock's sequence complete.

Status: Proposed for product and architecture approval  
Created: August 17, 2026  
Product: AuthorOS  
Positioning: The complete, AI-free creative operating system for authors

## 1. Purpose

AuthorOS 2.0 will evolve the existing local-first writing application into one connected author ecosystem. Writers will be able to draft books, plan stories, build reusable worlds, model characters and relationships, create maps and visual boards, verify continuity, format finished books, and track their writing journey without generative AI.

This plan prevents each studio from becoming an isolated feature. It defines the shared domain model, ownership boundaries, migration path, build order, and evidence required before a capability is considered complete.

## 2. Product promise

**Write. Plan. Build. Visualise. Format. Publish.**

AuthorOS gives writers sophisticated creative tools while leaving authorship with the writer.

Core principles:

1. **AI-free by design.** Generators use authored prompts, rules, weighted tables, and deterministic randomness rather than generative models.
2. **Local-first by default.** Creating, opening, editing, searching, linking, exporting, and recovering a project must work without an account or network connection.
3. **Everything can connect.** Manuscripts, scenes, people, places, events, maps, notes, research, and visual nodes share stable IDs and typed links.
4. **No lock-in.** Writers can export manuscripts and a complete, versioned project archive, including assets.
5. **Evidence over magic.** Continuity findings show the records, links, and rules that produced them.
6. **Progressive complexity.** A writer can draft a simple book without configuring a universe, timeline, map, or custom schema.
7. **Genre-flexible foundations.** Built-in templates help fantasy, romance, mystery, science fiction, and other genres, but custom record types prevent a fantasy-only data model.
8. **Private by default.** Community, telemetry, cloud backup, and sharing are separate opt-in capabilities.
9. **Backward-compatible evolution.** Existing Author Studio projects remain readable and migrate through tested, reversible schema steps.
10. **Accessibility and keyboard use are release requirements.** They are not deferred polish.

## 3. Scope boundaries

### AuthorOS application owns

- local creative projects and assets
- manuscript editing and organization
- story, world, character, timeline, map, and visual records
- the Connection Engine and continuity rules
- local search and indexes
- project archive import/export and backup health
- book formatting and publishing exports
- local writing statistics and author journey
- optional sync client behavior

### indiauthors.com platform owns

- marketing and documentation
- accounts and sessions
- commerce, orders, and subscriptions or licenses
- download entitlements and application releases
- support and administration
- optional community identity and aggregated community statistics
- optional cloud-sync authority exposed through versioned APIs

### Explicitly out of scope for the 2.0 foundation

- generative manuscript AI
- required cloud accounts
- real-time collaborative editing
- public social feeds
- a full raster/vector illustration suite
- replacing professional desktop-publishing software for every advanced layout case
- moving local project data into the website by default

## 4. Existing foundation to preserve

The current Flutter application already provides:

- onboarding and starter projects
- manuscript, chapter, and scene persistence
- scene relationships
- Story Codex entries
- visual planning
- timelines and chronology fields
- continuity checks and impact tracing
- PDF manuscript export
- backup health and recovery verification
- local-first behavior
- a versioned sync envelope with extension preservation
- automated model, store, and widget tests

These capabilities should be adapted behind the new core rather than discarded. The first architecture milestone is successful when an existing project can be represented by the new core with no visible loss of content or behavior.

## 5. Target system model

```text
AuthorOS Library
  |
  +-- Universe (optional shared canon)
  |     +-- Record definitions
  |     +-- Shared records and assets
  |     +-- Shared chronology
  |     +-- Series
  |           +-- Book / Project
  |                 +-- Manuscript
  |                 +-- Book-scoped records
  |                 +-- Views and studio settings
  |
  +-- Standalone Book / Project
        +-- Manuscript
        +-- Project-scoped records and assets
```

The model must support a standalone novel without forcing a series or universe. A project can later join a series or universe through a migration that preserves its IDs.

## 6. Canonical domain contracts

### 6.1 Scope

Every record has an explicit scope:

| Scope | Meaning | Example |
|---|---|---|
| library | Available across the local AuthorOS installation | author-defined generator table |
| universe | Shared canon across one or more series | a world, deity, calendar |
| series | Shared across books in a series | recurring protagonist, series arc |
| project | Belongs to one book/project | chapter-specific clue |
| manuscript | Structural writing content | chapter or scene |

Scope inheritance is read-only by default. Editing a shared character from a book edits the canonical shared record only after an explicit confirmation. Book-specific changes belong in scoped annotations or timeline state, not duplicated character records.

### 6.2 Core record

All connected objects implement a common envelope:

```text
Record
  id                 stable globally unique ID
  typeId             built-in or custom record type
  scope              library/universe/series/project/manuscript
  scopeId            owner of that scope
  title              human-readable name
  status             active/archived/deleted
  schemaVersion      record payload version
  createdAt
  updatedAt
  revision
  fields             typed field values
  tags
  extensionData      unknown-field preservation
```

IDs must not encode a title, order, or parent path. Renaming or moving a record must never break links.

### 6.3 Record type definition

Built-in and custom types share one schema mechanism:

```text
RecordTypeDefinition
  id
  name
  icon
  color
  baseType
  fields[]
  allowedLinkTypes[]
  templateVersion
```

Supported field primitives in the foundation:

- short text
- long text
- rich text
- number
- boolean
- date or fictional date
- single choice
- multiple choice
- record reference
- record-reference list
- asset reference
- URL
- checklist

Built-in types include character, location, faction, organization, region, item, lore, culture, religion, creature, technology, magic system, storyline, event, note, research item, chapter, and scene. Users can rename templates or create custom types such as Case, Relationship, or Recipe without a database migration.

### 6.4 Typed link

All cross-studio relationships use one canonical edge model:

```text
RecordLink
  id
  sourceId
  targetId
  typeId
  direction          directed/undirected
  label
  scopeId
  validFrom          optional story time or manuscript position
  validTo            optional story time or manuscript position
  metadata
  createdAt
  updatedAt
  revision
```

Examples:

- character `appearsIn` scene
- scene `occursAt` location
- event `involves` faction
- character `owns` item
- chapter `continues` storyline
- relationship `changesAt` chapter
- map marker `represents` location

Links refer only to IDs. Display names are resolved through the record repository. Deleting a target creates a visible broken-link state until the user relinks, restores, or confirms removal.

### 6.5 Manuscript structure

Manuscript content remains specialized because ordering, editing, and export have stronger requirements than general records:

```text
Manuscript
  +-- Part (optional)
        +-- Chapter
              +-- Scene
```

Parts, chapters, and scenes participate in the Connection Engine through stable IDs. Scene text is stored separately from graph indexes so large-document editing does not rewrite the full project graph.

### 6.6 Assets

```text
Asset
  id
  scopeId
  mediaType
  originalName
  relativePath
  byteLength
  checksum
  width/height optional
  createdAt
  metadata
```

Assets include portraits, map images, reference images, fonts permitted for embedding, and book ornaments. Project archives include assets and verify their checksums.

### 6.7 Views are not records

Boards, canvases, map layouts, filters, table columns, and panel positions are saved views over records and links. They do not own duplicate creative data.

```text
StudioView
  id
  studioType
  scopeId
  title
  layout
  filter
  selectedRecordIds
  presentationMetadata
```

This rule is essential: moving Kali on a relationship canvas changes the canvas layout, not the character record.

## 7. Connection Engine

The Connection Engine is an application service over records, typed links, manuscript nodes, and indexes.

Required capabilities:

- create, update, archive, restore, and remove links
- validate source, target, type, direction, and scope
- resolve incoming and outgoing links
- traverse links to a bounded depth
- list backlinks and mentions
- detect broken or ambiguous references
- expose change streams to studio views
- maintain indexes transactionally
- produce a portable graph representation
- preserve unknown fields from newer schema versions

The engine must not know Flutter widgets, Supabase, billing, or presentation layout.

### Link integrity rules

1. A link cannot point to an unknown ID unless imported into an explicit unresolved state.
2. Archived targets remain resolvable and visibly marked archived.
3. Deletion is soft until backup and reference policies complete.
4. Cross-scope links must obey inheritance rules.
5. Duplicate links are rejected unless the link type permits multiple time-bounded instances.
6. Link mutation and index updates commit atomically.

## 8. Storage architecture

### 8.1 Direction

SharedPreferences is acceptable for settings and small migration markers, but not for the AuthorOS 2.0 creative graph or manuscript corpus. The target is an embedded transactional database behind repositories, plus a managed asset directory.

The database technology must be selected through a short proof of concept before feature migration. It must support:

- Windows and Android first, with a credible macOS/iOS path
- transactions
- indexed queries and full-text search
- schema migrations
- deterministic backup/export
- test isolation
- maintained Flutter/Dart bindings
- no network requirement

Candidate evaluation should compare Drift/SQLite and Isar on these requirements. The architecture depends on repository interfaces, not a specific database package.

### 8.2 Repository boundaries

```text
LibraryRepository
UniverseRepository
ProjectRepository
ManuscriptRepository
RecordRepository
LinkRepository
AssetRepository
ViewRepository
WritingSessionRepository
MigrationRepository
```

Studios call application services; application services call repositories. Widgets never read SharedPreferences, database tables, or cloud APIs directly.

### 8.3 Transactions

The following operations must be atomic:

- create a record and its initial links
- move a project into a series/universe
- archive or restore a record and update indexes
- reorder manuscript nodes
- import an archive
- apply a schema migration
- apply a remote sync change set

### 8.4 Search indexes

Local indexes cover:

- record title and aliases
- typed field content
- manuscript headings and optionally body text
- tags
- incoming/outgoing links
- timeline positions
- asset metadata

Search results identify the scope and owning project and open the correct studio view.

## 9. Project archive and migration strategy

### 9.1 Portable archive

The canonical portable format is a ZIP-based archive with a documented extension, for example `.authoros`:

```text
manifest.json
data/
  library.json or database export
  records.json
  links.json
  manuscripts/
assets/
checksums.json
```

The manifest includes archive format version, application version, created time, project/universe IDs, included scopes, and checksum algorithm.

### 9.2 Migration rules

- Never mutate the only copy of a legacy project.
- Create a verified pre-migration backup first.
- Migrations are versioned, ordered, repeatable, and covered by fixtures.
- Unknown fields survive round trips.
- Migration failure leaves the original project usable.
- Import validates schema, IDs, references, asset paths, sizes, and checksums before committing.
- Every major release keeps at least one prior-version import fixture.

### 9.3 Current-model adapters

Initial adapters map:

- `StarterProject` to project metadata
- `ManuscriptProjectSummary` to manuscript/chapter/scene records
- `SceneRelationship` to canonical `RecordLink`
- `StoryCodexEntry` to `Record`
- `TimelineEra`, `TimelineSequence`, and `TimelineEvent` to timeline records and links
- planning scenes to saved views over canonical scenes
- current sync payloads to versioned change sets

The old stores remain readable until migration acceptance tests pass for production fixtures. New writes switch one bounded area at a time; a permanent dual-write system is prohibited.

## 10. Sync architecture

Sync remains optional and follows local commits. The local database is never replaced by a remote cache.

### Change model

- each mutable entity has a revision and update timestamp
- local commits append durable change operations
- sync uploads and downloads batches through a versioned API
- tombstones represent deletions
- unknown remote fields are preserved
- conflicts are surfaced at record/field level where practical
- manuscript text conflicts preserve both versions and require user resolution

The current `ProjectSyncEnvelope` is a useful compatibility boundary but is too coarse for an interconnected universe. The 2.0 protocol should sync entity change sets, not rewrite an entire project payload for every edit.

Cloud sync cannot enter general availability until authentication, row-level authorization, offline queueing, retry, conflict handling, account deletion, and restore-from-cloud have integration evidence.

## 11. Studio architecture

Every studio uses the same shell conventions:

- scope switcher
- searchable navigator
- primary workspace
- contextual inspector
- backlinks/connections panel
- undo/redo where mutation occurs
- empty, loading, error, archived, and broken-link states
- keyboard navigation and accessible semantics

### 11.1 AuthorOS World / Library

Purpose: command center across projects and series.

First release capabilities:

- recent projects and continue-writing action
- local writing streak, goal, and word-count summaries
- series and universe navigation
- backup-health status
- search across allowed local scopes

Community statistics remain a separate opt-in platform phase.

### 11.2 Manuscript Studio

- parts, chapters, and scenes
- focused editor
- status, POV, location, time, and storyline metadata through record links
- comments, notes, snapshots, and word counts
- backlinks to every connected record
- reliable autosave, undo, recovery, and export

### 11.3 Story Studio

- plotlines and story arcs
- beat sheets and templates
- scene cards and ordering
- structure overlays
- project and series arcs
- deterministic prompts and conflict generators

### 11.4 World Studio

- built-in and custom record types
- schema-driven forms
- folders, tags, tables, and galleries
- backlinks and mentions
- templates by genre
- import/export of selected records

### 11.5 M26 - Character Studio: Deep Character System

> **DO NOT SIMPLIFY CHARACTER STUDIO.** Character Studio is one of AuthorOS's deepest systems. Do not reduce it to Name, Age, Description, Appearance, and Notes; replace structured information with generic text fields; remove existing functionality to make the first UI pass easier; or create character data outside Universal Records and the Connection Engine.

The normative scope, current-state audit, implementation sequence, service boundary, migration requirements, and completion matrix are defined in [M26 - Character Studio: Deep Character System](m26-character-studio-deep-character-system.md).

Required scope:

**Identity -> Portrait -> Appearance -> Personality -> Psychology -> History -> Goals -> Motivation -> Fears -> Secrets -> Character Arc -> Voice -> Dialogue -> Relationships -> Scenes -> Chapters -> Timeline -> Locations -> Factions -> Items -> Plot Threads -> Notes -> Statistics -> Templates -> Questionnaires -> Generators -> Connections -> Series -> Branches -> Custom Fields.**

Character Studio requirements:

- one canonical character `AuthorRecord`, never a parallel character database
- schema-driven structured sections plus author-defined typed custom fields
- primary portrait and ordered reference images backed by shared assets
- configurable multi-stage character arcs linked to scenes, chapters, timeline events, and plot threads
- one shared, history-aware relationship visible from both characters
- live derived appearances, backlinks, chronology, graph views, and structural statistics
- series- and universe-scoped characters with book-specific annotations and development
- version, What-If branch, Alternate Universe, and canon-state isolation
- Standard, Protagonist, Antagonist, Supporting, Romance, Villain, and author-defined templates
- mapped questionnaires and deterministic, versioned, seed-reproducible generators from the shared Generator Framework
- a dedicated Character service over records, links, assets, manuscript nodes, and search
- impact-aware archive and deletion workflows that never cascade-delete connected creative records
- reversible migration of starter sheets, Story Codex characters, name-based relationships, scene links, timeline participation, continuity evidence, and existing archive/search behavior

The dashboard must expose the full system through manageable progressive disclosure without dropping any domain from the data model. Character Studio is a focused view over character records and links, not a second character database.

### 11.6 Timeline Studio

- eras, sequences, events, and fictional calendars
- links to characters, locations, scenes, factions, and lore
- filters by plotline, POV, character, place, and status
- continuity evidence for overlap, travel, order, and date-range rules
- series/universe chronology with project overlays

### 11.7 Relationship Studio

- family trees, houses, alliances, rivalries, romances, and custom relationships
- directed and undirected links
- relationship metadata
- validity by story time or manuscript position
- saved canvas layouts

### 11.8 Visual Studio

- infinite or bounded boards
- live record cards
- notes, connectors, groups, images, and references
- saved filters and layouts
- double-click navigation to owning records

### 11.9 Map Studio

Map Studio ships in two levels:

1. **Map annotation:** import an image, add layers, regions, routes, scale, and linked markers.
2. **Map creation:** terrain brushes, symbols, coastlines, rivers, borders, labels, and export.

Annotation ships first because it validates the data model and linking workflow without committing to a full cartography engine. Map geometry remains a view/asset layer linked to canonical location and event records.

### 11.10 Book Studio

- trim sizes and margins
- typography and paragraph styles
- front and back matter
- chapter openers, scene breaks, drop caps, headers, footers, and page numbers
- reusable style templates
- print preview and preflight
- PDF, print-ready PDF, EPUB, DOCX, and TXT export

Book Studio consumes a manuscript snapshot and style specification. It does not mutate the source manuscript while laying out a book.

### 11.11 Research and Notes

- source metadata and URLs
- excerpts and personal notes
- file attachments
- links to scenes and records
- citation/export support where applicable

### 11.12 Author Journey

- writing sessions
- daily/weekly/monthly goals
- heat map and streaks
- manuscript milestones
- private achievements and optional levels
- local-first statistics

No competitive or public ranking is enabled by default.

## 12. Continuity Engine 2.0

Continuity remains a key differentiator and must stay deterministic.

Rule families:

- invalid or reversed date ranges
- impossible character presence overlaps
- insufficient travel time between linked locations
- missing POV character presence
- sequence and dependency violations
- age/date inconsistencies
- relationship validity conflicts
- item ownership or location conflicts
- unresolved names and broken links
- series-canon conflicts between book-scoped and shared records

Every finding includes severity, rule ID, affected records, human-readable explanation, evidence, and suggested manual actions. Rules never silently rewrite creative content.

## 13. Delivery strategy

Two workstreams run with separate release criteria:

### Track A: ship and stabilize the current product

- complete Android manual QA
- validate live Supabase behavior or remove cloud promises from release scope
- finish privacy, data-safety, store assets, signing, and testing-track work
- release a stable 1.x baseline
- fix data-loss and reliability issues before 2.0 expansion

### Track B: build the 2.0 foundation behind controlled migrations

- approve domain contracts and ADRs
- prove the embedded database and archive format
- implement repositories, records, links, and adapters
- migrate one vertical slice before adding studios

Track B must not destabilize the releasable 1.x branch. Use short-lived feature branches and feature flags, or a dedicated 2.0 integration branch if simultaneous release work makes main unsafe.

## 14. Milestones and gates

### M0: Product and architecture lock

Deliverables:

- approve this feature boundary and terminology
- write ADRs for domain model, database, archive format, and sync protocol
- inventory every persisted 1.x key and model
- create representative legacy project fixtures
- define performance and supported-platform targets
- define the AI-free product policy

Exit gate:

- architecture review approves the contracts
- no studio has an unowned data type
- open decisions have owners and dates

### M1: AuthorOS Core

Deliverables:

- embedded database proof of concept and decision
- repository interfaces and transactional unit of work
- IDs, scopes, record types, records, links, assets, and saved views
- project archive export/import with checksums
- local search index
- migration runner and rollback behavior

Vertical-slice proof:

Create a character, connect it to a scene and timeline event, display backlinks in all three contexts, archive and restore it, export the project, delete local data, import the archive, and recover the same IDs and links.

Exit gate:

- focused tests pass on Windows and Android
- archive round trip is byte-content equivalent for creative data and assets
- forced migration failure leaves the legacy project usable
- graph queries meet agreed performance targets

### M2: Manuscript and World migration

Deliverables:

- migrate current manuscript hierarchy
- migrate Story Codex into schema-driven records
- replace name-based relationships with ID links
- integrated backlinks and record picker in Manuscript Studio
- custom record types and fields
- version snapshots and recovery UI

Exit gate:

- production-like legacy fixtures migrate without data loss
- existing manuscript/export tests remain green
- users can opt out of migration until the supported deadline

### M3: Story, Character, and Timeline

Deliverables:

- Story Studio over canonical scenes and storylines
- M26 Character Studio: Deep Character System, implemented to the dedicated directive and audit map
- deterministic generator framework with saved seeds
- timeline migration and fictional calendar model
- Continuity Engine 2.0 evidence model
- project-level relationship view

Exit gate:

- no duplicate scene, character, or event stores remain
- all structured M26 character domains persist and round-trip without being collapsed into generic text fields
- character links are ID-based, bidirectional where applicable, series-aware, branch-isolated, and deletion-safe
- existing starter, Codex, scene, timeline, continuity, search, archive, and migration behavior is preserved
- continuity rules link directly to source evidence
- generators reproduce identical output from the same version and seed

### M4: Series and Universe

Deliverables:

- universe and series creation
- promote project records to shared scope
- shared canon with project annotations
- series chronology and character appearances
- cross-book search and continuity
- portable series/universe archive

Exit gate:

- moving a standalone book into and out of a series preserves content and IDs
- conflicts between shared and book-scoped facts are visible and recoverable
- access and export boundaries are tested at every scope

### M5: Visual and Relationship Studios

Deliverables:

- reusable canvas framework
- live record cards and connectors
- family tree and general relationship modes
- time-bounded relationship changes
- visual board layouts, groups, and references

Exit gate:

- canvas layouts never duplicate or own creative records
- large-graph pan, zoom, selection, and save meet performance targets
- keyboard and screen-reader alternatives exist for graph operations

### M6: Map Studio, annotation release

Deliverables:

- map import and asset management
- markers linked to records/events
- layers, regions, routes, scale, and measurement
- map export
- timeline/location integration

Exit gate:

- archive round trip retains maps, geometry, links, and assets
- large images do not cause data loss or unacceptable memory use
- map data has a documented forward path to creation tools

### M7: Book Studio

Deliverables:

- style and layout model
- front/back matter editor
- print trim and typography controls
- PDF and print-ready PDF
- EPUB, DOCX, and TXT
- preflight checks and reusable templates

Exit gate:

- golden fixtures validate representative books
- EPUB passes a standard validator
- PDF font embedding, margins, page order, and blank-page rules pass preflight
- exports are reproducible from a frozen manuscript snapshot

### M8: Author Journey and optional World community

Deliverables:

- local writing sessions, heat maps, streaks, goals, and milestones
- privacy controls for every shared statistic
- opt-in aggregated community metrics through the platform API
- anonymous/friends/community visibility modes only if identity and moderation are ready

Exit gate:

- all tracking works locally without an account
- no manuscript text, title, genre, or private project metadata is included in community telemetry
- consent, deletion, abuse prevention, and aggregation thresholds are validated

### M9: Optional cloud sync general availability

Deliverables:

- entity-level change protocol
- encrypted transport and authorized storage
- offline queue, retries, conflict center, tombstones, and recovery
- account export and deletion
- operational monitoring and support runbooks

Exit gate:

- multi-device destructive conflict tests pass
- offline edits converge or surface a resolvable conflict without silent loss
- restore from cloud and full account deletion are independently verified

## 15. Recommended first implementation slice

Do not start with a new studio. Build one thin connection slice through existing features:

1. Define `AuthorOsId`, `RecordScope`, `RecordTypeDefinition`, `AuthorRecord`, and `RecordLink`.
2. Select the embedded database through a measured proof of concept.
3. Implement record and link repositories with transactions.
4. Adapt one existing Story Codex character into an `AuthorRecord`.
5. Adapt one existing manuscript scene into a linkable node.
6. Link the character to the scene.
7. Show the connection and backlink in existing Codex and Manuscript views.
8. Export and re-import both through the new archive.
9. Run migration, round-trip, broken-link, and recovery tests.

This slice tests the core hypothesis cheaply: one canonical graph can serve multiple existing studios without losing local-first reliability.

## 16. Quality strategy

### Automated tests

- domain invariants and ID stability
- schema serialization and unknown-field preservation
- repository transactions and rollback
- migrations from real legacy fixtures
- archive validation and malicious-path rejection
- graph traversal and broken-link handling
- continuity rule fixtures
- export golden files
- sync conflict simulations
- widget workflows for every studio shell state

### Performance targets to lock in M0

Targets must cover at least:

- cold-open time for a large project
- editor input latency and autosave duration
- search latency
- graph query latency
- archive/export duration
- memory use for long manuscripts, large canvases, and maps
- database size and backup size

Representative scale fixture:

- 5-book series
- 750,000 manuscript words
- 2,500 records
- 15,000 links
- 5,000 timeline events
- 1,000 assets or map markers

### Manual release checks

- first run and migration
- offline create/edit/restart
- crash during save and migration
- backup and restore on another device
- keyboard-only operation
- screen reader labels and focus order
- Windows and Android layout behavior
- print and EPUB inspection

## 17. Security and privacy baseline

- local content is not uploaded without a separate opt-in action
- secrets and license tokens use platform-secure storage, not project files
- archive imports reject path traversal, oversized entries, duplicate IDs, and invalid checksums
- external URLs and attachments are treated as untrusted
- optional telemetry has a documented event allowlist
- crash reports exclude manuscript and record field content by default
- public sharing uses revocable access, expiry, and explicit visibility language
- community aggregation enforces minimum cohort thresholds
- project deletion explains local backups and synced copies separately

## 18. Product and engineering decisions to lock

| Decision | Recommended default | Must be decided by |
|---|---|---|
| Public product name | AuthorOS | M0 |
| Primary launch platforms | Windows desktop and Android; validate macOS/iOS later | M0 |
| Embedded database | Select after Drift/SQLite vs Isar proof of concept | M1 start |
| Portable archive extension | `.authoros` ZIP container | M1 start |
| Rich-text source format | Structured document model with explicit export adapters | M1 start |
| Shared-record override model | Canonical shared record plus scoped annotations | M2 |
| Fictional calendar flexibility | User-defined eras, units, leap rules, and display formats | M3 |
| Map creation engine | Defer selection until annotation usage is validated | M6 |
| Book layout engine | Evaluate HTML/CSS paged media vs native PDF composition | M7 |
| AI policy | No generative AI in core product; future integrations require a new explicit decision | M0 |
| Community model | Private local stats first; all sharing opt-in | M8 |

## 19. Work management

- Keep the active implementation limit at three issues.
- Every milestone begins with an ADR or contract issue and ends with executable evidence.
- Feature issues name the owning record, link, view, and repository contracts.
- Cross-studio work cannot be marked done from a static mockup.
- "Done" requires migration behavior, empty/error states, accessibility, tests, and documentation.
- Unvalidated future ideas stay in the product backlog rather than entering the core schema prematurely.

## 20. Immediate next actions

1. **Approved:** use this plan as the 2.0 product boundary.
2. **In progress:** complete the 1.x release blockers without expanding its feature scope.
3. **Complete:** ADR-0003 proposes the connected domain model and invariants.
4. **Complete:** all current SharedPreferences namespaces and persisted JSON shapes are inventoried.
5. **Complete:** anonymized simple, large, malformed, partial, and future-field fixtures have a passing contract and real-store recovery tests.
6. **Complete for desktop spike:** Drift/SQLite and Isar Community were benchmarked with equivalent record/link workloads; packaged Windows and Android validation remains an M1 gate.
7. **Complete:** ADR-0004 selects Drift/SQLite, subject to the packaged-platform integration gate.
8. **Complete:** ADR-0005 and its JSON Schema specify the `.authoros` archive, integrity rules, migration provenance, and atomic import behavior.
9. **Core slice complete:** storage-agnostic records, manuscript-node references, typed links, backlinks, JSON round trips, transactional rollback, and a legacy character-to-scene adapter are implemented behind the disabled-by-default `AUTHOROS_CONNECTED_DOMAIN` flag. Drift-backed repositories and UI exposure await the packaged-platform gate.
10. **In progress:** Drift-backed records, manuscript nodes, links, FTS5, foreign keys, version 1-to-2 migration, transaction rollback, and forced-termination WAL recovery are implemented and tested. Packaged Windows debug/release open-query-close-reopen probes pass. The normalized `.authoros` connected-graph archive now has deterministic fingerprints, SHA-256 validation, path protections, and validation-before-commit tests. Android packaging/runtime remains blocked until an Android SDK and device/emulator are available; managed assets, structured content entries, migration reports, and cross-platform archive exchange remain before M2 scheduling.

## 21. Definition of 2.0 success

AuthorOS 2.0 succeeds when an author can:

- open an existing project without losing data
- write offline with dependable autosave and recovery
- connect a scene to any relevant story record
- reuse canon across a series without recreating it
- inspect why a continuity warning exists
- navigate naturally among manuscript, character, timeline, map, and relationship views
- create custom structures without waiting for a software update
- export a complete portable archive and restore it elsewhere
- format and export a publication-ready book
- track progress privately
- understand precisely when any data leaves the device

The architecture succeeds when those workflows use one canonical set of records and links rather than studio-specific copies.

---

## 22. What the Architecture Lock adds to this plan

This plan was written as a design. The [Architecture Lock](architecture/authoros-architecture-lock.md)
converts it into a set of constraints and adds six things this plan did not
cover, because the product had not yet grown far enough to need them.

### 22.1 Systems are a layer, and they live inside domains

This plan lists magic systems, religions, cultures and technologies as built-in
record types. The lock adds the layer above them: a **System** is a named,
project-activatable capability — Magic, Languages, Religion, Economy,
Government, Biology, Technology, Bestiary and whatever follows — that
contributes record types, fields, relationship types, templates and views to the
domain it belongs to.

A System contributes no store, no identity space, no relationship model, and no
permanent navigation destination. Twenty Systems must cost roughly what two do.

### 22.2 Extensions are configuration, and deactivation preserves data

Section 6 gives every record a scope. The lock adds a second axis: whether the
project has that capability **active**.

`inactive ≠ deleted` is a persistence rule. Deactivating a system hides its
interface and its specialised views; it never removes its records, its
relationships, or its fields. Reactivating returns the author to exactly what
they had. A feature that cannot honour this is not ready to ship.

`ProjectRows.payloadJson` is the eventual home for that configuration and is
currently opaque — Step 5 of the sequence.

### 22.3 Field configuration is a foundation, built once

Section 6.3 lists field primitives. The lock adds the **configuration surface**
around each field: enabled, required, input type, options, custom values,
default, quick create, main view, searchable, track changes, conditional
availability, relationships and calculated values.

`RecordFieldDefinition` today carries five of the thirteen. The rest are built
once, in Step 4, before more specialised entry surfaces exist — not grown
independently by each studio, and never smuggled through `extensionData`.

### 22.4 Presets configure; they never restrict

Principle 7 of this plan promises genre-flexible foundations. The lock states the
prohibition that makes it real: a genre preset may **suggest** that a fantasy
project enable Magic, Bestiary, Religion and Languages, and may never say
*"because this is fantasy, Economics cannot be enabled."*

Presets are configuration helpers. They are not capability gates, and no code
path may treat them as one.

### 22.5 Generation produces canonical entities

Section 2's first principle says generators are deterministic rather than
generative. The lock adds where their output goes:

```text
Procedural generator → canonical entities → canonical relationships
                     → universal fields → universal templates
                     → maps / codex / timeline / story
```

A generated city is a city record; its buildings are building records; its
geometry is map placement on those records. **The map is a view of the world, not
the world itself.** Generation is seeded, reproducible, provenance-stamped,
sandboxed before canon, adopted only on author approval, and must respect author
modifications on regeneration.

This governs Map Studio Phase 7, which does not begin until Step 6 re-audits its
design against it.

### 22.6 The feature gate

Every proposed feature answers ten questions in its implementation map before
implementation starts: does it use canonical data; does it duplicate data; can it
use universal fields; can it use universal templates; does it create a
relationship type unnecessarily; does it need a new navigation destination; does
it work through deterministic intelligence; does deactivation preserve data; does
export remain possible; does it add unnecessary complexity.

A feature that fails any of them is redesigned before code is written.

### 22.7 What the lock does not change

Everything in sections 1–21 stands. The lock adds constraints; it removes no
scope, reorders no milestone, and — per ADR-0006 — authorises no rewrite of
working code that already complies. The compliance audit found one conflict, four
debts and five extensions across 106,000 lines of hand-written Dart. The
correction pass is a short list, not a remediation programme.
