import 'dart:io';

import 'package:author_studio_v1/core/record_scope.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/plot_studio_view.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/plot_phase_1_fixture.dart';

Future<ResolvedTheme> _resolvedTheme() async {
  final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
  return engine.resolveSelection(
    selection: const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
    hostBrightness: ThemeBrightness.light,
  );
}

Future<void> _pumpView(
  WidgetTester tester, {
  required StarterProject project,
  required PlotService service,
}) async {
  final theme = await _resolvedTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: StudioThemeScope(
          theme: theme,
          child: PlotStudioView(project: project, service: service),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  StarterProject _project(String title, String id) => StarterProject(
        id: id,
        title: title,
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 80000,
        acts: const [],
        chapters: const [],
        characterSheets: const [],
        beatChecklist: const [],
        firstSceneTitle: 'Opening',
      );

  testWidgets('loads seeded plot records and applies theme tokens', (tester) async {
    final project = _project('Plot Project', 'plot-project');
    final service = PlotService(projectId: project.id, repository: repository);
    await service.createPlotRecord(const PlotRecordDraft(
      id: 'story-1',
      typeId: 'story',
      name: 'The Glass Crown',
      fields: {'plotStatus': 'active'},
    ));

    await _pumpView(tester, project: project, service: service);

    expect(find.text('The Glass Crown'), findsOneWidget);
    expect(find.byKey(const ValueKey('plot-lane-container-active')), findsOneWidget);

    final lane = tester.widget<Container>(
      find.byKey(const ValueKey('plot-lane-container-active')),
    );
    final decoration = lane.decoration! as BoxDecoration;
    final theme = await _resolvedTheme();
    expect(
      decoration.color,
      AuthorOsTheme.color(theme.color(ThemeColorRef.surfaceContainer)),
    );
  });

  testWidgets('creates, edits, archives, restores, deletes, and refreshes records', (
    tester,
  ) async {
    final project = _project('Plot Project', 'plot-project');
    final service = PlotService(projectId: project.id, repository: repository);
    await service.createPlotRecord(const PlotRecordDraft(
      id: 'story-1',
      typeId: 'story',
      name: 'The Glass Crown',
      fields: {'plotStatus': 'active'},
    ));

    await _pumpView(tester, project: project, service: service);

    await tester.tap(find.byKey(const ValueKey('plot-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plot-record-id-field')), 'story-2');
    await tester.enterText(
      find.byKey(const ValueKey('plot-record-title-field')),
      'The Rebel Crown',
    );
    await tester.tap(find.byKey(const ValueKey('plot-record-status-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planned').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('The Rebel Crown'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Edit'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plot-record-title-field')),
      'The Rebel Crown Revised',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('The Rebel Crown Revised'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Archive'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Restore'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Restore'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Archive'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('plot-record-story-2')),
        matching: find.byTooltip('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plot-record-story-2')), findsNothing);

    await service.createPlotRecord(const PlotRecordDraft(
      id: 'story-3',
      typeId: 'story',
      name: 'Fresh Cache',
      fields: {'plotStatus': 'planned'},
    ));
    await tester.tap(find.byKey(const ValueKey('plot-refresh-button')));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Cache'), findsOneWidget);
  });

  testWidgets('keeps plot records isolated by project', (tester) async {
    final projectA = _project('Project A', 'project-a');
    final projectB = _project('Project B', 'project-b');
    final serviceA = PlotService(projectId: projectA.id, repository: repository);
    final serviceB = PlotService(projectId: projectB.id, repository: repository);
    await serviceA.createPlotRecord(const PlotRecordDraft(
      id: 'story-a',
      typeId: 'story',
      name: 'Only In A',
      fields: {'plotStatus': 'active'},
    ));

    await _pumpView(tester, project: projectB, service: serviceB);

    expect(find.text('Only In A'), findsNothing);
    expect(find.text('No plot records found.'), findsOneWidget);
  });

  test('plot studio view does not use duplicate persistence', () {
    final source = File('lib/plot_studio_view.dart').readAsStringSync();
    expect(source, contains('PlotService'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('authoros_database')));
  });

  testWidgets('project custom Plot types reach the editor', (tester) async {
    final project = _project('Custom Types', 'plot-custom');
    final service = PlotService(projectId: project.id, repository: repository);
    await service.registerCustomType(RecordTypeDefinition(
      id: 'heist-turn',
      name: 'Heist Turn',
      categoryId: 'plot',
      baseTypeId: 'plot-record',
      fields: const [],
      sections: const [],
      scopeType: RecordScopeType.project,
      scopeId: project.id,
      sourcePackId: 'project:${project.id}',
    ));

    // The catalogue is resolved from the registry, not the built-in list, so a
    // project type registered at runtime is offered without a code change.
    expect(
      (await service.plotTemplates()).map((definition) => definition.id),
      contains('heist-turn'),
    );

    await _pumpView(tester, project: project, service: service);
    await tester.tap(find.byKey(const ValueKey('plot-create-button')));
    await tester.pumpAndSettle();

    // Opening the menu is the only way to read the offered items: the form
    // field exposes no public `items` getter.
    await tester.tap(find.byKey(const ValueKey('plot-record-type-field')));
    await tester.pumpAndSettle();
    expect(find.text('Heist Turn'), findsWidgets);
  });

  testWidgets('the Phase 1 fixture renders without being rewritten',
      (tester) async {
    // The fixture is the closest thing to real pre-existing Plot data: a whole
    // connected story graph written straight through PlotService.
    final project = _project('Fixture', PlotPhase1Fixture.projectId);
    final service = PlotService(projectId: project.id, repository: repository);
    await PlotPhase1Fixture.seed(service);
    final seeded = await service.query.all();
    expect(seeded, isNotEmpty);

    await _pumpView(tester, project: project, service: service);

    expect(find.text(seeded.first.title), findsWidgets);

    // Nothing was migrated or rewritten to make it renderable.
    final after = await service.query.all();
    expect(after.map((record) => record.id), seeded.map((record) => record.id));
    expect(after.every((record) => record.revision == 1), isTrue);
  });

  group('application navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // The shell backdrop loops forever, which would stall pumpAndSettle.
      debugDisableAuroraAnimation = true;
    });

    tearDown(() => debugDisableAuroraAnimation = false);

    /// The real shell, at a width that uses the desktop navigation rail.
    ///
    /// Wrapped in a [StudioThemeScope] because `AuthorStudioApp` installs one
    /// above the shell in production and `PlotStudioView` resolves its tokens
    /// through `StudioThemeScope.of`, which throws when none is present.
    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellDatabase = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(shellDatabase.close);
      final theme = await _resolvedTheme();
      await tester.pumpWidget(MaterialApp(
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: AuthorStudioShell(
            project: NovelStarterKit.create(
              title: 'Northstar',
              genre: 'Fantasy',
              projectType: 'Novel',
              wordGoal: 90000,
            ),
            manuscriptStore: ManuscriptStore(
              repository: DriftConnectedDomainRepository(shellDatabase),
            ),
            themeId: 'paper',
            accentId: 'default',
            onThemeChanged: (_, __) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    /// Taps a navigation destination and lets the shell's switcher finish.
    ///
    /// Not `pumpAndSettle`: inside the shell the view reads the shared
    /// application database, which a widget test cannot open, so its loading
    /// indicator spins forever. Reaching the view is what this asserts.
    Future<void> navigateTo(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the Plot section reaches PlotStudioView', (tester) async {
      await pumpShell(tester);

      expect(find.byType(PlotStudioView), findsNothing);

      await navigateTo(tester, 'Plot');

      // The shell's Plot destination is this view, not a parallel board.
      expect(find.byType(PlotStudioView), findsOneWidget);
    });

    testWidgets('navigating away from and back to Plot works', (tester) async {
      await pumpShell(tester);

      await navigateTo(tester, 'Plot');
      expect(find.byType(PlotStudioView), findsOneWidget);

      await navigateTo(tester, 'Chapters');
      expect(find.byType(PlotStudioView), findsNothing);

      await navigateTo(tester, 'Plot');
      expect(find.byType(PlotStudioView), findsOneWidget);
    });
  });
}
