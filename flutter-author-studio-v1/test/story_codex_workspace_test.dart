import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/story_codex_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const projectId = 'project-codex';
final timestamp = DateTime.utc(2026, 4, 2, 10);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexService service;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    service = StoryCodexService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  // -------------------------------------------------------------------------
  // Service surface used by the workspace
  // -------------------------------------------------------------------------

  group('Codex workspace service surface', () {
    test('filters by category, canon, knowledge, tag and archived state',
        () async {
      final harbor = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor.',
        canonStatus: CodexCanonStatus.canon,
      ));
      final rule = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-rule',
        title: 'Blood Binding',
        templateId: 'magic-rule',
        categoryId: 'magic',
      ));
      await service.setKnowledgeStatus(
        rule.id,
        CodexKnowledgeStatus.secret,
      );
      final archived = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-archived',
        title: 'Retired Lore',
        templateId: 'general-lore',
        categoryId: 'lore',
      ));
      await service.archiveCodexEntry(archived.id);

      Future<List<String>> ids(CodexEntryFilter filter) async =>
          (await service.filterEntries(filter))
              .map((entry) => entry.id)
              .toList();

      expect(
        await ids(CodexEntryFilter.empty),
        unorderedEquals([harbor.id, rule.id]),
      );
      expect(
        await ids(const CodexEntryFilter(includeArchived: true)),
        containsAll([harbor.id, rule.id, archived.id]),
      );
      expect(
        await ids(const CodexEntryFilter(categoryIds: {'magic'})),
        [rule.id],
      );
      expect(
        await ids(const CodexEntryFilter(
          canonStatuses: {CodexCanonStatus.canon},
        )),
        [harbor.id],
      );
      expect(
        await ids(const CodexEntryFilter(
          knowledgeStatuses: {CodexKnowledgeStatus.secret},
        )),
        [rule.id],
      );
      expect(
        await ids(const CodexEntryFilter(templateIds: {'location'})),
        [harbor.id],
      );
      expect(
        await ids(const CodexEntryFilter(sort: CodexEntrySort.title)),
        [rule.id, harbor.id],
      );
    });

    test('text queries are answered by UniversalSearchService', () async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'Smugglers move salt beneath the cliffs.',
      ));
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-rule',
        title: 'Blood Binding',
        templateId: 'magic-rule',
        categoryId: 'magic',
      ));

      final matches =
          await service.filterEntries(const CodexEntryFilter(query: 'salt'));
      expect(matches.map((entry) => entry.id), ['codex-harbor']);

      final none = await service
          .filterEntries(const CodexEntryFilter(query: 'zzzznothing'));
      expect(none, isEmpty);
    });

    test('needs-attention filter surfaces invalid records', () async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-valid',
        title: 'Valid Lore',
        templateId: 'general-lore',
        categoryId: 'lore',
      ));
      await _putInvalidCharacter(repository);

      final flagged = await service
          .filterEntries(const CodexEntryFilter(onlyInvalid: true));
      expect(flagged.map((entry) => entry.id), ['codex-invalid']);
    });

    test('saved views round-trip as universal records', () async {
      const filter = CodexEntryFilter(
        query: 'salt',
        categoryIds: {'locations'},
        canonStatuses: {CodexCanonStatus.canon},
        includeArchived: true,
        sort: CodexEntrySort.title,
      );
      final view = await service.saveView(name: 'Harbor watch', filter: filter);

      final loaded = await service.getSavedViews();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Harbor watch');
      expect(loaded.single.filter.query, 'salt');
      expect(loaded.single.filter.categoryIds, {'locations'});
      expect(loaded.single.filter.canonStatuses, {CodexCanonStatus.canon});
      expect(loaded.single.filter.includeArchived, isTrue);
      expect(loaded.single.filter.sort, CodexEntrySort.title);

      // Saving again under the same name updates in place.
      await service.saveView(
        name: 'Harbor watch',
        filter: const CodexEntryFilter(query: 'quay'),
        id: view.id,
      );
      expect((await service.getSavedViews()).single.filter.query, 'quay');

      await service.deleteSavedView(view.id);
      expect(await service.getSavedViews(), isEmpty);
      // Pinned collections are untouched by saved-view management.
      expect(
        (await service.getCollections())
            .where((item) => item.kind == CodexCollectionKind.pinned),
        hasLength(1),
      );
    });

    test('sources are added, edited, removed and kept as stable ids', () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await service.addSource(
        entry.id,
        const CodexSourceReference(
          recordId: '',
          kind: 'chapter',
          label: 'Chapter 3',
          location: 'p. 41',
        ),
        timestamp: timestamp,
      );
      var sources = await service.getSources(entry.id);
      expect(sources, hasLength(1));
      final sourceId = sources.single.stableId;
      expect(sourceId, isNotEmpty);

      await service.updateSource(
        entry.id,
        sources.single.copyWith(notes: 'Salt route revealed'),
      );
      sources = await service.getSources(entry.id);
      expect(sources.single.notes, 'Salt route revealed');
      expect(sources.single.stableId, sourceId);

      await service.removeSource(entry.id, sourceId);
      expect(await service.getSources(entry.id), isEmpty);
    });

    test('legacy string source values survive a round trip', () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        structuredFields: {
          'sourceReferences': ['A note written by an earlier release'],
        },
      ));
      final sources = await service.getSources(entry.id);
      expect(sources.single.label, 'A note written by an earlier release');

      await service.addSource(
        entry.id,
        const CodexSourceReference(
          recordId: '',
          kind: 'research',
          label: 'Field notes',
        ),
      );
      final updated = await service.getSources(entry.id);
      expect(updated.map((source) => source.label),
          containsAll(['A note written by an earlier release', 'Field notes']));
    });

    test('visibility, aliases and custom fields preserve unknown data',
        () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        structuredFields: {'legacyNote': 'written by an older release'},
        metadata: {'importedFrom': 'legacy-codex'},
      ));

      await service.setAliases(entry.id, ['The Salt Gate', ' Noxmere ']);
      await service.setFieldVisibility(
        entry.id,
        'secrets',
        CodexFieldVisibility.authorKnowledge,
      );
      await service.setFieldVisibility(
        entry.id,
        'geography',
        CodexFieldVisibility.publicKnowledge,
      );
      await service.setCustomField(
        entry.id,
        'custom.tide-table',
        'Tide table',
        'Spring tides flood the lower quay.',
      );

      final reloaded = (await service.getCodexEntry(entry.id))!;
      expect(reloaded.aliases, ['The Salt Gate', 'Noxmere']);
      expect(
        reloaded.visibilityFor('geography'),
        CodexFieldVisibility.publicKnowledge,
      );
      expect(
        reloaded.visibilityFor('secrets'),
        CodexFieldVisibility.authorKnowledge,
      );
      expect(
        reloaded.visibilityFor('undeclared'),
        CodexFieldVisibility.authorKnowledge,
      );
      expect(reloaded.structuredFields['custom.tide-table'],
          'Spring tides flood the lower quay.');
      expect(reloaded.metadata[CodexFields.customFieldsKey],
          containsPair('custom.tide-table', 'Tide table'));
      // Nothing written by an earlier release was lost along the way.
      expect(reloaded.structuredFields['legacyNote'],
          'written by an older release');
      expect(reloaded.metadata['importedFrom'], 'legacy-codex');
      expect(reloaded.record.extensionData['storyCodex'], isTrue);
      expect(reloaded.record.templateId, 'location');
    });

    test('custom fields refuse reserved keys', () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await expectLater(
        service.setCustomField(entry.id, '_codex.summary', 'Nope', 'x'),
        throwsArgumentError,
      );
      await expectLater(
        service.setCustomField(entry.id, '   ', 'Nope', 'x'),
        throwsArgumentError,
      );
    });

    test('relationships use ConnectionEngine and stay reversible', () async {
      final harbor = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      final guild = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-guild',
        title: 'Saltwrights Guild',
        templateId: 'faction',
        categoryId: 'factions',
      ));

      final types = await service.connectionTypesBetween(
        sourceTypeId: 'faction',
        targetTypeId: 'location',
      );
      expect(types.map((type) => type.id), contains('relatedTo'));

      final undirected = await service.connectEntry(
        sourceId: guild.id,
        targetId: harbor.id,
        typeId: 'relatedTo',
      );
      expect(undirected.direction, RecordLinkDirection.undirected);
      await service.disconnectEntry(undirected.id);

      final link = await service.connectEntry(
        sourceId: guild.id,
        targetId: harbor.id,
        typeId: 'locatedIn',
      );
      expect(link.direction, RecordLinkDirection.directed);
      expect(link.label, 'Located in');
      expect(await service.getCodexConnections(harbor.id), hasLength(1));

      final updated =
          await service.updateEntryConnection(link.id, typeId: 'controls');
      expect(updated.typeId, 'controls');
      // A retype cannot flip the stored direction.
      await expectLater(
        service.updateEntryConnection(link.id, typeId: 'relatedTo'),
        throwsA(isA<StateError>()),
      );

      await service.disconnectEntry(link.id);
      expect(await service.getCodexConnections(harbor.id), isEmpty);
      // Both endpoints survive the disconnect.
      expect(await service.getCodexEntry(harbor.id), isNotNull);
      expect(await service.getCodexEntry(guild.id), isNotNull);
    });

    test('canon cannot be mutated from an active branch', () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await service.branches.createBranch(StoryBranch(
        id: 'branch-ash',
        projectId: projectId,
        name: 'The Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: timestamp,
      ));

      await expectLater(
        service.setCanonStatus(
          entry.id,
          CodexCanonStatus.canon,
          activeBranchId: 'branch-ash',
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.updateEntryInBranch(
          'branch-ash',
          entry.id,
          canonStatus: CodexCanonStatus.canon,
        ),
        throwsA(isA<StateError>()),
      );

      // Canon itself is still editable when no branch is active.
      final promoted =
          await service.setCanonStatus(entry.id, CodexCanonStatus.canon);
      expect(promoted.canonStatus, CodexCanonStatus.canon);
    });

    test('branch edits overlay canon instead of replacing it', () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor.',
        canonStatus: CodexCanonStatus.canon,
      ));
      await service.branches.createBranch(StoryBranch(
        id: 'branch-ash',
        projectId: projectId,
        name: 'The Ash Victory',
        createdAt: timestamp,
      ));

      await service.updateEntryInBranch(
        'branch-ash',
        entry.id,
        title: 'Ashen Harbor',
        summary: 'Burned to the waterline.',
        canonStatus: CodexCanonStatus.alternate,
      );

      final branchEntries = await service.listByBranch('branch-ash');
      final branchEntry =
          branchEntries.firstWhere((item) => item.id == entry.id);
      expect(branchEntry.title, 'Ashen Harbor');
      expect(branchEntry.summary, 'Burned to the waterline.');

      final canonical = (await service.getCodexEntry(entry.id))!;
      expect(canonical.title, 'Noxmere Harbor');
      expect(canonical.summary, 'A cold harbor.');
      expect(canonical.canonStatus, CodexCanonStatus.canon);
    });

    test('branch-created entries are branch scoped and never canon', () async {
      await service.branches.createBranch(StoryBranch(
        id: 'branch-ash',
        projectId: projectId,
        name: 'The Ash Victory',
        createdAt: timestamp,
      ));
      final created = await service.createCodexEntryInBranch(
        'branch-ash',
        const CodexEntryDraft(
          id: 'codex-relic',
          title: 'The Unbroken Crown',
          templateId: 'item',
          categoryId: 'items',
          canonStatus: CodexCanonStatus.alternate,
        ),
      );

      expect(created.record.scopeType, RecordScopeType.branch);
      expect(created.record.branchId, 'branch-ash');
      expect(
        (await service.listByBranch('branch-ash')).map((entry) => entry.id),
        contains('codex-relic'),
      );
      expect(await service.getCodexEntry('codex-relic'), isNull);

      await expectLater(
        service.createCodexEntryInBranch(
          'branch-ash',
          const CodexEntryDraft(
            id: 'codex-canon-attempt',
            title: 'Canon Attempt',
            templateId: 'item',
            categoryId: 'items',
            canonStatus: CodexCanonStatus.canon,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('inspector, history and safe delete come from the shared services',
        () async {
      final entry = await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await service.updateCodexEntry(entry.id, summary: 'Updated once.');

      final inspection = await service.inspectEntry(entry.id);
      expect(inspection?.recordType, 'location');
      expect(inspection?.validation.state, InspectionValidationState.valid);
      expect(inspection?.template.id, 'location');

      final history = await service.getHistory(entry.id);
      expect(history.length, greaterThanOrEqualTo(2));
      expect(history.first.recordId, entry.id);

      await service.archiveCodexEntry(entry.id);
      expect((await service.getCodexEntry(entry.id))?.isArchived, isTrue);
      await service.restoreCodexEntry(entry.id);
      expect((await service.getCodexEntry(entry.id))?.isArchived, isFalse);
      expect(
        (await service.getHistory(entry.id)).length,
        greaterThanOrEqualTo(4),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Workspace UI
  // -------------------------------------------------------------------------

  group('Story Codex workspace', () {
    testWidgets('shows an empty state and creates an entry from a template',
        (tester) async {
      await _pump(tester, repository);

      expect(find.byKey(const Key('story-codex-workspace')), findsOneWidget);
      expect(find.byKey(const Key('codex-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('codex-detail-empty-state')), findsOneWidget);

      await _tap(tester, const Key('codex-new-entry-button'));
      expect(find.byKey(const Key('codex-create-dialog')), findsOneWidget);

      _choose<String>(tester, const Key('codex-create-template-field'),
          'location');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('codex-create-title-field')),
        'Noxmere Harbor',
      );
      await tester.enterText(
        find.byKey(const Key('codex-create-summary-field')),
        'A cold harbor beneath the northern cliffs.',
      );
      await tester.tap(find.byKey(const Key('codex-create-confirm')));
      await tester.pumpAndSettle();

      final stored = await service.getEntries();
      expect(stored, hasLength(1));
      expect(stored.single.recordType, 'location');
      expect(stored.single.categoryId, 'locations');
      expect(stored.single.record.templateId, 'location');
      expect(stored.single.record.templateVersion, isNotNull);
      expect(find.byKey(Key('codex-entry-tile-${stored.single.id}')),
          findsOneWidget);
      expect(find.byKey(const Key('codex-entry-pane')), findsOneWidget);
      expect(find.text('Noxmere Harbor'), findsWidgets);
    });

    testWidgets('a missing required field blocks creation and explains why',
        (tester) async {
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-new-entry-button'));
      _choose<String>(
          tester, const Key('codex-create-template-field'), 'character');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('codex-create-title-field')),
        'Kalis Ardent',
      );
      await tester.tap(find.byKey(const Key('codex-create-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('codex-create-error')), findsOneWidget);
      expect(await service.getEntries(), isEmpty);

      await tester.enterText(
        find.byKey(const Key('codex-create-field-identity.fullName')),
        'Kalis Ardent',
      );
      await tester.tap(find.byKey(const Key('codex-create-confirm')));
      await tester.pumpAndSettle();
      expect(await service.getEntries(), hasLength(1));
    });

    testWidgets('filters narrow the list and save into a reusable view',
        (tester) async {
      await _seed(service);
      await _pump(tester, repository);

      expect(find.byKey(const Key('codex-entry-tile-codex-harbor')),
          findsOneWidget);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-rule')), findsOneWidget);

      await _tap(tester, const Key('codex-category-filter-magic'));
      expect(
          find.byKey(const Key('codex-entry-tile-codex-rule')), findsOneWidget);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-harbor')), findsNothing);

      await _tap(tester, const Key('codex-save-view-button'));
      await tester.enterText(
        find.byKey(const Key('codex-save-view-name-field')),
        'Magic only',
      );
      await tester.tap(find.byKey(const Key('codex-save-view-confirm')));
      await tester.pumpAndSettle();

      final views = await service.getSavedViews();
      expect(views, hasLength(1));
      expect(views.single.name, 'Magic only');
      expect(views.single.filter.categoryIds, {'magic'});

      await _tap(tester, const Key('codex-clear-filters-button'));
      expect(find.byKey(const Key('codex-entry-tile-codex-harbor')),
          findsOneWidget);

      await _tap(tester, Key('codex-saved-view-${views.single.id}'));
      expect(
          find.byKey(const Key('codex-entry-tile-codex-harbor')), findsNothing);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-rule')), findsOneWidget);
    });

    testWidgets('search shows results and an explained no-results state',
        (tester) async {
      await _seed(service);
      await _pump(tester, repository);

      await tester.enterText(
        find.byKey(const Key('codex-search-field')),
        'smugglers',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codex-entry-tile-codex-harbor')),
          findsOneWidget);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-rule')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('codex-search-field')),
        'zzzznothing',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codex-no-results-state')), findsOneWidget);
    });

    testWidgets('simple edits save and preserve unknown and extension data',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor.',
        structuredFields: {'legacyNote': 'written by an older release'},
        metadata: {'importedFrom': 'legacy-codex'},
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));

      await tester.enterText(
        find.byKey(const Key('codex-summary-input')),
        'Smugglers move salt beneath the cliffs.',
      );
      await tester.enterText(
        find.byKey(const Key('codex-aliases-input')),
        'The Salt Gate, Noxmere',
      );
      await tester.enterText(
        find.byKey(const Key('codex-tags-input')),
        'Book One, Important',
      );
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsWidgets);

      await _tap(tester, const Key('codex-save-entry-button'));

      final saved = (await service.getCodexEntry('codex-harbor'))!;
      expect(saved.summary, 'Smugglers move salt beneath the cliffs.');
      expect(saved.aliases, ['The Salt Gate', 'Noxmere']);
      expect(saved.tagIds, containsAll(['book-one', 'important']));
      expect(saved.structuredFields['legacyNote'],
          'written by an older release');
      expect(saved.metadata['importedFrom'], 'legacy-codex');
      expect(saved.record.extensionData['storyCodex'], isTrue);
      expect(saved.record.templateId, 'location');
      expect(find.text('Saved Noxmere Harbor'), findsWidgets);
    });

    testWidgets('deep mode edits template fields and keeps unknown fields',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        structuredFields: {'legacyNote': 'written by an older release'},
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-fields'));

      // Simple mode hides the long-form worldbuilding fields.
      expect(find.byKey(const Key('codex-field-geography')), findsNothing);

      _select<CodexEditorMode>(
        tester,
        const Key('codex-editor-mode-selector'),
        {CodexEditorMode.deep},
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('codex-field-geography')), findsOneWidget);
      expect(find.byKey(const Key('codex-field-legacyNote')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('codex-field-geography')),
        'Black cliffs enclose a deep-water bay.',
      );
      await tester.enterText(
        find.byKey(const Key('codex-field-alternateNames')),
        'Grey Quay, Salt Reach',
      );
      await tester.pumpAndSettle();
      await _tap(tester, const Key('codex-save-entry-button'));

      final saved = (await service.getCodexEntry('codex-harbor'))!;
      expect(saved.structuredFields['geography'],
          'Black cliffs enclose a deep-water bay.');
      expect(saved.structuredFields['alternateNames'],
          ['Grey Quay', 'Salt Reach']);
      expect(saved.structuredFields['legacyNote'],
          'written by an older release');
    });

    testWidgets('relationships can be created, retyped, opened and removed',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await _putCharacter(repository, 'character-kalis', 'Kalis Ardent');

      final navigations = <CodexNavigationRequest>[];
      await _pump(tester, repository, navigations: navigations);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-relationships'));
      expect(find.byKey(const Key('codex-relationships-empty-state')),
          findsOneWidget);

      await _tap(tester, const Key('codex-add-relationship-button'));
      _choose<String>(tester, const Key('codex-relationship-target-field'),
          'character-kalis');
      await tester.pumpAndSettle();
      _choose<String>(
          tester, const Key('codex-relationship-type-field'), 'relatedTo');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('codex-relationship-confirm')));
      await tester.pumpAndSettle();

      final links = await service.getCodexConnections('codex-harbor');
      expect(links, hasLength(1));
      final linkId = links.single.id;
      expect(find.byKey(Key('codex-relationship-$linkId')), findsOneWidget);
      expect(find.text('Kalis Ardent'), findsWidgets);

      await _tap(tester, Key('codex-open-relationship-$linkId'));
      expect(navigations, hasLength(1));
      expect(navigations.single.recordId, 'character-kalis');
      expect(navigations.single.destination.name, 'characterStudio');

      await _tap(tester, Key('codex-remove-relationship-$linkId'));
      await tester.tap(find.byKey(const Key('codex-confirm-button')));
      await tester.pumpAndSettle();
      expect(await service.getCodexConnections('codex-harbor'), isEmpty);
      expect(await repository.recordById('character-kalis'), isNotNull);
    });

    testWidgets('sources are added, edited and removed from the workspace',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-sources'));
      expect(
          find.byKey(const Key('codex-sources-empty-state')), findsOneWidget);

      await _tap(tester, const Key('codex-add-source-button'));
      _choose<String>(tester, const Key('codex-source-kind-field'), 'chapter');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('codex-source-label-field')),
        'Chapter 3',
      );
      await tester.enterText(
        find.byKey(const Key('codex-source-location-field')),
        'p. 41',
      );
      await tester.tap(find.byKey(const Key('codex-source-confirm')));
      await tester.pumpAndSettle();

      var sources = await service.getSources('codex-harbor');
      expect(sources, hasLength(1));
      expect(sources.single.kind, 'chapter');
      final sourceId = sources.single.stableId;

      await _tap(tester, Key('codex-edit-source-$sourceId'));
      await tester.enterText(
        find.byKey(const Key('codex-source-notes-field')),
        'Confirms the salt route.',
      );
      await tester.tap(find.byKey(const Key('codex-source-confirm')));
      await tester.pumpAndSettle();
      sources = await service.getSources('codex-harbor');
      expect(sources.single.notes, 'Confirms the salt route.');
      expect(sources.single.stableId, sourceId);

      await _tap(tester, Key('codex-remove-source-$sourceId'));
      await tester.tap(find.byKey(const Key('codex-confirm-button')));
      await tester.pumpAndSettle();
      expect(await service.getSources('codex-harbor'), isEmpty);
    });

    testWidgets('canon state is editable on canon and locked on a branch',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor.',
      ));
      await service.branches.createBranch(StoryBranch(
        id: 'branch-ash',
        projectId: projectId,
        name: 'The Ash Victory',
        createdAt: timestamp,
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));

      _choose<CodexCanonStatus>(
        tester,
        const Key('codex-canon-status-field'),
        CodexCanonStatus.canon,
      );
      await tester.pumpAndSettle();
      expect((await service.getCodexEntry('codex-harbor'))?.canonStatus,
          CodexCanonStatus.canon);

      _choose<String>(tester, const Key('codex-branch-selector'), 'branch-ash');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codex-branch-banner')), findsOneWidget);

      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      final canonField =
          tester.widget<DropdownButtonFormField<CodexCanonStatus>>(
        find.byKey(const Key('codex-canon-status-field')),
      );
      expect(canonField.onChanged, isNull);

      await tester.enterText(
        find.byKey(const Key('codex-summary-input')),
        'Burned to the waterline.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, const Key('codex-save-entry-button'));

      final branchEntries = await service.listByBranch('branch-ash');
      expect(
        branchEntries.firstWhere((entry) => entry.id == 'codex-harbor').summary,
        'Burned to the waterline.',
      );
      final canonical = (await service.getCodexEntry('codex-harbor'))!;
      expect(canonical.summary, 'A cold harbor.');
      expect(canonical.canonStatus, CodexCanonStatus.canon);
    });

    testWidgets('the inspector and history panels read the shared services',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await service.updateCodexEntry('codex-harbor', summary: 'Updated once.');
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));

      await _tap(tester, const Key('codex-tab-inspector'));
      expect(find.byKey(const Key('codex-inspector-panel')), findsOneWidget);
      expect(find.text('Universal Record Inspector'), findsOneWidget);
      expect(find.text('location'), findsWidgets);

      await _tap(tester, const Key('codex-tab-history'));
      expect(find.byKey(const Key('codex-history-panel')), findsOneWidget);
      final versions = await service.getHistory('codex-harbor');
      expect(versions, isNotEmpty);
      expect(find.byKey(Key('codex-history-${versions.first.id}')),
          findsOneWidget);
    });

    testWidgets('archiving asks first and restoring brings the entry back',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));

      await _tap(tester, const Key('codex-entry-actions'));
      await tester.tap(find.text('Archive entry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codex-archive-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('codex-archive-confirm')));
      await tester.pumpAndSettle();

      expect((await service.getCodexEntry('codex-harbor'))?.isArchived, isTrue);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-harbor')), findsNothing);
      expect(find.byKey(const Key('codex-archived-chip')), findsOneWidget);

      await _tap(tester, const Key('codex-entry-actions'));
      await tester.tap(find.text('Restore entry'));
      await tester.pumpAndSettle();
      expect(
          (await service.getCodexEntry('codex-harbor'))?.isArchived, isFalse);
      expect(find.byKey(const Key('codex-entry-tile-codex-harbor')),
          findsOneWidget);
    });

    testWidgets('validation problems are flagged in the list and the pane',
        (tester) async {
      await _putInvalidCharacter(repository);
      await _pump(tester, repository);

      expect(find.byKey(const Key('codex-validation-badge-codex-invalid')),
          findsOneWidget);

      await _tap(tester, const Key('codex-entry-tile-codex-invalid'));
      expect(find.byKey(const Key('codex-validation-panel')), findsOneWidget);
      expect(find.textContaining('Full name is required.'), findsWidgets);
    });

    testWidgets('continuity recommendations are shown and resolvable',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-guild',
        title: 'Widow Network',
        templateId: 'faction',
        categoryId: 'factions',
      ));
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        content: 'The Widow Network smuggles salt through the harbor.',
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-continuity'));

      expect(find.byKey(const Key('codex-continuity-panel')), findsOneWidget);
      expect(find.textContaining('Unlinked mention of Widow Network'),
          findsOneWidget);

      await _tap(tester, const Key('codex-continuity-resolve-0'));
      await tester.tap(find.byKey(const Key('codex-confirm-button')));
      await tester.pumpAndSettle();

      final links = await service.getCodexConnections('codex-harbor');
      expect(links, hasLength(1));
      expect(links.single.typeId, 'relatedTo');
      expect(
        links.single.sourceId == 'codex-guild' ||
            links.single.targetId == 'codex-guild',
        isTrue,
      );
    });

    testWidgets('a relationship can be retyped from the workspace',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-guild',
        title: 'Saltwrights Guild',
        templateId: 'faction',
        categoryId: 'factions',
      ));
      final link = await service.connectEntry(
        sourceId: 'codex-guild',
        targetId: 'codex-harbor',
        typeId: 'locatedIn',
      );

      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-guild'));
      await _tap(tester, const Key('codex-tab-relationships'));
      await _tap(tester, Key('codex-edit-relationship-${link.id}'));

      _choose<String>(
        tester,
        const Key('codex-relationship-edit-type-field'),
        'controls',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('codex-relationship-type-confirm')));
      await tester.pumpAndSettle();

      final links = await service.getCodexConnections('codex-guild');
      expect(links.single.typeId, 'controls');
    });

    testWidgets('custom fields and knowledge visibility are set in deep mode',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
      ));
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-fields'));
      _select<CodexEditorMode>(
        tester,
        const Key('codex-editor-mode-selector'),
        {CodexEditorMode.deep},
      );
      await tester.pumpAndSettle();

      await _tap(tester, const Key('codex-add-custom-field-button'));
      await tester.enterText(
        find.byKey(const Key('codex-custom-field-label')),
        'Tide table',
      );
      await tester.tap(find.byKey(const Key('codex-custom-field-confirm')));
      await tester.pumpAndSettle();

      var saved = (await service.getCodexEntry('codex-harbor'))!;
      expect(
        saved.metadata[CodexFields.customFieldsKey],
        containsPair('custom.tide-table', 'Tide table'),
      );
      expect(find.byKey(const Key('codex-field-custom.tide-table')),
          findsOneWidget);

      await _tap(tester, const Key('codex-visibility-geography'));
      await tester.tap(find.text('Public knowledge').last);
      await tester.pumpAndSettle();

      saved = (await service.getCodexEntry('codex-harbor'))!;
      expect(
        saved.visibilityFor('geography'),
        CodexFieldVisibility.publicKnowledge,
      );
    });

    testWidgets('a previous version can be restored from history',
        (tester) async {
      await service.createCodexEntry(const CodexEntryDraft(
        id: 'codex-harbor',
        title: 'Noxmere Harbor',
        templateId: 'location',
        categoryId: 'locations',
        summary: 'A cold harbor.',
      ));
      await service.updateCodexEntry(
        'codex-harbor',
        summary: 'Rewritten by mistake.',
      );

      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-harbor'));
      await _tap(tester, const Key('codex-tab-history'));

      final versions = await service.getHistory('codex-harbor');
      expect(versions.length, greaterThanOrEqualTo(2));
      await _tap(tester, Key('codex-restore-version-${versions.first.id}'));
      await tester.tap(find.byKey(const Key('codex-confirm-button')));
      await tester.pumpAndSettle();

      expect((await service.getCodexEntry('codex-harbor'))?.summary,
          'A cold harbor.');
      // Restoring appends history rather than rewriting it.
      expect((await service.getHistory('codex-harbor')).length,
          greaterThan(versions.length));
    });

    testWidgets('pinning an entry drives the pinned-only view', (tester) async {
      await _seed(service);
      await _pump(tester, repository);
      await _tap(tester, const Key('codex-entry-tile-codex-rule'));
      await _tap(tester, const Key('codex-pin-button'));

      expect(
        (await service.getPinnedEntries()).map((entry) => entry.id),
        ['codex-rule'],
      );

      await _tap(tester, const Key('codex-pinned-toggle'));
      expect(
          find.byKey(const Key('codex-entry-tile-codex-rule')), findsOneWidget);
      expect(
          find.byKey(const Key('codex-entry-tile-codex-harbor')), findsNothing);
    });

    testWidgets('the workspace lays out on a narrow browser window',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _seed(service);
      await _pumpWidget(tester, repository);

      expect(find.byKey(const Key('story-codex-workspace')), findsOneWidget);
      expect(find.byKey(const Key('codex-search-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester,
  DriftConnectedDomainRepository repository, {
  List<CodexNavigationRequest>? navigations,
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await _pumpWidget(tester, repository, navigations: navigations);
}

Future<void> _pumpWidget(
  WidgetTester tester,
  DriftConnectedDomainRepository repository, {
  List<CodexNavigationRequest>? navigations,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: StoryCodexWorkspace(
          projectId: projectId,
          repository: repository,
          onNavigate: navigations?.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Drives a dropdown without depending on the overlay menu.
void _choose<T>(WidgetTester tester, Key key, T value) {
  final field = tester.widget<DropdownButtonFormField<T>>(find.byKey(key));
  field.onChanged?.call(value);
}

/// Drives a segmented button without depending on hit-testing its segments.
void _select<T>(WidgetTester tester, Key key, Set<T> values) {
  final button = tester.widget<SegmentedButton<T>>(find.byKey(key));
  button.onSelectionChanged?.call(values);
}

Future<void> _seed(StoryCodexService service) async {
  await service.createCodexEntry(const CodexEntryDraft(
    id: 'codex-harbor',
    title: 'Noxmere Harbor',
    templateId: 'location',
    categoryId: 'locations',
    summary: 'Smugglers move salt beneath the cliffs.',
  ));
  await service.createCodexEntry(const CodexEntryDraft(
    id: 'codex-rule',
    title: 'Blood Binding',
    templateId: 'magic-rule',
    categoryId: 'magic',
    summary: 'A costly binding rule.',
  ));
}

Future<void> _putCharacter(
  DriftConnectedDomainRepository repository,
  String id,
  String title,
) =>
    repository.putRecord(AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      templateId: 'character',
      fields: {
        'name': title,
        'identity.displayName': title,
        'identity.fullName': title,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    ));

/// Writes a record that fails template validation, bypassing RecordService so
/// the workspace has something to flag.
Future<void> _putInvalidCharacter(
  DriftConnectedDomainRepository repository,
) =>
    repository.putRecord(AuthorRecord(
      id: 'codex-invalid',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: 'Nameless Figure',
      templateId: 'character',
      fields: {
        'name': 'Nameless Figure',
        CodexFields.templateId: 'character',
        CodexFields.categoryId: 'characters',
        CodexFields.projectId: projectId,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    ));
