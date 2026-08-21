# Universal Records & Relationship Engine — Phase 1 Implementation Map

Audited: August 20, 2026
Scope: core record model and relationship foundation only. No Studio, no UI.

## Summary

Most of this phase already existed. AuthorOS shipped a Universal Record
envelope, a record type registry, scope/canon/branch semantics, a canonical
relationship edge, a relationship type registry and a Drift persistence layer
in earlier phases (see
`docs/cross-system-foundation-implementation-map.md`). This phase did **not**
rebuild any of that.

What Phase 1 added is the small set of foundations that were genuinely missing:
a typed record identity, one shared relationship validator (including the
branch-context rule), a project-scoped graph query surface, an explicit
Studio-facing repository boundary, the last few missing foundation record and
relationship types, and defined deletion behaviour for relationships.

## Existing architecture discovered

| Concern | Existing owner | Phase 1 decision |
|---|---|---|
| Universal record envelope | `AuthorRecord` — `lib/core/connected_domain.dart` | Reused unchanged |
| Record identity | `String id` on `AuthorRecord`, plus the `ConnectedEntities` Drift table as the shared id namespace | Reused; wrapped by `RecordId` |
| Record type registry | `RecordTypeDefinition` / `RecordTypeRegistry` — `lib/core/record_types.dart`, seeded by `BuiltInRecordTypes` | Reused; two type ids added |
| Scope | `RecordScopeType`, `RecordScope` — `lib/core/record_scope.dart` | Reused unchanged |
| Canon status | `CanonStatus` — `lib/core/record_scope.dart` | Reused unchanged |
| Lifecycle | `AuthorRecordStatus` — `lib/core/connected_domain.dart` | Reused unchanged |
| Branch model | `StoryBranch`, `BranchRecordOverlay`, `BranchLinkOverlay`, `BranchEngine`, `BranchService` | Reused unchanged |
| Relationship | `RecordLink` — `lib/core/connected_domain.dart` | Reused as *the* relationship model |
| Relationship type registry | `ConnectionTypeDefinition` / `ConnectionTypeRegistry`, seeded by `BuiltInConnectionTypes` | Reused; three types added |
| Relationship writes | `ConnectionEngine` — `lib/core/connection_engine.dart` | Reused; validation extracted and extended |
| Record writes | `RecordService` — `lib/core/record_service.dart` | Reused; link validation extracted |
| Record validation | `RecordValidator` — `lib/core/record_validation.dart` | Reused unchanged |
| Persistence | `AuthorOsDatabase` + `DriftConnectedDomainRepository` (SQLite via Drift, FTS5 `author_search`) | Reused; three additive read helpers |
| Deletion analysis | `SafeDeleteService`, `UniversalRecordInspector` | Reused unchanged |
| Version / audit | `VersionAuditService` | Reused unchanged |

Isar appears only in `dev_dependencies` for the storage benchmark tooling. The
persistence authority is Drift/SQLite, and this phase did not add a second
database.

## What was added

### 1. Record identity — `lib/core/record_id.dart` (new)

`RecordId` and `RelationshipId` are immutable, comparable, serializable value
types with no imports at all — not Flutter, not storage, not even another core
library. They are **not** a second identity system: `RecordId.value` is
byte-identical to the `AuthorRecord.id` that Drift already persists, and
`RelationshipId.value` to `RecordLink.id`. Nothing about the database changed.

Rules: values are trimmed, must be non-empty, must be strings, and must not
contain control characters (identities are also written into FTS rows, NDJSON
archives and audit summaries, where an embedded newline would corrupt the
surrounding record instead of failing loudly). `tryParse` returns `null`
instead of throwing. Identity is never derived from a title — two records may
share a title and remain different records.

### 2. Relationship validation — `lib/core/relationship_validation.dart` (new)

One validator now owns the rules that decide whether a relationship may exist.
`RelationshipValidator` takes a `ConnectionTypeRegistry` and two resolved
`RelationshipEndpoint`s (resolved by the caller, because a record can be
written in the same transaction as its links and therefore may not be readable
yet). It reports structured issues, mirroring `RecordValidationResult`.

Rules enforced, each with a stable issue code:

- `missing-relationship-id`, `missing-relationship-endpoint`,
  `missing-relationship-type`
- `unknown-relationship-source` / `unknown-relationship-target` — an endpoint
  that does not exist. Relationships never conjure phantom records.
- `relationship-project-mismatch`, `relationship-endpoint-project-mismatch` —
  project isolation.
- `relationship-branch-mismatch` — the two endpoints are in different branch
  contexts (see "Canon and branch" below).
- `relationship-endpoint-deleted` (error) and
  `relationship-endpoint-archived` (warning) — lifecycle handling.
- `relationship-self-reference` — rejected unless the relationship type opts in
  with `extensionData['allowSelfReference'] == true`.
- `unknown-relationship-type`, `invalid-relationship-direction`,
  `invalid-relationship-definition` — registry-driven checks, delegated to the
  existing `ConnectionTypeRegistry.validateConnection`.

`ConnectionEngine.connect`, `ConnectionEngine.updateConnection` and
`RecordService._validateLinks` were rewritten to call this validator instead of
each re-implementing endpoint, project, direction and metadata checks. Their
externally visible failure types are unchanged (`ArgumentError` for a missing
or self-referencing argument, `StateError` for a rejected relationship), so
existing callers and tests are unaffected.

### 3. Graph queries — `lib/core/record_graph.dart` (new)

`RecordGraph` provides the foundational reads over the existing repository:

- `outgoingRelationships(RecordId)`
- `incomingRelationships(RecordId)`
- `relationships(RecordId)`
- `related(RecordId, {direction, relationshipTypeIds, recordTypeIds, includeArchived, includeDeleted})`

Every read is confined to one project. Deleted records are excluded by default
so a soft-deleted record cannot leak back into a Studio through the graph.
There is no visual graph and no traversal beyond one hop; both belong to a
later phase.

### 4. Studio boundary — `lib/core/universal_records.dart` (new)

`UniversalRecordsRepository` is a thin, project-scoped facade. It owns no
storage and no rules: it composes `RecordService` (record lifecycle),
`ConnectionEngine` (relationship writes) and `RecordGraph` (reads) behind one
id-typed API.

```text
createRecord   getRecord   updateRecord   archiveRecord   restoreRecord
deleteRecord   listRecords findRecords(typeId:)
createRelationship  getRelationship  deleteRelationship  listRelationships
findRelated  findIncoming  findOutgoing
recordTypes()  relationshipTypes()
```

This is the surface a future Studio consumes — `findRecords(typeId: 'character')`
for Character Studio, `findRelated(eventId)` for Timeline Studio,
`findRecords(typeId: 'location')` for Map Studio — without any of them owning a
private identity, storage or link model.

### 5. Foundation types (extensions to the existing registries)

Added to `BuiltInConnectionTypes` (`lib/core/built_in_connection_types.dart`):
`childOf`, `locatedAt`, `references`. The other eleven primitives named by the
directive already existed: `contains`, `partOf`, `appearsIn`, `occursAt`,
`involves`, `relatedTo`, `parentOf`, `memberOf`, `belongsTo`, `precedes`,
`follows`. `BuiltInConnectionTypes.foundationTypeIds` names the fourteen so a
Studio can assert their presence without hard-coding the whole registry.

Added to `BuiltInRecordTypes` (`lib/core/built_in_record_types.dart`):
`project` (a record type for the project itself) and `event` (a selectable
alias over `timeline-event`). `BuiltInRecordTypes.foundationTypeIds` names the
twelve foundation record identities; several are aliases over a richer Studio
type (`object` over `item`, `lore` over `general-lore`, `research` over
`research-entry`), which is why it is a name list and not a second registry.

### 6. Persistence read helpers (additive)

`DriftConnectedDomainRepository` gained three read-only methods:
`relationshipEndpoint(entityId)`, `linkById(id)` and `linksByScope(scopeId)`.
No table, column, index or schema version changed.

## Record model

`AuthorRecord` was not modified. It already carries id, `typeId`, `scopeType`,
`scopeId`, `projectId`, `seriesId`, `bookId`, `branchId`, `canonStatus`,
`title`, lifecycle `status`, `schemaVersion`, `templateId`, `templateVersion`,
`revision`, `fields`, `tags`, `createdAt`, `updatedAt` and `extensionData`.

## Scope model

`RecordScopeType` (`library`, `universe`, `series`, `project`, `book`,
`branch`, `manuscript`) and `RecordScope` remain authoritative. No second
scope model was introduced and no scope semantics were invented.

## Relationship model

`RecordLink` remains the one relationship: id, `sourceId`, `targetId`,
`typeId`, `scopeId` (the owning project), `direction`, `label`, `revision`,
`metadata`, `createdAt`, `updatedAt`, `extensionData`. Relationship *types* are
data in `ConnectionTypeRegistry`, so the vocabulary stays extensible and no
relationship is hard-coded into the model.

## Repository boundary

```text
core model      record_id, record_scope, record_types, connection_types,
                connected_domain, relationship_validation, branch_domain
      |
storage         AuthorOsDatabase + DriftConnectedDomainRepository (Drift/SQLite)
      |
services        RecordService, ConnectionEngine, BranchService, RecordGraph,
                VersionAuditService, SafeDeleteService
      |
boundary        UniversalRecordsRepository
      |
studios / UI    (not part of this phase)
```

## Serialization

Unchanged and reused: every model already implements `toJson` /
`fromJson` with UTC ISO-8601 timestamps, enum-name encoding, and
`extensionData` passthrough so unknown future fields survive a round-trip.
`RecordId` and `RelationshipId` serialize to their plain string value.
Malformed data throws `FormatException` rather than producing a partial object.

## Canon and branch

Canon and branch semantics were not redefined. AuthorOS models a branch two
ways, and both are respected:

1. **Branch overlays** — `BranchRecordOverlay` / `BranchLinkOverlay` layered on
   canonical records by `BranchService`. Branch-only records live in the
   overlay, not in the canonical record table, so a canonical relationship can
   never reach one.
2. **Branch-scoped records** — an `AuthorRecord` with
   `scopeType: RecordScopeType.branch` and a `branchId`.

The new rule closes the gap in case 2: a relationship is rejected when its two
endpoints have different branch contexts, where "canon" means `branchId ==
null`. Concretely:

| Source | Target | Result |
|---|---|---|
| canon | canon | allowed |
| branch A | branch A | allowed |
| canon | branch A | rejected |
| branch A | branch B | rejected |

Branch relationships continue to be written through
`BranchService.addConnection` as `BranchLinkOverlay`s, which already require
both endpoints to be visible in that branch.

## Deletion behaviour

`UniversalRecordsRepository.deleteRecord` soft-deletes the record through the
existing `RecordService` lifecycle and, by default, removes every relationship
that references it via `ConnectionEngine.disconnect`, so each removal is
audited. No other record is touched, and the deleted record itself is preserved
as a soft delete with its version and audit history intact.

`detachRelationships: false` keeps the edges for callers that deliberately want
them; those callers own the resulting dangling references.

`RecordService.deleteRecord` and `SafeDeleteService` were not changed — a
physical delete still requires the existing safe-delete analysis to come back
unblocked.

## Dependency direction

The core model files import no Flutter, no Drift, no persistence and no Studio.
`lib/core/record_id.dart` has no imports at all. This is asserted by tests, not
just by convention.

`RecordService`, `ConnectionEngine`, `RecordGraph` and
`UniversalRecordsRepository` sit in the service layer and import the Drift
repository, which is the pre-existing arrangement. They import no Studio and no
Flutter widget code.

## Future Studio integration points

- Manuscript Studio — `findRecords(typeId: 'chapter' | 'scene' | 'book')`
- Character Studio — `findRecords(typeId: 'character')`, `findRelated(...)`
- World / Map Studio — `findRecords(typeId: 'location' | 'faction')`
- Timeline Studio — `findRelated(eventId)`, `findRecords(typeId: 'event')`
- Plot Studio — `findRelated(..., relationshipTypeIds: {...})`
- Community — `listRecords()` filtered by the caller's own publication rules

None of these Studios were implemented, and none of them exist as a dependency
of the core.

## Known limitations

1. `RecordId` is a boundary type. `AuthorRecord.id` and `RecordLink.id` are
   still `String`, because changing them would be a breaking, migration-bearing
   change across every Studio and the persisted schema. Conversion is
   `record.recordId` / `RecordId.parse(id)`.
2. `RecordGraph` reads canonical relationships only. Branch overlay edges are
   still read through `BranchService` / `BranchEngine`; a branch-aware graph
   read is future work.
3. `related()` is one hop. There is no traversal, path finding, cycle detection
   or graph visualisation.
4. The branch-context rule compares `branchId` for equality. It does not yet
   consult branch *lineage*, so a record in a child branch cannot be linked to
   a record in its parent branch. `BranchEngine.lineage` exists and could
   relax this in a later phase.
5. `deleteRecord` cascades relationship removal one relationship at a time
   rather than in a single transaction. Each removal is individually audited
   and consistent, but a mid-cascade failure leaves the earlier removals
   applied.
6. `listRelationships()` returns every relationship in the project with no
   paging.
7. The foundation relationship primitives (`childOf`, `locatedAt`,
   `references`) accept any record type on both ends and carry no metadata
   fields, on purpose. Richer Studio relationship types keep their own type
   constraints and metadata schemas.

## Database and schema changes

None. No table, column, index, trigger or `schemaVersion` was changed, no
migration was written, no persisted field was renamed and no record was
deleted. Every persistence addition is a read-only query helper.
