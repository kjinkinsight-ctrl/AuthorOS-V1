/// Universal Story Graph — Phase 1 behaviour tests.
///
/// These run against a real database through the real repository. Nothing here
/// asserts on source text: every claim is proved by building a graph, reading
/// it back through [UniversalStoryGraphService], and checking what came out.
///
/// The fixture is deliberately heterogeneous. Decision D-3 keeps scenes and
/// chapters in manuscript persistence while everything else is an
/// [AuthorRecord], so a graph read that only proves itself on records has not
/// proved the thing that actually matters.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_id.dart';
import 'package:author_studio_v1/core/story_graph_service.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 21, 9);

const _projectA = 'project-a';
const _projectB = 'project-b';

AuthorRecord _record(
  String id,
  String title,
  String projectId, {
  String typeId = 'character',
  AuthorRecordStatus status = AuthorRecordStatus.active,
  CanonStatus canonStatus = CanonStatus.draft,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      status: status,
      canonStatus: canonStatus,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

ManuscriptNodeReference _manuscriptNode(
  String id,
  String title,
  String projectId, {
  String nodeType = 'scene',
}) =>
    ManuscriptNodeReference(
      id: id,
      projectId: projectId,
      nodeType: nodeType,
      title: title,
      createdAt: _timestamp,
      updatedAt: _timestamp,
      extensionData: const {
        'status': 'draft',
        'order': 1,
        'wordCount': 1200,
        'notes': 'Kali pays the blood price.',
      },
    );

RecordId _id(String value) => RecordId.parse(value);

/// A database with the fixture graph below already in it.
///
///   kali ── cassian ── endovier
///     │
///   scene-1 ── chapter-1
///
///   orphan            (no relationships at all)
///   deleted-ghost     (soft-deleted record, linked to kali)
///
/// Project B holds `bram ── bree`, entirely separate.
Future<(AuthorOsDatabase, DriftConnectedDomainRepository)> _fixture() async {
  final database = AuthorOsDatabase(NativeDatabase.memory());
  final repository = DriftConnectedDomainRepository(database);

  await repository.putRecordsAndLinks(
    records: [
      _record('kali', 'Kali', _projectA, canonStatus: CanonStatus.canon),
      _record('cassian', 'Cassian', _projectA),
      _record('endovier', 'Endovier', _projectA, typeId: 'location'),
      _record('orphan', 'Unconnected Note', _projectA, typeId: 'note'),
      // Created active so the relationship below is allowed, then
      // soft-deleted underneath it — exactly the shape a real project reaches
      // when a linked character is removed.
      _record('deleted-ghost', 'Removed Character', _projectA),
      _record('bram', 'Bram', _projectB),
      _record('bree', 'Bree', _projectB),
    ],
    links: const [],
  );

  await repository.putManuscriptNodes([
    _manuscriptNode('chapter-1', 'Chapter One', _projectA,
        nodeType: 'chapter'),
    _manuscriptNode('scene-1', 'The Blood Price', _projectA),
    _manuscriptNode('b-scene', 'Elsewhere', _projectB),
  ]);

  final engineA =
      ConnectionEngine(scopeId: _projectA, repository: repository);
  await engineA.connect(
    sourceId: 'kali',
    targetId: 'cassian',
    typeId: 'relatedTo',
    timestamp: _timestamp,
  );
  await engineA.connect(
    sourceId: 'cassian',
    targetId: 'endovier',
    typeId: 'locatedAt',
    timestamp: _timestamp,
  );
  await engineA.connect(
    sourceId: 'scene-1',
    targetId: 'kali',
    typeId: 'references',
    timestamp: _timestamp,
  );
  await engineA.connect(
    sourceId: 'chapter-1',
    targetId: 'scene-1',
    typeId: 'childOf',
    timestamp: _timestamp,
  );
  await engineA.connect(
    sourceId: 'kali',
    targetId: 'deleted-ghost',
    typeId: 'relatedTo',
    timestamp: _timestamp,
  );

  await repository.putRecord(
    _record(
      'deleted-ghost',
      'Removed Character',
      _projectA,
      status: AuthorRecordStatus.deleted,
    ),
  );

  final engineB =
      ConnectionEngine(scopeId: _projectB, repository: repository);
  await engineB.connect(
    sourceId: 'bram',
    targetId: 'bree',
    typeId: 'relatedTo',
    timestamp: _timestamp,
  );

  return (database, repository);
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late UniversalStoryGraphService graph;

  setUp(() async {
    final (db, repo) = await _fixture();
    database = db;
    repository = repo;
    graph = UniversalStoryGraphService(
      projectId: _projectA,
      repository: repository,
    );
  });

  tearDown(() => database.close());

  // ------------------------------------------------------------------ nodes

  group('nodes', () {
    test('a record resolves as a record-kind node', () async {
      final node = await graph.getNode(_id('kali'));

      expect(node, isNotNull);
      expect(node!.kind, StoryGraphNodeKind.record);
      expect(node.label, 'Kali');
      expect(node.typeId, 'character');
      expect(node.projectId, _projectA);
      expect(node.lifecycle, StoryGraphNodeLifecycle.active);
      expect(node.canonStatus, CanonStatus.canon);
    });

    test('a manuscript scene resolves as a manuscript-kind node', () async {
      final node = await graph.getNode(_id('scene-1'));

      expect(node, isNotNull);
      expect(node!.kind, StoryGraphNodeKind.manuscript);
      expect(node.label, 'The Blood Price');
      expect(node.typeId, 'scene');
      expect(node.projectId, _projectA);
    });

    test('both node kinds coexist in one traversal', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      final kinds = traversal.nodes.map((node) => node.kind).toSet();
      expect(kinds, containsAll(<StoryGraphNodeKind>[
        StoryGraphNodeKind.record,
        StoryGraphNodeKind.manuscript,
      ]));
    });

    test('a manuscript node carries no canon status and no prose', () async {
      final node = await graph.getNode(_id('scene-1'));

      expect(node!.canonStatus, isNull);
      // The manuscript's drafting status is exposed as metadata, deliberately
      // separate from the graph lifecycle.
      expect(node.metadata['manuscriptStatus'], 'draft');
      expect(node.metadata.containsKey('body'), isFalse);
      expect(node.metadata.containsKey('text'), isFalse);
      expect(node.metadata.containsKey('wordCount'), isFalse);
    });

    test('an unknown id resolves to null', () async {
      expect(await graph.getNode(_id('no-such-node')), isNull);
    });

    test('a soft-deleted record is still readable but marked deleted',
        () async {
      final node = await graph.getNode(_id('deleted-ghost'));

      expect(node, isNotNull);
      expect(node!.lifecycle, StoryGraphNodeLifecycle.deleted);
    });

    test('project totals count both node kinds and exclude deleted records',
        () async {
      final totals = await graph.getTotals();

      // kali, cassian, endovier, orphan (deleted-ghost excluded)
      // + chapter-1, scene-1
      expect(totals.nodeCount, 6);
      expect(totals.projectId, _projectA);
      expect(totals.edgeCount, 5);
    });
  });

  // -------------------------------------------------------- project scoping

  group('project isolation', () {
    test('a foreign node is inaccessible and leaks nothing', () async {
      expect(await graph.getNode(_id('bram')), isNull);
      expect(await graph.getNode(_id('b-scene')), isNull);
    });

    test('traversal from a foreign origin returns an empty result', () async {
      final traversal = await graph.traverse(_id('bram'));

      expect(traversal.originFound, isFalse);
      expect(traversal.nodes, isEmpty);
      expect(traversal.edges, isEmpty);
    });

    test('a project-wide snapshot contains no foreign node', () async {
      final snapshot = await graph.getSnapshot();

      for (final node in snapshot.nodes) {
        expect(node.projectId, _projectA);
      }
      expect(
        snapshot.nodes.map((node) => node.id.value),
        isNot(contains('bram')),
      );
      expect(
        snapshot.nodes.map((node) => node.id.value),
        isNot(contains('b-scene')),
      );
    });

    test('a path cannot be found into another project', () async {
      final result = await graph.findPath(_id('kali'), _id('bram'));

      expect(result.isFound, isFalse);
      expect(result.failure, StoryGraphPathFailure.destinationInaccessible);
    });

    test('each project sees only its own graph', () async {
      final other = UniversalStoryGraphService(
        projectId: _projectB,
        repository: repository,
      );

      final snapshot = await other.getSnapshot();
      expect(
        snapshot.nodes.map((node) => node.id.value).toSet(),
        {'bram', 'bree', 'b-scene'},
      );
    });
  });

  // ------------------------------------------------------------- neighbours

  group('neighbours', () {
    test('returns one hop only, in deterministic order', () async {
      final neighbours = await graph.getNeighbours(_id('kali'));

      expect(
        neighbours.map((neighbour) => neighbour.node.id.value).toList(),
        ['cassian', 'scene-1'],
      );
      // endovier is two hops away and must not appear.
      expect(
        neighbours.map((neighbour) => neighbour.node.id.value),
        isNot(contains('endovier')),
      );
    });

    test('excludes soft-deleted records by default', () async {
      final neighbours = await graph.getNeighbours(_id('kali'));

      expect(
        neighbours.map((neighbour) => neighbour.node.id.value),
        isNot(contains('deleted-ghost')),
      );
    });

    test('admits soft-deleted records when the filter asks for them',
        () async {
      final neighbours = await graph.getNeighbours(
        _id('kali'),
        filter: const StoryGraphFilter(
          lifecycles: {
            StoryGraphNodeLifecycle.active,
            StoryGraphNodeLifecycle.deleted,
          },
        ),
      );

      expect(
        neighbours.map((neighbour) => neighbour.node.id.value),
        contains('deleted-ghost'),
      );
    });

    test('reports which end of the relationship the anchor sits on', () async {
      final neighbours = await graph.getNeighbours(_id('kali'));
      final byId = {
        for (final neighbour in neighbours) neighbour.node.id.value: neighbour,
      };

      // kali -> cassian was created with kali as source.
      expect(byId['cassian']!.direction, RelationshipDirection.outgoing);
      // scene-1 -> kali was created with the scene as source.
      expect(byId['scene-1']!.direction, RelationshipDirection.incoming);
    });

    test('direction narrows the result', () async {
      final outgoing = await graph.getNeighbours(
        _id('kali'),
        direction: RelationshipDirection.outgoing,
      );
      final incoming = await graph.getNeighbours(
        _id('kali'),
        direction: RelationshipDirection.incoming,
      );

      expect(outgoing.map((n) => n.node.id.value).toList(), ['cassian']);
      expect(incoming.map((n) => n.node.id.value).toList(), ['scene-1']);
    });

    test('a manuscript node reaches its record neighbours', () async {
      final neighbours = await graph.getNeighbours(_id('scene-1'));

      expect(
        neighbours.map((neighbour) => neighbour.node.id.value).toSet(),
        {'kali', 'chapter-1'},
      );
    });

    test('an isolated node has no neighbours', () async {
      expect(await graph.getNeighbours(_id('orphan')), isEmpty);
    });

    test('a foreign anchor returns nothing', () async {
      expect(await graph.getNeighbours(_id('bram')), isEmpty);
    });
  });

  // -------------------------------------------------------------- traversal

  group('traversal', () {
    test('depth 0 returns the origin alone', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 0),
      );

      expect(traversal.nodes.map((node) => node.id.value).toList(), ['kali']);
      expect(traversal.depthOf(_id('kali')), 0);
    });

    test('depth 1 adds direct neighbours', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 1),
      );

      expect(
        traversal.nodes.map((node) => node.id.value).toSet(),
        {'kali', 'cassian', 'scene-1'},
      );
      expect(traversal.atDepth(1).map((node) => node.id.value).toList(),
          ['cassian', 'scene-1']);
    });

    test('depth 2 adds neighbours of neighbours', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      expect(
        traversal.nodes.map((node) => node.id.value).toSet(),
        {'kali', 'cassian', 'scene-1', 'endovier', 'chapter-1'},
      );
      expect(traversal.depthOf(_id('endovier')), 2);
      expect(traversal.depthOf(_id('chapter-1')), 2);
    });

    test('ordering is depth ascending then identity ascending', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      final ordered = [
        for (var depth = 0; depth <= 2; depth++)
          ...traversal.atDepth(depth).map((node) => node.id.value),
      ];
      expect(ordered, [
        'kali',
        'cassian',
        'scene-1',
        'chapter-1',
        'endovier',
      ]);
    });

    test('repeated reads return identical ordering', () async {
      final first = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );
      final second = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      expect(
        first.nodes.map((node) => node.id.value).toList(),
        second.nodes.map((node) => node.id.value).toList(),
      );
      expect(
        first.edges.map((edge) => edge.id.value).toList(),
        second.edges.map((edge) => edge.id.value).toList(),
      );
    });

    test('a cycle terminates and visits each node once', () async {
      // Close kali -> cassian -> endovier back to kali.
      final engine =
          ConnectionEngine(scopeId: _projectA, repository: repository);
      await engine.connect(
        sourceId: 'endovier',
        targetId: 'kali',
        typeId: 'relatedTo',
        timestamp: _timestamp,
      );

      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 5),
      );

      final ids = traversal.nodes.map((node) => node.id.value).toList();
      expect(ids.toSet().length, ids.length, reason: 'no node is duplicated');
      expect(ids, containsAll(<String>['kali', 'cassian', 'endovier']));
    });

    test('every edge in a traversal has both endpoints present', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      final present = traversal.nodes.map((node) => node.id).toSet();
      for (final edge in traversal.edges) {
        expect(present, contains(edge.sourceId));
        expect(present, contains(edge.targetId));
      }
    });

    test('an isolated origin traverses to itself only', () async {
      final traversal = await graph.traverse(
        _id('orphan'),
        options: const StoryGraphTraversalOptions(maxDepth: 3),
      );

      expect(traversal.nodes.map((node) => node.id.value).toList(), ['orphan']);
      expect(traversal.edges, isEmpty);
      expect(traversal.bounds.isComplete, isTrue);
    });

    test('negative depth is rejected as a programmer error', () async {
      expect(
        () => graph.traverse(
          _id('kali'),
          options: const StoryGraphTraversalOptions(maxDepth: -1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a zero node budget is rejected', () async {
      expect(
        () => graph.traverse(
          _id('kali'),
          options: const StoryGraphTraversalOptions(maxNodes: 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ------------------------------------------------------------- truncation

  group('truncation', () {
    test('a complete traversal reports itself complete', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 5),
      );

      expect(traversal.bounds.isComplete, isTrue);
      expect(traversal.bounds.isTruncated, isFalse);
    });

    test('reaching the depth limit with more to explore is reported',
        () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 1),
      );

      expect(traversal.bounds.isTruncated, isTrue);
      expect(traversal.bounds.truncatedByDepth, isTrue);
    });

    test('exhausting the node budget is reported and never silent', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 5, maxNodes: 2),
      );

      expect(traversal.nodes, hasLength(2));
      expect(traversal.bounds.truncatedByNodeBudget, isTrue);
      expect(traversal.bounds.isComplete, isFalse);
    });

    test('a bounded project snapshot reports its own truncation', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(maxNodes: 3),
      );

      expect(snapshot.nodes, hasLength(3));
      expect(snapshot.bounds.truncatedByNodeBudget, isTrue);
    });

    test('an unbounded-looking snapshot is still complete when it fits',
        () async {
      final snapshot = await graph.getSnapshot();

      expect(snapshot.bounds.isComplete, isTrue);
      expect(
        snapshot.nodes.map((node) => node.id.value).toSet(),
        {'kali', 'cassian', 'endovier', 'orphan', 'chapter-1', 'scene-1'},
      );
    });
  });

  // ------------------------------------------------------------------- path

  group('shortest path', () {
    test('finds a direct path', () async {
      final result = await graph.findPath(_id('kali'), _id('cassian'));

      expect(result.isFound, isTrue);
      expect(result.path!.length, 1);
      expect(
        result.path!.nodes.map((node) => node.id.value).toList(),
        ['kali', 'cassian'],
      );
    });

    test('finds a multi-hop path across both node kinds', () async {
      final result = await graph.findPath(
        _id('endovier'),
        _id('chapter-1'),
        options: const StoryGraphTraversalOptions(maxDepth: 6),
      );

      expect(result.isFound, isTrue);
      expect(
        result.path!.nodes.map((node) => node.id.value).toList(),
        ['endovier', 'cassian', 'kali', 'scene-1', 'chapter-1'],
      );
    });

    test('a path satisfies nodes == edges + 1', () async {
      final result = await graph.findPath(
        _id('endovier'),
        _id('chapter-1'),
        options: const StoryGraphTraversalOptions(maxDepth: 6),
      );

      final path = result.path!;
      expect(path.nodes.length, path.edges.length + 1);
    });

    test('an invalid path cannot be constructed', () {
      expect(
        () => StoryGraphPath(
          nodes: [
            StoryGraphNode(
              id: _id('a'),
              kind: StoryGraphNodeKind.record,
              projectId: _projectA,
              label: 'A',
              typeId: 'character',
            ),
          ],
          edges: [
            StoryGraphEdge(
              id: RelationshipId.parse('edge'),
              sourceId: _id('a'),
              targetId: _id('b'),
              typeId: 'relatedTo',
              projectId: _projectA,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a path to self is length zero', () async {
      final result = await graph.findPath(_id('kali'), _id('kali'));

      expect(result.isFound, isTrue);
      expect(result.path!.length, 0);
      expect(result.path!.nodes, hasLength(1));
    });

    test('no path is a value, not an exception', () async {
      final result = await graph.findPath(_id('kali'), _id('orphan'));

      expect(result.isFound, isFalse);
      expect(result.failure, StoryGraphPathFailure.unreachableWithinBounds);
    });

    test('a failure carries the bounds the search ran under', () async {
      final result = await graph.findPath(
        _id('endovier'),
        _id('chapter-1'),
        options: const StoryGraphTraversalOptions(maxDepth: 1),
      );

      expect(result.isFound, isFalse);
      expect(result.failure, StoryGraphPathFailure.unreachableWithinBounds);
      expect(result.searchBounds!.isTruncated, isTrue);
    });

    test('an unknown origin is reported distinctly from no path', () async {
      final result = await graph.findPath(_id('nope'), _id('kali'));

      expect(result.failure, StoryGraphPathFailure.originInaccessible);
    });

    test('cycles do not break path finding', () async {
      final engine =
          ConnectionEngine(scopeId: _projectA, repository: repository);
      await engine.connect(
        sourceId: 'endovier',
        targetId: 'kali',
        typeId: 'relatedTo',
        timestamp: _timestamp,
      );

      final result = await graph.findPath(_id('kali'), _id('endovier'));

      expect(result.isFound, isTrue);
      // The cycle creates a one-hop route, which is now the shortest.
      expect(result.path!.length, 1);
    });
  });

  // ---------------------------------------------------------------- filters

  group('filters', () {
    test('node kind filter keeps manuscript nodes out', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(
          filter: StoryGraphFilter(nodeKinds: {StoryGraphNodeKind.record}),
        ),
      );

      expect(
        snapshot.nodes.every(
          (node) => node.kind == StoryGraphNodeKind.record,
        ),
        isTrue,
      );
    });

    test('node kind filter can isolate the manuscript domain', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(
          filter: StoryGraphFilter(nodeKinds: {StoryGraphNodeKind.manuscript}),
        ),
      );

      expect(
        snapshot.nodes.map((node) => node.id.value).toSet(),
        {'chapter-1', 'scene-1'},
      );
    });

    test('record type filter narrows by type id', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(
          filter: StoryGraphFilter(recordTypeIds: {'location'}),
        ),
      );

      expect(
        snapshot.nodes.map((node) => node.id.value).toList(),
        ['endovier'],
      );
    });

    test('relationship filter narrows traversal', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(
          maxDepth: 3,
          filter: StoryGraphFilter(relationshipTypeIds: {'relatedTo'}),
        ),
      );

      // Only the kali--cassian relatedTo edge is admitted; the scene's
      // `references` edge and the chapter's `childOf` edge are not.
      expect(
        traversal.nodes.map((node) => node.id.value).toSet(),
        {'kali', 'cassian'},
      );
    });

    test('canon filter admits only records that declare it', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(
          filter: StoryGraphFilter(canonStatuses: {CanonStatus.canon}),
        ),
      );

      expect(snapshot.nodes.map((node) => node.id.value).toList(), ['kali']);
    });

    test('an empty filter means any', () async {
      const filter = StoryGraphFilter();

      expect(filter.isUnfiltered, isTrue);
      final snapshot = await graph.getSnapshot();
      expect(snapshot.nodes.length, greaterThan(1));
    });

    test('a filtered snapshot never contains a dangling edge', () async {
      final snapshot = await graph.getSnapshot(
        options: const StoryGraphTraversalOptions(
          filter: StoryGraphFilter(nodeKinds: {StoryGraphNodeKind.record}),
        ),
      );

      final present = snapshot.nodes.map((node) => node.id).toSet();
      for (final edge in snapshot.edges) {
        expect(present, contains(edge.sourceId));
        expect(present, contains(edge.targetId));
      }
      // The scene--kali edge must be gone, because the scene is filtered out.
      expect(
        snapshot.edges.any(
          (edge) =>
              edge.sourceId.value == 'scene-1' ||
              edge.targetId.value == 'scene-1',
        ),
        isFalse,
      );
    });
  });

  // ----------------------------------------------------------------- edges

  group('edges', () {
    test('a wildcard relationship type is reported exactly as persisted',
        () async {
      final neighbours = await graph.getNeighbours(_id('kali'));
      final cassian = neighbours.firstWhere(
        (neighbour) => neighbour.node.id.value == 'cassian',
      );

      expect(cassian.edge.typeId, 'relatedTo');
      expect(cassian.edge.projectId, _projectA);
    });

    test('a manuscript relationship is a first-class graph edge', () async {
      final neighbours = await graph.getNeighbours(_id('chapter-1'));

      expect(neighbours.single.edge.typeId, 'childOf');
      expect(neighbours.single.node.kind, StoryGraphNodeKind.manuscript);
    });

    test('a snapshot exposes relationships between reached nodes', () async {
      final traversal = await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 2),
      );

      expect(
        traversal.edges.map((edge) => edge.typeId).toSet(),
        containsAll(<String>['relatedTo', 'locatedAt', 'references',
          'childOf']),
      );
    });
  });

  // -------------------------------------------------------------- boundary

  group('boundaries', () {
    test('a writing session can never become a graph node', () async {
      await repository.putWritingSession(
        WritingSession(
          id: 'session-1',
          projectId: _projectA,
          startedAt: _timestamp,
          endedAt: _timestamp.add(const Duration(minutes: 30)),
          startingWordCount: 1200,
          endingWordCount: 2100,
          wordsAdded: 900,
          wordsRemoved: 0,
          chapterId: 'chapter-1',
          sceneId: 'scene-1',
        ),
      );

      // Not resolvable as a node.
      expect(await graph.getNode(_id('session-1')), isNull);

      // Not reachable from the scene it references.
      final traversal = await graph.traverse(
        _id('scene-1'),
        options: const StoryGraphTraversalOptions(maxDepth: 5),
      );
      expect(
        traversal.nodes.map((node) => node.id.value),
        isNot(contains('session-1')),
      );

      // Not present in the project snapshot, and not counted as a node.
      final snapshot = await graph.getSnapshot();
      expect(
        snapshot.nodes.map((node) => node.id.value),
        isNot(contains('session-1')),
      );
      expect((await graph.getTotals()).nodeCount, 6);
    });

    test('reading the graph writes nothing', () async {
      Future<List<String>> rowIds(String table, String column) async {
        final rows =
            await database.customSelect('SELECT $column FROM $table').get();
        return rows.map((row) => row.read<String>(column)).toList()..sort();
      }

      final recordsBefore = await rowIds('author_record_rows', 'id');
      final linksBefore = await rowIds('record_link_rows', 'id');
      final nodesBefore = await rowIds('manuscript_node_rows', 'id');
      final versionsBefore = await rowIds('record_version_rows', 'id');
      final auditBefore = await rowIds('audit_event_rows', 'id');

      await graph.getNode(_id('kali'));
      await graph.getNeighbours(_id('kali'));
      await graph.traverse(
        _id('kali'),
        options: const StoryGraphTraversalOptions(maxDepth: 5),
      );
      await graph.findPath(_id('endovier'), _id('chapter-1'));
      await graph.getSnapshot();
      await graph.getTotals();

      expect(await rowIds('author_record_rows', 'id'), recordsBefore);
      expect(await rowIds('record_link_rows', 'id'), linksBefore);
      expect(await rowIds('manuscript_node_rows', 'id'), nodesBefore);
      expect(await rowIds('record_version_rows', 'id'), versionsBefore);
      expect(await rowIds('audit_event_rows', 'id'), auditBefore);
    });

    test('graph objects cannot be mutated by a consumer', () async {
      final snapshot = await graph.getSnapshot();

      expect(
        () => snapshot.nodes.add(snapshot.nodes.first),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.nodes.first.metadata['injected'] = true,
        throwsUnsupportedError,
      );
      final traversal = await graph.traverse(_id('kali'));
      expect(
        () => traversal.depths[_id('kali')] = 99,
        throwsUnsupportedError,
      );
    });
  });
}
