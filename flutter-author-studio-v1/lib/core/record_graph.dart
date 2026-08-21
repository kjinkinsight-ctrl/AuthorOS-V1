import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'record_id.dart';

/// Foundational graph reads over Universal Records and their relationships.
///
/// This is a query surface, not a second store: every read goes through the
/// existing [DriftConnectedDomainRepository]. Results are always confined to
/// one project, so two projects can never surface each other's records.
enum RelationshipDirection { incoming, outgoing, any }

class RelatedRecord {
  const RelatedRecord({
    required this.record,
    required this.relationship,
    required this.direction,
  });

  final AuthorRecord record;
  final RecordLink relationship;

  /// [RelationshipDirection.outgoing] when the anchor record is the
  /// relationship's source, [RelationshipDirection.incoming] otherwise.
  final RelationshipDirection direction;

  RecordId get recordId => RecordId.parse(record.id);

  RelationshipId get relationshipId => RelationshipId.parse(relationship.id);
}

class RecordGraph {
  const RecordGraph({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  Future<List<RecordLink>> outgoingRelationships(RecordId id) async {
    await _requireEntity(id);
    return _inProject(await repository.outgoingLinks(id.value));
  }

  Future<List<RecordLink>> incomingRelationships(RecordId id) async {
    await _requireEntity(id);
    return _inProject(await repository.incomingLinks(id.value));
  }

  Future<List<RecordLink>> relationships(RecordId id) async {
    await _requireEntity(id);
    return _inProject(await repository.backlinks(id.value));
  }

  /// Records reachable from [id] in one hop.
  ///
  /// [relationshipTypeIds] and [recordTypeIds] are inclusive filters; an empty
  /// set means "any". Deleted records are excluded by default so a soft-deleted
  /// record never leaks back into a Studio through the graph.
  Future<List<RelatedRecord>> related(
    RecordId id, {
    RelationshipDirection direction = RelationshipDirection.any,
    Set<String> relationshipTypeIds = const {},
    Set<String> recordTypeIds = const {},
    bool includeArchived = true,
    bool includeDeleted = false,
  }) async {
    final links = switch (direction) {
      RelationshipDirection.incoming => await incomingRelationships(id),
      RelationshipDirection.outgoing => await outgoingRelationships(id),
      RelationshipDirection.any => await relationships(id),
    };
    final results = <RelatedRecord>[];
    for (final link in links) {
      if (relationshipTypeIds.isNotEmpty &&
          !relationshipTypeIds.contains(link.typeId)) {
        continue;
      }
      final outgoing = link.sourceId == id.value;
      final otherId = outgoing ? link.targetId : link.sourceId;
      final record = await repository.recordById(otherId);
      if (record == null || !_belongsToProject(record)) continue;
      if (recordTypeIds.isNotEmpty && !recordTypeIds.contains(record.typeId)) {
        continue;
      }
      if (!includeDeleted && record.status == AuthorRecordStatus.deleted) {
        continue;
      }
      if (!includeArchived && record.status == AuthorRecordStatus.archived) {
        continue;
      }
      results.add(
        RelatedRecord(
          record: record,
          relationship: link,
          direction: outgoing
              ? RelationshipDirection.outgoing
              : RelationshipDirection.incoming,
        ),
      );
    }
    results.sort((left, right) => left.record.id.compareTo(right.record.id));
    return results;
  }

  List<RecordLink> _inProject(List<RecordLink> links) =>
      links.where((link) => link.scopeId == projectId).toList();

  bool _belongsToProject(AuthorRecord record) =>
      (record.projectId ?? record.scopeId) == projectId ||
      record.scopeId == projectId ||
      record.fields['projectId'] == projectId ||
      record.fields['_codex.projectId'] == projectId;

  Future<void> _requireEntity(RecordId id) async {
    if (await repository.entityProjectId(id.value) != projectId) {
      throw StateError('Entity ${id.value} does not belong to $projectId.');
    }
  }
}
