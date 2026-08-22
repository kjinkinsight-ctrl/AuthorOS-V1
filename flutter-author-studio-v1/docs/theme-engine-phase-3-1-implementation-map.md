# Theme Engine Phase 3.1 — Token Completion & Palette Decisions — Implementation Map

Audited and implemented: August 21, 2026
Status: **Delivered. All three Phase 3 token blockers closed; two questions answered with evidence and left unchanged.**

## Executive summary

Phase 3 ended with 37 colour literals that could not be migrated because the
token vocabulary had no way to express them, plus two open questions. Phase 3.1
closes the vocabulary gaps and answers both questions.

| Phase 3 blocker | Outcome |
|---|---|
| No `success` / `warning` / `error` roles | **Closed** — three roles added; 27 literals migrated |
| No categorical ramp | **Closed** — 8-slot ramp added; 10 literals migrated |
| `onSurfaceVariant == onSurface` | **Investigated — intentional.** Evidence below; left unchanged |
| JetBrainsMono missing | **Not required by the repository.** Deferred with an exact integration point |
| Legacy classes possibly dead | **Proven.** One is genuinely dead; reported, not deleted |

**Studio view code in `lib/main.dart` now contains zero hard-coded colours.**
`continuity.dart`, `backup_health.dart` and `visual_planning.dart` contain zero
colour literals of any kind.

No second `ThemeData`, no second colour system, no new persistence layer.

---

## 1. Status roles

### Vocabulary

`ThemeColorRef` gains three members:

```dart
  /// Semantic status signals. Distinct from [primary] because they carry
  /// meaning ("this passed", "this failed"), not brand identity, and from
  /// [ThemeCategoryRef] because they are states rather than categories.
  success,
  warning,
  error,
```

Because `ThemeDefinition.validate()` already requires every palette to define
every role, adding them is enforced, not optional: a theme that omits one fails
registry construction.

### Values

Both palettes carry the same values, because the literals being replaced were
**theme-independent** — they rendered identically in light and dark before this
phase. Adopting the roles is therefore not a recolour.

| Role | Value | Replaces |
|---|---|---|
| `success` | `0xFF77B884` | continuity pass, backup restore passed, public-profile badge |
| `warning` | `0xFFC59B6D` | continuity warn, private-profile badge |
| `error` | `0xFFE07A6F` | continuity critical, backup restore failed |

**Owner decision left open:** these values were authored against dark surfaces.
Measured against each palette's own `surface`, contrast is:

| Role | on light surface (`#FFFFFF`) | on dark surface (`#141414`) |
|---|---|---|
| `success` | 2.34 : 1 | 7.87 : 1 |
| `warning` | 2.54 : 1 | 7.27 : 1 |
| `error` | 2.92 : 1 | 6.30 : 1 |

In light theme these are below WCAG AA for body text. **That is the
pre-existing behaviour, not a regression** — the literals rendered exactly this
way before. Giving the light palette darker status values is now a one-line
registry change per role, but it *is* a visual change and needs sign-off, so it
was not made. Recorded as the top item in §8.

### Accessibility policy

Neither `highContrast` nor `reduceIntensity` touches the status roles, and this
is deliberate rather than an oversight:

- **High contrast** pushes foregrounds towards black or white. Success, warning
  and error are told apart *by hue*; flattening them towards an extreme removes
  the distinction a high-contrast user needs most.
- **Reduced intensity** desaturates towards neutral grey. These roles render as
  label text as well as fills, so softening them would reduce reading contrast —
  which the transformation's own contract forbids — and a desaturated warning
  is not a calmer warning, it is an absent one.

This matches the existing design: the high-contrast transform already skips
`primary`, `surface` and `background`. A test pins the invariant across all
three accessibility combinations.

---

## 2. Categorical ramp

### Why a separate vocabulary

Scene workflow states and link kinds are **values a user's data falls into**,
not semantic UI states. Putting them in `ThemeColorRef` would have meant
inventing roles like `politicalLink` — exactly the per-Studio role invention the
Phase 3 brief forbids.

`ThemeCategoryRef` is therefore a separate, positional enum of eight slots,
living **inside `ThemePalette`** so a palette still owns every colour it
renders. There is no palette service and no second provider.

```dart
enum ThemeCategoryRef { category1 … category8 }
```

Slots are addressed positionally on purpose: a slot only has to stay
distinguishable from its neighbours, so one palette swap re-colours every
category at once.

### Slot assignment

The eight slots hold exactly the eight distinct colours the two switches used
before this phase, so every category keeps its current colour.

| Slot | Value | `SceneStatus` | Link category |
|---|---|---|---|
| `category1` | `0xFF858A94` | backlog | — |
| `category2` | `0xFF65A8A0` | outlining | Character, Relationship |
| `category3` | `0xFFC59B6D` | drafting | *(default)* |
| `category4` | `0xFFD39A52` | revised | — |
| `category5` | `0xFF77B884` | finalDraft | — |
| `category6` | `0xFF7EA6D8` | — | World, Discovery |
| `category7` | `0xFFE07A6F` | — | Political, War |
| `category8` | `0xFF9B8AC4` | — | Historical |

### Kept deliberately independent of status

Three slots hold the same value as a status role today (`category3`/`warning`,
`category5`/`success`, `category7`/`error`). They are **not** aliased to those
roles, and that is the point:

- A scene being **drafted** is not a warning.
- A **Political** link is a kind of thing, not a failure.

Aliasing would mean that darkening `error` for light-theme legibility (§1)
would silently recolour every Political link. Keeping them separate lets each
system move independently, which is what a token vocabulary is for.

Validation was extended: a palette missing a ramp slot now fails
`ThemeDefinition.validate()`, tested explicitly.

---

## 3. How widgets reach the new roles

Material's `ColorScheme` has no slot for "this check passed" or "this is a
Political link". Rather than add a parallel provider, the adapter projects the
new roles onto the **same** `ThemeData` as a Flutter `ThemeExtension`:

```dart
ThemeData(
  …,
  extensions: [AuthorOsSemanticColors.from(theme)],
)
```

Consequences, all deliberate:

- Any widget reads them via `Theme.of(context)`. **No `StudioThemeScope` is
  required**, so widgets that tests mount in a bare `MaterialApp` keep working.
- The engine remains the only thing that decides the values — a test asserts
  nothing outside `lib/theme/` constructs `AuthorOsSemanticColors`.
- There is still exactly **one** `ThemeData` and now exactly **one**
  `ThemeExtension`, both test-enforced.

`AuthorOsSemanticColors.fallback` covers hosts with no AuthorOS `ThemeData`. It
is built from the registry's light palette rather than hand-written constants,
so a bare host renders precisely what the pre-migration literals did. A test
asserts the fallback equals the registry.

### `ColorScheme.error` was deliberately not re-pointed

Mapping the `error` role onto Flutter's `colorScheme.error` was considered and
rejected for now. `ColorScheme.fromSeed` derives `onError` to contrast with its
*own* error colour; overriding `error` alone would leave `onError` (near-white)
on `#E07A6F` at roughly 2.5 : 1 — an unreadable pairing in Material's own
error surfaces, app-wide, in places nobody asked to change. Doing it properly
needs an `onError` companion role. Listed in §8.

---

## 4. `onSurfaceVariant == onSurface` — investigated, intentional

**Verdict: intentional. Left unchanged. No test weakened.**

The equality is not an accident of palette authoring. Git history shows it was
introduced deliberately, in one commit, as part of exactly this kind of
migration:

- Commit **`e7ff214`** added `.copyWith(onSurface: foregroundColor,
  onSurfaceVariant: foregroundColor, …)` to the shell's `ColorScheme`.
- **The same commit** migrated `Colors.white70` → `theme.colorScheme
  .onSurfaceVariant` across the dashboard and navigation.
- **The same commit** added the assertion in `settings_theme_test.dart` that
  pins `onSurfaceVariant == onSurface`.

So the author was performing the same literal→role migration Phase 3 continued,
and forced the two roles equal so that secondary text stayed at full strength
in **both** themes rather than becoming faint on a light surface. The test was
written in the same breath to lock that decision in.

The surrounding assertions confirm it was considered rather than incidental:
the test separately requires `contrast(onSurface, surface) ≥ 7` (WCAG AAA) and
`contrast(onSurfaceVariant, surface) ≥ 4.5` (AA). Those floors would still pass
if the roles differed — the equality line is an **additional, deliberate**
statement, not a by-product.

Changing it now would mean overturning a documented product decision and
rewriting a test that exists specifically to prevent that. Per the brief's own
instruction — *"If it is intentional, document why and leave it unchanged"* —
it is left alone.

The consequence remains as Phase 3 recorded it: AuthorOS currently has no
de-emphasised text tone. If one is wanted, it should be a **new** role
(`onSurfaceMuted`) rather than a redefinition of `onSurfaceVariant`, so the
existing legibility guarantee survives. Listed in §8.

---

## 5. JetBrainsMono — not required, deferred

**Verdict: the repository does not require JetBrainsMono. Deferred.**

Evidence — every occurrence of "jetbrains" in the repository:

| Location | What it is |
|---|---|
| `android/settings.gradle.kts`, `android/app/build.gradle.kts` | `org.jetbrains.kotlin.android` Gradle plugin — unrelated JetBrains product |
| `docs/theme-engine-phase-3-implementation-map.md`, `test/theme_application_test.dart` | Phase 3's own notes recording the gap |

There is no font asset, no `pubspec.yaml` entry, no widget reference, and no
code path that names the family. What the editor architecture actually requires
is *a monospace face*, which it has.

Downloading a third-party font binary into the repository is a supply-chain and
licensing decision for the owner, not something to do on inference — especially
when nothing in the repository asks for it.

### Exact integration point

Adding it later is a three-step change with **no widget edits**:

1. Place `JetBrainsMono-Regular.ttf` (and any weights wanted) in `assets/fonts/`.
2. Declare `- family: JetBrainsMono` under `fonts:` in `pubspec.yaml`, alongside
   the existing Inter and Merriweather entries.
3. In **`lib/theme/theme_registry.dart`**, in the `_typography` constant, change
   `ThemeTextRole.code` from `family: 'monospace'` to `family: 'JetBrainsMono'`,
   leaving `fallbackFamilies: ['Courier New', 'monospace']` as the fallback.

The consumer is already wired: `lib/manuscript_studio.dart` resolves
`ThemeTextRole.code` through the theme, and a test asserts it names no family
literal of its own. The existing "every declared family is resolvable" test —
which generalises the original Inter defect — will validate step 2
automatically.

---

## 6. Legacy classes — proven, reported, not deleted

Repo-wide reference count, excluding each symbol's own declaration and the
already-quarantined backup file:

| Symbol | `lib/` references | `test/` references | Verdict |
|---|---|---|---|
| `AppThemePreset` | 1 — `AppThemeSelection.resolvedAccentColor` (`lib/main.dart:135`) | `settings_theme_test.dart`, `theme_engine_test.dart` | **Live.** Keep. |
| `AppThemeSelection` | 0 | `settings_theme_test.dart` | **Live via test only.** Keep — it is the legacy contract's fixture. |
| `AppThemeAccent` | **0** | **0** | **Genuinely dead.** Nothing constructs or reads it. Reported, not deleted. |
| `main.authorstudio.backup.dart` | 0 (proven by existing architecture test) | 0 | **Dead, quarantined.** Reported in Phase 3. |

`AppThemeAccent` holds the eight retired accent swatches (`amber`, `teal`,
`crimson`, `cobalt`, `olive`, `coral`, `slate`, plus `default`). The accent
picker was retired before Phase 3 — the shell pins `accentId` to `'default'` on
every launch — so the class has no remaining reader. It survives analyzer checks
only because it is a public top-level class.

**Nothing was deleted.** Both dead items are owner decisions.

---

## 7. Hard-coded styling — post-migration audit

Full re-run across `lib/`. `Colors.transparent` is excluded throughout: it is
structural, not a colour choice.

| File | `Color(0x…)` | `Colors.*` | `TextStyle(` | Classification |
|---|---|---|---|---|
| `lib/theme/theme_registry.dart` | 46 | 0 | 0 | **The vocabulary itself** — the one place literals belong |
| `lib/theme/theme_resolver.dart` | 4 | 0 | 0 | Accessibility lerp targets — engine internals |
| `lib/theme/theme_tokens.dart` | 1 | 0 | 0 | Doc example |
| `lib/theme/flutter/authoros_theme.dart` | 0 | 0 | 3 | The adapter — builds `TextStyle` from tokens |
| `lib/main.dart` | 16 | 49 | 24 | see breakdown below |
| `lib/main.authorstudio.backup.dart` | 19 | 20 | 5 | **Dead code**, quarantined (§6) |
| `lib/welcome_page.dart` | 11 | 0 | 16 | Branded launcher with its own `_WelcomePalette` |
| `lib/liquid_aurora_background.dart` | 4 | 0 | 0 | Artwork |
| `lib/manuscript_export.dart` | 0 | 4 | 9 | PDF document colours, not app chrome |
| `lib/impact_trace.dart` | **1** | 0 | 0 | **Actual bypass** — see below |
| `lib/release_destinations.dart` | 0 | 1 | 27 | Black `boxShadow`; no `shadow` role exists |
| `lib/continuity.dart` | **0** | **0** | 11 | **Fully migrated** |
| `lib/backup_health.dart` | **0** | **0** | 5 | **Fully migrated** |
| `lib/visual_planning.dart` | **0** | **0** | 7 | **Fully migrated** |
| all other Studio files | 0 | 0 | 2–5 | `TextStyle` built from `Theme.of(context)` |

### `lib/main.dart` breakdown

| Count | Region | Classification |
|---|---|---|
| 14 | `AppThemePreset` / `AppThemeAccent` tables | Legacy, preserved (§6) |
| 50 | `ProfileSetupScreen`, `_BrandPanel`, `_FeatureChip` | Startup artwork over the aurora — out of scope by instruction |
| 1 | `_AppMark` white logo plate | Backing plate for a brand asset |
| **0** | **Studio views** | **Nothing left** |

### The `TextStyle(` column is not a bypass count

127 occurrences repo-wide, but nearly all are
`Theme.of(context).textTheme.…?.copyWith(…)` — the idiomatic way to consume the
theme while varying weight or size. Only a `TextStyle` that names a colour or
family literal bypasses the engine, and outside the exceptions above there are
none.

### Remaining actual bypass

**`lib/impact_trace.dart:168`** — one decorative panel icon at `0xFFC59B6D`.
Not a status (the Impact Trace panel is not a warning), so migrating it means
choosing between `primary` — which would change it from amber to the theme
accent — and a ramp slot. Either is a visible change to a Studio outside this
phase's three named areas, so it is reported rather than migrated.

---

## 8. Remaining owner decisions

1. **Light-theme status contrast** (§1). `success`/`warning`/`error` sit at
   2.3–2.9 : 1 on the light surface — pre-existing, but below AA. Giving the
   light palette darker variants is a one-line change per role and a visible
   change.
2. **A muted text tone** (§4). If AuthorOS wants de-emphasised secondary text,
   add `onSurfaceMuted` as a *new* role rather than redefining
   `onSurfaceVariant`, so the existing legibility guarantee and its test stand.
3. **`onError` and `ColorScheme.error`** (§3). Unifying Material's error
   surfaces with the `error` role needs an `onError` companion first.
4. **Delete `AppThemeAccent`** (§6) — proven dead.
5. **Delete `lib/main.authorstudio.backup.dart`** (§6) — proven dead, carried
   over from Phase 3.
6. **JetBrainsMono** (§5) — a font-licensing decision, with the integration
   point already prepared.
7. **`lib/impact_trace.dart:168`** (§7) — pick a role for one accent icon.

---

## 9. Verification

Toolchain: Flutter 3.44.9 / Dart 3.12.2, provisioned outside the repository.

| Gate | Phase 3 baseline | Phase 3.1 |
|---|---|---|
| `flutter test` | 496 passed, 0 failed | **526 passed, 0 failed** (+30) |
| `flutter analyze` | 53 issues, 0 errors | **53 issues, 0 errors** — unchanged |
| `flutter build web --release` | succeeded | **succeeded** |
| `git diff --check` | clean | **clean** |

No test was deleted, skipped, weakened, or rewritten to obtain green results.
The `onSurfaceVariant` equality assertion — the one test a lazier migration
would have removed — is untouched and still passing.

### New tests — `test/theme_semantic_colors_test.dart` (30)

| Group | Tests | Covers |
|---|---|---|
| status roles | 5 | resolve in both themes; opaque and mutually distinct; values preserve the replaced literals; reach `ThemeData`; survive all three accessibility combinations unchanged |
| categorical ramp | 4 | all 8 slots defined and opaque in both palettes; all 8 mutually distinct; a missing slot fails validation; ramp reaches `ThemeData` in slot order |
| SceneStatus | 3 | every status has a slot; each of 5 reads its slot from the active theme via unique sentinels; bare-host fallback |
| link categories | 8 | all 8 link types render their ramp slot, asserted on the real rendered timeline bar |
| migrated widgets | 4 | continuity chip and clear-state line read `success` from a sentinel theme; migrated files hold no status/category literal; migrated files reach colour through the engine |
| code typography | 2 | the draft editor names no family literal; the code role carries a resolvable family and fallbacks |
| one colour system | 4 | exactly one `ThemeExtension`; nothing outside `lib/theme/` mints semantic colours; fallback equals the registry; the domain enum is unchanged |

Sentinel colours (`0xFF010101`, `0xFF111111`, …) are used deliberately: a widget
still holding its original literal cannot accidentally match a sentinel, so
these tests fail if a migration is reverted.

---

## 10. Change inventory

**Created (2)**
- `docs/theme-engine-phase-3-1-implementation-map.md`
- `test/theme_semantic_colors_test.dart`

**Modified (9)**
- `lib/theme/theme_tokens.dart` — 3 status roles, `ThemeCategoryRef`
- `lib/theme/theme_definition.dart` — `ThemePalette.categories`, accessors, validation
- `lib/theme/theme_registry.dart` — status + ramp values for both palettes
- `lib/theme/theme_resolver.dart` — explicit accessibility policy for the new families
- `lib/theme/resolved_theme.dart` — `category()` accessor
- `lib/theme/flutter/authoros_theme.dart` — `AuthorOsSemanticColors` extension
- `lib/continuity.dart` — 19 literals → roles and ramp
- `lib/backup_health.dart` — 6 literals → `success` / `error`
- `lib/visual_planning.dart` — 5 literals → ramp
- `lib/main.dart` — 2 named colours → `success` / `warning`; `_semantic()` helper

**Deleted (0)** — including both symbols proven dead, per instruction.

**Scope held**: no Map Studio, no Community, no unrelated Studio migrated, no UI
redesign, no engine rebuild, no second `ThemeData`, no second persistence layer.
