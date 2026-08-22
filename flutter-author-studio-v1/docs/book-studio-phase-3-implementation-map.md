# Book Studio Phase 3 Implementation Map

## Scope

Phase 3 builds the Editing and Proofing stages, the last two placeholders in the
6.1 pipeline. It adds a deterministic rule engine, auto-fixes that write back
through the manuscript's own history, layout checks that only a paginated book
can answer, and an offline spelling dictionary.

Every stage of `Write → Edit → Format → Publish` is now real.

## Everything here is deterministic, and that is the point

AuthorOS is deliberately AI-free (`NEXT.md` §9). Phases 1 and 2 honoured that by
making layout and export algorithmic. This phase is where it would have been
most tempting to reach for a model, and where refusing to pays off: every
finding can be explained by pointing at the rule that produced it, every fix is
reversible, and nothing an author writes leaves their machine.

There is nowhere in `proof_rules.dart` for a model call to hide. That is a
property of the design rather than a promise in a document.

## A separate engine from continuity, on purpose

`lib/continuity.dart` owns a *story* vocabulary — unknown character, unknown
location, impossible travel — and `ContinuityAnalyzer._recommendationFor`
switches over it exhaustively in a file that `world_continuity.dart` and
`codex_continuity.dart` both consume. Adding "straight quotes" to that enum
would force a recommendation string into that switch for a warning neither of
those studios can ever produce, and four test files pin the existing vocabulary.

The resolutions differ too, which is the deeper reason. `ContinuityActionKind`
describes graph repairs — create a record, add a link. A proof finding is
resolved by editing text at a character offset. Merging them would mean one
action type covering two unrelated mechanisms.

So Book Studio has its own engine, and the Proofing stage says plainly that
story continuity lives in Manuscript Studio's own panel rather than duplicating
it. One place to resolve a thing beats two places that can disagree.

## What a rule is

```dart
abstract class ProofRule {
  String get id;              // stable: stored when an author switches it off
  String get label;
  String get description;
  ProofStage get stage;       // editing | proofing | layout
  bool get defaultEnabled;
  Iterable<ProofFinding> run(ProofContext context);
}
```

A registry rather than a switch, so a rule is data: listable, describable,
switchable, and addable without touching the engine.

**Findings carry offsets into the manuscript's own prose**, not into a laid-out
book, because a fix has to be applied to the source the author wrote. That is
why the text rules read `ManuscriptProjectSummary` while the layout rules read
`PaginatedBook`.

**A rule offers a replacement only when the answer is unambiguous.** Where it
does not, that is deliberate: an unpaired quotation mark needs a person, and a
tool that guesses at prose is worse than one that points and stays quiet.

## The rules

**Editing** — mechanics, all auto-fixable:

| Rule | What it catches |
|---|---|
| `manualIndent` | Tabs or spaces starting a paragraph. **The highest-value rule in the set:** the layout engine applies `firstLineIndentPt` itself, so a hand-typed indent is applied twice. It looks fine in a plain editor and wrong in the finished book — the clearest link between writing and formatting. |
| `doubleSpace` | Two or more spaces between words |
| `trailingWhitespace` | Spaces left at the end of a line |
| `spaceBeforePunctuation` | A space in front of a comma or full stop |
| `straightQuotes` | Typewriter quotes, curled by what precedes them |
| `straightApostrophes` | Contractions, plural possessives and elisions |
| `repeatedWord` | A word twice in a row, with an allowlist for `had had` and friends |
| `mixedDashes` | Several dash forms, normalised to the author's own majority |
| `ellipsisStyle` | `...` and `…` mixed |

**Proofing** — what only the whole book can see:

| Rule | What it catches |
|---|---|
| `inconsistentSceneBreak` | Different markers in different chapters. Each chapter looks fine on its own; only the book sees the disagreement. |
| `emptyNode` | A chapter or scene with no prose |
| `chapterTitles` | Some chapters titled and others not. Absence is a fine choice; inconsistency reads as an oversight in the contents. |
| `unbalancedQuotes` | An odd number of marks, **suppressed when the speech carries into the next paragraph** — the correct form for multi-paragraph dialogue, which a naive counter flags every time |
| `unbalancedBrackets` | A bracket that never closes |
| `frontMatterIncomplete` | A generated page switched on without the details that fill it |
| `spelling` | See below |

**Layout** — only answerable once the book is paginated:

| Rule | What it catches |
|---|---|
| `river` | Justified lines stretched wide enough to be visible |
| `widowOrphan` | A line stranded at a page boundary. The engine prevents these while paginating, so a finding means the break rules were loosened. |
| `shortChapterEnd` | A chapter spilling one or two lines onto a final page |
| `blankPages` | How many pages exist so chapters open recto — explained before it is costed, because print-on-demand charges for them |
| `signature` | A page count that is not a multiple of four. Printers fold in fours, so the rest become blank leaves. |

Layout findings are never fixable: they are resolved by changing the format, not
by rewriting prose. A test asserts that.

## Spelling

The one part of this phase with a real cost, so each decision earned its place.

**A word list, not a model.** `assets/dictionaries/en.txt.gz` — 128,223 words,
**350 KB gzipped**, derived from the MIT-licensed English dictionary that ships
with `pyspellchecker`. Possessives are stripped from the list and derived at
lookup instead, which costs nothing and saves roughly 70 KB. Licence and
provenance in `assets/dictionaries/LICENSE.md`.

**Loaded lazily.** Nothing touches the asset until the author opens the Proofing
stage. Most sessions never do, and 350 KB has no business on the path that
decides how long the app takes to start.

**It errs towards silence.** Under-flagging is a mild annoyance; over-flagging
makes a spellchecker useless in a novel, where invented words are the point. So
the full 128,000 is shipped rather than a trimmed common-words list, and:

- **The author's own names are free.** `ManuscriptContinuityIntelligence.knownNames`
  already collects every record title and alias in the project, so characters,
  places and factions are never flagged and nothing has to be trained. This is
  the connection between the studios doing real work: *everything is connected,
  but nothing requires AI.*
- **Hyphenated compounds** count as spelled correctly when both halves are.
  English coins these freely and listing them is hopeless.
- **British spellings are handled at lookup.** The bundled list is American —
  it has `color` and not `colour`, `realize` and not `realise`. Measured
  against thirty common British spellings, twenty were missing, which would
  have flagged a British author on nearly every page. Rather than ship a second
  word list, the systematic differences are undone at lookup
  (`-our→-or`, `-ise→-ize`, `-re→-er`, `-ence→-ense`, `-ogue→-og`, doubled `l`,
  `ae`/`oe`), with a short table for the irregulars (`pyjamas`, `kerb`,
  `aluminium`, `manoeuvre`). **This costs no download at all**, and it cannot
  turn a typo into a word unless the typo maps onto a real American spelling.

**A cap of 40 findings per scene, one per distinct word.** A scene written in a
language the dictionary does not have would otherwise produce thousands and
drown everything genuinely wrong.

When no dictionary is loaded the rule produces *nothing* and `ProofReport.spellingChecked`
is false, so the studio can say spelling was not checked rather than implying the
book is clean.

## Applying fixes

This is the one place Book Studio writes prose, and only when the author asks.
Phases 1 and 2 established that the studio reads the manuscript through the
read-only `ManuscriptStore.readStudio`; that still holds for layout. A fix is a
different thing — an explicit edit — and it goes through **`ManuscriptService`,
not the store**, so the change lands in the manuscript's own version history and
can be undone from Manuscript Studio like any other edit.

`ProofFixer.apply` works in **descending offset order**, so earlier offsets stay
valid as later ones are rewritten. It also:

- skips a finding whose text no longer matches, so a stale report cannot corrupt
  a scene that has changed underneath it;
- drops findings that overlap one already applied, because the second would be
  operating on text the first has rewritten.

Both are tested directly.

## Performance

Measured against a 129,600-word manuscript — a full novel:

| | |
|---|---|
| Dictionary load | 55 ms |
| All 16 text rules, no spelling | 230 ms |
| All 16, with spelling | 294 ms |
| False positives on clean English prose | 0 |

The studio's proof cache is deliberately **not** keyed on the format. No text
rule depends on a trim size or a margin, so dragging a margin slider must not
re-run sixteen rules over the whole manuscript on every frame.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/book/proofing.dart` | `ProofStage`, `ProofSeverity`, `ProofFinding`, `ProofContext`, `ProofRule`, `LayoutProofRule`, `ProofReport`, `ProofingEngine`, `ProofFixer`, `SpellingDictionary` |
| `lib/book/proof_rules.dart` | `BuiltInProofRules` and every rule |
| `lib/book/book_dictionary.dart` | Asset loading, lookup, possessives, compounds, British forms |
| `assets/dictionaries/en.txt.gz` | The word list |
| `assets/dictionaries/LICENSE.md` | Its licence and provenance |

**Modified**

| Path | Change |
|---|---|
| `lib/book_studio_view.dart` | Editing and Proofing stages built; `BookStage.isAvailable` is now true for every stage; lazy dictionary load; fixes applied through `ManuscriptService` |
| `pubspec.yaml` | The dictionary asset |

**Tests**

| File | Covers |
|---|---|
| `test/book_proofing_test.dart` | Every rule, both what it catches and what it correctly leaves alone; multi-paragraph dialogue; ordinary English doubling; ambiguous single quotes; fix ordering, staleness and overlap; layout rules |
| `test/book_dictionary_test.dart` | The real asset: size, uncommon words, typos, case, possessives, compounds, 34 British spellings, and that mapping them does not start accepting typos |
| `test/book_studio_view_test.dart` | The stages list findings, fix them, write real corrected prose back, and report cleanly afterwards |

## Remaining work

- **Switching individual rules off.** The engine takes an `enabled` set and the
  UI does not yet expose it. Storing that on `BookProject` is a small change.
- **A personal word list the author can add to.** Record names cover invented
  proper nouns, but not an invented common noun used only in prose. The rule
  message already promises this; the store does not exist yet.
- **Jumping to a finding.** A finding carries a scene id and an offset, so
  "show me" could open Manuscript Studio at exactly that character.
- **More languages.** The dictionary is English. `EpubSettings.language` already
  records what the book is written in, which is the hook a second list would
  hang from.
- **Hyphenation** would use the same kind of asset, and would improve
  justification in the layout engine.
