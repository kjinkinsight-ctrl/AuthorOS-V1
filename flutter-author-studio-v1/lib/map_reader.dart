/// Map Studio Phase 6 — reader-facing maps and spoiler filtering.
///
/// An author's map shows everything the author knows. A reader's map must not.
/// This file is the projection that turns the first into the second, and it is
/// built on one rule:
///
/// > **Filtering happens in the model, never in the widget.**
///
/// A [MapReaderView] holds only what the chosen spoiler level permits. A
/// renderer handed one cannot leak a hidden city, because the hidden city is
/// not in the data it was given — there is nothing to forget to check.
///
/// ## Where a reveal comes from
///
/// From `revealedIn`, the canonical relationship AuthorOS already defines: an
/// entity is revealed in a chapter or scene, and the manuscript's own ordering
/// (`order` on a chapter node, `chapterId` + `order` on a scene) says when that
/// is. Map Studio adds no vocabulary and writes no link.
///
/// ## The consequence worth stating plainly
///
/// **Nothing in AuthorOS writes `revealedIn` today.** The relationship exists
/// and is read here; no Studio offers a way to create one. So on a project that
/// has never authored a reveal, every spoiler level below "everything" hides
/// everything — which is the correct behaviour for a spoiler filter and a poor
/// experience for an author who has not been told why their reader map is
/// empty. [MapReaderView.unrevealed] carries that count so the Studio can say
/// so, and the gap is reported rather than papered over by defaulting to
/// "visible", which would leak secrets by construction.
library;

import 'map_domain.dart';
import 'map_overlays.dart';
import 'map_world.dart';

/// Where in the manuscript something becomes known.
///
/// Ordered by the manuscript's own ordering, so "before chapter 7" means what
/// the author's chapter order says it means.
class MapRevealPoint implements Comparable<MapRevealPoint> {
  const MapRevealPoint({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    this.chapterOrder = 0,
    this.sceneOrder = 0,
  });

  final String nodeId;

  /// `chapter`, `scene` or `book`.
  final String nodeType;
  final String label;

  final int chapterOrder;
  final int sceneOrder;

  /// One comparable position: chapter first, then scene within it.
  int get sortKey => chapterOrder * 10000 + sceneOrder;

  @override
  int compareTo(MapRevealPoint other) {
    final byPosition = sortKey.compareTo(other.sortKey);
    return byPosition != 0 ? byPosition : nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      other is MapRevealPoint &&
      other.nodeId == nodeId &&
      other.sortKey == sortKey;

  @override
  int get hashCode => Object.hash(nodeId, sortKey);
}

/// How much of the story the reader of this map has read.
///
/// [public] shows only what is revealed before the story starts — in practice,
/// nothing, until an author marks something as public knowledge.
/// [everything] is the author's own view and is never what a reader receives.
class MapSpoilerLevel {
  const MapSpoilerLevel({
    required this.label,
    this.through,
    this.isEverything = false,
  });

  /// Nothing revealed yet.
  static const public = MapSpoilerLevel(label: 'Public');

  /// The author's view: no filtering at all.
  static const everything = MapSpoilerLevel(
    label: 'Full story',
    isEverything: true,
  );

  /// A reader who has read up to and including [through].
  factory MapSpoilerLevel.through(MapRevealPoint point) =>
      MapSpoilerLevel(label: 'Through ${point.label}', through: point);

  final String label;
  final MapRevealPoint? through;
  final bool isEverything;

  bool get isPublic => !isEverything && through == null;

  /// Whether something revealed at [point] may be shown.
  ///
  /// An entity with no reveal point at all is shown only at [everything]. That
  /// is deliberate: "the author never said when this becomes known" is not
  /// evidence that it is safe to show.
  bool allows(MapRevealPoint? point) {
    if (isEverything) return true;
    if (point == null) return false;
    final limit = through;
    if (limit == null) return false;
    return point.sortKey <= limit.sortKey;
  }
}

/// What a reader is allowed to see, and what was withheld.
///
/// The three canonical projections come in; smaller versions of the same
/// projections go out. No new representation of the world is created — a reader
/// map is the author's map with things removed.
class MapReaderView {
  const MapReaderView({
    required this.level,
    required this.canvas,
    required this.overlays,
    required this.world,
    this.hidden = const {},
    this.unrevealed = 0,
    this.revealedTotal = 0,
  });

  final MapSpoilerLevel level;

  /// The map itself, with unrevealed places, regions and markers removed.
  final MapCanvasData canvas;

  /// Story overlays, with unrevealed characters, events and scenes removed.
  final MapOverlayData overlays;

  /// The world state, with unrevealed settlements, territories, borders,
  /// routes, resources and conditions removed.
  final MapWorldState world;

  /// How many of each kind were withheld, for an honest notice.
  final Map<String, int> hidden;

  /// How many entities have no `revealedIn` link at all.
  ///
  /// Distinct from [hidden]: these are not "not yet revealed", they are "never
  /// said to be revealed", and that usually means the author has not authored
  /// reveal points rather than that everything is secret.
  final int unrevealed;

  /// How many entities carry a reveal point.
  final int revealedTotal;

  int get hiddenTotal =>
      hidden.values.fold(0, (total, count) => total + count);

  bool get isEmpty =>
      canvas.locations.isEmpty &&
      canvas.regions.isEmpty &&
      canvas.markers.isEmpty &&
      overlays.items.isEmpty;

  /// What the Studio should tell the author about this reader map.
  ///
  /// Says the useful thing rather than the tautological one: an empty reader
  /// map on a project with no reveal points is a missing-data problem, and
  /// saying "0 places visible" would send the author looking in the wrong
  /// place.
  String get notice {
    if (level.isEverything) return '';
    if (revealedTotal == 0 && unrevealed > 0) {
      return 'Nothing on this map has been marked as revealed anywhere in the '
          'manuscript, so a reader map shows nothing. Reveal points come from '
          "`revealedIn` links, which no Studio writes yet.";
    }
    if (hiddenTotal == 0) {
      return 'Everything on this map is visible at ${level.label}.';
    }
    return '$hiddenTotal hidden at ${level.label}.';
  }
}

/// Builds a reader view from the canonical projections.
///
/// Pure: given the same inputs it always removes the same things. It reads no
/// database of its own — the reveal points are handed to it, gathered by the
/// service that owns the link layer.
class MapReaderProjection {
  const MapReaderProjection._();

  /// [overlays] and [world] are optional because a map may have neither: an
  /// absent projection is absent, and the caller must not have to invent an
  /// empty one to ask this question — constructing a world in a widget is
  /// exactly what the architecture forbids.
  static MapReaderView apply({
    required MapSpoilerLevel level,
    required MapCanvasData canvas,
    required Map<String, MapRevealPoint> revealed,
    MapOverlayData? overlays,
    MapWorldState? world,
  }) {
    final overlayData = overlays ??
        MapOverlayData(
          mapId: canvas.map.id,
          projectId: canvas.map.record.projectId ?? '',
        );
    final worldState = world ??
        MapWorldState(
          mapId: canvas.map.id,
          projectId: canvas.map.record.projectId ?? '',
          kind: MapWorldStateKind.current,
        );
    if (level.isEverything) {
      return MapReaderView(
        level: level,
        canvas: canvas,
        overlays: overlayData,
        world: worldState,
        revealedTotal: revealed.length,
      );
    }

    bool visible(String id) => level.allows(revealed[id]);

    final hidden = <String, int>{};
    void withhold(String kind, int count) {
      if (count > 0) hidden[kind] = (hidden[kind] ?? 0) + count;
    }

    final locations = [
      for (final item in canvas.locations)
        if (visible(item.record.id)) item,
    ];
    withhold('places', canvas.locations.length - locations.length);

    final regions = [
      for (final item in canvas.regions)
        if (visible(item.record.id)) item,
    ];
    withhold('regions', canvas.regions.length - regions.length);

    final markers = [
      for (final item in canvas.markers)
        if (visible(item.record.id)) item,
    ];
    withhold('markers', canvas.markers.length - markers.length);

    // A place that is not on the reader's map cannot anchor anything on it:
    // an overlay whose location was withheld is withheld too, whatever its own
    // reveal point says. Otherwise a hidden city leaks through the character
    // standing in it.
    final visiblePlaces = {
      for (final item in locations) item.record.id,
      for (final item in regions) item.record.id,
    };

    final items = [
      for (final item in overlayData.items)
        if (visible(item.sourceId) &&
            (item.locationId.isEmpty || visiblePlaces.contains(item.locationId)))
          item,
    ];
    withhold('story overlays', overlayData.items.length - items.length);

    final journeys = [
      for (final journey in overlayData.journeys)
        if (visible(journey.characterId))
          MapJourney(
            characterId: journey.characterId,
            characterName: journey.characterName,
            stops: [
              for (final stop in journey.stops)
                if (visiblePlaces.contains(stop.locationId)) stop,
            ],
          ),
    ];

    final settlements = [
      for (final item in worldState.settlements)
        if (visible(item.id)) item,
    ];
    withhold('settlements', worldState.settlements.length - settlements.length);

    final territories = [
      for (final item in worldState.territories)
        if (visible(item.id)) item,
    ];
    withhold('territories', worldState.territories.length - territories.length);

    final borders = [
      for (final item in worldState.borders)
        if (visible(item.id)) item,
    ];
    withhold('borders', worldState.borders.length - borders.length);

    // A route is only shown when both of its ends are: half a road pointing off
    // the edge of a reader's map is itself a spoiler.
    final visibleSettlements = {for (final item in settlements) item.id};
    final routes = [
      for (final route in worldState.routes)
        if (visible(route.id) &&
            visibleSettlements.contains(route.fromId) &&
            visibleSettlements.contains(route.toId))
          route,
    ];
    withhold('routes', worldState.routes.length - routes.length);

    final resources = [
      for (final item in worldState.resources)
        if (visible(item.id) && visiblePlaces.contains(item.locationId)) item,
    ];
    withhold('resources', worldState.resources.length - resources.length);

    final conditions = [
      for (final item in worldState.conditions)
        if (item.locationId.isEmpty || visiblePlaces.contains(item.locationId))
          item,
    ];
    withhold('conditions', worldState.conditions.length - conditions.length);

    return MapReaderView(
      level: level,
      canvas: MapCanvasData(
        map: canvas.map,
        locations: locations,
        regions: regions,
        markers: markers,
      ),
      overlays: MapOverlayData(
        mapId: overlayData.mapId,
        projectId: overlayData.projectId,
        items: items,
        journeys: journeys,
        unmapped: overlayData.unmapped,
        moments: overlayData.moments,
      ),
      world: MapWorldState(
        mapId: worldState.mapId,
        projectId: worldState.projectId,
        kind: worldState.kind,
        moment: worldState.moment,
        settlements: settlements,
        territories: territories,
        borders: borders,
        routes: routes,
        resources: resources,
        conditions: conditions,
        moments: worldState.moments,
        factions: worldState.factions,
      ),
      hidden: hidden,
      unrevealed: _unrevealedCount(canvas, overlayData, worldState, revealed),
      revealedTotal: revealed.length,
    );
  }

  static int _unrevealedCount(
    MapCanvasData canvas,
    MapOverlayData overlays,
    MapWorldState world,
    Map<String, MapRevealPoint> revealed,
  ) {
    final ids = <String>{
      for (final item in canvas.locations) item.record.id,
      for (final item in canvas.regions) item.record.id,
      for (final item in canvas.markers) item.record.id,
      for (final item in overlays.items) item.sourceId,
    };
    return ids.where((id) => !revealed.containsKey(id)).length;
  }
}
