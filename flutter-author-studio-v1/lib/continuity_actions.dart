import 'dart:async';
import 'dart:convert';

import 'character_service.dart';
import 'continuity.dart';
import 'core/connected_domain.dart';
import 'persistence/authoros_database.dart';
import 'timeline_service.dart';
import 'world_service.dart';

enum ContinuityActionStatus { resolved, warningRemains, cancelled, failed }

class ContinuityActionResult {
  const ContinuityActionResult({
    required this.status,
    required this.warningRemains,
    this.recordId,
    this.linkId,
    this.message = '',
  });

  final ContinuityActionStatus status;
  final bool warningRemains;
  final String? recordId;
  final String? linkId;
  final String message;

  bool get mutationApplied =>
      status == ContinuityActionStatus.resolved ||
      status == ContinuityActionStatus.warningRemains;
}

class ContinuityActionService {
  const ContinuityActionService({
    required this.projectId,
    required this.repository,
    this.activeBranchId,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final String? activeBranchId;

  CharacterService get characters =>
      CharacterService(projectId: projectId, repository: repository);
  WorldService get worlds =>
      WorldService(projectId: projectId, repository: repository);
  TimelineService get timeline =>
      TimelineService(projectId: projectId, repository: repository);

  Future<ContinuityActionResult> createForRecommendation(
    ContinuityIntegrityIssue issue, {
    required String name,
    required bool confirmed,
    FutureOr<bool> Function()? recheck,
    DateTime? timestamp,
  }) async {
    if (issue.actionKind != ContinuityActionKind.create) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: 'This recommendation is not a creation action.',
      );
    }
    if (!confirmed) return _cancelled;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: 'A name is required.',
      );
    }

    try {
      final existing = activeBranchId == null
          ? await timeline.search.searchAll(normalizedName)
          : await timeline.search.searchByBranch(
              normalizedName,
              activeBranchId!,
            );
      if (existing.any((result) =>
          result.title.toLowerCase() == normalizedName.toLowerCase())) {
        return const ContinuityActionResult(
          status: ContinuityActionStatus.failed,
          warningRemains: true,
          message: 'A matching record already exists. Link it instead.',
        );
      }

      final now = (timestamp ?? DateTime.now()).toUtc();
      final id = _recordId(issue.type.name, normalizedName, now);
      final AuthorRecord created;
      switch (issue.type) {
        case ContinuityWarningType.unknownCharacter:
          created = await characters.createCharacter(
            id: id,
            displayName: normalizedName,
            scopeType: activeBranchId == null
                ? RecordScopeType.project
                : RecordScopeType.branch,
            scopeId: activeBranchId ?? projectId,
            branchId: activeBranchId,
            canonStatus: activeBranchId == null
                ? CanonStatus.draft
                : CanonStatus.alternate,
            timestamp: now,
          );
        case ContinuityWarningType.unknownLocation:
          created = await worlds.createWorldRecord(
            id: id,
            title: normalizedName,
            typeId: 'location',
            scopeType: activeBranchId == null
                ? RecordScopeType.project
                : RecordScopeType.branch,
            scopeId: activeBranchId ?? projectId,
            branchId: activeBranchId,
            canonStatus: activeBranchId == null
                ? CanonStatus.draft
                : CanonStatus.alternate,
            canonState: activeBranchId == null ? 'Draft' : 'Alternate',
            timestamp: now,
          );
        default:
          return const ContinuityActionResult(
            status: ContinuityActionStatus.failed,
            warningRemains: true,
            message: 'No creation workflow exists for this warning.',
          );
      }

      final indexed = activeBranchId == null
          ? await timeline.search.searchAll(normalizedName)
          : await timeline.search.searchByBranch(
              normalizedName,
              activeBranchId!,
            );
      if (!indexed.any((result) => result.recordId == created.id)) {
        return ContinuityActionResult(
          status: ContinuityActionStatus.warningRemains,
          warningRemains: true,
          recordId: created.id,
          message: 'Created, but the refreshed search index did not return it.',
        );
      }
      return _afterMutation(recordId: created.id, recheck: recheck);
    } catch (error) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: error.toString(),
      );
    }
  }

  Future<ContinuityActionResult> linkForRecommendation(
    ContinuityIntegrityIssue issue, {
    required String sourceId,
    required String targetId,
    required String typeId,
    required bool confirmed,
    RecordLinkDirection direction = RecordLinkDirection.directed,
    FutureOr<bool> Function()? recheck,
    DateTime? timestamp,
  }) async {
    if (issue.actionKind != ContinuityActionKind.link) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: 'This recommendation is not a link action.',
      );
    }
    if (!confirmed) return _cancelled;

    try {
      final now = (timestamp ?? DateTime.now()).toUtc();
      String linkId;
      if (activeBranchId == null) {
        final link = await timeline.connect(
          sourceId: sourceId,
          targetId: targetId,
          typeId: typeId,
          direction: direction,
          timestamp: now,
        );
        linkId = link.id;
      } else {
        final link = RecordLink(
          id: _linkId(activeBranchId!, sourceId, typeId, targetId),
          sourceId: sourceId,
          targetId: targetId,
          typeId: typeId,
          scopeId: projectId,
          direction: direction,
          createdAt: now,
          updatedAt: now,
        );
        await timeline.branches.addConnection(
          activeBranchId!,
          link,
          timestamp: now,
        );
        linkId = link.id;
      }
      return _afterMutation(linkId: linkId, recheck: recheck);
    } catch (error) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: error.toString(),
      );
    }
  }

  Future<ContinuityActionResult> reviewFixForRecommendation(
    ContinuityIntegrityIssue issue, {
    required String recordId,
    required Map<String, Object?> proposedFields,
    required bool confirmed,
    FutureOr<bool> Function()? recheck,
    DateTime? timestamp,
  }) async {
    if (issue.actionKind != ContinuityActionKind.review) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: 'This recommendation is not a review action.',
      );
    }
    if (!confirmed) return _cancelled;

    try {
      final existing = await timeline.getTimelineRecord(recordId);
      if (existing == null) {
        return const ContinuityActionResult(
          status: ContinuityActionStatus.failed,
          warningRemains: true,
          message: 'The timeline record no longer exists.',
        );
      }
      final now = (timestamp ?? DateTime.now()).toUtc();
      if (activeBranchId == null) {
        await timeline.updateTimelineRecord(
          existing.copyWith(
            fields: {...existing.fields, ...proposedFields},
            updatedAt: now,
          ),
          summary: 'Applied confirmed continuity recommendation',
        );
      } else {
        await timeline.overrideInBranch(
          activeBranchId!,
          recordId,
          fields: proposedFields,
          timestamp: now,
        );
      }
      return _afterMutation(recordId: recordId, recheck: recheck);
    } catch (error) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: error.toString(),
      );
    }
  }

  Future<ContinuityActionResult> _afterMutation({
    String? recordId,
    String? linkId,
    FutureOr<bool> Function()? recheck,
  }) async {
    final warningRemains = recheck == null ? true : await recheck();
    return ContinuityActionResult(
      status: warningRemains
          ? ContinuityActionStatus.warningRemains
          : ContinuityActionStatus.resolved,
      warningRemains: warningRemains,
      recordId: recordId,
      linkId: linkId,
      message: warningRemains
          ? 'The action was saved, but the warning still needs review.'
          : 'The recommendation was resolved.',
    );
  }
}

const _cancelled = ContinuityActionResult(
  status: ContinuityActionStatus.cancelled,
  warningRemains: true,
  message: 'No changes were made.',
);

String _recordId(String kind, String name, DateTime timestamp) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return 'continuity-$kind-${slug.isEmpty ? 'record' : slug}-${timestamp.microsecondsSinceEpoch}';
}

String _linkId(
    String branchId, String sourceId, String typeId, String targetId) {
  final identity = base64Url
      .encode(utf8.encode('$branchId|$sourceId|$typeId|$targetId'))
      .replaceAll('=', '');
  return 'branch-link-$identity';
}
