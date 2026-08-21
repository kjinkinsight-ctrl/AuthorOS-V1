/// Theme Engine Phase 1 — resolution rules.
///
/// Plain Dart. Must not import Flutter.
///
/// This is the only place where a mode becomes a brightness and where
/// accessibility transformations are applied. Widgets must never re-implement
/// either.
library;

import 'resolved_theme.dart';
import 'theme_definition.dart';
import 'theme_tokens.dart';

class ThemeResolver {
  const ThemeResolver();

  /// Resolves [definition] for [mode] against [hostBrightness].
  ///
  /// Rules, in order:
  ///
  /// 1. **Mode.** An explicit `light`/`dark` selection always wins.
  ///    `system` defers to [hostBrightness].
  /// 2. **Fallback.** If the theme has no palette for the requested
  ///    brightness, [ThemeDefinition.fallbackBrightness] is used and
  ///    [ResolvedTheme.fallbackApplied] is set. Resolution never throws for a
  ///    renderable theme.
  /// 3. **Accessibility.** `highContrast` is applied first, then
  ///    `reduceIntensity`. The order matters: contrast is established against
  ///    true palette values, then decorative saturation is softened without
  ///    undoing it.
  ResolvedTheme resolve({
    required ThemeDefinition definition,
    required AuthorOsThemeMode mode,
    required ThemeBrightness hostBrightness,
    ThemeAccessibility accessibility = ThemeAccessibility.none,
  }) {
    final requestedBrightness = switch (mode) {
      AuthorOsThemeMode.light => ThemeBrightness.light,
      AuthorOsThemeMode.dark => ThemeBrightness.dark,
      AuthorOsThemeMode.system => hostBrightness,
    };

    final supported = definition.supports(requestedBrightness);
    final brightness =
        supported ? requestedBrightness : definition.fallbackBrightness;

    var palette = definition.paletteFor(brightness);
    var studioOverrides = definition.studioOverrides;

    if (accessibility.highContrast) {
      palette = _applyHighContrast(palette, brightness);
      studioOverrides =
          _transformOverrides(studioOverrides, (ref, color) =>
              _highContrastColor(ref, color, brightness));
    }
    if (accessibility.reduceIntensity) {
      palette = _applyReducedIntensity(palette, brightness);
      studioOverrides =
          _transformOverrides(studioOverrides, (ref, color) =>
              _reducedIntensityColor(ref, color, brightness));
    }

    return ResolvedTheme(
      themeId: definition.id,
      name: definition.name,
      requestedMode: mode,
      brightness: brightness,
      requestedBrightness: requestedBrightness,
      fallbackApplied: !supported,
      palette: palette,
      typography: definition.typography,
      metrics: definition.metrics,
      accessibility: accessibility,
      studioOverrides: studioOverrides,
    );
  }

  // --- Accessibility transformations -----------------------------------

  /// Foreground roles move towards pure white/black; separators strengthen.
  ///
  /// Background and surface roles are deliberately untouched: moving them
  /// would change layout-level appearance rather than raise legibility.
  static ThemePalette _applyHighContrast(
    ThemePalette palette,
    ThemeBrightness brightness,
  ) =>
      palette.map((ref, color) => _highContrastColor(ref, color, brightness));

  static ThemeColor _highContrastColor(
    ThemeColorRef ref,
    ThemeColor color,
    ThemeBrightness brightness,
  ) {
    final extreme = brightness == ThemeBrightness.dark
        ? const ThemeColor(0xFFFFFFFF)
        : const ThemeColor(0xFF000000);
    return switch (ref) {
      ThemeColorRef.onSurface ||
      ThemeColorRef.onSurfaceVariant =>
        color.lerp(extreme, 0.65),
      ThemeColorRef.outline => color.lerp(extreme, 0.45),
      ThemeColorRef.outlineVariant => color.lerp(extreme, 0.35),
      ThemeColorRef.focusRing => color.lerp(extreme, 0.25),
      _ => color,
    };
  }

  /// Saturated decorative colour is softened towards the surface.
  ///
  /// Text roles (`onSurface`, `onSurfaceVariant`, `onPrimary`) are excluded —
  /// reducing intensity must never reduce reading contrast.
  static ThemePalette _applyReducedIntensity(
    ThemePalette palette,
    ThemeBrightness brightness,
  ) =>
      palette
          .map((ref, color) => _reducedIntensityColor(ref, color, brightness));

  static ThemeColor _reducedIntensityColor(
    ThemeColorRef ref,
    ThemeColor color,
    ThemeBrightness brightness,
  ) {
    final neutral = brightness == ThemeBrightness.dark
        ? const ThemeColor(0xFF808080)
        : const ThemeColor(0xFF9E9E9E);
    return switch (ref) {
      ThemeColorRef.primary ||
      ThemeColorRef.focusRing =>
        color.lerp(neutral, 0.3),
      ThemeColorRef.selection ||
      ThemeColorRef.highlight =>
        color.lerp(neutral, 0.45),
      _ => color,
    };
  }

  static Map<StudioId, Map<ThemeColorRef, ThemeColor>> _transformOverrides(
    Map<StudioId, Map<ThemeColorRef, ThemeColor>> overrides,
    ThemeColor Function(ThemeColorRef ref, ThemeColor color) transform,
  ) {
    if (overrides.isEmpty) return overrides;
    return {
      for (final studio in overrides.entries)
        studio.key: {
          for (final role in studio.value.entries)
            role.key: transform(role.key, role.value),
        },
    };
  }
}
