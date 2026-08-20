import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/core/version_audit_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late VersionAuditService history;
  final baseTime = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    history = VersionAuditService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('critical restore appends version 4 and preserves versions 1-3',
      () async {
    final created = await records.createRecord(
      _character('kali', 'Kali V1', baseTime),
    );
    final version1 =
        (await history.getVersionHistory(recordId: created.id)).single;
    final version1Json = version1.toJson();
    final version2Record = await records.updateRecord(created.copyWith(
      title: 'Kali V2',
      updatedAt: baseTime.add(const Duration(minutes: 1)),
    ));
    await records.updateRecord(version2Record.copyWith(
      title: 'Kali V3',
      updatedAt: baseTime.add(const Duration(minutes: 2)),
    ));

    final restored = await records.restoreVersion(
      version1.id,
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );
    final versions = await history.getVersionHistory(recordId: created.id);
    final events = await history.getAuditHistory(recordId: created.id);

    expect(versions, hasLength(4));
    expect(versions.map((version) => version.changeType), [
      AuditChangeType.created,
      AuditChangeType.renamed,
      AuditChangeType.renamed,
      AuditChangeType.restored,
    ]);
    expect(restored.title, 'Kali V1');
    expect(restored.revision, 4);
    expect(versions.first.toJson(), version1Json);
    expect(versions.last.previousVersionId, versions[2].id);
    expect(versions.last.metadata['restoredVersionId'], version1.id);
    expect(events, hasLength(4));
    expect(events.last.versionId, versions.last.id);
    expect(
      (await history.getVersionAt(
        created.id,
        baseTime.add(const Duration(minutes: 1)),
      ))
          ?.snapshot['title'],
      'Kali V2',
    );
    expect((await history.getLatestVersion(created.id))?.id, versions.last.id);
    expect(await history.getRecordVersionCount(created.id), 4);
    expect(
      await history.getChangesSince(baseTime.add(const Duration(minutes: 2))),
      hasLength(2),
    );
  });

  test('create rename archive restore delete duplicate and status are audited',
      () async {
    final created =
        await records.createRecord(_character('kali', 'Kali', baseTime));
    final renamed = await records.updateRecord(created.copyWith(
      title: 'Kali Vale',
      updatedAt: baseTime.add(const Duration(minutes: 1)),
    ));
    await records.archiveRecord(
      renamed.id,
      timestamp: baseTime.add(const Duration(minutes: 2)),
    );
    await records.restoreRecord(
      renamed.id,
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );
    final current = (await records.getRecord(renamed.id))!;
    await records.updateRecord(
      current.copyWith(
        canonStatus: CanonStatus.nonCanon,
        updatedAt: baseTime.add(const Duration(minutes: 4)),
      ),
    );
    await records.deleteRecord(
      renamed.id,
      timestamp: baseTime.add(const Duration(minutes: 5)),
    );
    await records.duplicateRecord(
      renamed.id,
      newId: 'kali-copy',
      timestamp: baseTime.add(const Duration(minutes: 6)),
    );

    final originalChanges = (await history.getAuditHistory(recordId: 'kali'))
        .map((event) => event.changeType);
    final duplicateChanges =
        (await history.getAuditHistory(recordId: 'kali-copy'))
            .map((event) => event.changeType);

    expect(originalChanges, [
      AuditChangeType.created,
      AuditChangeType.renamed,
      AuditChangeType.archived,
      AuditChangeType.restored,
      AuditChangeType.statusChanged,
      AuditChangeType.deleted,
    ]);
    expect(duplicateChanges, [AuditChangeType.duplicated]);
  });

  test('template and scope history retain previous and next metadata',
      () async {
    final created =
        await records.createRecord(_character('kali', 'Kali', baseTime));
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
    final templateChanged = AuthorRecord(
      id: created.id,
      typeId: created.typeId,
      scopeType: created.scopeType,
      scopeId: created.scopeId,
      projectId: created.projectId,
      canonStatus: created.canonStatus,
      title: created.title,
      templateId: 'protagonist',
      templateVersion: 2,
      revision: created.revision,
      fields: created.fields,
      createdAt: created.createdAt,
      updatedAt: baseTime.add(const Duration(minutes: 1)),
    );
    final afterTemplate = await records.updateRecord(templateChanged);
    expect(afterTemplate.templateId, 'protagonist');
    expect(
      (await records.registry()).resolve('protagonist').templateVersion,
      2,
    );
    await records.changeScope(
      created.id,
      scopeType: RecordScopeType.series,
      scopeId: 'series-a',
      seriesId: 'series-a',
      timestamp: baseTime.add(const Duration(minutes: 2)),
    );

    final versions = await history.getVersionHistory(recordId: created.id);

    expect(versions[1].changeType, AuditChangeType.templateChanged);
    expect(versions[1].metadata['previousTemplateVersion'], 1);
    expect(versions[1].metadata['newTemplateVersion'], 2);
    expect(versions[2].changeType, AuditChangeType.scopeChanged);
    expect(versions[2].metadata['previousScopeId'], 'project-a');
    expect(versions[2].metadata['newScopeId'], 'series-a');
    expect(versions[2].seriesId, 'series-a');
  });

  test('connection add metadata update and removal use shared history',
      () async {
    await records.createRecord(_character('kali', 'Kali', baseTime));
    await records.createRecord(_faction('widow-network', baseTime));
    final engine =
        ConnectionEngine(scopeId: 'project-a', repository: repository);
    final link = await engine.connect(
      sourceId: 'kali',
      targetId: 'widow-network',
      typeId: 'memberOf',
      metadata: const {'rank': 'Scout'},
      timestamp: baseTime.add(const Duration(minutes: 1)),
    );
    await engine.updateConnection(
      link.id,
      metadata: const {'rank': 'Captain'},
      timestamp: baseTime.add(const Duration(minutes: 2)),
    );
    await engine.disconnect(
      link.id,
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );

    final versions = await repository.versionHistory(const HistoryFilter(
      projectId: 'project-a',
      recordId: 'kali',
    ));
    final connectionVersions = versions
        .where((version) => version.entityKind == VersionEntityKind.connection)
        .toList();

    expect(connectionVersions.map((version) => version.changeType), [
      AuditChangeType.connectionAdded,
      AuditChangeType.connectionMetadataChanged,
      AuditChangeType.connectionRemoved,
    ]);
    expect(
      (connectionVersions[1].snapshot['metadata'] as Map)['rank'],
      'Captain',
    );
    expect(await repository.backlinks('kali'), isEmpty);
  });

  test('branch restore is isolated from canon record and canon history',
      () async {
    final canonical =
        await records.createRecord(_character('kali', 'Kali', baseTime));
    final branches =
        BranchService(projectId: 'project-a', repository: repository);
    await branches.createBranch(StoryBranch(
      id: 'branch-a',
      projectId: 'project-a',
      name: 'What if',
      kind: BranchKind.whatIf,
      createdAt: baseTime.add(const Duration(minutes: 1)),
    ));
    await branches.overrideRecord(
      'branch-a',
      canonical.id,
      title: 'Kali Branch V1',
      timestamp: baseTime.add(const Duration(minutes: 2)),
    );
    final branchV1 = (await history.getVersionHistory(
            recordId: 'kali', branchId: 'branch-a'))
        .single;
    await branches.overrideRecord(
      'branch-a',
      canonical.id,
      title: 'Kali Branch V2',
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );
    await branches.restoreVersion(
      branchV1.id,
      timestamp: baseTime.add(const Duration(minutes: 4)),
    );

    final canon = await repository.recordById('kali');
    final canonHistory = await history.getVersionHistory(recordId: 'kali');
    final branchHistory =
        await history.getVersionHistory(recordId: 'kali', branchId: 'branch-a');
    final resolved = (await branches.recordsForBranch('branch-a')).single;

    expect(canon?.title, 'Kali');
    expect(canonHistory, hasLength(1));
    expect(branchHistory, hasLength(3));
    expect(branchHistory.last.changeType, AuditChangeType.restored);
    expect(branchHistory.first.snapshot['title'], 'Kali Branch V1');
    expect(resolved.title, 'Kali Branch V1');
  });

  test('project isolation and history filters prevent leakage', () async {
    await records
        .createRecord(_character('shared-id-a', 'Same Name', baseTime));
    final projectB =
        RecordService(projectId: 'project-b', repository: repository);
    await projectB.createRecord(
      _character('shared-id-b', 'Same Name', baseTime, projectId: 'project-b'),
    );

    expect(
      (await history.getAuditHistory()).map((event) => event.recordId),
      ['shared-id-a'],
    );
    expect(
      (await VersionAuditService(
        projectId: 'project-b',
        repository: repository,
      ).getAuditHistory())
          .map((event) => event.recordId),
      ['shared-id-b'],
    );
    expect(
        await history.getVersion((await VersionAuditService(
          projectId: 'project-b',
          repository: repository,
        ).getLatestVersion('shared-id-b'))!
            .id),
        isNull);
  });

  test('history filters by type, series, book, change, and date range',
      () async {
    final scoped = AuthorRecord(
      id: 'book-character',
      typeId: 'character',
      scopeType: RecordScopeType.book,
      scopeId: 'book-1',
      projectId: 'project-a',
      seriesId: 'series-a',
      bookId: 'book-1',
      canonStatus: CanonStatus.draft,
      title: 'Book Character',
      templateId: 'character',
      templateVersion: 1,
      fields: const {'identity.fullName': 'Book Character'},
      createdAt: baseTime,
      updatedAt: baseTime,
    );
    await records.createRecord(scoped);
    await records.updateRecord(scoped.copyWith(
      title: 'Book Character Renamed',
      updatedAt: baseTime.add(const Duration(minutes: 1)),
    ));

    final filtered = await history.getAuditHistory(
      recordType: 'character',
      seriesId: 'series-a',
      bookId: 'book-1',
      changeType: AuditChangeType.renamed,
      from: baseTime.add(const Duration(seconds: 30)),
      to: baseTime.add(const Duration(minutes: 2)),
    );

    expect(filtered.single.recordId, scoped.id);
    expect(filtered.single.seriesId, 'series-a');
    expect(filtered.single.bookId, 'book-1');
  });

  test('cross-system fixture records shared record and relationship history',
      () async {
    final character =
        await records.createRecord(_character('kali', 'Kali', baseTime));
    final location = await records.createRecord(_record(
      'noxmere',
      'location',
      'Noxmere',
      baseTime,
      fields: const {'summary': 'Northern harbor'},
    ));
    final faction =
        await records.createRecord(_faction('widow-network', baseTime));
    final codex = await records.createRecord(_record(
      'noxmere-codex',
      'research-entry',
      'Noxmere Codex',
      baseTime,
      fields: const {'summary': 'Documents the network'},
    ));
    final event = await records.createRecord(_record(
      'fall-event',
      'historical-event',
      'Fall of Noxmere',
      baseTime,
      fields: const {'summary': 'Timeline event'},
    ));
    await repository.putConnectedSlice(
      record: _record(
        'scene-proxy',
        'general-lore',
        'Scene Reference',
        baseTime,
      ),
      manuscriptNode: ManuscriptNodeReference(
        id: 'scene-1',
        projectId: 'project-a',
        nodeType: 'scene',
        title: 'Noxmere Meeting',
        createdAt: baseTime,
        updatedAt: baseTime,
      ),
      link: RecordLink(
        id: 'proxy-scene',
        sourceId: 'scene-proxy',
        targetId: 'scene-1',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: baseTime,
        updatedAt: baseTime,
      ),
    );
    await repository.putConnectedSlice(
      record: _record(
        'chapter-proxy',
        'general-lore',
        'Chapter Reference',
        baseTime,
      ),
      manuscriptNode: ManuscriptNodeReference(
        id: 'chapter-1',
        projectId: 'project-a',
        nodeType: 'chapter',
        title: 'Noxmere Chapter',
        createdAt: baseTime,
        updatedAt: baseTime,
      ),
      link: RecordLink(
        id: 'proxy-chapter',
        sourceId: 'chapter-proxy',
        targetId: 'chapter-1',
        typeId: 'relatedTo',
        scopeId: 'project-a',
        direction: RecordLinkDirection.undirected,
        createdAt: baseTime,
        updatedAt: baseTime,
      ),
    );
    final connections = ConnectionEngine(
      scopeId: 'project-a',
      repository: repository,
    );
    await connections.connect(
      sourceId: character.id,
      targetId: faction.id,
      typeId: 'memberOf',
      timestamp: baseTime.add(const Duration(minutes: 1)),
    );
    await connections.connect(
      sourceId: character.id,
      targetId: 'scene-1',
      typeId: 'appearsIn',
      timestamp: baseTime.add(const Duration(minutes: 2)),
    );
    await connections.connect(
      sourceId: event.id,
      targetId: character.id,
      typeId: 'involves',
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );
    await connections.connect(
      sourceId: codex.id,
      targetId: faction.id,
      typeId: 'documents',
      timestamp: baseTime.add(const Duration(minutes: 4)),
    );
    await connections.connect(
      sourceId: 'scene-1',
      targetId: 'chapter-1',
      typeId: 'partOf',
      timestamp: baseTime.add(const Duration(minutes: 5)),
    );
    await records.updateRecord(location.copyWith(
      title: 'Noxmere Harbor',
      updatedAt: baseTime.add(const Duration(minutes: 6)),
    ));

    final events = await history.getAuditHistory();

    expect(
        events.map((item) => item.recordType).toSet(),
        containsAll({
          'character',
          'location',
          'faction',
          'research-entry',
          'historical-event',
          'scene',
        }));
    expect(
      events
          .where((item) => item.changeType == AuditChangeType.connectionAdded),
      hasLength(5),
    );
    expect(
      events.any((item) =>
          item.recordId == 'noxmere' &&
          item.changeType == AuditChangeType.renamed),
      isTrue,
    );
    expect(await repository.manuscriptNodeById('scene-1'), isNotNull);
    expect(await repository.manuscriptNodeById('chapter-1'), isNotNull);
  });

  test('versions and audits survive close/reopen and portable archive',
      () async {
    await database.close();
    final directory =
        await Directory.systemTemp.createTemp('authoros-history-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}history.sqlite');
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    final first =
        RecordService(projectId: 'project-a', repository: firstRepository);
    final created =
        await first.createRecord(_character('kali', 'Kali', baseTime));
    await first.updateRecord(created.copyWith(
      title: 'Kali Vale',
      updatedAt: baseTime.add(const Duration(minutes: 1)),
    ));
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopenedHistory = VersionAuditService(
      projectId: 'project-a',
      repository: reopenedRepository,
    );
    expect(await reopenedHistory.getRecordVersionCount('kali'), 2);

    const archives = AuthorOsArchiveService();
    final bytes = archives.exportSnapshot(
      await reopenedRepository.snapshot(),
      archiveId: 'history-archive',
      rootId: 'project-a',
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: baseTime,
    );
    final restored = archives.importSnapshot(bytes);
    expect(restored.versions, hasLength(2));
    expect(restored.auditEvents, hasLength(2));
    expect(restored.versions.first.snapshot['title'], 'Kali');

    final restoredDatabase = AuthorOsDatabase(NativeDatabase.memory());
    final restoredRepository = DriftConnectedDomainRepository(restoredDatabase);
    await restoredRepository.replaceSnapshot(restored);
    expect(
      await VersionAuditService(
        projectId: 'project-a',
        repository: restoredRepository,
      ).getRecordVersionCount('kali'),
      2,
    );
    await restoredDatabase.close();
    await reopenedDatabase.close();
  });
}

AuthorRecord _character(
  String id,
  String title,
  DateTime timestamp, {
  String projectId = 'project-a',
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      canonStatus: CanonStatus.canon,
      title: title,
      templateId: 'character',
      templateVersion: 1,
      fields: {'identity.fullName': title},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

AuthorRecord _faction(String id, DateTime timestamp) => AuthorRecord(
      id: id,
      typeId: 'faction',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      canonStatus: CanonStatus.canon,
      title: 'Widow Network',
      fields: const {},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

AuthorRecord _record(
  String id,
  String typeId,
  String title,
  DateTime timestamp, {
  Map<String, Object?> fields = const {},
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      canonStatus: CanonStatus.canon,
      title: title,
      fields: fields,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
