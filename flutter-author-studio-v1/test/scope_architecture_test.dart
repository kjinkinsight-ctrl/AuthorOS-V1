/// Architecture guardrails for cross-book scope.
///
/// These are not feature tests. Each one pins a boundary that
/// `docs/codex-universal-knowledge-implementation-map.md` depends on, so that a
/// change which quietly builds a second scope system — a series table, a second
/// resolution path, a cross-project edge, a forked history chain — fails here
/// instead of being discovered when an author's series stops agreeing with
/// itself.
///
/// A failure is not necessarily a bug. It means an architectural decision was
/// made, and the map needs updating alongside it.
library;

import 'dart:io';

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/codex_intelligence.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/entity_recognition.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/series_scope.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/series_fixture.dart';

Iterable<File> get _libSources => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => !file.path.endsWith('.g.dart'));

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  test('the roster owns series identity and the Codex mints none', () async {
    // Q-S1, locked. `series_rows` is the one place a series is named, and the
    // Codex consumes that id. This is the assertion that would have caught the
    // divergence had it existed when the two systems were built in parallel.
    final offenders = <String>[];
    for (final file in _libSources) {
      // `writing_series.dart` defines the generator; `main.dart` is the
      // Projects Studio, the one screen where an author names a series.
      // Everywhere else, minting one is the divergence this test exists for.
      if (file.path.endsWith('core/writing_series.dart')) continue;
      if (file.path.endsWith('main.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('WritingSeriesId.create(') ||
          source.contains("'series-\${") ||
          source.contains("'series_\${")) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'series identity is created in the Projects Studio, nowhere else');

    // The Codex cannot create, rename, enrol or withdraw. Those are the roster's.
    final scopeSource = File('lib/core/series_scope.dart').readAsStringSync();
    for (final gone in const [
      'createSeries',
      'Future<ScopeChain> enrol',
      'Future<ScopeChain> withdraw',
    ]) {
      expect(scopeSource.contains(gone), isFalse,
          reason: 'series authoring belongs to the roster ($gone)');
    }

    // Scope still adds no store of its own.
    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final names = rows.map((row) => row.read<String>('name')).toSet();
    for (final forbidden in const [
      'series_scope_rows',
      'universe_rows',
      'scope_rows',
      'series_member_rows',
    ]) {
      expect(names, isNot(contains(forbidden)));
    }
  });

  test('membership has exactly one source of truth', () async {
    // The roster row is the truth. A `project` record carrying a stale
    // series_id must not be able to contradict it, or the Codex and the
    // Projects Studio will disagree about what series a book is in.
    await enrolStandalone(repository, 'book-1');
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: 'book-1',
          typeId: kProjectRecordTypeId,
          scopeType: RecordScopeType.project,
          scopeId: 'book-1',
          projectId: 'book-1',
          seriesId: 'series_that_the_roster_never_heard_of',
          title: 'Ash',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      links: const [],
    );

    final chain =
        await ScopeResolver(projectId: 'book-1', repository: repository).chain();
    expect(chain.isStandalone, isTrue,
        reason: 'the record is a mirror; the roster row is the truth');
  });

  test('deleting a series never strands its canon', () async {
    final series = await enrolInSeries(repository,
        seriesId: 'series_1724_0', projectIds: ['book-1']);
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: 'kael',
          typeId: 'faction',
          scopeType: RecordScopeType.project,
          scopeId: 'book-1',
          projectId: 'book-1',
          title: 'Kael',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      links: const [],
    );
    final scope =
        SeriesScopeService(projectId: 'book-1', repository: repository);
    await scope.promoteToSeries('kael');

    await scope.releaseSeries(series.id);

    expect(await repository.recordsInSeriesScope(series.id), isEmpty);
    expect(await repository.recordById('kael'), isNotNull,
        reason: 'releasing a series must never delete a record');
  });

  test('there is exactly one scope-resolution path', () {
    final offenders = <String>[];
    for (final file in _libSources) {
      // The repository declares the query; the resolver is the only caller
      // allowed to use it. Anything else reading a project's series membership
      // is a second resolver, and the two will disagree.
      if (file.path.endsWith('scope_resolver.dart')) continue;
      if (file.path.endsWith('persistence/authoros_database.dart')) continue;
      // The roster store is the roster's own service; reading its own rows is
      // not a second resolver.
      if (file.path.endsWith('project_roster_store.dart')) continue;
      if (file.path.endsWith('sync/sync_appliers.dart')) continue;
      if (file.path.endsWith('series_analytics_service.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('projectRosterEntry(') ||
          source.contains('booksInSeries(')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'membership is resolved by ScopeResolver alone');
  });

  test('no second scope store has appeared in lib/', () {
    final offenders = <String>[];
    for (final file in _libSources) {
      final name = file.uri.pathSegments.last;
      if (const {
        'series_repository.dart',
        'scope_store.dart',
        'series_store.dart',
        'universe_store.dart',
      }.contains(name)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('scope changes only through RecordService.changeScope', () {
    // Behavioural rather than textual: copyWith still cannot express a scope
    // change, which is what keeps changeScope the only door.
    final now = DateTime.utc(2026, 8, 22);
    final record = AuthorRecord(
      id: 'x',
      typeId: 'faction',
      scopeType: RecordScopeType.project,
      scopeId: 'book-1',
      projectId: 'book-1',
      title: 'X',
      createdAt: now,
      updatedAt: now,
    );
    final copied = record.copyWith(title: 'Y');

    expect(copied.scopeType, record.scopeType);
    expect(copied.scopeId, record.scopeId);
    expect(copied.seriesId, record.seriesId);
    expect(copied.projectId, record.projectId);
  });

  test('no cross-project connection type was introduced', () {
    // The invariant: a record's *scope* — which book or series it belongs to —
    // is `seriesId`/`bookId`/`scopeId` on the row, never a link. Two ways to
    // answer "is this record series canon?" is how the two answers drift.
    //
    // `bookInSeries` is the deliberate exception, and it is not scope: it
    // links a Codex `book` record to a Codex `series` record, the same way
    // `appearsIn` links a character to a book. It moves no scope column, and
    // `ScopeResolver` never reads it. The behavioural proof that the roster
    // still owns membership is in story_graph_architecture_test.dart —
    // "building a series writes no records, links, versions or audit events".
    const codexSpine = {'bookinseries'};

    final ids = BuiltInConnectionTypes.registry()
        .definitions
        .map((definition) => definition.id.toLowerCase())
        .toList();

    for (final id in ids) {
      if (codexSpine.contains(id)) continue;
      expect(id.contains('series'), isFalse,
          reason: 'scope membership is a column, not an edge');
      expect(id.contains('universe'), isFalse);
    }

    // The exception stays an exception: it is typed to two Codex record types
    // and cannot be pointed at anything else.
    final spine = BuiltInConnectionTypes.registry().resolve('bookInSeries');
    expect(spine.permits('book', 'series'), isTrue);
    expect(spine.permits('character', 'series'), isFalse);
  });

  test('project isolation still holds for a promoted record', () async {
    final series = SeriesScopeService(
      projectId: 'book-1',
      repository: repository,
    );
    final created = await enrolInSeries(repository,
        seriesId: 'series_1724_0', projectIds: ['book-1']);
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: 'kael',
          typeId: 'faction',
          scopeType: RecordScopeType.project,
          scopeId: 'book-1',
          projectId: 'book-1',
          title: 'Kael',
          createdAt: now,
          updatedAt: now,
        ),
        AuthorRecord(
          id: 'outsider',
          typeId: 'faction',
          scopeType: RecordScopeType.project,
          scopeId: 'book-9',
          projectId: 'book-9',
          title: 'Outsider',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      links: const [],
    );
    await series.promoteToSeries('kael');

    final engine = ConnectionEngine(scopeId: 'book-1', repository: repository);
    expect(
      () => engine.connect(
        sourceId: 'kael',
        targetId: 'outsider',
        typeId: 'relatedTo',
      ),
      throwsA(isA<StateError>()),
      reason: 'promotion must not become a hole in project isolation',
    );

    final promoted = await repository.recordById('kael');
    expect(promoted!.scopeType, RecordScopeType.series);
    expect(promoted.scopeId, created.id,
        reason: 'the promoted record hangs on the roster\'s series id');
  });

  test('a record has exactly one history partition', () async {
    final series = SeriesScopeService(
      projectId: 'book-1',
      repository: repository,
    );
    final created = await enrolInSeries(repository,
        seriesId: 'series_1724_0', projectIds: ['book-1']);
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: 'kael',
          typeId: 'faction',
          scopeType: RecordScopeType.project,
          scopeId: 'book-1',
          projectId: 'book-1',
          title: 'Kael',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      links: const [],
    );
    await series.promoteToSeries('kael');
    await enrolInSeries(repository,
        seriesId: created.id, projectIds: ['book-1', 'book-2']);
    await series.demoteToProject('kael');

    final partitions = await database.customSelect(
      'SELECT DISTINCT project_id FROM record_version_rows WHERE record_id = ?',
      variables: [const Variable<String>('kael')],
    ).get();

    expect(partitions, hasLength(1),
        reason: 'a forked version chain silently loses an author\'s history');
  });

  test('universe membership has no second home', () {
    // The universe tier is deliberately not shipped. This fails the moment
    // someone hides it in a fields blob instead of adding the column.
    final offenders = <String>[];
    for (final file in _libSources) {
      final source = file.readAsStringSync();
      if (source.contains("'_universe.") || source.contains('"_universe.')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'the universe tier needs a column, not a JSON field');
  });

  test('entity recognition has one definition', () {
    // The mention predicate used to be written three times, in the Manuscript,
    // Codex and World analyzers. Three copies of a matching rule are three
    // chances for the Studios to disagree about whether a character appears in
    // a scene, and the disagreement would be silent.
    final offenders = <String>[];
    for (final file in _libSources) {
      if (file.path.endsWith('core/entity_recognition.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('RegExp.escape(') &&
          source.contains('[^a-z0-9]')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use mentionsName rather than inlining the predicate');

    expect(mentionsName('kali walked', 'Kali'), isTrue);
    expect(mentionsName('kalina walked', 'Kali'), isFalse);
  });

  test('a derived edge never becomes a link on its own', () {
    // Co-occurrence returns DerivedStoryGraphEdge, which has no id and cannot
    // be persisted. The Story Graph's own exit criterion for derived edges is
    // that not one reaches record_link_rows without an author pressing a
    // button; discovery must not be the exception.
    final source =
        File('lib/core/codex_intelligence.dart').readAsStringSync();
    expect(source.contains('RecordLink('), isFalse,
        reason: 'discovery may not construct a persisted edge');
    expect(source.contains('putRecord'), isFalse);
    expect(source.contains('ConnectionEngine'), isFalse);

    final edges = const CoOccurrenceDiscovery().discover(scenes: [
      const SceneMentionSet(
        sceneId: 'scene-1',
        sceneTitle: 'One',
        recordIds: {'a', 'b'},
      ),
      const SceneMentionSet(
        sceneId: 'scene-2',
        sceneTitle: 'Two',
        recordIds: {'a', 'b'},
      ),
    ]);
    expect(edges.single.derivation, kCoOccurrenceDerivation,
        reason: 'a promoted inference must carry its origin');
  });

  test('the intelligence layer stays deterministic and offline', () {
    // AI-free is the product position, not an implementation detail. This
    // fails the moment a model or a network call appears in the layer that
    // produces recommendations.
    const forbidden = [
      'package:http',
      'dart:io',
      'HttpClient',
      'anthropic',
      'openai',
      'Random(',
    ];
    for (final name in const [
      'lib/core/codex_intelligence.dart',
      'lib/core/entity_recognition.dart',
      'lib/codex_suggestions.dart',
      'lib/codex_continuity.dart',
      'lib/manuscript_continuity.dart',
    ]) {
      final source = File(name).readAsStringSync();
      for (final token in forbidden) {
        expect(source.contains(token), isFalse,
            reason: '$name must stay deterministic and offline ($token)');
      }
    }
  });

  test('the Codex reads prose without creating any', () {
    // loadStudio seeds and writes a starter manuscript on a miss. A Studio
    // asking to read prose must never be what causes a manuscript to exist.
    final source = File('lib/codex_suggestions.dart').readAsStringSync();
    expect(source.contains('loadStudio'), isFalse,
        reason: 'read through peekStudio, which never writes');
    expect(source.contains('saveStudio'), isFalse);
  });

  test('the shared-scope predicate has one definition', () {
    // The repository, the record service, the validator and the Codex all have
    // to agree on what "inherited" means. Three inlined copies are three
    // chances to disagree, and the disagreement would be silent.
    final offenders = <String>[];
    for (final file in _libSources) {
      if (file.path.endsWith('core/record_scope.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('RecordScopeType.series, RecordScopeType.universe') ||
          source.contains('RecordScopeType.universe, RecordScopeType.series')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use isInheritedSharedScope rather than inlining the set');

    expect(kSharedScopeTypes,
        {RecordScopeType.universe, RecordScopeType.series});
    expect(
      isInheritedSharedScope(
        scopeType: RecordScopeType.project,
        scopeId: 'series-1',
        inheritedScopeIds: const {'series-1'},
      ),
      isFalse,
      reason: 'carrying a shared scope id is not the same as being shared',
    );
  });

  test('scope containers are named in one place', () {
    expect(kScopeContainerTypeIds, {kProjectRecordTypeId, kSeriesRecordTypeId});

    final offenders = <String>[];
    for (final file in _libSources) {
      if (file.path.endsWith('scope_resolver.dart')) continue;
      final source = file.readAsStringSync();
      // A hand-rolled exclusion list is how the two copies drift apart.
      if (source.contains("{'project', 'series'}") ||
          source.contains("{'series', 'project'}")) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
