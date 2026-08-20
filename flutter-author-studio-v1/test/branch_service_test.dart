import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_engine.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late BranchService branches;
  final timestamp = DateTime.utc(2026, 8, 19);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    branches = BranchService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('project, series, and book scopes preserve shared canon statuses',
      () async {
    final records = [
      _character('project-character', timestamp),
      _character(
        'series-character',
        timestamp,
        scopeType: RecordScopeType.series,
        scopeId: 'series-a',
        seriesId: 'series-a',
        canonStatus: CanonStatus.draft,
      ),
      _character(
        'book-character',
        timestamp,
        scopeType: RecordScopeType.book,
        scopeId: 'book-a',
        seriesId: 'series-a',
        bookId: 'book-a',
        canonStatus: CanonStatus.nonCanon,
      ),
    ];
    for (final record in records) {
      await branches.records.createRecord(record);
    }

    final stored = await repository.recordsByProject('project-a');

    expect(stored.map((record) => record.scopeType).toSet(), {
      RecordScopeType.project,
      RecordScopeType.series,
      RecordScopeType.book,
    });
    expect(stored.map((record) => record.canonStatus).toSet(), {
      CanonStatus.canon,
      CanonStatus.draft,
      CanonStatus.nonCanon,
    });
  });

  test('parent override and child hide never mutate canonical record',
      () async {
    final canonical = _character('kali', timestamp);
    await branches.records.createRecord(canonical);
    await branches.createBranch(_branch(
      'branch-a',
      timestamp,
      kind: BranchKind.whatIf,
    ));
    await branches.createBranch(_branch(
      'branch-child',
      timestamp,
      parentId: 'branch-a',
      kind: BranchKind.alternateEnding,
    ));
    await branches.overrideRecord(
      'branch-a',
      canonical.id,
      title: 'Kali of Endovier',
      fields: const {'centralGoal': 'Remain in Endovier'},
      canonStatus: CanonStatus.alternate,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    final inherited = (await branches.recordsForBranch('branch-child'))
        .singleWhere((record) => record.id == canonical.id);
    final reloadedCanon = await repository.recordById(canonical.id);

    expect(inherited.title, 'Kali of Endovier');
    expect(inherited.canonStatus, CanonStatus.alternate);
    expect(inherited.branchId, 'branch-child');
    expect(reloadedCanon?.title, 'kali');
    expect(reloadedCanon?.fields, {'identity.fullName': 'kali'});
    expect(reloadedCanon?.canonStatus, CanonStatus.canon);
    expect(reloadedCanon?.branchId, isNull);

    await branches.hideRecord('branch-child', canonical.id);
    expect(
      (await branches.recordsForBranch('branch-child'))
          .where((record) => record.id == canonical.id),
      isEmpty,
    );
    expect(
      (await repository.recordById(canonical.id))?.toJson(),
      reloadedCanon?.toJson(),
    );
  });

  test('branch-created records and connections remain branch-isolated',
      () async {
    final kali = _character('kali', timestamp);
    final faction = _faction('widow-network', timestamp);
    await branches.records.createRecord(kali);
    await branches.records.createRecord(faction);
    await branches.createBranch(_branch(
      'branch-a',
      timestamp,
      kind: BranchKind.alternateUniverse,
    ));
    final created = _character(
      'alternate-heir',
      timestamp,
      scopeType: RecordScopeType.branch,
      scopeId: 'branch-a',
      branchId: 'branch-a',
      canonStatus: CanonStatus.alternate,
    );
    await branches.createRecord('branch-a', created, timestamp: timestamp);
    final alternateLink = RecordLink(
      id: 'alternate-member',
      sourceId: created.id,
      targetId: faction.id,
      typeId: 'memberOf',
      scopeId: 'project-a',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await branches.addConnection('branch-a', alternateLink);

    expect(
      (await branches.recordsForBranch('branch-a')).map((record) => record.id),
      contains(created.id),
    );
    expect((await branches.linksForBranch('branch-a')).single.id,
        alternateLink.id);
    expect(await repository.recordById(created.id), isNull);
    expect(await repository.backlinks(faction.id), isEmpty);
  });

  test('template provenance stays readable across persisted override',
      () async {
    final canonical = _character('kali', timestamp);
    await branches.records.createRecord(canonical);
    await branches.createBranch(_branch(
      'branch-a',
      timestamp,
      kind: BranchKind.draft,
    ));
    await branches.overrideRecord(
      'branch-a',
      canonical.id,
      fields: const {'personality.summary': 'More cautious'},
    );
    final resolved = (await branches.recordsForBranch('branch-a')).single;

    expect(resolved.templateId, canonical.templateId);
    expect(resolved.templateVersion, canonical.templateVersion);
    expect(
      TemplateEngine(await branches.records.registry())
          .inspect(resolved)
          .isReadable,
      isTrue,
    );
  });

  test('branches and overlays survive database close, reopen, and archive',
      () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('authoros-branch-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}branch.sqlite');
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    final first =
        BranchService(projectId: 'project-a', repository: firstRepository);
    await first.records.createRecord(_character('kali', timestamp));
    await first.records.createRecord(_faction('widow-network', timestamp));
    final canonicalLink = RecordLink(
      id: 'canon-member',
      sourceId: 'kali',
      targetId: 'widow-network',
      typeId: 'memberOf',
      scopeId: 'project-a',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await firstRepository.putLink(canonicalLink);
    await first.createBranch(_branch(
      'branch-a',
      timestamp,
      kind: BranchKind.alternateTimeline,
    ));
    await first.overrideRecord(
      'branch-a',
      'kali',
      title: 'Kali Remained',
      canonStatus: CanonStatus.alternate,
    );
    await first.hideConnection('branch-a', canonicalLink.id);
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopened =
        BranchService(projectId: 'project-a', repository: reopenedRepository);
    final resolved = (await reopened.recordsForBranch('branch-a'))
        .singleWhere((record) => record.id == 'kali');
    final snapshot = await reopenedRepository.snapshot();
    const archive = AuthorOsArchiveService();
    final bytes = archive.exportSnapshot(
      snapshot,
      archiveId: 'branch-archive',
      rootId: 'project-a',
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: timestamp,
    );
    final restored = archive.importSnapshot(bytes);

    expect(resolved.title, 'Kali Remained');
    expect((await reopenedRepository.recordById('kali'))?.title, 'kali');
    expect((await reopenedRepository.backlinks('kali')).single.id,
        canonicalLink.id);
    expect(await reopened.linksForBranch('branch-a'), isEmpty);
    expect(restored.branches.single.id, 'branch-a');
    expect(restored.branchRecordOverlays.single.state,
        BranchRecordState.overridden);
    expect(restored.branchLinkOverlays.single.state, BranchLinkState.hidden);
    expect(
      BranchEngine(
        branches: restored.branches,
        recordOverlays: restored.branchRecordOverlays,
      )
          .resolveRecord(
            restored.records.singleWhere((record) => record.id == 'kali'),
            'branch-a',
          )
          ?.title,
      'Kali Remained',
    );
    await reopenedDatabase.close();
  });
}

StoryBranch _branch(
  String id,
  DateTime timestamp, {
  String? parentId,
  BranchKind kind = BranchKind.draft,
}) =>
    StoryBranch(
      id: id,
      projectId: 'project-a',
      name: id,
      kind: kind,
      parentBranchId: parentId,
      createdAt: timestamp,
    );

AuthorRecord _character(
  String id,
  DateTime timestamp, {
  RecordScopeType scopeType = RecordScopeType.project,
  String scopeId = 'project-a',
  String? seriesId,
  String? bookId,
  String? branchId,
  CanonStatus canonStatus = CanonStatus.canon,
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: scopeType,
      scopeId: scopeId,
      projectId: 'project-a',
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: id,
      templateId: 'character',
      templateVersion: 1,
      fields: {'identity.fullName': id},
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
      title: id,
      fields: const {},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
