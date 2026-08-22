import '../persistence/authoros_database.dart';
import 'built_in_connection_types.dart';
import 'built_in_record_types.dart';
import 'connected_domain.dart';
import 'connection_types.dart';
import 'record_types.dart';
import 'record_validation.dart';
import 'relationship_validation.dart';
import 'version_audit.dart';
import 'version_audit_service.dart';

class RecordService {
  const RecordService({
    required this.projectId,
    required this.repository,
    this.inheritedScopeIds = const {},
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// Shared scopes this project inherits records from, resolved by
  /// `ScopeResolver`.
  ///
  /// Empty by default, so a caller that has not opted into cross-book reads
  /// behaves exactly as it did before scopes existed.
  final Set<String> inheritedScopeIds;

  VersionAuditService get history => VersionAuditService(
        projectId: projectId,
        repository: repository,
      );

  Future<RecordTypeRegistry> registry() async {
    final custom = await repository.recordTypeDefinitionsByScope(
      scopeType: RecordScopeType.project,
      scopeId: projectId,
    );
    return BuiltInRecordTypes.registry(additionalDefinitions: custom);
  }

  Future<ConnectionTypeRegistry> connectionRegistry() async {
    final custom = await repository.connectionTypeDefinitionsByScope(projectId);
    return BuiltInConnectionTypes.registry(additionalDefinitions: custom);
  }

  Future<RecordValidationResult> validateRecord(AuthorRecord record) async =>
      RecordValidator(await registry()).validate(
        record,
        projectId: projectId,
        inheritedScopeIds: inheritedScopeIds,
      );

  Future<AuthorRecord> createRecord(
    AuthorRecord record, {
    Iterable<RecordLink> links = const [],
    AuditChangeType changeType = AuditChangeType.created,
    String? summary,
    Map<String, Object?> historyMetadata = const {},
  }) async {
    if (await repository.recordById(record.id) != null) {
      throw StateError('A record with id ${record.id} already exists.');
    }
    await _requireValid(record);
    final linkList = links.toList();
    await _validateLinks(record, linkList);
    final entry = await history.forRecord(
      record,
      changeType: changeType,
      summary: summary ?? '${changeType.name} ${record.title}',
      timestamp: record.updatedAt,
      metadata: historyMetadata,
    );
    await repository.putRecordWithHistory(
      record: record,
      links: linkList,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return record;
  }

  Future<AuthorRecord?> getRecord(String id) async {
    final record = await repository.recordById(id);
    return record != null && _belongsToProject(record) ? record : null;
  }

  Future<AuthorRecord> updateRecord(
    AuthorRecord record, {
    Iterable<RecordLink> links = const [],
    AuditChangeType? changeType,
    String? summary,
    Map<String, Object?> historyMetadata = const {},
  }) async {
    final existing = await _requireRecord(record.id);
    if (record.typeId != existing.typeId) {
      throw StateError('Record type cannot be changed during an update.');
    }
    if (record.scopeType != existing.scopeType ||
        record.scopeId != existing.scopeId ||
        record.projectId != existing.projectId ||
        record.seriesId != existing.seriesId ||
        record.bookId != existing.bookId ||
        record.branchId != existing.branchId) {
      throw StateError('Record ownership scope cannot be changed by update.');
    }
    final updated = AuthorRecord(
      id: existing.id,
      typeId: existing.typeId,
      scopeType: record.scopeType,
      scopeId: record.scopeId,
      projectId: record.projectId,
      seriesId: record.seriesId,
      bookId: record.bookId,
      branchId: record.branchId,
      canonStatus: record.canonStatus,
      title: record.title,
      status: record.status,
      schemaVersion: record.schemaVersion,
      templateId: record.templateId ?? existing.templateId,
      templateVersion: record.templateVersion ?? existing.templateVersion,
      revision: existing.revision + 1,
      fields: record.fields,
      tags: record.tags,
      createdAt: existing.createdAt,
      updatedAt: record.updatedAt,
      extensionData: {...existing.extensionData, ...record.extensionData},
    );
    await _requireValid(updated);
    final linkList = links.toList();
    await _validateLinks(updated, linkList);
    final classified = changeType ?? _classifyChange(existing, updated);
    final metadata = {
      ...historyMetadata,
      if (existing.title != updated.title) 'previousTitle': existing.title,
      if (existing.title != updated.title) 'newTitle': updated.title,
      if (existing.templateId != updated.templateId)
        'previousTemplateId': existing.templateId,
      if (existing.templateId != updated.templateId)
        'newTemplateId': updated.templateId,
      if (existing.templateVersion != updated.templateVersion)
        'previousTemplateVersion': existing.templateVersion,
      if (existing.templateVersion != updated.templateVersion)
        'newTemplateVersion': updated.templateVersion,
      if (existing.canonStatus != updated.canonStatus)
        'previousCanonStatus': existing.canonStatus.name,
      if (existing.canonStatus != updated.canonStatus)
        'newCanonStatus': updated.canonStatus.name,
      if (existing.status != updated.status)
        'previousLifecycleStatus': existing.status.name,
      if (existing.status != updated.status)
        'newLifecycleStatus': updated.status.name,
    };
    final entry = await history.forRecord(
      updated,
      changeType: classified,
      summary: summary ?? '${classified.name} ${updated.title}',
      timestamp: updated.updatedAt,
      metadata: metadata,
    );
    await repository.putRecordWithHistory(
      record: updated,
      links: linkList,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return updated;
  }

  Future<AuthorRecord> archiveRecord(String id, {DateTime? timestamp}) =>
      _setStatus(
        id,
        AuthorRecordStatus.archived,
        changeType: AuditChangeType.archived,
        timestamp: timestamp,
      );

  Future<AuthorRecord> restoreRecord(String id, {DateTime? timestamp}) =>
      _setStatus(
        id,
        AuthorRecordStatus.active,
        changeType: AuditChangeType.restored,
        timestamp: timestamp,
      );

  Future<AuthorRecord> deleteRecord(String id, {DateTime? timestamp}) =>
      _setStatus(
        id,
        AuthorRecordStatus.deleted,
        changeType: AuditChangeType.deleted,
        timestamp: timestamp,
      );

  Future<AuthorRecord> duplicateRecord(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    if (await repository.recordById(newId) != null) {
      throw StateError('A record with id $newId already exists.');
    }
    final source = await _requireRecord(id);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final duplicate = AuthorRecord(
      id: newId,
      typeId: source.typeId,
      scopeType: source.scopeType,
      scopeId: source.scopeId,
      projectId: source.projectId,
      seriesId: source.seriesId,
      bookId: source.bookId,
      branchId: source.branchId,
      canonStatus: source.canonStatus,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : '${source.title} Copy',
      status: AuthorRecordStatus.active,
      schemaVersion: source.schemaVersion,
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      fields: Map<String, Object?>.from(source.fields),
      tags: List<String>.from(source.tags),
      createdAt: now,
      updatedAt: now,
      extensionData: {...source.extensionData, 'duplicatedFrom': source.id},
    );
    return createRecord(
      duplicate,
      changeType: AuditChangeType.duplicated,
      historyMetadata: {'duplicatedFrom': source.id},
    );
  }

  /// Moves [id] between books, or to series canon when [bookId] is null.
  ///
  /// A thin, intention-revealing wrapper over [changeScope]: book membership
  /// changes often and on its own, so it gets a method that says so and cannot
  /// be called with the wrong scope by accident.
  ///
  /// [updateRecord] cannot do this — it rejects any ownership-scope change
  /// outright, and that rule is worth keeping. Book membership is a deliberate,
  /// audited move, so it gets its own path rather than a hole in that rule.
  Future<AuthorRecord> changeBookAssignment(
    String id, {
    required String? bookId,
    DateTime? timestamp,
  }) async {
    final existing = await _requireRecord(id);
    final normalized = bookId?.trim();
    final target = normalized == null || normalized.isEmpty ? null : normalized;
    if (target == existing.bookId) {
      return existing;
    }
    if (target != null) {
      final book = await repository.recordById(target);
      if (book == null || book.typeId != 'book' || !_belongsToProject(book)) {
        throw StateError('Book $target does not exist in project $projectId.');
      }
    }
    return _writeScopeChange(
      existing,
      scopeType: existing.scopeType,
      scopeId: existing.scopeId,
      seriesId: existing.seriesId,
      bookId: target,
      branchId: existing.branchId,
      summary: 'Changed book assignment for ${existing.title}',
      timestamp: timestamp,
    );
  }

  /// Moves [id] to a different ownership scope.
  ///
  /// `seriesId`, `bookId` and `branchId` are **preserved unless you say
  /// otherwise**. Passing one sets it; passing the matching `clear…` flag nulls
  /// it; omitting both leaves it exactly as it was.
  ///
  /// That asymmetry exists because Dart cannot tell an omitted named argument
  /// from one passed as null. This method used to assign all three
  /// unconditionally, so `changeScope(id, scopeType: …, scopeId: …)` silently
  /// erased whichever of the three the caller had not thought to re-supply —
  /// a record could lose its book membership as a side effect of a scope move
  /// that had nothing to do with books. Preserving is the safe default; losing
  /// data should take an explicit flag.
  ///
  /// Scope consistency is still enforced: [RecordValidator] runs
  /// [RecordScope.validate], so a book scope without a matching `bookId`, or a
  /// series scope without its `seriesId`, is rejected with
  /// `invalid-scope-hierarchy` rather than written.
  Future<AuthorRecord> changeScope(
    String id, {
    required RecordScopeType scopeType,
    required String scopeId,
    String? seriesId,
    String? bookId,
    String? branchId,
    bool clearSeriesId = false,
    bool clearBookId = false,
    bool clearBranchId = false,
    DateTime? timestamp,
  }) async {
    final existing = await _requireRecord(id);
    return _writeScopeChange(
      existing,
      scopeType: scopeType,
      scopeId: scopeId,
      seriesId: _resolveScopeColumn(existing.seriesId, seriesId, clearSeriesId),
      bookId: _resolveScopeColumn(existing.bookId, bookId, clearBookId),
      branchId: _resolveScopeColumn(existing.branchId, branchId, clearBranchId),
      summary: 'Changed scope for ${existing.title}',
      timestamp: timestamp,
    );
  }

  /// One scope column's new value: explicit clear wins, then an explicit
  /// value, otherwise what the record already had.
  static String? _resolveScopeColumn(
    String? existing,
    String? requested,
    bool clear,
  ) {
    if (clear) return null;
    return requested ?? existing;
  }

  /// The single write path for a scope move, shared by [changeScope] and
  /// [changeBookAssignment] so the two can never disagree about which columns
  /// a move carries or how it is audited.
  Future<AuthorRecord> _writeScopeChange(
    AuthorRecord existing, {
    required RecordScopeType scopeType,
    required String scopeId,
    required String? seriesId,
    required String? bookId,
    required String? branchId,
    required String summary,
    DateTime? timestamp,
  }) async {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final changed = AuthorRecord(
      id: existing.id,
      typeId: existing.typeId,
      scopeType: scopeType,
      scopeId: scopeId,
      projectId: existing.projectId,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: existing.canonStatus,
      title: existing.title,
      status: existing.status,
      schemaVersion: existing.schemaVersion,
      templateId: existing.templateId,
      templateVersion: existing.templateVersion,
      revision: existing.revision + 1,
      fields: existing.fields,
      tags: existing.tags,
      createdAt: existing.createdAt,
      updatedAt: now,
      extensionData: existing.extensionData,
    );
    await _requireValid(changed);
    // Every existing link is re-validated against the moved record, so a scope
    // change can never leave behind a relationship the registry would reject.
    final links = await repository.backlinks(existing.id);
    await _validateLinks(changed, links);
    final entry = await history.forRecord(
      changed,
      changeType: AuditChangeType.scopeChanged,
      summary: summary,
      timestamp: now,
      metadata: {
        'previousScopeType': existing.scopeType.name,
        'previousScopeId': existing.scopeId,
        'newScopeType': changed.scopeType.name,
        'newScopeId': changed.scopeId,
        // Recorded only when they actually move, so the audit trail says which
        // columns a scope change touched rather than leaving it to be inferred.
        if (existing.seriesId != changed.seriesId) ...{
          'previousSeriesId': existing.seriesId,
          'newSeriesId': changed.seriesId,
        },
        if (existing.bookId != changed.bookId) ...{
          'previousBookId': existing.bookId,
          'newBookId': changed.bookId,
        },
        if (existing.branchId != changed.branchId) ...{
          'previousBranchId': existing.branchId,
          'newBranchId': changed.branchId,
        },
      },
    );
    await repository.putRecordWithHistory(
      record: changed,
      links: const [],
      version: entry.version,
      auditEvent: entry.audit,
    );
    return changed;
  }

  Future<AuthorRecord> restoreVersion(
    String versionId, {
    DateTime? timestamp,
  }) async {
    final version = await history.getVersion(versionId);
    if (version == null ||
        version.entityKind != VersionEntityKind.record ||
        version.branchId != null) {
      throw StateError('Version $versionId is not a canonical record version.');
    }
    final current = await _requireRecord(version.recordId);
    final historical = AuthorRecord.fromJson(
      Map<String, dynamic>.from(version.snapshot),
    );
    if ((historical.projectId ?? historical.scopeId) != projectId ||
        historical.id != current.id ||
        historical.typeId != current.typeId) {
      throw StateError(
          'Historical version is not compatible with current record.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final restored = AuthorRecord(
      id: current.id,
      typeId: current.typeId,
      scopeType: historical.scopeType,
      scopeId: historical.scopeId,
      projectId: historical.projectId,
      seriesId: historical.seriesId,
      bookId: historical.bookId,
      branchId: historical.branchId,
      canonStatus: historical.canonStatus,
      title: historical.title,
      status: historical.status,
      schemaVersion: historical.schemaVersion,
      templateId: historical.templateId,
      templateVersion: historical.templateVersion,
      revision: current.revision + 1,
      fields: historical.fields,
      tags: historical.tags,
      createdAt: current.createdAt,
      updatedAt: now,
      extensionData: historical.extensionData,
    );
    await _requireValid(restored);
    final links = await repository.backlinks(current.id);
    await _validateLinks(restored, links);
    final entry = await history.forRecord(
      restored,
      changeType: AuditChangeType.restored,
      summary: 'Restored ${restored.title} from $versionId',
      timestamp: now,
      metadata: {'restoredVersionId': versionId},
    );
    await repository.putRecordWithHistory(
      record: restored,
      links: const [],
      version: entry.version,
      auditEvent: entry.audit,
    );
    return restored;
  }

  Future<List<AuthorRecord>> searchRecords(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return repository.recordsByScope(projectId);
    }
    final ids = await repository.searchEntityIds(_ftsQuery(normalized));
    final results = <AuthorRecord>[];
    for (final id in ids) {
      final record = await getRecord(id);
      if (record != null && record.status != AuthorRecordStatus.deleted) {
        results.add(record);
      }
    }
    return results;
  }

  Future<AuthorRecord> _setStatus(
    String id,
    AuthorRecordStatus status, {
    required AuditChangeType changeType,
    DateTime? timestamp,
  }) async {
    final existing = await _requireRecord(id);
    return updateRecord(
      existing.copyWith(
        status: status,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
      changeType: changeType,
    );
  }

  Future<AuthorRecord> _requireRecord(String id) async {
    final record = await getRecord(id);
    if (record == null) {
      throw StateError('Record $id does not belong to project $projectId.');
    }
    return record;
  }

  Future<void> _requireValid(AuthorRecord record) async {
    final result = await validateRecord(record);
    if (!result.isValid) {
      throw RecordValidationException(result);
    }
  }

  bool _belongsToProject(AuthorRecord record) =>
      record.projectId == projectId ||
      record.scopeId == projectId ||
      record.fields['projectId'] == projectId ||
      record.fields['_codex.projectId'] == projectId ||
      isInheritedSharedScope(
        scopeType: record.scopeType,
        scopeId: record.scopeId,
        inheritedScopeIds: inheritedScopeIds,
      );

  Future<void> _validateLinks(
    AuthorRecord record,
    List<RecordLink> links,
  ) async {
    final validator = RelationshipValidator(await connectionRegistry());
    // The record being written may not be readable yet, so its own endpoint is
    // resolved from the in-flight value instead of from the repository.
    final inFlight = RelationshipEndpoint.fromRecord(record);
    for (final link in links) {
      if (link.sourceId != record.id && link.targetId != record.id) {
        throw StateError('Link ${link.id} does not reference ${record.id}.');
      }
      final source = link.sourceId == record.id
          ? inFlight
          : await repository.relationshipEndpoint(link.sourceId);
      final target = link.targetId == record.id
          ? inFlight
          : await repository.relationshipEndpoint(link.targetId);
      final result = validator.validate(
        relationship: link,
        projectId: projectId,
        source: source,
        target: target,
      );
      if (!result.isValid) {
        throw StateError(result.errorSummary!);
      }
    }
  }
}

AuditChangeType _classifyChange(
  AuthorRecord previous,
  AuthorRecord next,
) {
  if (previous.templateId != next.templateId ||
      previous.templateVersion != next.templateVersion) {
    return AuditChangeType.templateChanged;
  }
  if (previous.canonStatus != next.canonStatus ||
      previous.status != next.status) {
    return AuditChangeType.statusChanged;
  }
  if (previous.title != next.title) return AuditChangeType.renamed;
  return AuditChangeType.updated;
}

String _ftsQuery(String query) => query
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .map((term) => '"${term.replaceAll('"', '""')}"*')
    .join(' AND ');
