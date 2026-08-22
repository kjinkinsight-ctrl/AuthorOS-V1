/// Universal Story Graph — Phase 1 read model.
///
/// This library is the domain vocabulary Phase 2 (and any later graph
/// consumer) speaks. It owns no storage and no rules of its own.
///
/// AuthorOS keeps story knowledge in two persistence shapes, and decision
/// **D-3** makes that permanent: most entities are [AuthorRecord]s, while
/// scenes and chapters are [ManuscriptNodeReference]s owned by Manuscript
/// Studio. Both are rows in `connected_entities`, so both can already be
/// endpoints of a [RecordLink]. What did not exist before this milestone was
/// a single read model that presents them as one graph.
///
/// [StoryGraphNode] is that model. A consumer reads a node's [kind] when it
/// needs to know where the node came from — to route navigation, or to render
/// a manuscript node distinctly — and otherwise never needs to care.
///
/// Everything here is immutable. A returned graph object can be handed to a
/// canvas, a panel or a future analytics consumer without any risk that
/// mutating it writes back to canonical state, because nothing here can be
/// mutated and nothing here can write.
library;

import 'connected_domain.dart';
import 'record_graph.dart';
import 'record_id.dart';

export 'record_graph.dart' show RelationshipDirection;

/// Which persistence system a node came from.
///
/// This exists because of D-3, not in spite of it. A manuscript node must
/// never pretend to be an [AuthorRecord]: Manuscript Studio owns its prose,
/// its ordering and its lifecycle, and the graph is a reader of that, not an
/// owner of it.
enum StoryGraphNodeKind {
  /// Backed by an [AuthorRecord] — characters, locations, plot, timeline,
  /// research, map entities, and every other Universal Record.
  record,

  /// Backed by a [ManuscriptNodeReference] — scenes and chapters.
  manuscript,
}

/// A node's lifecycle state, as its owning domain defines it.
///
/// Records carry a real [AuthorRecordStatus]. Manuscript nodes have no
/// lifecycle column at all — a scene node exists while Manuscript Studio
/// projects it and is gone when it does not — so they resolve to
/// [StoryGraphNodeLifecycle.active] and never to anything else. The graph does
/// not invent a second deletion system to paper over that difference.
enum StoryGraphNodeLifecycle { active, archived, deleted }

/// A single node in the story graph.
///
/// Identity is [RecordId] — the same typed wrapper the rest of AuthorOS uses
/// for `connected_entities.id`, so a node id can be handed back to the
/// existing repositories unchanged. This is deliberately not a new identity
/// system.
class StoryGraphNode implements Comparable<StoryGraphNode> {
  StoryGraphNode({
    required this.id,
    required this.kind,
    required this.projectId,
    required this.label,
    required this.typeId,
    this.lifecycle = StoryGraphNodeLifecycle.active,
    this.canonStatus,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  /// Projects an [AuthorRecord] into a graph node.
  ///
  /// [projectId] is passed in rather than read off the record because record
  /// project membership is a disjunction across several fields — see
  /// [storyGraphRecordBelongsToProject] — and the caller has already resolved
  /// which project it is reading.
  factory StoryGraphNode.fromRecord(
    AuthorRecord record, {
    required String projectId,
  }) =>
      StoryGraphNode(
        id: RecordId.parse(record.id),
        kind: StoryGraphNodeKind.record,
        projectId: projectId,
        label: record.title,
        typeId: record.typeId,
        lifecycle: switch (record.status) {
          AuthorRecordStatus.active => StoryGraphNodeLifecycle.active,
          AuthorRecordStatus.archived => StoryGraphNodeLifecycle.archived,
          AuthorRecordStatus.deleted => StoryGraphNodeLifecycle.deleted,
        },
        canonStatus: record.canonStatus,
        metadata: {
          'tags': List<String>.unmodifiable(record.tags),
          'updatedAt': record.updatedAt.toUtc().toIso8601String(),
        },
      );

  /// Projects a [ManuscriptNodeReference] into a graph node.
  ///
  /// The scene or chapter's prose is deliberately absent. A manuscript node
  /// says *this scene participates in the story structure*; it says nothing
  /// about whether the scene has been written. See §19 of the Phase 1
  /// directive and `no-prose-assumption` in the Phase 1 documentation.
  factory StoryGraphNode.fromManuscriptNode(ManuscriptNodeReference node) =>
      StoryGraphNode(
        id: RecordId.parse(node.id),
        kind: StoryGraphNodeKind.manuscript,
        projectId: node.projectId,
        label: node.title,
        typeId: node.nodeType,
        // Manuscript nodes have no lifecycle column. Presence is the state.
        metadata: {
          'updatedAt': node.updatedAt.toUtc().toIso8601String(),
          // The manuscript's own drafting status ('draft', 'final', …). This
          // is a writing state, NOT a graph lifecycle state, and the two are
          // deliberately kept apart.
          if (node.extensionData['status'] != null)
            'manuscriptStatus': node.extensionData['status'],
          if (node.extensionData['order'] != null)
            'order': node.extensionData['order'],
          if (node.extensionData['chapterId'] != null)
            'chapterId': node.extensionData['chapterId'],
        },
      );

  final RecordId id;
  final StoryGraphNodeKind kind;
  final String projectId;

  /// The node's display label. Never an identity — two nodes may share one.
  final String label;

  /// The owning domain's type id: a record type id for [kind] `record`, and
  /// `'scene'` or `'chapter'` for [kind] `manuscript`.
  final String typeId;

  final StoryGraphNodeLifecycle lifecycle;

  /// Canon state where the source domain provides it. Always `null` for
  /// manuscript nodes, which have no canon concept.
  final CanonStatus? canonStatus;

  /// Display and filtering hints. Read-only; never a place to stash state.
  final Map<String, Object?> metadata;

  @override
  int compareTo(StoryGraphNode other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      other is StoryGraphNode &&
      other.id == id &&
      other.kind == kind &&
      other.projectId == projectId &&
      other.label == label &&
      other.typeId == typeId &&
      other.lifecycle == lifecycle &&
      other.canonStatus == canonStatus;

  @override
  int get hashCode =>
      Object.hash(id, kind, projectId, label, typeId, lifecycle, canonStatus);

  @override
  String toString() => 'StoryGraphNode(${id.value}, ${kind.name}, $typeId)';
}

/// A single relationship in the story graph.
///
/// This is a read-model projection of an existing [RecordLink]. It is not a
/// second edge model: nothing here is persisted, and there is no way to write
/// an edge through this type.
class StoryGraphEdge implements Comparable<StoryGraphEdge> {
  StoryGraphEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.typeId,
    required this.projectId,
    this.label = '',
    this.direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  factory StoryGraphEdge.fromLink(RecordLink link) => StoryGraphEdge(
        id: RelationshipId.parse(link.id),
        sourceId: RecordId.parse(link.sourceId),
        targetId: RecordId.parse(link.targetId),
        typeId: link.typeId,
        projectId: link.scopeId,
        label: link.label,
        direction: link.direction,
        metadata: {'updatedAt': link.updatedAt.toUtc().toIso8601String()},
      );

  final RelationshipId id;
  final RecordId sourceId;
  final RecordId targetId;

  /// The canonical connection type id, exactly as persisted.
  ///
  /// Wildcard relationship types are reported as they are. Phase 1 does not
  /// normalise, re-type, or invent a friendlier label for them.
  final String typeId;

  final String projectId;
  final String label;
  final RecordLinkDirection direction;
  final Map<String, Object?> metadata;

  /// The endpoint opposite [nodeId], or `null` when [nodeId] is not an
  /// endpoint of this edge.
  RecordId? otherEndpoint(RecordId nodeId) {
    if (sourceId == nodeId) return targetId;
    if (targetId == nodeId) return sourceId;
    return null;
  }

  @override
  int compareTo(StoryGraphEdge other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      other is StoryGraphEdge &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.targetId == targetId &&
      other.typeId == typeId &&
      other.projectId == projectId &&
      other.direction == direction;

  @override
  int get hashCode =>
      Object.hash(id, sourceId, targetId, typeId, projectId, direction);

  @override
  String toString() =>
      'StoryGraphEdge(${sourceId.value} -$typeId-> ${targetId.value})';
}

/// A domain query filter. Not a UI filter model.
///
/// Every set is an inclusive filter and an empty set means "any", matching the
/// convention [RecordGraph.related] already established.
class StoryGraphFilter {
  const StoryGraphFilter({
    this.nodeKinds = const {},
    this.recordTypeIds = const {},
    this.relationshipTypeIds = const {},
    this.lifecycles = const {
      StoryGraphNodeLifecycle.active,
      StoryGraphNodeLifecycle.archived,
    },
    this.canonStatuses = const {},
  });

  /// Matches everything the default lifecycle rule admits.
  static const StoryGraphFilter none = StoryGraphFilter();

  final Set<StoryGraphNodeKind> nodeKinds;

  /// Matches [StoryGraphNode.typeId] — record type ids for record nodes,
  /// `'scene'` / `'chapter'` for manuscript nodes.
  final Set<String> recordTypeIds;

  final Set<String> relationshipTypeIds;

  /// Which lifecycle states are admitted. Defaults to active and archived,
  /// so soft-deleted records stay out of the graph unless asked for — the
  /// same default [RecordGraph.related] uses.
  final Set<StoryGraphNodeLifecycle> lifecycles;

  /// Canon states admitted. An empty set means "any", and a node whose domain
  /// has no canon concept (every manuscript node) is admitted by an empty set
  /// and excluded by a non-empty one.
  final Set<CanonStatus> canonStatuses;

  bool admitsNode(StoryGraphNode node) {
    if (nodeKinds.isNotEmpty && !nodeKinds.contains(node.kind)) return false;
    if (recordTypeIds.isNotEmpty && !recordTypeIds.contains(node.typeId)) {
      return false;
    }
    if (!lifecycles.contains(node.lifecycle)) return false;
    if (canonStatuses.isNotEmpty) {
      final canon = node.canonStatus;
      if (canon == null || !canonStatuses.contains(canon)) return false;
    }
    return true;
  }

  bool admitsEdge(StoryGraphEdge edge) =>
      relationshipTypeIds.isEmpty || relationshipTypeIds.contains(edge.typeId);

  bool get isUnfiltered =>
      nodeKinds.isEmpty &&
      recordTypeIds.isEmpty &&
      relationshipTypeIds.isEmpty &&
      canonStatuses.isEmpty;
}

/// Why a bounded read returned less than the whole answer.
enum StoryGraphTruncationReason {
  /// The traversal reached [StoryGraphTraversalOptions.maxDepth] while
  /// relationships leading further out remained unexplored.
  depthLimit,

  /// The read reached [StoryGraphTraversalOptions.maxNodes].
  nodeBudget,
}

/// Whether a bounded read is the complete answer, and if not, why not.
///
/// This is first-class information, never an omission. A consumer that renders
/// a truncated subgraph as though it were the whole graph tells the author
/// "these things are not connected" when the truth is "not within this bound".
class StoryGraphBounds {
  StoryGraphBounds({Set<StoryGraphTruncationReason> reasons = const {}})
      : reasons = Set.unmodifiable(reasons);

  static final StoryGraphBounds complete = StoryGraphBounds();

  final Set<StoryGraphTruncationReason> reasons;

  bool get isComplete => reasons.isEmpty;

  bool get isTruncated => reasons.isNotEmpty;

  bool get truncatedByDepth =>
      reasons.contains(StoryGraphTruncationReason.depthLimit);

  bool get truncatedByNodeBudget =>
      reasons.contains(StoryGraphTruncationReason.nodeBudget);

  @override
  String toString() => isComplete
      ? 'StoryGraphBounds(complete)'
      : 'StoryGraphBounds(truncated: '
          '${reasons.map((reason) => reason.name).join(', ')})';
}

/// The bounds and filters a graph read is performed under.
///
/// There is no "unlimited" value. Every read is bounded, because the bounds
/// are an architectural safety mechanism and not a display preference: a dense
/// wildcard relationship set, a large project, or a future shared world must
/// not be able to pull an unbounded graph into memory.
class StoryGraphTraversalOptions {
  const StoryGraphTraversalOptions({
    this.maxDepth = defaultMaxDepth,
    this.maxNodes = defaultMaxNodes,
    this.direction = RelationshipDirection.any,
    this.filter = StoryGraphFilter.none,
  });

  static const int defaultMaxDepth = 2;
  static const int defaultMaxNodes = 250;

  /// Hops from the origin. `0` is the origin alone, `1` adds its direct
  /// neighbours, `2` adds theirs, and so on.
  ///
  /// Negative depth is invalid and is never a synonym for "unlimited".
  final int maxDepth;

  /// The most nodes a read may return, origin included.
  final int maxNodes;

  final RelationshipDirection direction;
  final StoryGraphFilter filter;

  StoryGraphTraversalOptions copyWith({
    int? maxDepth,
    int? maxNodes,
    RelationshipDirection? direction,
    StoryGraphFilter? filter,
  }) =>
      StoryGraphTraversalOptions(
        maxDepth: maxDepth ?? this.maxDepth,
        maxNodes: maxNodes ?? this.maxNodes,
        direction: direction ?? this.direction,
        filter: filter ?? this.filter,
      );

  /// Throws [ArgumentError] on programmer error. Invalid bounds are a caller
  /// bug, unlike "no path exists", which is an ordinary graph answer.
  void validate() {
    if (maxDepth < 0) {
      throw ArgumentError.value(
        maxDepth,
        'maxDepth',
        'Traversal depth must not be negative. Negative depth is not a '
            'synonym for unlimited depth; the Story Graph has no unlimited '
            'traversal.',
      );
    }
    if (maxNodes < 1) {
      throw ArgumentError.value(
        maxNodes,
        'maxNodes',
        'A traversal must be allowed at least one node.',
      );
    }
  }
}

/// A bounded, immutable, internally coherent view of one project's graph.
///
/// Coherence is enforced at construction: every edge's endpoints are present
/// in [nodes]. A consumer can therefore render every edge it is handed without
/// checking first, and a filter can never produce a dangling edge.
class StoryGraphSnapshot {
  StoryGraphSnapshot({
    required this.projectId,
    required Iterable<StoryGraphNode> nodes,
    required Iterable<StoryGraphEdge> edges,
    StoryGraphBounds? bounds,
    this.originId,
  })  : nodes = List.unmodifiable(nodes.toList()..sort()),
        edges = List.unmodifiable(
          _coherentEdges(nodes, edges)..sort(),
        ),
        bounds = bounds ?? StoryGraphBounds.complete;

  StoryGraphSnapshot.empty(this.projectId, {this.originId})
      : nodes = const <StoryGraphNode>[],
        edges = const <StoryGraphEdge>[],
        bounds = StoryGraphBounds.complete;

  final String projectId;

  /// Ordered by node identity ascending. Deterministic across runs.
  final List<StoryGraphNode> nodes;

  /// Ordered by edge identity ascending. Every endpoint is present in [nodes].
  final List<StoryGraphEdge> edges;

  final StoryGraphBounds bounds;

  /// The node this snapshot was built outwards from, when there was one.
  final RecordId? originId;

  bool get isEmpty => nodes.isEmpty;

  int get nodeCount => nodes.length;

  int get edgeCount => edges.length;

  StoryGraphNode? nodeById(RecordId id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  bool contains(RecordId id) => nodeById(id) != null;

  static List<StoryGraphEdge> _coherentEdges(
    Iterable<StoryGraphNode> nodes,
    Iterable<StoryGraphEdge> edges,
  ) {
    final present = {for (final node in nodes) node.id};
    return [
      for (final edge in edges)
        if (present.contains(edge.sourceId) && present.contains(edge.targetId))
          edge,
    ];
  }
}

/// One hop away from an anchor node, with the relationship that got there.
///
/// Mirrors the shape of [RelatedRecord], which Studios already consume, so a
/// caller moving from `RecordGraph.related` to the Story Graph is not learning
/// a new idea — only a heterogeneous one.
class StoryGraphNeighbour implements Comparable<StoryGraphNeighbour> {
  const StoryGraphNeighbour({
    required this.node,
    required this.edge,
    required this.direction,
  });

  final StoryGraphNode node;
  final StoryGraphEdge edge;

  /// [RelationshipDirection.outgoing] when the anchor is the edge's source.
  final RelationshipDirection direction;

  @override
  int compareTo(StoryGraphNeighbour other) {
    final byNode = node.compareTo(other.node);
    return byNode != 0 ? byNode : edge.compareTo(other.edge);
  }
}

/// A traversal result: a bounded snapshot plus the depth each node sits at.
class StoryGraphTraversal {
  StoryGraphTraversal({
    required this.snapshot,
    required this.originId,
    required Map<RecordId, int> depths,
    this.originFound = true,
  }) : depths = Map.unmodifiable(depths);

  /// The origin could not be read in this project — it does not exist, or it
  /// belongs to another project. Either way the result is empty and says
  /// nothing about whether the id exists elsewhere.
  StoryGraphTraversal.inaccessibleOrigin({
    required String projectId,
    required RecordId origin,
  })  : originId = origin,
        snapshot = StoryGraphSnapshot.empty(projectId, originId: origin),
        depths = const <RecordId, int>{},
        originFound = false;

  final StoryGraphSnapshot snapshot;
  final RecordId originId;

  /// Hop count from the origin, keyed by node id. The origin itself is `0`.
  final Map<RecordId, int> depths;

  final bool originFound;

  StoryGraphBounds get bounds => snapshot.bounds;

  List<StoryGraphNode> get nodes => snapshot.nodes;

  List<StoryGraphEdge> get edges => snapshot.edges;

  int? depthOf(RecordId id) => depths[id];

  /// Nodes at exactly [depth], in identity order.
  List<StoryGraphNode> atDepth(int depth) =>
      [for (final node in snapshot.nodes) if (depths[node.id] == depth) node];
}

/// A path through the graph.
///
/// The invariant `nodes.length == edges.length + 1` is enforced here so an
/// invalid path cannot be constructed and handed to a consumer.
class StoryGraphPath {
  StoryGraphPath({
    required Iterable<StoryGraphNode> nodes,
    required Iterable<StoryGraphEdge> edges,
  })  : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges) {
    if (this.nodes.isEmpty) {
      throw ArgumentError.value(
        nodes,
        'nodes',
        'A path contains at least its origin node.',
      );
    }
    if (this.nodes.length != this.edges.length + 1) {
      throw ArgumentError(
        'A path must have exactly one more node than it has edges: got '
        '${this.nodes.length} nodes and ${this.edges.length} edges.',
      );
    }
    for (var index = 0; index < this.edges.length; index++) {
      final edge = this.edges[index];
      final from = this.nodes[index].id;
      final to = this.nodes[index + 1].id;
      final connects = (edge.sourceId == from && edge.targetId == to) ||
          (edge.sourceId == to && edge.targetId == from);
      if (!connects) {
        throw ArgumentError(
          'Path edge ${edge.id.value} does not join ${from.value} to '
          '${to.value}.',
        );
      }
    }
  }

  final List<StoryGraphNode> nodes;
  final List<StoryGraphEdge> edges;

  /// Hops between the endpoints. A path from a node to itself has length `0`.
  int get length => edges.length;

  StoryGraphNode get origin => nodes.first;

  StoryGraphNode get destination => nodes.last;
}

/// Why a path search returned no path.
///
/// "No path exists" is an ordinary graph answer, not an error, so it is a
/// value rather than an exception.
enum StoryGraphPathFailure {
  /// The start node could not be read in this project.
  originInaccessible,

  /// The destination node could not be read in this project.
  destinationInaccessible,

  /// Both endpoints are readable, but no route joins them within the search
  /// bounds. The two may still be unconnected entirely — the bounded search
  /// deliberately does not distinguish those cases, because doing so would
  /// require an unbounded traversal.
  unreachableWithinBounds,
}

/// The result of a path search: a path, or a typed reason there was none.
class StoryGraphPathResult {
  const StoryGraphPathResult.found(StoryGraphPath this.path)
      : failure = null,
        searchBounds = null;

  const StoryGraphPathResult.notFound(
    StoryGraphPathFailure this.failure, {
    StoryGraphBounds? bounds,
  })  : path = null,
        searchBounds = bounds;

  final StoryGraphPath? path;
  final StoryGraphPathFailure? failure;

  /// How the search itself was bounded when it failed. When this reports
  /// truncation, "no path" means "none found within the bound".
  final StoryGraphBounds? searchBounds;

  bool get isFound => path != null;
}

/// The project's totals, for consumers that must show a bounded view honestly.
///
/// Phase 2 renders "48 of 512". These are the counts that make the second
/// number true.
class StoryGraphTotals {
  const StoryGraphTotals({
    required this.projectId,
    required this.nodeCount,
    required this.edgeCount,
  });

  final String projectId;
  final int nodeCount;
  final int edgeCount;
}

/// Whether [record] is a member of [projectId].
///
/// Record project membership is a disjunction across several fields because
/// different Studios populate different ones. This mirrors the rule
/// [RecordGraph] already applies, deliberately and exactly: the Story Graph
/// must not disagree with the read surface it sits beside about which records
/// belong to a project.
bool storyGraphRecordBelongsToProject(AuthorRecord record, String projectId) =>
    (record.projectId ?? record.scopeId) == projectId ||
    record.scopeId == projectId ||
    record.fields['projectId'] == projectId ||
    record.fields['_codex.projectId'] == projectId;
