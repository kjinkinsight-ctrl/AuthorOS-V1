import 'core/built_in_connection_types.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/research_record_types.dart';
import 'core/story_codex_domain.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';

/// How a research list is ordered.
enum ResearchSort {
  recentlyUpdated,
  recentlyCreated,
  alphabetical,
  category,
  importance,
}

/// The shelves the Research Library offers.
///
/// Each one is a read-derived view of the canonical records — none of them
/// owns storage, an index, or a record of its own.
enum ResearchShelf {
  all,
  sources,
  notes,
  references,
  important,
  unresolved,
  recent,
}

/// Everything the author supplies when creating or editing a research entry.
///
/// This is a form payload, not a model: [ResearchService] folds it straight
/// into an [AuthorRecord] and the record is the only thing persisted.
class ResearchDraft {
  const ResearchDraft({
    required this.id,
    required this.title,
    this.typeId = ResearchRecordTypes.baseTypeId,
    this.kind = ResearchRecordTypes.defaultKind,
    this.category = ResearchRecordTypes.defaultCategory,
    this.status = ResearchRecordTypes.defaultStatus,
    this.important = false,
    this.summary = '',
    this.notes = '',
    this.sourceUrl = '',
    this.citation = '',
    this.tags = const [],
    this.extensionData = const {},
  });

  final String id;
  final String title;
  final String typeId;
  final String kind;
  final String category;
  final String status;
  final bool important;
  final String summary;
  final String notes;
  final String sourceUrl;
  final String citation;
  final List<String> tags;

  /// Extra record-level extension data, merged over the Studio's own marker.
  ///
  /// Used by the manuscript-panel migration to stamp provenance at creation
  /// time, so a migrated record needs one revision rather than two.
  final Map<String, Object?> extensionData;

  /// Reads a draft back out of a canonical record so the editor can round-trip
  /// an existing entry without inventing a parallel representation.
  factory ResearchDraft.fromRecord(AuthorRecord record) => ResearchDraft(
        id: record.id,
        title: record.title,
        typeId: record.typeId,
        kind: ResearchService.kindOf(record),
        category: ResearchService.categoryOf(record),
        status: ResearchService.storedStatusOf(record),
        important: ResearchService.isImportant(record),
        summary: _text(record.fields['summary']),
        notes: _text(record.fields['notes']),
        sourceUrl: _text(record.fields[ResearchRecordTypes.sourceUrlFieldId]),
        citation: _text(record.fields[ResearchRecordTypes.citationFieldId]),
        tags: record.tags,
      );

  /// The canonical field map for this draft, layered over [existing] so fields
  /// this Studio does not edit — anything written by the Codex, an import, or
  /// a future Studio — survive an edit untouched.
  Map<String, Object?> fields({Map<String, Object?> existing = const {}}) => {
        ...existing,
        'name': title.trim(),
        'summary': summary.trim(),
        'notes': notes.trim(),
        ResearchRecordTypes.kindFieldId: _choice(
          kind,
          ResearchRecordTypes.kinds,
          ResearchRecordTypes.defaultKind,
        ),
        ResearchRecordTypes.categoryFieldId: _choice(
          category,
          ResearchRecordTypes.categories,
          ResearchRecordTypes.defaultCategory,
        ),
        ResearchRecordTypes.statusFieldId: _choice(
          status,
          ResearchRecordTypes.statuses,
          ResearchRecordTypes.defaultStatus,
        ),
        ResearchRecordTypes.importantFieldId: important,
        ResearchRecordTypes.sourceUrlFieldId: sourceUrl.trim(),
        ResearchRecordTypes.citationFieldId: citation.trim(),
      };
}

/// Research Studio's domain service.
///
/// It owns no storage. Every read and write goes through [RecordService],
/// [ConnectionEngine], and [UniversalSearchService] against the canonical
/// AuthorOS database, exactly as Plot and Timeline Studio do.
class ResearchService {
  const ResearchService({required this.projectId, required this.repository});

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);
  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);
  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);
  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);
  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);
  ResearchQueryService get query => ResearchQueryService(this);

  Future<AuthorRecord> createResearch(
    ResearchDraft draft, {
    DateTime? timestamp,
  }) async {
    final title = draft.title.trim();
    if (draft.id.trim().isEmpty || title.isEmpty) {
      throw ArgumentError('Research id and title are required.');
    }
    final definition = await _requireResearchType(draft.typeId);
    final now = (timestamp ?? DateTime.now()).toUtc();
    return records.createRecord(
      AuthorRecord(
        id: draft.id,
        typeId: draft.typeId,
        templateId: draft.typeId,
        templateVersion: definition.templateVersion,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: title,
        schemaVersion: definition.templateVersion,
        fields: draft.fields(),
        tags: draft.tags,
        createdAt: now,
        updatedAt: now,
        extensionData: {'researchStudio': true, ...draft.extensionData},
      ),
    );
  }

  Future<AuthorRecord?> getResearch(String id) async {
    final record = await records.getRecord(id);
    return record != null && await isResearchRecord(record) ? record : null;
  }

  /// Applies [draft] to an existing entry, preserving every field, tag, and
  /// piece of extension data the Studio does not own.
  Future<AuthorRecord> updateResearch(
    ResearchDraft draft, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireResearch(draft.id);
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Research title is required.');
    }
    return records.updateRecord(
      existing.copyWith(
        title: title,
        fields: draft.fields(existing: existing.fields),
        tags: draft.tags,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  /// Flips the important flag without touching anything else on the record.
  Future<AuthorRecord> setImportant(
    String id,
    bool important, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireResearch(id);
    return records.updateRecord(
      existing.copyWith(
        fields: {
          ...existing.fields,
          ResearchRecordTypes.importantFieldId: important,
        },
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  Future<AuthorRecord> archiveResearch(String id, {DateTime? timestamp}) async {
    await _requireResearch(id);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> restoreResearch(String id, {DateTime? timestamp}) async {
    await _requireResearch(id);
    return records.restoreRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> deleteResearch(String id, {DateTime? timestamp}) async {
    await _requireResearch(id);
    return records.deleteRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> duplicateResearch(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return records.duplicateRecord(
      id,
      newId: newId,
      title: title,
      timestamp: timestamp,
    );
  }

  /// Searches the canonical FTS index and keeps the research hits.
  ///
  /// The index already carries every record's title, encoded fields, and tags,
  /// so title, summary, notes, category, kind, and tag matches all fall out of
  /// one query — no second index exists.
  Future<List<AuthorRecord>> searchResearch(String queryText) async {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return query.all();
    final results = await search.searchAll(trimmed);
    final found = <String, AuthorRecord>{};
    for (final result in results) {
      final record = await getResearch(result.recordId);
      if (record != null && record.status != AuthorRecordStatus.deleted) {
        found[record.id] = record;
      }
    }
    return found.values.toList()..sort(_byUpdatedDescending);
  }

  Future<RecordLink> connect({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    final source = await repository.recordById(sourceId);
    final target = await repository.recordById(targetId);
    if (source == null || target == null) {
      throw StateError('Research connections require Universal Record IDs.');
    }
    if ((source.projectId ?? source.scopeId) != projectId ||
        (target.projectId ?? target.scopeId) != projectId) {
      throw StateError('Research connections cannot cross projects.');
    }
    if (!await isResearchRecord(source) && !await isResearchRecord(target)) {
      throw StateError(
        'At least one connection endpoint must be a research record.',
      );
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

  Future<List<RecordLink>> connectionsFor(String id) async {
    await _requireResearch(id);
    return connections.connections(id);
  }

  /// The records on the far end of [id]'s connections, for the detail view.
  Future<List<ResearchConnection>> connectedRecords(String id) async {
    final links = await connectionsFor(id);
    final result = <ResearchConnection>[];
    for (final link in links) {
      final otherId = link.sourceId == id ? link.targetId : link.sourceId;
      final other = await repository.recordById(otherId);
      if (other == null) continue;
      if ((other.projectId ?? other.scopeId) != projectId) continue;
      result.add(ResearchConnection(link: link, record: other));
    }
    result.sort(
      (left, right) => left.record.title.toLowerCase().compareTo(
            right.record.title.toLowerCase(),
          ),
    );
    return result;
  }

  Future<UniversalRecordInspection?> inspectResearch(String id) async {
    final record = await _requireResearch(id);
    return inspector.inspectRecord(id, recordType: record.typeId);
  }

  Future<List<RecordVersion>> researchHistory(String id) async {
    await _requireResearch(id);
    return history.getVersionHistory(recordId: id);
  }

  Future<bool> isResearchRecord(AuthorRecord record) async {
    if ((record.projectId ?? record.scopeId) != projectId) return false;
    final registry = await records.registry();
    return registry.isTemplateCompatible(
      record.typeId,
      ResearchRecordTypes.baseTypeId,
    );
  }

  Future<RecordTypeDefinition> _requireResearchType(String typeId) async {
    final registry = await records.registry();
    if (!registry.isTemplateCompatible(
      typeId,
      ResearchRecordTypes.baseTypeId,
    )) {
      throw StateError('$typeId is not a research record type.');
    }
    return registry.resolve(typeId);
  }

  Future<AuthorRecord> _requireResearch(String id) async {
    final record = await getResearch(id);
    if (record == null) {
      throw StateError('$id is not a research record in $projectId.');
    }
    return record;
  }

  // --- Sources -----------------------------------------------------------
  //
  // `general-lore` already declares `sourceReferences`, and the Codex already
  // has a structured shape for it. Research reuses both rather than inventing
  // a source model: `sourceUrl` and `citation` stay the entry's own primary
  // source, and this list carries the further ones a real bibliography needs.

  /// Every structured source on [record], newest position last.
  static List<CodexSourceReference> sourcesOf(AuthorRecord record) =>
      CodexSourceReference.listFrom(record.fields[CodexFields.sources]);

  /// Replaces the structured source list on [id].
  Future<AuthorRecord> setSources(
    String id,
    List<CodexSourceReference> sources, {
    DateTime? timestamp,
  }) async {
    final record = await _requireResearch(id);
    return records.updateRecord(
      record.copyWith(
        fields: {
          ...record.fields,
          CodexFields.sources: [
            for (final source in sources) source.toJson(),
          ],
        },
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  Future<AuthorRecord> addSource(
    String id,
    CodexSourceReference source, {
    DateTime? timestamp,
  }) async {
    final record = await _requireResearch(id);
    return setSources(
      id,
      [...sourcesOf(record), source],
      timestamp: timestamp,
    );
  }

  /// Removes the source whose [CodexSourceReference.stableId] matches.
  Future<AuthorRecord> removeSource(
    String id,
    String stableId, {
    DateTime? timestamp,
  }) async {
    final record = await _requireResearch(id);
    return setSources(
      id,
      sourcesOf(record)
          .where((source) => source.stableId != stableId)
          .toList(),
      timestamp: timestamp,
    );
  }

  // --- Connections -------------------------------------------------------

  /// The connection types the shared registry accepts between two records.
  ///
  /// The registry is the authority on what may link to what; the Studio only
  /// offers what it already allows.
  Future<List<ConnectionTypeDefinition>> connectionTypesBetween({
    required String sourceTypeId,
    required String targetTypeId,
  }) async {
    final registry = BuiltInConnectionTypes.registry(
      additionalDefinitions:
          await repository.connectionTypeDefinitionsByScope(projectId),
    );
    return registry.definitions.where((definition) {
      try {
        registry.validateConnection(
          typeId: definition.id,
          sourceTypeId: sourceTypeId,
          targetTypeId: targetTypeId,
        );
        return true;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// Every record in the project a research entry may be connected to.
  ///
  /// Research reaches World, Character, Plot, Timeline, Codex and Note records
  /// because they are all Universal Records in the same project — no
  /// per-Studio allow-list is invented here.
  Future<List<AuthorRecord>> connectableRecords({String? excludeId}) async {
    final all = await repository.recordsByScope(projectId);
    final result = all
        .where((record) => record.id != excludeId)
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .where(
          (record) =>
              !CodexInfrastructureTypes.all.contains(record.typeId),
        )
        .toList();
    result.sort(_byTitle);
    return result;
  }

  Future<void> disconnect(String linkId, {DateTime? timestamp}) =>
      connections.disconnect(linkId, timestamp: timestamp);

  // --- Saved views -------------------------------------------------------
  //
  // A saved view is a stored filter, and the Codex already persists exactly
  // that as a `codexCollection` record of kind `savedView`. Research writes
  // the same record type with its own `studioId`, so no new type, table, or
  // store appears, and `StoryCodexService.getSavedViews` skips anything
  // stamped for another Studio.

  static const savedViewStudioId = 'research';

  Future<List<ResearchSavedView>> savedViews() async {
    final all = await repository.recordsByScope(projectId);
    final views = <ResearchSavedView>[];
    for (final record in all) {
      if (record.typeId != CodexInfrastructureTypes.collection) continue;
      if (record.status == AuthorRecordStatus.deleted) continue;
      if (record.fields['studioId'] != savedViewStudioId) continue;
      views.add(ResearchSavedView.readFrom(record));
    }
    views.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return views;
  }

  Future<ResearchSavedView> saveView({
    required String id,
    required String name,
    required ResearchViewFilter filter,
    DateTime? timestamp,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('A view name is required.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final existing = await repository.recordById(id);
    final record = AuthorRecord(
      id: id,
      typeId: CodexInfrastructureTypes.collection,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: normalized,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      revision: existing == null ? 1 : existing.revision + 1,
      fields: {
        'name': normalized,
        'kind': CodexCollectionKind.savedView.name,
        'studioId': savedViewStudioId,
        ..._savedViewFields(filter),
      },
    );
    await repository.putRecord(record);
    return ResearchSavedView.readFrom(record);
  }

  Future<void> deleteSavedView(String id) async {
    final record = await repository.recordById(id);
    if (record == null) return;
    if (record.fields['studioId'] != savedViewStudioId) {
      throw StateError('$id is not a Research saved view.');
    }
    await repository.putRecord(
      record.copyWith(
        status: AuthorRecordStatus.deleted,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  // --- Dashboard ---------------------------------------------------------

  /// Aggregates the project's research into the dashboard read-model.
  ///
  /// Every number is computed from the records on each call. Nothing here is
  /// stored, cached, or written back, so the dashboard can never disagree
  /// with the library it summarises.
  Future<ResearchDashboard> dashboard() async {
    final active = await query.all();
    final archived = active
        .where((record) => record.status == AuthorRecordStatus.archived)
        .length;
    final categories = <String>{};
    final tags = <String>{};
    var sources = 0;
    var notes = 0;
    var references = 0;
    var important = 0;
    var sourceEntries = 0;
    final unresolved = <AuthorRecord>[];
    for (final record in active) {
      categories.add(categoryOf(record));
      tags.addAll(record.tags.where((tag) => tag.trim().isNotEmpty));
      switch (kindOf(record)) {
        case 'Source':
          sources += 1;
        case 'Reference':
          references += 1;
        default:
          notes += 1;
      }
      if (isImportant(record)) important += 1;
      sourceEntries += sourcesOf(record).length;
      if (isUnresolved(record)) unresolved.add(record);
    }
    return ResearchDashboard(
      total: active.length,
      sources: sources,
      notes: notes,
      references: references,
      important: important,
      archived: archived,
      categories: categories.toList()..sort(),
      tags: tags.toList()
        ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        ),
      sourceReferences: sourceEntries,
      recent: ResearchQueryService.sorted(
        active,
        ResearchSort.recentlyUpdated,
      ).take(5).toList(),
      unresolved: unresolved,
    );
  }

  /// Whether [record] still needs the author's attention.
  ///
  /// Derived, never stored: research is unresolved while its status is not yet
  /// Reviewed or Verified, or while an entry claiming to be a Source carries
  /// no source at all. Archived research is settled by definition.
  static bool isUnresolved(AuthorRecord record) {
    if (record.status == AuthorRecordStatus.archived) return false;
    final status = storedStatusOf(record);
    if (status == 'New' || status == 'In Progress') return true;
    return kindOf(record) == 'Source' && !hasAnySource(record);
  }

  /// Whether [record] cites anything at all — a link, a citation, or a
  /// structured source reference.
  static bool hasAnySource(AuthorRecord record) =>
      _text(record.fields[ResearchRecordTypes.sourceUrlFieldId])
          .trim()
          .isNotEmpty ||
      _text(record.fields[ResearchRecordTypes.citationFieldId])
          .trim()
          .isNotEmpty ||
      sourcesOf(record).isNotEmpty;

  // --- Read-derived accessors -------------------------------------------
  //
  // These read the canonical record. Nothing here caches or stores.

  static String kindOf(AuthorRecord record) => _choice(
        record.fields[ResearchRecordTypes.kindFieldId],
        ResearchRecordTypes.kinds,
        ResearchRecordTypes.defaultKind,
      );

  static String categoryOf(AuthorRecord record) => _choice(
        record.fields[ResearchRecordTypes.categoryFieldId],
        ResearchRecordTypes.categories,
        ResearchRecordTypes.defaultCategory,
      );

  /// The status stored on the record, ignoring the lifecycle.
  static String storedStatusOf(AuthorRecord record) => _choice(
        record.fields[ResearchRecordTypes.statusFieldId],
        ResearchRecordTypes.statuses,
        ResearchRecordTypes.defaultStatus,
      );

  /// The status the author sees.
  ///
  /// Archiving lives on the Universal Record lifecycle, so an archived record
  /// reports `Archived` regardless of the field it carried before.
  static String statusOf(AuthorRecord record) =>
      record.status == AuthorRecordStatus.archived
          ? ResearchRecordTypes.archivedStatus
          : storedStatusOf(record);

  static bool isImportant(AuthorRecord record) {
    final value = record.fields[ResearchRecordTypes.importantFieldId];
    if (value is bool) return value;
    return value is String && value.toLowerCase() == 'true';
  }

  static String summaryOf(AuthorRecord record) =>
      _text(record.fields['summary']);

  static String notesOf(AuthorRecord record) => _text(record.fields['notes']);
}

/// A research connection paired with the record on its far end.
class ResearchConnection {
  const ResearchConnection({required this.link, required this.record});

  final RecordLink link;
  final AuthorRecord record;
}

/// Read-only queries over the canonical research records.
///
/// Every list here is derived from a repository read and filtered in memory.
/// Research volumes are per-project and small, so this stays deliberately
/// lightweight — no index, no cache, no background work.
class ResearchQueryService {
  const ResearchQueryService(this.research);

  final ResearchService research;

  Future<List<AuthorRecord>> byType(String typeId) =>
      research.repository.recordsByTypeAndScope(
        typeId: typeId,
        scopeId: research.projectId,
      );

  /// Every research record in the project, deleted ones excluded.
  Future<List<AuthorRecord>> all() async {
    final registry = await research.records.registry();
    final typeIds = registry.definitions
        .where(
          (definition) => registry.isTemplateCompatible(
            definition.id,
            ResearchRecordTypes.baseTypeId,
          ),
        )
        .map((definition) => definition.id);
    final found = <String, AuthorRecord>{};
    for (final typeId in typeIds) {
      for (final record in await byType(typeId)) {
        if (record.status == AuthorRecordStatus.deleted) continue;
        if ((record.projectId ?? record.scopeId) != research.projectId) {
          continue;
        }
        found[record.id] = record;
      }
    }
    return sorted(found.values.toList(), ResearchSort.recentlyUpdated);
  }

  Future<List<AuthorRecord>> byCategory(String category) async =>
      (await all())
          .where((record) => ResearchService.categoryOf(record) == category)
          .toList();

  Future<List<AuthorRecord>> byKind(String kind) async => (await all())
      .where((record) => ResearchService.kindOf(record) == kind)
      .toList();

  Future<List<AuthorRecord>> byStatus(String status) async => (await all())
      .where((record) => ResearchService.statusOf(record) == status)
      .toList();

  Future<List<AuthorRecord>> byTag(String tag) async => (await all())
      .where(
        (record) => record.tags.any(
          (candidate) => candidate.toLowerCase() == tag.toLowerCase(),
        ),
      )
      .toList();

  Future<List<AuthorRecord>> important() async =>
      (await all()).where(ResearchService.isImportant).toList();

  /// Every category that currently has at least one entry, with its count.
  Future<Map<String, int>> categoryCounts() async {
    final counts = <String, int>{};
    for (final record in await all()) {
      final category = ResearchService.categoryOf(record);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  /// Every tag in use across the project's research, alphabetically.
  Future<List<String>> tags() async {
    final tags = <String>{};
    for (final record in await all()) {
      tags.addAll(record.tags.where((tag) => tag.trim().isNotEmpty));
    }
    final ordered = tags.toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
    return ordered;
  }

  /// Orders [records] client-side. Sorting never touches storage.
  static List<AuthorRecord> sorted(
    List<AuthorRecord> records,
    ResearchSort sort,
  ) {
    final ordered = [...records];
    switch (sort) {
      case ResearchSort.recentlyUpdated:
        ordered.sort(_byUpdatedDescending);
      case ResearchSort.recentlyCreated:
        ordered.sort(
          (left, right) => right.createdAt.compareTo(left.createdAt),
        );
      case ResearchSort.alphabetical:
        ordered.sort(_byTitle);
      case ResearchSort.category:
        ordered.sort((left, right) {
          final compare = ResearchService.categoryOf(left)
              .compareTo(ResearchService.categoryOf(right));
          return compare != 0 ? compare : _byTitle(left, right);
        });
      case ResearchSort.importance:
        ordered.sort((left, right) {
          final leftImportant = ResearchService.isImportant(left) ? 0 : 1;
          final rightImportant = ResearchService.isImportant(right) ? 0 : 1;
          final compare = leftImportant.compareTo(rightImportant);
          return compare != 0 ? compare : _byUpdatedDescending(left, right);
        });
    }
    return ordered;
  }

  /// Applies a shelf to an already-loaded list. Read-derived, never stored.
  static List<AuthorRecord> onShelf(
    List<AuthorRecord> records,
    ResearchShelf shelf,
  ) =>
      switch (shelf) {
        ResearchShelf.all => records,
        ResearchShelf.sources => records
            .where((record) => ResearchService.kindOf(record) == 'Source')
            .toList(),
        ResearchShelf.notes => records
            .where((record) => ResearchService.kindOf(record) == 'Note')
            .toList(),
        ResearchShelf.references => records
            .where((record) => ResearchService.kindOf(record) == 'Reference')
            .toList(),
        ResearchShelf.important =>
          records.where(ResearchService.isImportant).toList(),
        ResearchShelf.unresolved =>
          records.where(ResearchService.isUnresolved).toList(),
        ResearchShelf.recent =>
          sorted(records, ResearchSort.recentlyUpdated).take(10).toList(),
      };
}

int _byTitle(AuthorRecord left, AuthorRecord right) =>
    left.title.toLowerCase().compareTo(right.title.toLowerCase());

int _byUpdatedDescending(AuthorRecord left, AuthorRecord right) {
  final compare = right.updatedAt.compareTo(left.updatedAt);
  return compare != 0 ? compare : _byTitle(left, right);
}

String _text(Object? value) => value is String ? value : '';

/// Resolves a stored choice, falling back to the field's declared default.
///
/// Records written before Research Studio existed carry no choice at all, so
/// they read as the same default the record type declares.
String _choice(Object? value, List<String> options, String fallback) {
  final text = value is String ? value.trim() : '';
  if (options.contains(text)) return text;
  for (final option in options) {
    if (option.toLowerCase() == text.toLowerCase()) return option;
  }
  return fallback;
}

/// A stored Research library filter.
///
/// Serialisable on purpose: it round-trips through the same
/// `codexCollection` record the Codex already uses for its saved views.
class ResearchViewFilter {
  const ResearchViewFilter({
    this.query = '',
    this.shelf = ResearchShelf.all,
    this.category = '',
    this.status = '',
    this.tag = '',
    this.sort = ResearchSort.recentlyUpdated,
  });

  final String query;
  final ResearchShelf shelf;
  final String category;
  final String status;
  final String tag;
  final ResearchSort sort;

}

/// The record fields a saved view stores its filter in.
///
/// A filter is written as ordinary record fields rather than an encoded blob,
/// so the stored view stays readable by the same record tooling as everything
/// else and no research type gains a serialisation format of its own.
Map<String, Object?> _savedViewFields(ResearchViewFilter filter) => {
      'viewQuery': filter.query,
      'viewShelf': filter.shelf.name,
      'viewCategory': filter.category,
      'viewStatus': filter.status,
      'viewTag': filter.tag,
      'viewSort': filter.sort.name,
    };

/// Reads a filter back off a saved-view record.
///
/// Anything missing or unrecognised — a view written by a future release, or
/// one whose shelf has since been renamed — falls back to the default rather
/// than dropping the view from the list.
ResearchViewFilter _savedViewFilter(AuthorRecord record) => ResearchViewFilter(
      query: _text(record.fields['viewQuery']),
      shelf: _enumByName(
        ResearchShelf.values,
        record.fields['viewShelf'],
        ResearchShelf.all,
      ),
      category: _text(record.fields['viewCategory']),
      status: _text(record.fields['viewStatus']),
      tag: _text(record.fields['viewTag']),
      sort: _enumByName(
        ResearchSort.values,
        record.fields['viewSort'],
        ResearchSort.recentlyUpdated,
      ),
    );

/// A named [ResearchViewFilter], persisted as a `codexCollection` record.
class ResearchSavedView {
  const ResearchSavedView({
    required this.id,
    required this.name,
    required this.filter,
  });

  final String id;
  final String name;
  final ResearchViewFilter filter;

  /// Reads a stored saved-view record.
  ///
  /// Named for what it does rather than as a `fromJson`: the record is the
  /// stored shape, so there is no separate serialisation format to parse.
  static ResearchSavedView readFrom(AuthorRecord record) => ResearchSavedView(
        id: record.id,
        name: record.title,
        filter: _savedViewFilter(record),
      );
}

/// The aggregated read-model behind the Research dashboard.
///
/// Every field is derived on read. None of it is persisted.
class ResearchDashboard {
  const ResearchDashboard({
    required this.total,
    required this.sources,
    required this.notes,
    required this.references,
    required this.important,
    required this.archived,
    required this.categories,
    required this.tags,
    required this.sourceReferences,
    required this.recent,
    required this.unresolved,
  });

  final int total;
  final int sources;
  final int notes;
  final int references;
  final int important;
  final int archived;
  final List<String> categories;
  final List<String> tags;

  /// How many structured source references exist across the library.
  final int sourceReferences;

  /// The most recently updated entries, newest first.
  final List<AuthorRecord> recent;

  /// Entries still needing attention, by [ResearchService.isUnresolved].
  final List<AuthorRecord> unresolved;

  bool get isEmpty => total == 0;
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
