# AuthorOS — Intelligence Layer

Phase 1 — Structural conditions across the whole project

Status: implemented
Scope: `flutter-author-studio-v1/lib/intelligence/`

---

## 1. Why this exists

AuthorOS reported statistics. It could tell an author they had 143 world
entities; it could not tell them that 27 of those entities never reach the page.

The machinery to answer the second question was largely already present, and
entirely invisible:

| Already existed | Where | Reachable from the UI? |
|---|---|---|
| `ContinuityAnalyzer.summaryFor` — severity, score, recommendations | `lib/continuity.dart` | Yes, per record |
| `ContinuityAnalyzer.analyze` — character overlap, impossible travel, invalid range, impossible sequence | `lib/continuity.dart` | **No. No production caller at all** |
| `ContinuityTimelinePanel` | `lib/continuity.dart` | **No. Tests only** |
| `ManuscriptContinuityIntelligence.analyzeScene` — unlinked mention, unknown location, unknown POV | `lib/manuscript_continuity.dart` | Yes, one scene at a time |
| `WorldContinuityIntelligence`, `CodexContinuityIntelligence` | `lib/world_continuity.dart`, `lib/codex_continuity.dart` | Yes, one record at a time |
| `PlotService.validatePlot` — `unresolved-plotline`, `unresolved-arc`, `missing-payoff`, … | `lib/plot_service.dart` | Yes, inside Plot Studio |
| `ContinuityActionService` — one-click create/link/review | `lib/continuity_actions.dart` | Yes |

Every one of those answers for **one record, inside that record's own panel**.
Nothing asked the project-wide question, which is the question an author
actually has. This phase adds that, and wires up the timeline engine that was
already written and never called.

It is an **aggregator over the validators that exist**, not a second validation
system — which `docs/story-graph-phase-0-integrity-directive.md` forbids.

---

## 2. Architecture

```
IntelligenceService.analyze()
        │
        ├── 4 reads ────────────────────────────────────┐
        │   AnalyticsService.loadManuscript()           │
        │   repository.recordsByProject()               │
        │   repository.linksByScope()                   │
        │   repository.recordTypeDefinitionsByScope()   │
        │                                               ▼
        │                                        ProjectSurvey
        │                                   (indexed, in memory)
        │                                               │
        └── detectAll(survey) ──────────────────────────┘
                    │
                    ├── detectOrphanEntities
                    ├── detectManuscriptGaps ──► ManuscriptContinuityIntelligence
                    ├── detectOrphanPlots
                    ├── detectUnresolvedRelationships
                    ├── detectTimelineConflicts ──► ContinuityAnalyzer.analyze
                    ├── detectResearchGaps
                    └── detectUnusedWorldbuilding
                    │
                    ▼
             IntelligenceReport ──► IntelligenceStudioView
                                └─► IntelligenceHealthTile (World Board)
```

| File | Responsibility |
|---|---|
| `lib/intelligence/intelligence_models.dart` | `StructuralCondition`, `StructuralFinding`, `StructuralAction`, `IntelligenceReport`, `IntelligenceDestination` |
| `lib/intelligence/project_survey.dart` | One indexed read of the project |
| `lib/intelligence/detectors.dart` | One pure function per condition |
| `lib/intelligence/intelligence_service.dart` | Reads, runs detectors, folds the report |
| `lib/intelligence/intelligence_sections.dart` | Public presentation components |
| `lib/intelligence/intelligence_view.dart` | The Studio |
| `lib/core/prose_mentions.dart` | The shared word-boundary matcher (extracted) |

### Invariants held

| Invariant | How |
|---|---|
| Owns no storage; persists nothing | No write call anywhere in `lib/intelligence/`. Pinned by `test/intelligence_service_test.dart` — records, links, versions, audit events, manuscript nodes and every `SharedPreferences` key are compared before and after two analyses |
| I-9: a derived relationship never becomes a `RecordLink` | `StructuralFinding` has no id and is never written. Pinned by a test that reports an unlinked mention and asserts the link table is still empty |
| No second persistence, search index or validation system | No new table, no schema bump, no new index. Detectors call the existing validators |
| No AI | Every rule is structural: link presence, word-boundary name matching, calendar ordinals, field emptiness |

### Deliberate limitations

- **Canon only.** Branch overlays (`branch_record_overlay_rows`) are not
  resolved, so the report describes canon. Branch-aware analysis is deferred
  rather than half-done.
- **Studio-level navigation.** A finding opens the Studio that owns it, not the
  specific record. `SearchNavigationTarget` carries a `recordId`, but the shell
  discards it (`lib/main.dart`, the `onNavigate` switches) and no Studio accepts
  an initial record id. Record-level focus is a separate change.
- **Inherited read side effect (R-21).** `loadStudio()` seeds and saves a
  starter manuscript on a project whose manuscript has never been opened,
  writing chapter and scene nodes. This layer does not add a third such path —
  it calls `AnalyticsService.loadManuscript()`, the same entry the World Board
  already uses. Removing the side effect belongs to Story Graph Phase 0.

---

## 3. The detectors

| Condition | Rule | Severity | Reuses |
|---|---|---|---|
| **Orphan entity** | A character with **no** `appearsIn`/`mentionedIn` link to a live node **and** whose name and aliases appear nowhere in the prose | warning | `proseMentions`, `ManuscriptContinuityIntelligence.aliasesOf` |
| **Unlinked mention** | The prose names a record and no connection records it | notice | `ManuscriptContinuityIntelligence.analyzeScene` |
| **Location gap** | A scene's `location` string matches no location record | warning | same |
| **Cast gap** | A scene's POV names someone with no record | warning | same |
| **Orphan plot** | A plotline/subplot/arc with no connection to a live scene node | warning | — |
| **Unresolved relationship** | A `relationship-arc` Plot Studio does not consider resolved, **or** a character-to-character relationship link with no arc near either end | notice | Plot Studio's `plotStatus` semantics |
| **Timeline conflict** | Overlap, impossible travel, invalid range, backwards sequence | as the analyzer assigns | `ContinuityAnalyzer.analyze` |
| **Research gap** | A research record with a `documents` link and neither `sourceUrl` nor `citation` | notice | — |
| **Unused worldbuilding** | World-category records with no link to a live node, reported as **one** finding carrying the count | notice | — |

### Design notes worth keeping

**Why orphan entity is a conjunction.** A link-only rule flags every character
in a project that has not started connecting things — most projects on day one —
and the screen opens as a wall of false positives. A character the author has
written about but not connected is a different and more useful condition, and it
is one-click fixable. Hence two findings rather than one.

**Why the prose matcher was extracted.** Three continuity engines each carried
an identical private `_mentions`. They now share `lib/core/prose_mentions.dart`,
so the Manuscript workspace, World Studio, the Story Codex and this layer agree
on what "the prose names this record" means. `AnalyticsService`'s naive
substring match (risk R-20 — "Will" matches the auxiliary verb) is deliberately
**not** reused.

**Why the live node set comes from the manuscript.** `ProjectSurvey` builds it
from the **loaded manuscript**, never from `manuscript_node_rows`, so a link
naming a scene the author cannot see never counts as reaching the manuscript.

This was written against risk R-1 — deleted scenes leaving their node row, links
and search-index entry behind forever — which **Story Graph Phase 0 has since
closed**: `removeManuscriptNodes` now deletes a node's edges inside its own
transaction, and the projection reconciles on save. The rule stays anyway. The
manuscript is what the author actually has; the projection is a derivative of
it, and a derivative that has been wrong before is not the thing to ask.

Pinned at two levels: a detector unit test proves a link to a non-existent scene
does not count, and a service test proves a plotline whose only scene is deleted
is reported as orphaned.

**Why `orphaned-scene` was routed around, not fixed.** `PlotService.validatePlot`
queries `recordsByTypeAndScope(typeId: 'scene')`, which always returns zero
because scenes are manuscript nodes rather than records (risk R-5). The orphan
plot detector inverts the question — it walks the plotline's own connections —
rather than depending on a query that cannot return anything. Repairing
`PlotService` belongs to Story Graph Phase 0.

**Why the timeline projection sets a synthetic plotline key.**
`ContinuityAnalyzer` deliberately does not report two events in the *same*
plotline as overlapping. That makes the value for an unassigned event load
bearing: a blank plotline would make every unassigned event share one plotline
with every other, and the overlap check would never fire. Unassigned events
therefore get a key unique to themselves. The value is never displayed.

**Why there is no project score.** `ContinuityAnalyzer.summaryFor` scores
`100 − 25·critical − 10·warning − 4·notice`, clamped. That is right for a single
record and saturates to zero across a project — four criticals, or twenty-five
notices, and every book reads 0 out of 100. The report gives coverage instead:
counts by severity, and how many world entities reach the page.

---

## 4. Canon Conflict — deferred, with reasons

"Two records contain contradictory information" cannot be decided without
reading meaning, and AuthorOS is deliberately AI-free. Rather than ship a
detector that is right by accident, it is deferred with three
structurally-decidable candidates recorded:

1. **Duplicate-name records** — two live records of the same type whose
   normalised titles or aliases collide. Cheap, high signal, reuses the alias
   matching already present.
2. **Death-then-appearance** — a character linked to a death event, then
   appearing in a scene or event dated after it. `TimelineService` ordering
   already supports this.
3. **Contradictory single-valued fields** — two records asserting different
   values for the same single-valued fact. Real, but depends on fields authors
   often leave blank.

Semantic contradiction beyond these stays out of scope.

---

## 5. Surfacing

New top-level `StudioSection.intelligence`, registered in `lib/main.dart`, plus
`StudioId.intelligence` in `lib/theme/theme_tokens.dart`.

**The duplicated navigation lists were removed.** `_AuthorStudioShellState` and
`_DesktopNavigation` each held a verbatim copy of `workspaceSections` and
`storySections` with no shared constant — the shell indexes `sections` by
position while the rail renders its own copy, so a Studio added to one and not
the other silently selects the wrong screen. Both now reference one definition
(`_workspaceSections`, `_storySections`) at the top of the file.

The World Board carries `IntelligenceHealthTile`. `WorldBoardService` asks the
Intelligence Layer for its report exactly as it asks Analytics for its
aggregates, handing over the manuscript it has already loaded so the same prose
is not read a third time.

---

## 6. Tests

| File | Count | Covers |
|---|---|---|
| `test/intelligence_detectors_test.dart` | 34 | Each detector against a hand-built survey — no database. True positive, true negative, and the edge case most likely to make it wrong (substring vs. word boundary, aliases, soft deletion, templates, undated events, unknown calendars, maps excluded, one finding per pair) |
| `test/intelligence_service_test.dart` | 12 | End-to-end over an in-memory database, plus the read-only guardrails and the I-9 no-promotion guardrail |
| `test/intelligence_view_test.dart` | 8 | Loading / error / data states by key, grouping, the clean state, refresh, destination hand-off, and the World Board tile |

Full suite after merging `main` (which brought the Knowledge Graph milestone and
Story Graph Phase 0): **1207 tests passing, 60 analyzer issues, 0 errors.**

60 is the baseline: `origin/main` alone measures the same 60 on the SDK used
here (3.47.1), so this milestone adds none. CI runs 3.44.9 and reports a lower
count for both — the difference is the SDK's deprecation set, not the tree.

---

## 7. Follow-up work

- Canon Conflict, per §4.
- Record-level deep-linking: thread an `initialRecordId` through the shell and
  each Studio.
- Branch-aware analysis via `BranchEngine`.
- Wire `ContinuityTimelinePanel` into Timeline Studio — this phase makes
  `ContinuityAnalyzer.analyze` reachable for the first time, and the panel that
  renders its warnings is still unused.
- Repair `PlotService`'s dead `orphaned-scene` query (Story Graph Phase 0).
- The two `analyzeScene` rules not rolled up here — "POV not connected to this
  scene" and the per-scene chronology check — if they prove useful project-wide.
