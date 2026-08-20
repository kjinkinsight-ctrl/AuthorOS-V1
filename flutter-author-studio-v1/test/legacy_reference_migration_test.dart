import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/core/version_audit_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/migrations/legacy_reference_adapters.dart';
import 'package:author_studio_v1/migrations/legacy_reference_migration.dart';
import 'package:author_studio_v1/migrations/legacy_reference_models.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:author_studio_v1/timeline.dart';
import 'package:author_studio_v1/visual_planning.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late LegacyReferenceMigrationService migration;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    migration = LegacyReferenceMigrationService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('adapters expose only actual discovered legacy formats', () {
    const codex = StoryCodexEntry(
      id: 'codex-1',
      title: 'Codex',
      type: StoryCodexType.character,
      relationships: {'mentor': 'Kali Vale'},
      mentions: ['scene-1'],
    );
    final scene = ManuscriptScene(
      id: 'scene-1',
      chapterId: 'chapter-1',
      title: 'Scene',
      order: 1,
      content: '',
      status: ManuscriptNodeStatus.draft,
      pov: 'Kali Vale',
      location: 'Noxmere',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final event = _timeline(timestamp);
    const planning = PlanningScene(
      id: 'planning-1',
      title: 'Plan',
      status: SceneStatus.backlog,
      pov: 'Kali Vale',
      arc: 'Main Plot',
      order: 1,
    );

    expect(
      LegacyReferenceAdapters.storyCodex(codex)
          .map((reference) => reference.source),
      containsAll(
          ['StoryCodexEntry.relationships', 'StoryCodexEntry.mentions']),
    );
    expect(
      LegacyReferenceAdapters.manuscriptScene(scene)
          .map((reference) => reference.source),
      containsAll(['ManuscriptScene.pov', 'ManuscriptScene.location']),
    );
    expect(
      LegacyReferenceAdapters.timelineEvent(event)
          .map((reference) => reference.source),
      containsAll([
        'TimelineEvent.pov',
        'TimelineEvent.presentCharacters',
        'TimelineEvent.location',
        'TimelineEvent.plotline',
      ]),
    );
    expect(LegacyReferenceAdapters.planningScene(planning).single.source,
        'PlanningScene.pov');
  });

  test('deterministic exact title and alias resolution returns one stable ID',
      () async {
    await records.createRecord(_character(
      'kali',
      'Kali Vale',
      timestamp,
      aliases: const ['The Cartographer'],
    ));
    const reference = LegacyReference(
      id: 'scene:pov',
      legacyReference: 'The Cartographer',
      source: 'ManuscriptScene.pov',
      sourceEntityId: 'scene-1',
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    );

    final candidate = await migration.resolve(reference);

    expect(candidate.resolutionState, LegacyReferenceResolutionState.resolved);
    expect(candidate.candidateRecordIds, ['kali']);
    expect(candidate.candidateRecordTypes, ['character']);
    expect(candidate.confidence, LegacyReferenceConfidence.exact);
    expect(candidate.resolvedRecordId, 'kali');
  });

  test('ambiguous exact matches never choose automatically', () async {
    await records
        .createRecord(_character('kali-canon', 'Kali Vale', timestamp));
    await records
        .createRecord(_character('kali-draft', 'Kali Vale', timestamp));
    const reference = LegacyReference(
      id: 'scene:pov',
      legacyReference: 'Kali Vale',
      source: 'ManuscriptScene.pov',
      sourceEntityId: 'scene-1',
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    );

    final candidate = await migration.resolve(reference);

    expect(candidate.resolutionState, LegacyReferenceResolutionState.ambiguous);
    expect(candidate.candidateRecordIds, ['kali-canon', 'kali-draft']);
    expect(candidate.resolvedRecordId, isNull);
  });

  test('unresolved unsupported and already migrated references remain explicit',
      () async {
    await records.createRecord(_character('kali', 'Kali Vale', timestamp));
    final unresolved = await migration.resolve(const LegacyReference(
      id: 'missing',
      legacyReference: 'Nobody',
      source: 'ManuscriptScene.pov',
      sourceEntityId: 'scene-1',
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    ));
    final unsupported = await migration.resolve(const LegacyReference(
      id: 'unsupported',
      legacyReference: 'Kali Vale',
      source: 'UnknownLegacyFormat',
      sourceEntityId: 'legacy-1',
      fieldPath: 'unknown',
    ));
    final migrated = await migration.resolve(const LegacyReference(
      id: 'stable',
      legacyReference: 'kali',
      source: 'SceneRelationship.targetId',
      sourceEntityId: 'scene-1',
      fieldPath: 'relationships[0].targetId',
      stableRecordId: 'kali',
      expectedRecordTypes: ['character'],
    ));

    expect(
        unresolved.resolutionState, LegacyReferenceResolutionState.unresolved);
    expect(unsupported.resolutionState,
        LegacyReferenceResolutionState.unsupported);
    expect(migrated.resolutionState,
        LegacyReferenceResolutionState.alreadyMigrated);
  });

  test('non-resolved migration attempts preserve owner and history', () async {
    await records.createRecord(_character('kali-1', 'Kali Vale', timestamp));
    await records.createRecord(_character('kali-2', 'Kali Vale', timestamp));
    await records.createRecord(_owner('owner', timestamp));
    final before = (await repository.snapshot()).toJson();
    final versionCount = await VersionAuditService(
      projectId: 'project-a',
      repository: repository,
    ).getRecordVersionCount('owner');

    for (final reference in const [
      LegacyReference(
        id: 'ambiguous',
        legacyReference: 'Kali Vale',
        source: 'ManuscriptScene.pov',
        sourceEntityId: 'owner',
        fieldPath: 'pov',
        expectedRecordTypes: ['character'],
      ),
      LegacyReference(
        id: 'unresolved',
        legacyReference: 'Missing Person',
        source: 'ManuscriptScene.pov',
        sourceEntityId: 'owner',
        fieldPath: 'pov',
        expectedRecordTypes: ['character'],
      ),
      LegacyReference(
        id: 'unsupported',
        legacyReference: 'Kali Vale',
        source: 'UnknownLegacyFormat',
        sourceEntityId: 'owner',
        fieldPath: 'unknown',
      ),
    ]) {
      expect(
        (await migration.migrate(
          ownerRecordId: 'owner',
          reference: reference,
        ))
            .persisted,
        isFalse,
      );
    }

    expect((await repository.snapshot()).toJson(), before);
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: repository,
      ).getRecordVersionCount('owner'),
      versionCount,
    );
  });

  test(
      'canonical migration preserves legacy data, audits once, and is idempotent',
      () async {
    await records.createRecord(_character('kali', 'Kali Vale', timestamp));
    await records.createRecord(_owner('owner', timestamp));
    const reference = LegacyReference(
      id: 'owner:mentor',
      legacyReference: 'Kali Vale',
      source: 'StoryCodexEntry.relationships',
      sourceEntityId: 'owner',
      fieldPath: 'relationships.mentor',
      expectedRecordTypes: ['character'],
    );

    final first = await migration.migrate(
      ownerRecordId: 'owner',
      reference: reference,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );
    final versionCount = await VersionAuditService(
      projectId: 'project-a',
      repository: repository,
    ).getRecordVersionCount('owner');
    final second = await migration.migrate(
      ownerRecordId: 'owner',
      reference: reference,
      timestamp: timestamp.add(const Duration(minutes: 2)),
    );
    final owner = (await records.getRecord('owner'))!;
    final stable = owner.fields[legacyStableReferencesField] as Map;

    expect(first.persisted, isTrue);
    expect(second.persisted, isFalse);
    expect(second.candidate.resolutionState,
        LegacyReferenceResolutionState.alreadyMigrated);
    expect(stable, hasLength(1));
    expect((stable['owner:mentor'] as Map)['stableRecordId'], 'kali');
    expect(owner.fields['legacyRelationships'], {'mentor': 'Kali Vale'});
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: repository,
      ).getRecordVersionCount('owner'),
      versionCount,
    );
  });

  test('branch migration stays isolated and creates branch history only',
      () async {
    await records.createRecord(_character('kali', 'Kali Vale', timestamp));
    await records.createRecord(_owner('owner', timestamp));
    final branches =
        BranchService(projectId: 'project-a', repository: repository);
    await branches.createBranch(StoryBranch(
      id: 'branch-a',
      projectId: 'project-a',
      name: 'What If',
      createdAt: timestamp,
    ));
    const reference = LegacyReference(
      id: 'branch:owner:mentor',
      legacyReference: 'Kali Vale',
      source: 'StoryCodexEntry.relationships',
      sourceEntityId: 'owner',
      fieldPath: 'relationships.mentor',
      expectedRecordTypes: ['character'],
      branchId: 'branch-a',
    );

    final result = await migration.migrate(
      ownerRecordId: 'owner',
      reference: reference,
    );
    final canon = (await records.getRecord('owner'))!;
    final branch = (await branches.recordsForBranch('branch-a'))
        .singleWhere((record) => record.id == 'owner');
    final history = VersionAuditService(
      projectId: 'project-a',
      repository: repository,
    );

    expect(result.persisted, isTrue);
    expect(canon.fields[legacyStableReferencesField], isNull);
    expect(branch.fields[legacyStableReferencesField], isNotNull);
    expect(await history.getRecordVersionCount('owner'), 1);
    expect(
        await history.getRecordVersionCount('owner', branchId: 'branch-a'), 1);
  });

  test('branch-created record migration preserves created overlay state',
      () async {
    await records.createRecord(_character('kali', 'Kali Vale', timestamp));
    final branches =
        BranchService(projectId: 'project-a', repository: repository);
    await branches.createBranch(StoryBranch(
      id: 'branch-created',
      projectId: 'project-a',
      name: 'Created Records',
      createdAt: timestamp,
    ));
    await branches.createRecord(
      'branch-created',
      AuthorRecord(
        id: 'branch-owner',
        typeId: 'general-lore',
        scopeType: RecordScopeType.branch,
        scopeId: 'branch-created',
        projectId: 'project-a',
        branchId: 'branch-created',
        canonStatus: CanonStatus.alternate,
        title: 'Branch Owner',
        fields: const {
          'legacyRelationships': {'mentor': 'Kali Vale'}
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    const reference = LegacyReference(
      id: 'branch-created:mentor',
      legacyReference: 'Kali Vale',
      source: 'StoryCodexEntry.relationships',
      sourceEntityId: 'branch-owner',
      fieldPath: 'relationships.mentor',
      expectedRecordTypes: ['character'],
      branchId: 'branch-created',
    );

    await migration.migrate(
        ownerRecordId: 'branch-owner', reference: reference);
    final effective = (await branches.recordsForBranch('branch-created'))
        .singleWhere((record) => record.id == 'branch-owner');
    final overlay = (await repository.snapshot())
        .branchRecordOverlays
        .singleWhere((item) => item.recordId == 'branch-owner');

    expect(overlay.state, BranchRecordState.created);
    expect(effective.fields[legacyStableReferencesField], isNotNull);
    expect(await repository.recordById('branch-owner'), isNull);
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: repository,
      ).getRecordVersionCount('branch-owner', branchId: 'branch-created'),
      2,
    );
  });

  test('migration keeps Universal Search and project isolation intact',
      () async {
    await records.createRecord(_character('kali-a', 'Kali Vale', timestamp));
    await records.createRecord(_owner('owner', timestamp));
    final projectB =
        RecordService(projectId: 'project-b', repository: repository);
    await projectB.createRecord(_character(
      'kali-b',
      'Kali Vale',
      timestamp,
      projectId: 'project-b',
    ));
    const reference = LegacyReference(
      id: 'owner:pov',
      legacyReference: 'Kali Vale',
      source: 'ManuscriptScene.pov',
      sourceEntityId: 'owner',
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    );
    await migration.migrate(ownerRecordId: 'owner', reference: reference);

    final search = UniversalSearchService(
      projectId: 'project-a',
      repository: repository,
    );
    final byName = await search.searchAll('Kali Vale');
    final byStableId = await search.searchAll('kali-a');
    expect(byName.map((result) => result.recordId), contains('kali-a'));
    expect(byName.map((result) => result.recordId), isNot(contains('kali-b')));
    expect(byStableId.map((result) => result.recordId), contains('owner'));
  });

  test('legacy archive imports, migrates, reopens, and preserves unknown data',
      () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('legacy-migrate-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}legacy.sqlite');
    final sourceSnapshot = ConnectedDomainSnapshot(
      records: [
        _character('kali', 'Kali Vale', timestamp),
        _owner('owner', timestamp),
      ],
      manuscriptNodes: const [],
      links: const [],
    );
    const archives = AuthorOsArchiveService();
    final bytes = archives.exportSnapshot(
      sourceSnapshot,
      archiveId: 'legacy-archive',
      rootId: 'project-a',
      applicationVersion: '1.0.0',
      platform: 'windows',
      createdAt: timestamp,
    );
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    await firstRepository.replaceSnapshot(archives.importSnapshot(bytes));
    final service = LegacyReferenceMigrationService(
      projectId: 'project-a',
      repository: firstRepository,
    );
    await service.migrate(
      ownerRecordId: 'owner',
      reference: const LegacyReference(
        id: 'owner:mentor',
        legacyReference: 'Kali Vale',
        source: 'StoryCodexEntry.relationships',
        sourceEntityId: 'owner',
        fieldPath: 'relationships.mentor',
        expectedRecordTypes: ['character'],
      ),
    );
    await firstDatabase.close();

    final reopened = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopened);
    final owner = (await reopenedRepository.recordById('owner'))!;

    expect(owner.fields['futureUnknown'], {'preserved': true});
    expect(owner.fields[legacyStableReferencesField], isNotNull);
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: reopenedRepository,
      ).getRecordVersionCount('owner'),
      1,
    );
    await reopened.close();
  });
}

AuthorRecord _character(
  String id,
  String title,
  DateTime timestamp, {
  String projectId = 'project-a',
  List<String> aliases = const [],
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      templateId: 'character',
      templateVersion: 1,
      fields: {
        'identity.fullName': title,
        if (aliases.isNotEmpty) 'aliases': aliases,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );

AuthorRecord _owner(String id, DateTime timestamp) => AuthorRecord(
      id: id,
      typeId: 'general-lore',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: 'Legacy Owner',
      fields: const {
        'legacyRelationships': {'mentor': 'Kali Vale'},
        'futureUnknown': {'preserved': true},
      },
      extensionData: const {'unknownExtension': true},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

TimelineEvent _timeline(DateTime timestamp) => TimelineEvent(
      id: 'event-1',
      title: 'Event',
      description: '',
      dateLabel: '',
      startDay: 1,
      endDay: 1,
      pov: 'Kali Vale',
      plotline: 'Main Plot',
      presentCharacters: const ['Kali Vale'],
      location: 'Noxmere',
      travelDaysFromPrevious: 0,
      linkedNote: '',
      plotBeat: '',
      status: 'Draft',
      importance: 'Major',
      type: 'Event',
      eraId: 'era-1',
      sequenceId: 'sequence-1',
      order: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
