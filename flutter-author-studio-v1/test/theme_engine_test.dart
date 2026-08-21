import 'dart:io';

import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_resolver.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryThemeSettingsStore store;
  late ThemeEngine engine;

  setUp(() {
    store = MemoryThemeSettingsStore();
    engine = ThemeEngine.standard(store: store);
  });

  group('registry', () {
    test('registers the two built-in themes and validates them', () {
      final registry = ThemeRegistry.standard();
      expect(registry.ids, ['light', 'dark']);
      expect(registry.defaultThemeId, 'light');
      for (final theme in registry.themes) {
        theme.validate();
      }
    });

    test('every palette defines every colour role', () {
      for (final theme in ThemeRegistry.standard().themes) {
        for (final palette in theme.palettes.values) {
          expect(palette.missingRequiredRoles, isEmpty,
              reason: 'theme ${theme.id} is missing roles');
        }
      }
    });

    test('every theme defines every typography role', () {
      for (final theme in ThemeRegistry.standard().themes) {
        for (final role in ThemeTextRole.values) {
          expect(theme.typography.defines(role), isTrue,
              reason: '${theme.id} missing ${role.name}');
        }
      }
    });

    test('legacy ids normalize exactly as the pre-engine shell did', () {
      final registry = ThemeRegistry.standard();
      // Contract inherited from AppThemePreset.normalizeId.
      expect(registry.normalizeId('paper'), 'light');
      expect(registry.normalizeId('slate'), 'light');
      expect(registry.normalizeId('obsidian'), 'dark');
      expect(registry.normalizeId('midnight'), 'dark');
      expect(registry.normalizeId('forest'), 'dark');
      expect(registry.normalizeId('burgundy'), 'dark');
      expect(registry.normalizeId('plum'), 'dark');
      expect(registry.normalizeId('ocean'), 'dark');
      expect(registry.normalizeId('light'), 'light');
      expect(registry.normalizeId('dark'), 'dark');
    });

    test('unknown, empty, and null ids fall back to the default theme', () {
      final registry = ThemeRegistry.standard();
      expect(registry.normalizeId('not-a-theme'), 'light');
      expect(registry.normalizeId(''), 'light');
      expect(registry.normalizeId('   '), 'light');
      expect(registry.normalizeId(null), 'light');
    });

    test('a registry rejects a default id that is not registered', () {
      expect(
        () => ThemeRegistry(
          themes: ThemeRegistry.standard().themes,
          defaultThemeId: 'nope',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a registry rejects an alias pointing at an unregistered theme', () {
      expect(
        () => ThemeRegistry(
          themes: ThemeRegistry.standard().themes,
          defaultThemeId: 'light',
          aliases: const {'legacy': 'ghost'},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('resolution', () {
    test('default selection resolves to the light theme', () async {
      final theme = await engine.resolve(hostBrightness: ThemeBrightness.light);
      expect(theme.themeId, 'light');
      expect(theme.brightness, ThemeBrightness.light);
      expect(theme.fallbackApplied, isFalse);
    });

    test('light mode resolves light regardless of host brightness', () {
      for (final host in ThemeBrightness.values) {
        final theme = engine.resolveSelection(
          selection:
              const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
          hostBrightness: host,
        );
        expect(theme.brightness, ThemeBrightness.light);
      }
    });

    test('dark mode resolves dark regardless of host brightness', () {
      for (final host in ThemeBrightness.values) {
        final theme = engine.resolveSelection(
          selection: const ThemeSelection(themeId: 'dark', mode: AuthorOsThemeMode.dark),
          hostBrightness: host,
        );
        expect(theme.brightness, ThemeBrightness.dark);
      }
    });

    test('system mode follows the supplied host brightness', () {
      final light = engine.resolveSelection(
        selection:
            const ThemeSelection(themeId: 'dark', mode: AuthorOsThemeMode.system),
        hostBrightness: ThemeBrightness.light,
      );
      final dark = engine.resolveSelection(
        selection:
            const ThemeSelection(themeId: 'dark', mode: AuthorOsThemeMode.system),
        hostBrightness: ThemeBrightness.dark,
      );
      // The dark theme has no light palette, so light host triggers fallback.
      expect(light.requestedBrightness, ThemeBrightness.light);
      expect(dark.brightness, ThemeBrightness.dark);
      expect(dark.fallbackApplied, isFalse);
    });

    test('explicit selection overrides system mode', () {
      final systemTheme = engine.resolveSelection(
        selection:
            const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.system),
        hostBrightness: ThemeBrightness.dark,
      );
      final explicitTheme = engine.resolveSelection(
        selection:
            const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
        hostBrightness: ThemeBrightness.dark,
      );
      expect(systemTheme.requestedBrightness, ThemeBrightness.dark);
      expect(explicitTheme.requestedBrightness, ThemeBrightness.light);
      expect(explicitTheme.brightness, ThemeBrightness.light);
      expect(explicitTheme.fallbackApplied, isFalse);
    });

    test('a theme that cannot render the requested mode falls back', () {
      // The light theme defines no dark palette.
      final theme = engine.resolveSelection(
        selection: const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.dark),
        hostBrightness: ThemeBrightness.dark,
      );
      expect(theme.requestedBrightness, ThemeBrightness.dark);
      expect(theme.brightness, ThemeBrightness.light);
      expect(theme.fallbackApplied, isTrue);
    });

    test('resolution never throws for any registered theme and mode', () {
      final registry = ThemeRegistry.standard();
      for (final id in registry.ids) {
        for (final mode in AuthorOsThemeMode.values) {
          for (final host in ThemeBrightness.values) {
            expect(
              () => engine.resolveSelection(
                selection: ThemeSelection(themeId: id, mode: mode),
                hostBrightness: host,
              ),
              returnsNormally,
            );
          }
        }
      }
    });
  });

  group('accessibility', () {
    test('high contrast raises foreground/background contrast', () {
      const selection =
          ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light);
      final plain = engine.resolveSelection(
        selection: selection,
        hostBrightness: ThemeBrightness.light,
      );
      final contrasted = engine.resolveSelection(
        selection: selection.copyWith(
          accessibility: const ThemeAccessibility(highContrast: true),
        ),
        hostBrightness: ThemeBrightness.light,
      );

      double ratio(ResolvedTheme theme) => ThemeColor.contrastRatio(
            theme.color(ThemeColorRef.onSurface),
            theme.color(ThemeColorRef.surface),
          );

      expect(ratio(contrasted), greaterThan(ratio(plain)));
      expect(contrasted.accessibility.highContrast, isTrue);
    });

    test('high contrast raises contrast in dark mode too', () {
      const selection = ThemeSelection(themeId: 'dark', mode: AuthorOsThemeMode.dark);
      final plain = engine.resolveSelection(
        selection: selection,
        hostBrightness: ThemeBrightness.dark,
      );
      final contrasted = engine.resolveSelection(
        selection: selection.copyWith(
          accessibility: const ThemeAccessibility(highContrast: true),
        ),
        hostBrightness: ThemeBrightness.dark,
      );
      final plainOutline = ThemeColor.contrastRatio(
        plain.color(ThemeColorRef.outline),
        plain.color(ThemeColorRef.surface),
      );
      final contrastedOutline = ThemeColor.contrastRatio(
        contrasted.color(ThemeColorRef.outline),
        contrasted.color(ThemeColorRef.surface),
      );
      expect(contrastedOutline, greaterThan(plainOutline));
    });

    test('reduced intensity softens accent without harming text contrast', () {
      const selection =
          ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light);
      final plain = engine.resolveSelection(
        selection: selection,
        hostBrightness: ThemeBrightness.light,
      );
      final reduced = engine.resolveSelection(
        selection: selection.copyWith(
          accessibility: const ThemeAccessibility(reduceIntensity: true),
        ),
        hostBrightness: ThemeBrightness.light,
      );

      expect(reduced.color(ThemeColorRef.primary),
          isNot(plain.color(ThemeColorRef.primary)));
      // Text roles must be untouched.
      expect(reduced.color(ThemeColorRef.onSurface),
          plain.color(ThemeColorRef.onSurface));
      expect(reduced.color(ThemeColorRef.onSurfaceVariant),
          plain.color(ThemeColorRef.onSurfaceVariant));
    });

    test('transformations compose and are recorded on the resolved theme', () {
      final theme = engine.resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
          accessibility:
              ThemeAccessibility(highContrast: true, reduceIntensity: true),
        ),
        hostBrightness: ThemeBrightness.light,
      );
      expect(theme.accessibility.highContrast, isTrue);
      expect(theme.accessibility.reduceIntensity, isTrue);
      expect(theme.accessibility.isActive, isTrue);
    });

    test('no accessibility options leaves the palette untouched', () {
      final definition = ThemeRegistry.standard().byId('light');
      final theme = const ThemeResolver().resolve(
        definition: definition,
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
      );
      for (final ref in ThemeColorRef.values) {
        expect(theme.color(ref),
            definition.paletteFor(ThemeBrightness.light)[ref]);
      }
    });
  });

  group('persistence and migration', () {
    test('a legacy id migrates to its canonical theme', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'obsidian',
      });
      engine = ThemeEngine.standard(store: store);

      final selection = await engine.load();
      expect(selection.themeId, 'dark');
      expect(store.values[ThemePersistence.themeIdKey], 'dark');
    });

    test('migration is non-destructive: the legacy id is preserved', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'midnight',
      });
      engine = ThemeEngine.standard(store: store);

      await engine.load();
      expect(engine.persistence.hasMigratedLegacyId, isTrue);
      expect(engine.persistence.migratedLegacyId, 'midnight');
    });

    test('migration is idempotent', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'plum',
      });
      engine = ThemeEngine.standard(store: store);

      final first = await engine.load();
      final snapshot = Map<String, String>.from(store.values);
      final second = await engine.load();
      final third = await engine.load();

      expect(first.themeId, 'dark');
      expect(second.themeId, 'dark');
      expect(third.themeId, 'dark');
      expect(store.values, snapshot);
      // The backup must record the original, not an intermediate rewrite.
      expect(engine.persistence.migratedLegacyId, 'plum');
    });

    test('an already-canonical id is not treated as a migration', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'dark',
      });
      engine = ThemeEngine.standard(store: store);

      await engine.load();
      expect(engine.persistence.hasMigratedLegacyId, isFalse);
      expect(store.values.containsKey(ThemePersistence.legacyIdBackupKey),
          isFalse);
    });

    test('migration is lazy: nothing is written until load runs', () {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'ocean',
      });
      ThemeEngine.standard(store: store);
      expect(store.values[ThemePersistence.themeIdKey], 'ocean');
    });

    test('a read-only launch still resolves the migrated theme', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'burgundy',
      })..readOnly = true;
      engine = ThemeEngine.standard(store: store);

      final selection = await engine.load();
      expect(selection.themeId, 'dark');
      // The write was rejected, so storage still holds the legacy value.
      expect(store.values[ThemePersistence.themeIdKey], 'burgundy');

      final theme = await engine.resolve(hostBrightness: ThemeBrightness.dark);
      expect(theme.themeId, 'dark');
    });

    test('a selection survives a reload through the same store', () async {
      await engine.load();
      await engine.select(
        selection: const ThemeSelection(
          themeId: 'dark',
          mode: AuthorOsThemeMode.dark,
          accessibility: ThemeAccessibility(highContrast: true),
        ),
        hostBrightness: ThemeBrightness.light,
      );

      final reloaded = ThemeEngine.standard(store: store);
      final selection = await reloaded.load();
      expect(selection.themeId, 'dark');
      expect(selection.mode, AuthorOsThemeMode.dark);
      expect(selection.accessibility.highContrast, isTrue);
    });

    test('mode persists across a reload', () async {
      await engine.load();
      await engine.selectMode(
        mode: AuthorOsThemeMode.system,
        hostBrightness: ThemeBrightness.light,
      );
      final reloaded = ThemeEngine.standard(store: store);
      expect((await reloaded.load()).mode, AuthorOsThemeMode.system);
    });

    test('a pre-engine install with no mode key reads an explicit mode',
        () async {
      // Pre-engine installs persisted a theme id but no mode. Defaulting to
      // system would silently change their appearance.
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'obsidian',
      });
      engine = ThemeEngine.standard(store: store);
      final selection = await engine.load();
      expect(selection.mode, AuthorOsThemeMode.dark);
      expect(selection.themeId, 'dark');
    });

    test('the accent id is preserved verbatim', () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.accentIdKey: 'teal',
      });
      engine = ThemeEngine.standard(store: store);
      expect((await engine.load()).accentId, 'teal');
    });

    test('an unknown persisted mode falls back rather than throwing',
        () async {
      store = MemoryThemeSettingsStore({
        ThemePersistence.themeIdKey: 'light',
        ThemePersistence.modeKey: 'psychedelic',
      });
      engine = ThemeEngine.standard(store: store);
      expect((await engine.load()).mode, AuthorOsThemeMode.light);
    });

    test('no storage namespace beyond the theme keys is written', () async {
      await engine.load();
      await engine.select(
        selection:
            const ThemeSelection(themeId: 'dark', mode: AuthorOsThemeMode.dark),
        hostBrightness: ThemeBrightness.dark,
      );
      const allowed = {
        ThemePersistence.themeIdKey,
        ThemePersistence.accentIdKey,
        ThemePersistence.modeKey,
        ThemePersistence.highContrastKey,
        ThemePersistence.reduceIntensityKey,
        ThemePersistence.legacyIdBackupKey,
      };
      expect(store.values.keys.toSet().difference(allowed), isEmpty);
    });
  });

  group('studio scope', () {
    test('a Studio without overrides inherits the shell palette', () {
      final theme = engine.resolveSelection(
        selection: const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
        hostBrightness: ThemeBrightness.light,
      );
      expect(theme.colorFor(StudioId.world, ThemeColorRef.primary),
          theme.color(ThemeColorRef.primary));
      expect(theme.paletteFor(StudioId.world).colors,
          theme.palette.colors);
    });

    test('a Studio override layers over the shell palette', () {
      final base = ThemeRegistry.standard().byId('light');
      final scoped = ThemeDefinition(
        id: base.id,
        name: base.name,
        description: base.description,
        palettes: base.palettes,
        typography: base.typography,
        metrics: base.metrics,
        studioOverrides: {
          StudioId.world: const {
            ThemeColorRef.primary: ThemeColor(0xFF2E7D32),
          },
        },
      );
      final theme = const ThemeResolver().resolve(
        definition: scoped,
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
      );

      expect(theme.colorFor(StudioId.world, ThemeColorRef.primary),
          const ThemeColor(0xFF2E7D32));
      // Unrelated roles and unrelated Studios still see the shell palette.
      expect(theme.colorFor(StudioId.world, ThemeColorRef.surface),
          theme.color(ThemeColorRef.surface));
      expect(theme.colorFor(StudioId.plot, ThemeColorRef.primary),
          theme.color(ThemeColorRef.primary));
      expect(theme.colorFor(null, ThemeColorRef.primary),
          theme.color(ThemeColorRef.primary));
    });

    test('Studio overrides receive accessibility transformations', () {
      final base = ThemeRegistry.standard().byId('light');
      final scoped = ThemeDefinition(
        id: base.id,
        name: base.name,
        description: base.description,
        palettes: base.palettes,
        typography: base.typography,
        metrics: base.metrics,
        studioOverrides: {
          StudioId.world: const {
            ThemeColorRef.primary: ThemeColor(0xFF2E7D32),
          },
        },
      );
      final reduced = const ThemeResolver().resolve(
        definition: scoped,
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
        accessibility: const ThemeAccessibility(reduceIntensity: true),
      );
      expect(reduced.colorFor(StudioId.world, ThemeColorRef.primary),
          isNot(const ThemeColor(0xFF2E7D32)));
    });
  });

  group('typography and component tokens', () {
    test('Inter drives UI and label roles; Merriweather stays the reading face',
        () {
      final theme = engine.resolveSelection(
        selection: const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
        hostBrightness: ThemeBrightness.light,
      );
      expect(theme.text(ThemeTextRole.ui).family, 'Inter');
      expect(theme.text(ThemeTextRole.label).family, 'Inter');
      expect(theme.text(ThemeTextRole.body).family, 'Merriweather');
      expect(theme.text(ThemeTextRole.heading).family, 'Merriweather');
    });

    test('the code role falls back to a monospace family', () {
      final theme = engine.resolveSelection(
        selection: const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
        hostBrightness: ThemeBrightness.light,
      );
      final code = theme.text(ThemeTextRole.code);
      expect(code.family, 'monospace');
      expect(code.fallbackFamilies, contains('monospace'));
    });

    test('Inter is declared as a font family in pubspec.yaml', () {
      // Bundling the TTFs under `assets:` alone leaves fontFamily: 'Inter'
      // unresolvable. Guards against a silent regression to that state.
      final lines = File('pubspec.yaml').readAsLinesSync();
      final fontsIndex =
          lines.indexWhere((line) => line.trimRight() == '  fonts:');
      expect(fontsIndex, isNonNegative, reason: 'no fonts: section');

      // The section ends at the next key indented two spaces or less.
      var end = lines.length;
      for (var i = fontsIndex + 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        final indent = line.length - line.trimLeft().length;
        if (indent <= 2 && line.trimRight().endsWith(':')) {
          end = i;
          break;
        }
      }
      final section = lines.sublist(fontsIndex, end);

      expect(section.any((line) => line.trim() == '- family: Inter'), isTrue,
          reason: 'Inter must be a registered family, not just an asset');
      expect(
        section.any((line) => line.contains('assets/fonts/Inter-400.ttf')),
        isTrue,
      );
      expect(
        section.any((line) => line.contains('assets/fonts/Inter-700.ttf')),
        isTrue,
      );
    });

    test('component metrics reproduce the pre-engine shell', () {
      final metrics = ThemeRegistry.standard().byId('light').metrics;
      expect(metrics.radius('card'), 20);
      expect(metrics.radius('chip'), 12);
      expect(metrics.radius('button'), 14);
      expect(metrics.radius('input'), 14);
      expect(metrics.focusRingWidth, 2);
    });

    test('an undefined metric name fails loudly', () {
      final metrics = ThemeRegistry.standard().byId('light').metrics;
      expect(() => metrics.radius('nope'), throwsStateError);
      expect(() => metrics.space('nope'), throwsStateError);
    });
  });

  group('palette values match the pre-engine shell', () {
    test('light palette', () {
      final palette =
          ThemeRegistry.standard().byId('light').paletteFor(ThemeBrightness.light);
      expect(palette[ThemeColorRef.background], const ThemeColor(0xFFF2F7FC));
      expect(palette[ThemeColorRef.surface], const ThemeColor(0xFFFFFFFF));
      expect(palette[ThemeColorRef.primary], const ThemeColor(0xFF4F8FCB));
      expect(palette[ThemeColorRef.onSurface], const ThemeColor(0xFF17283A));
      expect(palette[ThemeColorRef.outline], const ThemeColor(0xFF718399));
      expect(
          palette[ThemeColorRef.outlineVariant], const ThemeColor(0xFFD4E0EB));
      expect(palette[ThemeColorRef.surfaceContainer],
          const ThemeColor(0xFFE7F0F8));
    });

    test('dark palette', () {
      final palette =
          ThemeRegistry.standard().byId('dark').paletteFor(ThemeBrightness.dark);
      expect(palette[ThemeColorRef.background], const ThemeColor(0xFF080808));
      expect(palette[ThemeColorRef.surface], const ThemeColor(0xFF141414));
      expect(palette[ThemeColorRef.primary], const ThemeColor(0xFFD4AF37));
      expect(palette[ThemeColorRef.onSurface], const ThemeColor(0xFFFFFFFF));
      expect(palette[ThemeColorRef.outline], const ThemeColor(0xFF8A8A8A));
      expect(
          palette[ThemeColorRef.outlineVariant], const ThemeColor(0xFF363636));
      expect(palette[ThemeColorRef.surfaceContainer],
          const ThemeColor(0xFF202020));
    });

    test('both themes keep readable body contrast', () {
      // Mirrors the contract asserted by settings_theme_test.dart.
      for (final id in ['light', 'dark']) {
        final theme = engine.resolveSelection(
          selection: ThemeSelection(
            themeId: id,
            mode: id == 'dark' ? AuthorOsThemeMode.dark : AuthorOsThemeMode.light,
          ),
          hostBrightness:
              id == 'dark' ? ThemeBrightness.dark : ThemeBrightness.light,
        );
        final ratio = ThemeColor.contrastRatio(
          theme.color(ThemeColorRef.onSurface),
          theme.color(ThemeColorRef.surface),
        );
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$id body contrast');
      }
    });
  });

  group('colour maths', () {
    test('contrast ratio is symmetric and bounded', () {
      const black = ThemeColor(0xFF000000);
      const white = ThemeColor(0xFFFFFFFF);
      expect(ThemeColor.contrastRatio(black, white), closeTo(21.0, 0.01));
      expect(ThemeColor.contrastRatio(white, black), closeTo(21.0, 0.01));
      expect(ThemeColor.contrastRatio(white, white), closeTo(1.0, 0.001));
    });

    test('lerp clamps and hits both endpoints', () {
      const from = ThemeColor(0xFF000000);
      const to = ThemeColor(0xFFFFFFFF);
      expect(from.lerp(to, 0), from);
      expect(from.lerp(to, 1), to);
      expect(from.lerp(to, -5), from);
      expect(from.lerp(to, 5), to);
      expect(from.lerp(to, 0.5), const ThemeColor(0xFF808080));
    });

    test('channel extraction round-trips', () {
      const color = ThemeColor(0x8012AB34);
      expect(color.alpha, 0x80);
      expect(color.red, 0x12);
      expect(color.green, 0xAB);
      expect(color.blue, 0x34);
      expect(color.withAlpha(0xFF).value, 0xFF12AB34);
    });
  });

  group('architecture', () {
    test('the theme core is plain Dart and imports no Flutter', () {
      final coreFiles = Directory('lib/theme')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      expect(coreFiles, isNotEmpty);
      for (final file in coreFiles) {
        expect(file.readAsStringSync(), isNot(contains('package:flutter/')),
            reason: '${file.path} must stay plain Dart');
      }
    });

    test('the theme core does not depend on other AuthorOS systems', () {
      // Theme is presentation only: it must not reach into records,
      // progression, analytics, or community.
      final forbidden = [
        'core/connected_domain',
        'core/record',
        'persistence/authoros_database',
        'progression',
        'analytics',
        'community',
      ];
      final files = Directory('lib/theme')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final needle in forbidden) {
          expect(source, isNot(contains("import '$needle")),
              reason: '${file.path} must not import $needle');
          expect(source,
              isNot(contains("package:author_studio_v1/$needle")),
              reason: '${file.path} must not import $needle');
        }
      }
    });

    test('exactly one resolver and one engine class exist', () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect('class ThemeEngine '.allMatches(sources).length, 1);
      expect('class ThemeResolver '.allMatches(sources).length, 1);
      expect('class ThemeRegistry '.allMatches(sources).length, 1);
    });
  });
}
