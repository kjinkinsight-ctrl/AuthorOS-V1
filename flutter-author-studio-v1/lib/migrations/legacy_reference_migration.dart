import '../core/branch_service.dart';
import '../core/connected_domain.dart';
import '../core/record_service.dart';
import '../core/version_audit.dart';
import '../persistence/authoros_database.dart';
import 'legacy_reference_models.dart';

class LegacyReferenceMigrationService {
  const LegacyReferenceMigrationService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);

  Future<LegacyMigrationCandidate> resolve(LegacyReference reference) async {
    if (reference.legacyReference.trim().isEmpty) {
      return _candidate(
        reference,
        LegacyReferenceResolutionState.unsupported,
        reason: 'Empty legacy references are unsupported.',
      );
    }
    if (!_supportedSources.contains(reference.source)) {
      return _candidate(
        reference,
        LegacyReferenceResolutionState.unsupported,
        reason: 'No adapter is registered for ${reference.source}.',
      );
    }
    final stableId = reference.stableRecordId?.trim();
    if (stableId != null && stableId.isNotEmpty) {
      final branchRecord = reference.branchId == null
          ? null
          : (await branches.recordsForBranch(reference.branchId!))
              .where((record) => record.id == stableId)
              .firstOrNull;
      final storedRecord = await repository.recordById(stableId);
      final node = await repository.manuscriptNodeById(stableId);
      final type =
          branchRecord?.typeId ?? storedRecord?.typeId ?? node?.nodeType;
      final belongsToProject = branchRecord != null ||
          (storedRecord != null &&
              (storedRecord.projectId ?? storedRecord.scopeId) == projectId) ||
          node?.projectId == projectId;
      if (type != null && belongsToProject) {
        return _candidate(
          reference,
          LegacyReferenceResolutionState.alreadyMigrated,
          ids: [stableId],
          types: [type],
          resolvedId: stableId,
          confidence: LegacyReferenceConfidence.exact,
          reason:
              'The legacy field already contains a stable project entity ID.',
        );
      }
      return _candidate(
        reference,
        LegacyReferenceResolutionState.unresolved,
        reason: 'The stored stable ID does not resolve inside $projectId.',
      );
    }

    final normalized = _normalize(reference.legacyReference);
    final availableRecords = reference.branchId == null
        ? await repository.recordsByProject(projectId)
        : await branches.recordsForBranch(reference.branchId!);
    final candidates = availableRecords
        .where((record) => _typeAllowed(
              record.typeId,
              reference.expectedRecordTypes,
            ))
        .where((record) => _names(record).contains(normalized))
        .toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    if (candidates.isEmpty) {
      return _candidate(
        reference,
        LegacyReferenceResolutionState.unresolved,
        reason: 'No exact title or alias match exists in $projectId.',
      );
    }
    if (candidates.length > 1) {
      return _candidate(
        reference,
        LegacyReferenceResolutionState.ambiguous,
        ids: candidates.map((record) => record.id).toList(),
        types: candidates.map((record) => record.typeId).toList(),
        confidence: LegacyReferenceConfidence.exact,
        reason: 'Multiple exact project matches require manual resolution.',
      );
    }
    return _candidate(
      reference,
      LegacyReferenceResolutionState.resolved,
      ids: [candidates.single.id],
      types: [candidates.single.typeId],
      resolvedId: candidates.single.id,
      confidence: LegacyReferenceConfidence.exact,
      reason: 'One exact project title or alias match was found.',
    );
  }

  Future<LegacyMigrationResult> migrate({
    required String ownerRecordId,
    required LegacyReference reference,
    DateTime? timestamp,
  }) async {
    final branchId = reference.branchId;
    final owner = branchId == null
        ? await records.getRecord(ownerRecordId)
        : (await branches.recordsForBranch(branchId))
            .where((record) => record.id == ownerRecordId)
            .firstOrNull;
    if (owner == null) {
      throw StateError('Migration owner $ownerRecordId is not visible.');
    }
    final existing = _stableReferences(owner.fields)[reference.id];
    if (existing is Map && existing['stableRecordId'] is String) {
      final stableId = existing['stableRecordId'] as String;
      final type = await repository.entityTypeId(stableId);
      return LegacyMigrationResult(
        candidate: _candidate(
          reference,
          LegacyReferenceResolutionState.alreadyMigrated,
          ids: [stableId],
          types: [if (type != null) type],
          resolvedId: stableId,
          confidence: LegacyReferenceConfidence.exact,
          reason: 'This migration reference was already persisted.',
        ),
        persisted: false,
        ownerRecordId: ownerRecordId,
        branchId: branchId,
      );
    }

    final candidate = await resolve(reference);
    if (candidate.resolutionState != LegacyReferenceResolutionState.resolved) {
      return LegacyMigrationResult(
        candidate: candidate,
        persisted: false,
        ownerRecordId: ownerRecordId,
        branchId: branchId,
      );
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final stableReferences = _stableReferences(owner.fields)
      ..[reference.id] = {
        'stableRecordId': candidate.resolvedRecordId,
        'legacyReference': reference.legacyReference,
        'source': reference.source,
        'fieldPath': reference.fieldPath,
        'migratedAt': now.toIso8601String(),
      };
    if (branchId == null) {
      await records.updateRecord(
        owner.copyWith(
          fields: {
            ...owner.fields,
            legacyStableReferencesField: stableReferences,
          },
          updatedAt: now,
        ),
        changeType: AuditChangeType.updated,
        summary: 'Migrated legacy reference ${reference.id}',
        historyMetadata: {
          'migration': 'legacy-reference',
          'legacyReferenceId': reference.id,
          'resolvedRecordId': candidate.resolvedRecordId,
        },
      );
    } else if (await repository.recordById(ownerRecordId) == null) {
      await branches.updateCreatedRecord(
        branchId,
        owner.copyWith(
          fields: {
            ...owner.fields,
            legacyStableReferencesField: stableReferences,
          },
          updatedAt: now,
        ),
        timestamp: now,
        summary: 'Migrated legacy reference ${reference.id}',
        historyMetadata: {
          'migration': 'legacy-reference',
          'legacyReferenceId': reference.id,
          'resolvedRecordId': candidate.resolvedRecordId,
        },
      );
    } else {
      await branches.overrideRecord(
        branchId,
        ownerRecordId,
        fields: {legacyStableReferencesField: stableReferences},
        timestamp: now,
      );
    }
    return LegacyMigrationResult(
      candidate: candidate,
      persisted: true,
      ownerRecordId: ownerRecordId,
      branchId: branchId,
    );
  }
}

const _supportedSources = {
  'StoryCodexEntry.relationships',
  'StoryCodexEntry.mentions',
  'ManuscriptScene.pov',
  'ManuscriptScene.location',
  'SceneRelationship.targetId',
  'TimelineEvent.pov',
  'TimelineEvent.presentCharacters',
  'TimelineEvent.location',
  'TimelineEvent.plotline',
  'PlanningScene.pov',
};

LegacyMigrationCandidate _candidate(
  LegacyReference reference,
  LegacyReferenceResolutionState state, {
  List<String> ids = const [],
  List<String> types = const [],
  LegacyReferenceConfidence confidence = LegacyReferenceConfidence.none,
  String? resolvedId,
  required String reason,
}) =>
    LegacyMigrationCandidate(
      legacyReference: reference,
      candidateRecordIds: List.unmodifiable(ids),
      candidateRecordTypes: List.unmodifiable(types),
      confidence: confidence,
      resolutionState: state,
      source: reference.source,
      reason: reason,
      resolvedRecordId: resolvedId,
    );

Map<String, Object?> _stableReferences(Map<String, Object?> fields) {
  final raw = fields[legacyStableReferencesField];
  return raw is Map
      ? raw.map((key, value) => MapEntry(key.toString(), value))
      : <String, Object?>{};
}

Set<String> _names(AuthorRecord record) {
  final names = <String>{_normalize(record.title)};
  for (final key in const ['aliases', 'identity.aliases']) {
    final value = record.fields[key];
    if (value is Iterable) {
      names.addAll(value.map((item) => _normalize(item.toString())));
    } else if (value is String) {
      names.addAll(value.split(',').map(_normalize));
    }
  }
  return names.where((name) => name.isNotEmpty).toSet();
}

bool _typeAllowed(String actual, List<String> expected) {
  if (expected.isEmpty) return true;
  if (expected.contains(actual)) return true;
  return (actual == 'location' && expected.contains('place')) ||
      (actual == 'place' && expected.contains('location'));
}

String _normalize(String value) => value.trim().toLowerCase();
