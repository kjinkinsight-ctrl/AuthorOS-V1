/// Map Studio Phase 5 — the world-state projection.
///
/// Like the Phase 4 overlay service, this is **read-only by construction**: no
/// create, update or delete method, no write path, no store of its own. A world
/// state is computed from records and links the rest of AuthorOS already owns,
/// and thrown away when the view rebuilds.
///
/// What it reads, and nothing else:
///
/// - **Settlements** — location records placed on this map, with their own
///   worldbuilding fields (population, culture, government, economy, climate).
/// - **Territories** — region records placed on this map, held by whoever a
///   `controls` link says holds them.
/// - **Borders** — `border` records placed on this map, between whatever a
///   `borders` link says they run between.
/// - **Routes** — route records whose `routeFrom`/`routeTo` endpoints are both
///   on this map, with the distance, travel time, difficulty and danger the
///   author recorded.
/// - **Resources** — `resource` records tied to a placed location.
/// - **Conditions** — timeline records that name a condition and occur at a
///   placed location, plus the `climate` an author wrote on a place.
///
/// Time comes from the same clock Phase 4 uses: link metadata `startDate` and
/// `endDate`, and event dates. A holding with no dates has, as far as the data
/// says, always been that way — which is what the map shows.
///
/// Where the data does not say, the projection says nothing. It never fills a
/// gap with a plausible value.
library;

import 'core/connected_domain.dart';
import 'core/timeline_record_types.dart';
import 'core/world_record_types.dart';
import 'map_domain.dart';
import 'map_overlay_service.dart';
import 'map_world.dart';
import 'persistence/authoros_database.dart';

export 'map_world.dart';

/// The link types the world projection reads. Reading only — nothing writes.
class MapWorldLinks {
  const MapWorldLinks._();

  /// A faction holds a place, a territory or a resource.
  ///
  /// `controls` carries no metadata in the canonical registry, so a holding
  /// expressed with it has no dates and is read as "holds it, as far as the
  /// data says". `rules` and `governedBy` are open, temporal relationships that
  /// do carry `startDate`/`endDate`, which is how a border that moved in 417
  /// gets to be a border that moved in 417. All three are read; none is
  /// written, and no fourth edge was invented to hold a date.
  static const controls = 'controls';
  static const rules = 'rules';
  static const governedBy = 'governedBy';

  /// Every edge that can say who holds something.
  static const holdings = {controls, rules, governedBy};

  /// A thing sits inside a place.
  static const locatedIn = 'locatedIn';

  /// A thing is at a place.
  static const locatedAt = 'locatedAt';

  /// Two spatial records share an edge.
  static const borders = 'borders';

  /// A route's two ends.
  static const routeFrom = 'routeFrom';
  static const routeTo = 'routeTo';

  /// An event happens at a place.
  static const occursAt = 'occursAt';

  /// A place holds a thing, or is known for one.
  static const contains = 'contains';
  static const knownFor = 'knownFor';

  /// Every link the world projection consults.
  static const all = {
    controls,
    rules,
    governedBy,
    locatedIn,
    locatedAt,
    contains,
    knownFor,
    borders,
    routeFrom,
    routeTo,
    occursAt,
  };

  /// The edges that can tie a thing to a place.
  ///
  /// Several, because the canonical vocabulary offers several and different
  /// Studios reach for different ones: a resource may be `locatedAt` a city,
  /// the city may `contain` it, or the city may be `knownFor` it.
  static const toPlace = {locatedIn, locatedAt, contains, knownFor, occursAt};
}

/// Record types the world projection recognises.
///
/// Every id here comes from the canonical registries. Map Studio adds no type
/// of its own and recognises nothing AuthorOS has not already defined.
class MapWorldTypes {
  const MapWorldTypes._();

  static const resource = 'resource';
  static const border = 'border';

  static const factions = <String>{
    'faction',
    'organisation',
    'house',
    'clan',
    'government',
  };

  static Set<String> get routes => WorldRecordTypes.routeTypeIds;

  static Set<String> get timelineRecords => {
        ...TimelineRecordTypes.recordTypeIds,
        'historical-event',
      };

  /// Words that make a timeline record an environmental condition rather than a
  /// plot event. Matched against the record's type and its `eventType` field,
  /// so an author names the weather in their own words and the map reads it.
  static const conditionWords = <String>{
    'weather',
    'season',
    'climate',
    'temperature',
    'rainfall',
    'rain',
    'snow',
    'snowfall',
    'storm',
    'tempest',
    'blizzard',
    'drought',
    'flood',
    'frost',
    'phenomenon',
    'anomaly',
  };
}

class MapWorldService {
  const MapWorldService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// The overlay projection, reused rather than reimplemented.
  ///
  /// Character journeys are a Phase 4 reading and stay one: "where has this
  /// character been" has exactly one answer in the codebase.
  MapOverlayService get overlays =>
      MapOverlayService(projectId: projectId, repository: repository);

  /// The world as it stands at [moment], or as a whole when [moment] is null.
  ///
  /// Reproducible: the same records and links always produce the same state,
  /// in the same order, with the same holders.
  Future<MapWorldState> loadWorldState(
    String mapId, {
    int? moment,
    MapStoryMoment? momentLabel,
  }) async {
    final all = await repository.recordsByProject(projectId);
    final active = [
      for (final record in all)
        if (record.status == AuthorRecordStatus.active) record,
    ];
    final byId = {for (final record in active) record.id: record};

    // Everything on this map, split the way Map Studio has always split it:
    // points are places, geometry is ground.
    final points = <String, AuthorRecord>{};
    final regions = <String, AuthorRecord>{};
    for (final record in active) {
      if (record.fields[MapFields.mapId] != mapId) continue;
      if (record.typeId == MapTypes.region) {
        regions[record.id] = record;
      } else if (MapTypes.locationTypeIds.contains(record.typeId)) {
        points[record.id] = record;
      }
    }

    MapPosition? positionOf(String id) {
      final record = points[id] ?? regions[id];
      if (record == null) return null;
      return MapPosition.read(record.fields,
          xKey: MapFields.x, yKey: MapFields.y);
    }

    String nameOf(String id) => byId[id]?.title ?? '';

    final links = <String, List<RecordLink>>{};
    Future<List<RecordLink>> linksOf(String id) async =>
        links[id] ??= [
          for (final link in await repository.backlinks(id))
            if (link.scopeId == projectId) link,
        ];

    final moments = <int, MapStoryMoment>{};
    void noteMoment(MapStoryMoment? value) {
      if (value != null) moments[value.sortKey] = value;
    }

    // --- who holds what ---------------------------------------------------
    //
    // One pass over `controls` links, dated, so a holding that ended before the
    // selected moment simply is not a holding at that moment.
    final factions = <String, String>{};
    final holders = <String, _Holding>{};
    final claims = <String, Set<String>>{};
    for (final record in active) {
      if (!MapWorldTypes.factions.contains(record.typeId)) continue;
      factions[record.id] = record.title;
      for (final link in await linksOf(record.id)) {
        if (!MapWorldLinks.holdings.contains(link.typeId)) continue;
        final held = link.sourceId == record.id ? link.targetId : link.sourceId;
        final from = MapWorldClock.momentFrom(link.metadata['startDate']);
        final to = MapWorldClock.momentFrom(link.metadata['endDate']);
        noteMoment(from);
        noteMoment(to);
        claims.putIfAbsent(held, () => <String>{}).add(record.id);
        if (!MapWorldClock.existsAt(moment, from, to)) continue;
        final holding = _Holding(record.id, record.title, from, to);
        final existing = holders[held];
        // Deterministic: the holder whose claim starts latest wins, ties by id.
        if (existing == null || holding.outranks(existing)) {
          holders[held] = holding;
        }
      }
    }

    // --- settlements ------------------------------------------------------
    final settlements = <MapSettlement>[];
    for (final entry in points.entries) {
      final record = entry.value;
      final position = positionOf(entry.key);
      if (position == null) continue;
      final founded = MapWorldClock.momentFrom(
        record.fields['founded'] ?? record.fields['startDate'],
      );
      final ended = MapWorldClock.momentFrom(
        record.fields['destroyed'] ?? record.fields['endDate'],
      );
      noteMoment(founded);
      noteMoment(ended);
      if (!MapWorldClock.existsAt(moment, founded, ended)) continue;
      final holder = holders[record.id];
      settlements.add(
        MapSettlement(
          id: record.id,
          name: record.title,
          kind: MapSettlementKindLabel.fromTypeId(
            record.typeId,
            settlementType: _string(record.fields[MapFields.locationType]),
          ),
          position: position,
          holderId: holder?.id ?? '',
          holderName: holder?.name ?? '',
          population: _int(record.fields['population']),
          culture: _string(record.fields['culture']),
          government: _string(record.fields['government']),
          economy: _string(record.fields['economy']),
          military: _string(record.fields['military']),
          importance: _string(record.fields['importance']),
          status: _string(record.fields['status']),
          foundedAt: founded,
          endedAt: ended,
        ),
      );
    }

    // --- territories ------------------------------------------------------
    final territories = <MapTerritory>[];
    for (final entry in regions.entries) {
      final record = entry.value;
      final geometry = MapGeometry.read(record.fields);
      if (!geometry.isValid) continue;
      final holder = holders[record.id];
      final bounds = geometry.bounds;
      final inside = <String>[
        if (bounds != null)
          for (final settlement in settlements)
            if (bounds.contains(settlement.position)) settlement.id,
      ]..sort();
      territories.add(
        MapTerritory(
          id: record.id,
          name: record.title,
          kind: MapTerritoryKindLabel.fromValue(
            _string(record.fields['regionType']).isEmpty
                ? _string(record.fields[MapFields.locationType])
                : _string(record.fields['regionType']),
          ),
          geometry: geometry,
          holderId: holder?.id ?? '',
          holderName: holder?.name ?? '',
          settlementIds: inside,
          from: holder?.from,
          to: holder?.to,
          isDisputed: (claims[record.id] ?? const <String>{}).length > 1,
        ),
      );
    }

    // --- borders ----------------------------------------------------------
    final borders = <MapBorder>[];
    for (final record in active) {
      if (record.typeId != MapWorldTypes.border) continue;
      if (record.fields[MapFields.mapId] != mapId) continue;
      final geometry = MapGeometry.read(record.fields);
      if (!geometry.isValid) continue;
      final from = MapWorldClock.momentFrom(record.fields['startDate']);
      final to = MapWorldClock.momentFrom(record.fields['endDate']);
      noteMoment(from);
      noteMoment(to);
      if (!MapWorldClock.existsAt(moment, from, to)) continue;
      final between = <String>[
        for (final link in await linksOf(record.id))
          if (link.typeId == MapWorldLinks.borders)
            link.sourceId == record.id ? link.targetId : link.sourceId,
      ]..sort();
      borders.add(
        MapBorder(
          id: record.id,
          name: record.title,
          kind: MapBorderKindLabel.fromValue(
            _string(record.fields['borderType']).isEmpty
                ? _string(record.fields['status'])
                : _string(record.fields['borderType']),
          ),
          geometry: geometry,
          betweenIds: between,
          from: from,
          to: to,
        ),
      );
    }

    // --- routes -----------------------------------------------------------
    final routes = <MapWorldRoute>[];
    for (final record in active) {
      if (!MapWorldTypes.routes.contains(record.typeId)) continue;
      String? startId;
      String? endId;
      Map<String, Object?> endpointMetadata = const {};
      for (final link in await linksOf(record.id)) {
        final other = link.sourceId == record.id ? link.targetId : link.sourceId;
        if (link.typeId == MapWorldLinks.routeFrom) {
          startId = other;
          endpointMetadata = link.metadata;
        } else if (link.typeId == MapWorldLinks.routeTo) {
          endId = other;
        }
      }
      startId ??= _string(record.fields['startId']);
      endId ??= _string(record.fields['endId']);
      final start = positionOf(startId);
      final end = positionOf(endId);
      // A route is on this map only when both of its ends are.
      if (start == null || end == null) continue;

      final from = MapWorldClock.momentFrom(
        record.fields['startDate'] ?? endpointMetadata['startDate'],
      );
      final to = MapWorldClock.momentFrom(
        record.fields['endDate'] ?? endpointMetadata['endDate'],
      );
      noteMoment(from);
      noteMoment(to);
      if (!MapWorldClock.existsAt(moment, from, to)) continue;

      final measured = parseMeasurement(
        record.fields['distance'] ?? endpointMetadata['distance'],
      );
      final holder = holders[record.id];
      routes.add(
        MapWorldRoute(
          id: record.id,
          name: record.title,
          kind: MapRouteKindLabel.fromTypeId(
            record.typeId,
            routeType: _string(record.fields['routeType']),
          ),
          fromId: startId,
          toId: endId,
          fromName: nameOf(startId),
          toName: nameOf(endId),
          fromPosition: start,
          toPosition: end,
          distance: measured.value,
          distanceUnit: measured.unit,
          statedTravelDays: parseTravelDays(
            record.fields['travelTime'] ?? endpointMetadata['travelTime'],
          ),
          difficulty: _string(
            record.fields['difficulty'] ?? endpointMetadata['difficulty'],
          ),
          danger: _string(record.fields['danger'] ?? endpointMetadata['danger']),
          holderId: holder?.id ?? '',
          holderName: holder?.name ?? '',
          conditions: _string(
            record.fields['conditions'] ?? endpointMetadata['conditions'],
          ),
          from: from,
          to: to,
        ),
      );
    }

    // --- resources --------------------------------------------------------
    final resources = <MapResource>[];
    for (final record in active) {
      if (record.typeId != MapWorldTypes.resource) continue;
      String? placeId;
      MapStoryMoment? from;
      MapStoryMoment? to;
      for (final link in await linksOf(record.id)) {
        if (!MapWorldLinks.toPlace.contains(link.typeId)) continue;
        final other = link.sourceId == record.id ? link.targetId : link.sourceId;
        if (!points.containsKey(other) && !regions.containsKey(other)) continue;
        // Deterministic where a resource is tied to several places.
        if (placeId == null || other.compareTo(placeId) < 0) {
          placeId = other;
          from = MapWorldClock.momentFrom(link.metadata['startDate']);
          to = MapWorldClock.momentFrom(link.metadata['endDate']);
        }
      }
      if (placeId == null) continue;
      final position = positionOf(placeId);
      if (position == null) continue;
      noteMoment(from);
      noteMoment(to);
      if (!MapWorldClock.existsAt(moment, from, to)) continue;
      final holder = holders[record.id];
      resources.add(
        MapResource(
          id: record.id,
          name: record.title,
          locationId: placeId,
          locationName: nameOf(placeId),
          position: position,
          abundance: _string(record.fields['abundance']),
          holderId: holder?.id ?? '',
          holderName: holder?.name ?? '',
          extraction: _string(record.fields['extraction']),
          from: from,
          to: to,
        ),
      );
    }

    // --- environmental conditions -----------------------------------------
    //
    // Author-controlled by construction: a condition exists on the map because
    // the author wrote a timeline record that names one, or wrote a climate on
    // a place. Nothing is modelled, simulated or fetched.
    final conditions = <MapCondition>[];
    for (final entry in points.entries) {
      final climate = _string(entry.value.fields['climate']);
      if (climate.isEmpty) continue;
      conditions.add(
        MapCondition(
          id: 'climate-${entry.key}',
          label: climate,
          kind: MapConditionKind.climate,
          locationId: entry.key,
          locationName: entry.value.title,
          position: positionOf(entry.key),
        ),
      );
    }
    for (final record in active) {
      if (!MapWorldTypes.timelineRecords.contains(record.typeId)) continue;
      final descriptor = '${record.typeId} '
              '${_string(record.fields['eventType'])} ${record.title}'
          .toLowerCase();
      final word = MapWorldTypes.conditionWords
          .where((value) => descriptor.contains(value))
          .firstOrNull;
      if (word == null) continue;
      String? placeId;
      for (final link in await linksOf(record.id)) {
        if (!MapWorldLinks.toPlace.contains(link.typeId)) continue;
        final other = link.sourceId == record.id ? link.targetId : link.sourceId;
        if (!points.containsKey(other) && !regions.containsKey(other)) continue;
        if (placeId == null || other.compareTo(placeId) < 0) placeId = other;
      }
      if (placeId == null) continue;
      final at = MapStoryMoment.fromEventFields(record.fields);
      noteMoment(at);
      if (!MapWorldClock.existsAt(moment, at, at)) continue;
      conditions.add(
        MapCondition(
          id: record.id,
          label: record.title,
          kind: MapConditionKindLabel.fromValue(word),
          locationId: placeId,
          locationName: nameOf(placeId),
          position: positionOf(placeId),
          detail: _string(record.fields['summary']),
          from: at,
          to: at,
        ),
      );
    }

    settlements.sort((a, b) => a.id.compareTo(b.id));
    territories.sort((a, b) => a.id.compareTo(b.id));
    borders.sort((a, b) => a.id.compareTo(b.id));
    routes.sort((a, b) => a.id.compareTo(b.id));
    resources.sort((a, b) => a.id.compareTo(b.id));
    conditions.sort((a, b) => a.id.compareTo(b.id));
    final ordered = moments.values.toList()..sort();

    return MapWorldState(
      mapId: mapId,
      projectId: projectId,
      kind: _kindFor(moment, ordered),
      moment: momentLabel ??
          (moment == null ? null : moments[moment]),
      settlements: settlements,
      territories: territories,
      borders: borders,
      routes: routes,
      resources: resources,
      conditions: conditions,
      moments: ordered,
      factions: factions,
    );
  }

  /// Whether the selected moment is the world's present, its past or its plans.
  MapWorldStateKind _kindFor(int? moment, List<MapStoryMoment> moments) {
    if (moment == null || moments.isEmpty) return MapWorldStateKind.current;
    if (moment < moments.last.sortKey) return MapWorldStateKind.historical;
    if (moment > moments.last.sortKey) return MapWorldStateKind.planned;
    return MapWorldStateKind.current;
  }

  // ------------------------------------------------------------- queries ---

  /// Everything a faction holds on this map.
  Future<MapWorldQueryResult> controlledBy(
    String mapId,
    String factionId, {
    int? moment,
  }) async {
    final state = await loadWorldState(mapId, moment: moment);
    final name = state.factions[factionId] ?? factionId;
    final territories = state.territoriesOf(factionId);
    final settlements = state.settlementsOf(factionId);
    return MapWorldQueryResult(
      kind: MapWorldQueryKind.controlledBy,
      subject: name,
      highlightedIds: [
        for (final item in territories) item.id,
        for (final item in settlements) item.id,
      ],
      lines: [
        for (final item in territories) '${item.name} — ${item.kind.label}',
        for (final item in settlements) '${item.name} — ${item.kind.label}',
      ],
      note: territories.isEmpty && settlements.isEmpty
          ? 'No holding is recorded for $name at this point in the story.'
          : '',
    );
  }

  /// The ways between two places, and the shortest of them.
  Future<MapWorldQueryResult> routesBetween(
    String mapId,
    String fromId,
    String toId, {
    int? moment,
    MapTravelMode mode = MapTravelMode.foot,
    MapSeason season = MapSeason.none,
  }) async {
    final state = await loadWorldState(mapId, moment: moment);
    final direct = [
      for (final route in state.routes)
        if ((route.fromId == fromId && route.toId == toId) ||
            (route.fromId == toId && route.toId == fromId))
          route,
    ];
    final estimate = state.travelBetween(
      fromId,
      toId,
      mode: mode,
      season: season,
    );
    final from = state.settlementById(fromId)?.name ?? fromId;
    final to = state.settlementById(toId)?.name ?? toId;
    return MapWorldQueryResult(
      kind: MapWorldQueryKind.routesBetween,
      subject: '$from and $to',
      highlightedIds: <String>{
        for (final route in direct) route.id,
        for (final leg in estimate.legs) leg.route.id,
      }.toList(),
      lines: [
        for (final route in direct) route.semanticLabel,
        ...estimate.explanation,
      ],
      note: estimate.isAvailable ? '' : estimate.reason,
    );
  }

  /// Where a character has been, read through the Phase 4 journey projection.
  Future<MapWorldQueryResult> visitedBy(
    String mapId,
    String characterId,
  ) async {
    final journey = await overlays.journeyFor(mapId, characterId);
    if (journey == null || journey.isEmpty) {
      return MapWorldQueryResult(
        kind: MapWorldQueryKind.visitedBy,
        subject: characterId,
        note: 'No dated events place this character anywhere on this map.',
      );
    }
    return MapWorldQueryResult(
      kind: MapWorldQueryKind.visitedBy,
      subject: journey.characterName,
      highlightedIds: <String>{
        for (final stop in journey.stops) stop.locationId,
      }.toList(),
      lines: [
        for (final stop in journey.stops)
          '${stop.moment.label} — ${stop.locationName} (${stop.eventName})',
      ],
    );
  }

  /// The scenes set inside a territory.
  Future<MapWorldQueryResult> scenesIn(String mapId, String territoryId) async {
    final state = await loadWorldState(mapId);
    final territory =
        state.territories.where((item) => item.id == territoryId).firstOrNull;
    if (territory == null) {
      return MapWorldQueryResult(
        kind: MapWorldQueryKind.scenesIn,
        subject: territoryId,
        note: 'That territory is not on this map.',
      );
    }
    final data = await overlays.loadOverlays(mapId);
    final inside = {...territory.settlementIds};
    final scenes = [
      for (final item in data.ofKind(MapOverlayKind.scene))
        if (inside.contains(item.locationId)) item,
    ];
    return MapWorldQueryResult(
      kind: MapWorldQueryKind.scenesIn,
      subject: territory.name,
      highlightedIds: [for (final scene in scenes) scene.locationId],
      lines: [
        for (final scene in scenes) '${scene.label} — ${scene.locationName}',
      ],
      note: scenes.isEmpty
          ? 'No scene is set at a place inside ${territory.name}.'
          : '',
    );
  }

  /// The places an event touched.
  Future<MapWorldQueryResult> affectedBy(String mapId, String eventId) async {
    final event = await repository.recordById(eventId);
    final state = await loadWorldState(mapId);
    if (event == null) {
      return MapWorldQueryResult(
        kind: MapWorldQueryKind.affectedBy,
        subject: eventId,
        note: 'That event is not in this project.',
      );
    }
    final touched = <String>{};
    for (final link in await repository.backlinks(eventId)) {
      if (link.scopeId != projectId) continue;
      final other = link.sourceId == eventId ? link.targetId : link.sourceId;
      if (state.settlementById(other) != null ||
          state.territories.any((item) => item.id == other) ||
          state.routeById(other) != null) {
        touched.add(other);
      }
    }
    final ids = touched.toList()..sort();
    return MapWorldQueryResult(
      kind: MapWorldQueryKind.affectedBy,
      subject: event.title,
      highlightedIds: ids,
      lines: [
        for (final id in ids)
          state.settlementById(id)?.name ??
              state.routeById(id)?.name ??
              state.territories
                  .where((item) => item.id == id)
                  .map((item) => item.name)
                  .firstOrNull ??
              id,
      ],
      note: ids.isEmpty
          ? '${event.title} is not linked to any place on this map.'
          : '',
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = parseMeasurement(value);
      return parsed.value?.round();
    }
    return null;
  }
}

/// One faction's claim on one thing, with the dates that bound it.
class _Holding {
  const _Holding(this.id, this.name, this.from, this.to);

  final String id;
  final String name;
  final MapStoryMoment? from;
  final MapStoryMoment? to;

  /// The later claim wins; an undated claim never displaces a dated one; ties
  /// break on id so the same data always names the same holder.
  bool outranks(_Holding other) {
    final mine = from?.sortKey;
    final theirs = other.from?.sortKey;
    if (mine != null && theirs == null) return true;
    if (mine == null && theirs != null) return false;
    if (mine != null && theirs != null && mine != theirs) return mine > theirs;
    return id.compareTo(other.id) < 0;
  }
}
