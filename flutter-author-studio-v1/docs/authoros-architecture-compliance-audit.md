# AuthorOS Architecture Compliance Audit

> **AUDIT + LOCK PASS.** This audit reads the tree; it does not restructure it.
> The only source change made alongside it is `test/architecture_lock_test.dart`,
> which pins invariants that are already true today.

Audited: August 22, 2026
Branch: `claude/authoros-architecture-lock-2qri2r`
Base commit: `3059221` — *Merge pull request #68 from claude/authoros-codex-knowledge*
Measures: [AuthorOS Architecture Lock](architecture/authoros-architecture-lock.md), Locks 1–12
Scope: `flutter-author-studio-v1/lib` — the actual implementation, not the roadmap

---

## Scale

| Metric | Value |
|---|---|
| Dart files in `lib/` | 172 |
| Lines of Dart in `lib/` | 118,439 |
| Hand-written (excluding `*.g.dart`) | 106,139 |
| Test files | 155 |
| Existing architecture-guard tests | 5 (`command`, `map`, `research`, `scope`, `story_graph`) |
| Top-level navigation destinations | 21 (`StudioSection`) |

---

## Categories

| Status | Meaning |
|---|---|
| 🟢 Compliant | Already follows the locked architecture |
| 🟡 Compatible | Works and does not violate a lock, but needs extension to satisfy one fully |
| 🟠 Architectural debt | Works, violates a lock locally, correctable without a rebuild |
| 🔴 Conflict | Must be corrected before dependent future work proceeds |
| ⚪ Future | Not implemented yet — the lock governs it when it arrives |

---

## Headline

**The tree is in materially better architectural health than the volume of
feature work would predict.** The Universal Creative Model is real, not
aspirational: `AuthorRecord` and `RecordLink` are each declared exactly once in
172 files, and Character, World, Codex, Research, Plot, Timeline, Series and Map
Studios all consume them rather than owning private entity models. Map Studio —
the largest single studio at ~14,000 lines across six phases — declares no store,
no vocabulary and no theme of its own, and says so in its own guard test.

The findings below are therefore a **short correction list, not a remediation
programme**: one 🔴 conflict, four 🟠 debts, five 🟡 extensions. Per
[ADR-0006](architecture/ADR-0006-architectural-precedence.md), nothing else is
touched.

| Status | Count |
|---|---|
| 🟢 Compliant | 11 |
| 🟡 Compatible | 5 |
| 🟠 Architectural debt | 4 |
| 🔴 Conflict | 1 |
| ⚪ Future | 6 |

---

## Lock 1 — One canonical representation

### 🟢 The record envelope is singular

`class AuthorRecord` is declared in exactly one place, `lib/core/connected_domain.dart:25`,
across the entire tree. No studio declares a competing entity type. The
`UniversalRecordsRepository` boundary (`lib/core/universal_records.dart`) states
the rule in its own doc comment and holds to it: *"This type owns no storage and
no rules of its own."*

### 🟢 Studios are lenses, not owners

`CharacterService`, `WorldService`, `StoryCodexService`, `ResearchService`,
`PlotService`, `TimelineService` and `MapService` all import
`core/record_service.dart` and operate on `AuthorRecord`. There is no
`CharacterRow`, no `LocationTable`, no per-studio entity.

Map Studio is the strongest instance. `lib/map_domain.dart` opens with:

> *"Map Studio owns no store of its own — every value here is a projection of an
> existing Universal Record."*

Map, location, region and marker records are ordinary records of the existing
`map`, `location`, `region` and `map-marker` types; Map Studio adds only
placement data, under a reserved `_map.` field prefix so it cannot collide with a
template field.

### 🟡 Manuscript structure remains specialised — as designed

`ManuscriptStore` keeps chapters and scenes in a project-scoped structure rather
than as generic records. This is the sanctioned specialisation in Lock 1, and it
is correctly bounded: prose moved out into `scene_prose_rows`, history into
`scene_revision_rows`, and both are documented as having exactly one owner each.

The remaining gap is that the structure blob still lives in `SharedPreferences`
rather than the embedded database, which is a Step 5 migration item, not a
violation.

---

## Lock 2 — One relationship model

### 🟢 `RecordLink` is the only edge model in `core`

Declared once, at `lib/core/connected_domain.dart:215`. `ConnectionEngine` is the
only writer. Deletion detaches edges through the engine so nothing is left
pointing at a record a studio can no longer read.

### 🔴 CONFLICT — a second, live relationship model in the manuscript path

**`SceneRelationship` is still authored into production from the live manuscript
surface, and never reaches the canonical graph.**

The evidence:

| Location | What it does |
|---|---|
| `lib/manuscript_store.dart:88` | Declares `SceneRelationship` — `id`, `type`, `targetId`, `label`, `metadata` |
| `lib/manuscript_studio.dart:3037` | The **live, routed** `ManuscriptStudioView` writes a new `SceneRelationship` into the scene from an "Add relationship" dialog, with a free-text `targetId` |
| `lib/manuscript_service.dart:1173` | The **modern** path creates a real `RecordLink` through `ConnectionEngine` |
| `lib/manuscript_service.dart:1460` | Validates `scene.relationships` and reports `broken-reference` |
| `lib/manuscript_service.dart:1475` | Validates backlinks and reports `broken-connection` |
| `lib/migrations/legacy_connection_slice.dart` | Maps `SceneRelationship` → `RecordLink` — but has **no production caller**; it is reachable only from `test/connected_domain_test.dart` |

So AuthorOS currently has two answers to "what is a relationship", two authoring
paths that produce them, and two distinct validation error codes for the same
idea — and the older of the two is invisible to `ConnectionEngine`, the knowledge
graph, deterministic continuity, canon conflict detection, universal search, and
the archive.

This is a Lock 2 violation and, because those relationships never enter the
graph, a Lock 8 violation as well: intelligence cannot reason over data it cannot
see.

**Correction (Step 3), bounded:** route the manuscript surface's relationship
dialog through `ManuscriptService.connectNode`, so the author's action produces a
`RecordLink` against a resolved record rather than a free-text string; keep
`SceneRelationship` as a **read-and-migrate** shape, following the precedent
already set by `lib/migrations/research_panel_store.dart`, since author data
exists in the legacy field and it is not covered by archive or sync. Do not
rewrite `ManuscriptStore`.

---

## Lock 3 — Views are not records

### 🟢 Enforced, and already guarded by a test

`lib/map_terrain.dart` states the rule and `test/map_architecture_test.dart`
pins it: terrain and placed assets *"are never `AuthorRecord`s and never
endpoints of a `RecordLink`, so a map with two thousand trees adds two thousand
pieces of scenery and zero nodes to the story graph."*

`lib/map_world.dart` extends the same discipline to world state: a world state is
a projection computed from records and links and thrown away when the view
rebuilds. Phase 6 presentation and export are readings of Phases 3–5, asserted by
snapshot tests that check the database is byte-identical afterwards.

---

## Lock 4 — Universal fields and templates

### 🟡 The mechanism exists; the configuration surface is a subset

`RecordFieldDefinition` (`lib/core/record_types.dart:29`) and `TemplateEngine`
(`lib/core/template_engine.dart`) are real, versioned, and shared. 24 field
primitives are supported, and `TemplateEngine` already handles compatibility,
upgrade plans, and required-field migration.

Measured against the thirteen capabilities Lock 4 requires:

| Capability | State |
|---|---|
| Input type | 🟢 `RecordFieldType`, 24 primitives |
| Options | 🟢 `options` |
| Default | 🟢 `defaultValue` |
| Required | 🟢 `required` |
| Relationships | 🟢 `recordReference` / `relationship` + `referenceTypeIds` |
| Enabled | 🟡 `hidden` exists, but hidden-in-a-view is not the same contract as disabled-in-a-project |
| Custom values | 🔴 absent — no "author may enter a value outside the options" flag |
| Quick Create | 🔴 absent |
| Main View | 🔴 absent |
| Searchable | 🟠 **exists only as an ad-hoc convention** |
| Track Changes | 🔴 absent at field level (`RecordVersionRows` is record-level) |
| Conditional availability | 🔴 absent |
| Calculated values | 🔴 absent |

### 🟠 DEBT — `searchable` smuggled through `extensionData`

`lib/core/world_record_types.dart` lines 129–153 carry
`extensionData: {'searchable': true}` on five alias fields. The concept exists in
AuthorOS twice: as an informal convention in one file, and as a contract nowhere.
This is exactly the failure mode ADR-0006 was written to stop, and it is the
clearest single argument for doing Step 4 before more specialised entry surfaces
are built.

**Correction:** Step 4 — promote `searchable` to a declared property of
`RecordFieldDefinition` and migrate the five call sites. Not a Step 3 item; it is
resolved by building the foundation, not by patching around it.

### 🟠 DEBT — reference field types duplicate the reference mechanism

`RecordFieldType` declares `characterReference`, `locationReference`,
`plotThreadReference` and `timelineReference` alongside the general
`recordReference` + `referenceTypeIds` pair. These are the same capability
expressed twice, and the specialised four cannot express a reference to a record
type that does not have a bespoke enum value — which is precisely what twenty
future Systems will need.

**Correction:** Step 4 — resolve the four specialised kinds to
`recordReference` with a constrained `referenceTypeIds`, keeping the old ids
readable so persisted values survive.

---

## Lock 5 — Systems live inside domains

### ⚪ Future — nothing has been built, and nothing has been foreclosed

No `SystemRegistry`, no system-scoped record grouping, no per-system activation
exists. That is the correct state: the twenty specialist systems are future
capability.

What matters for the lock is that the foundations they need already exist and are
generic — custom `RecordTypeDefinition`s, project-scoped registries, typed
relationship definitions — so a System can be delivered as record types, fields,
relationships and views without a store of its own.

### 🟠 DEBT — the navigation surface is already flat and already crowded

`StudioSection` (`lib/main.dart:845`) is **21 flat top-level destinations**:
dashboard, worldBoard, search, statistics, analytics, backup, projects, series,
ideas, manuscript, chapters, characters, codex, world, map, plot, timeline,
knowledgeGraph, research, notes, settings.

Lock 10 asks for five groups. Three of the current 21 (`statistics`, `analytics`,
`worldBoard`) are arguably one destination; `chapters` sits beside `manuscript`;
`notes` sits beside `research`. The surface is already showing the linear-growth
pattern the lock exists to prevent, and adding twenty Systems to it would be
fatal to the "calm UI" goal.

**Correction:** not Step 3. The lock's binding requirement is that *new* work must
not extend the surface, which `architecture_lock_test.dart` now enforces by
pinning the count at 21. Regrouping the existing 21 into the five broad domains is
UI work to be scheduled deliberately, and is explicitly **not** a reason to
restructure working studios.

---

## Lock 6 — Deactivation hides, never deletes

### ⚪ Future — but the precedent is already set correctly

There is no activation model yet. The relevant existing evidence is that AuthorOS
already treats data preservation as a hard rule elsewhere:

- `SafeDeleteService` and `safe_delete.dart` make deletion soft and audited.
- `UniversalRecordsRepository.deleteRecord` detaches relationships through
  `ConnectionEngine` rather than orphaning them.
- `research_panel_store.dart` is kept, unused, purely because *"author data can
  exist in it... Deleting it would destroy the only copy."*

That last comment is Lock 6 reasoning applied before Lock 6 was written. The
activation model, when built, inherits it.

---

## Lock 7 — Presets configure, never restrict

### 🟢 The one place this currently applies is compliant

`StoryTemplateLibrary` (`lib/onboarding.dart:36`) maps genre to scene
suggestions, arc names, a beat checklist, and a chapter blueprint. Genre seeds a
starting configuration and nothing else. No code path treats genre as a
capability gate — `starter_project.dart` carries `genre` as a plain string with a
`'Fantasy'` fallback, and nothing branches on it to withhold a feature.

The lock is recorded now so that this stays true when presets grow to select
active Systems.

---

## Lock 8 — Deterministic intelligence

### 🟢 There is no AI layer, and no dependency that could become one

`pubspec.yaml` declares 11 runtime dependencies: `archive`, `crypto`, `drift`,
`drift_flutter`, `file_selector`, `flutter`, `flutter_web_plugins`, `http`,
`package_info_plus`, `pdf`, `shared_preferences`, `supabase_flutter`. No
generative-model client, no inference SDK.

### 🟢 The intelligence that exists is deterministic and evidence-backed

`CanonConflictFinding` carries *"both sides of it... because a contradiction the
author cannot inspect is just an accusation."* `ContinuityWarningType.canonContradiction`
is documented as raised *"only from structured data — record fields, per-book
states, and typed relationships. Prose is never parsed for facts."*
`codex_intelligence.dart` states plainly: *"This file adds no second engine and
no second recogniser."* `analytics_service.dart`: *"nothing calculated here is"*
non-reproducible. `map_world.dart` returns `MapTravelEstimate.unavailable` rather
than a plausible number.

This is the lock the codebase honours most consistently.

### 🟠 DEBT — the intelligence vocabulary is welded to Flutter

`lib/continuity.dart` (1,074 lines) declares `ContinuityWarningType`,
`ContinuitySeverity`, `ContinuityActionKind` and `ContinuityWarning` — the shared
vocabulary that `canon_conflict_service.dart`, `codex_continuity.dart`,
`manuscript_continuity.dart`, `world_continuity.dart` and `codex_intelligence.dart`
all depend on — in the same library as `ContinuityTimelinePanel`, a
`StatefulWidget`, and `import 'package:flutter/material.dart'`.

Every core domain file checked is Flutter-free: `record_service`, `record_graph`,
`universal_records`, `template_engine`, `story_codex_domain`, `world_domain`,
`timeline_domain`, `map_domain`, `map_terrain`, `map_world`, `prose_document`,
`scene_prose`, `scene_revision`, `canon_facts`, `connection_engine`,
`story_graph`, `universal_search`, `entity_recognition`, `codex_intelligence`,
`record_validation` — all zero Flutter imports. `continuity.dart` is the
exception, and it sits at the root of the intelligence layer rather than at its
edge.

**Correction (Step 3), bounded:** extract the vocabulary into
`lib/core/continuity_domain.dart` as plain Dart and re-export it from
`continuity.dart` so no call site changes. This is a file split, not a redesign.

---

## Lock 9 — Generation produces canonical entities

### ⚪ Future — Phase 7 is genuinely unstarted

Map Studio Phase 6 closed with *"No Phase 7 was started."* No procedural
generator, no seed model, no generation sandbox and no provenance namespace
exists in `lib/`.

The architectural groundwork Phase 7 will need is already present and already
compliant:

- canonical location, region, city and building vocabulary in
  `world_record_types.dart`
- typed relationships in `built_in_connection_types.dart`
- geometry as record fields under the reserved `_map.` prefix
- `AuthorRecord.extensionData` as a documented home for provenance
- a determinism precedent: Phase 5 already guarantees identical world state
  *"down to the order of the steps in the explanation"*

The one thing Lock 9 adds beyond the existing Phase 7 groundwork: **the generator
must produce canonical world entities, not map-only objects.** A generated city
is a city record whose buildings are building records — the map is the view.

Per the sequence, Phase 7 does not begin until Step 6 re-audits it against this.

---

## Lock 10 — Broad-domain navigation

Covered under Lock 5 above. 🟠 — 21 flat destinations, now pinned.

---

## Lock 11 — Competitor features as targets, not architecture

### 🟢 The research is already framed this way

`research/author-studio-market-research.md`,
`research/codex-heim-competitive-research.md` and
`research/sudowrite-competitive-research.md` sit in a `research/` directory,
separate from `docs/`, and no implementation map cites a competitor's data model
as a design. The Codex work took the *capability* from Codex Heim and delivered
it as `AuthorRecord` + `RecordLink` + `CodexScopeFacet` — where `CodexScopeFacet`
is explicitly documented as *"a two-value view over `RecordScopeType`, not a
second scope model."*

That is the Lock 11 translation performed correctly, before the lock existed.

---

## Lock 12 — Dependency direction

### 🟢 Held, and already partially tested

`test/universal_records_phase1_test.dart` carries a `dependency direction` group
asserting the core model files import no Flutter, no `dart:ui`, no drift, no
theme, no persistence and no studio; `record_id.dart` is asserted to import
nothing at all. The 20-file sweep in this audit found zero violations outside
`continuity.dart` (above).

`architecture_lock_test.dart` widens that guard from 7 core files to the whole
domain and intelligence surface.

---

## Cross-cutting observations

These are not lock violations. They are recorded because they cost the audit time
and will cost the next one more.

### 🟠 DEBT — `release_destinations.dart` is an architectural attic

3,705 lines, named for release destinations, containing: settings UI,
`StoryCodexEntry`, `AuthorOsFeatureFlags`, search navigation targets, app
updating, and local image handling. Four production files and five test files
import it, so it is load-bearing.

Nothing in it violates a lock. But a file whose name predicts none of its
contents is where the *next* violation will land unnoticed, because no reviewer
looking for a relationship model would think to open it.

**Correction:** not Step 3 — this is a naming and altitude problem, and ADR-0006
explicitly does not authorise rebuilding working code to make it look tidier.
Split it opportunistically when its areas are next touched for a real reason.

### 🟢 `main.authorstudio.backup.dart` — dead but quarantined

838 lines, imported by nothing in `lib/`. Already recognised:
`test/theme_application_test.dart:638` names it `quarantined` and asserts nothing
imports it. Correctly handled; no action.

### 🟢 SharedPreferences holdouts are correctly classified

17 files reference `SharedPreferences`. Of those:

| Class | Files | Verdict |
|---|---|---|
| Application setting | `theme_persistence`, `authoros_theme`, `author_profile_store`, `reading_rhythm` | 🟢 Sanctioned by the master plan |
| Operational metadata | `backup_health`, `sync_engine`, `sync_store` | 🟢 Outside the creative graph |
| Migration read path | `research_panel_store` | 🟢 Documented as read-and-migrate, deliberately retained |
| Creative corpus | `manuscript_store`, `onboarding`, `timeline`, `visual_planning` | 🟡 Step 5 migration targets |

`timeline.dart` and `visual_planning.dart` are already fully superseded — the
only `lib/` importer of either is `migrations/legacy_reference_adapters.dart`.
The live surfaces are `TimelineService` and the plot/story graph, both of which
are canonical-model consumers. These two are migration-input files, not live
parallel stores, and the audit records them as 🟡 rather than 🟠 for that reason.

`prose_document.dart` and `scene_prose.dart` reference `SharedPreferences` only
in doc comments describing what they replaced.

---

## The correction list

Everything the audit asks for, in one place. Nothing else is in scope.

### Step 3 — correct genuine conflicts

| # | Item | Lock | Size |
|---|---|---|---|
| 1 | Route the manuscript relationship dialog through `ManuscriptService.connectNode`; demote `SceneRelationship` to read-and-migrate | 2, 8 | Bounded — one dialog, one migration path |
| 2 | Extract the continuity vocabulary into `lib/core/continuity_domain.dart`, re-exported from `continuity.dart` | 8, 12 | File split, no call-site changes |

### Step 4 — universal field and template foundation

| # | Item | Lock |
|---|---|---|
| 3 | Add the seven missing field-configuration properties (custom values, quick create, main view, searchable, track changes, conditional availability, calculated) | 4 |
| 4 | Promote `searchable` from `extensionData` to a declared property; migrate the five `world_record_types.dart` call sites | 4 |
| 5 | Resolve `characterReference` / `locationReference` / `plotThreadReference` / `timelineReference` to `recordReference` + `referenceTypeIds`, keeping persisted ids readable | 4 |
| 6 | Distinguish *enabled* (project configuration) from *hidden* (view state) | 4, 6 |

### Step 5 — model integration

| # | Item | Lock |
|---|---|---|
| 7 | Project configuration surface on `ProjectRows` — currently an opaque `payloadJson` with nowhere to record active systems and extensions | 5, 6 |
| 8 | Migrate the manuscript structure blob out of `SharedPreferences` into the embedded database | 1 |
| 9 | Complete and retire the `timeline.dart` / `visual_planning.dart` legacy read paths | 1 |

### Step 6 — Phase 7 re-audit

| # | Item | Lock |
|---|---|---|
| 10 | Re-audit the Map Studio Phase 7 design against Lock 9 before 7A begins: generated entities canonical, provenance stored, sandbox before canon, regeneration respects author edits | 9 |

### Explicitly not in scope

- Splitting `release_destinations.dart` — do it when its areas are touched for a real reason.
- Regrouping the 21 navigation sections — deliberate UI work, scheduled separately, and not a licence to restructure studios.
- Anything in Map Studio Phases 1–6, the Codex, Character Studio, World Studio, the Theme Engine, or prose persistence. They comply. Per ADR-0006, compliance is not a licence to rebuild.

---

## Re-running this audit

Most findings above were reached with `grep` and `wc` over `lib/`, and can be
re-derived. The invariants worth keeping continuously true have been moved into
`test/architecture_lock_test.dart`, which fails CI rather than waiting for the
next audit:

- one `AuthorRecord` declaration, one `RecordLink` declaration
- studios declare no persistence
- the domain and intelligence layers import no Flutter
- the navigation surface stays at 21 destinations
- no generative-AI dependency enters `pubspec.yaml`

The locks not yet represented there — field configuration, project
configuration, deactivation preserving data, generation provenance — become
testable as Steps 4, 5 and 6 land, and the test grows with them.
