enum LegacyReferenceResolutionState {
  resolved,
  ambiguous,
  unresolved,
  unsupported,
  alreadyMigrated,
}

enum LegacyReferenceConfidence { exact, none }

class LegacyReference {
  const LegacyReference({
    required this.id,
    required this.legacyReference,
    required this.source,
    required this.sourceEntityId,
    required this.fieldPath,
    this.expectedRecordTypes = const [],
    this.stableRecordId,
    this.branchId,
    this.reason = '',
  });

  final String id;
  final String legacyReference;
  final String source;
  final String sourceEntityId;
  final String fieldPath;
  final List<String> expectedRecordTypes;
  final String? stableRecordId;
  final String? branchId;
  final String reason;
}

class LegacyMigrationCandidate {
  const LegacyMigrationCandidate({
    required this.legacyReference,
    required this.candidateRecordIds,
    required this.candidateRecordTypes,
    required this.confidence,
    required this.resolutionState,
    required this.source,
    required this.reason,
    this.resolvedRecordId,
  });

  final LegacyReference legacyReference;
  final List<String> candidateRecordIds;
  final List<String> candidateRecordTypes;
  final LegacyReferenceConfidence confidence;
  final LegacyReferenceResolutionState resolutionState;
  final String source;
  final String reason;
  final String? resolvedRecordId;
}

class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.candidate,
    required this.persisted,
    this.ownerRecordId,
    this.branchId,
  });

  final LegacyMigrationCandidate candidate;
  final bool persisted;
  final String? ownerRecordId;
  final String? branchId;
}

const legacyStableReferencesField = '_legacyMigration.stableReferences';
