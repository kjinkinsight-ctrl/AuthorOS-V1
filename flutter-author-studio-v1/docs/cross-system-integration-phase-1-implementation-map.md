# Cross-System Integration Phase 1 — Implementation Map

Audited: August 20, 2026
Status: **BLOCKED — preconditions not met. No integration code written.**

## Executive summary

Phase 1 directed the integration of five authoritative systems: Progression,
Analytics, Community, Universal Records, and Theme.

A full repository inspection found that **one of the five exists**. Universal
Records is real, substantial, and authoritative. Progression, Analytics,
Community, and the Theme Engine described in the directive **do not exist in
this repository in any form, under any name.**

Because an integration phase can only connect systems that exist, Requirements
1 through 9 cannot be executed as written. Executing them would require first
building four foundational systems from scratch — which is not integration, and
which the directive explicitly places out of scope.

This document is the deliverable required by the SETUP section, and it records
the audit that produced the blocking finding. Per SETUP item 9 — *"Do not assume
anything exists merely because the roadmap says it exists"* — the audit was
performed before any code was written, and it stopped the phase.

## Audit method

Verification was by symbol search across `lib/` and `test/`, not by reading the
roadmap. Each named class in the directive was searched for directly, then
re-searched case-insensitively by concept to catch renamed equivalents, then
cross-checked against git history for deleted files.

## Finding 1 — System existence

| Directive system | Named symbols searched | Files found | Verdict |
|---|---|---|---|
| **Universal Records** | `AuthorRecord`, `RecordScope`, `CanonStatus`, `AuthorRecordStatus`, `StoryBranch` | 60 / 3 / 36 / 24 / 31 | **EXISTS — authoritative** |
| **Progression** | `ProgressionService`, `ProgressionExperience`, `ProgressionReader` | 0 / 0 / 0 | **ABSENT** |
| **Analytics** | `AuthorAnalyticsService`, `AnalyticsDataSource`, `WritingSession` | 0 / 0 / 0 | **ABSENT** |
| **Community** | `PublicProgressionProfile`, `PublicAuthorProfile`, `WorldShowcaseProjector`, `CommunityProjectionService`, `PublicPayloadGuard`, `WorldBoardAssembler`, `CommunityBackend` | 0 across all seven | **ABSENT** |
| **Theme Engine** | `ThemeRegistry`, `ThemeResolver`, `ThemePersistence`, `ThemeEngine`, `ResolvedTheme`, `StudioId`, `ThemeColorRef` | 0 across all seven | **ABSENT as described** |

### Concept-level re-check (case-insensitive)

The absent systems were searched again by concept to rule out renaming:

- `achievement` — **zero occurrences** in `lib/` and `test/`.
- `streak` — **zero occurrences**.
- `writing session` — **zero occurrences**.
- `community` — **zero occurrences**.
- `progression` — 7 occurrences, all narrative: a Plot Studio record-type field
  labelled "Progression", and `characterArcProgression` / `worldArcProgression`
  in `lib/plot_service.dart`. These are story-arc concepts, not an XP engine.
- `analytics` — 3 occurrences, all UI label strings in `lib/main.dart` and
  `lib/release_destinations.dart` ("Track continuity", "Review manuscript…
  analytics from canonical data"). No analytics runtime exists.

### Git history check

No Progression, Analytics, Community, or Theme-Engine source file has ever been
deleted from this repository. The only removed theme-related file is
`css/themes.css`, an artifact of the superseded web application. These systems
were never built here.

### Roadmap cross-reference

`docs/authoros-2-master-plan.md` is consistent with the audit, not with the
directive. It places these capabilities in the **future**:

- **M8: Author Journey and optional World community** — "local writing sessions,
  heat maps, streaks, goals, and milestones", "opt-in aggregated community
  metrics through the platform API".
- Section 11 lists "private achievements and optional levels" as a planned
  deliverable.
- Line 439: "Community statistics remain a separate opt-in platform phase."

The repository is currently at the Universal Records / Studios stage. **M8 has
not started.** The directive appears to assume a state the codebase has not
reached.

## Finding 2 — What actually exists

### Universal Records (authoritative, real)

`lib/core/connected_domain.dart` defines the canonical record envelope:

```dart
class AuthorRecord {
  final String id;
  final String typeId;
  final RecordScopeType scopeType;
  final String scopeId;
  final String? projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
  final AuthorRecordStatus status;   // active | archived | deleted
  ...
}
```

`lib/core/record_scope.dart` defines scope identity and canon state:

```dart
enum RecordScopeType { library, universe, series, project, book, branch, manuscript }
enum CanonStatus { canon, draft, proposed, deprecated, nonCanon, alternate }
class RecordScope {
  final RecordScopeType type;
  final String id;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  void validate();
}
```

`lib/core/branch_domain.dart` defines branch identity and lifecycle:

```dart
enum BranchStatus { active, archived }
class StoryBranch { final String id, projectId, name; final BranchStatus status; ... }
```

Supporting services, all real and tested: `RecordService`, `BranchService`,
`BranchEngine`, `ConnectionEngine`, `VersionAuditService`, `SafeDeleteService`,
`RecordInspector`, `UniversalSearch`, `TemplateEngine`, `AuthorOsArchiveService`,
`DriftConnectedDomainRepository`, `AuthorOsDatabase`.

### Theme (real, but not the described engine)

`AppThemePreset` in `lib/main.dart:31` — a two-preset (`light`, `dark`) value
class holding `Brightness` and three `Color` fields, with `normalizeId()`
mapping legacy ids (`paper`, `slate`, `obsidian`, `midnight`, `forest`,
`burgundy`, `plum`, `ocean`) onto the two survivors. Persisted under the
SharedPreferences key `author_studio.theme_id`. Covered by
`test/settings_theme_test.dart`.

This is a presentation-layer preset list, not a registry/resolver/persistence
engine with `StudioId` and `ThemeColorRef` indirection.

### Author profile (real — relevant to the "no second profile" rule)

A profile already exists as SharedPreferences keys under `author_studio.profile.*`
(`name`, `email`, `bio`, `website`, `avatar_path`, `focus`, `newsletter`,
`goodreads`, `x`, **`public`**, `require_reauth`, `secure_sessions`,
`sync_alerts`). Note `author_studio.profile.public` — a publication-visibility
flag already exists and must be treated as the authoritative profile if a
Community phase is ever built.

## Finding 3 — Naming collision on "cross-system"

`test/cross_system_integration_test.dart` (1,019 lines, 17 tests) and
`test/fixtures/cross_system_fixture.dart` (644 lines) **already exist**, and
`docs/cross-system-foundation-implementation-map.md` (34.5 KB) documents them.

These use "cross-system" in an entirely different sense: integration *among the
Universal Records subsystems* — Search, Inspector, Safe Delete, Version Audit,
Branch overlays, legacy migration, archive round-trip. They do not touch
Progression, Analytics, Community, or Theme.

**Any future Phase 1 work must not reuse the `cross_system_integration` name**,
or it will collide with an existing, passing, well-established test suite.

## Requirement-by-requirement feasibility

| Req | Subject | Status | Reason |
|---|---|---|---|
| 1 | Shared project context | **Already satisfied — no code needed** | See below |
| 2 | Progression → Analytics | **Blocked** | Neither system exists |
| 3 | Progression → Community | **Blocked** | Neither system exists |
| 4 | Analytics → Community | **Blocked** | Neither system exists |
| 5 | Universal Records boundary | **Partially satisfied** | Records is authoritative; no consumer exists to bound |
| 6 | Public projection chain | **Blocked** | No `PublicPayloadGuard`, no projection chain, no World Board |
| 7 | Theme isolation | **Already satisfied — verified** | See below |
| 8 | No second state store | **Satisfied by inaction** | Nothing added |
| 9 | Integration tests | **Blocked** | 12 of 17 cases reference absent systems |
| 10 | Regression protection | **Honoured** | No existing behaviour modified |
| 11 | Documentation | **This document** | Delivered |
| 12 | Verification | **Baseline captured** | See results below |

### Requirement 1 is already met

The directive says: *"If an equivalent context object already exists, reuse it
instead."* It does. `RecordScope` provides precisely the required tuple —
project id, optional series id, optional book id, optional branch id — and
validates its own invariants. Canon state is `CanonStatus`, in the same file.
Active/archive state is `AuthorRecordStatus` (record level) and `BranchStatus`
(branch level). `RecordScope` holds no persistence and is plain Dart.

**No new context contract should be created.** Creating one would duplicate the
Universal Records model, which Requirement 1 forbids.

### Requirement 7 is already met

`lib/core/` contains **zero** imports of `package:flutter/material.dart` or
`package:flutter/widgets.dart` — verified by grep across the whole directory.
The domain layer is plain Dart. The theme lives in `lib/main.dart`, the UI
layer, and nothing in the domain imports it. Theme isolation holds today by
construction. Any future phase must preserve this rather than establish it.

## Architecture — target vs. actual

The directive's intended dependency direction:

```
Universal Records → Project/branch context → Progression / Analytics
                  → Public projections → Community

Theme Engine → Studio/UI presentation   (separate, no domain coupling)
```

What exists today:

```
Universal Records (AuthorRecord, RecordScope, StoryBranch, CanonStatus)
        ↓
Studios (Character, Story Codex, World, Timeline, Plot, Manuscript)
        ↓
UI layer (main.dart, *_studio.dart, *_workspace.dart) ── AppThemePreset

[Progression]  — does not exist
[Analytics]    — does not exist
[Community]    — does not exist
[Theme Engine] — does not exist (AppThemePreset only)
```

The lower half of the target diagram has no counterpart in the codebase. There
is nothing to point an arrow at.

## Authoritative ownership

Stated as the directive requires, with current reality noted:

| Domain | Owner | Exists? |
|---|---|---|
| Records | Universal Records owns records. | **Yes** |
| Progression | Progression owns progression. | No — unbuilt |
| Analytics | Analytics owns analytics. | No — unbuilt |
| Publication/projection | Community owns publication/projection. | No — unbuilt |
| Presentation | Theme owns presentation. | Partially — `AppThemePreset` |

## Privacy boundaries

None exist to document. There is no `PublicPayloadGuard`, no public projection,
no World Board, and no network functionality. No private data is currently at
risk of leaking through a community surface, because no community surface
exists.

When Community is eventually built, the fail-closed rules from the directive
should govern it: hidden values must be **absent**, never coerced to zero, and
private record/project/branch ids must never cross the projection boundary.

## Verification baseline (pre-change)

Captured before any modification, to serve as the comparison baseline the
directive requires.

| Check | Result |
|---|---|
| `flutter test` | **387 tests, all passed** (exit 0) |
| `flutter analyze` | **53 issues: 0 errors, 9 warnings, 44 infos** (exit 1 — issues, not failure) |
| `flutter build web --release` | **Succeeded** (exit 0, 54.9s) |
| `flutter build linux --release` | **Not applicable** — host is Windows 11; no Linux toolchain |

The 53 analyzer issues are pre-existing and unrelated to this phase: unused
imports in existing tests, `prefer_const_constructors` infos, two unused
private elements in `built_in_record_types.dart`, and three
`deprecated_member_use` infos for `DropdownButtonFormField.value` in
`world_studio.dart`.

The web build emits a pre-existing non-fatal warning: fonts expected for
`packages/cupertino_icons/CupertinoIcons` were not found. This does not fail the
build and predates this phase.

## Deferred systems

Deferred by the directive, and confirmed absent: Community Phase 2, Analytics
Phase 2, Progression Phase 3, Map Studio, Expansion architecture, Deep Linking,
network functionality.

**Additionally deferred by this audit** — because they are prerequisites, not
successors: Progression Phase 1, Analytics Phase 1, Community Phase 1, and Theme
Engine Phase 1. Cross-System Integration Phase 1 cannot precede them.

## Testing strategy (when unblocked)

Of the 17 required integration test cases, 5 are testable against today's
codebase and 12 are not:

**Testable now** — 7 (Records context reaches read models), 8 (branch
isolation), 9 (canon isolation), 10 (archived records excluded), 13 (no
duplicate persistence). Note that 7–10 are already substantially covered by the
existing `test/cross_system_integration_test.dart`.

**Not testable** — 1–6 (progression/analytics/community availability and
hiding), 11 (private ids in public payloads — no payload exists), 12 (theme
independence from services that do not exist), 14–16 (existing Community,
Analytics, and Progression tests — none exist). 17 (Theme tests) maps to
`test/settings_theme_test.dart`, which passes.

## Known limitations

1. Four of five systems named authoritative by the directive do not exist.
2. The directive's phase ordering conflicts with `authoros-2-master-plan.md`,
   which schedules this work at M8.
3. The `cross_system_integration` test name is already taken by an unrelated
   suite.
4. Linux build cannot be verified on this Windows host.
5. This document describes an audit, not an implementation. No integration
   contract, adapter, or test has been written.

## Recommendation

Do not proceed with Cross-System Integration Phase 1. Integration is meaningful
only once at least two of the systems exist. The prerequisite is a foundation
phase for Progression, Analytics, and Community — each of which is a
substantial system in its own right, and each of which the directive forbids
building here.

Requirements 1 and 7 are the exception: both are already satisfied by the
existing codebase and require no work at all. That is a genuine, if small,
Phase 1 result — the shared context contract and theme isolation the phase
sought to establish are already in place.
