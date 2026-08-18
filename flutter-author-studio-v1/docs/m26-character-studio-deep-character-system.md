# M26 - Character Studio: Deep Character System

Status: Required implementation directive  
Product: AuthorOS 2.0  
Core posture: AI-free, local-first, connected, series-aware, and author-controlled

> **DO NOT SIMPLIFY CHARACTER STUDIO.**
>
> Character Studio is intended to be one of the deepest systems in AuthorOS. Do not reduce the character model to Name, Age, Description, Appearance, and Notes. Preserve and implement the full character-development architecture described in this directive.
>
> Before making any changes, inspect the existing Character Studio implementation and recover every existing template, field, component, service, API, generator, and function. Do not delete existing functionality because it is not immediately required for the first UI pass. Do not replace structured character information with generic text fields. Do not create isolated character data that bypasses Universal Records or the Connection Engine.
>
> Character Studio must ultimately function as a complete connected character-development system across manuscript, world, relationships, timeline, plot, series, maps, and visual boards.
>
> **The goal is to restore depth, not simplify it.**

## 1. Purpose and scope

Character Studio is a focused workspace over canonical character `AuthorRecord` instances, typed `RecordLink` connections, manuscript nodes, and linked assets. It is not a second character database.

The explicit M26 scope is:

**Identity -> Portrait -> Appearance -> Personality -> Psychology -> History -> Goals -> Motivation -> Fears -> Secrets -> Character Arc -> Voice -> Dialogue -> Relationships -> Scenes -> Chapters -> Timeline -> Locations -> Factions -> Items -> Plot Threads -> Notes -> Statistics -> Templates -> Questionnaires -> Generators -> Connections -> Series -> Branches -> Custom Fields.**

The core system must work without generative AI. Deterministic generators may use authored prompts, rules, weighted tables, versioned pools, and saved seeds.

## 2. Existing implementation audit

This mapping records the implementation surface found before M26 planning. Re-audit it immediately before implementation because the codebase may have moved.

| Existing feature | Existing data or behavior | Existing UI or service | M26 destination |
|---|---|---|---|
| Starter character sheets | `StarterCharacterSheet.name` and `role` inside `StarterProject.characterSheets` | Onboarding starter-project creation | Migration input and lightweight creation preset; never the canonical M26 model |
| Character board | Name, role, inferred category, and in-memory active/archive status | `CharacterBoardView` in `release_destinations.dart` | Character dashboard and searchable roster backed by canonical records |
| Story Codex characters | Stable Codex ID, title, aliases, summary, tags, name-based relationship map, archive state | Story Codex editor, cards, search, and archive/restore | Migrate into schema-driven character records and typed links |
| Scene relationships | Typed scene relationship with target ID and label | Manuscript scene relationship editor | Canonical Character <-> Scene links and derived appearances |
| Timeline participation | `presentCharacters`, POV, location, and event chronology | Timeline state and timeline view | Character <-> Timeline Event links and derived chronology |
| Continuity checks | Unknown character, absent POV, overlap, and travel findings | `ContinuityAnalyzer` | Evidence-backed character continuity using canonical IDs |
| Impact tracing | Character entities and scene-derived relationship counts | `ImpactTraceAnalyzer` | Character statistics and connection graph queries |
| Connected domain | `AuthorRecord`, scoped fields, status, revisions, tags, extension data | In-memory and Drift repositories | Canonical character persistence and Character service foundation |
| Connection model | Directed/undirected `RecordLink`, metadata, backlinks, revisions | Connected-domain repositories and migration adapter | All character relationships and cross-studio connections |
| Character-scene migration slice | Converts a Codex character and scene relationship to a canonical record and link | `LegacyConnectionSliceAdapter` behind a feature flag | Expanded, reversible migration for all character sources |
| Search | FTS over record titles, fields, and tags | Drift connected-domain repository | Character search, notes search, and record picker |
| Archive and recovery | Canonical record status, portable archive, and restoration tests | Archive/database repositories | Non-destructive archive, restore, and deletion impact workflow |

Audit conclusion at the time of this directive:

- No complete prior deep Character Studio implementation was found in repository history.
- The current Character board is a shallow, transient presentation over starter sheets.
- Character information is split among starter sheets, Story Codex entries, scene relationships, timeline names, continuity inputs, and the newer connected-domain model.
- Existing working behavior must be migrated or adapted. It must not be deleted while replacing the board.
- Name-based references are legacy migration inputs, not the final connection model.

## 3. Canonical character record

A character is one deep Universal Record with stable identity, explicit scope, structured typed fields, custom fields, assets, and typed links. The model must preserve unknown future fields and support schema migration.

### 3.1 Identity

- Character ID
- Full, first, middle, and last names
- Nicknames, titles, and aliases
- Pronouns
- Age and date of birth
- Place of birth
- Species or race
- Nationality or culture
- Occupation
- Status
- Affiliations

Names and aliases are display/search data. Links must use stable IDs and must survive renaming.

### 3.2 Portrait and references

- Primary portrait
- Ordered additional reference images
- Portrait metadata
- Replace and remove operations
- Image ordering

Images are linked asset records or asset references owned by the character record. They are not decorative widget-only state. Removal must respect archive and asset-reference policies.

### 3.3 Appearance

Provide structured fields and freeform notes for:

- height, build, and body type
- hair and hair colour
- eye colour and skin tone
- distinguishing features, scars, tattoos, and birthmarks
- clothing and accessories
- weapons or items commonly carried
- general appearance notes

Do not collapse these fields into one generic Appearance box.

### 3.4 Personality

- Personality summary
- Core, positive, and negative traits
- Strengths and weaknesses
- Habits, mannerisms, and quirks
- Likes and dislikes
- Values, beliefs, and morals
- Temperament and emotional tendencies
- Social behaviour
- Author-defined personality fields

### 3.5 Psychology and internal life

- Core desire
- Primary and secondary motivations
- Fears and phobias
- Insecurities
- Internal and external conflicts
- Emotional wounds
- Secrets, shame, and guilt
- Needs and wants
- Beliefs and misbeliefs
- Personal values and boundaries

These are author-controlled creative fields. AuthorOS must not present them as generated psychological diagnoses.

### 3.6 History

- Childhood and family background
- Education
- Significant events and important memories
- Trauma or other author-defined formative events
- Relationships
- Previous occupations
- Major life changes and historical milestones

History entries may link to canonical Timeline Events and Locations:

```text
Character -> Life Event -> Timeline Event -> Location
```

### 3.7 Goals and motivation

- Primary and secondary goals
- Short-term and long-term goals
- External and internal goals
- Motivation
- Obstacles
- Stakes and consequences
- Goal status

Goals may connect to Plot Threads and Character Arcs through typed links.

### 3.8 Character arc

An arc is a structured, configurable sequence, not one text box. A default sequence may be:

```text
Beginning -> Initial State -> Inciting Change -> Pressure -> Conflict
          -> Turning Point -> Transformation -> Final State
```

Support:

- Arc type and status
- Starting and desired states
- Configurable stages
- Major turning points
- Internal and external changes
- Lessons, failures, victories, and setbacks
- Resolution
- Stage links to chapters, scenes, and timeline events

### 3.9 Voice and dialogue

- Voice description
- Speech style and vocabulary
- Formality
- Accent or dialect notes
- Sentence patterns
- Favourite expressions
- Verbal habits
- Things the character would never say
- Dialogue examples
- Internal voice notes

Voice is author reference information. AI generation is never required.

### 3.10 Notes

- General notes
- Research notes
- Revision notes
- Continuity notes
- Scene ideas
- Dialogue ideas
- Author-only notes

Notes must be searchable and obey the record's scope, privacy, archive, version, and export rules.

## 4. Connected character domains

All connections use the shared Connection Engine. Character Studio must not create a character-only graph store.

### 4.1 Relationships

A relationship is one canonical connection or relationship record visible from both participants:

```text
Character A <-> Relationship <-> Character B
```

Built-in types include family, romance, friendship, rivalry, alliance, enemy, mentor, student, employer, employee, political, faction, and custom. Each relationship supports type, status, beginning, development, major changes, current state, ending, notes, validity range, and history.

### 4.2 Manuscript appearances

Character Studio derives appearances from live links to books, chapters, and scenes. It surfaces POV scenes, mentioned scenes, major scenes, first appearance, and last appearance. These lists must never be manually duplicated into the character payload.

### 4.3 Timeline

Display birth, major life events, relationship events, arc events, story events, death, disappearance, and status changes where relevant. Navigation is bidirectional between Character and Timeline Event.

### 4.4 Locations

Support typed connections such as `livesIn`, `bornIn`, `worksIn`, `hasLivedIn`, `visits`, `owns`, `hasMemoryAt`, and `appearsIn`. Scene-derived location appearances are calculated rather than copied.

### 4.5 Factions and organisations

Support membership, leadership, employment, allegiance, former membership, rival affiliation, and secret affiliation, with joined/left dates, current status, rank, role, and notes.

### 4.6 Items and possessions

Support `owns`, `carries`, `uses`, `inherited`, `stole`, `lost`, `gaveAway`, and `received`. Item history remains in World Studio and is visible through links.

### 4.7 Plot threads and arcs

Goals, conflicts, appearances, and arc stages may connect to canonical Plot Threads. Character Studio presents those links but does not own duplicate plot records.

## 5. Dashboard, navigation, graph, and statistics

The Character dashboard provides portrait, identity, primary goal, motivation, current arc state, current status, and live counts for relationships, scenes, locations, factions, plot threads, and timeline events.

Required detail destinations are Profile, Appearance, Personality, Psychology, History, Goals, Fears, Secrets, Arc, Voice, Relationships, Scenes, Timeline, Locations, Factions, Items, Plot Threads, Notes, Connections, Statistics, and Version History. Information architecture may group these destinations responsively, but it must not remove their data or capability.

The connection view is a saved view over shared records and links. Selecting a character reveals connected characters, relationships, scenes, chapters, timeline events, factions, locations, items, and plot threads. Layout coordinates belong to the saved view, not the character record.

Statistics are derived from canonical records and links:

- appearances, POV scenes, and chapters
- relationships, locations, factions, and plot threads
- first and last appearances
- timeline events
- arc progress

## 6. Templates, questionnaires, and generators

### 6.1 Templates

Ship schema-driven templates without creating separate data models:

- Standard Character
- Protagonist
- Antagonist
- Supporting Character
- Romance Character
- Villain
- Custom Character Template

Templates add or emphasize fields such as central goal, conflicts, stakes, transformation, ideology, philosophy, methods, resources, threat, weakness, attraction, compatibility, relationship milestones, function, story role, and scenes. Authors can create, version, duplicate, import, and export custom templates.

### 6.2 Questionnaires

Structured questionnaires cover Identity, Values, Fear, Desire, Secret, Relationship, and Conflict. Answers populate mapped character fields only after clear author action. Unmapped answers remain linked questionnaire responses and are never silently discarded.

### 6.3 Deterministic AI-free generators

Use the shared Generator Framework rather than hard-coded random widget functions. Support name, trait, appearance, personality, motivation, fear, goal, conflict, relationship, backstory, and archetype generation plus custom author-defined pools.

Every generated result records generator version, source pool versions, seed, and author acceptance state so the same inputs reproduce the same output. Generated suggestions never overwrite authored data without confirmation.

## 7. Series, versions, branches, and custom fields

### 7.1 Series-aware identity

One canonical series- or universe-scoped character can appear in multiple books. Do not duplicate the character per book. Book-specific state, annotations, appearances, and arc stages remain scoped to the relevant project.

### 7.2 Version and branch awareness

Character data must participate in Version History, What-If branches, Alternate Universes, and canon selection. Branch-specific character state must not mutate canonical state. Merge and conflict behavior must preserve both versions until the author resolves them.

### 7.3 Custom fields

Authors can add schema-backed fields of these types:

- Text and long text
- Number
- Date or fictional date
- Boolean
- Select and multi-select
- Relationship
- Record reference and record-reference list
- Image or asset reference
- URL
- Rating

Custom fields use the same validation, search, archive, migration, version, and export rules as built-in fields.

## 8. Character service boundary

Expose character behavior through a dedicated application service over Universal Records, assets, manuscript nodes, search, and the Connection Engine. The service conceptually supports:

```text
createCharacter
getCharacter
updateCharacter
archiveCharacter
restoreCharacter
deleteCharacter
duplicateCharacter
searchCharacters
getCharacterRelationships
getCharacterScenes
getCharacterTimeline
getCharacterLocations
getCharacterFactions
getCharacterItems
getCharacterThreads
getCharacterStatistics
getCharacterHistory
```

The service must enforce IDs, scopes, revisions, schema validation, link integrity, branch context, and transactional persistence. Flutter widgets must not write independent character stores or bypass repositories.

## 9. Data ownership and deletion safety

Deleting a character must not automatically delete scenes, chapters, timeline events, locations, relationships, plot threads, factions, or items.

Before destructive removal, AuthorOS must:

1. Calculate incoming and outgoing links, mentions, branch references, and asset references.
2. Present affected records grouped by type and scope.
3. Offer archive, cancel, relink, detach, preserve-as-unresolved, or confirmed removal where valid.
4. Preserve an auditable recovery path according to archive and backup policy.
5. Commit record, link, index, and asset-reference changes transactionally.

Archive is the default removal action. Hard deletion is a deliberate, separately confirmed operation.

## 10. Implementation sequence

1. Re-run and record the character audit; freeze destructive changes until migration coverage exists.
2. Define versioned character schemas, templates, link types, and branch-aware annotations over the shared domain contracts.
3. Expand reversible migration from starter sheets, Story Codex, scene relationships, timeline names, and legacy relationship maps.
4. Implement the Character service and repository queries before wiring new widgets.
5. Build dashboard and structured editors over the service, including empty, loading, error, archived, unresolved-link, and conflict states.
6. Add live manuscript, timeline, world, relationship, graph, and statistics views.
7. Integrate shared templates, questionnaires, and Generator Framework.
8. Enable series scope, branches, import/export, and deletion-impact workflows.
9. Remove legacy stores only after migration evidence proves no content or behavior is lost.

## 11. Completion tests

### Basic lifecycle

- Create, edit, save, reload, archive, restore, delete, and duplicate a character
- Search by name, alias, tags, structured fields, custom fields, and notes
- Export and import with stable IDs, fields, links, assets, and versions intact

### Deep data

- Identity, portrait, appearance, personality, psychology, history, goals, motivation, fears, secrets, arc, voice, dialogue, and notes
- Every supported custom field type and unknown-field preservation
- Image replacement, removal, ordering, metadata, and archive round trip

### Connections

- Character <-> Character
- Character <-> Scene and Chapter
- Character <-> Timeline Event
- Character <-> Location
- Character <-> Faction or Organisation
- Character <-> Item
- Character <-> Plot Thread
- Bidirectional backlinks, rename stability, archived targets, and unresolved links

### Series and branching

- One canonical character across multiple books and a shared universe
- Book-specific development without record duplication
- Canon state, alternate state, branch isolation, merge conflict, and recovery

### Templates and generators

- Standard, Protagonist, Antagonist, Supporting, Romance, Villain, and Custom templates
- Trait, appearance, personality, motivation, goal, conflict, relationship, backstory, archetype, name, and custom-pool generators
- Identical output for identical generator version, pool versions, and seed

### Data safety and migration

- Legacy starter, Codex, scene, timeline, and relationship data migrates without loss
- Character deletion never cascades into connected creative records
- Deletion impact counts and choices are correct at project, series, and universe scopes
- Failed migration or transaction leaves the prior project usable

## 12. Exit gate

M26 is complete only when:

- no duplicate character store remains
- all structured character domains in this directive persist and round-trip
- connections are canonical, ID-based, live, and bidirectional
- series and branch isolation are demonstrated
- deletion is impact-aware and recoverable
- templates and deterministic generators are extensible and reproducible
- focused Windows and Android tests pass
- migration fixtures prove existing character behavior and data were preserved

A visually complete form backed by starter sheets, name maps, widget state, or generic text fields does not satisfy M26.