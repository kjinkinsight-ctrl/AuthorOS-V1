import 'dart:convert';

import 'core/branch_domain.dart';
import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
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
import 'core/world_domain.dart';
import 'core/world_record_types.dart';
import 'persistence/authoros_database.dart';

export 'core/world_domain.dart';

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
  static const customFieldsField = '_world.customFields';
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

  // ---------------------------------------------------------------------
  // Phase 2 workspace surface.
  //
  // Everything below composes the existing services (RecordService,
  // ConnectionEngine, BranchService, UniversalSearchService, RecordValidator,
  // TemplateEngine, SafeDeleteService) rather than reaching past them. No new
  // store, index, or history log.
  // ---------------------------------------------------------------------

  /// Active story branches for this project, newest first.
  Future<List<StoryBranch>> getBranches() async =>
      (await repository.branchesByProject(projectId))
          .where((branch) => branch.status == BranchStatus.active)
          .toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

  Future<ConnectionTypeRegistry> connectionRegistry() =>
      records.connectionRegistry();

  /// Every template the World workspace can create from, built-in or custom.
  ///
  /// Definitions are returned resolved, so a derived template such as `city`
  /// carries the fields and sections it inherits from `location` instead of
  /// looking empty in the editor.
  Future<List<RecordTypeDefinition>> worldTemplates() async {
    final registry = await records.registry();
    final resolved = <RecordTypeDefinition>[];
    for (final definition in registry.definitions) {
      if (definition.extensionData['selectableForNewRecords'] == false) continue;
      if (definition.extensionData['archived'] == true) continue;
      if (!_isWorldTemplate(registry, definition.id)) continue;
      try {
        resolved.add(registry.resolve(definition.id));
      } on StateError {
        continue;
      }
    }
    return resolved
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  /// A [ConnectionEngine] that also resolves this project's custom connection
  /// types. [connections] stays available for the built-in-only Phase 1 path.
  Future<ConnectionEngine> projectConnectionEngine() async => ConnectionEngine(
        scopeId: projectId,
        repository: repository,
        registry: await connectionRegistry(),
      );

  /// Connection types that permit `sourceTypeId -> targetTypeId`.
  Future<List<ConnectionTypeDefinition>> connectionTypesBetween({
    required String sourceTypeId,
    required String targetTypeId,
  }) async =>
      (await connectionRegistry())
          .definitions
          .where((definition) => definition.permits(sourceTypeId, targetTypeId))
          .toList()
        ..sort((left, right) => left.displayName.compareTo(right.displayName));

  /// Every World-domain record visible in the current scope.
  Future<List<AuthorRecord>> worldRecords({
    String? branchId,
    bool includeArchived = true,
  }) async {
    final visible = branchId == null
        ? await repository.recordsByProject(projectId)
        : await branches.recordsForBranch(branchId);
    final result = <AuthorRecord>[];
    for (final record in visible) {
      if (record.status == AuthorRecordStatus.deleted) continue;
      if (!includeArchived && record.status == AuthorRecordStatus.archived) {
        continue;
      }
      if (!await _isWorldRecord(record)) continue;
      result.add(record);
    }
    result.sort((left, right) =>
        left.title.toLowerCase().compareTo(right.title.toLowerCase()));
    return result;
  }

  /// Records that can sit at either end of a World connection, across every
  /// Studio in the project.
  Future<List<AuthorRecord>> connectableRecords({String? branchId}) async {
    final visible = branchId == null
        ? (await repository.snapshot())
            .records
            .where((record) => (record.projectId ?? record.scopeId) == projectId)
            .toList()
        : await branches.recordsForBranch(branchId);
    return visible
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));
  }

  /// Applies a [WorldFilter].
  ///
  /// Text queries are answered by [UniversalSearchService]; the remaining
  /// facets narrow that result set in memory. No second index is built.
  Future<List<AuthorRecord>> filterWorldRecords(
    WorldFilter filter, {
    String? branchId,
  }) async {
    final all = await worldRecords(branchId: branchId);
    final ordered = <AuthorRecord>[];
    if (filter.query.trim().isEmpty) {
      ordered.addAll(all);
    } else {
      final results = branchId == null
          ? await search.searchByProject(filter.query.trim(), projectId)
          : await search.searchByBranch(filter.query.trim(), branchId);
      final rank = <String, int>{
        for (var index = 0; index < results.length; index += 1)
          results[index].recordId: index,
      };
      ordered.addAll(
        all.where((record) => rank.containsKey(record.id)).toList()
          ..sort((left, right) => rank[left.id]!.compareTo(rank[right.id]!)),
      );
    }

    final invalidIds = filter.onlyInvalid
        ? (await validateRecords(ordered))
            .entries
            .where((item) =>
                !item.value.isValid || item.value.warnings.isNotEmpty)
            .map((item) => item.key)
            .toSet()
        : const <String>{};

    final groupTypes = filter.group.typeIds;
    final matched = ordered.where((record) {
      if (!filter.includeArchived &&
          record.status == AuthorRecordStatus.archived) {
        return false;
      }
      if (!groupTypes.contains(record.typeId)) return false;
      if (filter.typeIds.isNotEmpty && !filter.typeIds.contains(record.typeId)) {
        return false;
      }
      if (filter.canonStates.isNotEmpty &&
          !filter.canonStates.contains(worldCanonState(record))) {
        return false;
      }
      if (filter.tagIds.isNotEmpty && !record.tags.any(filter.tagIds.contains)) {
        return false;
      }
      if (filter.onlyInvalid && !invalidIds.contains(record.id)) return false;
      return true;
    }).toList();

    switch (filter.sort) {
      case WorldSort.title:
      case WorldSort.hierarchy:
        matched.sort((left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()));
      case WorldSort.recentlyUpdated:
        matched.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    }
    return matched;
  }

  /// Builds the hierarchy tree for the workspace.
  ///
  /// When [visibleIds] is given, a node is kept if it matches or if one of its
  /// descendants matches, so the path down to a search hit stays navigable.
  Future<List<WorldTreeNode>> hierarchyTree({
    String? branchId,
    Set<String>? visibleIds,
    bool includeArchived = true,
  }) async {
    final model = await hierarchy(branchId: branchId);
    final all = <String, AuthorRecord>{
      for (final record in model.records.values)
        if (record.status != AuthorRecordStatus.deleted &&
            (includeArchived || record.status != AuthorRecordStatus.archived))
          record.id: record,
    };
    final roots = all.values
        .where((record) => model.parentOf(record.id) == null)
        .toList()
      ..sort((left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()));

    WorldTreeNode? build(AuthorRecord record, int depth, Set<String> seen) {
      if (!seen.add(record.id)) return null;
      final children = <WorldTreeNode>[];
      for (final child in model.childrenOf(record.id)) {
        if (!all.containsKey(child.id)) continue;
        final node = build(child, depth + 1, seen);
        if (node != null) children.add(node);
      }
      final matches = visibleIds == null || visibleIds.contains(record.id);
      if (!matches && children.isEmpty) return null;
      return WorldTreeNode(
        record: record,
        depth: depth,
        children: children,
        matchesFilter: matches,
      );
    }

    final seen = <String>{};
    final tree = <WorldTreeNode>[];
    for (final root in roots) {
      final node = build(root, 0, seen);
      if (node != null) tree.add(node);
    }
    return tree;
  }

  /// Validates many records against one registry build.
  Future<Map<String, RecordValidationResult>> validateRecords(
    Iterable<AuthorRecord> candidates,
  ) async {
    final validator = RecordValidator(await records.registry());
    return {
      for (final record in candidates)
        record.id: validator.validate(record, projectId: projectId),
    };
  }

  /// Template drift for many records against one registry build.
  Future<Map<String, TemplateCompatibilityReport>> templateReports(
    Iterable<AuthorRecord> candidates,
  ) async {
    final engine = TemplateEngine(await records.registry());
    return {
      for (final record in candidates) record.id: engine.inspect(record),
    };
  }

  /// Field ids on [record]'s template that reference a place.
  Future<Set<String>> locationReferenceFieldIds(AuthorRecord record) async {
    final registry = await records.registry();
    try {
      return registry
          .resolve(record.templateId ?? record.typeId)
          .fields
          .where((field) => field.type == RecordFieldType.locationReference)
          .map((field) => field.id)
          .toSet();
    } on StateError {
      return const {};
    }
  }

  /// Refuses a Canon mutation while a branch is active.
  void requireCanonScope(String? activeBranchId, String action) {
    if (activeBranchId != null) {
      throw StateError(
        '$action changes Canon and is not available while the $activeBranchId '
        'branch is active. Override the record in the branch instead.',
      );
    }
  }

  /// Sets the World canon state. Refuses to touch Canon from a branch.
  Future<AuthorRecord> setCanonState(
    String id,
    String canonState, {
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    requireCanonScope(activeBranchId, 'Changing the canon state');
    if (!canonStates.contains(canonState)) {
      throw ArgumentError.value(canonState, 'canonState', 'is not supported');
    }
    final existing = await _requireWorldRecord(id);
    return records.updateRecord(
      existing.copyWith(
        fields: {...existing.fields, canonStateField: canonState},
        canonStatus: _canonStatusFor(canonState),
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
      changeType: AuditChangeType.statusChanged,
      summary: 'Set ${existing.title} to $canonState',
    );
  }

  /// Saves editor changes to a World record, routing branch edits to overlays.
  Future<void> saveWorldRecord(
    String id, {
    required String title,
    Map<String, Object?> fields = const {},
    List<String>? tags,
    String? canonState,
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('A World record title is required.');
    }
    if (activeBranchId != null) {
      if (canonState == 'Canon') {
        throw StateError('A branch cannot promote a record to Canon.');
      }
      await overrideWorldRecordInBranch(
        activeBranchId,
        id,
        title: normalizedTitle,
        fields: {
          ...fields,
          'primaryName': normalizedTitle,
          if (canonState != null) canonStateField: canonState,
        },
        tags: tags,
        timestamp: timestamp,
      );
      return;
    }
    final existing = await _requireWorldRecord(id);
    await records.updateRecord(
      existing.copyWith(
        title: normalizedTitle,
        fields: {
          ...existing.fields,
          ...fields,
          'primaryName': normalizedTitle,
          if (canonState != null) canonStateField: canonState,
        },
        tags: tags,
        canonStatus:
            canonState == null ? null : _canonStatusFor(canonState),
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  /// Adds or updates an author-defined field that no template declares.
  ///
  /// The value lives in the record's own field map so it round-trips like any
  /// template field; the label is remembered in World metadata.
  Future<AuthorRecord> setCustomField(
    String id,
    String fieldId,
    String label,
    Object? value, {
    DateTime? timestamp,
  }) async {
    final normalized = fieldId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('A custom field key is required.');
    }
    if (normalized.startsWith('_world.')) {
      throw ArgumentError('Custom fields cannot use the reserved _world prefix.');
    }
    final existing = await _requireWorldRecord(id);
    final raw = existing.fields[customFieldsField];
    final labels = <String, Object?>{
      if (raw is Map)
        for (final item in raw.entries) item.key.toString(): item.value,
      normalized: label.trim().isEmpty ? normalized : label.trim(),
    };
    return records.updateRecord(existing.copyWith(
      fields: {
        ...existing.fields,
        normalized: value,
        customFieldsField: labels,
      },
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    ));
  }

  /// Author-declared labels for custom fields on [record].
  static Map<String, String> customFieldLabels(AuthorRecord record) {
    final raw = record.fields[customFieldsField];
    if (raw is! Map) return const {};
    return {
      for (final item in raw.entries) item.key.toString(): '${item.value}',
    };
  }

  /// Removes the parent link of [childId] without deleting either record.
  Future<void> clearParent(String childId, {String? branchId}) async {
    final model = await hierarchy(branchId: branchId);
    final existing = _parentLink(model.links, childId);
    if (existing == null) return;
    if (branchId != null) {
      await branches.hideConnection(branchId, existing.id);
      return;
    }
    await connections.disconnect(existing.id);
  }

  /// Creates a relationship from a World record.
  ///
  /// With [activeBranchId] set the link is added as a branch overlay so Canon
  /// is never mutated from a branch.
  Future<RecordLink> connectRecord({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    Map<String, Object?> metadata = const {},
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    final definition = (await connectionRegistry()).resolve(typeId);
    final direction = definition.direction == ConnectionDirection.directed
        ? RecordLinkDirection.directed
        : RecordLinkDirection.undirected;
    final resolvedLabel = label.isEmpty ? definition.displayName : label;
    if (activeBranchId == null) {
      final engine = await projectConnectionEngine();
      return engine.connect(
        sourceId: sourceId,
        targetId: targetId,
        typeId: typeId,
        label: resolvedLabel,
        direction: direction,
        metadata: metadata,
        timestamp: timestamp,
      );
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final identity = base64Url
        .encode(utf8.encode('$activeBranchId|$sourceId|$typeId|$targetId'))
        .replaceAll('=', '');
    final link = RecordLink(
      id: 'branch-link-$identity',
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      scopeId: projectId,
      direction: direction,
      label: resolvedLabel,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
    await branches.addConnection(activeBranchId, link, timestamp: now);
    return link;
  }

  Future<RecordLink> updateRecordConnection(
    String linkId, {
    String? typeId,
    String? label,
    Map<String, Object?>? metadata,
    DateTime? timestamp,
  }) async {
    final engine = await projectConnectionEngine();
    return engine.updateConnection(
      linkId,
      typeId: typeId,
      label: label,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  /// Removes a relationship. On a branch the canonical link is hidden by an
  /// overlay instead of being deleted.
  Future<void> disconnectRecord(
    String linkId, {
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    if (activeBranchId == null) {
      final engine = await projectConnectionEngine();
      await engine.disconnect(linkId, timestamp: timestamp);
      return;
    }
    await branches.hideConnection(activeBranchId, linkId, timestamp: timestamp);
  }

  /// Connections attached to [id] in the current scope.
  Future<List<RecordLink>> connectionsFor(String id, {String? branchId}) async {
    if (branchId == null) return connections.connections(id);
    return (await branches.linksForBranch(branchId))
        .where((link) => link.sourceId == id || link.targetId == id)
        .toList();
  }

  // --- Maps, markers and routes ------------------------------------------

  /// The map records attached to [id] plus every map in the project when [id]
  /// is itself a map.
  Future<List<AuthorRecord>> mapsFor(String id, {String? branchId}) async {
    final record = await _requireWorldRecord(id);
    if (WorldRecordTypes.mapTypeIds.contains(record.typeId)) return [record];
    final links = await connectionsFor(id, branchId: branchId);
    final byId = {
      for (final candidate in await worldRecords(branchId: branchId))
        candidate.id: candidate,
    };
    final result = <AuthorRecord>[];
    for (final link in links) {
      final otherId = link.sourceId == id ? link.targetId : link.sourceId;
      final other = byId[otherId];
      if (other != null &&
          WorldRecordTypes.mapTypeIds.contains(other.typeId) &&
          !result.any((item) => item.id == other.id)) {
        result.add(other);
      }
    }
    return result;
  }

  /// Updates the metadata block of a map record.
  Future<AuthorRecord> updateMapMetadata(
    String mapId,
    WorldMapMetadata metadata, {
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    requireCanonScope(activeBranchId, 'Editing map metadata');
    final map = await _requireWorldRecord(mapId);
    if (!WorldRecordTypes.mapTypeIds.contains(map.typeId)) {
      throw StateError('$mapId is not a map.');
    }
    return records.updateRecord(map.copyWith(
      fields: {...map.fields, ...metadata.toFields()},
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    ));
  }

  /// Markers placed on [mapId], resolved against their target records.
  Future<List<WorldMapMarkerView>> markersForMap(
    String mapId, {
    String? branchId,
    bool includeArchived = false,
  }) async {
    final map = await _requireWorldRecord(mapId);
    final metadata = WorldMapMetadata.fromRecord(map);
    final visible = branchId == null
        ? await repository.recordsByProject(projectId)
        : await branches.recordsForBranch(branchId);
    final byId = {for (final record in visible) record.id: record};
    final markers = visible
        .where((record) => record.typeId == 'map-marker')
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .where((record) =>
            includeArchived || record.status != AuthorRecordStatus.archived)
        .where((record) => '${record.fields['mapId'] ?? ''}' == mapId)
        .toList()
      ..sort((left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()));
    return [
      for (final marker in markers)
        _markerView(marker, byId, metadata),
    ];
  }

  WorldMapMarkerView _markerView(
    AuthorRecord marker,
    Map<String, AuthorRecord> byId,
    WorldMapMetadata metadata,
  ) {
    final targetId = '${marker.fields['recordId'] ?? ''}';
    final target = byId[targetId];
    final x = _num(marker.fields['x']);
    final y = _num(marker.fields['y']);
    final within = !metadata.hasBounds ||
        (x >= 0 && y >= 0 && x <= metadata.width! && y <= metadata.height!);
    return WorldMapMarkerView(
      record: marker,
      mapId: '${marker.fields['mapId'] ?? ''}',
      targetId: targetId,
      x: x,
      y: y,
      label: '${marker.fields['label'] ?? ''}',
      icon: '${marker.fields['icon'] ?? ''}',
      category: '${marker.fields['category'] ?? ''}',
      visibility: '${marker.fields['visibility'] ?? ''}',
      notes: '${marker.fields['markerNotes'] ?? ''}',
      targetTitle: target?.title ?? targetId,
      targetTypeId: target?.typeId ?? '',
      withinBounds: within,
    );
  }

  /// Edits a marker's placement and presentation without touching its links.
  Future<AuthorRecord> updateMapMarker(
    String markerId, {
    num? x,
    num? y,
    String? label,
    String? icon,
    String? category,
    String? visibility,
    String? notes,
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    requireCanonScope(activeBranchId, 'Editing a map marker');
    final marker = await _requireWorldRecord(markerId);
    if (marker.typeId != 'map-marker') {
      throw StateError('$markerId is not a map marker.');
    }
    final nextLabel = label ?? '${marker.fields['label'] ?? ''}';
    return records.updateRecord(marker.copyWith(
      title: nextLabel.trim().isEmpty ? marker.title : nextLabel.trim(),
      fields: {
        ...marker.fields,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (label != null) 'label': label,
        if (icon != null) 'icon': icon,
        if (category != null) 'category': category,
        if (visibility != null) 'visibility': visibility,
        if (notes != null) 'markerNotes': notes,
      },
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    ));
  }

  /// Routes that start or end at [id], or every route when [id] is a route.
  Future<List<WorldRouteView>> routesFor(
    String id, {
    String? branchId,
    bool includeArchived = false,
  }) async {
    final record = await _requireWorldRecord(id);
    final visible = branchId == null
        ? await repository.recordsByProject(projectId)
        : await branches.recordsForBranch(branchId);
    final byId = {for (final item in visible) item.id: item};
    final routes = visible
        .where((item) => WorldRecordTypes.routeTypeIds.contains(item.typeId))
        .where((item) => item.status != AuthorRecordStatus.deleted)
        .where((item) =>
            includeArchived || item.status != AuthorRecordStatus.archived)
        .where((item) =>
            item.id == record.id ||
            '${item.fields['startId'] ?? ''}' == id ||
            '${item.fields['endId'] ?? ''}' == id)
        .toList()
      ..sort((left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()));
    return [for (final route in routes) _routeView(route, byId)];
  }

  WorldRouteView _routeView(
    AuthorRecord route,
    Map<String, AuthorRecord> byId,
  ) {
    final startId = '${route.fields['startId'] ?? ''}';
    final endId = '${route.fields['endId'] ?? ''}';
    final start = byId[startId];
    final end = byId[endId];
    return WorldRouteView(
      record: route,
      startId: startId,
      endId: endId,
      startTitle: start?.title ?? startId,
      endTitle: end?.title ?? endId,
      routeType: '${route.fields['routeType'] ?? ''}',
      distance: '${route.fields['distance'] ?? ''}',
      travelTime: '${route.fields['travelTime'] ?? ''}',
      difficulty: '${route.fields['difficulty'] ?? ''}',
      startResolved: start != null,
      endResolved: end != null,
    );
  }

  /// Edits a route's metadata. Endpoint changes also move the stored links so
  /// the graph and the fields never disagree.
  Future<AuthorRecord> updateRoute(
    String routeId, {
    String? title,
    String? startId,
    String? endId,
    String? routeType,
    String? distance,
    String? travelTime,
    String? difficulty,
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    requireCanonScope(activeBranchId, 'Editing a route');
    final route = await _requireWorldRecord(routeId);
    if (!WorldRecordTypes.routeTypeIds.contains(route.typeId)) {
      throw StateError('$routeId is not a route.');
    }
    final nextStart = startId ?? '${route.fields['startId'] ?? ''}';
    final nextEnd = endId ?? '${route.fields['endId'] ?? ''}';
    if (nextStart == nextEnd) {
      throw ArgumentError('Route endpoints must differ.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final updated = await records.updateRecord(route.copyWith(
      title: title?.trim().isNotEmpty == true ? title!.trim() : route.title,
      fields: {
        ...route.fields,
        'startId': nextStart,
        'endId': nextEnd,
        if (routeType != null) 'routeType': routeType,
        if (distance != null) 'distance': distance,
        if (travelTime != null) 'travelTime': travelTime,
        if (difficulty != null) 'difficulty': difficulty,
      },
      updatedAt: now,
    ));
    await _moveRouteEndpoint(routeId, 'routeFrom', nextStart, now);
    await _moveRouteEndpoint(routeId, 'routeTo', nextEnd, now);
    return updated;
  }

  Future<void> _moveRouteEndpoint(
    String routeId,
    String typeId,
    String targetId,
    DateTime timestamp,
  ) async {
    final existing = (await connections.connections(routeId))
        .where((link) => link.typeId == typeId && link.sourceId == routeId)
        .firstOrNull;
    if (existing != null && existing.targetId == targetId) return;
    if (existing != null) {
      await connections.disconnect(existing.id, timestamp: timestamp);
    }
    if (targetId.trim().isEmpty) return;
    if (await records.getRecord(targetId) == null) return;
    await connections.connect(
      sourceId: routeId,
      targetId: targetId,
      typeId: typeId,
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

/// Maps a World canon state onto the universal [CanonStatus] used by scoping
/// and branch resolution, so the two never drift apart.
CanonStatus _canonStatusFor(String canonState) => switch (canonState) {
      'Canon' => CanonStatus.canon,
      'Proposed' => CanonStatus.proposed,
      'Deprecated' => CanonStatus.deprecated,
      'Non-Canon' => CanonStatus.nonCanon,
      'Alternate' => CanonStatus.alternate,
      _ => CanonStatus.draft,
    };

num _num(Object? value) {
  if (value is num) return value;
  return num.tryParse('${value ?? ''}') ?? 0;
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
