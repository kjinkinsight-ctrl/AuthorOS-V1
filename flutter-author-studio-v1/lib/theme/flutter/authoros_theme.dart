/// Theme Engine Phase 1 — Flutter adapter.
///
/// The ONLY place where the token vocabulary becomes Flutter types. Everything
/// under `lib/theme/` except this directory is plain Dart, which
/// `test/theme_engine_test.dart` enforces.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../resolved_theme.dart';
import '../theme_definition.dart';
import '../theme_persistence.dart';
import '../theme_tokens.dart';

/// Converts a [ResolvedTheme] into Flutter types.
class AuthorOsTheme {
  const AuthorOsTheme._();

  static Color color(ThemeColor token) => Color(token.value);

  static Brightness brightness(ThemeBrightness value) =>
      value == ThemeBrightness.dark ? Brightness.dark : Brightness.light;

  /// Flutter's [Brightness] as the engine's [ThemeBrightness].
  ///
  /// This is the boundary the host brightness crosses on its way in: Flutter's
  /// type stops here and the engine's type continues inwards.
  static ThemeBrightness themeBrightness(Brightness value) =>
      value == Brightness.dark ? ThemeBrightness.dark : ThemeBrightness.light;

  /// The engine's [AuthorOsThemeMode] as Flutter's [ThemeMode].
  ///
  /// Only `MaterialApp` needs Flutter's enum. The engine never sees it, so the
  /// core stays plain Dart and there is exactly one mode vocabulary inside it.
  static ThemeMode themeMode(AuthorOsThemeMode mode) => switch (mode) {
        AuthorOsThemeMode.light => ThemeMode.light,
        AuthorOsThemeMode.dark => ThemeMode.dark,
        AuthorOsThemeMode.system => ThemeMode.system,
      };

  static FontWeight fontWeight(int weight) => switch (weight) {
        <= 100 => FontWeight.w100,
        <= 200 => FontWeight.w200,
        <= 300 => FontWeight.w300,
        <= 400 => FontWeight.w400,
        <= 500 => FontWeight.w500,
        <= 600 => FontWeight.w600,
        <= 700 => FontWeight.w700,
        <= 800 => FontWeight.w800,
        _ => FontWeight.w900,
      };

  static TextStyle textStyle(ThemeTextStyle style, {Color? color}) => TextStyle(
        fontFamily: style.family,
        fontFamilyFallback:
            style.fallbackFamilies.isEmpty ? null : style.fallbackFamilies,
        fontSize: style.size,
        fontWeight: fontWeight(style.weight),
        height: style.height,
        letterSpacing: style.letterSpacing,
        color: color,
      );

  /// Builds the application [ThemeData] from [theme].
  ///
  /// Component shapes reproduce the pre-engine shell so adopting the engine is
  /// not a visual change: card radius 20, chip 12, button 14, input 14.
  static ThemeData toThemeData(ResolvedTheme theme) {
    final palette = theme.palette;
    final metrics = theme.metrics;

    final onSurface = color(palette[ThemeColorRef.onSurface]);
    final onSurfaceVariant = color(palette[ThemeColorRef.onSurfaceVariant]);
    final primary = color(palette[ThemeColorRef.primary]);
    final surface = color(palette[ThemeColorRef.surface]);
    final surfaceContainer = color(palette[ThemeColorRef.surfaceContainer]);
    final outline = color(palette[ThemeColorRef.outline]);
    final outlineVariant = color(palette[ThemeColorRef.outlineVariant]);
    final focusRing = color(palette[ThemeColorRef.focusRing]);
    final selection = color(palette[ThemeColorRef.selection]);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness(theme.brightness),
      surface: surface,
    ).copyWith(
      primary: primary,
      onPrimary: color(palette[ThemeColorRef.onPrimary]),
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
    );

    final bodyStyle = theme.text(ThemeTextRole.body);
    final headingStyle = theme.text(ThemeTextRole.heading);
    final uiStyle = theme.text(ThemeTextRole.ui);
    final labelStyle = theme.text(ThemeTextRole.label);

    final base = ThemeData(brightness: brightness(theme.brightness));
    final textTheme = base.textTheme
        .apply(
          fontFamily: bodyStyle.family,
          bodyColor: onSurface,
          displayColor: onSurface,
        )
        .copyWith(
          displayLarge: textStyle(headingStyle, color: onSurface)
              .copyWith(fontSize: headingStyle.size * 2.0),
          displayMedium: textStyle(headingStyle, color: onSurface)
              .copyWith(fontSize: headingStyle.size * 1.6),
          headlineMedium: textStyle(headingStyle, color: onSurface),
          titleMedium: textStyle(uiStyle, color: onSurface)
              .copyWith(fontWeight: FontWeight.w600),
          bodyMedium: textStyle(bodyStyle, color: onSurface),
          bodySmall: textStyle(bodyStyle, color: onSurfaceVariant)
              .copyWith(fontSize: bodyStyle.size - 1),
          labelLarge: textStyle(labelStyle, color: onSurface),
          labelMedium: textStyle(labelStyle, color: onSurfaceVariant),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness(theme.brightness),
      fontFamily: bodyStyle.family,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: color(palette[ThemeColorRef.background]),
      focusColor: focusRing,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radius('card')),
        ),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: selection,
        selectionHandleColor: primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: outlineVariant),
        labelStyle: textStyle(labelStyle, color: onSurface),
        secondaryLabelStyle:
            textStyle(labelStyle, color: colorScheme.onPrimaryContainer),
        padding: EdgeInsets.symmetric(
          horizontal: metrics.space('md'),
          vertical: metrics.space('sm'),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radius('chip')),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textStyle(uiStyle),
          padding: EdgeInsets.symmetric(
            horizontal: metrics.space('lg'),
            vertical: metrics.space('md'),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radius('button')),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        labelStyle: TextStyle(color: onSurface),
        hintStyle: TextStyle(color: onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radius('input')),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radius('input')),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radius('input')),
          borderSide:
              BorderSide(color: focusRing, width: metrics.focusRingWidth),
        ),
      ),
    );
  }
}

/// A [ThemeSettingsStore] backed by SharedPreferences.
///
/// Reuses the shell's existing keys; it introduces no new storage namespace.
/// Writes swallow failures so a read-only launch degrades rather than crashes.
class SharedPreferencesThemeStore implements ThemeSettingsStore {
  SharedPreferencesThemeStore(this._preferences);

  /// Loads a snapshot so reads can stay synchronous.
  static Future<SharedPreferencesThemeStore> load() async =>
      SharedPreferencesThemeStore(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<bool> write(String key, String value) async {
    try {
      return await _preferences.setString(key, value);
    } catch (_) {
      // Read-only launch, or storage unavailable. The caller keeps the value
      // in memory for this session.
      return false;
    }
  }
}

/// Provides the resolved theme, and an optional [StudioId], to a subtree.
///
/// Studios read their tokens through this scope instead of owning a theme
/// engine. Nesting a scope with a Studio id layers that Studio's overrides on
/// top of the inherited theme.
class StudioThemeScope extends InheritedWidget {
  const StudioThemeScope({
    super.key,
    required this.theme,
    this.studio,
    required super.child,
  });

  final ResolvedTheme theme;

  /// The Studio this subtree belongs to. `null` means shell chrome.
  final StudioId? studio;

  /// The nearest scope, or `null` when none is present.
  static StudioThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudioThemeScope>();

  /// The nearest scope. Throws when the shell has not installed one.
  static StudioThemeScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError(
        'No StudioThemeScope found. The application shell must install one '
        'above any widget that resolves theme tokens.',
      );
    }
    return scope;
  }

  /// Resolves [ref] for this scope's Studio, falling back to the shell palette.
  Color color(ThemeColorRef ref) =>
      AuthorOsTheme.color(theme.colorFor(studio, ref));

  /// Resolves a typography role, optionally tinted.
  TextStyle text(ThemeTextRole role, {ThemeColorRef? colorRef}) =>
      AuthorOsTheme.textStyle(
        theme.text(role),
        color: colorRef == null ? null : color(colorRef),
      );

  double space(String name) => theme.metrics.space(name);

  double radius(String name) => theme.metrics.radius(name);

  /// Resolves a token for [studio] from the nearest scope.
  static Color colorOf(
    BuildContext context,
    ThemeColorRef ref, {
    StudioId? studio,
  }) {
    final scope = of(context);
    return AuthorOsTheme.color(
      scope.theme.colorFor(studio ?? scope.studio, ref),
    );
  }

  @override
  bool updateShouldNotify(StudioThemeScope oldWidget) =>
      oldWidget.theme != theme || oldWidget.studio != studio;
}
