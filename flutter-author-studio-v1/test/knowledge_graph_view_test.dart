/// Widget behaviour for the Knowledge Graph studio.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/connection_types.dart';
import 'package:author_studio_v1/core/record_scope.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/knowledge_graph/knowledge_graph_view.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 21, 12);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  RecordService recordsFor(String projectId) =>
      RecordService(projectId: projectId, repository: repository);

  Future<void> create(
    String id,
    String title,
    String projectId, {
    String typeId = 'character',
  }) async {
    await recordsFor(projectId).createRecord(
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: title,
        fields: typeId == 'character' ? {'identity.fullName': title} : const {},
        createdAt: _timestamp,
        updatedAt: _timestamp,
      ),
    );
  }

  Future<void> connect(
    String projectId,
    String sourceId,
    String targetId,
    String typeId,
  ) async {
    final registry = await recordsFor(projectId).connectionRegistry();
    await ConnectionEngine(
      scopeId: projectId,
      repository: repository,
      registry: registry,
    ).connect(
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      direction:
          registry.resolve(typeId).direction == ConnectionDirection.undirected
              ? RecordLinkDirection.undirected
              : RecordLinkDirection.directed,
      timestamp: _timestamp,
    );
  }

  Future<void> seed() async {
    await create('kali', 'Kali Vale', 'project-a');
    await create('vincenzo', 'Vincenzo', 'project-a');
    await create('endovier', 'Endovier', 'project-a', typeId: 'location');
    await connect('project-a', 'kali', 'vincenzo', 'rivalOf');
    await connect('project-a', 'kali', 'endovier', 'livesIn');
  }

  /// The Studio lays out as filter rail | canvas | explorer above 980px, so
  /// the test surface has to be wide enough for that arrangement — on the
  /// default 800x600 the side panels would fall outside the viewport and be
  /// untappable.
  Future<void> pumpGraph(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeGraphView(
            projectId: 'project-a',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the graph and its mode switcher', (tester) async {
    await seed();
    await pumpGraph(tester);

    expect(find.byKey(const Key('knowledge-graph-title')), findsOneWidget);
    for (final mode in ['character', 'world', 'plot', 'manuscript', 'project']) {
      expect(find.byKey(Key('graph-mode-$mode')), findsOneWidget);
    }
    expect(find.byKey(const Key('graph-canvas-surface')), findsOneWidget);
    // Character mode anchors on Kali and draws what she connects to.
    expect(find.byKey(const Key('graph-node-kali')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-vincenzo')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-endovier')), findsOneWidget);
  });

  testWidgets('the explorer groups neighbours into buckets', (tester) async {
    await seed();
    await pumpGraph(tester);

    expect(find.byKey(const Key('graph-connection-explorer')), findsOneWidget);
    expect(find.byKey(const Key('graph-connection-summary')), findsOneWidget);
    expect(
      find.byKey(const Key('graph-explorer-node-vincenzo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('graph-explorer-node-endovier')),
      findsOneWidget,
    );
    expect(find.text('Characters · 1'), findsOneWidget);
    expect(find.text('Locations · 1'), findsOneWidget);
  });

  testWidgets('clicking a neighbour refocuses and leaves a breadcrumb',
      (tester) async {
    await seed();
    await pumpGraph(tester);

    await tester.tap(find.byKey(const Key('graph-explorer-node-vincenzo')));
    await tester.pumpAndSettle();

    // The explorer is now about Vincenzo, and Kali is behind us.
    expect(
      tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
      'Vincenzo',
    );
    expect(find.byKey(const Key('graph-breadcrumb-kali')), findsOneWidget);

    await tester.tap(find.byKey(const Key('graph-breadcrumb-kali')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
      'Kali Vale',
    );
  });

  testWidgets('deselecting a category removes that kind from the canvas',
      (tester) async {
    await seed();
    await pumpGraph(tester);

    // A mode starts with every category it allows already selected, so the
    // rail is an honest picture of what the mode shows rather than an empty
    // set that happens to mean "everything". Deselecting one hides that kind.
    expect(find.byKey(const Key('graph-node-endovier')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-vincenzo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('graph-category-filter-locations')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('graph-node-endovier')), findsNothing);
    expect(find.byKey(const Key('graph-node-vincenzo')), findsOneWidget);
  });

  testWidgets('the rail says how many nodes the filters are hiding',
      (tester) async {
    await seed();
    await pumpGraph(tester);

    await tester.tap(find.byKey(const Key('graph-category-filter-locations')));
    await tester.pumpAndSettle();

    // Never hide silently: a graph that quietly drops nodes reads as complete
    // when it is not.
    expect(find.byKey(const Key('graph-hidden-notice')), findsOneWidget);
  });

  testWidgets('switching mode re-anchors the graph', (tester) async {
    await seed();
    await pumpGraph(tester);

    await tester.tap(find.byKey(const Key('graph-mode-world')));
    await tester.pumpAndSettle();

    // World mode anchors on a place, not a person.
    expect(find.byKey(const Key('graph-node-endovier')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
      'Endovier',
    );
  });

  testWidgets('the search overlay finds a node by name', (tester) async {
    await seed();
    await pumpGraph(tester);

    await tester.tap(find.byKey(const Key('graph-search-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('graph-search-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('graph-search-field')),
      'Kali',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('graph-search-result-kali')), findsOneWidget);
  });

  testWidgets('Ctrl-K opens the search overlay', (tester) async {
    await seed();
    await pumpGraph(tester);

    // Studio-scoped, so the accelerator works without wrapping the whole
    // shell in a global Shortcuts/Actions pair.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('graph-search-field')), findsOneWidget);
  });

  testWidgets('an empty project says so rather than drawing nothing',
      (tester) async {
    await pumpGraph(tester);

    expect(find.byKey(const Key('graph-canvas-empty')), findsOneWidget);
    expect(find.byKey(const Key('graph-explorer-empty')), findsOneWidget);
  });

  testWidgets('canvas mode announces itself and keeps the nodes',
      (tester) async {
    await seed();
    await pumpGraph(tester);

    await tester.tap(find.byKey(const Key('graph-canvas-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('graph-canvas-mode-notice')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-kali')), findsOneWidget);
  });
}
