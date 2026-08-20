# World Studio Implementation Map

Status: Phase 1 domain and spatial-data foundation implemented  
Updated: August 20, 2026

The authoritative Phase 1 implementation detail is in
`docs/world-studio-phase-1-implementation-map.md`. The batch roadmap below is retained
as historical planning context. Where it conflicts with the Phase 1 map, the Phase 1
map and the shared service implementations are current.

Implemented since the original roadmap:

- shared `WorldService` facade over records, connections, templates, branches, search,
  history, Inspector, validation, and safe delete
- complete data-driven spatial/cosmic type families and the seven required templates
- derived parent/child/sibling/ancestor/descendant/root hierarchy with cycle protection
- stable universal Map, Map Marker, and Travel Route records and links
- Character, Faction, Codex, Timeline, and Manuscript stable-ID integration
- sparse branch overrides and branch link overlays without Canon world cloning
- comprehensive cross-system fixture and focused domain tests

No polished World Studio UI or interactive map editor was added.

## Architectural Rule

World Studio is a management view over AuthorOS canonical `AuthorRecord` and
`RecordLink` data. Story Codex, Character Studio, Map Studio, Timeline Studio,
and Manuscript Studio must resolve the same stable record IDs. No Studio may
own a second authoritative world, location, faction, item, or event record.

## Existing-System Audit

| Area | Existing implementation | Reuse decision |
| --- | --- | --- |
| Canonical records | `AuthorRecord`, stable IDs, scopes, revisions, status, tags, extension data | Use as the only world-record authority |
| Connections | `RecordLink` with directed/undirected edges, metadata, backlinks, and foreign keys | Use as the only relationship authority |
| Persistence | Drift/SQLite repository, transactions, FTS5, scope/type indexes, snapshots | Extend repository operations; do not add feature-owned storage |
| Custom types | `RecordTypeDefinition` and schema-version-3 persistence | Align World templates with this registry in the next schema batch |
| Story Codex | Five fixed SharedPreferences types with name-based relationships | Preserve during migration; remove authority after verified import |
| Character Studio | Canonical character records, but some connection data remains projected into the Character model | Link characters to world IDs through `RecordLink` |
| Timeline | Structured events with string locations and character names | Migrate events/names to canonical IDs and links |
| Manuscript | Specialized scene/chapter nodes | Keep specialized; link nodes to world records |
| Maps | No canonical map view/model found | Build saved map views that reference location IDs |
| Search | Canonical FTS plus feature-local filtering | Use FTS for corpus search and indexed filters for large worlds |
| Versioning | Revision fields and snapshots, no complete history service | Integrate with the shared history service when introduced |
| Branching | Scope model exists; canon branches do not | Add branch metadata and isolation without copying canon records |

## Batch 1: Canonical World Foundation

Status: implemented and covered by focused tests.

- schema-driven built-in World templates
- safe template inheritance and custom templates
- deep templates for geography, society, religion, language, magic,
  technology, species, creatures, economy, history, and items
- complete requested location-template catalogue
- canon, draft, research, author-note, and non-canon states
- custom record fields
- transactional canonical record/link writes
- hierarchy and reverse-connection retrieval
- FTS-backed world search
- responsive World dashboard and schema-driven editor
- archive/restore behavior
- temporary Codex compatibility view so existing projects remain reachable

## Batch 2: Canonical Type Registry and Migration

Status: in progress.

Completed integration slice:

- World Studio and Story Codex now read and edit the same canonical
   `AuthorRecord` IDs.
- New World records use their shared template ID as `AuthorRecord.typeId`
   instead of the feature-owned `worldRecord` type.
- World records include shared Codex category, project, template, and canon
   metadata and appear in Story Codex without a copied entry.
- Codex-created world types appear in World Studio and retain their stable ID
   when edited there.
- Existing `worldRecord` rows remain readable and are upgraded when edited.

Remaining work:

1. Convert the deep World template catalogue to shared
    `RecordTypeDefinition` data and remove the temporary template adapter.
2. Add a versioned, backup-first migration from legacy `StoryCodexEntry`.
3. Resolve place/faction/object/lore name relationships to IDs; retain
   unresolved or ambiguous references as explicit migration issues.
4. Remove the SharedPreferences Codex authority only after fixture, rollback,
   and archive round-trip tests pass. Do not introduce permanent dual writes.

## Batch 3: Cross-Studio Links

1. Character links: species, culture, religion, home, faction, language,
   occupation, item, and historical event.
2. Manuscript-node links: scene location, faction, item, event, and world rule.
3. Timeline links: canonical historical/world events, eras, and custom dates.
4. Plot links: threads, arcs, conflicts, mysteries, themes, and symbols.
5. Series and universe scopes with shared records and book-specific links.

## Batch 4: World Views and Systems

1. Hierarchy tree with accessible keyboard navigation and lazy children.
2. World graph over live records and links with bounded traversal.
3. Map saved views whose markers contain only record IDs and presentation data.
4. Custom calendars and date conversion contracts for Timeline Studio.
5. Collections, smart collections, pinned records, saved filters, and tag groups.
6. Canon/alternate/what-if branches with isolated mutation boundaries.

## Batch 5: Integrity, Generation, and Portability

1. Explainable World Inspector rules and structural World Health metrics.
2. Deterministic, AI-free generators that emit editable canonical records.
3. Expansion-pack registration through templates, fields, links, and generators.
4. World Bible section selection, ordering, templates, and export.
5. PDF, DOCX, TXT, JSON, and project-archive export where platform support exists.
6. Deletion impact analysis with archive, convert, unlink, retain, and cancel paths.

## Performance Gates

- Never load all world records to render a paged list.
- Index template/category, scope, status, tags, and relationship endpoints.
- Bound graph traversal by depth and result count.
- Lazy-load hierarchy children, backlinks, map markers, and history.
- Test with thousands of records and links before enabling large graph views.

## Acceptance Tracking

The master acceptance list is intentionally staged across the batches above.
Batch 1 establishes the canonical authority and functional creation surface; it
does not claim completion of maps, calendars, cross-Studio migrations,
branching, inspectors, generators, exports, or version-history integration.