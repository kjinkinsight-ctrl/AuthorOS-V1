/// Universal Story Graph — Phase 1 canonical read service.
///
/// This is the single entry point for universal graph reads. It is a read
/// model over persistence that already exists, and it is deliberately not:
///
/// - a database, a table, or a migration
/// - a second store, cache or index that could become authoritative
/// - a writer of records, relationships, manuscript nodes, history or audit
///
/// Everything it returns is assembled from [DriftConnectedDomainRepository],
/// the same repository RecordGraph, RecordService and ConnectionEngine
/// read. Where RecordGraph answers one-hop questions about AuthorRecords,
/// this service answers bounded multi-hop questions about *both* node kinds
/// that decision D-3 makes permanent — records, and the manuscript nodes that
/// Manuscript Studio owns.
///
/// ## Bounds are not a preference
///
/// Every traversal is bounded by depth and by a node budget, and there is no
/// way to ask for an unbounded one. AuthorOS contains wildcard relationship
/// types whose reach is unpredictable, and a large project's graph is not
/// something a caller should be able to pull into memory by accident. When a
/// bound truncates a result, the result says so — see [StoryGraphBounds].
///
/// ## Reading cost
///
/// Origin-anchored reads resolve nodes and relationships lazily, memoised for
/// the lifetime of one call, so the number of queries is bounded by the node
/// budget rather than by the size of the project. The project-wide snapshot is
/// the one read that loads in bulk, and it uses the existing bulk repository
/// methods rather than a per-node loop.
///
/// The memoisation lives and dies inside a single call. It is not a cache in
/// the architectural sense: nothing survives the call, nothing is invalidated,
/// and nothing can go stale, so it cannot become a second source of truth.
library;

import '../persistence/authoros_database.dart';
import 'record_id.dart';
import 'story_graph.dart';

export 'story_graph.dart';

/// The canonical, read-only, project-scoped Universal Story Graph.
class UniversalStoryGraphService {
  const UniversalStoryGraphService({
    required this.projectId,
    required this.repository,
  });

  /// The project every read is confined to.
  ///
  /// Project isolation is enforced here, in the service, and not by a caller
  /// filtering results afterwards. No method on this class can be asked for
  /// another project's data, and no method exposes an "entire database" read.
  final String projectId;

  final DriftConnectedDomainRepository repository;

  // ------------------------------------------------------------------ nodes

  /// Reads a single node, or `null` when this project cannot see it.
  ///
  /// `null` covers three cases deliberately without distinguishing them: the
  /// id does not exist, it belongs to another project, or it names something
  /// that is not a graph entity at all. Telling those apart would leak the
  /// existence of another project's records.
  Future<StoryGraphNode?> getNode(RecordId id) => _Reader(this).node(id);

  /// The project's totals, for callers that must show a bounded view honestly.
  ///
  /// Counted in the database rather than materialised. Soft-deleted records
  /// are excluded, matching the default lifecycle admission of
  /// [StoryGraphFilter]; a caller that deliberately admits deleted nodes will
  /// see a snapshot count that can exceed these totals.
  Future<StoryGraphTotals> getTotals() async {
    final records = await repository.countRecordsByProject(projectId);
    final manuscript =
        await repository.countManuscriptNodesByProject(projectId);
    final edges = await repository.countLinksByScope(projectId);
    return StoryGraphTotals(
      projectId: projectId,
      nodeCount: records + manuscript,
      edgeCount: edges,
    );
  }

  // ------------------------------------------------------------- neighbours

  /// The nodes one hop from [id], with the relationship that reaches each.
  ///
  /// This is strictly one hop. It performs no recursion, so a caller cannot
  /// accidentally walk the project by calling it in a loop without deciding
  /// to.
  ///
  /// [direction] describes which end of the relationship [id] sits on, not the
  /// relationship's own directed/undirected flag — the same meaning
  /// RecordGraph.related already gives it.
  ///
  /// Returns an empty list when [id] is not visible in this project.
  Future<List<StoryGraphNeighbour>> getNeighbours(
    RecordId id, {
    RelationshipDirection direction = RelationshipDirection.any,
    StoryGraphFilter filter = StoryGraphFilter.none,
  }) async {
    final reader = _Reader(this);
    final anchor = await reader.node(id);
    if (anchor == null) return const [];

    final neighbours = <StoryGraphNeighbour>[];
    for (final edge in await reader.edgesOf(id)) {
      if (!filter.admitsEdge(edge)) continue;
      if (!_matchesDirection(edge, id, direction)) continue;
      final otherId = edge.otherEndpoint(id);
      if (otherId == null) continue;
      final node = await reader.node(otherId);
      if (node == null || !filter.admitsNode(node)) continue;
      neighbours.add(
        StoryGraphNeighbour(
          node: node,
          edge: edge,
          direction: edge.sourceId == id
              ? RelationshipDirection.outgoing
              : RelationshipDirection.incoming,
        ),
      );
    }
    neighbours.sort();
    return List.unmodifiable(neighbours);
  }

  // -------------------------------------------------------------- traversal

  /// Breadth-first traversal outwards from [origin], bounded by [options].
  ///
  /// Depth semantics: `0` returns the origin alone, `1` adds its direct
  /// neighbours, `2` adds theirs. A negative depth is a programmer error and
  /// throws — it is never read as "unlimited".
  ///
  /// Cycles are safe: a visited set means each node is expanded once, so
  /// `A → B → C → A` yields three nodes and terminates.
  ///
  /// Ordering is deterministic — depth ascending, then node identity
  /// ascending — and never depends on hash iteration or query completion
  /// order.
  ///
  /// The origin is always included when it is visible, even if
  /// [StoryGraphFilter] would otherwise exclude it: the caller named it
  /// explicitly, and returning an empty result for it would be a confusing way
  /// to say "your filter excludes the thing you asked about".
  Future<StoryGraphTraversal> traverse(
    RecordId origin, {
    StoryGraphTraversalOptions options = const StoryGraphTraversalOptions(),
  }) async {
    options.validate();
    final reader = _Reader(this);
    final originNode = await reader.node(origin);
    if (originNode == null) {
      return StoryGraphTraversal.inaccessibleOrigin(
        projectId: projectId,
        origin: origin,
      );
    }

    final nodes = <RecordId, StoryGraphNode>{origin: originNode};
    final depths = <RecordId, int>{origin: 0};
    final reasons = <StoryGraphTruncationReason>{};

    var frontier = <RecordId>[origin];
    var depth = 0;
    var budgetExhausted = false;

    while (depth < options.maxDepth && frontier.isNotEmpty) {
      final next = <RecordId>[];
      for (final anchorId in frontier) {
        for (final edge in await reader.edgesOf(anchorId)) {
          if (!options.filter.admitsEdge(edge)) continue;
          if (!_matchesDirection(edge, anchorId, options.direction)) continue;
          final otherId = edge.otherEndpoint(anchorId);
          if (otherId == null || nodes.containsKey(otherId)) continue;
          final candidate = await reader.node(otherId);
          if (candidate == null) continue;
          if (!options.filter.admitsNode(candidate)) continue;
          if (nodes.length >= options.maxNodes) {
            budgetExhausted = true;
            break;
          }
          nodes[otherId] = candidate;
          depths[otherId] = depth + 1;
          next.add(otherId);
        }
        if (budgetExhausted) break;
      }
      if (budgetExhausted) break;
      next.sort();
      frontier = next;
      depth++;
    }

    if (budgetExhausted) {
      reasons.add(StoryGraphTruncationReason.nodeBudget);
    } else if (depth == options.maxDepth &&
        await _hasUnexploredEdge(reader, frontier, nodes, options)) {
      reasons.add(StoryGraphTruncationReason.depthLimit);
    }

    return StoryGraphTraversal(
      snapshot: StoryGraphSnapshot(
        projectId: projectId,
        nodes: nodes.values,
        edges: await _inducedEdges(reader, nodes.keys, options.filter),
        bounds: StoryGraphBounds(reasons: reasons),
        originId: origin,
      ),
      originId: origin,
      depths: depths,
    );
  }

  // --------------------------------------------------------------- snapshot

  /// A bounded, coherent view of the project graph.
  ///
  /// With an [origin], this is [traverse]'s snapshot. Without one it is the
  /// project's own nodes, taken in identity order up to the node budget — a
  /// bounded default, never the whole project by accident.
  Future<StoryGraphSnapshot> getSnapshot({
    RecordId? origin,
    StoryGraphTraversalOptions options = const StoryGraphTraversalOptions(),
  }) async {
    options.validate();
    if (origin != null) {
      return (await traverse(origin, options: options)).snapshot;
    }

    final candidates = <StoryGraphNode>[];
    for (final record in await repository.recordsByProject(projectId)) {
      if (!storyGraphRecordBelongsToProject(record, projectId)) continue;
      final node = StoryGraphNode.fromRecord(record, projectId: projectId);
      if (options.filter.admitsNode(node)) candidates.add(node);
    }
    for (final reference in await repository.manuscriptNodesByProject(
      projectId,
    )) {
      final node = StoryGraphNode.fromManuscriptNode(reference);
      if (options.filter.admitsNode(node)) candidates.add(node);
    }
    candidates.sort();

    final reasons = <StoryGraphTruncationReason>{};
    var included = candidates;
    if (candidates.length > options.maxNodes) {
      included = candidates.sublist(0, options.maxNodes);
      reasons.add(StoryGraphTruncationReason.nodeBudget);
    }

    final present = {for (final node in included) node.id};
    final edges = <StoryGraphEdge>[];
    for (final link in await repository.linksByScope(projectId)) {
      final edge = StoryGraphEdge.fromLink(link);
      if (!options.filter.admitsEdge(edge)) continue;
      if (!present.contains(edge.sourceId)) continue;
      if (!present.contains(edge.targetId)) continue;
      edges.add(edge);
    }

    return StoryGraphSnapshot(
      projectId: projectId,
      nodes: included,
      edges: edges,
      bounds: StoryGraphBounds(reasons: reasons),
    );
  }

  // ------------------------------------------------------------------- path

  /// The shortest path between two nodes, or a typed reason there is none.
  ///
  /// Breadth-first and unweighted, so the first route found is a shortest one.
  /// Ties are broken deterministically by node identity, then relationship
  /// identity, so the same graph always yields the same path.
  ///
  /// "No path" is an ordinary answer and is returned as
  /// [StoryGraphPathFailure], never thrown. Because the search is bounded, a
  /// failure means "not found within these bounds" — the result carries the
  /// bounds so a caller can say so accurately rather than claiming the two
  /// nodes are unrelated.
  Future<StoryGraphPathResult> findPath(
    RecordId from,
    RecordId to, {
    StoryGraphTraversalOptions options = const StoryGraphTraversalOptions(),
  }) async {
    options.validate();
    final reader = _Reader(this);

    final fromNode = await reader.node(from);
    if (fromNode == null) {
      return const StoryGraphPathResult.notFound(
        StoryGraphPathFailure.originInaccessible,
      );
    }
    final toNode = await reader.node(to);
    if (toNode == null) {
      return const StoryGraphPathResult.notFound(
        StoryGraphPathFailure.destinationInaccessible,
      );
    }
    if (from == to) {
      return StoryGraphPathResult.found(
        StoryGraphPath(nodes: [fromNode], edges: const []),
      );
    }

    final visited = <RecordId, StoryGraphNode>{from: fromNode};
    final cameFrom = <RecordId, _Step>{};
    final reasons = <StoryGraphTruncationReason>{};

    var frontier = <RecordId>[from];
    var depth = 0;
    var budgetExhausted = false;

    while (depth < options.maxDepth && frontier.isNotEmpty) {
      final next = <RecordId>[];
      for (final anchorId in frontier) {
        for (final edge in await reader.edgesOf(anchorId)) {
          if (!options.filter.admitsEdge(edge)) continue;
          if (!_matchesDirection(edge, anchorId, options.direction)) continue;
          final otherId = edge.otherEndpoint(anchorId);
          if (otherId == null || visited.containsKey(otherId)) continue;
          final candidate = await reader.node(otherId);
          if (candidate == null) continue;
          if (!options.filter.admitsNode(candidate)) continue;
          if (visited.length >= options.maxNodes) {
            budgetExhausted = true;
            break;
          }
          visited[otherId] = candidate;
          cameFrom[otherId] = _Step(anchorId, edge);
          if (otherId == to) {
            return StoryGraphPathResult.found(
              _rebuild(from, to, visited, cameFrom),
            );
          }
          next.add(otherId);
        }
        if (budgetExhausted) break;
      }
      if (budgetExhausted) break;
      next.sort();
      frontier = next;
      depth++;
    }

    if (budgetExhausted) {
      reasons.add(StoryGraphTruncationReason.nodeBudget);
    } else if (depth == options.maxDepth && frontier.isNotEmpty) {
      reasons.add(StoryGraphTruncationReason.depthLimit);
    }

    return StoryGraphPathResult.notFound(
      StoryGraphPathFailure.unreachableWithinBounds,
      bounds: StoryGraphBounds(reasons: reasons),
    );
  }

  // ---------------------------------------------------------------- helpers

  /// Every in-project relationship whose endpoints are both in [ids].
  ///
  /// This runs after the node set is settled so a snapshot is coherent: a
  /// relationship between two visible nodes is visible even when the traversal
  /// happened not to walk it. [StoryGraphTraversalOptions.direction] governs
  /// which nodes a traversal *reaches*, not which relationships exist between
  /// the nodes it reached, so it is deliberately not applied here.
  Future<List<StoryGraphEdge>> _inducedEdges(
    _Reader reader,
    Iterable<RecordId> ids,
    StoryGraphFilter filter,
  ) async {
    final present = ids.toSet();
    final collected = <RelationshipId, StoryGraphEdge>{};
    for (final id in present) {
      for (final edge in await reader.edgesOf(id)) {
        if (!filter.admitsEdge(edge)) continue;
        if (!present.contains(edge.sourceId)) continue;
        if (!present.contains(edge.targetId)) continue;
        collected[edge.id] = edge;
      }
    }
    return collected.values.toList();
  }

  /// Whether anything on the final frontier still led outwards.
  ///
  /// Deliberately conservative: it does not resolve the far endpoint, so it
  /// can report a depth limit for a neighbour that a filter would have
  /// excluded anyway. Over-reporting truncation is the safe direction — it
  /// makes a consumer say "there may be more", where under-reporting would
  /// make it claim a bounded view was the whole answer.
  Future<bool> _hasUnexploredEdge(
    _Reader reader,
    List<RecordId> frontier,
    Map<RecordId, StoryGraphNode> nodes,
    StoryGraphTraversalOptions options,
  ) async {
    for (final anchorId in frontier) {
      for (final edge in await reader.edgesOf(anchorId)) {
        if (!options.filter.admitsEdge(edge)) continue;
        if (!_matchesDirection(edge, anchorId, options.direction)) continue;
        final otherId = edge.otherEndpoint(anchorId);
        if (otherId == null || nodes.containsKey(otherId)) continue;
        return true;
      }
    }
    return false;
  }

  StoryGraphPath _rebuild(
    RecordId from,
    RecordId to,
    Map<RecordId, StoryGraphNode> visited,
    Map<RecordId, _Step> cameFrom,
  ) {
    final nodes = <StoryGraphNode>[];
    final edges = <StoryGraphEdge>[];
    var cursor = to;
    while (cursor != from) {
      final step = cameFrom[cursor]!;
      nodes.insert(0, visited[cursor]!);
      edges.insert(0, step.edge);
      cursor = step.from;
    }
    nodes.insert(0, visited[from]!);
    return StoryGraphPath(nodes: nodes, edges: edges);
  }
}

bool _matchesDirection(
  StoryGraphEdge edge,
  RecordId anchor,
  RelationshipDirection direction,
) =>
    switch (direction) {
      RelationshipDirection.outgoing => edge.sourceId == anchor,
      RelationshipDirection.incoming => edge.targetId == anchor,
      RelationshipDirection.any =>
        edge.sourceId == anchor || edge.targetId == anchor,
    };

/// One hop of a reconstructed path.
class _Step {
  const _Step(this.from, this.edge);

  final RecordId from;
  final StoryGraphEdge edge;
}

/// Per-call node and relationship resolution.
///
/// Memoised for the lifetime of one service call and discarded with it. It
/// keeps a bounded traversal from re-reading the same node once per edge that
/// points at it, without becoming a cache that could serve stale data: it
/// never outlives the call that created it.
class _Reader {
  _Reader(this._service);

  final UniversalStoryGraphService _service;
  final Map<RecordId, StoryGraphNode?> _nodes = {};
  final Map<RecordId, List<StoryGraphEdge>> _edges = {};

  /// Resolves [id] against both node kinds, in the order the rest of the
  /// persistence layer already uses: records first, then manuscript nodes.
  ///
  /// Returns `null` for anything this project cannot see. A writing session,
  /// an audit event or a version row can never resolve here — none of them is
  /// an entity in `connected_entities`, so none of them can be a node.
  Future<StoryGraphNode?> node(RecordId id) async {
    if (_nodes.containsKey(id)) return _nodes[id];

    final record = await _service.repository.recordById(id.value);
    if (record != null) {
      final visible =
          storyGraphRecordBelongsToProject(record, _service.projectId);
      return _nodes[id] = visible
          ? StoryGraphNode.fromRecord(record, projectId: _service.projectId)
          : null;
    }

    final reference = await _service.repository.manuscriptNodeById(id.value);
    if (reference != null && reference.projectId == _service.projectId) {
      return _nodes[id] = StoryGraphNode.fromManuscriptNode(reference);
    }
    return _nodes[id] = null;
  }

  /// Every in-project relationship touching [id], in identity order.
  ///
  /// Relationships outside this project's scope are dropped here, so no
  /// traversal can step across a project boundary even when a foreign
  /// relationship names an in-project endpoint.
  Future<List<StoryGraphEdge>> edgesOf(RecordId id) async {
    final cached = _edges[id];
    if (cached != null) return cached;

    final links = await _service.repository.backlinks(id.value);
    final edges = <StoryGraphEdge>[
      for (final link in links)
        if (link.scopeId == _service.projectId) StoryGraphEdge.fromLink(link),
    ]..sort();
    return _edges[id] = List.unmodifiable(edges);
  }
}
