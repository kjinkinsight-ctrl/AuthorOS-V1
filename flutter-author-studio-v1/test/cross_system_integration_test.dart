import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/record_inspector.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/safe_delete_service.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/core/version_audit_service.dart';
import 'package:author_studio_v1/migrations/legacy_reference_models.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/cross_system_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthorOsDatabase database;
  late CrossSystemFixtureContext fixture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    fixture = await CrossSystemFixture.build(
      DriftConnectedDomainRepository(database),
    );
  });

  tearDown(() => database.close());

  test('fixture builds one project, series, book, branch, and connected graph',
      () async {
    final snapshot = await fixture.repository.snapshot();
    final projectRecords = snapshot.records
        .where((record) => record.projectId == CrossSystemFixture.projectA)
        .toList();

    expect(
        projectRecords.map((record) => record.typeId).toSet(),
        containsAll({
          'series',
          'book',
          'chapter',
          'scene',
          'character',
          'location',
          'faction',
          'organisation',
          'item',
          'research-entry',
          'historical-event',
          'plotline',
          'character-arc',
          'beat',
        }));
    expect(snapshot.branches.single.id, CrossSystemFixture.branchId);
    expect(
        fixture.links.keys,
        containsAll({
          'characterFaction',
          'characterLocation',
          'characterItem',
          'characterScene',
          'sceneChapter',
          'chapterBook',
          'codexCharacter',
          'codexLocation',
          'timelineCharacter',
          'timelineLocation',
          'plotCharacter',
          'plotScene',
          'plotLocation',
          'codexTimeline',
          'codexPlot',
          'timelinePlot',
          'sceneLocation',
          'sceneTimeline',
          'characterArc',
          'arcPlot',
          'firstBeatPlot',
          'secondBeatPlot',
          'secondBeatScene',
        }));
    expect(
        snapshot.links.map((link) => link.typeId).toSet(),
        containsAll({
          'memberOf',
          'livesIn',
          'owns',
          'appearsIn',
          'partOf',
          'documents',
          'involves',
          'occursAt',
          'relatedTo',
          'hasArc',
        }));
    expect(
      snapshot.manuscriptNodes.map((node) => node.id),
      containsAll([CrossSystemFixture.chapterId, CrossSystemFixture.sceneId]),
    );
    final manuscript = await fixture.manuscript.loadStudio(
      CrossSystemFixture.projectA,
      manuscriptTitle: 'unused',
      defaultChapters: const [],
    );
    final scene = manuscript.sceneById(CrossSystemFixture.sceneId)!;
    expect(scene.pov, CrossSystemFixture.kaliId);
    expect(scene.location, CrossSystemFixture.endovierId);
    expect(
        scene.relationships.map((relationship) => relationship.targetId),
        containsAll([
          CrossSystemFixture.kaliId,
          CrossSystemFixture.endovierId,
          CrossSystemFixture.timelineId,
          CrossSystemFixture.secondBeatId,
        ]));
  });

  test('all fifteen cross-system relationship directions resolve by stable ID',
      () async {
    final expected = <String, (String, String)>{
      'characterLocation': (
        CrossSystemFixture.kaliId,
        CrossSystemFixture.endovierId
      ),
      'codexCharacter': (CrossSystemFixture.codexId, CrossSystemFixture.kaliId),
      'timelineCharacter': (
        CrossSystemFixture.timelineId,
        CrossSystemFixture.kaliId
      ),
      'plotCharacter': (CrossSystemFixture.plotId, CrossSystemFixture.kaliId),
      'characterScene': (CrossSystemFixture.kaliId, CrossSystemFixture.sceneId),
      'codexLocation': (
        CrossSystemFixture.codexId,
        CrossSystemFixture.endovierId
      ),
      'timelineLocation': (
        CrossSystemFixture.timelineId,
        CrossSystemFixture.endovierId
      ),
      'plotLocation': (
        CrossSystemFixture.plotId,
        CrossSystemFixture.endovierId
      ),
      'codexTimeline': (
        CrossSystemFixture.codexId,
        CrossSystemFixture.timelineId
      ),
      'codexPlot': (CrossSystemFixture.codexId, CrossSystemFixture.plotId),
      'timelinePlot': (
        CrossSystemFixture.timelineId,
        CrossSystemFixture.plotId
      ),
      'plotScene': (CrossSystemFixture.plotId, CrossSystemFixture.sceneId),
      'sceneCharacter': (CrossSystemFixture.kaliId, CrossSystemFixture.sceneId),
      'sceneLocation': (
        CrossSystemFixture.sceneId,
        CrossSystemFixture.endovierId
      ),
      'sceneTimeline': (
        CrossSystemFixture.sceneId,
        CrossSystemFixture.timelineId
      ),
    };

    for (final entry in expected.entries) {
      final link = entry.key == 'sceneCharacter'
          ? fixture.links['characterScene']!
          : fixture.links[entry.key]!;
      expect(link.sourceId, entry.value.$1, reason: entry.key);
      expect(link.targetId, entry.value.$2, reason: entry.key);

      final source = (await fixture.inspector.inspectRecord(link.sourceId))!;
      final target = (await fixture.inspector.inspectRecord(link.targetId))!;
      expect(
        source.outgoingConnections
            .any((connection) => connection.target.id == link.targetId),
        isTrue,
        reason: '${entry.key} outgoing',
      );
      expect(
        target.incomingConnections
            .any((connection) => connection.source.id == link.sourceId),
        isTrue,
        reason: '${entry.key} inverse',
      );
    }
  });

  test('Universal Search spans every fixture domain and isolates projects',
      () async {
    final cases = <String, (String, String, SearchDestination)>{
      'Kali Vale': (
        CrossSystemFixture.kaliId,
        'character',
        SearchDestination.characterStudio,
      ),
      'Endovier': (
        CrossSystemFixture.endovierId,
        'location',
        SearchDestination.worldStudio,
      ),
      'Widow Network': (
        CrossSystemFixture.widowNetworkId,
        'faction',
        SearchDestination.worldStudio,
      ),
      'holdings': (
        CrossSystemFixture.codexId,
        'research-entry',
        SearchDestination.storyCodex,
      ),
      'changes': (
        CrossSystemFixture.timelineId,
        'historical-event',
        SearchDestination.timelineStudio,
      ),
      'confronts': (
        CrossSystemFixture.plotId,
        'plotline',
        SearchDestination.plotStudio,
      ),
      'carrying': (
        CrossSystemFixture.sceneId,
        'scene',
        SearchDestination.manuscriptStudio,
      ),
      'returns': (
        CrossSystemFixture.chapterId,
        'chapter',
        SearchDestination.manuscriptStudio,
      ),
    };

    for (final entry in cases.entries) {
      final results = await fixture.search.searchAll(entry.key);
      expect(results.map((candidate) => candidate.recordId),
          contains(entry.value.$1),
          reason: entry.key);
      final result = results
          .singleWhere((candidate) => candidate.recordId == entry.value.$1);
      expect(result.recordType, entry.value.$2, reason: entry.key);
      expect(result.projectId, CrossSystemFixture.projectA, reason: entry.key);
      expect(result.navigationTarget.destination, entry.value.$3,
          reason: entry.key);
    }
    expect(
      (await fixture.search.searchAll('Kali Vale'))
          .map((result) => result.recordId),
      isNot(contains('project-b-kali')),
    );
    expect(
      (await fixture.search.searchBySeries(
        'Endovier',
        CrossSystemFixture.seriesId,
      ))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.endovierId),
    );
    expect(
      (await fixture.search.searchByBook(
        'Chapter',
        CrossSystemFixture.bookId,
      ))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.chapterId),
    );
    for (final entry in <String, String>{
      'Endovier Chronicles': CrossSystemFixture.seriesId,
      'Book One': CrossSystemFixture.bookNodeId,
      'Kali Vale': CrossSystemFixture.kaliId,
      'Endovier': CrossSystemFixture.endovierId,
      'Widow Network': CrossSystemFixture.widowNetworkId,
      'House Noxmere Codex': CrossSystemFixture.codexId,
      'The Fall of House Noxmere': CrossSystemFixture.timelineId,
      'The Red Widow Arc': CrossSystemFixture.plotId,
      "Kali's Return": CrossSystemFixture.characterArcId,
      'Return to Endovier': CrossSystemFixture.firstBeatId,
      'Confront House Noxmere': CrossSystemFixture.secondBeatId,
      'Chapter 14': CrossSystemFixture.chapterId,
      'Scene 3: The Red Knife': CrossSystemFixture.sceneId,
    }.entries) {
      expect(
        (await fixture.search.searchAll(entry.key))
            .map((result) => result.recordId),
        contains(entry.value),
        reason: entry.key,
      );
    }
  });

  test('FTS stays synchronized with record mutations', () async {
    const rewritten =
        'Kali crosses the obsidian causeway carrying the red knife.';
    final scene =
        (await fixture.records.getRecord(CrossSystemFixture.sceneId))!;
    await fixture.records.updateRecord(scene.copyWith(
      fields: const {'content': rewritten},
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(days: 1)),
    ));

    // The fixture holds this scene twice under one id: as a `scene` record,
    // and as the manuscript node an author actually types into. Scene prose
    // became searchable when it moved out of the manuscript blob and into the
    // database, so the old phrase only leaves the index once both copies have
    // moved on. Rewriting the record alone would say nothing about the node.
    final manuscript = await fixture.manuscript.loadStudio(
      CrossSystemFixture.projectA,
      manuscriptTitle: 'Book One',
      defaultChapters: const [],
    );
    await fixture.manuscript.saveStudio(
      manuscript.copyWith(
        chapters: [
          for (final chapter in manuscript.chapters)
            chapter.copyWith(
              scenes: [
                for (final sceneNode in chapter.scenes)
                  sceneNode.id == CrossSystemFixture.sceneId
                      ? sceneNode.copyWith(content: rewritten)
                      : sceneNode,
              ],
            ),
        ],
      ),
    );

    expect(
      (await fixture.search.searchAll('obsidian causeway'))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.sceneId),
    );
    expect(
      (await fixture.search.searchAll('enters Endovier'))
          .map((result) => result.recordId),
      isNot(contains(CrossSystemFixture.sceneId)),
    );
  });

  test('Inspector reads every domain, dependencies, and performs no writes',
      () async {
    final before = (await fixture.repository.snapshot()).toJson();
    for (final expectation in <String, String>{
      CrossSystemFixture.kaliId: 'character',
      CrossSystemFixture.endovierId: 'location',
      CrossSystemFixture.widowNetworkId: 'faction',
      CrossSystemFixture.codexId: 'research-entry',
      CrossSystemFixture.timelineId: 'historical-event',
      CrossSystemFixture.plotId: 'plotline',
      CrossSystemFixture.characterArcId: 'character-arc',
      CrossSystemFixture.firstBeatId: 'beat',
      CrossSystemFixture.secondBeatId: 'beat',
      CrossSystemFixture.sceneId: 'scene',
      CrossSystemFixture.chapterId: 'chapter',
    }.entries) {
      final result = (await fixture.inspector.inspectRecord(expectation.key))!;
      expect(result.recordType, expectation.value, reason: expectation.key);
      expect(result.projectId, CrossSystemFixture.projectA);
      expect(result.canonStatus, CanonStatus.canon);
      expect(result.template.compatibility.isReadable, isTrue);
      expect(result.validation.state, isNot(InspectionValidationState.error));
      expect(result.history.versionCount, greaterThan(0));
    }
    final kali = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;
    expect(kali.outgoingConnections, hasLength(greaterThanOrEqualTo(4)));
    expect(kali.incomingConnections, hasLength(greaterThanOrEqualTo(3)));
    expect(kali.safeDelete.hasDependencies, isTrue);
    expect((await fixture.repository.snapshot()).toJson(), before);
  });

  test('Version Audit chains status scope template and connection changes',
      () async {
    var kali = (await fixture.records.getRecord(CrossSystemFixture.kaliId))!;
    kali = await fixture.records.updateRecord(kali.copyWith(
      title: 'Kali Vale Revised',
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
    ));
    final templateChanged = AuthorRecord(
      id: kali.id,
      typeId: kali.typeId,
      scopeType: kali.scopeType,
      scopeId: kali.scopeId,
      projectId: kali.projectId,
      seriesId: kali.seriesId,
      bookId: kali.bookId,
      canonStatus: CanonStatus.proposed,
      title: kali.title,
      status: kali.status,
      schemaVersion: kali.schemaVersion,
      templateId: 'protagonist',
      templateVersion: 2,
      revision: kali.revision,
      fields: kali.fields,
      tags: kali.tags,
      createdAt: kali.createdAt,
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 2)),
      extensionData: kali.extensionData,
    );
    await fixture.records.updateRecord(templateChanged);
    await fixture.records.archiveRecord(
      CrossSystemFixture.codexId,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 3)),
    );
    await fixture.records.restoreRecord(
      CrossSystemFixture.codexId,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 4)),
    );
    await fixture.records.changeScope(
      CrossSystemFixture.houseNoxmereId,
      scopeType: RecordScopeType.series,
      scopeId: CrossSystemFixture.seriesId,
      seriesId: CrossSystemFixture.seriesId,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 5)),
    );
    final temporary = await fixture.connections.connect(
      sourceId: CrossSystemFixture.kaliId,
      targetId: CrossSystemFixture.houseNoxmereId,
      typeId: 'relatedTo',
      direction: RecordLinkDirection.undirected,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 6)),
    );
    await fixture.connections.updateConnection(
      temporary.id,
      label: 'Connected through Noxmere',
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 7)),
    );
    await fixture.connections.disconnect(
      temporary.id,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 8)),
    );

    final kaliHistory = (await fixture.history.getVersionHistory(
      recordId: CrossSystemFixture.kaliId,
    ))
        .where((version) => version.entityKind == VersionEntityKind.record)
        .toList();
    expect(
        kaliHistory.map((version) => version.changeType),
        containsAll([
          AuditChangeType.created,
          AuditChangeType.renamed,
          AuditChangeType.templateChanged,
        ]));
    for (var index = 1; index < kaliHistory.length; index++) {
      expect(kaliHistory[index].previousVersionId, kaliHistory[index - 1].id);
    }
    final events = await fixture.history.getAuditHistory();
    expect(
        events.map((event) => event.changeType),
        containsAll([
          AuditChangeType.archived,
          AuditChangeType.restored,
          AuditChangeType.scopeChanged,
          AuditChangeType.connectionAdded,
          AuditChangeType.connectionMetadataChanged,
          AuditChangeType.connectionRemoved,
        ]));
    final connectionHistory = await fixture.repository.versionHistory(
      HistoryFilter(
        projectId: CrossSystemFixture.projectA,
        recordId: CrossSystemFixture.kaliId,
      ),
    );
    final temporaryHistory = connectionHistory
        .where((version) => version.entityId == temporary.id)
        .toList();
    expect(temporaryHistory, hasLength(3));
    expect((temporaryHistory.first.snapshot['label'] as String), isEmpty);
    expect(
      temporaryHistory[1].snapshot['label'],
      'Connected through Noxmere',
    );
    expect(
        await fixture.repository.backlinks(CrossSystemFixture.kaliId),
        isNot(contains(
            predicate<RecordLink>((link) => link.id == temporary.id))));
  });

  test(
      'branch state, search, Inspector, history, and connections stay isolated',
      () async {
    final canonBefore =
        (await fixture.repository.recordById(CrossSystemFixture.kaliId))!
            .toJson();
    final canonHistoryBefore = await fixture.history.getVersionHistory(
      recordId: CrossSystemFixture.kaliId,
    );
    await fixture.branches.overrideRecord(
      CrossSystemFixture.branchId,
      CrossSystemFixture.kaliId,
      title: 'Kali Never Left',
      fields: const {'centralGoal': 'Guard Endovier'},
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
    );
    final branchHistory = (await fixture.history.getVersionHistory(
      recordId: CrossSystemFixture.kaliId,
      branchId: CrossSystemFixture.branchId,
    ))
        .where(
            (version) => version.entityKind == VersionEntityKind.branchRecord)
        .toList();
    await fixture.branches.restoreVersion(
      branchHistory.first.id,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 2)),
    );

    final canonSearch = await fixture.search.searchAll('Alternate Red Knife');
    final branchSearch = await fixture.search.searchByBranch(
      'Alternate Red Knife',
      CrossSystemFixture.branchId,
    );
    final overrideSearch = await fixture.search.searchByBranch(
      'Kali Remained',
      CrossSystemFixture.branchId,
    );
    final hiddenSearch = await fixture.search.searchByBranch(
      'House Noxmere',
      CrossSystemFixture.branchId,
    );
    final inspection = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
      branchId: CrossSystemFixture.branchId,
    ))!;

    expect(canonSearch, isEmpty);
    expect(branchSearch.single.recordId, CrossSystemFixture.branchItemId);
    expect(overrideSearch.single.title, 'Kali Remained');
    expect(hiddenSearch.map((result) => result.recordId),
        isNot(contains(CrossSystemFixture.hiddenRecordId)));
    expect(inspection.title, 'Kali Remained');
    expect(inspection.scope.branchState, BranchRecordState.overridden);
    expect(inspection.history.versionCount, 3);
    expect(
      inspection.outgoingConnections.map((connection) => connection.target.id),
      contains(CrossSystemFixture.branchItemId),
    );
    expect(
      inspection.outgoingConnections.map((connection) => connection.target.id),
      isNot(contains(CrossSystemFixture.knifeId)),
    );
    expect(
      (await fixture.repository.recordById(CrossSystemFixture.kaliId))!
          .toJson(),
      canonBefore,
    );
    expect(
      (await fixture.history.getVersionHistory(
        recordId: CrossSystemFixture.kaliId,
      ))
          .map((version) => version.toJson()),
      canonHistoryBefore.map((version) => version.toJson()),
    );
  });

  test('Safe Delete produces blocked, warning, and safe dispositions read-only',
      () async {
    final before = (await fixture.repository.snapshot()).toJson();
    final blockedCharacter =
        (await fixture.safeDelete.analyze(CrossSystemFixture.kaliId))!;
    final blockedLocation =
        (await fixture.safeDelete.analyze(CrossSystemFixture.endovierId))!;
    final blockedFaction =
        (await fixture.safeDelete.analyze(CrossSystemFixture.widowNetworkId))!;
    final blockedCodex =
        (await fixture.safeDelete.analyze(CrossSystemFixture.codexId))!;
    final blockedScene =
        (await fixture.safeDelete.analyze(CrossSystemFixture.sceneId))!;
    final warning =
        (await fixture.safeDelete.analyze(CrossSystemFixture.warningRecordId))!;
    final safe =
        (await fixture.safeDelete.analyze(CrossSystemFixture.safeRecordId))!;

    for (final result in [
      blockedCharacter,
      blockedLocation,
      blockedFaction,
      blockedCodex,
      blockedScene,
    ]) {
      expect(result.disposition, SafeDeleteDisposition.blocked,
          reason: result.recordId);
    }
    expect(warning.disposition, SafeDeleteDisposition.safeWithWarnings);
    expect(safe.disposition, SafeDeleteDisposition.safe);
    expect(safe.physicallyDeletable, isTrue);
    expect((await fixture.repository.snapshot()).toJson(), before);
  });

  test('legacy migration is deterministic, idempotent, audited, and searchable',
      () async {
    const reference = LegacyReference(
      id: 'legacy-owner:protagonist',
      legacyReference: 'Kali Vale',
      source: 'StoryCodexEntry.relationships',
      sourceEntityId: CrossSystemFixture.legacyOwnerId,
      fieldPath: 'relationships.protagonist',
      expectedRecordTypes: ['character'],
    );
    final first = await fixture.migration.migrate(
      ownerRecordId: CrossSystemFixture.legacyOwnerId,
      reference: reference,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
    );
    final versionCount = await fixture.history.getRecordVersionCount(
      CrossSystemFixture.legacyOwnerId,
    );
    final second = await fixture.migration.migrate(
      ownerRecordId: CrossSystemFixture.legacyOwnerId,
      reference: reference,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 2)),
    );
    final owner = (await fixture.records.getRecord(
      CrossSystemFixture.legacyOwnerId,
    ))!;

    expect(first.persisted, isTrue);
    expect(first.candidate.resolvedRecordId, CrossSystemFixture.kaliId);
    expect(second.persisted, isFalse);
    expect(second.candidate.resolutionState,
        LegacyReferenceResolutionState.alreadyMigrated);
    expect(owner.fields['legacyRelationships'], {'protagonist': 'Kali Vale'});
    expect(owner.fields['unknownLegacyData'], {'preserve': true});
    expect(
      await fixture.history.getRecordVersionCount(
        CrossSystemFixture.legacyOwnerId,
      ),
      versionCount,
    );
    expect(
      (await fixture.search.searchAll(CrossSystemFixture.kaliId))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.legacyOwnerId),
    );
  });

  test(
      'ambiguous migration leaves records, connections, versions, and audits intact',
      () async {
    await fixture.records.createRecord(AuthorRecord(
      id: 'character-kali-draft',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: CrossSystemFixture.projectA,
      projectId: CrossSystemFixture.projectA,
      canonStatus: CanonStatus.draft,
      title: 'Kali Vale',
      templateId: 'character',
      templateVersion: 1,
      fields: const {'identity.fullName': 'Kali Vale'},
      createdAt: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
    ));
    final before = (await fixture.repository.snapshot()).toJson();
    const reference = LegacyReference(
      id: 'ambiguous-kali',
      legacyReference: 'Kali Vale',
      source: 'ManuscriptScene.pov',
      sourceEntityId: CrossSystemFixture.legacyOwnerId,
      fieldPath: 'pov',
      expectedRecordTypes: ['character'],
    );

    final result = await fixture.migration.migrate(
      ownerRecordId: CrossSystemFixture.legacyOwnerId,
      reference: reference,
    );

    expect(result.persisted, isFalse);
    expect(result.candidate.resolutionState,
        LegacyReferenceResolutionState.ambiguous);
    expect(result.candidate.candidateRecordIds,
        [CrossSystemFixture.kaliId, 'character-kali-draft']);
    expect((await fixture.repository.snapshot()).toJson(), before);
  });

  test(
      'template metadata, compatibility, Inspector, Search, and history integrate',
      () async {
    final before =
        (await fixture.records.getRecord(CrossSystemFixture.kaliId))!;
    final inspectionBefore = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;
    expect(inspectionBefore.template.id, 'protagonist');
    expect(inspectionBefore.template.recordVersion, 1);
    expect(inspectionBefore.template.availableVersion, 2);
    expect(inspectionBefore.template.parentTemplateId, 'character');
    expect(inspectionBefore.template.compatibility.status,
        TemplateCompatibilityStatus.upgradeAvailable);

    final changed = AuthorRecord(
      id: before.id,
      typeId: before.typeId,
      scopeType: before.scopeType,
      scopeId: before.scopeId,
      projectId: before.projectId,
      seriesId: before.seriesId,
      bookId: before.bookId,
      canonStatus: before.canonStatus,
      title: before.title,
      status: before.status,
      schemaVersion: before.schemaVersion,
      templateId: before.templateId,
      templateVersion: 2,
      revision: before.revision,
      fields: before.fields,
      tags: before.tags,
      createdAt: before.createdAt,
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
      extensionData: before.extensionData,
    );
    await fixture.records.updateRecord(changed);

    final inspectionAfter = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;
    expect(inspectionAfter.template.compatibility.status,
        TemplateCompatibilityStatus.current);
    expect(
      (await fixture.history.getVersionHistory(
        recordId: CrossSystemFixture.kaliId,
      ))
          .last
          .changeType,
      AuditChangeType.templateChanged,
    );
    expect(
      (await fixture.search.searchByType('Kali', 'character'))
          .singleWhere((result) => result.recordId == CrossSystemFixture.kaliId)
          .templateId,
      'protagonist',
    );
  });

  test(
      'restore creates version 4 and preserves graph, search, Inspector, and safety',
      () async {
    var kali = (await fixture.records.getRecord(CrossSystemFixture.kaliId))!;
    kali = await fixture.records.updateRecord(kali.copyWith(
      title: 'Kali Version Two',
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 1)),
    ));
    await fixture.records.updateRecord(kali.copyWith(
      title: 'Kali Version Three',
      updatedAt: CrossSystemFixture.timestamp.add(const Duration(hours: 2)),
    ));
    final firstVersion = (await fixture.history.getVersion(
      fixture.initialKaliVersionId,
    ))!;
    final firstJson = firstVersion.toJson();

    await fixture.records.restoreVersion(
      firstVersion.id,
      timestamp: CrossSystemFixture.timestamp.add(const Duration(hours: 3)),
    );
    final versions = (await fixture.history.getVersionHistory(
      recordId: CrossSystemFixture.kaliId,
    ))
        .where((version) => version.entityKind == VersionEntityKind.record)
        .toList();
    final inspection = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;

    expect(versions, hasLength(4));
    expect(versions.first.toJson(), firstJson);
    expect(versions.last.changeType, AuditChangeType.restored);
    expect(versions.last.previousVersionId, versions[2].id);
    expect(inspection.history.latestVersion?.id, versions.last.id);
    expect(inspection.title, 'Kali Vale');
    expect(inspection.validation.state, isNot(InspectionValidationState.error));
    expect(
      (await fixture.search.searchAll('Kali Vale'))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.kaliId),
    );
    expect(
      (await fixture.safeDelete.analyze(CrossSystemFixture.kaliId))
          ?.disposition,
      SafeDeleteDisposition.blocked,
    );
    expect(
      await fixture.repository.backlinks(CrossSystemFixture.kaliId),
      hasLength(greaterThanOrEqualTo(7)),
    );
  });

  test(
      'validation detects invalid template, connection, reference, branch, and scope then repairs',
      () async {
    final now = CrossSystemFixture.timestamp.add(const Duration(hours: 10));
    final valid = (await fixture.records.getRecord(CrossSystemFixture.kaliId))!;
    await fixture.repository.putRecord(AuthorRecord(
      id: valid.id,
      typeId: valid.typeId,
      scopeType: RecordScopeType.book,
      scopeId: 'wrong-book',
      projectId: valid.projectId,
      seriesId: null,
      bookId: null,
      canonStatus: valid.canonStatus,
      title: valid.title,
      templateId: 'missing-template',
      templateVersion: 99,
      fields: valid.fields,
      createdAt: valid.createdAt,
      updatedAt: now,
    ));
    await fixture.repository.putLink(RecordLink(
      id: 'invalid-typed-link',
      sourceId: CrossSystemFixture.kaliId,
      targetId: CrossSystemFixture.endovierId,
      typeId: 'memberOf',
      scopeId: CrossSystemFixture.projectA,
      createdAt: now,
      updatedAt: now,
    ));
    await fixture.repository.putBranchLinkOverlay(BranchLinkOverlay(
      branchId: CrossSystemFixture.branchId,
      linkId: 'broken-reference',
      state: BranchLinkState.added,
      updatedAt: now,
      link: RecordLink(
        id: 'broken-reference',
        sourceId: CrossSystemFixture.kaliId,
        targetId: 'missing-record',
        typeId: 'relatedTo',
        scopeId: CrossSystemFixture.projectA,
        direction: RecordLinkDirection.undirected,
        createdAt: now,
        updatedAt: now,
      ),
    ));

    final invalidCanon = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;
    final invalidBranch = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
      branchId: CrossSystemFixture.branchId,
    ))!;
    expect(
        invalidCanon.validation.issues.map((issue) => issue.code),
        containsAll([
          'unknown-template',
          'invalid-scope-hierarchy',
          'invalid-connection'
        ]));
    expect(invalidBranch.validation.issues.map((issue) => issue.code),
        contains('broken-reference'));

    await fixture.repository.deleteLink('invalid-typed-link');
    await fixture.repository.putBranchLinkOverlay(BranchLinkOverlay(
      branchId: CrossSystemFixture.branchId,
      linkId: 'broken-reference',
      state: BranchLinkState.hidden,
      updatedAt: now.add(const Duration(minutes: 1)),
    ));
    await fixture.repository.putRecord(valid.copyWith(
      updatedAt: now.add(const Duration(minutes: 1)),
    ));

    final repairedCanon = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
    ))!;
    final repairedBranch = (await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
      branchId: CrossSystemFixture.branchId,
    ))!;
    expect(
        repairedCanon.validation.state, isNot(InspectionValidationState.error));
    expect(repairedBranch.validation.state,
        isNot(InspectionValidationState.error));
  });

  test('Search Inspector and Safe Delete are jointly read-only', () async {
    final before = (await fixture.repository.snapshot()).toJson();

    await fixture.search.searchAll('Kali');
    await fixture.search.searchByBranch('Kali', CrossSystemFixture.branchId);
    await fixture.inspector.inspectRecord(CrossSystemFixture.kaliId);
    await fixture.inspector.inspectRecord(
      CrossSystemFixture.kaliId,
      branchId: CrossSystemFixture.branchId,
    );
    await fixture.safeDelete.analyze(CrossSystemFixture.kaliId);

    expect((await fixture.repository.snapshot()).toJson(), before);
  });

  test('archive import and database reopen preserve the complete foundation',
      () async {
    const archiveService = AuthorOsArchiveService();
    final bytes = archiveService.exportSnapshot(
      await fixture.repository.snapshot(),
      archiveId: 'cross-system-fixture',
      rootId: CrossSystemFixture.projectA,
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: CrossSystemFixture.timestamp,
    );
    final directory = await Directory.systemTemp.createTemp('cross-system-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}fixture.sqlite');
    final importedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final importedRepository = DriftConnectedDomainRepository(importedDatabase);
    await importedRepository
        .replaceSnapshot(archiveService.importSnapshot(bytes));
    await importedDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopened = await CrossSystemFixtureContext.fromRepository(
      reopenedRepository,
    );

    final snapshot = await reopenedRepository.snapshot();
    expect(snapshot.records.map((record) => record.id),
        contains(CrossSystemFixture.kaliId));
    expect(snapshot.links, hasLength(greaterThanOrEqualTo(13)));
    expect(snapshot.branches.single.id, CrossSystemFixture.branchId);
    expect(snapshot.branchRecordOverlays, hasLength(3));
    expect(snapshot.versions, isNotEmpty);
    expect(snapshot.auditEvents, isNotEmpty);
    expect(
      (await reopened.search.searchAll('Kali Vale'))
          .map((result) => result.recordId),
      contains(CrossSystemFixture.kaliId),
    );
    expect(
      (await reopened.search.searchByBranch(
        'Alternate Red Knife',
        CrossSystemFixture.branchId,
      ))
          .single
          .recordId,
      CrossSystemFixture.branchItemId,
    );
    expect(
      (await reopened.inspector.inspectRecord(
        CrossSystemFixture.kaliId,
        branchId: CrossSystemFixture.branchId,
      ))
          ?.title,
      'Kali Remained',
    );
    expect(
      (await reopened.safeDelete.analyze(CrossSystemFixture.kaliId))
          ?.disposition,
      SafeDeleteDisposition.blocked,
    );
    await reopenedDatabase.close();
  });

  test(
      'project isolation holds across search Inspector history safety branches and links',
      () async {
    final searchB = UniversalSearchService(
      projectId: CrossSystemFixture.projectB,
      repository: fixture.repository,
    );
    final inspectorB = UniversalRecordInspector(
      projectId: CrossSystemFixture.projectB,
      repository: fixture.repository,
    );
    final historyB = VersionAuditService(
      projectId: CrossSystemFixture.projectB,
      repository: fixture.repository,
    );
    final safeDeleteB = SafeDeleteService(
      projectId: CrossSystemFixture.projectB,
      repository: fixture.repository,
    );

    expect(
      (await fixture.search.searchAll('Kali Vale'))
          .map((result) => result.recordId),
      isNot(contains('project-b-kali')),
    );
    expect((await searchB.searchAll('Kali Vale')).single.recordId,
        'project-b-kali');
    expect(await fixture.inspector.inspectRecord('project-b-kali'), isNull);
    expect(await inspectorB.inspectRecord(CrossSystemFixture.kaliId), isNull);
    expect(
      (await historyB.getAuditHistory())
          .every((event) => event.projectId == CrossSystemFixture.projectB),
      isTrue,
    );
    expect(await fixture.safeDelete.analyze('project-b-kali'), isNull);
    expect((await safeDeleteB.analyze('project-b-kali'))?.affectedRecords,
        isNot(contains(CrossSystemFixture.kaliId)));
    expect(
      (await fixture.repository.branchesByProject(CrossSystemFixture.projectB)),
      isEmpty,
    );
    expect(
      (await fixture.repository.backlinks('project-b-kali')),
      isEmpty,
    );
  });

  test('performance sanity remains bounded on a moderate deterministic project',
      () async {
    final additions = <AuthorRecord>[];
    for (var index = 0; index < 300; index++) {
      additions.add(AuthorRecord(
        id: 'scale-$index',
        typeId: 'general-lore',
        scopeType: RecordScopeType.project,
        scopeId: CrossSystemFixture.projectA,
        projectId: CrossSystemFixture.projectA,
        title: 'Scale Record $index',
        fields: {'content': 'scale-token-$index bounded fixture'},
        createdAt: CrossSystemFixture.timestamp,
        updatedAt: CrossSystemFixture.timestamp,
      ));
    }
    await fixture.repository.putRecordsAndLinks(
      records: additions,
      links: const [],
    );
    final stopwatch = Stopwatch()..start();

    final search = await fixture.search.searchAll('scale-token-299');
    final inspection = await fixture.inspector.inspectRecord('scale-299');

    stopwatch.stop();
    expect(search.single.recordId, 'scale-299');
    expect(inspection?.recordId, 'scale-299');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
  });
}
