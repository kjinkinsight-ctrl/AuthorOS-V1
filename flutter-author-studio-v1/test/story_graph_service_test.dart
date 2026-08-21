/// Behaviour tests for the Story Graph read model.
///
/// Everything here runs against a real in-memory database through the same
/// validated write paths a Studio uses, so the assertions are about behaviour
/// rather than about how the service is written.
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

  Future<ConnectionEngine> engineFor(String projectId) async =>
      ConnectionEngine(
        scopeId: projectId,
        repository: repository,
        registry: await recordsFor(projectId).connectionRegistry(),
      );

  AuthorRecord record(
    String id,
    String title,
    String projectId, {
    String typeId = 'character',
    String? bookId,
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        bookId: bookId,
        title: title,
        // `identity.fullName` is the one required field on `character`, so a
        // validated create needs it.
        fields: typeId == 'character' ? {'identity.fullName': title} : const {},
        createdAt: _timestamp,
        updatedAt: _timestamp,
      );

  Future<AuthorRecord> create(
    String id,
    String title,
    String projectId, {
    String typeId = 'character',
    String? bookId,
  }) =>
      recordsFor(projectId).createRecord(
        record(id, title, projectId, typeId: typeId, bookId: bookId),
      );

  /// Connects through the validated engine, using the direction the type
  /// declares. `friendOf` and its siblings are undirected and the engine
  /// rejects a directed link of an undirected type, so the direction is read
  /// from the registry rather than assumed.
  Future<RecordLink> connect(
    String projectId,
    String sourceId,
    String targetId,
    String typeId,
  ) async {
    final registry = await recordsFor(projectId).connectionRegistry();
    final definition = registry.resolve(typeId);
    return (await engineFor(projectId)).connect(
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      direction: definition.direction == ConnectionDirection.undirected
          ? RecordLinkDirection.undirected
          : RecordLinkDirection.directed,
      timestamp: _timestamp,
    );
  }

  Future<void> putScene(String id, String title, String projectId) =>
      repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: id,
          projectId: projectId,
          nodeType: 'scene',
          title: title,
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ]);

  group('getNode — one call, both node kinds', () {
    test('a record resolves with its category and capability flags', () async {
      await create('kali', 'Kali Vale', 'project-a');

      final node = await graphFor('project-a').getNode('kali');

      expect(node, isNotNull);
      expect(node!.kind, StoryGraphNodeKind.record);
      expect(node.typeId, 'character');
      expect(node.categoryId, 'characters');
      expect(node.bucket, StoryGraphBucket.characters);
      expect(node.versioned, isTrue);
      expect(node.inspectable, isTrue);
      expect(node.lifecycleStatus, AuthorRecordStatus.active);
    });

    test('a manuscript node resolves, and admits what it cannot do', () async {
      await putScene('scene-1', 'The Blood Price', 'project-a');

      final node = await graphFor('project-a').getNode('scene-1');

      expect(node, isNotNull);
      expect(node!.kind, StoryGraphNodeKind.manuscriptNode);
      expect(node.typeId, 'scene');
      expect(node.bucket, StoryGraphBucket.chapters);
      // A manuscript node has no version, audit, canon or lifecycle column.
      // The union must report the absence rather than invent a value, or a
      // view will offer history that cannot exist.
      expect(node.versioned, isFalse);
      expect(node.canonStatus, isNull);
      expect(node.lifecycleStatus, isNull);
      expect(node.inspectable, isFalse);
      // Deletable since Phase 0 made the projection reconciling.
      expect(node.deletable, isTrue);
    });

    test('another project\'s node is not visible', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await putScene('scene-1', 'The Blood Price', 'project-a');

      final other = graphFor('project-b');
      expect(await other.getNode('kali'), isNull);
      expect(await other.getNode('scene-1'), isNull);
    });

    test('getNodes hydrates both kinds together', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await putScene('scene-1', 'The Blood Price', 'project-a');

      final nodes =
          await graphFor('project-a').getNodes(['kali', 'scene-1', 'absent']);

      expect(nodes.keys.toSet(), {'kali', 'scene-1'});
      expect(nodes['kali']!.kind, StoryGraphNodeKind.record);
      expect(nodes['scene-1']!.kind, StoryGraphNodeKind.manuscriptNode);
    });
  });

  group('getNeighbours — the Connection Explorer read', () {
    setUp(() async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await create('endovier', 'Endovier', 'project-a', typeId: 'location');
      await create('red-widow', 'Red Widow', 'project-a',
          typeId: 'plot-thread');
      await create('dossier', 'Widow Dossier', 'project-a',
          typeId: 'research-entry');
      await putScene('scene-1', 'The Blood Price', 'project-a');

      await connect('project-a', 'kali', 'vincenzo', 'rivalOf');
      await connect('project-a', 'kali', 'endovier', 'livesIn');
      await connect('project-a', 'kali', 'red-widow', 'pursues');
      await connect('project-a', 'kali', 'scene-1', 'appearsIn');
      await connect('project-a', 'dossier', 'kali', 'documents');
    });

    test('neighbours group into the explorer buckets', () async {
      final neighbourhood = await graphFor('project-a').getNeighbours('kali');

      expect(neighbourhood, isNotNull);
      expect(neighbourhood!.centre.title, 'Kali Vale');
      expect(neighbourhood.neighbourCount, 5);
      expect(neighbourhood.buckets[StoryGraphBucket.characters]!.single.id,
          'vincenzo');
      expect(neighbourhood.buckets[StoryGraphBucket.locations]!.single.id,
          'endovier');
      expect(neighbourhood.buckets[StoryGraphBucket.plotlines]!.single.id,
          'red-widow');
      expect(neighbourhood.buckets[StoryGraphBucket.chapters]!.single.id,
          'scene-1');
      expect(neighbourhood.buckets[StoryGraphBucket.research]!.single.id,
          'dossier');
      expect(neighbourhood.truncated, isFalse);
    });

    test('incoming and outgoing can be asked for separately', () async {
      final graph = graphFor('project-a');

      final outgoing = await graph.getNeighbours(
        'kali',
        direction: StoryGraphDirection.outgoing,
      );
      final incoming = await graph.getNeighbours(
        'kali',
        direction: StoryGraphDirection.incoming,
      );

      // `documents` runs research -> character, so it is the only edge that
      // arrives at Kali rather than leaving her.
      expect(incoming!.neighbours.map((node) => node.id), ['dossier']);
      expect(
        outgoing!.neighbours.map((node) => node.id),
        isNot(contains('dossier')),
      );
      expect(outgoing.neighbourCount, 4);
    });

    test('a category filter removes nodes from the view', () async {
      final neighbourhood = await graphFor('project-a').getNeighbours(
        'kali',
        filter: const StoryGraphFilter(categoryIds: {'characters'}),
      );

      expect(neighbourhood!.neighbours.map((node) => node.id), ['vincenzo']);
      expect(neighbourhood.buckets.keys, [StoryGraphBucket.characters]);
    });

    test('every edge returned points at a node that was kept', () async {
      final neighbourhood = await graphFor('project-a').getNeighbours(
        'kali',
        filter: const StoryGraphFilter(categoryIds: {'characters'}),
      );

      final keptIds = neighbourhood!.neighbours.map((node) => node.id).toSet();
      for (final edge in neighbourhood.edges) {
        expect(keptIds, contains(edge.otherEnd('kali')));
      }
    });

    test('the node cap truncates and says so', () async {
      final neighbourhood = await graphFor('project-a').getNeighbours(
        'kali',
        maxNodes: 2,
      );

      expect(neighbourhood!.neighbourCount, 2);
      expect(neighbourhood.truncated, isTrue);
    });

    test('derived edges arrive separately and are empty for now', () async {
      final neighbourhood = await graphFor('project-a').getNeighbours('kali');

      expect(neighbourhood!.derivedEdges, isEmpty);
      expect(await graphFor('project-a').getDerivedEdges('kali'), isEmpty);
    });
  });

  group('filters that protect the view from itself', () {
    test('relatedTo is hidden by default and revealable', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await connect('project-a', 'kali', 'vincenzo', 'relatedTo');

      final graph = graphFor('project-a');

      // relatedTo is an undirected wildcard suggested on every record type.
      // Left on, it dominates every view it appears in.
      expect((await graph.getNeighbours('kali'))!.neighbours, isEmpty);
      expect(
        (await graph.getNeighbours(
          'kali',
          filter: const StoryGraphFilter(includeRelatedTo: true),
        ))!
            .neighbours
            .single
            .id,
        'vincenzo',
      );
    });

    test('wildcard edges are hidden by default and revealable', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('red-widow', 'Red Widow', 'project-a',
          typeId: 'plot-thread');
      // `opposes` is a `*` -> `*` plot edge: a real relationship with no type
      // discipline behind it.
      await connect('project-a', 'kali', 'red-widow', 'opposes');

      final graph = graphFor('project-a');
      expect((await graph.getNeighbours('kali'))!.neighbours, isEmpty);
      expect(
        (await graph.getNeighbours(
          'kali',
          filter: const StoryGraphFilter(includeWildcardEdges: true),
        ))!
            .neighbours
            .single
            .id,
        'red-widow',
      );
    });

    test('naming a wildcard type explicitly beats the wildcard filter',
        () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('red-widow', 'Red Widow', 'project-a',
          typeId: 'plot-thread');
      await connect('project-a', 'kali', 'red-widow', 'opposes');

      // The Plot mode depends on this: `plannedFor`, `fulfilledBy`,
      // `resolvesIn` and `opposes` are the only edges plot has, and they are
      // all wildcards. Asking for one by name has to mean it.
      final neighbourhood = await graphFor('project-a').getNeighbours(
        'kali',
        filter: const StoryGraphFilter(edgeTypeIds: {'opposes'}),
      );

      expect(neighbourhood!.neighbours.single.id, 'red-widow');
    });

    test('soft-deleted nodes are hidden by default and revealable', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await connect('project-a', 'kali', 'vincenzo', 'rivalOf');
      // Deleting is soft, and the edge deliberately survives it. A view that
      // forgot the filter would render a deleted character as live.
      await recordsFor('project-a').deleteRecord('vincenzo');

      final graph = graphFor('project-a');
      expect((await graph.getNeighbours('kali'))!.neighbours, isEmpty);
      expect(
        (await graph.getNeighbours(
          'kali',
          filter: const StoryGraphFilter(includeDeleted: true),
        ))!
            .neighbours
            .single
            .id,
        'vincenzo',
      );
    });

    test('a book scope narrows to that book only', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('one', 'Book One Ally', 'project-a', bookId: 'book-1');
      await create('two', 'Book Two Ally', 'project-a', bookId: 'book-2');
      await connect('project-a', 'kali', 'one', 'alliedWith');
      await connect('project-a', 'kali', 'two', 'alliedWith');

      final neighbourhood = await graphFor('project-a').getNeighbours(
        'kali',
        filter: const StoryGraphFilter(bookId: 'book-1'),
      );

      expect(neighbourhood!.neighbours.map((node) => node.id), ['one']);
    });
  });

  group('connectionSummary', () {
    test('counts every bucket, past the node cap', () async {
      await create('kali', 'Kali Vale', 'project-a');
      for (var index = 0; index < 12; index++) {
        await create('friend-$index', 'Friend $index', 'project-a');
        await connect('project-a', 'kali', 'friend-$index', 'friendOf');
      }
      await create('endovier', 'Endovier', 'project-a', typeId: 'location');
      await connect('project-a', 'kali', 'endovier', 'livesIn');

      final summary = await graphFor('project-a').connectionSummary('kali');

      expect(summary!.node.title, 'Kali Vale');
      expect(summary.countFor(StoryGraphBucket.characters), 12);
      expect(summary.countFor(StoryGraphBucket.locations), 1);
      expect(summary.total, 13);
      expect(summary.populated, [
        StoryGraphBucket.characters,
        StoryGraphBucket.locations,
      ]);
    });

    test('an unknown node summarises to nothing rather than throwing',
        () async {
      expect(await graphFor('project-a').connectionSummary('absent'), isNull);
    });
  });

  group('project isolation', () {
    test('two projects never see each other, even with matching ids',
        () async {
      await create('kali', 'Kali A', 'project-a');
      await create('ally', 'Ally A', 'project-a');
      await connect('project-a', 'kali', 'ally', 'friendOf');

      await create('kali-b', 'Kali B', 'project-b');
      await create('ally-b', 'Ally B', 'project-b');
      await connect('project-b', 'kali-b', 'ally-b', 'friendOf');

      final a = await graphFor('project-a').getNeighbours('kali');
      expect(a!.neighbours.single.title, 'Ally A');

      expect(await graphFor('project-b').getNeighbours('kali'), isNull);
      expect(
        (await graphFor('project-a').getSubgraph('kali')).nodeById('ally-b'),
        isNull,
      );
    });
  });

  group('batch repository queries', () {
    test('recordsByIds returns only the ids that are records', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await putScene('scene-1', 'The Blood Price', 'project-a');

      final records =
          await repository.recordsByIds(['kali', 'vincenzo', 'scene-1', 'x']);

      expect(records.map((record) => record.id), ['kali', 'vincenzo']);
    });

    test('manuscriptNodesByIds returns only the ids that are nodes', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await putScene('scene-1', 'The Blood Price', 'project-a');

      final nodes =
          await repository.manuscriptNodesByIds(['kali', 'scene-1', 'x']);

      expect(nodes.map((node) => node.id), ['scene-1']);
    });

    test('linksForEntities finds both directions and filters by type',
        () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await create('endovier', 'Endovier', 'project-a', typeId: 'location');
      await connect('project-a', 'kali', 'vincenzo', 'rivalOf');
      await connect('project-a', 'kali', 'endovier', 'livesIn');

      expect(await repository.linksForEntities(['kali']), hasLength(2));
      expect(
        (await repository.linksForEntities(['kali'], typeIds: {'livesIn'}))
            .single
            .targetId,
        'endovier',
      );
      // An empty type set means "no types are allowed", not "all of them".
      expect(
        await repository.linksForEntities(['kali'], typeIds: const {}),
        isEmpty,
      );
    });

    test('a link spanning two id chunks is returned once', () async {
      await create('kali', 'Kali Vale', 'project-a');
      await create('vincenzo', 'Vincenzo', 'project-a');
      await connect('project-a', 'kali', 'vincenzo', 'rivalOf');

      // Both endpoints in one call: the source and target clauses both match,
      // so a naive implementation returns the row twice.
      final links = await repository.linksForEntities(['kali', 'vincenzo']);

      expect(links, hasLength(1));
    });
  });
}
