# Story Codex Implementation Map

Status: Phase 1 deep Codex domain foundation implemented  
Audited: August 20, 2026  
Scope: `flutter-author-studio-v1` and the AuthorOS boundary with `indiauthors-platform`

## Phase 1 implementation status

The deep Codex domain is now implemented over Universal Records. Built-in and
project-scoped templates, inherited field definitions, Codex lifecycle APIs,
shared connection types, Universal Search, Inspector, Version/Audit, sparse
branches, validation, and Safe Delete are composed by `StoryCodexService`.

The detailed current map, fixture coverage, limitations, and future UI boundary
are recorded in `docs/story-codex-phase-1-implementation-map.md`.

Cross-book entities, entity recognition over manuscript prose, entity
suggestions, canon conflict detection, the universal entity profile, and the
usage explorer are recorded in
`docs/codex-universal-knowledge-implementation-map.md`. That work builds on this
same shared domain layer and adds no table, no second search index, and no
relaxation of project isolation.

The historical audit and batch plan below remain as provenance. Statements in
the original gap analysis describe the August 18 checkpoint and are superseded
where the Phase 1 map records an implemented capability.

## Purpose

This map is the required architectural checkpoint before Story Codex implementation. It identifies the existing systems that must be preserved, the canonical integration points, the legacy data that must be migrated, and the validation gate for each implementation batch.

Story Codex will be a view and knowledge system over AuthorOS records. It will not own a second character, location, timeline, plot, map, relationship, or manuscript database.

## Audit coverage

The audit searched application source, tests, architecture documents, persistence inventories, and platform contracts for:

- codex, lore, world, notes, research, encyclopedia, glossary, and knowledge
- templates, records, Universal Records, links, and connections
- storage, migrations, APIs, services, forms, dialogs, editors, navigation, and search
- manuscript, character, timeline, plot, map, visual, series, branching, history, health, inspector, expansion, generator, import, export, and portability integration

Generated build output and dependency directories were excluded as implementation sources.

## Existing system map

| Area | Current owner | Persistence | Current state | Codex direction |
|---|---|---|---|---|
| Universal creative records | `AuthorRecord` in `lib/core/connected_domain.dart` | Drift `AuthorRecordRows` | Implemented with stable IDs, scope, fields, tags, revision, status, and unknown-field preservation | Canonical record envelope for every Codex entry |
| Connections | `RecordLink` and connected-domain repositories | Drift `RecordLinkRows` | Implemented with source/target foreign keys, typed IDs, bidirectional backlink query, and transactional writes | The only Codex relationship store |
| Manuscript graph identity | `ManuscriptNodeReference` | Drift `ManuscriptNodeRows` | Implemented for linkable chapter/scene identity; manuscript bodies remain in the manuscript subsystem | Link Codex records to nodes by stable ID without copying text |
| Connected persistence | `DriftConnectedDomainRepository` | SQLite via Drift | Implemented: record lookup, type/scope query, backlinks, FTS, snapshots, replacement, and connected-slice transactions | Extend repositories rather than bypassing them |
| Portable graph archive | `AuthorOsArchiveService` | Versioned ZIP with NDJSON, manifest, and SHA-256 checksums | Implemented for records, manuscript nodes, and links | Extend archive versions when new canonical metadata is introduced |
| Legacy Story Codex | `StoryCodexEntry`, `StoryCodexStore`, `StoryCodexView` in `lib/release_destinations.dart` | Project-scoped SharedPreferences JSON | Working five-type CRUD UI with aliases, tags, name-based relationships, mention IDs, search, archive, and delete | Preserve during migration; retire as authority after verified conversion |
| Character Studio | `CharacterStudioRecord` and `CharacterStudioStore` | Canonical `AuthorRecord` plus `RecordLink` in Drift | Already writes `typeId=character`; deep structured fields and custom values exist | Codex character views must read these same records |
| Timeline Studio | Timeline models and `TimelineStore` | Project-scoped SharedPreferences JSON | Structured eras, sequences, and events, but character/location links are names | Migrate events and references into canonical records/links incrementally |
| Manuscript Studio | `ManuscriptStore` and manuscript models | Project-scoped SharedPreferences JSON | Structured chapters/scenes and scene relationships | Keep specialized text/order storage; project stable node IDs into Connection Engine |
| Visual planning | `VisualPlanningStore` | Project-scoped SharedPreferences JSON | Owns a legacy scene-shaped planning representation | Convert to saved views over manuscript nodes; preserve unmatched cards as records |
| Research panel | `ProjectResearchStore` in `lib/main.dart` | Project-scoped SharedPreferences JSON | Separate research/notes/timeline references | Migrate to research/reference/author-note records and links |
| Generic Ideas and Research studios | `StudioRecordStore` and `RecordStudioView` | Collection-scoped SharedPreferences JSON | Unscoped generic records | Classify and migrate without losing unknown collections |
| Continuity and impact analysis | `continuity.dart`, `impact_trace.dart` | Derived from current feature models | Deterministic, rules-based checks already exist | Add Codex structural rules using canonical IDs and evidence |
| Navigation | `StudioSection.world` in `lib/main.dart` | UI state | Opens legacy `StoryCodexView`; Character Studio has a separate focused view | Replace the world route only after connected Codex reads are verified |
| Platform | `indiauthors-platform` | Platform-owned commerce/account stores | Intentionally has no creative-record or Codex runtime | Keep AuthorOS local-first; optional sync must cross a versioned contract |

No encyclopedia subsystem or separate Story Codex API/database exists. The current Codex is real but remains a legacy SharedPreferences feature, not yet a view over the connected domain.

## Canonical ownership rules

1. `AuthorRecord` owns one creative entity and its structured field values.
2. `RecordLink` owns every cross-record or record-to-manuscript connection.
3. Manuscript text, chapter order, and scene order remain specialized manuscript data.
4. Template/type definitions describe record structure; they do not copy record values.
5. Categories, folders, collections, smart collections, graph layouts, table columns, and pins are views or organisational metadata that reference record IDs.
6. Character Studio, future World Studio, and Story Codex are different interfaces over the same canonical records.
7. Archived and non-canon records remain resolvable. Destructive removal must expose affected links and never cascade into manuscript or connected records.
8. The website/platform is not the implicit owner of local creative data.

## Existing invariants to preserve

- IDs are stable, non-empty, and independent of titles.
- Records have exactly one owning scope and scope ID.
- Links use stable source and target IDs and are discoverable from either endpoint.
- Record, link, entity-index, and search-index writes are transactional where they form one operation.
- Foreign keys reject dangling persisted links.
- Unknown extension data survives JSON, database, migration, and archive round trips.
- Core authoring remains usable offline and without an account.
- Existing SharedPreferences data remains readable until migration and recovery gates pass.
- The archive validates paths, sizes, checksums, fingerprints, IDs, and references before commit.

## Architectural gaps

### Canonical model gaps

- `RecordTypeDefinition` is designed in ADR-0003 but not implemented.
- Field primitives, sections, ordering, defaults, required fields, template inheritance, and template provenance are not modeled.
- Link type definitions and custom link types are not modeled; links currently accept arbitrary `typeId` strings.
- `AuthorRecordStatus` only represents active, archived, and deleted. Canon state and lifecycle state must not be conflated.
- Scope enums exist, but series/universe ownership and inherited querying are not implemented.
- Version revisions exist, but there is no canonical change-event/history repository.

### Repository and query gaps

- FTS exists for record titles, field values, tags, and manuscript-node metadata, but the legacy Codex UI does not use it.
- There are no repository filters for template, category, canon state, arbitrary indexed custom fields, or connected target.
- The database has individual type and scope indexes, not the combined/filter projections needed for large Codices.
- Link direction, allowed endpoints, inverse labels, duplicate policy, and cross-scope rules are not validated by a Connection Engine service.

### Integration gaps

- Legacy Codex entries are not loaded from the connected repository.
- The migration adapter proves one character-to-scene slice only; it does not migrate all Codex types or resolve all name-based links.
- Timeline, visual planning, research, generic records, and most manuscript references still have feature-owned persistence.
- Map Studio, World Studio, Relationship Studio, Plot/Thread records, series scope, branching, graph views, expansion registration, and generator output do not yet have complete connected implementations.
- Story Inspector and Story Health do not yet query Codex completeness, orphaned records, missing fields, conflicting canon, or broken connections.

## Safest integration points

- Add schema/type contracts beside `AuthorRecord` in the storage-agnostic connected domain.
- Persist canonical definitions through Drift and include them in versioned connected-domain snapshots and archives.
- Put connection validation and traversal in an application service over repositories, never in Flutter widgets.
- Use adapters from each legacy owner into records and links. Do not introduce permanent dual writes.
- Keep the current Codex UI on legacy data until migration verification can prove equal visible content and stable IDs.
- Let focused studios map typed record fields into their own editing interfaces while preserving fields they do not understand.
- Register built-in and expansion templates as data through the same definition contract used by custom templates.

## Implementation batches

### Batch 1: Schema-driven record type foundation

Deliver:

- `RecordTypeDefinition`, controlled field primitives, ordered sections, field definitions, defaults, required/optional state, suggested link types, scope/export metadata, and extension data
- inheritance resolution with cycle detection, additive child fields, optional-field hiding, default overrides, section additions, and suggested-link merging
- built-in definitions registered as data, including the directive's official starting templates and aliases for legacy `place`, `object`, and `lore` types
- Drift persistence, snapshot/archive participation, and unknown-field round trips for definitions
- validation that existing `AuthorRecord` instances remain readable when definitions evolve

Gate:

- focused domain and database tests pass
- custom `Magic Spell` and `Case` definitions round-trip through JSON, Drift close/reopen, and archive export/import
- inherited `Capital City` resolves from `Base Location -> City -> Capital City` without mutating parent definitions
- cyclic inheritance, duplicate field IDs, invalid defaults, and hiding required fields are rejected
- all pre-existing connected-domain, archive, Character Studio, and legacy Codex tests pass

### Batch 2: Link type registry and Connection Engine - passed

Deliver typed/inverse labels, endpoint and scope rules, custom link types, duplicate policy, incoming/outgoing traversal, bounded graph queries, integrity reporting, and safe removal previews.

Gate: a character-faction-location-scene graph is navigable from every endpoint; invalid links fail atomically; archives preserve definitions and links.

Implemented foundation: typed definitions, endpoint/direction/metadata validation,
derived incoming/outgoing traversal, project isolation, custom scoped definitions,
Drift schema v4 persistence, and portable archive participation. Bounded multi-hop
queries, cardinality enforcement, integrity reports, and safe-removal previews remain
part of the later inspector/integration work.

### Batch 3: Legacy Codex migration and connected read model

Deliver adapters for all five legacy types, aliases, statuses, relationships, and mentions; ambiguity/unresolved reports; backup-before-commit; connected Codex queries; and a compatibility fallback.

Gate: legacy fixtures and real saved projects retain visible entries, IDs, aliases, tags, archive state, and resolvable links after close/reopen; forced migration failure leaves the original project readable.

### Batch 4: Codex dashboard and entry editor

Deliver template selection, structured section editor, explicit canon versus notes/research controls, accessible search/filtering, archive/restore, pins, and connected navigation. The UI reads canonical records only after Batch 3 passes.

Gate: create, edit, archive, restore, duplicate, retarget template, custom field, tag, search, and linked-record workflows persist across restart with no legacy-data regression.

### Batch 5: Organisation and scalable discovery

Deliver categories, nested categories, tags with metadata, folders, collections, smart collections, saved custom views, series/book filters, indexed custom-field search, and lazy result loading.

Gate: smart collections update after mutations and large-project search/filter targets pass the measured latency budget without loading the full Codex.

### Batch 6: Cross-studio links

Migrate and expose manuscript mentions, timeline links, canonical Character/World/Relationship/Plot ownership, map markers, visual views, series scope, and explicit live-reference commands.

Gate: `Codex -> Character -> Relationship -> Scene -> Chapter -> Timeline -> Map -> Codex` uses stable IDs and no duplicated creative record.

### Batch 7: History, branches, inspector, and health

Deliver change events through the shared Version History system, branch/canon overlays, rules-based continuity checks, structural health reports, and recovery-safe destructive actions.

Gate: history records field/link/status/template changes; branch changes do not overwrite canon; all warnings include evidence and never judge prose quality.

### Batch 8: Graph, generators, expansion packs, and complete portability

Deliver graph views over live records, data-driven pack registration, editable generator output, managed assets, complete import/export formats, and optional versioned sync contracts.

Gate: an expansion pack adds templates, fields, categories, link types, icons, and views without core schema changes; full archive round-trip preserves the project graph and assets.

## Batch discipline

Only one batch may be active. At the end of each batch:

1. Run focused tests for the changed behavior.
2. Run the complete Flutter test suite.
3. Check analyzer and runtime errors.
4. Exercise affected workflows manually on an available packaged target.
5. Verify close/reopen persistence, links, navigation, and archive recovery.
6. Record exact changes and unresolved environment gates.

The next batch must not start until the current gate passes.