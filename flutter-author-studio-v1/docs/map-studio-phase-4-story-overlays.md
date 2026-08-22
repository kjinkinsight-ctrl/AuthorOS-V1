# Map Studio Phase 4 — Story, Character and Timeline Overlays

Phase 1 gave Map Studio places. Phase 2 made them editable. Phase 3 made the
world look like a world. Phase 4 puts the *story* on it: the characters, the
events, the scenes and the journeys AuthorOS already knows about, drawn over the
map that already exists.

The whole phase rests on one rule.

> **An overlay is a reading of canonical data, never a copy of it and never a
> second place where the story lives.**

There is no overlay table, no overlay record type, no overlay persistence and no
second world model. Everything Phase 4 draws is computed on read from records,
links and manuscript nodes that other Studios wrote, and is discarded when the
view rebuilds. Turning an overlay off changes what is drawn and nothing else.

## What is on the map, and why it is there

| Overlay | Comes from | Placed by |
| --- | --- | --- |
| Location | a World-domain location record already on this map | its own stored map-space position |
| Character | a `character` record | a `locatedAt` or `livesIn` link to a placed location |
| Event | any timeline record type (`timeline-event`, `timeline-battle`, `timeline-founding`, …) | an `occursAt` or `locatedAt` link to a placed location |
| Scene | a manuscript node (`scene`, `chapter`) | a `locatedAt` link to a placed location |
| Journey | dated events a character is `involves`d in | the stops those events already occur at |

Nothing is placed by guesswork. A character with no link to a place is not put
somewhere plausible — they are **counted as unmapped and reported**, because
silently dropping them would look like they do not exist and inventing a
position would be a claim the story never made. The same holds for dates: an
event with no start date is given no moment, and is therefore never hidden by
the story clock.

## Where each piece lives

| File | Role |
| --- | --- |
| `lib/map_overlays.dart` | The overlay vocabulary. Plain Dart, no Flutter: kinds, moments, items, clusters, journeys, the filter, and the projected data set. |
| `lib/map_overlay_service.dart` | The projection. **Read-only by construction** — it has no create, update or delete method and never opens a write path. |
| `lib/map_studio_view.dart` | The presentation: two new draw layers, the overlay panel, the story clock, the legend, search, focus and the way back to the owning Studio. |

`MapService` gained nothing. Phase 4 adds no write of any kind, so the one write
path established in Phase 1 is exactly as wide as it was.

## Draw order

`MapLayer` remains the single declared order, walked by the canvas rather than
hand-stacked:

```
base → terrain → regions → assets → locations → markers
     → storyPaths → storyOverlays → selection → interaction
```

Story paths sit beneath the overlays whose stops they join; both sit above the
world they are read against and below selection, which must stay visible
whatever else is on the map.

## The story clock

The timeline control is a question about the view, never a change to the story.

- **Whole story** — no moment is set; everything dated or undated is drawn.
- **A moment** — the map stands at one point on the clock. The past stays by
  default (history is what a map is good at showing), the future is hidden until
  the author reveals it, and undated overlays are always drawn.
- **Story moment mode** — stand at one moment with neither past nor future: what
  the world looked like then, and only then.

Moments come from each event's own `start` date, flattened to a sortable key
(`year × 100000 + month × 1000 + day`) and a label. Timeline Studio owns
calendars; the overlay layer only orders what it is given.

## Character journeys

A journey is derived, never stored. It is built from the dated events a
character is linked to, at locations that are on this map, in story order. Two
such stops are needed before a line is drawn — the map joins the points the data
gives it and never invents a third. Where a character went between two stops is
not something the story said, so the map does not say it either.

## Reading without colour

Every overlay category is distinguished by **shape and text**, not colour alone:
a person glyph for characters, a marker for locations, a triangle for events, an
open book for scenes, each named in the overlay key. Overlays sharing a position
cluster into one badge with a count, so a crowded city stays reachable instead of
hiding all but the last arrival. Every overlay and cluster carries a semantic
label naming what it is, where it is and when it happens.

## Getting back to the story

Selecting an overlay opens a detail panel that *reads* the record and offers the
way back to the Studio that owns it — Character Studio, Timeline Studio, the
Manuscript, the World Board. Map Studio names a destination
(`MapStudioDestination`) and the application shell decides what that means; the
Studio routes nothing itself and knows nothing about the navigation surface
hosting it.

## What proves it

- `test/map_overlay_test.dart` — 21 tests over the domain and the projection,
  including: a character stands where the story put them; an unlinked character
  is counted, not invented; an undated event gets no moment; a scene reaches the
  map as a manuscript node and never becomes a record; a journey is the dated
  events in order; another project never reaches this map; an archived character
  leaves it; **and a full database snapshot taken before and after loading
  overlays is byte-identical.**
- `test/map_overlay_view_test.dart` — 15 behaviour tests driven through the
  Studio, including filtering, the story clock, story moment mode, journeys,
  search and focus, navigation to the owning Studio, and a snapshot proving that
  every overlay control leaves the database untouched.
- `test/map_architecture_test.dart` — the Phase 4 guardrails: the overlay layer
  owns no data, the service is read-only by construction, the domain stays free
  of Flutter, every link type and record type it reads is one AuthorOS already
  defines, scenes stay manuscript nodes, the Studio routes nothing itself, and
  Phase 3 is still standing underneath.

## One fix beyond the overlays

Map Studio sits inside a scrolling page, and a scroll view accepts a vertical
drag sooner than an ordinary pan does. A mostly-vertical drag over the canvas
was therefore taken by the page: the pin the author grabbed did not move.
`_MapPanRecognizer` accepts at the same distance the page does, so the pointer's
own target wins — ground, pins, regions, scenery and geometry handles alike.
This was latent before Phase 4 and is fixed here.
