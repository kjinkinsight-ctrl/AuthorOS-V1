# Character Studio Implementation Map

Status: Phase 2 workspace and dynamic template UI implemented  
Audited: August 20, 2026  
Scope: Character domain, templates, connections, presentation contract, and shared-service integration

## Directive

**Do not simplify Character Studio.** Character Studio is a deep author-controlled workspace over Universal Records. It does not own a character database, connection store, branch engine, search index, audit log, inspector, validation engine, or delete system.

Phase 1 establishes depth and contracts. It does not claim the final polished Character Studio UI.

## Architecture

```text
Character Studio UI / Story Codex / Manuscript / Timeline / World / Plot
                              |
                       CharacterService
                              |
  RecordService + TemplateEngine + ConnectionEngine + BranchService
  UniversalSearchService + VersionAuditService + UniversalRecordInspector
                         + SafeDeleteService
                              |
          AuthorRecord + RecordLink + shared Drift repository
```

`CharacterService` is the character-specific application facade. It verifies character type and project ownership, then delegates to accepted foundation services. It does not implement parallel persistence or cross-system behavior.

The pre-existing `CharacterStudioStore` remains a compatibility adapter for the current UI. It writes canonical `AuthorRecord` values through `RecordService`, creates links through `CharacterService`/`ConnectionEngine`, and projects shared records back into the legacy string-oriented UI model. Legacy category links are represented as validated undirected `relatedTo` links with a `legacy:<category>` label until Phase 2 replaces that projection.

## Character Record

A Character is an `AuthorRecord` with:

- `typeId = character`
- stable record ID
- explicit project, series, book, branch, and owning scope metadata
- independent canon and lifecycle states
- template ID and version
- schema version, revision, created time, and updated time
- typed structured fields, tags, and extension preservation

Only `identity.fullName` is required. All other profile depth is optional, allowing both sparse and extensive characters.

## Fields and Sections

The shared `character` definition now contains more than 130 typed fields grouped into data-driven sections:

- Identity
- Appearance
- Personality
- Psychology
- Backstory
- Goals and motivations
- Character arcs
- Secrets
- Knowledge
- Voice
- POV profile
- Notes
- Portraits and references
- Family
- Relationships
- Factions and organisations
- Locations
- Items and possessions
- Role in story
- Timeline
- Manuscript appearances
- Story Codex
- World

Connection-backed sections declare that ownership in section metadata and do not duplicate connected records.

Structured tables are used for multiple goals, arcs, secrets, and character-knowledge entries. Author knowledge remains separate from character knowledge. Psychology fields are fictional development data and are not medical diagnoses.

## Template Architecture

Built-in templates are registered as `RecordTypeDefinition` children of `character`:

- Basic Character
- Main Character
- Supporting Character
- Antagonist
- Love Interest
- Villain
- Hero
- POV Character
- Fae Character
- Fantasy Character
- Modern Character
- Historical Character

Templates inherit the canonical schema and can control visible sections through extension metadata. Basic Character intentionally exposes a small section set without deleting deeper data.

`CharacterRecordTypes.customTemplate` creates project-scoped custom templates. `CharacterService.registerCustomTemplate` rejects templates that do not extend `character` or belong to the active project. Shared `TemplateEngine` and `RecordValidation` handle compatibility, versions, and required values.

## Presentation Model

`CharacterPresentationModel` resolves a character's template through the shared registry and produces ordered sections and typed fields for Phase 2 rendering. It exposes:

- template identity and version
- section order and default collapsed state
- connection-backed section markers
- typed field definitions and current values
- whether a section currently contains data

It contains no Flutter widgets and no persistence logic.

## Relationship Architecture

Character relationships remain shared `RecordLink` edges. The shared connection catalogue now includes:

- friend, enemy, ally, rival, and partner
- parent/child and guardian/ward
- mentor/student
- protector/protected
- employer/employee
- trust and distrust

Relationship edges support temporal validity plus structured strength, status, beginning, ending, mutuality, public/secret state, trust, conflict, history, and notes metadata. Updating relationship metadata uses `ConnectionEngine`, creating immutable version/audit entries rather than overwriting history without evidence.

Existing shared types continue to cover membership, residence, ownership, use, manuscript appearances, and timeline involvement. Added shared types cover mentions, birthplace, workplace, visits, carrying items, goals/plot threads, arcs, and character knowledge.

## Cross-System Integration

### Manuscript

`appearsIn` and `mentionedIn` link Characters to stable Scene, Chapter, and Book IDs. Character Studio queries these links; it does not own a manuscript index. Legacy name-only references remain migration inputs.

### Timeline

Timeline and historical event records connect to Characters through `involves`. Backstory and arc events can use the same stable links. Character Studio derives its timeline from shared records.

### Story Codex and World

Story Codex and Character Studio read the same `typeId=character` record. Character links to lore, secrets, factions, organisations, locations, species, occupation, items, culture, religion, magic, politics, and technology remain shared records and links.

### Plot

`pursues` and `hasArc` connect Characters to Plot Thread records. Goal and arc tables keep character-owned development details while cross-record references remain links.

### Search

`UniversalSearchService.searchByType(query, 'character')` searches names, aliases, titles, tags, traits, occupations, template metadata, canon/scope metadata, and custom structured values through the shared FTS index. There is no Character search index.

### Versions and Audit

All Character CRUD and connection mutations use `RecordService`, `ConnectionEngine`, and `VersionAuditService`. Name, field, relationship, lifecycle, canon, template, and branch changes therefore use shared immutable history.

### Branches and Canon

Character branch changes use sparse `BranchRecordOverlay` and `BranchLinkOverlay` data through `BranchService`. Canon records are not cloned or mutated by branch overrides. Character records support project, series, book, and branch ownership through the Universal Record envelope.

### Inspector and Validation

`UniversalRecordInspector` exposes Character overview, connections, references, history, template, scope, validation, dependencies, and branch-effective state. `RecordValidation` resolves the selected character template and validates required fields, field types, scope, template, and branch constraints.

### Safe Delete

`CharacterService.analyzeDelete` delegates to `SafeDeleteService`. Connections, manuscript references, branch dependencies, Codex/Timeline links, template dependencies, and legacy references can block deletion. Character Studio contains no custom cascade-delete logic.

## Phase 1 Test Fixture

`CharacterDomainFixture` creates:

- Main Character
- Supporting Character
- Antagonist
- Love Interest
- POV Character
- relationship history and metadata
- faction membership
- location residence
- item ownership
- structured secret, goal, arc, and knowledge data
- timeline event
- manuscript scene
- Story Codex lore record
- plot thread

Every cross-record relationship uses the shared connection architecture.

## Verification Coverage

Focused tests cover:

- sparse deep schema and all required sections
- built-in and custom templates
- typed identity, appearance, personality, psychology, backstory, goals, arcs, secrets, knowledge, voice, role, and POV data
- shared relationships and relationship history
- factions, locations, items, scenes, timeline, Codex, and plot links
- search, inspector, validation, audit history, archive/restore/delete
- canon and branch isolation
- safe-delete dependency blocking
- project isolation
- data-driven presentation sections
- legacy Character Studio persistence and link compatibility

## Known Limitations

- The current Character Studio Flutter screen remains a compatibility UI with hard-coded sections. Phase 2 will render `CharacterPresentationModel` dynamically.
- Final custom-template builder UI is not included.
- Legacy starter sheets, name-only manuscript references, and timeline character names still require complete migration workflows.
- Multiple goals, arcs, secrets, and knowledge entries have typed table payload contracts but no final table editors yet.
- Relationship Studio UI, graph layout, statistics dashboard, questionnaires, and deterministic AI-free generators remain future Character phases.
- Portrait storage still needs managed-asset integration; Phase 1 defines image/reference fields but does not generate images.
- No AI generation, writing assistance, portrait generation, marketplace, social sharing, analytics, or community behavior is included.

## Phase 2 Workspace

The writer-facing `CharacterBoardView` now provides a responsive Character
workspace over the Phase 1 services. It contains a searchable roster, character
header, template/canon/lifecycle/branch metadata, save state, profile completion,
section navigation, inline editing area, connected-record panels, quick actions,
and useful empty states.

Header actions delegate to shared services for duplicate, archive/restore,
template changes, Universal Inspector, and immutable Version/Audit history.
Historical snapshots are read-only.

### Dynamic Template Renderer

The workspace resolves the active template from the project-scoped shared
`RecordTypeRegistry`. It renders inherited sections and fields from
`RecordTypeDefinition`, including custom project templates, without template-
specific widget layouts.

The field renderer supports short/long text, number/rating, date, boolean,
single choice, multi-value/list/tag/checklist values, references, rich text,
and structured table values. Labels, descriptions, required state, defaults,
visibility, order, section order, and inherited fields come from definitions.

Structured goal, arc, secret, and knowledge tables use a reusable item editor
with add, edit, reorder, archive, and restore actions. Values remain the Phase 1
typed table payloads.

### Section System

Large desktop layouts use an independently scrollable secondary section rail.
Smaller desktop/browser widths use a compact section selector. Empty sections
remain reachable and show an empty marker and task-specific guidance.

Overview cards navigate to Goals, Psychology, and Character Arc sections.
Required-field completion is shown separately from optional profile depth, so
authors are not penalised for intentionally sparse characters.

### Editing, Validation, and Save State

Template fields edit inline in the workspace. Changes update the compatibility
view model immediately and debounce through the canonical Character adapter and
`RecordService`. `Ctrl+S` and `Cmd+S` flush pending saves.

The header reports Saved, Saving, Unsaved Changes, or Save Error. Workspace,
section, and field indicators use shared `RecordValidation`; no UI validation
engine was introduced.

### Relationships and Connections

Relationships and Family have dedicated shared-link workspaces. Authors can
search existing Characters through Universal Search, select a shared connection
type, add metadata, edit relationships, and remove links. Cards display target,
type, status, strength, and direction. Relationship mutations use
`CharacterService` and `ConnectionEngine`, retaining temporal/version history.

Other connection-backed sections use one reusable panel over Universal Inspector
references. It displays incoming/outgoing direction, type, target, and navigates
to the existing Manuscript, Timeline, Story Codex/World, or Plot Studio route.

### Goals, Arc, Timeline, Manuscript, Codex, and World

- Goals and motivations use structured reusable items plus psychology fields.
- Character arcs use structured starting state, turning points, choices,
       consequences, and end state items.
- Timeline displays shared event references and opens Timeline Studio.
- Manuscript displays Scene/Chapter/Book references and opens Manuscript Studio.
- Codex and World display shared references and open the existing connected
       World/Story Codex route.

Creation and detailed editing of Timeline, Manuscript, Codex, World, and Plot
records remain with their owning Studios. Character Studio navigates to those
owners rather than duplicating their editors.

### Inspector, History, and Branches

View Inspector opens a Character-filtered `UniversalRecordInspector` summary.
View History reads shared versions, dates, change types, audit counts, and
read-only snapshots.

When a branch context is supplied, the header names the branch and explains that
edits create an override. Autosave uses `BranchService.overrideRecord`; Canon is
not modified. Canon mode continues through canonical `RecordService` updates.

### Responsive and Keyboard Behaviour

The workspace supports large desktop, standard desktop, and narrower browser
widths. Roster/detail layout stacks below 820px; section navigation switches to
a compact selector below 760px. Mobile-specific optimisation is intentionally
outside Phase 2.

Keyboard traversal uses native Material controls, Enter advances or confirms
simple fields, Escape closes dialogs, and Ctrl/Cmd+S flushes character changes.

### Phase 2 Known Limitations

- Cross-Studio navigation currently opens the owning Studio; deep selection of a
       specific Scene/Event/Codex record awaits route-level selection contracts.
- Timeline event creation and manuscript scene editing remain in their owning
       Studios rather than embedded Character dialogs.
- Relationship history is available through shared audit/history views; a
       dedicated visual Friends-to-Rivals timeline is future polish.
- Portraits use local file references; managed asset copying/order metadata is
       still pending.
- Final graph visualisation, questionnaires, deterministic AI-free generators,
       and advanced statistics are later Character phases.
- No AI generation, marketplace, community, analytics, or paywall behavior was
       added.
