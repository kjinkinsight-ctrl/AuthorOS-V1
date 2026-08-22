/// Theme Engine Phase 1 — the registry of available themes.
///
/// Plain Dart. Must not import Flutter.
library;

import 'theme_definition.dart';
import 'theme_tokens.dart';

/// Holds every registered [ThemeDefinition] and resolves ids, including the
/// legacy ids persisted by earlier releases.
class ThemeRegistry {
  ThemeRegistry({
    required List<ThemeDefinition> themes,
    required this.defaultThemeId,
    Map<String, String> aliases = const {},
  })  : _themes = {for (final theme in themes) theme.id: theme},
        _aliases = Map.unmodifiable(aliases) {
    if (themes.isEmpty) {
      throw const FormatException('A registry needs at least one theme.');
    }
    for (final theme in themes) {
      theme.validate();
    }
    if (!_themes.containsKey(defaultThemeId)) {
      throw FormatException(
        'Default theme "$defaultThemeId" is not registered.',
      );
    }
    for (final entry in _aliases.entries) {
      if (!_themes.containsKey(entry.value)) {
        throw FormatException(
          'Alias "${entry.key}" points at unregistered theme "${entry.value}".',
        );
      }
    }
  }

  final Map<String, ThemeDefinition> _themes;
  final Map<String, String> _aliases;

  /// Used when a persisted id is absent or unrecognised.
  final String defaultThemeId;

  List<ThemeDefinition> get themes => List.unmodifiable(_themes.values);

  List<String> get ids => List.unmodifiable(_themes.keys);

  /// Maps any id — current, legacy, unknown, or null — onto a registered id.
  ///
  /// Total by construction: an unrecognised id resolves to [defaultThemeId].
  String normalizeId(String? id) {
    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) return defaultThemeId;
    if (_themes.containsKey(trimmed)) return trimmed;
    return _aliases[trimmed] ?? defaultThemeId;
  }

  bool isRegistered(String? id) =>
      id != null && _themes.containsKey(id.trim());

  /// True when [id] is a legacy alias rather than a registered theme.
  bool isAlias(String? id) => id != null && _aliases.containsKey(id.trim());

  ThemeDefinition byId(String? id) => _themes[normalizeId(id)]!;

  /// The two built-in AuthorOS themes.
  ///
  /// Colour values reproduce the pre-engine shell exactly, so adopting the
  /// engine is not a visual change. See
  /// `docs/theme-engine-phase-1-implementation-map.md`.
  factory ThemeRegistry.standard() => ThemeRegistry(
        defaultThemeId: 'light',
        themes: [_lightTheme, _darkTheme],
        aliases: const {
          // Legacy ids persisted by earlier releases. This mapping reproduces
          // AppThemePreset.normalizeId and is covered by settings_theme_test.
          'paper': 'light',
          'slate': 'light',
          'obsidian': 'dark',
          'midnight': 'dark',
          'forest': 'dark',
          'burgundy': 'dark',
          'plum': 'dark',
          'ocean': 'dark',
        },
      );
}

/// Shared metric scale. Radii match the pre-engine shell: card 20, chip 12,
/// button 14, input 14.
const _metrics = ThemeMetrics(
  spacing: {'xs': 4, 'sm': 8, 'md': 12, 'lg': 18, 'xl': 24},
  radii: {'card': 20, 'chip': 12, 'button': 14, 'input': 14},
  focusRingWidth: 2,
);

/// Inter drives UI chrome; Merriweather remains the reading face.
///
/// Both families are declared under `fonts:` in pubspec.yaml. Body and heading
/// stay on Merriweather so the engine reproduces current rendering.
const _typography = ThemeTypography(styles: {
  ThemeTextRole.ui: ThemeTextStyle(
    family: 'Inter',
    size: 14,
    weight: 500,
    height: 1.3,
    fallbackFamilies: ['Merriweather'],
  ),
  ThemeTextRole.heading: ThemeTextStyle(
    family: 'Merriweather',
    size: 22,
    weight: 700,
    height: 1.25,
  ),
  ThemeTextRole.body: ThemeTextStyle(
    family: 'Merriweather',
    size: 14,
    weight: 400,
    height: 1.45,
  ),
  ThemeTextRole.label: ThemeTextStyle(
    family: 'Inter',
    size: 12,
    weight: 600,
    height: 1.2,
    letterSpacing: 0.1,
    fallbackFamilies: ['Merriweather'],
  ),
  ThemeTextRole.code: ThemeTextStyle(
    family: 'monospace',
    size: 13,
    weight: 400,
    height: 1.4,
    fallbackFamilies: ['Courier New', 'monospace'],
  ),
});

const _lightTheme = ThemeDefinition(
  id: 'light',
  name: 'Light',
  description: 'Light blue, white, and cool gray for daytime writing.',
  typography: _typography,
  metrics: _metrics,
  palettes: {
    ThemeBrightness.light: ThemePalette({
      ThemeColorRef.background: ThemeColor(0xFFF2F7FC),
      ThemeColorRef.surface: ThemeColor(0xFFFFFFFF),
      ThemeColorRef.surfaceContainer: ThemeColor(0xFFE7F0F8),
      ThemeColorRef.primary: ThemeColor(0xFF4F8FCB),
      ThemeColorRef.onPrimary: ThemeColor(0xFFFFFFFF),
      ThemeColorRef.onSurface: ThemeColor(0xFF17283A),
      ThemeColorRef.onSurfaceVariant: ThemeColor(0xFF17283A),
      ThemeColorRef.outline: ThemeColor(0xFF718399),
      ThemeColorRef.outlineVariant: ThemeColor(0xFFD4E0EB),
      ThemeColorRef.focusRing: ThemeColor(0xFF4F8FCB),
      ThemeColorRef.selection: ThemeColor(0xFFCFE2F3),
      ThemeColorRef.highlight: ThemeColor(0xFFFFF3C4),
      // Status signals. Both palettes carry the same values because the
      // literals these replace were theme-independent; adopting the roles is
      // therefore not a visual change. See
      // docs/theme-engine-phase-3-1-implementation-map.md.
      ThemeColorRef.success: ThemeColor(0xFF77B884),
      ThemeColorRef.warning: ThemeColor(0xFFC59B6D),
      ThemeColorRef.error: ThemeColor(0xFFE07A6F),
    }, categories: {
      // The categorical ramp reproduces the eight distinct colours the Scene
      // status and link-category switches used before this phase.
      ThemeCategoryRef.category1: ThemeColor(0xFF858A94),
      ThemeCategoryRef.category2: ThemeColor(0xFF65A8A0),
      ThemeCategoryRef.category3: ThemeColor(0xFFC59B6D),
      ThemeCategoryRef.category4: ThemeColor(0xFFD39A52),
      ThemeCategoryRef.category5: ThemeColor(0xFF77B884),
      ThemeCategoryRef.category6: ThemeColor(0xFF7EA6D8),
      ThemeCategoryRef.category7: ThemeColor(0xFFE07A6F),
      ThemeCategoryRef.category8: ThemeColor(0xFF9B8AC4),
    }),
  },
);

const _darkTheme = ThemeDefinition(
  id: 'dark',
  name: 'Dark',
  description: 'Black, gold, and white for focused evening writing.',
  typography: _typography,
  metrics: _metrics,
  palettes: {
    ThemeBrightness.dark: ThemePalette({
      ThemeColorRef.background: ThemeColor(0xFF080808),
      ThemeColorRef.surface: ThemeColor(0xFF141414),
      ThemeColorRef.surfaceContainer: ThemeColor(0xFF202020),
      ThemeColorRef.primary: ThemeColor(0xFFD4AF37),
      ThemeColorRef.onPrimary: ThemeColor(0xFF141414),
      ThemeColorRef.onSurface: ThemeColor(0xFFFFFFFF),
      ThemeColorRef.onSurfaceVariant: ThemeColor(0xFFFFFFFF),
      ThemeColorRef.outline: ThemeColor(0xFF8A8A8A),
      ThemeColorRef.outlineVariant: ThemeColor(0xFF363636),
      ThemeColorRef.focusRing: ThemeColor(0xFFD4AF37),
      ThemeColorRef.selection: ThemeColor(0xFF3A3218),
      ThemeColorRef.highlight: ThemeColor(0xFF4A3F14),
      // Status signals. Both palettes carry the same values because the
      // literals these replace were theme-independent; adopting the roles is
      // therefore not a visual change. See
      // docs/theme-engine-phase-3-1-implementation-map.md.
      ThemeColorRef.success: ThemeColor(0xFF77B884),
      ThemeColorRef.warning: ThemeColor(0xFFC59B6D),
      ThemeColorRef.error: ThemeColor(0xFFE07A6F),
    }, categories: {
      // The categorical ramp reproduces the eight distinct colours the Scene
      // status and link-category switches used before this phase.
      ThemeCategoryRef.category1: ThemeColor(0xFF858A94),
      ThemeCategoryRef.category2: ThemeColor(0xFF65A8A0),
      ThemeCategoryRef.category3: ThemeColor(0xFFC59B6D),
      ThemeCategoryRef.category4: ThemeColor(0xFFD39A52),
      ThemeCategoryRef.category5: ThemeColor(0xFF77B884),
      ThemeCategoryRef.category6: ThemeColor(0xFF7EA6D8),
      ThemeCategoryRef.category7: ThemeColor(0xFFE07A6F),
      ThemeCategoryRef.category8: ThemeColor(0xFF9B8AC4),
    }),
  },
);
