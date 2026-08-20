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
    Map<String, Object?> metadata = const {},
  }) async {
    final normalizedTime = timestamp.toUtc();
    final previous = await repository.latestVersion(
      projectId: projectId,
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
      projectId: projectId,
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
      projectId: projectId,
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
