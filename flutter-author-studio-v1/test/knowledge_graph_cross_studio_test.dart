/// Cross-Studio integration: opening a record in the graph.
///
/// The graph already routed *outward* — click a node, land in its Studio.
/// These cover the other direction, which needed the record id plumbed through
/// the shell: section navigation otherwise carries only a destination, so
/// "open Kali in the graph" would arrive at the graph without Kali.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/knowledge_graph/knowledge_graph_view.dart';
import 'package:author_studio_v1/knowledge_graph/open_in_graph.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 22, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  Future<void> create(String id, String title, {required String typeId}) =>
      RecordService(projectId: 'project-a', repository: repository)
          .createRecord(
        AuthorRecord(
          id: id,
          typeId: typeId,
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          title: title,
          fields:
              typeId == 'character' ? {'identity.fullName': title} : const {},
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      );

  Future<void> pump(WidgetTester tester, {String? focusId}) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeGraphView(
            projectId: 'project-a',
            repository: repository,
            initialNodeId: focusId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('opening a record in the graph', () {
    testWidgets('the graph opens on the record it was given', (tester) async {
      await create('kali', 'Kali Vale', typeId: 'character');
      await create('vincenzo', 'Vincenzo', typeId: 'character');

      // Without a focus id the graph anchors on whatever sorts first, so
      // asking for Vincenzo has to actually mean Vincenzo.
      await pump(tester, focusId: 'vincenzo');

      expect(
        tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
        'Vincenzo',
      );
    });

    testWidgets('the mode follows the record rather than showing nothing',
        (tester) async {
      await create('kali', 'Kali Vale', typeId: 'character');
      await create('endovier', 'Endovier', typeId: 'location');

      // Character mode is the default and cannot anchor on a location. Opening
      // one from World Studio must switch mode, not render an empty graph.
      await pump(tester, focusId: 'endovier');

      expect(find.byKey(const Key('graph-mode-world')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
        'Endovier',
      );
      expect(find.byKey(const Key('graph-node-endovier')), findsOneWidget);
    });

    testWidgets('a focus id arriving later is honoured, not ignored',
        (tester) async {
      await create('kali', 'Kali Vale', typeId: 'character');
      await create('vincenzo', 'Vincenzo', typeId: 'character');

      await pump(tester);
      final first = tester
          .widget<Text>(find.byKey(const Key('graph-explorer-title')))
          .data;

      // The section is already mounted when a second "open in graph" arrives,
      // so reacting only in initState would silently drop it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeGraphView(
              projectId: 'project-a',
              repository: repository,
              initialNodeId: 'vincenzo',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(first, isNot('Vincenzo'));
      expect(
        tester.widget<Text>(find.byKey(const Key('graph-explorer-title'))).data,
        'Vincenzo',
      );
    });
  });

  group('the shared affordance', () {
    testWidgets('fires with the record it names', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpenInGraphButton(
              recordId: 'kali',
              onOpen: () => opened++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-in-graph-kali')));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('renders nothing without routing, or without a record',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // A Studio embedded without routing must not show an action
                // that cannot work.
                OpenInGraphButton(recordId: 'kali', onOpen: null),
                OpenInGraphButton(recordId: '', onOpen: _noop),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('open-in-graph-kali')), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}

void _noop() {}
