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
    tester.view.physicalSize = const Size(1400, 1200);
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

  Future<MapSummary> seedMap({
    String id = 'map-kingdom',
    String title = 'Kingdom Map',
  }) =>
      maps.createMap(
        MapDraft(id: id, title: title, description: 'The realm.'),
        timestamp: timestamp,
      );

  group('empty state', () {
    testWidgets('a project with no maps offers to create the first one',
        (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-empty-state')), findsOneWidget);
      expect(find.text('No maps yet'), findsOneWidget);
      expect(
        find.text('Create your first map to begin building your world.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-empty-create-button')), findsOneWidget);
      expect(find.byKey(const Key('map-canvas')), findsNothing);
    });
  });

  group('map creation', () {
    testWidgets('the create dialog writes a map that the canvas then shows',
        (tester) async {
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-empty-create-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-create-dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('map-create-name')),
        'Kingdom Map',
      );
      await tester.enterText(
        find.byKey(const Key('map-create-description')),
        'The realm at the height of the Crown.',
      );
      await tester.tap(find.byKey(const Key('map-create-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-empty-state')), findsNothing);
      expect(find.byKey(const Key('map-canvas')), findsOneWidget);
      expect(
        find.text('The realm at the height of the Crown.'),
        findsOneWidget,
      );

      // Not an in-memory creation: the map is a persisted record.
      final stored = await maps.listMaps();
      expect(stored.single.title, 'Kingdom Map');
    });

    testWidgets('cancelling the dialog writes nothing', (tester) async {
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-empty-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-create-name')),
        'Discarded',
      );
      await tester.tap(find.byKey(const Key('map-create-cancel')));
      await tester.pumpAndSettle();

      expect(await maps.listMaps(), isEmpty);
      expect(find.byKey(const Key('map-empty-state')), findsOneWidget);
    });
  });

  group('canvas', () {
    testWidgets('a map renders with its header and canvas', (tester) async {
      await seedMap();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-studio-title')), findsOneWidget);
      expect(find.text('MAP STUDIO'), findsOneWidget);
      expect(find.byKey(const Key('map-studio-heading')), findsOneWidget);
      expect(find.text('Kingdom Map'), findsWidgets);
      expect(find.byKey(const Key('map-canvas')), findsOneWidget);
      expect(find.byKey(const Key('map-canvas-empty')), findsOneWidget);
    });

    testWidgets('locations render on the canvas at their stored position',
        (tester) async {
      await seedMap();
      await maps.createLocation(
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
      await pumpStudio(tester);

      expect(
        find.byKey(const Key('map-location-city-endovier')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-canvas-empty')), findsNothing);
    });

    testWidgets('regions render on the canvas', (tester) async {
      await seedMap();
      await maps.createRegion(
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
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-region-region-north')), findsOneWidget);
    });

    testWidgets('markers render on the canvas', (tester) async {
      await seedMap();
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

      expect(find.byKey(const Key('map-marker-marker-well')), findsOneWidget);
    });

    testWidgets('a canvas item can be selected and shows its detail',
        (tester) async {
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-endovier',
          mapId: 'map-kingdom',
          name: 'Endovier',
          description: 'The salt city.',
          locationType: 'City',
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-detail-empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-location-city-endovier')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-detail')), findsOneWidget);
      expect(find.text('The salt city.'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
    });
  });

  group('authoring', () {
    testWidgets('a location added through the Studio persists and renders',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-add-location-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('location-create-name')),
        'Endovier',
      );
      await tester.enterText(
        find.byKey(const Key('location-create-category')),
        'City',
      );
      await tester.tap(find.byKey(const Key('location-create-confirm')));
      await tester.pumpAndSettle();

      final stored = await maps.locationsForMap('map-kingdom');
      expect(stored.single.name, 'Endovier');
      expect(stored.single.locationType, 'City');
      expect(find.byKey(Key('map-location-${stored.single.id}')),
          findsOneWidget);
    });

    testWidgets('a marker added through the Studio persists and renders',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-add-marker-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('marker-create-name')),
        'The Salt Well',
      );
      await tester.tap(find.byKey(const Key('marker-create-confirm')));
      await tester.pumpAndSettle();

      final stored = await maps.markersForMap('map-kingdom');
      expect(stored.single.label, 'The Salt Well');
      expect(
        find.byKey(Key('map-marker-${stored.single.id}')),
        findsOneWidget,
      );
    });

    testWidgets('a region added through the Studio persists and renders',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-add-region-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('region-create-name')),
        'The Northern Reach',
      );
      await tester.tap(find.byKey(const Key('region-create-confirm')));
      await tester.pumpAndSettle();

      final stored = await maps.regionsForMap('map-kingdom');
      expect(stored.single.name, 'The Northern Reach');
      expect(stored.single.geometry.points, hasLength(2));
      expect(find.byKey(Key('map-region-${stored.single.id}')), findsOneWidget);
    });

    testWidgets('map settings rewrite the persisted metadata', (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-settings-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-settings-name')),
        'Kingdom of Ash',
      );
      await tester.enterText(
        find.byKey(const Key('map-settings-description')),
        'After the war.',
      );
      await tester.tap(find.byKey(const Key('map-settings-confirm')));
      await tester.pumpAndSettle();

      final stored = await maps.getMap('map-kingdom');
      expect(stored!.title, 'Kingdom of Ash');
      expect(stored.description, 'After the war.');
      expect(find.text('After the war.'), findsOneWidget);
    });

    testWidgets('archiving the open map returns the Studio to its empty state',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('map-archive-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-empty-state')), findsOneWidget);
      expect((await maps.getMap('map-kingdom'))!.isArchived, isTrue);
    });
  });

  group('map selector', () {
    testWidgets('several maps are listed and one can be opened',
        (tester) async {
      await seedMap(id: 'map-kingdom', title: 'Kingdom Map');
      await seedMap(id: 'map-city', title: 'City Map');
      await maps.createMarker(
        const MapMarkerDraft(
          id: 'marker-well',
          mapId: 'map-kingdom',
          label: 'The Salt Well',
        ),
        timestamp: timestamp,
      );
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-selector')), findsOneWidget);
      expect(find.text('My Maps'), findsOneWidget);
      expect(find.byKey(const Key('map-selector-map-kingdom')), findsOneWidget);
      expect(find.byKey(const Key('map-selector-map-city')), findsOneWidget);

      // City Map sorts first, so the marker on the Kingdom map is not showing.
      expect(find.byKey(const Key('map-marker-marker-well')), findsNothing);
      await tester.tap(find.byKey(const Key('map-selector-map-kingdom')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-marker-marker-well')), findsOneWidget);
    });
  });

  group('theme integration', () {
    testWidgets('the Studio installs its own Theme Engine scope',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(
        scopes.map((scope) => scope.studio),
        contains(StudioId.map),
      );
    });

    testWidgets('the empty state draws from engine tokens, not literals',
        (tester) async {
      await pumpStudio(tester);

      final theme = resolvedTheme();
      final expected = AuthorOsTheme.color(
        theme.colorFor(StudioId.map, ThemeColorRef.primary),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('map-empty-state')),
          matching: find.byIcon(Icons.map_outlined),
        ),
      );
      expect(icon.color, expected);
    });

    testWidgets('the canvas ground comes from the engine surface token',
        (tester) async {
      await seedMap();
      await pumpStudio(tester);

      final theme = resolvedTheme();
      final expected = AuthorOsTheme.color(
        theme.colorFor(StudioId.map, ThemeColorRef.surfaceContainer),
      );
      final canvas = tester.widget<Container>(
        find.byKey(const Key('map-canvas')),
      );
      expect(
        (canvas.decoration as BoxDecoration).color,
        expected,
      );
    });
  });

  group('architecture', () {
    test('the Studio holds no persistence of its own', () {
      final source = File('lib/map_studio_view.dart').readAsStringSync();

      expect(source, contains('MapService'));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('authoros_database')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('AuthorOsDatabase')));
    });

    test('the Studio never hard-codes a colour or builds a ThemeData', () {
      final source = File('lib/map_studio_view.dart').readAsStringSync();

      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('ThemeData(')));
      expect(source, contains('StudioThemeScope'));
      expect(source, contains('StudioId.map'));
    });
  });
}
