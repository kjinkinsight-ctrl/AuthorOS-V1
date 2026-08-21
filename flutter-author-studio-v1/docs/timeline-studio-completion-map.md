# Timeline Studio Completion Map

Phase 2 of Timeline Studio: the writer-facing workspace over the Phase 1 Universal
Record domain. This is the "UI adapter over this service" that
`timeline-studio-phase-1-implementation-map.md` left as remaining work.

Status moves from **🟡 PARTIAL** to **🟢 IMPLEMENTED**.

## How this document came to be merged

Timeline Studio was completed **twice, independently**, by two passes that ran in
parallel without seeing each other:

- **Pass A** landed on `main` as `0d5c926`: `lib/timeline_studio_view.dart`
  (576 lines), a 130-line test, a 75-line map, and the routing change.
- **Pass B** landed on `claude/timeline-studio-completion-7wypb0` as `2ea4297`:
  `lib/timeline_studio.dart` (1,782 lines), a 586-line test, a 418-line map, plus
  service and calendar extensions.

Both reached the same architecture — `TimelineService` + `StudioThemeScope` — and
both were correct. The overlap was found while pushing Pass B, before either was
merged into the other. The repository owner chose **merge the best of both**, so
this branch now carries one reconciled Studio rather than two.

### What each pass contributed

| Kept from Pass A (`main`) | Kept from Pass B (this branch) |
| --- | --- |
| File name `lib/timeline_studio_view.dart` | The implementation itself |
| Constructor taking the shell's `StarterProject`, plus a `service` test seam | `repository` and `onNavigate` parameters |
| **Theme Engine typography** — `scope.text(role, colorRef:)` instead of the Material text theme | Theme Engine colours, with a Material fallback so the Studio renders in bare-`MaterialApp` tests |
| `ThemeRegistry.standard().byId(id).defaultMode` in `release_destinations.dart` | Deleting the 1,596-line legacy Studio that Pass A's re-route orphaned |
| Plot Studio routing (untouched) | Calendar-ordinal ordering, full event editor, filters, detail pane, archive/restore, safe delete, semantics, responsive layout, 15 tests |

### What was deliberately dropped

- **Pass A's `_dateOrdinal`** (`year * 10000 + month * 100 + day`). It ignores the
  project's calendar entirely — month lengths, `hasYearZero`, `yearsCountBackward`
  — and gives undated events ordinal `0`, which sorts them *between* negative and
  positive years instead of after everything. Replaced by
  `TimelineQueryService.chronological()`, which uses real calendar ordinals.
- **Pass A's `_humanDate`** (`Y18 · M2 · D5`), which ignored the calendar's own
  `dateFormat`. Replaced by `TimelineCalendar.format`.
- **Pass A's create dialog**, which offered only title and summary — so no dated
  event could be created through the UI, leaving the chronology unusable.
- **Pass A's `_editEvent`**, which hand-built the record and wrote
  `'temporalStatus': 'planned'` on every save, clobbering the author's status.
  Replaced by `TimelineService.updateEvent`, which shares `createEvent`'s field
  shaping.
- **Pass A's `_deleteEvent`**, which called `records.deleteRecord` directly and so
  bypassed the Timeline facade's `_requireTimelineId` guard. Replaced by
  `deleteTimelineRecord`, preceded by a `SafeDeleteService` analysis.
- **Pass B's `import 'main.dart' show AppThemePreset;`**. Pass B repaired a
  pre-existing compile break that way; Pass A repaired it better, by removing the
  `AppThemePreset` dependency from `release_destinations.dart` altogether. Pass
  A's fix stands and Pass B's import is gone.

## Existing architecture discovered

The audit ran before any edit. Timeline was two disconnected halves.

### The canonical half (complete, unused by the UI)

| File | What it holds |
| --- | --- |
| `lib/core/timeline_record_types.dart` | `timeline-record` base, `calendar-definition`, and 27 data-driven child types (Era, Event, War, Battle, Birth, Death, Journey, …) |
| `lib/timeline_domain.dart` | `TimelineDate`, `TimelineDateRange`, `RelativeTimelineDate`, `TimelineCalendar`, `TimelineCalendarMonth`, `TimelinePrecision`, `TimelineValidationIssue` |
| `lib/timeline_service.dart` | `TimelineService` (domain facade), `TimelineQueryService`, lane/card/marker view models, `TimelineValidationException` |
| `lib/persistence/authoros_database.dart` | Drift `AuthorOsDatabase` + `DriftConnectedDomainRepository`, and the `authorOsRepository` app singleton |
| `test/timeline_domain_test.dart`, `test/fixtures/timeline_domain_fixture.dart` | Service-level coverage of the domain |

`TimelineService` composes `RecordService`, `ConnectionEngine`, `BranchService`,
`UniversalSearchService`, `VersionAuditService`, `UniversalRecordInspector` and
`SafeDeleteService`. It owns no store, index or history of its own.

### The legacy half (what the navigation opened before either pass)

| File | What it held |
| --- | --- |
| `lib/timeline.dart` | `TimelineEra` / `TimelineSequence` / `TimelineEvent` / `TimelineState` / `TimelineStore`, on `SharedPreferences` |
| `lib/main.dart` | `_TimelineStudioView` + `_TimelineStudioViewState` + `_MetricChip` — 1,596 lines of card list, filters, era/sequence editors, continuity panel |

**The gap was integration, not architecture.** The visible Studio never touched
`TimelineService`, so nothing an author typed reached Universal Records, search,
connections, versioning, branches or safe delete. It was a vertical card list
that did not communicate chronology, and it read `Theme.of(context)` only, never
the Theme Engine — despite `StudioId.timeline` already existing and being unused.

## Files created

| File | Lines | Purpose |
| --- | --- | --- |
| `test/timeline_studio_view_test.dart` | ~600 | Service, widget, responsive and navigation coverage (replaces the 130-line version) |
| `docs/timeline-studio-completion-map.md` | this file | |

## Files modified

| File | Change |
| --- | --- |
| `lib/timeline_studio_view.dart` | Replaced with the reconciled Studio |
| `lib/main.dart` | Deleted the orphaned 1,596-line legacy Studio and `_MetricChip`; dropped the four imports that made dead (`timeline.dart`, `continuity.dart`, `continuity_actions.dart`, `impact_trace.dart`); re-added `onNavigate` to the Timeline route |
| `lib/timeline_service.dart` | Extended: `updateEvent`, `deleteTimelineRecord`, `calendars`, `primaryCalendar`, `query.chronological`, `query.startOrdinal`, `all(status:)` |
| `lib/timeline_domain.dart` | `TimelineCalendar.format` |
| `lib/release_destinations.dart` | Removed the `AppThemePreset` import Pass B added; `main`'s `ThemeRegistry` fix is untouched |

## Files deleted

`lib/timeline_studio.dart` — Pass B's filename, folded into
`lib/timeline_studio_view.dart`.

`lib/timeline.dart` **stays**: `lib/migrations/legacy_reference_adapters.dart`
still consumes `TimelineEvent`, and `test/timeline_test.dart` covers it.

## Architecture reused

No new timeline architecture. There is no `TimelineService2`,
`TimelineRepository`, `TimelineDatabase`, `TimelineStore`, `TimelineRecord` or
`TimelineStateStore`. Reused:

- **Identity** — every event is an `AuthorRecord` of a `timeline-record` subtype.
- **Persistence** — `DriftConnectedDomainRepository` / `AuthorOsDatabase`, via
  `authorOsRepository` in the app and an injected in-memory database in tests.
- **Lifecycle** — `archiveRecord` / `restoreRecord` / `deleteRecord`.
- **History** — `VersionAuditService` records every create and edit.
- **Connections** — `ConnectionEngine` via `connectionsFor`; the detail pane
  routes to other Studios through the shared `searchDestinationForType`.
- **Safe delete** — `SafeDeleteService` via `analyzeDelete`.
- **Validation** — `validateTemporal`, surfaced as `TimelineValidationException`.
- **Theme** — `StudioThemeScope`, `ThemeColorRef`, `ThemeTextRole` and the
  already-defined `StudioId.timeline`.

### Service extensions, and why each was necessary

- **`updateEvent(TimelineEventDraft)`** — `updateTimelineRecord` took a fully
  built `AuthorRecord`, forcing callers to reproduce `createEvent`'s field
  shaping (which is exactly where Pass A's edit path drifted). Shaping now lives
  in one private `_eventFields` used by both paths.
- **`deleteTimelineRecord(id)`** — the facade had archive/restore and
  `analyzeDelete` but no guarded delete.
- **`calendars()` / `primaryCalendar()`** — the editor needs the project's
  calendars; only single-id `getCalendar` existed.
- **`TimelineQueryService.chronological()`** — `all()` sorts by title.
  Chronological ordering needs calendar ordinals, which is domain knowledge.
  Dated records sort by ordinal; undated records keep stable alphabetical order
  **after** them, because the service never invents a date it was not given.
  Ordinals are not comparable across calendars without conversion metadata, so
  records group by calendar id first — a single-calendar project reads as one run.
- **`all(status:)`** — optional, defaulting to previous behaviour.
- **`TimelineCalendar.format`** — `dateFormat` was stored and validated but never
  rendered. Formatting belongs with the calendar that defines it.

`updateEvent` deliberately **rejects** a type change: `RecordService.updateRecord`
forbids it, and the facade surfaces that rule in Timeline wording. The dialog
disables the Type field when editing and explains why.

## Timeline UI

`TimelineStudioView({project, repository?, service?, onNavigate?})`.

**The chronological rail** is a real timeline, not a list. Each row is
`[date gutter] [spine + marker] [event card]`: a continuous 2px line running
through circular markers, drawn per row as a top segment, the marker, and an
expanding bottom segment, so it stays unbroken across cards of different heights.
The selected marker grows and fills. Undated events sit under their own `Undated`
header with their own spine, so the dated run ends cleanly on its last marker.

- **Date gutter** renders through `TimelineCalendar.format`, so `18-2-5` and `~40`
  come from the project's own calendar, not Gregorian assumptions.
- **Event cards** — title, type, date range when the end differs, temporal
  status, importance, archived state, up to three tags, two-line summary.
- **Detail pane** — type, canon, status, importance, start/end, summary, tags,
  description, notes, connections, and Edit / Archive / Delete.
- **Filter bar** — search across title, summary, description, tags and date
  label; type filter built from the types present, plus "Undated only";
  earliest/latest toggle; show-archived toggle.
- **Event dialog** — name, type, summary, description, start and end
  year/month/day, approximate flag, status, importance, canon, tags, notes, with
  inline validation before anything reaches the service.

### States

| State | Key | Behaviour |
| --- | --- | --- |
| Loading | `timeline-loading` | Header + spinner; the header renders in every state |
| Empty | `timeline-empty-state` | "Your story has no events yet." + **Create Event** |
| Populated | `timeline-studio` | Rail + filters + detail pane |
| No matches | `timeline-no-matches` | Filters matched nothing, distinct from empty |
| Error | `timeline-error-state` | Message + **Retry**, no crash |

Action failures surface as a `SnackBar` through `ScaffoldMessenger`. No new
notification or error architecture.

## TimelineService integration

| UI action | Service call |
| --- | --- |
| Load | `records.registry()`, `calendars()`, `query.chronological(status:, descending:)` |
| Select | `connectionsFor(id)` → `repository.recordById` per endpoint |
| Create | `createEvent(TimelineEventDraft)` (after `createCalendar` when the first dated event needs one) |
| Edit | `updateEvent(TimelineEventDraft)` |
| Archive / restore | `archiveTimelineRecord` / `restoreTimelineRecord` |
| Delete | `analyzeDelete` → `deleteTimelineRecord` |
| Validation | `validateTemporal` via `TimelineValidationException` |

## Persistence

Existing persistence only. **No migration, no schema change.** Timeline events fit
`AuthorRecordRows` as `timeline-*` typed Universal Records with structured
`start` / `end` / `dateRepresentations` table fields.

One deliberate extra write: a dated event needs a calendar, and `validateTemporal`
rejects `invalid-calendar`. On the first dated save into a calendar-less project
the Studio provisions a neutral 12×30-day `Story Calendar` through
`TimelineService.createCalendar`. It never guesses Earth semantics and never runs
for undated events.

## Project isolation

Inherited, not re-implemented: the service is constructed per `projectId`,
`query.all()` reads `recordsByProject`, `validateTemporal` rejects
`cross-project`, and `connect` refuses cross-project endpoints. Proven by a test
building two services over one database, asserting events **and calendars** stay
separate in both directions.

## Theme integration

`_TimelinePalette.of(context)` resolves once per build from
`StudioThemeScope.maybeOf(context)`, falling back to the Material theme so the
Studio renders in a bare `MaterialApp`. The Studio nests a `StudioThemeScope` with
`studio: StudioId.timeline`.

Colours: `surface`, `surfaceContainer`, `primary` (rail, markers, selected border,
type chips), `onPrimary`, `onSurface`, `onSurfaceVariant`, `outlineVariant`,
`selection`, `focusRing`.
Typography: `ThemeTextRole.heading` / `.ui` / `.body` / `.label` — carried on the
palette, so no view widget reads `Theme.of(context).textTheme` directly.

**No `ThemeData` is constructed anywhere in Timeline Studio.**

## Accessibility

Uses the existing infrastructure; no second accessibility system.
`FocusTraversalGroup`; event cards are keyboard-focusable `InkWell`s with a
`focusRing`-painted focus ring; `Semantics(button:, selected:, label:)` on cards
and on Create, Edit and Delete; tooltips on icon-only controls; text via
`onSurface` / `onSurfaceVariant` so the high-contrast transform applies unchanged.

## Tests

`test/timeline_studio_view_test.dart` — 15 tests, superseding the 3 from Pass A
(whose intents — empty state, chronological order, edit/delete actions — are all
covered here).

**Service** — create/retrieve/update/delete through Universal Records including
version history and the type-change rule; end-before-start rejection;
chronological ordering ascending and descending with undated last; project
isolation; calendar formatting.

**Widget** — empty state creates a first event and provisions the default
calendar; populated rail asserts **actual y-coordinates** for order, then
re-asserts after the sort toggle; select → detail → edit persists and versions;
delete confirmation soft-deletes; archive hides then reappears under "Show
archived"; search and type filters including no-matches; error state and retry
against a repository that fails on demand; theme tokens resolved from a real
`ThemeEngine`-resolved theme.

**Responsive** — 1280×720, 1440×900, 1920×1080, each selecting an event.

**Navigation** — pumps `AuthorStudioShell`, taps the sidebar Timeline entry,
asserts `TimelineStudioView` is on screen and the legacy board is gone.

No existing test was deleted, skipped or weakened.

## Verification results

Baseline is `origin/main` at `0d5c926`, the branch's merge base, measured in a
clean worktree with the same toolchain.

| Gate | `origin/main` | This branch |
| --- | --- | --- |
| `flutter test` | **1 failed, 1 hung** (suite never completes) | **509 passed, 0 failed, 0 skipped** |
| `flutter analyze` | 85 issues (21 errors, 12 warnings, 52 infos) | **78 issues (21 errors, 8 warnings, 49 infos)** |
| `flutter build web --release` | — | **✓ Built build/web** |
| `flutter build linux --release` | — | **✓ Built build/linux/x64/release/bundle** |

A normalized diff of the two analyzer runs shows **no new issue of any severity**.
The branch *removes* seven that exist on `main`, among them two
`unused_local_variable` warnings in `lib/timeline_studio_view.dart` and an unused
import in its test.

### The test suite on `main` does not currently pass

`origin/main`'s `test/timeline_studio_view_test.dart` constructs its service with
`repository: authorOsRepository` — the **real application Drift database** rather
than an in-memory one. Under `flutter test` there is no application documents
directory, so `timeline studio shows empty state` fails and `timeline studio
shows project events in chronological order` hangs indefinitely, taking the whole
run down with it (observed: 9 minutes with no progress, then a
`Cannot close sink while adding stream` shutdown error).

The replacement test file injects `AuthorOsDatabase(NativeDatabase.memory())`,
which is why this branch's suite completes green. Reconciling therefore repairs a
broken suite on `main` rather than merely adding to it.

The remaining 21 errors on both sides are the pre-existing
`tool/storage_benchmark.dart` breakage (it imports `isar_community`, which
`pubspec.yaml` does not declare).

Toolchain: Flutter 3.44.9 / Dart 3.12.2, matching `pubspec.lock`.

### Visual verification

The Linux release build was launched under Xvfb and driven through the real flow
— profile → project → sidebar Timeline — with events created **through the
dialog**, not seeded. Verified at 1280×720, 1440×900 and 1920×1080 and in dark
theme. Two rail defects (a segment dangling below the last dated marker, a stub
above the first undated marker) were found visually and fixed.

## Known limitations

1. **Legacy `TimelineStore` data is not migrated.** Events saved to
   `SharedPreferences` still exist but are not surfaced. Phase 1 anticipated this;
   a one-time import through `TimelineService.createEvent` is the natural next step.
2. **The continuity panel is not re-hosted.** The legacy view embedded
   `ContinuityTimelinePanel`, `ContinuityAnalyzer` and `ImpactTracePanel`, all
   driven by the legacy `TimelineEvent` model. Re-hosting needs a Universal-Record
   → `ContinuityEventSnapshot` projection. Those widgets are untouched and still
   independently tested.
3. **Eras and sequences have no dedicated editor.** They are creatable from the
   type dropdown, but hierarchy lives in `contains` / `partOf` connections, which
   the detail pane lists read-only.
4. **One calendar in the editor.** The domain supports alternate
   `dateRepresentations` and the rail groups by calendar id, but there is no
   calendar picker or designer.
5. **Cross-calendar ordering is grouped, not interleaved** — deliberate.
6. **No branch switcher.** The Studio reads canonical project records only.
7. **Web renders blank in the verification container** (blocked
   `fonts.gstatic.com`, software WebGL). Unrelated to Timeline; visual
   verification used the Linux desktop build.

## Decisions made

1. **One Studio, not two.** The owner chose to merge both passes rather than pick
   one; the table above records what survived from each and why.
2. **Kept Pass A's file name and constructor** so `main`'s routing and any other
   caller keep working, and so the diff against `main` reads as an evolution of
   the existing file rather than a replacement.
3. **Kept Pass A's Theme Engine typography** and extended it to the whole view.
4. **Replaced the legacy view rather than leaving it.** Pass A re-routed away from
   `_TimelineStudioView` without deleting it, leaving 1,596 lines of dead code and
   an `unused_element` warning on `main`. This branch removes it.
5. **Extended `TimelineService` rather than putting logic in the view.**
6. **Auto-provisioned a default calendar on the first dated event**, through the
   service, marked primary.
7. **Did not build a legacy data importer** — out of scope, and a data decision
   for the owner.

## Decisions requiring owner input

1. **Legacy timeline data** — recommend a one-time importer offered from the empty
   state, reading `TimelineStore.load` and writing through
   `TimelineService.createEvent`. No schema change.
2. **Continuity re-hosting** — return it over a Universal-Record projection, move
   it elsewhere, or retire it.
