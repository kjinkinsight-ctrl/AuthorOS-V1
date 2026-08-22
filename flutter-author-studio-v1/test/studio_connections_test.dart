/// A character's scenes must be visible from every Studio that lists
/// connections, and following one must land on it.
///
/// Each Studio resolved connection endpoints with `recordById`, which cannot
/// see manuscript nodes, and each failed differently: Timeline rendered
/// nothing at all, Codex rendered the raw id with "record unavailable",
/// Character rendered the relationship type where the title belonged. These
/// read through `StoryGraphService`, which is the one place that resolves both
/// kinds.
///
/// The scenes here are manuscript nodes only, never records.
/// `test/fixtures/cross_system_fixture.dart` writes its scenes as both, which
/// makes `recordById` succeed and hides the exact defect under test.
library;

import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/core/story_graph_service.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 22);
const _project = 'project-connections';

ManuscriptNodeReference _scene(String id, String title) =>
    ManuscriptNodeReference(
      id: id,
      projectId: _project,
      nodeType: 'scene',
      title: title,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryGraphService graph;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    graph = StoryGraphService(projectId: _project, repository: repository);
  });

  tearDown(() => database.close());

  /// A character who appears in a scene, where the scene exists only as a
  /// manuscript node — the shape every Studio used to get wrong.
  Future<void> seed() async {
    await repository.putManuscriptNodes([_scene('scene-1', 'The Blood Price')]);
    await CharacterService(projectId: _project, repository: repository)
        .createCharacter(id: 'kali', displayName: 'Kali Vale');
    await ConnectionEngine(scopeId: _project, repository: repository).connect(
      sourceId: 'kali',
      targetId: 'scene-1',
      typeId: 'appearsIn',
      timestamp: _timestamp,
    );
  }

  group('the scene resolves', () {
    test('from the character side, by title', () async {
      await seed();

      final neighbourhood = await graph.getNeighbours(
        'kali',
        filter: StoryGraphFilter.everyRelationship,
      );

      expect(neighbourhood!.neighbours, hasLength(1));
      final node = neighbourhood.neighbours.single;
      expect(node.title, 'The Blood Price');
      // The three old failure modes, each asserted against.
      expect(node.title, isNot('appearsIn'));
      expect(node.title, isNot('scene-1'));
      expect(node.kind, StoryGraphNodeKind.manuscriptNode);
    });

    test('from the scene side', () async {
      await seed();

      final neighbourhood = await graph.getNeighbours(
        'scene-1',
        filter: StoryGraphFilter.everyRelationship,
      );

      expect(neighbourhood!.neighbours.single.title, 'Kali Vale');
    });

    test('the records-only path still cannot see it', () async {
      await seed();

      // Pinned so this cannot be mistaken for a working read path.
      final linked = await ConnectionEngine(
        scopeId: _project,
        repository: repository,
      ).linkedRecords('kali');

      expect(linked, isEmpty);
    });
  });

  group('a relationship reads correctly from each end', () {
    test('Manuscript Studio uses the inverse label for an incoming edge',
        () async {
      await seed();

      final connections = await ManuscriptService(
        projectId: _project,
        repository: repository,
      ).connectionsFor('scene-1');

      expect(connections.single.title, 'Kali Vale');
      expect(connections.single.incoming, isTrue);
      // "the scene features Kali", not "the scene appears in Kali" — the
      // forward label in both directions inverted the relationship.
      expect(connections.single.displayName, 'Features');
      expect(
        connections.single.destination,
        SearchDestination.characterStudio,
      );
    });
  });

  group('the catch-all is not hidden from a record\'s own list', () {
    test('relatedTo appears under everyRelationship but not unfiltered',
        () async {
      final characters =
          CharacterService(projectId: _project, repository: repository);
      await characters.createCharacter(id: 'kali', displayName: 'Kali Vale');
      await characters.createCharacter(id: 'vin', displayName: 'Vincenzo');
      await ConnectionEngine(scopeId: _project, repository: repository).connect(
        sourceId: 'kali',
        targetId: 'vin',
        typeId: 'relatedTo',
        direction: RecordLinkDirection.undirected,
        timestamp: _timestamp,
      );

      final curated = await graph.getNeighbours('kali');
      final own = await graph.getNeighbours(
        'kali',
        filter: StoryGraphFilter.everyRelationship,
      );

      // A curated view drops the catch-all; the author's own relationship
      // list must not, or it reports a connection they made as absent.
      expect(curated!.neighbours, isEmpty);
      expect(own!.neighbours.single.title, 'Vincenzo');
    });
  });
}
