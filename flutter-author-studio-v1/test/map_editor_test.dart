import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map Studio Phase 2 — the editor's domain and service behaviour.
///
/// Everything the visual editor does ends here: a pointer becomes a map-space
/// position, a map-space position becomes a field on an existing record, and
/// the camera never becomes anything at all.
const projectId = 'project-map';
const otherProjectId = 'project-other';
final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<MapSummary> seedMap({
    String id = 'map-kingdom',
    MapExtent extent = MapExtent.standard,
    MapService? service,
  }) =>
      (service ?? maps).createMap(
        MapDraft(id: id, title: 'Kingdom Map', extent: extent),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedLocation({
    String id = 'city-endovier',
    MapPosition position = const MapPosition(100, 100),
  }) =>
      maps.createLocation(
        MapLocationDraft(
          id: id,
          mapId: 'map-kingdom',
          name: 'Endovier',
          locationType: 'City',
          position: position,
        ),
        timestamp: timestamp,
      );

  Future<MapRegionView> seedRegion({
    String id = 'region-north',
    MapGeometry geometry = const MapGeometry(
      kind: MapGeometryKind.bounds,
      points: [MapPosition(100, 100), MapPosition(500, 300)],
    ),
  }) =>
      maps.createRegion(
        MapRegionDraft(
          id: id,
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
          geometry: geometry,
        ),
        timestamp: timestamp,
      );

  // ------------------------------------------------------- camera and math --

  group('the camera is presentation state', () {
    test('zoom is bounded at both ends', () {
      expect(const MapCamera().withScale(100).scale, MapCamera.maxScale);
      expect(const MapCamera().withScale(0.001).scale, MapCamera.minScale);
    });

    test('a camera at rest is the map default view', () {
      expect(MapCamera.identity.isDefault, isTrue);
      expect(MapCamera.identity.scale, 1);
      expect(MapCamera.identity.offset, MapPosition.origin);
      expect(
        const MapCamera(scale: 2, offset: MapPosition(10, 10)).isDefault,
        isFalse,
      );
    });

    test('the framed window is clamped inside the map', () {
      const extent = MapExtent(width: 1000, height: 500);

      // Zoomed in twice, half the map is visible, so the offset may run to
      // half the extent and no further.
      final zoomed = const MapCamera(scale: 2, offset: MapPosition(900, 900))
          .clampedTo(extent);
      expect(zoomed.offset, const MapPosition(500, 250));

      // At rest the whole map is framed, so there is nowhere to pan to.
      final rest = const MapCamera(offset: MapPosition(400, 400))
          .clampedTo(extent);
      expect(rest.offset, MapPosition.origin);

      // Zoomed out past the map, it centres instead.
      final wide = const MapCamera(scale: 0.5).clampedTo(extent);
      expect(wide.offset, const MapPosition(-500, -250));
    });

    test('zooming around the centre holds the centre still', () {
      const extent = MapExtent(width: 1000, height: 500);
      final zoomed =
          MapCamera.identity.zoomedAroundCentre(2, extent);

      expect(zoomed.scale, 2);
      expect(zoomed.visibleRect(extent).centre, const MapPosition(500, 250));
      expect(
        MapCamera.identity.visibleRect(extent).centre,
        const MapPosition(500, 250),
      );
    });

    test('zooming around a pointer holds that map point under the pointer', () {
      const projection = MapProjection(
        extent: MapExtent(width: 1000, height: 1000),
        canvasWidth: 500,
        canvasHeight: 500,
      );
      final before = projection.toMap(100, 400);
      final camera = projection.zoomedBy(2, focusDx: 100, focusDy: 400);
      final after = projection.withCamera(camera).toMap(100, 400);

      expect(camera.scale, 2);
      expect(after.x, closeTo(before.x, 0.001));
      expect(after.y, closeTo(before.y, 0.001));
    });

    test('panning moves the camera the other way from the pointer', () {
      const projection = MapProjection(
        extent: MapExtent(width: 1000, height: 1000),
        canvasWidth: 500,
        canvasHeight: 500,
        camera: MapCamera(scale: 2, offset: MapPosition(400, 400)),
      );
      // The content follows the pointer, so dragging right reveals what is to
      // the left: the camera offset drops.
      final panned = projection.pannedBy(50, 0);
      expect(panned.offset.x, lessThan(400));
      expect(panned.scale, 2);
    });

    test('a canvas rectangle reads back as a map-space rectangle', () {
      const projection = MapProjection(
        extent: MapExtent(width: 1000, height: 500),
        canvasWidth: 500,
        canvasHeight: 250,
      );
      // Drawn bottom-right to top-left; the rectangle normalises itself.
      final rect = projection.toMapRect(200, 100, 50, 25);
      expect(rect.left, 100);
      expect(rect.top, 50);
      expect(rect.right, 400);
      expect(rect.bottom, 200);
    });

    test('map rectangles answer containment and overlap', () {
      const rect = MapRect(left: 0, top: 0, right: 100, bottom: 100);
      expect(rect.contains(const MapPosition(50, 50)), isTrue);
      expect(rect.contains(const MapPosition(150, 50)), isFalse);
      expect(
        rect.intersects(const MapRect(left: 90, top: 90, right: 200, bottom: 200)),
        isTrue,
      );
      expect(
        rect.intersects(
          const MapRect(left: 101, top: 101, right: 200, bottom: 200),
        ),
        isFalse,
      );
      expect(rect.centre, const MapPosition(50, 50));
    });
  });

  group('geometry editing is map-space arithmetic', () {
    const box = MapGeometry(
      kind: MapGeometryKind.bounds,
      points: [MapPosition(0, 0), MapPosition(100, 50)],
    );

    test('a point can be moved', () {
      final moved = box.withPointAt(1, const MapPosition(200, 80));
      expect(moved.points, [const MapPosition(0, 0), const MapPosition(200, 80)]);
      expect(moved.kind, MapGeometryKind.bounds);
    });

    test('an out-of-range point index changes nothing', () {
      expect(box.withPointAt(5, const MapPosition(1, 1)).points, box.points);
      expect(box.withPointRemoved(-1).points, box.points);
    });

    test('points can be added and removed within the shape minimum', () {
      final polygon = box.asPolygon();
      expect(polygon.kind, MapGeometryKind.polygon);
      expect(polygon.points, hasLength(4));

      final added = polygon.withPointAdded(const MapPosition(50, 50), index: 2);
      expect(added.points[2], const MapPosition(50, 50));
      expect(added.points, hasLength(5));

      final removed = added.withPointRemoved(2);
      expect(removed.points, hasLength(4));

      // A polygon never falls below three points.
      var trimmed = removed;
      for (var i = 0; i < 5; i++) {
        trimmed = trimmed.withPointRemoved(0);
      }
      expect(trimmed.points, hasLength(3));
      expect(trimmed.isValid, isTrue);
    });

    test('a shape can be moved whole and reduced back to its box', () {
      final moved = box.movedTo(const MapPosition(100, 100));
      expect(moved.centre, const MapPosition(100, 100));
      expect(moved.points, hasLength(2));

      final polygon = moved.asPolygon();
      expect(polygon.asBounds().kind, MapGeometryKind.bounds);
      expect(polygon.asBounds().bounds, moved.bounds);
    });

    test('a shape reports the rectangle it occupies', () {
      expect(box.bounds, const MapRect(left: 0, top: 0, right: 100, bottom: 50));
      expect(MapGeometry.empty.bounds, isNull);
      expect(
        box.intersects(const MapRect(left: 90, top: 40, right: 200, bottom: 200)),
        isTrue,
      );
      expect(
        box.intersects(
          const MapRect(left: 200, top: 200, right: 300, bottom: 300),
        ),
        isFalse,
      );
    });
  });

  group('marquee selection', () {
    test('a rectangle selects regions, locations and markers it covers',
        () async {
      await seedMap();
      await seedRegion();
      await seedLocation(position: const MapPosition(150, 150));
      await seedLocation(id: 'city-far', position: const MapPosition(900, 900));
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          position: MapPosition(200, 200),
        ),
        timestamp: timestamp,
      );

      final canvas = await maps.loadCanvas('map-kingdom');
      final selected = MapMarquee.selectionsWithin(
        canvas,
        const MapRect(left: 0, top: 0, right: 400, bottom: 400),
      );

      expect(selected, hasLength(3));
      expect(
        selected,
        containsAll(const [
          MapSelection(kind: MapSelectionKind.region, id: 'region-north'),
          MapSelection(kind: MapSelectionKind.location, id: 'city-endovier'),
          MapSelection(kind: MapSelectionKind.marker, id: 'marker-well'),
        ]),
      );
      // Regions first, then locations, then markers: the same drag always
      // yields the same selection.
      expect(selected.first.kind, MapSelectionKind.region);
      expect(selected.last.kind, MapSelectionKind.marker);
    });

    test('an empty patch of map selects nothing', () async {
      await seedMap();
      await seedLocation(position: const MapPosition(900, 900));
      final canvas = await maps.loadCanvas('map-kingdom');

      expect(
        MapMarquee.selectionsWithin(
          canvas,
          const MapRect(left: 0, top: 0, right: 100, bottom: 100),
        ),
        isEmpty,
      );
    });
  });

  // ------------------------------------------------------------- the service -

  group('drag to place', () {
    test('a placed location stores map space, not pixels', () async {
      await seedMap();
      const projection = MapProjection(
        extent: MapExtent.standard,
        canvasWidth: 500,
        canvasHeight: 500,
      );
      // What a pointer at (125, 250) on a 500px canvas means on a 1000-unit map.
      final dropped = projection.toMap(125, 250);
      final location = await maps.createLocation(
        MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          position: dropped,
        ),
        timestamp: timestamp,
      );

      expect(location.position, const MapPosition(250, 500));

      final record = await maps.records.getRecord('city-endovier');
      expect(record!.fields['_map.x'], 250);
      expect(record.fields['_map.y'], 500);
      // Nothing pixel-shaped reached the record.
      expect(record.fields.containsKey('screenX'), isFalse);
      expect(record.fields.containsKey('canvasX'), isFalse);
    });

    test('a reopened map puts the item back at the same logical position',
        () async {
      await seedMap();
      await seedLocation(position: const MapPosition(250, 500));

      final canvas = await maps.loadCanvas('map-kingdom');
      expect(
        canvas.locationById('city-endovier')!.position,
        const MapPosition(250, 500),
      );

      // The same stored position projects onto any canvas size.
      const small = MapProjection(
        extent: MapExtent.standard,
        canvasWidth: 500,
        canvasHeight: 500,
      );
      const large = MapProjection(
        extent: MapExtent.standard,
        canvasWidth: 2000,
        canvasHeight: 2000,
      );
      expect(small.toCanvas(const MapPosition(250, 500)),
          const MapPosition(125, 250));
      expect(large.toCanvas(const MapPosition(250, 500)),
          const MapPosition(500, 1000));
    });

    test('a placement past the edge is clamped into the map extent', () async {
      await seedMap(extent: const MapExtent(width: 800, height: 400));
      final location = await maps.createLocation(
        const MapLocationDraft(
          id: 'city-edge',
          mapId: 'map-kingdom',
          name: 'Edge',
          position: MapPosition(5000, -400),
        ),
        timestamp: timestamp,
      );

      expect(location.position, const MapPosition(800, 0));
    });
  });

  group('drag to move', () {
    test('moving a location rewrites its position and nothing else', () async {
      await seedMap();
      final before = await seedLocation(position: const MapPosition(100, 100));
      final beforeRecord = await maps.records.getRecord('city-endovier');

      final after = await maps.moveLocation(
        'city-endovier',
        const MapPosition(640, 320),
        timestamp: timestamp.add(const Duration(minutes: 1)),
      );

      expect(after.position, const MapPosition(640, 320));
      expect(before.position, const MapPosition(100, 100));
      // Same record, same identity, same everything but the coordinates.
      expect(after.id, before.id);
      expect(after.record.typeId, beforeRecord!.typeId);
      expect(after.name, 'Endovier');
      expect(after.locationType, 'City');

      // And no duplicate was written.
      final locations = await maps.locationsForMap('map-kingdom');
      expect(locations, hasLength(1));
      expect(locations.single.id, 'city-endovier');
    });

    test('moving a location leaves its connections intact', () async {
      await seedMap();
      await seedLocation();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-endovier',
          mapId: 'map-kingdom',
          label: 'Endovier',
          linkedRecordId: 'city-endovier',
        ),
        timestamp: timestamp,
      );

      List<String> linkIds(List<RecordLink> links) =>
          [for (final link in links) '${link.typeId}:${link.targetId}']..sort();

      final mapLinksBefore = linkIds(await maps.connections.outgoing('map-kingdom'));
      final markerLinksBefore =
          linkIds(await maps.connections.outgoing('marker-endovier'));

      await maps.moveLocation('city-endovier', const MapPosition(700, 700));
      await maps.moveMarker('marker-endovier', const MapPosition(700, 700));

      expect(linkIds(await maps.connections.outgoing('map-kingdom')),
          mapLinksBefore);
      expect(linkIds(await maps.connections.outgoing('marker-endovier')),
          markerLinksBefore);
      expect(markerLinksBefore, contains('represents:city-endovier'));
    });

    test('a move past the edge is clamped into the map extent', () async {
      await seedMap(extent: const MapExtent(width: 600, height: 300));
      await seedLocation(position: const MapPosition(10, 10));

      final moved =
          await maps.moveLocation('city-endovier', const MapPosition(-50, 9000));
      expect(moved.position, const MapPosition(0, 300));
    });

    test('every move is written to the shared version history', () async {
      await seedMap();
      await seedLocation();
      await maps.moveLocation('city-endovier', const MapPosition(200, 200));
      await maps.moveLocation('city-endovier', const MapPosition(300, 300));

      final versions = await maps.mapHistory('city-endovier');
      expect(versions.length, greaterThanOrEqualTo(3));
    });

    test('moving a marker rewrites its position and keeps its identity',
        () async {
      await seedMap();
      final marker = await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          category: 'Landmark',
          position: MapPosition(100, 100),
        ),
        timestamp: timestamp,
      );

      final moved =
          await maps.moveMarker('marker-well', const MapPosition(420, 260));

      expect(moved.id, marker.id);
      expect(moved.position, const MapPosition(420, 260));
      expect(moved.label, 'The Salt Well');
      expect(moved.category, 'Landmark');
      expect(await maps.markersForMap('map-kingdom'), hasLength(1));
    });

    test('moving a region carries the whole shape with it', () async {
      await seedMap();
      final region = await seedRegion();
      expect(region.geometry.centre, const MapPosition(300, 200));

      final moved =
          await maps.moveRegion('region-north', const MapPosition(500, 400));

      expect(moved.id, 'region-north');
      expect(moved.geometry.centre, const MapPosition(500, 400));
      expect(moved.geometry.points, hasLength(2));
      expect(moved.geometry.bounds!.width, 400);
      expect(moved.geometry.bounds!.height, 200);
      expect(await maps.regionsForMap('map-kingdom'), hasLength(1));
    });

    test('a region with no shape cannot be moved', () async {
      await seedMap();
      await seedRegion(id: 'region-empty', geometry: MapGeometry.empty);

      expect(
        () => maps.moveRegion('region-empty', const MapPosition(10, 10)),
        throwsA(isA<MapStudioException>()),
      );
    });
  });

  group('region geometry editing', () {
    test('a dragged point is persisted in map space', () async {
      await seedMap();
      await seedRegion();

      final edited = await maps.moveRegionPoint(
        'region-north',
        1,
        const MapPosition(600, 420),
      );

      expect(edited.geometry.points[0], const MapPosition(100, 100));
      expect(edited.geometry.points[1], const MapPosition(600, 420));

      final stored = await maps.regionGeometry('region-north');
      expect(stored.points[1], const MapPosition(600, 420));

      final record = await maps.records.getRecord('region-north');
      final geometry = record!.fields['_map.geometry'] as Map;
      expect(geometry['kind'], 'bounds');
      expect((geometry['points'] as List), hasLength(2));
    });

    test('a dragged point is clamped into the map extent', () async {
      await seedMap(extent: const MapExtent(width: 500, height: 500));
      await seedRegion(
        geometry: const MapGeometry(
          kind: MapGeometryKind.bounds,
          points: [MapPosition(10, 10), MapPosition(100, 100)],
        ),
      );

      final edited = await maps
          .moveRegionPoint('region-north', 1, const MapPosition(9000, -9000));
      expect(edited.geometry.points[1], const MapPosition(500, 0));
    });

    test('a point that does not exist is refused', () async {
      await seedMap();
      await seedRegion();
      expect(
        () => maps.moveRegionPoint('region-north', 7, MapPosition.origin),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('a bounds region becomes an editable polygon and back', () async {
      await seedMap();
      await seedRegion();

      final polygon =
          await maps.reshapeRegion('region-north', MapGeometryKind.polygon);
      expect(polygon.geometry.kind, MapGeometryKind.polygon);
      expect(polygon.geometry.points, hasLength(4));
      expect(polygon.geometry.points.first, const MapPosition(100, 100));

      final boxed =
          await maps.reshapeRegion('region-north', MapGeometryKind.bounds);
      expect(boxed.geometry.kind, MapGeometryKind.bounds);
      expect(boxed.geometry.bounds,
          const MapRect(left: 100, top: 100, right: 500, bottom: 300));
      expect(boxed.id, 'region-north');
    });

    test('polygon points can be added and removed through the service',
        () async {
      await seedMap();
      await seedRegion();
      await maps.reshapeRegion('region-north', MapGeometryKind.polygon);

      final added = await maps.addRegionPoint(
        'region-north',
        const MapPosition(300, 50),
        index: 1,
      );
      expect(added.geometry.points, hasLength(5));
      expect(added.geometry.points[1], const MapPosition(300, 50));

      final removed = await maps.removeRegionPoint('region-north', 1);
      expect(removed.geometry.points, hasLength(4));
      expect(removed.geometry.points[1], const MapPosition(500, 100));
    });

    test('a whole shape can be replaced in one write', () async {
      await seedMap();
      await seedRegion();

      final replaced = await maps.setRegionGeometry(
        'region-north',
        const MapGeometry(
          kind: MapGeometryKind.polygon,
          points: [
            MapPosition(0, 0),
            MapPosition(400, 0),
            MapPosition(200, 300),
          ],
        ),
      );

      expect(replaced.geometry.kind, MapGeometryKind.polygon);
      expect(replaced.geometry.points, hasLength(3));
      // The anchor follows the shape.
      expect(replaced.anchor, replaced.geometry.centre);
    });

    test('geometry edits keep the record and its history', () async {
      await seedMap();
      final region = await seedRegion();
      await maps.reshapeRegion('region-north', MapGeometryKind.polygon);
      await maps.moveRegionPoint('region-north', 0, const MapPosition(50, 50));

      final regions = await maps.regionsForMap('map-kingdom');
      expect(regions, hasLength(1));
      expect(regions.single.id, region.id);
      expect(regions.single.name, 'The Northern Reach');
      expect((await maps.mapHistory('region-north')).length,
          greaterThanOrEqualTo(3));
    });
  });

  group('inline editing', () {
    test('a renamed location keeps its id, position and links', () async {
      await seedMap();
      await seedLocation(position: const MapPosition(120, 240));
      final linksBefore = await maps.connections.outgoing('map-kingdom');

      final renamed = await maps.updateLocation(
        'city-endovier',
        name: 'Endovier Salt Mines',
        locationType: 'Prison',
      );

      expect(renamed.id, 'city-endovier');
      expect(renamed.name, 'Endovier Salt Mines');
      expect(renamed.locationType, 'Prison');
      expect(renamed.position, const MapPosition(120, 240));
      expect(await maps.connections.outgoing('map-kingdom'),
          hasLength(linksBefore.length));
    });

    test('a relabelled marker keeps its id, position and category', () async {
      await seedMap();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'Well',
          position: MapPosition(300, 300),
        ),
        timestamp: timestamp,
      );

      final renamed = await maps.updateMarker(
        'marker-well',
        label: 'The Salt Well',
        category: 'Landmark',
      );

      expect(renamed.id, 'marker-well');
      expect(renamed.label, 'The Salt Well');
      expect(renamed.category, 'Landmark');
      expect(renamed.position, const MapPosition(300, 300));
    });

    test('a name cannot be cleared from the canvas', () async {
      await seedMap();
      await seedLocation();
      expect(
        () => maps.updateLocation('city-endovier', name: '   '),
        throwsArgumentError,
      );
    });
  });

  group('project isolation', () {
    test('the editor never reaches another project\'s map', () async {
      final other = MapService(
        projectId: otherProjectId,
        repository: repository,
      );
      await seedMap();
      await seedLocation();
      await seedRegion();
      await seedMap(id: 'map-other', service: other);

      expect(await other.locationsForMap('map-other'), isEmpty);
      expect(
        () => other.moveLocation('city-endovier', const MapPosition(1, 1)),
        throwsA(isA<MapStudioException>()),
      );
      expect(
        () => other.moveRegionPoint('region-north', 0, MapPosition.origin),
        throwsA(isA<MapStudioException>()),
      );
      expect(
        () => other.reshapeRegion('region-north', MapGeometryKind.polygon),
        throwsA(isA<MapStudioException>()),
      );

      // And this project still holds exactly what it held.
      expect(await maps.locationsForMap('map-kingdom'), hasLength(1));
      expect(await maps.regionsForMap('map-kingdom'), hasLength(1));
    });
  });

  group('Phase 1 records stay readable', () {
    test('a Phase 1 record moves, reshapes and reloads unchanged in kind',
        () async {
      // Written exactly as Phase 1 wrote it: a bounds region and a plain pin.
      await seedMap();
      await seedRegion();
      await seedLocation();

      final canvas = await maps.loadCanvas('map-kingdom');
      expect(canvas.regions.single.geometry.kind, MapGeometryKind.bounds);
      expect(canvas.locations.single.position, const MapPosition(100, 100));

      await maps.moveLocation('city-endovier', const MapPosition(400, 400));
      await maps.moveRegionPoint('region-north', 0, const MapPosition(50, 50));

      final reloaded = await maps.loadCanvas('map-kingdom');
      expect(reloaded.locations.single.id, 'city-endovier');
      expect(reloaded.regions.single.id, 'region-north');
      expect(reloaded.regions.single.geometry.kind, MapGeometryKind.bounds);
      expect(reloaded.locations.single.position, const MapPosition(400, 400));
      expect(reloaded.regions.single.geometry.points.first,
          const MapPosition(50, 50));
    });
  });
}
