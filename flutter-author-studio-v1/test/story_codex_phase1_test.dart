import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/story_codex_phase1_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexPhase1Fixture fixture;

  setUp(() async {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    fixture = await StoryCodexPhase1Fixture.build(repository);
  });

  tearDown(() => database.close());

  test('all required entry families and deep templates are data-driven',
      () async {
    final registry = await fixture.codex.templateRegistry();
    const requiredTypes = {
      'general-lore',
      'location',
      'region',
      'country',
      'city',
      'settlement',
      'district',
      'building',
      'faction',
      'organisation',
      'house',
      'clan',
      'culture',
      'religion',
      'deity',
      'magic-system',
      'magic-ability',
      'spell',
      'technology',
      'language',
      'species',
      'race',
      'creature',
      'monster',
      'item',
      'artefact',
      'weapon',
      'armour',
      'clothing',
      'book',
      'document',
      'historical-event',
      'historical-period',
      'political-system',
      'government',
      'law',
      'custom-tradition',
      'festival',
      'institution',
      'profession',
      'concept',
      'myth',
      'legend',
      'rumour',
      'secret',
      'organisation-role',
      'other-custom-entry',
    };
    expect(
      registry.definitions.map((definition) => definition.id).toSet(),
      containsAll(requiredTypes),
    );

    expect(registry.resolve('general-lore').name, 'Basic Lore');
    expect(registry.resolve('location').fields.map((field) => field.id),
        containsAll(['name', 'geography', 'climate', 'secrets']));
    expect(registry.resolve('faction').fields.map((field) => field.id),
        containsAll(['purpose', 'leadership', 'allies', 'enemies']));
    expect(registry.resolve('culture').fields.map((field) => field.id),
        containsAll(['values', 'traditions', 'taboos']));
    expect(registry.resolve('religion').fields.map((field) => field.id),
        containsAll(['beliefs', 'deities', 'rituals']));
    expect(registry.resolve('magic-system').fields.map((field) => field.id),
        containsAll(['source', 'rules', 'limitations', 'costs']));
    expect(registry.resolve('historical-event').fields.map((field) => field.id),
        containsAll(['date', 'cause', 'consequences', 'hiddenTruth']));
    expect(registry.resolve('item').fields.map((field) => field.id),
        containsAll(['creator', 'owner', 'powers', 'currentLocation']));
    expect(registry.resolve('city').baseTypeId, 'location');
    expect(registry.resolve('weapon').baseTypeId, 'item');
  });

  test('entry operations, custom fields, templates, search, and history work',
      () async {
    const customTemplate = RecordTypeDefinition(
      id: 'vampire-court',
      name: 'Vampire Court',
      categoryId: 'factions',
      baseTypeId: 'faction',
      scopeType: RecordScopeType.project,
      scopeId: StoryCodexPhase1Fixture.projectId,
      fields: [
        RecordFieldDefinition(
          id: 'bloodLaw',
          label: 'Blood Law',
          type: RecordFieldType.longText,
          order: 300,
          required: true,
        ),
      ],
      sections: [],
    );
    await fixture.codex.saveTemplate(customTemplate);
    final created = await fixture.codex.createFromTemplate(
      'vampire-court',
      id: 'codex-vampire-court',
      title: 'Court of Red Glass',
      fields: const {
        'bloodLaw': 'No feeding beneath the seventh bell.',
        'customField': {'preserved': true},
        'aliases': ['The Crimson Court'],
      },
      tags: const ['Secret', 'Political'],
    );

    expect(created.record.templateId, 'vampire-court');
    expect(created.structuredFields['customField'], {'preserved': true});
    expect(created.aliases, ['The Crimson Court']);
    expect((await fixture.codex.searchCodex('Crimson Court')).single.id,
        created.id);

    final basic = await fixture.codex.createFromTemplate(
      'general-lore',
      id: 'codex-retargetable-lore',
      title: 'Unnamed Frontier',
    );
    final changed = await fixture.codex.changeTemplate(
      basic.id,
      'location',
    );
    expect(changed.record.typeId, 'general-lore');
    expect(changed.record.templateId, 'location');
    expect(await fixture.codex.getHistory(changed.id), hasLength(2));

    expect((await fixture.codex.archiveEntry(created.id)).isArchived, isTrue);
    expect((await fixture.codex.restoreEntry(created.id)).isArchived, isFalse);
    final duplicate = await fixture.codex.duplicateEntry(created.id);
    expect(duplicate.structuredFields['customField'], {'preserved': true});
  });

  test('connections support metadata, inverse discovery, updates, and removal',
      () async {
    final rivalry = fixture.links['faction-rivalry']!;
    final inverse = await fixture.codex.getCodexConnections(
      fixture.ids['faction-b']!,
    );
    expect(inverse.map((link) => link.id), contains(rivalry.id));
    expect(rivalry.metadata['startDate'], '342-01-01');
    expect(rivalry.metadata['strength'], 5);

    final updated = await fixture.codex.connections.updateConnection(
      rivalry.id,
      metadata: {...rivalry.metadata, 'status': 'Truce'},
    );
    expect(updated.revision, 2);
    expect(updated.metadata['status'], 'Truce');

    await fixture.codex.connections.disconnect(rivalry.id);
    expect(
      (await fixture.codex.getCodexConnections(fixture.ids['faction-a']!))
          .map((link) => link.id),
      isNot(contains(rivalry.id)),
    );
  });

  test(
      'fixture proves timeline, character, world, manuscript, and shared tools',
      () async {
    expect(await fixture.codex.getCharacters(fixture.ids['faction-a']!),
        hasLength(2));
    expect(await fixture.codex.getTimeline(fixture.ids['city']!), isNotEmpty);
    expect(await fixture.codex.getWorldReferences(fixture.ids['district']!),
        isNotEmpty);
    expect(
      await fixture.codex.getManuscriptReferences(fixture.ids['religion']!),
      isNotEmpty,
    );

    final inspection = await fixture.codex.inspectEntry(fixture.ids['leader']!);
    expect(inspection, isNotNull);
    expect(inspection?.references, isNotEmpty);
    expect(inspection?.history.versionCount, 1);
    expect((await fixture.codex.validateEntry(fixture.ids['leader']!)).isValid,
        isTrue);
    final delete = await fixture.codex.analyzeDelete(fixture.ids['leader']!);
    expect(delete?.disposition, SafeDeleteDisposition.blocked);
    expect(delete?.affectedRecords, isNotEmpty);
  });

  test('branch reads expose inherited, overridden, created, and hidden states',
      () async {
    const branchId = 'codex-alternate';
    await fixture.codex.branches.createBranch(StoryBranch(
      id: branchId,
      projectId: StoryCodexPhase1Fixture.projectId,
      name: 'The Ash Victory',
      kind: BranchKind.alternateTimeline,
      createdAt: StoryCodexPhase1Fixture.timestamp,
    ));
    await fixture.codex.branches.overrideRecord(
      branchId,
      fixture.ids['city']!,
      title: 'Ashen Lumenfall',
      canonStatus: CanonStatus.alternate,
    );
    await fixture.codex.branches.hideRecord(branchId, fixture.ids['item-1']!);
    final now = StoryCodexPhase1Fixture.timestamp.add(const Duration(hours: 1));
    await fixture.codex.branches.createRecord(
      branchId,
      AuthorRecord(
        id: 'codex-branch-relic',
        typeId: 'item',
        scopeType: RecordScopeType.branch,
        scopeId: branchId,
        projectId: StoryCodexPhase1Fixture.projectId,
        branchId: branchId,
        canonStatus: CanonStatus.alternate,
        title: 'The Unbroken Crown',
        templateId: 'item',
        templateVersion: 1,
        fields: const {'name': 'The Unbroken Crown'},
        createdAt: now,
        updatedAt: now,
      ),
    );

    final entries = await fixture.codex.listByBranch(branchId);
    expect(entries.map((entry) => entry.title), contains('Ashen Lumenfall'));
    expect(entries.map((entry) => entry.id), contains('codex-branch-relic'));
    expect(entries.map((entry) => entry.id),
        isNot(contains(fixture.ids['item-1'])));
    expect(
      (await fixture.codex
              .inspectEntry(fixture.ids['world']!, branchId: branchId))
          ?.scope
          .branchState,
      BranchRecordState.inherited,
    );
    expect(
      (await fixture.codex
              .inspectEntry(fixture.ids['city']!, branchId: branchId))
          ?.scope
          .branchState,
      BranchRecordState.overridden,
    );
  });

  test('validation and inspector expose VALID, WARNING, and ERROR', () async {
    final valid = await fixture.codex.inspectEntry(fixture.ids['culture']!);
    expect(valid?.validation.state, InspectionValidationState.valid);

    const versioned = RecordTypeDefinition(
      id: 'versioned-lore',
      name: 'Versioned Lore',
      categoryId: 'lore',
      baseTypeId: 'general-lore',
      scopeType: RecordScopeType.project,
      scopeId: StoryCodexPhase1Fixture.projectId,
      fields: [],
      sections: [],
      templateVersion: 2,
    );
    await fixture.codex.saveTemplate(versioned);
    final now = StoryCodexPhase1Fixture.timestamp.add(const Duration(hours: 2));
    await fixture.codex.records.createRecord(AuthorRecord(
      id: 'codex-warning',
      typeId: 'general-lore',
      scopeType: RecordScopeType.project,
      scopeId: StoryCodexPhase1Fixture.projectId,
      projectId: StoryCodexPhase1Fixture.projectId,
      title: 'Old Template Lore',
      templateId: 'versioned-lore',
      templateVersion: 1,
      fields: const {'name': 'Old Template Lore'},
      createdAt: now,
      updatedAt: now,
    ));
    expect(
      (await fixture.codex.inspectEntry('codex-warning'))?.validation.state,
      InspectionValidationState.warning,
    );

    await repository.putRecord(AuthorRecord(
      id: 'codex-error',
      typeId: 'general-lore',
      scopeType: RecordScopeType.project,
      scopeId: StoryCodexPhase1Fixture.projectId,
      projectId: StoryCodexPhase1Fixture.projectId,
      title: 'Broken Template Lore',
      templateId: 'missing-template',
      fields: const {'name': 'Broken Template Lore'},
      createdAt: now,
      updatedAt: now,
    ));
    expect(
      (await fixture.codex.inspectEntry('codex-error'))?.validation.state,
      InspectionValidationState.error,
    );
  });
}
