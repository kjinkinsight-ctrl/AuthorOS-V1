# Map Studio Phase 6 — Presentation, Export & Sharing

Phases 1–3 built the map, Phase 4 put the story on it, Phase 5 made the world
behave. Phase 6 turns all of that into something an author can show someone: a
titled, themed map, filtered for a reader, written out as a file.

The rule the phase is built on:

> **Phase 6 is a projection of Phases 3–5 and the canonical record layer. It
> creates no second representation of the world, and it writes nothing.**

`MapCanvasData`, `MapOverlayData`, `MapWorldState`, `MapProjection` and the
record/relationship layer stay authoritative. Presentation, reader filtering and
export are readings of them. Two snapshot tests drive every control — theme,
decorations, reader level, present, export in four formats — and assert the
database is byte-identical afterwards.

## One drawing, four renderers

```
MapCanvasData ┐
MapOverlayData├─▶ MapDrawingBuilder ─▶ MapDrawing ─┬─▶ MapSvgRenderer
MapWorldState ┘         ▲                          ├─▶ MapPdfRenderer
MapPresentation ────────┘                          ├─▶ MapPngRenderer
                                                   └─▶ MapDrawingPainter (screen)
```

`MapDrawingBuilder` is the only thing that decides where anything goes. Every
renderer paints the same primitive list, so the preview an author looks at and
the file they send a printer cannot disagree — not because a test compares them,
but because there is one picture and four painters.

PNG lives in `map_presentation_view.dart` because rasterising needs `dart:ui`;
the rest of the export domain stays free of Flutter. Colour arrives as plain
ARGB integers resolved from the Theme Engine, so no Map Studio file names a
colour, exactly as since Phase 3.

## What the canonical model could not supply

Three gaps, found by the audit and **reported rather than invented**:

| Wanted | Canonical state | What Phase 6 does |
| --- | --- | --- |
| Real-world scale | the map record declares `coordinateSystem` but no units-per-distance ratio | draws the bar in map units, labelled with the coordinate system's own name, and reports the gap |
| Series title | `series` is a declared record type that no Studio creates | omits the line; uses a series record if one ever exists |
| Reveal points | `revealedIn` exists and nothing writes it | reads what is there; reports that no Studio authors them |

Each is surfaced in the export dialog as a `MapPresentationGap`, so an author
sees why an element is missing instead of finding a blank corner.

## Reader maps and spoilers

Spoiler level is a position in the manuscript, read from `revealedIn` links to
chapters and scenes and ordered by the manuscript's own ordering. Filtering
happens in the **model**:

```
MapReaderProjection.apply(level, canvas, overlays, world, revealed)
    → a smaller MapCanvasData, MapOverlayData and MapWorldState
```

A renderer handed a reader view cannot leak a hidden city, because the city is
not in the data it was given. Three rules fall out of that and are each pinned
by a test:

- An entity with **no** reveal point is shown only in the author's own view.
  "The author never said when this becomes known" is not evidence it is safe.
- An overlay anchored at a hidden place is hidden too, whatever its own reveal
  says — otherwise the character gives away where the city is.
- A route is drawn only when **both** ends are visible. Half a road pointing off
  the edge is itself a spoiler.

**The consequence, stated plainly:** nothing in AuthorOS writes `revealedIn`
today, so on a project that has never authored a reveal, every level below "full
story" shows nothing. That is correct for a spoiler filter and confusing for an
author, so `MapReaderView.notice` says which link is missing rather than
reporting an empty map.

## Export

| Format | Produced by | Notes |
| --- | --- | --- |
| PNG | `MapPngRenderer` | headless `PictureRecorder`; no widget need be mounted |
| SVG | `MapSvgRenderer` | hand-written, deterministic, no new dependency |
| PDF | `MapPdfRenderer` | `package:pdf`, already in the tree |
| JSON | `MapJsonExporter` | the projections, serialised; no schema of its own |

Presets are Screen, Web, Print, Book, Poster and Presentation, carrying page
size, DPI and margins. **Every preset produces sRGB.** AuthorOS performs no
colour-space conversion, so no preset claims CMYK — a guardrail fails the build
if one ever does.

Saving goes through the existing `ExportFileSaver`, widened from `savePdf` to
`saveBytes` with `savePdf` delegating, so the manuscript exporter is unchanged.
It works on the web build as well as desktop: `file_selector_web` returns a
placeholder location and `XFile.saveTo` triggers a browser download.

## What looking at the output changed

The exports were generated and inspected, not merely asserted. Five defects that
every test had passed:

1. **A lattice of seams across the whole map.** Translucent terrain cells that
   merely abut are blended twice along their shared edge. Fixed by merging
   same-kind cells into rectangles — which also took the SVG from 223 KB to
   6 KB, and the drawing from 2,334 primitives to 39.
2. **A territory drawn as a diagonal line.** `MapGeometry.box` stores two
   corners; drawn as a polygon that is a line. `asPolygon()` already existed.
3. **Four of six places unlabelled.** The label planner gates by camera zoom,
   and an export has no zoom. Detail is now a property of the surface: a printed
   map shows every name that fits.
4. **Place names printed under story badges.** Labels now sit below the pin,
   badges above, and every badge is registered as an obstacle the planner avoids.
5. **The PDF ignored transparency.** `setFillColor` carries an alpha channel
   that PDF discards; real transparency is a graphics state. Without it a region
   wash printed as a solid block hiding the terrain — the PDF and the SVG
   disagreeing, which is the one thing this architecture exists to prevent.

A sixth was a measurement artefact worth recording: `flutter test` loads no real
font, so a test-generated PNG renders every glyph as a filled box. The preview
loads a real face before drawing; the application uses the platform's fonts.

## What proves it

- `test/map_export_test.dart` — 18 tests over the drawing and the four
  renderers, ending with the one that writes real artifacts to `MAP_PREVIEW_DIR`
  for inspection.
- `test/map_reader_test.dart` — 13 tests over reveal points, spoiler levels, the
  reader projection's three withholding rules, and the presentation service's
  canonical reads and reported gaps.
- `test/map_presentation_view_test.dart` — 12 behaviour tests through the
  Studio: themes, decorations, presentation mode, its accessible description,
  export in each format through a fake saver, reader filtering proving a hidden
  city never reaches the exported bytes, and a database snapshot across the lot.
- `test/map_architecture_test.dart` — 9 Phase 6 guardrails: no second
  representation, read-only by construction, filtering enforced in the model,
  `revealedIn` never written, one drawing per renderer, one saving abstraction,
  the domain free of Flutter, no false colour-space claim, and Phases 3–5 intact.

Three earlier guardrails fired and were **narrowed rather than weakened**: the
"no asset fetching" rule banned the substring `http`, which SVG's namespace URL
contains; the routing rule banned all `Navigator` use, when the invariant is
about leaving Map Studio, not about its own presentation route; and the phase
boundary moved from "no Phase 6" to "no Phase 7", as it has every phase.

A fourth was right about the code, not the test: constructing an empty
`MapWorldState` in the view to satisfy the reader projection is building a world
in a widget. `MapReaderProjection.apply` now takes both projections as optional.

## Phase boundary

**No Phase 7 was started.** No community, no marketplace, no collaborators, no
comments, no publishing to a platform AuthorOS does not have. §33–34's sharing
and embedding are prepared as an abstraction — `MapExportRequest` and
`MapDrawing` are the surface a reader portal would consume — and no platform
infrastructure was invented to go with them.
