# ADR-0003: Connected Creative Domain Model

## Status

Proposed

## Date

August 17, 2026

## Context

AuthorOS 1.x persists creative data in feature-owned models and stores:

- manuscript projects contain chapters, scenes, and scene-local relationships
- Story Codex entries contain a fixed five-value type enum and name-based relationship maps
- timeline events repeat character and location names
- visual planning stores a second scene representation
- research references and generic studio records use separate collection formats
- sync currently wraps a whole starter project rather than individual connected entities

This structure is appropriate for the current MVP, but it cannot safely support shared universes, series canon, custom record types, backlinks, relationship history, maps, visual boards, or entity-level sync. Adding those capabilities directly to the existing stores would create duplicate records and broken references whenever a title changes.

AuthorOS must preserve its local-first behavior, existing projects, deterministic continuity features, and explicit boundary from indiauthors.com.

## Decision

AuthorOS 2.0 will use one canonical connected domain beneath all studios.

### Ownership hierarchy

Creative content is owned by an explicit scope:

```text
Library
  +-- Universe
        +-- Series
              +-- Project / Book
                    +-- Manuscript
```

Universe and series are optional. Standalone projects remain first-class.

### Canonical entities

The core domain consists of:

- `RecordTypeDefinition`: schema for built-in and user-defined creative types
- `AuthorRecord`: typed creative record with stable ID, scope, fields, tags, revision, and extension data
- `RecordLink`: typed edge between stable record or manuscript-node IDs
- `Manuscript`: specialized ordered document structure containing parts, chapters, and scenes
- `Asset`: managed binary file with relative path, metadata, size, and checksum
- `StudioView`: presentation and layout state over canonical records and links

Chapters and scenes remain specialized manuscript nodes because editing, ordering, snapshots, and export need stronger contracts than a general record. They still participate in the graph through stable IDs.

### Identity and references

- IDs are globally unique and independent of names, order, and parent paths.
- Cross-studio references use IDs only.
- Human-readable names are resolved through repositories.
- Renaming or moving an entity does not alter its ID.
- Imported unresolved references are explicit states, not silently dropped strings.
- Archived entities remain resolvable and visibly archived.

### Custom types

Characters, locations, factions, items, lore, events, and similar concepts use the same schema mechanism as user-created types. Built-in types provide templates and behavior, not closed database tables that require a migration whenever a genre needs a new concept.

### Views do not own creative data

Planning boards, relationship canvases, maps, table layouts, and filters are saved views. They may own coordinates, colors, grouping, visibility, and presentation metadata, but they reference canonical records instead of copying them.

### Storage boundary

Creative corpus data moves behind repository interfaces backed by an embedded transactional database. SharedPreferences remains suitable for small application settings, migration markers, device identity, and operational preferences.

The database implementation is deliberately deferred to ADR-0004 after a measured Drift/SQLite versus Isar proof of concept. Domain and repository contracts must not depend on either candidate.

### Compatibility and migration

AuthorOS will provide versioned adapters from current models:

- `StarterProject` to project metadata
- `ManuscriptProjectSummary` to manuscript nodes
- `SceneRelationship` to `RecordLink`
- `StoryCodexEntry` to `AuthorRecord`
- timeline models to records and links
- planning scenes to saved views over manuscript scenes
- current sync envelopes to compatibility payloads

Migration creates and verifies a backup before committing. A failed migration leaves the original 1.x data readable. Unknown fields survive serialization round trips.

There will be no permanent dual-write architecture. Each bounded area may use a temporary compatibility adapter while its migration is validated, then switches authority to the new repository.

### Application and platform boundary

The AuthorOS application owns local creative data and local repositories. indiauthors.com owns identity, commerce, licensing, downloads, support, and optional community services. Cloud sync, if enabled, crosses a versioned API and does not make the website runtime an implicit owner of local creative data.

## Invariants

1. Every connected entity has a stable non-empty ID.
2. Every entity has exactly one owning scope and scope ID.
3. A link identifies source, target, type, direction, and owning scope.
4. Link and index mutations commit atomically.
5. A saved view cannot contain an authoritative copy of a creative record.
6. Deleting a referenced entity cannot silently erase links or linked content.
7. Project archive export includes all creative data and referenced managed assets in the selected scope.
8. Import and migration validate IDs, references, schema versions, paths, sizes, and checksums before commit.
9. Core authoring workflows remain functional without network access or an account.
10. Continuity rules report evidence and do not silently rewrite creative content.

## Consequences

### Positive

- Studios can share one character, event, location, or scene without duplication.
- Backlinks and graph traversal become consistent application services.
- Custom genre records do not require application schema changes.
- Series and universe canon can be shared without copying records into each book.
- Map, visual, and relationship layouts can evolve independently of creative content.
- Entity-level sync and conflict handling become possible.
- Complete archive export has a defined ownership boundary.

### Costs

- Existing stores require migration adapters and fixtures.
- Name-based relationships must be resolved, including ambiguous and broken names.
- Visual planning scene duplicates must be reconciled with manuscript scenes.
- Repository and transaction infrastructure must exist before new studios can rely on the model.
- Scope inheritance and book-specific annotations add product complexity.

### Risks

- A premature schema could encode current UI assumptions into the long-term domain.
- A broad one-time migration could create data-loss risk.
- Temporary compatibility code could become permanent if milestones lack removal gates.
- Custom fields can make validation and export inconsistent unless field primitives remain controlled.

## Rejected alternatives

### Keep one store per studio

Rejected because records would diverge and links would depend on names or duplicated IDs.

### Make every object a generic record

Rejected because manuscript text, ordering, snapshots, editor latency, and publishing export need specialized document behavior.

### Use the remote platform as the canonical database

Rejected because it violates the accepted local-first product and runtime boundary.

### Rewrite all 1.x data in one release

Rejected because it creates an unnecessary data-loss and release-stability risk.

### Select the database in this ADR

Rejected because storage selection requires a platform and workload benchmark. The domain decision is independent of that result.

## Validation

The first vertical slice must prove this decision by:

1. adapting one existing Story Codex character to an `AuthorRecord`
2. exposing one existing scene as a linkable manuscript node
3. creating a typed character-to-scene link transactionally
4. displaying the connection and backlink in both existing contexts
5. archiving and restoring the character without losing the link
6. exporting and importing the slice with identical IDs and content
7. forcing migration failure and confirming the original project still opens

ADR-0003 can move to Accepted after product approval of the AuthorOS 2.0 master plan and architecture review of these invariants. Implementation approval still depends on ADR-0004 for embedded storage.

## Related documents

- [AuthorOS 2.0 Master Feature and Architecture Plan](../authoros-2-master-plan.md)
- [Persisted Data Inventory](../persisted-data-inventory.md)
- indiauthors-platform/docs/architecture/ADR-0001-authoros-boundary.md
- indiauthors-platform/docs/architecture/ADR-0002-platform-runtime.md