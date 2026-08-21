/// Architecture guardrails for the future Universal Story Graph.
///
/// These are not feature tests. Each one pins a boundary that
/// `docs/universal-story-graph-architecture.md` depends on, so that a change
/// which quietly builds a second graph — a second edge table, a second
/// relationship model, an Analytics write path, a Story Graph UI landing ahead
/// of its design — fails here instead of being discovered later.
///
/// A failure is not necessarily a bug. It means an architectural decision was
/// made, and the master document needs updating alongside it.
library;

import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tables the audit recorded at schema version 8. A new table is a
/// deliberate act; this list makes it a visible one.
const _auditedTables = {
  'connected_entities',
  'author_record_rows',
  'manuscript_node_rows',
  'record_link_rows',
  'record_type_definition_rows',
  'connection_type_definition_rows',
  'story_branch_rows',
  'branch_record_overlay_rows',
  'branch_link_overlay_rows',
  'record_version_rows',
  'audit_event_rows',
};

final _timestamp = DateTime.utc(2026, 8, 21, 9);

Directory get _libDirectory => Directory('lib');

Iterable<File> get _libSources => _libDirectory
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

AuthorRecord _record(
  String id,
  String title,
  String projectId, {
  String typeId = 'character',
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

StarterProject _project(String id) => StarterProject(
      id: id,
      title: 'Guardrail Project',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

void main() {
  test('the graph has exactly one persistence system', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    // Force onCreate so every table and index really exists.
    await database.customSelect('SELECT 1').get();

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final tables = rows.map((row) => row.read<String>('name')).toSet();

    // `author_search` is the FTS5 virtual table plus its shadow tables; they
    // are a search index over nodes, not a second store of graph truth.
    final graphTables =
        tables.where((name) => !name.startsWith('author_search')).toSet();

    expect(
      graphTables,
      _auditedTables,
      reason: 'A table was added or removed since the Story Graph audit. If a '
          'graph feature introduced it, that is a second persistence system '
          'and contradicts the master design.',
    );
    expect(
      graphTables.where((name) => name.contains('link')),
      {'record_link_rows', 'branch_link_overlay_rows'},
      reason: 'record_link_rows is the only edge table. '
          'branch_link_overlay_rows overlays it per branch; it does not '
          'replace it.',
    );
  });

  test('graph edges are written as RecordLinks and nowhere else', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final engine =
        ConnectionEngine(scopeId: 'project-a', repository: repository);

    await repository.putRecordsAndLinks(
      records: [
        _record('kali', 'Kali', 'project-a'),
        _record('vincenzo', 'Vincenzo', 'project-a'),
      ],
      links: const [],
    );

    final link = await engine.connect(
      sourceId: 'kali',
      targetId: 'vincenzo',
      typeId: 'relatedTo',
      direction: RecordLinkDirection.undirected,
      timestamp: _timestamp,
    );

    final linkRows = await database
        .customSelect('SELECT id, source_id, target_id, type_id FROM '
            'record_link_rows')
        .get();
    expect(linkRows, hasLength(1));
    expect(linkRows.single.read<String>('id'), link.id);
    expect(linkRows.single.read<String>('type_id'), 'relatedTo');

    // The edge is discoverable from both endpoints through the one engine.
    expect((await engine.connections('kali')).single.id, link.id);
    expect((await engine.connections('vincenzo')).single.id, link.id);
  });

  test('no second relationship model has appeared in lib/', () {
    final graphish = _libSources
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where(
          (path) =>
              path.contains('story_graph') ||
              path.endsWith('/graph_store.dart') ||
              path.endsWith('/graph_repository.dart') ||
              path.endsWith('/edge_store.dart') ||
              path.endsWith('/relationship_store.dart'),
        )
        .toList();

    expect(
      graphish,
      isEmpty,
      reason: 'A graph-specific store appeared. The Story Graph is designed to '
          'own no storage and to read RecordLink through ConnectionEngine.',
    );

    // ImpactTraceAnalyzer carries its own TraceEntity/TraceLink model. The
    // audit records it as unused (risk R-6); if it gains a production caller,
    // that decision belongs in the master document.
    final impactTraceCallers = _libSources
        .where((file) => !file.path.endsWith('impact_trace.dart'))
        .where((file) => file.readAsStringSync().contains('ImpactTraceAnalyzer'))
        .map((file) => file.path)
        .toList();
    expect(
      impactTraceCallers,
      isEmpty,
      reason: 'ImpactTraceAnalyzer is a parallel graph traversal over its own '
          'TraceLink model. Wiring it into production creates a second graph; '
          'absorb it into the Story Graph read model instead.',
    );
  });

  test('project isolation holds: the graph cannot link across projects',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);

    await repository.putRecordsAndLinks(
      records: [
        _record('character-a', 'Character A', 'project-a'),
        _record('character-b', 'Character B', 'project-b'),
      ],
      links: const [],
    );

    final projectA =
        ConnectionEngine(scopeId: 'project-a', repository: repository);
    final projectB =
        ConnectionEngine(scopeId: 'project-b', repository: repository);

    await expectLater(
      projectA.connect(
        sourceId: 'character-a',
        targetId: 'character-b',
        typeId: 'relatedTo',
        direction: RecordLinkDirection.undirected,
        timestamp: _timestamp,
      ),
      throwsStateError,
    );
    await expectLater(
      projectB.connect(
        sourceId: 'character-b',
        targetId: 'character-a',
        typeId: 'relatedTo',
        direction: RecordLinkDirection.undirected,
        timestamp: _timestamp,
      ),
      throwsStateError,
    );

    // Nothing was written, and neither project can traverse into the other.
    expect(await repository.backlinks('character-a'), isEmpty);
    expect(await repository.backlinks('character-b'), isEmpty);
    await expectLater(projectA.connections('character-b'), throwsStateError);
  });

  test('Analytics never writes records, links, versions or audit events',
      () async {
    SharedPreferences.setMockInitialValues({});
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final project = _project('project-a');

    await repository.putRecordsAndLinks(
      records: [
        _record('kali', 'Kali', 'project-a'),
        _record('vincenzo', 'Vincenzo', 'project-a'),
      ],
      links: const [],
    );
    await ConnectionEngine(scopeId: 'project-a', repository: repository)
        .connect(
      sourceId: 'kali',
      targetId: 'vincenzo',
      typeId: 'relatedTo',
      direction: RecordLinkDirection.undirected,
      timestamp: _timestamp,
    );

    /// Everything Analytics consumes but must never own.
    Future<Map<String, int>> graphTruth() async {
      final snapshot = await repository.snapshot();
      return {
        'records': snapshot.records.length,
        'links': snapshot.links.length,
        'versions': snapshot.versions.length,
        'auditEvents': snapshot.auditEvents.length,
      };
    }

    Future<int> manuscriptNodes() async =>
        (await repository.snapshot()).manuscriptNodes.length;

    final analytics = AnalyticsService(
      project: project,
      repository: repository,
      manuscriptStore: ManuscriptStore(repository: repository),
    );

    final beforeTruth = await graphTruth();
    final summary = await analytics.getSummary();
    final afterTruth = await graphTruth();

    expect(summary.characterCount, 2);
    expect(
      summary.charactersWithRelationships,
      2,
      reason: 'The relationship count must come from RecordLinks, not from a '
          'store Analytics owns.',
    );
    expect(
      afterTruth,
      beforeTruth,
      reason: 'Analytics wrote record, link, version or audit data. It must '
          'derive graph truth and never own it.',
    );

    // Analytics does have one write-shaped side effect, and the audit records
    // it as risk R-21: reading a project whose manuscript has never been
    // opened makes ManuscriptStore seed and persist a starter manuscript,
    // which projects chapter and scene nodes into the graph. It is confined
    // to manuscript nodes and it settles after the first read.
    final seeded = await manuscriptNodes();
    await analytics.getSummary();
    expect(
      await manuscriptNodes(),
      seeded,
      reason: 'Manuscript-node seeding must be a one-time effect of the first '
          'read. If repeated reads keep writing, Analytics has become a '
          'source of graph churn.',
    );
  });

  test('map coordinates stay map-owned record fields, not edge data', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final worlds = WorldService(projectId: 'project-a', repository: repository);

    await worlds.createWorldRecord(
      id: 'harbour',
      title: 'Harbour',
      timestamp: _timestamp,
    );
    await worlds.createMap(
      id: 'harbour-map',
      title: 'Harbour Map',
      mappedRecordId: 'harbour',
      timestamp: _timestamp,
    );
    final marker = await worlds.createMapMarker(
      markerId: 'harbour-marker',
      mapId: 'harbour-map',
      recordId: 'harbour',
      x: 128,
      y: 64,
      label: 'Dock 7',
      timestamp: _timestamp,
    );

    expect(marker.typeId, 'map-marker');
    expect(marker.fields['x'], 128);
    expect(marker.fields['y'], 64);
    expect(marker.fields['mapId'], 'harbour-map');

    // The edges carry the relationships; they must not carry the geometry.
    final links = await repository.backlinks(marker.id);
    expect(
      links.map((link) => link.typeId).toSet(),
      {'onMap', 'represents'},
    );
    for (final link in links) {
      expect(
        link.metadata.keys,
        isNot(anyOf(contains('x'), contains('y'))),
        reason: 'Marker coordinates belong to Map Studio on the map-marker '
            'record. A graph edge must never become a second home for them.',
      );
    }
  });

  test('writing-session history remains absent from lib/', () {
    final matches = _libSources
        .where((file) => file.readAsStringSync().contains('WritingSession'))
        .map((file) => file.path)
        .toList();

    expect(
      matches,
      isEmpty,
      reason: 'The Story Graph audit recorded WritingSession as NOT PRESENT. '
          'If a writing-session system is being added, decide explicitly that '
          'it is analytics-history data and not a graph node type, and update '
          'docs/universal-story-graph-architecture.md.',
    );
  });

  test('the Research migration remains deferred', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(
      mainSource,
      contains('class ProjectResearchStore'),
      reason: 'ProjectResearchStore moved or was renamed. The audit records '
          'its migration to research-entry records as deferred; a move needs '
          'the master document updated with it.',
    );
    expect(
      mainSource,
      contains("'author_studio.research_panel.\$projectId'"),
      reason: 'The Research panel still persists to SharedPreferences. If it '
          'now writes records, the deferred migration has happened and risk '
          'R-4 needs closing out in the master document.',
    );
    expect(
      mainSource.contains('ProjectResearchStore') &&
          mainSource.contains('research-entry'),
      isFalse,
      reason: 'ProjectResearchStore appears to create research-entry records. '
          'That migration is deliberately out of scope for the audit '
          'milestone.',
    );
  });

  test('no Story Graph UI or service has been implemented', () {
    final offenders = <String>[];
    for (final file in _libSources) {
      final source = file.readAsStringSync();
      for (final symbol in const [
        'StoryGraphService',
        'StoryGraphView',
        'StoryGraphPanel',
        'StoryGraphWorkspace',
        'StoryGraphNode',
        'StoryGraphEdge',
      ]) {
        if (source.contains(symbol)) {
          offenders.add('${file.path}: $symbol');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The Story Graph is design-only. Implementation starts at Phase '
          '1 in docs/universal-story-graph-architecture.md, after the Phase 0 '
          'preconditions are resolved.',
    );
  });

  test('the edge table refuses a dangling link', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // Prove the pragma the invariant relies on is actually on.
    final pragma =
        await database.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.read<int>('foreign_keys'), 1);

    await expectLater(
      database.customStatement(
        'INSERT INTO record_link_rows(id, source_id, target_id, type_id, '
        'scope_id, direction, label, revision, metadata_json, created_at, '
        'updated_at, extension_json) '
        "VALUES (?, ?, ?, 'relatedTo', 'project-a', 'undirected', '', 1, "
        "'{}', 0, 0, '{}')",
        [
          const Variable<String>('orphan-link'),
          const Variable<String>('missing-source'),
          const Variable<String>('missing-target'),
        ],
      ),
      throwsA(anything),
      reason: 'Invariant I-1: the database itself must reject an edge whose '
          'endpoints do not exist.',
    );
  });
}
