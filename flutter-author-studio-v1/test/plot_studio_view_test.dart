import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/plot_studio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/plot_phase_1_fixture.dart';

const projectId = 'project-plot';
final timestamp = DateTime.utc(2026, 8, 20, 10);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late PlotService plot;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    plot = PlotService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> seed({
    required String id,
    required String name,
    String typeId = 'plotline',
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
  }) =>
      plot.createPlotRecord(
        PlotRecordDraft(
          id: id,
          typeId: typeId,
          name: name,
          fields: fields,
          tags: tags,
        ),
        timestamp: timestamp,
      );

  testWidgets('the empty plot explains itself instead of rendering a blank board',
      (tester) async {
    await _pump(tester, repository);

    expect(find.byKey(const Key('plot-studio-view')), findsOneWidget);
    expect(find.byKey(const Key('plot-empty-state')), findsOneWidget);
    expect(find.text('This story has no plot yet.'), findsOneWidget);
    expect(find.byKey(const Key('plot-empty-create-button')), findsOneWidget);
  });

  testWidgets('existing plot data renders through the service', (tester) async {
    await seed(
      id: 'plotline-salt',
      name: 'The salt conspiracy',
      fields: {
        'purpose': 'Pull the harbour into the war.',
        'plotStatus': 'active',
      },
      tags: const ['harbour', 'politics'],
    );
    await seed(id: 'beat-arrival', name: 'The envoy lands', typeId: 'beat');

    await _pump(tester, repository);

    expect(find.byKey(const Key('plot-empty-state')), findsNothing);
    expect(
        find.byKey(const Key('plot-record-tile-plotline-salt')), findsOneWidget);
    expect(
        find.byKey(const Key('plot-record-tile-beat-arrival')), findsOneWidget);
    expect(find.text('The salt conspiracy'), findsOneWidget);
    expect(find.text('Pull the harbour into the war.'), findsOneWidget);
    expect(find.text('harbour'), findsOneWidget);
  });

  testWidgets('creating a record writes one Universal Record via PlotService',
      (tester) async {
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-empty-create-button'));
    expect(find.byKey(const Key('plot-record-dialog')), findsOneWidget);

    _choose<String>(tester, const Key('plot-dialog-type-field'), 'act');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plot-dialog-name-field')),
      'Act One',
    );
    await tester.enterText(
      find.byKey(const Key('plot-dialog-field-purpose')),
      'Set the harbour alight.',
    );
    await _tap(tester, const Key('plot-dialog-save-button'));

    final stored = await plot.query.byType('act');
    expect(stored, hasLength(1));
    expect(stored.single.title, 'Act One');
    expect(stored.single.typeId, 'act');
    expect(stored.single.fields['purpose'], 'Set the harbour alight.');
    // The record is a Universal Record in the shared table, owned by Plot.
    expect(stored.single.projectId, projectId);
    expect(stored.single.extensionData['plotStudio'], isTrue);
    expect(find.text('Act One'), findsOneWidget);
  });

  testWidgets('the create dialog refuses an unnamed record', (tester) async {
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-empty-create-button'));
    await _tap(tester, const Key('plot-dialog-save-button'));

    expect(find.byKey(const Key('plot-record-dialog')), findsOneWidget);
    expect(find.text('A plot record needs a name.'), findsOneWidget);
    expect(await plot.query.all(), isEmpty);
  });

  testWidgets('editing goes through the service and keeps untouched fields',
      (tester) async {
    await seed(
      id: 'plotline-salt',
      name: 'The salt conspiracy',
      fields: {
        'purpose': 'Pull the harbour into the war.',
        // Ordering is not in the Phase 1 editor: it must survive a save.
        'narrativeOrder': 4,
      },
    );
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-record-tile-plotline-salt'));
    expect(find.byKey(const Key('plot-record-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('plot-dialog-name-field')),
      'The salt war',
    );
    await _tap(tester, const Key('plot-dialog-save-button'));

    final updated = await plot.getPlotRecord('plotline-salt');
    expect(updated, isNotNull);
    expect(updated!.title, 'The salt war');
    expect(updated.fields['name'], 'The salt war');
    expect(updated.fields['purpose'], 'Pull the harbour into the war.');
    expect(updated.fields['narrativeOrder'], 4);
    // The shared record service versions the edit; the view keeps no history.
    expect(updated.revision, greaterThan(1));
    expect(await plot.getPlotHistory('plotline-salt'), isNotEmpty);
  });

  testWidgets('deleting archives through the service and stays reversible',
      (tester) async {
    await seed(id: 'beat-arrival', name: 'The envoy lands', typeId: 'beat');
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-record-menu-beat-arrival'));
    await _tapText(tester, 'Delete');
    expect(find.byKey(const Key('plot-delete-dialog')), findsOneWidget);
    await _tap(tester, const Key('plot-delete-confirm-button'));

    // Soft delete only: the row survives so connections and history hold.
    final archived = await plot.getPlotRecord('beat-arrival');
    expect(archived, isNotNull);
    expect(archived!.status, AuthorRecordStatus.archived);
    expect(find.byKey(const Key('plot-record-tile-beat-arrival')), findsNothing);

    await _tap(tester, const Key('plot-archived-toggle'));
    expect(
        find.byKey(const Key('plot-record-tile-beat-arrival')), findsOneWidget);

    await _tap(tester, const Key('plot-record-menu-beat-arrival'));
    await _tapText(tester, 'Restore');
    final restored = await plot.getPlotRecord('beat-arrival');
    expect(restored!.status, AuthorRecordStatus.active);
  });

  testWidgets('cancelling a delete leaves the record active', (tester) async {
    await seed(id: 'beat-arrival', name: 'The envoy lands', typeId: 'beat');
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-record-menu-beat-arrival'));
    await _tapText(tester, 'Delete');
    await _tap(tester, const Key('plot-delete-cancel-button'));

    final record = await plot.getPlotRecord('beat-arrival');
    expect(record!.status, AuthorRecordStatus.active);
    expect(
        find.byKey(const Key('plot-record-tile-beat-arrival')), findsOneWidget);
  });

  testWidgets('duplicating uses the shared record service', (tester) async {
    await seed(id: 'beat-arrival', name: 'The envoy lands', typeId: 'beat');
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-record-menu-beat-arrival'));
    await _tapText(tester, 'Duplicate');

    final beats = await plot.query.byType('beat');
    expect(beats, hasLength(2));
    expect(
      beats.map((record) => record.title),
      containsAll(const ['The envoy lands', 'The envoy lands copy']),
    );
  });

  testWidgets('search and the type filter narrow the board', (tester) async {
    await seed(id: 'plotline-salt', name: 'The salt conspiracy');
    await seed(id: 'beat-arrival', name: 'The envoy lands', typeId: 'beat');
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('plot-search-field')),
      'envoy',
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('plot-record-tile-beat-arrival')), findsOneWidget);
    expect(find.byKey(const Key('plot-record-tile-plotline-salt')), findsNothing);

    await tester.enterText(find.byKey(const Key('plot-search-field')), '');
    await tester.pumpAndSettle();
    _choose<String>(tester, const Key('plot-type-filter'), 'plotline');
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('plot-record-tile-plotline-salt')), findsOneWidget);
    expect(find.byKey(const Key('plot-record-tile-beat-arrival')), findsNothing);

    // A filter that hides everything still explains itself.
    await tester.enterText(
      find.byKey(const Key('plot-search-field')),
      'nothing matches this',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plot-empty-state')), findsOneWidget);
    expect(find.text('No plot records match these filters.'), findsOneWidget);
  });

  testWidgets('warning-only validation is shown and never blocks authoring',
      (tester) async {
    // A setup with no payoff is exactly the creative warning Plot Studio
    // raises, and it must not stop the writer from saving anything.
    await seed(
      id: 'foreshadow-knife',
      name: 'The knife on the mantel',
      typeId: 'foreshadowing',
    );
    await _pump(tester, repository);

    expect(find.byKey(const Key('plot-validation-panel')), findsOneWidget);
    expect(
      find.text(
        'These are creative prompts, not errors. Nothing here blocks '
        'writing or saving.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('plot-new-record-button')), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('plot-new-record-button')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('project custom Plot types appear without a code change',
      (tester) async {
    await plot.registerCustomType(
      const RecordTypeDefinition(
        id: 'heist-turn',
        name: 'Heist Turn',
        categoryId: 'plot',
        baseTypeId: 'plot-record',
        fields: [],
        sections: [],
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        sourcePackId: 'project:$projectId',
      ),
    );
    expect(
      (await plot.plotTemplates()).map((template) => template.id),
      contains('heist-turn'),
    );
    await _pump(tester, repository);

    await _tap(tester, const Key('plot-empty-create-button'));
    // The catalogue is data-driven: the new type is offered without a UI list.
    _choose<String>(tester, const Key('plot-dialog-type-field'), 'heist-turn');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plot-dialog-name-field')),
      'The vault swap',
    );
    await _tap(tester, const Key('plot-dialog-save-button'));

    final stored = await plot.query.byType('heist-turn');
    expect(stored, hasLength(1));
    expect(stored.single.title, 'The vault swap');
  });

  testWidgets('records from another project never leak into this board',
      (tester) async {
    await seed(id: 'plotline-salt', name: 'The salt conspiracy');
    await PlotService(projectId: 'project-other', repository: repository)
        .createPlotRecord(
      const PlotRecordDraft(
        id: 'plotline-other',
        typeId: 'plotline',
        name: 'Someone else story',
      ),
      timestamp: timestamp,
    );

    await _pump(tester, repository);

    expect(
        find.byKey(const Key('plot-record-tile-plotline-salt')), findsOneWidget);
    expect(find.byKey(const Key('plot-record-tile-plotline-other')), findsNothing);
  });

  testWidgets('Plot data written before this view still renders', (tester) async {
    // The Phase 1 fixture is the Plot data that existed before this view: a
    // whole connected story graph written straight through PlotService. The
    // view must read it as-is, with no migration and no second store.
    final fixturePlot = PlotService(
      projectId: PlotPhase1Fixture.projectId,
      repository: repository,
    );
    await PlotPhase1Fixture.seed(fixturePlot);
    final seeded = await fixturePlot.query.all();
    expect(seeded, isNotEmpty);

    await _pump(tester, repository, projectId: PlotPhase1Fixture.projectId);

    expect(find.byKey(const Key('plot-empty-state')), findsNothing);
    for (final record in seeded.take(3)) {
      expect(
        find.byKey(Key('plot-record-tile-${record.id}')),
        findsOneWidget,
        reason: '${record.id} should render',
      );
    }
    // Nothing was rewritten to make it renderable.
    final after = await fixturePlot.query.all();
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
    Future<ManuscriptStore> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellDatabase = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(shellDatabase.close);
      final store = ManuscriptStore(
        repository: DriftConnectedDomainRepository(shellDatabase),
      );
      await tester.pumpWidget(MaterialApp(
        home: AuthorStudioShell(
          project: NovelStarterKit.create(
            title: 'Northstar',
            genre: 'Fantasy',
            projectType: 'Novel',
            wordGoal: 90000,
          ),
          manuscriptStore: store,
          themeId: 'paper',
          accentId: 'default',
          onThemeChanged: (_, __) {},
        ),
      ));
      await tester.pumpAndSettle();
      return store;
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

Future<void> _pump(
  WidgetTester tester,
  DriftConnectedDomainRepository repository, {
  String projectId = projectId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PlotStudioView(
            projectId: projectId,
            repository: repository,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Drives a dropdown without depending on menu overlays.
void _choose<T>(WidgetTester tester, Key key, T value) {
  final field = tester.widget<DropdownButtonFormField<T>>(find.byKey(key));
  field.onChanged?.call(value);
}
