# Theme Engine Phase 1 — Implementation Map

Implemented: August 20, 2026
Status: **Complete. Architecture only — the shell is not yet migrated.**

## Scope

Phase 1 builds the theme architecture. It does **not** make that architecture
authoritative for the application UI — that is Phase 2.

`lib/main.dart` is deliberately untouched. The pre-engine path
(`AppThemePreset` → `_buildThemeData` → `MaterialApp`) still renders the live
app, exactly as before. The engine sits beside it, fully tested, ready for
Phase 2 to switch over. This honours the standing rule that old code is not
deleted until its replacement is verified.

## Why this phase exists

Two prior directives — Cross-System Integration Phase 1 and Theme Engine
Phase 2 — assumed a completed Theme Engine Phase 1. Audits found none: zero
matches for every named symbol across all branches, all remotes, and all
history. See `docs/theme-engine-phase-2-implementation-map.md` for that audit.
This phase closes the gap.

## Resolution path

```
ThemeSettingsStore  (SharedPreferences, or memory in tests)
        ↓
ThemePersistence    — loads selection, migrates legacy ids
        ↓
ThemeSelection      — themeId + mode + accessibility + accentId
        ↓
ThemeEngine         — the single entry point
        ↓
ThemeRegistry       — resolves the id (incl. legacy aliases)
        ↓
ThemeResolver       — mode → brightness, fallback, accessibility
        ↓
ResolvedTheme       — plain Dart, fully decided
        ↓
AuthorOsTheme       — the Flutter adapter
        ↓
ThemeData           — consumed by MaterialApp in Phase 2
```

Nothing may bypass this chain. `ResolvedTheme` is the only thing widgets read,
and it is always the output of `ThemeResolver`.

## Files created

| File | Contents |
|---|---|
| `lib/theme/theme_tokens.dart` | `ThemeColor`, `ThemeColorRef`, `ThemeTextRole`, `ThemeTextStyle`, `ThemeTypography`, `ThemeMetrics`, `StudioId` |
| `lib/theme/theme_definition.dart` | `ThemeBrightness`, `AuthorOsThemeMode`, `ThemeAccessibility`, `ThemePalette`, `ThemeDefinition` |
| `lib/theme/theme_registry.dart` | `ThemeRegistry` + the two built-in themes + legacy aliases |
| `lib/theme/resolved_theme.dart` | `ResolvedTheme` |
| `lib/theme/theme_resolver.dart` | `ThemeResolver` — mode, fallback, accessibility |
| `lib/theme/theme_persistence.dart` | `ThemeSettingsStore`, `MemoryThemeSettingsStore`, `ThemeSelection`, `ThemePersistence` |
| `lib/theme/theme_engine.dart` | `ThemeEngine` |
| `lib/theme/flutter/authoros_theme.dart` | `AuthorOsTheme`, `SharedPreferencesThemeStore`, `StudioThemeScope` |
| `test/theme_engine_test.dart` | 40 core tests |
| `test/theme_flutter_adapter_test.dart` | 24 adapter and scope tests |

One file modified: `pubspec.yaml` — Inter registered as a font family.

## Architectural decisions

### The core is plain Dart

Everything under `lib/theme/` except `lib/theme/flutter/` imports no Flutter.
Colours are `ThemeColor` (a 32-bit ARGB value type), not `dart:ui`'s `Color`;
brightness is `ThemeBrightness`, not Flutter's `Brightness`. The adapter is the
sole translation point.

This keeps resolution testable without a Flutter binding and enforces the
standing rule that Theme is presentation-only and must not entangle itself with
domain systems. Two tests assert it: one greps the core for `package:flutter/`,
another for imports of records, persistence, progression, analytics, or
community.

### `AuthorOsThemeMode`, not `ThemeMode`

Flutter's `material.dart` already exports `ThemeMode`. Naming ours the same
forced every consumer — including `main.dart`, which imports `material.dart` —
to write a `hide` or a prefix. Renaming to `AuthorOsThemeMode` removes that
papercut permanently. Semantics are identical: `light`, `dark`, `system`.

### `ThemeColorRef` is a closed enum; `StudioId` is an open class

`ThemeColorRef` is an enum. The token vocabulary is deliberately fixed — one
vocabulary, no per-Studio role invention. Studios vary the *values* behind
these roles through `studioOverrides`, never the role set.

`StudioId` stays a class with static constants so Expansion Packs can introduce
Studio identities later without editing core. The cost is that it cannot key a
`const` map; call sites use a non-const map literal.

### The Phase 1 fallback rule

A theme need not define both brightnesses — the built-in `light` theme has no
dark palette, and `dark` has no light palette. When a requested brightness is
unavailable:

1. `ThemeDefinition.fallbackBrightness` supplies the theme's own supported
   brightness (light preferred when both somehow exist).
2. `ResolvedTheme.fallbackApplied` is set to `true`.
3. `ResolvedTheme.requestedBrightness` preserves what was asked for.

Resolution never throws for a registered theme. A test exercises every
combination of registered theme × mode × host brightness and asserts this.

### Accessibility transformation order

`highContrast` is applied first, then `reduceIntensity`. Contrast is
established against true palette values before decorative saturation is
softened, so softening cannot silently undo a contrast gain.

- **High contrast** moves `onSurface` and `onSurfaceVariant` 65% toward the
  brightness extreme, `outline` 45%, `outlineVariant` 35%, `focusRing` 25%.
  Background and surface roles are untouched: moving them changes layout
  appearance rather than raising legibility.
- **Reduced intensity** softens `primary` and `focusRing` 30% toward neutral,
  and `selection`/`highlight` 45%. Text roles are explicitly excluded — a test
  asserts `onSurface` and `onSurfaceVariant` are byte-identical before and
  after.

Both transformations also apply to Studio overrides, so a Studio's custom
accent is transformed consistently with the shell.

### Legacy migration

`ThemePersistence.load()` migrates a legacy theme id in place. The migration is:

- **lazy** — nothing happens until `load()` is called;
- **idempotent** — the trigger is `stored != normalized`, so a second run is a
  no-op. A test loads three times and asserts the store is byte-identical after
  the first;
- **non-destructive** — the original id is copied to
  `author_studio.theme.legacy_id` before the canonical key is rewritten, and
  only if no backup exists yet;
- **read-only safe** — `ThemeSettingsStore.write` returns `false` rather than
  throwing. A test runs a full migration against a read-only store and asserts
  the correct theme still resolves in memory.

### Mode inference for pre-engine installs

Installs predating this engine persisted a theme id but no mode key. Defaulting
them to `system` would silently change appearance on a machine whose host
brightness differs from the saved choice. Instead, a missing mode key is read
as the explicit mode matching the saved theme's brightness — an `obsidian`
install resolves to `AuthorOsThemeMode.dark`, not `system`.

## Compatibility with the pre-engine shell

The built-in palettes reproduce `_buildThemeData` exactly, so Phase 2 will not
be a visual change:

| Role | Light | Dark |
|---|---|---|
| `background` | `0xFFF2F7FC` | `0xFF080808` |
| `surface` | `0xFFFFFFFF` | `0xFF141414` |
| `surfaceContainer` | `0xFFE7F0F8` | `0xFF202020` |
| `primary` | `0xFF4F8FCB` | `0xFFD4AF37` |
| `onSurface` | `0xFF17283A` | `0xFFFFFFFF` |
| `outline` | `0xFF718399` | `0xFF8A8A8A` |
| `outlineVariant` | `0xFFD4E0EB` | `0xFF363636` |

Metrics also match: card radius 20, chip 12, button 14, input 14.

Legacy id aliases reproduce `AppThemePreset.normalizeId` exactly —
`paper`/`slate` → light; `obsidian`/`midnight`/`forest`/`burgundy`/`plum`/`ocean`
→ dark — and are asserted id-by-id.

Storage reuses the shell's existing keys (`author_studio.theme_id`,
`author_studio.accent_id`) and adds three under the same namespace
(`author_studio.theme.mode`, `.high_contrast`, `.reduce_intensity`) plus the
migration backup. No second namespace, and a test asserts nothing outside that
set is ever written.

## Typography

| Role | Family | Notes |
|---|---|---|
| `ui` | Inter | Chrome, toolbars, buttons; falls back to Merriweather |
| `heading` | Merriweather | Unchanged from the current shell |
| `body` | Merriweather | Unchanged — preserves `settings_theme_test` |
| `label` | Inter | Dense metadata and field labels |
| `code` | monospace | Falls back to Courier New, then monospace |

**Inter was registered as a font family in this phase.** It had been bundled
under `assets:` only, which left `fontFamily: 'Inter'` silently unresolvable.
A test asserts the `fonts:` section declares `- family: Inter` with both
weights, guarding against regression to asset-only bundling.

## Studio integration

`StudioThemeScope` is an `InheritedWidget` carrying a `ResolvedTheme` and an
optional `StudioId`. Studios call `StudioThemeScope.of(context).color(ref)` and
receive their override if one exists, or the shell value if not. Nesting a
scope with a Studio id layers that Studio's overrides onto the inherited theme.

Studios never own a theme engine, never construct `ThemeData`, and never
implement accessibility transformations.

## Intentionally unchanged

- **`lib/main.dart`** — the shell still uses `AppThemePreset` and
  `_buildThemeData`. Migrating it is Phase 2.
- **`AppThemePreset`, `AppThemeSelection`, `AppThemeAccent`** — retained and
  still authoritative for the live app.
- **`test/settings_theme_test.dart`** — untouched and still passing. It
  documents the contract this engine reproduces.
- **The 89 hard-coded `Color(0x…)` values in `lib/`** — not part of this phase.
- **`lib/main.authorstudio.backup.dart`** — dead code carrying a second
  `main()` and `ThemeData`. Flagged in the Phase 2 audit; deleting it is a
  repository cleanup decision, not a Phase 1 action.

## Known limitations

1. **The engine is not yet wired into the app.** It is fully tested but
   inert at runtime until Phase 2.
2. **The accent setting is preserved but not consumed.** The pre-engine shell
   persists `author_studio.accent_id` and offers 8 accent colours, but
   `AppThemeSelection.resolvedAccentColor` ignores the id and returns the
   theme's own accent, and `_accentId` is force-set to `'default'` at two call
   sites. The engine preserves the value verbatim and matches current
   behaviour. Whether accents should become functional is a product decision.
3. **Neither built-in theme supports both brightnesses.** This mirrors the
   current shell, where selecting a theme selects a brightness. The fallback
   rule handles the mismatch. A theme defining both palettes would make
   `system` mode fully meaningful.
4. **`reduceIntensity` and `highContrast` are not yet driven by host
   accessibility settings.** They are engine-level options; reading platform
   preferences is Phase 2 shell work.
5. **No dynamic/custom themes.** The registry supports registration, but only
   the two built-ins ship.

## Deferred

Theme Engine Phase 2 (shell migration), Phase 3, Studio redesign, new visual
themes, Map Studio, Expansion Packs.
