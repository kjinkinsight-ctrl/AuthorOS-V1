import 'dart:io';

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/world_record_types.dart';
import 'package:author_studio_v1/map_overlay_service.dart';
import 'package:author_studio_v1/map_presentation_service.dart';
import 'package:author_studio_v1/map_world_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Architecture guards for Map Studio Phase 1.
///
/// Map Studio must reuse AuthorOS architecture rather than grow a parallel one:
/// one persistence layer, one Theme Engine, one record vocabulary, and a service
/// that owns the business rules the widgets must not.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const mapFiles = <String>[
    'lib/map_domain.dart',
    'lib/map_service.dart',
    'lib/map_studio_view.dart',
    // Phase 3 terrain, biomes, scenery and styling. In this list from the day
    // it was written: every guardrail below applies to it too.
    'lib/map_terrain.dart',
    // Phase 4 story overlays. Also here from the day they were written: an
    // overlay is a reading of canonical data, so every rule about stores,
    // themes and vocabularies applies to it unchanged.
    'lib/map_overlays.dart',
    'lib/map_overlay_service.dart',
    // Phase 5 world state, territories, routes and travel. Same rules again: a
    // world state is a reading, so it may own no store, no theme and no
    // vocabulary of its own.
    'lib/map_world.dart',
    'lib/map_world_service.dart',
    // Phase 6 presentation, reader maps and export. In the list from the day
    // they were written, like every phase before them.
    'lib/map_presentation.dart',
    'lib/map_reader.dart',
    'lib/map_presentation_service.dart',
    'lib/map_export.dart',
    'lib/map_presentation_view.dart',
  ];

  group('one persistence system', () {
    test('Map Studio declares no store, database or repository of its own', () {
      for (final path in mapFiles) {
        final source = read(path);
        for (final banned in const [
          'class MapRepository',
          'class MapDatabase',
          'class MapStore',
          'MapSharedPreferences',
          'MapHive',
          'MapSQLite',
          'MapDrift',
        ]) {
          expect(source, isNot(contains(banned)), reason: '$path declares $banned');
        }
      }
    });

    test('no Map Studio file reaches SharedPreferences', () {
      for (final path in mapFiles) {
        expect(
          read(path),
          isNot(contains('SharedPreferences')),
          reason: '$path stores map data outside the record layer',
        );
      }
    });

    test('only the service touches the database, and only to bind to it', () {
      // The domain is plain Dart and the view knows nothing about storage.
      expect(read('lib/map_domain.dart'), isNot(contains('persistence/')));
      expect(read('lib/map_studio_view.dart'), isNot(contains('persistence/')));
      expect(read('lib/map_studio_view.dart'), isNot(contains('drift')));

      // The service reaches the database through the one shared repository.
      final service = read('lib/map_service.dart');
      expect(service, contains('DriftConnectedDomainRepository'));
      expect(service, contains('authorOsRepository'));
      expect(service, isNot(contains('AuthorOsDatabase(')));
      expect(service, isNot(contains('package:drift')));
      expect(service, isNot(contains('database.select')));
    });

    test('every write goes through RecordService or the ConnectionEngine', () {
      final service = read('lib/map_service.dart');
      expect(service, contains('RecordService'));
      expect(service, contains('ConnectionEngine'));
      // Reads may use the shared repository; writes may not.
      expect(service, isNot(contains('repository.putRecord')));
      expect(service, isNot(contains('repository.deleteRecord')));
    });
  });

  group('one theme system', () {
    test('Map Studio builds no theme of its own', () {
      for (final path in mapFiles) {
        final source = read(path);
        for (final banned in const [
          'class MapTheme',
          'class MapThemeData',
          'class MapColors',
          'class MapThemeScope',
          'ThemeData(',
        ]) {
          expect(source, isNot(contains(banned)), reason: '$path declares $banned');
        }
      }
    });

    test('no Map Studio file hard-codes a colour', () {
      for (final path in mapFiles) {
        final source = read(path);
        expect(source, isNot(contains('Color(0x')), reason: path);
        expect(source, isNot(contains('Colors.')), reason: path);
      }
    });

    test('the view resolves colour through the engine scope', () {
      final view = read('lib/map_studio_view.dart');
      expect(view, contains('StudioThemeScope'));
      expect(view, contains('ThemeColorRef.'));
      expect(view, contains('ThemeTextRole.'));
      expect(view, contains('StudioId.map'));
    });

    test('the domain and the service stay clear of Flutter', () {
      expect(read('lib/map_domain.dart'), isNot(contains('package:flutter/')));
      expect(read('lib/map_service.dart'), isNot(contains('package:flutter/')));
    });
  });

  group('MapService is the business layer', () {
    test('the view issues no record or link writes itself', () {
      final view = read('lib/map_studio_view.dart');
      expect(view, contains('MapService'));
      for (final banned in const [
        'AuthorRecord(',
        'RecordService',
        'ConnectionEngine',
        'createRecord',
        'updateRecord',
        'archiveRecord',
        'connect(',
      ]) {
        expect(view, isNot(contains(banned)), reason: 'the view calls $banned');
      }
    });

    test('the service owns the whole Phase 1 vocabulary', () {
      final service = read('lib/map_service.dart');
      for (final api in const [
        'createMap',
        'getMap',
        'listMaps',
        'updateMap',
        'archiveMap',
        'deleteMap',
        'createLocation',
        'updateLocation',
        'deleteLocation',
        'createRegion',
        'updateRegion',
        'deleteRegion',
        'createMarker',
        'updateMarker',
        'deleteMarker',
        'loadCanvas',
      ]) {
        expect(service, contains(api), reason: 'MapService lacks $api');
      }
    });
  });

  group('one record vocabulary', () {
    test('Map Studio reuses the existing World record types', () {
      final ids = BuiltInRecordTypes.definitions.map((type) => type.id).toSet();
      expect(ids, containsAll(<String>['map', 'location', 'region', 'map-marker']));
      expect(WorldRecordTypes.mapTypeIds, contains(MapTypes.map));
      expect(WorldRecordTypes.locationTypeIds, contains(MapTypes.location));
      expect(WorldRecordTypes.worldDomainTypeIds, contains(MapTypes.marker));
    });

    test('Map Studio declares no record type of its own', () {
      for (final path in mapFiles) {
        expect(
          read(path),
          isNot(contains('RecordTypeDefinition(')),
          reason: '$path invents a record type',
        );
      }
    });

    test('the placement fields live under one reserved namespace', () {
      expect(MapFields.prefix, '_map.');
      for (final field in const [MapFields.mapId, MapFields.x, MapFields.y, MapFields.geometry]) {
        expect(field, startsWith(MapFields.prefix));
      }
    });

    test('Map Studio uses the existing link vocabulary', () {
      expect(MapTypes.placedOn, 'maps');
      expect(MapTypes.markerOnMap, 'onMap');
      expect(MapTypes.markerRepresents, 'represents');
    });
  });

  group('positions are resolution independent', () {
    test('nothing in the domain assumes a pixel size', () {
      final domain = read('lib/map_domain.dart');
      expect(domain, isNot(contains('MediaQuery')));
      expect(domain, isNot(contains('Size(')));
      expect(domain, contains('MapProjection'));
      expect(domain, contains('MapCamera'));
    });

    test('a stored position projects onto any canvas size', () {
      const position = MapPosition(500, 250);
      const extent = MapExtent(width: 1000, height: 500);

      const small = MapProjection(
        extent: extent,
        canvasWidth: 200,
        canvasHeight: 100,
      );
      const large = MapProjection(
        extent: extent,
        canvasWidth: 1600,
        canvasHeight: 800,
      );

      expect(small.toCanvas(position), const MapPosition(100, 50));
      expect(large.toCanvas(position), const MapPosition(800, 400));
      // The same fraction of the map either way.
      expect(position.normalizedIn(extent), const MapPosition(0.5, 0.5));
    });

    test('a projection round-trips canvas coordinates back into map space', () {
      const projection = MapProjection(
        extent: MapExtent(width: 1000, height: 500),
        canvasWidth: 400,
        canvasHeight: 200,
      );
      expect(projection.toMap(200, 100), const MapPosition(500, 250));
    });

    test('a camera can reframe the canvas without moving what is stored', () {
      const position = MapPosition(500, 250);
      const zoomed = MapProjection(
        extent: MapExtent(width: 1000, height: 500),
        canvasWidth: 1000,
        canvasHeight: 500,
        camera: MapCamera(scale: 2, offset: MapPosition(250, 125)),
      );
      expect(zoomed.toCanvas(position), const MapPosition(500, 250));
      expect(zoomed.toMap(500, 250), position);
    });
  });

  group('World Board compatibility', () {
    late AuthorOsDatabase database;
    late MapService maps;
    late WorldService worlds;

    setUp(() {
      database = AuthorOsDatabase(NativeDatabase.memory());
      final repository = DriftConnectedDomainRepository(database);
      maps = MapService(projectId: 'project-map', repository: repository);
      worlds = WorldService(projectId: 'project-map', repository: repository);
    });

    tearDown(() => database.close());

    test('a Map Studio map is the same record World Studio already reads',
        () async {
      await maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: DateTime.utc(2026, 8, 21),
      );
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: DateTime.utc(2026, 8, 21),
      );

      // One source of truth: no second copy, no second store.
      expect((await worlds.getWorldRecord('map-kingdom'))?.title, 'Kingdom Map');
      expect((await worlds.getWorldRecord('city-endovier'))?.title, 'Endovier');
      expect(
        (await worlds.mapsFor('city-endovier')).map((record) => record.id),
        contains('map-kingdom'),
      );
    });

    test('a marker authored here is a marker World Studio can resolve',
        () async {
      await maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: DateTime.utc(2026, 8, 21),
      );
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
        ),
        timestamp: DateTime.utc(2026, 8, 21),
      );
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-endovier',
          mapId: 'map-kingdom',
          label: 'Endovier',
          position: MapPosition(250, 400),
          linkedRecordId: 'city-endovier',
        ),
        timestamp: DateTime.utc(2026, 8, 21),
      );

      final markers = await worlds.markersForMap('map-kingdom');
      expect(markers.single.displayLabel, 'Endovier');
      expect(markers.single.targetId, 'city-endovier');
      expect(markers.single.withinBounds, isTrue);
    });
  });

  group('Phase 2 editor architecture', () {
    test('the editor adds no store, no cache and no file of its own', () {
      for (final path in mapFiles) {
        final source = read(path);
        for (final banned in const [
          'class MapRepository',
          'class MapDatabase',
          'class MapStore',
          'class MapCameraStore',
          'class MapEditorStore',
          'class MapCache',
          'SharedPreferences',
          'dart:io',
          'File(',
          'Hive',
          'localStorage',
          'jsonEncode',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path introduces $banned');
        }
      }
    });

    test('the editor writes through the Phase 2 service vocabulary', () {
      final service = read('lib/map_service.dart');
      for (final api in const [
        'moveLocation',
        'moveMarker',
        'moveRegion',
        'setRegionGeometry',
        'moveRegionPoint',
        'addRegionPoint',
        'removeRegionPoint',
        'reshapeRegion',
        'regionGeometry',
      ]) {
        expect(service, contains(api), reason: 'MapService lacks $api');
      }
      // Still through the shared layers, still no repository writes.
      expect(service, contains('RecordService'));
      expect(service, contains('ConnectionEngine'));
      expect(service, isNot(contains('repository.putRecord')));
      expect(service, isNot(contains('repository.deleteRecord')));
    });

    test('the view still issues no record or link write itself', () {
      final view = read('lib/map_studio_view.dart');
      for (final banned in const [
        'AuthorRecord(',
        'RecordService',
        'ConnectionEngine',
        'createRecord',
        'updateRecord',
        'archiveRecord',
        'deleteRecord',
        'connect(',
      ]) {
        expect(view, isNot(contains(banned)), reason: 'the view calls $banned');
      }
    });

    test('the camera never reaches the service, and no pixel is ever stored',
        () {
      final service = read('lib/map_service.dart');
      // The service has no idea a camera exists; that is what keeps zoom and
      // pan out of the persistence model.
      expect(service, isNot(contains('MapCamera')));
      expect(service, isNot(contains('camera')));
      for (final banned in const [
        'screenX',
        'screenY',
        'pixelX',
        'pixelY',
        'canvasX',
        'canvasY',
        'viewportOffset',
        'widgetX',
        'devicePixelRatio',
        'Offset(',
      ]) {
        expect(service, isNot(contains(banned)),
            reason: 'MapService touches $banned');
      }
      // Every field the Studio owns is map space under one namespace.
      for (final field in const [
        MapFields.mapId,
        MapFields.x,
        MapFields.y,
        MapFields.geometry,
      ]) {
        expect(field, startsWith(MapFields.prefix));
      }
    });

    test('zoom and pan are camera arithmetic, not a second canvas', () {
      final view = read('lib/map_studio_view.dart');
      final domain = read('lib/map_domain.dart');
      expect(view, contains('MapProjection'));
      expect(view, contains('MapCamera'));
      expect(domain, contains('zoomedTo'));
      expect(domain, contains('pannedBy'));
      for (final banned in const [
        'InteractiveViewer',
        'Transform.scale',
        'TransformationController',
        'MatrixGestureDetector',
      ]) {
        expect(view, isNot(contains(banned)),
            reason: 'the canvas reaches for $banned');
      }
    });

    test('the draw order is one declared order', () {
      // Phase 3 inserted two layers. Terrain sits directly above the ground
      // because it is what the world is made of; scenery sits above regions so
      // a forest reads over its territory, and below the pins that name places.
      // Phase 4 added two more: story paths draw beneath the overlays whose
      // stops they join, and both sit above the world they are read against and
      // below selection, which must always stay visible. Phase 5 added borders
      // over the ground they divide, and routes over the scenery but under the
      // places they join.
      expect(MapLayer.values.map((layer) => layer.name), [
        'base',
        'terrain',
        'regions',
        'borders',
        'assets',
        'worldRoutes',
        'locations',
        'markers',
        'storyPaths',
        'storyOverlays',
        'selection',
        'interaction',
      ]);
      // The canvas walks the enum rather than hand-ordering a stack.
      expect(read('lib/map_studio_view.dart'), contains('MapLayer.values'));
    });

    test('the editor vocabulary lives in the domain, not the widget', () {
      final domain = read('lib/map_domain.dart');
      for (final api in const [
        'enum MapEditorTool',
        'enum MapLayer',
        'class MapRect',
        'class MapMarquee',
        'MapPlacementKind',
      ]) {
        expect(domain, contains(api), reason: 'the domain lacks $api');
      }
      // And it is still plain Dart.
      expect(domain, isNot(contains('package:flutter/')));
    });

    test('selection is UI state and is never persisted', () {
      final service = read('lib/map_service.dart');
      expect(service, isNot(contains('MapSelection')));
      expect(service, isNot(contains('marquee')));
      expect(service, isNot(contains('selectedIds')));
    });

    test('the Studio still resolves every colour through the engine', () {
      for (final path in mapFiles) {
        final source = read(path);
        expect(source, isNot(contains('Color(0x')), reason: path);
        expect(source, isNot(contains('Colors.')), reason: path);
        expect(source, isNot(contains('ThemeData(')), reason: path);
        expect(source, isNot(contains('MapThemeScope')), reason: path);
      }
      final view = read('lib/map_studio_view.dart');
      expect(view, contains('StudioThemeScope'));
      expect(view, contains('StudioId.map'));
      expect(view, contains('ThemeColorRef.'));
      expect(view, contains('ThemeTextRole.'));
    });
  });

  group('Phase 3 — terrain, scenery and styling', () {
    test('the visual domain stays plain Dart and store-free', () {
      final domain = read('lib/map_terrain.dart');
      expect(domain, isNot(contains('package:flutter/')),
          reason: 'the visual domain must resolve without a Flutter binding');
      for (final banned in const [
        'SharedPreferences',
        'dart:io',
        'jsonEncode',
        'class MapAssetRepository',
        'class MapTerrainStore',
        'class MapAssetDatabase',
        'package:drift',
      ]) {
        expect(domain, isNot(contains(banned)),
            reason: 'map_terrain.dart introduces $banned');
      }
    });

    test('Phase 3 stores everything under the one reserved namespace', () {
      for (final field in const [
        MapVisualFields.terrain,
        MapVisualFields.biomes,
        MapVisualFields.assets,
        MapVisualFields.style,
      ]) {
        expect(field, startsWith(MapFields.prefix));
      }
      // And invents no record type to hold any of it.
      expect(read('lib/map_terrain.dart'),
          isNot(contains('RecordTypeDefinition(')));
    });

    test('the service writes terrain and scenery through the record layer', () {
      final service = read('lib/map_service.dart');
      for (final api in const [
        'paintTerrainStroke',
        'fillTerrain',
        'clearTerrain',
        'setVisualStyle',
        'setBiomes',
        'addAsset',
        'moveAsset',
        'transformAsset',
        'removeAsset',
      ]) {
        expect(service, contains(api), reason: 'MapService lacks $api');
      }
      // Still the one persistence path Phase 1 established.
      expect(service, contains('RecordService'));
      expect(service, isNot(contains('repository.putRecord')));
      expect(service, isNot(contains('SharedPreferences')));
    });

    test('terrain colour is derived from the engine, never declared', () {
      final view = read('lib/map_studio_view.dart');
      final domain = read('lib/map_terrain.dart');
      // The domain carries no colour at all -- only the factors the view
      // rotates the engine's own colour by.
      expect(domain, isNot(contains('Color')));
      expect(domain, contains('hueShift'));
      // And the view derives rather than hard-codes.
      expect(view, contains('HSLColor'));
      expect(view, isNot(contains('Color(0x')));
      expect(view, isNot(contains('Colors.')));
    });

    test('scenery is not a graph entity and cannot become one', () {
      final domain = read('lib/map_terrain.dart');
      // An asset is a value in a field. If it ever gains a record type or a
      // link type, a densely painted map starts flooding the story graph.
      for (final banned in const [
        'AuthorRecord(',
        'RecordLink(',
        'ConnectionEngine',
        'connect(',
      ]) {
        expect(domain, isNot(contains(banned)),
            reason: 'scenery must never become a story entity: $banned');
      }
    });

    test('Phase 3 introduces no image generation and no asset fetching', () {
      for (final path in mapFiles) {
        final source = read(path);
        // The ban is on *fetching*, not on the four letters: Phase 6 writes
        // SVG, whose namespace is a URL. Named clients rather than a substring.
        for (final banned in const [
          'Image.network',
          'Image.file',
          'package:http',
          'HttpClient',
          'NetworkImage',
          'generateImage',
          'aiAsset',
          'promptFor',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path reaches outside the deterministic asset library');
        }
      }
    });

    test('the camera still owns zoom, and Phase 3 did not smuggle in another',
        () {
      final view = read('lib/map_studio_view.dart');
      for (final banned in const [
        'InteractiveViewer',
        'Transform.scale',
        'TransformationController',
      ]) {
        expect(view, isNot(contains(banned)));
      }
      expect(view, contains('MapProjection'));
      expect(view, contains('MapCamera'));
    });
  });

  group('Phase 4 — story overlays', () {
    test('the overlay layer owns no data of its own', () {
      for (final path in const [
        'lib/map_overlays.dart',
        'lib/map_overlay_service.dart',
      ]) {
        final source = read(path);
        for (final banned in const [
          'class OverlayStore',
          'class MapStoryGraph',
          'class MapCharacter ',
          'class MapEvent ',
          'class MapTimeline',
          'class MapScene ',
          'class MapWorldModel',
          'overlay_rows',
          'Table',
          'SharedPreferences',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path builds a second model of the story');
        }
      }
    });

    test('the overlay service is read-only by construction', () {
      final service = read('lib/map_overlay_service.dart');
      for (final banned in const [
        'createRecord',
        'updateRecord',
        'archiveRecord',
        'deleteRecord',
        'putRecord',
        'putManuscriptNodes',
        'removeManuscriptNodes',
        'RecordService',
        'ConnectionEngine',
        '.connect(',
        'disconnect',
        'Future<void> save',
      ]) {
        expect(service, isNot(contains(banned)),
            reason: 'the overlay service performs $banned');
      }
      // What it does do: read the shared repository.
      expect(service, contains('DriftConnectedDomainRepository'));
      expect(service, contains('repository.recordsByProject'));
      expect(service, contains('repository.backlinks'));
    });

    test('overlays point at the record that owns them', () {
      final domain = read('lib/map_overlays.dart');
      expect(domain, contains('sourceId'));
      expect(domain, contains('sourceType'));
      // No overlay may carry an edited copy of the record's own content.
      for (final banned in const [
        'set label',
        'set position',
        'Future<',
      ]) {
        expect(domain, isNot(contains(banned)),
            reason: 'the overlay domain does more than describe a reading');
      }
    });

    test('the overlay domain stays clear of Flutter', () {
      final domain = read('lib/map_overlays.dart');
      expect(domain, isNot(contains('package:flutter/')));
      expect(domain, isNot(contains('IconData')));
      expect(domain, isNot(contains('Widget')));
      // Shape, not colour, tells the categories apart, and the shape names live
      // in the domain while the glyphs live in the view.
      expect(domain, contains('shapeId'));
      expect(read('lib/map_studio_view.dart'), contains('_overlayIcon'));
    });

    test('every link the overlay layer reads is a canonical link type', () {
      final registry = BuiltInConnectionTypes.registry();
      for (final typeId in MapOverlayLinks.all) {
        expect(
          () => registry.resolve(typeId),
          returnsNormally,
          reason: '$typeId is not a link type AuthorOS already defines',
        );
      }
    });

    test('every type the overlay layer reads is a canonical record type', () {
      final registry = BuiltInRecordTypes.registry();
      final known = {
        for (final definition in registry.definitions) definition.id,
      };
      expect(known, contains(MapOverlayTypes.character));
      for (final typeId in MapOverlayTypes.events) {
        expect(known, contains(typeId),
            reason: '$typeId is not a record type AuthorOS already defines');
      }
    });

    test('scenes stay manuscript nodes and are never turned into records', () {
      final service = read('lib/map_overlay_service.dart');
      expect(service, contains('manuscriptNodeById'));
      for (final banned in const [
        "typeId: 'scene'",
        "typeId: 'chapter'",
        "'map-scene'",
        "'map-character'",
        "'map-event'",
        "'overlay-record'",
      ]) {
        expect(service, isNot(contains(banned)),
            reason: 'the overlay layer promotes a manuscript node into $banned');
      }
    });

    test('the Studio names a destination and routes to no other Studio', () {
      final view = read('lib/map_studio_view.dart');
      expect(view, contains('enum MapStudioDestination'));

      // The invariant is about *leaving* Map Studio: that is the shell's
      // decision, and the Studio only names where it would like to go. Phase 6
      // pushes a route of its own — presentation mode — which goes nowhere
      // else, so a blanket ban on Navigator would have forbidden the right
      // thing for the wrong reason.
      expect(view, isNot(contains('StudioSection')),
          reason: 'Map Studio names the shell own section enum');
      final routes = RegExp('MaterialPageRoute<[^>]*>\\(').allMatches(view);
      expect(routes, hasLength(1),
          reason: 'the only route Map Studio pushes is its own presentation '
              'mode');
      expect(view, contains('MapPresentationPage'));
    });

    test('the view reads overlays and writes none of them', () {
      final view = read('lib/map_studio_view.dart');
      for (final banned in const [
        'overlayService.create',
        'overlayService.update',
        'overlayService.save',
        'service.setOverlay',
        'service.saveOverlay',
        'MapOverlayItem(',
        'MapJourney(',
      ]) {
        expect(view, isNot(contains(banned)),
            reason: 'the view invents overlay data with $banned');
      }
      expect(view, contains('overlayService.loadOverlays'));
    });

    test('Phase 3 is still standing underneath the overlays', () {
      final view = read('lib/map_studio_view.dart');
      for (final api in const [
        '_TerrainPainter',
        '_assetIcon',
        'MapTerrainBrush',
        'MapVisualStyle',
        'onPaintStroke',
        'onPlaceAsset',
      ]) {
        expect(view, contains(api), reason: 'Phase 3 lost $api');
      }
    });
  });

  group('Phase 5 — world simulation', () {
    test('the world layer owns no world of its own', () {
      for (final path in const [
        'lib/map_world.dart',
        'lib/map_world_service.dart',
      ]) {
        final source = read(path);
        for (final banned in const [
          'class WorldStore',
          'class MapWorldDatabase',
          'class MapFaction ',
          'class MapCharacterRecord',
          'class MapTimelineEvent',
          'world_state_rows',
          'Table',
          'SharedPreferences',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path builds a second world model');
        }
      }
    });

    test('the world service is read-only by construction', () {
      final service = read('lib/map_world_service.dart');
      for (final banned in const [
        'createRecord',
        'updateRecord',
        'archiveRecord',
        'deleteRecord',
        'putRecord',
        'putManuscriptNodes',
        'RecordService',
        'ConnectionEngine',
        '.connect(',
        'disconnect',
        'Future<void> save',
      ]) {
        expect(service, isNot(contains(banned)),
            reason: 'the world service performs $banned');
      }
      expect(service, contains('repository.recordsByProject'));
      expect(service, contains('repository.backlinks'));
    });

    test('the world domain is deterministic and free of Flutter', () {
      final domain = read('lib/map_world.dart');
      expect(domain, isNot(contains('package:flutter/')));
      for (final banned in const [
        'Random(',
        'DateTime.now()',
        'Future<',
        'async',
      ]) {
        expect(domain, isNot(contains(banned)),
            reason: 'the world domain is not deterministic: $banned');
      }
    });

    test('every link the world layer reads is a canonical link type', () {
      final registry = BuiltInConnectionTypes.registry();
      for (final typeId in MapWorldLinks.all) {
        expect(() => registry.resolve(typeId), returnsNormally,
            reason: '$typeId is not a link type AuthorOS already defines');
      }
    });

    test('every type the world layer reads is a canonical record type', () {
      final registry = BuiltInRecordTypes.registry();
      final known = {
        for (final definition in registry.definitions) definition.id,
      };
      expect(known, contains(MapWorldTypes.resource));
      expect(known, contains(MapWorldTypes.border));
      for (final typeId in MapWorldTypes.factions) {
        expect(known, contains(typeId), reason: '$typeId is not a record type');
      }
      for (final typeId in MapWorldTypes.routes) {
        expect(known, contains(typeId), reason: '$typeId is not a record type');
      }
    });

    test('the world layer is scoped to one project throughout', () {
      final service = read('lib/map_world_service.dart');
      expect(service, contains('link.scopeId == projectId'));
      expect(service, contains('recordsByProject(projectId)'));
    });

    test('travel refuses rather than fabricates', () {
      final domain = read('lib/map_world.dart');
      expect(domain, contains('MapTravelEstimate.unavailable'));
      // The calculator returns null for a leg it cannot cost, and a leg it
      // cannot cost must not fall back to a default distance.
      expect(domain, isNot(contains('distance ?? ')));
      expect(domain, isNot(contains('statedTravelDays ?? ')));
    });

    test('the view reads the world and writes none of it', () {
      final view = read('lib/map_studio_view.dart');
      for (final banned in const [
        'worldService.create',
        'worldService.update',
        'worldService.save',
        'service.setTerritory',
        'service.setBorder',
        'MapWorldState(',
        'MapSettlement(',
        'MapTerritory(',
        'MapWorldRoute(',
      ]) {
        expect(view, isNot(contains(banned)),
            reason: 'the view invents world data with $banned');
      }
      expect(view, contains('worldService.loadWorldState'));
    });

    test('Phases 3 and 4 are still standing underneath', () {
      final view = read('lib/map_studio_view.dart');
      for (final api in const [
        '_TerrainPainter',
        '_assetIcon',
        '_overlayIcon',
        '_JourneyPainter',
        'overlayService.loadOverlays',
        'MapVisualStyle',
      ]) {
        expect(view, contains(api), reason: 'an earlier phase lost $api');
      }
    });
  });

  group('Phase 6 — presentation, export and reader maps', () {
    test('presentation owns no model of the world', () {
      for (final path in const [
        'lib/map_presentation.dart',
        'lib/map_reader.dart',
        'lib/map_export.dart',
      ]) {
        final source = read(path);
        for (final banned in const [
          'class PresentationStore',
          'class MapExportStore',
          'class ReaderMapStore',
          'class MapSnapshot',
          'export_rows',
          'reader_map_rows',
          'Table',
          'SharedPreferences',
          'DriftConnectedDomainRepository',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path builds a second representation of the world');
        }
      }
    });

    test('the presentation service is read-only by construction', () {
      final service = read('lib/map_presentation_service.dart');
      for (final banned in const [
        'createRecord',
        'updateRecord',
        'archiveRecord',
        'deleteRecord',
        'putRecord',
        'putManuscriptNodes',
        'RecordService',
        'ConnectionEngine',
        '.connect(',
        'disconnect',
      ]) {
        expect(service, isNot(contains(banned)),
            reason: 'the presentation service performs $banned');
      }
      expect(service, contains('repository.backlinks'));
    });

    test('spoiler filtering is enforced in the model, not the widgets', () {
      // The reader projection returns smaller canonical projections. A renderer
      // handed one cannot leak a hidden city because the city is not there.
      final reader = read('lib/map_reader.dart');
      expect(reader, contains('class MapReaderView'));
      expect(reader, contains('MapReaderProjection'));
      expect(reader, isNot(contains('Widget')));
      expect(reader, isNot(contains('Visibility(')));
      expect(reader, isNot(contains('package:flutter/')));
    });

    test('a reveal is the canonical relationship, and Phase 6 never writes it',
        () {
      final registry = BuiltInConnectionTypes.registry();
      expect(
        () => registry.resolve(MapPresentationLinks.revealedIn),
        returnsNormally,
      );
      for (final path in const [
        'lib/map_presentation.dart',
        'lib/map_reader.dart',
        'lib/map_presentation_service.dart',
        'lib/map_export.dart',
        'lib/map_presentation_view.dart',
        'lib/map_studio_view.dart',
      ]) {
        expect(read(path), isNot(contains("typeId: 'revealedIn'")),
            reason: '$path writes a reveal; Phase 6 only reads them');
      }
    });

    test('one drawing feeds every renderer', () {
      final export = read('lib/map_export.dart');
      // Each backend takes a MapDrawing. None of them reads the projections
      // directly, so none of them can disagree about what the map looks like.
      expect(export, contains('String render(MapDrawing drawing)'));
      expect(export, contains('Future<Uint8List> render(MapDrawing drawing'));
      expect(read('lib/map_presentation_view.dart'),
          contains('MapDrawingPainter'));
      for (final banned in const ['MapCanvasData canvas', 'MapWorldState world']) {
        expect(
          export.split('class MapSvgRenderer').last,
          isNot(contains(banned)),
          reason: 'a renderer reads the projections instead of the drawing',
        );
      }
    });

    test('export goes through the one saving abstraction', () {
      for (final path in const [
        'lib/map_export.dart',
        'lib/map_presentation_view.dart',
        'lib/map_studio_view.dart',
      ]) {
        final source = read(path);
        for (final banned in const [
          'dart:html',
          'File(',
          'getSaveLocation',
          'path_provider',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '$path saves files itself instead of using '
                  'ExportFileSaver');
        }
      }
      expect(read('lib/map_presentation_view.dart'),
          contains('ExportFileSaver'));
    });

    test('the export domain stays free of Flutter', () {
      for (final path in const [
        'lib/map_presentation.dart',
        'lib/map_reader.dart',
        'lib/map_export.dart',
      ]) {
        expect(read(path), isNot(contains('package:flutter/')), reason: path);
      }
      // Rasterising needs dart:ui, which is why PNG lives in the view file and
      // nowhere else.
      expect(read('lib/map_export.dart'), isNot(contains('dart:ui')));
      expect(read('lib/map_presentation_view.dart'), contains('dart:ui'));
    });

    test('no preset claims a colour space the code cannot produce', () {
      final export = read('lib/map_export.dart');
      expect(export.toLowerCase(), isNot(contains('cmyk-compatible')));
      expect(export, contains('sRGB'));
    });

    test('Phases 3, 4 and 5 are still standing underneath', () {
      final view = read('lib/map_studio_view.dart');
      for (final api in const [
        '_TerrainPainter',
        '_overlayIcon',
        '_JourneyPainter',
        'overlayService.loadOverlays',
        'worldService.loadWorldState',
        'presentationService.revealPoints',
      ]) {
        expect(view, contains(api), reason: 'an earlier phase lost $api');
      }
    });
  });

  group('phase boundary', () {
    test('the service exposes no later-phase entry point', () {
      final service = read('lib/map_service.dart');
      for (final api in const [
        // Terrain and brushes moved into scope with Phase 3, overlays with
        // Phase 4, world state with Phase 5. The boundary this test defends is
        // now Phase 6 and later -- and note that MapService still has no
        // overlay or world method of any kind, because both are read through
        // their own read-only services.
        'exportMap',
        'shareMap',
        'publishMap',
        'simulate',
        'characterOverlay',
        'timelineOverlay',
        'plotOverlay',
      ]) {
        expect(service, isNot(contains(api)), reason: 'MapService exposes $api');
      }
    });

    test('the canvas draws places and markers only', () {
      final view = read('lib/map_studio_view.dart');
      for (final banned in const [
        'Image.file',
        'Image.network',
        'Transform.scale',
        'InteractiveViewer',
        'PolygonEditor',
      ]) {
        expect(view, isNot(contains(banned)), reason: 'the canvas uses \$banned');
      }
    });

    test('no Phase 7 or later API has been introduced anywhere', () {
      // Phase 6 legitimately crossed the old line: presentation, export, reader
      // maps and spoiler filtering are in scope now, so those names are gone
      // from this list rather than the list being deleted. What is banned is
      // what is still ahead — a community, a marketplace, publishing to a
      // platform Map Studio does not have.
      for (final path in mapFiles) {
        final source = read(path);
        for (final banned in const [
          'publishToCommunity',
          'communityMap',
          'marketplace',
          'MapSubscription',
          'MapComment',
          'collaborator',
        ]) {
          expect(source, isNot(contains(banned)),
              reason: '\$path introduces the Phase 7+ API \$banned');
        }
      }
    });
  });
}
