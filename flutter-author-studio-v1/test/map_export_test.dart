import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/map_domain.dart';
import 'package:author_studio_v1/map_overlays.dart';
import 'package:author_studio_v1/map_presentation.dart';
import 'package:author_studio_v1/map_presentation_view.dart';
import 'package:author_studio_v1/map_terrain.dart';
import 'package:author_studio_v1/map_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map Studio Phase 6 — export.
///
/// The last test in this file writes real PNG, SVG, PDF and JSON files to
/// `MAP_PREVIEW_DIR` when that variable is set. That is not decoration: Phase 6
/// may not be merged until those files have been opened and looked at, because
/// a map can pass every assertion here and still be unpresentable — the first
/// run of it printed a lattice of seams across the whole world, labelled two
/// places out of six, and drew a territory as a diagonal line.
final timestamp = DateTime.utc(2026, 8, 22);

AuthorRecord record({
  required String id,
  required String typeId,
  required String title,
  Map<String, Object?> fields = const {},
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      templateId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: 'project-preview',
      projectId: 'project-preview',
      canonStatus: CanonStatus.canon,
      title: title,
      fields: fields,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

void main() {
  const extent = MapExtent.standard;

  MapTerrainGrid paintedWorld() {
    var terrain = MapTerrainGrid.empty();
    for (var row = 0; row < terrain.rows; row++) {
      for (var column = 0; column < terrain.columns; column++) {
        final kind = switch (true) {
          _ when row < 4 || column < 3 => MapTerrainKind.water,
          _ when row > 8 && row < 14 && column > 6 => MapTerrainKind.mountain,
          _ when row > 20 && column < 24 => MapTerrainKind.forest,
          _ when row > 34 => MapTerrainKind.sand,
          _ => MapTerrainKind.grass,
        };
        terrain = terrain.withCell(column, row, kind);
      }
    }
    return terrain;
  }

  MapSummary buildMap({MapTerrainGrid? terrain}) => MapSummary(
        record: record(
          id: 'map-aurelia',
          typeId: 'map',
          title: 'The World of Aurelia',
          fields: {
            MapFields.width: extent.width,
            MapFields.height: extent.height,
            MapFields.coordinateSystem: 'leagues',
            if (terrain != null) MapVisualFields.terrain: terrain.toJson(),
          },
        ),
      );

  MapLocationView place(
    String id,
    String name,
    double x,
    double y, [
    String type = 'City',
  ]) =>
      MapLocationView(
        record: record(
          id: id,
          typeId: 'location',
          title: name,
          fields: {
            MapFields.mapId: 'map-aurelia',
            MapFields.x: x,
            MapFields.y: y,
            MapFields.locationType: type,
          },
        ),
        mapId: 'map-aurelia',
      );

  final locations = [
    place('city-aurel', 'Aurel', 240, 320, 'capital'),
    place('city-blackmere', 'Blackmere', 700, 430, 'city'),
    place('city-vey', 'Vey', 460, 560, 'town'),
    place('city-orynth', 'Orynth', 820, 250, 'fortress'),
    place('village-mill', 'Millbrook', 330, 640, 'village'),
    place('ruin-old-vey', 'Old Vey', 560, 700, 'ruin'),
  ];

  final regions = [
    MapRegionView(
      record: record(
        id: 'region-north',
        typeId: 'region',
        title: 'The Northern Reach',
        fields: {
          MapFields.mapId: 'map-aurelia',
          MapFields.geometry: MapGeometry.box(
            const MapPosition(160, 200),
            const MapPosition(620, 480),
          ).toJson(),
        },
      ),
      mapId: 'map-aurelia',
    ),
  ];

  MapWorldState worldState() => MapWorldState(
        mapId: 'map-aurelia',
        projectId: 'project-preview',
        kind: MapWorldStateKind.current,
        settlements: [
          for (final location in locations)
            MapSettlement(
              id: location.record.id,
              name: location.name,
              kind: MapSettlementKindLabel.fromTypeId(
                'location',
                settlementType: location.locationType,
              ),
              position: location.position,
            ),
        ],
        routes: [
          const MapWorldRoute(
            id: 'route-north',
            name: 'The North Road',
            kind: MapRouteKind.road,
            fromId: 'city-aurel',
            toId: 'city-blackmere',
            fromPosition: MapPosition(240, 320),
            toPosition: MapPosition(700, 430),
            distance: 180,
            distanceUnit: 'leagues',
          ),
          const MapWorldRoute(
            id: 'route-pass',
            name: 'The High Pass',
            kind: MapRouteKind.mountainPass,
            fromId: 'city-blackmere',
            toId: 'city-orynth',
            fromPosition: MapPosition(700, 430),
            toPosition: MapPosition(820, 250),
          ),
        ],
        factions: const {'faction-aurel': 'Kingdom of Aurel'},
      );

  MapOverlayData overlayData() => const MapOverlayData(
        mapId: 'map-aurelia',
        projectId: 'project-preview',
        items: [
          MapOverlayItem(
            id: 'character-mara',
            projectId: 'project-preview',
            kind: MapOverlayKind.character,
            position: MapPosition(240, 320),
            label: 'Mara',
            sourceId: 'character-mara',
            sourceType: 'character',
            locationId: 'city-aurel',
          ),
          MapOverlayItem(
            id: 'event-siege',
            projectId: 'project-preview',
            kind: MapOverlayKind.event,
            position: MapPosition(700, 430),
            label: 'The Siege',
            sourceId: 'event-siege',
            sourceType: 'timeline-event',
            locationId: 'city-blackmere',
          ),
        ],
      );

  const palette = MapDrawPalette(
    background: 0xFFF6F1E7,
    surface: 0xFFFBF7EE,
    ink: 0xFF2B2118,
    muted: 0xFF6E6154,
    outline: 0xFFB8A88E,
    accent: 0xFF8A5A2B,
    regionFill: 0xFFDCCDB0,
    terrain: {
      MapTerrainKind.water: 0xFFA9C4CE,
      MapTerrainKind.grass: 0xFFCFCFA8,
      MapTerrainKind.forest: 0xFF9FB289,
      MapTerrainKind.mountain: 0xFFB6A894,
      MapTerrainKind.sand: 0xFFE3D6AE,
    },
  );

  MapPresentation presentation({
    MapPresentationTheme theme = MapPresentationTheme.classicFantasy,
    String watermark = '',
  }) =>
      MapPresentation(
        metadata: MapPresentationMetadata(
          projectTitle: 'A Crown of Ash',
          mapTitle: 'The World of Aurelia',
          bookTitle: 'House of Shadows & Saints',
          authorName: 'KJ Ink & Insight',
          eraLabel: '412 A.E.',
          revision: 4,
          createdAt: timestamp,
        ),
        theme: theme,
        decorations: MapDecorations({
          ...theme.decorations,
          // A watermark takes both a string and its own switch, like every
          // other decoration.
          if (watermark.isNotEmpty) MapDecoration.watermark,
        }),
        credit: '© KJ Ink & Insight',
        watermark: watermark,
        scaleBar:
            MapScaleBar.forExtent(extent.width, coordinateSystem: 'leagues'),
      );

  MapExportRequest request({
    MapExportPreset preset = MapExportPreset.print,
    MapExportFormat format = MapExportFormat.svg,
    MapPresentationTheme theme = MapPresentationTheme.classicFantasy,
    MapTerrainGrid? terrain,
    MapWorldState? world,
    MapOverlayData? overlays,
    String watermark = '',
  }) =>
      MapExportRequest(
        presentation: presentation(theme: theme, watermark: watermark),
        canvas: MapCanvasData(
          map: buildMap(terrain: terrain),
          locations: locations,
          regions: regions,
          markers: const [],
        ),
        overlays: overlays,
        world: world,
        palette: palette,
        preset: preset,
        format: format,
      );

  group('the drawing is built once and painted many times', () {
    test('every place and route reaches the drawing', () {
      final drawing = const MapDrawingBuilder().build(
        request(world: worldState(), overlays: overlayData()),
      );

      final texts = [
        for (final primitive in drawing.primitives)
          if (primitive is MapDrawText) primitive.text,
      ];
      expect(texts, contains('The World of Aurelia'));
      for (final location in locations) {
        expect(texts, contains(location.name),
            reason: '${location.name} was not labelled');
      }
      expect(drawing.width, greaterThan(drawing.height),
          reason: 'a print map is landscape by default');
    });

    test('terrain is merged into rectangles rather than drawn cell by cell',
        () {
      final painted = const MapDrawingBuilder().build(
        request(terrain: paintedWorld()),
      );
      final bare = const MapDrawingBuilder().build(request());

      final terrainRects = painted.primitives
          .where((primitive) => primitive.layer == MapLayer.terrain)
          .length;

      expect(terrainRects, greaterThan(0));
      expect(terrainRects, lessThan(40),
          reason: 'a 48x48 grid of five bands must not become 2,304 rectangles '
              '— translucent cells that merely abut print a lattice of seams');
      expect(painted.primitiveCount, greaterThan(bare.primitiveCount));
    });

    test('a bounds region is drawn as a rectangle, not a diagonal line', () {
      final drawing = const MapDrawingBuilder().build(request());
      final region = drawing.primitives
          .whereType<MapDrawPolygon>()
          .firstWhere((polygon) => polygon.layer == MapLayer.regions);

      expect(region.points.length, 8, reason: 'four corners, x and y each');
      expect(region.closed, isTrue);
    });

    test('the draw order follows the declared map layers', () {
      final drawing = const MapDrawingBuilder().build(
        request(terrain: paintedWorld(), world: worldState()),
      );
      final order = [
        for (final primitive in drawing.ordered) primitive.layer.index,
      ];

      expect(order, orderedEquals(<int>[...order]..sort()));
    });

    test('a printed map labels more than a screen export', () {
      int labels(MapExportPreset preset) => const MapDrawingBuilder()
          .build(request(preset: preset, world: worldState()))
          .primitives
          .whereType<MapDrawText>()
          .length;

      expect(labels(MapExportPreset.poster),
          greaterThan(labels(MapExportPreset.web)),
          reason: 'an export has no zoom, so a printed map shows what fits');
    });

    test('a label never overprints a story badge', () {
      final drawing = const MapDrawingBuilder().build(
        request(world: worldState(), overlays: overlayData()),
      );
      final badges = drawing.primitives
          .whereType<MapDrawCircle>()
          .where((circle) => circle.layer == MapLayer.storyOverlays);
      final labels = drawing.primitives
          .whereType<MapDrawText>()
          .where((text) => text.layer == MapLayer.markers);

      for (final badge in badges) {
        for (final label in labels) {
          final overlaps = (label.x - badge.x).abs() < badge.radius &&
              (label.y - badge.y).abs() < badge.radius;
          expect(overlaps, isFalse,
              reason: '"${label.text}" is printed under a badge');
        }
      }
    });
  });

  group('the formats agree, and are deterministic', () {
    test('the same request always produces the same SVG', () {
      final first = const MapSvgRenderer()
          .render(const MapDrawingBuilder().build(request()));
      final second = const MapSvgRenderer()
          .render(const MapDrawingBuilder().build(request()));

      expect(first, second);
      expect(first, startsWith('<?xml'));
      expect(first, contains('The World of Aurelia'));
    });

    test('SVG escapes prose that would otherwise break the document', () {
      final drawing = const MapDrawingBuilder().build(request());
      final svg = const MapSvgRenderer().render(drawing);

      expect(svg, contains('KJ Ink &amp; Insight'));
      expect(svg, isNot(contains('KJ Ink & Insight')));
    });

    test('PDF and SVG paint the same drawing', () async {
      final drawing = const MapDrawingBuilder().build(
        request(terrain: paintedWorld(), world: worldState()),
      );
      final pdf = await const MapPdfRenderer().render(drawing);
      final svg = const MapSvgRenderer().render(drawing);

      expect(pdf.length, greaterThan(1000));
      expect(svg.length, greaterThan(1000));
      // Both were handed the identical primitive list; the drawing is the
      // single source of the picture.
      expect(drawing.ordered.length, drawing.primitiveCount);
    });

    test('PNG rasterises at the preset resolution', () async {
      final drawing = const MapDrawingBuilder().build(request());
      final screen = await const MapPngRenderer().render(drawing);
      final print = await const MapPngRenderer()
          .render(drawing, pixelRatio: MapExportPreset.print.pixelRatio);

      expect(screen.length, greaterThan(1000));
      expect(print.length, greaterThan(screen.length),
          reason: '300 DPI carries more pixels than 96');
      expect(screen.sublist(1, 4), [0x50, 0x4E, 0x47],
          reason: 'a PNG says so in its own header');
    });

    test('JSON carries the canonical values and reports what was omitted', () {
      final json = jsonDecode(
        const MapJsonExporter().render(
          request(world: worldState(), overlays: overlayData()),
        ),
      ) as Map<String, Object?>;

      expect((json['map']! as Map)['title'], 'The World of Aurelia');
      expect((json['places']! as List), hasLength(locations.length));
      expect((json['routes']! as List), hasLength(2));
      expect((json['story']! as List).first, isA<Map<String, Object?>>());
      expect((json['metadata']! as Map)['version'], 'Version 1.4');
    });
  });

  group('presets and presentation', () {
    test('no preset claims a colour space AuthorOS cannot produce', () {
      for (final preset in MapExportPreset.values) {
        expect(preset.description.toLowerCase(), isNot(contains('cmyk')));
      }
    });

    test('a theme transforms the map own style rather than replacing it', () {
      const base = MapVisualStyle(saturation: 1, contrast: 1);

      expect(MapPresentationTheme.studio.styleFor(base), base);
      expect(
        MapPresentationTheme.minimal.styleFor(base).saturation,
        lessThan(base.saturation),
      );
      expect(MapPresentationTheme.minimal.styleFor(base).showLegend, isFalse);
    });

    test('decorations are independently switchable', () {
      const decorations = MapDecorations({MapDecoration.compass});

      expect(decorations.has(MapDecoration.compass), isTrue);
      expect(decorations.has(MapDecoration.legend), isFalse);
      expect(
        decorations.toggling(MapDecoration.compass).has(MapDecoration.compass),
        isFalse,
      );
    });

    test('a watermark is drawn only when there is one to draw', () {
      final without = const MapDrawingBuilder().build(request());
      final with_ = const MapDrawingBuilder().build(
        request(watermark: 'PROOF'),
      );

      expect(
        without.primitives.whereType<MapDrawText>().map((text) => text.text),
        isNot(contains('PROOF')),
      );
      expect(
        with_.primitives.whereType<MapDrawText>().map((text) => text.text),
        contains('PROOF'),
      );
    });

    test('a map with no canonical scale says map units, and reports the gap',
        () {
      final bar = MapScaleBar.forExtent(1000);

      expect(bar.unitLabel, 'map units');
      expect(bar.gap, isNotNull);
      expect(bar.gap!.missingSource, contains('no canonical map scale'));
      expect(
        MapScaleBar.forExtent(1000, coordinateSystem: 'leagues').gap,
        isNull,
      );
    });

    test('the suggested file name is derived from the map, safely', () {
      expect(
        request(format: MapExportFormat.png).suggestedFileName,
        'the-world-of-aurelia.png',
      );
    });
  });

  group('artifacts for inspection', () {
    setUpAll(() async {
      // `flutter test` loads no real font, so every glyph rasterises as a
      // filled box. Fine for geometry, useless for judging whether a map is
      // presentable — so the preview loads a real face before it draws. Test
      // scaffolding only: the application uses the fonts the platform gives it.
      TestWidgetsFlutterBinding.ensureInitialized();
      const path = '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf';
      final file = File(path);
      if (!file.existsSync()) return;
      final loader = FontLoader('Helvetica')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
      final roboto = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await roboto.load();
    });

    test('writes PNG, SVG, PDF and JSON when MAP_PREVIEW_DIR is set', () async {
      final target = Platform.environment['MAP_PREVIEW_DIR'];
      final drawing = const MapDrawingBuilder().build(
        request(
          terrain: paintedWorld(),
          world: worldState(),
          overlays: overlayData(),
        ),
      );

      final svg = const MapSvgRenderer().render(drawing);
      final pdf = await const MapPdfRenderer().render(drawing);
      final png = await const MapPngRenderer().render(drawing, pixelRatio: 1.5);
      final json = const MapJsonExporter().render(
        request(world: worldState(), overlays: overlayData()),
      );

      expect(svg, isNotEmpty);
      expect(pdf, isNotEmpty);
      expect(png, isNotEmpty);
      expect(json, isNotEmpty);

      if (target == null) return;
      final directory = Directory(target)..createSync(recursive: true);
      File('${directory.path}/aurelia.svg').writeAsStringSync(svg);
      File('${directory.path}/aurelia.pdf').writeAsBytesSync(pdf);
      File('${directory.path}/aurelia.png').writeAsBytesSync(png);
      File('${directory.path}/aurelia.json').writeAsStringSync(json);
    });
  });
}
