# ADR-0006: Book layout engine

Status: Accepted
Date: August 2026
Supersedes: nothing
Resolves: the open decision recorded in `docs/authoros-2-master-plan.md` §18,
"Book layout engine — evaluate HTML/CSS paged media vs native PDF composition"

## Context

Book Studio must show an author their finished book and then export it. Section
6.4 of the product brief states the requirement as a rejection of the usual
compromise:

> The author should be able to see: this is what my finished book will look
> like. Not simply export a document and hope.

That sentence is a constraint on the architecture, not a feature request. A
preview that is merely similar to the export is worse than no preview, because
it invites an author to sign off on a page count and a chapter opening that the
PDF will not honour, and the mistake only surfaces in a proof copy.

Before this work the app delegated all pagination to `package:pdf`:
`ManuscriptPdfExporter.generate` handed the entire manuscript to a `MultiPage`
as one `pw.Text`. Line and page breaks were therefore decided inside a library,
where nothing on screen could see them.

Two candidate engines were considered.

**HTML/CSS paged media.** Compose the book as HTML, use `@page`, named page
areas, and `break-before` to paginate, and let a browser engine render both the
preview and the printed output.

**Native composition.** Own the line breaker and the page breaker in Dart, and
have both the on-screen preview and the PDF writer consume the result.

## Decision

**Native composition, with a single engine that owns every break.**

`BookLayoutEngine.layout(BookDocument, BookFormat)` is a pure function returning
a `PaginatedBook`: a list of pages, each holding fully positioned elements in
points. `BookPdfRenderer` and `BookPagePainter` consume that structure and do
nothing but paint it.

```
BookDocument ──▶ BookLayoutEngine ──▶ PaginatedBook ──┬──▶ BookPdfRenderer
                        ▲               (pure data)   └──▶ BookPagePainter
                        │
                 BookFontMetrics
```

Three consequences follow, and they are the substance of the decision.

**Measurement is done once, with the exporter's own font.** `BookFontMetrics`
is backed by `PdfTtfFont`, the same TrueType parse the PDF embeds. The preview
does **not** measure with Flutter's text shaper; it uses `TextPainter` only to
draw a line the engine already broke, and to find that line's drawn ascent so
the glyphs sit on the engine's baseline. Making the authoritative measurer the
one the export actually uses removes preview/export divergence at its root
rather than trying to keep two measurers in agreement.

**Page furniture is positioned by the engine too.** Running heads and folios
sit outside the text block, and an earlier draft let each renderer place them,
which meant each renderer measured a string. They are now emitted as
`LaidOutPage.marginalia` in absolute page coordinates, so no renderer has any
reason to measure anything.

**The rule is enforced, not just documented.**
`test/book_layout_fidelity_test.dart` scans both renderer sources (comments
stripped) and fails the build if either references `BookLayoutEngine`,
`BookFontMetrics`, `advanceEm`, `advancePt`, `stringMetrics`, or `RegExp`. It
also asserts that the PDF's page count equals `PaginatedBook.pages.length`
equals the number of pages the preview builds.

## Why not paged media

- **It does not reach three of the four platforms.** AuthorOS ships to Android,
  Windows, macOS, Linux and web. Only the web target has a browser engine at
  all, and Flutter web renders to a canvas rather than to a paginatable DOM, so
  even there the app would have to host a second rendering stack.
- **Print CSS support is uneven** across engines for exactly the features a
  book needs: mirrored margins, named page areas, running heads drawn from
  content, and orphan and widow control.
- **It would put layout beyond reach of `flutter test`.** The engine as built is
  plain Dart, so widow control, recto starts, roman-to-arabic folio restarts and
  reproducibility are ordinary unit tests. That is what makes the M7 exit gate
  ("golden fixtures validate representative books") achievable at all.
- **It would not have solved the real problem.** Paged media gives one renderer,
  but the preview would still be a browser view of a document the exporter
  paginates separately unless the same engine drove both — which is the
  decision above, arrived at by a longer road.

## Consequences

Accepted costs:

- **Typography is ours to implement.** Line breaking is greedy first-fit, not
  Knuth–Plass. The difference in colour is invisible at preview zoom and greedy
  breaking is far easier to assert in a test; an optimal-fit breaker can be
  added later behind a switch without changing the `PaginatedBook` contract.
- **No hyphenation.** Liang patterns are a dictionary-sized asset and belong in
  the same budget conversation as spell-checking.
- **Reflowable formats must not use this engine.** EPUB and DOCX consume
  `BookDocument`, never `PaginatedBook`: pagination is meaningless in a format
  the reader reflows. Keeping `BookDocument` a separate stage from
  `PaginatedBook` is what preserves that, and is why the two exist at all.

Gained:

- Preview and export cannot disagree about the shape of the book.
- `layout()` is deterministic, so "exports are reproducible from a frozen
  manuscript snapshot" is a test rather than an aspiration.
- The engine runs unchanged on every platform, including web, with no new
  dependency: `pdf` and `archive` were already in `pubspec.yaml`.

## Notes on the binding allowance

Print-on-demand printers require a gutter that grows with the page count, which
is circular: the gutter changes the measure, the measure changes the page count.
The engine resolves it by re-flowing, bounded by `BookLayoutEngine.maxPasses`
(3), and records a `gutterDrift` issue if it has not settled. `BookLayoutStats.passes`
reports how many passes a book needed.

## Notes on the table of contents

The contents page needs body page numbers, but front-matter length depends on
how long the contents is. Rather than iterate to a fixed point, the engine
paginates the **body first** in its own arabic sequence, builds the contents
from those final numbers, and only then paginates the front matter in its own
roman sequence. Because the sequences are independent, laying out the front
matter cannot move the body, and the contents is right on the first pass.

That is the real reason front matter is traditionally numbered in roman: it
decouples two things that would otherwise chase each other. When an author turns
`countFrontMatterSeparately` off, the engine falls back to the bounded iteration
above.
