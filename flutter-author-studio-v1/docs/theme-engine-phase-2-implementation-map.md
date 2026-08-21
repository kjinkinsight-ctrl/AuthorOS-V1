# Theme Engine Phase 2 — Application Shell Integration — Implementation Map

Audited: August 20, 2026
Status: **BLOCKED — Phase 1 does not exist. No integration code written.**

## Executive summary

Phase 2 directs the integration of "the completed Theme Engine Phase 1" into the
application shell. **Theme Engine Phase 1 does not exist.** It has never existed
in this repository, on any branch, in any commit.

Phase 2 cannot migrate the shell onto an architecture that was never built.

What this document *does* deliver is the audit Phase 2's SETUP section requires
(items 2, 3, 4, 5, 9): a complete inventory of the current theme implementation,
every `ThemeData` construction path, the persistence contract, and the concrete
defects found. That inventory is the required input for whoever builds Phase 1,
and it is reusable unchanged.

## Finding 1 — Phase 1 does not exist

Every symbol named by the Phase 1 and Phase 2 directives was searched across
`lib/` and `test/`:

| Symbol | Files |
|---|---|
| `ThemeEngine` | 0 |
| `ThemeRegistry` | 0 |
| `ThemeResolver` | 0 |
| `ThemePersistence` | 0 |
| `ResolvedTheme` | 0 |
| `StudioId` | 0 |
| `ThemeColorRef` | 0 |
| `AuthorOsTheme` / `AuthorOSTheme` | 0 |
| `StudioThemeScope` | 0 |
| `ThemeFlutter` (adapter) | 0 |
| `ThemeMode` | 0 |
| `ComponentTokens` / `SemanticTokens` / `ThemeTokens` | 0 |

There is no `theme/` directory in `lib/` or `test/`. The only file in the
repository with "theme" in its name is `test/settings_theme_test.dart`.

### History-wide verification

This was confirmed beyond the working tree:

- **All branch tips** — `git grep` for `class ThemeEngine`, `class ResolvedTheme`,
  and `StudioThemeScope` across every local and remote branch (`main`,
  `feat/world-workspace`, `kjinkinsight-ctrl-refactored-pancake`, 11 `origin/*`
  branches including 6 `copilot/*`, and 4 `authoros-v1/*`): **zero matches**.
- **All history** — every file ever *added* on any branch matching `theme`:
  only `css/themes.css` (legacy web app, since deleted),
  `test/settings_theme_test.dart`, and its pre-move path.
- **Stashes** — none.
- **Worktrees** — two, both scanned via their branches.
- **Sibling project** — `indiauthors-platform` contains no Theme Engine symbols.

The Theme Engine was never written. This is not a rename, a move, or an
uncommitted change.

## Finding 2 — The current theme path (the "old path")

There is already exactly **one** `ThemeData` resolution path in the live
application. It is not an engine, but it is not duplicated either.

```
SharedPreferences ('author_studio.theme_id', 'author_studio.accent_id')
      ↓
_MyAppState._loadTheme  →  _themeId, _accentId
      ↓
AppThemePreset.byId(_themeId)  +  AppThemeSelection.resolvedAccentColor
      ↓
_buildThemeData()                             [lib/main.dart:242]
      ↓
ThemeData
      ↓
MaterialApp(theme: …)                         [lib/main.dart:351, 363]
```

### Components

| Component | Location | Role |
|---|---|---|
| `AppThemePreset` | `lib/main.dart:31` | Two presets (`light`, `dark`); holds `Brightness` + 3 `Color`s; `normalizeId()` maps 8 legacy ids |
| `AppThemeSelection` | `lib/main.dart:117` | Pairs `themeId` + `accentId`; exposes `resolvedAccentColor` |
| `_buildThemeData()` | `lib/main.dart:242` | **The single ThemeData construction site** |
| `_updateThemeSelection()` | `lib/main.dart:228` | Applies a new selection and persists it |
| `_handleThemeChanged()` | `lib/main.dart:236` | Settings callback into the above |
| Persistence keys | `lib/main.dart:193-194` | `author_studio.theme_id`, `author_studio.accent_id` |

### What `_buildThemeData()` produces

`ColorScheme.fromSeed(seedColor: accent, brightness: preset.brightness,
surface: preset.surfaceColor)`, then `.copyWith` overrides for `onSurface`,
`onSurfaceVariant`, `outline`, `outlineVariant`. It then themes: `appBarTheme`,
`cardTheme`, `dividerTheme`, `chipTheme`, `filledButtonTheme`,
`inputDecorationTheme`, and `textTheme`.

Radii are inline literals: cards 20, chips 12, buttons 14, inputs 14.

## Finding 3 — Capability gaps in the current shell

Three Phase 2 requirements have **no existing behaviour to migrate**. They would
be new features, not integrations:

| Requirement | Current state |
|---|---|
| **Req 9 — system mode** | **Does not exist.** `MaterialApp` is given only `theme:`. There is no `darkTheme:` and no `themeMode:`. Dark mode works by rebuilding `theme` from the selected preset, so the shell never consults host brightness. |
| **Req 8 — accessibility** | **Does not exist.** No reduced intensity, no high contrast, no focus-ring token, no selection/highlight token anywhere in the shell. |
| **Req 5 — studio theme scope** | **Does not exist.** No scope mechanism; Studios read `Theme.of(context)` directly. |

Two requirements are **already satisfied**:

| Requirement | Current state |
|---|---|
| **Req 10 — hot theme resolution** | **Already works.** `_handleThemeChanged` → `_updateThemeSelection` → `setState` rebuilds `MaterialApp` with new `ThemeData`. No stream architecture needed, and none should be added. |
| **Req 1 — single resolution path** | **Substantially true already.** `_buildThemeData()` is the only `ThemeData` construction site reachable from the live app. |

## Finding 4 — Inter is not registered as a font family

Requirement 7 states: *"The registered Inter family must actually be used by the
Theme Engine's UI typography."* **Inter is not a registered family.**

In `pubspec.yaml`, only Merriweather is declared under `fonts:`:

```yaml
  fonts:
    - family: Merriweather
      fonts:
        - asset: assets/fonts/Merriweather-400.ttf
          weight: 400
        - asset: assets/fonts/Merriweather-700.ttf
          weight: 700
  assets:
    - assets/fonts/Inter-400.ttf     # bundled as a raw asset only
    - assets/fonts/Inter-700.ttf     # not declared as a family
```

Both Inter TTFs exist on disk (`assets/fonts/Inter-400.ttf`, 324,820 bytes;
`Inter-700.ttf`, 326,468 bytes) and are bundled — but because they are listed
under `assets:` rather than `fonts:`, **Flutter cannot resolve `fontFamily:
'Inter'`**. Any such reference silently falls back to the default font.

The shell currently hard-codes `fontFamily: 'Merriweather'` in two places
(`lib/main.dart:267` in `textTheme.apply`, and `:274` in `ThemeData`), and
`test/settings_theme_test.dart:55` asserts `bodyMedium?.fontFamily ==
'Merriweather'`.

**This is a real defect and it is independent of the Theme Engine.** Fixing it
is a ~6-line `pubspec.yaml` change. It was not applied here because this phase
is blocked and the change was not sanctioned in isolation. It should be done as
a prerequisite to any Phase 1 typography contract.

## Finding 5 — A dead second theme already exists

`lib/main.authorstudio.backup.dart` is **not imported by anything** — verified
by grep across `lib/` and `test/`. It nonetheless contains:

- a second `main()` entry point,
- a second `MaterialApp`,
- a second complete `ThemeData` with its own `ColorScheme.fromSeed`,
- 19 hard-coded `Color(0x…)` literals (`0xFFC59B6D`, `0xFF161A22`, `0xFF0F1115`, …).

This is precisely the "second theme system" Requirement 13 exists to prevent,
and it predates this phase. It is dead code and should be deleted — but that is
a cleanup decision for the repository owner, not a Phase 2 action, so it was
left in place.

## Finding 6 — Requirement 13 inventory (hard-coded values)

Requirement 13 asks for a survey of remaining theme constants. Performed:

| File | `Color(0x…)` count | Assessment |
|---|---|---|
| `lib/main.dart` | 21 | 8 inside `_buildThemeData()` (foreground/outline/surface-container) — these are the shell's real palette and belong in a token vocabulary. The rest are scattered UI accents. |
| `lib/main.authorstudio.backup.dart` | 19 | **Dead code** — see Finding 5 |
| `lib/continuity.dart` | 19 | Status/severity colours — likely semantic, needs per-value review |
| `lib/welcome_page.dart` | 11 | Marketing surface — plausibly intentional |
| `lib/backup_health.dart` | 6 | Status colours — likely semantic |
| `lib/visual_planning.dart` | 5 | Canvas/board colours — likely intentional |
| `lib/impact_trace.dart` | 1 | Single accent |
| **Total in `lib/`** | **89** | |

`AppThemePreset` is referenced **only** in `lib/main.dart` and
`test/settings_theme_test.dart` — it has not leaked into Studios. A future
migration is therefore well contained.

## Finding 7 — Existing test contract to preserve

`test/settings_theme_test.dart` encodes behaviour any future migration must keep:

1. Exactly two presets, ids `['light', 'dark']`, with matching `Brightness`.
2. **Legacy id migration** — `paper` → `light`, `slate` → `light`,
   `obsidian` → `dark`, `midnight` → `dark`. (`normalizeId()` also maps
   `forest`, `burgundy`, `plum`, `ocean` → `dark`.)
3. Body text uses `fontFamily == 'Merriweather'`.
4. Contrast assertions on `onSurfaceVariant` vs `onSurface` and `onSurface` vs
   `surface`, for both themes.

Requirement 4's "legacy presets continue to resolve correctly" is already
implemented and already tested — by `normalizeId()`, not by a `ThemePersistence`
migration.

## Requirement-by-requirement feasibility

| Req | Subject | Status |
|---|---|---|
| 1 | Single theme source | **Blocked** — no `ThemeEngine`; one path already exists |
| 2 | Application theme | **Blocked** — no `AuthorOsTheme`; system mode absent |
| 3 | Remove duplicate theme logic | **Blocked** — nothing to migrate *to* |
| 4 | Settings compatibility | **Already works** via `normalizeId()`; no `ThemePersistence` to migrate through |
| 5 | Studio theme scope | **Blocked** — no `StudioThemeScope` |
| 6 | Component tokens | **Blocked** — no token vocabulary exists |
| 7 | Typography | **Blocked, and premise false** — Inter is not registered (Finding 4) |
| 8 | Accessibility | **Blocked** — no transformations exist anywhere |
| 9 | System mode | **Blocked** — shell has no `themeMode`/`darkTheme` |
| 10 | Hot theme resolution | **Already satisfied** |
| 11 | Tests | **Blocked** — 11 of 19 cases reference absent systems |
| 12 | Regression protection | **Honoured** — nothing modified |
| 13 | No new theme system | **Audited** — see Finding 6; one dead duplicate found |
| 14 | Documentation | **This document** |
| 15 | Verification | **Baseline captured** |

## Verification baseline (unchanged tree)

| Check | Result |
|---|---|
| `flutter test` | **387 tests, all passed** |
| `flutter analyze` | **53 issues: 0 errors**, 9 warnings, 44 infos |
| `flutter build web --release` | **Succeeded** |
| `flutter build linux --release` | **Not applicable** — Windows 11 host, no Linux toolchain |

No source file was modified, so these results are unchanged from the previous
audit and no regression is possible.

## Deferred

Deferred by the directive and confirmed absent: Theme Engine Phase 3, Studio
redesign, Map Studio, Expansion Packs, Community features.

**Additionally deferred, as a prerequisite rather than a successor:** Theme
Engine Phase 1 — `ThemeRegistry`, `ThemeResolver`, `ThemePersistence`,
`ThemeEngine`, `ResolvedTheme`, `StudioId`, `ThemeColorRef`, and the Flutter
adapter. Phase 2 cannot precede Phase 1.

## Recommended prerequisite work

Independent of the Theme Engine, and safe to do now:

1. **Register Inter as a font family** in `pubspec.yaml` (~6 lines). Currently
   bundled but unresolvable. Inert until referenced, so it breaks nothing.
2. **Delete `lib/main.authorstudio.backup.dart`** — dead code carrying a second
   `main()`, `MaterialApp`, and `ThemeData`.

Then Theme Engine Phase 1, with this document's Findings 2, 3, 6, and 7 as its
input: Finding 2 is the path to replace, Finding 3 is the gap list, Finding 6 is
the migration surface, Finding 7 is the behavioural contract to preserve.

## Known limitations

1. Phase 1 does not exist; Phase 2 is unexecutable as written.
2. Requirement 7's premise is factually incorrect — Inter is not registered.
3. Requirements 8, 9, and 5 describe new features, not migrations.
4. Linux build unverifiable on this Windows host.
5. This document is an audit, not an implementation.
