import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/record_inspector.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late UniversalRecordInspector inspector;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() async {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    await _buildFixture(repository, timestamp);
    inspector = UniversalRecordInspector(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('basic inspection exposes identity, project, series, book, and canon',
      () async {
    final result = await inspector.inspectRecord(
      'kali',
      recordType: 'character',
    );

    expect(result, isNotNull);
    expect(result?.recordId, 'kali');
    expect(result?.recordType, 'character');
    expect(result?.title, 'Kali Vale');
    expect(result?.projectId, 'project-a');
    expect(result?.seriesId, 'series-a');
    expect(result?.bookId, 'book-1');
    expect(result?.branchId, isNull);
    expect(result?.canonStatus, CanonStatus.canon);
    expect(result?.lifecycleStatus, AuthorRecordStatus.active);
    expect(result?.schemaVersion, 1);
    expect(result?.scope.branchState, BranchRecordState.inherited);
    expect(result?.scope.visible, isTrue);
  });

  test(
      'inspects actual World, Codex, Timeline, Plot, Item, Scene, and Chapter types',
      () async {
    for (final expectation in <String, String>{
      'noxmere': 'location',
      'widow-network': 'faction',
      'red-knife': 'item',
      'noxmere-codex': 'research-entry',
      'fall-event': 'historical-event',
      'noxmere-plot': 'plot-thread',
    }.entries) {
      expect(
        (await inspector.inspectRecord(expectation.key))?.recordType,
        expectation.value,
        reason: expectation.key,
      );
    }
    final character = (await inspector.inspectRecord('kali'))!;
    expect(
      character.references.map((reference) => reference.entity.type),
      contains('scene'),
    );
    final scene = character.references
        .singleWhere((reference) => reference.entity.id == 'scene-1');
    expect(scene.kind, ReferenceKind.scene);
    expect(await repository.manuscriptNodeById('chapter-1'), isNotNull);
  });

  test('template inspection exposes parent, inheritance, and upgrade status',
      () async {
    final result = (await inspector.inspectRecord('kali'))!;

    expect(result.template.id, 'protagonist');
    expect(result.template.recordVersion, 1);
    expect(result.template.availableVersion, 2);
    expect(result.template.parentTemplateId, 'character');
    expect(result.template.inheritedTemplateIds, ['character', 'general-lore']);
    expect(
      result.template.compatibility.status,
      TemplateCompatibilityStatus.upgradeAvailable,
    );
    expect(result.validation.state, InspectionValidationState.warning);
    expect(
      result.validation.issues.map((issue) => issue.code),
      contains('template-upgrade-available'),
    );
  });

  test(
      'connection inspection exposes incoming, outgoing, metadata, and inverse',
      () async {
    final result = (await inspector.inspectRecord('kali'))!;

    expect(result.outgoingConnections, hasLength(4));
    expect(result.incomingConnections, hasLength(2));
    final membership = result.outgoingConnections
        .singleWhere((connection) => connection.typeId == 'memberOf');
    expect(membership.source.id, 'kali');
    expect(membership.target.id, 'widow-network');
    expect(membership.displayName, 'Member of');
    expect(membership.inverseLabel, 'Has member');
    expect(membership.metadata['rank'], 'Founder');
    expect(membership.temporalSupport, isTrue);
    expect(membership.temporalMetadata, {
      'joinedDate': '2026-01-01',
      'status': 'Active',
    });
    expect(membership.valid, isTrue);
    expect(
      result.incomingConnections.map((connection) => connection.typeId),
      containsAll(['involves', 'relatedTo']),
    );
  });

  test('reference inspection classifies actual manuscript and domain links',
      () async {
    final result = (await inspector.inspectRecord('kali'))!;
    final kinds = result.references.map((reference) => reference.kind).toSet();

    expect(
        kinds,
        containsAll({
          ReferenceKind.scene,
          ReferenceKind.timeline,
          ReferenceKind.world,
          ReferenceKind.plot,
        }));
    expect(
      result.references
          .singleWhere((reference) => reference.entity.id == 'scene-1')
          .incoming,
      isFalse,
    );
    expect(
      result.capabilities.unsupportedReferenceKinds,
      [ReferenceKind.map],
    );
    expect(
      result.capabilities.limitations,
      contains(contains('Map markers')),
    );
  });

  test('history inspection separates record versions from connection audits',
      () async {
    final result = (await inspector.inspectRecord('kali'))!;

    expect(result.history.versionCount, 2);
    expect(result.history.versionIds, hasLength(2));
    expect(result.history.latestVersion?.snapshot['title'], 'Kali Vale');
    expect(result.history.auditEventCount,
        greaterThan(result.history.versionCount));
    expect(result.history.latestAuditEvent, isNotNull);
    expect(result.safeDelete.versionCount, 2);
  });

  test('validation detects invalid typed connections without another engine',
      () async {
    final now = timestamp.add(const Duration(hours: 1));
    await repository.putLink(RecordLink(
      id: 'invalid-link',
      sourceId: 'kali',
      targetId: 'noxmere',
      typeId: 'memberOf',
      scopeId: 'project-a',
      createdAt: now,
      updatedAt: now,
    ));

    final result = (await inspector.inspectRecord('kali'))!;

    expect(result.validation.state, InspectionValidationState.error);
    expect(
      result.validation.issues.map((issue) => issue.code),
      contains('invalid-connection'),
    );
    expect(
      result.outgoingConnections
          .singleWhere((connection) => connection.id == 'invalid-link')
          .valid,
      isFalse,
    );
  });

  test('validation reports a broken branch reference from an actual overlay',
      () async {
    await repository.putBranchLinkOverlay(BranchLinkOverlay(
      branchId: 'branch-a',
      linkId: 'broken-branch-link',
      state: BranchLinkState.added,
      updatedAt: timestamp.add(const Duration(hours: 2)),
      link: RecordLink(
        id: 'broken-branch-link',
        sourceId: 'kali',
        targetId: 'missing-record',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: timestamp.add(const Duration(hours: 2)),
        updatedAt: timestamp.add(const Duration(hours: 2)),
      ),
    ));

    final result = (await inspector.inspectRecord(
      'kali',
      branchId: 'branch-a',
    ))!;

    expect(result.validation.state, InspectionValidationState.error);
    expect(
      result.validation.issues.map((issue) => issue.code),
      contains('broken-reference'),
    );
    expect(
      result.references
          .singleWhere(
              (reference) => reference.connectionId == 'broken-branch-link')
          .entity
          .exists,
      isFalse,
    );
  });

  test('safe delete analysis reports links, references, branches, and versions',
      () async {
    final result = (await inspector.inspectRecord('kali'))!;

    expect(result.safeDelete.incomingConnectionCount, 2);
    expect(result.safeDelete.outgoingConnectionCount, 4);
    expect(result.safeDelete.knownReferenceCount, 6);
    expect(result.safeDelete.branchDependencyCount, 1);
    expect(result.safeDelete.versionCount, 2);
    expect(
        result.safeDelete.dependentEntityIds,
        containsAll([
          'widow-network',
          'noxmere',
          'red-knife',
          'scene-1',
          'fall-event',
          'noxmere-plot',
        ]));
    expect(result.safeDelete.hasDependencies, isTrue);
  });

  test('branch inspection distinguishes override, created, hidden, and canon',
      () async {
    final canon = (await inspector.inspectRecord('kali'))!;
    final override = (await inspector.inspectRecord(
      'kali',
      branchId: 'branch-a',
    ))!;
    final created = (await inspector.inspectRecord(
      'branch-relic',
      branchId: 'branch-a',
    ))!;
    final hidden = (await inspector.inspectRecord(
      'noxmere',
      branchId: 'branch-a',
    ))!;

    expect(canon.title, 'Kali Vale');
    expect(canon.history.versionCount, 2);
    expect(override.title, 'Kali Remained');
    expect(override.scope.branchState, BranchRecordState.overridden);
    expect(override.scope.visible, isTrue);
    expect(override.branchId, 'branch-a');
    expect(override.canonStatus, CanonStatus.alternate);
    expect(override.history.versionCount, 1);
    expect(created.scope.branchState, BranchRecordState.created);
    expect(created.scope.visible, isTrue);
    expect(created.recordType, 'item');
    expect(hidden.scope.branchState, BranchRecordState.hidden);
    expect(hidden.scope.visible, isFalse);
    expect(canon.title, 'Kali Vale');
  });

  test('branch connections reflect branch context without changing canon',
      () async {
    final canon = (await inspector.inspectRecord('kali'))!;
    final branch = (await inspector.inspectRecord(
      'kali',
      branchId: 'branch-a',
    ))!;

    final canonicalItemLink = canon.outgoingConnections
        .singleWhere((connection) => connection.target.id == 'red-knife');
    expect(
      branch.outgoingConnections.map((connection) => connection.id),
      isNot(contains(canonicalItemLink.id)),
    );
    expect(
      branch.outgoingConnections.map((connection) => connection.id),
      contains('branch-link-kali-relic'),
    );
    expect(
      branch.outgoingConnections
          .singleWhere(
              (connection) => connection.id == 'branch-link-kali-relic')
          .branchId,
      'branch-a',
    );
  });

  test('project isolation blocks records, links, references, and history',
      () async {
    expect(await inspector.inspectRecord('project-b-character'), isNull);
    final projectB = UniversalRecordInspector(
      projectId: 'project-b',
      repository: repository,
    );
    final result = (await projectB.inspectRecord('project-b-character'))!;

    expect(result.projectId, 'project-b');
    expect(result.outgoingConnections, isEmpty);
    expect(result.incomingConnections, isEmpty);
    expect(
        result.history.auditEvents.every(
          (event) => event.projectId == 'project-b',
        ),
        isTrue);
    expect(result.references, isEmpty);
  });

  test('search integration resolves stable record IDs and types', () async {
    final results = await inspector.searchAndInspect(
      'Kali Vale',
      recordType: 'character',
    );

    expect(results.single.recordId, 'kali');
    expect(results.single.recordType, 'character');
    expect(
        await inspector.inspectRecord('kali', recordType: 'location'), isNull);
  });

  test('inspection is strictly read-only', () async {
    final before = (await repository.snapshot()).toJson();

    await inspector.inspectRecord('kali');
    await inspector.inspectRecord('kali', branchId: 'branch-a');
    await inspector.searchAndInspect('Kali Vale', recordType: 'character');

    expect((await repository.snapshot()).toJson(), before);
  });

  test('inspection survives database reopen and archive restoration', () async {
    await database.close();
    final directory =
        await Directory.systemTemp.createTemp('authoros-inspector-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}inspector.sqlite');
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    await _buildFixture(firstRepository, timestamp);
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopened = UniversalRecordInspector(
      projectId: 'project-a',
      repository: reopenedRepository,
    );
    final reopenedResult = (await reopened.inspectRecord(
      'kali',
      branchId: 'branch-a',
    ))!;
    expect(reopenedResult.title, 'Kali Remained');
    expect(reopenedResult.history.versionCount, 1);
    expect(reopenedResult.safeDelete.branchDependencyCount, 1);

    const archives = AuthorOsArchiveService();
    final bytes = archives.exportSnapshot(
      await reopenedRepository.snapshot(),
      archiveId: 'inspector-archive',
      rootId: 'project-a',
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: timestamp,
    );
    final restoredDatabase = AuthorOsDatabase(NativeDatabase.memory());
    final restoredRepository = DriftConnectedDomainRepository(restoredDatabase);
    await restoredRepository.replaceSnapshot(archives.importSnapshot(bytes));
    final restored = UniversalRecordInspector(
      projectId: 'project-a',
      repository: restoredRepository,
    );
    final restoredResult = (await restored.inspectRecord('kali'))!;
    expect(restoredResult.history.versionCount, 2);
    expect(restoredResult.outgoingConnections, hasLength(4));
    expect(restoredResult.validation.state, InspectionValidationState.warning);
    await restoredDatabase.close();
    await reopenedDatabase.close();
  });
}

Future<void> _buildFixture(
  DriftConnectedDomainRepository repository,
  DateTime timestamp,
) async {
  final records = RecordService(projectId: 'project-a', repository: repository);
  await repository.putRecordTypeDefinition(const RecordTypeDefinition(
    id: 'protagonist',
    name: 'Protagonist',
    categoryId: 'characters',
    baseTypeId: 'character',
    scopeType: RecordScopeType.project,
    scopeId: 'project-a',
    fields: [],
    sections: [],
    templateVersion: 2,
  ));
  final kali = await records.createRecord(_record(
    'kali',
    'character',
    'Kali Vale',
    timestamp,
    seriesId: 'series-a',
    bookId: 'book-1',
    templateId: 'protagonist',
    templateVersion: 1,
    fields: const {'identity.fullName': 'Kali Vale'},
  ));
  await records.updateRecord(kali.copyWith(
    updatedAt: timestamp.add(const Duration(minutes: 1)),
  ));
  await records.createRecord(_record(
    'noxmere',
    'location',
    'Noxmere Harbor',
    timestamp,
  ));
  await records.createRecord(_record(
    'widow-network',
    'faction',
    'Widow Network',
    timestamp,
  ));
  await records.createRecord(_record(
    'red-knife',
    'item',
    'Red Knife',
    timestamp,
  ));
  await records.createRecord(_record(
    'noxmere-codex',
    'research-entry',
    'Noxmere Codex',
    timestamp,
  ));
  await records.createRecord(_record(
    'fall-event',
    'historical-event',
    'Fall of Noxmere',
    timestamp,
  ));
  await records.createRecord(_record(
    'noxmere-plot',
    'plot-thread',
    'Noxmere Plot',
    timestamp,
  ));
  await repository.putConnectedSlice(
    record: _record(
      'scene-proxy',
      'general-lore',
      'Scene Proxy',
      timestamp,
    ),
    manuscriptNode: ManuscriptNodeReference(
      id: 'scene-1',
      projectId: 'project-a',
      nodeType: 'scene',
      title: 'Noxmere Meeting',
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
  await repository.putConnectedSlice(
    record: _record(
      'chapter-proxy',
      'general-lore',
      'Chapter Proxy',
      timestamp,
    ),
    manuscriptNode: ManuscriptNodeReference(
      id: 'chapter-1',
      projectId: 'project-a',
      nodeType: 'chapter',
      title: 'Noxmere Chapter',
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
    link: RecordLink(
      id: 'proxy-chapter',
      sourceId: 'chapter-proxy',
      targetId: 'chapter-1',
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
    targetId: 'widow-network',
    typeId: 'memberOf',
    metadata: const {
      'rank': 'Founder',
      'joinedDate': '2026-01-01',
      'status': 'Active',
    },
    timestamp: timestamp.add(const Duration(minutes: 2)),
  );
  await connections.connect(
    sourceId: 'kali',
    targetId: 'noxmere',
    typeId: 'livesIn',
    timestamp: timestamp.add(const Duration(minutes: 3)),
  );
  final ownedItemLink = await connections.connect(
    sourceId: 'kali',
    targetId: 'red-knife',
    typeId: 'owns',
    timestamp: timestamp.add(const Duration(minutes: 4)),
  );
  await connections.connect(
    sourceId: 'kali',
    targetId: 'scene-1',
    typeId: 'appearsIn',
    timestamp: timestamp.add(const Duration(minutes: 5)),
  );
  await connections.connect(
    sourceId: 'fall-event',
    targetId: 'kali',
    typeId: 'involves',
    timestamp: timestamp.add(const Duration(minutes: 6)),
  );
  await connections.connect(
    sourceId: 'noxmere-codex',
    targetId: 'widow-network',
    typeId: 'documents',
    timestamp: timestamp.add(const Duration(minutes: 7)),
  );
  await connections.connect(
    sourceId: 'noxmere-plot',
    targetId: 'kali',
    typeId: 'relatedTo',
    direction: RecordLinkDirection.undirected,
    timestamp: timestamp.add(const Duration(minutes: 8)),
  );
  await connections.connect(
    sourceId: 'scene-1',
    targetId: 'chapter-1',
    typeId: 'partOf',
    timestamp: timestamp.add(const Duration(minutes: 9)),
  );

  final branches =
      BranchService(projectId: 'project-a', repository: repository);
  await branches.createBranch(StoryBranch(
    id: 'branch-a',
    projectId: 'project-a',
    name: 'What if Kali remained?',
    kind: BranchKind.whatIf,
    createdAt: timestamp.add(const Duration(minutes: 10)),
  ));
  await branches.overrideRecord(
    'branch-a',
    'kali',
    title: 'Kali Remained',
    canonStatus: CanonStatus.alternate,
    timestamp: timestamp.add(const Duration(minutes: 11)),
  );
  await branches.hideRecord(
    'branch-a',
    'noxmere',
    timestamp: timestamp.add(const Duration(minutes: 12)),
  );
  await branches.createRecord(
    'branch-a',
    _record(
      'branch-relic',
      'item',
      'Branch Relic',
      timestamp,
      scopeType: RecordScopeType.branch,
      scopeId: 'branch-a',
      branchId: 'branch-a',
      canonStatus: CanonStatus.alternate,
    ),
    timestamp: timestamp.add(const Duration(minutes: 13)),
  );
  await branches.hideConnection(
    'branch-a',
    ownedItemLink.id,
    timestamp: timestamp.add(const Duration(minutes: 14)),
  );
  await branches.addConnection(
    'branch-a',
    RecordLink(
      id: 'branch-link-kali-relic',
      sourceId: 'kali',
      targetId: 'branch-relic',
      typeId: 'owns',
      scopeId: 'project-a',
      createdAt: timestamp.add(const Duration(minutes: 15)),
      updatedAt: timestamp.add(const Duration(minutes: 15)),
    ),
  );

  final projectB =
      RecordService(projectId: 'project-b', repository: repository);
  await projectB.createRecord(_record(
    'project-b-character',
    'character',
    'Kali Vale',
    timestamp,
    projectId: 'project-b',
    fields: const {'identity.fullName': 'Kali Vale'},
  ));
}

AuthorRecord _record(
  String id,
  String typeId,
  String title,
  DateTime timestamp, {
  String projectId = 'project-a',
  RecordScopeType scopeType = RecordScopeType.project,
  String? scopeId,
  String? seriesId,
  String? bookId,
  String? branchId,
  CanonStatus canonStatus = CanonStatus.canon,
  String? templateId,
  int? templateVersion,
  Map<String, Object?> fields = const {},
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: scopeType,
      scopeId: scopeId ?? projectId,
      projectId: projectId,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: title,
      templateId: templateId,
      templateVersion: templateVersion,
      fields: fields,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
