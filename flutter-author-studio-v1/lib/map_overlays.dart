/// Map Studio Phase 4 — story, character and timeline overlays.
///
/// Plain Dart, like every other Map Studio domain file: this vocabulary must be
/// resolvable without a Flutter binding, and nothing here knows what a pixel is.
///
/// The whole file is a **projection**. Every value below is derived from data
/// that already exists somewhere else in AuthorOS and is authoritative there:
/// a character record, a timeline event, a manuscript node, a map location, a
/// `RecordLink`. Nothing here is persisted, and nothing here is a source of
/// truth. If an overlay shows a character standing in a city, that is because a
/// `locatedAt` link already said so — the map never writes one.
library;

import 'map_domain.dart';

/// What an overlay represents.
enum MapOverlayKind {
  /// A map location carrying story context.
  location,

  /// A character, placed at the location they are linked to.
  character,

  /// A timeline event, placed where it occurs.
  event,

  /// A manuscript scene or chapter, placed where it is set.
  scene,
}

extension MapOverlayKindLabel on MapOverlayKind {
  String get label => switch (this) {
        MapOverlayKind.location => 'Locations',
        MapOverlayKind.character => 'Characters',
        MapOverlayKind.event => 'Events',
        MapOverlayKind.scene => 'Scenes',
      };

  /// A shape name the view resolves to an icon.
  ///
  /// Every category is distinguished by shape as well as colour, so the map
  /// stays readable without colour vision — §28 of the directive and ordinary
  /// good sense.
  String get shapeId => switch (this) {
        MapOverlayKind.location => 'square',
        MapOverlayKind.character => 'circle',
        MapOverlayKind.event => 'diamond',
        MapOverlayKind.scene => 'book',
      };
}

/// A point on the story's clock, comparable across events.
///
/// Timeline Studio stores a rich `TimelineDate` (calendar, era, year, month,
/// day, time, precision). Overlays need only enough to order events and to say
/// whether one happens before the moment the author is looking at, so this
/// flattens that into a sortable key and keeps the original label for display.
/// An undated event has no moment at all, and is never given one.
class MapStoryMoment implements Comparable<MapStoryMoment> {
  const MapStoryMoment({
    required this.sortKey,
    required this.label,
    this.approximate = false,
  });

  /// Ordering only. Derived from year/month/day; never displayed as a number.
  final int sortKey;
  final String label;
  final bool approximate;

  /// Reads a moment from a timeline event's stored `start` field.
  ///
  /// Returns `null` when the event has no usable date. That is a real and
  /// common state, and the overlay layer must show it as "no date" rather than
  /// inventing one.
  static MapStoryMoment? fromEventFields(Map<String, Object?> fields) {
    final start = fields['start'];
    if (start is! List || start.isEmpty) return null;
    final first = start.first;
    if (first is! Map) return null;
    final date = Map<String, Object?>.from(first);
    final year = _asInt(date['year']);
    if (year == null) return null;
    final month = _asInt(date['month']) ?? 0;
    final day = _asInt(date['day']) ?? 0;
    final approximate = date['approximate'] == true;
    final era = _asString(date['era']);
    final parts = <String>[
      if (era.isNotEmpty) era,
      'Year $year',
      if (month > 0) 'Month $month',
      if (day > 0) 'Day $day',
    ];
    return MapStoryMoment(
      // Month and day are bounded, so this orders correctly without needing a
      // real calendar. Timeline Studio owns calendars; overlays only sort.
      sortKey: year * 100000 + month * 1000 + day,
      label: parts.join(' · '),
      approximate: approximate,
    );
  }

  @override
  int compareTo(MapStoryMoment other) => sortKey.compareTo(other.sortKey);

  @override
  bool operator ==(Object other) =>
      other is MapStoryMoment &&
      other.sortKey == sortKey &&
      other.label == label &&
      other.approximate == approximate;

  @override
  int get hashCode => Object.hash(sortKey, label, approximate);

  @override
  String toString() => label;
}

/// One thing shown on the map because the story already knows about it.
///
/// [sourceId] and [sourceType] are the whole point: an overlay is a pointer at
/// an authoritative record, never a copy of it. Selecting one opens the Studio
/// that owns it.
class MapOverlayItem {
  const MapOverlayItem({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.position,
    required this.label,
    required this.sourceId,
    required this.sourceType,
    this.subtitle = '',
    this.locationId = '',
    this.locationName = '',
    this.moment,
    this.metadata = const {},
  });

  final String id;
  final String projectId;
  final MapOverlayKind kind;

  /// Map space, borrowed from the location this overlay sits at.
  final MapPosition position;

  final String label;
  final String subtitle;

  /// The authoritative record or manuscript node this overlay stands for.
  final String sourceId;

  /// `character`, `timeline-event`, `location`, `scene`, `chapter`.
  final String sourceType;

  /// The map location that gave this overlay its position.
  final String locationId;
  final String locationName;

  /// When it happens, for overlays that happen at all.
  final MapStoryMoment? moment;

  final Map<String, Object?> metadata;

  bool get isDated => moment != null;

  /// A description that carries the whole overlay without relying on colour,
  /// shape or position — what a screen reader announces.
  String get semanticLabel {
    final parts = <String>[
      label,
      switch (kind) {
        MapOverlayKind.location => 'Location',
        MapOverlayKind.character => 'Character',
        MapOverlayKind.event => 'Event',
        MapOverlayKind.scene => 'Scene',
      },
      if (subtitle.isNotEmpty) subtitle,
      if (locationName.isNotEmpty && kind != MapOverlayKind.location)
        locationName,
      if (moment != null) moment!.label,
    ];
    return parts.join(' — ');
  }
}

/// Several overlays sharing one map position.
///
/// Characters gather in cities, so the common case is many overlays at exactly
/// the same coordinates. Drawing them on top of each other would hide all but
/// the last; a cluster keeps every one of them reachable.
class MapOverlayCluster {
  const MapOverlayCluster({required this.position, required this.items});

  final MapPosition position;
  final List<MapOverlayItem> items;

  int get count => items.length;
  bool get isSingle => items.length == 1;
  MapOverlayItem get primary => items.first;

  /// A stable id, so a cluster keeps its identity across rebuilds.
  String get id => 'cluster-${position.x}-${position.y}';

  String get semanticLabel => isSingle
      ? primary.semanticLabel
      : '${items.length} items at ${primary.locationName.isEmpty ? 'this location' : primary.locationName}: '
          '${items.map((item) => item.label).join(', ')}';

  /// Groups overlays that share a position, preserving input order within each
  /// group so the result is deterministic.
  static List<MapOverlayCluster> clusterAll(List<MapOverlayItem> items) {
    final groups = <String, List<MapOverlayItem>>{};
    for (final item in items) {
      groups
          .putIfAbsent('${item.position.x}|${item.position.y}', () => [])
          .add(item);
    }
    final clusters = [
      for (final entry in groups.entries)
        MapOverlayCluster(
          position: entry.value.first.position,
          items: entry.value,
        ),
    ];
    clusters.sort((a, b) {
      final byX = a.position.x.compareTo(b.position.x);
      return byX != 0 ? byX : a.position.y.compareTo(b.position.y);
    });
    return clusters;
  }
}

/// One stop on a character's journey.
class MapJourneyStop {
  const MapJourneyStop({
    required this.position,
    required this.locationId,
    required this.locationName,
    required this.eventId,
    required this.eventName,
    required this.moment,
  });

  final MapPosition position;
  final String locationId;
  final String locationName;
  final String eventId;
  final String eventName;
  final MapStoryMoment moment;
}

/// Where a character goes, in the order the story says they go there.
///
/// Derived, never stored. A journey exists only where the canonical data
/// already contains dated events at mapped locations; the map draws the line
/// between two stops it was given and never invents a third.
class MapJourney {
  const MapJourney({
    required this.characterId,
    required this.characterName,
    required this.stops,
  });

  final String characterId;
  final String characterName;
  final List<MapJourneyStop> stops;

  bool get isEmpty => stops.isEmpty;

  /// A journey needs two mapped, dated points before it is a journey at all.
  bool get isDrawable => stops.length >= 2;

  MapStoryMoment? get start => stops.isEmpty ? null : stops.first.moment;
  MapStoryMoment? get end => stops.isEmpty ? null : stops.last.moment;

  /// The legs actually drawn: consecutive pairs of stops.
  List<(MapJourneyStop from, MapJourneyStop to)> get legs => [
        for (var i = 0; i + 1 < stops.length; i++) (stops[i], stops[i + 1]),
      ];

  String get semanticLabel => stops.isEmpty
      ? '$characterName has no mapped journey'
      : '$characterName: ${stops.map((stop) => '${stop.locationName} ${stop.moment.label}').join(', then ')}';
}

/// How much of the story the map is showing.
///
/// Purely a view concern: changing it re-filters what is drawn and writes
/// nothing. [moment] is `null` for "the whole story".
class MapOverlayFilter {
  const MapOverlayFilter({
    this.visible = const {
      MapOverlayKind.location,
      MapOverlayKind.character,
      MapOverlayKind.event,
      MapOverlayKind.scene,
    },
    this.moment,
    this.showPast = true,
    this.showFuture = false,
    this.journeyCharacterIds = const {},
  });

  final Set<MapOverlayKind> visible;

  /// The story moment the author is standing in, or `null` for all of it.
  final int? moment;

  /// Whether events before [moment] stay on the map as history.
  final bool showPast;

  /// Whether events after [moment] are revealed.
  final bool showFuture;

  /// Characters whose journeys are drawn.
  final Set<String> journeyCharacterIds;

  bool get isWholeStory => moment == null;

  bool shows(MapOverlayKind kind) => visible.contains(kind);

  /// Whether an overlay survives the current temporal filter.
  ///
  /// An undated overlay is always shown: it has no position on the clock, so
  /// hiding it would be a claim about when it happens that the data does not
  /// support.
  bool allows(MapOverlayItem item) {
    if (!shows(item.kind)) return false;
    final at = moment;
    final own = item.moment;
    if (at == null || own == null) return true;
    if (own.sortKey > at) return showFuture;
    if (own.sortKey < at) return showPast;
    return true;
  }

  MapOverlayFilter copyWith({
    Set<MapOverlayKind>? visible,
    int? moment,
    bool clearMoment = false,
    bool? showPast,
    bool? showFuture,
    Set<String>? journeyCharacterIds,
  }) =>
      MapOverlayFilter(
        visible: visible ?? this.visible,
        moment: clearMoment ? null : (moment ?? this.moment),
        showPast: showPast ?? this.showPast,
        showFuture: showFuture ?? this.showFuture,
        journeyCharacterIds: journeyCharacterIds ?? this.journeyCharacterIds,
      );

  MapOverlayFilter toggling(MapOverlayKind kind) {
    final next = {...visible};
    if (!next.remove(kind)) next.add(kind);
    return copyWith(visible: next);
  }

  MapOverlayFilter togglingJourney(String characterId) {
    final next = {...journeyCharacterIds};
    if (!next.remove(characterId)) next.add(characterId);
    return copyWith(journeyCharacterIds: next);
  }
}

/// Everything the overlay layer needs for one map, in one read.
class MapOverlayData {
  const MapOverlayData({
    required this.mapId,
    required this.projectId,
    this.items = const [],
    this.journeys = const [],
    this.unmapped = const {},
    this.moments = const [],
  });

  final String mapId;
  final String projectId;
  final List<MapOverlayItem> items;
  final List<MapJourney> journeys;

  /// Counts of story entities that exist but have no map position, by kind.
  ///
  /// Reported rather than hidden: "12 characters have no mapped location" is
  /// useful, and silently dropping them would look like they do not exist.
  final Map<MapOverlayKind, int> unmapped;

  /// Every distinct dated moment on this map, ascending — the timeline the
  /// overlay control scrubs through.
  final List<MapStoryMoment> moments;

  bool get isEmpty => items.isEmpty;

  List<MapOverlayItem> ofKind(MapOverlayKind kind) =>
      [for (final item in items) if (item.kind == kind) item];

  int unmappedOf(MapOverlayKind kind) => unmapped[kind] ?? 0;

  List<MapOverlayItem> visibleUnder(MapOverlayFilter filter) =>
      [for (final item in items) if (filter.allows(item)) item];

  List<MapJourney> journeysUnder(MapOverlayFilter filter) => [
        for (final journey in journeys)
          if (filter.journeyCharacterIds.contains(journey.characterId) &&
              journey.isDrawable)
            journey,
      ];

  MapStoryMoment? get firstMoment => moments.isEmpty ? null : moments.first;
  MapStoryMoment? get lastMoment => moments.isEmpty ? null : moments.last;

  /// Matches overlays against a search term, for the focus flow.
  List<MapOverlayItem> search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    return [
      for (final item in items)
        if (item.label.toLowerCase().contains(term) ||
            item.subtitle.toLowerCase().contains(term) ||
            item.locationName.toLowerCase().contains(term))
          item,
    ];
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _asString(Object? value) => value is String ? value.trim() : '';
