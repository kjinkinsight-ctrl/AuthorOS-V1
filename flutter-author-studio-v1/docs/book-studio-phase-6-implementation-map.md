# Book Studio Phase 6 Implementation Map

## Scope

Every phase so far recorded the same gap:

> Scene prose is a plain string with no markup, so a book cannot italicise
> interior monologue at all.

`BookInlineMarkup { none, underscoreItalic }` had been in `book_format.dart`
since Phase 1 — declared, serialised, `copyWith`-able, and consumed by nothing.
Phase 6 makes it real, from the author's keystroke to all four formats.

## The blocker, and how it came down

Phase 1 recorded that the OFL italic faces were unreachable through this
environment's network policy — 403 through the proxy — so even a perfectly
parsed italic had no face to be set in.

The npm registry *is* reachable, and Google Fonts' static releases are
redistributed there. The four italics are **unmodified upstream files** from
`@expo-google-fonts/merriweather` and `@expo-google-fonts/inter`.

Unmodified matters legally, not just tidily. Merriweather is licensed **with the
Reserved Font Name "Merriweather"**, and the OFL defines a Modified Version as
one made *"by adding to, deleting, or substituting … any of the components of
the Original Version, by changing formats or by porting the Font Software to a
new environment"* — which a subset or a WOFF2-to-TrueType conversion plainly is,
and which clause 3 then forbids from carrying that name.

The first attempt did exactly that: pulled `@fontsource/*` WOFF2, converted with
`fontTools`, and merged the `latin` and `latin-ext` subsets. It worked, and the
render was correct, but it produced Modified Versions bearing a reserved name —
and the PDF embedded them as `MerriweatherLight18pt-Italic`, a variable-instance
label that says "Light" about a 400-weight face. The unmodified statics cost
about 2 MB more and remove both problems; they now embed as
`Merriweather-Italic`.

Metrics were checked against the bundled uprights before anything else: same
weight class, same units per em, same ascent and descent. That is what lets an
emphasised run sit on the same baseline with the same leading rather than
visibly floating.

## One parser, four consumers

`lib/book/inline_markup.dart`, plain Dart, no Flutter. The layout engine, the
EPUB, the DOCX and the text exporter all call it, for the reason
`chapterNumberLabel` records in `book_format.dart`: four implementations of what
emphasis means is how a paragraph comes to read one way in the PDF and another
in the Word file.

**`paragraphs` stays `List<String>`.** Every consumer still receives the
author's source text and parses at the point of use. That is deliberate: the
source is what a proof finding's offsets point into, what an auto-fix rewrites,
and what the word count counts. Making the parsed form primary would break all
three, for a feature that is off by default.

### An underscore is only a marker when it plausibly is one

Prose is full of underscores that are not emphasis, and a false positive
silently rewrites somebody's page. So:

- an opener must follow whitespace or opening punctuation, and be followed by a
  non-space;
- a closer must follow a non-space, and be followed by whitespace, closing
  punctuation, a dash or the end;
- `__` is a literal underscore, escaping itself;
- an unclosed marker is not emphasis, and emphasis **never spans paragraphs** —
  one dropped marker italicising the rest of a chapter is the failure this must
  not have.

`snake_case_name` therefore carries no emphasis at all. The cost of that rule is
that `un_believable_` carries none either: both are letter–marker–letter, only
one can win, and protecting prose that was never meant as emphasis matters more
than mid-word italics, which novels barely use. A word can still span faces
where a closer meets punctuation — `_The Kestrel_'s` is one word for breaking
and two segments for measuring.

## The line breaker

The delicate part, and where a regression would have hidden.

`_breakLines` measured one face for the whole paragraph: it took a string,
split on whitespace, and measured each word in that face. It now takes
`List<_ProseWord>`, where a word is a maximal run of non-space characters that
may itself span faces, and its width is the sum of its segments measured **in
their own faces**. An italic is not the width of its roman, so measuring it as
roman breaks the line in the wrong place.

`_composeLine` had two shapes: one run for an entire unjustified line, one run
per word when justifying. Both are now one walk emitting a run per **maximal
same-face stretch**, which collapses to exactly the old output in both cases —
a single run for an unemphasised unjustified line, one run per word for a
justified one, which is the `Tw` fix from Phase 1 that must not regress.

Inter-word spaces are measured in the body face even where one side is
emphasised: a space has no slant, the choice would otherwise be arbitrary at
every boundary, and the justification arithmetic already treats it as a
paragraph-level constant.

Front and back matter honour the convention too — a dedication and an epigraph
are exactly where an author reaches for italics.

A drop cap is taken from the tokenised prose rather than the raw string, or a
paragraph opening with a marker would set an underscore as its initial.

## The four formats

| Format | Emphasis becomes |
|---|---|
| PDF | the real italic face, embedded |
| EPUB | `<em>` — the reading system supplies the face, and it carries meaning to a screen reader |
| DOCX | a second `w:r` with `w:i` |
| TXT | the markers, kept |

Plain text keeping `_word_` is deliberate: that file is for word counts, diffs
and paste boxes, the convention is what the author typed, and stripping it would
make the text export lossy in a way the others are not.

The DOCX italic run is the one place that file uses direct run formatting. A
named character style would be tidier in principle and would stop an editor
italicising a word by hand — which is exactly what an editor is for.

## Switching it on

A toggle in the Design stage, off by default, that says what it would do before
it does it:

> Switching this on would set 34 phrases in italic. Your writing is not altered
> either way — the underscores stay in the manuscript.

The count comes from `countEmphasis` over the built document, so it is the real
number from the real parser. Switching off is lossless.

**`UnclosedEmphasisRule`** joins the proofing stage, in the shape of the
existing unbalanced-quotes and unbalanced-brackets rules. It only runs when the
convention is on, and it is never auto-fixed: which marker is the stray one is a
question about intent. It catches the one failure that costs something — the
parser refuses to run emphasis past a paragraph, so an unclosed marker produces
no italics at all, silently, on a phrase the author meant to emphasise.

Manuscript Studio's editor gains an **Italic** button that wraps the selection,
toggling on a second press. Its logic lives in `inline_markup.dart` rather than
in the widget, because a second place that knows what an underscore means is a
second place that can be wrong about it — and a test asserts that what the
button writes is what the parser reads back.

## Verification

Structural tests are not enough for something whose whole point is how a page
looks, so all four formats were rendered and read:

| Check | Result |
|---|---|
| PDF, rendered to image | *The Kestrel* and *Mariner* in genuine italic at matching weight; `snake_case_name` upright; justification intact |
| `pdffonts` | `Merriweather-Italic` embedded alongside Regular and Bold |
| EPUBCheck 5.3.0 | **0 fatals / 0 errors / 0 warnings / 0 infos**, with `<em>The Kestrel</em>` |
| LibreOffice Writer → PDF | both runs render slanted; the rest upright |
| The five existing golden fixtures | **byte-identical**, which is the proof the ordinary path did not move |

A sixth fixture, `emphasis.golden`, pins where italic runs begin and end. The
digest lists runs only when a line is set in more than one *face* — listing them
whenever there is more than one run would spell out every word of every
justified line, which is most of a book and none of it worth reviewing.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/book/inline_markup.dart` | `ProseSpan`, `parseProse`, `stripProse`, `hasUnclosedEmphasis`, `toggleEmphasis`, `countEmphasis` |
| `assets/fonts/*-Italic.ttf` | four unmodified upstream faces |
| `assets/fonts/LICENSE.md` | provenance and the OFL |
| `test/book_inline_markup_test.dart` | 33 tests, most of them underscores that are *not* emphasis |
| `test/book_italics_test.dart` | end to end across all four formats |
| `test/fixtures/books/emphasis.golden` | the sixth pinned book |

**Modified**

| Path | Change |
|---|---|
| `lib/book/book_layout.dart` | segments, per-face measurement, per-face runs |
| `lib/book/book_document.dart` | `BookDocument.inlineMarkup`, so exporters read one answer from one place |
| `lib/book/book_epub_exporter.dart` | `<em>` |
| `lib/book/book_docx_exporter.dart` | `w:i` runs |
| `lib/book/book_fonts.dart` | four asset paths; `FakeBookFontMetrics.italicFactor` |
| `lib/book/book_digest.dart` | runs listed on multi-face lines |
| `lib/book/proof_rules.dart` | `UnclosedEmphasisRule` |
| `lib/book_studio_view.dart` | the Design toggle and its count |
| `lib/manuscript_studio.dart` | the Italic button |
| `pubspec.yaml` | four assets |

**No new dependency.** The fonts are assets.

## Known gaps

- **Bold has no convention.** Novels barely use it and manuscripts discourage
  it, so `BookInlineMarkup` still names one style. Adding `**bold**` would be
  another enum case and another branch in the same parser.
- **Emphasis cannot begin mid-word**, by the deliberate trade above.
- **Headings and the title page do not take emphasis** — a marker in a chapter
  title is treated as literal.
- **The `.authoros` archive still excludes book data** — settings, cover bytes
  and export snapshots. R-2 itself is now closed on `main`: the archive carries
  scene prose and writing sessions, and its format treats new entries as
  additive and optional, which makes adding book data a smaller change than it
  was when Phase 1 first recorded the gap.
