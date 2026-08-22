# Series Identity — architecture delta (Q-S1)

Status: **ACCEPTED and IMPLEMENTED.** Approved 2026-08-22; built the same day.
Decision: the Projects/Series system is the canonical owner of series identity.
The Codex consumes it and mints none.
Audited: 2026-08-22, working tree at `5d1c794` (PR #53), `main` merged at `9b629e4`
Implemented against `main` at `df6bcad`
Unblocks: Codex Phase 3 and further scope expansion
Related: `docs/codex-universal-knowledge-implementation-map.md` §6a (Q-S1)

---

## 0. The headline

**The two systems already agree on project identity, and every future consumer
already reads the same column.** The gap is one hop wide: nothing copies the
roster's `series_id` onto the records.

```
ProjectRosterEntry.projectId  ==  project.id  ==  StarterProject.id  ==  the
Codex's projectId
```

That is not a coincidence to be exploited — it is the join key, and it means the
mapping needs **no id translation, no lookup table, and no backfill of project
ids**. What it needs is a direction of flow and one resolver change.

---

## 1. Current `SeriesRows` identity (the roster's series)

| | |
|---|---|
| Domain type | `WritingSeries` — `lib/core/writing_series.dart:20` |
| Fields | `id`, `name`, `defaultTargetWords`, `createdAt`, `updatedAt` |
| Id format | `series_<microsecondsSinceEpoch>_<sequence>` — `WritingSeriesId.create()`, `writing_series.dart:134` |
| Table | `SeriesRows` — `id` (pk), `name`, `defaultTargetWords`, `createdAt`, `updatedAt` |
| Membership | `ProjectRows.seriesId` + `ProjectRows.seriesPosition`, surfaced as `ProjectRosterEntry.seriesId` / `.seriesPosition` |
| Standalone | `seriesId == null`. `ProjectSeriesMembership.standalone()` distinguishes "is standalone" from "sender did not know" (`sync/project_sync.dart:108`) |
| Repository | `allSeries`, `seriesById`, `putSeries`, `deleteSeries`, `booksInSeries`, `projectRosterEntry`, `putProjectRosterEntry` |
| Service | `ProjectRosterStore` — including **`seriesForProject(projectId)`** |
| Synced | Yes. `SyncRecordTypes.series` and `SyncRecordTypes.project`, membership on the project envelope |
| UI | Projects Studio — `lib/main.dart`, keys `projects-series-new`, `projects-new-series-field`, `projects-series-dialog`, `projects-series-move-up/down-<projectId>` |
| Delete | `deleteSeries` releases every member book to standalone in one transaction, and records the membership change for each freed book so other devices can follow |

**What it is:** the author-facing planning object. A name, a word target a
joining book inherits, and an order. It is created where an author thinks about
their series, and it is the only one of the two with a UI, a sync contract and a
delete policy.

## 2. Current `SeriesScope` identity (the Codex's series)

| | |
|---|---|
| Domain type | `SeriesScope` wrapping an `AuthorRecord` — `lib/core/series_scope.dart` |
| Storage | No table. An ordinary `AuthorRecord`, `typeId: 'series'`, `scopeType: series`, `scopeId == seriesId == record.id` |
| Id format | `series-<slug>-<microsecondsSinceEpoch>` — `series_scope.dart` `_slug` path |
| Membership | `AuthorRecordRows.seriesId` on the book's own `project` record, resolved by `ScopeResolver.chain()` |
| Standalone | `ScopeChain.isStandalone`; a dangling series id resolves to standalone rather than throwing |
| Service | `SeriesScopeService` — `createSeries`, `enrol`, `withdraw`, `promoteToSeries`, `demoteToProject`, `rehomeSeries` |
| Synced | No |
| UI | Codex header control — keys `codex-series-button`, `codex-series-start`, `codex-series-join-<id>`, `codex-series-leave` |
| Delete | None. A series record can be archived like any record |

**What it is:** the *scope* a record can be owned by, so canon is shared rather
than retyped. It exists because `AuthorRecordRows.series_id` needed a value.

**It is younger, has no UI story of its own worth keeping, and no sync
contract.** That asymmetry is most of the argument for direction.

## 3. The exact mapping

One hop, no translation:

```
ProjectRosterStore.seriesForProject(projectId).id          <- canonical
        │
        │  (identical string, no lookup, no mapping table)
        ▼
ScopeChain.seriesId
        │
        ▼
AuthorRecordRows.series_id   +   scope_type = 'series', scope_id = <that id>
```

Because `ProjectRosterEntry.projectId => project.id` (`project_roster_entry.dart:44`)
is the same `StarterProject.id` the Codex is constructed with, the two systems
are already keyed alike. The mapping is **identity**, not a correspondence.

Concretely, `ScopeResolver.chain()` changes from *"read `series_id` off the
project record"* to *"ask the roster"*:

```
current:  repository.recordById(projectId).seriesId
proposed: rosterStore.seriesForProject(projectId)?.id
```

The `project` `AuthorRecord` stops being the source of membership. It may keep
`series_id` as a **denormalised mirror** — see §5 — but it stops being read as
truth.

**Two name collisions to fix while doing this.** They are currently the easiest
way for a future reader to wire the wrong world:

| Name | Roster meaning | Scope meaning |
|---|---|---|
| `allSeries()` | `ProjectRosterStore.allSeries()` → `List<WritingSeries>` | `SeriesScopeService.allSeries()` → `List<SeriesScope>` |
| "books in series" | `repository.booksInSeries(id)` → roster entries | `repository.projectsInSeries(id)` → `AuthorRecord`s |

Both pairs take a `seriesId` from what are today disjoint id spaces. Once the id
spaces merge, only the return type distinguishes them. Rename the scope-side pair
on implementation.

## 4. Which system becomes canonical

**The roster. `SeriesRows` owns identity, name and membership.**

Four reasons, in order of weight:

1. **Identity belongs where the author creates the thing.** A series is named
   in the Projects Studio. A system that mints a second id for the same act is
   creating a fact the author did not.
2. **It is the only one with a sync contract.** `SyncRecordTypes.series` already
   replicates series across devices, and the project envelope already carries
   membership with a deliberate "unknown vs standalone" distinction. Making the
   Codex canonical would mean either building a second sync contract or leaving
   canon unsynced while planning syncs.
3. **It is the only one with a delete policy.** `deleteSeries` releases books in
   a transaction and records each freed book. Scope has no answer for deletion
   at all.
4. **It has the UI, and a consumer.** Series creation, ordering and membership
   are built and tested (`test/projects_studio_test.dart`), and
   `SeriesAnalyticsService` already resolves a book's series through
   `ProjectRosterStore.seriesForProject`. Making the Codex canonical would return
   `null` there for every book unless the roster row were populated anyway —
   which is the proposal, reached from the other direction.

   Two gaps in that UI for whoever implements: there is **no rename** and **no
   delete** control for a series, though `saveSeries` supports rename as an
   id-keyed upsert.

**What scope keeps:** the record-level meaning. `scopeType: series` and
`scope_id` stay exactly as they are, because that is what makes a record shared
rather than book-private, and that is what every consumer already reads.

**What scope loses:** the right to mint an id. `SeriesScopeService.createSeries`
stops being a public authoring path.

> This is already reversible-by-design: `createSeries` takes an optional `id` and
> a guardrail asserts it, so scope has never minted an identity it could not have
> been handed. Locking the direction is a change to callers, not to the layer.

## 5. Migration and compatibility

Three populations, and one of them is empty today.

**(a) Records already promoted to a Codex-minted series.** Population: **zero in
any shipped build.** `SeriesScopeService` has never been in a release, and its id
format (`series-<slug>-<micros>`) is distinguishable from the roster's
(`series_<micros>_<seq>`), so a migration can find them exactly if one is ever
needed. Recommendation: **no migration.** Detect-and-log, and treat a
Codex-format series id as a defect rather than silently rewriting an author's
scope.

**(b) The `project` AuthorRecord's `series_id`.** Currently written by
`enrol`/`withdraw`. Under the proposal it becomes a **mirror**, written only by a
sync-down from the roster. Two options:

- **B1 — keep the mirror.** `recordsVisibleToProject` and the FTS index keep
  working unchanged; one write must be kept honest.
- **B2 — drop the mirror,** resolve membership from the roster on every read.
  Fewer places to disagree; adds a roster read to a hot path and makes the
  repository depend on a store above it, which inverts the current layering.

Recommendation: **B1**, with the mirror written in exactly one place and a
guardrail that nothing else writes it.

**(b2) A project the Codex sees but the roster has never heard of.** The
sharpest edge in this design. `OnboardingStore.saveProject` writes the
shared-preferences pointer and queues sync but **does not write a roster row**;
`ProjectRosterStore._adoptLegacyProject` backfills one only when the roster is
*entirely empty*. Meanwhile `ScopeResolver.ensureProjectRecord` is lazy and runs
only on first Codex open. Each side can exist without the other.

Under the proposal such a project resolves to standalone — correct, non-fatal,
and **wrong for the author**, because it would silently hide series canon from a
book they consider part of a series. Mitigation must be explicit:
`ensureProjectRecord` should ensure a *roster* row too, or the Codex should treat
"no roster entry" as a condition to repair rather than a synonym for standalone.
Decide and test this during implementation.

Expect **`legacy-<base64url(title|genre|projectType)>`** project ids in the wild
too, minted by `StarterProject.fromJson` for pre-id installs. They join fine;
they simply do not match the `project_<micros>` format.

**(c) A series deleted while records are scoped to it.** `deleteSeries` releases
books but knows nothing about records owned by that scope; those records would
keep `scope_id` pointing at a series that no longer exists. `ScopeChain` already
degrades safely (a dangling id reads as standalone), so nothing crashes — but
the records become unreachable from any book.

Worth being precise about the trigger: **there is no delete-series control in the
UI today.** `ProjectRosterStore.deleteSeries` is reachable only from
`SeriesApplier.applyDelete` — a deletion arriving by sync from another device.
That makes it rarer than it looks, and also worse: it lands without the author
asking for it on this device.

Recommendation: **deleting a series must first demote its records to their
provenance book**, reusing `demoteToProject`, which already preserves ids,
fields, tags and links. That makes deletion symmetric with `deleteSeries`'s
existing promise that projects survive. **This must be designed and tested
before the identity change ships, not after.**

## 6. How cross-book entity sharing resolves through the canonical id

Unchanged in mechanism; only the source of the id moves.

```
Book 2 opens the Codex
   │
   ├─ ScopeResolver.chain(projectId)
   │     └─ rosterStore.seriesForProject('book-2') -> series_1724...
   │
   ├─ ScopeChain{ projectId: 'book-2', seriesId: 'series_1724...' }
   │
   └─ repository.recordsVisibleToProject('book-2',
                inheritedScopeIds: {'series_1724...'})
         → book-2's own records
         ∪ records where scope_type IN ('series','universe')
                     AND scope_id = 'series_1724...'
```

"Kali is the same character across Books 1–5" is then literally one record with
`scope_type = 'series'`, readable from every member book, with one id and one
version history — the history-partition fix in Phase 1 is what makes editing her
from Book 3 safe.

**On the per-book layer in your example** (Kali's universal canon plus Book 1
injuries, Book 2 abilities): the mechanism for that already exists and is tested.
`BranchRecordOverlay` (`lib/core/branch_domain.dart:69`) is exactly the right
shape — `inherited | overridden | created | hidden`, a partial `fields` override,
`removedFieldIds`, per-scope. Today it is keyed by `branchId`. A per-book view of
series canon is the same overlay keyed by book.

That is a strong argument for **not** inventing a per-book annotation model
later, but it is **out of scope for this decision** and is called out only so the
identity model does not foreclose it. It does not: an overlay keys off a record
id and a scope id, both of which this proposal leaves intact.

## 7. How standalone books keep working

Untouched, and this is a requirement rather than a side effect — the master plan
calls for progressive complexity, and most authors never write a series.

- `seriesForProject` returns `null` → `ScopeChain.isStandalone` → `inheritedScopeIds`
  is empty → `recordsVisibleToProject` **is byte-for-byte `recordsByProject`**
  (the method short-circuits on an empty set).
- The Codex's scope facet, scope chip and share action are already hidden when
  `isStandalone`. No standalone author sees a control for a concept they do not
  have.
- A project with no roster entry resolves to standalone rather than failing —
  but see §5(b2): that path also covers a project the roster has not caught up
  with, and those two cases must not stay indistinguishable.

Covered today by `test/scope_resolver_test.dart` ("a book with no record resolves
to standalone", "a dangling series id resolves to standalone rather than
throwing") and by the "with no inherited scope the visible read is the project
read" case in `test/scoped_records_test.dart`.

## 8. How the other Studios consume the same identity

**They already do, and this is the strongest argument for the whole proposal.**
Every consumer reads `AuthorRecordRows.series_id` or the `StoryGraphFilter`
built from it. None of them needs to learn about the roster.

| Studio | Consumes today | Change needed |
|---|---|---|
| **Story Graph** | `StoryGraphFilter.seriesId`, applied at `story_graph_service.dart:523`. `main`'s `a2f5f87` already reads a null `bookId` as "series canon, not book-specific" | None to the filter. Its node source is still `recordsByProject`; widening it to `recordsVisibleToProject` is Codex Phase 3 work, not identity work |
| **Codex** | `ScopeChain` → `recordsVisibleToProject` | The one hop in §3 |
| **Timeline** | `TimelineService` accepts and filters `seriesId` (`timeline_service.dart:634,648`) | None |
| **World** | Preserves `seriesId` across updates (`world_service.dart:335`) | None |
| **Map Studio** | No series awareness at all today | None now. When it gains one, it reads the same column |
| **Search / FTS** | `author_search` indexes `series_id` | None. Cross-book *search* still needs the v10 rebuild, unchanged by this |
| **Version / Audit** | `RecordVersion` and `AuditEvent` carry `seriesId` | None |

One column, one meaning, every Studio. That is what makes this the cheap moment
to decide: the consumers are already aligned, and only the producer is ambiguous.

---

## Recommended shape, in one paragraph

`ProjectRosterStore` owns series identity. `ScopeResolver` gains a roster
dependency and answers `chain()` from `seriesForProject`. `SeriesScopeService`
keeps `promoteToSeries` / `demoteToProject` / `rehomeSeries` and loses
`createSeries` / `enrol` / `withdraw` as authoring paths. The Codex's series
control stops offering "start a series" and instead shows the roster's series,
or points the author at the Projects Studio when there are none. The `project`
record's `series_id` becomes a mirror with a single writer. Deleting a series
demotes its scoped records first.

## Open items this design does not settle

1. **Where the Codex sends an author with no series.** Cross-Studio navigation
   from the Codex to the Projects Studio does not exist yet.
2. **Whether scope should sync.** The roster syncs; records do not yet. Out of
   scope here, but the answer changes what "canonical" buys.
3. **Universe.** Still no indexed column, still deferred. The chain extends; it
   does not get rewritten.

## Verification plan (for the implementation that follows approval)

- `scope_resolver_test.dart`: chain resolves from the roster; standalone when the
  roster says standalone; standalone when there is no roster entry.
- New: a roster series and a Codex read agree on one id, end to end.
- New: deleting a roster series demotes its scoped records and loses nothing —
  ids, fields, tags and links preserved, asserted the way the M4 gate is.
- Guardrail: exactly one writer of the `project` record's `series_id`.
- Guardrail: the Codex mints no series id.
- Regression: the 1749 currently passing tests, and the analyzer at 57/0.

---

## Implementation record

Built as designed, with three departures worth recording:

1. **The `series` `AuthorRecord` is gone entirely.** The design said scope keeps
   `scopeType`/`scope_id` and loses only the right to mint an id. In building it,
   keeping a series *record* as well as a `series_rows` row turned out to be the
   same duplication the decision exists to remove — two representations of one
   series, one of them unreachable by the Projects Studio. A series now exists in
   `series_rows` and nowhere else; scope is `(scopeType: series, scopeId:
   <roster id>)`, validated against `series_rows` rather than against a record.
   `rehomeSeries` went with it: there is no record whose provenance could move.

2. **`ScopeResolver` reads the repository, not `ProjectRosterStore`.** The design
   named the store. The store lives above `lib/core/`, so depending on it would
   have inverted the layering the whole architecture rests on. `repository
   .projectRosterEntry(projectId)` is the same canonical row without the
   inversion; the store's extra work (positions, sync recording) is for writes,
   which the resolver does not do.

3. **§5(b2) is answered, not deferred.** `ScopeResolver.ensureRosterEntry` adds
   an absent book to the roster as **standalone** — the truthful default for a
   book nothing has placed in a series — and `membershipUnknown()` lets a caller
   tell "standalone" from "the roster has not caught up". Repair never guesses at
   membership and never overwrites an existing row.

§5(c) shipped as designed: `ProjectRosterStore.deleteSeries` now calls
`SeriesScopeService.releaseSeries` before the delete, demoting shared canon back
to the books that authored it. A record whose provenance book is gone is
reported rather than guessed at.

The two name collisions from §3 are resolved: `repository.projectsInSeries`
became `recordsInSeriesScope` ("what canon does this series hold?", as against
the roster's `booksInSeries`, "which books are in it?"), and
`SeriesScopeService.allSeries` is gone with the rest of the authoring surface.

### What the Codex looks like now

The series control is a read-only chip naming the book's series. There is no
"start a series", no join, no leave — a guardrail asserts those keys are absent.
Sharing and returning an entry remain, because those are scope operations, not
identity ones.

### Verification

| Step | `main` at `df6bcad` | This branch |
|---|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | 59 issues, 0 errors | **59 issues, 0 errors** |
| `flutter test` | 1922 passed, 0 failed | **1928 passed, 0 failed** |
| `flutter build web --release --no-web-resources-cdn` | green | green |

Net **-267 lines in `lib/`**: removing a duplicate identity system is most of
what this change is.

Guardrails now pinning this decision, in `test/scope_architecture_test.dart`:

- *the roster owns series identity and the Codex mints none* — only
  `writing_series.dart` defines the generator and only the Projects Studio calls
  it; `series_scope.dart` contains no `createSeries`, `enrol` or `withdraw`
- *membership has exactly one source of truth* — a `project` record carrying a
  stale `series_id` cannot contradict the roster row
- *deleting a series never strands its canon*
