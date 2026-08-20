import '../persistence/authoros_database.dart';
import 'branch_domain.dart';
import 'branch_service.dart';
import 'connected_domain.dart';
import 'connection_types.dart';
import 'record_inspection.dart';
import 'record_service.dart';
import 'record_types.dart';
import 'record_validation.dart';
import 'search_models.dart';
import 'template_engine.dart';
import 'universal_search.dart';
import 'version_audit_service.dart';
import 'version_audit.dart';

class UniversalRecordInspector {
  const UniversalRecordInspector({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);

  VersionAuditService get history => VersionAuditService(
        projectId: projectId,
        repository: repository,
      );

  UniversalSearchService get search => UniversalSearchService(
        projectId: projectId,
        repository: repository,
      );

  Future<UniversalRecordInspection?> inspectRecord(
    String recordId, {
    String? recordType,
    String? branchId,
  }) async {
    final context = await _resolveContext(recordId, branchId);
    if (context == null) return null;
    final record = context.effective ?? context.canonical;
    if (recordType != null && record.typeId != recordType) return null;

    final registry = await records.registry();
    final connectionRegistry = await records.connectionRegistry();
    final links = context.links
        .where(
            (link) => link.sourceId == record.id || link.targetId == record.id)
        .toList();
    final outgoing = <ConnectionInspection>[];
    final incoming = <ConnectionInspection>[];
    final references = <ReferenceInspection>[];
    final connectionIssues = <RecordValidationIssue>[];

    for (final link in links) {
      final inspection = await _inspectConnection(
        link,
        context,
        connectionRegistry,
        branchId,
      );
      if (link.sourceId == record.id) outgoing.add(inspection);
      if (link.targetId == record.id) incoming.add(inspection);
      final other =
          link.sourceId == record.id ? inspection.target : inspection.source;
      references.add(ReferenceInspection(
        kind: _referenceKind(other.type),
        entity: other,
        connectionId: link.id,
        connectionType: link.typeId,
        incoming: link.targetId == record.id,
      ));
      if (!inspection.valid) {
        connectionIssues.add(RecordValidationIssue(
          code: inspection.source.exists && inspection.target.exists
              ? 'invalid-connection'
              : 'broken-reference',
          message: inspection.validationMessage ??
              'Connection ${inspection.id} is invalid.',
        ));
      }
    }

    final template = _inspectTemplate(record, registry);
    final recordValidation = await records.validateRecord(record);
    final validationIssues = [
      ...recordValidation.issues,
      ...connectionIssues,
      if (branchId != null && context.branchState == null)
        RecordValidationIssue(
          code: 'invalid-branch',
          message: 'Branch $branchId does not belong to $projectId.',
        ),
      if (template.compatibility.status ==
          TemplateCompatibilityStatus.missingDefinition)
        const RecordValidationIssue(
          code: 'invalid-template',
          message: 'The record template is missing.',
        ),
      if (template.compatibility.status ==
          TemplateCompatibilityStatus.upgradeAvailable)
        RecordValidationIssue(
          code: 'template-upgrade-available',
          message: 'Template ${template.id} has an available upgrade.',
          severity: RecordValidationSeverity.warning,
        ),
    ];
    final allVersions = await history.getVersionHistory(
      recordId: record.id,
      branchId: branchId,
    );
    final versionHistory = allVersions
        .where((version) => branchId == null
            ? version.entityKind == VersionEntityKind.record
            : version.entityKind == VersionEntityKind.branchRecord)
        .toList();
    final auditHistory = await history.getAuditHistory(
      recordId: record.id,
      branchId: branchId,
    );
    final projectBranches = await repository.branchesByProject(projectId);
    final projectBranchIds = projectBranches.map((branch) => branch.id).toList();
    final recordOverlays =
      await repository.branchRecordOverlays(projectBranchIds);
    final linkOverlays = await repository.branchLinkOverlays(projectBranchIds);
    final branchDependencies = recordOverlays
        .where((overlay) => overlay.recordId == record.id)
        .map((overlay) => overlay.branchId)
        .toSet();
    for (final overlay in linkOverlays) {
      final link = overlay.link;
      if (link != null &&
          (link.sourceId == record.id || link.targetId == record.id)) {
        branchDependencies.add(overlay.branchId);
      }
    }
    final dependentIds = references
        .where((reference) => reference.entity.exists)
        .map((reference) => reference.entity.id)
        .toSet()
        .toList()
      ..sort();
    final state = _validationState(validationIssues);

    return UniversalRecordInspection(
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
      projectId: record.projectId ?? record.scopeId,
      seriesId: record.seriesId,
      bookId: record.bookId,
      branchId: branchId ?? record.branchId,
      canonStatus: record.canonStatus,
      lifecycleStatus: record.status,
      schemaVersion: record.schemaVersion,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      outgoingConnections: outgoing,
      incomingConnections: incoming,
      references: references,
      history: HistoryInspection(
        versions: versionHistory,
        auditEvents: auditHistory,
        latestVersion: versionHistory.lastOrNull,
        latestAuditEvent: auditHistory.lastOrNull,
      ),
      template: template,
      scope: ScopeInspection(
        projectId: record.projectId ?? record.scopeId,
        seriesId: record.seriesId,
        bookId: record.bookId,
        branchId: branchId ?? record.branchId,
        canonStatus: record.canonStatus,
        lifecycleStatus: record.status,
        branchState: context.branchState ?? BranchRecordState.inherited,
        visible: context.effective != null,
      ),
      validation: ValidationInspection(
        state: state,
        issues: validationIssues,
      ),
      safeDelete: SafeDeleteInspection(
        incomingConnectionCount: incoming.length,
        outgoingConnectionCount: outgoing.length,
        knownReferenceCount: references.length,
        branchDependencyCount: branchDependencies.length,
        versionCount: versionHistory.length,
        dependentEntityIds: dependentIds,
      ),
      capabilities: const InspectionCapabilities(
        supportedReferenceKinds: [
          ReferenceKind.manuscript,
          ReferenceKind.chapter,
          ReferenceKind.scene,
          ReferenceKind.codex,
          ReferenceKind.timeline,
          ReferenceKind.plot,
          ReferenceKind.world,
          ReferenceKind.universalRecord,
        ],
        unsupportedReferenceKinds: [ReferenceKind.map],
        limitations: [
          'References are derived from canonical RecordLinks and branch link overlays.',
          'Legacy name-only references are not inspectable until migrated to stable IDs.',
          'Map markers do not yet have a canonical shared reference projection.',
        ],
      ),
    );
  }

  Future<List<UniversalRecordInspection>> searchAndInspect(
    String query, {
    String? recordType,
    String? branchId,
  }) async {
    final results = branchId == null
        ? await search.searchAll(
            query,
            filter: UniversalSearchFilter(
              projectId: projectId,
              recordType: recordType,
            ),
          )
        : await search.searchByBranch(
            query,
            branchId,
            filter: UniversalSearchFilter(
              projectId: projectId,
              recordType: recordType,
            ),
          );
    final inspections = <UniversalRecordInspection>[];
    for (final result in results) {
      final inspection = await inspectRecord(
        result.recordId,
        recordType: recordType,
        branchId: branchId,
      );
      if (inspection != null) inspections.add(inspection);
    }
    return inspections;
  }

  Future<_InspectionContext?> _resolveContext(
    String recordId,
    String? branchId,
  ) async {
    final canonical = await repository.recordById(recordId);
    if (canonical != null &&
        (canonical.projectId ?? canonical.scopeId) != projectId) {
      return null;
    }
    if (branchId == null) {
      if (canonical == null) return null;
      return _InspectionContext(
        canonical: canonical,
        effective: canonical,
        records: {canonical.id: canonical},
        links: await repository.backlinks(recordId),
      );
    }
    final projectBranches = await repository.branchesByProject(projectId);
    if (!projectBranches.any((branch) => branch.id == branchId)) return null;
    final engine = await branches.loadEngine();
    final allBranchIds = projectBranches.map((branch) => branch.id).toList();
    final recordOverlays = await repository.branchRecordOverlays(allBranchIds);
    final created = recordOverlays
        .where((overlay) =>
            overlay.recordId == recordId && overlay.createdRecord != null)
        .map((overlay) => overlay.createdRecord!)
        .firstOrNull;
    final base = canonical ?? created;
    final effective = base == null ? null : engine.resolveRecord(base, branchId);
    if (canonical == null && effective == null) return null;
    final canonicalLinks = canonical == null
        ? <RecordLink>[]
        : await repository.backlinks(recordId);
    final linkOverlays = await repository.branchLinkOverlays(allBranchIds);
    final addedLinks = linkOverlays
        .where((overlay) =>
            overlay.link != null &&
            (overlay.link!.sourceId == recordId ||
                overlay.link!.targetId == recordId))
        .map((overlay) => overlay.link!);
    final effectiveLinks = engine.linksForBranch(
      [...canonicalLinks, ...addedLinks],
      branchId,
    );
    final effectiveById = <String, AuthorRecord>{
      if (effective != null) effective.id: effective,
    };
    final endpointIds = effectiveLinks
        .expand((link) => [link.sourceId, link.targetId])
        .where((id) => !effectiveById.containsKey(id))
        .toSet();
    for (final endpointId in endpointIds) {
      final stored = await repository.recordById(endpointId);
      final createdEndpoint = recordOverlays
          .where((overlay) =>
              overlay.recordId == endpointId && overlay.createdRecord != null)
          .map((overlay) => overlay.createdRecord!)
          .firstOrNull;
      final endpointBase = stored ?? createdEndpoint;
      if (endpointBase == null) continue;
      final resolved = engine.resolveRecord(endpointBase, branchId);
      if (resolved != null) effectiveById[resolved.id] = resolved;
    }
    return _InspectionContext(
      canonical: canonical ?? effective!,
      effective: effective,
      records: effectiveById,
      links: effectiveLinks,
      branchState: engine.stateFor(recordId, branchId),
    );
  }

  Future<ConnectionInspection> _inspectConnection(
    RecordLink link,
    _InspectionContext context,
    ConnectionTypeRegistry registry,
    String? branchId,
  ) async {
    final source = await _endpoint(link.sourceId, context, branchId);
    final target = await _endpoint(link.targetId, context, branchId);
    ConnectionTypeDefinition? definition;
    String? message;
    try {
      definition = registry.resolve(link.typeId);
      if (!source.exists || !target.exists) {
        message = 'Connection ${link.id} has a missing endpoint.';
      } else {
        registry.validateConnection(
          typeId: link.typeId,
          sourceTypeId: source.type,
          targetTypeId: target.type,
          metadata: link.metadata,
        );
      }
    } on StateError catch (error) {
      message = error.message;
    }
    return ConnectionInspection(
      id: link.id,
      typeId: link.typeId,
      displayName: definition?.displayName ?? link.label,
      inverseLabel: definition?.inverseLabel ?? '',
      source: source,
      target: target,
      direction: link.direction,
      metadata: Map<String, Object?>.unmodifiable(link.metadata),
      temporalMetadata: Map<String, Object?>.unmodifiable({
        for (final entry in link.metadata.entries)
          if ({
            'startDate',
            'endDate',
            'joinedDate',
            'leftDate',
            'status',
          }.contains(entry.key))
            entry.key: entry.value,
      }),
      temporalSupport: definition?.temporalSupport ?? false,
      branchId: branchId,
      valid: message == null,
      validationMessage: message,
    );
  }

  Future<InspectionEndpoint> _endpoint(
    String id,
    _InspectionContext context,
    String? branchId,
  ) async {
    final record = context.records[id];
    if (record != null) {
      return InspectionEndpoint(
        id: record.id,
        type: record.typeId,
        title: record.title,
        projectId: record.projectId ?? record.scopeId,
        branchId: branchId ?? record.branchId,
        exists: true,
      );
    }
    final node = await repository.manuscriptNodeById(id);
    if (node != null && node.projectId == projectId) {
      return InspectionEndpoint(
        id: node.id,
        type: node.nodeType,
        title: node.title,
        projectId: node.projectId,
        branchId: branchId,
        exists: true,
      );
    }
    final stored = await repository.recordById(id);
    final crossProject = stored?.projectId ?? stored?.scopeId;
    if (stored != null && crossProject == projectId) {
      return InspectionEndpoint(
        id: stored.id,
        type: stored.typeId,
        title: stored.title,
        projectId: projectId,
        branchId: branchId,
        exists: true,
      );
    }
    return InspectionEndpoint(
      id: id,
      type: stored?.typeId ?? 'unknown',
      title: stored?.title ?? 'Missing reference',
      projectId: crossProject ?? projectId,
      branchId: branchId,
      exists: false,
    );
  }
}

class _InspectionContext {
  const _InspectionContext({
    required this.canonical,
    required this.effective,
    required this.records,
    required this.links,
    this.branchState,
  });

  final AuthorRecord canonical;
  final AuthorRecord? effective;
  final Map<String, AuthorRecord> records;
  final List<RecordLink> links;
  final BranchRecordState? branchState;
}

TemplateInspection _inspectTemplate(
  AuthorRecord record,
  RecordTypeRegistry registry,
) {
  final engine = TemplateEngine(registry);
  final report = engine.inspect(record);
  final templateId = record.templateId ?? record.typeId;
  final inherited = <String>[];
  String? parentId;
  var currentId = templateId;
  final seen = <String>{};
  while (seen.add(currentId)) {
    final definition = registry.definitions
        .where((candidate) => candidate.id == currentId)
        .firstOrNull;
    if (definition == null || definition.baseTypeId == null) break;
    parentId ??= definition.baseTypeId;
    inherited.add(definition.baseTypeId!);
    currentId = definition.baseTypeId!;
  }
  return TemplateInspection(
    id: templateId,
    recordVersion: record.templateVersion ?? record.schemaVersion,
    availableVersion: report.availableVersion,
    parentTemplateId: parentId,
    inheritedTemplateIds: inherited,
    compatibility: report,
  );
}

ReferenceKind _referenceKind(String type) => switch (type) {
      'scene' => ReferenceKind.scene,
      'chapter' => ReferenceKind.chapter,
      'manuscript' || 'part' => ReferenceKind.manuscript,
      'general-lore' ||
      'research-entry' ||
      'reference' ||
      'glossary-term' ||
      'codex-entry' =>
        ReferenceKind.codex,
      'historical-event' || 'timeline-event' => ReferenceKind.timeline,
      'plot-thread' => ReferenceKind.plot,
      'location' ||
      'place' ||
      'faction' ||
      'organisation' ||
      'world' ||
      'item' ||
      'artefact' =>
        ReferenceKind.world,
      'map' || 'map-marker' => ReferenceKind.map,
      _ => ReferenceKind.universalRecord,
    };

InspectionValidationState _validationState(
  List<RecordValidationIssue> issues,
) {
  if (issues.any((issue) => issue.severity == RecordValidationSeverity.error)) {
    return InspectionValidationState.error;
  }
  if (issues.isNotEmpty) return InspectionValidationState.warning;
  return InspectionValidationState.valid;
}
