import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_engine.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 19);

  test('project, series, book, canon statuses, and branch kinds serialize', () {
    for (final status in CanonStatus.values) {
      final restored = AuthorRecord.fromJson(
        _record('record-${status.name}', timestamp, canonStatus: status)
            .toJson(),
      );
      expect(restored.canonStatus, status);
    }
    expect(
      RecordScope.fromJson(const RecordScope(
        type: RecordScopeType.series,
        id: 'series-a',
        projectId: 'project-a',
        seriesId: 'series-a',
      ).toJson())
          .type,
      RecordScopeType.series,
    );
    expect(
      RecordScope.fromJson(const RecordScope(
        type: RecordScopeType.book,
        id: 'book-a',
        projectId: 'project-a',
        seriesId: 'series-a',
        bookId: 'book-a',
      ).toJson())
          .type,
      RecordScopeType.book,
    );
    expect(BranchKind.values, hasLength(5));
  });

  test('child branch inherits parent override without mutating canon', () {
    final canonical = _record('kali', timestamp);
    final engine = BranchEngine(
      branches: [
        _branch('branch-a', timestamp),
        _branch('branch-child', timestamp, parentId: 'branch-a'),
      ],
      recordOverlays: [
        BranchRecordOverlay(
          branchId: 'branch-a',
          recordId: 'kali',
          state: BranchRecordState.overridden,
          title: 'Kali of Endovier',
          fields: const {'centralGoal': 'Remain in Endovier'},
          canonStatus: CanonStatus.alternate,
          updatedAt: timestamp.add(const Duration(minutes: 1)),
        ),
      ],
    );

    final branchRecord = engine.resolveRecord(canonical, 'branch-child')!;

    expect(branchRecord.title, 'Kali of Endovier');
    expect(branchRecord.fields['centralGoal'], 'Remain in Endovier');
    expect(branchRecord.canonStatus, CanonStatus.alternate);
    expect(branchRecord.branchId, 'branch-child');
    expect(canonical.title, 'Kali Vale');
    expect(canonical.fields, {'identity.fullName': 'Kali Vale'});
    expect(canonical.branchId, isNull);
    expect(canonical.canonStatus, CanonStatus.canon);
  });

  test('branch-created and hidden records resolve by lineage', () {
    final canonical = _record('kali', timestamp);
    final created = _record(
      'alternate-heir',
      timestamp,
      scopeType: RecordScopeType.branch,
      scopeId: 'branch-a',
      branchId: 'branch-a',
      canonStatus: CanonStatus.alternate,
    );
    final engine = BranchEngine(
      branches: [
        _branch('branch-a', timestamp),
        _branch('branch-child', timestamp, parentId: 'branch-a'),
      ],
      recordOverlays: [
        BranchRecordOverlay(
          branchId: 'branch-a',
          recordId: 'kali',
          state: BranchRecordState.hidden,
          updatedAt: timestamp,
        ),
        BranchRecordOverlay(
          branchId: 'branch-a',
          recordId: created.id,
          state: BranchRecordState.created,
          createdRecord: created,
          updatedAt: timestamp,
        ),
      ],
    );

    final records = engine.recordsForBranch([canonical], 'branch-child');

    expect(records.map((record) => record.id), ['alternate-heir']);
    expect(engine.stateFor('kali', 'branch-a'), BranchRecordState.hidden);
    expect(engine.stateFor('unknown', 'branch-a'), BranchRecordState.inherited);
  });

  test('branch link changes do not mutate canonical connections', () {
    final canonical = _link('canon-link', timestamp);
    final alternate = _link('alternate-link', timestamp);
    final engine = BranchEngine(
      branches: [_branch('branch-a', timestamp)],
      linkOverlays: [
        BranchLinkOverlay(
          branchId: 'branch-a',
          linkId: canonical.id,
          state: BranchLinkState.hidden,
          updatedAt: timestamp,
        ),
        BranchLinkOverlay(
          branchId: 'branch-a',
          linkId: alternate.id,
          state: BranchLinkState.added,
          link: alternate,
          updatedAt: timestamp,
        ),
      ],
    );

    expect(engine.linksForBranch([canonical], 'branch-a').single.id,
        'alternate-link');
    expect(canonical.id, 'canon-link');
  });

  test('template provenance remains compatible across branch overrides', () {
    final canonical = _record('kali', timestamp);
    final engine = BranchEngine(
      branches: [_branch('branch-a', timestamp)],
      recordOverlays: [
        BranchRecordOverlay(
          branchId: 'branch-a',
          recordId: canonical.id,
          state: BranchRecordState.overridden,
          fields: const {'personality.summary': 'More cautious'},
          updatedAt: timestamp,
        ),
      ],
    );
    final resolved = engine.resolveRecord(canonical, 'branch-a')!;

    expect(resolved.templateId, canonical.templateId);
    expect(resolved.templateVersion, canonical.templateVersion);
    expect(
      TemplateEngine(BuiltInRecordTypes.registry())
          .inspect(resolved)
          .isReadable,
      isTrue,
    );
  });
}

StoryBranch _branch(String id, DateTime timestamp, {String? parentId}) =>
    StoryBranch(
      id: id,
      projectId: 'project-a',
      name: id,
      parentBranchId: parentId,
      createdAt: timestamp,
    );

AuthorRecord _record(
  String id,
  DateTime timestamp, {
  RecordScopeType scopeType = RecordScopeType.project,
  String scopeId = 'project-a',
  String? branchId,
  CanonStatus canonStatus = CanonStatus.canon,
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: scopeType,
      scopeId: scopeId,
      projectId: 'project-a',
      branchId: branchId,
      canonStatus: canonStatus,
      title: id == 'kali' ? 'Kali Vale' : id,
      templateId: 'character',
      templateVersion: 1,
      fields: {'identity.fullName': id == 'kali' ? 'Kali Vale' : id},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

RecordLink _link(String id, DateTime timestamp) => RecordLink(
      id: id,
      sourceId: 'kali',
      targetId: 'faction',
      typeId: 'memberOf',
      scopeId: 'project-a',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
