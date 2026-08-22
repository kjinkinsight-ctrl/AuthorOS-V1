import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/map_overlay_service.dart';
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
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Studio Phase 4 — the story overlays, driven through the Studio.
///
/// Every fixture here is written by the Studio that owns it: places by
/// [MapService], events by [TimelineService], characters by [RecordService],
/// scenes as manuscript nodes, relationships by [ConnectionEngine]. Nothing
/// seeds an overlay, because an overlay is only ever a reading.
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
  late RecordService records;
  late ConnectionEngine connections;
  late TimelineService timeline;
  late MapOverlayService overlays;
  final navigated = <MapStudioDestination>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    records = RecordService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    timeline = TimelineService(projectId: projectId, repository: repository);
    overlays = MapOverlayService(projectId: projectId, repository: repository);
    navigated.clear();
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
    tester.view.physicalSize = const Size(1400, 2400);
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
                overlays: overlays,
                onNavigate: navigated.add,
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

  Future<MapLocationView> seedLocation({
    required String id,
    required String name,
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

  Future<AuthorRecord> seedCharacter({
    required String id,
    required String name,
    String role = 'Protagonist',
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          templateId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          canonStatus: CanonStatus.canon,
          title: name,
          fields: {'identity.fullName': name, 'role': role},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<void> seedCalendar() => timeline.createCalendar(
        const TimelineCalendar(
          id: 'royal-calendar',
          name: 'Royal Calendar',
          months: [
            TimelineCalendarMonth(name: 'Ember', length: 30),
            TimelineCalendarMonth(name: 'Rain', length: 30),
          ],
          weekDays: ['Firstday', 'Secondday'],
          eraNames: ['Third Age'],
          conversionMetadata: {'epochOrdinal': 0},
        ),
        primary: true,
        timestamp: timestamp,
      );

  Future<AuthorRecord> seedEvent({
    required String id,
    required String name,
    int? year,
  }) =>
      timeline.createEvent(
        TimelineEventDraft(
          id: id,
          name: name,
          typeId: 'timeline-event',
          summary: name,
          start: year == null
              ? null
              : TimelineDate(calendarId: 'royal-calendar', year: year),
        ),
        timestamp: timestamp,
      );

  Future<void> seedScene({required String id, required String title}) =>
      repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: id,
          projectId: projectId,
          nodeType: 'scene',
          title: title,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ]);

  Future<void> link(String source, String target, String type) =>
      connections.connect(
        sourceId: source,
        targetId: target,
        typeId: type,
        timestamp: timestamp,
      );

  /// One map with a character, two dated events, a scene and a journey — the
  /// smallest world that exercises every overlay kind at once.
  Future<void> seedStory() async {
    await seedMap();
    await seedCalendar();
    await seedLocation(
      id: 'city-endovier',
      name: 'Endovier',
      position: const MapPosition(200, 200),
    );
    await seedLocation(
      id: 'city-orynth',
      name: 'Orynth',
      position: const MapPosition(700, 500),
    );
    await seedCharacter(id: 'character-mara', name: 'Mara');
    await seedCharacter(id: 'character-cass', name: 'Cass', role: 'Rival');
    await link('character-mara', 'city-endovier', 'locatedAt');
    await seedEvent(id: 'event-siege', name: 'The Siege', year: 12);
    await seedEvent(id: 'event-crowning', name: 'The Crowning', year: 13);
    await link('event-siege', 'city-endovier', 'occursAt');
    await link('event-crowning', 'city-orynth', 'occursAt');
    await link('event-siege', 'character-mara', 'involves');
    await link('event-crowning', 'character-mara', 'involves');
    await seedScene(id: 'scene-first-bell', title: 'The First Bell');
    await link('scene-first-bell', 'city-endovier', 'locatedAt');
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------------------- drawing ---

  group('overlays are drawn from canonical data', () {
    testWidgets('characters, events and scenes reach the map', (tester) async {
      await seedStory();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-overlay-panel')), findsOneWidget);
      expect(find.byKey(const Key('map-overlay-character-character-mara')),
          findsOneWidget);
      expect(find.byKey(const Key('map-overlay-scene-scene-first-bell')),
          findsNothing,
          reason: 'the scene shares Endovier with the character and clusters');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);
      expect(
        find.byKey(const Key('map-overlay-legend')),
        findsOneWidget,
        reason: 'shape and text carry the category, not colour alone',
      );
      for (final kind in MapOverlayKind.values) {
        expect(find.byKey(Key('map-overlay-legend-${kind.name}')),
            findsOneWidget);
      }
    });

    testWidgets('overlays sharing a place are one cluster with a count',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      // Mara, the siege and the first bell all sit at Endovier.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a place with nothing on it reports what is unmapped',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      expect(
        find.byKey(const Key('map-overlay-unmapped-character')),
        findsOneWidget,
        reason: 'Cass is linked to nowhere and is counted, not hidden',
      );
      expect(find.textContaining('1 characters have no mapped location'),
          findsOneWidget);
    });

    testWidgets('a map with no story data still draws its own places',
        (tester) async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-location-city-endovier')),
          findsOneWidget);
      expect(find.byKey(const Key('map-overlay-panel')), findsOneWidget);
      expect(find.byKey(const Key('map-overlay-detail')), findsNothing);
    });
  });

  // ------------------------------------------------------------ filtering ---

  group('overlay controls', () {
    testWidgets('a kind can be hidden and brought back', (tester) async {
      await seedStory();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);

      await press(tester, 'map-overlay-filter-event');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsNothing);

      await press(tester, 'map-overlay-filter-event');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);
    });

    testWidgets('the whole overlay layer can be switched off', (tester) async {
      await seedStory();
      await pumpStudio(tester);

      await press(tester, 'map-overlays-toggle');
      expect(find.byKey(const Key('map-overlay-character-character-mara')),
          findsNothing);
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsNothing);
      expect(
        find.byKey(const Key('map-location-city-endovier')),
        findsOneWidget,
        reason: 'the map itself is untouched by an overlay switch',
      );

      await press(tester, 'map-overlays-toggle');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);
    });

    testWidgets('the story clock hides what has not happened yet',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-overlay-timeline')), findsOneWidget);
      expect(find.text('Whole story'), findsWidgets);

      // Stand at the first moment: the siege has happened, the crowning has
      // not.
      await press(tester, 'map-overlay-moment-prev');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsNothing);
      expect(find.byKey(const Key('map-overlay-moment-position')),
          findsOneWidget);

      await press(tester, 'map-overlay-show-future');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);

      await press(tester, 'map-overlay-whole-story');
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsOneWidget);
    });

    testWidgets('story moment mode shows one point in the story',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      await press(tester, 'map-overlay-moment-next');
      await press(tester, 'map-overlay-story-moment');

      // Standing at the siege: the crowning is still ahead.
      expect(find.byKey(const Key('map-overlay-event-event-crowning')),
          findsNothing);
      // Undated overlays are never claimed to happen at another time.
      expect(find.byKey(const Key('map-overlay-character-character-mara')),
          findsOneWidget);
    });

    testWidgets('a journey is drawn only when the author asks for it',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-story-paths')), findsNothing);

      await press(tester, 'map-journey-character-mara');
      expect(find.byKey(const Key('map-story-paths')), findsOneWidget);

      await press(tester, 'map-journey-character-mara');
      expect(find.byKey(const Key('map-story-paths')), findsNothing);
    });
  });

  // --------------------------------------------------------------- focus ---

  group('search and focus', () {
    testWidgets('searching finds an entity and centres the map on it',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      final before = tester.getCenter(
        find.byKey(const Key('map-overlay-event-event-crowning')),
      );

      await tester.enterText(
        find.byKey(const Key('map-overlay-search')),
        'Crowning',
      );
      await tester.pumpAndSettle();
      await press(tester, 'map-overlay-result-event-event-crowning');

      final after = tester.getCenter(
        find.byKey(const Key('map-overlay-event-event-crowning')),
      );
      final canvas = tester.getRect(find.byKey(const Key('map-canvas')));

      expect(after, isNot(before), reason: 'the camera moved to the entity');
      expect((after.dx - canvas.center.dx).abs(), lessThan(24));
      expect(find.byKey(const Key('map-overlay-detail')), findsOneWidget);
    });

    testWidgets('a search that matches nothing says so', (tester) async {
      await seedStory();
      await pumpStudio(tester);

      await tester.enterText(
        find.byKey(const Key('map-overlay-search')),
        'a city that was never written',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-overlay-no-results')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------- navigation ---

  group('overlays lead back to the Studio that owns them', () {
    testWidgets('a character opens Character Studio', (tester) async {
      await seedStory();
      await pumpStudio(tester);

      await press(tester, 'map-overlay-event-event-crowning');
      expect(find.byKey(const Key('map-overlay-detail')), findsOneWidget);
      expect(find.text('Open in Timeline Studio'), findsOneWidget);

      await press(tester, 'map-overlay-open-button');
      expect(navigated, [MapStudioDestination.timeline]);
    });

    testWidgets('the detail panel reads the record and never edits it',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      final before = (await repository.snapshot()).toJson();

      await press(tester, 'map-overlay-event-event-crowning');
      expect(find.byKey(const Key('map-overlay-detail-summary')),
          findsOneWidget);
      await press(tester, 'map-overlay-focus-button');
      await press(tester, 'map-overlay-detail-close');

      expect(find.byKey(const Key('map-overlay-detail')), findsNothing);
      expect((await repository.snapshot()).toJson(), before);
    });
  });

  // ------------------------------------------------------------ integrity ---

  group('Phase 4 writes nothing and regresses nothing', () {
    testWidgets('every overlay control leaves the database untouched',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      final before = (await repository.snapshot()).toJson();

      await press(tester, 'map-overlay-filter-character');
      await press(tester, 'map-overlay-moment-next');
      await press(tester, 'map-overlay-story-moment');
      await press(tester, 'map-overlay-show-past');
      await press(tester, 'map-journey-character-mara');
      await press(tester, 'map-overlays-toggle');
      await press(tester, 'map-overlay-whole-story');

      expect((await repository.snapshot()).toJson(), before,
          reason: 'the overlay layer asks questions; it never answers with a '
              'write',
      );
    });

    testWidgets('the Phase 1–3 editor still works with overlays on top',
        (tester) async {
      await seedStory();
      await pumpStudio(tester);

      // Phase 2: select a place and read its detail.
      await press(tester, 'map-location-city-orynth');
      expect(find.byKey(const Key('map-detail')), findsOneWidget);

      // Phase 3: the terrain tools still open.
      await press(tester, 'map-tool-terrain');
      expect(find.byKey(const Key('map-terrain-tools')), findsOneWidget);

      // Phase 2: the camera still zooms.
      await press(tester, 'map-zoom-in-button');
      expect(find.text('125%'), findsOneWidget);
    });
  });
}
