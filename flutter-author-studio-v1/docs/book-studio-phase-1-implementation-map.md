# Book Studio Phase 1 Implementation Map

## Scope

Book Studio Phase 1 is the Format, Design, Preview and Export stages of the
publishing pipeline. It adds a book model, a format preset system, a layout
engine, an on-screen page preview, and print-ready PDF export. It does not add
a record type, a database table, a second persistence system, or an export
format other than PDF.

Before this milestone the entire publishing surface of the app was
`lib/manuscript_export.dart`: three presets that handed the whole manuscript to
`package:pdf` as a single `pw.Text`, so every line and page break was decided
inside a library and nothing on screen could see them. That exporter still
exists and is unchanged; it serves a different job, exporting a working draft
for a beta reader.

## Architecture

Book Studio is a reader of the manuscript and an owner of presentation.

```
ManuscriptProjectSummary ─┐
                          ├─▶ BookDocumentBuilder ─▶ BookDocument
BookProject ──────────────┘                              │
                                                         ▼
                                                 BookLayoutEngine
                                                         │
                                                  PaginatedBook
                                                         │
                                     ┌───────────────────┴──────────────────┐
                                     ▼                                      ▼
                              BookPdfRenderer                        BookPagePainter
```

Three shapes, and the distinction between them is load-bearing:

- **`BookProject`** is what the author owns and what is persisted: metadata,
  the front and back matter they chose, their parts, and their format.
- **`BookDocument`** is derived and never persisted: the manuscript and the
  book settings flattened into one reading order. Keeping it a separate stage
  is what will later let EPUB and DOCX consume the book's structure without
  inheriting a print layout's fixed pagination.
- **`PaginatedBook`** is the laid-out book: pages of positioned elements.

`BookLayoutEngine.layout` is a pure function. The same document and format
always produce the same `PaginatedBook`, which is what makes the master plan's
"exports are reproducible from a frozen manuscript snapshot" a test rather than
an aspiration.

The layout engine decision is recorded in
[ADR-0006](architecture/ADR-0006-book-layout-engine.md), which resolves the open
item in `docs/authoros-2-master-plan.md` §18.

## Ownership

Book Studio owns only presentation. It owns no creative record, writes no link,
and creates no node.

It does not mutate the manuscript. `BookStore` writes one key of its own and
never a manuscript key, and the studio reads the manuscript through
`ManuscriptStore.readStudio`, a read-only path added for this purpose:
`loadStudio` seeds and persists a manuscript when a project has none, which is
right for the writing studio and wrong for a reader. A project that has never
been written in opens as an empty book rather than having one created for it.

## Why book data is not in the graph, and not in the database

`docs/universal-story-graph-architecture.md` §0 sets the membership test as
participation, not proximity: a thing belongs in the graph if the story is made
of it and it can be an endpoint of a `RecordLink`. A copyright page, an ISBN and
a trim size fail that test. Modelling them as records would also put
"Copyright (c) 2026" into Universal Search beside characters and locations, and
would write version history every time a margin moved — reopening the problem
decision D-2 was withdrawn for.

The registered-but-never-instantiated `book`, `chapter` and `scene` record types
stay uninstantiated. Decision **D-3** in
`docs/story-graph-phase-0-integrity-directive.md` keeps scenes and chapters as
manuscript-domain nodes, and D-1 — which would have made them records — is
withdrawn.

A new database table is ruled out by a test rather than by preference:
`test/story_graph_architecture_test.dart` pins the table set and fails any
addition with "that is a second persistence system". `AuthorOsDatabase.currentSchemaVersion`
stays **9**; this milestone adds no table and no migration.

Book settings therefore persist the way the prose itself does, as a JSON blob in
shared preferences at `author_studio.book_studio.{projectId}`, deliberately
mirroring `ManuscriptStore`'s studio key.

Two costs, stated rather than hidden:

- Book settings are outside the `.authoros` archive. This is structurally the
  same gap as scene prose (R-2 in the story-graph audit), not a new class of
  one. Closing it means adding a `data/book.json` entry, which changes the entry
  count that audit pins, so it lands with the doc amendment and the archive test
  together in a later phase.
- Book settings carry no version history. A margin is not creative corpus;
  dedication and acknowledgement text is, and it is mitigated by the `version`
  and `migration` fields `ManuscriptProjectSummary` already uses, plus a backup
  key written on first overwrite.

## Book model

`lib/book/book_document.dart`.

`BookSectionKind` covers front matter (half title, title page, copyright,
dedication, epigraph, contents) and back matter (acknowledgements, about the
author, other books, newsletter, custom). A `BookSection` carries a title, an
authored body, an order, and an `included` flag so a section can be switched off
without losing its text.

**Generated sections are not authored.** Title, half-title and copyright pages
render from the book's metadata; the contents is built from the body every time
the book is laid out, so it cannot go stale. Only dedication, epigraph and the
back-matter kinds carry free text.

**Title and author are stored as overrides, never as copies.** An empty override
resolves at build time from the manuscript title and the author profile. Storing
a copy would mean renaming a project kept printing the old title on the title
page and in every running head, and the author would not find out until a proof
copy arrived.

**Parts are ordering metadata, not nodes.** `BookPart.startsAtChapterId` names
an existing chapter, so chapters are never re-parented and every manuscript
operation keeps working untouched. It is also the forward-compatible shape:
when the story graph gains containment edges, that id becomes an edge with no
change to the model or the engine. A part whose anchor chapter was deleted is
skipped and reported as a `danglingPart` issue — never silently repaired, never
a crash.

## Format presets

`lib/book/book_format.dart`, plain Dart, no Flutter and no `package:pdf`, so the
whole preset table is unit-testable without a binding. Every measurement is in
PostScript points.

`BookFormat` composes `TrimSize`, `BookMargins`, `BookTypography`,
`ChapterStyle`, `RunningHead`, `PageNumbering` and `BookBreakRules`.

The six built-ins are Paperback, Hardcover, Large Print, Print-on-Demand, Ebook
and EPUB. Three of them make a point worth recording:

- **Large Print** is set ragged right, not merely bigger. Justifying large type
  on a narrow measure opens rivers, and accessibility guidance prefers a ragged
  edge.
- **Ebook** never starts a chapter on a recto. A blank verso is a print artefact
  that a reader on a screen experiences as a bug. `BookFormat.requiresRectoStarts`
  is what gates blank-page insertion, in the front matter as well as the body.
- **EPUB** is `reflowable: true` and is excluded from `BookFormatPresets.paginated`.
  It exists in the table so the preset list is complete; a reflowable format
  never drives a paginated export.

**A customised preset stores every resolved value, plus `basePresetId` for
provenance.** Not a preset id plus a diff: if only the difference were stored,
shipping a change to a preset default would silently reflow every existing
author's book. The provenance drives "modified from Paperback" and "reset to
preset".

## Layout engine

`lib/book/book_layout.dart`.

The measure is `trim − inside − outside` on both sides of the book: mirrored
margins swap which physical edge the binding allowance sits on, but not how wide
the text block is. Line breaking therefore does not depend on which side a page
is, which is what lets the engine paginate before it knows how long the front
matter is. Sides, folios and running heads are assigned in a final pass.

Rules implemented:

- **Line breaking** is greedy first-fit on measured advances, breaking at spaces
  only. No hyphenation.
- **Justification** distributes the residual into interword gaps as
  `wordSpacingPt`, never on a paragraph's last line. A line whose spacing
  exceeds `maxWordSpaceMultiple` is counted as a river — a purely metric,
  deterministic proofing signal.
- **Widows and orphans** are handled by laying a whole paragraph out and then
  choosing the split, so both rules are applied in one place rather than chased
  with a reflow afterwards.
- **Chapter openers** force a new page, or the next recto, inserting a genuine
  blank verso. Running heads and optionally folios are suppressed on openers.
- **Drop caps** reserve an n-line notch and narrow those lines' measure.
- **Ornaments** are drawn as vector paths, not typeset: neither bundled face
  carries ornament glyphs, so a character like U+2767 would render as tofu.

Two ordering problems and their resolutions are described in ADR-0006: the
print-on-demand gutter (bounded re-flow) and the table of contents (body
paginated first, in its own sequence).

## Preview and export

`BookPdfRenderer` and `BookPagePainter` consume `PaginatedBook` and only paint
it. Neither measures text: page furniture is positioned by the engine and
carried as `LaidOutPage.marginalia` in absolute page coordinates.

`test/book_layout_fidelity_test.dart` enforces this by scanning both renderer
sources with comments stripped, and by asserting that the PDF's page count, the
preview's page count and `PaginatedBook.pages.length` are the same number.

Export reuses the seams `lib/manuscript_export.dart` established but does not
alter its contract. `BookFileSaver` is a **new** interface:
`test/manuscript_export_test.dart` declares a fake that `implements
ExportFileSaver`, so adding any member to that interface would break it at
compile time. `NativeExportFileSaver` is untouched; `NativeBookFileSaver` is its
sibling. On web, `getSaveLocation` reports no destination and the file lands in
downloads, so an empty path means success, not failure — the same contract
`lib/manuscript_studio.dart` already documents.

## Fonts

Only Merriweather 400/700 and Inter 400/700 are bundled, both SIL OFL 1.1, which
permits embedding.

**Italic is not shipped**, and Phase 1 does not add it: the fonts were not
reachable from this environment's network policy. Rather than fail, an
unavailable face degrades along the cheapest axis — slope, then weight, then
family — and the substitution is recorded and surfaced as a
`fontSubstituted` layout issue. `BookFontAssets.assetPaths` is the only place
that needs to change when the italic TTFs are added.

Nothing in Phase 1's default output needs italic: `BookInlineMarkup` defaults to
`none`, so scene prose has no emphasis to render.

## Inline emphasis

Scene content is a plain string edited in a plain field, so a formatted book
currently cannot italicise interior monologue or a ship's name.
`BookTypography.inlineMarkup` reserves the opt-in convention, off by default.

`LayoutTextLine` holds a `List<LayoutTextRun>` rather than a string from the
start, even though Phase 1 emits exactly one run per line. Retrofitting runs
after the line breaker, both renderers and the fidelity test exist would be a
rewrite; it costs nothing now.

## Studio shell

`StudioSection.book` sits directly after `StudioSection.manuscript` — formatting
the book is the step after writing it — and is registered in the workspace
group. Insertion point matters: `test/map_navigation_test.dart` pins Map's
position relative to World, and `test/analytics_studio_view_test.dart` asserts
label uniqueness. `StudioId.book` gives the studio scoped theme tokens like
every other one.

The 6.1 pipeline is a left stage rail rather than a `Stepper` — the stages are
freely revisitable — collapsing to a scrolling chip row below the shell's own
980 px breakpoint. Editing and Proofing appear as disabled steps so the pipeline
reads as a whole while nothing pretends to work.

## Fixture and tests

`test/fixtures/book_studio_fixture.dart` provides a three-chapter manuscript, a
single-chapter long manuscript for tests that need full body pages, and
`arithmeticFormat()`: a 200 × 200 pt text block with 10 pt type on 20 pt
leading and four-letter words, so that with `FakeBookFontMetrics` every expected
line break is arithmetic — eight words to a line, ten lines to a page.

| File | Covers |
|---|---|
| `test/book_format_test.dart` | Trim maths, mirrored margins, gutter bands, preset table, customisation provenance, JSON round trips, malformed input |
| `test/book_store_test.dart` | Seeding, round trip, malformed blobs, re-homing, backup, that no manuscript key is written, title/author resolution |
| `test/book_layout_test.dart` | Greedy wrap, justification, recto openers and blank versos, widows and orphans, roman-to-arabic folios, contents accuracy, dangling part anchors, reproducibility, every preset |
| `test/book_export_test.dart` | Font loading and degradation, real PDF output, one PDF page per laid-out page, metadata, blank-page rules, file saving |
| `test/book_layout_fidelity_test.dart` | That no renderer measures or breaks text, and that preview and PDF page counts agree |
| `test/book_studio_view_test.dart` | Stage rail, disabled stages, preview painting, preset change repaginating and persisting, export reaching the saver |
| `test/book_studio_navigation_test.dart` | Section registration, position, label and icon uniqueness, theme id |

## Remaining work

- **Phase 2 — EPUB.** `archive`'s `ZipEncoder`, already the pattern in
  `lib/archive/authoros_archive.dart`. `mimetype` first and stored is the
  classic validation failure and needs its own test. Consumes `BookDocument`,
  never `PaginatedBook`. Plus chapter-opener templates and richer ornaments.
- **Phase 3 — Editing and Proofing.** A separate `ProofingEngine` with a rule
  registry, *not* new `ContinuityWarningType` values:
  `ContinuityAnalyzer._recommendationFor` is an exhaustive switch consumed by
  `world_continuity.dart` and `codex_continuity.dart`, and `ContinuityActionKind`
  describes graph resolutions while a proof finding resolves by editing text at
  a character offset. Highest-value rule: manual tab indents, which double up
  because the engine applies `firstLineIndentPt` itself. Layout-stage rules
  (widows, orphans, rivers, a total that is not a multiple of four) are already
  computable from `PaginatedBook`.
- **Phase 4 — DOCX, spelling, named presets, archive inclusion.** The bundled
  dictionary should auto-seed its personal word list from
  `ManuscriptContinuityIntelligence.knownNames`, so invented character and place
  names are never flagged and the author trains nothing.
- **Italic faces**, per the Fonts section above.
- **Incremental re-layout**, if measurement demands it. `BookLayoutStats.elapsed`
  is surfaced in the Preview stage so a regression is visible rather than
  reported, and the studio caches a laid-out book against the manuscript
  timestamp and the format fingerprint.
