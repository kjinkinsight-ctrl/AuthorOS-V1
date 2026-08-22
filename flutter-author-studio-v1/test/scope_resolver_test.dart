import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/series_scope.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
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

  ScopeResolver resolverFor(String projectId) =>
      ScopeResolver(projectId: projectId, repository: repository);

  SeriesScopeService seriesFor(String projectId) =>
      SeriesScopeService(projectId: projectId, repository: repository);

  test('a book with no record resolves to standalone', () async {
    final chain = await resolverFor('book-1').chain();

    expect(chain.isStandalone, isTrue);
    expect(chain.seriesId, isNull);
    expect(chain.inheritedScopeIds, isEmpty);
    expect(chain.visibleScopeIds, {'book-1'});
  });

  test('the project record is created once and never rewritten', () async {
    final resolver = resolverFor('book-1');
    final first = await resolver.ensureProjectRecord(title: 'Ash and Lanterns');
    final second = await resolver.ensureProjectRecord(title: 'A Different Name');

    expect(first.id, 'book-1');
    expect(first.typeId, kProjectRecordTypeId);
    expect(first.scopeType, RecordScopeType.project);
    expect(second.title, 'Ash and Lanterns',
        reason: 'a second call must not overwrite the author\'s title');
    expect(second.revision, first.revision,
        reason: 'a no-op must not bump a revision');
  });

  test('enrolling a book puts its series on the indexed column', () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'The Endovier Cycle');

    final chain = await resolverFor('book-1').chain();
    expect(chain.isStandalone, isFalse);
    expect(chain.seriesId, created.id);
    expect(chain.inheritedScopeIds, {created.id});

    final project = await repository.recordById('book-1');
    expect(project?.seriesId, created.id,
        reason: 'membership must live in series_id, not in a fields blob');
  });

  test('a series names the scope it owns', () async {
    final created = await seriesFor('book-1').createSeries(title: 'Endovier');

    expect(created.record.typeId, kSeriesRecordTypeId);
    expect(created.record.scopeType, RecordScopeType.series);
    expect(created.record.scopeId, created.id);
    expect(created.record.seriesId, created.id,
        reason: 'RecordScope.validate requires scope id and series id to match');
    expect(created.record.projectId, 'book-1',
        reason: 'the founding book stays on the record as provenance');
  });

  test('a second book joins an existing series', () async {
    final created = await seriesFor('book-1').createSeries(title: 'Endovier');
    await seriesFor('book-2').enrol(created.id);

    final members = await resolverFor('book-1').membersOf(created.id);
    expect(
      members.map((record) => record.id),
      containsAll(<String>['book-1', 'book-2']),
    );
  });

  test('a dangling series id resolves to standalone rather than throwing',
      () async {
    final resolver = resolverFor('book-1');
    final project = await resolver.ensureProjectRecord();
    await RecordServiceHarness(repository).stampMissingSeries(project);

    final chain = await resolver.chain();
    expect(chain.isStandalone, isTrue,
        reason: 'a missing series is a reason to show the book, not to fail');
  });

  test('withdrawing clears membership without touching shared records',
      () async {
    final series = seriesFor('book-1');
    final created = await series.createSeries(title: 'Endovier');
    final after = await series.withdraw();

    expect(after.isStandalone, isTrue);
    expect(await repository.recordById(created.id), isNotNull,
        reason: 'leaving a series must not delete the series');
  });
}

/// Writes a project record pointing at a series that does not exist.
///
/// Nothing in the application can produce this, so it is built directly. It is
/// still reachable in the wild: a series deleted while another book referenced
/// it leaves exactly this shape behind.
class RecordServiceHarness {
  const RecordServiceHarness(this.repository);

  final DriftConnectedDomainRepository repository;

  Future<void> stampMissingSeries(AuthorRecord project) async {
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: project.id,
          typeId: project.typeId,
          scopeType: project.scopeType,
          scopeId: project.scopeId,
          projectId: project.projectId,
          seriesId: 'series-that-was-deleted',
          title: project.title,
          createdAt: project.createdAt,
          updatedAt: now,
          revision: project.revision + 1,
        ),
      ],
      links: const [],
    );
  }
}
