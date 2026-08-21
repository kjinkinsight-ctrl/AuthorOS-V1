/// Model types for the Universal Story Graph read layer.
///
/// The graph owns no storage (invariant I-15). Everything here is a projection
/// of `author_record_rows`, `manuscript_node_rows` and `record_link_rows`, held
/// only for as long as a view is rendering it.
///
/// Two node kinds are a permanent architectural reality under decision D-3:
/// characters, locations, plot and the rest are [AuthorRecord]s, while scenes
/// and chapters are [ManuscriptNodeReference]s. [StoryGraphNode] renders both
/// through one type, and carries capability flags so no caller can assume they
/// behave alike.
library;

import 'connected_domain.dart';
import 'connection_types.dart';
import 'record_scope.dart';

/// Which table a node came from.
enum StoryGraphNodeKind { record, manuscriptNode }

/// The groups the Connection Explorer presents neighbours in.
///
/// Buckets are derived from `RecordTypeDefinition.categoryId` rather than from
/// a hardcoded list of type ids, so the ~224 built-in types and any
/// project-defined type land somewhere sensible without this file knowing about
/// them individually.
enum StoryGraphBucket {
  characters,
  locations,
  events,
  plotlines,
  chapters,
  research,
  maps,
  notes,
  worldbuilding,
  other,
}

extension StoryGraphBucketLabel on StoryGraphBucket {
  String get label => switch (this) {
        StoryGraphBucket.characters => 'Characters',
        StoryGraphBucket.locations => 'Locations',
        StoryGraphBucket.events => 'Events',
        StoryGraphBucket.plotlines => 'Plotlines',
        StoryGraphBucket.chapters => 'Chapters',
        StoryGraphBucket.research => 'Research',
        StoryGraphBucket.maps => 'Maps',
        StoryGraphBucket.notes => 'Notes',
        StoryGraphBucket.worldbuilding => 'Worldbuilding',
        StoryGraphBucket.other => 'Other',
      };
}

/// Maps a record category onto the bucket the explorer shows it under.
///
/// Anything unrecognised falls to [StoryGraphBucket.other] rather than being
/// dropped: a project-defined category is still a real part of the author's
/// story and must not vanish from the graph because this map has not heard of
/// it.
StoryGraphBucket bucketForCategory(String categoryId) => switch (categoryId) {
      'characters' => StoryGraphBucket.characters,
      'locations' || 'places' || 'world' || 'routes' =>
        StoryGraphBucket.locations,
      'timeline' || 'history' => StoryGraphBucket.events,
      'plot' => StoryGraphBucket.plotlines,
      'manuscript' => StoryGraphBucket.chapters,
      'research' => StoryGraphBucket.research,
      'maps' => StoryGraphBucket.maps,
      'reference' => StoryGraphBucket.notes,
      'lore' ||
      'magic' ||
      'culture' ||
      'religion' ||
      'factions' ||
      'items' ||
      'creatures' ||
      'technology' ||
      'custom' =>
        StoryGraphBucket.worldbuilding,
      _ => StoryGraphBucket.other,
    };

/// One graph node, of either kind.
class StoryGraphNode {
  const StoryGraphNode({
    required this.id,
    required this.kind,
    required this.typeId,
    required this.categoryId,
    required this.title,
    required this.projectId,
    required this.versioned,
    required this.deletable,
    this.canonStatus,
    this.lifecycleStatus,
    this.record,
    this.manuscriptNode,
  });

  /// Projects an [AuthorRecord]. [categoryId] comes from the resolved type
  /// definition, so an inherited category is honoured.
  factory StoryGraphNode.fromRecord(
    AuthorRecord record, {
    required String categoryId,
  }) =>
      StoryGraphNode(
        id: record.id,
        kind: StoryGraphNodeKind.record,
        typeId: record.typeId,
        categoryId: categoryId,
        title: record.title,
        projectId: record.projectId ?? record.scopeId,
        versioned: true,
        deletable: true,
        canonStatus: record.canonStatus,
        lifecycleStatus: record.status,
        record: record,
      );

  /// Projects a manuscript node.
  ///
  /// [versioned] is false because `manuscript_node_rows` carries no version or
  /// audit trail, and [canonStatus]/[lifecycleStatus] are null because the row
  /// has no such columns — a view must render the absence, not invent a value.
  /// [deletable] is true: Story Graph Phase 0 made the projection reconciling
  /// and node removal link-safe, so a retired scene no longer leaves a ghost.
  factory StoryGraphNode.fromManuscriptNode(ManuscriptNodeReference node) =>
      StoryGraphNode(
        id: node.id,
        kind: StoryGraphNodeKind.manuscriptNode,
        typeId: node.nodeType,
        categoryId: 'manuscript',
        title: node.title,
        projectId: node.projectId,
        versioned: false,
        deletable: true,
        manuscriptNode: node,
      );

  final String id;
  final StoryGraphNodeKind kind;

  /// `character`, `location`, `scene`, `chapter`, … For a manuscript node this
  /// is `ManuscriptNodeReference.nodeType`.
  final String typeId;

  /// Resolved record category; `manuscript` for manuscript nodes.
  final String categoryId;
  final String title;
  final String projectId;

  /// False for manuscript nodes: they have no version or audit history.
  final bool versioned;

  /// Whether the owning Studio can remove this node.
  final bool deletable;

  /// Null for manuscript nodes, which have no canon column.
  final CanonStatus? canonStatus;

  /// Null for manuscript nodes, which have no lifecycle column.
  final AuthorRecordStatus? lifecycleStatus;

  final AuthorRecord? record;
  final ManuscriptNodeReference? manuscriptNode;

  StoryGraphBucket get bucket => bucketForCategory(categoryId);

  /// Whether a Studio can open a full inspector for this node.
  ///
  /// `UniversalRecordInspector` resolves records only, so a manuscript node's
  /// detail lives in Manuscript Studio instead.
  bool get inspectable => kind == StoryGraphNodeKind.record;
}

/// One persisted relationship.
///
/// Always backed by a real [RecordLink]. There is no other edge kind in the
/// graph — invariant I-13, one edge table, ever.
class StoryGraphEdge {
  const StoryGraphEdge({
    required this.link,
    required this.inverseLabel,
    required this.wildcard,
  });

  final RecordLink link;

  /// The type's reverse-direction label, for rendering an incoming edge.
  final String inverseLabel;

  /// True when the connection type permits `*` -> `*`.
  ///
  /// 73 of ~130 built-in types do. They are real edges, but they carry no type
  /// discipline, so a view should be able to dim or hide them rather than
  /// present them as though they meant as much as a typed edge.
  final bool wildcard;

  String get id => link.id;
  String get sourceId => link.sourceId;
  String get targetId => link.targetId;
  String get typeId => link.typeId;
  bool get undirected => link.direction == RecordLinkDirection.undirected;

  /// The endpoint that is not [nodeId].
  String otherEnd(String nodeId) => sourceId == nodeId ? targetId : sourceId;
}

/// A relationship the graph computed rather than read.
///
/// Deliberately has **no id**: a derived edge cannot be persisted by accident
/// because there is nothing to persist it under. It is returned by a different
/// method from [StoryGraphEdge] and must never be merged into the same
/// collection — the rule from the architecture's §7.3, made structural.
class DerivedStoryGraphEdge {
  const DerivedStoryGraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.derivation,
    required this.confidence,
    this.promotable = false,
    this.label = '',
  });

  final String sourceId;
  final String targetId;

  /// How this edge was inferred, stamped onto any link an author later
  /// promotes it into.
  final String derivation;

  /// 0..1. Derived edges are suggestions, not facts.
  final double confidence;

  /// Whether an author may turn this into a real link.
  final bool promotable;
  final String label;
}

/// Which way an edge runs relative to the node being asked about.
enum StoryGraphDirection { incoming, outgoing, any }

/// One node and everything one hop away from it.
class StoryGraphNeighbourhood {
  const StoryGraphNeighbourhood({
    required this.centre,
    required this.edges,
    required this.neighbours,
    required this.buckets,
    required this.truncated,
    this.derivedEdges = const [],
  });

  final StoryGraphNode centre;
  final List<StoryGraphEdge> edges;
  final List<StoryGraphNode> neighbours;

  /// [neighbours] grouped for the Connection Explorer. Empty buckets are
  /// omitted.
  final Map<StoryGraphBucket, List<StoryGraphNode>> buckets;

  /// True when a node cap stopped the read short. Never silent — a view must
  /// say so.
  final bool truncated;

  /// Kept separate from [edges] by construction, never merged.
  final List<DerivedStoryGraphEdge> derivedEdges;

  int get neighbourCount => neighbours.length;
}

/// A bounded region of the graph.
class StorySubgraph {
  const StorySubgraph({
    required this.nodes,
    required this.edges,
    required this.depthReached,
    required this.truncated,
    this.rootId,
    this.derivedEdges = const [],
  });

  static const StorySubgraph empty = StorySubgraph(
    nodes: [],
    edges: [],
    depthReached: 0,
    truncated: false,
  );

  final List<StoryGraphNode> nodes;
  final List<StoryGraphEdge> edges;

  /// How far the walk actually got, which may be less than the depth asked for
  /// if the region ran out or the node cap hit first.
  final int depthReached;
  final bool truncated;
  final String? rootId;
  final List<DerivedStoryGraphEdge> derivedEdges;

  bool get isEmpty => nodes.isEmpty;

  StoryGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}

/// One route between two nodes.
class StoryGraphPath {
  const StoryGraphPath({required this.nodes, required this.edges});

  /// Ordered from the start node to the end node.
  final List<StoryGraphNode> nodes;

  /// `edges[i]` joins `nodes[i]` to `nodes[i + 1]`.
  final List<StoryGraphEdge> edges;

  int get length => edges.length;
}

/// The answer to "show me everything connected to this".
class ConnectionSummary {
  const ConnectionSummary({required this.node, required this.counts});

  final StoryGraphNode node;

  /// Neighbour count per bucket. Empty buckets are omitted.
  final Map<StoryGraphBucket, int> counts;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  int countFor(StoryGraphBucket bucket) => counts[bucket] ?? 0;

  /// Buckets that actually have neighbours, in enum order.
  List<StoryGraphBucket> get populated => [
        for (final bucket in StoryGraphBucket.values)
          if ((counts[bucket] ?? 0) > 0) bucket,
      ];
}

/// What a graph read is allowed to return.
///
/// Immutable, with `toggle` methods, so a filter rail can stay stateless and
/// raise a whole new filter rather than mutating shared state — the same shape
/// Story Codex's rail already uses.
class StoryGraphFilter {
  const StoryGraphFilter({
    this.categoryIds = const {},
    this.edgeTypeIds = const {},
    this.canonStatuses = const {},
    this.seriesId,
    this.bookId,
    this.branchId,
    this.includeArchived = false,
    this.includeDeleted = false,
    this.includeRelatedTo = false,
    this.includeWildcardEdges = false,
  });

  static const StoryGraphFilter unfiltered = StoryGraphFilter();

  /// Inclusive. Empty means every category.
  final Set<String> categoryIds;

  /// Inclusive. Empty means every edge type, subject to the wildcard and
  /// `relatedTo` switches below.
  final Set<String> edgeTypeIds;

  /// Inclusive. Empty means every canon status.
  final Set<CanonStatus> canonStatuses;

  /// Scope narrowing — "show Kali's relationships across Book 1 only".
  final String? seriesId;
  final String? bookId;
  final String? branchId;

  /// Archived and soft-deleted nodes stay in the edge table, so they are
  /// hidden by default and revealable rather than pretended away.
  final bool includeArchived;
  final bool includeDeleted;

  /// `relatedTo` is an undirected wildcard suggested on every record type. Left
  /// on, it dominates any view it appears in, so it is opt-in.
  final bool includeRelatedTo;

  /// The other `*` -> `*` types. Meaningful names, no type discipline.
  final bool includeWildcardEdges;

  bool get scoped => seriesId != null || bookId != null || branchId != null;

  /// True when this filter hides something, so a view can say what.
  bool get hidesAnything =>
      !includeArchived ||
      !includeDeleted ||
      !includeRelatedTo ||
      !includeWildcardEdges ||
      categoryIds.isNotEmpty ||
      edgeTypeIds.isNotEmpty ||
      canonStatuses.isNotEmpty ||
      scoped;

  bool allowsCategory(String categoryId) =>
      categoryIds.isEmpty || categoryIds.contains(categoryId);

  bool allowsCanon(CanonStatus? status) =>
      canonStatuses.isEmpty || status == null || canonStatuses.contains(status);

  bool allowsStatus(AuthorRecordStatus? status) => switch (status) {
        null => true,
        AuthorRecordStatus.active => true,
        AuthorRecordStatus.archived => includeArchived,
        AuthorRecordStatus.deleted => includeDeleted,
      };

  /// Whether an edge of [typeId] may appear, given its type definition.
  ///
  /// [definition] is null when the type is not in the registry — a link written
  /// before a custom type was removed, say. Those are treated as ordinary typed
  /// edges rather than dropped, because dropping them would hide a real
  /// relationship the author created.
  bool allowsEdgeType(String typeId, ConnectionTypeDefinition? definition) {
    // Naming a type explicitly beats the noise filters below. The Plot mode
    // asks for `plannedFor`, `fulfilledBy` and `resolvesIn` precisely because
    // scene-to-plot has no typed edge; dropping them for being wildcards would
    // leave that mode with nothing to draw.
    if (edgeTypeIds.isNotEmpty) return edgeTypeIds.contains(typeId);
    // `relatedTo` has its own switch, so that switch decides it outright — in
    // both directions. It is itself a `*` -> `*` type, so leaving it to fall
    // through to the wildcard rule below would let the general filter override
    // the specific opt-in and the toggle would appear to do nothing.
    if (typeId == 'relatedTo') return includeRelatedTo;
    if (!includeWildcardEdges && (definition?.permits('*', '*') ?? false)) {
      return false;
    }
    return true;
  }

  /// The edge types to ask SQL for, or null for "no type restriction".
  ///
  /// Only [edgeTypeIds] can be pushed down: the wildcard and `relatedTo`
  /// switches need the registry to resolve, which SQL does not have.
  Set<String>? get queryableEdgeTypeIds =>
      edgeTypeIds.isEmpty ? null : edgeTypeIds;

  StoryGraphFilter toggleCategory(String categoryId) => copyWith(
        categoryIds: _toggled(categoryIds, categoryId),
      );

  StoryGraphFilter toggleEdgeType(String typeId) => copyWith(
        edgeTypeIds: _toggled(edgeTypeIds, typeId),
      );

  StoryGraphFilter toggleCanonStatus(CanonStatus status) => copyWith(
        canonStatuses: _toggled(canonStatuses, status),
      );

  StoryGraphFilter copyWith({
    Set<String>? categoryIds,
    Set<String>? edgeTypeIds,
    Set<CanonStatus>? canonStatuses,
    String? seriesId,
    String? bookId,
    String? branchId,
    bool? includeArchived,
    bool? includeDeleted,
    bool? includeRelatedTo,
    bool? includeWildcardEdges,
    bool clearSeries = false,
    bool clearBook = false,
    bool clearBranch = false,
  }) =>
      StoryGraphFilter(
        categoryIds: categoryIds ?? this.categoryIds,
        edgeTypeIds: edgeTypeIds ?? this.edgeTypeIds,
        canonStatuses: canonStatuses ?? this.canonStatuses,
        seriesId: clearSeries ? null : (seriesId ?? this.seriesId),
        bookId: clearBook ? null : (bookId ?? this.bookId),
        branchId: clearBranch ? null : (branchId ?? this.branchId),
        includeArchived: includeArchived ?? this.includeArchived,
        includeDeleted: includeDeleted ?? this.includeDeleted,
        includeRelatedTo: includeRelatedTo ?? this.includeRelatedTo,
        includeWildcardEdges:
            includeWildcardEdges ?? this.includeWildcardEdges,
      );

  Map<String, Object?> toJson() => {
        'categoryIds': categoryIds.toList()..sort(),
        'edgeTypeIds': edgeTypeIds.toList()..sort(),
        'canonStatuses': canonStatuses.map((status) => status.name).toList()
          ..sort(),
        'seriesId': seriesId,
        'bookId': bookId,
        'branchId': branchId,
        'includeArchived': includeArchived,
        'includeDeleted': includeDeleted,
        'includeRelatedTo': includeRelatedTo,
        'includeWildcardEdges': includeWildcardEdges,
      };

  factory StoryGraphFilter.fromJson(Map<String, Object?> json) =>
      StoryGraphFilter(
        categoryIds: _stringSet(json['categoryIds']),
        edgeTypeIds: _stringSet(json['edgeTypeIds']),
        canonStatuses: {
          for (final name in _stringSet(json['canonStatuses']))
            for (final status in CanonStatus.values)
              if (status.name == name) status,
        },
        seriesId: json['seriesId'] as String?,
        bookId: json['bookId'] as String?,
        branchId: json['branchId'] as String?,
        includeArchived: json['includeArchived'] as bool? ?? false,
        includeDeleted: json['includeDeleted'] as bool? ?? false,
        includeRelatedTo: json['includeRelatedTo'] as bool? ?? false,
        includeWildcardEdges: json['includeWildcardEdges'] as bool? ?? false,
      );
}

Set<T> _toggled<T>(Set<T> values, T value) {
  final next = {...values};
  if (!next.remove(value)) next.add(value);
  return next;
}

Set<String> _stringSet(Object? value) => {
      if (value is List)
        for (final entry in value)
          if (entry is String) entry,
    };
