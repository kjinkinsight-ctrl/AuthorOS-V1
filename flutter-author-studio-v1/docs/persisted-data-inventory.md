# AuthorOS 1.x Persisted Data Inventory

Status: M0 migration input  
Audited: August 17, 2026  
Scope: Flutter application persistence through `SharedPreferences`

## Purpose

This inventory identifies every current preference namespace, its value shape, owner, migration destination, and compatibility treatment. It is the source checklist for legacy fixtures and AuthorOS 2.0 migration tests.

Dynamic placeholders use `{projectId}` or `{collection}`. SharedPreferences stores platform-specific primitive values; JSON and dates below are encoded as strings unless noted otherwise.

## Classification

| Class | Meaning | 2.0 direction |
|---|---|---|
| Creative corpus | Author-created project content | Migrate to embedded database and include in project archives |
| Creative preference | Project-specific authoring behavior | Keep in project/settings repository and include where needed in archives |
| Application setting | Device/application preference | May remain in SharedPreferences |
| Operational metadata | Backup or sync process state | Keep outside creative graph; migrate only with owning subsystem |
| Legacy compatibility | Previous representation retained for fallback | Read-only migration input, then retire after support window |

## Creative corpus keys

### `author_studio.starter_project`

- Owner: `OnboardingStore`
- Storage type: JSON object string
- Shape: `StarterProject`
- Fields: `id`, `title`, `genre`, `projectType`, `wordGoal`, `templateName`, `chapters`, `characterSheets`, `acts`, `beatChecklist`, `firstSceneTitle`
- Risk: stores only one active starter project globally
- 2.0 destination: project metadata plus initial records/manuscript seeds
- Fixture coverage: simple, missing optional fields, unknown future fields

### `author_studio.book_studio.{projectId}`

- Owner: `BookStore`
- Storage type: JSON object string
- Shape: `BookProject`
- Root fields: `projectId`, `titleOverride`, `authorOverride`, `subtitle`, `seriesName`, `seriesNumber`, `isbn`, `publisher`, `copyrightYear`, `copyrightHolder`, `edition`, `rightsStatement`, `frontMatter`, `backMatter`, `parts`, `format`, `epub`, `exportHistory`, `version`, `migration`
- Note: title and author are stored as *overrides*. Empty means "resolve from the
  manuscript title and the author profile at build time", so renaming a project
  keeps the title page and the running heads correct. Storing copies would go
  stale silently and only show up in a proof copy.
- Note: front and back matter that is generated (title page, copyright, contents)
  carries no body text here; it is rendered from the metadata and, for the
  contents, from the laid-out body, so it cannot go stale.
- Risk: outside the `.authoros` archive, structurally the same gap as scene prose
  (R-2); closing it adds a `data/book.json` entry and changes the archive entry
  count the story-graph audit pins
- Risk: no version history. A margin is not creative corpus; dedication and
  acknowledgement text is, and is mitigated by `version`/`migration` plus a
  `author_studio.book_studio_backup.{projectId}` key written on first overwrite
- 2.0 destination: project presentation settings, alongside the manuscript
- Fixture coverage: seeded defaults, malformed blob, foreign `projectId`, backup
- Note: also carries `epub` — the reflowable settings, kept apart from `format`
  because trim, margins and folios mean nothing once a reader reflows the text
- Note: `exportHistory` names what was exported and the hash of the manuscript it
  came from. The manuscript *bytes* are in `book_asset_rows`; only the reference
  is here, so the blob stays small. Capped at `BookProject.historyLimit` (25),
  deliberately more than the five snapshots kept — a row saying what was exported
  last Tuesday is still true after its manuscript has been evicted

### `author_studio.book_templates`

- Owner: `BookTemplateStore`
- Storage type: JSON array string
- Shape: `List<BookTemplate>`
- Per-template fields: `id`, `name`, `createdAt`, `format`, `epub`,
  `frontMatter`, `backMatter`
- Why global rather than per-project: a template exists to be applied to a
  *different* book. A project-scoped one would be useless, which also rules out
  the record graph, where `ConnectionEngine` enforces scope isolation
- Note: deliberately carries no identity — no title, author, ISBN, edition,
  copyright, cover, or `parts`. Book one's ISBN silently reaching book two is a
  way to publish something wrong; `parts` anchor to `startsAtChapterId`, which
  names another project's chapters
- Note: matter is structure only. Section bodies are stripped on capture, and
  applying a template keeps whatever the receiving book had already written
- Note: stores resolved values rather than a diff against a preset, for the same
  reason `BookFormat` does — a stored delta means shipping a preset change
  silently reflows every book built on it
- Risk: outside the `.authoros` archive, like the rest of the book data (R-2)
- 2.0 destination: project presentation settings, shared across the library
- Fixture coverage: capture, identity exclusion, apply, prose preservation, JSON
  round trip, malformed blob

### `book_asset_rows` (embedded database, not SharedPreferences)

- Owner: `BookCoverStore` (`cover`), `BookSnapshotStore` (`snapshot:{hash}`)
- Storage type: SQLite table, `(projectId, role)` primary key
- Columns: `projectId`, `role` (`cover` or `snapshot:{hash}`), `mediaType`,
  `bytes`, `width`, `height`, `updatedAt`, `extensionJson`
- Why not SharedPreferences: on the web that is `localStorage`, roughly five
  megabytes for the whole origin and shared with the author's prose. A cover is
  hundreds of kilobytes of binary; storing it there can fail to save or crowd out
  the manuscript. The embedded database is IndexedDB-backed in the browser.
- Note: bytes are stored exactly as the author supplied them. Re-encoding would
  mean PNG only, which makes a photographic cover larger, not smaller.
- Note: a `snapshot:{hash}` row is the gzipped JSON of the manuscript an export
  was built from, so an export can be reproduced after more writing — the M7 gate
  asks for exactly this. It shares this table rather than adding one because it
  is an authored asset by the same argument a cover is: never a `RecordLink`
  endpoint, participating in nothing. The `role` column was already a
  discriminator in the primary key.
- Note: snapshots are content-addressed on the manuscript's own hash, so
  exporting one book to four formats stores one row, not four. Capped at
  `BookSnapshotStore.retained` (5) per project, evicted least-recently-used, and
  anything the export history no longer names is collected on the next export.
- Risk: outside the `.authoros` archive, widening the same gap as scene prose
  (R-2)
- 2.0 destination: the Asset model in master plan §6.6
- Fixture coverage: sniffing, every rejection path, round trip, replacement,
  per-project isolation, schema 9 to 10 migration on a real file; for snapshots,
  round trip, dedupe, eviction, garbage collection, and that clearing them leaves
  the cover alone

### `author_studio.manuscript_studio.{projectId}`

- Owner: `ManuscriptStore`
- Storage type: JSON object string
- Shape: `ManuscriptProjectSummary`
- Root fields: `projectId`, `manuscriptTitle`, `chapters`, `currentChapterId`, `currentSceneId`, `createdAt`, `updatedAt`, `version`, `migration`
- Chapter fields: `id`, `title`, `order`, `status`, `summary`, `prompt`, `pov`, `linkedChapterIds`, `scenes`, `createdAt`, `updatedAt`
- Scene fields: `id`, `chapterId`, `title`, `order`, `content`, `status`, `pov`, `location`, `timeLabel`, `notes`, `relationships`, `createdAt`, `updatedAt`
- Scene relationship fields: `id`, `type`, `targetId`, `label`, `metadata`
- 2.0 destination: specialized manuscript repository plus canonical links
- Migration concerns: generated or missing IDs, ordering normalization, parent-ID repair, local relationship enum mapping, unknown relationship targets
- Fixture coverage: simple, large manuscript, malformed JSON, duplicate IDs, missing parent IDs, partially migrated version

### `author_studio.story_codex.{projectId}`

- Owner: `StoryCodexStore`
- Storage type: JSON array string
- Shape: `StoryCodexEntry[]`
- Fields: `id`, `title`, `type`, `aliases`, `summary`, `tags`, `relationships`, `mentions`, `status`
- Current types: `character`, `place`, `faction`, `object`, `lore`
- Relationship shape: map of relationship label to target display name
- Mention shape: list of presumed record/node IDs
- 2.0 destination: `AuthorRecord`, `RecordTypeDefinition`, and `RecordLink`
- Migration concerns: name-based target resolution, aliases, ambiguous names, archived targets, missing mention IDs
- Fixture coverage: exact match, alias match, ambiguous match, unresolved target, archived record, unknown future type

### `author_studio.story_codex`

- Owner: `StoryCodexStore` with empty project ID
- Storage type and shape: same as project Story Codex
- Behavior: falls back to demo/default entries when absent or malformed
- 2.0 destination: classify user-authored values as library records; never migrate built-in demo entries as user canon without evidence they were saved
- Migration concern: distinguish defaults from persisted user edits

### `author_studio.project.{projectId}.timeline`

- Owner: `TimelineStore`
- Storage type: JSON object string
- Root fields: `eras`, `sequences`, `events`
- Era fields: `id`, `title`, `status`, `description`, `createdAt`, `updatedAt`
- Sequence fields: `id`, `title`, `status`, `description`, `eraId`, `order`, `createdAt`, `updatedAt`
- Event fields: `id`, `title`, `description`, `dateLabel`, `startDay`, `endDay`, `pov`, `plotline`, `presentCharacters`, `location`, `travelDaysFromPrevious`, `linkedNote`, `plotBeat`, `status`, `importance`, `type`, `eraId`, `sequenceId`, `order`, `createdAt`, `updatedAt`
- 2.0 destination: timeline records, chronology values, and canonical links
- Migration concerns: character/location/POV names need ID resolution; free-text linked notes; invalid ranges; orphan era/sequence IDs
- Fixture coverage: valid chronology, invalid range, unresolved names, orphan sequence, future event fields

### `author_studio.project.{projectId}.visual_planning`

- Owner: `VisualPlanningStore`
- Storage type: JSON object string
- Root fields: `scenes`, `overlay`
- Planning scene fields: `id`, `title`, `status`, `pov`, `arc`, `order`
- 2.0 destination: saved Story Studio view over canonical manuscript scenes, plus storyline/POV links
- Migration concerns: determine whether IDs correspond to manuscript scenes; title-only matches are ambiguous; preserve unmatched cards as explicit planning records rather than discard them
- Fixture coverage: matched IDs, title-only candidate, unmatched card, duplicate card, unknown overlay

### `author_studio.research_panel.{projectId}`

- Owner: `ProjectResearchStore` in `lib/migrations/research_panel_store.dart` (moved from `main.dart` when the panel became read-only)
- Storage type: JSON map string keyed by `ResearchTab` name (`research`, `notes`, `timeline`)
- Values: arrays of `ResearchReference`
- Known fields: `title`, `detail`, `tag` — three strings, no URLs or record ids, as defined by `ResearchReference.toJson`
- 2.0 destination: `research-entry` records owned by Research Studio, plus links to manuscript/story records
- Migration concerns: duplicate references, unknown tabs, and `timeline` tab entries that are free text about chronology rather than timeline records
- Status: **migrated (August 2026), key retained.** `ResearchPanelMigrationService` lifts each reference into a canonical `research-entry` record on first open per project, and writes a receipt to `author_studio.research_panel.{projectId}.migrated`. The original key is deliberately never deleted or rewritten: it was never covered by the archive, sync, or backup subsystems, so it is the only copy of anything not yet migrated. Retain it for one support window, then retire. The migration is idempotent — record ids derive from project, tab, and title — so re-running is a no-op. See `docs/research-studio-expansion-map.md` §7.
- Fixture coverage: `legacy-research-panel.json` (all three tabs, category and non-category tags), `legacy-research-panel-malformed.json` (unknown tab, missing title key, whitespace title, duplicate title)

### `author_studio.research_panel.{projectId}.migrated`

- Owner: `ProjectResearchStore` in `lib/migrations/research_panel_store.dart`
- Storage type: JSON object string
- Shape: `ResearchPanelMigrationMarker`
- Fields: `version`, `migratedAt`, `createdRecordIds`, `skipped`
- Class: operational metadata — a migration receipt, not creative content
- 2.0 destination: none; retire alongside the legacy key it guards
- Migration concerns: an unreadable marker is treated as absent, which is safe because the migration is idempotent

### `author_studio.collection.{collection}`

- Owner: `StudioRecordStore`
- Storage type: JSON array string
- Shape: `StudioRecord[]`
- Fields: `id`, `title`, `category`, `details`, `status`
- Collection name is supplied by the caller
- 2.0 destination: classify each known collection into built-in/custom record types
- Migration concerns: collection namespace is not project-scoped; ownership must be inferred or requested; unknown collections must be preserved
- Fixture coverage: known collection, unknown collection, archived item, duplicate ID

## Creative preference keys

### `author_studio.project.{projectId}.reading_rhythm`

- Owner: `ReadingRhythmStore`
- Storage type: enum name string
- Values: current `ReadingRhythmPreset` names
- 2.0 destination: project writing preference
- Fallback: balanced preset for missing/unknown value

### `author_studio.chapters.{projectId}`

- Owners: legacy chapter screens and `ManuscriptStore`
- Storage type: string list; each item is a JSON chapter object
- Known fields consumed by migration: `title`, `prompt`, `status`, `scenes`, `linkedChapterIds`
- Classification: legacy compatibility and creative corpus seed
- 2.0 destination: manuscript migration input only
- Concern: malformed entries are currently skipped silently

## Legacy compatibility keys

### `author_studio.manuscript.{projectId}`

- Owner: `ManuscriptStore`
- Storage type: plain manuscript text string
- Behavior: current structured manuscript writes also refresh this flattened representation unless disabled
- 2.0 treatment: migration fallback only; structured manuscript wins when valid

### `author_studio.manuscript_legacy_backup.{projectId}`

- Owner: `ManuscriptStore`
- Storage type: plain manuscript text string
- Behavior: snapshot taken before legacy text is migrated into the structured manuscript
- 2.0 treatment: retain through the migration support window and include in diagnostic recovery export, but do not treat as a second authoritative manuscript

## Application setting keys

| Key | Type | Owner/use | 2.0 treatment |
|---|---|---|---|
| `author_studio.onboarding_complete` | bool | onboarding completion | remain application setting until library supports multiple projects |
| `author_studio.theme_id` | string | selected theme | remain SharedPreferences |
| `author_studio.accent_id` | string | selected accent | remain SharedPreferences |
| `author_studio.settings.autosave` | bool | autosave preference | remain setting; behavior must be reconciled with database transactions |
| `author_studio.settings.focus_defaults` | bool | default focus mode | remain SharedPreferences |
| `author_studio.profile_setup_complete` | bool | profile onboarding | remain SharedPreferences/platform profile adapter |
| `author_studio.profile.name` | string | writer identity and export metadata | remain profile setting; explicitly include author metadata in chosen exports |
| `author_studio.profile.email` | string | local profile/account hint | remain profile setting; never include in project archive by default |
| `author_studio.profile.focus` | string | writing focus | remain profile setting |
| `author_studio.profile.bio` | string | author bio | remain profile setting |
| `author_studio.profile.avatar_path` | string | local avatar path | move to managed profile asset if portability is required |
| `author_studio.profile.website` | string | author link | remain profile setting |
| `author_studio.profile.x` | string | author social link | remain profile setting |
| `author_studio.profile.goodreads` | string | author social link | remain profile setting |
| `author_studio.profile.newsletter` | string | author link | remain profile setting |
| `author_studio.profile.public` | bool | profile visibility preference | default must be reviewed; target is private by default |
| `author_studio.profile.require_reauth` | bool | security preference | remain operational setting |
| `author_studio.profile.secure_sessions` | bool | security preference | remain operational setting |
| `author_studio.profile.sync_alerts` | bool | notification preference | remain operational setting |

## Backup operational keys

| Key | Type | Meaning |
|---|---|---|
| `author_studio.backup_destination` | string | selected/displayed backup destination |
| `author_studio.backup_last_success` | ISO-8601 string | last successful backup time |
| `author_studio.backup_last_restore` | ISO-8601 string | last restore test time |
| `author_studio.backup_restore_status` | string enum | `passed` or `failed` |

These values describe backup health; they are not the backup itself. The 2.0 backup subsystem should derive health from actual archive manifests and checksums while preserving these values for upgrade continuity.

## Sync operational keys

### `author_studio.sync.device_id`

- Type: UUID-like string
- Meaning: durable local device identity
- Treatment: retain or move to secure application storage; never include in project archive

### `author_studio.sync.queue`

- Type: JSON array string
- Shape: `SyncOperation[]`
- Fields: `operationId`, `recordType`, `recordId`, `action`, `baseRevision`, `enqueuedAt`, `retryCount`, `deletedAt`, `payload`
- Treatment: current protocol compatibility only; drain or explicitly migrate before enabling entity-level 2.0 sync

### `author_studio.sync.revisions`

- Type: JSON object string
- Shape: map keyed by `{recordType}:{recordId}` to non-negative revision
- Treatment: preserve for current protocol; new entity repository owns revisions in 2.0

### `author_studio.sync.cursor`

- Type: nullable string
- Meaning: remote synchronization cursor
- Treatment: protocol-version-specific operational value; clear only through an explicit protocol migration

## Data not currently represented as durable creative storage

The audit found no canonical persisted 1.x stores for:

- universes or series
- custom record-type definitions
- general typed links independent of scenes
- managed project assets and checksums
- relationship-canvas layouts
- map geometry or layers
- book-layout specifications
- writing-session history and heat maps
- complete project archive manifests
- per-entity tombstones and revision history

These must be introduced by the 2.0 domain rather than inferred from unrelated settings.

## Migration precedence

When multiple legacy representations exist, use this precedence:

1. valid `manuscript_studio` structured data
2. legacy chapter seeds plus plain manuscript text
3. plain manuscript text alone
4. starter-project chapter prompts as empty manuscript seeds

For relationships:

1. exact target ID
2. unique normalized title match within the permitted scope
3. unique alias match within the permitted scope
4. explicit unresolved-reference record requiring user review

Never choose arbitrarily between multiple matches.

## Required fixture matrix

| Fixture | Purpose |
|---|---|
| `legacy-simple` | one project, chapter, scene, Codex character, timeline event, and valid links |
| `legacy-large` | performance-scale chapters, scenes, records, events, and references |
| `legacy-malformed` | invalid JSON, invalid dates, missing IDs, and wrong primitive types |
| `legacy-partial` | structured manuscript plus legacy fallbacks and mixed migration metadata |
| `legacy-ambiguous-links` | duplicate titles, aliases, archived targets, and unresolved names |
| `legacy-future-fields` | unknown root and nested fields that must survive compatibility round trips |

Fixtures must be anonymized, static, reviewed into source control, and loaded through test helpers rather than copied from a real author's local preferences.

## Completion criteria

This inventory is complete for M0 when:

- every `author_studio.*` preference accessed in `lib/` appears here
- each creative shape has a fixture owner
- every key has an explicit migration or retention treatment
- fixture tests prove malformed data cannot overwrite the only readable source
- a future code change adding a persisted key updates this inventory or a generated persistence registry