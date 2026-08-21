import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/world_board/world_board_view.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  StarterProject project() => NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    final theme = engine.resolveSelection(
      selection: const ThemeSelection(
        themeId: 'light',
        mode: AuthorOsThemeMode.light,
      ),
      hostBrightness: ThemeBrightness.light,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: AuthorStudioShell(
            project: project(),
            manuscriptStore: manuscriptStore,
            themeId: 'light',
            accentId: 'default',
            onThemeChanged: (_, __) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('the shell registers World Board as a section', () {
    expect(StudioSection.values, contains(StudioSection.worldBoard));
  });

  test('World Board sits directly after the dashboard', () {
    expect(
      StudioSection.values.indexOf(StudioSection.worldBoard),
      StudioSection.values.indexOf(StudioSection.dashboard) + 1,
    );
  });

  test('World Board carries its own label and navigation icon', () {
    expect(StudioSection.worldBoard.label, 'World Board');
    expect(StudioSection.worldBoard.icon, Icons.hub_outlined);
    // The board must not wear World Studio's globe.
    expect(StudioSection.worldBoard.icon, isNot(StudioSection.world.icon));
  });

  test('adding the section left every existing studio addressable', () {
    // Sections are addressed by identity rather than index, so the previously
    // completed Studios must all still be present and uniquely labelled.
    for (final section in const [
      StudioSection.dashboard,
      StudioSection.manuscript,
      StudioSection.characters,
      StudioSection.codex,
      StudioSection.world,
      StudioSection.plot,
      StudioSection.timeline,
      StudioSection.settings,
    ]) {
      expect(StudioSection.values, contains(section));
    }

    final labels = StudioSection.values.map((section) => section.label);
    expect(labels.toSet(), hasLength(StudioSection.values.length));
    for (final section in StudioSection.values) {
      expect(section.label, isNotEmpty);
    }
  });

  testWidgets('World Board appears in the shell navigation', (tester) async {
    await pumpShell(tester);

    expect(find.text('World Board'), findsWidgets);
    expect(find.byIcon(Icons.hub_outlined), findsWidgets);
    // It joins the workspace group, which the rail renders under WORKSPACE.
    expect(find.text('WORKSPACE'), findsWidgets);
  });

  testWidgets('the navigation still lists every completed studio',
      (tester) async {
    await pumpShell(tester);

    for (final label in const [
      'Dashboard',
      'World Board',
      'Manuscript',
      'Characters',
      'Story Codex',
      'World',
      'Plot',
      'Timeline',
      'Settings',
    ]) {
      expect(find.text(label), findsWidgets, reason: '$label must stay in nav');
    }
  });

  testWidgets('selecting World Board renders the World Board studio',
      (tester) async {
    // The shell hands every Studio the production repository, and opening it
    // schedules work this test must not adopt. Construct it in real async so
    // its lazy open leaves no pending timer behind at teardown.
    await tester.runAsync(() async {
      expect(authorOsRepository, isNotNull);
    });

    await pumpShell(tester);

    expect(find.byType(WorldBoardView), findsNothing);

    await tester.tap(find.text('World Board').first);
    // One frame proves the shell routed here: the board is mounted and
    // loading. The tree is deliberately not settled — the production database
    // does not open inside a widget test, which is the same limitation the
    // Timeline Studio's own view tests run into.
    await tester.pump();

    expect(find.byType(WorldBoardView), findsOneWidget);

    // Unmount before anything the load scheduled can outlive the test.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
