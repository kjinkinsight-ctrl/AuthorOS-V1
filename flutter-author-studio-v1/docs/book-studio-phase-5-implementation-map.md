# Book Studio Phase 5 Implementation Map

## Scope

Phase 5 closes milestone **M7** (`docs/authoros-2-master-plan.md:727-744`). Phases
1–4 built the pipeline and every export target; what was left was not another
format but the *evidence* that the formats are correct.

| M7 asks for | Before | After |
|---|---|---|
| preflight checks | nothing | `lib/book/preflight.dart`, nine checks |
| reusable templates | nothing | `lib/book/book_template.dart` |
| golden fixtures validate representative books | nothing | five pinned books |
| EPUB passes a standard validator | ✅ Phase 2 | ✅ |
| PDF font embedding … pass preflight | **silently wrong** | reported, and critical |
| exports reproducible from a frozen snapshot | **not reproducible** | byte-identical, and frozen |

## Three things were quietly broken

None of these would have shown up in a test that counts pages. All three were
found by reading what the code actually does rather than what it says.

### The PDF was never reproducible

EPUB and DOCX have both pinned their timestamps and asserted byte-identical
re-export since they were built. The PDF did neither, and could not:
`PdfInfo` hardcodes `'/CreationDate': PdfString.fromDate(DateTime.now())`
(`pdf-3.13.0/lib/src/pdf/obj/info.dart:48`) with no parameter to override it.
There was also no reproducibility test in `book_export_test.dart` at all, so
nothing would have caught it.

`PdfString` is not exported from `package:pdf`, so the entry cannot be rewritten
without reaching into the package's `src/`. It is **dropped** instead — the key
is optional in the specification — and the date moved into a proper XMP packet
via `PdfMetadata`, which *is* public API and is the channel readers, library
catalogues and PDF/A all prefer anyway. The packet is built with `XmlBuilder`,
for the same reason the EPUB and DOCX documents are: it carries the author's own
title, and a book called *Smith & Sons* must not produce a file that will not
parse.

That was not sufficient. `PdfDocument.documentID` is
`sha256(DateTime.now() + 32 random bytes)`, which alone made every export a
different file. The trailer `/ID` exists to identify a particular file, so it
should differ between two books and match between two exports of one — exactly
what deriving it from the book's own content gives. `PdfDocument` is a plain
class with a virtual getter, so a small subclass covers it with no internal
imports.

The remaining `DateTime.now()` in `package:pdf` sits in the xref table behind
`assert(() { if (settings.verbose) … })` with `verbose` defaulting off, so it
never reaches output.

### Fonts were substituted silently, in two places

`PdfBookFontMetrics.resolve` ended `return BookFontAssets.fallbackFace;` without
recording the substitution, and `BookPdfRenderer` does
`assets.bytesFor(face) ?? assets.bytesFor(fallbackFace)` with no record at all
and without going through `resolve`. A book could be exported entirely in the
wrong face with nothing anywhere reporting it.

The one-line `resolve` bug is fixed. The renderer's fallback is left alone,
because preflight now answers the question independently and better — see below.

### The manuscript was never actually frozen

`§11.10` states *"Book Studio consumes a manuscript snapshot and does not mutate
the source manuscript while laying out a book."* The second half was true from
Phase 1. The first was not: the studio read whatever the manuscript said at that
instant, and an export could not be reproduced once another paragraph existed.

## Preflight

A separate engine from `ProofRule`, and the signature is why. A proof rule asks
*"is this well set"* and is blind to where the book is going — a river is a river
whether the file becomes a PDF or an EPUB. A preflight check asks *"will this
come out right in **this** format"* and cannot answer without knowing the target.
The target is in `PreflightContext` because it is in the question.

Findings are `ProofFinding`s rather than a parallel vocabulary: the studio
already knows how to render them, and an author should not have to learn two
words for "warning". Preflight is the first thing in Book Studio that
legitimately emits `ProofSeverity.critical` — no layout rule does, because no
layout rule describes something that comes out actually broken.

| id | Asks | Severity |
|---|---|---|
| `fontEmbedding` | is every face the book is set in going to be embedded? | critical |
| `marginMinimum` | is any margin under the half-inch printers want? | warning |
| `gutterSettled` | did the print-on-demand binding allowance converge? | warning |
| `pageOrder` | does every chapter open on the side its rule requires? | critical |
| `blankPages` | how many blanks will print-on-demand charge for? | notice |
| `signature` | is the extent a multiple of four? | notice |
| `coverPresent` | an EPUB with no cover | warning |
| `emptyContent` | empty chapters or sections reaching the export | varies |
| `layoutIssue` | anything the engine reported that no check claimed | warning |

**It warns and never blocks.** Export always proceeds. An author has context this
engine does not — a proof copy, a printer with its own rules, a deliberate choice
— and a tool that refuses to produce a file is one that gets worked around
instead of read.

`blankPages` and `signature` **moved out of `BuiltInProofRules.layout`**. They
were always preflight questions filed in the wrong drawer: both describe what a
printer does and what it costs, not how the text is set. `river`, `widowOrphan`
and `shortChapterEnd` stayed, because those are typesetting quality.

### Font embedding, answered without touching the renderer

The obvious move — have `render` return what it embedded — is wrong twice: it
breaks eight call sites, and it makes the answer available only *after* an export
the author may not have run.

Only two element kinds carry a face: `LayoutTextLine.runs[].face` and
`LayoutDropCap.face`. `LayoutRule` and `LayoutOrnament` are vector paths.
`requestedFaces(PaginatedBook)` walks pages, elements **and marginalia** — page
furniture is text too — and yields exactly the set the renderer will ask for.

That equivalence is asserted, and the assertion is only possible because the PDF
is now reproducible: render once with the full asset set and once with **only**
the derived set, and require byte-identical output. A face the derivation missed
would have been substituted, and the bytes would differ.

The check is also proved to fire. A test removes a face the book genuinely uses
and requires a critical finding — a check that has never once fired is not a
check.

`LayoutElement` is `sealed`, so a new face-carrying element kind is a compile
error in `requestedFaces` rather than a silent omission.

## The frozen snapshot

**No new table.** `book_asset_rows` already exists, is already declared in
`test/story_graph_architecture_test.dart`'s audited set with its rationale, and
already has a `role` discriminator in its primary key. A snapshot is an authored
asset by exactly the argument a cover is: never a `RecordLink` endpoint,
participating in nothing. A second table saying the same thing would be a second
persistence system for no gain.

```
role:      'snapshot:<first 16 hex of sha256 of the manuscript JSON>'
mediaType: 'application/json'
bytes:     gzip(utf8(jsonEncode(manuscript.toJson())))
```

**Content-addressing is what makes this affordable.** Exporting one book to PDF,
EPUB, DOCX and TXT stores *one* snapshot, not four. Re-capturing an existing
manuscript refreshes its timestamp, so a draft exported again is no longer the
oldest — which is what keeps eviction honest.

The bytes are in the database rather than beside the other book settings for the
Phase 2 reason: shared preferences is `localStorage` on the web, roughly five
megabytes for the whole origin, shared with the author's own prose. A novel is a
couple of hundred kilobytes gzipped and there are several.

The **export history** is small and lives in the `BookProject` blob with
everything else: timestamp, format, variant, manuscript version, snapshot hash,
page and word count. Capped at `BookProject.historyLimit` (25) — deliberately
more than the five snapshots kept, because a row saying "you exported an EPUB
last Tuesday" is still true after its manuscript has been evicted.

Recording is wrapped so that a storage failure can never look like a failed
export: the file is already written and the author already has it.

## Reusable style templates

One JSON array under the global key `author_studio.book_templates`, mirroring
`AuthorProfileStore`'s `author_studio.profiles`. Templates must be cross-project
— that is the entire point — which rules out both the record graph (scope-
isolated by design, and proven so by the architecture test) and `BookStore`'s
per-project key.

Carried: trim, margins, typography, chapter design, running heads, page
numbering, EPUB settings, and matter *structure* (which sections exist, their
order, whether they are on).

Deliberately not carried, each for a concrete reason:

- **Identity** — title, author, subtitle, ISBN, edition, copyright year and
  holder, series number. Carrying book one's ISBN into book two is a way to
  publish something genuinely wrong, and it would be silent. One test asserts
  that none of these strings appears anywhere in a template's JSON.
- **Parts** — `BookPart.startsAtChapterId` names a chapter in *that* project;
  copied across, every part becomes a `danglingPart`.
- **Cover** — binary, per-book, in the database.
- **Authored section bodies** — a dedication belongs to one book. Applying a
  template *keeps* whatever the receiving book had already written, matched on
  the fixed section ids.

Templates store resolved values, not a diff against a preset, for the reason
already recorded at `book_format.dart:825`: a stored delta means shipping a
preset change silently reflows every book built on it.

## Golden fixtures

Checked-in **text digests**, not PNGs or PDFs. A binary golden for a PDF is
unreviewable — a diff says "these 40 kilobytes changed" and a human learns
nothing — and it is rewritten by any change inside `package:pdf` that has nothing
to do with the book. What is under test is the *layout*, and that is text.

`bookDigest` writes each page with its role, side, folio, running head and text
block, then every line with its position and content, plus the contents entries
with their folios. Coordinates round to two decimal places so float noise cannot
fail a build. Elapsed time and pass counts are excluded as machine-dependent;
folios and running heads are included because page furniture is exactly where an
off-by-one in the front matter shows.

Built with the **real** `PdfBookFontMetrics`. A golden on fake metrics validates
arithmetic, not books.

| fixture | catches |
|---|---|
| `paperback-novel` | parts, full matter, recto chapter starts |
| `pod-long` | the gutter that changes the measure that changes it |
| `large-print` | a different trim and type scale |
| `ebook-fixed` | unmirrored margins, no blank versos |
| `bare` | no front matter, no back matter, no author |

`test/book_golden_test.dart` enumerates the directory and requires the file set
and the book set to match exactly, following
`test/legacy_fixture_contract_test.dart`. Each fixture declares the digest
version it was written at.

**The fixtures were proved to catch a regression**: nudging the paperback body
size from 11 pt to 11.25 pt failed five of nine tests and named both the fixture
and the remedy.

Regeneration is `bash tool/update-book-goldens.sh`, and
`test/update_book_goldens.dart` is deliberately not named `*_test.dart` so
`flutter test` can never silently rewrite the files it is meant to be checking —
the same reason `test/startup_screens_capture.dart` is named the way it is.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/book/preflight.dart` | `PreflightCheck`, `PreflightContext`, `PreflightReport`, `PreflightEngine`, `requestedFaces` |
| `lib/book/preflight_checks.dart` | the nine built-in checks |
| `lib/book/book_snapshot.dart` | `BookSnapshot`, `BookSnapshotStore` |
| `lib/book/book_template.dart` | `BookTemplate`, `BookTemplateStore` |
| `lib/book/book_digest.dart` | `bookDigest`, the golden format |
| `test/book_preflight_test.dart` | 25 tests |
| `test/book_snapshot_test.dart` | 12 tests |
| `test/book_template_test.dart` | 12 tests |
| `test/book_golden_test.dart` | 9 tests |
| `test/update_book_goldens.dart`, `tool/update-book-goldens.sh` | regeneration |
| `test/fixtures/books/*.golden` | five pinned books |

**Modified**

| Path | Change |
|---|---|
| `lib/book/book_pdf_renderer.dart` | reproducible: derived `/ID`, XMP instead of a clock-based `/CreationDate` |
| `lib/book/book_fonts.dart` | `resolve`'s final fallback records its substitution |
| `lib/book/proof_rules.dart` | `blankPages` and `signature` moved to preflight |
| `lib/book/book_document.dart` | `ExportRecord`; `BookProject.exportHistory` |
| `lib/book_studio_view.dart` | preflight panel, template panel and dialog, snapshot on export |
| `test/book_export_test.dart` | a reproducibility group it never had |
| `test/book_proofing_test.dart`, `test/book_studio_view_test.dart` | follow the moves |

**No new dependency.** `crypto`, `archive`, `xml` and `drift` were all already
direct.

## Known gaps

- **Re-exporting an older snapshot is not yet a button.** The history is
  recorded and the manuscript is recoverable — the studio lists what was
  exported and when — but choosing a past row and rebuilding from it is UI that
  has not been written. The data is all there.
- **Italics** remain unbundled and unmarkupable, unchanged since Phase 1.
  `requestedFaces` will report an italic the moment anything asks for one, which
  is the piece that was missing.
- **The `.authoros` archive still excludes book data**, now including snapshots.
