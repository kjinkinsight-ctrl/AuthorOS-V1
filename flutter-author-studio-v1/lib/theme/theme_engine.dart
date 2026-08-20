/// Theme Engine Phase 1 — the authoritative entry point.
///
/// Plain Dart. Must not import Flutter.
///
/// One resolution path:
///
///     ThemePersistence → ThemeEngine → ResolvedTheme → adapter → ThemeData
///
/// Nothing outside this library may construct a [ResolvedTheme] for the shell.
library;

import 'resolved_theme.dart';
import 'theme_definition.dart';
import 'theme_persistence.dart';
import 'theme_registry.dart';
import 'theme_resolver.dart';

class ThemeEngine {
  ThemeEngine({
    required this.registry,
    required this.persistence,
    this.resolver = const ThemeResolver(),
  });

  /// Convenience wiring: the two built-in themes over [store].
  factory ThemeEngine.standard({required ThemeSettingsStore store}) {
    final registry = ThemeRegistry.standard();
    return ThemeEngine(
      registry: registry,
      persistence: ThemePersistence(store: store, registry: registry),
    );
  }

  final ThemeRegistry registry;
  final ThemePersistence persistence;
  final ThemeResolver resolver;

  ThemeSelection? _selection;

  /// The selection in force, once loaded.
  ThemeSelection? get selection => _selection;

  /// Loads the persisted selection, migrating legacy values. Idempotent.
  Future<ThemeSelection> load() async {
    final loaded = await persistence.load();
    _selection = loaded;
    return loaded;
  }

  /// Resolves the current selection against [hostBrightness].
  ///
  /// [hostBrightness] is only consulted when the selection's mode is
  /// [AuthorOsThemeMode.system]; an explicit light/dark choice overrides it.
  Future<ResolvedTheme> resolve({
    required ThemeBrightness hostBrightness,
  }) async {
    final selection = _selection ?? await load();
    return resolveSelection(
      selection: selection,
      hostBrightness: hostBrightness,
    );
  }

  /// Resolves an arbitrary [selection] without persisting it. Pure.
  ResolvedTheme resolveSelection({
    required ThemeSelection selection,
    required ThemeBrightness hostBrightness,
  }) =>
      resolver.resolve(
        definition: registry.byId(selection.themeId),
        mode: selection.mode,
        hostBrightness: hostBrightness,
        accessibility: selection.accessibility,
      );

  /// Applies and persists a new selection, returning the resolved result.
  ///
  /// The returned theme is honoured for this session even if persistence was
  /// rejected — a read-only launch must not block a theme change.
  Future<ResolvedTheme> select({
    required ThemeSelection selection,
    required ThemeBrightness hostBrightness,
  }) async {
    final normalized =
        selection.copyWith(themeId: registry.normalizeId(selection.themeId));
    _selection = normalized;
    await persistence.save(normalized);
    return resolveSelection(
      selection: normalized,
      hostBrightness: hostBrightness,
    );
  }

  /// Changes only the theme, keeping mode and accessibility.
  Future<ResolvedTheme> selectTheme({
    required String themeId,
    required ThemeBrightness hostBrightness,
  }) async {
    final current = _selection ?? await load();
    return select(
      selection: current.copyWith(themeId: themeId),
      hostBrightness: hostBrightness,
    );
  }

  /// Changes only the mode, keeping theme and accessibility.
  Future<ResolvedTheme> selectMode({
    required AuthorOsThemeMode mode,
    required ThemeBrightness hostBrightness,
  }) async {
    final current = _selection ?? await load();
    return select(
      selection: current.copyWith(mode: mode),
      hostBrightness: hostBrightness,
    );
  }

  /// Changes only the accessibility options.
  Future<ResolvedTheme> selectAccessibility({
    required ThemeAccessibility accessibility,
    required ThemeBrightness hostBrightness,
  }) async {
    final current = _selection ?? await load();
    return select(
      selection: current.copyWith(accessibility: accessibility),
      hostBrightness: hostBrightness,
    );
  }
}
