import 'dart:convert';

import 'package:author_studio_v1/author_profile_store.dart';
import 'package:author_studio_v1/create_profile_page.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/login_select_user_page.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/startup_backdrop.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_resolver.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/welcome_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG relative-contrast ratio between two opaque colours.
double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    debugDisableAuroraAnimation = true;
    database = AuthorOsDatabase(NativeDatabase.memory());
    manuscriptStore = ManuscriptStore(
      repository: DriftConnectedDomainRepository(database),
    );
  });

  tearDown(() {
    database.close();
    debugDisableAuroraAnimation = false;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AuthorStudioApp(manuscriptStore: manuscriptStore));
    await tester.pumpAndSettle();
  }

  ThemeData appTheme(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;

  group('startup ignores the workspace theme', () {
    // The regression: a StudioThemeScope carrying the author's workspace theme
    // is installed above startup. If StartupPalette followed it, a light
    // workspace theme would wash out the panels and bleach the artwork behind
    // them, because the backdrop scrim is drawn from `background`.
    for (final workspaceTheme in const ['light', 'dark']) {
      testWidgets('$workspaceTheme workspace theme still paints startup dark',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'author_studio.theme_id': workspaceTheme,
          AuthorProfileStore.profilesKey: jsonEncode([
            {
              'id': 'a',
              'displayName': 'Alexandra',
              'penName': 'Lead Author',
              'email': 'alexandra@example.com',
              'genres': '',
              'goals': '',
              'region': '',
              'avatarPath': '',
              'lastActiveAt': null,
            },
          ]),
        });

        await pumpApp(tester);
        expect(find.byType(LoginSelectUserPage), findsOneWidget);

        final palette = StartupPalette.of(
          tester.element(find.byType(LoginSelectUserPage)),
        );
        expect(palette.background, StartupPalette.engineDark.background);
        expect(palette.gold, StartupPalette.engineDark.gold);
        expect(palette.onSurface, StartupPalette.engineDark.onSurface);
      });
    }

    testWidgets('an enclosing light scope does not lighten the palette',
        (tester) async {
      final lightResolved = const ThemeResolver().resolve(
        definition: ThemeRegistry.standard().byId('light'),
        mode: AuthorOsThemeMode.light,
        hostBrightness: ThemeBrightness.light,
        accessibility: ThemeAccessibility.none,
      );

      late StartupPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            theme: lightResolved,
            studio: StudioId.shell,
            child: Builder(
              builder: (context) {
                seen = StartupPalette.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // The scope really is light, and startup ignored it anyway.
      expect(
        AuthorOsTheme.color(lightResolved.colorFor(null, ThemeColorRef.background)),
        isNot(StartupPalette.engineDark.background),
      );
      expect(seen.background, StartupPalette.engineDark.background);
    });
  });

  group('startup surfaces stay readable', () {
    test('login and profile creation meet contrast on the dark palette', () {
      final palette = StartupPalette.engineDark;
      // Body copy on the panel.
      expect(
        contrastRatio(palette.onSurface, palette.background),
        greaterThanOrEqualTo(7),
      );
      // Gold headings and controls on the panel.
      expect(
        contrastRatio(palette.gold, palette.background),
        greaterThanOrEqualTo(4.5),
      );
      // Panel fill must stay distinguishable from the page behind it.
      expect(palette.panel, isNot(palette.background));
    });

    testWidgets('both startup screens render their key controls',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
      });
      await pumpApp(tester);

      expect(find.text('AuthorOS'), findsOneWidget);
      expect(find.byKey(const Key('startup-continue')), findsOneWidget);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateProfilePage), findsOneWidget);
      expect(find.text('Create Your Profile'), findsOneWidget);
      expect(find.byKey(const Key('start-your-adventure')), findsOneWidget);
    });
  });

  group('the workspace theme is left alone', () {
    testWidgets('startup introduces no second ThemeData', (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
      });
      await pumpApp(tester);

      // One MaterialApp, and its ThemeData is still the author's light choice
      // even though the startup panels are painted dark.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(appTheme(tester).brightness, Brightness.light);
      expect(
        StartupPalette.of(
          tester.element(find.byType(LoginSelectUserPage)),
        ).background,
        StartupPalette.engineDark.background,
      );
    });

    testWidgets('visiting startup does not rewrite the persisted theme',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': 'light',
        'author_studio.accent_id': 'default',
      });
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-profile-back')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('author_studio.theme_id'), 'light');
      expect(prefs.getString('author_studio.accent_id'), 'default');
    });

    for (final entry in const {
      'light': Brightness.light,
      'dark': Brightness.dark,
    }.entries) {
      testWidgets(
          'the workspace still uses the ${entry.key} theme after sign-in',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'author_studio.theme_id': entry.key,
          AuthorProfileStore.profilesKey: jsonEncode([
            {
              'id': 'a',
              'displayName': 'Alexandra',
              'penName': '',
              'email': 'a@example.com',
              'genres': '',
              'goals': '',
              'region': '',
              'avatarPath': '',
              'lastActiveAt': null,
            },
          ]),
        });
        await pumpApp(tester);

        await tester.tap(find.byKey(const Key('startup-continue')));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(LoginSelectUserPage), findsNothing);
        // Past startup, the author's own theme is in force again.
        expect(appTheme(tester).brightness, entry.value);
        expect(
          Theme.of(tester.element(find.byType(WelcomePage))).brightness,
          entry.value,
        );
      });
    }
  });
}
