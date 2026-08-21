import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/research_domain.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/story_codex_domain.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';
import 'story_codex_service.dart';

export 'core/research_domain.dart';

/// What Research Studio needs to open a new research item.
///
/// A call shape, not a record: [ResearchService.createResearch] turns it into a
/// [CodexEntryDraft] so the entry is written by the existing Codex service as an
/// ordinary Universal Record.
class ResearchDraft {
  const ResearchDraft({
    required this.title,
    this.id,
    this.typeId = ResearchRecordTypes.entryTypeId,
    this.categoryId = 'research',
    this.summary = '',
    this.details = '',
    this.notes = '',
    this.aliases = const [],
    this.tagIds = const [],
    this.canonStatus = CodexCanonStatus.draft,
    this.knowledgeStatus = CodexKnowledgeStatus.unknown,
    this.sources = const [],
    this.seriesId,
    this.bookId,
  });

  final String title;
  final String? id;

  /// One of [ResearchRecordTypes.templateIds].
  final String typeId;

  /// A Codex category id; defaults to the built-in `research` category.
  final String categoryId;

  /// The `summary` template field.
  final String summary;

  /// The `description` template field, shown as the item's detail body.
  final String details;

  /// The `notes` template field.
  final String notes;

  /// The `aliases` template field.
  final List<String> aliases;

  final List<String> tagIds;
  final CodexCanonStatus canonStatus;

  /// The `knowledgeStatus` template field, read as reliability.
  final CodexKnowledgeStatus knowledgeStatus;

  /// Entries for the `sourceReferences` template field.
  final List<CodexSourceReference> sources;

  final String? seriesId;
  final String? bookId;
}

/// The Research Studio service.
///
/// Research Studio introduces no persistence of its own. Every read and write
/// goes through [StoryCodexService], which composes `RecordService`,
/// `RecordTypeRegistry`, `ConnectionEngine`, `UniversalSearchService`,
/// `UniversalRecordInspector`, `VersionAuditService` and `SafeDeleteService`
/// over the shared AuthorOS Drift database. This class only narrows that
/// surface to the record types in [ResearchRecordTypes] and adds the derived
/// read-models the Studio renders.
class ResearchService {
  ResearchService({
    required this.projectId,
    required this.repository,
  }) : codex = StoryCodexService(projectId: projectId, repository: repository);

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// The shared Codex service every research write is routed through.
  final StoryCodexService codex;

  RecordService get records => codex.records;
  ConnectionEngine get connections => codex.connections;
  UniversalSearchService get search => codex.search;
  VersionAuditService get history => codex.history;
  UniversalRecordInspector get inspector => codex.inspector;
  SafeDeleteService get safeDelete => codex.safeDelete;

  /// Record type ids this Studio owns.
  Set<String> get typeIds => ResearchRecordTypes.typeIds;

  // --- Lifecycle ---------------------------------------------------------

  Future<CodexEntry> createResearch(
    ResearchDraft draft, {
    DateTime? timestamp,
  }) async {
    if (!ResearchRecordTypes.templateIds.contains(draft.typeId)) {
      throw ArgumentError(
        '${draft.typeId} is not a Research Studio record type.',
      );
    }
    final entry = await codex.createCodexEntry(
      CodexEntryDraft(
        id: draft.id,
        title: draft.title,
        templateId: draft.typeId,
        categoryId: draft.categoryId,
        summary: draft.summary,
        content: draft.details,
        tagIds: draft.tagIds,
        canonStatus: draft.canonStatus,
        seriesId: draft.seriesId,
        bookId: draft.bookId,
        structuredFields: {
          if (draft.notes.trim().isNotEmpty) 'notes': draft.notes.trim(),
          if (draft.aliases.isNotEmpty)
            CodexFields.aliases: draft.aliases
                .map((alias) => alias.trim())
                .where((alias) => alias.isNotEmpty)
                .toList(),
          CodexFields.knowledgeStatus:
              codexKnowledgeStatusValue(draft.knowledgeStatus),
        },
      ),
      timestamp: timestamp,
    );
    if (draft.sources.isEmpty) return entry;
    var stored = entry;
    for (final source in draft.sources) {
      stored = await codex.addSource(entry.id, source, timestamp: timestamp);
    }
    return stored;
  }

  Future<CodexEntry?> getResearch(String id) async {
    final entry = await codex.getCodexEntry(id);
    return entry != null && _isResearch(entry) ? entry : null;
  }

  Future<CodexEntry> updateResearch(
    String id, {
    String? title,
    String? summary,
    String? details,
    String? notes,
    List<String>? aliases,
    String? categoryId,
    List<String>? tagIds,
    CodexCanonStatus? canonStatus,
    CodexKnowledgeStatus? knowledgeStatus,
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.updateCodexEntry(
      id,
      title: title,
      summary: summary,
      content: details,
      categoryId: categoryId,
      tagIds: tagIds,
      canonStatus: canonStatus,
      structuredFields: {
        if (notes != null) 'notes': notes.trim(),
        if (aliases != null)
          CodexFields.aliases: aliases
              .map((alias) => alias.trim())
              .where((alias) => alias.isNotEmpty)
              .toList(),
        if (knowledgeStatus != null)
          CodexFields.knowledgeStatus:
              codexKnowledgeStatusValue(knowledgeStatus),
      },
      timestamp: timestamp,
    );
  }

  Future<CodexEntry> archiveResearch(String id) async {
    await _requireResearch(id);
    return codex.archiveCodexEntry(id);
  }

  Future<CodexEntry> restoreResearch(String id) async {
    await _requireResearch(id);
    return codex.restoreCodexEntry(id);
  }

  /// Soft-deletes a research item.
  ///
  /// The record architecture has no hard delete: [AuthorRecordStatus.deleted]
  /// is the terminal state, so the record and its history survive.
  Future<CodexEntry> deleteResearch(String id) async {
    await _requireResearch(id);
    return codex.deleteCodexEntry(id);
  }

  Future<CodexEntry> duplicateResearch(String id, {DateTime? timestamp}) async {
    await _requireResearch(id);
    return codex.duplicateCodexEntry(id, timestamp: timestamp);
  }

  // --- Reads -------------------------------------------------------------

  Future<List<CodexEntry>> listResearch({bool includeArchived = false}) async {
    final entries = await codex.getEntries(includeArchived: includeArchived);
    return entries.where(_isResearch).toList();
  }

  /// Applies [filter] through the Codex service, then the Research-only facets.
  Future<List<CodexEntry>> filterResearch(ResearchFilter filter) async {
    final entries = (await codex.filterEntries(filter.toCodexFilter()))
        .where(_isResearch)
        .toList();
    final connected =
        filter.onlyConnected ? await _connectedIds(entries) : const <String>{};
    final matched = entries.where((entry) {
      if (filter.onlyUnresolved && researchIsResolved(entry)) return false;
      if (filter.onlyConnected && !connected.contains(entry.id)) return false;
      return true;
    }).toList();
    if (filter.sort == ResearchSort.reliability) {
      matched.sort((left, right) {
        final compared = researchReliabilityRank(left.knowledgeStatus)
            .compareTo(researchReliabilityRank(right.knowledgeStatus));
        return compared != 0
            ? compared
            : left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    }
    return matched;
  }

  /// Full-text search over stored research records.
  ///
  /// Delegates to [UniversalSearchService], which reads the database's FTS
  /// index. No second index is built.
  Future<List<CodexEntry>> searchResearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return listResearch();
    return (await codex.searchCodex(normalized)).where(_isResearch).toList();
  }

  Future<List<CodexCategory>> categories() async {
    final all = await codex.getCategories();
    final used = {
      for (final entry in await listResearch(includeArchived: true))
        entry.categoryId,
    };
    return all
        .where((category) =>
            ResearchRecordTypes.categoryIds.contains(category.id) ||
            used.contains(category.id))
        .toList();
  }

  Future<List<CodexTag>> tags() => codex.getTags();

  Future<CodexTag> createTag({
    required String name,
    String description = '',
    String group = '',
    DateTime? timestamp,
  }) =>
      codex.createTag(
        name: name,
        description: description,
        group: group,
        timestamp: timestamp,
      );

  /// Every source cited by the project's research, rolled up by source id.
  Future<List<ResearchSourceUsage>> sources() async =>
      _rollUpSources(await listResearch(includeArchived: true));

  /// Everything the Research dashboard renders.
  Future<ResearchDashboard> dashboard({int recentLimit = 5}) async {
    final all = await listResearch(includeArchived: true);
    final active =
        all.where((entry) => !entry.isArchived && !entry.isDeleted).toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final categoryCounts = <String, int>{};
    final tagCounts = <String, int>{};
    final typeCounts = <String, int>{};
    for (final entry in active) {
      categoryCounts.update(entry.categoryId, (value) => value + 1,
          ifAbsent: () => 1);
      typeCounts.update(entry.recordType, (value) => value + 1,
          ifAbsent: () => 1);
      for (final tag in entry.tagIds) {
        tagCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return ResearchDashboard(
      items: active,
      recent: active.take(recentLimit).toList(),
      unresolved:
          active.where((entry) => !researchIsResolved(entry)).toList(),
      connectedItemIds: await _connectedIds(active),
      sources: _rollUpSources(active),
      categoryCounts: categoryCounts,
      tagCounts: tagCounts,
      typeCounts: typeCounts,
      archivedCount: all.where((entry) => entry.isArchived).length,
    );
  }

  // --- Sources -----------------------------------------------------------

  Future<List<CodexSourceReference>> sourcesFor(String id) async {
    final entry = await _requireResearch(id);
    return entry.sources;
  }

  Future<CodexEntry> addSource(
    String id,
    CodexSourceReference source, {
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.addSource(id, source, timestamp: timestamp);
  }

  Future<CodexEntry> updateSource(
    String id,
    CodexSourceReference source, {
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.updateSource(id, source, timestamp: timestamp);
  }

  Future<CodexEntry> removeSource(
    String id,
    String sourceId, {
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.removeSource(id, sourceId, timestamp: timestamp);
  }

  // --- Status ------------------------------------------------------------

  Future<CodexEntry> setKnowledgeStatus(
    String id,
    CodexKnowledgeStatus status, {
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.setKnowledgeStatus(id, status, timestamp: timestamp);
  }

  Future<CodexEntry> setCanonStatus(
    String id,
    CodexCanonStatus status, {
    DateTime? timestamp,
  }) async {
    await _requireResearch(id);
    return codex.setCanonStatus(id, status, timestamp: timestamp);
  }

  // --- Connections -------------------------------------------------------

  /// Everything in this project a research item can be connected to.
  ///
  /// Story entities are Universal Records; manuscript chapters and scenes are
  /// manuscript nodes. Both are connectable entities in the shared connection
  /// engine, so both are offered here. [excludeId] drops the research item
  /// doing the connecting, since a record cannot link to itself.
  Future<List<ResearchConnectionTarget>> connectionTargets({
    String? excludeId,
  }) async {
    final records = await codex.connectableRecords();
    final nodes = (await repository.snapshot())
        .manuscriptNodes
        .where((node) => node.projectId == projectId);
    final targets = <ResearchConnectionTarget>[
      for (final record in records)
        if (record.id != excludeId)
          ResearchConnectionTarget(
            id: record.id,
            title: record.title,
            typeId: record.typeId,
            isManuscriptNode: false,
          ),
      for (final node in nodes)
        if (node.id != excludeId)
          ResearchConnectionTarget(
            id: node.id,
            title: node.title,
            typeId: node.nodeType,
            isManuscriptNode: true,
          ),
    ]..sort((left, right) =>
        left.title.toLowerCase().compareTo(right.title.toLowerCase()));
    return targets;
  }

  /// Connection types that permit `research type -> targetTypeId`.
  Future<List<ConnectionTypeDefinition>> connectionTypesFor({
    required String sourceTypeId,
    required String targetTypeId,
  }) =>
      codex.connectionTypesBetween(
        sourceTypeId: sourceTypeId,
        targetTypeId: targetTypeId,
      );

  Future<RecordLink> connectResearch({
    required String researchId,
    required String targetId,
    required String typeId,
    String label = '',
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    await _requireResearch(researchId);
    return codex.connectEntry(
      sourceId: researchId,
      targetId: targetId,
      typeId: typeId,
      label: label,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<void> disconnectResearch(String linkId, {DateTime? timestamp}) =>
      codex.disconnectEntry(linkId, timestamp: timestamp);

  /// The links on [id], resolved against the record at the other end.
  Future<List<ResearchConnectionView>> connectionsFor(String id) async {
    await _requireResearch(id);
    final links = await codex.getCodexConnections(id);
    final views = <ResearchConnectionView>[];
    for (final link in links) {
      final outgoing = link.sourceId == id;
      final otherId = outgoing ? link.targetId : link.sourceId;
      final other = await repository.recordById(otherId);
      final node =
          other == null ? await repository.manuscriptNodeById(otherId) : null;
      if (other == null && node == null) continue;
      views.add(ResearchConnectionView(
        linkId: link.id,
        typeId: link.typeId,
        label: link.label.isEmpty ? link.typeId : link.label,
        otherId: otherId,
        otherTitle: other?.title ?? node!.title,
        otherTypeId: other?.typeId ?? node!.nodeType,
        outgoing: outgoing,
      ));
    }
    views.sort((left, right) => left.otherTitle
        .toLowerCase()
        .compareTo(right.otherTitle.toLowerCase()));
    return views;
  }

  // --- Inspection --------------------------------------------------------

  Future<RecordValidationResult> validateResearch(String id) async {
    final entry = await _requireResearch(id);
    return records.validateRecord(entry.record);
  }

  Future<RecordTypeDefinition> template(String typeId) async =>
      (await codex.templateRegistry()).resolve(typeId);

  Future<List<RecordVersion>> historyFor(String id) async {
    await _requireResearch(id);
    return history.getVersionHistory(recordId: id);
  }

  Future<UniversalRecordInspection?> inspect(String id) async {
    final entry = await _requireResearch(id);
    return inspector.inspectRecord(id, recordType: entry.record.typeId);
  }

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) async {
    await _requireResearch(id);
    return safeDelete.analyze(id);
  }

  // --- Internals ---------------------------------------------------------

  bool _isResearch(CodexEntry entry) =>
      ResearchRecordTypes.owns(entry.record.typeId) ||
      ResearchRecordTypes.owns(entry.recordType);

  Future<CodexEntry> _requireResearch(String id) async {
    final entry = await getResearch(id);
    if (entry == null) {
      throw StateError('Research item $id does not belong to $projectId.');
    }
    return entry;
  }

  Future<Set<String>> _connectedIds(Iterable<CodexEntry> entries) async {
    final ids = {for (final entry in entries) entry.id};
    if (ids.isEmpty) return const {};
    final links = (await repository.snapshot()).links;
    final connected = <String>{};
    for (final link in links) {
      if (link.scopeId != projectId) continue;
      if (ids.contains(link.sourceId) && link.sourceId != link.targetId) {
        connected.add(link.sourceId);
      }
      if (ids.contains(link.targetId) && link.sourceId != link.targetId) {
        connected.add(link.targetId);
      }
    }
    return connected;
  }

  List<ResearchSourceUsage> _rollUpSources(List<CodexEntry> entries) {
    final byId = <String, ResearchSourceUsage>{};
    for (final entry in entries) {
      for (final source in entry.sources) {
        final key = source.stableId;
        final existing = byId[key];
        byId[key] = ResearchSourceUsage(
          id: key,
          label: source.displayLabel,
          kind: source.kind,
          location: source.location,
          itemIds: [...?existing?.itemIds, entry.id],
        );
      }
    }
    final usages = byId.values.toList()
      ..sort((left, right) {
        final compared = right.usageCount.compareTo(left.usageCount);
        return compared != 0
            ? compared
            : left.label.toLowerCase().compareTo(right.label.toLowerCase());
      });
    return usages;
  }
}
