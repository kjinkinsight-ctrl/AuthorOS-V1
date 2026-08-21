import 'dart:io';

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
}
