import 'dart:io';

import 'package:author_studio_v1/backup_health.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_resolver.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/visual_planning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Theme Engine Phase 3.1 — status roles and the categorical ramp.
///
/// Phase 3 left 37 colour literals stranded because the token vocabulary had
/// no way to say "this passed" or "this is a Political link". These tests
/// prove the new roles exist, carry valid values in both palettes, reach
/// rendered widgets, and did not arrive as a second colour system.
void main() {
  const statusRoles = [
    ThemeColorRef.success,
    ThemeColorRef.warning,
    ThemeColorRef.error,
  ];

  ResolvedTheme resolve(String themeId, ThemeBrightness brightness) =>
      const ThemeResolver().resolve(
        definition: ThemeRegistry.standard().byId(themeId),
        mode: brightness == ThemeBrightness.dark
            ? AuthorOsThemeMode.dark
            : AuthorOsThemeMode.light,
        hostBrightness: brightness,
      );

  /// The light theme with selected roles or ramp slots replaced.
  ///
  /// Overriding a token and watching a widget change is the only way to prove
  /// the widget reads the theme rather than a literal that happens to match.
  ThemeData customized({
    Map<ThemeColorRef, ThemeColor> colors = const {},
    Map<ThemeCategoryRef, ThemeColor> categories = const {},
  }) {
    final base = ThemeRegistry.standard().byId('light');
    final palette = base.paletteFor(ThemeBrightness.light);
    final definition = ThemeDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      typography: base.typography,
      metrics: base.metrics,
      palettes: {
        ThemeBrightness.light: ThemePalette(
          {...palette.colors, ...colors},
          categories: {...palette.categories, ...categories},
        ),
      },
    );
    return AuthorOsTheme.toThemeData(
      const ThemeResolver().resolve(
        definition: definition,
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
      ),
    );
  }

  group('status roles', () {
    test('all three resolve through the engine in both themes', () {
      for (final entry in {
        'light': ThemeBrightness.light,
        'dark': ThemeBrightness.dark,
      }.entries) {
        final theme = resolve(entry.key, entry.value);
        for (final role in statusRoles) {
          expect(
            () => theme.color(role),
            returnsNormally,
            reason: '${entry.key}.${role.name}',
          );
        }
      }
    });

    test('both palettes define fully opaque, distinguishable values', () {
      for (final themeId in ['light', 'dark']) {
        final palette = ThemeRegistry.standard().byId(themeId).paletteFor(
              themeId == 'dark'
                  ? ThemeBrightness.dark
                  : ThemeBrightness.light,
            );
        final values = <int>{};
        for (final role in statusRoles) {
          final color = palette[role];
          expect(color.alpha, 0xFF, reason: '$themeId.${role.name}');
          values.add(color.value);
        }
        expect(
          values.length,
          statusRoles.length,
          reason: '$themeId status roles must not collide with each other',
        );
      }
    });

    test('status values preserve the literals they replaced', () {
      // Phase 3.1 is a token migration, not a recolour. The literals were
      // theme-independent, so both palettes carry the same values.
      for (final themeId in ['light', 'dark']) {
        final brightness = themeId == 'dark'
            ? ThemeBrightness.dark
            : ThemeBrightness.light;
        final palette =
            ThemeRegistry.standard().byId(themeId).paletteFor(brightness);
        expect(palette[ThemeColorRef.success].value, 0xFF77B884);
        expect(palette[ThemeColorRef.warning].value, 0xFFC59B6D);
        expect(palette[ThemeColorRef.error].value, 0xFFE07A6F);
      }
    });

    test('the roles reach rendered ThemeData', () {
      for (final themeId in ['light', 'dark']) {
        final brightness = themeId == 'dark'
            ? ThemeBrightness.dark
            : ThemeBrightness.light;
        final resolved = resolve(themeId, brightness);
        final semantic = AuthorOsTheme.toThemeData(resolved)
            .extension<AuthorOsSemanticColors>();

        expect(semantic, isNotNull, reason: themeId);
        expect(
          semantic!.success,
          AuthorOsTheme.color(resolved.color(ThemeColorRef.success)),
        );
        expect(
          semantic.warning,
          AuthorOsTheme.color(resolved.color(ThemeColorRef.warning)),
        );
        expect(
          semantic.error,
          AuthorOsTheme.color(resolved.color(ThemeColorRef.error)),
        );
      }
    });

    test('accessibility transformations leave signal colours intact', () {
      // Documented invariant: success, warning and error are told apart by
      // hue. High contrast pushes foregrounds towards black/white and reduced
      // intensity desaturates — either would erase the distinction these
      // roles exist to carry, so both skip them deliberately.
      final plain = resolve('light', ThemeBrightness.light);
      for (final options in [
        const ThemeAccessibility(highContrast: true),
        const ThemeAccessibility(reduceIntensity: true),
        const ThemeAccessibility(highContrast: true, reduceIntensity: true),
      ]) {
        final transformed = const ThemeResolver().resolve(
          definition: ThemeRegistry.standard().byId('light'),
          mode: AuthorOsThemeMode.light,
          hostBrightness: ThemeBrightness.light,
          accessibility: options,
        );
        for (final role in statusRoles) {
          expect(
            transformed.color(role),
            plain.color(role),
            reason: '${role.name} under $options',
          );
        }
        for (final ref in ThemeCategoryRef.values) {
          expect(
            transformed.category(ref),
            plain.category(ref),
            reason: '${ref.name} under $options',
          );
        }
      }
    });
  });

  group('categorical ramp', () {
    test('every slot is defined in both palettes and is opaque', () {
      for (final themeId in ['light', 'dark']) {
        final brightness = themeId == 'dark'
            ? ThemeBrightness.dark
            : ThemeBrightness.light;
        final palette =
            ThemeRegistry.standard().byId(themeId).paletteFor(brightness);
        expect(palette.missingCategories, isEmpty, reason: themeId);
        for (final ref in ThemeCategoryRef.values) {
          expect(palette.category(ref).alpha, 0xFF,
              reason: '$themeId.${ref.name}');
        }
      }
    });

    test('every slot is visually distinct from every other', () {
      // A categorical ramp whose slots collide cannot separate categories.
      final palette = ThemeRegistry.standard()
          .byId('light')
          .paletteFor(ThemeBrightness.light);
      final values = {
        for (final ref in ThemeCategoryRef.values) palette.category(ref).value,
      };
      expect(values.length, ThemeCategoryRef.values.length);
    });

    test('a theme missing a ramp slot fails validation', () {
      final base = ThemeRegistry.standard().byId('light');
      final palette = base.paletteFor(ThemeBrightness.light);
      final incomplete = ThemeDefinition(
        id: base.id,
        name: base.name,
        description: base.description,
        typography: base.typography,
        metrics: base.metrics,
        palettes: {
          ThemeBrightness.light: ThemePalette(
            palette.colors,
            categories: {
              for (final entry in palette.categories.entries)
                if (entry.key != ThemeCategoryRef.category8)
                  entry.key: entry.value,
            },
          ),
        },
      );
      expect(incomplete.validate, throwsA(isA<FormatException>()));
    });

    test('the ramp reaches rendered ThemeData in slot order', () {
      final resolved = resolve('light', ThemeBrightness.light);
      final semantic = AuthorOsTheme.toThemeData(resolved)
          .extension<AuthorOsSemanticColors>()!;

      expect(semantic.categories.length, ThemeCategoryRef.values.length);
      for (final ref in ThemeCategoryRef.values) {
        expect(
          semantic.category(ref),
          AuthorOsTheme.color(resolved.category(ref)),
          reason: ref.name,
        );
      }
    });
  });

  group('SceneStatus resolves through the theme', () {
    const expectedSlots = <SceneStatus, ThemeCategoryRef>{
      SceneStatus.backlog: ThemeCategoryRef.category1,
      SceneStatus.outlining: ThemeCategoryRef.category2,
      SceneStatus.drafting: ThemeCategoryRef.category3,
      SceneStatus.revised: ThemeCategoryRef.category4,
      SceneStatus.finalDraft: ThemeCategoryRef.category5,
    };

    test('every status has a slot', () {
      expect(expectedSlots.keys.toSet(), SceneStatus.values.toSet());
    });

    testWidgets('each status reads its slot from the active theme',
        (tester) async {
      // Every slot gets a unique sentinel, so a widget still holding a
      // literal cannot accidentally match.
      const sentinels = {
        ThemeCategoryRef.category1: ThemeColor(0xFF010101),
        ThemeCategoryRef.category2: ThemeColor(0xFF020202),
        ThemeCategoryRef.category3: ThemeColor(0xFF030303),
        ThemeCategoryRef.category4: ThemeColor(0xFF040404),
        ThemeCategoryRef.category5: ThemeColor(0xFF050505),
      };

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: customized(categories: sentinels),
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final entry in expectedSlots.entries) {
        expect(
          entry.key.colorIn(context),
          AuthorOsTheme.color(sentinels[entry.value]!),
          reason: entry.key.name,
        );
      }
    });

    testWidgets('a host without AuthorOS ThemeData falls back to the palette',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final palette = ThemeRegistry.standard()
          .byId('light')
          .paletteFor(ThemeBrightness.light);
      expect(
        SceneStatus.backlog.colorIn(context),
        AuthorOsTheme.color(palette.category(ThemeCategoryRef.category1)),
      );
    });
  });

  group('migrated widgets read the theme', () {
    testWidgets('the continuity integrity chip uses the success role',
        (tester) async {
      const sentinel = ThemeColor(0xFF123456);
      await tester.pumpWidget(
        MaterialApp(
          theme: customized(colors: {ThemeColorRef.success: sentinel}),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ContinuityTimelinePanel(events: [], warnings: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const Key('continuity-integrity-score')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = chip.decoration! as BoxDecoration;

      // No warnings means a perfect score, which renders as "success".
      expect(decoration.color, AuthorOsTheme.color(sentinel)
          .withValues(alpha: 0.18));
      expect(decoration.border!.top.color, AuthorOsTheme.color(sentinel));
    });

    testWidgets('the continuity clear-state line uses the success role',
        (tester) async {
      const sentinel = ThemeColor(0xFF654321);
      await tester.pumpWidget(
        MaterialApp(
          theme: customized(colors: {ThemeColorRef.success: sentinel}),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ContinuityTimelinePanel(events: [], warnings: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.text(
          'No character presence, overlap, or sequence conflicts detected.',
        ),
      );
      expect(text.style!.color, AuthorOsTheme.color(sentinel));
    });

    test('the migrated files hold no status or category literals', () {
      // The exact values that were stranded before this phase. Any of them
      // reappearing means a widget went back to bypassing the engine.
      const literals = [
        '0xFF77B884', // success
        '0xFFC59B6D', // warning
        '0xFFE07A6F', // error
        '0xFF858A94', '0xFF65A8A0', '0xFFD39A52',
        '0xFF7EA6D8', '0xFF9B8AC4', // ramp
      ];
      const migrated = [
        'lib/continuity.dart',
        'lib/backup_health.dart',
        'lib/visual_planning.dart',
      ];

      for (final path in migrated) {
        final source = File(path).readAsStringSync();
        for (final literal in literals) {
          expect(
            source,
            isNot(contains(literal)),
            reason: '$path holds $literal',
          );
        }
      }

      // Projects' public/private badge used Material's named colours.
      final shell = File('lib/main.dart').readAsStringSync();
      const namedColors = [
        'Colors.green',
        'Colors.orange',
        'Colors.greenAccent',
        'Colors.orangeAccent',
      ];
      for (final named in namedColors) {
        expect(shell, isNot(contains(named)), reason: 'lib/main.dart: $named');
      }
    });

    test('the migrated files reach status colour through the engine', () {
      for (final path in [
        'lib/continuity.dart',
        'lib/backup_health.dart',
        'lib/visual_planning.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('AuthorOsSemanticColors'),
          reason: path,
        );
      }
    });
  });

  group('link categories resolve through the theme', () {
    // Every link type the Continuity timeline distinguishes, and the ramp
    // slot it must render as.
    const expectedSlots = <String, ThemeCategoryRef>{
      'Character': ThemeCategoryRef.category2,
      'Relationship': ThemeCategoryRef.category2,
      'World': ThemeCategoryRef.category6,
      'Discovery': ThemeCategoryRef.category6,
      'Political': ThemeCategoryRef.category7,
      'War': ThemeCategoryRef.category7,
      'Historical': ThemeCategoryRef.category8,
      'Plot': ThemeCategoryRef.category3,
    };

    const sentinels = {
      ThemeCategoryRef.category2: ThemeColor(0xFF111111),
      ThemeCategoryRef.category3: ThemeColor(0xFF222222),
      ThemeCategoryRef.category6: ThemeColor(0xFF666666),
      ThemeCategoryRef.category7: ThemeColor(0xFF777777),
      ThemeCategoryRef.category8: ThemeColor(0xFF888888),
    };

    for (final entry in expectedSlots.entries) {
      testWidgets('a "${entry.key}" event renders its ramp slot',
          (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final events = [
          ContinuityEventSnapshot(
            id: 'event-1',
            title: 'Opening',
            startDay: 1,
            endDay: 1,
            order: 1,
            pov: 'Mara',
            plotline: 'Main Plot',
            presentCharacters: const ['Mara'],
            type: entry.key,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: customized(categories: sentinels),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ContinuityTimelinePanel(
                  events: events,
                  warnings: const [],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bar = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(const Key('timeline-lane-event-event-1')),
                matching: find.byType(Material),
              )
              .first,
        );
        final expected = AuthorOsTheme.color(sentinels[entry.value]!);

        // No warnings, so the outline carries the category colour directly.
        expect(
          (bar.shape! as RoundedRectangleBorder).side.color,
          expected,
          reason: entry.key,
        );
        expect(bar.color, expected.withValues(alpha: 0.24), reason: entry.key);
      });
    }
  });

  group('code typography role', () {
    test('the manuscript draft editor consumes the role, not a literal', () {
      final source = File('lib/manuscript_studio.dart').readAsStringSync();
      expect(source, contains('ThemeTextRole.code'));
      // The editor must not name a family directly...
      expect(source, isNot(contains("fontFamily: 'monospace'")));
      // ...and the one literal left is the documented no-scope fallback.
      expect("?? 'monospace'".allMatches(source).length, 1);
    });

    test('the code role carries a resolvable family and fallbacks', () {
      final code = ThemeRegistry.standard()
          .themes
          .first
          .typography[ThemeTextRole.code];
      // JetBrainsMono is not owned by this repository; see the Phase 3.1 map,
      // "Font ownership". The role is wired so adding it is a registry edit.
      expect(code.family, 'monospace');
      expect(code.fallbackFamilies, contains('monospace'));
      expect(code.size, greaterThan(0));
    });
  });

  group('still one colour system', () {
    List<File> libSources() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    test('exactly one ThemeExtension exists', () {
      final sources = libSources().map((f) => f.readAsStringSync()).join('\n');
      expect('extends ThemeExtension<'.allMatches(sources).length, 1);
      expect('class AuthorOsSemanticColors '.allMatches(sources).length, 1);
    });

    test('only the adapter builds the semantic colours', () {
      // Widgets may read them; nothing outside the Theme Engine boundary may
      // mint its own set, which is how a parallel palette service starts.
      final offenders = <String>[];
      for (final file in libSources()) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/theme/')) continue;
        final source = file.readAsStringSync();
        if (source.contains('AuthorOsSemanticColors(') ||
            source.contains('AuthorOsSemanticColors.from(')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'semantic colours must come from the engine: $offenders');
    });

    test('the fallback matches the registry rather than inventing values', () {
      final palette = ThemeRegistry.standard()
          .byId('light')
          .paletteFor(ThemeBrightness.light);
      final fallback = AuthorOsSemanticColors.fallback;

      expect(fallback.success,
          AuthorOsTheme.color(palette[ThemeColorRef.success]));
      expect(fallback.warning,
          AuthorOsTheme.color(palette[ThemeColorRef.warning]));
      expect(fallback.error, AuthorOsTheme.color(palette[ThemeColorRef.error]));
      for (final ref in ThemeCategoryRef.values) {
        expect(fallback.category(ref),
            AuthorOsTheme.color(palette.category(ref)), reason: ref.name);
      }
    });

    test('backup health still exposes its status enum unchanged', () {
      // The migration changed colour resolution, not the domain.
      expect(RestoreTestStatus.values,
          [RestoreTestStatus.passed, RestoreTestStatus.failed]);
    });
  });
}
