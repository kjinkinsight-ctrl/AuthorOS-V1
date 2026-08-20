import 'connected_domain.dart';
import 'world_record_types.dart';

/// How much of a template the World editor shows at once.
enum WorldEditorMode { simple, deep }

/// Ordering applied to the World record list and tree roots.
enum WorldSort { hierarchy, title, recentlyUpdated }

/// Top-level buckets the World workspace groups records into.
///
/// Spatial records form the hierarchy tree; maps, markers and routes hang off
/// it and are edited through their own panels.
enum WorldRecordGroup { spatial, maps, markers, routes }

extension WorldRecordGroupTypes on WorldRecordGroup {
  Set<String> get typeIds => switch (this) {
        WorldRecordGroup.spatial => WorldRecordTypes.spatialTypeIds,
        WorldRecordGroup.maps => WorldRecordTypes.mapTypeIds,
        WorldRecordGroup.markers => const {'map-marker'},
        WorldRecordGroup.routes => WorldRecordTypes.routeTypeIds,
      };

  String get label => switch (this) {
        WorldRecordGroup.spatial => 'Places',
        WorldRecordGroup.maps => 'Maps',
        WorldRecordGroup.markers => 'Markers',
        WorldRecordGroup.routes => 'Routes',
      };
}

/// Declarative filter over the World record list and hierarchy tree.
///
/// Everything is serialisable so a filter can round-trip through a stored view
/// without a bespoke encoder.
class WorldFilter {
  const WorldFilter({
    this.query = '',
    this.group = WorldRecordGroup.spatial,
    this.typeIds = const {},
    this.canonStates = const {},
    this.tagIds = const {},
    this.includeArchived = false,
    this.onlyInvalid = false,
    this.sort = WorldSort.hierarchy,
  });

  final String query;
  final WorldRecordGroup group;
  final Set<String> typeIds;
  final Set<String> canonStates;
  final Set<String> tagIds;
  final bool includeArchived;
  final bool onlyInvalid;
  final WorldSort sort;

  static const empty = WorldFilter();

  bool get isEmpty =>
      query.trim().isEmpty &&
      group == WorldRecordGroup.spatial &&
      typeIds.isEmpty &&
      canonStates.isEmpty &&
      tagIds.isEmpty &&
      !includeArchived &&
      !onlyInvalid &&
      sort == WorldSort.hierarchy;

  int get activeFacetCount =>
      (query.trim().isEmpty ? 0 : 1) +
      (group == WorldRecordGroup.spatial ? 0 : 1) +
      typeIds.length +
      canonStates.length +
      tagIds.length +
      (includeArchived ? 1 : 0) +
      (onlyInvalid ? 1 : 0);

  WorldFilter copyWith({
    String? query,
    WorldRecordGroup? group,
    Set<String>? typeIds,
    Set<String>? canonStates,
    Set<String>? tagIds,
    bool? includeArchived,
    bool? onlyInvalid,
    WorldSort? sort,
  }) =>
      WorldFilter(
        query: query ?? this.query,
        group: group ?? this.group,
        typeIds: typeIds ?? this.typeIds,
        canonStates: canonStates ?? this.canonStates,
        tagIds: tagIds ?? this.tagIds,
        includeArchived: includeArchived ?? this.includeArchived,
        onlyInvalid: onlyInvalid ?? this.onlyInvalid,
        sort: sort ?? this.sort,
      );

  WorldFilter toggleType(String id) => copyWith(typeIds: _toggle(typeIds, id));
  WorldFilter toggleCanonState(String state) =>
      copyWith(canonStates: _toggle(canonStates, state));
  WorldFilter toggleTag(String id) => copyWith(tagIds: _toggle(tagIds, id));

  Map<String, Object?> toJson() => {
        'query': query,
        'group': group.name,
        'typeIds': typeIds.toList()..sort(),
        'canonStates': canonStates.toList()..sort(),
        'tagIds': tagIds.toList()..sort(),
        'includeArchived': includeArchived,
        'onlyInvalid': onlyInvalid,
        'sort': sort.name,
      };

  factory WorldFilter.fromJson(Map<String, Object?> json) => WorldFilter(
        query: json['query'] as String? ?? '',
        group: WorldRecordGroup.values
                .where((value) => value.name == json['group'])
                .firstOrNull ??
            WorldRecordGroup.spatial,
        typeIds: _stringList(json['typeIds']).toSet(),
        canonStates: _stringList(json['canonStates']).toSet(),
        tagIds: _stringList(json['tagIds']).toSet(),
        includeArchived: json['includeArchived'] as bool? ?? false,
        onlyInvalid: json['onlyInvalid'] as bool? ?? false,
        sort: WorldSort.values
                .where((value) => value.name == json['sort'])
                .firstOrNull ??
            WorldSort.hierarchy,
      );
}

Set<T> _toggle<T>(Set<T> source, T value) {
  final next = source.toSet();
  next.contains(value) ? next.remove(value) : next.add(value);
  return next;
}

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

/// One row of the World hierarchy tree.
class WorldTreeNode {
  const WorldTreeNode({
    required this.record,
    required this.depth,
    required this.children,
    this.matchesFilter = true,
  });

  final AuthorRecord record;
  final int depth;
  final List<WorldTreeNode> children;

  /// False when the node is only present because a descendant matched, so the
  /// tree can dim context rows instead of hiding the path to a match.
  final bool matchesFilter;

  String get id => record.id;
  bool get hasChildren => children.isNotEmpty;

  /// Depth-first flattening, honouring [expanded] ids.
  List<WorldTreeNode> flatten(Set<String> expanded) {
    final result = <WorldTreeNode>[this];
    if (!expanded.contains(id)) return result;
    for (final child in children) {
      result.addAll(child.flatten(expanded));
    }
    return result;
  }

  Iterable<String> get allIds sync* {
    yield id;
    for (final child in children) {
      yield* child.allIds;
    }
  }
}

/// A map marker resolved against the record it points at.
class WorldMapMarkerView {
  const WorldMapMarkerView({
    required this.record,
    required this.mapId,
    required this.targetId,
    required this.x,
    required this.y,
    required this.label,
    required this.icon,
    required this.category,
    required this.visibility,
    required this.notes,
    required this.targetTitle,
    required this.targetTypeId,
    required this.withinBounds,
  });

  final AuthorRecord record;
  final String mapId;
  final String targetId;
  final num x;
  final num y;
  final String label;
  final String icon;
  final String category;
  final String visibility;
  final String notes;
  final String targetTitle;
  final String targetTypeId;

  /// False when the marker sits outside the map's declared width or height.
  final bool withinBounds;

  String get id => record.id;
  String get displayLabel => label.trim().isEmpty ? record.title : label;
  bool get isArchived => record.status == AuthorRecordStatus.archived;
}

/// A travel route resolved against both endpoints.
class WorldRouteView {
  const WorldRouteView({
    required this.record,
    required this.startId,
    required this.endId,
    required this.startTitle,
    required this.endTitle,
    required this.routeType,
    required this.distance,
    required this.travelTime,
    required this.difficulty,
    required this.startResolved,
    required this.endResolved,
  });

  final AuthorRecord record;
  final String startId;
  final String endId;
  final String startTitle;
  final String endTitle;
  final String routeType;
  final String distance;
  final String travelTime;
  final String difficulty;
  final bool startResolved;
  final bool endResolved;

  String get id => record.id;
  bool get isArchived => record.status == AuthorRecordStatus.archived;
  bool get endpointsResolved => startResolved && endResolved;
}

/// The editable metadata block of a map record.
class WorldMapMetadata {
  const WorldMapMetadata({
    this.mapType = '',
    this.coordinateSystem = '',
    this.width,
    this.height,
    this.scale = '',
    this.projection = '',
    this.backgroundReference = '',
  });

  final String mapType;
  final String coordinateSystem;
  final num? width;
  final num? height;
  final String scale;
  final String projection;
  final String backgroundReference;

  bool get hasBounds =>
      (width ?? 0) > 0 && (height ?? 0) > 0;

  factory WorldMapMetadata.fromRecord(AuthorRecord record) => WorldMapMetadata(
        mapType: _string(record.fields['mapType']),
        coordinateSystem: _string(record.fields['coordinateSystem']),
        width: record.fields['width'] is num
            ? record.fields['width'] as num
            : num.tryParse('${record.fields['width'] ?? ''}'),
        height: record.fields['height'] is num
            ? record.fields['height'] as num
            : num.tryParse('${record.fields['height'] ?? ''}'),
        scale: _string(record.fields['scale']),
        projection: _string(record.fields['projection']),
        backgroundReference: _string(record.fields['backgroundReference']),
      );

  Map<String, Object?> toFields() => {
        'mapType': mapType,
        'coordinateSystem': coordinateSystem,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'scale': scale,
        'projection': projection,
        'backgroundReference': backgroundReference,
      };
}

String _string(Object? value) => value is String ? value.trim() : '';

/// Human labels for the World canon state field.
const worldCanonStateOrder = <String>[
  'Canon',
  'Draft',
  'Proposed',
  'Deprecated',
  'Non-Canon',
  'Alternate',
];

/// Reads the World canon state written by [WorldService].
String worldCanonState(AuthorRecord record) {
  final raw = record.fields['_world.canonState'];
  final value = raw is String ? raw.trim() : '';
  return worldCanonStateOrder.contains(value) ? value : 'Draft';
}
