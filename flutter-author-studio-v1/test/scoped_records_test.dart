import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
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

  StoryCodexService codexFor(String projectId) =>
      StoryCodexService(projectId: projectId, repository: repository);

  Future<void> seed(
    String id, {
    required String projectId,
    required RecordScopeType scopeType,
    required String scopeId,
    String? seriesId,
  }) async {
    final now = DateTime.utc(2026, 8, 22);
    await repository.putRecordsAndLinks(
      records: [
        AuthorRecord(
          id: id,
          typeId: 'faction',
          scopeType: scopeType,
          scopeId: scopeId,
          projectId: projectId,
          seriesId: seriesId,
          title: id,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      links: const [],
    );
  }

  test('with no inherited scope the visible read is the project read', () async {
    await seed('a-own', projectId: 'book-1',
        scopeType: RecordScopeType.project, scopeId: 'book-1');
    await seed('b-own', projectId: 'book-2',
        scopeType: RecordScopeType.project, scopeId: 'book-2');

    final visible = await repository.recordsVisibleToProject('book-1');
    final plain = await repository.recordsByProject('book-1');

    expect(visible.map((record) => record.id), plain.map((record) => record.id));
    expect(visible.map((record) => record.id), ['a-own']);
  });

  test('an inherited scope adds shared canon and nothing else', () async {
    await seed('a-own', projectId: 'book-1',
        scopeType: RecordScopeType.project, scopeId: 'book-1');
    await seed('b-own', projectId: 'book-2',
        scopeType: RecordScopeType.project, scopeId: 'book-2');
    await seed('shared', projectId: 'book-2',
        scopeType: RecordScopeType.series, scopeId: 'series-1',
        seriesId: 'series-1');

    final visible = await repository
        .recordsVisibleToProject('book-1', inheritedScopeIds: const ['series-1']);

    expect(
      visible.map((record) => record.id),
      containsAll(<String>['a-own', 'shared']),
    );
    expect(visible.map((record) => record.id), isNot(contains('b-own')));
  });

  test('carrying a series id is not the same as being shared', () async {
    // A book-scoped record that merely names a series must stay private. This
    // is what the scope_type clause in the predicate buys.
    await seed('b-tagged', projectId: 'book-2',
        scopeType: RecordScopeType.project, scopeId: 'book-2',
        seriesId: 'series-1');

    final visible = await repository
        .recordsVisibleToProject('book-1', inheritedScopeIds: const ['series-1']);

    expect(visible.map((record) => record.id), isNot(contains('b-tagged')));
  });

  group('the Codex reads across books', () {
    test('a member book sees canon another book shared', () async {
      final one = codexFor('book-1');
      final created = await one.series.createSeries(title: 'Endovier');
      await one.createCodexEntry(
        const CodexEntryDraft(
          id: 'house-noxmere',
          title: 'House Noxmere',
          templateId: 'faction',
          categoryId: 'factions',
        ),
      );
      await one.promoteToSeries('house-noxmere');

      final two = codexFor('book-2');
      await two.series.enrol(created.id);
      await two.ensureFoundation();

      final entries = await two.getEntries();
      final titles = entries.map((entry) => entry.title);
      expect(titles, contains('House Noxmere'));

      final shared = entries.firstWhere((entry) => entry.id == 'house-noxmere');
      expect(shared.isShared, isTrue);
      expect(shared.scopeFacet, CodexScopeFacet.series);
      expect(shared.seriesId, created.id);
    });

    test('a standalone book sees nothing from a series it never joined',
        () async {
      final one = codexFor('book-1');
      await one.series.createSeries(title: 'Endovier');
      await one.createCodexEntry(
        const CodexEntryDraft(
          id: 'house-noxmere',
          title: 'House Noxmere',
          templateId: 'faction',
          categoryId: 'factions',
        ),
      );
      await one.promoteToSeries('house-noxmere');

      final outsider = codexFor('book-9');
      await outsider.ensureFoundation();

      expect(
        (await outsider.getEntries()).map((entry) => entry.id),
        isNot(contains('house-noxmere')),
      );
    });

    test('the scope facet narrows the list to one side', () async {
      final one = codexFor('book-1');
      await one.series.createSeries(title: 'Endovier');
      await one.createCodexEntry(
        const CodexEntryDraft(
          id: 'shared-faction',
          title: 'House Noxmere',
          templateId: 'faction',
          categoryId: 'factions',
        ),
      );
      await one.createCodexEntry(
        const CodexEntryDraft(
          id: 'book-faction',
          title: 'The Harbour Watch',
          templateId: 'faction',
          categoryId: 'factions',
        ),
      );
      await one.promoteToSeries('shared-faction');

      final shared = await one.filterEntries(
        const CodexEntryFilter(scopes: {CodexScopeFacet.series}),
      );
      expect(shared.map((entry) => entry.id), ['shared-faction']);

      final own = await one.filterEntries(
        const CodexEntryFilter(scopes: {CodexScopeFacet.book}),
      );
      expect(own.map((entry) => entry.id), ['book-faction']);
    });

    test('a saved view round-trips the scope facet', () async {
      const filter = CodexEntryFilter(scopes: {CodexScopeFacet.series});
      final restored = CodexEntryFilter.fromJson(filter.toJson());

      expect(restored.scopes, {CodexScopeFacet.series});
      expect(restored.isEmpty, isFalse);
      expect(restored.activeFacetCount, 1);
    });

    test('scope containers are not Codex entries', () async {
      final one = codexFor('book-1');
      await one.series.createSeries(title: 'Endovier');
      await one.ensureFoundation();

      final ids = (await one.getEntries(includeArchived: true))
          .map((entry) => entry.id)
          .toList();
      expect(ids, isNot(contains('book-1')),
          reason: 'the book is a container, not a lore entry');
      expect(
        ids.where((id) => id.startsWith('series-')),
        isEmpty,
        reason: 'the series is a container, not a lore entry',
      );
    });
  });
}
