/// The Universal Story Graph read model.
///
/// This is a **query surface, not a store**. It owns no table, no cache and no
/// index; every answer is assembled from the repository the rest of AuthorOS
/// already writes through, and nothing here mutates anything (invariant I-15).
/// Relationship writes stay on [ConnectionEngine] — see `StoryGraphMutations`,
/// which delegates rather than validating a second time.
///
/// Its one genuinely new capability is reading **both node kinds through one
/// call**. `RecordService.getRecord` returns null for a scene, and
/// `ConnectionEngine.linkedRecords` silently drops manuscript nodes, so a view
/// built on either would lose half the manuscript spine. [StoryGraphNode] is
/// the union, and [getNode] is where the fallback lives.
library;

import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'connection_types.dart';
import 'record_inspection.dart';
import 'record_inspector.dart';
import 'record_service.dart';
import 'record_types.dart';
import 'story_graph.dart';

/// Default ceiling on how many nodes one read may return.
///
/// Both a depth limit and a node cap are required, not one or the other: 73 of
/// ~130 connection types permit `*` -> `*`, so a two-hop walk from a
/// well-connected character can reach most of a project.
const int kStoryGraphDefaultMaxNodes = 250;

class StoryGraphService {
  StoryGraphService({
    required this.projectId,
    required this.repository,
    this.branchId,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// Reserved for branch-aware reads. Carried so callers can pass it today and
  /// keep working when overlay support lands; it does not filter yet.
  final String? branchId;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);

  RecordTypeRegistry? _recordTypes;
  ConnectionTypeRegistry? _connectionTypes;
  final Map<String, String> _categoryCache = {};

  /// Registries are resolved once per service instance.
  ///
  /// This is not a data cache — records and links are always read fresh. It
  /// caches only the type *definitions*, which change when an author edits a
  /// custom type, not while a single view is rendering.
  Future<RecordTypeRegistry> recordTypes() async =>
      _recordTypes ??= await records.registry();

  Future<ConnectionTypeRegistry> connectionTypes() async =>
      _connectionTypes ??= await records.connectionRegistry();

  // ------------------------------------------------------------------ nodes

  /// The node for [id], of whichever kind it is, or null if this project does
  /// not own it.
  ///
  /// Returning null rather than throwing for a foreign id is deliberate: a
  /// graph view resolves ids that came from links, and a link into another
  /// project is a data problem to render as a gap, not an exception to crash a
  /// whole neighbourhood on.
  Future<StoryGraphNode?> getNode(String id) async {
    final record = await repository.recordById(id);
    if (record != null) {
      if (!_recordBelongsToProject(record)) return null;
      return StoryGraphNode.fromRecord(
        record,
        categoryId: await _categoryFor(record.typeId),
      );
    }
    final node = await repository.manuscriptNodeById(id);
    if (node == null || node.projectId != projectId) return null;
    return StoryGraphNode.fromManuscriptNode(node);
  }

  /// Hydrates many ids at once, in two queries rather than one per id.
  ///
  /// Ids this project does not own are absent from the result rather than
  /// present as nulls.
  Future<Map<String, StoryGraphNode>> getNodes(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const {};

    final records = await repository.recordsByIds(wanted);
    final nodes = <String, StoryGraphNode>{};
    for (final record in records) {
      if (!_recordBelongsToProject(record)) continue;
      nodes[record.id] = StoryGraphNode.fromRecord(
        record,
        categoryId: await _categoryFor(record.typeId),
      );
    }

    // Only ids that were not records can be manuscript nodes: an id is one or
    // the other, never both — `ConnectedDomainTransaction` rejects the overlap.
    final remaining = wanted.difference(nodes.keys.toSet());
    if (remaining.isNotEmpty) {
      for (final node in await repository.manuscriptNodesByIds(remaining)) {
        if (node.projectId != projectId) continue;
        nodes[node.id] = StoryGraphNode.fromManuscriptNode(node);
      }
    }
    return nodes;
  }

  // ------------------------------------------------------------------ edges

  /// Every edge touching [nodeId], in both directions.
  Future<List<StoryGraphEdge>> getEdges(
    String nodeId, {
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
  }) async =>
      _edgesFrom(await repository.backlinks(nodeId), filter);

  Future<List<StoryGraphEdge>> getOutgoingEdges(
    String nodeId, {
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
  }) async =>
      _edgesFrom(await repository.outgoingLinks(nodeId), filter);

  Future<List<StoryGraphEdge>> getIncomingEdges(
    String nodeId, {
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
  }) async =>
      _edgesFrom(await repository.incomingLinks(nodeId), filter);

  /// Derived relationships for [nodeId].
  ///
  /// Empty today, and deliberately still present: the shape is the point. A
  /// derived edge arrives from a *different method* returning a *different
  /// type* with no id, so no future provider can quietly feed inferences into
  /// the same list as persisted links.
  Future<List<DerivedStoryGraphEdge>> getDerivedEdges(String nodeId) async =>
      const [];

  // ---------------------------------------------------------- neighbourhood

  /// [nodeId] and everything one hop from it, grouped for the explorer.
  Future<StoryGraphNeighbourhood?> getNeighbours(
    String nodeId, {
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
    StoryGraphDirection direction = StoryGraphDirection.any,
    int maxNodes = kStoryGraphDefaultMaxNodes,
  }) async {
    final centre = await getNode(nodeId);
    if (centre == null) return null;

    final links = switch (direction) {
      StoryGraphDirection.incoming => await repository.incomingLinks(nodeId),
      StoryGraphDirection.outgoing => await repository.outgoingLinks(nodeId),
      StoryGraphDirection.any => await repository.backlinks(nodeId),
    };
    final edges = await _edgesFrom(links, filter);
    final neighbours = await getNodes(
      edges.map((edge) => edge.otherEnd(nodeId)).toSet(),
    );

    final kept = <StoryGraphNode>[];
    final keptIds = <String>{};
    var truncated = false;
    for (final edge in edges) {
      final neighbour = neighbours[edge.otherEnd(nodeId)];
      if (neighbour == null || neighbour.id == nodeId) continue;
      if (!_allows(neighbour, filter)) continue;
      if (keptIds.contains(neighbour.id)) continue;
      // The cap is checked before the id is recorded, so a node the cap
      // excluded cannot leave its edges behind in `visible` below.
      if (kept.length >= maxNodes) {
        truncated = true;
        break;
      }
      keptIds.add(neighbour.id);
      kept.add(neighbour);
    }

    final visible = [
      for (final edge in edges)
        if (keptIds.contains(edge.otherEnd(nodeId))) edge,
    ];

    return StoryGraphNeighbourhood(
      centre: centre,
      edges: visible,
      neighbours: kept,
      buckets: groupIntoBuckets(kept),
      truncated: truncated,
      derivedEdges: await getDerivedEdges(nodeId),
    );
  }

  /// "Show me everything connected to Kali", as counts per bucket.
  Future<ConnectionSummary?> connectionSummary(
    String nodeId, {
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
  }) async {
    // The cap is lifted deliberately: a summary that stopped counting at 250
    // would report a number the author could not act on.
    final neighbourhood = await getNeighbours(
      nodeId,
      filter: filter,
      maxNodes: 1 << 30,
    );
    if (neighbourhood == null) return null;
    return ConnectionSummary(
      node: neighbourhood.centre,
      counts: {
        for (final entry in neighbourhood.buckets.entries)
          entry.key: entry.value.length,
      },
    );
  }

  /// Delegates to the inspector every Studio already uses.
  ///
  /// The graph does not grow a second detail panel. Manuscript nodes return
  /// null because the inspector resolves records only; a view should say so
  /// rather than inventing an inspection.
  Future<UniversalRecordInspection?> inspect(
    String nodeId, {
    String? branchId,
  }) =>
      inspector.inspectRecord(nodeId, branchId: branchId ?? this.branchId);

  // -------------------------------------------------------------- traversal

  /// A bounded region of the graph around [rootId].
  ///
  /// Depth **and** node cap both apply. Either alone is insufficient: depth
  /// alone lets one hub node pull in a whole project, and a cap alone gives no
  /// control over how far the shape reaches.
  Future<StorySubgraph> getSubgraph(
    String rootId, {
    int depth = 2,
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
    int maxNodes = kStoryGraphDefaultMaxNodes,
  }) async {
    final root = await getNode(rootId);
    if (root == null) return StorySubgraph.empty;

    final nodes = <String, StoryGraphNode>{rootId: root};
    var frontier = <String>{rootId};
    var truncated = false;
    var reached = 0;

    for (var hop = 0; hop < depth && frontier.isNotEmpty; hop++) {
      final links = await repository.linksForEntities(
        frontier,
        typeIds: filter.queryableEdgeTypeIds,
      );
      final edges = await _edgesFrom(links, filter);

      final candidates = <String>{};
      for (final edge in edges) {
        for (final endpoint in [edge.sourceId, edge.targetId]) {
          if (!nodes.containsKey(endpoint)) candidates.add(endpoint);
        }
      }
      if (candidates.isEmpty) break;

      final hydrated = await getNodes(candidates);
      final next = <String>{};
      for (final candidate in candidates) {
        final node = hydrated[candidate];
        if (node == null || !_allows(node, filter)) continue;
        if (nodes.length >= maxNodes) {
          truncated = true;
          break;
        }
        nodes[node.id] = node;
        next.add(node.id);
      }
      // Only count a hop that actually reached something, so `depthReached`
      // reports how far the region really extends rather than how far we asked.
      if (next.isNotEmpty) reached = hop + 1;
      if (truncated) break;
      frontier = next;
    }

    // One final sweep so edges *between* nodes at the same depth are present,
    // not just the ones the walk arrived along. Without it the result is a
    // spanning tree rather than the subgraph.
    final edges = await _edgesFrom(
      await repository.linksForEntities(
        nodes.keys,
        typeIds: filter.queryableEdgeTypeIds,
      ),
      filter,
    );

    return StorySubgraph(
      rootId: rootId,
      nodes: nodes.values.toList(),
      edges: [
        for (final edge in edges)
          if (nodes.containsKey(edge.sourceId) &&
              nodes.containsKey(edge.targetId))
            edge,
      ],
      depthReached: reached,
      truncated: truncated,
    );
  }

  /// Every node in the project, capped.
  Future<StorySubgraph> getProjectGraph({
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
    int maxNodes = kStoryGraphDefaultMaxNodes,
  }) async {
    final nodes = <String, StoryGraphNode>{};
    var truncated = false;

    for (final record in await repository.recordsByProject(projectId)) {
      final node = StoryGraphNode.fromRecord(
        record,
        categoryId: await _categoryFor(record.typeId),
      );
      if (!_allows(node, filter)) continue;
      if (nodes.length >= maxNodes) {
        truncated = true;
        break;
      }
      nodes[node.id] = node;
    }

    if (!truncated) {
      for (final reference
          in await repository.manuscriptNodesForProject(projectId)) {
        final node = StoryGraphNode.fromManuscriptNode(reference);
        if (!_allows(node, filter)) continue;
        if (nodes.length >= maxNodes) {
          truncated = true;
          break;
        }
        nodes[node.id] = node;
      }
    }

    final edges = await _edgesFrom(
      await repository.linksForEntities(
        nodes.keys,
        typeIds: filter.queryableEdgeTypeIds,
      ),
      filter,
    );

    return StorySubgraph(
      nodes: nodes.values.toList(),
      edges: [
        for (final edge in edges)
          if (nodes.containsKey(edge.sourceId) &&
              nodes.containsKey(edge.targetId))
            edge,
      ],
      depthReached: 0,
      truncated: truncated,
    );
  }

  /// How [fromId] connects to [toId] — the question no existing screen answers.
  ///
  /// Breadth-first, so shorter routes come first, and bounded on both depth and
  /// result count because the wildcard edge density makes an exhaustive search
  /// unaffordable.
  Future<List<StoryGraphPath>> findPaths(
    String fromId,
    String toId, {
    int maxDepth = 4,
    int maxPaths = 10,
    StoryGraphFilter filter = StoryGraphFilter.unfiltered,
  }) async {
    if (fromId == toId || maxDepth < 1 || maxPaths < 1) return const [];
    final start = await getNode(fromId);
    final end = await getNode(toId);
    if (start == null || end == null) return const [];

    final found = <List<StoryGraphEdge>>[];
    // Each entry is the edge chain walked so far; the node chain is derived at
    // the end, so the queue stays cheap.
    var queue = <List<StoryGraphEdge>>[<StoryGraphEdge>[]];
    final nodeCache = <String, StoryGraphNode>{fromId: start, toId: end};

    for (var hop = 0; hop < maxDepth && queue.isNotEmpty; hop++) {
      final tails = <String>{
        for (final path in queue) _tailOf(path, fromId),
      };
      final links = await repository.linksForEntities(
        tails,
        typeIds: filter.queryableEdgeTypeIds,
      );
      final byEndpoint = <String, List<StoryGraphEdge>>{};
      for (final edge in await _edgesFrom(links, filter)) {
        for (final endpoint in {edge.sourceId, edge.targetId}) {
          byEndpoint.putIfAbsent(endpoint, () => []).add(edge);
        }
      }

      final next = <List<StoryGraphEdge>>[];
      for (final path in queue) {
        final tail = _tailOf(path, fromId);
        final visited = _visitedOf(path, fromId);
        for (final edge in byEndpoint[tail] ?? const <StoryGraphEdge>[]) {
          final step = edge.otherEnd(tail);
          if (visited.contains(step)) continue;
          final extended = [...path, edge];
          if (step == toId) {
            found.add(extended);
            if (found.length >= maxPaths) break;
            continue;
          }
          next.add(extended);
        }
        if (found.length >= maxPaths) break;
      }
      if (found.length >= maxPaths) break;
      queue = next;
    }

    final missing = <String>{
      for (final path in found)
        ..._visitedOf(path, fromId).where((id) => !nodeCache.containsKey(id)),
    };
    nodeCache.addAll(await getNodes(missing));

    return [
      for (final path in found)
        StoryGraphPath(
          nodes: [
            for (final id in _nodeChain(path, fromId))
              if (nodeCache[id] != null) nodeCache[id]!,
          ],
          edges: path,
        ),
    ];
  }

  /// The node a path currently ends at.
  String _tailOf(List<StoryGraphEdge> path, String fromId) {
    var current = fromId;
    for (final edge in path) {
      current = edge.otherEnd(current);
    }
    return current;
  }

  List<String> _nodeChain(List<StoryGraphEdge> path, String fromId) {
    final chain = <String>[fromId];
    var current = fromId;
    for (final edge in path) {
      current = edge.otherEnd(current);
      chain.add(current);
    }
    return chain;
  }

  Set<String> _visitedOf(List<StoryGraphEdge> path, String fromId) =>
      _nodeChain(path, fromId).toSet();

  // ---------------------------------------------------------------- helpers

  /// Groups nodes for the Connection Explorer. Empty buckets are omitted, and
  /// the order follows [StoryGraphBucket]'s declaration order so the panel does
  /// not reshuffle between reads.
  Map<StoryGraphBucket, List<StoryGraphNode>> groupIntoBuckets(
    Iterable<StoryGraphNode> nodes,
  ) {
    final grouped = <StoryGraphBucket, List<StoryGraphNode>>{};
    for (final node in nodes) {
      grouped.putIfAbsent(node.bucket, () => <StoryGraphNode>[]).add(node);
    }
    return {
      for (final bucket in StoryGraphBucket.values)
        if (grouped[bucket] != null)
          bucket: grouped[bucket]!
            ..sort((left, right) => left.title.compareTo(right.title)),
    };
  }

  Future<List<StoryGraphEdge>> _edgesFrom(
    List<RecordLink> links,
    StoryGraphFilter filter,
  ) async {
    if (links.isEmpty) return const [];
    final registry = await connectionTypes();
    final edges = <StoryGraphEdge>[];
    for (final link in links) {
      if (link.scopeId != projectId) continue;
      final definition = _definitionOrNull(registry, link.typeId);
      if (!filter.allowsEdgeType(link.typeId, definition)) continue;
      edges.add(
        StoryGraphEdge(
          link: link,
          inverseLabel: definition?.inverseLabel ?? '',
          wildcard: definition?.permits('*', '*') ?? false,
        ),
      );
    }
    return edges;
  }

  bool _allows(StoryGraphNode node, StoryGraphFilter filter) {
    // Workspace artefacts are outside the graph by definition, not by filter,
    // so no filter setting can reveal them.
    if (kNonGraphRecordTypeIds.contains(node.typeId)) return false;
    if (!filter.allowsStatus(node.lifecycleStatus)) return false;
    if (!filter.allowsCategory(node.categoryId)) return false;
    if (!filter.allowsCanon(node.canonStatus)) return false;
    final record = node.record;
    if (record != null) {
      if (filter.seriesId != null && record.seriesId != filter.seriesId) {
        return false;
      }
      // A null `bookId` is not "unassigned", it is *series canon*: a record
      // shared by every book (`BookScope` rule B-1). Narrowing to Book 1 must
      // therefore keep it, or the shared entities the Codex exists to create
      // would be the first thing a book filter hides.
      if (filter.bookId != null &&
          record.bookId != null &&
          record.bookId != filter.bookId) {
        return false;
      }
      if (filter.branchId != null && record.branchId != filter.branchId) {
        return false;
      }
    } else if (filter.scoped) {
      // A manuscript node carries no series, book or branch column, so it
      // cannot satisfy a scope narrowing. Excluding it is honest; claiming it
      // belongs to Book 1 would not be.
      return false;
    }
    return true;
  }

  /// Mirrors the four project signals `entityProjectId` accepts, so the graph
  /// and the repository agree on what "belongs to this project" means.
  bool _recordBelongsToProject(AuthorRecord record) =>
      (record.projectId ?? record.scopeId) == projectId ||
      record.scopeId == projectId ||
      record.fields['projectId'] == projectId ||
      record.fields['_codex.projectId'] == projectId;

  /// Resolves a type's category, tolerating a type the registry has never
  /// heard of.
  ///
  /// `RecordTypeRegistry.resolve` throws on an unknown id. A record written
  /// against a custom type that was later removed would otherwise take a whole
  /// graph read down with it.
  Future<String> _categoryFor(String typeId) async {
    final cached = _categoryCache[typeId];
    if (cached != null) return cached;
    final registry = await recordTypes();
    String category;
    try {
      category = registry.resolve(typeId).categoryId;
    } on StateError {
      category = 'custom';
    }
    _categoryCache[typeId] = category;
    return category;
  }

  ConnectionTypeDefinition? _definitionOrNull(
    ConnectionTypeRegistry registry,
    String typeId,
  ) {
    try {
      return registry.resolve(typeId);
    } on StateError {
      return null;
    }
  }
}
