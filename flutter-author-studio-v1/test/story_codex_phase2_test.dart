import 'package:author_studio_v1/codex_continuity.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/continuity_actions.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story Codex Phase 2 workspace behaviour, exercised through the same
/// services the workspace UI calls.
void main() {
  const projectId = 'project-codex-2';
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexService codex;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    codex = StoryCodexService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<CodexEntry> seed({
    required String id,
    required String title,
    String templateId = 'general-lore',
    String categoryId = 'lore',
    String summary = '',
    String content = '',
    CodexCanonStatus canonStatus = CodexCanonStatus.draft,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
  }) =>
      codex.createCodexEntry(CodexEntryDraft(
        id: id,
        title: title,
        templateId: templateId,
        categoryId: categoryId,
        summary: summary,
        content: content,
        canonStatus: canonStatus,
        structuredFields: fields,
        tagIds: tags,
      ));

  group('templates and creation', () {
    test('an entry is created from an existing template and stays universal',
        () async {
      final registry = await codex.templateRegistry();
      final template = registry.resolve('faction');
      final entry = await seed(
        id: 'house-noxmere',
        title: 'House Noxmere',
        templateId: 'faction',
        categoryId: 'factions',
        summary: 'A merchant house.',
      );

      expect(entry.templateId, 'faction');
      expect(entry.record.typeId, 'faction');
      expect(entry.record.templateVersion, template.templateVersion);
      expect(entry.record.extensionData['storyCodex'], isTrue);
      expect(await codex.getCodexEntry(entry.id), isNotNull);

      final reports = await codex.templateReports([entry]);
      expect(
        reports[entry.id]!.status,
        TemplateCompatibilityStatus.current,
      );
    });

    test('unknown fields, aliases, tags, and extension data survive an edit',
        () async {
      await seed(
        id: 'ward-lore',
        title: 'Warding Lore',
        fields: {
          'legacyFieldFromOldRelease': 'keep me',
          'aliases': ['Ward Craft'],
        },
        tags: ['book-one'],
      );

      await codex.updateCodexEntry('ward-lore', summary: 'Reworked summary.');
      final entry = (await codex.getCodexEntry('ward-lore'))!;

      expect(entry.summary, 'Reworked summary.');
      expect(entry.record.fields['legacyFieldFromOldRelease'], 'keep me');
      expect(entry.aliases, contains('Ward Craft'));
      expect(entry.tagIds, contains('book-one'));
      expect(entry.record.extensionData['storyCodex'], isTrue);
    });

    test('a custom field round-trips with its author-facing label', () async {
      await seed(id: 'guild', title: 'The Glass Guild');
      await codex.setCustomField(
        'guild',
        'custom_founding_rite',
        'Founding rite',
        'Sealed in glass',
      );

      final entry = (await codex.getCodexEntry('guild'))!;
      expect(entry.record.fields['custom_founding_rite'], 'Sealed in glass');
      expect(
        (entry.metadata[CodexFields.customFieldsKey] as Map)[
            'custom_founding_rite'],
        'Founding rite',
      );
      expect(
        () => codex.setCustomField('guild', '_codex.sneaky', 'x', 'y'),
        throwsArgumentError,
      );
    });
  });

  group('search, filtering, and saved views', () {
    setUp(() async {
      await seed(
        id: 'harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor beneath the northern cliffs.',
        canonStatus: CodexCanonStatus.canon,
      );
      await seed(
        id: 'binding',
        title: 'Blood Binding',
        templateId: 'magic-rule',
        categoryId: 'magic',
        summary: 'An irreversible binding rule.',
      );
      await seed(
        id: 'retired',
        title: 'Retired Concept',
        summary: 'No longer used.',
      );
      await codex.archiveCodexEntry('retired');
    });

    test('a text query is answered by the universal search service', () async {
      final results = await codex.filterEntries(
        const CodexEntryFilter(query: 'irreversible'),
      );
      expect(results.map((entry) => entry.id), ['binding']);
    });

    test('facets narrow the list and archived entries stay hidden by default',
        () async {
      expect(
        (await codex.filterEntries(const CodexEntryFilter()))
            .map((entry) => entry.id),
        unorderedEquals(['harbor', 'binding']),
      );
      expect(
        (await codex.filterEntries(
          const CodexEntryFilter(categoryIds: {'locations'}),
        ))
            .map((entry) => entry.id),
        ['harbor'],
      );
      expect(
        (await codex.filterEntries(
          const CodexEntryFilter(canonStatuses: {CodexCanonStatus.canon}),
        ))
            .map((entry) => entry.id),
        ['harbor'],
      );
      expect(
        (await codex.filterEntries(
          const CodexEntryFilter(includeArchived: true),
        ))
            .map((entry) => entry.id),
        contains('retired'),
      );
    });

    test('title sorting is applied when requested', () async {
      final sorted = await codex.filterEntries(
        const CodexEntryFilter(sort: CodexEntrySort.title),
      );
      expect(sorted.map((entry) => entry.title), ['Blood Binding',
        'Noxmere Harbor']);
    });

    test('a saved view persists its filter as a universal record', () async {
      const filter = CodexEntryFilter(
        query: 'harbor',
        categoryIds: {'locations'},
        canonStatuses: {CodexCanonStatus.canon},
        sort: CodexEntrySort.title,
      );
      final view = await codex.saveView(name: 'Canon Places', filter: filter);

      final stored = await codex.getSavedViews();
      expect(stored.map((item) => item.name), ['Canon Places']);
      final restored = stored.single.filter;
      expect(restored.query, 'harbor');
      expect(restored.categoryIds, {'locations'});
      expect(restored.canonStatuses, {CodexCanonStatus.canon});
      expect(restored.sort, CodexEntrySort.title);

      final backing = await repository.recordById('codex-collection-${view.id}');
      expect(backing?.typeId, CodexInfrastructureTypes.collection);

      expect(
        (await codex.filterEntries(restored)).map((entry) => entry.id),
        ['harbor'],
      );

      await codex.deleteSavedView(view.id);
      expect(await codex.getSavedViews(), isEmpty);
      expect(await repository.recordById('codex-collection-${view.id}'),
          isNotNull);
    });

    test('pinned-only and needs-attention views use existing services',
        () async {
      await codex.setPinned('harbor', true);
      expect(
        (await codex.filterEntries(const CodexEntryFilter(onlyPinned: true)))
            .map((entry) => entry.id),
        ['harbor'],
      );

      final broken = await seed(id: 'broken', title: 'Broken');
      await repository.putRecord(broken.record.copyWith(
        fields: {...broken.record.fields, 'knowledgeStatus': 'Nonsense'},
        revision: broken.record.revision + 1,
      ));
      expect(
        (await codex.filterEntries(const CodexEntryFilter(onlyInvalid: true)))
            .map((entry) => entry.id),
        contains('broken'),
      );
    });
  });

  group('relationships', () {
    test('relationships are created, edited, and removed through the engine',
        () async {
      await seed(
        id: 'harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      );
      await seed(
        id: 'house',
        title: 'House Noxmere',
        templateId: 'faction',
        categoryId: 'factions',
      );

      final permitted = await codex.connectionTypesBetween(
        sourceTypeId: 'faction',
        targetTypeId: 'location',
      );
      expect(permitted.map((item) => item.id), contains('relatedTo'));

      final link = await codex.connectEntry(
        sourceId: 'house',
        targetId: 'harbor',
        typeId: 'relatedTo',
      );
      expect(link.direction, RecordLinkDirection.undirected);
      expect(link.label, 'Related to');
      expect((await codex.getCodexConnections('harbor')).single.id, link.id);

      final updated = await codex.updateEntryConnection(
        link.id,
        label: 'Anchors trade in',
      );
      expect(updated.label, 'Anchors trade in');

      await codex.disconnectEntry(link.id);
      expect(await codex.getCodexConnections('harbor'), isEmpty);
      expect(await codex.getCodexEntry('harbor'), isNotNull);
      expect(await codex.getCodexEntry('house'), isNotNull);
    });

    test('connectable records span every studio in the project', () async {
      await seed(id: 'lore', title: 'Lore');
      final now = DateTime.utc(2026, 8, 20);
      await codex.records.createRecord(AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: 'Kali',
        templateId: 'character',
        templateVersion: 1,
        fields: const {'identity.fullName': 'Kali'},
        createdAt: now,
        updatedAt: now,
      ));

      final connectable = await codex.connectableRecords();
      expect(connectable.map((record) => record.id), containsAll(['lore',
        'kali']));
      expect(
        connectable.map((record) => record.typeId),
        isNot(contains(CodexInfrastructureTypes.category)),
      );
    });
  });

  group('sources and knowledge visibility', () {
    test('sources are added, edited, removed, and preserve legacy strings',
        () async {
      await seed(
        id: 'rite',
        title: 'The Ash Rite',
        fields: {
          CodexFields.sources: ['legacy free text reference'],
        },
      );

      expect((await codex.getSources('rite')).single.label,
          'legacy free text reference');

      await codex.addSource(
        'rite',
        const CodexSourceReference(
          recordId: 'chapter-3',
          kind: 'chapter',
          label: 'Chapter 3',
          location: 'p. 88',
        ),
      );
      var sources = await codex.getSources('rite');
      expect(sources, hasLength(2));
      final added = sources.last;

      await codex.updateSource('rite', added.copyWith(notes: 'Verified.'));
      sources = await codex.getSources('rite');
      expect(sources.last.notes, 'Verified.');
      expect(sources.first.label, 'legacy free text reference');

      await codex.removeSource('rite', added.stableId);
      expect(await codex.getSources('rite'), hasLength(1));
    });

    test('knowledge status and per-field visibility persist', () async {
      await seed(id: 'secret', title: 'The Sealed Name');

      await codex.setKnowledgeStatus('secret', CodexKnowledgeStatus.secret);
      await codex.setFieldVisibility(
        'secret',
        'notes',
        CodexFieldVisibility.authorKnowledge,
      );
      await codex.setFieldVisibility(
        'secret',
        'summary',
        CodexFieldVisibility.publicKnowledge,
      );

      final entry = (await codex.getCodexEntry('secret'))!;
      expect(entry.knowledgeStatus, CodexKnowledgeStatus.secret);
      expect(entry.visibilityFor('notes'), CodexFieldVisibility.authorKnowledge);
      expect(
        entry.visibilityFor('summary'),
        CodexFieldVisibility.publicKnowledge,
      );
      expect(
        entry.visibilityFor('undeclared'),
        CodexFieldVisibility.authorKnowledge,
      );
      expect((await codex.validateEntries([entry]))[entry.id]!.isValid, isTrue);
    });
  });

  group('canon, branches, archive, and history', () {
    test('canon state changes are refused while a branch is active', () async {
      await seed(id: 'pact', title: 'The Pact');
      const branchId = 'branch-ash';
      await codex.branches.createBranch(StoryBranch(
        id: branchId,
        projectId: projectId,
        name: 'Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: DateTime.utc(2026, 8, 20),
      ));

      await expectLater(
        codex.setCanonStatus(
          'pact',
          CodexCanonStatus.canon,
          activeBranchId: branchId,
        ),
        throwsStateError,
      );
      expect(
        (await codex.getCodexEntry('pact'))!.canonStatus,
        CodexCanonStatus.draft,
      );

      await codex.setCanonStatus('pact', CodexCanonStatus.canon);
      expect(
        (await codex.getCodexEntry('pact'))!.canonStatus,
        CodexCanonStatus.canon,
      );
    });

    test('a branch edit overrides without touching the canonical record',
        () async {
      await seed(id: 'pact', title: 'The Pact', summary: 'Canon summary.');
      const branchId = 'branch-ash';
      await codex.branches.createBranch(StoryBranch(
        id: branchId,
        projectId: projectId,
        name: 'Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: DateTime.utc(2026, 8, 20),
      ));

      await codex.updateEntryInBranch(
        branchId,
        'pact',
        title: 'The Broken Pact',
        summary: 'Branch summary.',
      );

      final canonical = (await codex.getCodexEntry('pact'))!;
      expect(canonical.title, 'The Pact');
      expect(canonical.summary, 'Canon summary.');

      final branchEntry = (await codex.listByBranch(branchId))
          .firstWhere((entry) => entry.id == 'pact');
      expect(branchEntry.title, 'The Broken Pact');
      expect(branchEntry.summary, 'Branch summary.');

      await expectLater(
        codex.updateEntryInBranch(
          branchId,
          'pact',
          canonStatus: CodexCanonStatus.canon,
        ),
        throwsStateError,
      );
    });

    test('archive and restore are reversible and keep connections', () async {
      await seed(id: 'harbor', title: 'Harbor', templateId: 'location',
          categoryId: 'locations');
      await seed(id: 'house', title: 'House', templateId: 'faction',
          categoryId: 'factions');
      await codex.connectEntry(
        sourceId: 'house',
        targetId: 'harbor',
        typeId: 'relatedTo',
      );

      final analysis = await codex.analyzeDelete('harbor');
      expect(analysis, isNotNull);
      expect(analysis!.incomingConnections.length +
          analysis.outgoingConnections.length, greaterThan(0));

      await codex.archiveCodexEntry('harbor');
      expect((await codex.getCodexEntry('harbor'))!.isArchived, isTrue);
      expect(await codex.getCodexConnections('harbor'), hasLength(1));

      await codex.restoreCodexEntry('harbor');
      expect((await codex.getCodexEntry('harbor'))!.isArchived, isFalse);
      expect(await codex.getCodexConnections('harbor'), hasLength(1));
    });

    test('inspector and history read through the existing services', () async {
      await seed(id: 'harbor', title: 'Harbor');
      await codex.updateCodexEntry('harbor', summary: 'Rewritten.');

      final inspection = await codex.inspectEntry('harbor');
      expect(inspection?.recordId, 'harbor');
      expect(inspection?.template.id, 'general-lore');

      final history = await codex.getHistory('harbor');
      expect(history.length, greaterThanOrEqualTo(2));

      final first = history.first;
      await codex.records.restoreVersion(first.id);
      expect((await codex.getCodexEntry('harbor'))!.summary, isEmpty);
    });
  });

  group('validation', () {
    test('missing required values are reported per entry', () async {
      final entry = await seed(id: 'lore', title: 'Lore');
      final results = await codex.validateEntries([entry]);
      expect(results[entry.id]!.isValid, isTrue);

      final broken = CodexEntry(entry.record.copyWith(title: ''));
      final rechecked = await codex.validateEntries([broken]);
      expect(rechecked['lore']!.isValid, isFalse);
      expect(
        rechecked['lore']!.errors.map((issue) => issue.code),
        contains('missing-title'),
      );
    });

    test('a stored value that no longer matches its template is invalid',
        () async {
      final entry = await seed(id: 'lore', title: 'Lore');
      await repository.putRecord(entry.record.copyWith(
        fields: {...entry.record.fields, 'knowledgeStatus': 'Nonsense'},
        revision: entry.record.revision + 1,
      ));
      final stored = (await codex.getCodexEntry('lore'))!;
      final results = await codex.validateEntries([stored]);
      expect(results['lore']!.isValid, isFalse);
      expect(
        results['lore']!.errors.map((issue) => issue.fieldId),
        contains('knowledgeStatus'),
      );
    });
  });

  group('continuity intelligence', () {
    test('an unlinked mention becomes a resolvable link recommendation',
        () async {
      await seed(
        id: 'harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      );
      final house = await seed(
        id: 'house',
        title: 'House Noxmere',
        templateId: 'faction',
        categoryId: 'factions',
        content: 'The house keeps hidden routes through Noxmere Harbor.',
      );

      Future<CodexContinuityReport> analyze() async {
        final entry = (await codex.getCodexEntry(house.id))!;
        return const CodexContinuityIntelligence().analyze(
          entry: entry,
          entries: await codex.getEntries(),
          links: await codex.getCodexConnections(entry.id),
          knownNames: CodexContinuityIntelligence.knownNames(
            await codex.connectableRecords(),
          ),
        );
      }

      final report = await analyze();
      expect(report.findings, hasLength(1));
      final finding = report.findings.single;
      expect(finding.actionKind, ContinuityActionKind.link);
      expect(finding.targetId, 'harbor');
      final issue = report.summary.issues.single;
      expect(issue.recommendation, isNotEmpty);
      expect(report.findingFor(issue), same(finding));

      final service = ContinuityActionService(
        projectId: projectId,
        repository: repository,
      );
      final result = await service.linkForRecommendation(
        issue,
        sourceId: finding.entryId,
        targetId: finding.targetId!,
        typeId: finding.connectionTypeId,
        direction: RecordLinkDirection.undirected,
        confirmed: true,
        recheck: () async => (await analyze()).findings.isNotEmpty,
      );

      expect(result.status, ContinuityActionStatus.resolved);
      expect(await codex.getCodexConnections('house'), hasLength(1));
      expect((await analyze()).isClean, isTrue);
    });

    test('a roster name with no record becomes a create recommendation',
        () async {
      final entry = await seed(
        id: 'guild',
        title: 'The Glass Guild',
        templateId: 'faction',
        categoryId: 'factions',
        fields: {
          'importantPeople': ['Serrin Vale'],
        },
      );

      final report = const CodexContinuityIntelligence().analyze(
        entry: entry,
        entries: await codex.getEntries(),
        links: const [],
        knownNames: CodexContinuityIntelligence.knownNames(
          await codex.connectableRecords(),
        ),
      );

      expect(report.findings, hasLength(1));
      expect(report.findings.single.actionKind, ContinuityActionKind.create);
      expect(report.findings.single.missingName, 'Serrin Vale');
      expect(report.summary.issues.single.severity, ContinuitySeverity.warning);
      expect(report.summary.score, lessThan(100));
    });

    test('a name owned by another studio is never reported as missing',
        () async {
      final now = DateTime.utc(2026, 8, 20);
      await codex.records.createRecord(AuthorRecord(
        id: 'serrin',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: 'Serrin Vale',
        templateId: 'character',
        templateVersion: 1,
        fields: const {'identity.fullName': 'Serrin Vale'},
        createdAt: now,
        updatedAt: now,
      ));
      final entry = await seed(
        id: 'guild',
        title: 'The Glass Guild',
        templateId: 'faction',
        categoryId: 'factions',
        fields: {
          'importantPeople': ['Serrin Vale'],
        },
      );

      final report = const CodexContinuityIntelligence().analyze(
        entry: entry,
        entries: await codex.getEntries(),
        links: const [],
        knownNames: CodexContinuityIntelligence.knownNames(
          await codex.connectableRecords(),
        ),
      );
      expect(
        report.findings
            .where((finding) =>
                finding.warning.type == ContinuityWarningType.unknownCharacter),
        isEmpty,
      );
    });
  });
}
