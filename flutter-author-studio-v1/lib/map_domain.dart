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
/// The camera is presentation state and nothing else: zoom and pan move it, and
/// no map record changes when they do. Phase 1 rendered every map at
/// [MapCamera.identity]; the Phase 2 editor drives it.
class MapCamera {
  const MapCamera({this.scale = 1, this.offset = MapPosition.origin});

  final double scale;

  /// The map-space point drawn at the canvas origin.
  final MapPosition offset;

  static const identity = MapCamera();

  /// The zoom range the editor allows.
  static const double minScale = 0.25;
  static const double maxScale = 8;

  /// One press of zoom in, or its inverse for zoom out.
  static const double zoomStep = 1.25;

  /// True when the camera is showing the map's normal starting view.
  bool get isDefault => this == identity;

  MapCamera withScale(double value) => MapCamera(
        scale: value.clamp(minScale, maxScale).toDouble(),
        offset: offset,
      );

  MapCamera withOffset(MapPosition value) =>
      MapCamera(scale: scale, offset: value);

  /// Keeps the framed window inside [extent].
  ///
  /// Zoomed in, the window may sit anywhere over the map. Zoomed out past the
  /// whole map it centres instead, so the editor never wanders off into empty
  /// space and the map is always where the writer left it.
  MapCamera clampedTo(MapExtent extent) {
    if (!extent.isValid) return this;
    final visibleWidth = extent.width / scale;
    final visibleHeight = extent.height / scale;
    return MapCamera(
      scale: scale,
      offset: MapPosition(
        _clampAxis(offset.x, extent.width - visibleWidth),
        _clampAxis(offset.y, extent.height - visibleHeight),
      ),
    );
  }

  static double _clampAxis(double value, double limit) =>
      limit >= 0 ? value.clamp(0.0, limit).toDouble() : limit / 2;

  /// The part of the map this camera is framing.
  MapRect visibleRect(MapExtent extent) => MapRect(
        left: offset.x,
        top: offset.y,
        right: offset.x + extent.width / scale,
        bottom: offset.y + extent.height / scale,
      );

  /// Zoom by [factor], holding the centre of the frame still.
  ///
  /// Pure map space: the toolbar's zoom buttons need no pixel size to work, and
  /// nothing about the stored map changes.
  MapCamera zoomedAroundCentre(double factor, MapExtent extent) {
    if (!extent.isValid) return this;
    final next =
        (scale * factor).clamp(minScale, maxScale).toDouble();
    final frame = visibleRect(extent);
    return MapCamera(
      scale: next,
      offset: MapPosition(
        frame.centre.x - extent.width / (2 * next),
        frame.centre.y - extent.height / (2 * next),
      ),
    ).clampedTo(extent);
  }

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

  /// Pixels per map unit before the camera's zoom is applied.
  double get baseScaleX => extent.width == 0 ? 0 : canvasWidth / extent.width;
  double get baseScaleY =>
      extent.height == 0 ? 0 : canvasHeight / extent.height;

  double get scaleX => baseScaleX * camera.scale;
  double get scaleY => baseScaleY * camera.scale;

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

  /// The same projection under a different camera.
  MapProjection withCamera(MapCamera value) => MapProjection(
        extent: extent,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        camera: value,
      );

  /// A canvas-pixel rectangle, read back as the map-space rectangle it covers.
  ///
  /// This is how the marquee stays a map-space question: the pointer draws in
  /// pixels, the projection answers in map units, and nothing pixel-shaped ever
  /// reaches a record.
  MapRect toMapRect(double dx1, double dy1, double dx2, double dy2) =>
      MapRect.fromCorners(toMap(dx1, dy1), toMap(dx2, dy2));

  /// The camera that would show the map at [scale], holding the map point under
  /// the given canvas pixel still.
  ///
  /// With no focus point the canvas centre is held instead, which is what the
  /// toolbar's zoom buttons want.
  MapCamera zoomedTo(double scale, {double? focusDx, double? focusDy}) {
    final next =
        scale.clamp(MapCamera.minScale, MapCamera.maxScale).toDouble();
    final dx = focusDx ?? canvasWidth / 2;
    final dy = focusDy ?? canvasHeight / 2;
    final anchor = toMap(dx, dy);
    final nextScaleX = baseScaleX * next;
    final nextScaleY = baseScaleY * next;
    return MapCamera(
      scale: next,
      offset: MapPosition(
        nextScaleX == 0 ? camera.offset.x : anchor.x - dx / nextScaleX,
        nextScaleY == 0 ? camera.offset.y : anchor.y - dy / nextScaleY,
      ),
    ).clampedTo(extent);
  }

  /// Multiplies the current zoom, holding a canvas pixel still. One wheel notch
  /// or one toolbar press.
  MapCamera zoomedBy(double factor, {double? focusDx, double? focusDy}) =>
      zoomedTo(camera.scale * factor, focusDx: focusDx, focusDy: focusDy);

  /// The camera after dragging the map by a pixel delta.
  ///
  /// The content follows the pointer, so the camera moves the other way.
  MapCamera pannedBy(double dxPixels, double dyPixels) => MapCamera(
        scale: camera.scale,
        offset: MapPosition(
          camera.offset.x - (scaleX == 0 ? 0 : dxPixels / scaleX),
          camera.offset.y - (scaleY == 0 ? 0 : dyPixels / scaleY),
        ),
      ).clampedTo(extent);
}

/// An axis-aligned rectangle in map space.
///
/// Used for region bounds and for the marquee. Like every other coordinate in
/// this library it is map units, never pixels.
class MapRect {
  const MapRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory MapRect.fromCorners(MapPosition a, MapPosition b) => MapRect(
        left: a.x <= b.x ? a.x : b.x,
        top: a.y <= b.y ? a.y : b.y,
        right: a.x <= b.x ? b.x : a.x,
        bottom: a.y <= b.y ? b.y : a.y,
      );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  MapPosition get topLeft => MapPosition(left, top);
  MapPosition get bottomRight => MapPosition(right, bottom);
  MapPosition get centre => MapPosition((left + right) / 2, (top + bottom) / 2);

  bool get isEmpty => width <= 0 && height <= 0;

  bool contains(MapPosition position) =>
      position.x >= left &&
      position.x <= right &&
      position.y >= top &&
      position.y <= bottom;

  /// True when the two rectangles overlap or touch.
  bool intersects(MapRect other) =>
      left <= other.right &&
      right >= other.left &&
      top <= other.bottom &&
      bottom >= other.top;

  MapRect clampTo(MapExtent extent) => MapRect.fromCorners(
        topLeft.clampTo(extent),
        bottomRight.clampTo(extent),
      );

  @override
  bool operator ==(Object other) =>
      other is MapRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'MapRect($left, $top, $right, $bottom)';
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

  /// The shape's extent as a rectangle, or `null` when it has no points.
  MapRect? get bounds {
    final box = boundingBox;
    if (box == null) return null;
    return MapRect.fromCorners(box.topLeft, box.bottomRight);
  }

  /// How many points this kind of shape needs to be worth drawing.
  int get minimumPoints => switch (kind) {
        MapGeometryKind.point => 1,
        MapGeometryKind.bounds => 2,
        MapGeometryKind.polyline => 2,
        MapGeometryKind.polygon => 3,
      };

  bool get isValid => points.length >= minimumPoints;

  /// True when the shape overlaps [rect] — the marquee's question.
  bool intersects(MapRect rect) {
    final own = bounds;
    if (own == null) return false;
    return own.intersects(rect);
  }

  /// The same shape with one point moved. The editor's core geometry edit.
  MapGeometry withPointAt(int index, MapPosition position) {
    if (index < 0 || index >= points.length) return this;
    final next = [...points];
    next[index] = position;
    return MapGeometry(kind: kind, points: next);
  }

  /// The same shape with a point inserted, appended when [index] is absent.
  MapGeometry withPointAdded(MapPosition position, {int? index}) {
    final next = [...points];
    if (index == null || index < 0 || index > next.length) {
      next.add(position);
    } else {
      next.insert(index, position);
    }
    return MapGeometry(kind: kind, points: next);
  }

  /// The same shape with a point removed, unless that would leave too few.
  MapGeometry withPointRemoved(int index) {
    if (index < 0 || index >= points.length) return this;
    if (points.length <= minimumPoints) return this;
    final next = [...points]..removeAt(index);
    return MapGeometry(kind: kind, points: next);
  }

  /// The whole shape shifted by a map-space delta, for dragging a region.
  MapGeometry translatedBy(double dx, double dy) => MapGeometry(
        kind: kind,
        points: [for (final point in points) MapPosition(point.x + dx, point.y + dy)],
      );

  /// The whole shape moved so its centre lands on [position].
  MapGeometry movedTo(MapPosition position) {
    final current = centre;
    if (current == null) return this;
    return translatedBy(position.x - current.x, position.y - current.y);
  }

  /// This shape as an editable polygon.
  ///
  /// A bounds region becomes the four corners of its box, so the writer can
  /// start from a rectangle and pull it into a coastline. A polygon is already
  /// one and comes back unchanged.
  MapGeometry asPolygon() {
    if (kind == MapGeometryKind.polygon) return this;
    final box = bounds;
    if (box == null) return const MapGeometry(kind: MapGeometryKind.polygon);
    if (kind == MapGeometryKind.polyline && points.length >= 3) {
      return MapGeometry(kind: MapGeometryKind.polygon, points: [...points]);
    }
    return MapGeometry(
      kind: MapGeometryKind.polygon,
      points: [
        MapPosition(box.left, box.top),
        MapPosition(box.right, box.top),
        MapPosition(box.right, box.bottom),
        MapPosition(box.left, box.bottom),
      ],
    );
  }

  /// This shape reduced to its bounding box.
  MapGeometry asBounds() {
    if (kind == MapGeometryKind.bounds) return this;
    final box = bounds;
    if (box == null) return MapGeometry.empty;
    return MapGeometry.box(box.topLeft, box.bottomRight);
  }

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

  MapLocationView? locationById(String id) =>
      locations.where((item) => item.id == id).firstOrNull;
  MapRegionView? regionById(String id) =>
      regions.where((item) => item.id == id).firstOrNull;
  MapMarkerView? markerById(String id) =>
      markers.where((item) => item.id == id).firstOrNull;

  /// The map-space anchor of whatever [selection] points at.
  MapPosition? anchorOf(MapSelection selection) => switch (selection.kind) {
        MapSelectionKind.location => locationById(selection.id)?.position,
        MapSelectionKind.region => regionById(selection.id)?.anchor,
        MapSelectionKind.marker => markerById(selection.id)?.position,
      };

  /// True when [selection] still points at something on this map.
  bool contains(MapSelection selection) => switch (selection.kind) {
        MapSelectionKind.location => locationById(selection.id) != null,
        MapSelectionKind.region => regionById(selection.id) != null,
        MapSelectionKind.marker => markerById(selection.id) != null,
      };
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

/// The tool the editor is holding.
///
/// One tool at a time decides what a drag on the canvas means, which is what
/// keeps place, move, marquee and region editing from fighting over the pointer.
enum MapEditorTool {
  /// Click to select, drag the background for a marquee.
  select,

  /// Click or drop to place a new location or marker.
  place,

  /// Drag a location, marker or region to a new map-space position.
  move,

  /// Draw a new region, and drag the points of the selected one.
  region,

  /// Drag to move the camera. No record changes.
  pan,

  /// Paint the ground with a terrain brush.
  terrain,

  /// Place and shape visual scenery.
  asset,
}

extension MapEditorToolLabel on MapEditorTool {
  String get label => switch (this) {
        MapEditorTool.select => 'Select',
        MapEditorTool.place => 'Place',
        MapEditorTool.move => 'Move',
        MapEditorTool.region => 'Region',
        MapEditorTool.pan => 'Pan',
        MapEditorTool.terrain => 'Terrain',
        MapEditorTool.asset => 'Scenery',
      };

  /// True when this tool writes to records at all.
  bool get isEditing =>
      this == MapEditorTool.place ||
      this == MapEditorTool.move ||
      this == MapEditorTool.region ||
      this == MapEditorTool.terrain ||
      this == MapEditorTool.asset;

  /// True when the tool paints or places scenery rather than story entities.
  /// Phase 3 tools change how a map looks; they never create a graph entity.
  bool get isVisual =>
      this == MapEditorTool.terrain || this == MapEditorTool.asset;
}

/// What the place tool drops onto the canvas.
enum MapPlacementKind { location, marker }

extension MapPlacementKindLabel on MapPlacementKind {
  String get label => switch (this) {
        MapPlacementKind.location => 'Location',
        MapPlacementKind.marker => 'Marker',
      };
}

/// The canvas draw order.
///
/// Declaration order is the render order, back to front, and the canvas builds
/// its stack by walking [MapLayer.values]. Rendering order is all this is: how
/// an element is *styled* is Phase 3 work and lives nowhere in this enum.
enum MapLayer {
  /// The map ground and its graticule.
  base,

  /// Painted terrain. Above the ground, below everything that means something:
  /// terrain is what the world is made of, not what happens on it.
  terrain,

  /// Region fills and outlines.
  regions,

  /// Placed scenery — trees, mountains, settlements. Above regions so a forest
  /// reads over the territory it grows in, below the pins that name places.
  assets,

  /// Location pins.
  locations,

  /// Marker pins.
  markers,

  /// Journeys and story routes. Below the overlay points they connect, so a
  /// line never hides the thing at its end.
  storyPaths,

  /// Story overlays: characters, events and scenes read from canonical data.
  /// Above the map's own furniture because they are what the author came to
  /// look at, below selection because they are still content.
  storyOverlays,

  /// Selection rings, geometry handles and the marquee rectangle.
  selection,

  /// Live interaction affordances: the drag surface and inline editors.
  interaction,
}

/// Resolves a marquee rectangle into the items it covers.
///
/// Pure map-space geometry, and pure UI state: a marquee selects, it never
/// writes. The order is regions, then locations, then markers, so the same drag
/// always yields the same selection.
class MapMarquee {
  const MapMarquee._();

  static List<MapSelection> selectionsWithin(
    MapCanvasData data,
    MapRect rect,
  ) =>
      [
        for (final region in data.regions)
          if (region.geometry.intersects(rect))
            MapSelection(kind: MapSelectionKind.region, id: region.id),
        for (final location in data.locations)
          if (rect.contains(location.position))
            MapSelection(kind: MapSelectionKind.location, id: location.id),
        for (final marker in data.markers)
          if (rect.contains(marker.position))
            MapSelection(kind: MapSelectionKind.marker, id: marker.id),
      ];
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String _asString(Object? value) => value is String ? value.trim() : '';
