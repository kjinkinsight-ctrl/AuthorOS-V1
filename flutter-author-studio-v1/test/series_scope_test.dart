import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/series_scope.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  SeriesScopeService seriesFor(String projectId) =>
      SeriesScopeService(projectId: projectId, repository: repository);

  RecordService recordsFor(String projectId, {Set<String> inherited = const {}}) =>
      RecordService(
        projectId: projectId,
        repository: repository,
        inheritedScopeIds: inherited,
      );

  Future<AuthorRecord> seedCharacter(
    String projectId, {
    String id = 'kael',
    String title = 'Kael Noxmere',
  }) async {
    final now = DateTime.utc(2026, 8, 22);
    return recordsFor(projectId).createRecord(
      AuthorRecord(
        id: id,
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: title,
        canonStatus: CanonStatus.canon,
        templateId: 'character',
        fields: {'identity.fullName': title},
        tags: const ['northern'],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('promote and demote preserve identity, content and relationships',
      () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'The Endovier Cycle');
    final original = await seedCharacter('book-1');

    // A relationship the character must survive being shared.
    await seedCharacter('book-1', id: 'lyra', title: 'Lyra Vane');
    final engine = ConnectionEngine(scopeId: 'book-1', repository: repository);
    await engine.connect(
      sourceId: 'kael',
      targetId: 'lyra',
      typeId: 'knows',
    );

    final promoted = await series.promoteToSeries('kael');

    expect(promoted.id, original.id, reason: 'the M4 gate: ids are preserved');
    expect(promoted.createdAt, original.createdAt);
    expect(promoted.typeId, original.typeId);
    expect(promoted.title, original.title);
    expect(promoted.fields, original.fields);
    expect(promoted.tags, original.tags);
    expect(promoted.scopeType, RecordScopeType.series);
    expect(promoted.scopeId, created.id);
    expect(promoted.seriesId, created.id);
    expect(promoted.projectId, 'book-1',
        reason: 'provenance survives promotion; it is the history partition');

    final linksAfterPromote = await repository.backlinks('kael');
    expect(linksAfterPromote, hasLength(1));
    expect(linksAfterPromote.single.scopeId, 'book-1',
        reason: 'promotion moves the node, not its edges');

    final demoted = await series.demoteToProject('kael');

    expect(demoted.id, original.id);
    expect(demoted.createdAt, original.createdAt);
    expect(demoted.fields, original.fields);
    expect(demoted.tags, original.tags);
    expect(demoted.scopeType, RecordScopeType.project);
    expect(demoted.scopeId, 'book-1');
    expect(demoted.seriesId, isNull);
    expect(demoted.revision, original.revision + 2,
        reason: 'two audited scope changes, no more');

    expect(await repository.backlinks('kael'), hasLength(1));
  });

  test('each scope change is audited exactly once', () async {
    final series = seriesFor('book-1');
    await series.createSeries(title: 'Endovier');
    await seedCharacter('book-1');

    await series.promoteToSeries('kael');
    await series.demoteToProject('kael');

    final events = await repository.auditHistory(
      const HistoryFilter(projectId: 'book-1', recordId: 'kael'),
    );
    final scopeChanges = events
        .where((event) => event.changeType == AuditChangeType.scopeChanged)
        .toList();
    expect(scopeChanges, hasLength(2));
  });

  test('a shared record keeps one version chain across books', () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'Endovier');
    await seedCharacter('book-1');
    await series.promoteToSeries('kael');

    // Book two joins and edits the shared record through the inherited scope.
    await seriesFor('book-2').enrol(created.id);
    final fromBookTwo = recordsFor('book-2', inherited: {created.id});
    final shared = await fromBookTwo.getRecord('kael');
    expect(shared, isNotNull,
        reason: 'a member book must be able to read shared canon');

    await fromBookTwo.updateRecord(
      shared!.copyWith(
        title: 'Kael Noxmere the Elder',
        updatedAt: DateTime.utc(2026, 8, 23),
      ),
    );

    final partitions = await database.customSelect(
      'SELECT DISTINCT project_id FROM record_version_rows WHERE record_id = ?',
      variables: [const Variable<String>('kael')],
    ).get();
    expect(partitions, hasLength(1),
        reason: 'history belongs to the record, not to whoever opened it');
    expect(partitions.single.read<String>('project_id'), 'book-1');
  });

  test('a book cannot return canon another book owns', () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'Endovier');
    await seedCharacter('book-1');
    await series.promoteToSeries('kael');
    await seriesFor('book-2').enrol(created.id);

    expect(
      () => seriesFor('book-2').demoteToProject('kael'),
      throwsA(isA<StateError>()),
    );
  });

  test('promoting without a series is refused', () async {
    await seedCharacter('book-1');

    expect(
      () => seriesFor('book-1').promoteToSeries('kael'),
      throwsA(isA<StateError>()),
    );
  });

  test('rehoming moves provenance so a series outlives its founding book',
      () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'Endovier');

    final rehomed = await series.rehomeSeries(created.id, toProjectId: 'book-2');

    expect(rehomed.projectId, 'book-2');
    expect(rehomed.id, created.id);
    expect(rehomed.scopeId, created.id,
        reason: 'the scope a series owns never moves');
  });
}
