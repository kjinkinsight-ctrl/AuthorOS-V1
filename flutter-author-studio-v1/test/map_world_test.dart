import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/map_world_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map Studio Phase 5 — the world state, read from canonical data.
///
/// Every fixture here is written the way the owning Studio writes it: places
/// through [MapService], routes through [WorldService], factions and resources
/// as ordinary records, holdings as `controls` links with dates on them. No
/// test seeds a world state, because no world state is stored.
const projectId = 'project-map';
const otherProjectId = 'project-other';
final timestamp = DateTime.utc(2026, 8, 22, 9);

/// A year on the story's clock, in the sort-key form the shared clock uses.
int year(int value) => value * 100000;

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;
  late WorldService world;
  late RecordService records;
  late ConnectionEngine connections;
  late MapWorldService worlds;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    world = WorldService(projectId: projectId, repository: repository);
    records = RecordService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    worlds = MapWorldService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<void> seedMap() => maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedPlace({
    required String id,
    required String name,
    MapPosition position = const MapPosition(200, 200),
    String locationType = 'City',
    Map<String, Object?> fields = const {},
  }) async {
    final view = await maps.createLocation(
      MapLocationDraft(
        id: id,
        mapId: 'map-kingdom',
        name: name,
        locationType: locationType,
        position: position,
      ),
      timestamp: timestamp,
    );
    if (fields.isEmpty) return view;
    final stored = await repository.recordById(id);
    await records.updateRecord(
      stored!.copyWith(
        fields: {...stored.fields, ...fields},
        updatedAt: timestamp.add(const Duration(minutes: 1)),
      ),
    );
    return view;
  }

  Future<MapRegionView> seedRegion({
    required String id,
    required String name,
    MapGeometry? geometry,
    String regionType = 'kingdom',
  }) async {
    final view = await maps.createRegion(
      MapRegionDraft(
        id: id,
        mapId: 'map-kingdom',
        name: name,
        geometry: geometry ??
            MapGeometry.box(
              const MapPosition(100, 100),
              const MapPosition(500, 500),
            ),
      ),
      timestamp: timestamp,
    );
    final stored = await repository.recordById(id);
    await records.updateRecord(
      stored!.copyWith(
        fields: {...stored.fields, 'regionType': regionType},
        updatedAt: timestamp.add(const Duration(minutes: 1)),
      ),
    );
    return view;
  }

  Future<AuthorRecord> seedRecord({
    required String id,
    required String title,
    required String typeId,
    Map<String, Object?> fields = const {},
    String scope = projectId,
  }) =>
      RecordService(projectId: scope, repository: repository).createRecord(
        AuthorRecord(
          id: id,
          typeId: typeId,
          templateId: typeId,
          scopeType: RecordScopeType.project,
          scopeId: scope,
          projectId: scope,
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

  Future<AuthorRecord> seedRoute({
    required String id,
    required String title,
    required String startId,
    required String endId,
    String typeId = 'road-route',
    Map<String, Object?> fields = const {},
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

  group('reading measurements an author typed', () {
    test('a distance is read with or without its unit', () {
      expect(parseMeasurement(120).value, 120);
      expect(parseMeasurement('120').value, 120);
      expect(parseMeasurement('120 miles').value, 120);
      expect(parseMeasurement('120 miles').unit, 'miles');
      expect(parseMeasurement('about 87.5km').value, 87.5);
      expect(parseMeasurement('a long way').value, isNull);
      expect(parseMeasurement(null).value, isNull);
    });

    test('a travel time is converted only from units it understands', () {
      expect(parseTravelDays('6 days'), 6);
      expect(parseTravelDays('6'), 6);
      expect(parseTravelDays('12 hours'), 0.5);
      expect(parseTravelDays('2 weeks'), 14);
      expect(parseTravelDays('1 month'), 30);
      expect(parseTravelDays('2 fortnights'), isNull,
          reason: 'an unrecognised unit is not silently treated as days');
      expect(parseTravelDays('soon'), isNull);
    });
  });

  group('the shared clock', () {
    test('a date is read from every shape the canonical layer stores', () {
      expect(MapWorldClock.momentFrom(412)!.sortKey, year(412));
      expect(MapWorldClock.momentFrom('412')!.sortKey, year(412));
      expect(
        MapWorldClock.momentFrom({'year': 412, 'month': 2, 'day': 4})!.sortKey,
        412 * 100000 + 2 * 1000 + 4,
      );
      expect(MapWorldClock.momentFrom('not a date'), isNull);
      expect(MapWorldClock.momentFrom(null), isNull);
    });

    test('an open-ended span is open-ended', () {
      final from = MapWorldClock.momentFrom(412);
      final to = MapWorldClock.momentFrom(417);

      expect(MapWorldClock.existsAt(null, from, to), isTrue,
          reason: 'the whole story shows everything');
      expect(MapWorldClock.existsAt(year(410), from, to), isFalse);
      expect(MapWorldClock.existsAt(year(414), from, to), isTrue);
      expect(MapWorldClock.existsAt(year(420), from, to), isFalse);
      expect(MapWorldClock.existsAt(year(420), from, null), isTrue,
          reason: 'no end date means it has not ended');
      expect(MapWorldClock.existsAt(year(400), null, to), isTrue,
          reason: 'no start date means the data does not say it began');
    });
  });

  group('the world state is a reading of canonical data', () {
    test('places on the map become settlements with their own metadata',
        () async {
      await seedMap();
      await seedPlace(
        id: 'city-aurel',
        name: 'Aurel',
        locationType: 'capital',
        fields: {
          'population': 48000,
          'culture': 'Aurelian',
          'government': 'Monarchy',
          'climate': 'Temperate',
        },
      );
      await seedPlace(
        id: 'ruin-vey',
        name: 'Old Vey',
        locationType: 'ruin',
        position: const MapPosition(600, 400),
      );

      final state = await worlds.loadWorldState('map-kingdom');
      final aurel = state.settlementById('city-aurel')!;
      final vey = state.settlementById('ruin-vey')!;

      expect(aurel.kind, MapSettlementKind.capital);
      expect(aurel.population, 48000);
      expect(aurel.culture, 'Aurelian');
      expect(aurel.government, 'Monarchy');
      expect(aurel.kind.rank, greaterThan(vey.kind.rank));
      expect(vey.isRuin, isTrue);
      expect(vey.kind.isInhabited, isFalse);
      expect(
        state.conditions.map((item) => item.label),
        contains('Temperate'),
        reason: 'a climate an author wrote is an environmental condition',
      );
    });

    test('a faction holds what the controls link says it holds', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRegion(id: 'region-north', name: 'The Northern Reach');
      await seedRecord(
        id: 'faction-aurel',
        title: 'Kingdom of Aurel',
        typeId: 'faction',
      );
      await link('faction-aurel', 'region-north', 'controls');
      await link('faction-aurel', 'city-aurel', 'controls');

      final state = await worlds.loadWorldState('map-kingdom');

      expect(state.factions['faction-aurel'], 'Kingdom of Aurel');
      expect(state.territoriesOf('faction-aurel').single.name,
          'The Northern Reach');
      expect(state.settlementsOf('faction-aurel').single.name, 'Aurel');
      expect(state.territories.single.kind, MapTerritoryKind.kingdom);
      expect(state.territories.single.settlementIds, ['city-aurel']);
      expect(state.territories.single.isDisputed, isFalse);
    });

    test('a territory two factions claim is disputed, not silently assigned',
        () async {
      await seedMap();
      await seedRegion(id: 'region-vey', name: 'The Vey Marches');
      await seedRecord(
          id: 'faction-aurel', title: 'Aurel', typeId: 'faction');
      await seedRecord(
          id: 'faction-noxmere',
          title: 'House Noxmere',
          typeId: 'organisation');
      await link('faction-aurel', 'region-vey', 'controls');
      await link('faction-noxmere', 'region-vey', 'controls');

      final state = await worlds.loadWorldState('map-kingdom');

      expect(state.territories.single.isDisputed, isTrue);
    });

    test('the map at an earlier moment shows the earlier holder', () async {
      await seedMap();
      await seedRegion(id: 'region-vey', name: 'The Vey Marches');
      await seedRecord(id: 'faction-aurel', title: 'Aurel', typeId: 'faction');
      await seedRecord(
          id: 'faction-noxmere',
          title: 'House Noxmere',
          typeId: 'organisation');
      // `rules` is the canonical dated holding edge: `controls` carries no
      // metadata, so a holding that changes hands is written with `rules`.
      await link('faction-aurel', 'region-vey', 'rules',
          metadata: {'startDate': 405, 'endDate': 417});
      await link('faction-noxmere', 'region-vey', 'rules',
          metadata: {'startDate': 417});

      final before = await worlds.loadWorldState('map-kingdom',
          moment: year(412));
      final after =
          await worlds.loadWorldState('map-kingdom', moment: year(421));

      expect(before.territories.single.holderName, 'Aurel');
      expect(before.kind, MapWorldStateKind.historical);
      expect(after.territories.single.holderName, 'House Noxmere');
      expect(before.moments.map((moment) => moment.sortKey),
          containsAll([year(405), year(417)]));
    });

    test('the same read twice gives exactly the same world', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRegion(id: 'region-north', name: 'The Northern Reach');
      await seedRecord(id: 'faction-aurel', title: 'Aurel', typeId: 'faction');
      await link('faction-aurel', 'region-north', 'controls');
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: {'distance': '180 miles'},
      );

      final first = await worlds.loadWorldState('map-kingdom');
      final second = await worlds.loadWorldState('map-kingdom');

      expect(
        second.settlements.map((item) => item.id).toList(),
        first.settlements.map((item) => item.id).toList(),
      );
      expect(second.routes.single.distance, first.routes.single.distance);
      expect(second.territories.single.holderId,
          first.territories.single.holderId);
    });

    test('a route counts only when both ends are on this map', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRecord(
        id: 'city-elsewhere',
        title: 'Elsewhere',
        typeId: 'city',
      );
      await seedRoute(
        id: 'route-away',
        title: 'The Long Way Out',
        startId: 'city-aurel',
        endId: 'city-elsewhere',
      );

      final state = await worlds.loadWorldState('map-kingdom');

      expect(state.routes, isEmpty);
    });

    test('a resource sits where the story says it is found', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRecord(
        id: 'resource-iron',
        title: 'Vey Iron',
        typeId: 'resource',
        fields: {'abundance': 'Rich'},
      );
      await link('city-aurel', 'resource-iron', 'knownFor');
      await seedRecord(id: 'faction-aurel', title: 'Aurel', typeId: 'faction');
      await link('faction-aurel', 'resource-iron', 'controls');

      final state = await worlds.loadWorldState('map-kingdom');
      final iron = state.resourcesAt('city-aurel').single;

      expect(iron.name, 'Vey Iron');
      expect(iron.abundance, 'Rich');
      expect(iron.holderName, 'Aurel');
      expect(iron.position, const MapPosition(200, 200));
    });

    test('another project never reaches this map', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRecord(
        id: 'faction-stranger',
        title: 'A Stranger Court',
        typeId: 'faction',
        scope: otherProjectId,
      );

      final state = await worlds.loadWorldState('map-kingdom');

      expect(state.factions.containsKey('faction-stranger'), isFalse);
      expect(state.projectId, projectId);
    });

    test('reading the world writes nothing at all', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRegion(id: 'region-north', name: 'The Northern Reach');
      await seedRecord(id: 'faction-aurel', title: 'Aurel', typeId: 'faction');
      await link('faction-aurel', 'region-north', 'controls');
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: {'distance': '180 miles'},
      );

      final before = (await repository.snapshot()).toJson();
      await worlds.loadWorldState('map-kingdom');
      await worlds.loadWorldState('map-kingdom', moment: year(412));
      await worlds.controlledBy('map-kingdom', 'faction-aurel');
      await worlds.routesBetween('map-kingdom', 'city-aurel', 'city-blackmere');
      final after = (await repository.snapshot()).toJson();

      expect(after, before,
          reason: 'the world state is a reading, never a write');
    });
  });

  group('travel is calculated, never guessed', () {
    Future<MapWorldState> twoTowns({
      Map<String, Object?> routeFields = const {'distance': '180 miles'},
      String typeId = 'road-route',
    }) async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        typeId: typeId,
        fields: routeFields,
      );
      return worlds.loadWorldState('map-kingdom');
    }

    test('distance and mode give a deterministic, explained answer', () async {
      final state = await twoTowns();

      final onFoot = state.travelBetween('city-aurel', 'city-blackmere');
      final riding = state.travelBetween('city-aurel', 'city-blackmere',
          mode: MapTravelMode.horse);

      expect(onFoot.isAvailable, isTrue);
      expect(onFoot.wholeDays, 6, reason: '180 ÷ 30 per day on a road');
      expect(riding.wholeDays, 3, reason: '180 ÷ 60 per day on a road');
      expect(onFoot.explanation.first, contains('180 miles'));
      expect(onFoot.explanation.last, contains('Total'));
      expect(
        state.travelBetween('city-aurel', 'city-blackmere').days,
        onFoot.days,
        reason: 'the same question always gives the same answer',
      );
    });

    test('winter is slower, and says so', () async {
      final state = await twoTowns();

      final summer = state.travelBetween('city-aurel', 'city-blackmere',
          season: MapSeason.summer);
      final winter = state.travelBetween('city-aurel', 'city-blackmere',
          season: MapSeason.winter);

      expect(winter.days!, greaterThan(summer.days!));
      expect(winter.wholeDays, 10, reason: '6 days × 1.6 winter');
      expect(winter.explanation.first, contains('winter'));
    });

    test('a mountain pass costs more than a road over the same distance',
        () async {
      final state = await twoTowns();
      await seedPlace(
          id: 'city-vey', name: 'Vey', position: const MapPosition(300, 600));
      await seedPlace(
          id: 'city-orynth',
          name: 'Orynth',
          position: const MapPosition(800, 600));
      await seedRoute(
        id: 'route-pass',
        title: 'The High Pass',
        startId: 'city-vey',
        endId: 'city-orynth',
        typeId: 'tunnel-route',
        fields: {'distance': '180 miles'},
      );
      final withPass = await worlds.loadWorldState('map-kingdom');

      expect(
        withPass.travelBetween('city-vey', 'city-orynth').days,
        greaterThan(state.travelBetween('city-aurel', 'city-blackmere').days!),
        reason: 'the same 180 miles over a pass is a longer journey',
      );
      expect(withPass.routeById('route-pass')!.kind, MapRouteKind.mountainPass);
    });

    test('terrain slows the crossing when the map has terrain under it',
        () async {
      final state = await twoTowns();

      final flat = state.travelBetween('city-aurel', 'city-blackmere');
      final mountainous = state.travelBetween(
        'city-aurel',
        'city-blackmere',
        terrainAt: (position) => 'mountain',
      );

      expect(mountainous.days!, greaterThan(flat.days!));
      expect(mountainous.explanation.first, contains('mountain'));
    });

    test("the author's own travel time wins over the calculation", () async {
      final state = await twoTowns(
        routeFields: {'distance': '180 miles', 'travelTime': '2 days'},
      );

      final estimate = state.travelBetween('city-aurel', 'city-blackmere');

      expect(estimate.wholeDays, 2);
      expect(estimate.explanation.first, contains('as recorded'));
    });

    test('no travel data means no answer, not a plausible number', () async {
      final state = await twoTowns(routeFields: const {});

      final estimate = state.travelBetween('city-aurel', 'city-blackmere');

      expect(estimate.isAvailable, isFalse);
      expect(estimate.days, isNull);
      expect(estimate.reason, contains('No travel data'));
      expect(estimate.summary, estimate.reason);
    });

    test('no route at all is reported as no route', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));

      final state = await worlds.loadWorldState('map-kingdom');
      final estimate = state.travelBetween('city-aurel', 'city-blackmere');

      expect(estimate.isAvailable, isFalse);
      expect(estimate.reason, contains('No route'));
    });

    test('a mode that cannot use the way is refused, not routed around',
        () async {
      final state = await twoTowns();

      final byShip = state.travelBetween('city-aurel', 'city-blackmere',
          mode: MapTravelMode.ship);

      expect(byShip.isAvailable, isFalse);
      expect(byShip.reason, contains('No route'));
    });

    test('the shortest of two ways wins, and the legs are listed', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-vey', name: 'Vey', position: const MapPosition(400, 300));
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRoute(
        id: 'route-direct',
        title: 'The Long Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: {'distance': '600 miles'},
      );
      await seedRoute(
        id: 'route-a',
        title: 'The Vey Road',
        startId: 'city-aurel',
        endId: 'city-vey',
        fields: {'distance': '120 miles'},
      );
      await seedRoute(
        id: 'route-b',
        title: 'The Marsh Road',
        startId: 'city-vey',
        endId: 'city-blackmere',
        fields: {'distance': '150 miles'},
      );

      final state = await worlds.loadWorldState('map-kingdom');
      final estimate = state.travelBetween('city-aurel', 'city-blackmere');

      expect(estimate.isAvailable, isTrue);
      expect(estimate.legs.map((leg) => leg.route.id), ['route-a', 'route-b']);
      expect(estimate.wholeDays, 9, reason: '(120 + 150) ÷ 30 per day');
    });

    test('a route that has not opened yet is not travelled', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: {'distance': '180 miles', 'startDate': 417},
      );

      final early = await worlds.loadWorldState('map-kingdom',
          moment: year(412));
      final later = await worlds.loadWorldState('map-kingdom',
          moment: year(420));

      expect(early.routes, isEmpty);
      expect(
        early.travelBetween('city-aurel', 'city-blackmere').isAvailable,
        isFalse,
      );
      expect(
        later.travelBetween('city-aurel', 'city-blackmere').isAvailable,
        isTrue,
      );
    });
  });

  group('world queries', () {
    test('what a faction holds', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRegion(id: 'region-north', name: 'The Northern Reach');
      await seedRecord(
          id: 'faction-noxmere',
          title: 'House Noxmere',
          typeId: 'organisation');
      await link('faction-noxmere', 'region-north', 'controls');
      await link('faction-noxmere', 'city-aurel', 'controls');

      final result =
          await worlds.controlledBy('map-kingdom', 'faction-noxmere');

      expect(result.subject, 'House Noxmere');
      expect(result.highlightedIds, containsAll(['region-north', 'city-aurel']));
      expect(result.isEmpty, isFalse);
      expect(result.note, isEmpty);
    });

    test('a faction that holds nothing is told so plainly', () async {
      await seedMap();
      await seedRecord(id: 'faction-aurel', title: 'Aurel', typeId: 'faction');

      final result = await worlds.controlledBy('map-kingdom', 'faction-aurel');

      expect(result.isEmpty, isTrue);
      expect(result.note, contains('No holding is recorded'));
    });

    test('routes between two cities, with the working shown', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedPlace(
          id: 'city-blackmere',
          name: 'Blackmere',
          position: const MapPosition(700, 400));
      await seedRoute(
        id: 'route-north',
        title: 'The North Road',
        startId: 'city-aurel',
        endId: 'city-blackmere',
        fields: {'distance': '180 miles'},
      );

      final result = await worlds.routesBetween(
          'map-kingdom', 'city-aurel', 'city-blackmere');

      expect(result.highlightedIds, ['route-north']);
      expect(result.lines.any((line) => line.contains('Total')), isTrue);
      expect(result.note, isEmpty);
    });

    test('an event lights up the places it touched', () async {
      await seedMap();
      await seedPlace(id: 'city-blackmere', name: 'Blackmere');
      await seedRecord(
        id: 'event-siege',
        title: 'The Siege of Blackmere',
        typeId: 'timeline-battle',
      );
      await link('event-siege', 'city-blackmere', 'occursAt');

      final result = await worlds.affectedBy('map-kingdom', 'event-siege');

      expect(result.subject, 'The Siege of Blackmere');
      expect(result.highlightedIds, ['city-blackmere']);
    });

    test('an event that touched nothing on this map says so', () async {
      await seedMap();
      await seedRecord(
        id: 'event-quiet',
        title: 'A Quiet Year',
        typeId: 'timeline-event',
      );

      final result = await worlds.affectedBy('map-kingdom', 'event-quiet');

      expect(result.isEmpty, isTrue);
      expect(result.note, contains('not linked to any place'));
    });

    test('scenes set inside a territory', () async {
      await seedMap();
      await seedPlace(id: 'city-aurel', name: 'Aurel');
      await seedRegion(id: 'region-north', name: 'The Northern Reach');
      await repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'scene-first-bell',
          projectId: projectId,
          nodeType: 'scene',
          title: 'The First Bell',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ]);
      await link('scene-first-bell', 'city-aurel', 'locatedAt');

      final result = await worlds.scenesIn('map-kingdom', 'region-north');

      expect(result.subject, 'The Northern Reach');
      expect(result.lines.single, contains('The First Bell'));
      expect(result.highlightedIds, ['city-aurel']);
    });

    test('a territory that is not on this map is reported, not invented',
        () async {
      await seedMap();

      final result = await worlds.scenesIn('map-kingdom', 'region-nowhere');

      expect(result.isEmpty, isTrue);
      expect(result.note, contains('not on this map'));
    });
  });
}
