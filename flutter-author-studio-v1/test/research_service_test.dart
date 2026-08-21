import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/research_record_types.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const projectA = 'project-research-a';
const projectB = 'project-research-b';
final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService research;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    research = ResearchService(projectId: projectA, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> seed(
    String id,
    String title, {
    String kind = 'Note',
    String category = 'Other',
    String status = 'New',
    bool important = false,
    String summary = '',
    String notes = '',
    List<String> tags = const [],
    ResearchService? service,
    int minute = 0,
  }) =>
      (service ?? research).createResearch(
        ResearchDraft(
          id: id,
          title: title,
          kind: kind,
          category: category,
          status: status,
          important: important,
          summary: summary,
          notes: notes,
          tags: tags,
        ),
        timestamp: timestamp.add(Duration(minutes: minute)),
      );

  group('Canonical record type', () {
    test('research-entry keeps its id, category, and general-lore base', () {
      final registry = BuiltInRecordTypes.registry();
      final entry = registry.resolve(ResearchRecordTypes.baseTypeId);

      expect(entry.id, 'research-entry');
      expect(entry.categoryId, 'research');
      expect(entry.baseTypeId, 'general-lore');
      expect(entry.builtIn, isTrue);
      // The general-lore fields research already relied on are inherited.
      final fieldIds = entry.fields.map((field) => field.id).toSet();
      expect(fieldIds, containsAll(<String>['name', 'summary', 'notes']));
      expect(
        fieldIds,
        containsAll(<String>[
          ResearchRecordTypes.kindFieldId,
          ResearchRecordTypes.categoryFieldId,
          ResearchRecordTypes.statusFieldId,
          ResearchRecordTypes.importantFieldId,
        ]),
      );
    });

    test('the research alias still resolves to the same canonical type', () {
      final registry = BuiltInRecordTypes.registry();
      expect(
        registry.isTemplateCompatible(
          ResearchRecordTypes.aliasTypeId,
          ResearchRecordTypes.baseTypeId,
        ),
        isTrue,
      );
      expect(
        registry
            .resolve(ResearchRecordTypes.aliasTypeId)
            .fields
            .map((field) => field.id),
        contains(ResearchRecordTypes.categoryFieldId),
      );
    });

    test('a research-entry written before this milestone still validates',
        () async {
      // A bare record with only general-lore fields, exactly as the Codex
      // wrote it before Research Studio existed.
      final legacy = AuthorRecord(
        id: 'legacy-research',
        typeId: ResearchRecordTypes.baseTypeId,
        scopeType: RecordScopeType.project,
        scopeId: projectA,
        projectId: projectA,
        title: 'Siege engines',
        fields: const {'name': 'Siege engines', 'summary': 'Trebuchets.'},
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final service = RecordService(
        projectId: projectA,
        repository: repository,
      );
      final result = await service.validateRecord(legacy);
      expect(result.isValid, isTrue, reason: result.errors.toString());

      await service.createRecord(legacy);
      final loaded = await research.getResearch('legacy-research');
      expect(loaded, isNotNull);
      // Missing choices fall back to the defaults rather than blowing up.
      expect(ResearchService.kindOf(loaded!), 'Note');
      expect(ResearchService.categoryOf(loaded), 'Other');
      expect(ResearchService.statusOf(loaded), 'New');
      expect(ResearchService.isImportant(loaded), isFalse);
    });
  });

  group('Research persistence', () {
    test('entries persist through the canonical repository', () async {
      final created = await seed(
        'research-1',
        'Medieval siege warfare',
        kind: 'Source',
        category: 'History',
        status: 'Reviewed',
        summary: 'How walls fell.',
        tags: const ['siege'],
      );

      expect(created.typeId, ResearchRecordTypes.baseTypeId);
      expect(created.projectId, projectA);
      expect(created.extensionData['researchStudio'], isTrue);

      // The record is readable straight off the shared repository, with no
      // Research-specific storage in between.
      final stored = await repository.recordById('research-1');
      expect(stored, isNotNull);
      expect(stored!.title, 'Medieval siege warfare');
      expect(
        stored.fields[ResearchRecordTypes.categoryFieldId],
        'History',
      );
      expect(stored.tags, ['siege']);
    });

    test('editing preserves fields the Studio does not own', () async {
      await seed('research-2', 'Star charts', summary: 'Navigation.');
      // Something outside Research Studio adds a field to the same record.
      final withForeignField = (await research.getResearch('research-2'))!;
      await research.records.updateRecord(
        withForeignField.copyWith(
          fields: {
            ...withForeignField.fields,
            'knowledgeStatus': 'Confirmed',
            'aliases': const ['Celestial charts'],
          },
          updatedAt: timestamp.add(const Duration(minutes: 1)),
        ),
      );

      final updated = await research.updateResearch(
        const ResearchDraft(
          id: 'research-2',
          title: 'Star charts of the north',
          category: 'Science',
          summary: 'Navigation and drift.',
          tags: ['stars'],
        ),
        timestamp: timestamp.add(const Duration(minutes: 2)),
      );

      expect(updated.title, 'Star charts of the north');
      expect(updated.fields['summary'], 'Navigation and drift.');
      expect(updated.fields[ResearchRecordTypes.categoryFieldId], 'Science');
      // Untouched foreign fields survive the edit.
      expect(updated.fields['knowledgeStatus'], 'Confirmed');
      expect(updated.fields['aliases'], ['Celestial charts']);
      expect(updated.createdAt, timestamp);
      expect(updated.revision, greaterThan(1));
    });

    test('important is a canonical field, and archived is the lifecycle',
        () async {
      await seed('research-3', 'Guild ledgers');
      final marked = await research.setImportant('research-3', true);
      expect(ResearchService.isImportant(marked), isTrue);
      expect(
        marked.fields[ResearchRecordTypes.importantFieldId],
        isTrue,
      );

      final archived = await research.archiveResearch('research-3');
      expect(archived.status, AuthorRecordStatus.archived);
      expect(ResearchService.statusOf(archived), 'Archived');
      // Archiving does not clobber the stored research status.
      expect(ResearchService.storedStatusOf(archived), 'New');

      final restored = await research.restoreResearch('research-3');
      expect(ResearchService.statusOf(restored), 'New');
    });

    test('deleted entries drop out of the library', () async {
      await seed('research-4', 'Rope making');
      await research.deleteResearch('research-4');
      expect(await research.query.all(), isEmpty);
    });
  });

  group('Search', () {
    test('finds entries by title, summary, notes, tags, and category',
        () async {
      await seed(
        'research-title',
        'Falconry',
        category: 'Culture',
        minute: 1,
      );
      await seed(
        'research-summary',
        'Hawking notes',
        summary: 'The mews and the jesses.',
        minute: 2,
      );
      await seed(
        'research-notes',
        'Bird lore',
        notes: 'Peregrines stoop at speed.',
        minute: 3,
      );
      await seed(
        'research-tag',
        'Hunting law',
        tags: const ['quarry'],
        minute: 4,
      );
      await seed(
        'research-category',
        'Coastal trade',
        category: 'Geography',
        minute: 5,
      );

      Future<Set<String>> ids(String query) async =>
          (await research.searchResearch(query))
              .map((record) => record.id)
              .toSet();

      expect(await ids('Falconry'), contains('research-title'));
      expect(await ids('jesses'), contains('research-summary'));
      expect(await ids('Peregrines'), contains('research-notes'));
      expect(await ids('quarry'), contains('research-tag'));
      expect(await ids('Geography'), contains('research-category'));
    });

    test('search is case-insensitive', () async {
      await seed('research-case', 'The Long Winter', summary: 'Snow drifts.');
      expect(
        (await research.searchResearch('long winter'))
            .map((record) => record.id),
        contains('research-case'),
      );
      expect(
        (await research.searchResearch('SNOW')).map((record) => record.id),
        contains('research-case'),
      );
    });

    test('an empty query returns the whole library', () async {
      await seed('research-a', 'A', minute: 1);
      await seed('research-b', 'B', minute: 2);
      expect((await research.searchResearch('   ')).length, 2);
    });

    test('search never returns non-research records', () async {
      await seed('research-hit', 'Harbour charts', minute: 1);
      await research.records.createRecord(
        AuthorRecord(
          id: 'character-hit',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: projectA,
          projectId: projectA,
          title: 'Harbour master',
          fields: const {
            'name': 'Harbour master',
            'identity.fullName': 'Harbour master',
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      final ids =
          (await research.searchResearch('Harbour')).map((r) => r.id).toSet();
      expect(ids, contains('research-hit'));
      expect(ids, isNot(contains('character-hit')));
    });
  });

  group('Filtering and sorting', () {
    setUp(() async {
      await seed(
        'r-history',
        'Siege engines',
        kind: 'Source',
        category: 'History',
        important: true,
        tags: const ['war'],
        minute: 1,
      );
      await seed(
        'r-culture',
        'Harvest festivals',
        kind: 'Note',
        category: 'Culture',
        status: 'Verified',
        tags: const ['war', 'feast'],
        minute: 5,
      );
      await seed(
        'r-science',
        'Alchemy primers',
        kind: 'Reference',
        category: 'Science',
        minute: 3,
      );
    });

    test('category filtering keeps only that category', () async {
      expect(
        (await research.query.byCategory('History')).map((r) => r.id),
        ['r-history'],
      );
      expect(await research.query.byCategory('Politics'), isEmpty);
    });

    test('kind, status, tag, and importance filters read the record',
        () async {
      expect(
        (await research.query.byKind('Reference')).map((r) => r.id),
        ['r-science'],
      );
      expect(
        (await research.query.byStatus('Verified')).map((r) => r.id),
        ['r-culture'],
      );
      expect(
        (await research.query.byTag('war')).map((r) => r.id).toSet(),
        {'r-history', 'r-culture'},
      );
      expect(
        (await research.query.important()).map((r) => r.id),
        ['r-history'],
      );
    });

    test('category counts and tags summarise the library', () async {
      expect(await research.query.categoryCounts(), {
        'History': 1,
        'Culture': 1,
        'Science': 1,
      });
      expect(await research.query.tags(), ['feast', 'war']);
    });

    test('shelves are derived from the loaded records', () async {
      final all = await research.query.all();
      expect(
        ResearchQueryService.onShelf(all, ResearchShelf.sources)
            .map((r) => r.id),
        ['r-history'],
      );
      expect(
        ResearchQueryService.onShelf(all, ResearchShelf.notes).map((r) => r.id),
        ['r-culture'],
      );
      expect(
        ResearchQueryService.onShelf(all, ResearchShelf.references)
            .map((r) => r.id),
        ['r-science'],
      );
      expect(
        ResearchQueryService.onShelf(all, ResearchShelf.important)
            .map((r) => r.id),
        ['r-history'],
      );
      expect(
        ResearchQueryService.onShelf(all, ResearchShelf.all).length,
        3,
      );
    });

    test('every sort order behaves', () async {
      final all = await research.query.all();

      expect(
        ResearchQueryService.sorted(all, ResearchSort.recentlyUpdated)
            .map((r) => r.id),
        ['r-culture', 'r-science', 'r-history'],
      );
      expect(
        ResearchQueryService.sorted(all, ResearchSort.recentlyCreated)
            .map((r) => r.id),
        ['r-culture', 'r-science', 'r-history'],
      );
      expect(
        ResearchQueryService.sorted(all, ResearchSort.alphabetical)
            .map((r) => r.id),
        ['r-science', 'r-culture', 'r-history'],
      );
      expect(
        ResearchQueryService.sorted(all, ResearchSort.category)
            .map((r) => r.id),
        ['r-culture', 'r-history', 'r-science'],
      );
      expect(
        ResearchQueryService.sorted(all, ResearchSort.importance)
            .first
            .id,
        'r-history',
      );
    });
  });

  group('Connections', () {
    test('research connects to other records through the shared engine',
        () async {
      await seed('r-link', 'Siege engines', minute: 1);
      await research.records.createRecord(
        AuthorRecord(
          id: 'character-mara',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: projectA,
          projectId: projectA,
          title: 'Mara',
          fields: const {'name': 'Mara', 'identity.fullName': 'Mara'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

      final link = await research.connect(
        sourceId: 'r-link',
        targetId: 'character-mara',
        typeId: 'documents',
        timestamp: timestamp,
      );
      expect(link.typeId, 'documents');
      expect(link.scopeId, projectA);

      // The link is readable off the shared repository, not a research table.
      expect(
        (await repository.outgoingLinks('r-link')).map((l) => l.id),
        contains(link.id),
      );

      final connected = await research.connectedRecords('r-link');
      expect(connected.single.record.id, 'character-mara');
      expect(connected.single.link.typeId, 'documents');
    });

    test('the research alias can also document a record', () async {
      await research.createResearch(
        const ResearchDraft(
          id: 'r-alias',
          title: 'Field notes',
          typeId: ResearchRecordTypes.aliasTypeId,
        ),
        timestamp: timestamp,
      );
      await research.records.createRecord(
        AuthorRecord(
          id: 'location-keep',
          typeId: 'location',
          scopeType: RecordScopeType.project,
          scopeId: projectA,
          projectId: projectA,
          title: 'The Keep',
          fields: const {'name': 'The Keep'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      final link = await research.connect(
        sourceId: 'r-alias',
        targetId: 'location-keep',
        typeId: 'documents',
        timestamp: timestamp,
      );
      expect(link.sourceId, 'r-alias');
    });

    test('connections cannot cross projects', () async {
      await seed('r-here', 'Local lore', minute: 1);
      final other = ResearchService(
        projectId: projectB,
        repository: repository,
      );
      await seed('r-there', 'Distant lore', service: other, minute: 1);

      expect(
        () => research.connect(
          sourceId: 'r-here',
          targetId: 'r-there',
          typeId: 'relatedTo',
          direction: RecordLinkDirection.undirected,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Project isolation', () {
    test('each project sees only its own research', () async {
      final other = ResearchService(
        projectId: projectB,
        repository: repository,
      );
      await seed('research-a', 'Research A', minute: 1);
      await seed('research-b', 'Research B', service: other, minute: 1);

      expect(
        (await research.query.all()).map((record) => record.id),
        ['research-a'],
      );
      expect(
        (await other.query.all()).map((record) => record.id),
        ['research-b'],
      );

      expect(await research.getResearch('research-b'), isNull);
      expect(await other.getResearch('research-a'), isNull);

      // Search is scoped too.
      expect(
        (await research.searchResearch('Research')).map((r) => r.id),
        ['research-a'],
      );
      expect(
        (await other.searchResearch('Research')).map((r) => r.id),
        ['research-b'],
      );

      expect(
        () => research.updateResearch(
          const ResearchDraft(id: 'research-b', title: 'Stolen'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => research.deleteResearch('research-b'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Guards', () {
    test('a blank title or id is rejected', () async {
      expect(
        () => research.createResearch(
          const ResearchDraft(id: 'r-blank', title: '   '),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => research.createResearch(
          const ResearchDraft(id: '  ', title: 'Nameless'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a non-research type cannot be created through this Studio',
        () async {
      expect(
        () => research.createResearch(
          const ResearchDraft(
            id: 'r-wrong',
            title: 'Wrong type',
            typeId: 'character',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('duplicate and inspect run through the shared record services',
        () async {
      await seed('r-source-entry', 'Sail rigging', category: 'Technology',
          minute: 1);

      final copy = await research.duplicateResearch(
        'r-source-entry',
        newId: 'r-copy',
        timestamp: timestamp.add(const Duration(minutes: 2)),
      );
      expect(copy.id, 'r-copy');
      expect(copy.title, 'Sail rigging Copy');
      expect(ResearchService.categoryOf(copy), 'Technology');
      expect(copy.extensionData['duplicatedFrom'], 'r-source-entry');
      expect(await research.getResearch('r-copy'), isNotNull);

      final inspection = await research.inspectResearch('r-source-entry');
      expect(inspection, isNotNull);

      // Neither reaches outside the project.
      expect(
        () => research.duplicateResearch('missing', newId: 'r-nope'),
        throwsA(isA<StateError>()),
      );
    });

    test('history is recorded through the shared audit trail', () async {
      await seed('r-history-trail', 'Sail rigging', minute: 1);
      await research.updateResearch(
        const ResearchDraft(id: 'r-history-trail', title: 'Sail rigging II'),
        timestamp: timestamp.add(const Duration(minutes: 2)),
      );
      final versions = await research.researchHistory('r-history-trail');
      expect(versions.length, greaterThanOrEqualTo(2));
    });
  });
}
