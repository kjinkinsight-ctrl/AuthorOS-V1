/// Scope resolution under the locked identity model (Q-S1).
///
/// The project roster owns series identity. These tests prove the Codex reads
/// that id and never invents one.
library;

import 'package:author_studio_v1/core/scope_resolver.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/series_fixture.dart';

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

  test('a book the roster has never seen resolves to standalone', () async {
    final chain = await resolverFor('book-1').chain();

    expect(chain.isStandalone, isTrue);
    expect(chain.inheritedScopeIds, isEmpty);
    expect(chain.visibleScopeIds, {'book-1'});
  });

  test('an absent book is reported as unknown, not as a choice', () async {
    final resolver = resolverFor('book-1');
    expect(await resolver.membershipUnknown(), isTrue,
        reason: 'standalone and "not on the roster" must be distinguishable');

    await enrolStandalone(repository, 'book-1');
    expect(await resolver.membershipUnknown(), isFalse);
    expect((await resolver.chain()).isStandalone, isTrue);
  });

  test('a book on the roster with no series is standalone', () async {
    await enrolStandalone(repository, 'book-1');

    expect((await resolverFor('book-1').chain()).isStandalone, isTrue);
  });

  test('the chain reads the series the roster assigned', () async {
    await enrolInSeries(
      repository,
      seriesId: 'series_1724_0',
      projectIds: ['book-1', 'book-2'],
    );

    final chain = await resolverFor('book-2').chain();
    expect(chain.isStandalone, isFalse);
    expect(chain.seriesId, 'series_1724_0',
        reason: 'the roster id is used verbatim, with no translation');
    expect(chain.inheritedScopeIds, {'series_1724_0'});
  });

  test('members come from the roster, in series order', () async {
    await enrolInSeries(
      repository,
      seriesId: 'series_1724_0',
      projectIds: ['book-1', 'book-2', 'book-3'],
    );

    final members = await resolverFor('book-1').membersOf('series_1724_0');
    expect(members.map((entry) => entry.projectId),
        ['book-1', 'book-2', 'book-3']);
  });

  test('a series id with no series row resolves to standalone', () async {
    // The roster's own delete releases its books, so this should not occur.
    // A half-applied sync could still produce it, and inheriting from a series
    // that does not exist would be worse than showing the book alone.
    await enrolInSeries(
      repository,
      seriesId: 'series_gone',
      projectIds: ['book-1'],
    );
    await repository.deleteSeries('series_gone');

    expect((await resolverFor('book-1').chain()).isStandalone, isTrue);
  });

  test('ensureRosterEntry repairs an absent book without inventing a series',
      () async {
    final resolver = resolverFor('book-1');
    await resolver.ensureRosterEntry(starterProject('book-1', title: 'Ash'));

    final entry = await repository.projectRosterEntry('book-1');
    expect(entry, isNotNull);
    expect(entry!.seriesId, isNull,
        reason: 'repair must never guess at membership');
    expect(entry.project.title, 'Ash');
  });

  test('ensureRosterEntry never overwrites an existing row', () async {
    await enrolInSeries(
      repository,
      seriesId: 'series_1724_0',
      projectIds: ['book-1'],
    );

    await resolverFor('book-1')
        .ensureRosterEntry(starterProject('book-1', title: 'Renamed'));

    final entry = await repository.projectRosterEntry('book-1');
    expect(entry!.seriesId, 'series_1724_0',
        reason: 'a repair must not knock a book out of its series');
  });

  test('the project record is created once and never rewritten', () async {
    final resolver = resolverFor('book-1');
    final first = await resolver.ensureProjectRecord(title: 'Ash and Lanterns');
    final second = await resolver.ensureProjectRecord(title: 'A Different Name');

    expect(first.id, 'book-1');
    expect(first.typeId, kProjectRecordTypeId);
    expect(second.title, 'Ash and Lanterns');
    expect(second.revision, first.revision);
  });
}
