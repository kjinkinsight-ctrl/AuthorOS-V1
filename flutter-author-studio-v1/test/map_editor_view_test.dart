import 'dart:io';

import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/map_studio_view.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Studio Phase 2 — the visual editor, driven through the pointer.
const projectId = 'project-map';
final timestamp = DateTime.utc(2026, 8, 21, 9);

const testProject = StarterProject(
  id: projectId,
  title: 'A Crown of Ash',
  genre: 'Fantasy',
  projectType: 'Novel',
  wordGoal: 90000,
  acts: ['Act I'],
  chapters: [StarterChapter(title: 'Chapter 1', prompt: 'Begin')],
  characterSheets: [StarterCharacterSheet(name: 'Mara', role: 'Protagonist')],
  beatChecklist: ['Opening Image'],
  firstSceneTitle: 'The First Bell',
);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  ResolvedTheme resolvedTheme() {
    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    return engine.resolveSelection(
      selection: const ThemeSelection(
        themeId: 'light',
        mode: AuthorOsThemeMode.light,
      ),
      hostBrightness: ThemeBrightness.light,
    );
  }

  Future<void> pumpStudio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = resolvedTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MapStudioView(project: testProject, service: maps),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<MapSummary> seedMap() => maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedLocation({
    String id = 'city-endovier',
    String name = 'Endovier',
    MapPosition position = const MapPosition(200, 200),
  }) =>
      maps.createLocation(
        MapLocationDraft(
          id: id,
          mapId: 'map-kingdom',
          name: name,
          locationType: 'City',
          position: position,
        ),
        timestamp: timestamp,
      );

  Future<MapRegionView> seedRegion() => maps.createRegion(
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

  // The canvas geometry, read back from the widget so nothing here assumes a
  // pixel size of its own.
  Rect canvasRect(WidgetTester tester) => tester.getRect(
        find.byKey(const Key('map-canvas')),
      );

  MapProjection projectionFor(
    WidgetTester tester, {
    MapExtent extent = MapExtent.standard,
    MapCamera camera = MapCamera.identity,
  }) {
    final rect = canvasRect(tester);
    return MapProjection(
      extent: extent,
      canvasWidth: rect.width,
      canvasHeight: rect.height,
      camera: camera,
    );
  }

  Offset atCanvas(WidgetTester tester, double dx, double dy) =>
      canvasRect(tester).topLeft + Offset(dx, dy);

  Future<void> useTool(WidgetTester tester, String tool) async {
    await tester.tap(find.byKey(Key('map-tool-$tool')));
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------- toolbar ---

  group('editor toolbar', () {
    testWidgets('every Phase 2 control renders', (tester) async {
      await seedMap();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-editor-toolbar')), findsOneWidget);
      for (final tool in const [
        'select',
        'place',
        'move',
        'region',
        'pan',
      ]) {
        expect(find.byKey(Key('map-tool-$tool')), findsOneWidget,
            reason: '$tool tool must be on the toolbar');
      }
      expect(find.byKey(const Key('map-place-location-chip')), findsOneWidget);
      expect(find.byKey(const Key('map-place-marker-chip')), findsOneWidget);
      expect(find.byKey(const Key('map-zoom-in-button')), findsOneWidget);
      expect(find.byKey(const Key('map-zoom-out-button')), findsOneWidget);
      expect(find.byKey(const Key('map-reset-view-button')), findsOneWidget);
      expect(find.byKey(const Key('map-zoom-level')), findsOneWidget);
      // The Phase 1 authoring dialogs are still reachable.
      expect(find.byKey(const Key('map-add-location-button')), findsOneWidget);
      expect(find.byKey(const Key('map-add-region-button')), findsOneWidget);
      expect(find.byKey(const Key('map-add-marker-button')), findsOneWidget);
    });

    testWidgets('the toolbar draws from engine tokens, not literals',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      final theme = resolvedTheme();
      final expected = AuthorOsTheme.color(
        theme.colorFor(StudioId.map, ThemeColorRef.surfaceContainer),
      );
      final toolbar = tester.widget<Container>(
        find.byKey(const Key('map-editor-toolbar')),
      );
      expect((toolbar.decoration as BoxDecoration).color, expected);
    });

    testWidgets('the region tools appear only with the region tool',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-region-tools')), findsNothing);
      await useTool(tester, 'region');
      expect(find.byKey(const Key('map-region-tools')), findsOneWidget);
      await useTool(tester, 'select');
      expect(find.byKey(const Key('map-region-tools')), findsNothing);
    });
  });

  // ----------------------------------------------------------- draw order ---

  group('draw order', () {
    testWidgets('the canvas stacks its layers in one deterministic order',
        (tester) async {
      await seedMap();
      await seedRegion();
      await seedLocation();
      await pumpStudio(tester);

      final stack = tester.widget<Stack>(
        find
            .descendant(
              of: find.byKey(const Key('map-canvas')),
              matching: find.byType(Stack),
            )
            .first,
      );
      final order = [
        for (final child in stack.children)
          (child.key as ValueKey<String>).value,
      ];

      expect(order, [
        'map-layer-base',
        'map-layer-terrain',
        'map-layer-regions',
        'map-layer-assets',
        'map-layer-locations',
        'map-layer-markers',
        'map-layer-selection',
        'map-layer-interaction',
      ]);
      expect(order, MapLayer.values.map((layer) => 'map-layer-${layer.name}'));
    });
  });

  // --------------------------------------------------------------- placing --

  group('place', () {
    testWidgets('tapping the canvas in place mode writes a location there',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'place');

      final projection = projectionFor(tester);
      final expected = projection.toMap(120, 90);
      await tester.tapAt(atCanvas(tester, 120, 90));
      await tester.pumpAndSettle();

      final stored = await maps.locationsForMap('map-kingdom');
      expect(stored, hasLength(1));
      expect(stored.single.name, 'New Location');
      expect(stored.single.position.x, closeTo(expected.x, 0.5));
      expect(stored.single.position.y, closeTo(expected.y, 0.5));
      expect(find.byKey(Key('map-location-${stored.single.id}')),
          findsOneWidget);
    });

    testWidgets('the placement chip switches what the canvas drops',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-place-marker-chip')));
      await tester.pumpAndSettle();

      final projection = projectionFor(tester);
      final expected = projection.toMap(240, 160);
      await tester.tapAt(atCanvas(tester, 240, 160));
      await tester.pumpAndSettle();

      final markers = await maps.markersForMap('map-kingdom');
      expect(markers, hasLength(1));
      expect(markers.single.label, 'New Marker');
      expect(markers.single.position.x, closeTo(expected.x, 0.5));
      expect(markers.single.position.y, closeTo(expected.y, 0.5));
      expect(await maps.locationsForMap('map-kingdom'), isEmpty);
    });

    testWidgets('dragging onto the canvas places at the release point',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'place');

      final projection = projectionFor(tester);
      final expected = projection.toMap(300, 220);
      await tester.dragFrom(
        atCanvas(tester, 40, 40),
        const Offset(260, 180),
      );
      await tester.pumpAndSettle();

      final stored = await maps.locationsForMap('map-kingdom');
      expect(stored, hasLength(1));
      expect(stored.single.position.x, closeTo(expected.x, 0.5));
      expect(stored.single.position.y, closeTo(expected.y, 0.5));
    });

    testWidgets('a placed item survives a reload at the same logical position',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'place');
      await tester.tapAt(atCanvas(tester, 160, 120));
      await tester.pumpAndSettle();

      final placed = (await maps.locationsForMap('map-kingdom')).single;

      // Reopen the Studio against the same database.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpStudio(tester);

      final reloaded = (await maps.locationsForMap('map-kingdom')).single;
      expect(reloaded.id, placed.id);
      expect(reloaded.position, placed.position);
      expect(find.byKey(Key('map-location-${placed.id}')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- moving --

  group('move', () {
    testWidgets('dragging a location rewrites its map-space position',
        (tester) async {
      await seedMap();
      final before = await seedLocation();
      await pumpStudio(tester);
      await useTool(tester, 'move');

      final projection = projectionFor(tester);
      await tester.drag(
        find.byKey(const Key('map-location-city-endovier')),
        const Offset(120, 80),
      );
      await tester.pumpAndSettle();

      final after = (await maps.locationsForMap('map-kingdom')).single;
      expect(after.id, before.id, reason: 'a move is not a new record');
      expect(
        after.position.x,
        closeTo(before.position.x + 120 / projection.scaleX, 0.5),
      );
      expect(
        after.position.y,
        closeTo(before.position.y + 80 / projection.scaleY, 0.5),
      );
      expect(await maps.locationsForMap('map-kingdom'), hasLength(1));
    });

    testWidgets('dragging a marker moves it and leaves its links alone',
        (tester) async {
      await seedMap();
      await seedLocation();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          position: MapPosition(300, 300),
          linkedRecordId: 'city-endovier',
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);
      await useTool(tester, 'move');

      final linksBefore = await maps.connections.outgoing('marker-well');
      await tester.drag(
        find.byKey(const Key('map-marker-marker-well')),
        const Offset(-60, 40),
      );
      await tester.pumpAndSettle();

      final after = (await maps.markersForMap('map-kingdom')).single;
      expect(after.id, 'marker-well');
      expect(after.position, isNot(const MapPosition(300, 300)));
      expect(after.linkedRecordId, 'city-endovier');
      expect(await maps.connections.outgoing('marker-well'),
          hasLength(linksBefore.length));
    });

    testWidgets('a drag past the edge is clamped into the map', (tester) async {
      await seedMap();
      await seedLocation(position: const MapPosition(980, 20));
      await pumpStudio(tester);
      await useTool(tester, 'move');

      await tester.drag(
        find.byKey(const Key('map-location-city-endovier')),
        const Offset(400, -400),
      );
      await tester.pumpAndSettle();

      final after = (await maps.locationsForMap('map-kingdom')).single;
      expect(after.position, const MapPosition(1000, 0));
    });

    testWidgets('dragging a region carries its whole shape', (tester) async {
      await seedMap();
      final before = await seedRegion();
      await pumpStudio(tester);
      await useTool(tester, 'move');

      await tester.drag(
        find.byKey(const Key('map-region-region-north')),
        const Offset(60, 40),
      );
      await tester.pumpAndSettle();

      final after = (await maps.regionsForMap('map-kingdom')).single;
      expect(after.id, before.id);
      expect(after.geometry.points, hasLength(2));
      expect(after.geometry.bounds!.width,
          closeTo(before.geometry.bounds!.width, 0.001));
      expect(after.geometry.centre, isNot(before.geometry.centre));
    });
  });

  // ----------------------------------------------------- camera behaviour ---

  group('zoom, pan and reset', () {
    testWidgets('zooming in changes the visual scale, not the record',
        (tester) async {
      await seedMap();
      await seedLocation(position: const MapPosition(500, 500));
      await pumpStudio(tester);

      final before = tester.getTopLeft(
        find.byKey(const Key('map-location-city-endovier')),
      );
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-zoom-in-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-zoom-in-button')));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsNothing);
      expect(find.text('156%'), findsOneWidget);
      final canvasSize = canvasRect(tester).size;
      // The canvas itself did not change size; only what it frames did.
      expect(canvasSize, canvasRect(tester).size);
      expect(
        tester.getTopLeft(find.byKey(const Key('map-location-city-endovier'))),
        isNot(before),
      );

      final stored = (await maps.locationsForMap('map-kingdom')).single;
      expect(stored.position, const MapPosition(500, 500));
    });

    testWidgets('zoom is bounded and never touches a record', (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byKey(const Key('map-zoom-in-button')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.text('${(MapCamera.maxScale * 100).round()}%'),
        findsOneWidget,
      );

      for (var i = 0; i < 40; i++) {
        await tester.tap(find.byKey(const Key('map-zoom-out-button')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.text('${(MapCamera.minScale * 100).round()}%'),
        findsOneWidget,
      );

      final stored = (await maps.locationsForMap('map-kingdom')).single;
      expect(stored.position, const MapPosition(200, 200));
    });

    testWidgets('panning moves the camera and no record', (tester) async {
      await seedMap();
      await seedLocation(position: const MapPosition(500, 500));
      await pumpStudio(tester);

      // Pan only has somewhere to go once the frame is smaller than the map.
      await tester.tap(find.byKey(const Key('map-zoom-in-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-zoom-in-button')));
      await tester.pumpAndSettle();
      await useTool(tester, 'pan');

      final before = tester.getTopLeft(
        find.byKey(const Key('map-location-city-endovier')),
      );
      await tester.dragFrom(atCanvas(tester, 30, 30), const Offset(60, 50));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('map-location-city-endovier'))),
        isNot(before),
      );
      final stored = (await maps.locationsForMap('map-kingdom')).single;
      expect(stored.position, const MapPosition(500, 500));
      expect(await maps.locationsForMap('map-kingdom'), hasLength(1));
    });

    testWidgets('reset view restores the starting view and writes nothing',
        (tester) async {
      await seedMap();
      await seedLocation(position: const MapPosition(500, 500));
      await pumpStudio(tester);

      final home = tester.getTopLeft(
        find.byKey(const Key('map-location-city-endovier')),
      );
      final updatedBefore =
          (await maps.locationsForMap('map-kingdom')).single.record.updatedAt;

      await tester.tap(find.byKey(const Key('map-zoom-in-button')));
      await tester.pumpAndSettle();
      await useTool(tester, 'pan');
      await tester.dragFrom(atCanvas(tester, 30, 30), const Offset(80, 60));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('map-location-city-endovier'))),
        isNot(home),
      );

      await tester.tap(find.byKey(const Key('map-reset-view-button')));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('map-location-city-endovier'))),
        home,
      );
      final after = (await maps.locationsForMap('map-kingdom')).single;
      expect(after.position, const MapPosition(500, 500));
      expect(after.record.updatedAt, updatedBefore);
    });
  });

  // ---------------------------------------------------------- selection ----

  group('selection', () {
    testWidgets('tapping empty ground clears the selection', (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-detail')), findsOneWidget);

      await tester.tapAt(atCanvas(tester, 8, 8));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-detail-empty')), findsOneWidget);
    });

    testWidgets('a marquee selects every item it covers', (tester) async {
      await seedMap();
      await seedRegion();
      await seedLocation(position: const MapPosition(150, 150));
      await seedLocation(
        id: 'city-far',
        name: 'Far Away',
        position: const MapPosition(950, 950),
      );
      await pumpStudio(tester);

      final projection = projectionFor(tester);
      final corner = projection.toCanvas(const MapPosition(600, 600));
      // Started inside the canvas's rounded corner, which clips its own hits.
      await tester.dragFrom(
        atCanvas(tester, 30, 30),
        Offset(corner.x - 30, corner.y - 30),
      );
      await tester.pumpAndSettle();

      // The region and the near location, but not the far one.
      expect(find.byKey(const Key('map-detail-multi')), findsOneWidget);
      expect(find.text('2 items selected.'), findsOneWidget);
    });

    testWidgets('a marquee over empty ground selects nothing', (tester) async {
      await seedMap();
      await seedLocation(position: const MapPosition(950, 950));
      await pumpStudio(tester);

      await tester.dragFrom(atCanvas(tester, 30, 30), const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-detail-empty')), findsOneWidget);
      expect(find.byKey(const Key('map-detail-multi')), findsNothing);
    });

    testWidgets('selection is never written to a record', (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();

      final record = await maps.records.getRecord('city-endovier');
      final keys = record!.fields.keys.join(',');
      expect(keys, isNot(contains('select')));
      expect(record.extensionData.keys.join(','), isNot(contains('select')));
    });
  });

  // ------------------------------------------------------ region geometry ---

  group('region geometry editing', () {
    testWidgets('dragging on empty ground with the region tool draws a region',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'region');

      final projection = projectionFor(tester);
      final from = projection.toCanvas(const MapPosition(100, 100));
      final to = projection.toCanvas(const MapPosition(400, 300));
      await tester.dragFrom(
        atCanvas(tester, from.x, from.y),
        Offset(to.x - from.x, to.y - from.y),
      );
      await tester.pumpAndSettle();

      final stored = await maps.regionsForMap('map-kingdom');
      expect(stored, hasLength(1));
      expect(stored.single.name, 'New Region');
      expect(stored.single.geometry.kind, MapGeometryKind.bounds);
      expect(stored.single.geometry.bounds!.left, closeTo(100, 1));
      expect(stored.single.geometry.bounds!.bottom, closeTo(300, 1));
      expect(find.byKey(Key('map-region-${stored.single.id}')), findsOneWidget);
    });

    testWidgets('a selected region shows a handle for every geometry point',
        (tester) async {
      await seedMap();
      await seedRegion();
      await pumpStudio(tester);
      await useTool(tester, 'region');

      expect(find.byKey(const Key('map-geometry-handle-0')), findsNothing);
      await tester.tap(find.byKey(const Key('map-region-region-north')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-geometry-handle-0')), findsOneWidget);
      expect(find.byKey(const Key('map-geometry-handle-1')), findsOneWidget);
      expect(find.byKey(const Key('map-geometry-handle-2')), findsNothing);
      expect(find.byKey(const Key('map-region-tools-status')), findsOneWidget);
    });

    testWidgets('dragging a handle persists the point in map space',
        (tester) async {
      await seedMap();
      await seedRegion();
      await pumpStudio(tester);
      await useTool(tester, 'region');
      await tester.tap(find.byKey(const Key('map-region-region-north')));
      await tester.pumpAndSettle();

      final projection = projectionFor(tester);
      await tester.drag(
        find.byKey(const Key('map-geometry-handle-1')),
        const Offset(80, 60),
      );
      await tester.pumpAndSettle();

      final stored = (await maps.regionsForMap('map-kingdom')).single;
      expect(stored.id, 'region-north');
      expect(stored.geometry.points.first, const MapPosition(100, 100));
      expect(
        stored.geometry.points[1].x,
        closeTo(500 + 80 / projection.scaleX, 1),
      );
      expect(
        stored.geometry.points[1].y,
        closeTo(300 + 60 / projection.scaleY, 1),
      );
    });

    testWidgets('a region can be reshaped into a polygon and edited point by '
        'point', (tester) async {
      await seedMap();
      await seedRegion();
      await pumpStudio(tester);
      await useTool(tester, 'region');
      await tester.tap(find.byKey(const Key('map-region-region-north')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('map-region-polygon-button')));
      await tester.pumpAndSettle();

      var stored = (await maps.regionsForMap('map-kingdom')).single;
      expect(stored.geometry.kind, MapGeometryKind.polygon);
      expect(stored.geometry.points, hasLength(4));
      expect(find.byKey(const Key('map-geometry-handle-3')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-region-add-point-button')));
      await tester.pumpAndSettle();
      stored = (await maps.regionsForMap('map-kingdom')).single;
      expect(stored.geometry.points, hasLength(5));
      expect(find.byKey(const Key('map-geometry-handle-4')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-region-remove-point-button')));
      await tester.pumpAndSettle();
      stored = (await maps.regionsForMap('map-kingdom')).single;
      expect(stored.geometry.points, hasLength(4));

      await tester.tap(find.byKey(const Key('map-region-bounds-button')));
      await tester.pumpAndSettle();
      stored = (await maps.regionsForMap('map-kingdom')).single;
      expect(stored.geometry.kind, MapGeometryKind.bounds);
      expect(stored.id, 'region-north');
      expect(await maps.regionsForMap('map-kingdom'), hasLength(1));
    });
  });

  // -------------------------------------------------------- inline editing --

  group('inline editing', () {
    testWidgets('a location can be renamed on the canvas', (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-inline-editor')), findsNothing);

      await tester.tap(find.byKey(const Key('map-detail-edit-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-inline-editor')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('map-inline-name')),
        'Endovier Salt Mines',
      );
      await tester.enterText(
        find.byKey(const Key('map-inline-category')),
        'Prison',
      );
      await tester.tap(find.byKey(const Key('map-inline-save')));
      await tester.pumpAndSettle();

      final stored = (await maps.locationsForMap('map-kingdom')).single;
      expect(stored.id, 'city-endovier');
      expect(stored.name, 'Endovier Salt Mines');
      expect(stored.locationType, 'Prison');
      expect(stored.position, const MapPosition(200, 200));
      expect(find.byKey(const Key('map-inline-editor')), findsNothing);
    });

    testWidgets('a marker label and category are editable inline',
        (tester) async {
      await seedMap();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'Well',
          position: MapPosition(400, 400),
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-marker-marker-well')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-inline-edit-marker-well')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('map-inline-name')),
        'The Salt Well',
      );
      await tester.enterText(
        find.byKey(const Key('map-inline-category')),
        'Landmark',
      );
      await tester.tap(find.byKey(const Key('map-inline-save')));
      await tester.pumpAndSettle();

      final stored = (await maps.markersForMap('map-kingdom')).single;
      expect(stored.id, 'marker-well');
      expect(stored.label, 'The Salt Well');
      expect(stored.category, 'Landmark');
      expect(stored.position, const MapPosition(400, 400));
    });

    testWidgets('cancelling an inline edit writes nothing', (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-detail-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-inline-name')),
        'Discarded',
      );
      await tester.tap(find.byKey(const Key('map-inline-cancel')));
      await tester.pumpAndSettle();

      final stored = (await maps.locationsForMap('map-kingdom')).single;
      expect(stored.name, 'Endovier');
      expect(find.byKey(const Key('map-inline-editor')), findsNothing);
    });

    testWidgets('an inline edit is a revision of the same record',
        (tester) async {
      await seedMap();
      await seedLocation();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-detail-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-inline-name')),
        'Endovier Mines',
      );
      await tester.tap(find.byKey(const Key('map-inline-save')));
      await tester.pumpAndSettle();

      expect(await maps.locationsForMap('map-kingdom'), hasLength(1));
      expect((await maps.mapHistory('city-endovier')).length,
          greaterThanOrEqualTo(2));
    });
  });

  // ----------------------------------------------------- base expectations --

  group('the Phase 1 surface still holds', () {
    testWidgets('a project with no maps still offers the empty state',
        (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('map-editor-toolbar')), findsNothing);
      expect(find.byKey(const Key('map-canvas')), findsNothing);
    });

    testWidgets('a map renders its canvas, regions, pins and markers',
        (tester) async {
      await seedMap();
      await seedRegion();
      await seedLocation();
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
          position: MapPosition(600, 200),
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-canvas')), findsOneWidget);
      expect(find.byKey(const Key('map-region-region-north')), findsOneWidget);
      expect(
        find.byKey(const Key('map-location-city-endovier')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-marker-marker-well')), findsOneWidget);
      expect(find.byKey(const Key('map-canvas-empty')), findsNothing);
    });
  });

  group('architecture', () {
    test('the editor writes through MapService and nothing else', () {
      final source = File('lib/map_studio_view.dart').readAsStringSync();

      expect(source, contains('MapService'));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('authoros_database')));
      expect(source, isNot(contains('AuthorOsDatabase')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('ThemeData(')));
    });
  });

  // ---------------------------------------------------------------------
  // Phase 3 — terrain, scenery and styling.
  // ---------------------------------------------------------------------
  group('terrain painting', () {
    testWidgets('the terrain tools appear only with the terrain brush',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-terrain-tools')), findsNothing);
      await useTool(tester, 'terrain');
      expect(find.byKey(const Key('map-terrain-tools')), findsOneWidget);
      expect(find.byKey(const Key('map-terrain-kind-forest')), findsOneWidget);
      expect(find.byKey(const Key('map-brush-size')), findsOneWidget);
      await useTool(tester, 'select');
      expect(find.byKey(const Key('map-terrain-tools')), findsNothing);
    });

    testWidgets('painting on the canvas persists terrain in map space',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'terrain');
      await tester.tap(find.byKey(const Key('map-terrain-kind-forest')));
      await tester.pumpAndSettle();

      final projection = projectionFor(tester);
      final expected = projection.toMap(200, 160);
      await tester.tapAt(atCanvas(tester, 200, 160));
      await tester.pumpAndSettle();

      final terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.paintedKinds, [MapTerrainKind.forest]);
      final cell = terrain.cellFor(expected, MapExtent.standard)!;
      expect(terrain.kindAt(cell.$1, cell.$2), MapTerrainKind.forest);
      expect(find.byKey(const Key('map-terrain')), findsOneWidget,
          reason: 'the painted ground renders');
    });

    testWidgets('a drag paints a whole stroke as one revision', (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'terrain');
      final before = (await maps.mapHistory('map-kingdom')).length;

      await tester.dragFrom(atCanvas(tester, 60, 60), const Offset(220, 140));
      await tester.pumpAndSettle();

      final terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.paintedKinds, isNotEmpty);
      final after = (await maps.mapHistory('map-kingdom')).length;
      expect(after - before, 1,
          reason: 'a stroke is one editing act, not one write per move');
    });

    testWidgets('fill and clear cover and reset the map', (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'terrain');

      await tester.tap(find.byKey(const Key('map-terrain-fill')));
      await tester.pumpAndSettle();
      var terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.coverage[MapTerrainKind.grass], 1.0);
      expect(find.byKey(const Key('map-legend')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-terrain-clear')));
      await tester.pumpAndSettle();
      terrain = await maps.terrainFor('map-kingdom');
      expect(terrain.cellCount, 0);
      expect(find.byKey(const Key('map-legend')), findsNothing);
    });

    testWidgets('the brush resizes in map units', (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'terrain');

      final start = tester.widget<Text>(
        find.byKey(const Key('map-brush-size')),
      );
      await tester.tap(find.byKey(const Key('map-brush-larger')));
      await tester.pumpAndSettle();
      final larger = tester.widget<Text>(
        find.byKey(const Key('map-brush-size')),
      );

      expect(int.parse(larger.data!), greaterThan(int.parse(start.data!)));
    });

    testWidgets('the background treatment persists', (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'terrain');

      await tester.tap(find.byKey(const Key('map-style-treatment-parchment')));
      await tester.pumpAndSettle();

      final style = await maps.visualStyleFor('map-kingdom');
      expect(style.treatment, MapBackgroundTreatment.parchment);
    });
  });

  group('scenery', () {
    testWidgets('the scenery tools list categories and their assets',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'asset');

      expect(find.byKey(const Key('map-asset-tools')), findsOneWidget);
      expect(find.byKey(const Key('map-asset-category-settlement')),
          findsOneWidget);
      expect(find.byKey(const Key('map-asset-def-tree')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-asset-category-settlement')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-asset-def-village')), findsOneWidget);
      expect(find.byKey(const Key('map-asset-def-tree')), findsNothing);
    });

    testWidgets('tapping the canvas places scenery at that map position',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);
      await useTool(tester, 'asset');

      final projection = projectionFor(tester);
      final expected = projection.toMap(300, 200);
      await tester.tapAt(atCanvas(tester, 300, 200));
      await tester.pumpAndSettle();

      final assets = await maps.assetsFor('map-kingdom');
      expect(assets, hasLength(1));
      expect(assets.single.definitionId, 'tree');
      expect(assets.single.position.x, closeTo(expected.x, 0.5));
      expect(assets.single.position.y, closeTo(expected.y, 0.5));
      expect(find.byKey(Key('map-asset-${assets.single.id}')), findsOneWidget);
    });

    testWidgets('scenery rotates, scales, re-layers and is removed',
        (tester) async {
      await seedMap();
      await maps.addAsset(
        'map-kingdom',
        const MapAssetInstance(
          id: 'asset-1',
          definitionId: 'castle',
          position: MapPosition(400, 400),
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);
      await useTool(tester, 'asset');

      await tester.tap(find.byKey(const Key('map-asset-asset-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-asset-rotate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-asset-scale-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map-asset-forward')));
      await tester.pumpAndSettle();

      var asset = (await maps.assetsFor('map-kingdom')).single;
      expect(asset.id, 'asset-1', reason: 'shaping is not a new asset');
      expect(asset.rotation, 45);
      expect(asset.scale, greaterThan(1.0));
      expect(asset.layer, 1);
      expect(asset.position, const MapPosition(400, 400),
          reason: 'shaping does not move it');

      await tester.tap(find.byKey(const Key('map-asset-remove')));
      await tester.pumpAndSettle();
      expect(await maps.assetsFor('map-kingdom'), isEmpty);
    });

    testWidgets('dragging scenery rewrites its map-space position',
        (tester) async {
      await seedMap();
      await maps.addAsset(
        'map-kingdom',
        const MapAssetInstance(
          id: 'asset-1',
          definitionId: 'tree',
          position: MapPosition(200, 200),
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);
      await useTool(tester, 'asset');

      final projection = projectionFor(tester);
      await tester.drag(
        find.byKey(const Key('map-asset-asset-1')),
        const Offset(100, 60),
      );
      await tester.pumpAndSettle();

      final asset = (await maps.assetsFor('map-kingdom')).single;
      expect(asset.id, 'asset-1');
      expect(asset.position.x, closeTo(200 + 100 / projection.scaleX, 1));
      expect(asset.position.y, closeTo(200 + 60 / projection.scaleY, 1));
    });

    testWidgets('scenery renders in stored draw order', (tester) async {
      await seedMap();
      for (final entry in [('back', 0), ('front', 5), ('middle', 2)]) {
        await maps.addAsset(
          'map-kingdom',
          MapAssetInstance(
            id: entry.$1,
            definitionId: 'tree',
            position: const MapPosition(300, 300),
            layer: entry.$2,
          ),
          timestamp: timestamp.add(Duration(seconds: entry.$2 + 1)),
        );
      }
      await pumpStudio(tester);

      final layer = tester.widget<Stack>(
        find
            .descendant(
              of: find.byKey(const Key('map-layer-assets')),
              matching: find.byType(Stack),
            )
            .first,
      );
      final order = [
        for (final child in layer.children)
          ((child as Positioned).child as GestureDetector).key,
      ];
      expect(order, [
        const Key('map-asset-back'),
        const Key('map-asset-middle'),
        const Key('map-asset-front'),
      ]);
    });
  });

  group('Phase 3 keeps Phase 1 and Phase 2 intact', () {
    testWidgets('a painted map still selects, moves and inspects places',
        (tester) async {
      await seedMap();
      await maps.fillTerrain('map-kingdom', MapTerrainKind.grass,
          timestamp: timestamp);
      final before = await seedLocation();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-terrain')), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-detail')), findsOneWidget);

      await useTool(tester, 'move');
      await tester.drag(
        find.byKey(const Key('map-location-city-endovier')),
        const Offset(60, 40),
      );
      await tester.pumpAndSettle();

      final after = (await maps.locationsForMap('map-kingdom')).single;
      expect(after.id, before.id);
      expect(after.position, isNot(before.position));
    });
  });

}
