import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/map_overlay_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map Studio Phase 4 — the overlay projection.
///
/// These tests read the story through the same records, links and manuscript
/// nodes the rest of AuthorOS writes. Nothing here seeds an overlay table,
/// because there is no overlay table: every expectation below is a claim about
/// what canonical data already says.
const projectId = 'project-map';
const otherProjectId = 'project-other';
final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;
  late RecordService records;
  late ConnectionEngine connections;
  late TimelineService timeline;
  late MapOverlayService overlays;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    records = RecordService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    timeline = TimelineService(projectId: projectId, repository: repository);
    overlays = MapOverlayService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<void> seedMap() => maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedLocation({
    required String id,
    required String name,
    MapPosition position = const MapPosition(200, 200),
    String mapId = 'map-kingdom',
  }) =>
      maps.createLocation(
        MapLocationDraft(
          id: id,
          mapId: mapId,
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
    String scope = projectId,
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          templateId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: scope,
          projectId: scope,
          canonStatus: CanonStatus.canon,
          title: name,
          fields: {'identity.fullName': name, 'role': role},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  /// Timeline Studio's own calendar, created the way Timeline Studio creates
  /// it. Events are dated against it, and the overlay layer only ever reads
  /// what that dating produced.
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
    int month = 1,
    int day = 1,
  }) =>
      timeline.createEvent(
        TimelineEventDraft(
          id: id,
          name: name,
          typeId: 'timeline-event',
          summary: name,
          start: year == null
              ? null
              : TimelineDate(
                  calendarId: 'royal-calendar',
                  year: year,
                  month: month,
                  day: day,
                ),
        ),
        timestamp: timestamp,
      );

  Future<void> link(String source, String target, String type) =>
      connections.connect(
        sourceId: source,
        targetId: target,
        typeId: type,
        timestamp: timestamp,
      );

  Future<void> seedScene({
    required String id,
    required String title,
    String nodeType = 'scene',
    String project = projectId,
  }) =>
      repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: id,
          projectId: project,
          nodeType: nodeType,
          title: title,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ]);

  group('the story clock', () {
    test('a moment is read from the event\'s own start date', () {
      final moment = MapStoryMoment.fromEventFields(const {
        'start': [
          {'year': 12, 'month': 2, 'day': 4, 'era': 'Third Age'},
        ],
      });

      expect(moment, isNotNull);
      expect(moment!.sortKey, 12 * 100000 + 2 * 1000 + 4);
      expect(moment.label, 'Third Age · Year 12 · Month 2 · Day 4');
      expect(moment.approximate, isFalse);
    });

    test('an undated event is given no moment at all', () {
      expect(MapStoryMoment.fromEventFields(const {}), isNull);
      expect(MapStoryMoment.fromEventFields(const {'start': []}), isNull);
      expect(
        MapStoryMoment.fromEventFields(const {
          'start': [
            {'month': 2},
          ],
        }),
        isNull,
      );
    });

    test('moments order by year, then month, then day', () {
      final moments = [
        MapStoryMoment.fromEventFields(const {
          'start': [
            {'year': 12, 'month': 5},
          ],
        })!,
        MapStoryMoment.fromEventFields(const {
          'start': [
            {'year': 11, 'month': 9},
          ],
        })!,
        MapStoryMoment.fromEventFields(const {
          'start': [
            {'year': 12, 'month': 2},
          ],
        })!,
      ]..sort();

      expect(
        moments.map((moment) => moment.sortKey),
        [11 * 100000 + 9000, 12 * 100000 + 2000, 12 * 100000 + 5000],
      );
    });
  });

  group('the overlay filter', () {
    MapOverlayItem item({
      String id = 'event-a',
      MapOverlayKind kind = MapOverlayKind.event,
      int? sortKey,
    }) =>
        MapOverlayItem(
          id: id,
          projectId: projectId,
          kind: kind,
          position: const MapPosition(10, 10),
          label: id,
          sourceId: id,
          sourceType: 'timeline-event',
          moment: sortKey == null
              ? null
              : MapStoryMoment(sortKey: sortKey, label: 'Year $sortKey'),
        );

    test('a hidden kind is hidden whatever its date', () {
      const filter = MapOverlayFilter(visible: {MapOverlayKind.location});

      expect(filter.allows(item(sortKey: 10)), isFalse);
      expect(filter.allows(item(kind: MapOverlayKind.location)), isTrue);
    });

    test('the past stays and the future is hidden until it is revealed', () {
      const filter = MapOverlayFilter(moment: 100);

      expect(filter.allows(item(sortKey: 50)), isTrue, reason: 'the past');
      expect(filter.allows(item(sortKey: 100)), isTrue, reason: 'now');
      expect(filter.allows(item(sortKey: 150)), isFalse, reason: 'the future');
      expect(filter.copyWith(showFuture: true).allows(item(sortKey: 150)),
          isTrue);
      expect(filter.copyWith(showPast: false).allows(item(sortKey: 50)),
          isFalse);
    });

    test('an undated overlay is never hidden by the clock', () {
      const filter = MapOverlayFilter(moment: 100, showPast: false);

      expect(filter.allows(item()), isTrue);
    });

    test('toggling a kind or a journey leaves the rest of the filter alone',
        () {
      const filter = MapOverlayFilter(moment: 100, showFuture: true);
      final without = filter.toggling(MapOverlayKind.event);

      expect(without.shows(MapOverlayKind.event), isFalse);
      expect(without.moment, 100);
      expect(without.showFuture, isTrue);
      expect(without.toggling(MapOverlayKind.event).shows(MapOverlayKind.event),
          isTrue);

      final traced = filter.togglingJourney('character-mara');
      expect(traced.journeyCharacterIds, {'character-mara'});
      expect(traced.togglingJourney('character-mara').journeyCharacterIds,
          isEmpty);
    });

    test('clearing the moment returns the whole story', () {
      const filter = MapOverlayFilter(moment: 100);

      expect(filter.isWholeStory, isFalse);
      expect(filter.copyWith(clearMoment: true).isWholeStory, isTrue);
    });
  });

  group('clusters and journeys', () {
    MapOverlayItem at(String id, double x, double y) => MapOverlayItem(
          id: id,
          projectId: projectId,
          kind: MapOverlayKind.character,
          position: MapPosition(x, y),
          label: id,
          sourceId: id,
          sourceType: 'character',
          locationName: 'Endovier',
        );

    test('overlays sharing a position become one reachable cluster', () {
      final clusters = MapOverlayCluster.clusterAll([
        at('a', 10, 10),
        at('b', 40, 40),
        at('c', 10, 10),
      ]);

      expect(clusters, hasLength(2));
      expect(clusters.first.count, 2);
      expect(clusters.first.items.map((item) => item.id), ['a', 'c']);
      expect(clusters.first.isSingle, isFalse);
      expect(clusters.first.semanticLabel, contains('2 items at Endovier'));
      expect(clusters.last.isSingle, isTrue);
    });

    test('a journey needs two mapped, dated stops before it is drawn', () {
      MapJourneyStop stop(String id, int sortKey) => MapJourneyStop(
            position: const MapPosition(10, 10),
            locationId: 'city',
            locationName: 'Endovier',
            eventId: id,
            eventName: id,
            moment: MapStoryMoment(sortKey: sortKey, label: 'Year $sortKey'),
          );

      const alone = MapJourney(
        characterId: 'character-mara',
        characterName: 'Mara',
        stops: [],
      );
      final one = MapJourney(
        characterId: 'character-mara',
        characterName: 'Mara',
        stops: [stop('a', 1)],
      );
      final two = MapJourney(
        characterId: 'character-mara',
        characterName: 'Mara',
        stops: [stop('a', 1), stop('b', 2)],
      );

      expect(alone.isEmpty, isTrue);
      expect(one.isDrawable, isFalse);
      expect(two.isDrawable, isTrue);
      expect(two.legs, hasLength(1));
      expect(two.semanticLabel, contains('Mara'));
    });
  });

  group('the overlay projection reads canonical data', () {
    test('a character stands where the story already put them', () async {
      await seedMap();
      await seedLocation(
        id: 'city-endovier',
        name: 'Endovier',
        position: const MapPosition(200, 300),
      );
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'locatedAt');

      final data = await overlays.loadOverlays('map-kingdom');
      final character = data.ofKind(MapOverlayKind.character).single;

      expect(character.label, 'Mara');
      expect(character.position, const MapPosition(200, 300));
      expect(character.sourceId, 'character-mara');
      expect(character.sourceType, 'character');
      expect(character.locationName, 'Endovier');
      expect(character.subtitle, 'Protagonist');
    });

    test('the Character Studio edge places them just as well', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'livesIn');

      final data = await overlays.loadOverlays('map-kingdom');

      expect(data.ofKind(MapOverlayKind.character), hasLength(1));
      expect(data.unmappedOf(MapOverlayKind.character), 0);
    });

    test('a character with no place is counted, never invented', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await seedCharacter(id: 'character-cass', name: 'Cass');
      await link('character-mara', 'city-endovier', 'locatedAt');

      final data = await overlays.loadOverlays('map-kingdom');

      expect(data.ofKind(MapOverlayKind.character).single.label, 'Mara');
      expect(data.unmappedOf(MapOverlayKind.character), 1);
    });

    test('an event stands where it occurs, dated by its own record', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCalendar();
      await seedEvent(id: 'event-siege', name: 'The Siege', year: 12, month: 2);
      await seedEvent(id: 'event-rumour', name: 'A Rumour');
      await link('event-siege', 'city-endovier', 'occursAt');
      await link('event-rumour', 'city-endovier', 'occursAt');

      final data = await overlays.loadOverlays('map-kingdom');
      final events = data.ofKind(MapOverlayKind.event);

      expect(events, hasLength(2));
      final siege = events.firstWhere((item) => item.label == 'The Siege');
      final rumour = events.firstWhere((item) => item.label == 'A Rumour');
      expect(siege.isDated, isTrue);
      expect(siege.moment!.sortKey, 12 * 100000 + 2 * 1000 + 1);
      expect(rumour.isDated, isFalse,
          reason: 'an undated event is never given a date');
      expect(data.moments, hasLength(1));
    });

    test('a scene appears through the manuscript node it already is', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedScene(id: 'scene-first-bell', title: 'The First Bell');
      await link('scene-first-bell', 'city-endovier', 'locatedAt');

      final data = await overlays.loadOverlays('map-kingdom');
      final scene = data.ofKind(MapOverlayKind.scene).single;

      expect(scene.label, 'The First Bell');
      expect(scene.sourceId, 'scene-first-bell');
      expect(scene.sourceType, 'scene');
      expect(scene.locationName, 'Endovier');
      expect(
        await repository.recordById('scene-first-bell'),
        isNull,
        reason: 'a scene stays a manuscript node and never becomes a record',
      );
    });

    test('a journey is the dated events a character is in, in order', () async {
      await seedMap();
      await seedLocation(
        id: 'city-endovier',
        name: 'Endovier',
        position: const MapPosition(100, 100),
      );
      await seedLocation(
        id: 'city-orynth',
        name: 'Orynth',
        position: const MapPosition(400, 400),
      );
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'locatedAt');
      await seedCalendar();
      await seedEvent(id: 'event-later', name: 'The Crowning', year: 13);
      await seedEvent(id: 'event-early', name: 'The Siege', year: 12);
      await seedEvent(id: 'event-undated', name: 'A Rumour');
      await link('event-early', 'city-endovier', 'occursAt');
      await link('event-later', 'city-orynth', 'occursAt');
      await link('event-undated', 'city-orynth', 'occursAt');
      await link('event-early', 'character-mara', 'involves');
      await link('event-later', 'character-mara', 'involves');
      await link('event-undated', 'character-mara', 'involves');

      final journey = await overlays.journeyFor('map-kingdom', 'character-mara');

      expect(journey, isNotNull);
      expect(journey!.characterName, 'Mara');
      expect(
        journey.stops.map((stop) => stop.eventName),
        ['The Siege', 'The Crowning'],
        reason: 'story order, and only the stops the data supports',
      );
      expect(journey.stops.first.position, const MapPosition(100, 100));
      expect(journey.stops.last.position, const MapPosition(400, 400));
      expect(journey.isDrawable, isTrue);
      expect(journey.legs, hasLength(1));
    });

    test('another project never reaches this map', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'locatedAt');
      await RecordService(projectId: otherProjectId, repository: repository)
          .createRecord(
        AuthorRecord(
          id: 'character-stranger',
          typeId: 'character',
          templateId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: otherProjectId,
          projectId: otherProjectId,
          canonStatus: CanonStatus.canon,
          title: 'A Stranger',
          fields: const {'identity.fullName': 'A Stranger'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      await seedScene(
        id: 'scene-elsewhere',
        title: 'Elsewhere',
        project: otherProjectId,
      );

      final data = await overlays.loadOverlays('map-kingdom');

      expect(
        data.items.map((item) => item.label),
        isNot(contains('A Stranger')),
      );
      expect(data.ofKind(MapOverlayKind.scene), isEmpty);
      expect(data.items.every((item) => item.projectId == projectId), isTrue);
    });

    test('an archived character leaves the map', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      final character = await seedCharacter(
        id: 'character-mara',
        name: 'Mara',
      );
      await link('character-mara', 'city-endovier', 'locatedAt');

      expect(
        (await overlays.loadOverlays('map-kingdom'))
            .ofKind(MapOverlayKind.character),
        hasLength(1),
      );

      await records.archiveRecord(
        character.id,
        timestamp: timestamp.add(const Duration(hours: 1)),
      );

      final data = await overlays.loadOverlays('map-kingdom');
      expect(data.ofKind(MapOverlayKind.character), isEmpty);
      expect(data.unmappedOf(MapOverlayKind.character), 0,
          reason: 'an archived character is gone, not merely unplaced');
    });

    test('a location on another map is not on this one', () async {
      await seedMap();
      await maps.createMap(
        const MapDraft(id: 'map-city', title: 'City Map'),
        timestamp: timestamp,
      );
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedLocation(
        id: 'street-market',
        name: 'The Market',
        mapId: 'map-city',
      );

      final data = await overlays.loadOverlays('map-kingdom');

      expect(
        data.ofKind(MapOverlayKind.location).map((item) => item.label),
        ['Endovier'],
      );
    });

    test('reading overlays writes nothing at all', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'locatedAt');
      await seedCalendar();
      await seedEvent(id: 'event-siege', name: 'The Siege', year: 12);
      await link('event-siege', 'city-endovier', 'occursAt');
      await link('event-siege', 'character-mara', 'involves');
      await seedScene(id: 'scene-first-bell', title: 'The First Bell');
      await link('scene-first-bell', 'city-endovier', 'locatedAt');

      final before = (await repository.snapshot()).toJson();
      await overlays.loadOverlays('map-kingdom');
      await overlays.journeyFor('map-kingdom', 'character-mara');
      final after = (await repository.snapshot()).toJson();

      expect(after, before,
          reason: 'the overlay layer is a reading of the story, not a write');
    });

    test('a search finds an entity by name, place or subtitle', () async {
      await seedMap();
      await seedLocation(id: 'city-endovier', name: 'Endovier');
      await seedCharacter(id: 'character-mara', name: 'Mara');
      await link('character-mara', 'city-endovier', 'locatedAt');

      final data = await overlays.loadOverlays('map-kingdom');

      expect(data.search('mara').single.sourceId, 'character-mara');
      expect(data.search('endovier').map((item) => item.kind),
          contains(MapOverlayKind.character));
      expect(data.search('protagonist').single.label, 'Mara');
      expect(data.search('   '), isEmpty);
      expect(data.search('nobody'), isEmpty);
    });
  });
}
