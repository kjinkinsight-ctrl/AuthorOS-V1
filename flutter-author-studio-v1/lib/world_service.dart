import 'dart:convert';

import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/search_models.dart';
import 'core/template_engine.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'core/world_record_types.dart';
import 'persistence/authoros_database.dart';

class WorldHierarchyException implements Exception {
  const WorldHierarchyException(this.message);

  final String message;

  @override
  String toString() => 'WorldHierarchyException: $message';
}

class WorldHierarchy {
  WorldHierarchy({
    required Iterable<AuthorRecord> records,
    required Iterable<RecordLink> links,
  })  : records = {for (final record in records) record.id: record},
        links = links.toList();

  final Map<String, AuthorRecord> records;
  final List<RecordLink> links;

  AuthorRecord? record(String id) => records[id];

  AuthorRecord? parentOf(String id) {
    final parentId = _parentId(id);
    return parentId == null ? null : records[parentId];
  }

  List<AuthorRecord> childrenOf(String id) => _childIds(id)
      .map((childId) => records[childId])
      .whereType<AuthorRecord>()
      .toList()
    ..sort(_byTitle);

  List<AuthorRecord> siblingsOf(String id) {
    final parent = parentOf(id);
    if (parent == null) return const [];
    return childrenOf(parent.id).where((record) => record.id != id).toList();
  }

  List<AuthorRecord> ancestorsOf(String id) {
    final result = <AuthorRecord>[];
    final visited = <String>{id};
    var currentId = id;
    while (true) {
      final parentId = _parentId(currentId);
      if (parentId == null || !visited.add(parentId)) break;
      final parent = records[parentId];
      if (parent == null) break;
      result.add(parent);
      currentId = parentId;
    }
    return result;
  }

  List<AuthorRecord> descendantsOf(String id) {
    final result = <AuthorRecord>[];
    final visited = <String>{id};
    final pending = <String>[id];
    while (pending.isNotEmpty) {
      final currentId = pending.removeAt(0);
      for (final childId in _childIds(currentId)) {
        if (!visited.add(childId)) continue;
        final child = records[childId];
        if (child != null) {
          result.add(child);
          pending.add(childId);
        }
      }
    }
    return result;
  }

  AuthorRecord? rootOf(String id) {
    final ancestors = ancestorsOf(id);
    return ancestors.isEmpty ? records[id] : ancestors.last;
  }

  AuthorRecord? rootUniverseOf(String id) =>
      ancestorsOf(id).where((record) => record.typeId == 'universe').lastOrNull;

  AuthorRecord? rootWorldOf(String id) {
    final lineage = [records[id], ...ancestorsOf(id)].whereType<AuthorRecord>();
    return lineage.where((record) => record.typeId == 'world').lastOrNull;
  }

  String? _parentId(String id) {
    for (final link in links) {
      if (_childToParentTypes.contains(link.typeId) && link.sourceId == id) {
        return link.targetId;
      }
      if (link.typeId == 'contains' && link.targetId == id) {
        return link.sourceId;
      }
    }
    return null;
  }

  Set<String> _childIds(String id) {
    final result = <String>{};
    for (final link in links) {
      if (_childToParentTypes.contains(link.typeId) && link.targetId == id) {
        result.add(link.sourceId);
      }
      if (link.typeId == 'contains' && link.sourceId == id) {
        result.add(link.targetId);
      }
    }
    return result;
  }
}

class WorldService {
  const WorldService({
    required this.projectId,
    required this.repository,
  });

  static const canonStateField = '_world.canonState';
  static const canonStates = <String>{
    'Canon',
    'Draft',
    'Proposed',
    'Deprecated',
    'Non-Canon',
    'Alternate',
  };

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);
  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);
  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);
  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);
  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);
  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);
  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);

  Future<AuthorRecord> createWorldRecord({
    required String id,
    required String title,
    String typeId = 'location',
    String? templateId,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    RecordScopeType scopeType = RecordScopeType.project,
    String? scopeId,
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus canonStatus = CanonStatus.draft,
    String canonState = 'Draft',
    DateTime? timestamp,
  }) async {
    final normalizedTitle = title.trim();
    if (id.trim().isEmpty || normalizedTitle.isEmpty) {
      throw ArgumentError('World record id and title are required.');
    }
    if (!canonStates.contains(canonState)) {
      throw ArgumentError.value(canonState, 'canonState', 'is not supported');
    }
    final registry = await records.registry();
    final selectedTemplate = templateId ?? typeId;
    _requireWorldTemplate(registry, selectedTemplate);
    if (!registry.isTemplateCompatible(selectedTemplate, typeId)) {
      throw StateError('$selectedTemplate is not compatible with $typeId.');
    }
    final definition = registry.resolve(selectedTemplate);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = AuthorRecord(
      id: id,
      typeId: typeId,
      templateId: selectedTemplate,
      templateVersion: definition.templateVersion,
      scopeType: scopeType,
      scopeId: scopeId ??
          (scopeType == RecordScopeType.branch
              ? branchId ?? projectId
              : projectId),
      projectId: projectId,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: normalizedTitle,
      schemaVersion: definition.templateVersion,
      fields: {
        'primaryName': normalizedTitle,
        canonStateField: canonState,
        ...fields,
      },
      tags: tags,
      createdAt: now,
      updatedAt: now,
      extensionData: const {'worldStudio': true},
    );
    if (scopeType == RecordScopeType.branch) {
      if (branchId == null) {
        throw StateError('Branch-created World records require a branch id.');
      }
      await branches.createRecord(branchId, record, timestamp: now);
      return record;
    }
    return records.createRecord(record);
  }

  Future<AuthorRecord> createFromTemplate({
    required String id,
    required String title,
    required String templateId,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    DateTime? timestamp,
  }) async {
    final registry = await records.registry();
    _requireWorldTemplate(registry, templateId);
    final typeId = WorldRecordTypes.isBuiltInWorldType(templateId)
        ? templateId
        : registry.isTemplateCompatible(templateId, 'world')
            ? 'world'
            : registry.isTemplateCompatible(templateId, 'map')
                ? 'map'
                : registry.isTemplateCompatible(templateId, 'travel-route')
                    ? 'travel-route'
                    : 'location';
    return createWorldRecord(
      id: id,
      title: title,
      typeId: typeId,
      templateId: templateId,
      fields: fields,
      tags: tags,
      timestamp: timestamp,
    );
  }

  Future<AuthorRecord?> getWorldRecord(String id) async {
    final record = await records.getRecord(id);
    if (record == null) return null;
    return await _isWorldRecord(record) ? record : null;
  }

  Future<AuthorRecord> updateWorldRecord(
    AuthorRecord record, {
    AuditChangeType? changeType,
    String? summary,
  }) async {
    await _requireWorldRecord(record.id);
    if (!await _isWorldRecord(record)) {
      throw StateError('${record.id} is not a World record.');
    }
    return records.updateRecord(
      record,
      changeType: changeType,
      summary: summary,
    );
  }

  Future<AuthorRecord> archiveWorldRecord(String id,
      {DateTime? timestamp}) async {
    await _requireWorldRecord(id);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> restoreWorldRecord(String id,
      {DateTime? timestamp}) async {
    await _requireWorldRecord(id);
    return records.restoreRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> duplicateWorldRecord(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    await _requireWorldRecord(id);
    return records.duplicateRecord(id,
        newId: newId, title: title, timestamp: timestamp);
  }

  Future<AuthorRecord> changeTemplate(
    String id, {
    required String templateId,
    DateTime? timestamp,
  }) async {
    final existing = await _requireWorldRecord(id);
    final registry = await records.registry();
    _requireWorldTemplate(registry, templateId);
    if (!registry.isTemplateCompatible(templateId, existing.typeId)) {
      throw StateError(
          '$templateId is not compatible with ${existing.typeId}.');
    }
    final definition = registry.resolve(templateId);
    final changed = AuthorRecord(
      id: existing.id,
      typeId: existing.typeId,
      templateId: templateId,
      templateVersion: definition.templateVersion,
      scopeType: existing.scopeType,
      scopeId: existing.scopeId,
      projectId: existing.projectId,
      seriesId: existing.seriesId,
      bookId: existing.bookId,
      branchId: existing.branchId,
      canonStatus: existing.canonStatus,
      title: existing.title,
      status: existing.status,
      schemaVersion: definition.templateVersion,
      revision: existing.revision,
      fields: existing.fields,
      tags: existing.tags,
      createdAt: existing.createdAt,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      extensionData: existing.extensionData,
    );
    return records.updateRecord(
      changed,
      changeType: AuditChangeType.templateChanged,
      summary: 'Changed ${existing.title} to $templateId',
    );
  }

  Future<void> registerCustomTemplate(RecordTypeDefinition template) async {
    if (template.scopeType != RecordScopeType.project ||
        template.scopeId != projectId ||
        template.baseTypeId == null) {
      throw StateError('Custom World templates must be scoped to $projectId.');
    }
    final registry = await records.registry();
    _requireWorldTemplate(registry, template.baseTypeId!);
    await repository.putRecordTypeDefinition(template);
  }

  Future<RecordLink> connectWorldRecord({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    final source = await records.getRecord(sourceId);
    final target = await records.getRecord(targetId);
    if (source == null || target == null) {
      throw StateError('World connection endpoints must exist in $projectId.');
    }
    if (!await _isWorldRecord(source) && !await _isWorldRecord(target)) {
      throw StateError('At least one endpoint must be a World record.');
    }
    return connections.connect(
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      label: label,
      direction: direction,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<WorldHierarchy> hierarchy({String? branchId}) async {
    final allRecords = branchId == null
        ? await repository.recordsByProject(projectId)
        : await branches.recordsForBranch(branchId);
    final allLinks = branchId == null
        ? (await repository.snapshot())
            .links
            .where((link) => link.scopeId == projectId)
        : await branches.linksForBranch(branchId);
    return WorldHierarchy(
      records: allRecords.where(
          (record) => WorldRecordTypes.spatialTypeIds.contains(record.typeId)),
      links: allLinks.where((link) => _hierarchyTypes.contains(link.typeId)),
    );
  }

  Future<RecordLink> setParent({
    required String childId,
    required String parentId,
    String? branchId,
    DateTime? timestamp,
  }) async {
    if (childId == parentId) {
      throw const WorldHierarchyException(
          'A location cannot be its own parent.');
    }
    final child = await _worldRecordInView(childId, branchId);
    final parent = await _worldRecordInView(parentId, branchId);
    if (!WorldRecordTypes.spatialTypeIds.contains(child.typeId) ||
        !WorldRecordTypes.spatialTypeIds.contains(parent.typeId)) {
      throw const WorldHierarchyException(
          'Hierarchy endpoints must be spatial records.');
    }
    final model = await hierarchy(branchId: branchId);
    if (model.ancestorsOf(parentId).any((record) => record.id == childId)) {
      throw WorldHierarchyException('$parentId is already below $childId.');
    }
    final existing = _parentLink(model.links, childId);
    final link = _link(
      sourceId: childId,
      targetId: parentId,
      typeId: 'locatedIn',
      timestamp: timestamp,
    );
    if (branchId != null) {
      if (existing != null)
        await branches.hideConnection(branchId, existing.id);
      await branches.addConnection(branchId, link, timestamp: timestamp);
      return link;
    }
    if (child.branchId != parent.branchId) {
      throw const WorldHierarchyException(
          'Hierarchy endpoints must share a branch.');
    }
    if (existing != null)
      await connections.disconnect(existing.id, timestamp: timestamp);
    return connections.connect(
      sourceId: childId,
      targetId: parentId,
      typeId: 'locatedIn',
      timestamp: timestamp,
    );
  }

  Future<AuthorRecord?> getParent(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).parentOf(id);

  Future<List<AuthorRecord>> getChildren(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).childrenOf(id);

  Future<List<AuthorRecord>> getSiblings(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).siblingsOf(id);

  Future<List<AuthorRecord>> getAncestors(String id,
          {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).ancestorsOf(id);

  Future<List<AuthorRecord>> getDescendants(String id,
          {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).descendantsOf(id);

  Future<AuthorRecord?> getRoot(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).rootOf(id);

  Future<AuthorRecord?> getRootWorld(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).rootWorldOf(id);

  Future<AuthorRecord?> getRootUniverse(String id, {String? branchId}) async =>
      (await hierarchy(branchId: branchId)).rootUniverseOf(id);

  Future<AuthorRecord> createMap({
    required String id,
    required String title,
    required String mappedRecordId,
    String typeId = 'map',
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    await _requireWorldRecord(mappedRecordId);
    final map = await createWorldRecord(
      id: id,
      title: title,
      typeId: typeId,
      fields: metadata,
      timestamp: timestamp,
    );
    await connectWorldRecord(
      sourceId: map.id,
      targetId: mappedRecordId,
      typeId: 'maps',
      timestamp: timestamp,
    );
    return map;
  }

  Future<AuthorRecord> createMapMarker({
    required String markerId,
    required String mapId,
    required String recordId,
    required num x,
    required num y,
    String label = '',
    String icon = '',
    String category = '',
    String visibility = 'visible',
    String notes = '',
    DateTime? timestamp,
  }) async {
    final map = await _requireWorldRecord(mapId);
    if (!WorldRecordTypes.mapTypeIds.contains(map.typeId)) {
      throw StateError('$mapId is not a map.');
    }
    if (await records.getRecord(recordId) == null) {
      throw StateError('Marker target $recordId does not exist in $projectId.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final marker = await createWorldRecord(
      id: markerId,
      title: label.trim().isEmpty ? markerId : label,
      typeId: 'map-marker',
      fields: {
        'mapId': mapId,
        'recordId': recordId,
        'x': x,
        'y': y,
        'label': label,
        'icon': icon,
        'category': category,
        'visibility': visibility,
        'markerNotes': notes,
      },
      timestamp: now,
    );
    await connectWorldRecord(
        sourceId: marker.id, targetId: mapId, typeId: 'onMap', timestamp: now);
    await connectWorldRecord(
        sourceId: marker.id,
        targetId: recordId,
        typeId: 'represents',
        timestamp: now);
    return marker;
  }

  Future<AuthorRecord> createRoute({
    required String id,
    required String title,
    required String startId,
    required String endId,
    String typeId = 'travel-route',
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    if (startId == endId) throw ArgumentError('Route endpoints must differ.');
    final start = await _requireWorldRecord(startId);
    final end = await _requireWorldRecord(endId);
    if (!WorldRecordTypes.spatialTypeIds.contains(start.typeId) ||
        !WorldRecordTypes.spatialTypeIds.contains(end.typeId)) {
      throw StateError('Route endpoints must be spatial records.');
    }
    final route = await createWorldRecord(
      id: id,
      title: title,
      typeId: typeId,
      fields: {'startId': startId, 'endId': endId, ...metadata},
      timestamp: timestamp,
    );
    await connectWorldRecord(
        sourceId: route.id,
        targetId: startId,
        typeId: 'routeFrom',
        timestamp: timestamp);
    await connectWorldRecord(
        sourceId: route.id,
        targetId: endId,
        typeId: 'routeTo',
        timestamp: timestamp);
    return route;
  }

  Future<List<AuthorRecord>> getConnectedCharacters(String id) =>
      _connectedRecordsOfTypes(id, const {'character'});

  Future<List<AuthorRecord>> getConnectedFactions(String id) =>
      _connectedRecordsOfTypes(
          id, const {'faction', 'organisation', 'government', 'house', 'clan'});

  Future<List<AuthorRecord>> getTimeline(String id) => _connectedRecordsOfTypes(
      id, const {'timeline-event', 'historical-event'});

  Future<List<AuthorRecord>> getMaps(String id) =>
      _connectedRecordsOfTypes(id, WorldRecordTypes.mapTypeIds);

  Future<List<AuthorRecord>> getRoutes(String id) =>
      _connectedRecordsOfTypes(id, WorldRecordTypes.routeTypeIds);

  Future<List<SearchResult>> searchWorldRecords(String query) async {
    final results = await search.searchAll(query);
    return results
        .where((result) =>
            WorldRecordTypes.worldDomainTypeIds.contains(result.recordType))
        .toList();
  }

  Future<RecordValidationResult> validateWorldRecord(
      AuthorRecord record) async {
    if (!await _isWorldRecord(record)) {
      throw StateError('${record.id} is not a World record.');
    }
    return records.validateRecord(record);
  }

  Future<TemplateCompatibilityReport> inspectTemplate(
      AuthorRecord record) async {
    if (!await _isWorldRecord(record)) {
      throw StateError('${record.id} is not a World record.');
    }
    return TemplateEngine(await records.registry()).inspect(record);
  }

  Future<UniversalRecordInspection?> inspectWorldRecord(String id,
      {String? branchId}) async {
    final record = await _requireWorldRecord(id);
    return inspector.inspectRecord(id,
        recordType: record.typeId, branchId: branchId);
  }

  Future<List<RecordVersion>> getWorldHistory(String id,
      {String? branchId}) async {
    await _requireWorldRecord(id);
    return history.getVersionHistory(recordId: id, branchId: branchId);
  }

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) async {
    await _requireWorldRecord(id);
    return safeDelete.analyze(id);
  }

  Future<void> overrideWorldRecordInBranch(
    String branchId,
    String recordId, {
    String? title,
    Map<String, Object?> fields = const {},
    List<String> removedFieldIds = const [],
    List<String>? tags,
    CanonStatus? canonStatus,
    DateTime? timestamp,
  }) async {
    await _requireWorldRecord(recordId);
    return branches.overrideRecord(
      branchId,
      recordId,
      title: title,
      fields: fields,
      removedFieldIds: removedFieldIds,
      tags: tags,
      canonStatus: canonStatus,
      timestamp: timestamp,
    );
  }

  Future<List<AuthorRecord>> _connectedRecordsOfTypes(
      String id, Set<String> typeIds) async {
    await _requireWorldRecord(id);
    final linked = await connections.linkedRecords(id);
    return linked.where((record) => typeIds.contains(record.typeId)).toList();
  }

  Future<AuthorRecord> _requireWorldRecord(String id) async {
    final record = await getWorldRecord(id);
    if (record == null)
      throw StateError('$id is not a World record in $projectId.');
    return record;
  }

  Future<AuthorRecord> _worldRecordInView(String id, String? branchId) async {
    if (branchId == null) return _requireWorldRecord(id);
    final record = (await branches.recordsForBranch(branchId))
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (record == null || !await _isWorldRecord(record)) {
      throw StateError('$id is not visible in $branchId.');
    }
    return record;
  }

  Future<bool> _isWorldRecord(AuthorRecord record) async {
    if ((record.projectId ?? record.scopeId) != projectId) return false;
    if (WorldRecordTypes.isBuiltInWorldType(record.typeId)) return true;
    final registry = await records.registry();
    final templateId = record.templateId ?? record.typeId;
    return _isWorldTemplate(registry, templateId);
  }

  void _requireWorldTemplate(RecordTypeRegistry registry, String templateId) {
    if (!_isWorldTemplate(registry, templateId)) {
      throw StateError('$templateId is not a World template.');
    }
  }

  bool _isWorldTemplate(RecordTypeRegistry registry, String templateId) {
    try {
      return WorldRecordTypes.isBuiltInWorldType(templateId) ||
          registry.isTemplateCompatible(templateId, 'location') ||
          registry.isTemplateCompatible(templateId, 'world') ||
          registry.isTemplateCompatible(templateId, 'map') ||
          registry.isTemplateCompatible(templateId, 'map-marker') ||
          registry.isTemplateCompatible(templateId, 'travel-route');
    } on StateError {
      return false;
    }
  }

  RecordLink _link({
    required String sourceId,
    required String targetId,
    required String typeId,
    DateTime? timestamp,
  }) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final identity = base64Url
        .encode(utf8.encode('$projectId|$sourceId|$typeId|$targetId'))
        .replaceAll('=', '');
    return RecordLink(
      id: 'link-$identity',
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      scopeId: projectId,
      createdAt: now,
      updatedAt: now,
    );
  }
}

const _childToParentTypes = <String>{'locatedIn', 'partOf', 'inside'};
const _hierarchyTypes = <String>{..._childToParentTypes, 'contains'};

RecordLink? _parentLink(Iterable<RecordLink> links, String childId) {
  for (final link in links) {
    if (_childToParentTypes.contains(link.typeId) && link.sourceId == childId) {
      return link;
    }
    if (link.typeId == 'contains' && link.targetId == childId) return link;
  }
  return null;
}

int _byTitle(AuthorRecord left, AuthorRecord right) =>
    left.title.toLowerCase().compareTo(right.title.toLowerCase());
