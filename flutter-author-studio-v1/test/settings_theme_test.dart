import 'dart:async';

import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The profile screen's aurora loops forever, which would stall
  // `pumpAndSettle`; pin it to a static frame for the widget tests.
  setUp(() => debugDisableAuroraAnimation = true);
  tearDown(() => debugDisableAuroraAnimation = false);

  double contrastRatio(Color first, Color second) {
    final lighter = first.computeLuminance() > second.computeLuminance()
        ? first.computeLuminance()
        : second.computeLuminance();
    final darker = first.computeLuminance() > second.computeLuminance()
        ? second.computeLuminance()
        : first.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('theme presets expose one light and one dark choice', () {
    expect(AppThemePreset.values.map((theme) => theme.id), ['light', 'dark']);
    expect(AppThemePreset.byId('light').brightness, Brightness.light);
    expect(AppThemePreset.byId('dark').brightness, Brightness.dark);
    expect(
      AppThemePreset.byId('light').accentColor,
      const Color(0xFF4F8FCB),
    );
    expect(
      AppThemePreset.byId('dark').accentColor,
      const Color(0xFFD4AF37),
    );
  });

  test('legacy theme IDs preserve their previous brightness', () {
    expect(AppThemePreset.byId('paper').id, 'light');
    expect(AppThemePreset.byId('slate').id, 'light');
    expect(AppThemePreset.byId('obsidian').id, 'dark');
    expect(AppThemePreset.byId('midnight').id, 'dark');
  });

  for (final themeId in ['light', 'dark']) {
    testWidgets('$themeId theme uses readable foreground contrast',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'author_studio.theme_id': themeId,
      });

      await tester.pumpWidget(const AuthorStudioApp(showWelcome: false));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = app.theme!;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Merriweather');
      expect(
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.onSurface,
      );
      expect(
        contrastRatio(
          theme.colorScheme.onSurface,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrastRatio(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('dashboard surfaces follow the active light color scheme',
      (tester) async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    final manuscriptStore = ManuscriptStore(
      repository: DriftConnectedDomainRepository(database),
    );
    addTearDown(database.close);
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8A512A),
      brightness: Brightness.light,
      surface: Colors.white,
    );
    final project = NovelStarterKit.create(
      title: 'The Light Draft',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        home: AuthorStudioShell(
          project: project,
          manuscriptStore: manuscriptStore,
          themeId: 'light',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();

    final hero = tester.widget<Container>(find.byKey(
      const Key('dashboard-hero'),
    ));
    final heroDecoration = hero.decoration! as BoxDecoration;
    expect(
      (heroDecoration.gradient! as LinearGradient).colors,
      [colorScheme.surfaceContainerHighest, colorScheme.surface],
    );

    final recentProjects = tester.widget<Container>(find.byKey(
      const Key('dashboard-recent-projects'),
    ));
    expect(
      (recentProjects.decoration! as BoxDecoration).color,
      colorScheme.surface,
    );
  });

  testWidgets('theme settings exposes palette choices and can change selection',
      (tester) async {
    String? pickedTheme;
    String? pickedAccent;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'light',
          accentId: 'default',
          onThemeChanged: (themeId, accentId) {
            pickedTheme = themeId;
            pickedAccent = accentId;
          },
        ),
      ),
    );

    expect(find.text('Light'), findsNothing);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Obsidian'), findsNothing);

    final darkFinder = find.text('Dark');
    await tester.ensureVisible(darkFinder);
    await tester.tap(darkFinder);
    await tester.pumpAndSettle();

    expect(pickedTheme, 'dark');
    expect(pickedAccent, 'default');
  });

  testWidgets('appearance uses fixed theme palettes without accent overrides',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'light',
          accentId: 'coral',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Accent'), findsNothing);
    expect(find.text('Coral'), findsNothing);
    expect(
      const AppThemeSelection(themeId: 'light', accentId: 'coral')
          .resolvedAccentColor,
      AppThemePreset.byId('light').accentColor,
    );
  });

  testWidgets('engine-backed appearance exposes system, light, dark, and accessibility',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final store = MemoryThemeSettingsStore();
    final engine = ThemeEngine.standard(store: store);
    await engine.load();
    ThemeSelection? reportedSelection;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          selection: const ThemeSelection(
            themeId: 'light',
            mode: AuthorOsThemeMode.light,
          ),
          onSelectionChanged: (selection) {
            reportedSelection = selection;
            unawaited(
              engine.select(
                selection: selection,
                hostBrightness: ThemeBrightness.light,
              ),
            );
          },
          themeId: 'light',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('High contrast'), findsOneWidget);
    expect(find.text('Reduce intensity'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(reportedSelection, isNotNull);
    expect(reportedSelection!.mode, AuthorOsThemeMode.dark);
    expect(reportedSelection!.themeId, 'dark');

    final reloaded = ThemeEngine.standard(store: store);
    final selection = await reloaded.load();
    expect(selection.mode, AuthorOsThemeMode.dark);
    expect(selection.themeId, 'dark');
  });

  testWidgets('account security controls are inside a collapsible section',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.profile.name': 'Elara West',
      'author_studio.profile.focus': 'Literary fantasy and mythic fiction',
      'author_studio.profile.bio': 'A writer of folklore and found family.',
      'author_studio.profile.public': true,
      'author_studio.profile.require_reauth': true,
      'author_studio.profile.secure_sessions': true,
      'author_studio.profile.sync_alerts': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Require re-auth for sensitive actions'), findsNothing);
    await tester.tap(find.text('Account Security'));
    await tester.pumpAndSettle();

    expect(find.text('Require re-auth for sensitive actions'), findsOneWidget);
    expect(find.text('Secure device sessions'), findsOneWidget);
  });

  testWidgets('logout asks for confirmation and cancel keeps session active',
      (tester) async {
    var logoutCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          onLogout: () async {
            logoutCalled = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Account Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log Out'), findsNWidgets(2));
    expect(
      find.text(
          'Are you sure you want to log out?\n\nYour projects, manuscripts, chapters, and profile data will remain saved.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isFalse);
    expect(find.text('Log Out'), findsNothing);
  });

  testWidgets('logout confirmation calls the real logout callback',
      (tester) async {
    var logoutCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'obsidian',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          onLogout: () async {
            logoutCalled = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Account Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
  });

  testWidgets('saved starter projects remain available after startup checks',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.starter_project':
          '{"id":"saved-project","title":"Hidden Draft","genre":"Fantasy","projectType":"Novel","wordGoal":80000,"acts":["Act I"],"chapters":[{"title":"Chapter 1","prompt":"Intro"}],"characterSheets":[{"name":"Hero","role":"Main"}],"beatChecklist":["Opening"],"firstSceneTitle":"Opening Scene"}',
      'author_studio.onboarding_complete': true,
    });

    const store = OnboardingStore();
    final loaded = await store.loadProject();

    expect(loaded, isNotNull);
    expect(loaded!.title, 'Hidden Draft');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('author_studio.onboarding_complete'), isTrue);
    expect(prefs.getString('author_studio.starter_project'), isNotNull);
  });
}
