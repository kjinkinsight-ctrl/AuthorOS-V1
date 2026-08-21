import 'dart:io';

import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Engine Phase 3 — application-wide theme consumption.
///
/// `theme_engine_test.dart` proves the engine is correct in isolation and
/// `theme_flutter_adapter_test.dart` proves the adapter maps tokens onto
/// Flutter types. This file proves the *application* actually consumes that
/// engine: one ThemeData boundary, one persistence path, and a Studio scope
/// over every section.
void main() {
  const starterProjectJson =
      '{"id":"saved-project","title":"Hidden Draft","genre":"Fantasy",'
      '"projectType":"Novel","wordGoal":80000,"acts":["Act I"],'
      '"chapters":[{"title":"Chapter 1","prompt":"Intro"}],'
      '"characterSheets":[{"name":"Hero","role":"Main"}],'
      '"beatChecklist":["Opening"],"firstSceneTitle":"Opening Scene"}';

  setUp(() => debugDisableAuroraAnimation = true);
  tearDown(() => debugDisableAuroraAnimation = false);

  /// Mounts the real application past startup, so the shell and its Studio
  /// scopes are reachable.
  ///
  /// Startup always presents the profile gate, so the helper signs in with
  /// the stored profile rather than trying to bypass it. Startup composition
  /// is not under test here and is not modified.
  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.profile_setup_complete': true,
      'author_studio.onboarding_complete': true,
      'author_studio.profile.name': 'Ari Rowan',
      'author_studio.profile.email': 'ari@example.com',
      'author_studio.starter_project': starterProjectJson,
      ...preferences,
    });
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.physicalSize = const Size(1920, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AuthorStudioApp(
        showWelcome: false,
        manuscriptStore: ManuscriptStore(
          repository: DriftConnectedDomainRepository(database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final signIn = find.text('Continue with selected profile');
    if (signIn.evaluate().isNotEmpty) {
      await tester.tap(signIn);
      await tester.pumpAndSettle();
    }
  }

  MaterialApp materialApp(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  /// Runs [action], tolerating the pre-existing RenderFlex overflows some
  /// Studios show at test viewport sizes.
  ///
  /// Those overflows are layout defects that predate this phase and are not
  /// in scope here — see the Phase 3 map, "Known limitations". Any error that
  /// is not an overflow still fails the test, so this hides nothing else.
  Future<void> toleratingOverflow(
    Future<void> Function() action,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    try {
      await action();
    } finally {
      FlutterError.onError = previous;
    }
    final unexpected = captured
        .where((details) => !details.exceptionAsString().contains('overflowed'))
        .map((details) => details.exceptionAsString())
        .toList();
    expect(unexpected, isEmpty, reason: unexpected.join('\n'));
  }

  ThemeData engineThemeData(String themeId, ThemeBrightness brightness) {
    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    return AuthorOsTheme.toThemeData(
      engine.resolveSelection(
        selection: ThemeSelection(
          themeId: themeId,
          mode: brightness == ThemeBrightness.dark
              ? AuthorOsThemeMode.dark
              : AuthorOsThemeMode.light,
        ),
        hostBrightness: brightness,
      ),
    );
  }

  group('one ThemeData boundary', () {
    testWidgets('the application ThemeData comes from the Theme Engine',
        (tester) async {
      await pumpApp(tester);
      final app = materialApp(tester);

      final expectedLight = engineThemeData('light', ThemeBrightness.light);
      expect(app.theme!.colorScheme.surface, expectedLight.colorScheme.surface);
      expect(app.theme!.colorScheme.primary, expectedLight.colorScheme.primary);
      expect(
        app.theme!.scaffoldBackgroundColor,
        expectedLight.scaffoldBackgroundColor,
      );
    });

    testWidgets('both brightness slots are supplied so system mode resolves',
        (tester) async {
      await pumpApp(tester);
      final app = materialApp(tester);

      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
      expect(
        app.darkTheme!.colorScheme.surface,
        engineThemeData('dark', ThemeBrightness.dark).colorScheme.surface,
      );
    });

    testWidgets('the shell palette reaches rendered widgets', (tester) async {
      await pumpApp(tester);

      final context = tester.element(find.byType(Scaffold).first);
      final rendered = Theme.of(context);
      final expected = engineThemeData('light', ThemeBrightness.light);

      expect(rendered.colorScheme.surface, expected.colorScheme.surface);
      expect(rendered.colorScheme.onSurface, expected.colorScheme.onSurface);
      expect(rendered.textTheme.bodyMedium?.fontFamily, 'Merriweather');
    });
  });

  group('theme switching', () {
    testWidgets('light to dark rebuilds the application theme',
        (tester) async {
      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'light',
        ThemePersistence.modeKey: 'light',
      });
      expect(materialApp(tester).themeMode, ThemeMode.light);

      final shell = tester.widget<AuthorStudioShell>(
        find.byType(AuthorStudioShell),
      );
      shell.onThemeChanged('dark', 'default');
      await tester.pumpAndSettle();

      expect(materialApp(tester).themeMode, ThemeMode.dark);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).colorScheme.surface,
        engineThemeData('dark', ThemeBrightness.dark).colorScheme.surface,
      );
    });

    testWidgets('dark to light rebuilds the application theme',
        (tester) async {
      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'dark',
        ThemePersistence.modeKey: 'dark',
      });
      expect(materialApp(tester).themeMode, ThemeMode.dark);

      final shell = tester.widget<AuthorStudioShell>(
        find.byType(AuthorStudioShell),
      );
      shell.onThemeChanged('light', 'default');
      await tester.pumpAndSettle();

      expect(materialApp(tester).themeMode, ThemeMode.light);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('system mode follows a light host', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'dark',
        ThemePersistence.modeKey: 'system',
      });

      expect(materialApp(tester).themeMode, ThemeMode.system);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(
        Theme.of(context).colorScheme.surface,
        engineThemeData('light', ThemeBrightness.light).colorScheme.surface,
      );
    });

    testWidgets('system mode follows a dark host', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'light',
        ThemePersistence.modeKey: 'system',
      });

      expect(materialApp(tester).themeMode, ThemeMode.system);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).colorScheme.surface,
        engineThemeData('dark', ThemeBrightness.dark).colorScheme.surface,
      );
    });
  });

  group('persistence survives restart', () {
    testWidgets('a theme chosen in one session is restored in the next',
        (tester) async {
      await pumpApp(tester);
      expect(materialApp(tester).themeMode, ThemeMode.light);

      tester
          .widget<AuthorStudioShell>(find.byType(AuthorStudioShell))
          .onThemeChanged('dark', 'default');
      await tester.pumpAndSettle();
      expect(materialApp(tester).themeMode, ThemeMode.dark);

      // The engine wrote through to SharedPreferences; a fresh engine over the
      // same store must read the same selection back.
      final store = await SharedPreferencesThemeStore.load();
      expect(store.read(ThemePersistence.themeIdKey), 'dark');
      expect(store.read(ThemePersistence.modeKey), 'dark');

      final restored = await ThemeEngine.standard(store: store).load();
      expect(restored.themeId, 'dark');
      expect(restored.mode, AuthorOsThemeMode.dark);
    });

    testWidgets('a persisted dark selection launches dark', (tester) async {
      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'dark',
        ThemePersistence.modeKey: 'dark',
      });

      expect(materialApp(tester).themeMode, ThemeMode.dark);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('the shell never writes theme preferences itself',
        (tester) async {
      // A legacy id must be migrated by ThemePersistence, not by the shell.
      await pumpApp(tester, preferences: {
        ThemePersistence.themeIdKey: 'obsidian',
      });

      final store = await SharedPreferencesThemeStore.load();
      expect(store.read(ThemePersistence.themeIdKey), 'dark');
      expect(store.read(ThemePersistence.legacyIdBackupKey), 'obsidian');
      expect(materialApp(tester).themeMode, ThemeMode.dark);
    });
  });

  group('Studio scope', () {
    test('every section maps onto a registered Studio identity', () {
      const expected = <StudioSection, StudioId>{
        StudioSection.manuscript: StudioId.manuscript,
        StudioSection.chapters: StudioId.manuscript,
        StudioSection.characters: StudioId.character,
        StudioSection.codex: StudioId.storyCodex,
        StudioSection.world: StudioId.world,
        StudioSection.plot: StudioId.plot,
        StudioSection.timeline: StudioId.timeline,
        StudioSection.dashboard: StudioId.shell,
        StudioSection.search: StudioId.shell,
        StudioSection.statistics: StudioId.shell,
        StudioSection.backup: StudioId.shell,
        StudioSection.projects: StudioId.shell,
        StudioSection.ideas: StudioId.shell,
        StudioSection.notes: StudioId.shell,
        StudioSection.settings: StudioId.shell,
      };

      // Total: adding a section without deciding its theme identity fails.
      expect(expected.keys.toSet(), StudioSection.values.toSet());
      for (final entry in expected.entries) {
        expect(entry.key.studioId, entry.value, reason: entry.key.name);
      }
    });

    testWidgets('the shell installs a scope above every route',
        (tester) async {
      await pumpApp(tester);

      final scope = StudioThemeScope.maybeOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(scope, isNotNull);
      expect(scope!.theme.themeId, 'light');
    });

    testWidgets('a Studio section resolves through its own scope',
        (tester) async {
      await pumpApp(tester);

      // The innermost scope over the section body carries the Studio identity.
      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(scopes, isNotEmpty);
      expect(
        scopes.map((scope) => scope.studio).whereType<StudioId>(),
        isNotEmpty,
        reason: 'at least one Studio-scoped subtree must be mounted',
      );

      // With no overrides registered, a Studio inherits the shell palette.
      final resolved = scopes.first.theme;
      for (final studio in [
        StudioId.manuscript,
        StudioId.character,
        StudioId.world,
        StudioId.plot,
        StudioId.timeline,
        StudioId.storyCodex,
      ]) {
        for (final ref in ThemeColorRef.values) {
          expect(
            resolved.colorFor(studio, ref),
            resolved.color(ref),
            reason: '${studio.value}.${ref.name}',
          );
        }
      }
    });
  });

  group('Studio theme consumption', () {
    // A representative widget from each major Studio must resolve the
    // authoritative ThemeData and sit under that Studio's scope.
    const studios = <StudioSection, StudioId>{
      StudioSection.dashboard: StudioId.shell,
      StudioSection.manuscript: StudioId.manuscript,
      StudioSection.chapters: StudioId.manuscript,
      StudioSection.characters: StudioId.character,
      StudioSection.codex: StudioId.storyCodex,
      StudioSection.world: StudioId.world,
      StudioSection.plot: StudioId.plot,
      StudioSection.timeline: StudioId.timeline,
      StudioSection.notes: StudioId.shell,
      StudioSection.settings: StudioId.shell,
    };

    for (final entry in studios.entries) {
      final section = entry.key;
      testWidgets('${section.label} consumes the authoritative theme',
          (tester) async {
        await pumpApp(tester);

        final tile = find.text(section.label);
        expect(tile, findsWidgets, reason: '${section.label} must be navigable');
        // Some Studios keep a progress indicator running while they load, so
        // settling would time out. Building the section is enough here.
        await toleratingOverflow(() async {
          await tester.tap(tile.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        });

        // The section subtree is scoped to its Studio.
        final scoped = tester
            .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
            .where((scope) => scope.studio != null)
            .toList();
        expect(scoped, isNotEmpty, reason: section.label);
        expect(scoped.last.studio, entry.value, reason: section.label);

        // And it resolves the engine's ThemeData, not a private one.
        final expected = engineThemeData('light', ThemeBrightness.light);
        final context = tester.element(find.byType(Scaffold).first);
        final rendered = Theme.of(context);
        expect(rendered.colorScheme.surface, expected.colorScheme.surface);
        expect(rendered.colorScheme.primary, expected.colorScheme.primary);
        expect(rendered.colorScheme.onSurface, expected.colorScheme.onSurface);
        expect(
          rendered.colorScheme.outlineVariant,
          expected.colorScheme.outlineVariant,
        );
        expect(rendered.textTheme.bodyMedium?.fontFamily, 'Merriweather');
      });
    }
  });

  group('typography', () {
    test('every declared family is resolvable at runtime', () {
      // Regression guard for the Inter defect: a family referenced by the
      // typography contract but only bundled under `assets:` silently falls
      // back to the default face.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(r'^\s*-\s*family:\s*(\S+)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((match) => match.group(1)!)
          .toSet();

      // Families Flutter resolves without a bundled asset.
      const platformGeneric = {'monospace', 'serif', 'sans-serif'};

      final typography = ThemeRegistry.standard().themes.first.typography;
      for (final role in ThemeTextRole.values) {
        final style = typography[role];
        final families = [style.family, ...style.fallbackFamilies];
        expect(
          families.any(
            (family) =>
                declared.contains(family) || platformGeneric.contains(family),
          ),
          isTrue,
          reason: 'role ${role.name} resolves to none of $families; '
              'declared families are $declared',
        );
      }
    });

    test('the documented font roles are the ones in force', () {
      final typography = ThemeRegistry.standard().themes.first.typography;
      expect(typography[ThemeTextRole.ui].family, 'Inter');
      expect(typography[ThemeTextRole.label].family, 'Inter');
      expect(typography[ThemeTextRole.body].family, 'Merriweather');
      expect(typography[ThemeTextRole.heading].family, 'Merriweather');
      // JetBrainsMono is not bundled in this repository. See
      // docs/theme-engine-phase-3-implementation-map.md, "Token and asset
      // gaps"; the code role uses the platform monospace face until the
      // font asset is added.
      expect(typography[ThemeTextRole.code].family, 'monospace');
    });

    testWidgets('Inter and Merriweather both reach rendered ThemeData',
        (tester) async {
      await pumpApp(tester);
      final theme = materialApp(tester).theme!;

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Merriweather');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Merriweather');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
    });
  });

  group('accessibility reaches the application', () {
    testWidgets('high contrast is applied to the rendered ThemeData',
        (tester) async {
      await pumpApp(tester, preferences: {
        ThemePersistence.highContrastKey: 'true',
      });

      final plain = engineThemeData('light', ThemeBrightness.light);
      final rendered = materialApp(tester).theme!;

      expect(
        rendered.colorScheme.onSurface,
        isNot(plain.colorScheme.onSurface),
        reason: 'high contrast must change the foreground role',
      );
      expect(
        rendered.colorScheme.onSurface.computeLuminance(),
        lessThan(plain.colorScheme.onSurface.computeLuminance()),
        reason: 'a light theme darkens its foreground under high contrast',
      );
    });

    testWidgets('reduced intensity is applied to the rendered ThemeData',
        (tester) async {
      await pumpApp(tester, preferences: {
        ThemePersistence.reduceIntensityKey: 'true',
      });

      final plain = engineThemeData('light', ThemeBrightness.light);
      final rendered = materialApp(tester).theme!;

      expect(rendered.colorScheme.primary, isNot(plain.colorScheme.primary));
      expect(
        rendered.colorScheme.onSurface,
        plain.colorScheme.onSurface,
        reason: 'reducing intensity must never reduce reading contrast',
      );
    });

    testWidgets('focus and selection treatments survive into ThemeData',
        (tester) async {
      await pumpApp(tester);
      final theme = materialApp(tester).theme!;
      final palette = ThemeRegistry.standard()
          .byId('light')
          .paletteFor(ThemeBrightness.light);

      expect(
        theme.textSelectionTheme.selectionColor,
        AuthorOsTheme.color(palette[ThemeColorRef.selection]),
      );
      expect(
        theme.focusColor,
        AuthorOsTheme.color(palette[ThemeColorRef.focusRing]),
      );
    });
  });

  group('legacy compatibility', () {
    const legacyIds = {
      'paper': 'light',
      'slate': 'light',
      'obsidian': 'dark',
      'midnight': 'dark',
      'forest': 'dark',
      'burgundy': 'dark',
      'plum': 'dark',
      'ocean': 'dark',
    };

    test('all eight legacy ids still resolve', () {
      final registry = ThemeRegistry.standard();
      for (final entry in legacyIds.entries) {
        expect(registry.normalizeId(entry.key), entry.value,
            reason: entry.key);
        expect(registry.isAlias(entry.key), isTrue, reason: entry.key);
      }
    });

    for (final entry in legacyIds.entries) {
      testWidgets('a persisted "${entry.key}" install launches ${entry.value}',
          (tester) async {
        await pumpApp(tester, preferences: {
          ThemePersistence.themeIdKey: entry.key,
        });

        final app = materialApp(tester);
        expect(
          app.themeMode,
          entry.value == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );

        final context = tester.element(find.byType(Scaffold).first);
        expect(
          Theme.of(context).brightness,
          entry.value == 'dark' ? Brightness.dark : Brightness.light,
        );
      });
    }
  });

  group('architecture', () {
    /// Dead code carrying a second `main()` and a second `ThemeData`. It is
    /// imported by nothing; see the Phase 3 map, "Stop conditions". Deleting
    /// it is a repository-owner decision, so it is quarantined rather than
    /// silently permitted.
    const quarantined = 'lib/main.authorstudio.backup.dart';
    const boundary = 'lib/theme/flutter/authoros_theme.dart';

    List<File> libSources() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    test('ThemeData is only constructed inside the Theme Engine boundary', () {
      // Matches `ThemeData(` but not `CardThemeData(`, `toThemeData(`, etc.
      final constructor = RegExp(r'(?<![A-Za-z_$])ThemeData\(');
      final offenders = <String>[];

      for (final file in libSources()) {
        if (!constructor.hasMatch(file.readAsStringSync())) continue;
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith(boundary) || path.endsWith(quarantined)) continue;
        offenders.add(path);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'ThemeData must only be built by AuthorOsTheme.toThemeData. '
            'Offending files: $offenders',
      );
    });

    test('the quarantined duplicate is genuinely dead code', () {
      // If anything starts importing it, the exemption above is no longer
      // safe and this fails rather than hiding a second live theme system.
      const importedAs = 'main.authorstudio.backup.dart';
      final importers = <String>[];
      for (final file in libSources()) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith(quarantined)) continue;
        if (file.readAsStringSync().contains(importedAs)) {
          importers.add(path);
        }
      }
      expect(importers, isEmpty,
          reason: 'the quarantined duplicate theme must stay unreachable');
    });

    test('only the Theme Engine persists theme settings', () {
      // No UI-level theme persistence: preference keys live in
      // ThemePersistence and nowhere else.
      final offenders = <String>[];
      for (final file in libSources()) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/theme/')) continue;
        final source = file.readAsStringSync();
        if (source.contains("'author_studio.theme_id'") ||
            source.contains("'author_studio.accent_id'") ||
            source.contains("'author_studio.theme.")) {
          offenders.add(path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'theme preference keys belong to ThemePersistence. '
            'Offending files: $offenders',
      );
    });

    test('the shell owns no second theme resolution path', () {
      final shell = File('lib/main.dart').readAsStringSync();
      expect(shell, isNot(contains('ColorScheme.fromSeed')),
          reason: 'colour scheme derivation belongs to the adapter');
      expect(shell, contains('AuthorOsTheme.toThemeData'));
    });
  });
}
