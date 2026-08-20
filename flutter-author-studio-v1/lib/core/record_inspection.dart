import 'branch_domain.dart';
import 'connected_domain.dart';
import 'record_validation.dart';
import 'template_engine.dart';
import 'version_audit.dart';

enum InspectionValidationState { valid, warning, error }

enum ReferenceKind {
  manuscript,
  chapter,
  scene,
  codex,
  timeline,
  plot,
  world,
  map,
  universalRecord,
}

class InspectionEndpoint {
  const InspectionEndpoint({
    required this.id,
    required this.type,
    required this.title,
    required this.projectId,
    required this.exists,
    this.branchId,
  });

  final String id;
  final String type;
  final String title;
  final String projectId;
  final String? branchId;
  final bool exists;
}

class ConnectionInspection {
  const ConnectionInspection({
    required this.id,
    required this.typeId,
    required this.displayName,
    required this.inverseLabel,
    required this.source,
    required this.target,
    required this.direction,
    required this.metadata,
    required this.temporalMetadata,
    required this.temporalSupport,
    required this.valid,
    this.branchId,
    this.validationMessage,
  });

  final String id;
  final String typeId;
  final String displayName;
  final String inverseLabel;
  final InspectionEndpoint source;
  final InspectionEndpoint target;
  final RecordLinkDirection direction;
  final Map<String, Object?> metadata;
  final Map<String, Object?> temporalMetadata;
  final bool temporalSupport;
  final String? branchId;
  final bool valid;
  final String? validationMessage;
}

class ReferenceInspection {
  const ReferenceInspection({
    required this.kind,
    required this.entity,
    required this.connectionId,
    required this.connectionType,
    required this.incoming,
  });

  final ReferenceKind kind;
  final InspectionEndpoint entity;
  final String connectionId;
  final String connectionType;
  final bool incoming;
}

class HistoryInspection {
  const HistoryInspection({
    required this.versions,
    required this.auditEvents,
    this.latestVersion,
    this.latestAuditEvent,
  });

  final List<RecordVersion> versions;
  final List<AuditEvent> auditEvents;
  final RecordVersion? latestVersion;
  final AuditEvent? latestAuditEvent;

  int get versionCount => versions.length;
  int get auditEventCount => auditEvents.length;
  List<String> get versionIds => versions.map((version) => version.id).toList();
}

class TemplateInspection {
  const TemplateInspection({
    required this.id,
    required this.recordVersion,
    required this.compatibility,
    required this.inheritedTemplateIds,
    this.parentTemplateId,
    this.availableVersion,
  });

  final String id;
  final int recordVersion;
  final int? availableVersion;
  final String? parentTemplateId;
  final List<String> inheritedTemplateIds;
  final TemplateCompatibilityReport compatibility;
}

class ScopeInspection {
  const ScopeInspection({
    required this.projectId,
    required this.canonStatus,
    required this.lifecycleStatus,
    required this.branchState,
    required this.visible,
    this.seriesId,
    this.bookId,
    this.branchId,
  });

  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
  final AuthorRecordStatus lifecycleStatus;
  final BranchRecordState branchState;
  final bool visible;
}

class ValidationInspection {
  const ValidationInspection({
    required this.state,
    required this.issues,
  });

  final InspectionValidationState state;
  final List<RecordValidationIssue> issues;
}

class SafeDeleteInspection {
  const SafeDeleteInspection({
    required this.incomingConnectionCount,
    required this.outgoingConnectionCount,
    required this.knownReferenceCount,
    required this.branchDependencyCount,
    required this.versionCount,
    required this.dependentEntityIds,
  });

  final int incomingConnectionCount;
  final int outgoingConnectionCount;
  final int knownReferenceCount;
  final int branchDependencyCount;
  final int versionCount;
  final List<String> dependentEntityIds;

  bool get hasDependencies =>
      incomingConnectionCount > 0 ||
      outgoingConnectionCount > 0 ||
      knownReferenceCount > 0 ||
      branchDependencyCount > 0;
}

class InspectionCapabilities {
  const InspectionCapabilities({
    required this.supportedReferenceKinds,
    required this.unsupportedReferenceKinds,
    required this.limitations,
  });

  final List<ReferenceKind> supportedReferenceKinds;
  final List<ReferenceKind> unsupportedReferenceKinds;
  final List<String> limitations;
}

class UniversalRecordInspection {
  const UniversalRecordInspection({
    required this.recordId,
    required this.recordType,
    required this.title,
    required this.projectId,
    required this.canonStatus,
    required this.lifecycleStatus,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.outgoingConnections,
    required this.incomingConnections,
    required this.references,
    required this.history,
    required this.template,
    required this.scope,
    required this.validation,
    required this.safeDelete,
    required this.capabilities,
    this.seriesId,
    this.bookId,
    this.branchId,
  });

  final String recordId;
  final String recordType;
  final String title;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
  final AuthorRecordStatus lifecycleStatus;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConnectionInspection> outgoingConnections;
  final List<ConnectionInspection> incomingConnections;
  final List<ReferenceInspection> references;
  final HistoryInspection history;
  final TemplateInspection template;
  final ScopeInspection scope;
  final ValidationInspection validation;
  final SafeDeleteInspection safeDelete;
  final InspectionCapabilities capabilities;
}
