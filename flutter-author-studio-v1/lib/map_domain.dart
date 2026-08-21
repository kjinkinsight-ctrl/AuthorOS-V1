/// Map Studio Phase 1 — domain vocabulary.
///
/// Plain Dart on purpose: the Map domain must be resolvable in tests without a
/// Flutter binding, exactly like `timeline_domain.dart` and `core/world_domain.dart`.
/// Map Studio owns no store of its own — every value here is a projection of an
/// existing Universal Record, and [MapFields] is the single field namespace the
/// Studio writes into.
library;

import 'core/connected_domain.dart';
import 'core/world_record_types.dart';

/// The record field names Map Studio owns.
///
/// Map, location, region and marker records are ordinary Universal Records of
/// the existing `map`, `location`, `region` and `map-marker` types. Map Studio
/// adds only the placement data those templates do not already declare, under a
/// reserved prefix so a field can never collide with a template field.
class MapFields {
  const MapFields._();

  static const prefix = '_map.';

  /// The map a location or region is placed on.
  static const mapId = '${prefix}mapId';

  /// Map-space X of a location or region anchor.
  static const x = '${prefix}x';

  /// Map-space Y of a location or region anchor.
  static const y = '${prefix}y';

  /// A region's geometry, stored as `{kind, points}`.
  static const geometry = '${prefix}geometry';

  /// Marks a record as authored through Map Studio.
  static const studioFlag = 'mapStudio';

  /// Fields the existing `map` template already declares.
  static const description = 'description';
  static const mapType = 'mapType';
  static const width = 'width';
  static const height = 'height';
  static const backgroundReference = 'backgroundReference';
  static const coordinateSystem = 'coordinateSystem';
  static const locationType = 'locationType';
  static const primaryName = 'primaryName';

  /// Fields the existing `map-marker` template already declares.
  static const markerMapId = 'mapId';
  static const markerRecordId = 'recordId';
  static const markerX = 'x';
  static const markerY = 'y';
  static const markerLabel = 'label';
  static const markerIcon = 'icon';
  static const markerCategory = 'category';
  static const markerVisibility = 'visibility';
  static const markerNotes = 'markerNotes';
}

/// The record types Map Studio reads and writes.
class MapTypes {
  const MapTypes._();

  static const map = 'map';
  static const location = 'location';
  static const region = 'region';
  static const marker = 'map-marker';

  /// Every `map`-family type, so an existing World Studio map opens here too.
  static Set<String> get mapTypeIds => WorldRecordTypes.mapTypeIds;

  /// Every spatial type a Map Studio location may use.
  ///
  /// `region` is excluded on purpose: it is a Map Studio concept of its own,
  /// with geometry rather than a single anchor, even though the record
  /// vocabulary files it under the location family.
  static Set<String> get locationTypeIds =>
      WorldRecordTypes.locationTypeIds.difference(const {region});

  /// The link that puts a place on a map (`map` → place).
  static const placedOn = 'maps';

  /// The link that puts a marker on a map (`map-marker` → `map`).
  static const markerOnMap = 'onMap';

  /// The link from a marker to the entity it stands for.
  static const markerRepresents = 'represents';
}

/// The default map extent, in map-space units.
///
/// Positions are stored in map space rather than pixels so the canvas can be
/// any size: the viewport projects map space onto whatever room it is given.
const double defaultMapExtent = 1000;

/// A point in map space.
///
/// Map space is the coordinate system declared by a map's `width` and `height`.
/// Nothing here is expressed in device pixels, so a stored position survives a
/// window resize, a zoom, and the scalable canvas Phase 2 introduces.
class MapPosition {
  const MapPosition(this.x, this.y);

  final double x;
  final double y;

  static const origin = MapPosition(0, 0);

  /// Reads a position from [fields] under [xKey]/[yKey].
  static MapPosition? read(
    Map<String, Object?> fields, {
    required String xKey,
    required String yKey,
  }) {
    final x = _asDouble(fields[xKey]);
    final y = _asDouble(fields[yKey]);
    if (x == null || y == null) return null;
    return MapPosition(x, y);
  }

  MapPosition clampTo(MapExtent extent) => MapPosition(
        x.clamp(0, extent.width).toDouble(),
        y.clamp(0, extent.height).toDouble(),
      );

  /// This position as a fraction of [extent], in `0.0..1.0`.
  ///
  /// The canvas draws from these fractions, which is what keeps rendering
  /// independent of the widget's pixel size.
  MapPosition normalizedIn(MapExtent extent) => MapPosition(
        extent.width == 0 ? 0 : x / extent.width,
        extent.height == 0 ? 0 : y / extent.height,
      );

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  factory MapPosition.fromJson(Map<String, Object?> json) =>
      MapPosition(_asDouble(json['x']) ?? 0, _asDouble(json['y']) ?? 0);

  @override
  bool operator ==(Object other) =>
      other is MapPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'MapPosition($x, $y)';
}

/// The declared size of a map's coordinate system.
class MapExtent {
  const MapExtent({this.width = defaultMapExtent, this.height = defaultMapExtent});

  final double width;
  final double height;

  static const standard = MapExtent();

  bool get isValid => width > 0 && height > 0;

  bool contains(MapPosition position) =>
      position.x >= 0 &&
      position.y >= 0 &&
      position.x <= width &&
      position.y <= height;

  /// The centre of the coordinate system, used when a caller supplies no
  /// position of its own.
  MapPosition get centre => MapPosition(width / 2, height / 2);

  factory MapExtent.fromRecord(AuthorRecord record) => MapExtent(
        width: _asDouble(record.fields[MapFields.width]) ?? defaultMapExtent,
        height: _asDouble(record.fields[MapFields.height]) ?? defaultMapExtent,
      );

  @override
  bool operator ==(Object other) =>
      other is MapExtent && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// How much of the map the canvas is showing.
///
/// Phase 1 always renders the whole map at [MapCamera.identity]. The type exists
/// so the Phase 2 editor can add zoom and pan without changing how a position is
/// stored or how the canvas projects one.
class MapCamera {
  const MapCamera({this.scale = 1, this.offset = MapPosition.origin});

  final double scale;

  /// The map-space point drawn at the canvas origin.
  final MapPosition offset;

  static const identity = MapCamera();

  @override
  bool operator ==(Object other) =>
      other is MapCamera && other.scale == scale && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);
}

/// Projects map space onto a canvas of a given pixel size.
///
/// The canvas never stores pixel coordinates; it asks the projection for them
/// on every layout, which is what lets one stored map render at any size.
class MapProjection {
  const MapProjection({
    required this.extent,
    required this.canvasWidth,
    required this.canvasHeight,
    this.camera = MapCamera.identity,
  });

  final MapExtent extent;
  final double canvasWidth;
  final double canvasHeight;
  final MapCamera camera;

  double get scaleX =>
      extent.width == 0 ? 0 : (canvasWidth / extent.width) * camera.scale;
  double get scaleY =>
      extent.height == 0 ? 0 : (canvasHeight / extent.height) * camera.scale;

  /// Map space → canvas pixels.
  MapPosition toCanvas(MapPosition position) => MapPosition(
        (position.x - camera.offset.x) * scaleX,
        (position.y - camera.offset.y) * scaleY,
      );

  /// Canvas pixels → map space.
  MapPosition toMap(double dx, double dy) => MapPosition(
        scaleX == 0 ? 0 : dx / scaleX + camera.offset.x,
        scaleY == 0 ? 0 : dy / scaleY + camera.offset.y,
      );
}

/// The shape a region occupies.
///
/// Phase 1 stores the representation and renders a bounding box; the polygon
/// editor that authors these points is Phase 2 work.
enum MapGeometryKind { point, bounds, polyline, polygon }

/// A region's stored shape.
class MapGeometry {
  const MapGeometry({
    this.kind = MapGeometryKind.bounds,
    this.points = const [],
  });

  final MapGeometryKind kind;
  final List<MapPosition> points;

  static const empty = MapGeometry(points: []);

  bool get isEmpty => points.isEmpty;

  /// The axis-aligned box the shape occupies, or `null` when it has no points.
  ({MapPosition topLeft, MapPosition bottomRight})? get boundingBox {
    if (points.isEmpty) return null;
    var minX = points.first.x;
    var minY = points.first.y;
    var maxX = minX;
    var maxY = minY;
    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }
    return (
      topLeft: MapPosition(minX, minY),
      bottomRight: MapPosition(maxX, maxY),
    );
  }

  /// The centre of [boundingBox], used to anchor a region's label.
  MapPosition? get centre {
    final box = boundingBox;
    if (box == null) return null;
    return MapPosition(
      (box.topLeft.x + box.bottomRight.x) / 2,
      (box.topLeft.y + box.bottomRight.y) / 2,
    );
  }

  /// A rectangle from two corners, the shape Phase 1 authors.
  factory MapGeometry.box(MapPosition topLeft, MapPosition bottomRight) =>
      MapGeometry(
        kind: MapGeometryKind.bounds,
        points: [topLeft, bottomRight],
      );

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'points': [for (final point in points) point.toJson()],
      };

  factory MapGeometry.fromJson(Map<String, Object?> json) => MapGeometry(
        kind: MapGeometryKind.values
                .where((value) => value.name == json['kind'])
                .firstOrNull ??
            MapGeometryKind.bounds,
        points: [
          for (final raw in (json['points'] as List? ?? const []))
            if (raw is Map)
              MapPosition.fromJson(Map<String, Object?>.from(raw)),
        ],
      );

  static MapGeometry read(Map<String, Object?> fields) {
    final raw = fields[MapFields.geometry];
    if (raw is Map) return MapGeometry.fromJson(Map<String, Object?>.from(raw));
    return MapGeometry.empty;
  }
}

/// A map, resolved for display.
class MapSummary {
  const MapSummary({required this.record});

  final AuthorRecord record;

  String get id => record.id;
  String get title => record.title;
  String get description => _asString(record.fields[MapFields.description]);
  String get mapType => _asString(record.fields[MapFields.mapType]);
  String get backgroundReference =>
      _asString(record.fields[MapFields.backgroundReference]);
  MapExtent get extent => MapExtent.fromRecord(record);
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;

  /// Map Studio's "active status": the record's own lifecycle, so archiving a
  /// map here is the same act as archiving it anywhere else in AuthorOS.
  bool get isActive => record.status == AuthorRecordStatus.active;
  bool get isArchived => record.status == AuthorRecordStatus.archived;
}

/// A place placed on a map.
class MapLocationView {
  const MapLocationView({required this.record, required this.mapId});

  final AuthorRecord record;
  final String mapId;

  String get id => record.id;
  String get name => record.title;
  String get description => _asString(record.fields[MapFields.description]);
  String get locationType => _asString(record.fields[MapFields.locationType]);
  String get typeId => record.typeId;
  MapPosition get position =>
      MapPosition.read(record.fields, xKey: MapFields.x, yKey: MapFields.y) ??
      MapPosition.origin;
  bool get isArchived => record.status == AuthorRecordStatus.archived;
}

/// A region placed on a map.
class MapRegionView {
  const MapRegionView({required this.record, required this.mapId});

  final AuthorRecord record;
  final String mapId;

  String get id => record.id;
  String get name => record.title;
  String get description => _asString(record.fields[MapFields.description]);
  String get category => _asString(record.fields[MapFields.locationType]);
  MapGeometry get geometry => MapGeometry.read(record.fields);
  MapPosition get anchor =>
      geometry.centre ??
      MapPosition.read(record.fields, xKey: MapFields.x, yKey: MapFields.y) ??
      MapPosition.origin;
  bool get isArchived => record.status == AuthorRecordStatus.archived;
}

/// A marker placed on a map.
class MapMarkerView {
  const MapMarkerView({required this.record, required this.mapId});

  final AuthorRecord record;
  final String mapId;

  String get id => record.id;
  String get label {
    final stored = _asString(record.fields[MapFields.markerLabel]);
    return stored.isEmpty ? record.title : stored;
  }

  String get category => _asString(record.fields[MapFields.markerCategory]);
  String get icon => _asString(record.fields[MapFields.markerIcon]);
  String get notes => _asString(record.fields[MapFields.markerNotes]);

  /// The record this marker stands for, or `null` when it stands alone.
  ///
  /// Phase 1 keeps the reference optional and untyped so Phase 4 can point a
  /// marker at a character, plot thread, timeline event or research entry
  /// without changing how a marker is stored.
  String? get linkedRecordId {
    final value = _asString(record.fields[MapFields.markerRecordId]);
    return value.isEmpty ? null : value;
  }

  MapPosition get position =>
      MapPosition.read(record.fields,
          xKey: MapFields.markerX, yKey: MapFields.markerY) ??
      MapPosition.origin;

  bool get isArchived => record.status == AuthorRecordStatus.archived;
}

/// Everything the canvas needs to draw one map.
class MapCanvasData {
  const MapCanvasData({
    required this.map,
    this.locations = const [],
    this.regions = const [],
    this.markers = const [],
  });

  final MapSummary map;
  final List<MapLocationView> locations;
  final List<MapRegionView> regions;
  final List<MapMarkerView> markers;

  MapExtent get extent => map.extent;

  bool get isEmpty =>
      locations.isEmpty && regions.isEmpty && markers.isEmpty;
}

/// What the canvas currently has selected.
enum MapSelectionKind { location, region, marker }

class MapSelection {
  const MapSelection({required this.kind, required this.id});

  final MapSelectionKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is MapSelection && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String _asString(Object? value) => value is String ? value.trim() : '';
