import 'dart:convert';

import '../persistence/authoros_database.dart';
import 'built_in_connection_types.dart';
import 'connected_domain.dart';
import 'connection_types.dart';
import 'relationship_validation.dart';
import 'version_audit.dart';
import 'version_audit_service.dart';

class ConnectionEngine {
  ConnectionEngine({
    required this.scopeId,
    required this.repository,
    ConnectionTypeRegistry? registry,
  }) : registry = registry ?? BuiltInConnectionTypes.registry();

  final String scopeId;
  final DriftConnectedDomainRepository repository;
  final ConnectionTypeRegistry registry;

  VersionAuditService get history => VersionAuditService(
        projectId: scopeId,
        repository: repository,
      );

  Future<RecordLink> connect({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    if (sourceId.trim().isEmpty ||
        targetId.trim().isEmpty ||
        typeId.trim().isEmpty) {
      throw ArgumentError('Connection source, target, and type are required.');
    }
    if (sourceId == targetId) {
      throw ArgumentError('A record cannot connect to itself.');
    }
    final source = await repository.relationshipEndpoint(sourceId);
    final target = await repository.relationshipEndpoint(targetId);
    if (!source.exists || !target.exists) {
      throw StateError('Connection endpoints must exist in $scopeId.');
    }
    if (source.projectId != scopeId || target.projectId != scopeId) {
      throw StateError('Connection endpoints must exist in $scopeId.');
    }
    if (source.typeId == null || target.typeId == null) {
      throw StateError('Connection endpoint types could not be resolved.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final identity = base64Url
        .encode(utf8.encode('$scopeId|$sourceId|$typeId|$targetId'))
        .replaceAll('=', '');
    final link = RecordLink(
      id: 'link-$identity',
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      scopeId: scopeId,
      direction: direction,
      label: label,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
    final validation = RelationshipValidator(registry).validate(
      relationship: link,
      projectId: scopeId,
      source: source,
      target: target,
    );
    if (!validation.isValid) {
      throw StateError(validation.errorSummary!);
    }
    final existing = await repository.outgoingLinks(sourceId);
    for (final candidate in existing) {
      if (candidate.targetId == targetId &&
          candidate.typeId == typeId &&
          candidate.direction == direction) {
        return candidate;
      }
    }
    final entry = await history.forConnection(
      link,
      recordId: sourceId,
      recordType: source.typeId!,
      changeType: AuditChangeType.connectionAdded,
      summary: 'Added $typeId connection to $targetId',
      timestamp: now,
      metadata: {'targetId': targetId, 'connectionType': typeId},
    );
    await repository.putLinkWithHistory(
      link: link,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return link;
  }

  Future<RecordLink> updateConnection(
    String linkId, {
    String? typeId,
    String? label,
    Map<String, Object?>? metadata,
    DateTime? timestamp,
  }) async {
    final snapshot = await repository.snapshot();
    final existing =
        snapshot.links.where((link) => link.id == linkId).firstOrNull;
    if (existing == null || existing.scopeId != scopeId) {
      throw StateError('Connection $linkId does not belong to $scopeId.');
    }
    final source = await repository.relationshipEndpoint(existing.sourceId);
    final target = await repository.relationshipEndpoint(existing.targetId);
    final sourceType = source.typeId;
    if (sourceType == null || target.typeId == null) {
      throw StateError('Connection endpoints could not be resolved.');
    }
    final nextType = typeId ?? existing.typeId;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final updated = RecordLink(
      id: existing.id,
      sourceId: existing.sourceId,
      targetId: existing.targetId,
      typeId: nextType,
      scopeId: existing.scopeId,
      direction: existing.direction,
      label: label ?? existing.label,
      revision: existing.revision + 1,
      metadata: metadata ?? existing.metadata,
      createdAt: existing.createdAt,
      updatedAt: now,
      extensionData: existing.extensionData,
    );
    final validation = RelationshipValidator(registry).validate(
      relationship: updated,
      projectId: scopeId,
      source: source,
      target: target,
    );
    if (!validation.isValid) {
      throw StateError(validation.errorSummary!);
    }
    final changeType = nextType != existing.typeId
        ? AuditChangeType.connectionTypeChanged
        : AuditChangeType.connectionMetadataChanged;
    final entry = await history.forConnection(
      updated,
      recordId: existing.sourceId,
      recordType: sourceType,
      changeType: changeType,
      summary: '${changeType.name} for ${existing.id}',
      timestamp: now,
      metadata: {
        'targetId': existing.targetId,
        'previousType': existing.typeId,
        'newType': updated.typeId,
        'previousMetadata': existing.metadata,
        'newMetadata': updated.metadata,
      },
    );
    await repository.putLinkWithHistory(
      link: updated,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return updated;
  }

  Future<List<RecordLink>> connections(String entityId) async {
    await _requireEntity(entityId);
    return repository.backlinks(entityId);
  }

  Future<List<RecordLink>> outgoing(String entityId) async {
    await _requireEntity(entityId);
    return repository.outgoingLinks(entityId);
  }

  Future<List<RecordLink>> incoming(String entityId) async {
    await _requireEntity(entityId);
    return repository.incomingLinks(entityId);
  }

  Future<List<AuthorRecord>> linkedRecords(String entityId) async {
    final links = await connections(entityId);
    final records = <AuthorRecord>[];
    for (final link in links) {
      final linkedId =
          link.sourceId == entityId ? link.targetId : link.sourceId;
      final record = await repository.recordById(linkedId);
        if (record != null &&
          (record.projectId ?? record.scopeId) == scopeId) {
        records.add(record);
      }
    }
    return records;
  }

  Future<void> disconnect(String linkId, {DateTime? timestamp}) async {
    final snapshot = await repository.snapshot();
    final link = snapshot.links.where((item) => item.id == linkId).firstOrNull;
    if (link == null) {
      return;
    }
    if (link.scopeId != scopeId) {
      throw StateError('Connection does not belong to $scopeId.');
    }
    final sourceType = await repository.entityTypeId(link.sourceId);
    if (sourceType == null) {
      throw StateError('Connection source could not be resolved.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final entry = await history.forConnection(
      link,
      recordId: link.sourceId,
      recordType: sourceType,
      changeType: AuditChangeType.connectionRemoved,
      summary: 'Removed ${link.typeId} connection to ${link.targetId}',
      timestamp: now,
      metadata: {'targetId': link.targetId, 'connectionType': link.typeId},
    );
    await repository.deleteLinkWithHistory(
      linkId: linkId,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> _requireEntity(String entityId) async {
    if (await repository.entityProjectId(entityId) != scopeId) {
      throw StateError('Entity $entityId does not belong to $scopeId.');
    }
  }
}
