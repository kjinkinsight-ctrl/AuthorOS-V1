# Book Studio Phase 2 Implementation Map

## Scope

Phase 2 adds EPUB 3 export, cover art, and a set of ebook settings kept apart
from the print format. It does not add DOCX, TXT, or the Editing and Proofing
stages, which remain visible and disabled in the pipeline.

Phase 1 shipped the print half of the promise. EPUB is the half print cannot
cover: it is what Kindle, Kobo, Apple Books and every library system actually
ingest.

## Architecture

Phase 1 deliberately built two derived shapes, and this is the milestone that
uses the second one.

```
BookDocument ──▶ BookLayoutEngine ──▶ PaginatedBook ──▶ PDF     (fixed pages)
     └──────────────────────────────────────────────▶ EPUB     (reflowable)
```

`BookEpubExporter` consumes a `BookDocument` and **never** a `PaginatedBook`.
That is the rule [ADR-0006](architecture/ADR-0006-book-layout-engine.md)
records: a reader reflows an EPUB to their own screen, type size and margins, so
a print layout's page breaks are not merely unnecessary there, they would be
wrong. `test/book_layout_fidelity_test.dart` fails the build if this exporter
ever references `PaginatedBook`, `LaidOutPage`, `BookLayoutEngine` or
`book_layout.dart`.

## Documents are written, not templated

Every package document — the OPF, the navigation document, the NCX, the
container and every XHTML content document — is built with `XmlBuilder` from the
`xml` package.

`xml` was already in the dependency tree, required transitively by `pdf`, so
promoting it to a direct dependency adds nothing new.

The reason is correctness rather than taste. XHTML content documents are XML,
not HTML, and they carry author prose. A manuscript containing "Smith & Sons",
or a `<` in dialogue, assembled by string templating produces a package that
will not parse — and that failure surfaces as a corrupt book, not as a test
failure. Handing escaping to the writer removes the class of bug rather than
requiring it to be remembered at every call site. There is a test that puts
`Smith & Sons said "go" — 3 < 5 > 2 & <not a tag>` through the exporter and
reads it back out of a real XML parse.

## The package

```
mimetype                        stored, uncompressed, first entry
META-INF/container.xml          → OEBPS/content.opf
OEBPS/content.opf               EPUB 3 package document
OEBPS/nav.xhtml                 the table of contents
OEBPS/toc.ncx                   EPUB 2 fallback, which KDP still asks for
OEBPS/styles/book.css           derived from EpubSettings, in em and rem
OEBPS/images/cover.(png|jpg)    when a cover is set
OEBPS/text/cover.xhtml
OEBPS/text/front-<kind>.xhtml   one per enabled front-matter section
OEBPS/text/part-NNN.xhtml       one per part
OEBPS/text/chapter-NNN.xhtml    one per chapter
OEBPS/text/back-<kind>.xhtml
OEBPS/fonts/*.ttf + OFL.txt     only when fonts are embedded
```

**`mimetype` first and stored** is the single most common reason an otherwise
correct EPUB is rejected. With `archive` 4.x that is
`ArchiveFile.string('mimetype', 'application/epub+zip')..compression =
CompressionType.none`, added before anything else because `Archive` preserves
insertion order. It has its own test, asserting on the decoded entry's
`compression` rather than `isCompressed` — the latter flips once the bytes have
been read.

**The contents page is `nav.xhtml` itself**, placed in the spine when the author
has the Contents section enabled. In EPUB 3 the navigation document *is* the
table of contents; generating a second visible one would mean two tables of
contents that can drift apart. Parts nest their chapters in the nav `<ol>`,
mirroring the book's own structure, and the NCX is generated from the same list
so the fallback cannot point somewhere else.

## Determinism

Phase 1 asserts that layout is reproducible; the same property holds here. EPUB
has two sources of drift and both are pinned:

- **`dc:identifier`** is `urn:isbn:` when the author has set an ISBN, and
  otherwise a UUID derived from `sha256(projectId)`. Deriving rather than
  generating keeps exports reproducible, but the stronger reason is that
  `dc:identifier` names the *work*: a reading system uses it to recognise that a
  newly sideloaded file is a newer copy of a book already on the shelf. A fresh
  identifier each export would leave a reader collecting duplicates instead of
  receiving an update.
- **`dcterms:modified`** is required by the specification, in exactly
  `CCYY-MM-DDThh:mm:ssZ` with no fractional seconds. It comes from the
  manuscript's own `updatedAt`: deterministic *and* meaningful, where
  `DateTime.now()` would make every export of an unchanged book a different file.
- Zip entry timestamps are pinned with `modified: DateTime.utc(2000)`, the
  pattern `lib/archive/authoros_archive.dart` already uses.

## Ebook settings are their own model

`lib/book/epub_settings.dart`. Not a second `BookFormat`: trim size, margins,
binding allowance, running heads and folios are all meaningless once a reader
reflows the text, and carrying them would put controls in the studio that change
nothing.

What is left is what a reading system honours: font family, line height,
first-line indent, paragraph spacing, alignment, chapter numbering, scene-break
style, drop cap, font embedding and language. The vocabulary is reused from
`book_format.dart` (`BookAlignment`, `ChapterNumberStyle`, `SceneBreakStyle`,
`BookOrnamentId`, `BookFontFamilyId`) rather than duplicated.

Everything is relative. **Body text is `1em`** — the reader owns the size, and an
absolute value set by the author would fight the size they chose on their own
device. A test asserts the stylesheet contains no `pt` values at all.

`language` is new, and genuinely required: EPUB mandates `dc:language`, and
AuthorOS had no language field anywhere. A malformed tag falls back to `en`
rather than travelling into the package, because a reading system can refuse a
book whose `dc:language` is nonsense.

Persisted as one more field on the existing `BookProject` blob. Only the cover
needed somewhere else.

## Ornaments are typeset here, and drawn in print

Phase 1 draws ornaments as vector paths because the PDF embeds only two faces
and a character like U+2767 would render as tofu. That reasoning does not carry
over: a reading system has full Unicode coverage, so in an EPUB the ornament is
simply set as text (`⁂`, `◆`, `❧`). The rule ornament stays an `<hr>`.

## Why cover art needed a database table

Covers are binary and large — a typical retailer cover is several hundred
kilobytes.

Every other book setting lives in shared preferences, which **on the web is
`localStorage`** (`shared_preferences_web` calls `html.window.localStorage`
directly). That is roughly a five-megabyte quota for the entire origin, shared
with the author's manuscript prose. A cover stored there can fail to save, or
crowd out the book itself.

So cover bytes go into the embedded database, which is SQLite over IndexedDB in
the browser and has no such ceiling.

That adds `book_asset_rows`, which `test/story_graph_architecture_test.dart`
pins. The test is not a prohibition — it requires an addition to be deliberate
and declared, and `writing_session_rows` is already listed with a comment
explaining why it is there and why it is not graph truth. This follows that
precedent: a cover is an authored asset, never a `RecordLink` endpoint, and it
participates in nothing.

- `currentSchemaVersion` 9 → **10**, with a guarded step in the established
  shape. `test/book_cover_test.dart` exercises it against a real file: a
  version 9 database with the table dropped, reopened at the current version,
  gaining the table and keeping its data.
- The architecture document and the persisted-data inventory are amended
  alongside, as those documents require.

**Bytes are stored exactly as supplied.** Re-encoding is tempting and wrong:
Flutter can only re-encode to PNG, and a photographic cover as PNG is several
times larger than the JPEG it came from. Import validates instead — media type
sniffed from the file's own magic bytes (a filename extension is a claim, not
evidence, and a manifest that mislabels a media type fails validation), one
decode to prove it is really an image and read its dimensions, a size cap, and a
minimum edge. A rejected file returns a reason rather than throwing: a bad file
is an ordinary answer.

## Font embedding

Off by default. Many reading systems ignore embedded fonts, several let the
reader override them outright, and embedding roughly doubles the file — for the
fixture book it grew from 7 KB to 1 MB. When it is switched on, all four bundled
faces travel with the book and the OFL notice travels with them, as the licence
requires.

Italic still is not bundled (Phase 1's open gap), so an embedded book carries
upright faces only and the reader's own italic applies for emphasis.

## Validation

`test/book_epub_test.dart` asserts the package's structure and runs in CI. It
cannot speak for the whole specification, so `tool/validate-epub.sh` runs the
official **EPUBCheck**, which is the reference implementation retailers
themselves use, and is what milestone M7's exit gate is written against.

Three variants were validated during development against EPUBCheck 5.3.0, all
reporting **0 fatals / 0 errors / 0 warnings / 0 infos**:

- plain — front and back matter, parts, contents
- everything on — cover, embedded fonts, drop caps, ornaments, `en-GB`, roman
  chapter numerals, series metadata, and prose containing `&` and `<`
- bare — no front matter, no back matter, no contents, no author name

The script is deliberately **not** wired into `.github/workflows/dart.yml`: that
job installs Flutter and nothing else, and adding a Java toolchain to CI is a
decision worth taking on its own merits rather than arriving with a feature.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/book/epub_settings.dart` | `EpubSettings`, defaults, language validation |
| `lib/book/book_epub_exporter.dart` | The package builder |
| `lib/book/book_cover.dart` | `BookCover`, magic-byte sniffing, validation, `BookCoverStore` |
| `tool/validate-epub.sh` | Runs EPUBCheck against an exported file |

**Modified**

| Path | Change |
|---|---|
| `lib/persistence/authoros_database.dart` | `BookAssetRows`, schema 10, migration step |
| `lib/book/book_document.dart` | `BookProject` carries `EpubSettings` |
| `lib/book/book_export_targets.dart` | `epub.isAvailable`; `isReflowable` |
| `lib/book_studio_view.dart` | Export branches by format; cover panel in Structure; ebook settings in Design; switches now carry their own `Material` |
| `test/story_graph_architecture_test.dart` | Declares `book_asset_rows` with its rationale |
| `pubspec.yaml` | `xml` promoted from transitive to direct |

**Tests**

| File | Covers |
|---|---|
| `test/book_epub_test.dart` | `mimetype` first and stored; container resolves; required metadata; stable identifier; spine idrefs resolve; unique manifest ids; chapter order; contents is the nav; parts nest; nav and NCX agree; landmarks; every document well-formed with a non-empty title; hostile prose survives; drop caps; ornaments; reproducibility; relative units |
| `test/book_cover_test.dart` | Sniffing, every rejection path, storage round trip, replacement, isolation between projects, and the 13 → 14 migration on a real file |
| `test/book_studio_view_test.dart` | EPUB selectable and exporting a real package; ebook settings persisted and kept apart from print; cover chosen, stored and shown; a bad file refused with a reason |
| `test/book_layout_fidelity_test.dart` | The EPUB exporter never reaches for the layout engine |

## A defect this phase fixed

Adding the first test that taps a switch surfaced a framework assertion that had
been latent since Phase 1: a `SwitchListTile` placed directly on a coloured
`_Panel` paints its ink on the nearest `Material` ancestor, so the splash is
invisible. All the studio's switches now go through `_SwitchRow`, which carries
its own transparent `Material`.

## Remaining work

- **DOCX and TXT.** Both consume `BookDocument`, like EPUB. DOCX is OOXML in a
  zip, so `archive` covers it with no new dependency; TXT is nearly free from
  `ManuscriptProjectSummary.exportAsSingleText()`.
- **Editing and Proofing**, still the largest gap in the pipeline. A separate
  deterministic `ProofingEngine`, not new `ContinuityWarningType` values — see
  the Phase 1 map for why.
- **Italic faces**, which would improve both PDF and EPUB.
- **Archive inclusion.** Book settings were already outside the `.authoros`
  archive, and cover bytes now widen that gap. Closing it means a `data/book.json`
  entry plus the asset bytes, which changes the archive entry count the
  story-graph audit pins, so it lands with the doc amendment and the archive test
  together.
- **Cover in print.** The cover is an ebook-only asset today; a print PDF could
  carry it as a first page for proofing.
