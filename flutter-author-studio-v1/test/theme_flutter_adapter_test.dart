import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_resolver.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ResolvedTheme _resolve({
  String themeId = 'light',
  AuthorOsThemeMode mode = AuthorOsThemeMode.light,
  ThemeBrightness host = ThemeBrightness.light,
  ThemeAccessibility accessibility = ThemeAccessibility.none,
}) =>
    ThemeEngine.standard(store: MemoryThemeSettingsStore()).resolveSelection(
      selection: ThemeSelection(
        themeId: themeId,
        mode: mode,
        accessibility: accessibility,
      ),
      hostBrightness: host,
    );

void main() {
  group('ThemeData derives from ResolvedTheme', () {
    test('light theme maps every colour role onto the scheme', () {
      final resolved = _resolve();
      final data = AuthorOsTheme.toThemeData(resolved);

      expect(data.brightness, Brightness.light);
      expect(data.colorScheme.primary,
          Color(resolved.color(ThemeColorRef.primary).value));
      expect(data.colorScheme.onSurface,
          Color(resolved.color(ThemeColorRef.onSurface).value));
      expect(data.colorScheme.outline,
          Color(resolved.color(ThemeColorRef.outline).value));
      expect(data.colorScheme.outlineVariant,
          Color(resolved.color(ThemeColorRef.outlineVariant).value));
      expect(data.scaffoldBackgroundColor,
          Color(resolved.color(ThemeColorRef.background).value));
    });

    test('dark theme maps every colour role onto the scheme', () {
      final resolved = _resolve(
        themeId: 'dark',
        mode: AuthorOsThemeMode.dark,
        host: ThemeBrightness.dark,
      );
      final data = AuthorOsTheme.toThemeData(resolved);

      expect(data.brightness, Brightness.dark);
      expect(data.colorScheme.primary,
          Color(resolved.color(ThemeColorRef.primary).value));
      expect(data.scaffoldBackgroundColor,
          Color(resolved.color(ThemeColorRef.background).value));
    });

    test('component shapes come from theme metrics, not literals', () {
      final resolved = _resolve();
      final data = AuthorOsTheme.toThemeData(resolved);

      BorderRadius radiusOf(ShapeBorder? shape) =>
          (shape as RoundedRectangleBorder).borderRadius as BorderRadius;

      expect(radiusOf(data.cardTheme.shape).topLeft.x,
          resolved.metrics.radius('card'));
      expect(radiusOf(data.chipTheme.shape).topLeft.x,
          resolved.metrics.radius('chip'));
      expect(
        (data.inputDecorationTheme.border as OutlineInputBorder)
            .borderRadius
            .topLeft
            .x,
        resolved.metrics.radius('input'),
      );
    });

    test('the focus ring uses the focusRing token and its width', () {
      final resolved = _resolve();
      final data = AuthorOsTheme.toThemeData(resolved);
      final focused =
          data.inputDecorationTheme.focusedBorder as OutlineInputBorder;

      expect(focused.borderSide.color,
          Color(resolved.color(ThemeColorRef.focusRing).value));
      expect(focused.borderSide.width, resolved.metrics.focusRingWidth);
    });

    test('the selection token drives text selection', () {
      final resolved = _resolve();
      final data = AuthorOsTheme.toThemeData(resolved);
      expect(data.textSelectionTheme.selectionColor,
          Color(resolved.color(ThemeColorRef.selection).value));
    });

    test('accessibility transformations reach ThemeData', () {
      final plain = AuthorOsTheme.toThemeData(_resolve());
      final contrasted = AuthorOsTheme.toThemeData(_resolve(
        accessibility: const ThemeAccessibility(highContrast: true),
      ));
      expect(contrasted.colorScheme.onSurface,
          isNot(plain.colorScheme.onSurface));
    });

    test('body typography resolves to Merriweather', () {
      // Preserves the contract asserted by settings_theme_test.dart.
      final data = AuthorOsTheme.toThemeData(_resolve());
      expect(data.textTheme.bodyMedium?.fontFamily, 'Merriweather');
    });

    test('UI and label typography resolve to Inter', () {
      final data = AuthorOsTheme.toThemeData(_resolve());
      expect(data.textTheme.labelLarge?.fontFamily, 'Inter');
      expect(data.textTheme.titleMedium?.fontFamily, 'Inter');
    });

    test('font weights map onto the nearest FontWeight', () {
      expect(AuthorOsTheme.fontWeight(400), FontWeight.w400);
      expect(AuthorOsTheme.fontWeight(500), FontWeight.w500);
      expect(AuthorOsTheme.fontWeight(700), FontWeight.w700);
      expect(AuthorOsTheme.fontWeight(950), FontWeight.w900);
      expect(AuthorOsTheme.fontWeight(50), FontWeight.w100);
    });

    test('a fallback resolution still produces renderable ThemeData', () {
      // The light theme has no dark palette; the resolver falls back.
      final resolved = _resolve(
        themeId: 'light',
        mode: AuthorOsThemeMode.dark,
        host: ThemeBrightness.dark,
      );
      expect(resolved.fallbackApplied, isTrue);
      expect(() => AuthorOsTheme.toThemeData(resolved), returnsNormally);
      expect(AuthorOsTheme.toThemeData(resolved).brightness, Brightness.light);
    });
  });

  group('StudioThemeScope', () {
    testWidgets('resolves shell tokens when no Studio is set', (tester) async {
      final resolved = _resolve();
      late Color primary;

      await tester.pumpWidget(
        StudioThemeScope(
          theme: resolved,
          child: Builder(
            builder: (context) {
              primary = StudioThemeScope.of(context).color(ThemeColorRef.primary);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(primary, Color(resolved.color(ThemeColorRef.primary).value));
    });

    testWidgets('a Studio scope resolves its own override', (tester) async {
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
      final resolved = const ThemeResolver().resolve(
        definition: scoped,
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
      );

      late Color worldPrimary;
      late Color shellPrimary;

      await tester.pumpWidget(
        StudioThemeScope(
          theme: resolved,
          child: Builder(
            builder: (outer) {
              shellPrimary =
                  StudioThemeScope.of(outer).color(ThemeColorRef.primary);
              return StudioThemeScope(
                theme: resolved,
                studio: StudioId.world,
                child: Builder(
                  builder: (inner) {
                    worldPrimary = StudioThemeScope.of(inner)
                        .color(ThemeColorRef.primary);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(worldPrimary, const Color(0xFF2E7D32));
      expect(shellPrimary, isNot(const Color(0xFF2E7D32)));
    });

    testWidgets('exposes typography, spacing, and radii', (tester) async {
      final resolved = _resolve();
      late TextStyle uiStyle;
      late double cardRadius;
      late double mediumSpace;

      await tester.pumpWidget(
        StudioThemeScope(
          theme: resolved,
          child: Builder(
            builder: (context) {
              final scope = StudioThemeScope.of(context);
              uiStyle = scope.text(ThemeTextRole.ui);
              cardRadius = scope.radius('card');
              mediumSpace = scope.space('md');
              return const SizedBox();
            },
          ),
        ),
      );

      expect(uiStyle.fontFamily, 'Inter');
      expect(cardRadius, 20);
      expect(mediumSpace, 12);
    });

    testWidgets('throws a clear error when no scope is installed',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(StudioThemeScope.maybeOf(context), isNull);
            expect(() => StudioThemeScope.of(context), throwsFlutterError);
            return const SizedBox();
          },
        ),
      );
    });
  });

  group('SharedPreferencesThemeStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips a value through SharedPreferences', () async {
      final store = await SharedPreferencesThemeStore.load();
      expect(store.read(ThemePersistence.themeIdKey), isNull);
      expect(await store.write(ThemePersistence.themeIdKey, 'dark'), isTrue);
      expect(store.read(ThemePersistence.themeIdKey), 'dark');
    });

    test('migrates a legacy id persisted by the pre-engine shell', () async {
      SharedPreferences.setMockInitialValues({
        ThemePersistence.themeIdKey: 'obsidian',
      });
      final engine = ThemeEngine.standard(
        store: await SharedPreferencesThemeStore.load(),
      );
      final selection = await engine.load();

      expect(selection.themeId, 'dark');
      expect(selection.mode, AuthorOsThemeMode.dark);

      final theme = await engine.resolve(hostBrightness: ThemeBrightness.light);
      expect(theme.brightness, ThemeBrightness.dark);
      expect(AuthorOsTheme.toThemeData(theme).brightness, Brightness.dark);
    });
  });
}
