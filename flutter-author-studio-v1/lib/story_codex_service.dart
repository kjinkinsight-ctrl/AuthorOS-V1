import 'dart:convert';

import 'core/branch_domain.dart';
import 'core/built_in_record_types.dart';
import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/record_types.dart';
import 'core/story_codex_domain.dart';
import 'core/template_engine.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';

class StoryCodexService {
  StoryCodexService({
    required this.projectId,
    required this.repository,
  })  : connections = ConnectionEngine(
          scopeId: projectId,
          repository: repository,
        ),
        records = RecordService(
          projectId: projectId,
          repository: repository,
        );

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final ConnectionEngine connections;
  final RecordService records;

  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);

  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);

  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);

  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);

  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);

  Future<CodexEntry> createEntry(
    CodexEntryDraft draft, {
    DateTime? timestamp,
  }) =>
      createCodexEntry(draft, timestamp: timestamp);

  Future<CodexEntry?> readEntry(String id) => getCodexEntry(id);

  Future<void> ensureFoundation({DateTime? timestamp}) async {
    final existing = {
      for (final record in await repository.recordsByScope(projectId))
        record.id,
    };
    final now = (timestamp ?? DateTime.now()).toUtc();
    final records = <AuthorRecord>[];
    for (final category in officialCodexCategories) {
      final id = _categoryRecordId(category.id);
      if (!existing.contains(id)) {
        records.add(_categoryRecord(category, now));
      }
    }
    if (!existing.contains(_pinnedCollectionId)) {
      records.add(_collectionRecord(
        const CodexCollection(
          id: _pinnedCollectionId,
          name: 'Pinned Entries',
          kind: CodexCollectionKind.pinned,
        ),
        now,
      ));
    }
    if (records.isNotEmpty) {
      await repository.putRecordsAndLinks(records: records, links: const []);
    }
  }

  Future<RecordTypeRegistry> templateRegistry() async {
    final custom = await repository.recordTypeDefinitionsByScope(
      scopeType: RecordScopeType.project,
      scopeId: projectId,
    );
    return BuiltInRecordTypes.registry(additionalDefinitions: custom);
  }

  Future<CodexEntry> createCodexEntry(
    CodexEntryDraft draft, {
    DateTime? timestamp,
  }) async {
    await ensureFoundation(timestamp: timestamp);
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Codex entry title is required.');
    }
    final registry = await templateRegistry();
    final template = registry.resolve(draft.templateId);
    final categories = await getCategories();
    if (!categories.any((category) => category.id == draft.categoryId)) {
      throw ArgumentError('Unknown Codex category: ${draft.categoryId}');
    }
    final values = <String, Object?>{
      for (final field in template.fields)
        if (field.defaultValue != null) field.id: field.defaultValue,
      'name': title,
      if (draft.summary.trim().isNotEmpty) 'summary': draft.summary.trim(),
      if (draft.content.trim().isNotEmpty) 'description': draft.content.trim(),
      ...draft.structuredFields,
    };
    for (final field in template.fields.where((field) => field.required)) {
      final value = values[field.id];
      if (value == null || value.toString().trim().isEmpty) {
        throw ArgumentError('${field.label} is required.');
      }
    }
    final ownerScopeId = draft.ownerScopeId ??
        switch (draft.scopeType) {
          RecordScopeType.series => draft.seriesId,
          _ => projectId,
        };
    if (ownerScopeId == null || ownerScopeId.trim().isEmpty) {
      throw ArgumentError('The selected Codex scope requires an owner ID.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final id = draft.id ?? _newId('codex', title, now);
    if (await repository.recordById(id) != null) {
      throw StateError('A record with id $id already exists.');
    }
    final record = AuthorRecord(
      id: id,
      typeId: draft.templateId,
      scopeType: draft.scopeType,
      scopeId: ownerScopeId,
      projectId: projectId,
      seriesId: draft.seriesId,
      bookId: draft.bookId,
      branchId: draft.branchId,
      canonStatus: CanonStatus.values.byName(draft.canonStatus.name),
      title: title,
      templateId: draft.templateId,
      templateVersion: template.templateVersion,
      fields: {
        ...values,
        CodexFields.summary: draft.summary.trim(),
        CodexFields.content: draft.content.trim(),
        CodexFields.templateId: draft.templateId,
        CodexFields.categoryId: draft.categoryId,
        CodexFields.projectId: projectId,
        if (draft.seriesId != null) CodexFields.seriesId: draft.seriesId,
        if (draft.bookId != null) CodexFields.bookId: draft.bookId,
        if (draft.branchId != null) CodexFields.branchId: draft.branchId,
        CodexFields.canonStatus: draft.canonStatus.name,
        CodexFields.metadata: draft.metadata,
      },
      tags: draft.tagIds.toSet().toList(),
      createdAt: now,
      updatedAt: now,
      extensionData: const {'storyCodex': true},
    );
    await records.createRecord(record);
    return CodexEntry(record);
  }

  Future<CodexEntry?> getCodexEntry(String id) async {
    final record = await records.getRecord(id);
    if (record == null || !_isEntry(record)) {
      return null;
    }
    return CodexEntry(record);
  }

  Future<CodexEntry> updateCodexEntry(
    String id, {
    String? title,
    String? summary,
    String? content,
    String? categoryId,
    List<String>? tagIds,
    CodexCanonStatus? canonStatus,
    Map<String, Object?>? structuredFields,
    DateTime? timestamp,
  }) async {
    final existing = await _requireEntry(id);
    if (categoryId != null &&
        !(await getCategories()).any((category) => category.id == categoryId)) {
      throw ArgumentError('Unknown Codex category: $categoryId');
    }
    final nextTitle = title?.trim() ?? existing.title;
    if (nextTitle.isEmpty) {
      throw ArgumentError('Codex entry title is required.');
    }
    final fields = Map<String, Object?>.from(existing.record.fields)
      ..addAll(structuredFields ?? const {});
    if (title != null) fields['name'] = nextTitle;
    if (summary != null) fields[CodexFields.summary] = summary.trim();
    if (summary != null) fields['summary'] = summary.trim();
    if (content != null) {
      fields[CodexFields.content] = content.trim();
      fields['description'] = content.trim();
    }
    if (categoryId != null) fields[CodexFields.categoryId] = categoryId;
    if (canonStatus != null) {
      fields[CodexFields.canonStatus] = canonStatus.name;
    }
    final updated = existing.record.copyWith(
      title: nextTitle,
      canonStatus: canonStatus == null
          ? null
          : CanonStatus.values.byName(canonStatus.name),
      fields: fields,
      tags: tagIds?.toSet().toList(),
      revision: existing.record.revision + 1,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
    );
    return CodexEntry(await records.updateRecord(updated));
  }

  Future<CodexEntry> updateEntry(
    String id, {
    String? title,
    String? summary,
    String? content,
    String? categoryId,
    List<String>? tagIds,
    CodexCanonStatus? canonStatus,
    Map<String, Object?>? structuredFields,
    DateTime? timestamp,
  }) =>
      updateCodexEntry(
        id,
        title: title,
        summary: summary,
        content: content,
        categoryId: categoryId,
        tagIds: tagIds,
        canonStatus: canonStatus,
        structuredFields: structuredFields,
        timestamp: timestamp,
      );

  Future<CodexEntry> archiveCodexEntry(String id) =>
      _setLifecycle(id, AuthorRecordStatus.archived);

  Future<CodexEntry> restoreCodexEntry(String id) =>
      _setLifecycle(id, AuthorRecordStatus.active);

  Future<CodexEntry> deleteCodexEntry(String id) =>
      _setLifecycle(id, AuthorRecordStatus.deleted);

  Future<CodexEntry> archiveEntry(String id) => archiveCodexEntry(id);

  Future<CodexEntry> restoreEntry(String id) => restoreCodexEntry(id);

  Future<CodexEntry> duplicateCodexEntry(
    String id, {
    DateTime? timestamp,
  }) async {
    final source = await _requireEntry(id);
    return createCodexEntry(
      CodexEntryDraft(
        title: '${source.title} Copy',
        templateId: source.templateId,
        categoryId: source.categoryId,
        summary: source.summary,
        content: source.content,
        structuredFields: source.structuredFields,
        tagIds: source.tagIds,
        seriesId: source.seriesId,
        bookId: source.bookId,
        branchId: source.branchId,
        canonStatus: source.canonStatus,
        metadata: source.metadata,
        scopeType: source.record.scopeType,
        ownerScopeId: source.record.scopeId,
      ),
      timestamp: timestamp,
    );
  }

  Future<CodexEntry> duplicateEntry(
    String id, {
    DateTime? timestamp,
  }) =>
      duplicateCodexEntry(id, timestamp: timestamp);

  Future<CodexEntry> createFromTemplate(
    String templateId, {
    required String title,
    String? id,
    String? categoryId,
    String summary = '',
    String description = '',
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    String? seriesId,
    String? bookId,
    String? branchId,
    CodexCanonStatus canonStatus = CodexCanonStatus.draft,
    DateTime? timestamp,
  }) async {
    final template = (await templateRegistry()).resolve(templateId);
    return createCodexEntry(
      CodexEntryDraft(
        id: id,
        title: title,
        templateId: templateId,
        categoryId: categoryId ?? template.categoryId,
        summary: summary,
        content: description,
        structuredFields: fields,
        tagIds: tags,
        seriesId: seriesId,
        bookId: bookId,
        branchId: branchId,
        canonStatus: canonStatus,
      ),
      timestamp: timestamp,
    );
  }

  Future<CodexEntry> changeTemplate(
    String id,
    String templateId, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireEntry(id);
    final registry = await templateRegistry();
    final template = registry.resolve(templateId);
    if (!registry.isTemplateCompatible(templateId, existing.record.typeId)) {
      throw StateError(
        'Template $templateId is not compatible with ${existing.record.typeId}.',
      );
    }
    final fields = <String, Object?>{
      for (final field in template.fields)
        if (field.defaultValue != null) field.id: field.defaultValue,
      ...existing.record.fields,
    };
    final updated = AuthorRecord(
      id: existing.id,
      typeId: existing.record.typeId,
      scopeType: existing.record.scopeType,
      scopeId: existing.record.scopeId,
      projectId: existing.record.projectId,
      seriesId: existing.record.seriesId,
      bookId: existing.record.bookId,
      branchId: existing.record.branchId,
      canonStatus: existing.record.canonStatus,
      title: existing.title,
      status: existing.status,
      schemaVersion: existing.record.schemaVersion,
      templateId: templateId,
      templateVersion: template.templateVersion,
      revision: existing.record.revision + 1,
      fields: {
        ...fields,
        CodexFields.templateId: templateId,
      },
      tags: existing.tagIds,
      createdAt: existing.createdAt,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      extensionData: existing.record.extensionData,
    );
    return CodexEntry(await records.updateRecord(updated));
  }

  Future<List<CodexEntry>> getEntries({
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    final records = await repository.snapshot().then((value) => value.records);
    return records
        .where(_belongsToProject)
        .where(_isEntry)
        .where((record) =>
            includeArchived || record.status != AuthorRecordStatus.archived)
        .where((record) =>
            includeDeleted || record.status != AuthorRecordStatus.deleted)
        .map(CodexEntry.new)
        .toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  Future<List<CodexEntry>> getCodexByType(String typeId) async =>
      (await getEntries())
          .where((entry) => entry.recordType == typeId)
          .toList();

  Future<List<CodexEntry>> listByType(String typeId) => getCodexByType(typeId);

  Future<List<CodexEntry>> listByProject([String? requestedProjectId]) {
    if (requestedProjectId != null && requestedProjectId != projectId) {
      throw StateError('Codex service cannot access $requestedProjectId.');
    }
    return getEntries();
  }

  Future<List<CodexEntry>> listByBranch(String branchId) async =>
      (await branches.recordsForBranch(branchId))
          .where(_isEntry)
          .map(CodexEntry.new)
          .toList();

  Future<List<CodexEntry>> getCodexByCategory(String categoryId) async =>
      (await getEntries())
          .where((entry) => entry.categoryId == categoryId)
          .toList();

  Future<List<CodexEntry>> getCodexByTag(String tagId) async =>
      (await getEntries())
          .where((entry) => entry.tagIds.contains(tagId))
          .toList();

  Future<List<CodexEntry>> searchCodex(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return getEntries();
    final results = await search.searchByProject(normalized, projectId);
    final entries = <CodexEntry>[];
    for (final result in results) {
      final entry = await getCodexEntry(result.recordId);
      if (entry != null && !entry.isArchived && !entry.isDeleted) {
        entries.add(entry);
      }
    }
    return entries;
  }

  Future<List<RecordLink>> getCodexConnections(String id) =>
      connections.connections(id);

  Future<List<AuthorRecord>> getRelated(String id) =>
      connections.linkedRecords(id);

  Future<List<AuthorRecord>> getTimeline(String id) =>
      _relatedRecordsByType(id, const {
        'timeline-event',
        'historical-event',
        'historical-period',
        'era',
      });

  Future<List<AuthorRecord>> getCharacters(String id) =>
      _relatedRecordsByType(id, const {'character'});

  Future<List<RecordLink>> getManuscriptReferences(String id) =>
      _connectionsToTypes(id, const {'book', 'chapter', 'scene', 'manuscript'});

  Future<List<AuthorRecord>> getWorldReferences(String id) =>
      _relatedRecordsByType(id, const {
        'world',
        'location',
        'region',
        'country',
        'city',
        'settlement',
        'district',
        'building',
      });

  Future<RecordValidationResult> validateEntry(String id) async =>
      records.validateRecord((await _requireEntry(id)).record);

  Future<UniversalRecordInspection?> inspectEntry(
    String id, {
    String? branchId,
  }) =>
      inspector.inspectRecord(id, branchId: branchId);

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) =>
      safeDelete.analyze(id);

  Future<List<RecordVersion>> getHistory(
    String id, {
    String? branchId,
  }) =>
      history.getVersionHistory(recordId: id, branchId: branchId);

  Future<CodexCategory> createCategory({
    required String name,
    String? parentId,
    DateTime? timestamp,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    if (parentId != null &&
        !(await getCategories()).any((category) => category.id == parentId)) {
      throw ArgumentError('Unknown parent category: $parentId');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final category = CodexCategory(
      id: _slug(normalized),
      name: normalized,
      parentId: parentId,
      order: (await getCategories()).length,
    );
    await repository.putRecord(_categoryRecord(category, now));
    return category;
  }

  Future<List<CodexCategory>> getCategories() async {
    await ensureFoundation();
    final records = await repository.recordsByTypeAndScope(
      typeId: CodexInfrastructureTypes.category,
      scopeId: projectId,
    );
    final categories = records.map(_categoryFromRecord).toList()
      ..sort((left, right) => left.order.compareTo(right.order));
    return categories;
  }

  Future<CodexTag> createTag({
    required String name,
    String description = '',
    String group = '',
    String color = '',
    DateTime? timestamp,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Tag name is required.');
    final now = (timestamp ?? DateTime.now()).toUtc();
    final tag = CodexTag(
      id: _slug(normalized),
      name: normalized,
      description: description.trim(),
      group: group.trim(),
      color: color.trim(),
      createdAt: now,
    );
    await repository.putRecord(AuthorRecord(
      id: _tagRecordId(tag.id),
      typeId: CodexInfrastructureTypes.tag,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      title: tag.name,
      fields: {
        'tagId': tag.id,
        'description': tag.description,
        'group': tag.group,
        'color': tag.color,
      },
      createdAt: now,
      updatedAt: now,
    ));
    return tag;
  }

  Future<List<CodexTag>> getTags() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: CodexInfrastructureTypes.tag,
      scopeId: projectId,
    );
    return records
        .map((record) => CodexTag(
              id: record.fields['tagId'] as String? ?? record.id,
              name: record.title,
              description: record.fields['description'] as String? ?? '',
              group: record.fields['group'] as String? ?? '',
              color: record.fields['color'] as String? ?? '',
              createdAt: record.createdAt,
            ))
        .toList();
  }

  Future<CodexCollection> createCollection({
    required String name,
    CodexCollectionKind kind = CodexCollectionKind.manual,
    List<String> recordIds = const [],
    Map<String, Object?> filter = const {},
    DateTime? timestamp,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Collection name is required.');
    }
    await _validateRecordIds(recordIds);
    final collection = CodexCollection(
      id: _slug(normalized),
      name: normalized,
      kind: kind,
      recordIds: recordIds.toSet().toList(),
      filter: filter,
    );
    await repository.putRecord(
      _collectionRecord(collection, (timestamp ?? DateTime.now()).toUtc()),
    );
    return collection;
  }

  Future<List<CodexCollection>> getCollections() async {
    await ensureFoundation();
    final records = await repository.recordsByTypeAndScope(
      typeId: CodexInfrastructureTypes.collection,
      scopeId: projectId,
    );
    return records.map(_collectionFromRecord).toList();
  }

  Future<void> setPinned(String recordId, bool pinned) async {
    await _requireEntry(recordId);
    final record = await repository.recordById(_pinnedCollectionId);
    if (record == null) throw StateError('Pinned collection is missing.');
    final ids = _stringList(record.fields['recordIds']).toSet();
    pinned ? ids.add(recordId) : ids.remove(recordId);
    await repository.putRecord(record.copyWith(
      fields: {...record.fields, 'recordIds': ids.toList()},
      revision: record.revision + 1,
      updatedAt: DateTime.now().toUtc(),
    ));
  }

  Future<List<CodexEntry>> getPinnedEntries() async {
    final collections = await getCollections();
    final pinned = collections.firstWhere(
      (collection) => collection.kind == CodexCollectionKind.pinned,
    );
    final entries = <CodexEntry>[];
    for (final id in pinned.recordIds) {
      final entry = await getCodexEntry(id);
      if (entry != null && !entry.isDeleted) entries.add(entry);
    }
    return entries;
  }

  Future<void> saveTemplate(RecordTypeDefinition definition) async {
    if (definition.scopeType != RecordScopeType.project ||
        definition.scopeId != projectId ||
        definition.builtIn) {
      throw ArgumentError('Custom templates must belong to this project.');
    }
    await repository.putRecordTypeDefinition(definition);
  }

  Future<RecordTypeDefinition> duplicateTemplate(
    String templateId, {
    required String newId,
    required String newName,
  }) async {
    final source = (await templateRegistry()).resolve(templateId);
    final duplicate = RecordTypeDefinition(
      id: newId,
      name: newName,
      description: source.description,
      icon: source.icon,
      categoryId: source.categoryId,
      fields: source.fields,
      sections: source.sections,
      tags: source.tags,
      suggestedLinkTypeIds: source.suggestedLinkTypeIds,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      allowedScopeTypes: source.allowedScopeTypes,
      permissions: source.permissions,
      exportBehavior: source.exportBehavior,
      extensionData: const {'duplicatedTemplate': true},
    );
    await saveTemplate(duplicate);
    return duplicate;
  }

  Future<void> archiveTemplate(String templateId) async {
    final existing = await repository.recordTypeDefinitionById(templateId);
    if (existing == null || existing.scopeId != projectId) {
      throw StateError('Custom template does not belong to this project.');
    }
    await repository.putRecordTypeDefinition(RecordTypeDefinition.fromJson({
      ...existing.toJson(),
      'extensionData': {...existing.extensionData, 'archived': true},
    }));
  }

  // ---------------------------------------------------------------------
  // Phase 2 workspace surface.
  //
  // Everything below composes the existing services (RecordService,
  // ConnectionEngine, BranchService, UniversalSearchService, RecordValidator)
  // rather than reaching past them. No new store, index, or history log.
  // ---------------------------------------------------------------------

  /// Active story branches for this project, newest first.
  Future<List<StoryBranch>> getBranches() async {
    final branches = (await repository.branchesByProject(projectId))
        .where((branch) => branch.status == BranchStatus.active)
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return branches;
  }

  Future<ConnectionTypeRegistry> connectionRegistry() =>
      records.connectionRegistry();

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

  /// Creates a relationship from a Codex entry.
  ///
  /// With [activeBranchId] set the link is added as a branch overlay so Canon
  /// is never mutated from a branch.
  Future<RecordLink> connectEntry({
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
    final link = RecordLink(
      id: 'branch-link-${_identity(activeBranchId, sourceId, typeId, targetId)}',
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

  Future<RecordLink> updateEntryConnection(
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
  Future<void> disconnectEntry(
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

  /// Records visible on [branchId], keyed by id, for connection endpoints.
  Future<List<AuthorRecord>> connectableRecords({String? branchId}) async {
    final visible = branchId == null
        ? (await repository.snapshot()).records.where(_belongsToProject).toList()
        : await branches.recordsForBranch(branchId);
    return visible
        .where((record) => !CodexInfrastructureTypes.all.contains(record.typeId))
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));
  }

  // --- Sources and references -------------------------------------------

  Future<List<CodexSourceReference>> getSources(String id) async =>
      (await _requireEntry(id)).sources;

  Future<CodexEntry> setSources(
    String id,
    List<CodexSourceReference> sources, {
    DateTime? timestamp,
  }) =>
      updateCodexEntry(
        id,
        structuredFields: {
          CodexFields.sources:
              sources.map((source) => source.toJson()).toList(),
        },
        timestamp: timestamp,
      );

  Future<CodexEntry> addSource(
    String id,
    CodexSourceReference source, {
    DateTime? timestamp,
  }) async {
    final entry = await _requireEntry(id);
    final resolved = source.id.isEmpty
        ? source.copyWith(
            id: _newId('source', source.displayLabel,
                (timestamp ?? DateTime.now()).toUtc()),
          )
        : source;
    return setSources(id, [...entry.sources, resolved], timestamp: timestamp);
  }

  Future<CodexEntry> updateSource(
    String id,
    CodexSourceReference source, {
    DateTime? timestamp,
  }) async {
    final entry = await _requireEntry(id);
    final updated = entry.sources
        .map((existing) =>
            existing.stableId == source.stableId ? source : existing)
        .toList();
    return setSources(id, updated, timestamp: timestamp);
  }

  Future<CodexEntry> removeSource(
    String id,
    String sourceId, {
    DateTime? timestamp,
  }) async {
    final entry = await _requireEntry(id);
    return setSources(
      id,
      entry.sources.where((source) => source.stableId != sourceId).toList(),
      timestamp: timestamp,
    );
  }

  // --- Knowledge and visibility -----------------------------------------

  Future<CodexEntry> setKnowledgeStatus(
    String id,
    CodexKnowledgeStatus status, {
    DateTime? timestamp,
  }) =>
      updateCodexEntry(
        id,
        structuredFields: {
          CodexFields.knowledgeStatus: codexKnowledgeStatusValue(status),
        },
        timestamp: timestamp,
      );

  Future<CodexEntry> setAliases(
    String id,
    List<String> aliases, {
    DateTime? timestamp,
  }) =>
      updateCodexEntry(
        id,
        structuredFields: {
          CodexFields.aliases: aliases
              .map((alias) => alias.trim())
              .where((alias) => alias.isNotEmpty)
              .toList(),
        },
        timestamp: timestamp,
      );

  /// Sets knowledge visibility for one field without disturbing other
  /// metadata keys written by earlier releases or other Studios.
  Future<CodexEntry> setFieldVisibility(
    String id,
    String fieldId,
    CodexFieldVisibility visibility, {
    DateTime? timestamp,
  }) async {
    final entry = await _requireEntry(id);
    final metadata = Map<String, Object?>.from(entry.metadata);
    final existing = metadata[CodexFields.visibilityKey];
    final map = <String, Object?>{
      if (existing is Map)
        for (final item in existing.entries) item.key.toString(): item.value,
      fieldId: visibility.name,
    };
    metadata[CodexFields.visibilityKey] = map;
    return updateCodexEntry(
      id,
      structuredFields: {CodexFields.metadata: metadata},
      timestamp: timestamp,
    );
  }

  /// Adds or updates an author-defined field that no template declares.
  ///
  /// The value lives in the record's own field map so it round-trips like any
  /// template field; the label is remembered in Codex metadata.
  Future<CodexEntry> setCustomField(
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
    if (normalized.startsWith(CodexFields.prefix)) {
      throw ArgumentError('Custom fields cannot use the reserved _codex prefix.');
    }
    final entry = await _requireEntry(id);
    final metadata = Map<String, Object?>.from(entry.metadata);
    final existing = metadata[CodexFields.customFieldsKey];
    metadata[CodexFields.customFieldsKey] = <String, Object?>{
      if (existing is Map)
        for (final item in existing.entries) item.key.toString(): item.value,
      normalized: label.trim().isEmpty ? normalized : label.trim(),
    };
    return updateCodexEntry(
      id,
      structuredFields: {
        normalized: value,
        CodexFields.metadata: metadata,
      },
      timestamp: timestamp,
    );
  }

  // --- Canon and branch -------------------------------------------------

  /// Sets the Canon state of an entry.
  ///
  /// Refuses to touch Canon while a branch is active; branch authors override
  /// the entry inside their branch instead.
  Future<CodexEntry> setCanonStatus(
    String id,
    CodexCanonStatus status, {
    String? activeBranchId,
    DateTime? timestamp,
  }) async {
    if (activeBranchId != null) {
      throw StateError(
        'Canon cannot be changed while the $activeBranchId branch is active. '
        'Override the entry in the branch instead.',
      );
    }
    return updateCodexEntry(id, canonStatus: status, timestamp: timestamp);
  }

  /// Creates a new entry that only exists inside [branchId].
  ///
  /// Canon is untouched: the record is branch-scoped and can never be Canon.
  Future<CodexEntry> createCodexEntryInBranch(
    String branchId,
    CodexEntryDraft draft, {
    DateTime? timestamp,
  }) async {
    await ensureFoundation(timestamp: timestamp);
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Codex entry title is required.');
    }
    if (draft.canonStatus == CodexCanonStatus.canon) {
      throw StateError('A branch cannot create a Canon entry.');
    }
    final template = (await templateRegistry()).resolve(draft.templateId);
    if (!(await getCategories())
        .any((category) => category.id == draft.categoryId)) {
      throw ArgumentError('Unknown Codex category: ${draft.categoryId}');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final id = draft.id ?? _newId('codex', title, now);
    if (await repository.recordById(id) != null) {
      throw StateError('A record with id $id already exists.');
    }
    final record = AuthorRecord(
      id: id,
      typeId: draft.templateId,
      scopeType: RecordScopeType.branch,
      scopeId: branchId,
      projectId: projectId,
      branchId: branchId,
      canonStatus: CanonStatus.values.byName(draft.canonStatus.name),
      title: title,
      templateId: draft.templateId,
      templateVersion: template.templateVersion,
      fields: {
        for (final field in template.fields)
          if (field.defaultValue != null) field.id: field.defaultValue,
        'name': title,
        if (draft.summary.trim().isNotEmpty) 'summary': draft.summary.trim(),
        if (draft.content.trim().isNotEmpty)
          'description': draft.content.trim(),
        ...draft.structuredFields,
        CodexFields.summary: draft.summary.trim(),
        CodexFields.content: draft.content.trim(),
        CodexFields.templateId: draft.templateId,
        CodexFields.categoryId: draft.categoryId,
        CodexFields.projectId: projectId,
        CodexFields.branchId: branchId,
        CodexFields.canonStatus: draft.canonStatus.name,
        CodexFields.metadata: draft.metadata,
      },
      tags: draft.tagIds.toSet().toList(),
      createdAt: now,
      updatedAt: now,
      extensionData: const {'storyCodex': true},
    );
    await branches.createRecord(branchId, record, timestamp: now);
    return CodexEntry(record);
  }

  /// Applies an edit inside a branch as an overlay over the canonical record.
  Future<void> updateEntryInBranch(
    String branchId,
    String id, {
    String? title,
    String? summary,
    String? content,
    Map<String, Object?> structuredFields = const {},
    List<String>? tagIds,
    CodexCanonStatus? canonStatus,
    DateTime? timestamp,
  }) async {
    if (canonStatus == CodexCanonStatus.canon) {
      throw StateError('A branch cannot promote an entry to Canon.');
    }
    final fields = <String, Object?>{
      ...structuredFields,
      if (title != null) 'name': title.trim(),
      if (summary != null) ...{
        CodexFields.summary: summary.trim(),
        'summary': summary.trim(),
      },
      if (content != null) ...{
        CodexFields.content: content.trim(),
        'description': content.trim(),
      },
      if (canonStatus != null) CodexFields.canonStatus: canonStatus.name,
    };
    await branches.overrideRecord(
      branchId,
      id,
      title: title?.trim(),
      fields: fields,
      tags: tagIds,
      canonStatus: canonStatus == null
          ? null
          : CanonStatus.values.byName(canonStatus.name),
      timestamp: timestamp,
    );
  }

  // --- Validation -------------------------------------------------------

  /// Validates many entries against one registry build.
  Future<Map<String, RecordValidationResult>> validateEntries(
    Iterable<CodexEntry> entries,
  ) async {
    final validator = RecordValidator(await templateRegistry());
    return {
      for (final entry in entries)
        entry.id: validator.validate(entry.record, projectId: projectId),
    };
  }

  /// Template drift for many entries against one registry build.
  ///
  /// Surfaces "template upgrade available" and "template missing" states next
  /// to plain field validation so an entry written by an older release is
  /// flagged instead of silently rewritten.
  Future<Map<String, TemplateCompatibilityReport>> templateReports(
    Iterable<CodexEntry> entries,
  ) async {
    final engine = TemplateEngine(await templateRegistry());
    return {
      for (final entry in entries) entry.id: engine.inspect(entry.record),
    };
  }

  // --- Filtering and saved views ----------------------------------------

  /// Applies a [CodexEntryFilter].
  ///
  /// Text queries are answered by [UniversalSearchService]; the remaining
  /// facets narrow that result set in memory. No second index is built.
  Future<List<CodexEntry>> filterEntries(
    CodexEntryFilter filter, {
    String? branchId,
  }) async {
    final entries = branchId == null
        ? await getEntries(includeArchived: true)
        : await listByBranch(branchId);
    final ordered = <CodexEntry>[];
    if (filter.query.trim().isEmpty) {
      ordered.addAll(entries);
    } else {
      final results = branchId == null
          ? await search.searchByProject(filter.query.trim(), projectId)
          : await search.searchByBranch(filter.query.trim(), branchId);
      final rank = <String, int>{
        for (var index = 0; index < results.length; index += 1)
          results[index].recordId: index,
      };
      ordered.addAll(
        entries.where((entry) => rank.containsKey(entry.id)).toList()
          ..sort((left, right) => rank[left.id]!.compareTo(rank[right.id]!)),
      );
    }

    final pinnedIds = filter.onlyPinned
        ? (await getPinnedEntries()).map((entry) => entry.id).toSet()
        : const <String>{};
    final invalidIds = filter.onlyInvalid
        ? (await validateEntries(ordered))
            .entries
            .where((item) => !item.value.isValid || item.value.warnings.isNotEmpty)
            .map((item) => item.key)
            .toSet()
        : const <String>{};

    final matched = ordered.where((entry) {
      if (entry.isDeleted) return false;
      if (!filter.includeArchived && entry.isArchived) return false;
      if (filter.categoryIds.isNotEmpty &&
          !filter.categoryIds.contains(entry.categoryId)) {
        return false;
      }
      if (filter.templateIds.isNotEmpty &&
          !filter.templateIds.contains(entry.templateId)) {
        return false;
      }
      if (filter.tagIds.isNotEmpty &&
          !entry.tagIds.any(filter.tagIds.contains)) {
        return false;
      }
      if (filter.canonStatuses.isNotEmpty &&
          !filter.canonStatuses.contains(entry.canonStatus)) {
        return false;
      }
      if (filter.knowledgeStatuses.isNotEmpty &&
          !filter.knowledgeStatuses.contains(entry.knowledgeStatus)) {
        return false;
      }
      if (filter.onlyPinned && !pinnedIds.contains(entry.id)) return false;
      if (filter.onlyInvalid && !invalidIds.contains(entry.id)) return false;
      return true;
    }).toList();

    if (filter.query.trim().isNotEmpty &&
        filter.sort == CodexEntrySort.recentlyUpdated) {
      return matched;
    }
    switch (filter.sort) {
      case CodexEntrySort.title:
        matched.sort((left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()));
      case CodexEntrySort.canonStatus:
        matched.sort((left, right) {
          final compared =
              left.canonStatus.index.compareTo(right.canonStatus.index);
          return compared != 0 ? compared : left.title.compareTo(right.title);
        });
      case CodexEntrySort.recentlyUpdated:
        matched.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    }
    return matched;
  }

  /// Saved views, stored as `codexCollection` universal records.
  Future<List<CodexSavedView>> getSavedViews() async {
    await ensureFoundation();
    final records = await repository.recordsByTypeAndScope(
      typeId: CodexInfrastructureTypes.collection,
      scopeId: projectId,
    );
    return records
        .where((record) => record.status == AuthorRecordStatus.active)
        .where((record) =>
            record.fields['kind'] == CodexCollectionKind.savedView.name)
        // Saved views are a shared record type, so another Studio may store
        // its own filter here. A record stamped for a different Studio is not
        // a Codex view and its filter would not decode as one; only unstamped
        // records — every view the Codex has ever written — belong to it.
        .where((record) =>
            record.fields['studioId'] == null ||
            record.fields['studioId'] == 'story_codex')
        .map((record) => CodexSavedView.fromCollection(
              _collectionFromRecord(record),
            ))
        .toList()
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  Future<CodexSavedView> saveView({
    required String name,
    required CodexEntryFilter filter,
    String? id,
    DateTime? timestamp,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('A view name is required.');
    final viewId = id ?? _slug(normalized);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final collection = CodexCollection(
      id: viewId,
      name: normalized,
      kind: CodexCollectionKind.savedView,
      filter: filter.toJson(),
    );
    final existing = await repository.recordById('codex-collection-$viewId');
    await repository.putRecord(
      existing == null
          ? _collectionRecord(collection, now)
          : existing.copyWith(
              title: normalized,
              status: AuthorRecordStatus.active,
              fields: {
                ...existing.fields,
                'collectionId': viewId,
                'kind': CodexCollectionKind.savedView.name,
                'recordIds': collection.recordIds,
                'filter': collection.filter,
              },
              revision: existing.revision + 1,
              updatedAt: now,
            ),
    );
    return CodexSavedView(id: viewId, name: normalized, filter: filter);
  }

  /// Archives a saved view. Nothing is physically deleted, so a view can be
  /// recreated under the same id without colliding with history.
  Future<void> deleteSavedView(String id) async {
    final record = await repository.recordById('codex-collection-$id');
    if (record == null) return;
    if (record.fields['kind'] != CodexCollectionKind.savedView.name) {
      throw StateError('$id is not a saved view.');
    }
    await repository.putRecord(record.copyWith(
      status: AuthorRecordStatus.archived,
      revision: record.revision + 1,
      updatedAt: DateTime.now().toUtc(),
    ));
  }

  Future<CodexEntry> _setLifecycle(
    String id,
    AuthorRecordStatus status,
  ) async {
    await _requireEntry(id);
    final updated = switch (status) {
      AuthorRecordStatus.active => records.restoreRecord(id),
      AuthorRecordStatus.archived => records.archiveRecord(id),
      AuthorRecordStatus.deleted => records.deleteRecord(id),
    };
    return CodexEntry(await updated);
  }

  Future<CodexEntry> _requireEntry(String id) async {
    final entry = await getCodexEntry(id);
    if (entry == null) {
      throw StateError('Codex entry $id does not belong to $projectId.');
    }
    return entry;
  }

  bool _belongsToProject(AuthorRecord record) =>
      record.scopeId == projectId ||
      record.fields[CodexFields.projectId] == projectId;

  bool _isEntry(AuthorRecord record) =>
      !CodexInfrastructureTypes.all.contains(record.typeId);

  Future<void> _validateRecordIds(Iterable<String> ids) async {
    for (final id in ids) {
      await _requireEntry(id);
    }
  }

  Future<List<AuthorRecord>> _relatedRecordsByType(
    String id,
    Set<String> typeIds,
  ) async =>
      (await connections.linkedRecords(id))
          .where((record) => typeIds.contains(record.typeId))
          .toList();

  Future<List<RecordLink>> _connectionsToTypes(
    String id,
    Set<String> typeIds,
  ) async {
    final links = await connections.connections(id);
    final matching = <RecordLink>[];
    for (final link in links) {
      final otherId = link.sourceId == id ? link.targetId : link.sourceId;
      final typeId = await repository.entityTypeId(otherId);
      if (typeId != null && typeIds.contains(typeId)) matching.add(link);
    }
    return matching;
  }

  AuthorRecord _categoryRecord(CodexCategory category, DateTime timestamp) =>
      AuthorRecord(
        id: _categoryRecordId(category.id),
        typeId: CodexInfrastructureTypes.category,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        title: category.name,
        status: category.archived
            ? AuthorRecordStatus.archived
            : AuthorRecordStatus.active,
        fields: {
          'categoryId': category.id,
          if (category.parentId != null) 'parentId': category.parentId,
          'order': category.order,
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  CodexCategory _categoryFromRecord(AuthorRecord record) => CodexCategory(
        id: record.fields['categoryId'] as String? ?? record.id,
        name: record.title,
        parentId: record.fields['parentId'] as String?,
        archived: record.status == AuthorRecordStatus.archived,
        order: record.fields['order'] as int? ?? 0,
      );

  AuthorRecord _collectionRecord(
    CodexCollection collection,
    DateTime timestamp,
  ) =>
      AuthorRecord(
        id: collection.id == _pinnedCollectionId
            ? _pinnedCollectionId
            : 'codex-collection-${collection.id}',
        typeId: CodexInfrastructureTypes.collection,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        title: collection.name,
        fields: {
          'collectionId': collection.id,
          'kind': collection.kind.name,
          'recordIds': collection.recordIds,
          'filter': collection.filter,
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  CodexCollection _collectionFromRecord(AuthorRecord record) {
    final kind = record.fields['kind'] as String?;
    final filter = record.fields['filter'];
    return CodexCollection(
      id: record.fields['collectionId'] as String? ?? record.id,
      name: record.title,
      kind: CodexCollectionKind.values.firstWhere(
        (value) => value.name == kind,
        orElse: () => CodexCollectionKind.manual,
      ),
      recordIds: _stringList(record.fields['recordIds']),
      filter: filter is Map
          ? filter.map((key, value) => MapEntry(key.toString(), value))
          : const {},
    );
  }
}

const _pinnedCollectionId = 'codex-collection-pinned';

String _categoryRecordId(String id) => 'codex-category-$id';
String _tagRecordId(String id) => 'codex-tag-$id';

String _newId(String prefix, String title, DateTime timestamp) =>
    '$prefix-${_slug(title)}-${timestamp.microsecondsSinceEpoch}';

/// Stable identity for a branch-scoped link, mirroring [ConnectionEngine].
String _identity(
  String scope,
  String sourceId,
  String typeId,
  String targetId,
) =>
    base64Url
        .encode(utf8.encode('$scope|$sourceId|$typeId|$targetId'))
        .replaceAll('=', '');

String _slug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-+|-+$)'), '');
  return slug.isEmpty ? 'item' : slug;
}

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : [];
