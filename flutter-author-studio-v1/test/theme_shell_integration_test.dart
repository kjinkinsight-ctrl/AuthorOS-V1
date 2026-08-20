/// Theme Engine Phase 2 — application shell integration.
///
/// These tests assert the *live* path: the shell resolves through the engine
/// and hands the result to `MaterialApp`. They read the shell's own
/// `StudioThemeScope`, which carries the exact `ResolvedTheme` the running
/// application used, so nothing here re-derives a theme in order to check one.
library;

import 'dart:io';

import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the real application and settles it.
Future<void> _pumpApp(WidgetTester tester, {ManuscriptStore? store}) async {
  await tester.pumpWidget(AuthorStudioApp(
    manuscriptStore: store ?? const ManuscriptStore(),
    showWelcome: false,
  ));
  await tester.pumpAndSettle();
}

/// The `ThemeData` the running application handed to `MaterialApp`.
ThemeData _appTheme(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;

MaterialApp _materialApp(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

/// The `ResolvedTheme` the running application resolved, read from the scope
/// the shell installs above `MaterialApp`.
ResolvedTheme _appResolved(WidgetTester tester) =>
    tester.widgetList<StudioThemeScope>(find.byType(StudioThemeScope)).first.theme;

void main() {
  // 1. MaterialApp receives ThemeEngine output.
  group('MaterialApp consumes the Theme Engine', () {
    testWidgets('the theme is exactly the engine adapter output',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      final expected = AuthorOsTheme.toThemeData(resolved);
      final actual = _appTheme(tester);

      expect(actual.brightness, expected.brightness);
      expect(actual.colorScheme.primary, expected.colorScheme.primary);
      expect(actual.colorScheme.surface, expected.colorScheme.surface);
      expect(actual.colorScheme.onSurface, expected.colorScheme.onSurface);
      expect(actual.scaffoldBackgroundColor, expected.scaffoldBackgroundColor);
      expect(actual.textTheme.bodyMedium?.fontFamily,
          expected.textTheme.bodyMedium?.fontFamily);
    });

    testWidgets('every colour role in the theme comes from the resolved palette',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      final theme = _appTheme(tester);
      Color token(ThemeColorRef ref) => Color(resolved.color(ref).value);

      expect(theme.scaffoldBackgroundColor, token(ThemeColorRef.background));
      expect(theme.colorScheme.surface, token(ThemeColorRef.surface));
      expect(theme.colorScheme.primary, token(ThemeColorRef.primary));
      expect(theme.colorScheme.onPrimary, token(ThemeColorRef.onPrimary));
      expect(theme.colorScheme.onSurface, token(ThemeColorRef.onSurface));
      expect(theme.colorScheme.outline, token(ThemeColorRef.outline));
      expect(theme.colorScheme.outlineVariant,
          token(ThemeColorRef.outlineVariant));
      expect(theme.focusColor, token(ThemeColorRef.focusRing));
      expect(theme.textSelectionTheme.selectionColor,
          token(ThemeColorRef.selection));
    });

    test('the shell builds no ThemeData of its own', () {
      // A guard, not a style rule: if a second construction path reappears in
      // the shell, the engine stops being authoritative.
      final source = File('lib/main.dart').readAsStringSync();
      // Any `ThemeData(` not preceded by an identifier character is a
      // constructor call; `AuthorOsTheme.toThemeData(` is not.
      expect(RegExp(r'(?<![A-Za-z0-9_])ThemeData\(').hasMatch(source), isFalse,
          reason: 'main.dart must not construct ThemeData; '
              'AuthorOsTheme.toThemeData is the only builder.');
      expect(source, isNot(contains('_buildThemeData')));
      expect(source, isNot(contains('ColorScheme.fromSeed')),
          reason: 'palette derivation belongs to the engine adapter');
    });

    // 11. No duplicate theme preference persistence.
    test('the shell persists no theme preference of its own', () {
      final source = File('lib/main.dart').readAsStringSync();

      // The shell still uses SharedPreferences for profile data. What it must
      // not do is read or write a *theme* key directly: those belong to
      // ThemePersistence, reached only through SharedPreferencesThemeStore.
      for (final key in const [
        'author_studio.theme_id',
        'author_studio.accent_id',
        'author_studio.theme.mode',
        'author_studio.theme.high_contrast',
        'author_studio.theme.reduce_intensity',
        'author_studio.theme.legacy_id',
      ]) {
        expect(source, isNot(contains(key)),
            reason: 'main.dart must not touch "$key"; ThemePersistence owns it');
      }
      expect(source, isNot(contains('_themePreferenceKey')));
      expect(source, isNot(contains('_accentPreferenceKey')));
      expect(source, contains('SharedPreferencesThemeStore'),
          reason: 'the one theme store the shell may use');
    });

    test('exactly one theme persistence layer defines the theme keys', () {
      // Every theme storage key is declared once, in ThemePersistence.
      final themeKeys = [
        ThemePersistence.themeIdKey,
        ThemePersistence.accentIdKey,
        ThemePersistence.modeKey,
        ThemePersistence.highContrastKey,
        ThemePersistence.reduceIntensityKey,
        ThemePersistence.legacyIdBackupKey,
      ];
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('main.authorstudio.backup'));
      for (final key in themeKeys) {
        final declaring = sources
            .where((file) => file.readAsStringSync().contains("'$key'"))
            .map((file) => file.path)
            .toList();
        expect(declaring, ['lib/theme/theme_persistence.dart'],
            reason: '"$key" must be declared only by ThemePersistence');
      }
    });
  });

  // 12. Existing visual compatibility is intact.
  group('visual compatibility with the pre-engine shell', () {
    testWidgets('the light theme still renders the shell palette',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
      });
      await _pumpApp(tester);
      final theme = _appTheme(tester);

      // The exact values the pre-engine shell used. They must survive the move
      // onto the engine unchanged.
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F7FC));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF17283A));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF17283A));
      expect(theme.colorScheme.outline, const Color(0xFF718399));
      expect(theme.colorScheme.outlineVariant, const Color(0xFFD4E0EB));
      expect(theme.chipTheme.backgroundColor, const Color(0xFFE7F0F8));
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFFE7F0F8));
      expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(theme.brightness, Brightness.light);
    });

    testWidgets('the dark theme still renders the shell palette',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
      });
      await _pumpApp(tester);
      final theme = _appTheme(tester);

      expect(theme.scaffoldBackgroundColor, const Color(0xFF080808));
      expect(theme.colorScheme.surface, const Color(0xFF141414));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.outline, const Color(0xFF8A8A8A));
      expect(theme.colorScheme.outlineVariant, const Color(0xFF363636));
      expect(theme.chipTheme.backgroundColor, const Color(0xFF202020));
      expect(theme.cardTheme.color, const Color(0xFF141414));
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('component shapes and padding are unchanged', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpApp(tester);
      final theme = _appTheme(tester);

      double radiusOf(ShapeBorder? shape) =>
          ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
              .topLeft
              .x;

      // Card 20, chip 12, input 14, button 14 — the pre-engine values.
      expect(radiusOf(theme.cardTheme.shape), 20);
      expect(radiusOf(theme.chipTheme.shape), 12);
      expect(
        (theme.inputDecorationTheme.border! as OutlineInputBorder)
            .borderRadius
            .topLeft
            .x,
        14,
      );
      expect(radiusOf(theme.filledButtonTheme.style?.shape?.resolve({})), 14);
      expect(theme.chipTheme.padding,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
      expect(theme.filledButtonTheme.style?.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12));
      expect(theme.cardTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.centerTitle, isFalse);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.useMaterial3, isTrue);
    });
  });

  // 2. Default theme resolves correctly.
  group('default resolution', () {
    testWidgets('a first launch with no stored settings resolves the '
        'registry default', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.themeId, ThemeRegistry.standard().defaultThemeId);
      expect(resolved.themeId, 'light');
      expect(resolved.brightness, ThemeBrightness.light);
      expect(resolved.fallbackApplied, isFalse);
      expect(_appTheme(tester).brightness, Brightness.light);
    });
  });

  // 3, 4. Explicit light and dark.
  group('explicit modes', () {
    testWidgets('explicit light renders the light ThemeData even on a dark host',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.mode': 'light',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedMode, AuthorOsThemeMode.light);
      expect(resolved.brightness, ThemeBrightness.light);
      expect(resolved.fallbackApplied, isFalse);
      expect(_appTheme(tester).brightness, Brightness.light);
      expect(_materialApp(tester).themeMode, ThemeMode.light);
    });

    testWidgets('explicit dark renders the dark ThemeData even on a light host',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
        'author_studio.theme.mode': 'dark',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedMode, AuthorOsThemeMode.dark);
      expect(resolved.brightness, ThemeBrightness.dark);
      expect(resolved.fallbackApplied, isFalse);
      expect(_appTheme(tester).brightness, Brightness.dark);
      expect(_materialApp(tester).themeMode, ThemeMode.dark);
      expect(_appTheme(tester).scaffoldBackgroundColor,
          const Color(0xFF080808));
    });
  });

  // 5. System mode.
  group('system mode', () {
    testWidgets('a dark host drives a dark resolution', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
        'author_studio.theme.mode': 'system',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedMode, AuthorOsThemeMode.system);
      expect(resolved.requestedBrightness, ThemeBrightness.dark,
          reason: 'the host brightness must reach the engine');
      expect(resolved.brightness, ThemeBrightness.dark);
      expect(resolved.fallbackApplied, isFalse);
      expect(_appTheme(tester).brightness, Brightness.dark);
      expect(_materialApp(tester).themeMode, ThemeMode.system);
    });

    testWidgets('a light host drives a light resolution', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.mode': 'system',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedBrightness, ThemeBrightness.light);
      expect(resolved.brightness, ThemeBrightness.light);
      expect(resolved.fallbackApplied, isFalse);
      expect(_appTheme(tester).brightness, Brightness.light);
    });

    testWidgets('a host brightness change re-resolves without a restart',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
        'author_studio.theme.mode': 'system',
      });
      await _pumpApp(tester);
      expect(_appResolved(tester).requestedBrightness, ThemeBrightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(_appResolved(tester).requestedBrightness, ThemeBrightness.dark);
      expect(_appTheme(tester).brightness, Brightness.dark);
    });
  });

  // 6. Unsupported brightness uses the Phase 1 fallback.
  group('Phase 1 fallback survives integration', () {
    testWidgets('a light-only theme on a dark host falls back rather than '
        'rendering an unsupported brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.mode': 'system',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedBrightness, ThemeBrightness.dark);
      expect(resolved.brightness, ThemeBrightness.light,
          reason: 'the light theme defines no dark palette');
      expect(resolved.fallbackApplied, isTrue);
      expect(_appTheme(tester).brightness, Brightness.light,
          reason: 'MaterialApp must render the fallback, not an empty palette');
    });

    testWidgets('a dark-only theme asked for light falls back to dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
        'author_studio.theme.mode': 'light',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.requestedBrightness, ThemeBrightness.light);
      expect(resolved.brightness, ThemeBrightness.dark);
      expect(resolved.fallbackApplied, isTrue);
      expect(_appTheme(tester).brightness, Brightness.dark);
    });
  });

  // 7. Legacy theme ids migrate.
  group('legacy settings compatibility', () {
    for (final entry in const {
      'paper': 'light',
      'slate': 'light',
      'obsidian': 'dark',
      'midnight': 'dark',
      'forest': 'dark',
      'burgundy': 'dark',
      'plum': 'dark',
      'ocean': 'dark',
    }.entries) {
      testWidgets('a stored "${entry.key}" launches as ${entry.value}',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'author_studio.theme_id': entry.key,
        });
        await _pumpApp(tester);

        final resolved = _appResolved(tester);
        expect(resolved.themeId, entry.value);
        expect(
          _appTheme(tester).brightness,
          entry.value == 'dark' ? Brightness.dark : Brightness.light,
          reason: 'a legacy install must keep the brightness it had',
        );

        // Migration is non-destructive and rewrites the canonical key.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('author_studio.theme_id'), entry.value);
        expect(prefs.getString('author_studio.theme.legacy_id'), entry.key);
      });
    }

    testWidgets('an unknown stored id falls back to the default theme',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'not-a-theme',
      });
      await _pumpApp(tester);

      expect(_appResolved(tester).themeId, 'light');
    });

    test('the retained legacy AppThemePreset agrees with the registry', () {
      // AppThemePreset survives only for test/settings_theme_test.dart. Pinning
      // it against the registry here means the two normalizations cannot drift.
      final registry = ThemeRegistry.standard();
      for (final id in const [
        'light',
        'dark',
        'paper',
        'slate',
        'obsidian',
        'midnight',
        'forest',
        'burgundy',
        'plum',
        'ocean',
        'unknown',
        '',
      ]) {
        expect(registry.normalizeId(id), AppThemePreset.normalizeId(id),
            reason: 'legacy id "$id" must normalize identically');
      }
      expect(registry.normalizeId(null), AppThemePreset.normalizeId(null));
    });
  });

  // 8. Theme changes update the application.
  group('runtime theme changes', () {
    testWidgets('choosing Dark in Settings rebuilds the application theme',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      SharedPreferences.setMockInitialValues({
        'author_studio.profile_setup_complete': true,
        'author_studio.profile.name': 'Ari Rowan',
        'author_studio.profile.email': 'ari@example.com',
        'author_studio.starter_project': '{"title":"Northstar"}',
        'author_studio.onboarding_complete': true,
        'author_studio.theme_id': 'light',
      });

      await _pumpApp(
        tester,
        store: ManuscriptStore(
          repository: DriftConnectedDomainRepository(database),
        ),
      );
      await tester.tap(find.text('Continue with selected profile'));
      await tester.pumpAndSettle();

      expect(_appTheme(tester).brightness, Brightness.light);

      await tester.tap(find.text('Theme').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      final dark = find.text('Dark');
      await tester.ensureVisible(dark);
      await tester.tap(dark);
      await tester.pumpAndSettle();

      expect(_appTheme(tester).brightness, Brightness.dark,
          reason: 'setState on the selection must re-resolve the engine');
      expect(_appResolved(tester).themeId, 'dark');
      expect(_appResolved(tester).fallbackApplied, isFalse,
          reason: 'picking a theme also fixes its natural mode');

      // The choice reached persistence through ThemePersistence, not through a
      // second settings store.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('author_studio.theme_id'), 'dark');
      expect(prefs.getString('author_studio.theme.mode'), 'dark');
    });
  });

  // 9. Accessibility state reaches the engine.
  group('accessibility flows through the engine', () {
    testWidgets('persisted high contrast reaches the resolved theme',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.high_contrast': 'true',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.accessibility.highContrast, isTrue);

      final plain = ThemeEngine.standard(store: MemoryThemeSettingsStore())
          .resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
        ),
        hostBrightness: ThemeBrightness.light,
      );
      double contrast(ResolvedTheme theme) => ThemeColor.contrastRatio(
            theme.color(ThemeColorRef.onSurface),
            theme.color(ThemeColorRef.surface),
          );
      expect(contrast(resolved), greaterThan(contrast(plain)),
          reason: 'the engine transformation, not a widget, raised contrast');
      // The transformed palette is what MaterialApp received.
      expect(_appTheme(tester).colorScheme.onSurface,
          Color(resolved.color(ThemeColorRef.onSurface).value));
    });

    testWidgets('persisted reduced intensity softens the accent',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.reduce_intensity': 'true',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.accessibility.reduceIntensity, isTrue);
      expect(resolved.color(ThemeColorRef.primary).value,
          isNot(0xFF4F8FCB));
      expect(_appTheme(tester).colorScheme.primary,
          Color(resolved.color(ThemeColorRef.primary).value));
    });

    testWidgets('focus ring, selection, and highlight carry the transformation',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.theme.high_contrast': 'true',
        'author_studio.theme.reduce_intensity': 'true',
      });
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.accessibility.highContrast, isTrue);
      expect(resolved.accessibility.reduceIntensity, isTrue);
      for (final ref in const [
        ThemeColorRef.focusRing,
        ThemeColorRef.selection,
        ThemeColorRef.highlight,
      ]) {
        expect(resolved.color(ref).value, isNot(0),
            reason: '${ref.name} must still resolve');
      }
      final theme = _appTheme(tester);
      expect(theme.focusColor, Color(resolved.color(ThemeColorRef.focusRing).value));
      expect(theme.textSelectionTheme.selectionColor,
          Color(resolved.color(ThemeColorRef.selection).value));
      expect(
        (theme.inputDecorationTheme.focusedBorder as OutlineInputBorder)
            .borderSide
            .width,
        resolved.metrics.focusRingWidth,
      );
    });

    testWidgets('a host high-contrast request reaches the engine without '
        'being persisted', (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
      });
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(highContrast: true),
        child: AuthorStudioApp(showWelcome: false),
      ));
      await tester.pumpAndSettle();

      expect(_appResolved(tester).accessibility.highContrast, isTrue,
          reason: 'the platform request must reach ThemeEngine');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('author_studio.theme.high_contrast'), isNull,
          reason: 'an OS setting is not the user\'s saved preference');
    });
  });

  // 10, 11. Fonts.
  group('typography', () {
    testWidgets('Inter resolves for UI and label roles', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.text(ThemeTextRole.ui).family, 'Inter');
      expect(resolved.text(ThemeTextRole.label).family, 'Inter');

      final theme = _appTheme(tester);
      expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.labelMedium?.fontFamily, 'Inter');
      expect(theme.chipTheme.labelStyle?.fontFamily, 'Inter');
    });

    testWidgets('Merriweather remains the reading face', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpApp(tester);

      final resolved = _appResolved(tester);
      expect(resolved.text(ThemeTextRole.body).family, 'Merriweather');
      expect(resolved.text(ThemeTextRole.heading).family, 'Merriweather');

      final theme = _appTheme(tester);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Merriweather');
      expect(theme.textTheme.bodySmall?.fontFamily, 'Merriweather');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Merriweather');
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Merriweather',
          reason: 'roles the engine does not override still read Merriweather');
    });
  });

  // 12. StudioThemeScope.
  group('StudioThemeScope integration', () {
    testWidgets('the shell installs a scope carrying the resolved theme',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'dark',
      });
      await _pumpApp(tester);

      final scopes = tester.widgetList<StudioThemeScope>(
        find.byType(StudioThemeScope),
      );
      expect(scopes, isNotEmpty);
      final shell = scopes.first;
      expect(shell.studio, isNull, reason: 'the root scope is shell chrome');
      expect(shell.theme.themeId, 'dark');
      expect(Color(shell.theme.color(ThemeColorRef.background).value),
          _appTheme(tester).scaffoldBackgroundColor);
    });

    testWidgets('a real Studio surface resolves its own StudioId and tokens',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final database = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final resolved = ThemeEngine.standard(store: MemoryThemeSettingsStore())
          .resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
        ),
        hostBrightness: ThemeBrightness.light,
      );

      // The real shell, under the scope the application installs at its root.
      await tester.pumpWidget(StudioThemeScope(
        theme: resolved,
        child: MaterialApp(
          theme: AuthorOsTheme.toThemeData(resolved),
          home: AuthorStudioShell(
            project: NovelStarterKit.create(
              title: 'Northstar',
              genre: 'Fantasy',
              projectType: 'Novel',
              wordGoal: 80000,
            ),
            manuscriptStore: ManuscriptStore(
              repository: DriftConnectedDomainRepository(database),
            ),
            themeId: 'light',
            accentId: 'default',
            onThemeChanged: (_, __) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chapters').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(scopes.length, greaterThan(1),
          reason: 'the Studio section nests a scope under the shell scope');

      final studioScope = scopes.last;
      expect(studioScope.studio, StudioId.manuscript);
      // The Studio receives the same resolved theme the shell resolved, and
      // token lookup falls back to the shell palette where it overrides none.
      expect(studioScope.theme.themeId, scopes.first.theme.themeId);
      expect(studioScope.color(ThemeColorRef.surface),
          Color(scopes.first.theme.color(ThemeColorRef.surface).value));
      expect(studioScope.space('md'), studioScope.theme.metrics.space('md'));
      expect(studioScope.radius('card'),
          studioScope.theme.metrics.radius('card'));
    });

    test('every Studio section maps onto a token-scoped identity or the shell',
        () {
      // A section must not silently acquire a Studio id that the engine has no
      // StudioId for.
      const mapped = {
        StudioSection.characters: StudioId.character,
        StudioSection.codex: StudioId.storyCodex,
        StudioSection.world: StudioId.world,
        StudioSection.timeline: StudioId.timeline,
        StudioSection.plot: StudioId.plot,
        StudioSection.manuscript: StudioId.manuscript,
        StudioSection.chapters: StudioId.manuscript,
      };
      for (final section in StudioSection.values) {
        expect(sectionStudioId(section), mapped[section],
            reason: '${section.name} maps to the wrong Studio identity');
      }
    });
  });
}
