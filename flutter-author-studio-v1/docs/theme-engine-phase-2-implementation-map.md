# Theme Engine Phase 2 — Application Shell Integration — Implementation Map

Status: **complete**. `ThemeEngine` is the live application theme source.

Phase 1 built the engine under `lib/theme/` but deliberately left `main.dart`
untouched, so the engine existed without driving anything. Phase 2 connects it:
the shell now resolves through the engine and hands the result to `MaterialApp`,
and the pre-engine construction path is gone from the runtime.

This is an integration, not a redesign. No Studio, Dashboard, Progression,
Analytics, Community, or Universal Records behaviour was changed, and no new
theme was added.

---

## 1. Architecture

### Old runtime theme path

```
SharedPreferences ('author_studio.theme_id')
  → AppThemePreset.normalizeId / AppThemePreset.byId
  → _AuthorStudioAppState._buildThemeData()      ← palette, typography,
  → MaterialApp.theme                              metrics, brightness all
                                                   derived inline in the shell
```

Everything lived in `_AuthorStudioAppState`: the light/dark literals, the
`ColorScheme.fromSeed` call, the Merriweather assignment, the radii (20/12/14),
and the padding. There was no mode concept — the theme id *was* the brightness —
no accessibility, and no Studio scoping.

### New runtime theme path

```
SharedPreferences
  → SharedPreferencesThemeStore        (ThemeSettingsStore, Flutter adapter)
  → ThemePersistence                   (reads + migrates legacy ids)
  → ThemeSelection                     (themeId, mode, accessibility, accentId)
  → ThemeEngine.resolveSelection(hostBrightness:)
  → ThemeRegistry → ThemeResolver      (mode rule, fallback rule, a11y transforms)
  → ResolvedTheme                      (authoritative: one brightness, one palette)
  → AuthorOsTheme.toThemeData          (the only ThemeData builder)
  → MaterialApp.theme / .darkTheme
```

The shell no longer derives palette, typography, metrics, accessibility,
brightness, or fallback. It supplies two inputs — the persisted selection and
the host environment — and consumes one output.

---

## 2. MaterialApp integration

`_AuthorStudioAppState.build` is now the single resolution point:

```dart
_hostBrightness = AuthorOsTheme.themeBrightness(
  MediaQuery.maybePlatformBrightnessOf(context) ??
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
);
final resolved  = _engine.resolveSelection(selection: …, hostBrightness: _hostBrightness);
final themeData = AuthorOsTheme.toThemeData(resolved);
```

`resolveSelection` is pure, so building is safe to repeat and there is no cached
theme to invalidate.

**Why `theme` and `darkTheme` hold the same value.** The engine has already
applied the mode and the fallback rule before `MaterialApp` is constructed, so
both slots carry the identical resolved `ThemeData`. Whichever branch Flutter
takes for `themeMode`, it renders what the engine decided — Flutter cannot
re-derive a brightness the engine did not choose. `themeMode` is still set from
the selection so the widget tree reports the user's actual choice.

**Loading.** `SharedPreferences` resolves asynchronously. Until it does, the
engine runs over an empty `MemoryThemeSettingsStore` and resolves the registry
default (light) — the same default the old shell used while loading, but now
produced by the engine rather than by a hand-built `ThemeData`. When preferences
arrive, the engine is rebuilt over `SharedPreferencesThemeStore` and the
persisted selection replaces the default. This is a placeholder store, not a
second settings store: it is `ThemeSettingsStore`, and it is discarded.

---

## 3. State update mechanism

Unchanged in shape, as required: `_handleThemeChanged` → `setState` → rebuild →
re-resolve. **No stream was introduced.** The engine is a plain object the
`State` owns; a rebuild re-runs a pure resolution.

```dart
Future<void> _handleThemeChanged(String themeId, String accentId) async {
  final next = current.copyWith(
    themeId: themeId,
    mode: engine.registry.naturalMode(themeId),
    accentId: accentId,
  );
  setState(() => _selection = next);
  await engine.select(selection: next, hostBrightness: _hostBrightness);
}
```

`engine.select` persists through `ThemePersistence`. Its returned `ResolvedTheme`
is intentionally discarded: `build` re-resolves against the live host brightness,
keeping exactly one resolution point.

**Natural mode.** The settings UI offers theme *ids* ("Light"/"Dark"), not modes.
Selecting a theme therefore also fixes an explicit mode, via
`ThemeRegistry.naturalMode` — a dark-only theme is naturally a dark selection.
That rule already existed inside `ThemePersistence._readMode` for reading
pre-engine installs; Phase 2 promoted it to `ThemeRegistry.naturalMode` and made
`ThemePersistence` call it, so the shell reuses the rule rather than restating
it. Without this, picking "Dark" while the stored mode was `light` would render
correctly only via the fallback path, and `fallbackApplied` would be permanently
true — technically right, semantically misleading.

---

## 4. Light / dark / system

| Selection | Host | Result | `fallbackApplied` |
|---|---|---|---|
| theme `light`, mode `light` | any | light | false |
| theme `dark`, mode `dark` | any | dark | false |
| theme `dark`, mode `system` | dark | dark | false |
| theme `light`, mode `system` | light | light | false |
| theme `light`, mode `system` | dark | **light** (fallback) | true |
| theme `dark`, mode `light` | any | **dark** (fallback) | true |

The host brightness is read with `MediaQuery.maybePlatformBrightnessOf`, which
establishes a dependency: when the OS switches appearance the shell rebuilds and
re-resolves with no restart. This is covered by a test.

Both built-in themes define exactly one palette, so any `system` selection whose
host brightness disagrees with the theme lands on the Phase 1 fallback rule.
That is correct and intended: the fallback exists precisely so resolution never
throws and never renders an undefined palette.

**Type boundary.** `AuthorOsThemeMode` is the engine's vocabulary. Flutter's
`ThemeMode` and `Brightness` are translated only in the Flutter adapter, via
`AuthorOsTheme.themeMode` and `AuthorOsTheme.themeBrightness`. No Flutter type
enters `lib/theme/*.dart`; the Phase 1 plain-Dart architecture test still
enforces this.

---

## 5. Accessibility

Accessibility reaches the engine from two sources and is applied only by
`ThemeResolver`. No widget performs colour manipulation.

1. **Persisted preferences** — `author_studio.theme.high_contrast` and
   `author_studio.theme.reduce_intensity`, read by `ThemePersistence` into
   `ThemeSelection.accessibility`.
2. **Host request** — `MediaQuery.maybeHighContrastOf` is OR-ed into the
   selection at resolve time only. It is honoured for the session but never
   written back: an OS setting is not the user's saved preference.

Verified end to end through the running application: high contrast raises the
onSurface/surface contrast ratio, reduced intensity softens `primary`, and the
`focusRing`, `selection`, and `highlight` tokens carry the transformation into
`ThemeData.focusColor`, `textSelectionTheme.selectionColor`, and the input
focused border (whose width comes from `metrics.focusRingWidth`).

### Deferred

There is **no user-facing accessibility settings UI**. The Appearance page
offers theme choice only. Adding controls would mean designing new settings
surface, which is outside this phase. The persistence keys, the engine
transformations, and the shell wiring all exist and are tested — only the
controls are missing. Beyond high contrast, no platform accessibility signal is
consumed; `reduceIntensity` has no host equivalent and is preference-only.

---

## 6. Fonts

`Inter` and `Merriweather` are both declared in `pubspec.yaml`. Phase 2 adds no
font package and changes no asset.

Verified against the `ThemeData` the running application uses:

* **Inter** — `textTheme.titleMedium` (engine `ui` role), `labelLarge` and
  `labelMedium` (engine `label` role), and `chipTheme.labelStyle`.
* **Merriweather** — `textTheme.bodyMedium`, `bodySmall`, `headlineMedium`, and
  `ThemeData.fontFamily`, so every role the engine does not explicitly override
  (`bodyLarge`, `titleLarge`, `titleSmall`, `headlineSmall`, `labelSmall`) still
  reads Merriweather.

Merriweather remains the reading and writing face. Manuscript rendering is
untouched.

---

## 7. StudioThemeScope

Two levels, both installed by the shell:

* **Root** — `StudioThemeScope(theme: resolved, studio: null)` wraps
  `MaterialApp`, so every route, dialog, and overlay can reach the resolved
  theme. `studio: null` means shell chrome.
* **Per section** — `_SectionView` nests a scope carrying the section's
  `StudioId`, resolved by the new top-level `sectionStudioId`:

  | Section | StudioId |
  |---|---|
  | characters | `StudioId.character` |
  | codex | `StudioId.storyCodex` |
  | world | `StudioId.world` |
  | timeline | `StudioId.timeline` |
  | plot | `StudioId.plot` |
  | manuscript, chapters | `StudioId.manuscript` |
  | everything else | `null` (shell chrome) |

The nested scope uses `StudioThemeScope.maybeOf`, not `of`: several existing
tests drive `AuthorStudioShell` directly inside a bare `MaterialApp`, where no
root scope exists. Those keep working unchanged, and no fake Studio was created
to test this.

**No Studio was redesigned.** Studios continue to use `Theme.of(context)`; the
scope establishes the mechanism and is proven on a real surface (the Chapters
section resolving `StudioId.manuscript` and reading tokens, spacing, and radii).
Neither built-in theme currently defines `studioOverrides`, so Studio token
lookup correctly falls through to the shell palette today.

---

## 8. Legacy settings compatibility

All eight legacy ids continue to resolve, through `ThemeRegistry`'s alias table:

| Legacy id | Resolves to |
|---|---|
| `paper`, `slate` | `light` |
| `obsidian`, `midnight`, `forest`, `burgundy`, `plum`, `ocean` | `dark` |

Migration behaviour, verified through the running application:

* **Lazy** — performed on read, not at startup.
* **Non-destructive** — the original id is copied to
  `author_studio.theme.legacy_id` before `author_studio.theme_id` is rewritten.
* **Idempotent** — a second launch is a no-op.
* **Read-only safe** — a rejected write still resolves the migrated theme.
* **Same keys** — no new storage namespace; `author_studio.theme_id` and
  `author_studio.accent_id` are the pre-engine keys.

Pre-engine installs have no `theme.mode` key. `ThemePersistence` reads an
explicit mode from the stored theme's natural mode rather than defaulting to
`system`, so an upgrading user's appearance does not silently change.

`AppThemePreset.normalizeId` is **retained** (see below) and is now pinned
against `ThemeRegistry.normalizeId` by a test over every legacy id, so the two
normalizations cannot drift apart.

---

## 9. Remaining legacy code

Nothing below is on the live theme path. Each is documented in place.

| Item | Location | Why it remains |
|---|---|---|
| `AppThemePreset` | `lib/main.dart` | `test/settings_theme_test.dart` asserts the legacy id and accent contract against it. Deleting it would mean deleting or weakening existing tests. Pinned to `ThemeRegistry` by a new equivalence test. |
| `AppThemeSelection` | `lib/main.dart` | Same test file (`resolvedAccentColor`). Superseded by `ThemeSelection`. |
| `AppThemeAccent` | `lib/main.dart` | Already unreferenced before Phase 2 — the shell dropped accent tinting earlier. Removing it is unrelated cleanup, so it is documented rather than deleted. |
| `ThemeSelection.accentId` | `lib/theme/theme_persistence.dart` | Round-tripped for compatibility with the pre-engine key. Resolution does not consume it. |
| `lib/main.authorstudio.backup.dart` | `lib/` | **Dead code.** Contains a second `main()`, a second `MaterialApp`, a second `ThemeData`, and hard-coded colours. Nothing imports it — verified across `lib/`, `test/`, `web/`, `tool/`, and `tools/` — and it is not reachable from the entrypoint, so it is not part of the runtime theme path. It is **not deleted**: removing a file of that size is outside this phase's scope and is a separate decision. It must not be revived. |

**Removed from the runtime:** `_buildThemeData` (deleted), and the shell's direct
`SharedPreferences` theme read/write (`_saveThemeSelection`,
`_updateThemeSelection`, `_themePreferenceKey`, `_accentPreferenceKey`).

### Duplicate-path search

Every occurrence of `AppThemePreset`, `_buildThemeData`, `ThemeData(`,
`ThemeMode`, `Color(0x`, and `fontFamily:` was reviewed and classified:

* `lib/theme/**` — authoritative engine and its Flutter adapter.
* `lib/main.dart` — the legacy compatibility types above, plus
  `AuthorOsTheme.toThemeData` consumption. A test asserts `main.dart` contains
  no `ThemeData(` constructor call, no `_buildThemeData`, and no
  `ColorScheme.fromSeed`.
* `lib/main.authorstudio.backup.dart` — dead, documented above.
* Other `lib/` files — literal `Color(0x…)` values inside individual widgets
  (semantic status colours, chart colours, Studio-specific decoration). These
  are outside the migrated surface and are **not** migrated in this phase; see
  Limitations.
* `test/**` — fixtures constructing their own `ThemeData`/`ColorScheme`, which
  is correct for tests that isolate a widget from the shell.

Nothing was removed mechanically. Only `_buildThemeData` and the shell's
duplicate persistence were obsolete.

---

## 10. Discrepancies discovered

The pre-Phase-2 `_buildThemeData` output was reconstructed verbatim and compared
field by field against the engine's `ThemeData`, for both themes.

**Identical:** `scaffoldBackgroundColor` (`0xFFF2F7FC` / `0xFF080808`),
`colorScheme.surface`, `onSurface`/`onSurfaceVariant` (`0xFF17283A` /
`0xFFFFFFFF`), `outline` (`0xFF718399` / `0xFF8A8A8A`), `outlineVariant`
(`0xFFD4E0EB` / `0xFF363636`), `primaryContainer`, `surfaceContainerHighest`,
`secondary`, card colour, chip background and border (`0xFFE7F0F8` /
`0xFF202020`), input fill, divider, app bar, all radii (card 20, chip 12,
button 14, input 14), chip padding (12/8), button padding (18/12), and body text
family, size, and colour.

Three differences remain. **None is a Phase 2 bypass** — each traces to a
deliberate Phase 1 decision, and none was introduced by this integration.

### D1 — the brand accent is now painted literally *(needs a product decision)*

| | Old | New |
|---|---|---|
| `colorScheme.primary` (light) | `0xFF32618D` | `0xFF4F8FCB` |
| `colorScheme.primary` (dark) | `0xFFE2C46D` | `0xFFD4AF37` |
| `colorScheme.onPrimary` (dark) | `0xFF3C2F00` | `0xFF141414` |

The old shell passed the brand accent to `ColorScheme.fromSeed` as a *seed* and
never applied it, so Material's tonal derivation shipped instead — the declared
brand colour was never actually on screen. Phase 1 sets `primary` to the token
value, which is what Phase 2's brief requires (`0xFF4F8FCB` must "continue
through the Theme Engine") and what `settings_theme_test` has always asserted
`AppThemePreset.accentColor` to be.

**Classification: C — the old behaviour was accidental.** Phase 1's is correct.
It is nevertheless *visible*: filled button backgrounds, focused input borders,
and selected chips shift to the true brand colour. Flagged rather than
silently accepted.

### D2 — focus and selection tokens are now bound

| | Old | New |
|---|---|---|
| `focusColor` | `0x1F000000` / `0x1FFFFFFF` (Material default) | `focusRing` token |
| `textSelectionTheme.selectionColor` | unset | `selection` token |
| focused input border width | `1.5` | `2.0` (`metrics.focusRingWidth`) |

The old shell never bound these; Material's defaults applied and text selection
had no themed colour. Phase 1 introduced the tokens, and Phase 2's accessibility
requirement is that focus ring and selection flow through the engine.

**Classification: C — new behaviour Phase 1 added deliberately.**

### D3 — the typography scale is now explicit *(needs a product decision)*

The old shell set a *family* but no *scale*, so Material 3's default sizes
applied by accident. Phase 1 declares a scale (heading 22, ui 14, label 12,
body 14) and maps it onto Material's role names:

| Role | Old size | New size | Uses in `lib/` |
|---|---|---|---|
| `headlineMedium` | 28 | **22** | 4 |
| `titleMedium` | 16 | **14** (and Inter) | 16 |
| `labelLarge` | 14 | **12** (and Inter) | 14 |
| `bodySmall` | 12 | **13** | 46 |
| `labelMedium` | 12 | 12 (Inter) | 5 |
| `bodyMedium` | 14 | 14 | 25 |
| `displayLarge` / `displayMedium` | 57 / 45 | 44 / 35.2 | 0 |

Roles the engine does not override (`bodyLarge`, `titleLarge`, `titleSmall`,
`headlineSmall`, `labelSmall` — 66 uses) are unchanged.

The **Inter** part of this is required by Phase 2 §8 and is not a discrepancy.
The **size** changes are a Phase 1 design choice: headings and labels render
somewhat smaller, body copy is unchanged, and `bodySmall` gains 1px.

**Classification: C, escalating to D — a product decision.** Phase 2 must not
redesign, and equally must not silently undo Phase 1, so Phase 1's scale is
preserved as built. If the intent was byte-identical typography, the fix belongs
in Phase 1's `_typography` (heading 28, ui 16, label 14, bodySmall 12), not in
the shell.

---

## 11. Limitations and deferred work

1. **No accessibility settings UI.** Engine, persistence, and shell wiring are
   complete and tested; the controls are not built. §5.
2. **No mode selector.** The Appearance page offers themes, not
   light/dark/system. `system` mode is fully supported by the engine, is honoured
   when persisted, and is tested — but no UI writes it today.
3. **Neither built-in theme defines `studioOverrides`.** The Studio scoping
   mechanism is integrated and proven; there is no per-Studio palette variation
   to show yet. Creating one would be a redesign.
4. **Hard-coded colours outside the migrated surface remain.** Individual
   widgets across `lib/` still use literal `Color(0x…)` values for semantic
   status, chart, and decoration colours. This phase migrated the application
   shell and the theme boundary only; a component-wide migration is explicitly
   not in scope.
5. **`lib/main.authorstudio.backup.dart` is dead but retained.** §9.
6. **`AuthorOsThemeMode.system` cannot render both brightnesses in one theme.**
   Both built-in themes are single-brightness, so `system` always resolves via
   the fallback rule unless the theme matches the host. A theme defining both
   palettes would need to be authored — out of scope.
7. **Verified on Linux with Flutter 3.47.1.** The web release build, the full
   test suite, and the analyzer were run there. The Linux *desktop* build could
   not run — the GTK 3 development headers are absent from the environment.
   Windows, macOS, iOS, and Android were not built, and no platform support is
   claimed for any of them.
8. **The change is left uncommitted** in the working tree for the repository
   owner to commit manually.

---

## 12. Verification

| Check | Baseline (before Phase 2) | After Phase 2 |
|---|---|---|
| `flutter test` | 451 passed | **487 passed**, 0 failed |
| `flutter analyze` | 56 issues, 0 errors | **56 issues, 0 errors** — output byte-identical |
| `flutter build web --release` | — | **succeeded** |
| `flutter build linux --release` | — | **unavailable** (see below) |

`flutter build linux --release` cannot run in this environment: CMake fails at
`pkg_check_modules(gtk+-3.0)` because the GTK 3 development headers are not
installed. The CMake toolchain itself (cmake, ninja, clang, pkg-config) is
present. This is an environment limitation, not a project defect — no project
configuration was changed and no system package was installed to force it.

The analyzer baseline was re-measured on this toolchain rather than assumed; the
Phase 1 note of 53 issues reflects a different Flutter version. What matters is
that Phase 2 introduces **no new issue of any severity**.

Generated files rewritten by the Flutter tooling during verification
(`analysis_options.yaml`, `linux/flutter/*`, `windows/flutter/*`, `pubspec.lock`)
were restored and are **not** part of this change.

### Tests added — `test/theme_shell_integration_test.dart` (36)

| Phase 2 requirement | Coverage |
|---|---|
| 1. MaterialApp receives engine output | theme equals adapter output; every colour role traced to the resolved palette; guard that `main.dart` builds no `ThemeData` |
| 2. Default theme resolves | first launch with no settings → registry default |
| 3. Explicit light | light on a dark host, `themeMode` light |
| 4. Explicit dark | dark on a light host, `themeMode` dark, background `0xFF080808` |
| 5. System mode | dark host → dark, light host → light, and a live host switch re-resolves without restart |
| 6. Fallback | light-only theme on a dark host, and dark-only theme asked for light |
| 7. Legacy ids | all eight aliases launch with the right brightness, migrate the key, and back up the original; unknown id → default; `AppThemePreset` ≡ `ThemeRegistry` |
| 8. Theme changes update the app | full app → Settings → Appearance → Dark rebuilds the theme and persists |
| 9. Accessibility reaches the engine | persisted high contrast raises measured contrast; reduced intensity softens `primary`; focus ring / selection / highlight carried; host high-contrast honoured but not persisted |
| 10. Inter for UI | `titleMedium`, `labelLarge`, `labelMedium`, chip label |
| 11. Merriweather reading face | `bodyMedium`, `bodySmall`, `headlineMedium`, non-overridden roles |
| 12. StudioThemeScope resolves | root shell scope carries the resolved theme; a real Studio surface resolves `StudioId.manuscript` and reads tokens, spacing, and radii; every section maps to the right identity |
| No duplicate preference persistence | `main.dart` names no theme storage key and keeps no theme preference constants; every theme key is declared in exactly one file (`ThemePersistence`) across all of `lib/` |
| Visual compatibility intact | the live `MaterialApp` theme still renders the pre-engine palette for both themes (`0xFFF2F7FC`, `0xFFFFFFFF`, `0xFF17283A`, `0xFF718399`, `0xFFD4E0EB`, `0xFFE7F0F8` / `0xFF080808`, `0xFF141414`, `0xFF8A8A8A`, `0xFF363636`, `0xFF202020`) and the same shapes: card 20, chip 12, input 14, button 14, chip padding 12/8, button padding 18/12, zero elevation |

### Existing tests

All 451 pre-existing tests pass unchanged. None was deleted, weakened, or
rewritten — including `test/settings_theme_test.dart`, whose light/dark contrast
assertions now run against engine-produced `ThemeData`. Dashboard, Studio,
Progression, Analytics, Community, Universal Records, and manuscript behaviour
are untouched.
