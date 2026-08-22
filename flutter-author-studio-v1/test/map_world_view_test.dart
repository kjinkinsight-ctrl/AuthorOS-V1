import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/map_studio_view.dart';
import 'package:author_studio_v1/map_world_service.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Studio Phase 5 — the world simulation, driven through the Studio.
const projectId = 'project-map';
final timestamp = DateTime.utc(2026, 8, 22, 9);

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
  late WorldService world;
  late RecordService records;
  late ConnectionEngine connections;
  late MapWorldService worlds;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    world = WorldService(projectId: projectId, repository: repository);
    records = RecordService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    worlds = MapWorldService(projectId: projectId, repository: repository);
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
    tester.view.physicalSize = const Size(1400, 3200);
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
              child: MapStudioView(
                project: testProject,
                service: maps,
                world: worlds,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedMap() => maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedPlace({
    required String id,
    required String name,
    MapPosition position = const MapPosition(200, 200),
    String locationType = 'City',
  }) =>
      maps.createLocation(
        MapLocationDraft(
          id: id,
          mapId: 'map-kingdom',
          name: name,
          locationType: locationType,
          position: position,
        ),
        timestamp: timestamp,
      );

  Future<MapRegionView> seedRegion({
    required String id,
    required String name,
  }) =>
      maps.createRegion(
        MapRegionDraft(
          id: id,
          mapId: 'map-kingdom',
          name: name,
          geometry: MapGeometry.box(
            const MapPosition(100, 100),
            const MapPosition(500, 500),
          ),
        ),
        timestamp: timestamp,
      );

  Future<AuthorRecord> seedRecord({
    required String id,
    required String title,
    required String typeId,
    Map<String, Object?> fields = const {},
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: typeId,
          templateId: typeId,
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          canonStatus: CanonStatus.canon,
          title: title,
          fields: fields,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<void> link(
    String source,
    String target,
    String type, {
    Map<String, Object?> metadata = const {},
  }) =>
      connections.connect(
        sourceId: source,
        targetId: target,
        typeId: type,
        metadata: metadata,
        timestamp: timestamp,
      );

  Future<void> seedRoute({
    required String id,
    required String title,
    required String startId,
    required String endId,
    String typeId = 'road-route',
    Map<String, Object?> fields = const {'distance': '180 miles'},
  }) =>
      world.createRoute(
        id: id,
        title: title,
        startId: startId,
        endId: endId,
        typeId: typeId,
        metadata: fields,
        timestamp: timestamp,
      );

  /// A small world: two cities on a road, a region that changes hands.
  Future<void> seedWorld() async {
    await seedMap();
    await seedPlace(id: 'city-aurel', name: 'Aurel', locationType: 'capital');
    await seedPlace(
      id: 'city-blackmere',
      name: 'Blackmere',
      position: const MapPosition(700, 400),
    );
    await seedRegion(id: 'region-north', name: 'The Northern Reach');
    await seedRecord(
        id: 'faction-aurel', title: 'Kingdom of Aurel', typeId: 'faction');
    await seedRecord(
        id: 'faction-noxmere', title: 'House Noxmere', typeId: 'organisation');
    await link('faction-aurel', 'region-north', 'rules',
        metadata: {'startDate': 405, 'endDate': 417});
    await link('faction-noxmere', 'region-north', 'rules',
        metadata: {'startDate': 417});
    await seedRoute(
      id: 'route-north',
      title: 'The North Road',
      startId: 'city-aurel',
      endId: 'city-blackmere',
    );
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> choose<T>(
    WidgetTester tester,
    String key,
    String label,
  ) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('the world panel reads canonical data', () {
    testWidgets('it counts what the world actually contains', (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-world-panel')), findsOneWidget);
      expect(find.byKey(const Key('map-world-count-settlements')),
          findsOneWidget);
      expect(find.byKey(const Key('map-world-count-routes')), findsOneWidget);
      expect(find.byKey(const Key('map-world-summary')), findsOneWidget);
      expect(find.byKey(const Key('map-world-routes')), findsOneWidget,
          reason: 'the road is drawn on the canvas');
    });

    testWidgets('a map with nothing dated says so instead of inventing an era',
        (tester) async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-world-no-eras')), findsOneWidget);
      expect(find.byKey(const Key('map-world-whole-story')), findsNothing);
    });

    testWidgets('the era control walks the story and comes back',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      expect(find.text('The whole story'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);

      await press(tester, 'map-world-era-prev');
      expect(find.text('The whole story'), findsNothing);
      expect(find.text('Historical'), findsOneWidget,
          reason: 'the first dated moment is before the last');

      await press(tester, 'map-world-whole-story');
      expect(find.text('The whole story'), findsOneWidget);
    });

    testWidgets('the world layers can be switched off without touching the map',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      await press(tester, 'map-world-routes-toggle');
      expect(find.byKey(const Key('map-world-routes')), findsNothing);
      expect(find.byKey(const Key('map-location-city-aurel')), findsOneWidget,
          reason: 'the map itself is untouched by a world switch');

      await press(tester, 'map-world-routes-toggle');
      expect(find.byKey(const Key('map-world-routes')), findsOneWidget);

      await press(tester, 'map-world-toggle');
      expect(find.byKey(const Key('map-world-routes')), findsNothing);
    });
  });

  group('travel is answered from the data or not at all', () {
    testWidgets('a road with a distance gives an explained answer',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      await choose(tester, 'map-world-travel-from', 'Aurel');
      await choose(tester, 'map-world-travel-to', 'Blackmere');
      await press(tester, 'map-world-travel-button');

      expect(find.byKey(const Key('map-world-travel-result')), findsOneWidget);
      expect(find.text('6 days on foot'), findsOneWidget);
      expect(find.byKey(const Key('map-world-travel-line-0')), findsOneWidget);
      expect(find.textContaining('180 miles'), findsOneWidget);
    });

    testWidgets('a route with no travel data reports the gap, not a number',
        (tester) async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
        id: 'city-blackmere',
        name: 'Blackmere',
        position: const MapPosition(700, 400),
      );
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: const {},
      );
      await pumpStudio(tester);

      await choose(tester, 'map-world-travel-from', 'Aurel');
      await choose(tester, 'map-world-travel-to', 'Blackmere');
      await press(tester, 'map-world-travel-button');

      expect(find.textContaining('No travel data'), findsOneWidget);
      expect(find.textContaining('days on foot'), findsNothing);
    });
  });

  group('world queries', () {
    testWidgets('asking what a faction holds lights up its ground',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      await press(tester, 'map-world-query-faction-noxmere');

      expect(find.byKey(const Key('map-world-query-result')), findsOneWidget);
      expect(find.textContaining('House Noxmere'), findsWidgets);
      expect(find.textContaining('The Northern Reach'), findsWidgets);

      await press(tester, 'map-world-query-clear');
      expect(find.byKey(const Key('map-world-query-result')), findsNothing);
    });

    testWidgets('a faction that holds nothing at this era is told plainly',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      // Stand in 405–417, when Noxmere holds nothing.
      await press(tester, 'map-world-era-prev');
      await press(tester, 'map-world-query-faction-noxmere');

      expect(find.byKey(const Key('map-world-query-note')), findsOneWidget);
      expect(find.textContaining('No holding is recorded'), findsOneWidget);
    });
  });

  group('Phase 5 writes nothing and regresses nothing', () {
    testWidgets('every world control leaves the database untouched',
        (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      final before = (await repository.snapshot()).toJson();

      await press(tester, 'map-world-era-prev');
      await press(tester, 'map-world-era-next');
      await press(tester, 'map-world-whole-story');
      await press(tester, 'map-world-borders-toggle');
      await press(tester, 'map-world-routes-toggle');
      await press(tester, 'map-world-toggle');
      await press(tester, 'map-world-query-faction-aurel');
      await choose(tester, 'map-world-travel-from', 'Aurel');
      await choose(tester, 'map-world-travel-to', 'Blackmere');
      await press(tester, 'map-world-travel-button');

      expect((await repository.snapshot()).toJson(), before,
          reason: 'simulating a world never edits it');
    });

    testWidgets('the Phase 1–4 map still works underneath', (tester) async {
      await seedWorld();
      await pumpStudio(tester);

      await press(tester, 'map-location-city-blackmere');
      expect(find.byKey(const Key('map-detail')), findsOneWidget);

      await press(tester, 'map-tool-terrain');
      expect(find.byKey(const Key('map-terrain-tools')), findsOneWidget);

      await press(tester, 'map-zoom-in-button');
      expect(find.text('125%'), findsOneWidget);

      expect(find.byKey(const Key('map-overlay-panel')), findsOneWidget,
          reason: 'the Phase 4 overlay panel is still there');
    });
  });
}
