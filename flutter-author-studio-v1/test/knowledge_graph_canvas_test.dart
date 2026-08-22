/// A canvas is an ordinary record, and holds no edges.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/knowledge_graph_record_types.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/core/story_graph_service.dart';
import 'package:author_studio_v1/knowledge_graph/canvas_service.dart';
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

  KnowledgeCanvasService canvasesFor(String projectId) =>
      KnowledgeCanvasService(projectId: projectId, repository: repository);

  RecordService recordsFor(String projectId) =>
      RecordService(projectId: projectId, repository: repository);

  Future<void> createCharacter(String id, String title, String projectId) =>
      recordsFor(projectId).createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          title: title,
          fields: {'identity.fullName': title},
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      );

  test('an arrangement round-trips', () async {
    await createCharacter('kali', 'Kali Vale', 'project-a');
    final canvases = canvasesFor('project-a');

    await canvases.save(
      'character',
      positions: {'kali': const Offset(120, -40)},
      rootId: 'kali',
      timestamp: _timestamp,
    );

    final loaded = await canvases.load('character');

    expect(loaded, isNotNull);
    expect(loaded!.positions['kali'], const Offset(120, -40));
    expect(loaded.rootId, 'kali');
    expect(loaded.modeId, 'character');
  });

  test('saving twice updates one record rather than accumulating boards',
      () async {
    final canvases = canvasesFor('project-a');

    await canvases.save(
      'character',
      positions: {'kali': const Offset(10, 10)},
      timestamp: _timestamp,
    );
    await canvases.save(
      'character',
      positions: {'kali': const Offset(80, 80)},
      timestamp: _timestamp,
    );

    expect((await canvases.load('character'))!.positions['kali'],
        const Offset(80, 80));
    final all = await repository.recordsByProject('project-a');
    expect(
      all
          .where((record) =>
              record.typeId == KnowledgeGraphRecordTypes.canvasTypeId)
          .length,
      1,
    );
  });

  test('each mode keeps its own arrangement', () async {
    final canvases = canvasesFor('project-a');

    await canvases.save(
      'character',
      positions: {'kali': const Offset(10, 10)},
      timestamp: _timestamp,
    );
    await canvases.save(
      'world',
      positions: {'endovier': const Offset(50, 50)},
      timestamp: _timestamp,
    );

    expect((await canvases.load('character'))!.positions.keys, ['kali']);
    expect((await canvases.load('world'))!.positions.keys, ['endovier']);
  });

  test('a filter is saved and restored with the arrangement', () async {
    final canvases = canvasesFor('project-a');

    await canvases.save(
      'character',
      positions: {'kali': Offset.zero},
      filter: const StoryGraphFilter(
        bookId: 'book-1',
        includeRelatedTo: true,
      ),
      timestamp: _timestamp,
    );

    final loaded = await canvases.load('character');

    expect(loaded!.filter, isNotNull);
    expect(loaded.filter!.bookId, 'book-1');
    expect(loaded.filter!.includeRelatedTo, isTrue);
  });

  test('clearing forgets the arrangement but keeps it in history', () async {
    final canvases = canvasesFor('project-a');
    await canvases.save(
      'character',
      positions: {'kali': Offset.zero},
      timestamp: _timestamp,
    );

    await canvases.clear('character', timestamp: _timestamp);

    expect(await canvases.load('character'), isNull);
    // Soft-deleted, not erased: the record is still there to restore.
    final record = await repository
        .recordById(KnowledgeGraphRecordTypes.canvasId('project-a', 'character'));
    expect(record, isNotNull);
    expect(record!.status, AuthorRecordStatus.deleted);
  });

  test('an unsaved mode loads as null, meaning "lay it out for me"', () async {
    expect(await canvasesFor('project-a').load('plot'), isNull);
  });

  test('a canvas never appears inside the graph it describes', () async {
    await createCharacter('kali', 'Kali Vale', 'project-a');
    await canvasesFor('project-a').save(
      'character',
      positions: {'kali': Offset.zero},
      timestamp: _timestamp,
    );

    final graph = StoryGraphService(
      projectId: 'project-a',
      repository: repository,
    );

    // The boundary test is participation, not proximity: a canvas references
    // graph entities but is not one, so no filter setting reveals it.
    final project = await graph.getProjectGraph(
      filter: const StoryGraphFilter(
        includeArchived: true,
        includeDeleted: true,
        includeRelatedTo: true,
        includeWildcardEdges: true,
      ),
    );

    expect(project.nodes.map((node) => node.id), ['kali']);
    expect(
      project.nodeById(
        KnowledgeGraphRecordTypes.canvasId('project-a', 'character'),
      ),
      isNull,
    );
  });

  test('canvases do not cross projects', () async {
    await canvasesFor('project-a').save(
      'character',
      positions: {'kali': Offset.zero},
      timestamp: _timestamp,
    );

    expect(await canvasesFor('project-b').load('character'), isNull);
  });

  test('the canvas record carries positions and no relationships', () async {
    final canvases = canvasesFor('project-a');
    await canvases.save(
      'character',
      positions: {'kali': const Offset(1, 2), 'vincenzo': const Offset(3, 4)},
      timestamp: _timestamp,
    );

    final record = await repository
        .recordById(KnowledgeGraphRecordTypes.canvasId('project-a', 'character'));
    final nodes =
        record!.fields[KnowledgeGraphRecordTypes.nodesFieldId] as List;

    expect(nodes, hasLength(2));
    for (final entry in nodes) {
      // Ids and coordinates only. An edge stored here could drift out of step
      // with record_link_rows, which is the one thing a canvas must never do.
      expect((entry as Map).keys.toSet(), {'entityId', 'x', 'y'});
    }
    // And it creates no links of its own.
    expect(await repository.linksByScope('project-a'), isEmpty);
  });
}
