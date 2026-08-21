/// Theme Engine Phase 1 — theme definitions, modes, and accessibility options.
///
/// Plain Dart. Must not import Flutter.
library;

import 'theme_tokens.dart';

/// The two renderable brightnesses. Distinct from Flutter's `Brightness` so the
/// core stays plain Dart; the adapter maps between them.
enum ThemeBrightness { light, dark }

/// What the user selected. `system` defers to the host.
enum AuthorOsThemeMode { light, dark, system }

/// Accessibility transformations, owned by the engine.
///
/// Individual widgets must never implement these; they consume the already
/// transformed [ResolvedTheme].
class ThemeAccessibility {
  const ThemeAccessibility({
    this.highContrast = false,
    this.reduceIntensity = false,
  });

  static const none = ThemeAccessibility();

  /// Raises separation between foreground and background roles.
  final bool highContrast;

  /// Softens saturated decorative colour without touching text contrast.
  final bool reduceIntensity;

  bool get isActive => highContrast || reduceIntensity;

  ThemeAccessibility copyWith({bool? highContrast, bool? reduceIntensity}) =>
      ThemeAccessibility(
        highContrast: highContrast ?? this.highContrast,
        reduceIntensity: reduceIntensity ?? this.reduceIntensity,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeAccessibility &&
      other.highContrast == highContrast &&
      other.reduceIntensity == reduceIntensity;

  @override
  int get hashCode => Object.hash(highContrast, reduceIntensity);

  @override
  String toString() =>
      'ThemeAccessibility(highContrast: $highContrast, '
      'reduceIntensity: $reduceIntensity)';
}

/// A complete set of colour roles for one brightness.
class ThemePalette {
  const ThemePalette(this.colors);

  final Map<ThemeColorRef, ThemeColor> colors;

  ThemeColor operator [](ThemeColorRef ref) {
    final color = colors[ref];
    if (color == null) {
      throw StateError('Palette does not define ${ref.name}.');
    }
    return color;
  }

  bool defines(ThemeColorRef ref) => colors.containsKey(ref);

  /// Roles this palette does not define.
  List<ThemeColorRef> get missingRequiredRoles => [
        for (final ref in ThemeColorRef.values)
          if (!colors.containsKey(ref)) ref,
      ];

  /// A copy with [overrides] applied on top. Absent keys are inherited.
  ThemePalette merge(Map<ThemeColorRef, ThemeColor> overrides) =>
      ThemePalette({...colors, ...overrides});

  /// Applies [transform] to every role.
  ThemePalette map(
    ThemeColor Function(ThemeColorRef ref, ThemeColor color) transform,
  ) =>
      ThemePalette({
        for (final entry in colors.entries)
          entry.key: transform(entry.key, entry.value),
      });
}

/// A registered theme: its palettes, typography, metrics, and Studio overrides.
class ThemeDefinition {
  const ThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.palettes,
    required this.typography,
    required this.metrics,
    this.studioOverrides = const {},
  });

  final String id;
  final String name;
  final String description;

  /// Palettes by brightness. A theme need not supply both.
  final Map<ThemeBrightness, ThemePalette> palettes;

  final ThemeTypography typography;
  final ThemeMetrics metrics;

  /// Partial per-Studio colour overrides, layered over the base palette.
  final Map<StudioId, Map<ThemeColorRef, ThemeColor>> studioOverrides;

  Set<ThemeBrightness> get supportedBrightnesses => palettes.keys.toSet();

  bool supports(ThemeBrightness brightness) =>
      palettes.containsKey(brightness);

  /// The explicit mode that matches this theme when no mode has been chosen.
  ///
  /// A theme offering only a dark palette pins itself to dark; anything else
  /// reads as light. Two callers need this and must agree: migrating a
  /// pre-engine install, which persisted a theme id but no mode, and settings
  /// UI deriving a mode from a bare theme choice. Deriving it here keeps that
  /// rule in the engine rather than restating it at each call site.
  AuthorOsThemeMode get defaultMode =>
      supports(ThemeBrightness.dark) && !supports(ThemeBrightness.light)
          ? AuthorOsThemeMode.dark
          : AuthorOsThemeMode.light;

  /// The brightness this theme falls back to when the requested one is absent.
  ///
  /// Phase 1 fallback rule: prefer the theme's own supported brightness, with
  /// light winning when a theme somehow supports neither the request nor dark.
  ThemeBrightness get fallbackBrightness {
    if (palettes.containsKey(ThemeBrightness.light)) {
      return ThemeBrightness.light;
    }
    if (palettes.containsKey(ThemeBrightness.dark)) {
      return ThemeBrightness.dark;
    }
    throw StateError('Theme "$id" defines no palette.');
  }

  ThemePalette paletteFor(ThemeBrightness brightness) {
    final palette = palettes[brightness];
    if (palette == null) {
      throw StateError(
        'Theme "$id" has no palette for ${brightness.name}. '
        'Resolve through ThemeResolver, which applies the fallback rule.',
      );
    }
    return palette;
  }

  /// Validates that every palette defines every required role.
  void validate() {
    if (id.trim().isEmpty) {
      throw const FormatException('Theme id is required.');
    }
    if (palettes.isEmpty) {
      throw FormatException('Theme "$id" defines no palette.');
    }
    for (final entry in palettes.entries) {
      final missing = entry.value.missingRequiredRoles;
      if (missing.isNotEmpty) {
        throw FormatException(
          'Theme "$id" (${entry.key.name}) is missing colour roles: '
          '${missing.map((ref) => ref.name).join(', ')}.',
        );
      }
    }
    for (final role in ThemeTextRole.values) {
      if (!typography.defines(role)) {
        throw FormatException(
          'Theme "$id" is missing typography role ${role.name}.',
        );
      }
    }
  }
}
