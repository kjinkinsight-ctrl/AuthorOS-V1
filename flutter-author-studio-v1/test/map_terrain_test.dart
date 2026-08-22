import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map Studio Phase 3 — terrain, biomes, scenery and styling.
///
/// Every position here is map space. The one thing these tests never allow is a
/// pixel reaching a record.
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

  // ------------------------------------------------------- terrain domain ---

  group('the terrain grid is map space', () {
    const extent = MapExtent(width: 1000, height: 500);

    test('a cell maps to the part of the map it covers', () {
      final grid = MapTerrainGrid.empty(columns: 10, rows: 5);

      expect(grid.cellFor(const MapPosition(0, 0), extent), (0, 0));
      expect(grid.cellFor(const MapPosition(550, 250), extent), (5, 2));
      // The far edge clamps in rather than falling out, so painting the
      // boundary works.
      expect(grid.cellFor(const MapPosition(1000, 500), extent), (9, 4));

      expect(grid.rectFor(0, 0, extent),
          const MapRect(left: 0, top: 0, right: 100, bottom: 100));
      expect(grid.centreOf(0, 0, extent), const MapPosition(50, 50));
    });

    test('the same grid describes the same ground at any resolution', () {
      // A grid is a fraction of the extent, never a pixel count: doubling the
      // map's declared size moves the same cell to twice the coordinates.
      final grid = MapTerrainGrid.empty(columns: 4, rows: 4);
      expect(grid.centreOf(1, 1, const MapExtent(width: 400, height: 400)),
          const MapPosition(150, 150));
      expect(grid.centreOf(1, 1, const MapExtent(width: 800, height: 800)),
          const MapPosition(300, 300));
    });

    test('a brush paints in map units, not pixels', () {
      final grid = MapTerrainGrid.empty(columns: 10, rows: 10);
      const square = MapExtent(width: 1000, height: 1000);
      const brush = MapTerrainBrush(kind: MapTerrainKind.forest, radius: 120);

      final painted =
          grid.painted(brush, const MapPosition(500, 500), square);

      // The cell under the brush centre is painted; one four hundred units
      // away is not.
      expect(painted.kindAt(5, 5), MapTerrainKind.forest);
      expect(painted.kindAt(0, 0), isNull);
      expect(painted.paintedKinds, [MapTerrainKind.forest]);
    });

    test('an erasing brush returns ground to unpainted', () {
      const square = MapExtent(width: 100, height: 100);
      final filled = MapTerrainGrid.empty(columns: 4, rows: 4)
          .filled(MapTerrainKind.grass);
      expect(filled.kindAt(1, 1), MapTerrainKind.grass);

      final erased = filled.painted(
        const MapTerrainBrush(
          kind: MapTerrainKind.grass,
          radius: 200,
          erases: true,
        ),
        const MapPosition(50, 50),
        square,
      );

      expect(erased.kindAt(1, 1), isNull);
      expect(erased.isEmpty, isTrue);
    });

    test('brush radius is bounded', () {
      const brush = MapTerrainBrush(kind: MapTerrainKind.grass);
      expect(brush.withRadius(9999).radius, MapTerrainBrush.maxRadius);
      expect(brush.withRadius(0).radius, MapTerrainBrush.minRadius);
    });

    test('coverage and legend describe what the map is made of', () {
      var grid = MapTerrainGrid.empty(columns: 2, rows: 2)
          .filled(MapTerrainKind.water);
      grid = grid.withCell(0, 0, MapTerrainKind.forest);

      expect(grid.coverage[MapTerrainKind.water], 0.75);
      expect(grid.coverage[MapTerrainKind.forest], 0.25);

      final legend = mapLegendFor(grid);
      expect(legend.first.kind, MapTerrainKind.water,
          reason: 'the legend leads with most of the map');
      expect(legend.last.kind, MapTerrainKind.forest);
    });

    test('a grid survives a JSON round trip through run-length encoding', () {
      final grid = MapTerrainGrid.empty(columns: 8, rows: 8)
          .filled(MapTerrainKind.grass)
          .withCell(3, 3, MapTerrainKind.mountain);

      final restored = MapTerrainGrid.fromJson(grid.toJson());

      expect(restored, grid);
      expect(restored.kindAt(3, 3), MapTerrainKind.mountain);
      expect(restored.kindAt(0, 0), MapTerrainKind.grass);
      // The encoding is compact: a mostly-uniform map is a short string, not
      // sixty-four numbers.
      expect(grid.encodeRuns().length, lessThan(40));
    });

    test('elevation rises with the kind of ground', () {
      expect(MapTerrainKind.water.elevation,
          lessThan(MapTerrainKind.grass.elevation));
      expect(MapTerrainKind.grass.elevation,
          lessThan(MapTerrainKind.mountain.elevation));
      expect(MapTerrainKind.snow.elevation, 1.0);
      expect(MapTerrainKind.water.isWater, isTrue);
      expect(MapTerrainKind.grass.isWater, isFalse);
    });
  });

  group('biomes name terrain combinations', () {
    test('every built-in biome is made of real terrain', () {
      expect(MapBiome.builtIn, isNotEmpty);
      for (final biome in MapBiome.builtIn) {
        expect(biome.kinds, isNotEmpty, reason: '${biome.id} paints nothing');
        expect(biome.name, isNotEmpty);
        expect(biome.kinds, everyElement(isA<MapTerrainKind>()));
      }
      expect(
        MapBiome.builtIn.map((biome) => biome.id).toSet(),
        hasLength(MapBiome.builtIn.length),
        reason: 'biome ids must be unique',
      );
    });

    test('a biome round trips', () {
      final biome = MapBiome.builtIn.first;
      final restored = MapBiome.fromJson(biome.toJson());
      expect(restored.id, biome.id);
      expect(restored.kinds, biome.kinds);
      expect(restored.dominant, biome.dominant);
    });
  });

  // ---------------------------------------------------------- persistence ---

  group('terrain persists through MapService', () {
    test('a painted stroke is stored in map space on the map record', () async {
      await seedMap();

      await maps.paintTerrainStroke(
        'map-kingdom',
        const MapTerrainBrush(kind: MapTerrainKind.forest, radius: 100),
        const [MapPosition(500, 500)],
        timestamp: timestamp,
      );

      final terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.paintedKinds, [MapTerrainKind.forest]);

      final record = await maps.records.getRecord('map-kingdom');
      final stored = record!.fields['_map.terrain'] as Map;
      expect(stored['columns'], MapTerrainGrid.defaultResolution);
      expect(stored['runs'], isA<String>());
      // Nothing pixel-shaped reached the record.
      for (final key in record.fields.keys) {
        expect(key, isNot(contains('screen')));
        expect(key, isNot(contains('pixel')));
        expect(key, isNot(contains('canvas')));
      }
    });

    test('a stroke is one revision, not one per dab', () async {
      await seedMap();
      final before = (await maps.mapHistory('map-kingdom')).length;

      await maps.paintTerrainStroke(
        'map-kingdom',
        const MapTerrainBrush(kind: MapTerrainKind.grass, radius: 60),
        const [
          MapPosition(100, 100),
          MapPosition(150, 120),
          MapPosition(200, 140),
          MapPosition(250, 160),
        ],
        timestamp: timestamp,
      );

      final after = (await maps.mapHistory('map-kingdom')).length;
      expect(after - before, 1,
          reason: 'one stroke is one editing act and one audit event');
    });

    test('terrain survives a reload at the same logical position', () async {
      await seedMap();
      await maps.fillTerrain('map-kingdom', MapTerrainKind.water,
          timestamp: timestamp);
      await maps.paintTerrainStroke(
        'map-kingdom',
        const MapTerrainBrush(kind: MapTerrainKind.sand, radius: 80),
        const [MapPosition(250, 250)],
        timestamp: timestamp,
      );

      final terrain = await maps.terrainFor('map-kingdom');
      final cell = terrain.cellFor(
        const MapPosition(250, 250),
        MapExtent.standard,
      )!;
      expect(terrain.kindAt(cell.$1, cell.$2), MapTerrainKind.sand);
      expect(terrain.kindAt(0, 0), MapTerrainKind.water);

      // Reload from the database rather than reusing the in-memory value.
      final reloaded = MapTerrainGrid.read(
        (await maps.records.getRecord('map-kingdom'))!.fields,
      );
      expect(reloaded, terrain);
    });

    test('painting outside the map is clamped into it', () async {
      await seedMap(extent: const MapExtent(width: 400, height: 400));

      await maps.paintTerrainStroke(
        'map-kingdom',
        const MapTerrainBrush(kind: MapTerrainKind.rock, radius: 40),
        const [MapPosition(99999, -99999)],
        timestamp: timestamp,
      );

      final terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.paintedKinds, [MapTerrainKind.rock]);
      // Clamped to the top-right corner of the map, not off it.
      expect(terrain.kindAt(terrain.columns - 1, 0), MapTerrainKind.rock);
    });

    test('clearing terrain removes the field rather than storing emptiness',
        () async {
      await seedMap();
      await maps.fillTerrain('map-kingdom', MapTerrainKind.grass,
          timestamp: timestamp);
      expect((await maps.terrainFor('map-kingdom')).isEmpty, isFalse);

      await maps.clearTerrain('map-kingdom', timestamp: timestamp);

      final record = await maps.records.getRecord('map-kingdom');
      expect(record!.fields.containsKey('_map.terrain'), isFalse,
          reason: 'an unpainted map should cost nothing to store');
      expect((await maps.terrainFor('map-kingdom')).cellCount, 0);
    });

    test('style and biomes persist on the same record', () async {
      await seedMap();

      await maps.setVisualStyle(
        'map-kingdom',
        const MapVisualStyle(
          treatment: MapBackgroundTreatment.parchment,
          saturation: 1.4,
          showLegend: false,
        ),
        timestamp: timestamp,
      );
      await maps.setBiomes(
        'map-kingdom',
        [MapBiome.builtIn.first],
        timestamp: timestamp,
      );

      final style = await maps.visualStyleFor('map-kingdom');
      expect(style.treatment, MapBackgroundTreatment.parchment);
      expect(style.saturation, 1.4);
      expect(style.showLegend, isFalse);
      expect(await maps.biomesFor('map-kingdom'), hasLength(1));
    });

    test('style values are bounded', () {
      const style = MapVisualStyle();
      expect(style.copyWith(saturation: 99).saturation, 2.0);
      expect(style.copyWith(contrast: 0).contrast, 0.5);
      expect(style.copyWith(terrainOpacity: 0).terrainOpacity, 0.1);
    });
  });

  // -------------------------------------------------------------- scenery ---

  group('scenery persists through MapService', () {
    MapAssetInstance tree(String id, MapPosition position) => MapAssetInstance(
          id: id,
          definitionId: 'tree',
          position: position,
        );

    test('an asset is placed, moved, shaped and removed', () async {
      await seedMap();

      await maps.addAsset('map-kingdom', tree('a1', const MapPosition(100, 100)),
          timestamp: timestamp);
      expect(await maps.assetsFor('map-kingdom'), hasLength(1));

      await maps.moveAsset('map-kingdom', 'a1', const MapPosition(400, 300),
          timestamp: timestamp);
      await maps.transformAsset('map-kingdom', 'a1',
          rotation: 450, scale: 2.5, layer: 3, timestamp: timestamp);

      final asset = (await maps.assetsFor('map-kingdom')).single;
      expect(asset.id, 'a1', reason: 'shaping is not a new asset');
      expect(asset.position, const MapPosition(400, 300));
      expect(asset.rotation, 90, reason: 'rotation normalises into 0..360');
      expect(asset.scale, 2.5);
      expect(asset.layer, 3);

      await maps.removeAsset('map-kingdom', 'a1', timestamp: timestamp);
      expect(await maps.assetsFor('map-kingdom'), isEmpty);
    });

    test('an asset is clamped into the map', () async {
      await seedMap(extent: const MapExtent(width: 600, height: 300));

      await maps.addAsset(
          'map-kingdom', tree('a1', const MapPosition(9999, -50)),
          timestamp: timestamp);

      expect((await maps.assetsFor('map-kingdom')).single.position,
          const MapPosition(600, 0));
    });

    test('scale is bounded and draw order is deterministic', () async {
      await seedMap();
      await maps.addAsset('map-kingdom', tree('b', const MapPosition(10, 10)),
          timestamp: timestamp);
      await maps.addAsset('map-kingdom', tree('a', const MapPosition(20, 20)),
          timestamp: timestamp);
      await maps.transformAsset('map-kingdom', 'a',
          scale: 99, layer: 5, timestamp: timestamp);
      await maps.transformAsset('map-kingdom', 'b',
          scale: 0.001, layer: 1, timestamp: timestamp);

      final assets = await maps.assetsFor('map-kingdom');
      expect(assets.map((asset) => asset.id), ['b', 'a'],
          reason: 'lower layers draw first');
      expect(assets.last.scale, MapAssetInstance.maxScale);
      expect(assets.first.scale, MapAssetInstance.minScale);
    });

    test('an unknown definition or a duplicate id is refused', () async {
      await seedMap();
      await maps.addAsset('map-kingdom', tree('a1', const MapPosition(1, 1)),
          timestamp: timestamp);

      expect(
        () => maps.addAsset(
          'map-kingdom',
          const MapAssetInstance(
            id: 'a2',
            definitionId: 'dragon-statue',
            position: MapPosition(1, 1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => maps.addAsset('map-kingdom', tree('a1', const MapPosition(2, 2))),
        throwsA(isA<MapStudioException>()),
      );
      expect(
        () => maps.moveAsset('map-kingdom', 'nope', const MapPosition(1, 1)),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('the asset library is coherent', () {
      expect(MapAssetDefinition.library, isNotEmpty);
      expect(
        MapAssetDefinition.library.map((item) => item.id).toSet(),
        hasLength(MapAssetDefinition.library.length),
        reason: 'asset ids must be unique',
      );
      for (final category in MapAssetCategory.values) {
        expect(MapAssetDefinition.inCategory(category), isNotEmpty,
            reason: '${category.name} has no assets');
      }
      expect(MapAssetDefinition.byId('tree'), isNotNull);
      expect(MapAssetDefinition.byId('nothing'), isNull);
    });
  });

  // --------------------------------------------------------- architecture ---

  group('Phase 3 adds scenery, not story entities', () {
    test('terrain and assets create no records and no links', () async {
      await seedMap();
      final recordsBefore =
          (await repository.recordsByProject(projectId)).length;

      await maps.fillTerrain('map-kingdom', MapTerrainKind.grass,
          timestamp: timestamp);
      for (var i = 0; i < 25; i++) {
        // Distinct timestamps on purpose. VersionAuditService derives a
        // version id from the record, the timestamp and a sequence taken from
        // the *previous* version -- and when several versions share a
        // timestamp that lookup is ambiguous, the sequence repeats and the
        // insert fails on a duplicate id. Production uses DateTime.now(), so
        // this is a test-only hazard, but it is a real one.
        await maps.addAsset(
          'map-kingdom',
          MapAssetInstance(
            id: 'tree-$i',
            definitionId: 'tree',
            position: MapPosition(i * 10.0, i * 10.0),
          ),
          timestamp: timestamp.add(Duration(seconds: i + 1)),
        );
      }

      // Twenty-five trees and a painted world. The graph gained nothing.
      expect((await repository.recordsByProject(projectId)).length,
          recordsBefore,
          reason: 'scenery must never become an AuthorRecord');
      expect(await maps.connections.outgoing('map-kingdom'), isEmpty,
          reason: 'scenery must never become a RecordLink endpoint');
      expect(await maps.assetsFor('map-kingdom'), hasLength(25));
    });

    test('every Phase 3 field lives under the reserved namespace', () async {
      await seedMap();
      await maps.fillTerrain('map-kingdom', MapTerrainKind.grass,
          timestamp: timestamp);
      await maps.addAsset(
          'map-kingdom',
          const MapAssetInstance(
              id: 'a1', definitionId: 'tree', position: MapPosition(1, 1)),
          timestamp: timestamp);
      await maps.setVisualStyle('map-kingdom', MapVisualStyle.standard,
          timestamp: timestamp);

      for (final field in const [
        MapVisualFields.terrain,
        MapVisualFields.assets,
        MapVisualFields.style,
        MapVisualFields.biomes,
      ]) {
        expect(field, startsWith(MapFields.prefix));
      }
      final record = await maps.records.getRecord('map-kingdom');
      expect(record!.typeId, 'map',
          reason: 'Phase 3 invents no record type of its own');
    });

    test('terrain and scenery cannot cross projects', () async {
      final other = MapService(
        projectId: otherProjectId,
        repository: repository,
      );
      await seedMap();
      await seedMap(id: 'map-other', service: other);
      await maps.fillTerrain('map-kingdom', MapTerrainKind.snow,
          timestamp: timestamp);

      expect((await other.terrainFor('map-other')).cellCount, 0);
      expect(
        () => other.paintTerrainStroke(
          'map-kingdom',
          const MapTerrainBrush(kind: MapTerrainKind.water),
          const [MapPosition(1, 1)],
        ),
        throwsA(isA<MapStudioException>()),
      );
      expect(
        () => other.addAsset(
          'map-kingdom',
          const MapAssetInstance(
              id: 'x', definitionId: 'tree', position: MapPosition(1, 1)),
        ),
        throwsA(isA<MapStudioException>()),
      );
      expect((await maps.terrainFor('map-kingdom')).paintedKinds,
          [MapTerrainKind.snow]);
    });

    test('Phase 1 and Phase 2 map data is untouched by Phase 3', () async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          position: MapPosition(250, 400),
        ),
        timestamp: timestamp,
      );
      await maps.createRegion(
        MapRegionDraft(
          id: 'region-north',
          mapId: 'map-kingdom',
          name: 'The North',
          geometry: MapGeometry.box(
            const MapPosition(100, 100),
            const MapPosition(500, 300),
          ),
        ),
        timestamp: timestamp,
      );

      await maps.fillTerrain('map-kingdom', MapTerrainKind.forest,
          timestamp: timestamp);
      await maps.addAsset(
          'map-kingdom',
          const MapAssetInstance(
              id: 'a1', definitionId: 'castle', position: MapPosition(10, 10)),
          timestamp: timestamp);

      final canvas = await maps.loadCanvas('map-kingdom');
      expect(canvas.locations.single.position, const MapPosition(250, 400));
      expect(canvas.regions.single.geometry.points, hasLength(2));
      expect(canvas.map.terrain.paintedKinds, [MapTerrainKind.forest]);
      expect(canvas.map.assets, hasLength(1));
    });
  });
}
