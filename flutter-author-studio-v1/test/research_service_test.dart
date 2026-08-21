import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_validation.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const projectId = 'project-research';
final timestamp = DateTime.utc(2026, 5, 4, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService service;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    service = ResearchService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<CodexEntry> seed({
    String id = 'research-tide',
    String title = 'Tidal lock records',
    String typeId = ResearchRecordTypes.entryTypeId,
    String categoryId = 'research',
    String summary = 'Harbour tide tables for the siege chapters.',
    String details = 'Two tides a day, four hours out of phase.',
    String notes = 'Cross-check against the Admiralty chart.',
    List<String> tags = const ['harbour'],
    CodexKnowledgeStatus knowledgeStatus = CodexKnowledgeStatus.unknown,
    CodexCanonStatus canonStatus = CodexCanonStatus.draft,
    List<CodexSourceReference> sources = const [],
  }) =>
      service.createResearch(
        ResearchDraft(
          id: id,
          title: title,
          typeId: typeId,
          categoryId: categoryId,
          summary: summary,
          details: details,
          notes: notes,
          tagIds: tags,
          knowledgeStatus: knowledgeStatus,
          canonStatus: canonStatus,
          sources: sources,
        ),
        timestamp: timestamp,
      );

  // -------------------------------------------------------------------------
  // Create, read, update
  // -------------------------------------------------------------------------

  group('lifecycle', () {
    test('creates a research record on the shared Universal Record schema',
        () async {
      final entry = await seed();

      expect(entry.id, 'research-tide');
      expect(entry.record.typeId, ResearchRecordTypes.entryTypeId);
      expect(entry.record.templateId, ResearchRecordTypes.entryTypeId);
      expect(entry.record.templateVersion, isNotNull);
      expect(entry.record.scopeType, RecordScopeType.project);
      expect(entry.projectId, projectId);
      expect(entry.categoryId, 'research');
      expect(entry.title, 'Tidal lock records');
      expect(entry.summary, 'Harbour tide tables for the siege chapters.');
      expect(entry.content, 'Two tides a day, four hours out of phase.');
      expect(entry.structuredFields['notes'],
          'Cross-check against the Admiralty chart.');
      expect(entry.tagIds, ['harbour']);
      expect(entry.knowledgeStatus, CodexKnowledgeStatus.unknown);
      expect(entry.status, AuthorRecordStatus.active);

      // The row is a plain AuthorRecord: no second research table exists.
      final stored = await repository.recordById(entry.id);
      expect(stored, isNotNull);
      expect(stored!.fields['name'], 'Tidal lock records');
    });

    test('reads back only records this project owns', () async {
      await seed();
      final other = ResearchService(
        projectId: 'other-project',
        repository: repository,
      );

      expect(await service.getResearch('research-tide'), isNotNull);
      expect(await other.getResearch('research-tide'), isNull);
      expect(await other.listResearch(), isEmpty);
    });

    test('does not claim records belonging to other studios', () async {
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.createCodexEntry(
        const CodexEntryDraft(
          id: 'loc-harbour',
          title: 'Noxmere Harbour',
          templateId: 'location',
          categoryId: 'locations',
        ),
        timestamp: timestamp,
      );
      await seed();

      final ids = (await service.listResearch()).map((e) => e.id).toList();
      expect(ids, ['research-tide']);
      expect(await service.getResearch('loc-harbour'), isNull);
    });

    test('updates every editable research field', () async {
      final entry = await seed();

      final updated = await service.updateResearch(
        entry.id,
        title: 'Tide tables, revised',
        summary: 'Revised summary.',
        details: 'Revised details.',
        notes: 'Revised notes.',
        categoryId: 'reference',
        tagIds: const ['harbour', 'siege'],
        canonStatus: CodexCanonStatus.canon,
        knowledgeStatus: CodexKnowledgeStatus.confirmed,
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      expect(updated.title, 'Tide tables, revised');
      expect(updated.summary, 'Revised summary.');
      expect(updated.content, 'Revised details.');
      expect(updated.structuredFields['notes'], 'Revised notes.');
      expect(updated.categoryId, 'reference');
      expect(updated.tagIds, containsAll(['harbour', 'siege']));
      expect(updated.canonStatus, CodexCanonStatus.canon);
      expect(updated.knowledgeStatus, CodexKnowledgeStatus.confirmed);
      expect(updated.record.revision, greaterThan(entry.record.revision));
    });

    test('archives, restores, and soft-deletes through the record lifecycle',
        () async {
      final entry = await seed();

      final archived = await service.archiveResearch(entry.id);
      expect(archived.status, AuthorRecordStatus.archived);
      expect(await service.listResearch(), isEmpty);
      expect(await service.listResearch(includeArchived: true), hasLength(1));

      final restored = await service.restoreResearch(entry.id);
      expect(restored.status, AuthorRecordStatus.active);
      expect(await service.listResearch(), hasLength(1));

      final deleted = await service.deleteResearch(entry.id);
      expect(deleted.status, AuthorRecordStatus.deleted);
      expect(await service.listResearch(includeArchived: true), isEmpty);
      // Deletion is a lifecycle state, so the record and its history survive.
      expect(await repository.recordById(entry.id), isNotNull);
      expect(await service.getResearch(entry.id), isNotNull);
    });

    test('duplicating copies the fields into a new record', () async {
      final entry = await seed();
      final copy = await service.duplicateResearch(
        entry.id,
        timestamp: timestamp.add(const Duration(minutes: 5)),
      );

      expect(copy.id, isNot(entry.id));
      expect(copy.title, '${entry.title} Copy');
      expect(copy.summary, entry.summary);
      expect(copy.record.typeId, ResearchRecordTypes.entryTypeId);
    });

    test('writes a version history entry for each change', () async {
      final entry = await seed();
      await service.updateResearch(
        entry.id,
        title: 'Second title',
        timestamp: timestamp.add(const Duration(hours: 2)),
      );

      final history = await service.historyFor(entry.id);
      expect(history.length, greaterThanOrEqualTo(2));
    });
  });

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  group('validation', () {
    test('rejects an empty title', () async {
      await expectLater(
        service.createResearch(const ResearchDraft(title: '   ')),
        throwsA(isA<ArgumentError>()),
      );
      expect(await service.listResearch(), isEmpty);
    });

    test('rejects a record type Research Studio does not own', () async {
      await expectLater(
        service.createResearch(
          const ResearchDraft(title: 'Not research', typeId: 'location'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an unknown category', () async {
      await expectLater(
        service.createResearch(
          const ResearchDraft(title: 'Nowhere', categoryId: 'not-a-category'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a duplicate id', () async {
      await seed();
      await expectLater(
        seed(title: 'Same id again'),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses to mutate a record from another project', () async {
      await seed();
      final other = ResearchService(
        projectId: 'other-project',
        repository: repository,
      );
      await expectLater(
        other.updateResearch('research-tide', title: 'Hijacked'),
        throwsA(isA<StateError>()),
      );
    });

    test('validates a stored record against its template', () async {
      final entry = await seed();
      final result = await service.validateResearch(entry.id);
      expect(result, isA<RecordValidationResult>());
      expect(result.isValid, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Search and filtering
  // -------------------------------------------------------------------------

  group('search and filtering', () {
    Future<void> seedLibrary() async {
      await seed();
      await seed(
        id: 'research-charts',
        title: 'Admiralty chart notes',
        summary: 'Depth soundings around the northern cliffs.',
        details: 'Soundings taken in the third season.',
        notes: '',
        tags: const ['charts'],
        typeId: 'reference',
        categoryId: 'reference',
        knowledgeStatus: CodexKnowledgeStatus.confirmed,
        canonStatus: CodexCanonStatus.canon,
        sources: const [
          CodexSourceReference(
            recordId: '',
            kind: 'external',
            label: 'Admiralty Chart 118',
            location: 'https://example.invalid/chart-118',
          ),
        ],
      );
      await seed(
        id: 'research-retired',
        title: 'Retired lantern lore',
        summary: 'Superseded by the harbour rewrite.',
        details: '',
        notes: '',
        tags: const [],
        categoryId: 'research',
      );
      await service.archiveResearch('research-retired');
    }

    test('searches stored records through the shared FTS index', () async {
      await seedLibrary();

      // "soundings" appears only in the chart entry; "Admiralty" appears in
      // both, because the tide entry's notes cite the same chart.
      expect(
        (await service.searchResearch('soundings')).map((entry) => entry.id),
        ['research-charts'],
      );
      expect(
        (await service.searchResearch('Admiralty')).map((entry) => entry.id),
        unorderedEquals(['research-charts', 'research-tide']),
      );

      expect(await service.searchResearch('   '), hasLength(2));
      expect(await service.searchResearch('nothing-matches-this'), isEmpty);
    });

    test('search never returns another studio\'s records', () async {
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.createCodexEntry(
        const CodexEntryDraft(
          id: 'loc-soundings',
          title: 'Soundings House',
          templateId: 'location',
          categoryId: 'locations',
        ),
        timestamp: timestamp,
      );
      await seedLibrary();

      // The location matches the same term, but Research Studio never
      // surfaces a record it does not own.
      expect(
        (await codex.searchCodex('soundings')).map((entry) => entry.id),
        containsAll(['loc-soundings', 'research-charts']),
      );
      expect(
        (await service.searchResearch('soundings')).map((entry) => entry.id),
        ['research-charts'],
      );
    });

    test('filters by query, type, category, tag, canon and knowledge',
        () async {
      await seedLibrary();

      Future<List<String>> ids(ResearchFilter filter) async =>
          (await service.filterResearch(filter))
              .map((entry) => entry.id)
              .toList();

      expect(
        await ids(ResearchFilter.empty),
        unorderedEquals(['research-tide', 'research-charts']),
      );
      expect(
        await ids(const ResearchFilter(query: 'soundings')),
        ['research-charts'],
      );
      expect(
        await ids(const ResearchFilter(typeIds: {'reference'})),
        ['research-charts'],
      );
      expect(
        await ids(const ResearchFilter(categoryIds: {'research'})),
        ['research-tide'],
      );
      expect(
        await ids(const ResearchFilter(tagIds: {'charts'})),
        ['research-charts'],
      );
      expect(
        await ids(const ResearchFilter(
          canonStatuses: {CodexCanonStatus.canon},
        )),
        ['research-charts'],
      );
      expect(
        await ids(const ResearchFilter(
          knowledgeStatuses: {CodexKnowledgeStatus.confirmed},
        )),
        ['research-charts'],
      );
    });

    test('filters archived and unresolved research', () async {
      await seedLibrary();

      Future<List<String>> ids(ResearchFilter filter) async =>
          (await service.filterResearch(filter))
              .map((entry) => entry.id)
              .toList();

      expect(
        await ids(const ResearchFilter(includeArchived: true)),
        containsAll(['research-tide', 'research-charts', 'research-retired']),
      );
      // Unresolved = not verified, or verified without a source.
      expect(
        await ids(const ResearchFilter(onlyUnresolved: true)),
        ['research-tide'],
      );
    });

    test('filters research connected to another record in the project',
        () async {
      await seedLibrary();
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.createCodexEntry(
        const CodexEntryDraft(
          id: 'loc-cliffs',
          title: 'Northern cliffs',
          templateId: 'location',
          categoryId: 'locations',
        ),
        timestamp: timestamp,
      );
      await service.connectResearch(
        researchId: 'research-charts',
        targetId: 'loc-cliffs',
        typeId: 'documents',
        timestamp: timestamp,
      );

      final connected =
          await service.filterResearch(const ResearchFilter(onlyConnected: true));
      expect(connected.map((entry) => entry.id), ['research-charts']);
    });

    test('sorts by title, recency and reliability', () async {
      await seedLibrary();

      Future<List<String>> ids(ResearchSort sort) async =>
          (await service.filterResearch(ResearchFilter(sort: sort)))
              .map((entry) => entry.id)
              .toList();

      expect(await ids(ResearchSort.title),
          ['research-charts', 'research-tide']);
      expect(await ids(ResearchSort.reliability),
          ['research-charts', 'research-tide']);
      expect(await ids(ResearchSort.recentlyUpdated), hasLength(2));
    });

    test('a filter round-trips through JSON', () {
      const filter = ResearchFilter(
        query: 'tide',
        typeIds: {'reference'},
        categoryIds: {'research'},
        tagIds: {'charts'},
        canonStatuses: {CodexCanonStatus.canon},
        knowledgeStatuses: {CodexKnowledgeStatus.confirmed},
        includeArchived: true,
        onlyUnresolved: true,
        onlyConnected: true,
        sort: ResearchSort.title,
      );

      final restored = ResearchFilter.fromJson(filter.toJson());

      expect(restored.query, filter.query);
      expect(restored.typeIds, filter.typeIds);
      expect(restored.categoryIds, filter.categoryIds);
      expect(restored.tagIds, filter.tagIds);
      expect(restored.canonStatuses, filter.canonStatuses);
      expect(restored.knowledgeStatuses, filter.knowledgeStatuses);
      expect(restored.includeArchived, isTrue);
      expect(restored.onlyUnresolved, isTrue);
      expect(restored.onlyConnected, isTrue);
      expect(restored.sort, ResearchSort.title);
      expect(restored.activeFacetCount, filter.activeFacetCount);
    });
  });

  // -------------------------------------------------------------------------
  // Sources, categories and tags
  // -------------------------------------------------------------------------

  group('sources, categories and tags', () {
    test('adds, updates and removes sources on the stored record', () async {
      final entry = await seed();

      final added = await service.addSource(
        entry.id,
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Harbourmaster ledger',
          location: 'https://example.invalid/ledger',
        ),
        timestamp: timestamp,
      );
      expect(added.sources, hasLength(1));
      final sourceId = added.sources.single.stableId;
      expect(sourceId, isNotEmpty);

      final edited = await service.updateSource(
        entry.id,
        added.sources.single.copyWith(notes: 'Pages 40-52.'),
        timestamp: timestamp,
      );
      expect(edited.sources.single.notes, 'Pages 40-52.');

      final removed = await service.removeSource(
        entry.id,
        sourceId,
        timestamp: timestamp,
      );
      expect(removed.sources, isEmpty);
    });

    test('rolls sources up across the library with usage counts', () async {
      const ledger = CodexSourceReference(
        id: 'source-ledger',
        recordId: '',
        kind: 'external',
        label: 'Harbourmaster ledger',
        location: 'https://example.invalid/ledger',
      );
      await seed(sources: const [ledger]);
      await seed(
        id: 'research-second',
        title: 'Second entry',
        sources: const [ledger],
      );

      final sources = await service.sources();
      expect(sources, hasLength(1));
      expect(sources.single.id, 'source-ledger');
      expect(sources.single.label, 'Harbourmaster ledger');
      expect(sources.single.usageCount, 2);
      expect(
        sources.single.itemIds,
        unorderedEquals(['research-tide', 'research-second']),
      );
    });

    test('exposes the research categories and the project tags', () async {
      await seed();
      await service.createTag(name: 'Harbour', timestamp: timestamp);

      final categoryIds =
          (await service.categories()).map((category) => category.id).toSet();
      expect(categoryIds, containsAll(['research', 'reference']));
      expect(categoryIds, isNot(contains('characters')));

      expect(
        (await service.tags()).map((tag) => tag.name),
        contains('Harbour'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Connections
  // -------------------------------------------------------------------------

  group('connections', () {
    Future<void> seedTarget(String id, String title, String templateId,
        String categoryId) async {
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.createCodexEntry(
        CodexEntryDraft(
          id: id,
          title: title,
          templateId: templateId,
          categoryId: categoryId,
        ),
        timestamp: timestamp,
      );
    }

    test('documents another record and resolves the link for display',
        () async {
      await seed();
      await seedTarget('loc-cliffs', 'Northern cliffs', 'location', 'locations');

      final link = await service.connectResearch(
        researchId: 'research-tide',
        targetId: 'loc-cliffs',
        typeId: 'documents',
        timestamp: timestamp,
      );
      expect(link.sourceId, 'research-tide');
      expect(link.targetId, 'loc-cliffs');

      final views = await service.connectionsFor('research-tide');
      expect(views, hasLength(1));
      expect(views.single.otherId, 'loc-cliffs');
      expect(views.single.otherTitle, 'Northern cliffs');
      expect(views.single.otherTypeId, 'location');
      expect(views.single.outgoing, isTrue);

      await service.disconnectResearch(link.id, timestamp: timestamp);
      expect(await service.connectionsFor('research-tide'), isEmpty);
    });

    test('offers connection types the shared registry permits', () async {
      await seed();
      await seedTarget('loc-cliffs', 'Northern cliffs', 'location', 'locations');

      final types = await service.connectionTypesFor(
        sourceTypeId: ResearchRecordTypes.entryTypeId,
        targetTypeId: 'location',
      );

      expect(types.map((type) => type.id), contains('documents'));
      expect(types.map((type) => type.id), contains('relatedTo'));
    });

    test('lists records and manuscript nodes, minus the item itself',
        () async {
      await seed();
      await seed(id: 'research-other', title: 'Another entry');
      await seedTarget('loc-cliffs', 'Northern cliffs', 'location', 'locations');
      await repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'chapter-1',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'Chapter One',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ]);

      final targets =
          await service.connectionTargets(excludeId: 'research-tide');
      final ids = targets.map((target) => target.id).toList();

      expect(ids, contains('loc-cliffs'));
      expect(ids, contains('chapter-1'));
      // Other research is connectable; the item doing the connecting is not.
      expect(ids, contains('research-other'));
      expect(ids, isNot(contains('research-tide')));

      final chapter =
          targets.firstWhere((target) => target.id == 'chapter-1');
      expect(chapter.isManuscriptNode, isTrue);
      expect(chapter.typeId, 'chapter');
    });

    test('documents a manuscript chapter through the shared engine', () async {
      await seed();
      await repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'chapter-1',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'Chapter One',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ]);

      await service.connectResearch(
        researchId: 'research-tide',
        targetId: 'chapter-1',
        typeId: 'documents',
        timestamp: timestamp,
      );

      final views = await service.connectionsFor('research-tide');
      expect(views, hasLength(1));
      expect(views.single.otherId, 'chapter-1');
      expect(views.single.otherTitle, 'Chapter One');
      expect(views.single.otherTypeId, 'chapter');
    });

    test('refuses to connect a record from another project', () async {
      await seed();
      final other = ResearchService(
        projectId: 'other-project',
        repository: repository,
      );
      await expectLater(
        other.connectResearch(
          researchId: 'research-tide',
          targetId: 'research-tide',
          typeId: 'documents',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Dashboard
  // -------------------------------------------------------------------------

  group('dashboard', () {
    test('summarises items, sources, categories, tags and open questions',
        () async {
      await seed();
      await seed(
        id: 'research-charts',
        title: 'Admiralty chart notes',
        typeId: 'reference',
        categoryId: 'reference',
        tags: const ['charts'],
        knowledgeStatus: CodexKnowledgeStatus.confirmed,
        sources: const [
          CodexSourceReference(
            id: 'source-chart',
            recordId: '',
            kind: 'external',
            label: 'Admiralty Chart 118',
          ),
        ],
      );
      await seed(id: 'research-old', title: 'Old note');
      await service.archiveResearch('research-old');

      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.createCodexEntry(
        const CodexEntryDraft(
          id: 'loc-cliffs',
          title: 'Northern cliffs',
          templateId: 'location',
          categoryId: 'locations',
        ),
        timestamp: timestamp,
      );
      await service.connectResearch(
        researchId: 'research-charts',
        targetId: 'loc-cliffs',
        typeId: 'documents',
        timestamp: timestamp,
      );

      final dashboard = await service.dashboard();

      expect(dashboard.itemCount, 2);
      expect(dashboard.archivedCount, 1);
      expect(dashboard.sourceCount, 1);
      expect(dashboard.categoryCounts.keys,
          unorderedEquals(['research', 'reference']));
      expect(dashboard.tagCounts.keys, unorderedEquals(['harbour', 'charts']));
      expect(dashboard.typeCounts.keys,
          unorderedEquals([ResearchRecordTypes.entryTypeId, 'reference']));
      expect(dashboard.unresolved.map((entry) => entry.id), ['research-tide']);
      expect(dashboard.connectedItemIds, {'research-charts'});
      expect(dashboard.recent.map((entry) => entry.id),
          containsAll(['research-tide', 'research-charts']));
    });

    test('an empty project reports an empty dashboard', () async {
      final dashboard = await service.dashboard();

      expect(dashboard.itemCount, 0);
      expect(dashboard.sourceCount, 0);
      expect(dashboard.unresolvedCount, 0);
      expect(dashboard.connectedCount, 0);
      expect(dashboard.recent, isEmpty);
    });

    test('resolution is read from the stored fields, not a written flag',
        () async {
      final entry = await seed(knowledgeStatus: CodexKnowledgeStatus.confirmed);
      expect(researchIsResolved(entry), isFalse);
      expect(researchUnresolvedReason(entry), 'Needs a source');

      final sourced = await service.addSource(
        entry.id,
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Harbourmaster ledger',
        ),
        timestamp: timestamp,
      );
      expect(researchIsResolved(sourced), isTrue);
      expect(researchUnresolvedReason(sourced), isEmpty);

      final unverified = await service.setKnowledgeStatus(
        entry.id,
        CodexKnowledgeStatus.rumoured,
        timestamp: timestamp,
      );
      expect(researchIsResolved(unverified), isFalse);
      expect(researchUnresolvedReason(unverified), 'Needs verification');
    });
  });

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  test('research survives a full reload through the real persistence layer',
      () async {
    final directory = await Directory.systemTemp.createTemp('authoros-research');
    final file = File('${directory.path}/authoros_research_test.sqlite');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    final firstService = ResearchService(
      projectId: projectId,
      repository: firstRepository,
    );

    await firstService.createResearch(
      const ResearchDraft(
        id: 'research-persisted',
        title: 'Lighthouse rotation schedule',
        summary: 'Four-hour watches, two keepers.',
        details: 'The lamp is relit at dusk from the lower gallery.',
        notes: 'Confirm the winter schedule.',
        tagIds: ['harbour'],
        knowledgeStatus: CodexKnowledgeStatus.confirmed,
        sources: [
          CodexSourceReference(
            id: 'source-keeper',
            recordId: '',
            kind: 'external',
            label: "Keeper's logbook",
            location: 'Vol. II, p. 31',
          ),
        ],
      ),
      timestamp: timestamp,
    );
    await firstDatabase.close();

    // A brand new database handle, repository and service over the same file.
    final secondDatabase = AuthorOsDatabase(NativeDatabase(file));
    final secondRepository = DriftConnectedDomainRepository(secondDatabase);
    final secondService = ResearchService(
      projectId: projectId,
      repository: secondRepository,
    );
    addTearDown(secondDatabase.close);

    final reloaded = await secondService.getResearch('research-persisted');
    expect(reloaded, isNotNull);
    expect(reloaded!.title, 'Lighthouse rotation schedule');
    expect(reloaded.summary, 'Four-hour watches, two keepers.');
    expect(reloaded.content, 'The lamp is relit at dusk from the lower gallery.');
    expect(reloaded.structuredFields['notes'], 'Confirm the winter schedule.');
    expect(reloaded.tagIds, ['harbour']);
    expect(reloaded.knowledgeStatus, CodexKnowledgeStatus.confirmed);
    expect(reloaded.sources.single.label, "Keeper's logbook");
    expect(reloaded.sources.single.location, 'Vol. II, p. 31');
    expect(researchIsResolved(reloaded), isTrue);

    expect((await secondService.listResearch()).map((entry) => entry.id),
        ['research-persisted']);
    expect((await secondService.dashboard()).itemCount, 1);
  });

  test('Research Studio adds no persistence of its own', () {
    final source = File('lib/research_service.dart').readAsStringSync();
    expect(source, contains('StoryCodexService'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('jsonEncode')));
    expect(source, isNot(contains('AuthorOsDatabase(')));
  });
}
