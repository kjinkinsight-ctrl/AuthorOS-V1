# AuthorOS Cross-System Foundation Implementation Map

Audited: August 18, 2026  
Status: Foundation provisionally accepted; Character Studio Phase 1 consumes the shared services

## Directive

Character Studio, Story Codex, World Studio, Manuscript Studio, Timeline Studio,
Relationship Studio, Plot Studio, Map Studio, and Visual Studio must operate on
one connected AuthorOS data architecture. A Studio may own a specialized view or
editor, but not a second canonical copy of a creative record or connection.

## Audit findings

The Flutter application is the current creative-data owner. The
`indiauthors-platform` workspace has commerce, account, and generic sync concerns,
but no competing creative-record runtime.

| Concern | Existing owner | Decision |
|---|---|---|
| Universal records | `AuthorRecord` in `lib/core/connected_domain.dart` | Extend this envelope; do not add Studio databases |
| Stable identity | `ConnectedEntities` in Drift | Preserve one ID namespace for records and manuscript nodes |
| Record types/templates | `RecordTypeDefinition` and `RecordTypeRegistry` | Shared schema-driven registry; expansion definitions remain data |
| Connections | `RecordLink`, `ConnectionEngine`, and `ConnectionTypeRegistry` | Store one canonical edge and derive incoming/inverse views |
| Persistence | `AuthorOsDatabase` and `DriftConnectedDomainRepository` | SQLite/Drift remains the local-first authority |
| Search | Drift FTS5 `author_search` | Extend the shared index; keep Studio filters as projections |
| Portable recovery | `AuthorOsArchiveService` | Versioned NDJSON archive remains the migration and recovery boundary |
| Legacy Codex | `StoryCodexStore` SharedPreferences data | Back up, adapt, validate, then change authority; never discard fields |
| Character Studio | Connected `AuthorRecord` and `RecordLink` writes | Keep as a focused editor over shared records |
| Manuscript | Specialized chapter/scene storage plus stable node references | Keep manuscript bodies specialized; project graph identity into core |
| Timeline/visual/research | Feature-owned SharedPreferences models | Migrate incrementally through adapters after foundation gates pass |
| Version/audit | Revision fields only | Add one shared event/version repository in a later batch |
| Branch/canon | Partial scope enums only | Add shared branch overlays and canon state before deep Studio branching UI |
| Inspector | No universal implementation | Build over records, links, references, validation, and versions |

## Invariants

1. IDs are stable and independent of titles.
2. Records and links have one canonical owner.
3. A persisted link has valid endpoints in one project boundary.
4. Reverse relationships are derived from the canonical link.
5. Unknown extension data survives JSON, Drift, archives, and migrations.
6. Migrations are additive, transactional, recoverable, and tested across reopen.
7. Existing SharedPreferences data remains readable until its migration gate passes.
8. No destructive operation cascades into dependent creative records.

## Character Studio Phase 1 integration

Character Studio Phase 1 confirms the foundation assumptions without replacing them:

- `CharacterService` composes `RecordService`, `ConnectionEngine`,
  `BranchService`, `UniversalSearchService`, `VersionAuditService`,
  `UniversalRecordInspector`, and `SafeDeleteService`.
- The deep Character schema and built-in Character templates are
  `RecordTypeDefinition` data registered through the shared registry.
- Family, relationship, manuscript, timeline, faction, location, item, plot,
  arc, and knowledge edges are shared `ConnectionTypeDefinition` and
  `RecordLink` data.
- `CharacterPresentationModel` is a template-derived read model for future UI;
  it owns no persistence, validation, search, history, or branch behavior.
- Story Codex and Character Studio continue to read one canonical Character
  record. The current Character UI adapter remains transitional.

See `docs/character-studio-implementation-map.md` for fields, templates,
integration coverage, test fixtures, limitations, and Phase 2 boundaries.

## World Studio Phase 1 integration

World Studio Phase 1 consumes the same accepted foundation through `WorldService`.
Its spatial/cosmic types, location templates, maps, markers, routes, hierarchy edges,
Character/Faction/Codex/Timeline/Manuscript links, search, history, inspection, branch
overlays, validation, and safe-delete analysis remain Universal Record concerns.

Two genuine compatibility requirements were found and fixed without adding a World-
specific subsystem:

- `RecordValidator` now honors a field definition whose `recordProperty` is `title`.
  This makes the shared required `general-lore.name` contract validate the canonical
  record title rather than requiring a duplicate structured `name` value.
- Exact connection endpoint validation now registers the complete shared spatial type
  family. A City, River, Building, Planet, or custom location subtype can therefore
  participate in the same validated relations as Location without weakening endpoint
  validation globally.

See `docs/world-studio-phase-1-implementation-map.md` for the complete domain map,
fixture, limitations, and future UI boundary.

## Batch status

### Batch 1: Universal record and record-type foundation - passed

- Stable records, manuscript-node identities, links, snapshots, and Drift storage exist.
- Record types, field primitives, sections, validation, inheritance, versions, and
  built-in/extension registration are data-driven.
- Schema v3 persists record-type definitions.

### Batch 2: Connection type registry and validation - passed

- `ConnectionTypeDefinition` models endpoint types, direction, inverse labels,
  cardinality, temporal support, metadata fields, owning scope, pack provenance,
  and extension data.
- `ConnectionTypeRegistry` validates endpoint pairs and metadata contracts.
- `BuiltInConnectionTypes` provides one core catalogue for cross-system links.
- `ConnectionEngine` resolves endpoint types and validates every new connection.
- Custom connection types persist in scoped Drift schema v4 rows and portable archives.
- Old archives remain readable when no connection-definition entry is present.

Automated gate: 127 Flutter tests passed with no diagnostics on changed files.

### Batch 3: Shared record validation and CRUD - passed

- `RecordValidator` returns structured error/warning results for stable identity,
  project ownership, registered record type, allowed scope, schema compatibility,
  required fields, and field value types.
- `RecordService` owns create, get, update, archive, restore, recoverable delete,
  duplicate, validation, and FTS-backed search for project records.
- Record-plus-link writes remain atomic and validate scope, endpoint ownership,
  endpoint record types, direction, metadata, and custom/core connection definitions.
- Story Codex entries, Character Studio records, and canonical World Studio records
  now use the shared service instead of writing records directly.
- World subtype templates resolve through their ancestry to a registered canonical
  record type while preserving exact template identity in structured metadata.
- Normal delete is a soft lifecycle transition, so links and references remain
  available for restore and future safe-delete inspection.

Focused automated gate: 18 tests passed across shared CRUD, Story Codex, Character
Studio, and World Studio with no diagnostics.

Compatibility boundary: Codex categories/tags/collections remain infrastructure
records on their existing repository path. Conversion from legacy `worldRecord` IDs
uses an explicit migration bridge. Physical purge is intentionally unavailable until
the Universal Record Inspector can produce a safe-delete dependency report.

### Batch 4: Template engine completion - passed

- Universal records carry optional `templateId` and `templateVersion` provenance.
- Legacy records remain readable by falling back to `typeId` and `schemaVersion`.
- `TemplateEngine` reports current, upgrade-available, newer-than-definition,
  missing-definition, and incompatible-record-type states.
- Migration plans identify additive fields and required values needing author input
  without changing the record, deleting unknown fields, or advancing its version.
- Child templates are compatible with canonical parent record types, and shared
  validation enforces the resolved child schema rather than only the parent type.
- Drift schema v5 stores nullable provenance columns through an additive,
  introspection-safe migration. Snapshots and portable archives preserve them.
- Shared updates and duplication retain template provenance.

Focused automated gate: 20 tests passed across template behavior, shared CRUD,
database upgrades/reopen, and portable archive round trips with no diagnostics.

### Batch 5: Scope, canon, and branch engine - passed

- `RecordScopeType` now includes explicit Book and Branch scopes alongside Project
  and Series. `RecordScope` validates project, series, book, and branch ownership.
- Universal records carry first-class `projectId`, `seriesId`, `bookId`, `branchId`,
  and shared `CanonStatus` metadata. Canon state is separate from active/archive/delete
  lifecycle state.
- Shared canon states are Canon, Draft, Proposed, Deprecated, Non-Canon, and Alternate.
  Existing Codex and World enums remain compatibility adapters and populate the shared
  value rather than acting as separate authorities.
- `StoryBranch` supports What-If, Alternate Timeline, Alternate Ending, Alternate
  Universe, and Draft kinds, optional parent branches, project ownership, and status.
- `BranchRecordOverlay` stores sparse overridden fields/title/tags/canon, branch-created
  records, and hidden/inapplicable states. Canonical records are never cloned or
  updated to represent an override.
- `BranchLinkOverlay` adds or hides connections in a branch without changing the
  canonical `RecordLink`. Typed endpoints, direction, metadata, and connection rules
  reuse the central connection registry.
- `BranchEngine` resolves parent-to-child lineage into immutable record and connection
  views. Parent-created records are inherited and may be overridden or hidden by a
  child branch.
- `BranchService` owns branch creation, override/create/hide commands, branch-aware
  record/link resolution, template validation, and project isolation.
- Normal `RecordService.updateRecord` cannot change record ownership scope. Branch
  changes must use overlays and therefore cannot leak into Canon.
- Template ID/version and schema fields are preserved through branch resolution, and
  resolved records pass shared template/record validation before an overlay commits.
- Drift schema v6 adds nullable scope/canon columns, indexed project/series/book/branch
  queries, branch definitions, and sparse record/link overlay tables.
- Portable archives add optional branch and overlay NDJSON streams. Archives from
  earlier batches remain readable with empty branch collections.
- Legacy `_codex.*` and `_world.*` project/canon metadata is promoted on hydration so
  existing projects remain compatible without destructive rewriting.

Focused automated gate: 47 tests passed across branch resolution/persistence plus
shared CRUD, templates, connections, database migration/reopen, archives, Story Codex,
World Studio, and Character Studio. Full Flutter regression: 144 passed, 0 failed.
Changed-file diagnostics are clean and Drift schema generation completed successfully.

Deliberate boundary: no What-If or alternate-world UI, branch merge/rebase/conflict UI,
branch-aware FTS projection, branch marketplace behavior, or permanent purge is part
of this batch. Branch-created records and connection deltas remain overlay-owned and
are accessed through `BranchService`; they are not inserted into Canon tables. No
Character, World, or Codex-specific branch engine was introduced.

### Batch 6: Universal search - passed

Files created:

- `lib/core/search_models.dart`
- `lib/core/universal_search.dart`
- `test/universal_search_test.dart`

Files modified:

- `lib/persistence/authoros_database.dart`
- `lib/persistence/authoros_database.g.dart`
- `docs/cross-system-foundation-implementation-map.md`

Architecture and result model:

- `UniversalSearchService` provides `searchAll`, `searchByType`,
  `searchByProject`, `searchBySeries`, `searchByBook`, `searchByStatus`, and
  `searchByBranch` over Universal Records and linkable manuscript nodes.
- `SearchResult` carries stable ID/type/title/snippet, project/series/book/branch,
  shared canon status, template/category/tags, matched field, FTS relevance, and a
  navigation target without copying the underlying record payload.
- `SearchNavigationTarget` maps current record types to Character, World, Story Codex,
  Timeline, Plot, Manuscript, Series, or generic record destinations. No navigation UI
  or command-palette integration is included.

Indexing decisions:

- Drift schema v7 retains one shared SQLite FTS5 table. It does not create Studio-owned
  Character, World, Codex, Timeline, Plot, or Manuscript search databases.
- The shared index stores unindexed project/series/book/branch/canon/lifecycle/type/
  template metadata beside indexed title, structured/custom field JSON, and tags.
- Canonical record and manuscript-node writes update FTS transactionally. Snapshot and
  archive restore rebuild the same index through normal repository writes.
- Sparse branch record overlays use deterministic synthetic FTS row IDs in the same
  table. Canonical edits refresh dependent overlay rows so inherited metadata remains
  current. Hidden branch records are removed from the overlay index and rejected again
  during branch resolution.
- Queries apply project/type/series/book/lifecycle and Canon-branch isolation in SQL
  before bounded rank limits. FTS5 `bm25` and snippets are used; exact title matches get
  a small deterministic priority. No custom ranking engine was introduced.
- Search hydrates only matched candidate records or manuscript nodes. Branch candidates
  resolve through `BranchEngine`, then deduplicate canonical and overlay hits. It does
  not load every canonical record merely to search.

Scope, branch, and canon behavior:

- Project ID is mandatory at the service and SQL query boundaries, preventing records
  with identical content in another project from leaking into results.
- Series, Book, all six shared Canon states, record type, and lifecycle filters use the
  shared Universal Record metadata.
- Canon search excludes branch overlay rows. Branch search includes inherited Canon
  candidates plus only the requested branch lineage, applies sparse overrides, includes
  branch-created records, removes hidden records, and never exposes unrelated branches.
- Branch results carry the active branch in result and navigation metadata even when an
  inherited canonical record has no stored `branchId`.

Compatibility decisions:

- `searchEntityIds` remains as an ID-only compatibility wrapper, so existing Story
  Codex search continues to use the shared FTS table unchanged.
- Existing Character, World, Manuscript, and legacy global Search UI filters remain in
  place. This batch adds the shared service beneath future integration rather than
  replacing specialized behavior prematurely.
- The integration fixture covers Character, Location, Faction, Codex Entry, Timeline
  Event, Scene, and Chapter results plus navigation metadata.

Focused automated gate: 56 tests passed across Universal Search, branch resolution,
shared CRUD, templates, connections, database migration/reopen, archives, Story Codex,
World Studio, and Character Studio. Full Flutter regression: 153 passed, 0 failed.
Changed-file diagnostics are clean and Drift schema v7 generation succeeded.

Known limitations: no search UI, suggestions, analytics, semantic/AI search, connection
reference text indexing, branch merge/rebase behavior, saved searches, highlighting UI,
or advanced field-specific ranking. Manuscript Scene/Chapter results use existing
`ManuscriptNodeReference` metadata; full manuscript bodies remain searchable through
the existing specialized Manuscript search until their canonical node projection is
expanded in a later integration batch.

### Batch 7: Version and audit engine - passed

Files created:

- `lib/core/version_audit.dart`
- `lib/core/version_audit_service.dart`
- `test/version_audit_model_test.dart`
- `test/version_audit_service_test.dart`

Files modified:

- `lib/core/connected_domain.dart`
- `lib/core/record_service.dart`
- `lib/core/connection_engine.dart`
- `lib/core/branch_service.dart`
- `lib/persistence/authoros_database.dart`
- `lib/persistence/authoros_database.g.dart`
- `lib/archive/authoros_archive.dart`
- `docs/cross-system-foundation-implementation-map.md`

Version and audit models:

- `RecordVersion` is an immutable, chained snapshot with version/entity/record IDs,
  entity kind, record type, project/series/book/branch ownership, timestamp, change
  type, summary, schema version, previous version ID, source, snapshot, and metadata.
- `AuditEvent` is a separate immutable event referencing exactly one created version.
  It records the entity/record/project/branch, change taxonomy, timestamp, summary,
  source, Series/Book metadata, and meaningful before/after context.
- Snapshot and metadata collections are defensively deep-copied and exposed through
  unmodifiable maps/lists. Drift inserts use plain append-only inserts; duplicate IDs
  fail instead of updating historical rows.
- The extensible taxonomy includes create/update/rename/archive/restore/delete/
  duplicate, connection add/remove/metadata/type, template/status/scope/branch changes.

Storage strategy:

- Drift schema v8 adds immutable `record_version_rows` and `audit_event_rows` with
  indexes for project, entity, record, branch, Series/Book, change type, and date.
- The engine stores full JSON snapshots for shared structured records, links, branch
  definitions, and sparse overlays. This favors reliable reconstruction and restore
  over fragile diffs. Binary assets and full manuscript bodies are not duplicated;
  they remain outside the current Universal Record history boundary.
- Current-state writes and their version/audit rows commit in one SQLite transaction.
  A failed history insert rolls back the current-state mutation.
- `VersionAuditService` is the only model/query constructor. It chains
  `previousVersionId` independently per entity and branch and exposes version lookup,
  ordered history, audit history, version-at-time, count, latest, and changes-since.
- Filters support Record, record type, Project, Series, Book, Branch, change type, and
  date range. Every query requires a project boundary.

Record, connection, branch, and template history:

- Shared `RecordService` create/update/archive/restore/delete/duplicate operations now
  append history. Rename, template, lifecycle/canon status, and general updates are
  classified centrally with previous/new metadata where applicable.
- `changeScope` is an explicit validated operation that records previous/new Project,
  Series, Book, or Branch ownership without making historical versions ambiguous.
- `ConnectionEngine` records add/remove and provides a validated update path for
  metadata and connection-type changes. Version snapshots contain the complete link,
  providing the foundation for reconstructing a record's historical connections.
- Branch creation, sparse record overrides/create/hide states, and branch connection
  overlays use the same engine with explicit branch-scoped chains. Canonical and branch
  histories never share a chain or overwrite one another.
- Template changes retain previous/new template IDs and versions. Canon/lifecycle
  changes retain previous/new shared statuses.

Restore strategy:

- Canonical restore reads an immutable historical snapshot, preserves the current
  version, validates record/project/type/template/scope, validates all current
  connections, then writes a new current record revision plus a new Restored version
  and audit event. Historical rows are never rewritten.
- Branch restore reconstructs a historical sparse overlay, validates branch resolution
  and the resulting record, then appends a new branch version. It never writes the
  canonical record or canonical history.
- Critical tests prove Version 1 -> Version 2 -> Version 3 -> restore Version 1 creates
  Version 4 while Versions 1-3 remain byte-equivalent, and prove branch restoration
  leaves Canon and Canon history unchanged.

Migration and archive strategy:

- Schema v8 is additive and preserves all prior records, branch overlays, FTS data,
  unknown extension data, and archives.
- Connected snapshots now optionally carry versions and audit events. Portable archives
  add `versions.jsonl` and `audit-events.jsonl` with checksums and manifest schema
  metadata. Older archives without those streams import with empty history.
- Close/reopen and archive export/import/commit tests retain ordered versions, audit
  events, immutable snapshots, and project/branch context.

Focused automated gate: 66 tests passed across Version/Audit, Universal Search,
branching, shared CRUD, templates, connections, database migration/reopen, archives,
Story Codex, World Studio, and Character Studio. Full Flutter regression: 163 passed,
0 failed. Changed-file diagnostics are clean and Drift schema v8 generation succeeded.

Known limitations: no history UI, Inspector, diff viewer, branch merge/rebase, bulk
history compaction, asset history, or full manuscript-body history. History is emitted
by shared services; explicit legacy migration/probe repository writes remain low-level
compatibility paths. Full historical graph reconstruction is not exposed yet, but
immutable connection snapshots and timestamps provide its required data foundation.

### Batch 8: Universal record inspector - passed

Files created:

- `lib/core/record_inspection.dart`
- `lib/core/record_inspector.dart`
- `test/record_inspector_test.dart`

Files modified:

- `docs/cross-system-foundation-implementation-map.md`

Inspector architecture:

- `UniversalRecordInspector` is a strictly read-only composition service. It does not
  add tables, caches, secondary records, connection copies, history rows, branches, or
  template definitions.
- `UniversalRecordInspection` is a structured future-UI read model with Overview,
  Connections, References, History, Template, Scope, Validation, Dependencies, and
  capability/limitation sections. It contains lightweight IDs and summaries rather
  than duplicating the underlying Universal Record payload.
- Records resolve directly by stable ID and optional type, or through
  `UniversalSearchService.searchAndInspect`. Every lookup is bound to one project.
- Tests compare connected snapshots before and after direct/search/branch inspection
  to prove the service performs no writes.

Data sources:

- Identity, Project/Series/Book/Canon/lifecycle/schema/timestamps come from
  `AuthorRecord` through `DriftConnectedDomainRepository`.
- Canon connections use repository incoming/outgoing links. Branch connections and
  effective records use `BranchEngine` through `BranchService`; no alternate graph is
  built by the Inspector.
- Connection names, inverse labels, endpoint rules, metadata validation, temporal
  support, and temporal metadata use the shared `ConnectionTypeRegistry`.
- Record/template/scope checks use `RecordService.validateRecord`, `TemplateEngine`,
  and existing template inheritance definitions.
- Record versions and all related audit events use `VersionAuditService`. Record
  version counts exclude connection-event versions while audit history retains those
  related connection events.
- Search resolution uses Universal Search and its existing project/type/branch filters.

Connection and reference inspection:

- Each connection reports stable ID/type, display and inverse labels, source/target
  endpoint identity/type/title/project, direction, metadata, temporal support/state,
  branch context, and validation outcome.
- References are derived only from actual canonical RecordLinks and branch link
  overlays. Current classifiers cover Universal Records, World, Codex, Timeline, Plot,
  Manuscript, Chapter, and Scene endpoints.
- Legacy name-only Story Codex, Timeline, planning, or manuscript references are not
  fabricated. Map/Map Marker references are explicitly reported as unsupported until
  they gain a canonical stable-ID projection.

Scope, history, template, and validation inspection:

- Canon, overridden, inherited, branch-created, and hidden records are distinguished.
  Hidden records remain inspectable as non-visible dependencies without being shown as
  effective Canon state.
- Canon and branch history queries remain separate. The model exposes latest version,
  ordered version IDs/count, latest change/event, change type/time, and branch context;
  no diff or editing behavior is included.
- Template output includes ID/version, parent, complete inherited lineage,
  compatibility status, available version, and upgrade/migration state from the shared
  Template Engine.
- Validation combines existing record/template/scope checks with typed connection,
  missing endpoint, broken reference, and branch-context diagnostics. It produces
  structured VALID/WARNING/ERROR state without introducing another validation engine.

Safe-delete analysis:

- The Inspector reports incoming/outgoing connections, known stable-ID references,
  unique branch dependencies, record-version count, and dependent entity IDs.
- Analysis is informational only. No physical deletion or bypass around RecordService
  safeguards exists in this batch.

Focused fixture and verification:

- The fixture contains Character, Location, Faction, Item, Codex Entry, Timeline Event,
  Plot Thread, Scene, Chapter, Canon links, branch override, branch-created and hidden
  records, branch link deltas, Version/Audit history, and a second isolated project.
- Focused automated gate: 81 tests passed across Inspector, Version/Audit, Universal
  Search, branching, shared CRUD, templates, connections, database, archives, Story
  Codex, World Studio, and Character Studio.
- Full Flutter regression: 178 passed, 0 failed. Changed-file diagnostics are clean.
  No schema changed; Drift remains at the previously verified schema v8 and generation
  was not required for this read-only batch.

Known limitations and future UI:

- No Inspector UI, Story Inspector, graph editor, map editor, version diff, branch
  merge, or deep Studio work is included.
- Inspection is snapshot-based rather than streamed. Large-project pagination and
  batched endpoint hydration can be added before a user-facing Inspector UI.
- The structured model can later render Overview, Connections, References, History,
  Template, Scope, Validation, and Dependencies panels without changing core storage.

### Batch 9: Safe delete and legacy migration adapters - passed

Files created:

- `lib/core/safe_delete.dart`
- `lib/core/safe_delete_service.dart`
- `lib/migrations/legacy_reference_models.dart`
- `lib/migrations/legacy_reference_adapters.dart`
- `lib/migrations/legacy_reference_migration.dart`
- `test/safe_delete_service_test.dart`
- `test/legacy_reference_migration_test.dart`

Files modified:

- `lib/core/branch_service.dart`
- `docs/cross-system-foundation-implementation-map.md`

Safe Delete architecture and policy:

- `SafeDeleteService` is read-only and composes `UniversalRecordInspector`, current
  records/links, branch overlays, Version/Audit history, and adapter-reported or
  previously migrated legacy references. It creates no dependency table and performs
  no archive, lifecycle, connection, history, template, or search mutation.
- `SafeDeleteAnalysis` reports deterministic identity/type, disposition, blocking
  reasons, warnings, incoming/outgoing connections, stable-ID references, legacy
  references, branch dependencies, versions/audits, affected records/branches/
  manuscript nodes, template dependents, lifecycle state, and physical eligibility.
- Active incoming/outgoing connections, stable-ID references, branch record/link
  dependencies, migrated or adapter-resolved legacy references, and actual template
  dependents are BLOCKING.
- Historical versions/audit events alone are warnings and remain immutable. An Active
  record is not physically eligible until Archived or Soft Deleted. A dependency-free
  Archived or Soft Deleted record is physically eligible but this service still does
  not delete it.
- Canon analysis includes all canonical dependencies. Branch overrides, branch-created
  records, hidden states, and branch connection deltas are reported without allowing a
  branch operation to remove Canon. Project B records/links/history never appear in a
  Project A analysis.
- Snapshot-equality tests prove analysis is strictly read-only.

Legacy reference formats discovered and adapted:

- `StoryCodexEntry.relationships`: relationship key to target name.
- `StoryCodexEntry.mentions`: intended stable Scene/Chapter/Timeline IDs.
- `ManuscriptScene.pov` and `.location`: name-only Character/Location strings.
- `SceneRelationship.targetId`: intended stable ID with relationship-type constraints.
- `TimelineEvent.pov`, `.presentCharacters`, `.location`, and `.plotline`: name-only
  Character, Location, and Plot Thread strings.
- `PlanningScene.pov`: name-only Character string.
- Legacy unknown formats are reported Unsupported; no format is inferred or invented.

Migration architecture and ambiguity rules:

- Adapters emit structured `LegacyReference` descriptors with source entity, field
  path, original value, expected record types, optional branch, and optional stable ID.
- Resolution is exact and deterministic: normalized title or alias, constrained by
  project, active branch view, and expected type. One candidate is Resolved; multiple
  exact candidates are Ambiguous; none are Unresolved; unknown adapters are Unsupported;
  existing valid stable IDs or persisted migration-map entries are Already Migrated.
- Ambiguous, Unresolved, and Unsupported references never write, create records, create
  links, or append versions/audits. Dedicated snapshot/history tests verify this.
- Successful migration adds a stable-ID resolution entry under
  `_legacyMigration.stableReferences` on the owning Universal Record or branch overlay.
  The original name/field, unknown fields, and extension data are retained unchanged.
- Canonical writes use `RecordService`; branch overrides use `BranchService`; branch-
  created records use a dedicated validated `updateCreatedRecord` path that preserves
  Created overlay state. All successful writes append shared Version/Audit history and
  refresh FTS through existing services.
- Repeating a migration returns Already Migrated and creates no duplicate map entry,
  record, connection, version, or audit event.
- Branch resolution includes inherited and branch-created candidates only from the
  requested branch lineage; unrelated branch candidates cannot introduce ambiguity or
  cross-branch writes.

Archive, search, and cross-system safety:

- No schema change was required. Legacy portable archives import through the existing
  archive service, migrate through adapters, reopen with stable IDs and audit history,
  and preserve unknown fields. Older archives remain readable.
- Successful migration updates the existing Universal Record FTS row. Tests confirm
  target records remain searchable, migrated owners become searchable by stable ID,
  and project isolation remains intact.
- The safety fixture includes Character, Location, Faction, Item, Codex Entry, Timeline
  Event, Plot Thread, Scene, Chapter, stable links, manuscript references, dependency
  analysis, repeat migration, Version/Audit integrity, and Universal Search integrity.

Focused automated gate: 98 tests passed across Safe Delete, migration adapters,
Inspector, Version/Audit, Universal Search, branching, shared CRUD, templates,
connections, database, archives, Story Codex, World Studio, and Character Studio.
Full Flutter regression: 195 passed, 0 failed. Changed-file diagnostics are clean.
No schema changed; Drift remains at verified schema v8 and regeneration was not
required.

Known limitations:

- No physical deletion, deletion UI, migration/resolution UI, dependency graph, or
  automatic fuzzy/partial-name matching is included.
- Legacy SharedPreferences owners are adapted into descriptors; persisting their
  rewritten source payloads remains a future owner-specific integration step. Batch 9
  persists stable mappings on Universal Records/branch overlays while preserving those
  legacy payloads as fallback.
- Map/Map Marker stable-ID references remain unsupported until the map subsystem gains
  a canonical projection.

### Batch 10: Full cross-system integration fixture - not started

Prove the complete Character -> Codex -> World -> Timeline -> Plot -> Manuscript ->
Connections -> Search -> Branches -> Versions -> Audit -> Inspector -> Safe Delete
architecture through one controlled fixture and final foundation gate.

## Migration decision

Use additive Drift versions and versioned archive entries. Before converting a legacy
owner, create a portable backup, detect its schema, adapt into records and links in a
transaction, validate identity/reference counts, and retain the old source as a
readable recovery path until verification succeeds. Never silently normalize away
unknown or unsupported fields.

## Acceptance boundary

The complete cross-system directive is not yet accepted. Batch 1 through Batch 9 are
verified foundations. The full Batch 10 cross-system integration fixture and final
foundation gate remain required before deep Studio implementations can begin. Work
stops at Batch 9 here; Batch 10 is not started.