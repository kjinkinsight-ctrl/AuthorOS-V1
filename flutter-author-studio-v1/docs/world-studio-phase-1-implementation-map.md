# World Studio Phase 1 Implementation Map

Status: Domain foundation implemented and focused tests passing  
Audited: August 20, 2026  
Scope: World domain, hierarchy, spatial data, maps, routes, and shared-service integration

## Architecture

World Studio is a peer of Story Codex over the AuthorOS Universal Record architecture.
It does not own persistence, search, history, connections, validation, branches,
inspection, or deletion behavior.

```text
World UI / Character / Faction / Codex / Timeline / Manuscript
                              |
                        WorldService
                              |
 RecordService + TemplateEngine + ConnectionEngine + BranchService
 UniversalSearchService + VersionAuditService + UniversalRecordInspector
                         + SafeDeleteService
                              |
         AuthorRecord + RecordLink + shared Drift repository
```

`WorldService` is the domain facade. `WorldStudioService` remains the compatibility
adapter for the existing World UI and legacy `worldRecord` rows. New domain work uses
the universal service stack directly. Story Codex is optional enrichment, not a World
dependency.

## Record Types

`WorldRecordTypes` registers data-driven definitions in `BuiltInRecordTypes`.

- Cosmic: Universe, World, Planet, Moon, Star, Solar System, Galaxy, Dimension,
  Realm, and Plane.
- Political/geographic: Continent, Region, Country, Nation, Province, State,
  Territory, City, Town, Village, Settlement, District, and Neighbourhood.
- Built environment: Building, Structure, Room, Interior Location, and Landmark.
- Natural/historical: Natural Feature, Mountain, River, Lake, Ocean, Sea, Forest,
  Desert, Island, Cave, Ruin, and Battlefield.
- Network/boundary: Road, Route Location, Border, and Other Custom Location.
- Map: base Map plus World, Regional, Country, City, Building, Dungeon, Battle,
  and Custom Map.
- Route: base Travel Route plus Road, Path, Portal, Gate, Ferry, Bridge, Tunnel,
  Flight Path, Space Route, and Magical Route.
- Map Marker is a universal record with stable map and target record IDs.

Projects choose only the types they need. The registry, not a hard-coded database
hierarchy, controls availability.

## Templates And Dynamic Fields

The shared `RecordTypeDefinition`/`TemplateEngine` path provides Basic Location,
City, Country/Nation, Region, Building, Natural Feature, and World templates.
Each inherits common identity, environment, society, history, and secret fields.
Specialized templates add only their narrower fields.

Project templates are persisted shared definitions with project scope. They may
inherit Location, a location subtype, World, Map, or Travel Route. The service rejects
templates from another project or outside the World family.

Fields use the shared types: short/long/rich text, number, date, boolean, choices,
multi-choice, tags, references, lists, and structured tables. Definitions carry label,
order, required state, visibility metadata, and template ownership. Optional fields
avoid imposing Earth-based categories on every project.

Identity supports primary, alternate, historical, local, translated, nickname, type,
summary, description, notes, tags, scope, canon, and branch metadata. Alias fields are
marked searchable and use the universal FTS JSON projection.

## Hierarchy

`WorldHierarchy` derives parent, children, siblings, ancestors, descendants, root,
root World, and root Universe from shared records and `RecordLink` edges. It recognizes
child-to-parent `locatedIn`, `partOf`, and `inside` links plus parent-to-child
`contains` links. It stores no duplicate parent IDs.

`WorldService.setParent` rejects self-parenting, circular ancestry, non-spatial
endpoints, records outside the project, and incompatible branch views. Branch
hierarchy changes use `BranchLinkOverlay`; Canon links remain unchanged.

## Connections

`BuiltInConnectionTypes` now recognizes every spatial subtype for existing Character,
Faction, Timeline, and World relations. Missing shared types were added for containment,
adjacency, borders, distance/direction, access, crossing, maps, routes, governance,
headquarters, cultures, and Character current/previous/home/safehouse/favourite/
forbidden locations. Equivalent generic types such as `partOf`, `connectedTo`, and
`associatedWith` are reused instead of duplicated.

Temporal and route-capable edges support start/end date, distance, travel time,
difficulty, cost, danger, restrictions, conditions, and notes through shared metadata.

## Maps And Markers

Map records contain optional type, coordinate system, width, height, scale, center,
background reference, projection, and structured metadata. `maps` links associate a
map with a spatial record.

Map Marker records contain `mapId`, `recordId`, coordinates, label, icon, category,
visibility, and notes. `onMap` and `represents` links validate both stable IDs. No
location copy or map-specific database exists. Interactive drawing is outside Phase 1.

## Routes

Travel Route records contain stable start/end location IDs plus optional distance,
travel time, difficulty, cost, danger, restrictions, and conditions. `routeFrom` and
`routeTo` links validate endpoints through `ConnectionEngine`. Travel simulation is
outside Phase 1.

## Cross-System Integration

- Character locations use temporal shared links including `livesIn`, `bornIn`,
  `worksIn`, `currentlyAt`, and related location roles.
- Factions, governments, houses, organisations, guilds, and clans connect through
  controls, rules, headquarters, membership, and generic shared links.
- Culture, religion, language, magic, technology, lore, political systems, and
  artifacts remain Codex/universal records referenced by stable ID.
- Historical and Timeline records use `occursAt` and related temporal links. World
  Studio does not create a timeline store.
- Locations and Characters connect to Book, Chapter, and Scene records through shared
  manuscript links. Manuscript bodies remain owned by Manuscript Studio.

The reusable `WorldPhase1Fixture` proves one connected graph containing a Universe,
World, continent, two regions, two countries, three cities, multiple buildings,
ruler/resident/traveller, government/rebellion, culture/religion/magic/artifact,
three historical events, one book, two chapters, and three scenes.

## Shared Services

- Search: `UniversalSearchService`; no World index.
- Inspector: `UniversalRecordInspector`; no World Inspector.
- Version/audit: `VersionAuditService`; World CRUD, links, templates, archive,
  restore, and branch changes use shared history.
- Branches: sparse record/link overlays through `BranchService`; alternate worlds do
  not clone Canon graphs.
- Validation: `RecordValidator` plus hierarchy/map/route domain checks.
- Safe delete: `SafeDeleteService` reports child, Character, Faction, Timeline,
  manuscript, map, marker, route, branch, reference, and history dependencies exposed
  by the shared graph. World Studio performs archive/restore, not physical deletion.

## Legacy Compatibility

The existing `WorldStudioService`, `WorldTemplateRegistry`, widgets, and legacy
`worldRecord` read/upgrade path remain intact. Existing rows are still readable and are
upgraded by the established adapter when edited. Unknown fields and extension data are
preserved. No destructive migration or Drift schema change was introduced.

## Validation Coverage

Focused tests cover the complete type catalogue, seven built-in template families,
project custom template inheritance, CRUD/archive/restore/duplicate, hierarchy queries,
cycle/self/cross-project rejection, maps, markers, routes, Character integration,
search, Inspector, history, safe delete, sparse branch overrides, Canon isolation, and
the cross-system fixture. Existing World UI and shared-service suites remain regression
gates.

## Known Limitations

- The current World UI still uses the legacy adapter; polished hierarchy, map, route,
  Inspector, branch, validation, and dependency views are future UI work.
- Hierarchy queries currently materialize the project graph in memory. A future large-
  world UI should page records and bound traversal.
- Map/marker/route creation uses shared service calls but is not yet exposed as one
  multi-record transaction command.
- Legacy name-only references remain readable but require the existing migration
  workflow to resolve them to IDs; ambiguous names are not guessed.
- No graphical map editor, simulation, AI generation, graph visualization, 3D globe,
  sharing, marketplace, or premium content is included.

## Future World Studio UI

Phase 2 may bind `WorldService` to a hierarchy browser, dynamic record editor,
connection panel, map metadata/marker list, route list, Universal Inspector, history,
branch controls, validation feedback, and safe-delete analysis. It must continue using
the shared services and must not begin an interactive map editor implicitly.