/// Theme Engine Phase 1 — the resolved output.
///
/// Plain Dart. Must not import Flutter.
library;

import 'theme_definition.dart';
import 'theme_tokens.dart';

/// A fully resolved theme: one brightness, one transformed palette, ready for
/// an adapter to render.
///
/// Everything is already decided here — mode resolution, the fallback rule, and
/// accessibility transformations have all been applied. Adapters and widgets
/// read; they never re-derive.
class ResolvedTheme {
  const ResolvedTheme({
    required this.themeId,
    required this.name,
    required this.requestedMode,
    required this.brightness,
    required this.palette,
    required this.typography,
    required this.metrics,
    required this.accessibility,
    required this.fallbackApplied,
    required this.requestedBrightness,
    this.studioOverrides = const {},
  });

  final String themeId;
  final String name;

  /// What the user asked for, including `system`.
  final AuthorOsThemeMode requestedMode;

  /// The brightness actually rendered.
  final ThemeBrightness brightness;

  /// Post-transformation colours for the shell.
  final ThemePalette palette;

  final ThemeTypography typography;
  final ThemeMetrics metrics;
  final ThemeAccessibility accessibility;

  /// True when [requestedBrightness] could not be rendered and the Phase 1
  /// fallback rule selected [brightness] instead.
  final bool fallbackApplied;

  /// The brightness resolution asked for, before any fallback.
  final ThemeBrightness requestedBrightness;

  /// Per-Studio colour overrides, already transformed alongside the palette.
  final Map<StudioId, Map<ThemeColorRef, ThemeColor>> studioOverrides;

  /// Resolves a colour role for the shell.
  ThemeColor color(ThemeColorRef ref) => palette[ref];

  /// Resolves a colour role for [studio], falling back to the shell palette
  /// when that Studio overrides nothing for this role.
  ThemeColor colorFor(StudioId? studio, ThemeColorRef ref) {
    if (studio == null) return palette[ref];
    final override = studioOverrides[studio]?[ref];
    return override ?? palette[ref];
  }

  /// The effective palette for [studio]: the shell palette with that Studio's
  /// overrides layered on top.
  ThemePalette paletteFor(StudioId? studio) {
    if (studio == null) return palette;
    final overrides = studioOverrides[studio];
    if (overrides == null || overrides.isEmpty) return palette;
    return palette.merge(overrides);
  }

  ThemeTextStyle text(ThemeTextRole role) => typography[role];

  bool get isDark => brightness == ThemeBrightness.dark;

  @override
  String toString() => 'ResolvedTheme($themeId, ${brightness.name}, '
      'requested: ${requestedMode.name}, fallback: $fallbackApplied)';
}
