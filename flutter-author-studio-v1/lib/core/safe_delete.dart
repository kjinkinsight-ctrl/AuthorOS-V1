import 'record_inspection.dart';

enum SafeDeleteDisposition { safe, safeWithWarnings, blocked }

class SafeDeleteAnalysis {
  const SafeDeleteAnalysis({
    required this.recordId,
    required this.recordType,
    required this.disposition,
    required this.blockingReasons,
    required this.warnings,
    required this.incomingConnections,
    required this.outgoingConnections,
    required this.references,
    required this.legacyReferences,
    required this.affectedBranches,
    required this.versionCount,
    required this.auditCount,
    required this.affectedRecords,
    required this.affectedManuscriptNodes,
    required this.templateDependentRecordIds,
    required this.archived,
    required this.softDeleted,
    required this.physicallyDeletable,
  });

  final String recordId;
  final String recordType;
  final SafeDeleteDisposition disposition;
  final List<String> blockingReasons;
  final List<String> warnings;
  final List<ConnectionInspection> incomingConnections;
  final List<ConnectionInspection> outgoingConnections;
  final List<ReferenceInspection> references;
  final List<String> legacyReferences;
  final List<String> affectedBranches;
  final int versionCount;
  final int auditCount;
  final List<String> affectedRecords;
  final List<String> affectedManuscriptNodes;
  final List<String> templateDependentRecordIds;
  final bool archived;
  final bool softDeleted;
  final bool physicallyDeletable;

  bool get canDelete => disposition != SafeDeleteDisposition.blocked;
}
