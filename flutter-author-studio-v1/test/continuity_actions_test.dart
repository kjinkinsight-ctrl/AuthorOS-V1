import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/continuity_actions.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ContinuityActionService actions;
  late TimelineService timeline;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    actions = ContinuityActionService(
      projectId: 'project-a',
      repository: repository,
    );
    timeline = TimelineService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('create from recommendation persists audits and refreshes search',
      () async {
    final result = await actions.createForRecommendation(
      _issue(ContinuityWarningType.unknownLocation),
      name: 'Signal Observatory',
      confirmed: true,
      recheck: () async {
        final matches = await timeline.search.searchAll('Signal Observatory');
        return matches.isEmpty;
      },
      timestamp: timestamp,
    );

    expect(result.status, ContinuityActionStatus.resolved);
    expect(result.recordId, isNotNull);
    expect(
      (await timeline.search.searchAll('Signal Observatory')).single.recordId,
      result.recordId,
    );
    expect(
      await timeline.history.getVersionHistory(recordId: result.recordId!),
      hasLength(1),
    );
    expect(
      await timeline.history.getAuditHistory(recordId: result.recordId!),
      hasLength(1),
    );
  });

  test('link from recommendation uses stable ids and connection audit',
      () async {
    final event = await timeline.createEvent(
      const TimelineEventDraft(id: 'event-1', name: 'Opening'),
      timestamp: timestamp,
    );
    final character = await actions.characters.createCharacter(
      id: 'character-1',
      displayName: 'Mara',
      timestamp: timestamp,
    );

    final result = await actions.linkForRecommendation(
      _issue(ContinuityWarningType.missingRelationship),
      sourceId: event.id,
      targetId: character.id,
      typeId: 'involves',
      confirmed: true,
      recheck: () async => (await timeline.connectionsFor(event.id)).isEmpty,
      timestamp: timestamp,
    );

    expect(result.status, ContinuityActionStatus.resolved);
    final links = await timeline.connectionsFor(event.id);
    expect(links.single.id, result.linkId);
    expect(links.single.targetId, character.id);
    expect(
      await timeline.history.getAuditHistory(
        recordId: event.id,
        changeType: AuditChangeType.connectionAdded,
      ),
      hasLength(1),
    );
  });

  test('fix review applies only after confirmation and records a version',
      () async {
    final event = await timeline.createEvent(
      const TimelineEventDraft(id: 'event-1', name: 'Opening'),
      timestamp: timestamp,
    );
    final result = await actions.reviewFixForRecommendation(
      _issue(ContinuityWarningType.invalidRange),
      recordId: event.id,
      proposedFields: const {'importance': 'critical'},
      confirmed: true,
      recheck: () => false,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    expect(result.status, ContinuityActionStatus.resolved);
    expect(
      (await timeline.getTimelineRecord(event.id))?.fields['importance'],
      'critical',
    );
    expect(await timeline.getTimelineHistory(event.id), hasLength(2));
  });

  test('cancel action does not mutate and warning remains', () async {
    final before = await repository.snapshot();
    final result = await actions.createForRecommendation(
      _issue(ContinuityWarningType.unknownCharacter),
      name: 'Mara',
      confirmed: false,
      timestamp: timestamp,
    );
    final after = await repository.snapshot();

    expect(result.status, ContinuityActionStatus.cancelled);
    expect(result.warningRemains, isTrue);
    expect(after.records, before.records);
    expect(after.versions, before.versions);
  });

  test('validation failure preserves warning and creates no record', () async {
    final result = await actions.createForRecommendation(
      _issue(ContinuityWarningType.unknownCharacter),
      name: '   ',
      confirmed: true,
      timestamp: timestamp,
    );

    expect(result.status, ContinuityActionStatus.failed);
    expect(result.warningRemains, isTrue);
    expect((await repository.snapshot()).records, isEmpty);
  });

  test('active branch create protects canon and records branch history',
      () async {
    await timeline.branches.createBranch(StoryBranch(
      id: 'alternate',
      projectId: 'project-a',
      name: 'Alternate',
      kind: BranchKind.whatIf,
      createdAt: timestamp,
    ));
    final branchActions = ContinuityActionService(
      projectId: 'project-a',
      repository: repository,
      activeBranchId: 'alternate',
    );

    final result = await branchActions.createForRecommendation(
      _issue(ContinuityWarningType.unknownCharacter),
      name: 'Branch Mara',
      confirmed: true,
      recheck: () => false,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    expect(result.status, ContinuityActionStatus.resolved);
    expect(await repository.recordById(result.recordId!), isNull);
    final branchRecords = await timeline.branches.recordsForBranch('alternate');
    expect(branchRecords.single.id, result.recordId);
    expect(branchRecords.single.canonStatus, CanonStatus.alternate);
    expect(
      await timeline.history.getVersionHistory(
        recordId: result.recordId!,
        branchId: 'alternate',
      ),
      hasLength(1),
    );
  });

  test('branch review creates an overlay and leaves canonical data unchanged',
      () async {
    final event = await timeline.createEvent(
      const TimelineEventDraft(
        id: 'event-1',
        name: 'Canon Opening',
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.branches.createBranch(StoryBranch(
      id: 'alternate',
      projectId: 'project-a',
      name: 'Alternate',
      kind: BranchKind.whatIf,
      createdAt: timestamp,
    ));
    final branchActions = ContinuityActionService(
      projectId: 'project-a',
      repository: repository,
      activeBranchId: 'alternate',
    );

    final result = await branchActions.reviewFixForRecommendation(
      _issue(ContinuityWarningType.impossibleSequence),
      recordId: event.id,
      proposedFields: const {'importance': 'critical'},
      confirmed: true,
      recheck: () => false,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    expect(result.status, ContinuityActionStatus.resolved);
    expect(
      (await timeline.getTimelineRecord(event.id))?.fields['importance'],
      'normal',
    );
    final branchRecord = (await timeline.query.all(branchId: 'alternate'))
        .singleWhere((record) => record.id == event.id);
    expect(branchRecord.fields['importance'], 'critical');
    expect(branchRecord.canonStatus, CanonStatus.canon);
  });

  test('successful mutation keeps warning when recheck still fails', () async {
    final result = await actions.createForRecommendation(
      _issue(ContinuityWarningType.unknownLocation),
      name: 'Unresolved Place',
      confirmed: true,
      recheck: () => true,
      timestamp: timestamp,
    );

    expect(result.status, ContinuityActionStatus.warningRemains);
    expect(result.warningRemains, isTrue);
    expect(result.mutationApplied, isTrue);
  });
}

ContinuityIntegrityIssue _issue(ContinuityWarningType type) {
  final warning = ContinuityWarning(
    type: type,
    severity: ContinuitySeverity.warning,
    title: 'Continuity recommendation',
    message: 'Resolve this issue.',
    eventIds: const ['event-1'],
  );
  return ContinuityAnalyzer.summaryFor([warning]).issues.single;
}
