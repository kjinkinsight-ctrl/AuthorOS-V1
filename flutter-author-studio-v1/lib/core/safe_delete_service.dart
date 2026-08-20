import '../migrations/legacy_reference_migration.dart';
import '../migrations/legacy_reference_models.dart';
import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'record_inspection.dart';
import 'record_inspector.dart';
import 'safe_delete.dart';

class SafeDeleteService {
  const SafeDeleteService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  UniversalRecordInspector get inspector => UniversalRecordInspector(
        projectId: projectId,
        repository: repository,
      );

  LegacyReferenceMigrationService get migration =>
      LegacyReferenceMigrationService(
        projectId: projectId,
        repository: repository,
      );

  Future<SafeDeleteAnalysis?> analyze(
    String recordId, {
    Iterable<LegacyReference> legacyReferences = const [],
  }) async {
    final inspection = await inspector.inspectRecord(recordId);
    if (inspection == null) return null;
    final snapshot = await repository.snapshot();
    final projectRecords = snapshot.records.where(
      (record) => (record.projectId ?? record.scopeId) == projectId,
    );
    final branchIds = <String>{};
    for (final overlay in snapshot.branchRecordOverlays) {
      if (overlay.recordId == recordId ||
          _containsStableReference(overlay.fields, recordId) ||
          _containsStableReference(
            overlay.createdRecord?.fields ?? const {},
            recordId,
          )) {
        final branch = snapshot.branches
            .where((candidate) => candidate.id == overlay.branchId)
            .firstOrNull;
        if (branch?.projectId == projectId) branchIds.add(overlay.branchId);
      }
    }
    for (final overlay in snapshot.branchLinkOverlays) {
      final link = overlay.link;
      if (link != null &&
          (link.sourceId == recordId || link.targetId == recordId)) {
        final branch = snapshot.branches
            .where((candidate) => candidate.id == overlay.branchId)
            .firstOrNull;
        if (branch?.projectId == projectId) branchIds.add(overlay.branchId);
      }
    }

    final persistedLegacy = <String>[];
    for (final owner in projectRecords) {
      final stable = owner.fields[legacyStableReferencesField];
      if (stable is! Map) continue;
      for (final entry in stable.entries) {
        final value = entry.value;
        if (value is Map && value['stableRecordId'] == recordId) {
          persistedLegacy.add('${owner.id}:${entry.key}');
        }
      }
    }
    final reportedLegacy = <String>[];
    for (final reference in legacyReferences) {
      final candidate = await migration.resolve(reference);
      if (candidate.resolvedRecordId == recordId ||
          candidate.candidateRecordIds.contains(recordId)) {
        reportedLegacy
            .add('${reference.sourceEntityId}:${reference.fieldPath}');
      }
    }
    final legacyDependencies = {...persistedLegacy, ...reportedLegacy}.toList()
      ..sort();
    final templateDependents = projectRecords
        .where(
            (record) => record.id != recordId && record.templateId == recordId)
        .map((record) => record.id)
        .toList()
      ..sort();

    final blocking = <String>[];
    if (inspection.incomingConnections.isNotEmpty) {
      blocking.add('Active incoming connections exist.');
    }
    if (inspection.outgoingConnections.isNotEmpty) {
      blocking.add('Active outgoing connections exist.');
    }
    if (inspection.references.isNotEmpty) {
      blocking.add('Stable-ID references depend on this record.');
    }
    if (branchIds.isNotEmpty) {
      blocking.add('Branch records or connections depend on this record.');
    }
    if (legacyDependencies.isNotEmpty) {
      blocking.add('Legacy or migrated references may depend on this record.');
    }
    if (templateDependents.isNotEmpty) {
      blocking.add('Records use this record ID as a template dependency.');
    }
    final warnings = <String>[];
    if (inspection.history.versionCount > 0 ||
        inspection.history.auditEventCount > 0) {
      warnings
          .add('Historical versions and audit events will remain immutable.');
    }
    if (inspection.lifecycleStatus == AuthorRecordStatus.active) {
      warnings
          .add('Archive or soft-delete the record before physical removal.');
    }
    final disposition = blocking.isNotEmpty
        ? SafeDeleteDisposition.blocked
        : warnings.isNotEmpty
            ? SafeDeleteDisposition.safeWithWarnings
            : SafeDeleteDisposition.safe;
    final references = inspection.references;
    final affectedRecords = {
      ...inspection.safeDelete.dependentEntityIds,
      ...templateDependents,
    }.toList()
      ..sort();
    final manuscriptNodes = references
        .where((reference) => {
              ReferenceKind.manuscript,
              ReferenceKind.chapter,
              ReferenceKind.scene,
            }.contains(reference.kind))
        .map((reference) => reference.entity.id)
        .toSet()
        .toList()
      ..sort();
    final archived = inspection.lifecycleStatus == AuthorRecordStatus.archived;
    final softDeleted =
        inspection.lifecycleStatus == AuthorRecordStatus.deleted;

    return SafeDeleteAnalysis(
      recordId: inspection.recordId,
      recordType: inspection.recordType,
      disposition: disposition,
      blockingReasons: List.unmodifiable(blocking),
      warnings: List.unmodifiable(warnings),
      incomingConnections: inspection.incomingConnections,
      outgoingConnections: inspection.outgoingConnections,
      references: references,
      legacyReferences: List.unmodifiable(legacyDependencies),
      affectedBranches: List.unmodifiable(branchIds.toList()..sort()),
      versionCount: inspection.history.versionCount,
      auditCount: inspection.history.auditEventCount,
      affectedRecords: List.unmodifiable(affectedRecords),
      affectedManuscriptNodes: List.unmodifiable(manuscriptNodes),
      templateDependentRecordIds: List.unmodifiable(templateDependents),
      archived: archived,
      softDeleted: softDeleted,
      physicallyDeletable: blocking.isEmpty && (archived || softDeleted),
    );
  }
}

bool _containsStableReference(Map<String, Object?> fields, String recordId) {
  final stable = fields[legacyStableReferencesField];
  if (stable is! Map) return false;
  return stable.values.any(
    (value) => value is Map && value['stableRecordId'] == recordId,
  );
}
