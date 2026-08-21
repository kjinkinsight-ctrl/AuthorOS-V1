/// Theme Engine Phase 1 — token vocabulary.
///
/// This library is plain Dart. It must not import Flutter. The Flutter binding
/// lives in `lib/theme/flutter/authoros_theme.dart` and is the only place where
/// tokens become `ThemeData`.
library;

import 'dart:math' as math;

/// An immutable 32-bit ARGB colour.
///
/// Deliberately independent of `dart:ui` so the token vocabulary stays plain
/// Dart and resolvable in tests without a Flutter binding.
class ThemeColor {
  const ThemeColor(this.value);

  /// 0xAARRGGBB.
  final int value;

  int get alpha => (value >> 24) & 0xFF;
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;

  /// WCAG 2.1 relative luminance.
  double get relativeLuminance {
    double channel(int raw) {
      final srgb = raw / 255.0;
      return srgb <= 0.03928
          ? srgb / 12.92
          : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(red) +
        0.7152 * channel(green) +
        0.0722 * channel(blue);
  }

  /// WCAG 2.1 contrast ratio between two opaque colours, in `1.0..21.0`.
  static double contrastRatio(ThemeColor a, ThemeColor b) {
    final lighter = a.relativeLuminance >= b.relativeLuminance ? a : b;
    final darker = identical(lighter, a) ? b : a;
    return (lighter.relativeLuminance + 0.05) /
        (darker.relativeLuminance + 0.05);
  }

  ThemeColor withAlpha(int alpha) =>
      ThemeColor((alpha & 0xFF) << 24 | (value & 0x00FFFFFF));

  /// Linear interpolation towards [other]. `t` is clamped to `0.0..1.0`.
  ThemeColor lerp(ThemeColor other, double t) {
    final ratio = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
    int mix(int from, int to) => (from + (to - from) * ratio).round() & 0xFF;
    return ThemeColor(
      mix(alpha, other.alpha) << 24 |
          mix(red, other.red) << 16 |
          mix(green, other.green) << 8 |
          mix(blue, other.blue),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'ThemeColor(0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

/// A reference to a semantic colour role.
///
/// Components and Studios address colours through a [ThemeColorRef] rather than
/// a literal value, so one palette swap re-colours every surface. The set is
/// closed on purpose: one token vocabulary, no per-Studio role invention.
/// Studios vary the *values* behind these roles via `studioOverrides`.
enum ThemeColorRef {
  background,
  surface,
  surfaceContainer,
  primary,
  onPrimary,
  onSurface,
  onSurfaceVariant,
  outline,
  outlineVariant,
  focusRing,
  selection,
  highlight,
}

/// Typography roles the shell and Studios may request.
enum ThemeTextRole {
  /// Chrome: navigation, toolbars, buttons.
  ui,

  /// Titles and section headings.
  heading,

  /// Long-form reading and manuscript body copy.
  body,

  /// Dense metadata, captions, field labels.
  label,

  /// Monospaced code and identifiers.
  code,
}

/// A resolved text style. Plain Dart; the adapter maps it to `TextStyle`.
class ThemeTextStyle {
  const ThemeTextStyle({
    required this.family,
    required this.size,
    required this.weight,
    this.height,
    this.letterSpacing,
    this.fallbackFamilies = const [],
  });

  final String family;
  final double size;

  /// Numeric font weight, 100..900.
  final int weight;
  final double? height;
  final double? letterSpacing;

  /// Families tried when [family] has no glyph, in order.
  final List<String> fallbackFamilies;

  ThemeTextStyle copyWith({
    String? family,
    double? size,
    int? weight,
    double? height,
    double? letterSpacing,
    List<String>? fallbackFamilies,
  }) =>
      ThemeTextStyle(
        family: family ?? this.family,
        size: size ?? this.size,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        fallbackFamilies: fallbackFamilies ?? this.fallbackFamilies,
      );
}

/// The full typography contract for a theme.
class ThemeTypography {
  const ThemeTypography({required this.styles});

  final Map<ThemeTextRole, ThemeTextStyle> styles;

  ThemeTextStyle operator [](ThemeTextRole role) {
    final style = styles[role];
    if (style == null) {
      throw StateError('Typography role ${role.name} is not defined.');
    }
    return style;
  }

  bool defines(ThemeTextRole role) => styles.containsKey(role);
}

/// Spacing and radius scale.
class ThemeMetrics {
  const ThemeMetrics({
    required this.spacing,
    required this.radii,
    required this.focusRingWidth,
  });

  /// Named spacing steps, e.g. `xs`, `sm`, `md`, `lg`, `xl`.
  final Map<String, double> spacing;

  /// Named corner radii, e.g. `card`, `chip`, `button`, `input`.
  final Map<String, double> radii;

  final double focusRingWidth;

  double space(String name) {
    final value = spacing[name];
    if (value == null) throw StateError('Spacing step "$name" is not defined.');
    return value;
  }

  double radius(String name) {
    final value = radii[name];
    if (value == null) throw StateError('Radius "$name" is not defined.');
    return value;
  }
}

/// Identifies a Studio so it can carry scoped token overrides.
///
/// Studios request tokens through this identity; they never own a theme engine.
class StudioId {
  const StudioId(this.value);

  final String value;

  static const shell = StudioId('shell');
  static const character = StudioId('character');
  static const storyCodex = StudioId('story_codex');
  static const world = StudioId('world');
  static const timeline = StudioId('timeline');
  static const plot = StudioId('plot');
  static const worldBoard = StudioId('world_board');
  static const map = StudioId('map');
  static const manuscript = StudioId('manuscript');
  static const analytics = StudioId('analytics');

  @override
  bool operator ==(Object other) => other is StudioId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StudioId($value)';
}
