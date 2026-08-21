# Timeline Studio Completion Map

Phase 2 of Timeline Studio: the writer-facing workspace over the Phase 1 Universal
Record domain. This is the "UI adapter over this service" that
`timeline-studio-phase-1-implementation-map.md` left as remaining work.

Status moves from **🟡 PARTIAL** to **🟢 IMPLEMENTED**.

## Existing architecture discovered

The audit ran before any edit. Timeline was already two disconnected halves.

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

### The legacy half (what the navigation actually opened)

| File | What it held |
| --- | --- |
| `lib/timeline.dart` | `TimelineEra` / `TimelineSequence` / `TimelineEvent` / `TimelineState` / `TimelineStore`, persisted to `SharedPreferences` |
| `lib/main.dart:1843–3438` | `_TimelineStudioView` + `_TimelineStudioViewState` + `_MetricChip` — 1,596 lines of card list, filters, era/sequence editors, continuity panel |

`main.dart` routed `StudioSection.timeline => _TimelineStudioView(project: project)`.

**The gap was integration, not architecture.** The visible Studio never touched
`TimelineService`, so nothing an author typed into Timeline reached Universal
Records, search, connections, versioning, branches or safe delete. It was also a
vertical card list — it did not communicate chronology — and it consumed
`Theme.of(context)` only, never the Theme Engine, despite `StudioId.timeline`
already existing in `lib/theme/theme_tokens.dart` and being unused.

## Files created

| File | Lines | Purpose |
| --- | --- | --- |
| `lib/timeline_studio.dart` | 1,782 | `TimelineStudioView` — the real workspace, plus `TimelineNavigationRequest` |
| `test/timeline_studio_view_test.dart` | 586 | Service, widget and navigation coverage |
| `docs/timeline-studio-completion-map.md` | this file | |

## Files modified

| File | Change |
| --- | --- |
| `lib/main.dart` | Route `StudioSection.timeline` to `TimelineStudioView`; delete the legacy in-shell Studio (`_TimelineStudioView`, `_TimelineStudioViewState`, `_MetricChip`); drop the four imports those made dead (`timeline.dart`, `continuity.dart`, `continuity_actions.dart`, `impact_trace.dart`, `persistence/authoros_database.dart`) |
| `lib/timeline_service.dart` | Extended: `updateEvent`, `deleteTimelineRecord`, `calendars`, `primaryCalendar`, `TimelineQueryService.chronological`, `TimelineQueryService.startOrdinal`, `all(status:)` |
| `lib/timeline_domain.dart` | `TimelineCalendar.format` — renders a `TimelineDate` through the calendar's own `dateFormat` |
| `lib/release_destinations.dart` | One-line import fix; see **Decisions** below |

## Files deleted

None. `lib/timeline.dart` stays: `lib/migrations/legacy_reference_adapters.dart`
still consumes `TimelineEvent` via `LegacyReferenceAdapters.timelineEvent`, and
`test/timeline_test.dart` covers it. Only the dead in-shell view was removed.

## Architecture reused

No new timeline architecture was introduced. There is no `TimelineService2`,
`TimelineRepository`, `TimelineDatabase`, `TimelineStore`, `TimelineRecord` or
`TimelineStateStore`. Specifically reused:

- **Identity** — every event is an `AuthorRecord` of a `timeline-record` subtype
  from the existing catalogue. No second event identity system.
- **Persistence** — `DriftConnectedDomainRepository` / `AuthorOsDatabase`, via
  `authorOsRepository` in the app and an injected in-memory database in tests.
- **Lifecycle** — `archiveRecord` / `restoreRecord` / `deleteRecord` through
  `RecordService`, so archive and delete are the same reversible states every
  other Studio uses.
- **History** — `VersionAuditService` records every create and edit; the Studio
  keeps no history of its own.
- **Connections** — `ConnectionEngine` via `TimelineService.connectionsFor`; the
  detail pane lists links and routes to other Studios through the shared
  `searchDestinationForType`.
- **Safe delete** — `SafeDeleteService` via `analyzeDelete`, surfaced in the
  delete confirmation.
- **Validation** — `TimelineService.validateTemporal` (shared `RecordValidation`
  plus calendar/date/range/anchor rules). The Studio catches
  `TimelineValidationException` and shows the issues.
- **Theme** — `StudioThemeScope` + `ThemeColorRef` + the already-defined
  `StudioId.timeline`.

### Service extensions, and why each was necessary

Each is a thin delegation to something that already existed, added because the
Studio needed the operation and the facade did not expose it.

- **`updateEvent(TimelineEventDraft)`** — `updateTimelineRecord` took a fully
  built `AuthorRecord`, which would have forced the UI to reproduce
  `createEvent`'s field shaping. Field shaping is now factored into one private
  `_eventFields`, shared by create and update, so an edited event keeps the exact
  record layout it was created with.
- **`deleteTimelineRecord(id)`** — the facade exposed archive/restore and
  `analyzeDelete` but no delete. Delegates to `RecordService.deleteRecord` (soft
  delete; links, versions and audit survive).
- **`calendars()` / `primaryCalendar()`** — the editor needs the project's
  calendars; only single-id `getCalendar` existed.
- **`TimelineQueryService.chronological()`** — `all()` sorts by title.
  Chronological ordering needs calendar ordinals, which is domain knowledge, not
  view knowledge. Dated records sort by ordinal; undated records keep stable
  alphabetical order **after** them, because the service never invents a date it
  was not given. Ordinals are not comparable across calendars without conversion
  metadata, so records group by calendar id first — a single-calendar project
  therefore reads as one chronological run.
- **`all(status:)`** — an optional filter, defaulting to the previous behaviour,
  so archived and soft-deleted records can be excluded. No existing caller changes.
- **`TimelineCalendar.format`** — `dateFormat` was stored and validated but never
  rendered. Formatting belongs with the calendar that defines it.

`updateEvent` deliberately **rejects** a type change rather than working around
it: `RecordService.updateRecord` forbids type changes, and the facade now
surfaces that rule in Timeline wording. The dialog disables the Type field when
editing and explains why.

## Timeline UI

`TimelineStudioView(projectId, repository?, onNavigate?)` — the same constructor
shape as `WorldWorkspace`.

**The chronological rail** is a real timeline, not a list. Each row is
`[date gutter] [spine + marker] [event card]`: the spine is a continuous 2px
line running through circular markers, drawn per row as a top segment, the
marker, and an expanding bottom segment, so it stays unbroken across cards of
different heights. The selected marker grows and fills. Undated events sit under
their own `Undated` header with their own spine, so the dated run ends cleanly
on its last marker.

- **Date gutter** renders through `TimelineCalendar.format`, so `18-2-5` and
  `~40` come from the project's own calendar, not Gregorian assumptions.
- **Event cards** show title, type, date range when the end differs from the
  start, temporal status, importance, archived state, up to three tags, and a
  two-line summary.
- **Detail pane** shows type, canon, status, importance, start/end, summary,
  tags, description, notes, connections, and Edit / Archive / Delete.
- **Filter bar** — search across title, summary, description, tags and date
  label; type filter built from the types actually present, plus "Undated only";
  earliest/latest toggle; show-archived toggle.
- **Event dialog** — name, type, summary, description, start and end
  year/month/day, approximate flag, status, importance, canon, tags, notes, with
  inline validation before anything reaches the service.

### States

| State | Key | Behaviour |
| --- | --- | --- |
| Loading | `timeline-loading` | Header + spinner (the header always renders, so the Studio is identifiable in every state) |
| Empty | `timeline-empty-state` | "Your story has no events yet." with a **Create Event** action |
| Populated | `timeline-studio` | Rail + filters + detail pane |
| No matches | `timeline-no-matches` | Filters matched nothing, distinct from empty |
| Error | `timeline-error-state` | Message + **Retry**, no crash |

Action failures surface as a `SnackBar` through `ScaffoldMessenger` — the
existing pattern. No new notification or error architecture.

## TimelineService integration

Every read and write goes through the facade:

| UI action | Service call |
| --- | --- |
| Load | `records.registry()`, `calendars()`, `query.chronological(status:, descending:)` |
| Select | `connectionsFor(id)` → `repository.recordById` for each endpoint |
| Create | `createEvent(TimelineEventDraft)` (after `createCalendar` if the first dated event needs one) |
| Edit | `updateEvent(TimelineEventDraft)` |
| Archive / restore | `archiveTimelineRecord` / `restoreTimelineRecord` |
| Delete | `analyzeDelete` → `deleteTimelineRecord` |
| Validation | `validateTemporal`, surfaced via `TimelineValidationException` |

## Persistence

Existing persistence only. **No migration was created and no schema changed** —
timeline events already fit `AuthorRecordRows` as `timeline-*` typed Universal
Records with structured `start` / `end` / `dateRepresentations` table fields.

One deliberate write beyond events: a dated event needs a calendar, and
`validateTemporal` rejects `invalid-calendar`. When an author saves the first
dated event into a project with no calendar, the Studio provisions a neutral
12×30-day `Story Calendar` through `TimelineService.createCalendar` (an ordinary
`calendar-definition` record, marked primary). It never guesses Earth semantics
and never runs for undated events.

## Project isolation

Isolation is inherited, not re-implemented: `TimelineService` is constructed per
`projectId`, `query.all()` reads `recordsByProject`, `validateTemporal` rejects
`cross-project`, and `connect` refuses cross-project endpoints.

Proven by `timeline events stay isolated per project`, which builds two services
over one database and asserts that events **and calendars** stay separate in both
directions, including `getTimelineRecord` returning `null` across the boundary.

## Theme integration

`_TimelinePalette.of(context)` resolves once per build from
`StudioThemeScope.maybeOf(context)`, falling back to `Theme.of(context)` so the
Studio still renders inside a bare `MaterialApp` in tests. The Studio nests a
`StudioThemeScope` with `studio: StudioId.timeline`, layering that Studio's
overrides on the shell theme.

Tokens consumed: `surface`, `surfaceContainer`, `primary` (rail line, markers,
selected border, type chips), `onPrimary`, `onSurface`, `onSurfaceVariant`,
`outlineVariant`, `selection` (selected card), `focusRing` (`InkWell.focusColor`).

**No `ThemeData` is constructed anywhere in Timeline Studio.** Typography comes
from `Theme.of(context).textTheme`, which the adapter derives from the resolved
theme. Verified both by widget test (marker border == the resolved
`StudioId.timeline` primary) and visually in the running app in light and dark.

## Accessibility

Uses the existing infrastructure; no second accessibility system.

- `FocusTraversalGroup` around the Studio; event cards are `InkWell`s, so they
  are keyboard-focusable and Enter-activatable, with a focus ring painted from
  the `focusRing` token.
- `Semantics(button:, selected:, label:)` on event cards
  ("Timeline event {title}, {date}"), and semantic labels on Create, Edit and
  Delete.
- Tooltips on icon-only controls (`Close details`).
- Text and secondary text use `onSurface` / `onSurfaceVariant`, so the Theme
  Engine's high-contrast accessibility transform applies unchanged.

## Tests

`test/timeline_studio_view_test.dart` — 15 tests.

**Service (5)** — create/retrieve/update/delete through Universal Records
(including version history and the type-change rule); end-before-start
rejection; chronological ordering ascending and descending with undated last;
project isolation; calendar formatting.

**Widget (8)** — empty state creates a first event (and provisions the default
calendar); populated rail renders markers and asserts **actual y-coordinates**
for chronological order, then re-asserts after the sort toggle; select → detail →
edit persists and versions; delete confirmation soft-deletes; archive hides then
reappears under "Show archived"; search and type filters including the
no-matches state; error state and retry via a repository that fails on demand;
theme tokens resolved from a real `ThemeEngine`-resolved theme.

**Responsive (1)** — 1280×720, 1440×900 and 1920×1080, each selecting an event
and asserting no exception.

**Navigation (1)** — pumps `AuthorStudioShell`, taps the sidebar **Timeline**
entry, asserts `TimelineStudioView` is on screen and that the legacy board's
`Add Era` / `Add Sequence` are gone.

No existing test was deleted, skipped, or weakened.

## Verification results

| Gate | Before | After |
| --- | --- | --- |
| `flutter test` | 394 passed, **7 failed**, 0 skipped | **492 passed, 0 failed, 0 skipped** |
| `flutter analyze` | 77 issues (23 errors, 9 warnings, 45 infos) | **74 issues (21 errors, 8 warnings, 45 infos)** — zero new |
| `flutter build web --release` | — | **✓ Built build/web** |
| `flutter build linux --release` | — | **✓ Built build/linux/x64/release/bundle** |

A normalized diff of the two analyzer runs shows **no new issue of any severity**.
The remaining 74 are pre-existing: 21 errors in `tool/storage_benchmark.dart`
(imports `isar_community`, which `pubspec.yaml` does not declare) and assorted
lints in files this work did not touch.

The 7 baseline failures were all "failed to load" on `lib/release_destinations.dart`
— see **Decisions**. Fixing that unblocked `connected_domain_test`,
`legacy_reference_migration_test`, `reading_rhythm_test`, `settings_theme_test`,
`startup_flow_test`, `widget_test` and one more, which is most of the
394 → 492 jump; the other 15 are this work's.

Toolchain: Flutter 3.44.9 / Dart 3.12.2, matching `pubspec.lock`
(`dart: >=3.12.0`, `flutter: >=3.44.0`).

### Visual verification

The Linux release build was launched under Xvfb and driven through the real
flow — profile creation → project creation → shell → sidebar **Timeline** — and
four events were created **through the dialog**, not seeded.

| Check | Result |
| --- | --- |
| Sidebar → Timeline Studio | Opens the real Studio |
| Empty state | "Your story has no events yet." + Create Event |
| Create dialog | All fields render, no clipping |
| Populated rail | Continuous spine, markers, gutter labels `1` / `18-2` / `40`, `Undated` group below |
| Chronological order | Founding (1) → War of Ash (18-2) → Coronation (40) → undated |
| Detail pane | Chips, start, summary, Edit / Archive / Delete |
| 1280×720 | Detail pane stacks below the rail; no clipping or overflow |
| 1440×900 | Rail and detail side by side |
| 1920×1080 | Side by side, generous spacing |
| Dark theme | Rail, markers and chips take the dark accent; surfaces and text correct |
| Error state | Reproduced live before the container had an XDG documents dir: message + Retry, no crash |

Two defects were found visually and fixed: a rail segment dangling below the last
dated marker, and a stub above the first undated marker. Both are in the shipped
code.

## Known limitations

1. **Legacy `TimelineStore` data is not migrated.** Eras, sequences and events an
   author previously saved to `SharedPreferences` still exist but are no longer
   surfaced. `lib/timeline.dart` and its tests are untouched. Phase 1 anticipated
   this ("legacy `TimelineStore` migration" as later work); a one-time import
   through `TimelineService.createEvent` is the natural next step. See **Decisions**.
2. **The continuity panel is not in the new Studio.** The legacy view embedded
   `ContinuityTimelinePanel`, `ContinuityAnalyzer` and `ImpactTracePanel`, all
   driven by the legacy `TimelineEvent` model (integer `startDay`, string `pov`,
   string `location`). Re-hosting it needs a Universal-Record → `ContinuityEventSnapshot`
   projection resolving POV and locations through `involves` / `occursAt` links.
   The widgets themselves are untouched and still independently tested.
3. **Eras and sequences have no dedicated editor.** Era, Age and Historical Period
   are creatable from the type dropdown, but hierarchy is expressed with
   `contains` / `partOf` connections and the Studio does not yet edit those. The
   detail pane lists connections read-only.
4. **One calendar in the editor.** The dialog writes dates in the project's first
   calendar. The domain supports alternate `dateRepresentations` and the rail
   groups by calendar id, but there is no calendar picker or designer yet.
5. **Cross-calendar ordering is grouped, not interleaved.** Deliberate: ordinals
   from different calendars are not comparable without conversion metadata.
6. **No branch switcher.** `TimelineService` exposes `overrideInBranch` and
   `query.inBranch`; the Studio reads canonical project records only.
7. **Web renders blank in this container.** The release build succeeds and is
   served, but Chromium headless here cannot bring up the Flutter web canvas
   (blocked `fonts.gstatic.com`, software WebGL). Unrelated to Timeline; visual
   verification was done on the Linux desktop build instead.

## Decisions made

1. **Replaced the legacy view rather than keeping both.** The brief requires the
   navigation item to open the real Studio, not a legacy or disconnected one.
   Leaving `_TimelineStudioView` in place after re-routing would also have made it
   dead code and produced new `unused_element` warnings, breaking the analyzer
   gate. `lib/timeline.dart` itself was kept because the migrations layer still
   uses it.
2. **Extended `TimelineService` instead of adding logic to the view.** Ordering,
   field shaping, calendar reads and delete are domain operations. The view holds
   no persistence, ordering or validation rules of its own.
3. **Auto-provisioned a default calendar on the first dated event.** The
   alternative was to reject dated events until the author hand-built a calendar,
   or to let the Studio write dates that fail validation. The calendar is a normal
   Universal Record, created through the service, marked primary, and only on the
   first dated save.
4. **Made `updateEvent` reject type changes** rather than silently working around
   `RecordService`'s rule.
5. **Did not build a legacy data importer.** It is not in the brief's scope, and
   it is a data-migration decision for the repository owner. Flagged below.

## Decisions requiring owner input

### 1. A boundary was crossed in `lib/release_destinations.dart` — one line

At `HEAD` (`637f376`), `lib/release_destinations.dart` referenced
`AppThemePreset` at lines 2761 and 3761 without importing it — `AppThemePreset`
is declared in `lib/main.dart`. This is a genuine pre-existing compile error, and
it blocked **7 test files from loading**, `widget_test.dart` among them.

It is a direct Timeline dependency: the acceptance gate "Sidebar → Timeline Studio
opens the real Timeline Studio" cannot be tested without `main.dart` compiling
under test, and `main.dart` imports `release_destinations.dart`.

The fix is one line and changes no behaviour:

```dart
import 'main.dart' show AppThemePreset;
```

A second line changed as a direct consequence: with the file compiling again, the
analyzer surfaced an `unused_element_parameter` warning on
`_LegacyCharacterBoardView`'s never-supplied `key`, which was removed to keep the
"no new warnings" gate honest.

**Please confirm this is the fix you want.** The alternative — moving
`AppThemePreset` into the theme layer — is a larger change squarely inside the
Theme Engine boundary, which the brief puts out of bounds.

### 2. Legacy timeline data

Authors with existing `SharedPreferences` timeline data will find their events
absent. Options:

- **Recommended:** a one-time importer, offered from the empty state, reading
  `TimelineStore.load` and writing through `TimelineService.createEvent`
  (`title` → name, `dateLabel` / `startDay` → a project-calendar date, `status`
  and `importance` → the matching fields, `pov` / `location` /
  `presentCharacters` → `involves` / `occursAt` connections). No schema change.
- Ship as-is and treat legacy data as abandoned.
- Migrate eagerly on first open of the Studio.

### 3. Continuity re-hosting

Whether the continuity panel and impact trace should return to Timeline Studio
over a Universal-Record projection, move to another Studio, or be retired.

## Working tree status

**Nothing committed. Nothing pushed.**

```
 M flutter-author-studio-v1/lib/main.dart
 M flutter-author-studio-v1/lib/release_destinations.dart
 M flutter-author-studio-v1/lib/timeline_domain.dart
 M flutter-author-studio-v1/lib/timeline_service.dart
?? flutter-author-studio-v1/lib/timeline_studio.dart
?? flutter-author-studio-v1/test/timeline_studio_view_test.dart
?? flutter-author-studio-v1/docs/timeline-studio-completion-map.md
```

`pubspec.lock` was modified by `flutter pub get` (it had stale `isar_community`
entries no longer in `pubspec.yaml`) and has been restored to `HEAD`. No other
file outside Timeline was touched — Map, Community, Progression, AI, Manuscript,
Character, World and Plot Studios and the Theme Engine are all unmodified.
