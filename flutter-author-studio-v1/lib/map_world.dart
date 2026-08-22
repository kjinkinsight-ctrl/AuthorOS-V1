/// Map Studio Phase 5 — the world-state vocabulary.
///
/// Phase 4 taught the map to read the story. Phase 5 teaches it to read the
/// *world*: which settlements stand, who holds which territory, where the
/// borders run, which routes are open, what a journey between two places costs,
/// and what all of that looked like at some other point in the story.
///
/// Everything here is plain Dart with no Flutter and no persistence. A world
/// state is a **projection**: it is computed from records and links AuthorOS
/// already owns and thrown away when the view rebuilds. Map Studio visualises
/// world state; it never becomes the owner of world state.
///
/// Two rules run through the whole file:
///
/// 1. **Nothing is invented.** Where the canonical data does not say how far it
///    is, how long it takes, or who holds a place, the answer is "not defined",
///    never a plausible number. See [MapTravelEstimate.unavailable].
/// 2. **Everything is deterministic.** The same records and links always give
///    the same world state, the same route and the same estimate, down to the
///    order of the steps in the explanation.
library;

import 'map_domain.dart';
import 'map_overlays.dart';

/// Which world the author is looking at.
///
/// The distinction is about the relationship between the selected moment and
/// the story's own present, not about three different stores: all three read
/// exactly the same records.
enum MapWorldStateKind {
  /// What exists now — no moment selected, or the story's latest moment.
  current,

  /// What existed at an earlier moment.
  historical,

  /// What the author intends to happen, at a moment still ahead.
  planned,
}

extension MapWorldStateKindLabel on MapWorldStateKind {
  String get label => switch (this) {
        MapWorldStateKind.current => 'Current',
        MapWorldStateKind.historical => 'Historical',
        MapWorldStateKind.planned => 'Planned',
      };
}

/// Reads a moment out of whatever the canonical layer stored.
///
/// Link metadata declares `startDate`/`endDate` as a date field, but the value
/// that actually arrives depends on which Studio wrote it: Timeline Studio
/// writes a `TimelineDate` map, an import may leave an ISO-8601 string, and a
/// hand-typed year arrives as a number. All three are read; anything else is
/// read as "no date", which is the honest answer.
class MapWorldClock {
  const MapWorldClock._();

  static MapStoryMoment? momentFrom(Object? value) {
    if (value == null) return null;
    if (value is Map) {
      final fields = Map<String, Object?>.from(value);
      // A TimelineDate map, or the {start: [...]} shape a record field carries.
      return MapStoryMoment.fromEventFields({
            'start': [fields],
          }) ??
          MapStoryMoment.fromEventFields(fields);
    }
    if (value is num) {
      final year = value.toInt();
      return MapStoryMoment(sortKey: year * 100000, label: 'Year $year');
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final iso = DateTime.tryParse(text);
      if (iso != null) {
        return MapStoryMoment(
          sortKey: iso.year * 100000 + iso.month * 1000 + iso.day,
          label: text,
        );
      }
      final year = int.tryParse(text);
      if (year != null) {
        return MapStoryMoment(sortKey: year * 100000, label: text);
      }
    }
    return null;
  }

  /// Whether something that runs from [from] to [to] exists at [moment].
  ///
  /// An open-ended span is exactly that: something with no start date has
  /// always been there as far as the data says, and something with no end date
  /// has not ended. `null` [moment] means "the whole story", where everything
  /// the author has written down exists.
  static bool existsAt(int? moment, MapStoryMoment? from, MapStoryMoment? to) {
    if (moment == null) return true;
    if (from != null && from.sortKey > moment) return false;
    if (to != null && to.sortKey < moment) return false;
    return true;
  }
}

/// What kind of place a settlement is.
///
/// The ids are the canonical record type ids; Map Studio recognises them, it
/// does not define them.
enum MapSettlementKind {
  village,
  town,
  city,
  capital,
  fortress,
  port,
  outpost,
  camp,
  ruin,
  hidden,
  other,
}

extension MapSettlementKindLabel on MapSettlementKind {
  String get label => switch (this) {
        MapSettlementKind.village => 'Village',
        MapSettlementKind.town => 'Town',
        MapSettlementKind.city => 'City',
        MapSettlementKind.capital => 'Capital',
        MapSettlementKind.fortress => 'Fortress',
        MapSettlementKind.port => 'Port',
        MapSettlementKind.outpost => 'Outpost',
        MapSettlementKind.camp => 'Camp',
        MapSettlementKind.ruin => 'Ruin',
        MapSettlementKind.hidden => 'Hidden settlement',
        MapSettlementKind.other => 'Settlement',
      };

  /// Relative weight on the map, used for label priority and marker size.
  ///
  /// A capital outranks a city outranks a village: at low zoom the map shows
  /// what matters, and it needs an order to do that.
  int get rank => switch (this) {
        MapSettlementKind.capital => 6,
        MapSettlementKind.city => 5,
        MapSettlementKind.fortress => 4,
        MapSettlementKind.port => 4,
        MapSettlementKind.town => 3,
        MapSettlementKind.village => 2,
        MapSettlementKind.outpost => 2,
        MapSettlementKind.camp => 1,
        MapSettlementKind.ruin => 1,
        MapSettlementKind.hidden => 1,
        MapSettlementKind.other => 2,
      };

  bool get isInhabited =>
      this != MapSettlementKind.ruin && this != MapSettlementKind.hidden;

  /// Resolves a canonical record type or a settlement-type field to a kind.
  static MapSettlementKind fromTypeId(String typeId, {String settlementType = ''}) {
    final value = (settlementType.trim().isEmpty ? typeId : settlementType)
        .trim()
        .toLowerCase();
    return switch (value) {
      'village' || 'hamlet' => MapSettlementKind.village,
      'town' => MapSettlementKind.town,
      'city' || 'city-map' => MapSettlementKind.city,
      'capital' => MapSettlementKind.capital,
      'fortress' || 'castle' || 'keep' || 'stronghold' =>
        MapSettlementKind.fortress,
      'port' || 'harbour' || 'harbor' => MapSettlementKind.port,
      'outpost' || 'garrison' => MapSettlementKind.outpost,
      'camp' || 'encampment' => MapSettlementKind.camp,
      'ruin' || 'ruins' => MapSettlementKind.ruin,
      'hidden' || 'hidden-settlement' => MapSettlementKind.hidden,
      'settlement' || 'district' || 'neighbourhood' => MapSettlementKind.other,
      _ => MapSettlementKind.other,
    };
  }
}

/// A place that people live in, as the world state sees it.
///
/// Every field beyond the name and the position is optional worldbuilding
/// metadata read from the location record. An author who never fills any of it
/// in still gets a settlement; they simply get one the map says little about.
class MapSettlement {
  const MapSettlement({
    required this.id,
    required this.name,
    required this.kind,
    required this.position,
    this.holderId = '',
    this.holderName = '',
    this.population,
    this.culture = '',
    this.government = '',
    this.economy = '',
    this.military = '',
    this.importance = '',
    this.status = '',
    this.foundedAt,
    this.endedAt,
  });

  final String id;
  final String name;
  final MapSettlementKind kind;
  final MapPosition position;

  /// The faction that holds it at the moment this state was read.
  final String holderId;
  final String holderName;

  final int? population;
  final String culture;
  final String government;
  final String economy;
  final String military;
  final String importance;
  final String status;

  final MapStoryMoment? foundedAt;
  final MapStoryMoment? endedAt;

  bool get isRuin => kind == MapSettlementKind.ruin;

  String get semanticLabel {
    final parts = <String>[
      name,
      kind.label,
      if (holderName.isNotEmpty) 'held by $holderName',
      if (population != null) '$population people',
      if (status.isNotEmpty) status,
    ];
    return parts.join(' — ');
  }
}

/// What kind of political unit a territory is.
enum MapTerritoryKind {
  kingdom,
  empire,
  duchy,
  province,
  faction,
  clan,
  cityState,
  disputed,
  neutral,
  other,
}

extension MapTerritoryKindLabel on MapTerritoryKind {
  String get label => switch (this) {
        MapTerritoryKind.kingdom => 'Kingdom',
        MapTerritoryKind.empire => 'Empire',
        MapTerritoryKind.duchy => 'Duchy',
        MapTerritoryKind.province => 'Province',
        MapTerritoryKind.faction => 'Faction territory',
        MapTerritoryKind.clan => 'Clan territory',
        MapTerritoryKind.cityState => 'City-state',
        MapTerritoryKind.disputed => 'Disputed',
        MapTerritoryKind.neutral => 'Neutral',
        MapTerritoryKind.other => 'Territory',
      };

  static MapTerritoryKind fromValue(String value) => switch (
          value.trim().toLowerCase()) {
        'kingdom' => MapTerritoryKind.kingdom,
        'empire' => MapTerritoryKind.empire,
        'duchy' => MapTerritoryKind.duchy,
        'province' || 'state' => MapTerritoryKind.province,
        'clan' => MapTerritoryKind.clan,
        'city-state' || 'city state' => MapTerritoryKind.cityState,
        'disputed' => MapTerritoryKind.disputed,
        'neutral' || 'unclaimed' => MapTerritoryKind.neutral,
        'faction' || 'faction-territory' => MapTerritoryKind.faction,
        'territory' => MapTerritoryKind.other,
        _ => MapTerritoryKind.other,
      };
}

/// Ground somebody holds.
///
/// A territory is a region or territory record; who holds it is a `controls`
/// link from a faction. Map Studio stores neither — it reads both, and reads
/// the dates on the link so a border that moved in 417 shows as it was in 412.
class MapTerritory {
  const MapTerritory({
    required this.id,
    required this.name,
    required this.kind,
    required this.geometry,
    this.holderId = '',
    this.holderName = '',
    this.settlementIds = const [],
    this.from,
    this.to,
    this.isDisputed = false,
  });

  final String id;
  final String name;
  final MapTerritoryKind kind;

  /// The shape on the map, borrowed from the region record that owns it.
  final MapGeometry geometry;

  final String holderId;
  final String holderName;
  final List<String> settlementIds;

  final MapStoryMoment? from;
  final MapStoryMoment? to;

  /// True where more than one faction claims the same ground at this moment.
  final bool isDisputed;

  bool get isHeld => holderId.isNotEmpty;

  String get semanticLabel {
    final parts = <String>[
      name,
      kind.label,
      if (holderName.isNotEmpty) 'held by $holderName' else 'unclaimed',
      if (isDisputed) 'disputed',
      if (from != null) 'from ${from!.label}',
      if (to != null) 'until ${to!.label}',
    ];
    return parts.join(' — ');
  }
}

/// What kind of line a border is.
enum MapBorderKind { natural, political, disputed, temporary, historical }

extension MapBorderKindLabel on MapBorderKind {
  String get label => switch (this) {
        MapBorderKind.natural => 'Natural',
        MapBorderKind.political => 'Political',
        MapBorderKind.disputed => 'Disputed',
        MapBorderKind.temporary => 'Temporary',
        MapBorderKind.historical => 'Historical',
      };

  static MapBorderKind fromValue(String value) =>
      switch (value.trim().toLowerCase()) {
        'natural' => MapBorderKind.natural,
        'disputed' || 'contested' => MapBorderKind.disputed,
        'temporary' || 'truce' || 'ceasefire' => MapBorderKind.temporary,
        'historical' || 'former' => MapBorderKind.historical,
        _ => MapBorderKind.political,
      };
}

/// A line between two holdings, at a moment.
class MapBorder {
  const MapBorder({
    required this.id,
    required this.name,
    required this.kind,
    required this.geometry,
    this.betweenIds = const [],
    this.from,
    this.to,
  });

  final String id;
  final String name;
  final MapBorderKind kind;
  final MapGeometry geometry;
  final List<String> betweenIds;
  final MapStoryMoment? from;
  final MapStoryMoment? to;

  String get semanticLabel => [
        name,
        '${kind.label} border',
        if (from != null) 'from ${from!.label}',
        if (to != null) 'until ${to!.label}',
      ].join(' — ');
}

/// Something the ground yields.
class MapResource {
  const MapResource({
    required this.id,
    required this.name,
    required this.locationId,
    required this.position,
    this.locationName = '',
    this.abundance = '',
    this.holderId = '',
    this.holderName = '',
    this.extraction = '',
    this.from,
    this.to,
  });

  final String id;
  final String name;

  /// The place it is found, which is where it is drawn.
  final String locationId;
  final String locationName;
  final MapPosition position;

  final String abundance;
  final String holderId;
  final String holderName;
  final String extraction;
  final MapStoryMoment? from;
  final MapStoryMoment? to;

  String get semanticLabel => [
        name,
        if (locationName.isNotEmpty) 'at $locationName',
        if (abundance.isNotEmpty) abundance,
        if (holderName.isNotEmpty) 'held by $holderName',
      ].join(' — ');
}

/// What kind of way it is between two places.
enum MapRouteKind {
  road,
  path,
  river,
  sea,
  mountainPass,
  trade,
  military,
  magical,
  hidden,
  other,
}

extension MapRouteKindLabel on MapRouteKind {
  String get label => switch (this) {
        MapRouteKind.road => 'Road',
        MapRouteKind.path => 'Path',
        MapRouteKind.river => 'River',
        MapRouteKind.sea => 'Sea route',
        MapRouteKind.mountainPass => 'Mountain pass',
        MapRouteKind.trade => 'Trade route',
        MapRouteKind.military => 'Military route',
        MapRouteKind.magical => 'Magical route',
        MapRouteKind.hidden => 'Hidden route',
        MapRouteKind.other => 'Route',
      };

  /// How much the way itself slows a traveller, before terrain or weather.
  ///
  /// A road is the baseline: 1.0. Everything else is measured against it, and
  /// the numbers are deliberately plain so an author can predict them.
  double get travelFactor => switch (this) {
        MapRouteKind.road => 1,
        MapRouteKind.trade => 1,
        MapRouteKind.military => 1,
        MapRouteKind.path => 1.3,
        MapRouteKind.hidden => 1.5,
        MapRouteKind.mountainPass => 2,
        MapRouteKind.river => 0.9,
        MapRouteKind.sea => 0.8,
        MapRouteKind.magical => 0.25,
        MapRouteKind.other => 1.2,
      };

  bool get isWaterway => this == MapRouteKind.sea || this == MapRouteKind.river;

  static MapRouteKind fromTypeId(String typeId, {String routeType = ''}) {
    final value =
        (routeType.trim().isEmpty ? typeId : routeType).trim().toLowerCase();
    return switch (value) {
      'road-route' || 'road' => MapRouteKind.road,
      'path-route' || 'path' || 'trail' => MapRouteKind.path,
      'ferry-route' || 'river' || 'river-route' => MapRouteKind.river,
      'space-route' || 'sea' || 'sea-route' || 'shipping-lane' =>
        MapRouteKind.sea,
      'tunnel-route' || 'mountain-pass' || 'pass' => MapRouteKind.mountainPass,
      'trade' || 'trade-route' => MapRouteKind.trade,
      'military' || 'military-route' => MapRouteKind.military,
      'magical-route' || 'portal-route' || 'gate-route' || 'magical' =>
        MapRouteKind.magical,
      'hidden' || 'hidden-route' || 'smuggler' => MapRouteKind.hidden,
      _ => MapRouteKind.other,
    };
  }
}

/// How a traveller is moving.
///
/// [dailyRange] is in map units per day at the reference scale, and is only
/// ever used where the route itself declares a distance. It is a stated
/// assumption of the calculator, not a fact about the author's world, and the
/// explanation says so.
enum MapTravelMode { foot, horse, cart, ship, flight }

extension MapTravelModeDetail on MapTravelMode {
  String get label => switch (this) {
        MapTravelMode.foot => 'On foot',
        MapTravelMode.horse => 'On horseback',
        MapTravelMode.cart => 'By cart',
        MapTravelMode.ship => 'By ship',
        MapTravelMode.flight => 'By air',
      };

  double get dailyRange => switch (this) {
        MapTravelMode.foot => 30,
        MapTravelMode.horse => 60,
        MapTravelMode.cart => 24,
        MapTravelMode.ship => 120,
        MapTravelMode.flight => 240,
      };

  /// Whether this mode can use a given way at all.
  ///
  /// A cart cannot take a mountain pass and a ship cannot take a road: the
  /// calculator refuses rather than quietly routing around the problem.
  bool canUse(MapRouteKind kind) => switch (this) {
        MapTravelMode.ship => kind.isWaterway || kind == MapRouteKind.magical,
        MapTravelMode.flight => true,
        MapTravelMode.cart => kind == MapRouteKind.road ||
            kind == MapRouteKind.trade ||
            kind == MapRouteKind.military ||
            kind == MapRouteKind.magical,
        MapTravelMode.foot || MapTravelMode.horse => !kind.isWaterway,
      };
}

/// The season the journey is made in.
enum MapSeason { none, spring, summer, autumn, winter }

extension MapSeasonDetail on MapSeason {
  String get label => switch (this) {
        MapSeason.none => 'Any season',
        MapSeason.spring => 'Spring',
        MapSeason.summer => 'Summer',
        MapSeason.autumn => 'Autumn',
        MapSeason.winter => 'Winter',
      };

  double get travelFactor => switch (this) {
        MapSeason.none => 1,
        MapSeason.summer => 1,
        MapSeason.spring => 1.1,
        MapSeason.autumn => 1.2,
        MapSeason.winter => 1.6,
      };
}

/// What the world is doing to itself, where the author has said so.
enum MapConditionKind {
  weather,
  season,
  climate,
  temperature,
  rainfall,
  snow,
  storm,
  drought,
  phenomenon,
}

extension MapConditionKindLabel on MapConditionKind {
  String get label => switch (this) {
        MapConditionKind.weather => 'Weather',
        MapConditionKind.season => 'Season',
        MapConditionKind.climate => 'Climate',
        MapConditionKind.temperature => 'Temperature',
        MapConditionKind.rainfall => 'Rainfall',
        MapConditionKind.snow => 'Snow',
        MapConditionKind.storm => 'Storm',
        MapConditionKind.drought => 'Drought',
        MapConditionKind.phenomenon => 'Phenomenon',
      };

  static MapConditionKind fromValue(String value) =>
      switch (value.trim().toLowerCase()) {
        'season' => MapConditionKind.season,
        'climate' => MapConditionKind.climate,
        'temperature' => MapConditionKind.temperature,
        'rainfall' || 'rain' => MapConditionKind.rainfall,
        'snow' || 'snowfall' => MapConditionKind.snow,
        'storm' || 'tempest' => MapConditionKind.storm,
        'drought' => MapConditionKind.drought,
        'phenomenon' || 'magical' || 'anomaly' => MapConditionKind.phenomenon,
        _ => MapConditionKind.weather,
      };
}

/// An environmental condition over part of the map, at a moment.
class MapCondition {
  const MapCondition({
    required this.id,
    required this.label,
    required this.kind,
    this.locationId = '',
    this.locationName = '',
    this.position,
    this.detail = '',
    this.from,
    this.to,
  });

  final String id;
  final String label;
  final MapConditionKind kind;
  final String locationId;
  final String locationName;
  final MapPosition? position;
  final String detail;
  final MapStoryMoment? from;
  final MapStoryMoment? to;

  String get semanticLabel => [
        label,
        kind.label,
        if (locationName.isNotEmpty) 'at $locationName',
        if (detail.isNotEmpty) detail,
      ].join(' — ');
}

/// A way between two places, as the world state sees it.
class MapWorldRoute {
  const MapWorldRoute({
    required this.id,
    required this.name,
    required this.kind,
    required this.fromId,
    required this.toId,
    required this.fromPosition,
    required this.toPosition,
    this.fromName = '',
    this.toName = '',
    this.distance,
    this.distanceUnit = '',
    this.statedTravelDays,
    this.difficulty = '',
    this.danger = '',
    this.holderId = '',
    this.holderName = '',
    this.conditions = '',
    this.from,
    this.to,
  });

  final String id;
  final String name;
  final MapRouteKind kind;

  final String fromId;
  final String toId;
  final String fromName;
  final String toName;
  final MapPosition fromPosition;
  final MapPosition toPosition;

  /// What the record says the distance is. `null` means the author has not
  /// said, and the calculator will not guess.
  final double? distance;
  final String distanceUnit;

  /// What the record says the journey takes, in days, if it says so at all.
  final double? statedTravelDays;

  final String difficulty;
  final String danger;
  final String holderId;
  final String holderName;
  final String conditions;

  final MapStoryMoment? from;
  final MapStoryMoment? to;

  bool get hasTravelData => statedTravelDays != null || distance != null;

  /// The other end of this route from [placeId], or `null` if it does not touch
  /// that place.
  String? otherEnd(String placeId) => placeId == fromId
      ? toId
      : placeId == toId
          ? fromId
          : null;

  String get semanticLabel => [
        name,
        kind.label,
        if (fromName.isNotEmpty && toName.isNotEmpty) '$fromName to $toName',
        if (distance != null) '$distance $distanceUnit'.trim(),
        if (difficulty.isNotEmpty) difficulty,
        if (danger.isNotEmpty) 'danger: $danger',
      ].join(' — ');
}

/// One leg of a calculated journey, with the arithmetic that produced it.
class MapTravelLeg {
  const MapTravelLeg({
    required this.route,
    required this.fromId,
    required this.toId,
    required this.days,
    required this.explanation,
  });

  final MapWorldRoute route;
  final String fromId;
  final String toId;
  final double days;

  /// Why this leg costs what it costs, in the author's terms.
  final String explanation;
}

/// The answer to "how long does it take to get from A to B?".
///
/// An estimate is either supported by the data or it does not exist. There is
/// no third state where the map guesses: [unavailable] carries the reason
/// instead, which is the whole point of §16.
class MapTravelEstimate {
  const MapTravelEstimate({
    required this.isAvailable,
    required this.mode,
    required this.season,
    this.days,
    this.legs = const [],
    this.reason = '',
  });

  factory MapTravelEstimate.unavailable({
    required MapTravelMode mode,
    required MapSeason season,
    required String reason,
  }) =>
      MapTravelEstimate(
        isAvailable: false,
        mode: mode,
        season: season,
        reason: reason,
      );

  final bool isAvailable;
  final MapTravelMode mode;
  final MapSeason season;

  /// Total days, rounded up: a journey of 3.2 days ends on the fourth day.
  final double? days;
  final List<MapTravelLeg> legs;

  /// Why there is no answer, when there is none.
  final String reason;

  int? get wholeDays => days?.ceil();

  String get summary => isAvailable
      ? '$wholeDays days ${mode.label.toLowerCase()}'
      : reason;

  /// The full working, one line per leg, for an author who wants to argue with
  /// the number.
  List<String> get explanation => [
        for (final leg in legs) leg.explanation,
        if (isAvailable)
          'Total: ${_trim(days!)} days (${mode.label.toLowerCase()}'
              '${season == MapSeason.none ? '' : ', ${season.label.toLowerCase()}'})',
      ];

  static String _trim(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
}

/// How terrain slows a traveller.
///
/// Deliberately small and deliberately fixed: the point is that the same map
/// always gives the same answer, and that an author can hold the whole rule in
/// their head.
class MapTerrainTravel {
  const MapTerrainTravel._();

  static const _factors = <String, double>{
    'mountain': 2.2,
    'hill': 1.4,
    'forest': 1.3,
    'swamp': 1.8,
    'desert': 1.6,
    'snow': 1.7,
    'tundra': 1.5,
    'grass': 1,
    'plain': 1,
    'farmland': 1,
    'water': 1,
    'ocean': 1,
  };

  /// The factor for a named terrain kind, or 1 where the map says nothing.
  static double factorFor(String terrainKind) =>
      _factors[terrainKind.trim().toLowerCase()] ?? 1;
}

/// Everything the map knows about the world at one moment.
///
/// Reproducible by construction: the same records, links and [moment] always
/// produce the same state, in the same order.
class MapWorldState {
  const MapWorldState({
    required this.mapId,
    required this.projectId,
    required this.kind,
    this.moment,
    this.settlements = const [],
    this.territories = const [],
    this.borders = const [],
    this.routes = const [],
    this.resources = const [],
    this.conditions = const [],
    this.moments = const [],
    this.factions = const {},
  });

  final String mapId;
  final String projectId;
  final MapWorldStateKind kind;

  /// The moment this state was read at, or `null` for the whole story.
  final MapStoryMoment? moment;

  final List<MapSettlement> settlements;
  final List<MapTerritory> territories;
  final List<MapBorder> borders;
  final List<MapWorldRoute> routes;
  final List<MapResource> resources;
  final List<MapCondition> conditions;

  /// Every dated moment this map knows about, ascending — the era scrubber.
  final List<MapStoryMoment> moments;

  /// Faction id to display name, for the legend and the queries.
  final Map<String, String> factions;

  bool get isEmpty =>
      settlements.isEmpty &&
      territories.isEmpty &&
      borders.isEmpty &&
      routes.isEmpty &&
      resources.isEmpty &&
      conditions.isEmpty;

  MapSettlement? settlementById(String id) =>
      settlements.where((item) => item.id == id).firstOrNull;

  MapWorldRoute? routeById(String id) =>
      routes.where((item) => item.id == id).firstOrNull;

  List<MapTerritory> territoriesOf(String factionId) =>
      [for (final item in territories) if (item.holderId == factionId) item];

  List<MapSettlement> settlementsOf(String factionId) =>
      [for (final item in settlements) if (item.holderId == factionId) item];

  List<MapWorldRoute> routesTouching(String placeId) =>
      [for (final route in routes) if (route.otherEnd(placeId) != null) route];

  List<MapResource> resourcesAt(String locationId) =>
      [for (final item in resources) if (item.locationId == locationId) item];

  /// Deterministic shortest journey between two places.
  ///
  /// Dijkstra over the routes that exist at this moment and that the mode can
  /// actually use, with ties broken by route id so the same world always yields
  /// the same road. A leg with no distance and no stated time is not traversed:
  /// it is missing data, and missing data is reported rather than filled in.
  MapTravelEstimate travelBetween(
    String fromId,
    String toId, {
    MapTravelMode mode = MapTravelMode.foot,
    MapSeason season = MapSeason.none,
    String Function(MapPosition position)? terrainAt,
  }) {
    if (fromId == toId) {
      return MapTravelEstimate.unavailable(
        mode: mode,
        season: season,
        reason: 'Start and destination are the same place.',
      );
    }
    final usable = [
      for (final route in routes)
        if (mode.canUse(route.kind)) route,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (usable.isEmpty) {
      return MapTravelEstimate.unavailable(
        mode: mode,
        season: season,
        reason: 'No route ${mode.label.toLowerCase()} exists between these '
            'places at this point in the story.',
      );
    }

    final best = <String, double>{fromId: 0};
    final cameFrom = <String, MapTravelLeg>{};
    final settled = <String>{};

    while (true) {
      String? current;
      var currentCost = double.infinity;
      // Deterministic frontier: cheapest, then lowest id.
      for (final entry in best.entries) {
        if (settled.contains(entry.key)) continue;
        if (entry.value < currentCost ||
            (entry.value == currentCost &&
                current != null &&
                entry.key.compareTo(current) < 0)) {
          current = entry.key;
          currentCost = entry.value;
        }
      }
      if (current == null) break;
      if (current == toId) break;
      settled.add(current);

      for (final route in usable) {
        final other = route.otherEnd(current);
        if (other == null || settled.contains(other)) continue;
        final leg = _legFor(route, current, other, mode, season, terrainAt);
        if (leg == null) continue;
        final cost = currentCost + leg.days;
        final known = best[other];
        if (known == null || cost < known) {
          best[other] = cost;
          cameFrom[other] = leg;
        }
      }
    }

    final total = best[toId];
    if (total == null) {
      final touchingStart = routesTouching(fromId);
      final touchingEnd = routesTouching(toId);
      final reason = touchingStart.isEmpty || touchingEnd.isEmpty
          ? 'No route connects these places at this point in the story.'
          : 'No travel data has been defined for the routes between these '
              'places.';
      return MapTravelEstimate.unavailable(
        mode: mode,
        season: season,
        reason: reason,
      );
    }

    final legs = <MapTravelLeg>[];
    var cursor = toId;
    while (cursor != fromId) {
      final leg = cameFrom[cursor];
      if (leg == null) break;
      legs.insert(0, leg);
      cursor = leg.fromId;
    }

    return MapTravelEstimate(
      isAvailable: true,
      mode: mode,
      season: season,
      days: total,
      legs: legs,
    );
  }

  /// The cost of one leg, or `null` where the data does not support one.
  MapTravelLeg? _legFor(
    MapWorldRoute route,
    String fromId,
    String toId,
    MapTravelMode mode,
    MapSeason season,
    String Function(MapPosition position)? terrainAt,
  ) {
    final seasonFactor = season.travelFactor;
    final stated = route.statedTravelDays;
    if (stated != null) {
      // The author's own number wins. Season still applies, because the author
      // wrote a journey, not a winter journey.
      final days = stated * seasonFactor;
      return MapTravelLeg(
        route: route,
        fromId: fromId,
        toId: toId,
        days: days,
        explanation: '${route.name}: ${MapTravelEstimate._trim(stated)} days '
            'as recorded'
            '${season == MapSeason.none ? '' : ' × $seasonFactor× ${season.label.toLowerCase()}'}'
            ' = ${MapTravelEstimate._trim(days)} days',
      );
    }
    final distance = route.distance;
    if (distance == null) return null;

    final terrainKind = terrainAt == null
        ? ''
        : terrainAt(
            MapPosition(
              (route.fromPosition.x + route.toPosition.x) / 2,
              (route.fromPosition.y + route.toPosition.y) / 2,
            ),
          );
    final terrainFactor = MapTerrainTravel.factorFor(terrainKind);
    final days = distance /
        mode.dailyRange *
        route.kind.travelFactor *
        terrainFactor *
        seasonFactor;
    final unit = route.distanceUnit.isEmpty ? 'units' : route.distanceUnit;
    return MapTravelLeg(
      route: route,
      fromId: fromId,
      toId: toId,
      days: days,
      explanation: '${route.name}: ${MapTravelEstimate._trim(distance)} $unit ÷ '
          '${MapTravelEstimate._trim(mode.dailyRange)} per day'
          ' × ${route.kind.travelFactor}× ${route.kind.label.toLowerCase()}'
          '${terrainFactor == 1 ? '' : ' × $terrainFactor× $terrainKind'}'
          '${seasonFactor == 1 ? '' : ' × $seasonFactor× ${season.label.toLowerCase()}'}'
          ' = ${MapTravelEstimate._trim(days)} days',
    );
  }
}

/// A question an author can ask the map.
enum MapWorldQueryKind {
  controlledBy,
  routesBetween,
  visitedBy,
  scenesIn,
  affectedBy,
  worldAt,
}

extension MapWorldQueryKindLabel on MapWorldQueryKind {
  String get label => switch (this) {
        MapWorldQueryKind.controlledBy => 'Controlled by',
        MapWorldQueryKind.routesBetween => 'Routes between',
        MapWorldQueryKind.visitedBy => 'Visited by',
        MapWorldQueryKind.scenesIn => 'Scenes in',
        MapWorldQueryKind.affectedBy => 'Affected by',
        MapWorldQueryKind.worldAt => 'The world at',
      };
}

/// What a query found, and what the map should light up.
///
/// A query that finds nothing says so; it never returns a partial guess and
/// never explains an empty result as "probably none".
class MapWorldQueryResult {
  const MapWorldQueryResult({
    required this.kind,
    required this.subject,
    this.highlightedIds = const [],
    this.lines = const [],
    this.note = '',
  });

  final MapWorldQueryKind kind;
  final String subject;

  /// Record ids the map should highlight.
  final List<String> highlightedIds;

  /// One readable line per hit.
  final List<String> lines;

  /// Set where the answer is limited by what the data contains.
  final String note;

  bool get isEmpty => highlightedIds.isEmpty && lines.isEmpty;

  String get headline => '${kind.label} $subject';
}

/// Parses a number out of a field an author typed by hand.
///
/// `"120"`, `"120 miles"`, `"about 120km"` all give 120; anything with no
/// number in it gives `null`, which the caller must treat as "not defined"
/// rather than zero.
({double? value, String unit}) parseMeasurement(Object? raw) {
  if (raw is num) return (value: raw.toDouble(), unit: '');
  if (raw is! String) return (value: null, unit: '');
  final text = raw.trim();
  if (text.isEmpty) return (value: null, unit: '');
  final match = RegExp(r'(-?\d+(?:[.,]\d+)?)').firstMatch(text);
  if (match == null) return (value: null, unit: '');
  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (value == null) return (value: null, unit: '');
  final unit = text.replaceFirst(match.group(0)!, '').trim();
  return (value: value, unit: unit);
}

/// Reads a stated travel time as days.
///
/// Understands hours, days, weeks and months, because that is what authors
/// write. An unrecognised unit is not converted: it returns `null` rather than
/// pretending a "2 fortnights" is 2 days.
double? parseTravelDays(Object? raw) {
  final parsed = parseMeasurement(raw);
  final value = parsed.value;
  if (value == null) return null;
  final unit = parsed.unit.toLowerCase();
  if (unit.isEmpty || unit.startsWith('day')) return value;
  if (unit.startsWith('hour') || unit == 'h' || unit == 'hrs') {
    return value / 24;
  }
  if (unit.startsWith('week')) return value * 7;
  if (unit.startsWith('month')) return value * 30;
  return null;
}
