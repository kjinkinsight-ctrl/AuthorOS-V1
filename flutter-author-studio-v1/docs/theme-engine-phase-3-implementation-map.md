# Theme Engine Phase 3 — Application-Wide Theme Consumption — Implementation Map

Audited and implemented: August 21, 2026
Status: **Delivered, with three documented stop conditions.**

## Executive summary

Phase 3 was briefed as pure consumption work on the premise that "the Theme
Engine already exists and is wired into MaterialApp." **Half of that premise
was false.** The engine existed; it was not wired into anything.

`lib/main.dart` still ran its own `_buildThemeData()` — the pre-engine shell
described by the Phase 2 audit. The engine under `lib/theme/` was complete and
well tested but **inert at runtime**, exactly as the Phase 1 map's first known
limitation says: *"The engine is not yet wired into the app… it is fully tested
but inert at runtime until Phase 2."* Phase 2 was never done.

So the application contained **two live-capable ThemeData architectures** plus a
third dead one. Consolidating them is precisely this phase's stated success
condition (ONE ThemeData boundary, ZERO duplicate theme infrastructure), so the
shell migration was completed here rather than deferred. Everything else in the
brief — Studio scopes, the styling audit, Settings, accessibility, legacy
compatibility, tests — was then done on top of it.

The application now converges on the target architecture:

```
ThemeSettingsStore → ThemePersistence → ThemeSelection → ThemeEngine
    → ThemeRegistry → ThemeResolver → ResolvedTheme → AuthorOsTheme
    → ThemeData → MaterialApp → StudioThemeScope → Studios
```

---

## 1. Premise corrections

Three things in the brief did not match the repository. They are recorded here
because they change what "done" means for this phase.

| Brief says | Repository reality |
|---|---|
| "The Theme Engine … is wired into MaterialApp." | It was not. `lib/main.dart:243 _buildThemeData()` built `ThemeData` from `AppThemePreset`; `AuthorOsTheme.toThemeData` was never called by the app. |
| "Startup Experience is now visually verified and complete." | **None of the named startup files exist on this branch or on `origin/main`** — no `login_select_user_page.dart`, `create_profile_page.dart`, `startup_backdrop.dart`, `author_profile_store.dart`, `startup_authentication.dart`, `startup_flow_test.dart`, `startup_screens_capture.dart`, `assets/startup-doorway.png`. The startup surface that *does* exist is `ProfileSetupScreen` in `lib/main.dart` over `LiquidAuroraBackground`. It was treated as protected. |
| "Read `docs/authoros-repository-reality-audit.md`." | That document does not exist. `docs/theme-engine-phase-1-implementation-map.md` and `…-phase-2-…` do, and were read. |

The Phase 2 map is also stale: it was written before Phase 1 landed and still
opens with "BLOCKED — Phase 1 does not exist." Its *audit* content (the
`_buildThemeData` inventory, the persistence contract, the hard-coded value
survey) remained accurate and was reused.

Nothing was changed on the basis of these corrections beyond doing the shell
migration; no startup composition was altered.

---

## 2. What was actually implemented

### 2.1 The shell now consumes the engine

`lib/main.dart` — `_AuthorStudioAppState`:

| Removed | Replaced by |
|---|---|
| `_buildThemeData()` (69 lines, the second `ThemeData` site) | `AuthorOsTheme.toThemeData(ResolvedTheme)` |
| `_themeId` / `_accentId` fields | one `ThemeSelection` |
| `_loadThemeSelection()` reading `SharedPreferences` and rewriting legacy ids | `ThemeEngine.standard(store: SharedPreferencesThemeStore)` + `engine.load()` |
| `_saveThemeSelection()` writing `author_studio.theme_id` / `.accent_id` | `ThemeEngine.select()` → `ThemePersistence.save()` |
| `_updateThemeSelection()` | folded into `_handleThemeChanged` |
| `ColorScheme.fromSeed(...)` in the shell | lives only in the adapter |

`MaterialApp` is now given `theme:`, `darkTheme:` **and** `themeMode:`. That is
new capability the Phase 2 audit listed as absent (Req 9): the shell previously
had no `darkTheme` and no `themeMode`, so `system` could not work at all.

### 2.2 System mode

`AuthorOsThemeMode` stays the domain type. Flutter's `ThemeMode` appears in
exactly one expression, `_flutterThemeMode`, at the `MaterialApp` boundary.

Both built-in themes render exactly one brightness each (Phase 1 known
limitation 3). So `_resolveFor(brightness)` applies a shell-level policy: use
the selected theme when it can render that brightness, otherwise the registry's
theme for that brightness. That is what makes `system` meaningful without
touching the engine or inventing a dual-brightness palette.

`system` is fully wired and tested end to end. **No settings UI was added for
it** — §10 explicitly rules out a settings project here, so the mode is
reachable by persisted value only.

### 2.3 Studio scope

`StudioThemeScope` is installed twice:

1. **Shell scope** — in `MaterialApp.builder`, above every route, carrying the
   `ResolvedTheme` matching the brightness Flutter actually selected.
2. **Studio scope** — in `_SectionView.build`, carrying `section.studioId`.

A new total mapping `StudioSectionData.studioId` assigns every one of the 15
sections a `StudioId`. Sections that are shell chrome resolve `StudioId.shell`.
`chapters` shares `StudioId.manuscript` because chapter structure is part of the
manuscript surface. A test asserts the mapping is total, so adding a section
without deciding its theme identity fails the build.

The Studio scope is **additive**: `_SectionView` uses `maybeOf`, so a host that
embeds `AuthorStudioShell` in a bare `MaterialApp` still renders. This keeps the
existing embedding contract (used by `settings_theme_test.dart` and
`widget_test.dart`) intact rather than rewriting those tests.

### 2.4 Settings

**Settings needed no restructuring.** `SettingsStudioView` already delegates
upward through `onThemeChanged(themeId, accentId)` and styles itself entirely
from `Theme.of(context)`. It never touched theme preference keys.

The UI-level persistence was in `lib/main.dart`, and that is what moved onto
`ThemeEngine`. There is now **no theme preference key anywhere outside
`lib/theme/`** — enforced by a source-level test.

The accent picker remains retired: the shell pins `accentId` to `'default'` on
load and on every change, reproducing pre-engine behaviour exactly.

---

## 3. Full application styling audit

Search performed across `lib/` for `ThemeData(`, `Color(`, `Colors.`,
`ColorScheme(`, `TextStyle(`, `fontFamily:`, `backgroundColor:`,
`foregroundColor:`, `border:`, `shadow:`, `primary:`, and `0xFF`.

Occurrences were classified before any replacement. `Colors.transparent` is
excluded throughout — it is structural, not a colour choice.

| Area | Hard-coded styling found | Existing Theme source | Migration |
|---|---|---|---|
| Dashboard | none | `Theme.of(context).colorScheme` | none needed — already compliant |
| Sidebar (`_DesktopNavigation`, `_NavigationTile`) | none | `colorScheme.primaryContainer` / `onSurface` | none needed |
| Toolbar (`_TopBar`, `_HeaderActionButton`) | none | `theme.scaffoldBackgroundColor`, `surfaceContainerHighest`, `outlineVariant` | none needed |
| Cards | none | `cardTheme` from `metrics.radius('card')` | none needed |
| Manuscript | 1 × `Colors.white70`; 2 × `fontFamily: 'monospace'` | `bodyLarge` + literals | **3 migrated** → `onSurfaceVariant`; draft face → `ThemeTextRole.code` via `StudioThemeScope` |
| Chapters | none | `Theme.of(context)` | none needed |
| Characters | none | `Theme.of(context)` | none needed |
| World | none (1 × `Colors.transparent`) | `scheme.secondaryContainer` | none needed |
| Plot (`visual_planning.dart`) | 5 × `SceneStatus` colours | none | **blocked** — domain status ramp, see §4 |
| Timeline (`_TimelineStudioView`) | 1 × `Colors.white70` | `bodyMedium` | **1 migrated** → `onSurfaceVariant` |
| Notes (`_NotesStudioView`) | 4 × `Colors.white70`, 1 × `Color(0xFFC59B6D)` | `bodyMedium` / `bodyLarge` | **5 migrated** → `onSurfaceVariant`; pin icon → `colorScheme.primary` |
| Story Codex | none (1 × `Colors.transparent`) | `Theme.of(context)` | none needed |
| Search | none | `Theme.of(context)` | none needed |
| Statistics | none | `Theme.of(context)` | none needed |
| Settings (`release_destinations.dart`) | 1 × `Colors.white60`; 1 × black `boxShadow` | `labelLarge`, `colorScheme.primary` | **1 migrated** → `onSurfaceVariant`; shadow left (§5) |
| Dialogs | none | `Theme.of(context)` | none needed |
| Forms | none | `inputDecorationTheme` from the engine | none needed |
| Projects (`_ProjectsStudioView`) | 8 × `Colors.white*`, 1 × white chip fill, 2 × green/orange | `bodyMedium` / `bodySmall` | **9 migrated** → `onSurfaceVariant` + `surfaceContainerHighest`; 2 status colours **blocked**, see §4 |
| Continuity | 19 × status/category literals | none | **blocked** — see §4 |
| Backup health | 6 × status literals | none | **blocked** — see §4 |
| Welcome / launcher | 11 × `_WelcomePalette`, 6 × `fontFamily: 'Merriweather'` | dedicated brand palette | **intentional** — see §5 |
| Startup (`ProfileSetupScreen`) | 50 × white-on-dark over aurora art | intentional | **preserved** per §13 of the brief |

**19 genuine bypasses were migrated across 3 files. Nothing was blind-replaced.**

The 13 secondary-text sites go through a named helper, `_mutedOn(context)` in
`lib/main.dart`, rather than inlining `colorScheme.onSurfaceVariant` at each
call. Naming the role keeps the intent readable and means every one of them
de-emphasises automatically if the palette ever gives `onSurfaceVariant` its
own value (§4.4).

### Before / after

| Metric | Before | After |
|---|---|---|
| Live `ThemeData` construction sites | 2 (`main.dart`, adapter — only `main.dart` reachable) | **1** (adapter) |
| Dead `ThemeData` construction sites | 1 (`main.authorstudio.backup.dart`) | 1 (quarantined + test-guarded) |
| Theme preference writers outside `lib/theme/` | 1 (`main.dart`) | **0** |
| `Colors.*` / `Color(0x…)` in Studio view code | 23 | **4** (all blocked on missing roles) |
| Sections with a `StudioId` | 0 | **15 / 15** |

---

## 4. Stop conditions — token and asset gaps

Per §5 and §18 of the brief, these were **documented rather than improvised
around**. The core token vocabulary was not expanded.

### 4.1 No `success` / `warning` / `error` colour roles — **BLOCKING**

`ThemeColorRef` defines: `background`, `surface`, `surfaceContainer`,
`primary`, `onPrimary`, `onSurface`, `onSurfaceVariant`, `outline`,
`outlineVariant`, `focusRing`, `selection`, `highlight`.

There is **no status role**. These 27 occurrences therefore cannot be migrated:

| File | Count | Values |
|---|---|---|
| `lib/continuity.dart` | 19 | `0xFF77B884` pass, `0xFFE07A6F` fail, `0xFFC59B6D` warn, plus 5 category colours |
| `lib/backup_health.dart` | 6 | `0xFF77B884` / `0xFFE07A6F` restore-test status |
| `lib/main.dart` (Projects) | 2 | `Colors.green` / `Colors.orange` public-profile badge |

Recommended, **not applied**: add `success`, `warning`, `error` (and their
`on*` pairs) to `ThemeColorRef`, with values for both palettes. That is a core
vocabulary change and needs owner sign-off.

### 4.2 No domain-status ramp — **BLOCKING**

`lib/visual_planning.dart` maps `SceneStatus` onto 5 colours and
`lib/continuity.dart` maps link categories onto 5 more. These are *data
category* ramps, not semantic UI roles. A closed 12-role vocabulary cannot
express them, and inventing per-Studio roles is exactly what §5 forbids.

Recommended: a separate, explicitly-scoped categorical ramp (as
`dataviz`-style ordered categories), not additional `ThemeColorRef` members.

### 4.3 JetBrainsMono is not in the repository — **BLOCKING**

§7 asks that technical/code text use JetBrainsMono. It cannot:

- `assets/fonts/` contains only `Inter-400/700` and `Merriweather-400/700`.
- No JetBrainsMono `.ttf` exists anywhere in the repo.
- Declaring the family without the asset would silently fall back — the exact
  defect Phase 1 fixed for Inter.
- `pubspec.yaml` is owned by the CI agent this milestone (§2).

The `code` role therefore still resolves to the platform `monospace` face with
`Courier New` / `monospace` fallbacks. The manuscript draft editor now consumes
that role instead of a hard-coded `'monospace'` literal, so **adding the font
later is a one-line registry change with no widget edits**.

A test now asserts every family named by the typography contract is either
declared under `fonts:` in `pubspec.yaml` or is a platform-generic family —
generalising the Inter regression guard.

### 4.4 `onSurfaceVariant` carries no de-emphasis — **NON-BLOCKING, needs a decision**

Both palettes define `onSurfaceVariant` **equal to** `onSurface`, and
`test/settings_theme_test.dart:65` asserts that equality.

Consequence of the migration: the secondary text that was `Colors.white70` now
resolves to `onSurfaceVariant`, which is full-strength. In **light** theme this
is a straight bug fix — white-on-white was invisible. In **dark** theme that
text goes from 70 % white to 100 % white, a small visible change.

The migration still names the *correct role*, so the moment the palette gives
`onSurfaceVariant` its own muted value, every one of these de-emphasises
automatically. Changing the palette now would require weakening an existing
assertion, which §15 forbids. Flagged for owner decision.

### 4.5 Duplicate `ThemeData` architecture — **quarantined**

`lib/main.authorstudio.backup.dart` (838 lines) still carries a second
`main()`, a second `MaterialApp`, a second `ThemeData` and 19 colour literals.

It is imported by nothing. The Phase 2 audit already flagged it and left
deletion as a repository-owner decision; that judgement is unchanged, so it was
**not deleted**. Instead it is quarantined by two tests: one allows it as a
named exemption from the single-`ThemeData` rule, and one asserts it stays
unreachable — if anything ever imports it, the build fails rather than silently
gaining a second theme system.

---

## 5. Intentionally not migrated

| Surface | Why |
|---|---|
| `ProfileSetupScreen`, `_BrandPanel`, `_FeatureChip` (50 literals) | The startup surface. White-on-dark over `LiquidAuroraBackground` night art. §13: preserve. |
| `lib/liquid_aurora_background.dart` (4) | The artwork itself. |
| `lib/welcome_page.dart` (11 + 6 font literals) | Self-contained branded launcher with its own `_WelcomePalette` (gold/cream). Its `TextStyle`s are `const` inside `const` widget trees; theming them would force `const` removal throughout for zero visual gain. A candidate for a future brand-surface token set. |
| `_AppMark` white logo plate | Backing plate for `author-studio-logo.png`, a brand asset. |
| `AppThemePreset` / `AppThemeAccent` / `AppThemeSelection` (14 literals) | §11: preserved. Still exercised by `settings_theme_test.dart`. |
| `release_destinations.dart:3049` black `boxShadow` | No `shadow` role exists (§5 lists one; the vocabulary does not have it). A neutral drop shadow is not a palette decision. |
| `lib/manuscript_export.dart` (4) | PDF document colours, not application chrome. |
| `lib/theme/**` literals | The vocabulary's own definitions — the single place literals belong. |

---

## 6. Studio overrides

**Zero `studioOverrides` were added.**

§6 is explicit: *"Do not create overrides merely because the mechanism exists."*
No Studio currently requires a distinct semantic treatment that the base palette
cannot express, and §12 forbids redesign. Every Studio therefore resolves the
shell palette, which a test asserts explicitly across all six Studio identities
and all twelve colour roles.

The mechanism is installed and proven: when a Studio does need an override, it
is a data change in `ThemeRegistry`, with no widget edits.

---

## 7. Typography

The role contract is unchanged and now verified end to end:

| Role | Family | Reaches |
|---|---|---|
| `ui` | Inter | `titleMedium`, button text |
| `label` | Inter | `labelLarge`, `labelMedium`, chip labels |
| `heading` | Merriweather | `displayLarge/Medium`, `headlineMedium` |
| `body` | Merriweather | `bodyMedium`, `bodySmall`, `ThemeData.fontFamily` |
| `code` | monospace | manuscript draft editor (see §4.3) |

### The `headlineMedium` / `titleMedium` / `labelLarge` discrepancy

Investigated as §7 directs. The mapping in `AuthorOsTheme.toThemeData` is:

- `headlineMedium` ← `heading` role → Merriweather 22/700
- `titleMedium` ← `ui` role → Inter 14, forced to `w600`
- `labelLarge` ← `label` role → Inter 12/600

The pre-engine shell applied `fontFamily: 'Merriweather'` to the *entire* text
theme, so all three were Merriweather. The engine deliberately moves
`titleMedium` and `labelLarge` onto Inter — that is the documented "UI → Inter,
Labels → Inter" contract from §7, and it is what makes Inter's registration
meaningful.

**No change made.** The current values implement the stated role mapping
correctly; the "discrepancy" is the intended Phase 1 behaviour, not a defect.
Regression tests now pin all four assignments.

---

## 8. Accessibility

`ThemeAccessibility` is unchanged — no second subsystem was built. What was
missing was proof that it reaches rendered `ThemeData` **through the app**, and
that is now tested:

| Transformation | Verified reaches |
|---|---|
| `highContrast` | `colorScheme.onSurface` darkens in light theme |
| `reduceIntensity` | `colorScheme.primary` softens while `onSurface` is provably untouched |
| focus treatment | `ThemeData.focusColor` == `focusRing` token; `focusedBorder` width == `metrics.focusRingWidth` |
| selection treatment | `textSelectionTheme.selectionColor` == `selection` token |

Both flags are persisted through `ThemePersistence` and read at launch. They
are **not** yet driven by host accessibility settings — that remains Phase 1
known limitation 4 and is unchanged here.

---

## 9. Legacy compatibility

All eight legacy ids verified twice: at registry level, and end to end by
launching the application with each id persisted.

| Legacy id | Resolves to | Launches |
|---|---|---|
| `paper` | `light` | light |
| `slate` | `light` | light |
| `obsidian` | `dark` | dark |
| `midnight` | `dark` | dark |
| `forest` | `dark` | dark |
| `burgundy` | `dark` | dark |
| `plum` | `dark` | dark |
| `ocean` | `dark` | dark |

Migration is still lazy, idempotent, non-destructive and read-only-safe; a test
confirms the original id lands in `author_studio.theme.legacy_id` and that the
**shell** performs no rewriting of its own.

`AppThemePreset`, `AppThemeAccent` and `AppThemeSelection` are retained
unchanged per §11.

---

## 10. Tests

`test/theme_application_test.dart` — **42 new tests**, none weakened, none
skipped, none deleted.

| Group | Tests | Covers |
|---|---|---|
| one ThemeData boundary | 3 | app `ThemeData` comes from the engine; both brightness slots supplied; palette reaches rendered widgets |
| theme switching | 4 | light→dark, dark→light, system→light host, system→dark host |
| persistence survives restart | 3 | selection round-trips through `SharedPreferences`; dark launches dark; shell writes nothing itself |
| Studio scope | 3 | section→`StudioId` mapping is total; shell scope above every route; no Studio diverges from the shell palette |
| Studio theme consumption | 10 | Dashboard, Manuscript, Chapters, Characters, Story Codex, World, Plot, Timeline, Notes, Settings each resolve the engine `ThemeData` under the right scope |
| typography | 3 | every declared family is resolvable; role→family contract; Inter + Merriweather reach `ThemeData` |
| accessibility | 3 | high contrast, reduced intensity, focus + selection |
| legacy compatibility | 9 | registry mapping + all eight ids launching |
| architecture | 4 | `ThemeData` only in the adapter; quarantined duplicate stays dead; only the engine persists theme settings; shell has no second resolution path |

The Studio consumption tests tolerate **pre-existing** `RenderFlex` overflows in
the Notes filter row (`lib/main.dart:4954`, `:4983` — untouched by this phase).
Any error that is *not* an overflow still fails the test, so nothing else is
hidden.

---

## 11. Verification

Toolchain: **Flutter 3.44.9 / Dart 3.12.2** (satisfies `pubspec.lock`'s
`flutter >=3.44.0`, `dart >=3.12.0`). No Flutter SDK was present in the
environment; one was provisioned outside the repository.

| Check | Before | After |
|---|---|---|
| `flutter test` | 454 passed, 0 failed | **496 passed, 0 failed** (+42) |
| `flutter analyze` | 53 issues, 0 errors | **53 issues, 0 errors** — unchanged |
| `flutter build web --release` | not run | **succeeded** — `✓ Built build/web`, 61.7 s |
| `flutter build windows --release` | not available | **not available** — Linux host; `flutter doctor` reports no Windows toolchain |
| `git diff --check` | clean | **clean** |

No test was deleted, skipped, or loosened. No analyzer suppression was added.

The web build emits one pre-existing warning — *"Expected to find fonts for
(MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found
(MaterialIcons)"*. It concerns `cupertino_icons`, not the Theme Engine's
families, and predates this phase. Fixing it would mean editing `pubspec.yaml`,
which belongs to the CI agent this milestone.

---

## 12. Concurrent-agent safety

Working tree at hand-off:

```
 M flutter-author-studio-v1/lib/main.dart
 M flutter-author-studio-v1/lib/manuscript_studio.dart
 M flutter-author-studio-v1/lib/release_destinations.dart
?? flutter-author-studio-v1/docs/theme-engine-phase-3-implementation-map.md
?? flutter-author-studio-v1/test/theme_application_test.dart
```

**All five are this phase's work.** No concurrent agent changes were detected —
the branch was identical to `origin/main` at start.

Untouched, as required by §2 and §17: `.github/`, workflow files,
`pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `tool/`, `tools/`,
`linux/`, `windows/`, `macos/`, `android/`, `ios/`, `web/`, `dist/`,
`supabase/`.

`flutter pub get` was run and left `pubspec.lock` byte-identical.

Running the toolchain *did* regenerate four platform files as a side effect —
`linux/flutter/generated_plugin_registrant.cc`,
`linux/flutter/generated_plugins.cmake`,
`windows/flutter/generated_plugin_registrant.cc`,
`windows/flutter/generated_plugins.cmake` — dropping the
`isar_community_flutter_libs` registration. That is a toolchain artefact
unrelated to theming, and §16 forbids altering platform-generated files.
**All four were reverted**; the working tree contains no platform changes.

Startup code was read but not modified. `ProfileSetupScreen`,
`LiquidAuroraBackground` and the profile bootstrap are unchanged; the new tests
sign in through the existing profile gate rather than bypassing or altering it.

---

## 13. Known limitations

1. **Three token gaps block 27 + 10 literals** — status roles, a categorical
   ramp, and the JetBrainsMono asset (§4.1–4.3).
2. **`onSurfaceVariant` has no de-emphasis**, so migrated secondary text is
   slightly stronger in dark theme (§4.4).
3. **`system` mode has no settings UI.** Wired and tested, reachable only by
   persisted value — §10 ruled a settings project out of scope.
4. **Accessibility flags are not driven by host settings**, unchanged from
   Phase 1.
5. **A second `ThemeData` survives in dead code**, quarantined by test (§4.5).
6. **Pre-existing Notes layout overflow** at `lib/main.dart:4954`, `:4983`.
   Out of scope; recorded here because the tests must tolerate it.
7. **Windows build unverified** — Linux host.
8. **The Studio scope is additive**, so a host embedding `AuthorStudioShell`
   outside `AuthorStudioApp` gets shell theming without Studio overrides. The
   live app always installs both scopes.

---

## 14. Architectural decisions

1. **Completed the missing Phase 2 rather than reporting blocked.** The stated
   success condition *is* one `ThemeData` boundary; leaving two would have
   failed the milestone by definition.
2. **Kept `theme:` + `darkTheme:` + `themeMode:` instead of rebuilding one
   `ThemeData`.** Flutter's own mechanism handles host brightness; the domain
   type stays `AuthorOsThemeMode`.
3. **Put the "which theme renders this brightness" policy in the shell, not the
   engine.** It is a product policy about a two-theme registry, not a
   resolution rule, and the brief forbids rebuilding the engine.
4. **Made the Studio scope additive.** Preserves the existing embedding
   contract; avoided rewriting three passing tests to satisfy a new hard
   requirement.
5. **Migrated to `Theme.of(context).colorScheme`, not to `StudioThemeScope`,
   for ordinary colours.** `ThemeData` now comes solely from the engine, so
   `Theme.of` *is* engine consumption — and it is idiomatic, `const`-friendly,
   and needs no scope. The scope is used where `ThemeData` cannot reach: the
   `code` typography role.
6. **Added zero `studioOverrides`.** The mechanism is proven by test; inventing
   overrides would be the redesign §12 forbids.
7. **Quarantined rather than deleted the dead duplicate.** Deletion is an owner
   decision; a test now prevents it from coming back to life.

---

## 15. Recommended next phase

In priority order:

1. **Status token decision** (§4.1) — unblocks 27 literals across Continuity,
   Backup Health and Projects. Smallest change, largest coverage gain.
2. **`onSurfaceVariant` palette decision** (§4.4) — requires updating the
   `settings_theme_test` equality assertion deliberately, with visual sign-off.
3. **JetBrainsMono asset** (§4.3) — add the font files, declare the family,
   point `ThemeTextRole.code` at it. No widget changes needed.
4. **Categorical ramp design** (§4.2) — for `SceneStatus` and link categories.
5. **Delete `lib/main.authorstudio.backup.dart`** (§4.5) — owner decision.
6. **Host-driven accessibility** — read platform high-contrast / reduced-motion
   into `ThemeAccessibility`.
7. **Brand-surface tokens** — for `welcome_page.dart` and the startup surface,
   if they should ever follow a theme.

Explicitly **not** started, per §19: Map Studio, Community, Progression, AI,
new database architecture, new authentication backend.
