import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/safe_delete_service.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/core/version_audit_service.dart';
import 'package:author_studio_v1/migrations/legacy_reference_migration.dart';
import 'package:author_studio_v1/migrations/legacy_reference_models.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late SafeDeleteService safeDelete;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    safeDelete = SafeDeleteService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('no current dependencies is safe with history warning', () async {
    await records.createRecord(_record('orphan', 'character', timestamp));

    final analysis = (await safeDelete.analyze('orphan'))!;

    expect(analysis.disposition, SafeDeleteDisposition.safeWithWarnings);
    expect(analysis.canDelete, isTrue);
    expect(analysis.blockingReasons, isEmpty);
    expect(analysis.versionCount, 1);
    expect(analysis.auditCount, 1);
    expect(analysis.physicallyDeletable, isFalse);
  });

  test(
      'archived and soft-deleted dependency-free records are physically eligible',
      () async {
    await records.createRecord(_record('archived', 'character', timestamp));
    await records.archiveRecord('archived');
    await records.createRecord(_record('deleted', 'character', timestamp));
    await records.deleteRecord('deleted');

    final archived = (await safeDelete.analyze('archived'))!;
    final deleted = (await safeDelete.analyze('deleted'))!;

    expect(archived.archived, isTrue);
    expect(archived.physicallyDeletable, isTrue);
    expect(deleted.softDeleted, isTrue);
    expect(deleted.physicallyDeletable, isTrue);
  });

  test(
      'incoming outgoing manuscript and branch dependencies block Canon deletion',
      () async {
    await records.createRecord(_record('kali', 'character', timestamp));
    await records.createRecord(_record('faction', 'faction', timestamp));
    await records.createRecord(_record('event', 'historical-event', timestamp));
    await repository.putConnectedSlice(
      record: _record('scene-proxy', 'general-lore', timestamp),
      manuscriptNode: ManuscriptNodeReference(
        id: 'scene-1',
        projectId: 'project-a',
        nodeType: 'scene',
        title: 'Scene One',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      link: RecordLink(
        id: 'proxy-scene',
        sourceId: 'scene-proxy',
        targetId: 'scene-1',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    final connections = ConnectionEngine(
      scopeId: 'project-a',
      repository: repository,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'faction',
      typeId: 'memberOf',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'event',
      targetId: 'kali',
      typeId: 'involves',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'scene-1',
      typeId: 'appearsIn',
      timestamp: timestamp,
    );
    final branches = BranchService(
      projectId: 'project-a',
      repository: repository,
    );
    await branches.createBranch(StoryBranch(
      id: 'branch-a',
      projectId: 'project-a',
      name: 'What If',
      createdAt: timestamp,
    ));
    await branches.overrideRecord('branch-a', 'kali', title: 'Branch Kali');

    final analysis = (await safeDelete.analyze('kali'))!;

    expect(analysis.disposition, SafeDeleteDisposition.blocked);
    expect(analysis.canDelete, isFalse);
    expect(analysis.incomingConnections, hasLength(1));
    expect(analysis.outgoingConnections, hasLength(2));
    expect(analysis.affectedManuscriptNodes, ['scene-1']);
    expect(analysis.affectedBranches, ['branch-a']);
    expect(analysis.physicallyDeletable, isFalse);
    expect(
        (await repository.recordById('kali'))?.canonStatus, CanonStatus.canon);
  });

  test('branch-created and hidden dependencies are reported deterministically',
      () async {
    await records.createRecord(_record('location', 'location', timestamp));
    final branches = BranchService(
      projectId: 'project-a',
      repository: repository,
    );
    await branches.createBranch(StoryBranch(
      id: 'branch-b',
      projectId: 'project-a',
      name: 'Alternate',
      createdAt: timestamp,
    ));
    await branches.createRecord(
      'branch-b',
      _record(
        'branch-item',
        'item',
        timestamp,
        scopeType: RecordScopeType.branch,
        scopeId: 'branch-b',
        branchId: 'branch-b',
        canonStatus: CanonStatus.alternate,
      ),
    );
    await branches.addConnection(
      'branch-b',
      RecordLink(
        id: 'branch-location-item',
        sourceId: 'branch-item',
        targetId: 'location',
        typeId: 'locatedIn',
        scopeId: 'project-a',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await branches.hideRecord('branch-b', 'location');

    final analysis = (await safeDelete.analyze('location'))!;

    expect(analysis.disposition, SafeDeleteDisposition.blocked);
    expect(analysis.affectedBranches, ['branch-b']);
    expect(analysis.blockingReasons, contains(contains('Branch')));
  });

  test('legacy references and migrated stable references block deletion',
      () async {
    await records.createRecord(_record('kali', 'character', timestamp));
    await records.createRecord(AuthorRecord(
      id: 'owner',
      typeId: 'general-lore',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: 'Owner',
      fields: const {
        legacyStableReferencesField: {
          'legacy-1': {'stableRecordId': 'kali'}
        }
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    ));
    const unresolvedLegacy = LegacyReference(
      id: 'legacy-name',
      legacyReference: 'Kali',
      source: 'ManuscriptScene.pov',
      sourceEntityId: 'scene-legacy',
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    );

    final analysis = (await safeDelete.analyze(
      'kali',
      legacyReferences: const [unresolvedLegacy],
    ))!;

    expect(analysis.disposition, SafeDeleteDisposition.blocked);
    expect(analysis.legacyReferences, [
      'owner:legacy-1',
      'scene-legacy:pov',
    ]);
  });

  test('project isolation and analysis are strictly read-only', () async {
    await records.createRecord(_record('kali-a', 'character', timestamp));
    final projectB =
        RecordService(projectId: 'project-b', repository: repository);
    await projectB.createRecord(_record(
      'kali-b',
      'character',
      timestamp,
      projectId: 'project-b',
    ));
    final before = (await repository.snapshot()).toJson();

    expect(await safeDelete.analyze('kali-b'), isNull);
    final analysis = (await safeDelete.analyze('kali-a'))!;

    expect(analysis.affectedRecords, isNot(contains('kali-b')));
    expect((await repository.snapshot()).toJson(), before);
  });

  test('cross-system safety fixture remains stable across repeat migration',
      () async {
    for (final record in [
      _record('kali', 'character', timestamp),
      _record('noxmere', 'location', timestamp),
      _record('network', 'faction', timestamp),
      _record('knife', 'item', timestamp),
      _record('codex', 'research-entry', timestamp),
      _record('event', 'historical-event', timestamp),
      _record('plot', 'plot-thread', timestamp),
      AuthorRecord(
        id: 'legacy-owner',
        typeId: 'general-lore',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        projectId: 'project-a',
        title: 'Legacy Owner',
        fields: const {
          'legacyRelationships': {'hero': 'kali'}
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ]) {
      await records.createRecord(record);
    }
    await repository.putConnectedSlice(
      record: _record('scene-proxy', 'general-lore', timestamp),
      manuscriptNode: ManuscriptNodeReference(
        id: 'scene-x',
        projectId: 'project-a',
        nodeType: 'scene',
        title: 'Scene X',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      link: RecordLink(
        id: 'scene-proxy-link',
        sourceId: 'scene-proxy',
        targetId: 'scene-x',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await repository.putConnectedSlice(
      record: _record('chapter-proxy', 'general-lore', timestamp),
      manuscriptNode: ManuscriptNodeReference(
        id: 'chapter-x',
        projectId: 'project-a',
        nodeType: 'chapter',
        title: 'Chapter X',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      link: RecordLink(
        id: 'chapter-proxy-link',
        sourceId: 'chapter-proxy',
        targetId: 'chapter-x',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    final connections = ConnectionEngine(
      scopeId: 'project-a',
      repository: repository,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'network',
      typeId: 'memberOf',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'noxmere',
      typeId: 'livesIn',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'knife',
      typeId: 'owns',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'kali',
      targetId: 'scene-x',
      typeId: 'appearsIn',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'event',
      targetId: 'kali',
      typeId: 'involves',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'codex',
      targetId: 'network',
      typeId: 'documents',
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'plot',
      targetId: 'kali',
      typeId: 'relatedTo',
      direction: RecordLinkDirection.undirected,
      timestamp: timestamp,
    );
    await connections.connect(
      sourceId: 'scene-x',
      targetId: 'chapter-x',
      typeId: 'partOf',
      timestamp: timestamp,
    );

    final characterAnalysis = (await safeDelete.analyze('kali'))!;
    final locationAnalysis = (await safeDelete.analyze('noxmere'))!;
    expect(characterAnalysis.disposition, SafeDeleteDisposition.blocked);
    expect(characterAnalysis.affectedManuscriptNodes, ['scene-x']);
    expect(characterAnalysis.affectedRecords,
        containsAll(['network', 'noxmere', 'knife', 'event', 'plot']));
    expect(locationAnalysis.disposition, SafeDeleteDisposition.blocked);
    expect(locationAnalysis.affectedRecords, contains('kali'));

    final migration = LegacyReferenceMigrationService(
      projectId: 'project-a',
      repository: repository,
    );
    const legacy = LegacyReference(
      id: 'legacy-owner:hero',
      legacyReference: 'kali',
      source: 'StoryCodexEntry.relationships',
      sourceEntityId: 'legacy-owner',
      fieldPath: 'relationships.hero',
      expectedRecordTypes: ['character'],
    );
    final first = await migration.migrate(
      ownerRecordId: 'legacy-owner',
      reference: legacy,
    );
    final second = await migration.migrate(
      ownerRecordId: 'legacy-owner',
      reference: legacy,
    );
    expect(first.persisted, isTrue);
    expect(second.persisted, isFalse);
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: repository,
      ).getRecordVersionCount('legacy-owner'),
      2,
    );
    final search = UniversalSearchService(
      projectId: 'project-a',
      repository: repository,
    );
    expect(
      (await search.searchAll('kali')).map((result) => result.recordId),
      containsAll(['kali', 'legacy-owner']),
    );
  });
}

AuthorRecord _record(
  String id,
  String typeId,
  DateTime timestamp, {
  String projectId = 'project-a',
  RecordScopeType scopeType = RecordScopeType.project,
  String? scopeId,
  String? branchId,
  CanonStatus canonStatus = CanonStatus.canon,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: scopeType,
      scopeId: scopeId ?? projectId,
      projectId: projectId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: id,
      templateId: typeId == 'character' ? 'character' : null,
      templateVersion: typeId == 'character' ? 1 : null,
      fields: typeId == 'character' ? {'identity.fullName': id} : const {},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
