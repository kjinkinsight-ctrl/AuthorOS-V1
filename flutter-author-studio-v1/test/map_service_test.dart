import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const projectId = 'project-map';
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
    String title = 'Kingdom Map',
    String description = 'The realm at the height of the Crown.',
  }) =>
      maps.createMap(
        MapDraft(id: id, title: title, description: description),
        timestamp: timestamp,
      );

  group('maps', () {
    test('a created map is a project-scoped Universal Record', () async {
      final map = await seedMap();

      expect(map.id, 'map-kingdom');
      expect(map.title, 'Kingdom Map');
      expect(map.description, 'The realm at the height of the Crown.');
      expect(map.isActive, isTrue);
      expect(map.extent, MapExtent.standard);

      final record = await maps.records.getRecord('map-kingdom');
      expect(record, isNotNull);
      expect(record!.typeId, 'map');
      expect(record.projectId, projectId);
      expect(record.scopeType, RecordScopeType.project);
      expect(record.extensionData['mapStudio'], isTrue);
    });

    test('a map without an id or a title is refused', () async {
      expect(
        () => maps.createMap(const MapDraft(id: '', title: 'Nameless')),
        throwsArgumentError,
      );
      expect(
        () => maps.createMap(const MapDraft(id: 'map-x', title: '  ')),
        throwsArgumentError,
      );
    });

    test('a non-map record type is refused', () async {
      expect(
        () => maps.createMap(
          const MapDraft(id: 'map-x', title: 'Wrong', typeId: 'character'),
        ),
        throwsArgumentError,
      );
    });

    test('getMap returns the map and ignores non-maps', () async {
      await seedMap();
      expect((await maps.getMap('map-kingdom'))?.title, 'Kingdom Map');
      expect(await maps.getMap('does-not-exist'), isNull);

      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      expect(await maps.getMap('city-endovier'), isNull);
    });

    test('listMaps returns active maps in title order', () async {
      await seedMap(id: 'map-world', title: 'World Map');
      await seedMap(id: 'map-city', title: 'City Map');
      await seedMap(id: 'map-kingdom', title: 'Kingdom Map');

      expect(
        (await maps.listMaps()).map((map) => map.title),
        ['City Map', 'Kingdom Map', 'World Map'],
      );
    });

    test('updateMap rewrites the metadata surface', () async {
      await seedMap();
      final updated = await maps.updateMap(
        'map-kingdom',
        title: 'Kingdom of Ash',
        description: 'After the war.',
        extent: const MapExtent(width: 2000, height: 1200),
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      expect(updated.title, 'Kingdom of Ash');
      expect(updated.description, 'After the war.');
      expect(updated.extent, const MapExtent(width: 2000, height: 1200));

      final reread = await maps.getMap('map-kingdom');
      expect(reread!.title, 'Kingdom of Ash');
      expect(reread.record.fields['primaryName'], 'Kingdom of Ash');
    });

    test('a map title cannot be cleared and an extent must be positive',
        () async {
      await seedMap();
      expect(
        () => maps.updateMap('map-kingdom', title: '   '),
        throwsArgumentError,
      );
      expect(
        () => maps.updateMap(
          'map-kingdom',
          extent: const MapExtent(width: 0, height: 10),
        ),
        throwsArgumentError,
      );
    });

    test('archiving hides a map from the list without erasing it', () async {
      await seedMap();
      await maps.archiveMap('map-kingdom', timestamp: timestamp);

      expect(await maps.listMaps(), isEmpty);
      final archived = await maps.listMaps(includeArchived: true);
      expect(archived.single.isArchived, isTrue);

      await maps.restoreMap('map-kingdom', timestamp: timestamp);
      expect((await maps.listMaps()).single.isActive, isTrue);
    });

    test('deleting a map is the shared soft delete', () async {
      await seedMap();
      await maps.deleteMap('map-kingdom', timestamp: timestamp);

      expect(await maps.listMaps(includeArchived: true), isEmpty);
      final record = await maps.records.getRecord('map-kingdom');
      expect(record!.status, AuthorRecordStatus.deleted);
    });

    test('map edits are written to the shared version history', () async {
      await seedMap();
      await maps.updateMap('map-kingdom', description: 'Redrawn.');

      final versions = await maps.mapHistory('map-kingdom');
      expect(versions.length, greaterThanOrEqualTo(2));
    });
  });

  group('locations', () {
    test('a location is placed on its map and linked to it', () async {
      await seedMap();
      final location = await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          description: 'The salt city.',
          locationType: 'City',
          position: MapPosition(250, 400),
        ),
        timestamp: timestamp,
      );

      expect(location.name, 'Endovier');
      expect(location.mapId, 'map-kingdom');
      expect(location.position, const MapPosition(250, 400));
      expect(location.locationType, 'City');

      final links = await maps.connections.outgoing('map-kingdom');
      expect(
        links.where((link) =>
            link.typeId == 'maps' && link.targetId == 'city-endovier'),
        hasLength(1),
      );
    });

    test('a location defaults to the centre of its map', () async {
      await seedMap();
      final location = await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      expect(location.position, MapExtent.standard.centre);
    });

    test('a position outside the map extent is clamped into it', () async {
      await seedMap();
      final location = await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          position: MapPosition(5000, -40),
        ),
        timestamp: timestamp,
      );
      expect(location.position, const MapPosition(1000, 0));
    });

    test('a location on a map that does not exist is refused', () async {
      expect(
        () => maps.createLocation(
          const MapLocationDraft(
            id: 'city-endovier',
            mapId: 'no-such-map',
            name: 'Endovier',
          ),
        ),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('updateLocation rewrites name, description, type and position',
        () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      final updated = await maps.updateLocation(
        'city-endovier',
        name: 'Endovier Ruins',
        description: 'Burned in the Ash War.',
        locationType: 'Ruin',
        position: const MapPosition(120, 340),
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      expect(updated.name, 'Endovier Ruins');
      expect(updated.description, 'Burned in the Ash War.');
      expect(updated.locationType, 'Ruin');
      expect(updated.position, const MapPosition(120, 340));
      expect(updated.mapId, 'map-kingdom');
    });

    test('moveLocation stores the new position', () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      final moved = await maps.moveLocation(
        'city-endovier',
        const MapPosition(10, 20),
        timestamp: timestamp,
      );
      expect(moved.position, const MapPosition(10, 20));
    });

    test('locationsForMap only returns places on that map', () async {
      await seedMap();
      await seedMap(id: 'map-city', title: 'City Map');
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      await maps.createLocation(
        const MapLocationDraft(
          id: 'district-salt',
          mapId: 'map-city',
          name: 'Salt District',
        ),
        timestamp: timestamp,
      );

      expect(
        (await maps.locationsForMap('map-kingdom')).map((item) => item.name),
        ['Endovier'],
      );
      expect(
        (await maps.locationsForMap('map-city')).map((item) => item.name),
        ['Salt District'],
      );
    });

    test('archived and deleted locations leave the canvas', () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      await maps.archiveLocation('city-endovier', timestamp: timestamp);
      expect(await maps.locationsForMap('map-kingdom'), isEmpty);
      expect(
        await maps.locationsForMap('map-kingdom', includeArchived: true),
        hasLength(1),
      );

      await maps.deleteLocation('city-endovier', timestamp: timestamp);
      expect(
        await maps.locationsForMap('map-kingdom', includeArchived: true),
        isEmpty,
      );
    });
  });

  group('regions', () {
    test('a region stores its geometry and anchors on its centre', () async {
      await seedMap();
      final region = await maps.createRegion(
        MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
          description: 'Snow and salt.',
          category: 'Territory',
          geometry: MapGeometry.box(
            const MapPosition(100, 100),
            const MapPosition(500, 300),
          ),
        ),
        timestamp: timestamp,
      );

      expect(region.name, 'The Northern Reach');
      expect(region.category, 'Territory');
      expect(region.geometry.kind, MapGeometryKind.bounds);
      expect(region.geometry.points, hasLength(2));
      expect(region.anchor, const MapPosition(300, 200));
      expect(region.record.typeId, 'region');
    });

    test('a region with no geometry still anchors on the map', () async {
      await seedMap();
      final region = await maps.createRegion(
        const MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
        ),
        timestamp: timestamp,
      );
      expect(region.geometry.isEmpty, isTrue);
      expect(region.anchor, MapExtent.standard.centre);
    });

    test('region geometry is clamped into the map extent', () async {
      await seedMap();
      final region = await maps.createRegion(
        MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
          geometry: MapGeometry.box(
            const MapPosition(-50, -50),
            const MapPosition(4000, 4000),
          ),
        ),
        timestamp: timestamp,
      );
      expect(region.geometry.points.first, const MapPosition(0, 0));
      expect(region.geometry.points.last, const MapPosition(1000, 1000));
    });

    test('updateRegion rewrites the shape and the anchor', () async {
      await seedMap();
      await maps.createRegion(
        const MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
        ),
        timestamp: timestamp,
      );
      final updated = await maps.updateRegion(
        'region-north',
        name: 'The Reach',
        category: 'Province',
        geometry: MapGeometry.box(
          const MapPosition(0, 0),
          const MapPosition(200, 200),
        ),
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      expect(updated.name, 'The Reach');
      expect(updated.category, 'Province');
      expect(updated.anchor, const MapPosition(100, 100));
    });

    test('regionsForMap honours archive state', () async {
      await seedMap();
      await maps.createRegion(
        const MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
        ),
        timestamp: timestamp,
      );
      expect(await maps.regionsForMap('map-kingdom'), hasLength(1));

      await maps.archiveRegion('region-north', timestamp: timestamp);
      expect(await maps.regionsForMap('map-kingdom'), isEmpty);
      expect(
        await maps.regionsForMap('map-kingdom', includeArchived: true),
        hasLength(1),
      );
    });
  });

  group('markers', () {
    test('a marker is stored, positioned and linked to its map', () async {
      await seedMap();
      final marker = await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          category: 'Landmark',
          notes: 'Where the rebellion began.',
          position: MapPosition(600, 200),
        ),
        timestamp: timestamp,
      );

      expect(marker.label, 'The Salt Well');
      expect(marker.category, 'Landmark');
      expect(marker.notes, 'Where the rebellion began.');
      expect(marker.position, const MapPosition(600, 200));
      expect(marker.linkedRecordId, isNull);

      final links = await maps.connections.outgoing('marker-well');
      expect(links.single.typeId, 'onMap');
      expect(links.single.targetId, 'map-kingdom');
    });

    test('a marker may point at another record', () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      final marker = await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-endovier',
          mapId: 'map-kingdom',
          label: 'Endovier',
          linkedRecordId: 'city-endovier',
        ),
        timestamp: timestamp,
      );

      expect(marker.linkedRecordId, 'city-endovier');
      final links = await maps.connections.outgoing('marker-endovier');
      expect(
        links.map((link) => link.typeId),
        containsAll(<String>['onMap', 'represents']),
      );
    });

    test('a marker pointing at a record outside the project is refused',
        () async {
      await seedMap();
      expect(
        () => maps.createMarker(
          const MapMarkerDraft(
            id: 'marker-ghost',
            mapId: 'map-kingdom',
            label: 'Ghost',
            linkedRecordId: 'not-here',
          ),
        ),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('updateMarker rewrites the label, notes and position', () async {
      await seedMap();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
        ),
        timestamp: timestamp,
      );
      final updated = await maps.updateMarker(
        'marker-well',
        label: 'The Dry Well',
        notes: 'Sealed after the war.',
        category: 'Ruin',
        position: const MapPosition(42, 84),
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      expect(updated.label, 'The Dry Well');
      expect(updated.notes, 'Sealed after the war.');
      expect(updated.category, 'Ruin');
      expect(updated.position, const MapPosition(42, 84));
    });

    test('moveMarker clamps into the map extent', () async {
      await seedMap();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
        ),
        timestamp: timestamp,
      );
      final moved = await maps.moveMarker(
        'marker-well',
        const MapPosition(-10, 9999),
        timestamp: timestamp,
      );
      expect(moved.position, const MapPosition(0, 1000));
    });

    test('markersForMap honours archive and delete state', () async {
      await seedMap();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
        ),
        timestamp: timestamp,
      );
      expect(await maps.markersForMap('map-kingdom'), hasLength(1));

      await maps.archiveMarker('marker-well', timestamp: timestamp);
      expect(await maps.markersForMap('map-kingdom'), isEmpty);
      expect(
        await maps.markersForMap('map-kingdom', includeArchived: true),
        hasLength(1),
      );

      await maps.deleteMarker('marker-well', timestamp: timestamp);
      expect(
        await maps.markersForMap('map-kingdom', includeArchived: true),
        isEmpty,
      );
    });
  });

  group('canvas', () {
    test('loadCanvas gathers the map with its places and markers', () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: timestamp,
      );
      await maps.createRegion(
        const MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
        ),
        timestamp: timestamp,
      );
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
        ),
        timestamp: timestamp,
      );

      final canvas = await maps.loadCanvas('map-kingdom');
      expect(canvas.map.title, 'Kingdom Map');
      expect(canvas.locations, hasLength(1));
      expect(canvas.regions, hasLength(1));
      expect(canvas.markers, hasLength(1));
      expect(canvas.isEmpty, isFalse);
      expect(canvas.extent, MapExtent.standard);
    });

    test('an unknown map is refused rather than returning an empty canvas',
        () async {
      expect(
        () => maps.loadCanvas('no-such-map'),
        throwsA(isA<MapStudioException>()),
      );
    });
  });

  group('projects', () {
    test('one project never reads another project\'s maps', () async {
      await seedMap();
      final other = MapService(
        projectId: 'project-other',
        repository: repository,
      );
      expect(await other.listMaps(), isEmpty);
      expect(await other.getMap('map-kingdom'), isNull);
    });
  });

  group('persistence', () {
    test('maps, places and markers survive reopening the database', () async {
      final directory = await Directory.systemTemp.createTemp('map_studio');
      addTearDown(() => directory.delete(recursive: true));
      final file =
          File('${directory.path}${Platform.pathSeparator}map.sqlite');

      var db = AuthorOsDatabase(NativeDatabase(file));
      var service = MapService(
        projectId: projectId,
        repository: DriftConnectedDomainRepository(db),
      );
      await service.createMap(
        const MapDraft(
          id: 'map-kingdom',
          title: 'Kingdom Map',
          description: 'The realm.',
        ),
        timestamp: timestamp,
      );
      await service.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          position: MapPosition(250, 400),
        ),
        timestamp: timestamp,
      );
      await service.createRegion(
        MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The Northern Reach',
          geometry: MapGeometry.box(
            const MapPosition(100, 100),
            const MapPosition(500, 300),
          ),
        ),
        timestamp: timestamp,
      );
      await service.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          position: MapPosition(600, 200),
        ),
        timestamp: timestamp,
      );
      await db.close();

      db = AuthorOsDatabase(NativeDatabase(file));
      service = MapService(
        projectId: projectId,
        repository: DriftConnectedDomainRepository(db),
      );
      final canvas = await service.loadCanvas('map-kingdom');
      await db.close();

      expect(canvas.map.title, 'Kingdom Map');
      expect(canvas.map.description, 'The realm.');
      expect(canvas.locations.single.position, const MapPosition(250, 400));
      expect(canvas.regions.single.anchor, const MapPosition(300, 200));
      expect(canvas.markers.single.position, const MapPosition(600, 200));
    });
  });
}
