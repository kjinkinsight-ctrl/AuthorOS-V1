import '../persistence/authoros_database.dart';
import 'branch_service.dart';
import 'connected_domain.dart';
import 'plot_record_types.dart';
import 'record_service.dart';
import 'search_models.dart';

class UniversalSearchService {
  const UniversalSearchService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  Future<List<SearchResult>> searchAll(
    String query, {
    UniversalSearchFilter? filter,
  }) =>
      _search(query, filter ?? UniversalSearchFilter(projectId: projectId));

  Future<List<SearchResult>> searchByType(
    String query,
    String recordType, {
    UniversalSearchFilter? filter,
  }) =>
      _search(
        query,
        (filter ?? UniversalSearchFilter(projectId: projectId))
            .copyWith(recordType: recordType),
      );

  Future<List<SearchResult>> searchByProject(
    String query,
    String requestedProjectId, {
    UniversalSearchFilter? filter,
  }) {
    if (requestedProjectId != projectId) {
      throw StateError('Search service cannot access $requestedProjectId.');
    }
    return _search(
      query,
      filter ?? UniversalSearchFilter(projectId: projectId),
    );
  }

  Future<List<SearchResult>> searchBySeries(
    String query,
    String seriesId, {
    UniversalSearchFilter? filter,
  }) =>
      _search(
        query,
        (filter ?? UniversalSearchFilter(projectId: projectId))
            .copyWith(seriesId: seriesId),
      );

  Future<List<SearchResult>> searchByBook(
    String query,
    String bookId, {
    UniversalSearchFilter? filter,
  }) =>
      _search(
        query,
        (filter ?? UniversalSearchFilter(projectId: projectId))
            .copyWith(bookId: bookId),
      );

  Future<List<SearchResult>> searchByStatus(
    String query,
    CanonStatus status, {
    UniversalSearchFilter? filter,
  }) =>
      _search(
        query,
        (filter ?? UniversalSearchFilter(projectId: projectId))
            .copyWith(canonStatus: status),
      );

  Future<List<SearchResult>> searchByBranch(
    String query,
    String branchId, {
    UniversalSearchFilter? filter,
  }) =>
      _search(
        query,
        (filter ?? UniversalSearchFilter(projectId: projectId))
            .copyWith(branchId: branchId),
      );

  Future<List<SearchResult>> _search(
    String query,
    UniversalSearchFilter filter,
  ) async {
    if (filter.projectId != projectId) {
      throw StateError('Search filter does not belong to $projectId.');
    }
    final normalized = query.trim();
    if (normalized.isEmpty) return [];
    final hits = await repository.searchIndex(
      _ftsQuery(normalized),
      exactQuery: normalized,
      filter: filter,
    );
    final branchService = filter.branchId == null
        ? null
        : BranchService(projectId: projectId, repository: repository);
    final branchEngine = await branchService?.loadEngine();
    final branchCreated = branchEngine == null
        ? const <String, AuthorRecord>{}
        : {
            for (final record in branchEngine.recordsForBranch(
              const <AuthorRecord>[],
              filter.branchId!,
            ))
              record.id: record,
          };
    final registry = await records.registry();
    final results = <String, SearchResult>{};
    for (final hit in hits) {
      if (hit.kind == SearchEntityKind.manuscriptNode) {
        final node = await repository.manuscriptNodeById(hit.entityId);
        if (node == null || node.projectId != projectId) continue;
        results[node.id] = _nodeResult(node, hit, filter.branchId);
        continue;
      }
      final parsed = parseBranchSearchEntityId(hit.entityId);
      final recordId = parsed?.recordId ?? hit.entityId;
      final canonical = await repository.recordById(recordId);
      var record = canonical ?? branchCreated[recordId];
      if (record == null) continue;
      if (branchEngine != null) {
        record = canonical == null
            ? branchCreated[recordId]
            : branchEngine.resolveRecord(record, filter.branchId!);
      }
      if (record == null || !_matches(record, filter)) continue;
      String? category;
      try {
        category = registry.resolve(record.typeId).categoryId;
      } on StateError {
        category = null;
      }
      final result = _recordResult(
        record,
        hit,
        category,
        normalized,
        filter.branchId,
      );
      final existing = results[record.id];
      if (existing == null || result.relevance > existing.relevance) {
        results[record.id] = result;
      }
    }
    final ordered = results.values.toList()
      ..sort((left, right) => right.relevance.compareTo(left.relevance));
    return ordered.take(filter.limit).toList();
  }

  bool _matches(AuthorRecord record, UniversalSearchFilter filter) =>
      (record.projectId ?? record.scopeId) == projectId &&
      (filter.recordType == null || record.typeId == filter.recordType) &&
      (filter.seriesId == null || record.seriesId == filter.seriesId) &&
      (filter.bookId == null || record.bookId == filter.bookId) &&
      (filter.canonStatus == null ||
          record.canonStatus == filter.canonStatus) &&
      (filter.lifecycleStatus == null ||
          record.status == filter.lifecycleStatus);
}

SearchResult _recordResult(
  AuthorRecord record,
  SearchIndexHit hit,
  String? category,
  String query,
  String? activeBranchId,
) =>
    SearchResult(
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
      snippet: hit.snippet,
      projectId: record.projectId ?? record.scopeId,
      seriesId: record.seriesId,
      bookId: record.bookId,
      branchId: activeBranchId ?? record.branchId,
      canonStatus: record.canonStatus,
      templateId: record.templateId,
      category: category,
      tags: record.tags,
      matchedField: record.tags.any(
        (tag) => tag.toLowerCase().contains(query.toLowerCase()),
      )
          ? 'tags'
          : hit.matchedField,
      relevance: -hit.rank,
      navigationTarget: SearchNavigationTarget(
        destination: _destination(record.typeId),
        recordId: record.id,
        projectId: record.projectId ?? record.scopeId,
        branchId: activeBranchId ?? record.branchId,
      ),
    );

SearchResult _nodeResult(
  ManuscriptNodeReference node,
  SearchIndexHit hit,
  String? branchId,
) =>
    SearchResult(
      recordId: node.id,
      recordType: node.nodeType,
      title: node.title,
      snippet: hit.snippet,
      projectId: node.projectId,
      branchId: branchId,
      canonStatus: CanonStatus.canon,
      matchedField: hit.matchedField,
      relevance: -hit.rank,
      navigationTarget: SearchNavigationTarget(
        destination: SearchDestination.manuscriptStudio,
        recordId: node.id,
        projectId: node.projectId,
        branchId: branchId,
      ),
    );

/// The Studio that owns records of [typeId].
///
/// Shared with workspaces that need to route to a connected record without
/// running a search first.
SearchDestination searchDestinationForType(String typeId) =>
    _destination(typeId);

SearchDestination _destination(String typeId) {
  if (typeId == 'timeline' || typeId.startsWith('timeline-')) {
    return SearchDestination.timelineStudio;
  }
  if (PlotRecordTypes.recordTypeIds.contains(typeId)) {
    return SearchDestination.plotStudio;
  }
  return switch (typeId) {
    'character' => SearchDestination.characterStudio,
    'location' ||
    'place' ||
    'faction' ||
    'organisation' ||
    'world' ||
    'item' ||
    'artefact' =>
      SearchDestination.worldStudio,
    'historical-event' || 'timeline-event' => SearchDestination.timelineStudio,
    'plot-thread' => SearchDestination.plotStudio,
    'scene' || 'chapter' || 'book' => SearchDestination.manuscriptStudio,
    'series' => SearchDestination.seriesStudio,
    'general-lore' ||
    'research-entry' ||
    'reference' ||
    'glossary-term' ||
    'codex-entry' =>
      SearchDestination.storyCodex,
    _ => SearchDestination.record,
  };
}

String _ftsQuery(String query) => query
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .map((term) => '"${term.replaceAll('"', '""')}"*')
    .join(' AND ');
