/// Universal Story Graph — Phase 1 architecture guardrails.
///
/// These pin the boundaries the Phase 1 read model is only worth having if it
/// keeps. A failure here is not necessarily a bug: it means an architectural
/// decision was taken, and `docs/universal-story-graph-phase-1-read-model.md`
/// and `docs/universal-story-graph-architecture.md` need updating with it.
library;

import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_id.dart';
import 'package:author_studio_v1/core/story_graph_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _modelPath = 'lib/core/story_graph.dart';
const _servicePath = 'lib/core/story_graph_service.dart';

Iterable<File> get _libSources => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('the read model is exactly two files, both in core', () {
    expect(File(_modelPath).existsSync(), isTrue);
    expect(File(_servicePath).existsSync(), isTrue);
  });

  test('there is exactly one canonical Story Graph service', () {
    final declarations = <String>[];
    for (final file in _libSources) {
      final source = file.readAsStringSync();
      for (final match
          in RegExp(r'class\s+(\w*StoryGraph\w*Service)').allMatches(source)) {
        declarations.add(match.group(1)!);
      }
    }

    expect(
      declarations,
      ['UniversalStoryGraphService'],
      reason: 'A second graph service appeared. Phase 2 and every later '
          'consumer must have exactly one canonical read source, or the two '
          'will drift apart on project scoping and bounds.',
    );
  });

  test('the core read model imports no Flutter', () {
    for (final path in const [_modelPath, _servicePath]) {
      expect(
        _read(path),
        isNot(contains('package:flutter/')),
        reason: '$path imports Flutter. lib/core/ is Flutter-free, and the '
            'dependency direction is core -> storage -> services -> studios.',
      );
    }
  });

  test('the read model has no write path', () {
    const mutations = [
      'putRecord',
      'putLink',
      'putManuscriptNodes',
      'removeManuscriptNodes',
      'putRecordsAndLinks',
      'putConnectedSlice',
      'replaceSnapshot',
      'deleteLink',
      'appendHistory',
      'putWritingSession',
      'ConnectionEngine(',
      '.connect(',
      '.disconnect(',
    ];

    for (final path in const [_modelPath, _servicePath]) {
      final source = _read(path);
      for (final mutation in mutations) {
        expect(
          source,
          isNot(contains(mutation)),
          reason: '$path can mutate canonical state through "$mutation". The '
              'Story Graph is a read model: it reads what the Studios and '
              'ConnectionEngine wrote, and it never writes.',
        );
      }
    }
  });

  test('no graph-specific persistence or cache was introduced', () {
    for (final path in const [_modelPath, _servicePath]) {
      final source = _read(path);
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('Table')));
      expect(source, isNot(contains('Migration')));
      expect(source, isNot(contains('customStatement')));
    }
  });

  test('the schema is untouched by Phase 1', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    expect(
      AuthorOsDatabase.currentSchemaVersion,
      9,
      reason: 'Phase 1 is a read layer. A schema version bump means it needed '
          'persistence, which is a stop condition, not an implementation '
          'detail.',
    );

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final tables = rows
        .map((row) => row.read<String>('name'))
        .where((name) => !name.startsWith('author_search'))
        .toSet();

    expect(
      tables.where((name) => name.contains('graph')),
      isEmpty,
      reason: 'A graph table appeared. The read model has no storage.',
    );
  });

  test('RecordGraph survives and is not duplicated', () {
    expect(File('lib/core/record_graph.dart').existsSync(), isTrue);

    // The Story Graph composes the same repository RecordGraph reads; it does
    // not reimplement RecordGraph's one-hop surface under new names.
    final service = _read(_servicePath);
    expect(service, isNot(contains('class RecordGraph')));
    expect(service, isNot(contains('class RelatedRecord')));
  });

  test('every public read entry point is project-scoped', () {
    final service = _read(_servicePath);

    expect(
      service,
      contains('required this.projectId'),
      reason: 'The service must not be constructible without a project. '
          'Project isolation is enforced in the service, never by a caller '
          'filtering results afterwards.',
    );

    for (final leak in const [
      'allProjects',
      'entireGraph',
      'globalGraph',
      'crossProject',
    ]) {
      expect(
        service,
        isNot(contains(leak)),
        reason: 'An unscoped read named "$leak" appeared. There is no '
            'all-projects graph, and a shared or public scope is a separate '
            'future surface, not a widening of this one.',
      );
    }
  });

  test('traversal cannot be asked for an unbounded read', () {
    const options = StoryGraphTraversalOptions();

    expect(options.maxDepth, lessThan(10));
    expect(options.maxNodes, lessThan(1000));

    // Negative depth is a programmer error, never a synonym for "unlimited".
    expect(
      () => const StoryGraphTraversalOptions(maxDepth: -1).validate(),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => const StoryGraphTraversalOptions(maxNodes: 0).validate(),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('D-3 holds: a scene stays a manuscript node and never becomes a record',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);

    await repository.putManuscriptNodes([
      ManuscriptNodeReference(
        id: 'scene-x',
        projectId: 'project-a',
        nodeType: 'scene',
        title: 'A Scene',
        createdAt: DateTime.utc(2026, 8, 21),
        updatedAt: DateTime.utc(2026, 8, 21),
      ),
    ]);

    final asRecord = await repository.recordById('scene-x');
    expect(
      asRecord,
      isNull,
      reason: 'A scene acquired an AuthorRecord representation. D-3 keeps '
          'scenes in manuscript persistence; duplicating one into a record is '
          'the migration D-1 was withdrawn to avoid.',
    );

    final graph = UniversalStoryGraphService(
      projectId: 'project-a',
      repository: repository,
    );
    final node = await graph.getNode(RecordId.parse('scene-x'));
    expect(node!.kind, StoryGraphNodeKind.manuscript);

    // And the projection Manuscript Studio writes is still the node kind.
    expect(
      _read('lib/manuscript_store.dart'),
      contains('static List<ManuscriptNodeReference> manuscriptNodesFor('),
      reason: 'Manuscript Studio stopped projecting scenes as manuscript '
          'nodes. That is a D-3 reversal and belongs in the master document.',
    );
  });

  test('the graph exposes no persistence type to its consumers', () {
    final model = _read(_modelPath);

    // Phase 2 must be able to work entirely in graph vocabulary.
    for (final leak in const [
      'AuthorRecordRow',
      'ManuscriptNodeRow',
      'RecordLinkRow',
      'drift',
    ]) {
      expect(
        model,
        isNot(contains(leak)),
        reason: 'The read model leaks the persistence type "$leak". The '
            'abstraction boundary is StoryGraphNode / StoryGraphEdge.',
      );
    }
  });
}
