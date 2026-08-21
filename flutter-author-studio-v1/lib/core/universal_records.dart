import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'connection_engine.dart';
import 'connection_types.dart';
import 'record_graph.dart';
import 'record_id.dart';
import 'record_service.dart';
import 'record_types.dart';

export 'connected_domain.dart'
    show AuthorRecord, AuthorRecordStatus, RecordLink, RecordLinkDirection;
export 'record_graph.dart';
export 'record_id.dart';
export 'relationship_validation.dart';

/// The Universal Records boundary a future Studio consumes.
///
/// This type owns no storage and no rules of its own. It composes the systems
/// that already exist — [RecordService] for the record lifecycle,
/// [ConnectionEngine] for relationships, [RecordGraph] for reads — behind one
/// project-scoped, id-typed API so Manuscript, Character, World, Map, Timeline
/// and Plot Studios never need a private identity, storage or link model.
///
/// Dependency direction is core -> storage -> services -> studios. Nothing in
/// this file imports a Studio, and nothing imports Flutter directly.
class UniversalRecordsRepository {
  UniversalRecordsRepository({
    required this.projectId,
    required this.repository,
    ConnectionTypeRegistry? relationshipRegistry,
  }) : _relationshipRegistry = relationshipRegistry;

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final ConnectionTypeRegistry? _relationshipRegistry;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  RecordGraph get graph =>
      RecordGraph(projectId: projectId, repository: repository);

  /// Registry of record types, including any project-scoped custom types.
  Future<RecordTypeRegistry> recordTypes() => records.registry();

  /// Registry of relationship types, including project-scoped custom types.
  Future<ConnectionTypeRegistry> relationshipTypes() async =>
      _relationshipRegistry ?? await records.connectionRegistry();

  Future<ConnectionEngine> _relationships() async => ConnectionEngine(
        scopeId: projectId,
        repository: repository,
        registry: await relationshipTypes(),
      );

  // ---------------------------------------------------------------- records

  Future<AuthorRecord> createRecord(
    AuthorRecord record, {
    Iterable<RecordLink> relationships = const [],
  }) =>
      records.createRecord(record, links: relationships);

  Future<AuthorRecord?> getRecord(RecordId id) => records.getRecord(id.value);

  Future<AuthorRecord> updateRecord(
    AuthorRecord record, {
    Iterable<RecordLink> relationships = const [],
  }) =>
      records.updateRecord(record, links: relationships);

  Future<AuthorRecord> archiveRecord(RecordId id, {DateTime? timestamp}) =>
      records.archiveRecord(id.value, timestamp: timestamp);

  Future<AuthorRecord> restoreRecord(RecordId id, {DateTime? timestamp}) =>
      records.restoreRecord(id.value, timestamp: timestamp);

  /// Soft-deletes a record and, by default, removes the relationships that
  /// reference it.
  ///
  /// Deleting is never allowed to leave an edge pointing at a record a Studio
  /// can no longer read. Each removal is audited through [ConnectionEngine],
  /// and no other record is touched. Pass `detachRelationships: false` to keep
  /// the edges — callers that do are responsible for the resulting dangling
  /// references.
  Future<AuthorRecord> deleteRecord(
    RecordId id, {
    bool detachRelationships = true,
    DateTime? timestamp,
  }) async {
    final existing = await getRecord(id);
    if (existing == null) {
      throw StateError('Record ${id.value} does not belong to $projectId.');
    }
    if (detachRelationships) {
      final engine = await _relationships();
      for (final link in await graph.relationships(id)) {
        await engine.disconnect(link.id, timestamp: timestamp);
      }
    }
    return records.deleteRecord(id.value, timestamp: timestamp);
  }

  Future<List<AuthorRecord>> listRecords({
    bool includeArchived = true,
    bool includeDeleted = false,
  }) async {
    final all = await repository.recordsByProject(projectId);
    return all
        .where((record) => _visible(record, includeArchived, includeDeleted))
        .toList();
  }

  Future<List<AuthorRecord>> findRecords({
    required String typeId,
    bool includeArchived = true,
    bool includeDeleted = false,
  }) async {
    final all = await listRecords(
      includeArchived: includeArchived,
      includeDeleted: includeDeleted,
    );
    return all.where((record) => record.typeId == typeId).toList();
  }

  // ---------------------------------------------------------- relationships

  Future<RecordLink> createRelationship({
    required RecordId sourceId,
    required RecordId targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    final engine = await _relationships();
    return engine.connect(
      sourceId: sourceId.value,
      targetId: targetId.value,
      typeId: typeId,
      label: label,
      direction: direction,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<RecordLink?> getRelationship(RelationshipId id) async {
    final link = await repository.linkById(id.value);
    return link != null && link.scopeId == projectId ? link : null;
  }

  Future<void> deleteRelationship(
    RelationshipId id, {
    DateTime? timestamp,
  }) async {
    final engine = await _relationships();
    await engine.disconnect(id.value, timestamp: timestamp);
  }

  Future<List<RecordLink>> listRelationships() =>
      repository.linksByScope(projectId);

  Future<List<RecordLink>> findOutgoing(RecordId id) =>
      graph.outgoingRelationships(id);

  Future<List<RecordLink>> findIncoming(RecordId id) =>
      graph.incomingRelationships(id);

  Future<List<RelatedRecord>> findRelated(
    RecordId id, {
    RelationshipDirection direction = RelationshipDirection.any,
    Set<String> relationshipTypeIds = const {},
    Set<String> recordTypeIds = const {},
    bool includeArchived = true,
    bool includeDeleted = false,
  }) =>
      graph.related(
        id,
        direction: direction,
        relationshipTypeIds: relationshipTypeIds,
        recordTypeIds: recordTypeIds,
        includeArchived: includeArchived,
        includeDeleted: includeDeleted,
      );
}

bool _visible(
  AuthorRecord record,
  bool includeArchived,
  bool includeDeleted,
) =>
    switch (record.status) {
      AuthorRecordStatus.active => true,
      AuthorRecordStatus.archived => includeArchived,
      AuthorRecordStatus.deleted => includeDeleted,
    };

extension AuthorRecordIdentity on AuthorRecord {
  RecordId get recordId => RecordId.parse(id);
}

extension RecordLinkIdentity on RecordLink {
  RelationshipId get relationshipId => RelationshipId.parse(id);

  RecordId get sourceRecordId => RecordId.parse(sourceId);

  RecordId get targetRecordId => RecordId.parse(targetId);
}
