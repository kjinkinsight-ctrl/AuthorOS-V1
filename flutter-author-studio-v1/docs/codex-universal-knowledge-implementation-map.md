# AuthorOS — Codex / Universal Knowledge

Status: **Phase 1 implemented — cross-book scope is live. Phases 2-4 designed, not built.**
Audited: 2026-08-22, from the working tree at `d1b74c8` (PR #35, Knowledge Graph)
Scope: series-wide and cross-book knowledge in the Story Codex, and the phase
order for the rest of the Codex vision
Builds on: `docs/story-codex-implementation-map.md`,
`docs/universal-story-graph-architecture.md`,
`docs/authoros-2-master-plan.md` §6.1, §12, §14 (M4)
Decision in force: **D-3** — scenes and chapters remain manuscript-domain nodes

---

## 0. What this milestone is

The Codex vision has three parts: **cross-book knowledge**, **automatic
intelligence**, and **structured knowledge**. The audit below found that the
third is largely built, the first was plumbed but never instantiated, and the
second has a foundation nobody has pointed at prose yet.

They are not independent. Cross-book scope is the substrate: entity recognition
that cannot see book two's characters is a worse feature, and a reader-facing
export that cannot express "this is series canon" is a wrong one. So Phase 1 is
scope, and it is the phase this document ships.

**Codex and Knowledge Graph stay distinct.** The Codex is what the author knows
about the world. The Graph is how it connects. They read the same records
through the same repository; neither owns the other's storage.

### The graph boundary, restated for scope

A scope is not a node. `series` and `project` records exist so that scope has
somewhere indexed to live, but they describe containment, not the world, and
`kScopeContainerTypeIds` keeps them out of every list of *entries*. This is the
same rule `kNonGraphRecordTypeIds` applies to the graph's own canvas.

---

## 1. Repository reality discovered

Audited before writing any code. Every claim here was checked against the tree,
not carried forward from an earlier document.

| Claim | Finding |
|---|---|
| The Codex is unbuilt | **False.** `story_codex_service.dart` (1428 lines), `story_codex_workspace.dart` (4009 lines, 7 tabs), `core/story_codex_domain.dart` (655 lines). Templates, categories, tags, collections, saved views, sources, aliases, per-field visibility, branches, validation, safe-delete and version history all exist |
| Series scope is unmodelled | **False.** `RecordScopeType` has carried `library, universe, series, project, book, branch, manuscript` since Universal Records. `AuthorRecordRows` has `scope_type, scope_id, project_id, series_id, book_id, branch_id, canon_status` plus the `author_records_series_book` index, and the FTS5 table indexes `series_id`/`book_id`/`canon_status` |
| Nothing writes a series | **True, and this was the gap.** No UI ever set `seriesId`; no series record instance had ever existed; `SearchDestination.seriesStudio` routed to a placeholder |
| Reads are project-bound | **True.** Every read was `recordsByProject(projectId)` or `recordsByScope(scopeId)`. `UniversalSearchService.searchBySeries` filtered *within* one project |
| `StoryGraphFilter` cannot filter by series | **False.** `story_graph_service.dart:523-527` already filters `seriesId`/`bookId`/`branchId`. It had no data and no control |
| Promote/demote needs new machinery | **False.** `RecordService.changeScope` already preserved id, `createdAt` and `typeId`, bumped revision, validated through `RecordScope.validate()`, and wrote `AuditChangeType.scopeChanged` through `putRecordWithHistory`. It had two callers, both in tests |
| `_ProjectsStudioView` manages projects | **False.** `lib/main.dart:1982` is an in-memory `List<_ProjectRecord>` seeded in `initState`, never persisted. The application is effectively single-project: one `StarterProject` from onboarding, in shared preferences |
| `getEntries` is a scoped query | **False.** It read `repository.snapshot()` — every row in the database — and filtered in Dart |

### Three blockers the design had to clear

1. **Links are bound to one project.** `ConnectionEngine.connect` and
   `RelationshipValidator` reject an edge whose endpoints are not the engine's
   project (invariant I-2, pinned by `story_graph_architecture_test.dart`). A
   `partOfSeries` edge is therefore unbuildable without relaxing project
   isolation. Membership is a column instead.
2. **History forked per editor.** `VersionAuditService._build` stamped the
   *calling service's* `projectId` on every version and used it to find the
   previous one. Promote in book one, edit from book two, and the record grew
   two disjoint chains each restarting at sequence 1. Fixed here; shipping
   cross-book editing on top of it would have been a silent data-integrity bug.
3. **The FTS snippet index is positional.** `snippet(author_search, 11, …)` is a
   column ordinal. Any new FTS column inserted before `title` silently renders
   the wrong column. This is why cross-book *search* is deferred rather than
   bolted on — see §6.

---

## 2. Files

| Path | Role |
|---|---|
| `lib/core/record_scope.dart` | `kSharedScopeTypes` and `isInheritedSharedScope` — the single definition of "inherited", shared by the repository, the record service, the validator and the Codex |
| `lib/core/scope_resolver.dart` | **New.** `ScopeChain`, `ScopeResolver`, `kScopeContainerTypeIds`. The one answer to "what may this book read?" |
| `lib/core/series_scope.dart` | **New.** `SeriesScope`, `SeriesScopeService` — create, enrol, withdraw, promote, demote, rehome |
| `lib/persistence/authoros_database.dart` | `recordsByType`, `projectsInSeries`, `recordsVisibleToProject`. Queries only — no table, no column |
| `lib/core/version_audit_service.dart` | History partitions by the record's provenance, not by the editor. Adds `getVersionHistoryForRecord` |
| `lib/core/record_service.dart` | Optional `inheritedScopeIds`; `_belongsToProject` admits inherited shared canon |
| `lib/core/record_validation.dart` | Same widening, so a read that succeeds is not followed by a write that fails validation |
| `lib/core/story_codex_domain.dart` | `CodexScopeFacet`, `CodexEntry.scopeFacet`/`isShared`, `CodexEntryFilter.scopes` |
| `lib/story_codex_service.dart` | Scoped reads, `promoteToSeries`/`demoteToProject`, scope-aware relationship reads |
| `lib/story_codex_workspace.dart` | Series control, scope facet, scope chip, shared marker, read-only banner, create-dialog scope selector |

---

## 3. Layering

```
        ScopeResolver          <- resolves Series -> Project, owns no storage
              |
      SeriesScopeService       <- create/enrol/promote/demote, via RecordService
              |
       StoryCodexService       <- a view over records; owns no second store
              |
      StoryCodexWorkspace      <- widgets only
```

Dependency direction is unchanged: core -> storage -> services -> studios.
Nothing added here imports a Studio.

---

## 4. Where a series lives, and what `projectId` means

A series is an ordinary `AuthorRecord`:

```
id:        <seriesId>
typeId:    'series'                  // registered since Universal Records
scopeType: RecordScopeType.series
scopeId:   <seriesId>                // RecordScope.validate: a series names its own scope
seriesId:  <seriesId>                // the indexed column
projectId: <founding book>           // provenance
```

**On a cross-book record, `projectId` is provenance — which book's workspace
authored this row — not containment. Containment is `(scopeType, scopeId)`.**
This is forced, not chosen:

- `RecordScope.validate()` rejects an empty `projectId` for every scope type.
  Null is not available.
- `RecordValidator` admits a record when `scopeId == projectId` **or**
  `owningProjectId == projectId`. Provenance makes the series editable from its
  founding book with no validator change.
- `RelationshipEndpoint.fromRecord` derives an endpoint's project from
  `record.projectId ?? … ?? record.scopeId`. Setting `projectId = seriesId`
  would make the series record unlinkable from every book.
- `_indexEntity` gives the FTS row both a real `project_id` and a real
  `series_id` only if provenance is kept.

Accepted consequence: **shared canon is read-only in every book except the one
that owns it.** That is master-plan §6.1 ("scope inheritance is read-only by
default") falling out of the model rather than being enforced on top of it. The
owning book is where the default is lifted. `rehomeSeries` exists so a series
whose founding book is deleted does not become uneditable.

### Membership is a column, not an edge

`series_id` on the book's own `project` record. One primary-key read answers
"which series is this book in?". Two alternatives were rejected:

- **A `partOfSeries` link.** Blocked by project isolation (§1, blocker 1).
  Relaxing that rule is far larger and more dangerous than reading a column
  that already exists and is already indexed.
- **A membership list in the series record's `fields` JSON.** Unindexed, needs a
  full type scan to answer a per-book question, and puts containment somewhere
  `StoryGraphFilter`, the search index and `RecordVersion` cannot see.

The cost is that a book must exist as a record. `ensureProjectRecord` is
idempotent and runs from `ensureFoundation`, which already materialises
infrastructure records on every Codex open.

---

## 5. Guardrails

`test/scope_architecture_test.dart`, in the shape of
`test/story_graph_architecture_test.dart`. Each pins a decision in this document:

| Test | Pins |
|---|---|
| a series is an AuthorRecord, not a new table | no `series_rows`/`universe_rows`/`scope_rows`; `series` stays a registered record type |
| there is exactly one scope-resolution path | only `ScopeResolver` calls `projectsInSeries` |
| no second scope store has appeared in lib/ | no `series_repository.dart`, `scope_store.dart`, … |
| scope changes only through `changeScope` | `copyWith` still cannot express a scope change |
| no cross-project connection type was introduced | no built-in link id names a series or universe |
| project isolation still holds for a promoted record | a promoted record still cannot link outside its book |
| a record has exactly one history partition | `SELECT DISTINCT project_id FROM record_version_rows` returns one row |
| universe membership has no second home | no `_universe.` field key hides the deferred tier in JSON |
| the shared-scope predicate has one definition | nothing inlines the shared-scope set instead of calling `isInheritedSharedScope` |
| scope containers are named in one place | no hand-rolled `{'project', 'series'}` copy |

---

## 6. Deliberately not in this milestone

- **The universe tier.** `RecordScopeType.universe` exists and the read
  predicate already accepts it, but there is no `universe_id` column, so
  "which universe is this series in?" has no indexed answer. Putting it in a
  `fields` blob is exactly the second resolution path the guardrails forbid.
  When it ships it gets a nullable column via `migrator.addColumn`, following
  the v6 pattern, and `ScopeChain` gains a third link. A guardrail fails today
  if anyone hides it in JSON first.
- **Cross-book search.** `UniversalSearchService` is still project-bound, so
  `searchBySeries` still means "within this book, tagged with this series". Making
  it genuine needs `scope_type`/`scope_id` in the FTS5 table and a schema bump to
  v10, and the new columns must be **appended after `tags`** — `snippet(author_search, 11, …)`
  is a positional ordinal for `body`. Nothing regresses by deferring it: search
  works exactly as it did.
- **Graph reads across books.** `StoryGraphService` still sources nodes from
  `recordsByProject`, so shared canon does not yet appear in book two's graph.
  The filter half is already built. Edges stay project-owned either way.
- **Real multi-project management.** `_ProjectsStudioView` is untouched. Because
  the running app has one book, cross-book reads are proven in tests but cannot
  yet be *demonstrated* in the UI by opening a second book. That is the honest
  cost of not rewriting project management in this PR, and it is the next PR.
- **`SearchDestination.seriesStudio`** still routes to the placeholder.

---

## 7. Carried risks — stated, not fixed

Existing risks from `docs/universal-story-graph-architecture.md` §18 that this
milestone touches or inherits:

- **R-8** — seven raw validated-write bypasses in `story_codex_service.dart`.
  Records written through those paths skipped validation; the scope layer reads
  them as-is and cannot tell.
- **R-2 / R-22** — prose and writing sessions are still outside the archive. A
  series exported and restored is structure-only. Scope does not change this,
  and must not be read as evidence that it did.
- **New: shared canon is not in the portable archive as a series.**
  `AuthorOsArchiveService` is project-scoped. Exporting book one carries the
  records it owns, including ones it promoted, but there is no series-level
  archive. M4's "portable series/universe archive" is unmet.
- **New: a member book sees shared canon with no relationships.** Edges are
  project-owned, so book two sees a shared character with only the edges book
  two drew. This is correct under I-2 and is documented rather than fixed; the
  Codex returns book two's own edges instead of throwing.

---

## 8. The remaining phases

**Phase 2 — automatic intelligence, deterministic.** No new engine and no model.
`ManuscriptContinuityIntelligence` already flattens records into alias-bearing
known names and matches them in scene prose; `CodexContinuityIntelligence`
already emits the finding/action pair the workspace renders and resolves. Phase 2
widens the record set those analyzers receive from project-scoped to
`recordsVisibleToProject` — so a series character is recognised in book three's
prose — adds a `suggestedLink` finding kind, and surfaces an inbox that is a
*filtered view over findings*, not a second store. Co-occurrence discovery is a
derived read and must be returned as a derived edge, never written as a
`RecordLink`. This is string matching over author-authored aliases: exactly the
AI-free differentiator `NEXT.md` §9 sells, and the determinism master-plan §12
requires.

**Phase 3 — hierarchical worldbuilding and deep linking.** The universe tier
lands here and pays for the `universe_id` column. Hierarchy *inside* a scope —
continent contains region contains city — is the existing `partOf` connection
type plus a `StoryGraphMode` that walks only `partOf`; no new edge model.
Deep linking is a `[[Name]]` resolver over the alias index Phase 2 builds,
routing through the existing `searchDestinationForType`.

**Phase 4 — reader-facing presentation.** `CodexFieldVisibility`
(`publicKnowledge`/`privateKnowledge`/`authorKnowledge`) is already stored
per-field and already editable in the workspace; nothing consumes it. Phase 4 is
a read-only projection that drops every field not marked public, plus a reveal
point resolved deterministically against reading position. A renderer over
existing data — no second store, no second copy of an entry, no second
visibility model.

---

## 9. Verification

Run locally against Flutter **3.44.9** (revision `6b182d2c75`) — the revision
`.metadata` records and CI pins.

| Step | Baseline at `d1b74c8` | After this milestone |
|---|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | 57 issues, 0 errors | **57 issues, 0 errors** |
| `flutter test` | 1153 passed, 0 failed | **1189 passed, 0 failed** |
| `flutter build web --release --no-web-resources-cdn` | green | green |

The analyzer count is unchanged: this work added no new issues and cleared the
six it introduced along the way. The 36 new tests are
`scope_resolver_test.dart` (7), `series_scope_test.dart` (6),
`scoped_records_test.dart` (8), `scope_architecture_test.dart` (10),
`story_codex_series_view_test.dart` (5).

### Gate

- [x] a book can start a series, join one, and leave one
- [x] an entry can be shared with the series and returned to its book
- [x] moving an entry in and out preserves its id, creation time, fields, tags
      and relationships (master plan §14, M4)
- [x] a member book reads shared canon; a non-member book does not
- [x] a book-scoped record that merely carries a series id is not shared
- [x] shared canon is read-only in books that do not own it, and the save path
      refuses the write rather than only hiding the button
- [x] a shared record keeps one version chain across books
- [x] a book that belongs to no series reads exactly what it read before

### Not verified here

Manual exercise on a packaged target, and close/reopen persistence in the
running app, per the batch discipline in
`docs/story-codex-implementation-map.md`. The application is single-project, so
the two-book path cannot be walked by hand yet — it is covered by
`scoped_records_test.dart` and `story_codex_series_view_test.dart`, both of
which drive two real project ids against one database.
