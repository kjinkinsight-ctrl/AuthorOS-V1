import 'connected_domain.dart';
import 'connection_types.dart';

/// Validation rules shared by every writer of a Universal Record relationship.
///
/// `RecordLink` is the persisted relationship. This library owns the rules that
/// decide whether a link may exist, so `ConnectionEngine`, `RecordService` and
/// the `UniversalRecordsRepository` boundary all reach the same verdict instead
/// of re-implementing endpoint, project, branch and lifecycle checks.
enum RelationshipValidationSeverity { warning, error }

enum RelationshipEndpointKind { record, manuscriptNode, missing }

class RelationshipValidationIssue {
  const RelationshipValidationIssue({
    required this.code,
    required this.message,
    this.severity = RelationshipValidationSeverity.error,
  });

  final String code;
  final String message;
  final RelationshipValidationSeverity severity;
}

class RelationshipValidationResult {
  const RelationshipValidationResult(this.issues);

  final List<RelationshipValidationIssue> issues;

  bool get isValid => !issues
      .any((issue) => issue.severity == RelationshipValidationSeverity.error);

  List<RelationshipValidationIssue> get errors => issues
      .where((issue) => issue.severity == RelationshipValidationSeverity.error)
      .toList();

  List<RelationshipValidationIssue> get warnings => issues
      .where(
          (issue) => issue.severity == RelationshipValidationSeverity.warning)
      .toList();

  /// A single-line summary of every error, or `null` when the result is valid.
  String? get errorSummary {
    final failures = errors;
    if (failures.isEmpty) return null;
    return failures.map((issue) => issue.message).join(' ');
  }
}

class RelationshipValidationException implements Exception {
  const RelationshipValidationException(this.result);

  final RelationshipValidationResult result;

  @override
  String toString() =>
      'Relationship validation failed: ${result.errorSummary ?? ''}';
}

/// The facts a validator needs about one end of a relationship.
///
/// Endpoints are resolved by the caller because a record may still be in
/// flight (created in the same transaction as its links) and therefore not yet
/// readable from the repository.
class RelationshipEndpoint {
  const RelationshipEndpoint({
    required this.id,
    required this.kind,
    this.typeId,
    this.projectId,
    this.branchId,
    this.canonStatus,
    this.lifecycleStatus,
  });

  factory RelationshipEndpoint.fromRecord(AuthorRecord record) =>
      RelationshipEndpoint(
        id: record.id,
        kind: RelationshipEndpointKind.record,
        typeId: record.typeId,
        projectId: record.projectId ??
            record.fields['projectId'] as String? ??
            record.fields['_codex.projectId'] as String? ??
            record.scopeId,
        branchId: record.branchId,
        canonStatus: record.canonStatus,
        lifecycleStatus: record.status,
      );

  factory RelationshipEndpoint.fromManuscriptNode(
    ManuscriptNodeReference node,
  ) =>
      RelationshipEndpoint(
        id: node.id,
        kind: RelationshipEndpointKind.manuscriptNode,
        typeId: node.nodeType,
        projectId: node.projectId,
      );

  factory RelationshipEndpoint.missing(String id) => RelationshipEndpoint(
        id: id,
        kind: RelationshipEndpointKind.missing,
      );

  final String id;
  final RelationshipEndpointKind kind;
  final String? typeId;
  final String? projectId;
  final String? branchId;
  final CanonStatus? canonStatus;
  final AuthorRecordStatus? lifecycleStatus;

  bool get exists => kind != RelationshipEndpointKind.missing;

  /// The branch a relationship written against this endpoint belongs to.
  ///
  /// `null` means canonical (non-branch) context.
  String? get branchContext => branchId;
}

class RelationshipValidator {
  const RelationshipValidator(this.registry);

  final ConnectionTypeRegistry registry;

  /// Validates [relationship] for [projectId] using already-resolved endpoints.
  RelationshipValidationResult validate({
    required RecordLink relationship,
    required String projectId,
    required RelationshipEndpoint source,
    required RelationshipEndpoint target,
  }) {
    final issues = <RelationshipValidationIssue>[];
    if (relationship.id.trim().isEmpty) {
      issues.add(const RelationshipValidationIssue(
        code: 'missing-relationship-id',
        message: 'Relationship id is required.',
      ));
    }
    if (relationship.sourceId.trim().isEmpty ||
        relationship.targetId.trim().isEmpty) {
      issues.add(const RelationshipValidationIssue(
        code: 'missing-relationship-endpoint',
        message: 'Relationship source and target ids are required.',
      ));
    }
    if (relationship.typeId.trim().isEmpty) {
      issues.add(const RelationshipValidationIssue(
        code: 'missing-relationship-type',
        message: 'Relationship type id is required.',
      ));
    }
    if (relationship.scopeId != projectId) {
      issues.add(RelationshipValidationIssue(
        code: 'relationship-project-mismatch',
        message:
            'Relationship ${relationship.id} does not belong to $projectId.',
      ));
    }
    if (!source.exists) {
      issues.add(RelationshipValidationIssue(
        code: 'unknown-relationship-source',
        message: 'Relationship source ${relationship.sourceId} does not exist.',
      ));
    }
    if (!target.exists) {
      issues.add(RelationshipValidationIssue(
        code: 'unknown-relationship-target',
        message: 'Relationship target ${relationship.targetId} does not exist.',
      ));
    }
    if (source.exists && source.projectId != projectId) {
      issues.add(RelationshipValidationIssue(
        code: 'relationship-endpoint-project-mismatch',
        message: 'Relationship source ${source.id} is outside $projectId.',
      ));
    }
    if (target.exists && target.projectId != projectId) {
      issues.add(RelationshipValidationIssue(
        code: 'relationship-endpoint-project-mismatch',
        message: 'Relationship target ${target.id} is outside $projectId.',
      ));
    }
    if (source.exists &&
        target.exists &&
        source.branchContext != target.branchContext) {
      issues.add(RelationshipValidationIssue(
        code: 'relationship-branch-mismatch',
        message: 'Relationship ${relationship.id} would connect '
            '${_branchLabel(source.branchContext)} to '
            '${_branchLabel(target.branchContext)}.',
      ));
    }
    for (final endpoint in [source, target]) {
      if (endpoint.lifecycleStatus == AuthorRecordStatus.deleted) {
        issues.add(RelationshipValidationIssue(
          code: 'relationship-endpoint-deleted',
          message: 'Relationship endpoint ${endpoint.id} is deleted.',
        ));
      } else if (endpoint.lifecycleStatus == AuthorRecordStatus.archived) {
        issues.add(RelationshipValidationIssue(
          code: 'relationship-endpoint-archived',
          message: 'Relationship endpoint ${endpoint.id} is archived.',
          severity: RelationshipValidationSeverity.warning,
        ));
      }
    }

    ConnectionTypeDefinition? definition;
    try {
      definition = registry.resolve(relationship.typeId);
    } on StateError {
      issues.add(RelationshipValidationIssue(
        code: 'unknown-relationship-type',
        message: 'Unknown relationship type: ${relationship.typeId}.',
      ));
    }
    if (definition == null) {
      return RelationshipValidationResult(issues);
    }
    if (relationship.sourceId == relationship.targetId &&
        definition.extensionData['allowSelfReference'] != true) {
      issues.add(RelationshipValidationIssue(
        code: 'relationship-self-reference',
        message: '${relationship.typeId} may not connect '
            '${relationship.sourceId} to itself.',
      ));
    }
    final expectedDirection =
        definition.direction == ConnectionDirection.directed
            ? RecordLinkDirection.directed
            : RecordLinkDirection.undirected;
    if (relationship.direction != expectedDirection) {
      issues.add(RelationshipValidationIssue(
        code: 'invalid-relationship-direction',
        message:
            '${relationship.typeId} requires ${expectedDirection.name} links.',
      ));
    }
    final sourceTypeId = source.typeId;
    final targetTypeId = target.typeId;
    if (sourceTypeId == null || targetTypeId == null) {
      issues.add(RelationshipValidationIssue(
        code: 'unresolved-relationship-endpoint-type',
        message:
            'Relationship ${relationship.id} has an unresolved endpoint type.',
      ));
      return RelationshipValidationResult(issues);
    }
    try {
      registry.validateConnection(
        typeId: relationship.typeId,
        sourceTypeId: sourceTypeId,
        targetTypeId: targetTypeId,
        metadata: relationship.metadata,
      );
    } on StateError catch (error) {
      issues.add(RelationshipValidationIssue(
        code: 'invalid-relationship-definition',
        message: error.message,
      ));
    }
    return RelationshipValidationResult(issues);
  }
}

String _branchLabel(String? branchId) =>
    branchId == null ? 'canon' : 'branch $branchId';
