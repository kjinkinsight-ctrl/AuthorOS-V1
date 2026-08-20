import '../persistence/authoros_database.dart';
import 'branch_domain.dart';
import 'branch_engine.dart';
import 'connected_domain.dart';
import 'connection_types.dart';
import 'record_service.dart';
import 'record_validation.dart';
import 'template_engine.dart';
import 'version_audit.dart';
import 'version_audit_service.dart';

class BranchService {
  const BranchService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  VersionAuditService get history => VersionAuditService(
        projectId: projectId,
        repository: repository,
      );

  Future<StoryBranch> createBranch(StoryBranch branch) async {
    if (branch.projectId != projectId) {
      throw StateError('Branch does not belong to $projectId.');
    }
    final existing = await repository.branchesByProject(projectId);
    if (existing.any((item) => item.id == branch.id)) {
      throw StateError('A branch with id ${branch.id} already exists.');
    }
    BranchEngine(branches: [...existing, branch]);
    final entry = await history.forBranch(
      branch,
      changeType: AuditChangeType.branchChanged,
      summary: 'Created branch ${branch.name}',
      timestamp: branch.createdAt,
    );
    await repository.putBranchWithHistory(
      branch: branch,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return branch;
  }

  Future<void> overrideRecord(
    String branchId,
    String recordId, {
    String? title,
    Map<String, Object?> fields = const {},
    List<String> removedFieldIds = const [],
    List<String>? tags,
    CanonStatus? canonStatus,
    DateTime? timestamp,
  }) async {
    final engine = await loadEngine();
    final canonical = await repository.recordById(recordId) ??
        await _requireVisibleRecord(branchId, recordId);
    final overlay = BranchRecordOverlay(
      branchId: branchId,
      recordId: recordId,
      state: BranchRecordState.overridden,
      title: title,
      fields: fields,
      removedFieldIds: removedFieldIds,
      tags: tags,
      canonStatus: canonStatus,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    final candidate = await _engineWith(recordOverlay: overlay);
    final resolved = candidate.resolveRecord(canonical, branchId)!;
    final templateReport =
        TemplateEngine(await records.registry()).inspect(resolved);
    if (!templateReport.isReadable) {
      throw StateError('Branch override is not template-compatible.');
    }
    final validation = await records.validateRecord(resolved);
    if (!validation.isValid) {
      throw RecordValidationException(validation);
    }
    engine.lineage(branchId);
    final entry = await history.forRecordOverlay(
      overlay,
      recordType: resolved.typeId,
      changeType: AuditChangeType.branchChanged,
      summary: 'Updated ${resolved.title} in $branchId',
      timestamp: overlay.updatedAt,
      metadata: {'state': overlay.state.name},
    );
    await repository.putBranchRecordOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> createRecord(
    String branchId,
    AuthorRecord record, {
    DateTime? timestamp,
  }) async {
    final branch = await _requireBranch(branchId);
    if (record.projectId != projectId ||
        record.scopeType != RecordScopeType.branch ||
        record.scopeId != branchId ||
        record.branchId != branchId ||
        record.canonStatus == CanonStatus.canon) {
      throw StateError(
        'Branch-created records require branch scope and non-canon status.',
      );
    }
    final validation = await records.validateRecord(record);
    if (!validation.isValid) {
      throw RecordValidationException(validation);
    }
    final overlay = BranchRecordOverlay(
      branchId: branch.id,
      recordId: record.id,
      state: BranchRecordState.created,
      createdRecord: record,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    await _engineWith(recordOverlay: overlay);
    final entry = await history.forRecordOverlay(
      overlay,
      recordType: record.typeId,
      changeType: AuditChangeType.created,
      summary: 'Created ${record.title} in $branchId',
      timestamp: overlay.updatedAt,
      metadata: {'state': overlay.state.name},
    );
    await repository.putBranchRecordOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> hideRecord(
    String branchId,
    String recordId, {
    DateTime? timestamp,
  }) async {
    await _requireVisibleRecord(branchId, recordId);
    final overlay = BranchRecordOverlay(
      branchId: branchId,
      recordId: recordId,
      state: BranchRecordState.hidden,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    await _engineWith(recordOverlay: overlay);
    final record = await _requireVisibleRecord(branchId, recordId);
    final entry = await history.forRecordOverlay(
      overlay,
      recordType: record.typeId,
      changeType: AuditChangeType.branchChanged,
      summary: 'Hid ${record.title} in $branchId',
      timestamp: overlay.updatedAt,
      metadata: {'state': overlay.state.name},
    );
    await repository.putBranchRecordOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> updateCreatedRecord(
    String branchId,
    AuthorRecord record, {
    DateTime? timestamp,
    String? summary,
    Map<String, Object?> historyMetadata = const {},
  }) async {
    final snapshot = await repository.snapshot();
    final existing = snapshot.branchRecordOverlays
        .where((overlay) =>
            overlay.branchId == branchId &&
            overlay.recordId == record.id &&
            overlay.state == BranchRecordState.created)
        .firstOrNull;
    if (existing?.createdRecord == null ||
        record.scopeType != RecordScopeType.branch ||
        record.scopeId != branchId ||
        record.branchId != branchId ||
        record.projectId != projectId) {
      throw StateError(
          '${record.id} is not a branch-created record in $branchId.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final updated = AuthorRecord(
      id: record.id,
      typeId: record.typeId,
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
      templateId: record.templateId,
      templateVersion: record.templateVersion,
      revision: existing!.createdRecord!.revision + 1,
      fields: record.fields,
      tags: record.tags,
      createdAt: existing.createdRecord!.createdAt,
      updatedAt: now,
      extensionData: record.extensionData,
    );
    final validation = await records.validateRecord(updated);
    if (!validation.isValid) throw RecordValidationException(validation);
    final overlay = BranchRecordOverlay(
      branchId: branchId,
      recordId: updated.id,
      state: BranchRecordState.created,
      createdRecord: updated,
      updatedAt: now,
    );
    await _engineWith(recordOverlay: overlay);
    final entry = await history.forRecordOverlay(
      overlay,
      recordType: updated.typeId,
      changeType: AuditChangeType.updated,
      summary: summary ?? 'Updated ${updated.title} in $branchId',
      timestamp: now,
      metadata: historyMetadata,
    );
    await repository.putBranchRecordOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> addConnection(
    String branchId,
    RecordLink link, {
    DateTime? timestamp,
  }) async {
    final branchRecords = {
      for (final record in await recordsForBranch(branchId)) record.id: record,
    };
    final source = branchRecords[link.sourceId];
    final target = branchRecords[link.targetId];
    if (source == null || target == null || link.scopeId != projectId) {
      throw StateError('Branch connection endpoints must exist in $projectId.');
    }
    final registry = await records.connectionRegistry();
    final definition = registry.resolve(link.typeId);
    final expected = definition.direction == ConnectionDirection.directed
        ? RecordLinkDirection.directed
        : RecordLinkDirection.undirected;
    if (link.direction != expected) {
      throw StateError('${link.typeId} requires ${expected.name} links.');
    }
    registry.validateConnection(
      typeId: link.typeId,
      sourceTypeId: source.typeId,
      targetTypeId: target.typeId,
      metadata: link.metadata,
    );
    final overlay = BranchLinkOverlay(
      branchId: branchId,
      linkId: link.id,
      state: BranchLinkState.added,
      link: link,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    await _engineWith(linkOverlay: overlay);
    final entry = await history.forLinkOverlay(
      overlay,
      recordId: source.id,
      recordType: source.typeId,
      changeType: AuditChangeType.connectionAdded,
      summary: 'Added ${link.typeId} connection in $branchId',
      timestamp: overlay.updatedAt,
    );
    await repository.putBranchLinkOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<void> hideConnection(
    String branchId,
    String linkId, {
    DateTime? timestamp,
  }) async {
    final canonical = (await repository.snapshot()).links;
    if (!canonical.any((link) => link.id == linkId)) {
      throw StateError('Unknown canonical connection: $linkId');
    }
    final overlay = BranchLinkOverlay(
      branchId: branchId,
      linkId: linkId,
      state: BranchLinkState.hidden,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    await _engineWith(linkOverlay: overlay);
    final sourceType = await repository.entityTypeId(
      canonical.firstWhere((link) => link.id == linkId).sourceId,
    );
    if (sourceType == null) throw StateError('Connection source is unknown.');
    final link = canonical.firstWhere((item) => item.id == linkId);
    final entry = await history.forLinkOverlay(
      overlay,
      recordId: link.sourceId,
      recordType: sourceType,
      changeType: AuditChangeType.connectionRemoved,
      summary: 'Hid ${link.typeId} connection in $branchId',
      timestamp: overlay.updatedAt,
    );
    await repository.putBranchLinkOverlayWithHistory(
      overlay: overlay,
      version: entry.version,
      auditEvent: entry.audit,
    );
  }

  Future<BranchRecordOverlay> restoreVersion(
    String versionId, {
    DateTime? timestamp,
  }) async {
    final version = await history.getVersion(versionId);
    if (version == null ||
        version.entityKind != VersionEntityKind.branchRecord ||
        version.branchId == null) {
      throw StateError('Version $versionId is not a branch record version.');
    }
    final historical = BranchRecordOverlay.fromJson(
      Map<String, dynamic>.from(version.snapshot),
    );
    final now = (timestamp ?? DateTime.now()).toUtc();
    final restored = BranchRecordOverlay(
      branchId: historical.branchId,
      recordId: historical.recordId,
      state: historical.state,
      updatedAt: now,
      title: historical.title,
      fields: historical.fields,
      removedFieldIds: historical.removedFieldIds,
      tags: historical.tags,
      canonStatus: historical.canonStatus,
      createdRecord: historical.createdRecord,
    );
    final candidate = await _engineWith(recordOverlay: restored);
    final canonical = await repository.recordById(restored.recordId) ??
        restored.createdRecord ??
        await _requireVisibleRecord(restored.branchId, restored.recordId);
    final resolved = candidate.resolveRecord(canonical, restored.branchId);
    if (resolved == null && restored.state != BranchRecordState.hidden) {
      throw StateError('Restored branch version cannot be resolved.');
    }
    if (resolved != null) {
      final validation = await records.validateRecord(resolved);
      if (!validation.isValid) throw RecordValidationException(validation);
    }
    final entry = await history.forRecordOverlay(
      restored,
      recordType: version.recordType,
      changeType: AuditChangeType.restored,
      summary: 'Restored ${restored.recordId} in ${restored.branchId}',
      timestamp: now,
      metadata: {'restoredVersionId': versionId},
    );
    await repository.putBranchRecordOverlayWithHistory(
      overlay: restored,
      version: entry.version,
      auditEvent: entry.audit,
    );
    return restored;
  }

  Future<List<AuthorRecord>> recordsForBranch(String branchId) async =>
      (await loadEngine()).recordsForBranch(
        await repository.recordsByProject(projectId),
        branchId,
      );

  Future<List<RecordLink>> linksForBranch(String branchId) async =>
      (await loadEngine()).linksForBranch(
        (await repository.snapshot())
            .links
            .where((link) => link.scopeId == projectId),
        branchId,
      );

  Future<BranchEngine> loadEngine() async {
    final branches = await repository.branchesByProject(projectId);
    final ids = branches.map((branch) => branch.id);
    return BranchEngine(
      branches: branches,
      recordOverlays: await repository.branchRecordOverlays(ids),
      linkOverlays: await repository.branchLinkOverlays(ids),
    );
  }

  Future<BranchEngine> _engineWith({
    BranchRecordOverlay? recordOverlay,
    BranchLinkOverlay? linkOverlay,
  }) async {
    final branches = await repository.branchesByProject(projectId);
    final ids = branches.map((branch) => branch.id).toList();
    final recordOverlays = await repository.branchRecordOverlays(ids);
    final linkOverlays = await repository.branchLinkOverlays(ids);
    if (recordOverlay != null) {
      recordOverlays.removeWhere((item) =>
          item.branchId == recordOverlay.branchId &&
          item.recordId == recordOverlay.recordId);
      recordOverlays.add(recordOverlay);
    }
    if (linkOverlay != null) {
      linkOverlays.removeWhere((item) =>
          item.branchId == linkOverlay.branchId &&
          item.linkId == linkOverlay.linkId);
      linkOverlays.add(linkOverlay);
    }
    return BranchEngine(
      branches: branches,
      recordOverlays: recordOverlays,
      linkOverlays: linkOverlays,
    );
  }

  Future<AuthorRecord> _requireCanonical(String recordId) async {
    final record = await repository.recordById(recordId);
    if (record == null ||
        (record.projectId ?? record.scopeId) != projectId ||
        record.branchId != null) {
      throw StateError('Unknown canonical record: $recordId');
    }
    return record;
  }

  Future<AuthorRecord> _requireVisibleRecord(
    String branchId,
    String recordId,
  ) async {
    return (await recordsForBranch(branchId))
            .where((record) => record.id == recordId)
            .firstOrNull ??
        (throw StateError('Record $recordId is not visible in $branchId.'));
  }

  Future<StoryBranch> _requireBranch(String branchId) async {
    final branches = await repository.branchesByProject(projectId);
    return branches.where((branch) => branch.id == branchId).firstOrNull ??
        (throw StateError('Unknown branch: $branchId'));
  }
}
