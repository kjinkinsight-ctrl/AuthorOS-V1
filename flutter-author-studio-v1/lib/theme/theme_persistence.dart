/// Theme Engine Phase 1 — settings persistence and legacy migration.
///
/// Plain Dart. Must not import Flutter.
///
/// The store is abstracted so the core stays testable without a Flutter
/// binding. The shell supplies a SharedPreferences-backed implementation.
library;

import 'theme_definition.dart';
import 'theme_registry.dart';

/// A minimal key/value store. Reads are synchronous against an already-loaded
/// snapshot; writes may fail on a read-only launch and must not throw.
abstract class ThemeSettingsStore {
  String? read(String key);

  /// Persists [key]. Implementations should swallow storage failures and
  /// return `false` rather than throwing — a read-only launch is not an error.
  Future<bool> write(String key, String value);
}

/// An in-memory store. Used by tests and as a safe default.
class MemoryThemeSettingsStore implements ThemeSettingsStore {
  MemoryThemeSettingsStore([Map<String, String>? initial])
      : _values = {...?initial};

  final Map<String, String> _values;

  /// Simulates a read-only launch: writes are rejected.
  bool readOnly = false;

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  Future<bool> write(String key, String value) async {
    if (readOnly) return false;
    _values[key] = value;
    return true;
  }
}

/// The user's persisted theme choice.
class ThemeSelection {
  const ThemeSelection({
    required this.themeId,
    required this.mode,
    this.accessibility = ThemeAccessibility.none,
    this.accentId = 'default',
  });

  final String themeId;
  final AuthorOsThemeMode mode;
  final ThemeAccessibility accessibility;

  /// Preserved for compatibility with the pre-engine shell, which persists an
  /// accent id. Resolution does not consume it — see the Phase 1 map.
  final String accentId;

  ThemeSelection copyWith({
    String? themeId,
    AuthorOsThemeMode? mode,
    ThemeAccessibility? accessibility,
    String? accentId,
  }) =>
      ThemeSelection(
        themeId: themeId ?? this.themeId,
        mode: mode ?? this.mode,
        accessibility: accessibility ?? this.accessibility,
        accentId: accentId ?? this.accentId,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeSelection &&
      other.themeId == themeId &&
      other.mode == mode &&
      other.accessibility == accessibility &&
      other.accentId == accentId;

  @override
  int get hashCode => Object.hash(themeId, mode, accessibility, accentId);

  @override
  String toString() =>
      'ThemeSelection($themeId, ${mode.name}, accent: $accentId, '
      '$accessibility)';
}

/// Reads and writes the theme selection, migrating legacy values in place.
///
/// The migration is:
///
/// * **lazy** — performed on read, never at startup;
/// * **idempotent** — re-running changes nothing after the first pass;
/// * **non-destructive** — the original legacy id is copied to
///   [legacyIdBackupKey] before the canonical key is rewritten;
/// * **read-only safe** — if writes fail, the migrated value is still returned.
class ThemePersistence {
  ThemePersistence({required this.store, required this.registry});

  final ThemeSettingsStore store;
  final ThemeRegistry registry;

  /// Existing key, shared with the pre-engine shell. Not a new namespace.
  static const themeIdKey = 'author_studio.theme_id';

  /// Existing key, shared with the pre-engine shell.
  static const accentIdKey = 'author_studio.accent_id';

  static const modeKey = 'author_studio.theme.mode';
  static const highContrastKey = 'author_studio.theme.high_contrast';
  static const reduceIntensityKey = 'author_studio.theme.reduce_intensity';

  /// Where a pre-migration legacy id is preserved.
  static const legacyIdBackupKey = 'author_studio.theme.legacy_id';

  /// Loads the selection, migrating a legacy theme id if one is present.
  Future<ThemeSelection> load() async {
    final rawThemeId = store.read(themeIdKey);
    final themeId = registry.normalizeId(rawThemeId);

    // Migrate only when the stored value is not already canonical. Because the
    // condition is "stored != normalized", a second run is a no-op.
    if (rawThemeId != null && rawThemeId.trim() != themeId) {
      if (store.read(legacyIdBackupKey) == null) {
        await store.write(legacyIdBackupKey, rawThemeId);
      }
      await store.write(themeIdKey, themeId);
    }

    return ThemeSelection(
      themeId: themeId,
      mode: _readMode(),
      accentId: store.read(accentIdKey) ?? 'default',
      accessibility: ThemeAccessibility(
        highContrast: _readFlag(highContrastKey),
        reduceIntensity: _readFlag(reduceIntensityKey),
      ),
    );
  }

  /// Persists [selection]. Returns `false` if any write was rejected, in which
  /// case the caller should still honour [selection] for this session.
  Future<bool> save(ThemeSelection selection) async {
    final results = await Future.wait([
      store.write(themeIdKey, registry.normalizeId(selection.themeId)),
      store.write(modeKey, selection.mode.name),
      store.write(accentIdKey, selection.accentId),
      store.write(
        highContrastKey,
        selection.accessibility.highContrast.toString(),
      ),
      store.write(
        reduceIntensityKey,
        selection.accessibility.reduceIntensity.toString(),
      ),
    ]);
    return results.every((ok) => ok);
  }

  /// True when a legacy id was migrated at some point.
  bool get hasMigratedLegacyId => store.read(legacyIdBackupKey) != null;

  /// The original legacy id, if one was migrated.
  String? get migratedLegacyId => store.read(legacyIdBackupKey);

  AuthorOsThemeMode _readMode() {
    final raw = store.read(modeKey)?.trim();
    for (final mode in AuthorOsThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    // Pre-engine installs have no mode key. They persisted an explicit theme
    // id, so an explicit mode matching that theme's brightness is the correct
    // reading — not `system`, which would silently change their appearance.
    final themeId = registry.normalizeId(store.read(themeIdKey));
    return registry.byId(themeId).defaultMode;
  }

  bool _readFlag(String key) => store.read(key)?.trim() == 'true';
}
