import 'branch_domain.dart';
import 'connected_domain.dart';

class BranchEngine {
  BranchEngine({
    required Iterable<StoryBranch> branches,
    Iterable<BranchRecordOverlay> recordOverlays = const [],
    Iterable<BranchLinkOverlay> linkOverlays = const [],
  })  : _branches = {for (final branch in branches) branch.id: branch},
        _recordOverlays = recordOverlays.toList(),
        _linkOverlays = linkOverlays.toList() {
    _validate();
  }

  final Map<String, StoryBranch> _branches;
  final List<BranchRecordOverlay> _recordOverlays;
  final List<BranchLinkOverlay> _linkOverlays;

  List<StoryBranch> lineage(String branchId) {
    final result = <StoryBranch>[];
    final seen = <String>{};
    StoryBranch? current = _branches[branchId];
    if (current == null) throw StateError('Unknown branch: $branchId');
    while (current != null) {
      if (!seen.add(current.id)) {
        throw StateError('Branch inheritance cycle includes ${current.id}.');
      }
      result.add(current);
      final parentId = current.parentBranchId;
      current = parentId == null ? null : _branches[parentId];
    }
    return result.reversed.toList();
  }

  BranchRecordState stateFor(String recordId, String branchId) {
    var state = BranchRecordState.inherited;
    for (final branch in lineage(branchId)) {
      final overlay = _recordOverlay(branch.id, recordId);
      if (overlay != null) state = overlay.state;
    }
    return state;
  }

  AuthorRecord? resolveRecord(AuthorRecord canonical, String branchId) {
    final branch = _requireBranch(branchId);
    _requireProject(canonical, branch.projectId);
    AuthorRecord? resolved = canonical;
    for (final item in lineage(branchId)) {
      final overlay = _recordOverlay(item.id, canonical.id);
      if (overlay == null || overlay.state == BranchRecordState.inherited) {
        continue;
      }
      if (overlay.state == BranchRecordState.hidden) {
        resolved = null;
        continue;
      }
      if (overlay.state == BranchRecordState.created) {
        resolved = overlay.createdRecord;
        continue;
      }
      if (resolved == null) {
        throw StateError('Hidden record ${canonical.id} cannot be overridden.');
      }
      resolved = _apply(resolved, overlay, branchId);
    }
    return resolved;
  }

  List<AuthorRecord> recordsForBranch(
    Iterable<AuthorRecord> canonicalRecords,
    String branchId,
  ) {
    final branch = _requireBranch(branchId);
    final records = <String, AuthorRecord>{};
    for (final canonical in canonicalRecords) {
      _requireProject(canonical, branch.projectId);
      final resolved = resolveRecord(canonical, branchId);
      if (resolved != null) records[resolved.id] = resolved;
    }
    for (final item in lineage(branchId)) {
      for (final overlay in _recordOverlays.where(
        (candidate) =>
            candidate.branchId == item.id &&
            candidate.state == BranchRecordState.created,
      )) {
        final created = overlay.createdRecord!;
        final resolved = resolveRecord(created, branchId);
        if (resolved != null) records[resolved.id] = resolved;
      }
    }
    return records.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  List<RecordLink> linksForBranch(
    Iterable<RecordLink> canonicalLinks,
    String branchId,
  ) {
    _requireBranch(branchId);
    final links = {for (final link in canonicalLinks) link.id: link};
    for (final branch in lineage(branchId)) {
      for (final overlay
          in _linkOverlays.where((item) => item.branchId == branch.id)) {
        if (overlay.state == BranchLinkState.hidden) {
          links.remove(overlay.linkId);
        } else {
          links[overlay.linkId] = overlay.link!;
        }
      }
    }
    return links.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  AuthorRecord _apply(
    AuthorRecord base,
    BranchRecordOverlay overlay,
    String branchId,
  ) {
    final fields = Map<String, Object?>.from(base.fields)
      ..addAll(overlay.fields);
    for (final fieldId in overlay.removedFieldIds) {
      fields.remove(fieldId);
    }
    return AuthorRecord(
      id: base.id,
      typeId: base.typeId,
      scopeType: base.scopeType,
      scopeId: base.scopeId,
      projectId: base.projectId,
      seriesId: base.seriesId,
      bookId: base.bookId,
      branchId: branchId,
      canonStatus: overlay.canonStatus ?? base.canonStatus,
      title: overlay.title ?? base.title,
      status: base.status,
      schemaVersion: base.schemaVersion,
      templateId: base.templateId,
      templateVersion: base.templateVersion,
      revision: base.revision,
      fields: fields,
      tags: overlay.tags ?? List<String>.from(base.tags),
      createdAt: base.createdAt,
      updatedAt: overlay.updatedAt,
      extensionData: Map<String, Object?>.from(base.extensionData),
    );
  }

  void _validate() {
    for (final branch in _branches.values) {
      if (branch.id.trim().isEmpty ||
          branch.projectId.trim().isEmpty ||
          branch.name.trim().isEmpty) {
        throw const FormatException(
            'Branch identity and project are required.');
      }
      final parentId = branch.parentBranchId;
      if (parentId != null) {
        final parent = _branches[parentId];
        if (parent == null) {
          throw StateError('Branch ${branch.id} has unknown parent $parentId.');
        }
        if (parent.projectId != branch.projectId) {
          throw StateError('Parent and child branches must share a project.');
        }
      }
      lineage(branch.id);
    }
    final recordKeys = <String>{};
    for (final overlay in _recordOverlays) {
      _requireBranch(overlay.branchId);
      if (!recordKeys.add('${overlay.branchId}|${overlay.recordId}')) {
        throw StateError('A branch can have only one state per record.');
      }
      if (overlay.state == BranchRecordState.created) {
        final created = overlay.createdRecord;
        if (created == null ||
            created.id != overlay.recordId ||
            created.scopeType != RecordScopeType.branch ||
            created.branchId != overlay.branchId) {
          throw StateError('Branch-created records require branch ownership.');
        }
      } else if (overlay.createdRecord != null) {
        throw StateError('Only created overlays may contain a full record.');
      }
    }
    final linkKeys = <String>{};
    for (final overlay in _linkOverlays) {
      _requireBranch(overlay.branchId);
      if (!linkKeys.add('${overlay.branchId}|${overlay.linkId}')) {
        throw StateError('A branch can have only one state per link.');
      }
      if ((overlay.state == BranchLinkState.added) != (overlay.link != null)) {
        throw StateError('Added link overlays require exactly one link.');
      }
    }
  }

  StoryBranch _requireBranch(String id) {
    final branch = _branches[id];
    if (branch == null) throw StateError('Unknown branch: $id');
    return branch;
  }

  BranchRecordOverlay? _recordOverlay(String branchId, String recordId) =>
      _recordOverlays
          .where(
              (item) => item.branchId == branchId && item.recordId == recordId)
          .firstOrNull;

  void _requireProject(AuthorRecord record, String projectId) {
    final owner = record.projectId ??
        record.fields['projectId'] ??
        record.fields['_codex.projectId'] ??
        record.scopeId;
    if (owner != projectId) {
      throw StateError('Record ${record.id} does not belong to $projectId.');
    }
  }
}
