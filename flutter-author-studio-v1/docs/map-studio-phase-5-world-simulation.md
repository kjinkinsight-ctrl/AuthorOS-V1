# Map Studio Phase 5 — Advanced World Simulation

Phase 4 taught the map to read the story. Phase 5 teaches it to read the
**world**: which settlements stand, who holds which ground, where the borders
run, which routes are open, how long a journey takes, and what all of that
looked like at some other point in the story.

The rule from Phase 4 carries over unchanged, and is the whole design:

> **Map Studio visualises world state. It never becomes the owner of world
> state.**

There is no world table, no world record type, no world persistence and no
second world model. A `MapWorldState` is computed on read from records, links
and manuscript nodes other Studios already own, and discarded when the view
rebuilds. `MapService` — the one write path — gained nothing this phase.

## What the world is made of, and where each part comes from

| Part of the world | Canonical source | Placed by |
| --- | --- | --- |
| Settlement | a location record on this map | its own stored map-space position |
| Territory | a region record on this map | its own geometry |
| Border | a `border` record on this map | its own geometry; `borders` links say what it runs between |
| Route | a route record | `routeFrom` / `routeTo` links, both ends on this map |
| Resource | a `resource` record | `locatedAt` / `contains` / `knownFor` to a placed location |
| Condition | a `climate` field, or a timeline record naming weather | the place it applies to |
| Holder | `controls`, `rules` or `governedBy` from a faction | — |

No new record type and no new edge type was introduced. A guardrail resolves
every id the world layer reads against `BuiltInRecordTypes` and
`BuiltInConnectionTypes`, so it cannot quietly acquire a vocabulary of its own.

## Two facts about the canonical layer that shaped the design

**`controls` carries no metadata.** It is the natural "who holds this" edge, but
its definition declares no metadata fields, so a `controls` link cannot carry
dates. `rules` and `governedBy` are open, temporal relationships that *do* carry
`startDate`/`endDate`. So the world layer reads all three: `controls` says who
holds something with no dates attached, and `rules`/`governedBy` say who held it
*between two dates*. That is what makes a border that moved in 417 show
correctly in 412 — without adding an edge type to hold a date.

**Dates arrive in several shapes.** Link metadata declares `startDate` as a date
field, but the value depends on who wrote it: a Timeline `TimelineDate` map, an
ISO-8601 string, or a plain year. `MapWorldClock.momentFrom` reads all three and
returns *no moment* for anything else, which is the honest answer.

## Time

The era control reads the world at a moment on the same clock Phase 4 uses
(`year × 100000 + month × 1000 + day`). A thing exists at that moment when its
span contains it, and an open-ended span is genuinely open: something with no
start date has always been there as far as the data says, and something with no
end date has not ended. The state reports itself as **Current**, **Historical**
or **Planned** by comparing the selected moment to the world's own latest.

## Travel

The travel calculator is deterministic and explainable, and it never invents a
number:

1. If the author recorded a travel time on the route, that wins — their world,
   their number. Season still applies, because they wrote a journey, not a
   winter journey.
2. Otherwise, if the route records a distance:
   `days = distance ÷ mode daily range × route factor × terrain factor × season
   factor`.
3. If it records neither, that leg cannot be travelled. The estimate comes back
   **unavailable**, with the reason.

Terrain comes from the painted Phase 3 grid where there is one — the ground the
author painted is the ground the traveller crosses. Modes are restricted to ways
they can actually use: a ship does not take a road, a cart does not take a
mountain pass, and the calculator says "no route" rather than routing around the
problem. Routing is Dijkstra over the routes that exist at the selected moment,
with ties broken by route id so the same world always yields the same road.

Every answer carries its working:

```
The Vey Road: 120 miles ÷ 30 per day × 1.0× road = 4 days
The Marsh Road: 150 miles ÷ 30 per day × 1.0× road = 5 days
Total: 9 days (on foot)
```

## Queries

- **Held by** — every territory and settlement a faction holds at this era.
- **Routes between** — the direct ways, plus the shortest journey with its
  working.
- **Visited by** — delegated to the Phase 4 journey projection rather than
  reimplemented: "where has this character been" has one answer in the codebase.
- **Scenes in** — scenes set at places inside a territory.
- **Affected by** — the places an event is linked to.

A query that finds nothing says so plainly ("No holding is recorded for House
Noxmere at this point in the story") rather than returning an empty list that
reads like an answer.

## Draw order

`MapLayer` remains the single declared order, walked by the canvas:

```
base → terrain → regions → borders → assets → worldRoutes
     → locations → markers → storyPaths → storyOverlays
     → selection → interaction
```

Borders sit over the ground they divide and under the things that stand on it.
Routes sit over the scenery and under the places they join. Route kind is
carried by dash pattern as well as weight, so a hidden path and a king's road do
not read alike in greyscale.

## What proves it

- `test/map_world_test.dart` — 30 tests: measurement and date parsing, the
  clock, holders and dated holdings, disputed ground, historical state,
  reproducibility, routes scoped to one map, resources, project isolation, the
  travel rules above (including every refusal), the queries, and a full database
  snapshot proving a read changes nothing.
- `test/map_world_view_test.dart` — 10 behaviour tests through the Studio: the
  panel and its counts, an undated map, era stepping, layer toggles, travel with
  and without data, queries and their empty case, a snapshot across every
  control, and Phases 1–4 still working underneath.
- `test/map_architecture_test.dart` — 9 Phase 5 guardrails: no second world
  model, read-only by construction, a deterministic Flutter-free domain,
  canonical links, canonical types, project scoping, travel refuses rather than
  fabricates, the view writes no world data, and Phases 3–4 intact.

## Phase boundary

**Phase 6 was not started.** No presentation mode, no themes, no decorations, no
label system, no export, no print layout, no reader maps, no spoiler filtering
and no sharing. The phase-boundary guardrail now defends Phase 6 and later.
