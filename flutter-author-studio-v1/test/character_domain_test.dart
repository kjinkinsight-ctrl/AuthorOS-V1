import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/character_record_types.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/record_validation.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/character_domain_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late CharacterService characters;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    characters = CharacterService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('deep schema is sparse, sectioned, typed, and template-driven',
      () async {
    final registry = await characters.records.registry();
    final schema = registry.resolve('character');

    expect(schema.fields.length, greaterThan(130));
    expect(
        schema.sections.map((section) => section.id),
        containsAll([
          'identity',
          'appearance',
          'personality',
          'psychology',
          'backstory',
          'family',
          'relationships',
          'factions',
          'locations',
          'items',
          'secrets',
          'knowledge',
          'voice',
          'storyRole',
          'pov',
          'goals',
          'arcs',
          'timeline',
          'manuscript',
          'codex',
          'world',
          'notes',
        ]));
    expect(
      schema.fields.singleWhere((field) => field.id == 'goals.entries').type,
      RecordFieldType.table,
    );
    expect(
      schema.fields
          .singleWhere((field) => field.id == 'identity.fullName')
          .required,
      isTrue,
    );
    expect(
      schema.fields.where((field) => field.required).map((field) => field.id),
      ['identity.fullName'],
    );
    expect(CharacterRecordTypes.templates, hasLength(12));
    expect(registry.resolve('character-pov').baseTypeId, 'character');

    final basic = await characters.createCharacter(
      id: 'basic',
      displayName: 'Basic Character',
      fields: const {'appearance.eyeColour': 'Green'},
      timestamp: timestamp,
    );
    final presentation = await characters.presentationFor(basic);
    expect(
      presentation.sections.map((section) => section.id),
      ['identity', 'appearance', 'personality', 'notes'],
    );
    expect(
      presentation.sections
          .singleWhere((section) => section.id == 'appearance')
          .hasData,
      isTrue,
    );
  });

  test('fixture uses canonical records and shared cross-system connections',
      () async {
    await CharacterDomainFixture(characters).seed();

    final kali = (await characters.getCharacter('kali'))!;
    final relationships = await characters.getCharacterRelationships('kali');
    final scenes = await characters.getCharacterScenes('kali');
    final timeline = await characters.getCharacterTimeline('kali');
    final factions = await characters.getCharacterFactions('kali');
    final locations = await characters.getCharacterLocations('kali');
    final items = await characters.getCharacterItems('kali');
    final threads = await characters.getCharacterThreads('kali');
    final inspection = (await characters.inspectCharacter('kali'))!;
    final search = await characters.searchCharacters('Red Widow');
    final history = await characters.getCharacterHistory('kali');

    expect(kali.fields['identity.aliases'], ['Red Widow']);
    expect(kali.fields['goals.entries'], isA<List>());
    expect(kali.fields['arcs.entries'], isA<List>());
    expect(kali.fields['knowledge.entries'], isA<List>());
    expect(relationships.map((link) => link.typeId),
        containsAll(['friendOf', 'enemyOf', 'partnerOf']));
    expect(scenes.single.targetId, 'scene-opening');
    expect(timeline.single.sourceId, 'event-betrayal');
    expect(factions.single.targetId, 'widow-network');
    expect(locations.single.targetId, 'ashfall-harbor');
    expect(items.single.targetId, 'widows-knife');
    expect(threads.map((link) => link.targetId), contains('widow-thread'));
    expect(inspection.recordType, 'character');
    expect(inspection.validation.state, InspectionValidationState.valid);
    expect(inspection.references, isNotEmpty);
    expect(search.single.recordId, 'kali');
    expect(history, isNotEmpty);
  });

  test('relationship metadata changes append shared audit history', () async {
    await CharacterDomainFixture(characters).seed();
    final relationship = (await characters.getCharacterRelationships('kali'))
        .singleWhere((link) => link.typeId == 'friendOf');

    final updated = await characters.connections.updateConnection(
      relationship.id,
      metadata: const {
        'status': 'Betrayed',
        'trust': 1,
        'conflict': 'Cassian concealed the map.',
        'history': 'Friends, allies, then betrayal.',
      },
      timestamp: timestamp.add(const Duration(days: 1)),
    );
    final audits = await characters.history.getAuditHistory(recordId: 'kali');

    expect(updated.metadata['status'], 'Betrayed');
    expect(updated.revision, 2);
    expect(
      audits.map((event) => event.changeType),
      contains(AuditChangeType.connectionMetadataChanged),
    );
  });

  test('branch override is isolated from canonical character', () async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      canonStatus: CanonStatus.canon,
      timestamp: timestamp,
    );
    await characters.branches.createBranch(StoryBranch(
      id: 'what-if',
      projectId: 'project-a',
      name: 'What If Kali Stayed',
      kind: BranchKind.whatIf,
      createdAt: timestamp,
    ));
    await characters.overrideCharacterInBranch(
      'what-if',
      'kali',
      title: 'Kali of Endovier',
      fields: const {'psychology.primaryMotivation': 'Remain in Endovier'},
      canonStatus: CanonStatus.alternate,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    final canonical = (await characters.getCharacter('kali'))!;
    final branch = (await characters.inspectCharacter(
      'kali',
      branchId: 'what-if',
    ))!;

    expect(canonical.title, 'Kali Vale');
    expect(canonical.canonStatus, CanonStatus.canon);
    expect(branch.title, 'Kali of Endovier');
    expect(branch.canonStatus, CanonStatus.alternate);
    expect(branch.scope.branchState, BranchRecordState.overridden);
  });

  test('custom templates validate and remain project-scoped', () async {
    final template = CharacterRecordTypes.customTemplate(
      id: 'project-a-fae-courtier',
      name: 'Fae Courtier',
      projectId: 'project-a',
      fields: const [
        RecordFieldDefinition(
          id: 'fae.courtDuty',
          label: 'Court duty',
          type: RecordFieldType.shortText,
          order: 1500,
          required: true,
        ),
      ],
      sections: const [
        RecordTemplateSection(
          id: 'fae',
          title: 'Fae Court',
          order: 1500,
          fieldIds: ['fae.courtDuty'],
        ),
      ],
    );
    await characters.registerCustomTemplate(template);

    await expectLater(
      characters.createCharacter(
        id: 'invalid-fae',
        displayName: 'Aster',
        templateId: template.id,
        timestamp: timestamp,
      ),
      throwsA(isA<RecordValidationException>()),
    );
    final valid = await characters.createCharacter(
      id: 'aster',
      displayName: 'Aster',
      templateId: template.id,
      fields: const {'fae.courtDuty': 'Keeper of Names'},
      timestamp: timestamp,
    );
    final report = await characters.inspectTemplate(valid);
    final otherProject = CharacterService(
      projectId: 'project-b',
      repository: repository,
    );

    expect(report.status, TemplateCompatibilityStatus.current);
    expect(await otherProject.getCharacter(valid.id), isNull);
    expect(
      (await otherProject.records.registry())
          .definitions
          .map((item) => item.id),
      isNot(contains(template.id)),
    );
  });

  test('safe delete blocks dependencies and lifecycle operations are audited',
      () async {
    await CharacterDomainFixture(characters).seed();

    final blocked = (await characters.analyzeDelete('kali'))!;
    expect(blocked.disposition, SafeDeleteDisposition.blocked);
    await expectLater(
      characters.softDeleteCharacter('kali'),
      throwsStateError,
    );

    await characters.createCharacter(
      id: 'minor',
      displayName: 'Minor Character',
      timestamp: timestamp,
    );
    final archived = await characters.archiveCharacter('minor');
    final restored = await characters.restoreCharacter('minor');
    final deleted = await characters.softDeleteCharacter('minor');
    final history = await characters.getCharacterHistory('minor');

    expect(archived.status, AuthorRecordStatus.archived);
    expect(restored.status, AuthorRecordStatus.active);
    expect(deleted.status, AuthorRecordStatus.deleted);
    expect(history.length, greaterThanOrEqualTo(4));
  });
}
