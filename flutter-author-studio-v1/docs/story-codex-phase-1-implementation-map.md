# Story Codex Phase 1 Implementation Map

Status: Implemented and covered by focused domain tests
Updated: August 20, 2026

## Architecture

Story Codex is a domain layer over the shared AuthorOS knowledge architecture.
Every entry is an `AuthorRecord`; every relationship is a `RecordLink`; all
persistence remains in `DriftConnectedDomainRepository`.

`StoryCodexService` owns Codex-specific orchestration and delegates:

- record CRUD, lifecycle, validation, and version creation to `RecordService`
- relationships and relationship history to `ConnectionEngine`
- templates and inheritance to `RecordTypeRegistry` and `TemplateEngine`
- branch overlays to `BranchService`
- discovery to `UniversalSearchService`
- inspection to `UniversalRecordInspector`
- deletion analysis to `SafeDeleteService`
- history reads to `VersionAuditService`

There is no Codex database, relationship table, search index, history service,
timeline store, inspector, or physical deletion path.

## Entry Types

Built-in definitions cover Basic Lore; geographic levels; factions,
organisations, houses, and clans; cultures and religions; magic and technology;
languages, species, creatures, and monsters; items and artefacts; documents;
historical events and periods; governments, laws, traditions, institutions,
professions, concepts, myths, legends, rumours, secrets, roles, and custom
entries.

The registry is data-driven. Projects add custom types through project-scoped
`RecordTypeDefinition` records without schema changes.

## Template System

Required built-ins are available for:

- Basic Lore
- Location
- Faction
- Culture
- Religion
- Magic System
- Historical Event
- Item / Artifact

Templates inherit through `baseTypeId`. Location levels inherit Location;
organisation, house, and clan inherit Faction; magic abilities and spells
inherit Magic System; item subtypes inherit Item; historical periods and eras
inherit Historical Event. Resolved definitions merge parent fields and sections
without copying them into child definitions.

Simple mode maps to title, summary, description, tags, and notes. Deep fields
are optional unless a project template marks one required.

## Field System

Structured values remain in `AuthorRecord.fields`. `CodexStructuredField`
describes key, label, type, value, validation metadata, visibility, ordering,
template ownership, and custom status. Unknown values are retained by record,
database, archive, and legacy JSON round trips.

Basic Lore adds searchable aliases, knowledge status, and stable source
reference fields. Record tags remain the canonical tag storage.

## Connection System

Codex uses `ConnectionEngine` and `ConnectionTypeRegistry`. Existing types are
reused. Missing Codex semantics were added as shared built-in definitions,
including rule, origin, cause/effect, chronology, knowledge, culture, and
manuscript-reveal relationships.

Codex relationship metadata uses the existing typed metadata mechanism for
strength, dates, status, privacy, secrecy, notes, context, source, and
confidence. Custom connection definitions can add project-specific metadata.

## Timeline Integration

Historical events and periods are Universal Records. Codex timeline queries
traverse shared links to `timeline-event`, `historical-event`,
`historical-period`, and `era` records. Chronology uses shared `precedes`,
`follows`, `caused`, and `resultedIn` links.

## Character Integration

Characters are the same `character` records used by Character Studio. Codex
queries return connected character records by stable ID. Membership, location,
religion, item, language, culture, and event participation are represented by
shared links rather than copied character fields.

## World Integration

World, region, country, city, settlement, district, building, and location
records are visible through shared IDs. World Studio remains the owner of
geographic editing; Codex supplies lore templates and knowledge views.

## Manuscript Integration

Books, chapters, scenes, and manuscript nodes are link targets. `mentionedIn`,
`appearsIn`, `revealedIn`, `introducedIn`, `explainedIn`, `foreshadowedIn`, and
`confirmedIn` use shared connections. Manuscript text and indexing are not
duplicated.

## Search

`searchCodex` delegates to `UniversalSearchService`. The shared FTS projection
indexes titles, aliases and other fields, tags, type/template metadata, canon,
scope, and branch projections.

## Inspector

`inspectEntry` delegates to `UniversalRecordInspector` and exposes overview,
connections, references, history, template compatibility, scope, validation,
dependencies, and branch state.

## Version And Audit

Record and connection mutations pass through `RecordService` and
`ConnectionEngine`. Name, field, lifecycle, canon, template, relationship, and
branch changes therefore use `VersionAuditService`. No `CodexHistory` exists.

## Branches

`BranchService` provides inherited, overridden, branch-created, and hidden
states using sparse record and link overlays. Canon records are not cloned or
mutated when edited in a branch.

## Validation

Codex creation validates required template fields and category ownership.
Shared `RecordValidator`, template compatibility checks, connection endpoint
validation, and inspector aggregation provide VALID, WARNING, and ERROR states.

## Safe Delete

`analyzeDelete` delegates to `SafeDeleteService`. Analysis includes incoming
and outgoing links, manuscript and domain references, branch overlays,
historical versions, legacy references, and template dependencies. Codex only
archives, restores, or soft-deletes through `RecordService`.

## Legacy Compatibility

Legacy aliases (`place`, `object`, `lore`) remain registered. Existing IDs,
extension fields, unknown metadata, tags, lifecycle state, and relationships
remain readable. No destructive migration or physical deletion was added.

## Tests

`story_codex_service_test.dart` covers legacy service behavior, lifecycle,
project isolation, custom templates, FTS, links, and close/reopen persistence.

`story_codex_phase1_test.dart` and its rich fixture cover built-in families,
deep templates, custom fields and templates, relationship metadata and
mutation, timeline/character/world/manuscript integration, search, inspector,
history, branches, safe delete, and all validation states.

## Known Limitations

- This phase does not replace the complete legacy Codex Flutter UI.
- Branch-created entries are created through `BranchService`; the convenience
  `createFromTemplate` API currently creates canonical records.
- Structured source references are modeled, but research/source editor UI is
  deferred.
- Full temporal consistency analysis is deferred; dates and ordered links are
  present for a future engine.
- Map markers remain outside the canonical reference projection reported by
  the Universal Record Inspector.

## Future Codex UI Work

Phase 2 may build the polished Codex workspace: template picker, simple/deep
editing modes, section navigation, relationship editing, branch controls,
knowledge visibility, source references, saved views, and inspector entry
points. It must continue to use this shared domain layer.