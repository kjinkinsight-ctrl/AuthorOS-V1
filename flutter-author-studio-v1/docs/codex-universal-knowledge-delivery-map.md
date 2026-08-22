# Codex — Universal Knowledge System Delivery Map

Companion to `docs/codex-universal-knowledge-implementation-map.md`, which holds the
audit and the phase order for the same milestone. That document says what the Codex
should become; this one says what this branch built and where each piece lives.

Status: Implemented and covered by focused domain and widget tests
Updated: August 21, 2026
Verification baseline: 1206 tests passing, 57 analyzer issues (0 errors), Flutter 3.44.9

## Architecture

The Codex is a knowledge layer over the shared AuthorOS record architecture, not a
second database. Every entity is an `AuthorRecord`; every relationship is a
`RecordLink`; all persistence stays in `DriftConnectedDomainRepository`.

Nothing here adds a table. The schema is still version 9.

Six services compose what already exists and own no storage of their own:

| Service | Owns | Delegates to |
|---|---|---|
| `SeriesService` | Books, book membership, per-book entity state | `RecordService`, `ConnectionEngine`, `SafeDeleteService` |
| `EntitySuggestionService` | Recognition over prose, suggestion state | `EntityNameIndex`, `ConnectionEngine`, `RecordService` |
| `CanonConflictAnalyzer` | Contradiction rules, canon confidence | `ContinuityAnalyzer`, `RecordService` |
| `EntityProfileService` | The profile and the usage report | `UniversalRecordInspector`, `SeriesService`, `CanonConflictAnalyzer` |
| `EntityNameIndex` | Name matching, shared by every Studio | — |
| `BookScope` | The single definition of book membership | — |

## Universal Entities

The record registry covers People, Places, Organizations, Concepts, Story Objects and
Events. Nine ids were added to close the gaps: `person`, `historical-figure`,
`public-figure`, `guild`, `company`, `military-unit`, `vehicle`, plus `entity-state`,
and `series`/`book` gained real fields.

"Leader", "military group" and "org member" are deliberately **not** types. They are
roles and relationships, already expressed by `memberOf{rank}`. A type for every noun
would make the registry a thesaurus.

`test/universal_entity_vocabulary_test.dart` asserts the coverage claim rather than
leaving it to prose.

### A reserved id

`universe` is already a **cosmic place** type while `RecordScopeType.universe` means a
canon container. Anything building the master plan's M4 universe scope must use
`story-universe`, which is reserved and pinned by a test.

## Cross-Book Entities

**The project is the series.** AuthorOS persists one project, so a series is not a
container above projects — it is the project, and a book is a record inside it.

Everything therefore stays inside one project's isolation boundary.
`ConnectionEngine.connect`, `RelationshipValidator`'s endpoint rule and the search
index's project filter are **untouched**, and the guardrail test *"project isolation
holds: the graph cannot link across projects"* keeps passing as the proof.

| Directive term | Representation |
|---|---|
| Series canon | the record itself, `bookId` null, visible from every book |
| Book usage | `appearsIn` link, entity → `book` record, metadata carries role and status |
| Scene usage | `appearsIn` / `mentionedIn` link, entity → scene manuscript node |
| Chapter → book | `ManuscriptChapter.bookId`, projected into the chapter node |
| Version/state | an `entity-state` record holding only what differs from canon |

### The three rules

- **B-1.** Book membership is `AuthorRecord.bookId`. Never derived, never inferred from
  links, changed only by an audited author action.
- **B-2.** A `book` record's own `bookId` is its own id, so `bookId == null`
  unambiguously means series canon rather than "unfiled".
- **B-3.** `RecordScopeType.book` stays reserved. `RecordScope` requires a `seriesId`
  for book scope and there is no series *scope* inside one project, so book-specific
  records stay project-scoped and carry their book in the column the database, its
  index and the search index already read.

Every read of book membership goes through `BookScope`. If a future multi-project
library ever makes each book its own project, "which book is this in" changes in one
file rather than at every call site.

### What this unlocked for free

`searchByBook`, `UniversalSearchFilter.bookId`, the `author_records_series_book` index
and the FTS `book_id` column were all already built. They returned nothing because no
service had ever set the column.

### Why a state is a record and not an overlay row

`BranchRecordOverlayRows` has the right shape, and the wrong meaning. A branch overlay
is a what-if deliberately kept out of canon. A book state **is** canon at a point in the
series, so it has to be searchable, linkable, versioned and exported like any other
record. It is a difference, never a copy: editing canon still reaches every book that
does not override that field.

## Entity Recognition

One matcher, in `lib/core/entity_recognition.dart`. Manuscript, Codex and World Studio
previously each carried a byte-identical private `_mentions`; a guardrail test now fails
if a fourth appears.

Exact, case-insensitive, word-boundary matching against titles and aliases the author
wrote down. No fuzzy matching, no stemming, no scoring, no model. Names shorter than four
characters are ignored — a blunt rule that will miss a genuinely short name, and the
deliberate trade for a recogniser that does not cry wolf.

| State | Rule |
|---|---|
| Confirmed | an `appearsIn`/`mentionedIn` link already joins entity and scene |
| Suggested | exactly one entity answers to the name, nothing connects them |
| Unconfirmed | the name means two entities, or none |

Recognition is book-aware: a Book 2 entity is not suggested against a Book 1 scene.

## Entity Suggestions

Link, Ignore, Create Entity, Create Alias, Review.

Create Entity delegates to `ContinuityActionService`, which already knows how to mint a
character or a location and refuses when a matching record exists. It accepts only those
two kinds — anything else belongs in its own Studio, where its required fields are known.

**A scan writes nothing.** A test pins that scanning leaves the record and link counts
untouched. Only an explicit author action mutates anything, and `link` refuses an
ambiguous name until the author says which entity they meant.

A promoted link carries `extensionData {derivedFrom: entityRecognition, matchedName}`,
so a relationship AuthorOS proposed can always be told from one the author drew by hand.

Dismissals persist on a project-scoped infrastructure record — the same class of thing as
a saved view or a pin, and stored the same way. Written straight to the repository rather
than through `RecordService`: dismissing a suggestion is housekeeping and should not put a
version snapshot in the author's history per click. Unlike a table it also travels in the
archive. A dismissal silences an open question and never an established fact — linking an
entity the author previously ignored still reads as Confirmed.

## Canon Management

`CanonFactStatus` gives the directive's seven values without touching `CanonStatus`,
which is persisted in a database column and an FTS column and describes a whole record
rather than one field.

- Retired maps onto the existing `deprecated`.
- **Contradicted and Unknown are derived and refuse to be stored.** A stored
  "contradicted" goes stale the moment the author fixes the disagreement, so writing one
  throws.

Four contradiction rules, all over typed data:

1. Canon versus a book state — the directive's own example, profile says 27 and Book
   Three says 29. Two drafts disagreeing are alternatives, not a contradiction.
2. A number that cannot go backwards. Which fields are monotonic is declared, not
   inferred.
3. Duplicate canon — two active canon records sharing a title or alias.
4. A relationship there can only be one of — two birthplaces contradict, two friends
   do not.

**Prose is never parsed for facts.** A rule that guessed at a number in a sentence would
produce contradictions the author has to argue with, and the first false accusation is
the one that gets the whole feature switched off.

`canonConfidence` is a pure function of a declared status and three counts, pinned to the
digit by a test. A confidence an author cannot predict is a confidence they cannot use.

The analyzer performs zero writes — pinned, including revision counts.

## Where Is This Used

`EntityUsageReport` groups usage Books → Chapters → Scenes, with buckets for plot,
timeline, map and research. Built from a single `UniversalRecordInspection` rather than a
second walk of the edge table; a second traversal would be a second answer.

Manuscript structure is read through `repository.manuscriptNodesByProject`, never through
`ManuscriptStore.loadStudio` — that seeds a starter manuscript on a project nobody has
opened, and a report must not be able to invent a chapter by looking at one.

Derived usage is returned in its own collection and never merged with recorded usage.

## Universal Entity Profiles

`EntityProfileView` renders the same sections for a character, a city and plain lore. It
is reusable across Studios on purpose: the profile belongs to the entity, not to the
screen showing it. Story Codex hosts it as a Profile tab.

## User Interface

| Surface | What it does |
|---|---|
| Series Studio (`StudioSection.series`) | Books, order, chapter assignment, per-book rosters |
| Codex Profile tab | The full profile and usage explorer |
| Manuscript continuity panel | Suggestions for the open scene, below the continuity issues |

`SearchDestination.seriesStudio` now routes to the Series Studio at all four sites that
previously dead-ended at the hardcoded Projects demo.

## Known Limitations

- **Ghost manuscript nodes (audit R-1).** `putManuscriptNodes` is upsert-only and
  `ManuscriptNodeReference` has no status, so a deleted scene leaves its node behind.
  The usage report surfaces these as ghosts rather than counting them as real usage.
  Fixing the lifecycle belongs to the separately-directed Story Graph Phase 0 milestone.
- **Scene prose is outside the graph and outside the archive (audit R-2).** Recognition
  reads `SharedPreferences` content the archive does not export. The suggestions and the
  links they produce are archived; the prose they came from is not.
- **`EntityProfileService`'s derived usage sees only what a manuscript node carries** —
  its title and notes, not the scene body. The manuscript-side scan sees the full text.
- **`_ProjectsStudioView` is still a hardcoded demo.** Two screens now list the author's
  work and one of them is fiction. Deciding what Projects becomes is a product call.
- **One project, one series.** Master plan M4's multi-project series remains future work;
  see below.
*(Resolved: `changeScope` used to erase sibling scope columns. It now preserves anything
the caller did not name — see Scope Changes below.)*

## Scope Changes

`RecordService.changeScope` **preserves the scope columns you did not ask it to change.**
Passing `seriesId`, `bookId` or `branchId` sets it; passing the matching `clear…` flag
nulls it; omitting both leaves it alone. The asymmetry exists because Dart cannot tell an
omitted named argument from one passed as null, so losing data takes an explicit flag.

It previously assigned all three unconditionally, which meant a scope move silently erased
whichever of them the caller had not thought to re-supply — a record could lose its book
membership as a side effect of a move that had nothing to do with books.

`changeBookAssignment` is a thin wrapper over it: book membership changes often and on its
own, so it gets a method that says so and cannot be called with the wrong scope by
accident. Both share one write path, so they cannot disagree about which columns a move
carries or how it is audited.

Scope consistency is enforced either way — `RecordValidator` runs `RecordScope.validate`,
so a book scope without a matching `bookId` is rejected with `invalid-scope-hierarchy`
rather than written, and a rejected move leaves the record untouched. The audit trail
records `previousBookId`/`newBookId` and its siblings only when they actually move.

## Forward Path to M4

If a real multi-project library later makes each book its own project:

1. For each `book` record `B`: mint a project id; re-home every record with `bookId == B`
   and the matching manuscript chapters.
2. Records with `bookId == null` become series-scoped.
3. Rewrite `record_link_rows.scopeId` to the narrowest scope both endpoints share.
4. Relax exactly one function — `RelationshipValidator`'s endpoint-project rule —
   replacing "both endpoints share a projectId" with "both endpoints sit in the writing
   project's scope chain".

**No entity id and no link id changes in any step.** That is what `BookScope` exists to
protect: step 4 is a one-function change because nothing reads `record.bookId` inline.

## Tests

| File | Pins |
|---|---|
| `universal_entity_vocabulary_test.dart` | §1.1 coverage, the series spine, book-usage metadata, the reserved `universe` id |
| `series_service_test.dart` | Book lifecycle, membership, promote/restrict reversibility, `searchByBook`, close and reopen |
| `manuscript_book_assignment_test.dart` | Chapter→book, scene inheritance, legacy blobs, reads that never seed |
| `entity_book_state_test.dart` | One entity across four books, canon showing through, archive round trip |
| `entity_recognition_test.dart` | The matcher, aliases, ambiguity, longest-name-first, one-matcher guardrail |
| `entity_suggestions_test.dart` | Three states, five actions, dismissal persistence, scans that never write |
| `canon_conflict_test.dart` | Each rule and its near-miss, the confidence arithmetic, zero writes |
| `entity_profile_test.dart` | Usage grouping, derived kept apart, profile assembly, zero writes |
| `entity_profile_view_test.dart` | Header, empty state, contradiction surfaced not resolved |
| `series_studio_view_test.dart` | Book list, chapter assignment, no persistence of its own |
| `record_scope_change_test.dart` | `changeScope` preserves unnamed columns; `clear…` flags; scope validation; audit metadata |
