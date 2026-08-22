# Book Studio Phase 4 Implementation Map

## Scope

Phase 4 builds the last two export targets: **DOCX** and **TXT**. With them,
every format in `BookExportFormat` is real, and the 6.1 pipeline
`MANUSCRIPT → EDITING → PROOFING → FORMATTING → DESIGN → PREVIEW → EXPORT`
ends somewhere for every audience a book has — a printer, a reading system, an
editor, and a machine.

| Target | Consumes | Built in |
|---|---|---|
| Print PDF, Digital PDF | `PaginatedBook` | Phase 1 |
| EPUB | `BookDocument` | Phase 2 |
| **DOCX** | **`BookDocument`** | **Phase 4** |
| **TXT** | **`BookDocument`** | **Phase 4** |

## Both are reflowable, and the build now enforces it

ADR-0006 fixed the rule that a reflowable format consumes `BookDocument` and
never `PaginatedBook`. Phase 2 tested that for EPUB alone. It now covers all
three, because the reason is the same in each and gets *stronger* as the list
grows:

- an **EPUB** reflows to a screen and type size this app cannot see;
- a **DOCX** repaginates on whatever paper and printer Word is opened with;
- a **TXT** file has no pages at all.

Inheriting print page breaks would be wrong in all three, and differently wrong
in each. `test/book_layout_fidelity_test.dart` now loops the ban over every
reflowable exporter, so the next one added inherits the check rather than
needing to remember it.

The same honesty reaches the UI. The Export stage used to say *"This will write
N pages at 6 × 9 in"* for whatever was selected. For a reflowable target that
is not a simplification, it is a false statement, so `_exportSummary` now says
what each format can actually promise — chapters for EPUB and DOCX, words for
text, pages only for the two PDFs.

## DOCX: two flavours, because a Word file does two jobs

A `.docx` is asked for by two different people who want opposite things.

| | `DocxFlavour.submission` | `DocxFlavour.typeset` |
|---|---|---|
| Paper | US Letter, 1 in margins | the book's own trim and margins |
| Leading | double (`w:line=480`, `auto`) | the book's leading (`exact`) |
| Alignment | ragged right | the book's alignment |
| Running head | `Surname / TITLE / page` | none — the book carries its own |
| Scene break | `#` | the book's own mark |
| Chapter number | `Chapter 1` | the book's own style |

They are the same document generated from one `_Metrics` record, which is why
they share an exporter rather than being two.

`submission` is set ragged right on purpose: it is a working copy, and
justification hides how much has actually been written on a line.

`typeset` measures its chapter sink against the **text block**, not the trim,
because that is what `BookLayoutEngine._composeChapterOpener` does. A flavour
that claims to be "the book as you have formatted it" has to agree with the
thing that formats it, and the two would otherwise drift by about 22 pt on a
paperback.

## Real named styles, not direct formatting

Every paragraph carries a `w:pStyle` and the body carries no `w:rPr` at all.
Both are asserted, because the difference is invisible on open and decisive
afterwards:

- an editor restyles the whole manuscript in one action;
- Word's navigation pane shows the chapter tree, because chapter titles are
  `Heading1` whose `w:name` is the built-in `heading 1` — a custom name would
  look identical and do nothing;
- a table of contents can be generated, which is what the contents page uses.

Styles defined: `Normal`, `BodyText`, `BodyTextFirst`, `Heading1`, `PartTitle`,
`ChapterNumber`, `SceneBreak`, `BookTitle`, `BookSubtitle`, `FrontMatter`,
`Copyright`, `RunningHeader`.

### The contents page is a TOC field

A contents page is built during pagination from page numbers a Word file does
not have — Word repaginates on open, so any number written into the file would
be wrong. The page instead gets Word's own field:

```
TOC \o "1-1" \h \z \u
```

written as a five-run field rather than `w:fldSimple`, so the placeholder text
sits between `separate` and `end`. Word evaluates it on open (`w:updateFields`)
and the author never sees the placeholder; a reader that does not evaluate
fields shows the placeholder line instead of a blank page.

This is the whole reason the headings are real named styles rather than bold
centred text.

### Three things found by rendering the file and looking at it

Structural tests pass on a document that is visibly wrong. All three of these
were found by converting the export to PDF and reading the coordinates.

1. **The chapter sink landed between the number and the title.** `Heading1`
   carried `w:before = chapterSink`, so `CHAPTER 1` sat at the top of the page
   and its title a third of a page below it. The sink and the page break now
   belong to `ChapterNumber`, and the title that follows suppresses both.
2. **Display styles were clipped by the body's pinned leading.** The typeset
   flavour sets `lineRule="exact"` so the measure matches the printed book,
   which silently clips anything set larger — every title in the document.
   Every style that sets its own type size now overrides the leading back to
   `auto`.
3. **`w:evenAndOddHeaders` was on with only a default header part**, which left
   every left-hand page of a submission bare.

### Validation

Structural tests are not enough for a format this strict, so the exports were
run through two real tools:

| Tool | Result |
|---|---|
| `python-docx` 1.2.0 | all six exports open; page size, margins, styles and header read back as written |
| LibreOffice Writer 24.2 → PDF | all six convert; text positions confirm centring, indents, justification, sink and scene breaks |

LibreOffice is the stronger of the two: it is a real word processor rather than
a parser, so a file it renders correctly is one Word will open.

## TXT: the format nothing can refuse

Two styles, because a text file is asked for by a person and by a machine:

- **`readable`** — front matter, chapter headings, scene breaks, blank lines
  between paragraphs. The whole book as a person would read it.
- **`manuscriptOnly`** — nothing but prose in reading order, for word counts,
  diffs, and submission portals that only take a paste box.

`manuscriptOnly` is asserted to produce exactly `BookDocument.wordCount` words,
so a count taken from the file agrees with the one the studio shows.

**What it deliberately does not do**: no box drawing, no headings centred with
spaces, no ASCII rules. Those assume a monospaced font at a known width and
turn into ragged debris the moment the file is opened in anything proportional.
The one indent it does use — two spaces for chapters under a part on the
contents page — is hierarchy, not alignment, and reads correctly in any font.

Line endings are `\n` everywhere, including on Windows: Notepad has read them
since 2018, and it is the only choice that keeps the export byte-identical
across the platforms AuthorOS runs on.

A contents page lists the chapters by name rather than printing an empty
heading — the part of a contents page that survives into a format with no pages.

## One numbering implementation, shared

`romanUpper` and `numberWord` moved from `book_layout.dart` to
`book_format.dart`, joined by a new `chapterNumberLabel`.

They had to move. Exporters are banned from importing `book_layout.dart`, so
EPUB had already copied both, and DOCX and TXT were about to make it four
copies. Four implementations of "what does chapter 21 look like" is exactly how
a book comes to read `Chapter Twenty-one` in the PDF and `Chapter 21` in the
Word file. `book_format.dart` is plain Dart with no pagination in it, so the
fidelity ban is untouched.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/book/book_docx_exporter.dart` | `DocxFlavour`, `BookDocxExporter`, the OOXML package |
| `lib/book/book_text_exporter.dart` | `TextExportStyle`, `BookTextExporter` |
| `test/book_docx_test.dart` | 21 tests |
| `test/book_text_test.dart` | 15 tests |

**Modified**

| Path | Change |
|---|---|
| `lib/book/book_export_targets.dart` | every target available; DOCX and TXT are reflowable |
| `lib/book/book_format.dart` | `chapterNumberLabel`, `romanUpper`, `numberWord` |
| `lib/book/book_layout.dart` | numbering helpers moved out |
| `lib/book/book_epub_exporter.dart` | uses the shared numbering |
| `lib/book_studio_view.dart` | exports branch by format; flavour and style pickers; honest export summary |
| `test/book_layout_fidelity_test.dart` | the pagination ban covers all three reflowable exporters |
| `test/book_studio_view_test.dart` | DOCX and TXT export paths; no page count on a reflowable target |
| `test/fixtures/book_studio_fixture.dart` | `manuscriptFixtureWithProse` |

**No new dependency.** `archive` and `xml` were both already direct.

## Known gaps

- **Italics.** Scene prose is a plain string, so the DOCX carries no inline
  emphasis — the same Phase 1 gap the PDF and EPUB have. `BookInlineMarkup`
  exists for it and nothing consumes it yet.
- **No cover in the DOCX.** A cover is an ebook and print artefact; Word has
  nowhere sensible to put one that an editor would want.
- **The `.authoros` archive still excludes book data**, unchanged from R-2.
