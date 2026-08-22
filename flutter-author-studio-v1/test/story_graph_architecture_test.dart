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

import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/scene_revision.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
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
  // Writing session history. Present since the writing-session milestone
  // merged into main. It is deliberately in this list and deliberately NOT
  // graph truth — see the invariant I-12 test below.
  'writing_session_rows',
  // The author's daily, weekly, and monthly word targets, from the author
  // performance milestone. A per-project setting, not a node and not an edge:
  // deliberately listed here and deliberately not graph truth — see the
  // writing-goals test below, which holds it there the same way I-12 holds
  // sessions.
  'writing_goal_rows',
  // Named series, from the series-analytics milestone. A series is library
  // structure: it names a sequence of books and the target a joining book
  // inherits, and nothing else. It could not have been graph data even by
  // choice — a series spans projects, and the project-isolation test above
  // shows the graph refuses to link across them.
  'series_rows',
  // The project roster: every book on this machine, and which series it
  // belongs to. Before it, AuthorOS held one project in a single preference
  // key. A catalogue entry, not a node and not an edge — see the roster test
  // below.
  'project_rows',
  // Prose history, from the scene-revision milestone. The first place in
  // AuthorOS that keeps a copy of a scene's words after they are overwritten.
  // Deliberately in this list and deliberately not graph truth: a revision is
  // an archived body of text, and the graph has never stored prose at all —
  // see the scene-revision test below, and R-14 in the Story Graph audit.
  'scene_revision_rows',
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
    // This used to reject any path containing `story_graph`, back when the
    // graph was design-only and any such file was by definition premature.
    // The read model now exists, so the check returns to what it was actually
    // protecting: a *store*. That the read model owns no storage is proved
    // directly by 'the Story Graph read model owns no storage' below.
    final graphish = _libSources
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where(
          (path) =>
              path.endsWith('/graph_store.dart') ||
              path.endsWith('/graph_repository.dart') ||
              path.endsWith('/graph_database.dart') ||
              path.endsWith('/graph_cache.dart') ||
              path.endsWith('/graph_index.dart') ||
              path.endsWith('/story_graph_store.dart') ||
              path.endsWith('/story_graph_repository.dart') ||
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

  test('writing sessions stay history data and never become graph truth',
      () async {
    // Invariant I-12. The audit recorded WritingSession as NOT PRESENT; the
    // writing-session milestone has since landed on main, so the question the
    // guardrail existed to force is now live: is a session graph data or
    // history? It is history, and this test holds it there.
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    // A session is not a node: no foreign key into the graph's identity table.
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_list(writing_session_rows)')
        .get();
    expect(
      foreignKeys,
      isEmpty,
      reason: 'writing_session_rows gained a foreign key. A session that '
          'points into connected_entities is a graph node, not history.',
    );

    // A session is not a record type either.
    expect(
      BuiltInRecordTypes.definitions.map((definition) => definition.id),
      isNot(anyOf(
        contains('writing-session'),
        contains('writingSession'),
        contains('session'),
      )),
      reason: 'A writing session became a registered record type. Sessions '
          'are analytics history; promoting one to a node makes Analytics a '
          'source of graph truth.',
    );

    // And no connection type may take one as an endpoint.
    final sessionEdges = BuiltInConnectionTypes.definitions
        .where((definition) =>
            definition.sourceTypeIds.contains('writing-session') ||
            definition.targetTypeIds.contains('writing-session'))
        .map((definition) => definition.id)
        .toList();
    expect(sessionEdges, isEmpty);
  });

  test('writing goals stay a setting and never become graph truth', () async {
    // The same question I-12 forces about a session, asked about a goal: is
    // the author's word target graph data? It is not. It is a per-project
    // setting, and this test holds it there.
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    // A goal is not a node: no foreign key into the graph's identity table.
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_list(writing_goal_rows)')
        .get();
    expect(
      foreignKeys,
      isEmpty,
      reason: 'writing_goal_rows gained a foreign key. A goal that points '
          'into connected_entities is a graph node, not a setting.',
    );

    // One row per project, so goals can never accumulate into a history.
    final columns = await database
        .customSelect('PRAGMA table_info(writing_goal_rows)')
        .get();
    final primaryKey = columns
        .where((row) => row.read<int>('pk') > 0)
        .map((row) => row.read<String>('name'))
        .toList();
    expect(
      primaryKey,
      ['project_id'],
      reason: 'Writing goals are keyed by project. A surrogate key would let '
          'one project hold several sets of targets.',
    );

    // A writing goal is not a record type either. Note the ids are specific:
    // the Plot Studio already registers a `goal` record type, which is a
    // story goal a character pursues — a different thing entirely from the
    // author's word target, and legitimately graph data.
    expect(
      BuiltInRecordTypes.definitions.map((definition) => definition.id),
      isNot(anyOf(
        contains('writing-goal'),
        contains('writingGoal'),
        contains('writing-goals'),
      )),
      reason: 'A writing goal became a registered record type. Word targets '
          'are a setting; promoting one to a node makes Analytics a source '
          'of graph truth.',
    );

    // And no connection type may take one as an endpoint.
    final goalEdges = BuiltInConnectionTypes.definitions
        .where((definition) =>
            definition.sourceTypeIds.contains('writing-goal') ||
            definition.targetTypeIds.contains('writing-goal'))
        .map((definition) => definition.id)
        .toList();
    expect(goalEdges, isEmpty);
  });

  test('scene revisions stay archived prose and never become graph truth',
      () async {
    // The question I-12 forces about a session, asked about a paragraph: is a
    // stored copy of a scene's prose graph data? It is not — and here the
    // answer is stronger than a judgement call. The graph has never held prose
    // at all: `manuscriptNodeForScene` stores metadata and a word count, and
    // R-14 in the Story Graph audit records scene text being unsearchable as a
    // known consequence. A revision table that leaked into the graph would
    // reverse that silently.
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    // Not a node: no foreign key into the graph's identity table.
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_list(scene_revision_rows)')
        .get();
    expect(
      foreignKeys,
      isEmpty,
      reason: 'scene_revision_rows gained a foreign key. A revision that '
          'points into connected_entities is a graph node, not an archive.',
    );

    // A surrogate key, unlike goals: a scene keeps many revisions, and that
    // is the entire point of the table.
    final columns = await database
        .customSelect('PRAGMA table_info(scene_revision_rows)')
        .get();
    final primaryKey = columns
        .where((row) => row.read<int>('pk') > 0)
        .map((row) => row.read<String>('name'))
        .toList();
    expect(primaryKey, ['id']);

    // Not a record type, and not an endpoint of any connection.
    expect(
      BuiltInRecordTypes.definitions.map((definition) => definition.id),
      isNot(anyOf(
        contains('scene-revision'),
        contains('sceneRevision'),
        contains('revision'),
      )),
      reason: 'A stored copy of prose became a registered record type, which '
          'would put scene text into the graph and into the search index.',
    );
    final revisionEdges = BuiltInConnectionTypes.definitions
        .where((definition) =>
            definition.sourceTypeIds.contains('scene-revision') ||
            definition.targetTypeIds.contains('scene-revision'))
        .map((definition) => definition.id)
        .toList();
    expect(revisionEdges, isEmpty);

    // And writing one leaves graph truth alone.
    final repository = DriftConnectedDomainRepository(database);
    await repository.putSceneRevision(
      SceneRevision(
        id: 'rev-1',
        projectId: 'project-a',
        sceneId: 'scene-1',
        chapterId: 'chapter-1',
        title: 'The Blood Price',
        content: 'She opened the door.',
        wordCount: 4,
        capturedAt: _timestamp,
        trigger: SceneRevisionTrigger.boundary,
      ),
    );

    for (final table in const [
      'connected_entities',
      'author_record_rows',
      'manuscript_node_rows',
      'record_link_rows',
      'record_version_rows',
      'audit_event_rows',
    ]) {
      final count = await database
          .customSelect('SELECT COUNT(*) AS total FROM $table')
          .getSingle();
      expect(count.read<int>('total'), 0, reason: table);
    }
    final indexed = await database
        .customSelect('SELECT COUNT(*) AS total FROM author_search')
        .getSingle();
    expect(
      indexed.read<int>('total'),
      0,
      reason: 'Keeping a copy of a scene must not put its prose into the '
          'search index — the manuscript itself deliberately does not.',
    );
  });

  test('the project roster stays a catalogue and never becomes graph truth',
      () async {
    // The question I-12 forces about a session, asked about a book: is the
    // roster graph data? It is not. It is the author's catalogue of projects,
    // and a series is a sequence within it.
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    // Neither table points into the graph's identity table.
    for (final table in const ['project_rows', 'series_rows']) {
      final foreignKeys =
          await database.customSelect('PRAGMA foreign_key_list($table)').get();
      expect(
        foreignKeys,
        isEmpty,
        reason: '$table gained a foreign key. A roster row that points into '
            'connected_entities is a node, not a catalogue entry.',
      );
    }

    // One row per project, and one per series.
    for (final table in const ['project_rows', 'series_rows']) {
      final columns =
          await database.customSelect('PRAGMA table_info($table)').get();
      final primaryKey = columns
          .where((row) => row.read<int>('pk') > 0)
          .map((row) => row.read<String>('name'))
          .toList();
      expect(
        primaryKey,
        [table == 'project_rows' ? 'id' : 'id'],
        reason: '$table must be keyed by its own id, so a project cannot '
            'hold two roster rows.',
      );
    }

    // The series/book record-type placeholders stay placeholders. Promoting
    // them into real typed records is M4's call, not this milestone's.
    //
    // Read from the declarations rather than through `registry.resolve`:
    // these types derive from `general-lore`, so a resolved definition
    // inherits that type's fields and would never look empty.
    for (final typeId in const ['series', 'book', 'project']) {
      final declared = BuiltInRecordTypes.definitions
          .firstWhere((definition) => definition.id == typeId);
      expect(
        declared.fields,
        isEmpty,
        reason: '$typeId declared fields of its own. The roster stores books; '
            'promoting the record type is a separate, deliberate decision.',
      );
      expect(declared.baseTypeId, 'general-lore', reason: typeId);
    }

    // Note what is deliberately NOT asserted here: that no connection type
    // touches `book`. `appearsIn` and `mentionedIn` already take a `book`
    // record as a target, and that is fine — a `book` record in the Codex is
    // a thing a character can appear in. It is not a roster row. The
    // invariant that matters is that series membership is stored as roster
    // columns rather than as edges, which the next test proves directly by
    // building a series and showing the graph did not move.
  });

  test('building a series writes no records, links, versions or audit events',
      () async {
    SharedPreferences.setMockInitialValues({});
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final roster = ProjectRosterStore(repository: repository);

    Future<Map<String, int>> graphTruth() async {
      final snapshot = await repository.snapshot();
      return {
        'records': snapshot.records.length,
        'links': snapshot.links.length,
        'versions': snapshot.versions.length,
        'auditEvents': snapshot.auditEvents.length,
        'manuscriptNodes': snapshot.manuscriptNodes.length,
      };
    }

    final before = await graphTruth();

    await roster.saveSeries(
      const WritingSeries(
        id: 'series-1',
        name: 'Endovier Chronicles',
        defaultTargetWords: 90000,
      ),
    );
    for (final id in const ['book-1', 'book-2']) {
      await roster.save(
        StarterProject(
          id: id,
          title: id,
          genre: 'Fantasy',
          projectType: 'Novel',
          wordGoal: 90000,
          acts: const [],
          chapters: const [],
          characterSheets: const [],
          beatChecklist: const [],
          firstSceneTitle: 'Opening Scene',
        ),
      );
      await roster.addBookToSeries(projectId: id, seriesId: 'series-1');
    }

    expect(
      await graphTruth(),
      before,
      reason: 'A series is roster data. Creating one must not create records, '
          'links, versions, audit events or manuscript nodes.',
    );
    expect(await roster.books('series-1'), hasLength(2));
  });

  test('research lives in records and the legacy panel blob is never rewritten',
      () {
    // The audit recorded the research-panel migration as deferred (R-4). It
    // has since landed on main, so this guardrail flips from "still deferred"
    // to the invariant that replaced it: research is graph data, and the
    // legacy blob is a read-only migration input — the only remaining copy of
    // anything that has not migrated yet.
    expect(
      File('lib/migrations/research_panel_store.dart').existsSync(),
      isTrue,
      reason: 'The legacy research store moved or was deleted. It is still the '
          'only copy of any reference that has not migrated; deleting it '
          'before every project has migrated loses author data.',
    );

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(
      mainSource,
      isNot(contains('class ProjectResearchStore')),
      reason: 'ProjectResearchStore reappeared in main.dart. It belongs in '
          'lib/migrations/ as a legacy input, not in the app shell as a live '
          'store.',
    );

    // Research must be reachable as graph nodes, which is what the migration
    // was for.
    final researchTypes = BuiltInRecordTypes.definitions
        .where((definition) => definition.categoryId == 'research')
        .map((definition) => definition.id)
        .toSet();
    expect(researchTypes, containsAll(<String>{'research-entry', 'research'}));

    // And something must be able to document an arbitrary record, or research
    // is a node with no way to attach to the story.
    expect(
      BuiltInConnectionTypes.definitions.any((definition) =>
          definition.id == 'documents' &&
          definition.sourceTypeIds.contains('research-entry')),
      isTrue,
      reason: 'The documents edge lost research-entry as a source. Research '
          'nodes would no longer be able to attach to anything.',
    );
  });

  // This assertion used to read "no Story Graph UI or service has been
  // implemented". Its job was to stop the graph landing *ahead of its design*.
  // The design is now agreed and Phase 0 has shipped, so the guardrail's job
  // changes rather than disappearing: the graph exists, and it must stay a
  // read model over the storage that already exists.
  test('the Story Graph read model owns no storage', () {
    final graphSources = _libSources.where((file) {
      final path = file.path.replaceAll(r'\', '/');
      return path.contains('/story_graph') || path.contains('/knowledge_graph/');
    }).toList();

    expect(
      graphSources,
      isNotEmpty,
      reason: 'The Story Graph files have moved or been removed. This test can '
          'only guard code it can find.',
    );

    // Exactly two graph files may write, and both do it by delegating:
    // relationships to ConnectionEngine, canvases to RecordService. Everything
    // else is read-only. Naming them here means adding a third writer is a
    // conscious act rather than a quiet one.
    const writers = {
      'story_graph_mutations.dart',
      'canvas_service.dart',
    };
    final readOnly = graphSources.where(
      (file) => !writers.any(file.path.endsWith),
    );

    final offenders = <String>[];
    for (final file in readOnly) {
      final source = file.readAsStringSync();
      for (final write in const [
        'putRecord',
        'putLink',
        'putRecordsAndLinks',
        'putManuscriptNodes',
        'removeManuscriptNodes',
        'replaceSnapshot',
        'SharedPreferences',
      ]) {
        if (source.contains(write)) offenders.add('${file.path}: $write');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Invariant I-15: the graph is a query surface. A write here is a '
          'second source of graph truth, and belongs on RecordService or '
          'ConnectionEngine instead.',
    );
  });

  test('the graph delegates every relationship write to ConnectionEngine', () {
    final mutations =
        File('lib/core/story_graph_mutations.dart').readAsStringSync();

    // No second validation path: the moment this file starts deciding what a
    // valid edge is, there are two answers in the tree and they will diverge.
    expect(mutations.contains('ConnectionEngine'), isTrue);
    for (final forbidden in const [
      'validateConnection',
      'registry.resolve',
      'putLink',
      'repository.putRecordsAndLinks',
    ]) {
      expect(
        mutations.contains(forbidden),
        isFalse,
        reason: 'StoryGraphMutations must delegate, not re-validate. '
            'Found: $forbidden',
      );
    }
  });

  test('the canvas is a record, and holds no edges', () {
    final source =
        File('lib/knowledge_graph/canvas_service.dart').readAsStringSync();

    // Writes go through RecordService, so a canvas is validated, versioned,
    // audited and archived like anything else — and adds no table, which is
    // what keeps the 'exactly one persistence system' assertion above green.
    expect(source.contains('RecordService'), isTrue);
    for (final forbidden in const [
      'RecordLink',
      'ConnectionEngine',
      'putRecord',
      'putLink',
      'SharedPreferences',
    ]) {
      expect(
        source.contains(forbidden),
        isFalse,
        reason: 'A canvas stores positions and entity ids only. Storing an '
            'edge would let a saved board drift out of step with the graph. '
            'Found: $forbidden',
      );
    }
  });

  test('the graph never grows a second traversal model', () {
    // ImpactTraceAnalyzer is an unused depth-limited BFS over its own
    // TraceEntity/TraceLink types (risk R-6). It is the likeliest accidental
    // seed of a duplicate relationship system, so the graph must not adopt it.
    for (final file in _libSources) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/story_graph') &&
          !path.contains('/knowledge_graph/')) {
        continue;
      }
      expect(
        file.readAsStringSync().contains('impact_trace'),
        isFalse,
        reason: '${file.path} imports the orphaned ImpactTrace BFS. Absorbing '
            'it is a deliberate decision, not an import.',
      );
    }
  });

  test('a graph read never seeds a manuscript', () {
    // Risk R-21: AnalyticsService.getSummary() on a cold project seeds and
    // saves a starter manuscript, so reading a dashboard creates nodes. That
    // side effect must stay confined to Analytics — a graph read that reached
    // ManuscriptStore.loadStudio would make "look at the graph" and "write
    // graph nodes" the same action.
    for (final file in _libSources) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/story_graph') &&
          !path.contains('/knowledge_graph/')) {
        continue;
      }
      final source = file.readAsStringSync();
      expect(
        source.contains('loadStudio'),
        isFalse,
        reason: '${file.path} can trigger starter-manuscript seeding.',
      );
      expect(
        source.contains('ManuscriptStore'),
        isFalse,
        reason: '${file.path} reaches the manuscript blob directly. The graph '
            'reads manuscript nodes through the repository.',
      );
    }
  });

  test('derived edges cannot become RecordLinks', () {
    final source = File('lib/core/story_graph.dart').readAsStringSync();
    final derived = source.substring(
      source.indexOf('class DerivedStoryGraphEdge'),
    );
    final body = derived.substring(0, derived.indexOf('\n}'));

    // No id means nothing to persist it under. That is the whole guarantee:
    // §7.3 says a derived relationship must never masquerade as a stored link,
    // and this makes it structurally impossible rather than a convention.
    expect(
      body.contains('final String id'),
      isFalse,
      reason: 'DerivedStoryGraphEdge grew an id. A derived edge with an id is '
          'one refactor away from being written to record_link_rows.',
    );
  });

  test('the graph hides relatedTo and wildcard edges by default', () {
    // relatedTo is undirected, wildcard, and suggested on all ~224 record
    // types (risk R-16). A view that shows it by default degenerates into a
    // hairball on its first render.
    const filter = StoryGraphFilter();
    final relatedTo = BuiltInConnectionTypes.registry().resolve('relatedTo');

    expect(filter.includeRelatedTo, isFalse);
    expect(filter.includeWildcardEdges, isFalse);
    expect(filter.allowsEdgeType('relatedTo', relatedTo), isFalse);
    expect(filter.includeArchived, isFalse);
    expect(filter.includeDeleted, isFalse);
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

  // ---------------------------------------------------------------------
  // Phase 0 — manuscript node lifecycle integrity.
  //
  // Every test here proves behaviour against a real database. They exist
  // because the manuscript node projection was upsert-only: a deleted scene
  // kept its node, its links and its search row for the life of the database,
  // and the edge foreign key made the node impossible to remove afterwards.
  // ---------------------------------------------------------------------
  group('Phase 0 — manuscript node lifecycle', () {
    late AuthorOsDatabase database;
    late DriftConnectedDomainRepository repository;
    late ManuscriptStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = AuthorOsDatabase(NativeDatabase.memory());
      repository = DriftConnectedDomainRepository(database);
      store = ManuscriptStore(repository: repository);
    });

    tearDown(() => database.close());

    ManuscriptService serviceFor(String projectId) => ManuscriptService(
          projectId: projectId,
          repository: repository,
          store: store,
        );

    Future<ManuscriptProjectSummary> seedManuscript(String projectId) =>
        store.loadStudio(
          projectId,
          manuscriptTitle: 'Guardrail Book',
          defaultChapters: const [
            ManuscriptChapterSeed(
              title: 'Chapter 01',
              scenes: ['Scene 01', 'Scene 02'],
            ),
          ],
          firstSceneTitle: 'Scene 01',
        );

    Future<bool> isSearchable(String entityId) async {
      final rows = await database.customSelect(
        'SELECT entity_id FROM author_search WHERE entity_id = ?',
        variables: [Variable<String>(entityId)],
      ).get();
      return rows.isNotEmpty;
    }

    test('a scene dropped from the manuscript leaves no node behind',
        () async {
      final manuscript = await seedManuscript('project-ghost');
      await store.saveStudio(manuscript);
      final chapter = manuscript.chapters.first;
      final removed = chapter.scenes.last;
      final kept = chapter.scenes.first;
      expect(await repository.manuscriptNodeById(removed.id), isNotNull);

      // Saving a manuscript that no longer contains the scene is the path
      // ManuscriptStudio.dispose() takes with its in-memory snapshot.
      await store.saveStudio(
        manuscript.copyWith(
          chapters: [
            chapter.copyWith(scenes: [kept]),
          ],
        ),
      );

      expect(await repository.manuscriptNodeById(removed.id), isNull,
          reason: 'the projection must retire what it no longer contains');
      expect(await isSearchable(removed.id), isFalse,
          reason: 'a retired node must leave the search index with it');
      expect(await repository.manuscriptNodeById(kept.id), isNotNull,
          reason: 'reconciliation must not touch surviving nodes');
    });

    test('retiring a node removes the links that pointed at it', () async {
      final manuscript = await seedManuscript('project-links');
      await store.saveStudio(manuscript);
      final chapter = manuscript.chapters.first;
      final doomed = chapter.scenes.last;
      final survivor = chapter.scenes.first;

      await repository.putRecordsAndLinks(
        records: [_record('char-1', 'Mara', 'project-links')],
        links: [
          RecordLink(
            id: 'link-doomed-out',
            sourceId: doomed.id,
            targetId: 'char-1',
            typeId: 'relatedTo',
            scopeId: 'project-links',
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
          RecordLink(
            id: 'link-doomed-in',
            sourceId: 'char-1',
            targetId: doomed.id,
            typeId: 'relatedTo',
            scopeId: 'project-links',
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
          RecordLink(
            id: 'link-survivor',
            sourceId: survivor.id,
            targetId: 'char-1',
            typeId: 'relatedTo',
            scopeId: 'project-links',
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        ],
      );
      expect(await repository.backlinks(doomed.id), hasLength(2));

      await store.saveStudio(
        manuscript.copyWith(
          chapters: [
            chapter.copyWith(scenes: [survivor]),
          ],
        ),
      );

      expect(await repository.backlinks(doomed.id), isEmpty,
          reason: 'no edge may outlive the node it points at');
      expect(await repository.backlinks(survivor.id), hasLength(1),
          reason: 'an unrelated edge must survive');
      expect(await repository.recordById('char-1'), isNotNull,
          reason: 'the connected record itself is never deleted');
    });

    test('a linked node can be removed at all', () async {
      // Before Phase 0 this threw: record_link_rows references
      // connected_entities, so deleting the entity row with a live edge failed
      // the foreign key and the node could never be removed.
      final manuscript = await seedManuscript('project-fk');
      await store.saveStudio(manuscript);
      final scene = manuscript.chapters.first.scenes.first;
      await repository.putRecordsAndLinks(
        records: [_record('char-fk', 'Mara', 'project-fk')],
        links: [
          RecordLink(
            id: 'link-fk',
            sourceId: scene.id,
            targetId: 'char-fk',
            typeId: 'relatedTo',
            scopeId: 'project-fk',
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        ],
      );

      await repository.removeManuscriptNodes([scene.id]);

      expect(await repository.manuscriptNodeById(scene.id), isNull);
      expect(await repository.backlinks(scene.id), isEmpty);
    });

    test('deleting a scene through the service retires exactly its node',
        () async {
      final service = serviceFor('project-delete');
      final manuscript = await seedManuscript('project-delete');
      await store.saveStudio(manuscript);
      final chapter = manuscript.chapters.first;
      final doomed = chapter.scenes.last;
      final kept = chapter.scenes.first;

      await service.deleteScene(manuscript, doomed.id,
          confirmed: true, timestamp: _timestamp);

      expect(await repository.manuscriptNodeById(doomed.id), isNull);
      expect(await repository.manuscriptNodeById(kept.id), isNotNull);
      expect(await repository.manuscriptNodeById(chapter.id), isNotNull,
          reason: 'deleting a scene must not take its chapter with it');
      expect(await isSearchable(doomed.id), isFalse);
    });

    test('deleting a chapter retires the chapter and every scene it held',
        () async {
      final service = serviceFor('project-chapter');
      var manuscript = await seedManuscript('project-chapter');
      manuscript = await service.createChapter(manuscript,
          title: 'Chapter 02', timestamp: _timestamp);
      await store.saveStudio(manuscript);
      final doomed = manuscript.chapters.first;
      final survivor = manuscript.chapters.last;
      final doomedScenes = doomed.scenes.map((scene) => scene.id).toList();
      expect(doomedScenes, isNotEmpty);

      await service.deleteChapter(manuscript, doomed.id,
          confirmed: true, timestamp: _timestamp);

      expect(await repository.manuscriptNodeById(doomed.id), isNull);
      for (final sceneId in doomedScenes) {
        expect(await repository.manuscriptNodeById(sceneId), isNull,
            reason: 'a chapter takes its own scenes with it');
        expect(await isSearchable(sceneId), isFalse);
      }
      expect(await repository.manuscriptNodeById(survivor.id), isNotNull);
    });

    test('deletion preserves version and audit history', () async {
      final service = serviceFor('project-history');
      final manuscript = await seedManuscript('project-history');
      await store.saveStudio(manuscript);
      final doomed = manuscript.chapters.first.scenes.last;

      await service.deleteScene(manuscript, doomed.id,
          confirmed: true, timestamp: _timestamp);

      // Active graph state is gone; the historical record of it is not.
      expect(await repository.manuscriptNodeById(doomed.id), isNull);
      final versions = await repository.versionHistory(
        HistoryFilter(projectId: 'project-history', recordId: doomed.id),
      );
      expect(versions, isNotEmpty,
          reason: 'history must outlive the active node');
    });

    test('deletion is idempotent and recreation is clean', () async {
      final manuscript = await seedManuscript('project-repeat');
      await store.saveStudio(manuscript);
      final chapter = manuscript.chapters.first;
      final scene = chapter.scenes.last;
      final pruned = manuscript.copyWith(
        chapters: [
          chapter.copyWith(scenes: [chapter.scenes.first]),
        ],
      );

      await store.saveStudio(pruned);
      await store.saveStudio(pruned);
      expect(await repository.manuscriptNodeById(scene.id), isNull);

      // Saving the original again recreates the node from the projection.
      await store.saveStudio(manuscript);
      expect(await repository.manuscriptNodeById(scene.id), isNotNull);
      expect(await isSearchable(scene.id), isTrue,
          reason: 'a recreated node must be searchable again');
    });

    test('retiring a node in one project cannot touch another', () async {
      final a = await seedManuscript('project-a');
      final b = await seedManuscript('project-b');
      await store.saveStudio(a);
      await store.saveStudio(b);
      final bScenes = [
        for (final chapter in b.chapters)
          for (final scene in chapter.scenes) scene.id,
      ];

      final chapter = a.chapters.first;
      await store.saveStudio(
        a.copyWith(
          chapters: [
            chapter.copyWith(scenes: [chapter.scenes.first]),
          ],
        ),
      );

      for (final id in bScenes) {
        expect(await repository.manuscriptNodeById(id), isNotNull,
            reason: 'project B must be untouched by a save in project A');
      }
      final bNodes =
          await repository.manuscriptNodesForProject('project-b');
      expect(bNodes.map((node) => node.projectId).toSet(), {'project-b'},
          reason: 'a project query must never return another project\'s nodes');
    });

    test('reading Analytics on a cold project creates no manuscript nodes',
        () async {
      // R-21, now fixed rather than pinned. This was a read path that wrote
      // graph nodes: opening a dashboard seeded a starter manuscript and saved
      // it, and because manuscript nodes carry version and audit entries, it
      // manufactured history for prose the author had never written.
      // AnalyticsService reads through ManuscriptStore.peekStudio and reports
      // an empty manuscript instead; seeding stays with Manuscript Studio.
      final analytics = AnalyticsService(
        repository: repository,
        project: _project('project-cold'),
        manuscriptStore: store,
      );
      expect(await repository.manuscriptNodesForProject('project-cold'),
          isEmpty);

      final summary = await analytics.getSummary();

      expect(
        await repository.manuscriptNodesForProject('project-cold'),
        isEmpty,
        reason: 'A dashboard read must not be the same action as creating '
            'graph nodes.',
      );
      // And a project with no manuscript reports as empty rather than as a
      // seeded starter the author never asked for.
      expect(summary.chapterCount, 0);
      expect(summary.sceneCount, 0);
      expect(summary.totalWordCount, 0);
    });

    test('an archive carries manuscript structure but never its prose',
        () async {
      // R-2, pinned rather than fixed. The graph must never read node
      // existence as evidence that the writing still exists.
      final manuscript = await seedManuscript('project-archive');
      final scene = manuscript.chapters.first.scenes.first;
      await store.saveStudio(
        manuscript.copyWith(
          chapters: [
            manuscript.chapters.first.copyWith(
              scenes: [
                scene.copyWith(content: 'The bell rang twice before dawn.'),
                ...manuscript.chapters.first.scenes.skip(1),
              ],
            ),
          ],
        ),
      );

      final snapshot = await repository.snapshot();
      final archived = snapshot.manuscriptNodes
          .where((node) => node.id == scene.id)
          .toList();
      expect(archived, hasLength(1),
          reason: 'structure is archived');
      expect(jsonEncode(archived.single.toJson()),
          isNot(contains('The bell rang twice before dawn')),
          reason: 'prose lives in SharedPreferences and is NOT in the archive');
    });

    test('PlotService scene validation is dead because scenes are not records',
        () async {
      // R-5, pinned as a finding. Scenes are manuscript nodes under D-3, so a
      // record query for typeId 'scene' finds nothing and the orphaned-scene
      // rule never fires. The future graph must read manuscript nodes here.
      final manuscript = await seedManuscript('project-plot');
      await store.saveStudio(manuscript);
      expect(await repository.manuscriptNodesForProject('project-plot'),
          isNotEmpty);

      final scenesAsRecords = await repository.recordsByTypeAndScope(
        typeId: 'scene',
        scopeId: 'project-plot',
      );
      expect(scenesAsRecords, isEmpty,
          reason: 'scenes are manuscript nodes, never AuthorRecords (D-3)');
    });
  });

}
