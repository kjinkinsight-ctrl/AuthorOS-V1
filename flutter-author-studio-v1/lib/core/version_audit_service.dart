import 'dart:convert';

import '../persistence/authoros_database.dart';
import 'branch_domain.dart';
import 'connected_domain.dart';
import 'version_audit.dart';

class VersionAuditService {
  const VersionAuditService({
    required this.projectId,
    required this.repository,
    this.source = 'authoros',
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final String source;

  Future<({RecordVersion version, AuditEvent audit})> forRecord(
    AuthorRecord record, {
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
    Map<String, Object?> metadata = const {},
  }) =>
      _build(
        entityId: record.id,
        entityKind: VersionEntityKind.record,
        recordId: record.id,
        recordType: record.typeId,
        seriesId: record.seriesId,
        bookId: record.bookId,
        branchId: record.branchId,
        partitionProjectId: record.projectId ?? record.scopeId,
        schemaVersion: record.schemaVersion,
        snapshot: record.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
        metadata: metadata,
      );

  Future<({RecordVersion version, AuditEvent audit})> forConnection(
    RecordLink link, {
    required String recordId,
    required String recordType,
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
    String? branchId,
    VersionEntityKind entityKind = VersionEntityKind.connection,
    Map<String, Object?> metadata = const {},
  }) =>
      _build(
        entityId: link.id,
        entityKind: entityKind,
        recordId: recordId,
        recordType: recordType,
        branchId: branchId,
        schemaVersion: 1,
        snapshot: link.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
        metadata: metadata,
      );

  /// History for a manuscript node (chapter or scene).
  ///
  /// Manuscript nodes are entities in the same connected store as records, but
  /// they are not [AuthorRecord]s, so they cannot go through [forRecord]. They
  /// still belong in the one shared history system, so this builds the same
  /// [RecordVersion]/[AuditEvent] pair from the node reference. The snapshot is
  /// the node reference itself: manuscript body text stays in the manuscript
  /// store and is never copied into history.
  Future<({RecordVersion version, AuditEvent audit})> forManuscriptNode(
    ManuscriptNodeReference node, {
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
    Map<String, Object?> metadata = const {},
  }) =>
      _build(
        entityId: node.id,
        entityKind: VersionEntityKind.record,
        recordId: node.id,
        recordType: node.nodeType,
        schemaVersion: 1,
        snapshot: node.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
        metadata: metadata,
      );

  Future<({RecordVersion version, AuditEvent audit})> forBranch(
    StoryBranch branch, {
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
  }) =>
      _build(
        entityId: branch.id,
        entityKind: VersionEntityKind.branch,
        recordId: branch.id,
        recordType: 'branch',
        branchId: branch.id,
        schemaVersion: 1,
        snapshot: branch.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
      );

  Future<({RecordVersion version, AuditEvent audit})> forRecordOverlay(
    BranchRecordOverlay overlay, {
    required String recordType,
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
    Map<String, Object?> metadata = const {},
  }) =>
      _build(
        entityId: 'branch-record:${overlay.branchId}:${overlay.recordId}',
        entityKind: VersionEntityKind.branchRecord,
        recordId: overlay.recordId,
        recordType: recordType,
        branchId: overlay.branchId,
        schemaVersion: overlay.createdRecord?.schemaVersion ?? 1,
        snapshot: overlay.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
        metadata: metadata,
      );

  Future<({RecordVersion version, AuditEvent audit})> forLinkOverlay(
    BranchLinkOverlay overlay, {
    required String recordId,
    required String recordType,
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
  }) =>
      _build(
        entityId: 'branch-link:${overlay.branchId}:${overlay.linkId}',
        entityKind: VersionEntityKind.branchConnection,
        recordId: recordId,
        recordType: recordType,
        branchId: overlay.branchId,
        schemaVersion: 1,
        snapshot: overlay.toJson(),
        changeType: changeType,
        summary: summary,
        timestamp: timestamp,
      );

  Future<RecordVersion?> getVersion(String versionId) =>
      repository.versionById(versionId, projectId);

  Future<List<RecordVersion>> getVersionHistory({
    required String recordId,
    String? branchId,
  }) =>
      repository.versionHistory(HistoryFilter(
        projectId: projectId,
        recordId: recordId,
        branchId: branchId,
      ));

  /// The version chain for [record], read from the partition it was written to.
  ///
  /// A shared record's history is stamped with its provenance book, so reading
  /// it from a second book in the series has to ask for that partition rather
  /// than the caller's own. Records this book owns resolve to the same value
  /// [getVersionHistory] would have used.
  Future<List<RecordVersion>> getVersionHistoryForRecord(
    AuthorRecord record, {
    String? branchId,
  }) =>
      repository.versionHistory(HistoryFilter(
        projectId: record.projectId ?? record.scopeId,
        recordId: record.id,
        branchId: branchId,
      ));

  Future<List<AuditEvent>> getAuditHistory({
    String? recordId,
    String? recordType,
    String? seriesId,
    String? bookId,
    String? branchId,
    AuditChangeType? changeType,
    DateTime? from,
    DateTime? to,
  }) =>
      repository.auditHistory(HistoryFilter(
        projectId: projectId,
        recordId: recordId,
        recordType: recordType,
        seriesId: seriesId,
        bookId: bookId,
        branchId: branchId,
        changeType: changeType,
        from: from,
        to: to,
      ));

  Future<RecordVersion?> getVersionAt(
    String recordId,
    DateTime timestamp, {
    String? branchId,
  }) async {
    final versions = await repository.versionHistory(HistoryFilter(
      projectId: projectId,
      recordId: recordId,
      branchId: branchId,
      to: timestamp,
    ));
    return versions.lastOrNull;
  }

  Future<int> getRecordVersionCount(
    String recordId, {
    String? branchId,
  }) async =>
      (await getVersionHistory(recordId: recordId, branchId: branchId)).length;

  Future<RecordVersion?> getLatestVersion(
    String entityId, {
    String? branchId,
  }) =>
      repository.latestVersion(
        projectId: projectId,
        entityId: entityId,
        branchId: branchId,
      );

  Future<List<AuditEvent>> getChangesSince(DateTime timestamp) =>
      repository.auditHistory(HistoryFilter(
        projectId: projectId,
        from: timestamp,
      ));

  Future<({RecordVersion version, AuditEvent audit})> _build({
    required String entityId,
    required VersionEntityKind entityKind,
    required String recordId,
    required String recordType,
    required int schemaVersion,
    required Map<String, Object?> snapshot,
    required AuditChangeType changeType,
    required String summary,
    required DateTime timestamp,
    String? seriesId,
    String? bookId,
    String? branchId,
    String? partitionProjectId,
    Map<String, Object?> metadata = const {},
  }) async {
    // A record's history belongs to the record, not to whoever opened it. A
    // shared record is edited from several books, so partitioning by the
    // calling service's projectId would start a second chain at sequence 1 for
    // every book that touched it. Provenance never changes across promote and
    // demote, which is what makes it a stable partition key.
    final partition = partitionProjectId ?? projectId;
    final normalizedTime = timestamp.toUtc();
    final previous = await repository.latestVersion(
      projectId: partition,
      entityId: entityId,
      branchId: branchId,
    );
    final sequence =
        ((previous?.metadata['sequence'] as num?)?.toInt() ?? 0) + 1;
    final versionId = 'version-${_encode(entityId)}-'
        '${normalizedTime.microsecondsSinceEpoch}-$sequence';
    final version = RecordVersion(
      id: versionId,
      entityId: entityId,
      entityKind: entityKind,
      recordId: recordId,
      recordType: recordType,
      projectId: partition,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      createdAt: normalizedTime,
      changeType: changeType,
      summary: summary,
      schemaVersion: schemaVersion,
      previousVersionId: previous?.id,
      source: source,
      snapshot: snapshot,
      metadata: {...metadata, 'sequence': sequence},
    );
    final audit = AuditEvent(
      id: 'audit-$versionId',
      versionId: versionId,
      entityId: entityId,
      entityKind: entityKind,
      recordId: recordId,
      recordType: recordType,
      projectId: partition,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      createdAt: normalizedTime,
      changeType: changeType,
      summary: summary,
      source: source,
      metadata: {...metadata, 'sequence': sequence},
    );
    return (version: version, audit: audit);
  }
}

String _encode(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');
