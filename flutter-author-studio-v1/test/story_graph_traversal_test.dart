/// Traversal behaviour: bounded walks, whole-project reads and path finding.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/connection_types.dart';
import 'package:author_studio_v1/core/record_scope.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/core/story_graph_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
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

  StoryGraphService graphFor(String projectId) =>
      StoryGraphService(projectId: projectId, repository: repository);

  RecordService recordsFor(String projectId) =>
      RecordService(projectId: projectId, repository: repository);

  Future<AuthorRecord> create(
    String id,
    String title,
    String projectId, {
    String typeId = 'character',
  }) =>
      recordsFor(projectId).createRecord(
        AuthorRecord(
          id: id,
          typeId: typeId,
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          title: title,
          fields:
              typeId == 'character' ? {'identity.fullName': title} : const {},
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      );

  /// Connects through the validated engine, using the direction the type
  /// declares — the engine rejects a directed link of an undirected type.
  Future<void> connect(
    String projectId,
    String sourceId,
    String targetId,
    String typeId,
  ) async {
    final registry = await recordsFor(projectId).connectionRegistry();
    final engine = ConnectionEngine(
      scopeId: projectId,
      repository: repository,
      registry: registry,
    );
    await engine.connect(
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      direction: registry.resolve(typeId).direction ==
              ConnectionDirection.undirected
          ? RecordLinkDirection.undirected
          : RecordLinkDirection.directed,
      timestamp: _timestamp,
    );
  }

  /// kali -> endovier -> harbor -> noxmere, a spatial chain three hops deep.
  Future<void> seedChain() async {
    await create('kali', 'Kali Vale', 'project-a');
    await create('endovier', 'Endovier', 'project-a', typeId: 'location');
    await create('harbor', 'The Harbor', 'project-a', typeId: 'location');
    await create('noxmere', 'Noxmere', 'project-a', typeId: 'location');
    await connect('project-a', 'kali', 'endovier', 'livesIn');
    await connect('project-a', 'harbor', 'endovier', 'locatedIn');
    await connect('project-a', 'noxmere', 'harbor', 'locatedIn');
  }

  group('getSubgraph', () {
    test('depth bounds how far the walk reaches', () async {
      await seedChain();
      final graph = graphFor('project-a');

      final one = await graph.getSubgraph('kali', depth: 1);
      expect(one.nodes.map((node) => node.id).toSet(), {'kali', 'endovier'});
      expect(one.depthReached, 1);

      final two = await graph.getSubgraph('kali', depth: 2);
      expect(two.nodes.map((node) => node.id).toSet(),
          {'kali', 'endovier', 'harbor'});
      expect(two.depthReached, 2);

      final three = await graph.getSubgraph('kali', depth: 3);
      expect(three.nodes, hasLength(4));
      expect(three.truncated, isFalse);
    });

    test('depthReached reports how far the region actually goes', () async {
      await seedChain();

      // Asking for ten hops on a three-hop chain must not claim ten.
      final subgraph = await graphFor('project-a').getSubgraph(
        'kali',
        depth: 10,
      );

      expect(subgraph.depthReached, 3);
    });

    test('edges between same-depth nodes are included, not just tree edges',
        () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await create('lucia', 'Lucia', 'project-a');
      await connect('project-a', 'kali', 'vincenzo', 'rivalOf');
      await connect('project-a', 'kali', 'lucia', 'alliedWith');
      // Vincenzo and Lucia are both one hop from Kali, and also joined to each
      // other. A spanning tree would lose that edge; a subgraph must not.
      await connect('project-a', 'vincenzo', 'lucia', 'enemyOf');

      final subgraph = await graphFor('project-a').getSubgraph(
        'kali',
        depth: 1,
      );

      expect(subgraph.edges.map((edge) => edge.typeId).toSet(),
          {'rivalOf', 'alliedWith', 'enemyOf'});
    });

    test('every edge returned has both endpoints in the node set', () async {
      await seedChain();

      final subgraph = await graphFor('project-a').getSubgraph(
        'kali',
        depth: 2,
      );

      final ids = subgraph.nodes.map((node) => node.id).toSet();
      for (final edge in subgraph.edges) {
        expect(ids, contains(edge.sourceId));
        expect(ids, contains(edge.targetId));
      }
    });

    test('the node cap truncates and says so', () async {
      await seedChain();

      final subgraph = await graphFor('project-a').getSubgraph(
        'kali',
        depth: 3,
        maxNodes: 2,
      );

      expect(subgraph.nodes, hasLength(2));
      expect(subgraph.truncated, isTrue);
    });

    test('an unknown root yields an empty subgraph, not a throw', () async {
      final subgraph = await graphFor('project-a').getSubgraph('absent');

      expect(subgraph.isEmpty, isTrue);
      expect(subgraph.truncated, isFalse);
    });

    test('a cycle terminates', () async {
      await create('a', 'A', 'project-a');
      await create('b', 'B', 'project-a');
      await create('c', 'C', 'project-a');
      await connect('project-a', 'a', 'b', 'friendOf');
      await connect('project-a', 'b', 'c', 'friendOf');
      await connect('project-a', 'c', 'a', 'friendOf');

      final subgraph = await graphFor('project-a').getSubgraph('a', depth: 10);

      expect(subgraph.nodes, hasLength(3));
    });
  });

  group('getProjectGraph', () {
    test('returns every node in the project and nothing from another',
        () async {
      await seedChain();
      await create('other', 'Other Project Character', 'project-b');

      final graph = await graphFor('project-a').getProjectGraph();

      expect(graph.nodes, hasLength(4));
      expect(graph.nodeById('other'), isNull);
    });

    test('includes manuscript nodes alongside records', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'scene-1',
          projectId: 'project-a',
          nodeType: 'scene',
          title: 'The Blood Price',
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ]);

      final graph = await graphFor('project-a').getProjectGraph();

      expect(graph.nodes.map((node) => node.id).toSet(), {'kali', 'scene-1'});
      expect(
        graph.nodeById('scene-1')!.kind,
        StoryGraphNodeKind.manuscriptNode,
      );
    });

    test('the cap truncates and says so', () async {
      await seedChain();

      final graph = await graphFor('project-a').getProjectGraph(maxNodes: 2);

      expect(graph.nodes, hasLength(2));
      expect(graph.truncated, isTrue);
    });
  });

  group('findPaths', () {
    test('finds a route and orders it from start to end', () async {
      await seedChain();

      final paths =
          await graphFor('project-a').findPaths('kali', 'noxmere');

      expect(paths, isNotEmpty);
      final path = paths.first;
      expect(path.nodes.first.id, 'kali');
      expect(path.nodes.last.id, 'noxmere');
      expect(path.length, 3);
      // `edges[i]` must actually join `nodes[i]` to `nodes[i + 1]`.
      for (var index = 0; index < path.edges.length; index++) {
        final edge = path.edges[index];
        expect(
          {edge.sourceId, edge.targetId},
          {path.nodes[index].id, path.nodes[index + 1].id},
        );
      }
    });

    test('respects the depth bound', () async {
      await seedChain();

      // Noxmere is three hops from Kali, so a two-hop search must not find it.
      expect(
        await graphFor('project-a')
            .findPaths('kali', 'noxmere', maxDepth: 2),
        isEmpty,
      );
    });

    test('shorter routes come first', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('lucia', 'Lucia', 'project-a');
      await create('cassian', 'Cassian', 'project-a');
      await connect('project-a', 'kali', 'lucia', 'alliedWith');
      await connect('project-a', 'kali', 'cassian', 'friendOf');
      await connect('project-a', 'cassian', 'lucia', 'friendOf');

      final paths = await graphFor('project-a').findPaths('kali', 'lucia');

      expect(paths.first.length, 1);
    });

    test('a node has no path to itself, and unknown ids find nothing',
        () async {
      await seedChain();
      final graph = graphFor('project-a');

      expect(await graph.findPaths('kali', 'kali'), isEmpty);
      expect(await graph.findPaths('kali', 'absent'), isEmpty);
    });

    test('disconnected nodes yield no path', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('stranger', 'Stranger', 'project-a');

      expect(
        await graphFor('project-a').findPaths('kali', 'stranger'),
        isEmpty,
      );
    });
  });
}
