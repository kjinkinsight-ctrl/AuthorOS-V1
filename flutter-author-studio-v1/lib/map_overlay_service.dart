/// Map Studio Phase 4 — the overlay projection.
///
/// This service is **read-only by construction**. It has no create, update or
/// delete method, it never opens a write path, and every value it returns is
/// derived from records and links that already exist. The map visualises the
/// story AuthorOS already knows; it never becomes the place that knows it.
///
/// It also owns no data of its own. There is no overlay table, no overlay
/// record type and no overlay persistence: an overlay is computed on read from
/// the canonical services, and discarded when the view rebuilds.
///
/// Relationships come from the existing link vocabulary and nowhere else:
///
/// - `locatedAt`  — anything → location, and scene → location
/// - `livesIn`    — character → location, the edge Character Studio writes
/// - `occursAt`   — event → location
/// - `involves`   — event → character, which is what a journey is made of
/// - `appearsIn`  — character → scene
///
/// A character appears on the map because something already said they are
/// located somewhere. If no link says so, they are reported as unmapped. The
/// overlay layer never creates the link it wishes existed.
library;

import 'core/connected_domain.dart';
import 'core/timeline_record_types.dart';
import 'core/world_record_types.dart';
import 'map_domain.dart';
import 'map_overlays.dart';
import 'persistence/authoros_database.dart';

export 'map_overlays.dart';

/// The link types the overlay layer reads. Reading only — nothing here writes.
class MapOverlayLinks {
  const MapOverlayLinks._();

  /// A character or a scene is located at a place.
  static const locatedAt = 'locatedAt';

  /// A character lives in a place.
  static const livesIn = 'livesIn';

  /// An event occurs at a place.
  static const occursAt = 'occursAt';

  /// An event involves a character. This is the edge Timeline Studio already
  /// writes, and the one a journey is read from.
  static const involves = 'involves';

  /// A character appears in a scene.
  static const appearsIn = 'appearsIn';

  /// Every link the projection consults.
  static const all = {locatedAt, livesIn, occursAt, involves, appearsIn};

  /// The edges that can put a character on the map.
  static const characterToPlace = {locatedAt, livesIn};

  /// The edges that can put an event on the map.
  static const eventToPlace = {occursAt, locatedAt};

  /// The edges that can tie a character to an event.
  ///
  /// Both are read because the canonical vocabulary carries both: `involves`
  /// runs from the event, `appearsIn` from the character. Neither is written
  /// here.
  static const characterToEvent = {involves, appearsIn};
}

/// Record types the overlay layer recognises as story entities.
///
/// The type vocabulary is the canonical one, read from the registries that
/// already define it. Map Studio adds no type of its own and recognises nothing
/// the rest of AuthorOS does not already have.
class MapOverlayTypes {
  const MapOverlayTypes._();

  static const character = 'character';

  /// Every timeline record type, not just the plain event: a founding, a battle
  /// and a death are all things that happen somewhere, and Timeline Studio
  /// stores each under its own type.
  static final events = <String>{
    ...TimelineRecordTypes.recordTypeIds,
    'historical-event',
  };
}

class MapOverlayService {
  const MapOverlayService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// Everything the overlay layer draws for one map, in one pass.
  ///
  /// Scoped to [projectId] throughout: every record is checked against the
  /// project before it can contribute an overlay, so a second project's
  /// characters can never appear here even if a link crossed the boundary.
  Future<MapOverlayData> loadOverlays(String mapId) async {
    final all = await repository.recordsByProject(projectId);
    final active = [
      for (final record in all)
        if (record.status == AuthorRecordStatus.active) record,
    ];
    final byId = {for (final record in active) record.id: record};

    // The places on this map, and where each one sits. Everything else borrows
    // its position from one of these.
    final placed = <String, AuthorRecord>{};
    for (final record in active) {
      if (!WorldRecordTypes.locationTypeIds.contains(record.typeId)) continue;
      if (record.fields[MapFields.mapId] != mapId) continue;
      placed[record.id] = record;
    }

    MapPosition? positionOf(String locationId) {
      final record = placed[locationId];
      if (record == null) return null;
      return MapPosition.read(record.fields,
          xKey: MapFields.x, yKey: MapFields.y);
    }

    String nameOf(String id) => byId[id]?.title ?? '';

    final items = <MapOverlayItem>[];
    final unmapped = <MapOverlayKind, int>{};
    void countUnmapped(MapOverlayKind kind) =>
        unmapped[kind] = (unmapped[kind] ?? 0) + 1;

    // --- locations -------------------------------------------------------
    for (final entry in placed.entries) {
      final record = entry.value;
      final position = positionOf(entry.key);
      if (position == null) continue;
      items.add(
        MapOverlayItem(
          id: 'location-${record.id}',
          projectId: projectId,
          kind: MapOverlayKind.location,
          position: position,
          label: record.title,
          subtitle: _string(record.fields[MapFields.locationType]),
          sourceId: record.id,
          sourceType: record.typeId,
          locationId: record.id,
          locationName: record.title,
        ),
      );
    }

    // --- characters ------------------------------------------------------
    for (final record in active) {
      if (record.typeId != MapOverlayTypes.character) continue;
      final locationId = await _linkedPlace(
        record.id,
        MapOverlayLinks.characterToPlace,
        placed.keys.toSet(),
      );
      final position = locationId == null ? null : positionOf(locationId);
      if (position == null) {
        countUnmapped(MapOverlayKind.character);
        continue;
      }
      items.add(
        MapOverlayItem(
          id: 'character-${record.id}',
          projectId: projectId,
          kind: MapOverlayKind.character,
          position: position,
          label: record.title,
          subtitle: _string(record.fields['role']),
          sourceId: record.id,
          sourceType: record.typeId,
          locationId: locationId!,
          locationName: nameOf(locationId),
        ),
      );
    }

    // --- timeline events -------------------------------------------------
    for (final record in active) {
      if (!MapOverlayTypes.events.contains(record.typeId)) continue;
      final locationId = await _linkedPlace(
        record.id,
        MapOverlayLinks.eventToPlace,
        placed.keys.toSet(),
      );
      final position = locationId == null ? null : positionOf(locationId);
      if (position == null) {
        countUnmapped(MapOverlayKind.event);
        continue;
      }
      items.add(
        MapOverlayItem(
          id: 'event-${record.id}',
          projectId: projectId,
          kind: MapOverlayKind.event,
          position: position,
          label: record.title,
          subtitle: _string(record.fields['eventType']),
          sourceId: record.id,
          sourceType: record.typeId,
          locationId: locationId!,
          locationName: nameOf(locationId),
          moment: MapStoryMoment.fromEventFields(record.fields),
        ),
      );
    }

    // --- manuscript scenes and chapters ----------------------------------
    //
    // Scenes and chapters stay manuscript-domain nodes. They are read here
    // through the shared entity layer they already participate in; nothing
    // promotes them into records, and no scene record is created.
    //
    // The query runs from the map inwards rather than from the manuscript
    // outwards: only places already on this map can anchor a scene, so walking
    // their links finds every mapped scene while reading nothing about the
    // chapters and scenes that are not on the map at all.
    final seenNodes = <String>{};
    for (final locationId in placed.keys) {
      final position = positionOf(locationId);
      if (position == null) continue;
      for (final link in await repository.backlinks(locationId)) {
        if (link.scopeId != projectId) continue;
        if (link.typeId != MapOverlayLinks.locatedAt) continue;
        final other =
            link.sourceId == locationId ? link.targetId : link.sourceId;
        if (!seenNodes.add(other)) continue;
        final node = await repository.manuscriptNodeById(other);
        if (node == null) continue;
        if (node.projectId != projectId) continue;
        items.add(
          MapOverlayItem(
            id: 'scene-${node.id}',
            projectId: projectId,
            kind: MapOverlayKind.scene,
            position: position,
            label: node.title,
            subtitle: node.nodeType,
            sourceId: node.id,
            sourceType: node.nodeType,
            locationId: locationId,
            locationName: nameOf(locationId),
          ),
        );
      }
    }

    final journeys = <MapJourney>[];
    for (final record in active) {
      if (record.typeId != MapOverlayTypes.character) continue;
      final journey = await _journeyFor(record, placed, positionOf, nameOf);
      if (!journey.isEmpty) journeys.add(journey);
    }

    final moments = <int, MapStoryMoment>{};
    for (final item in items) {
      final moment = item.moment;
      if (moment != null) moments[moment.sortKey] = moment;
    }
    final ordered = moments.values.toList()..sort();

    items.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : a.id.compareTo(b.id);
    });
    journeys.sort((a, b) => a.characterId.compareTo(b.characterId));

    return MapOverlayData(
      mapId: mapId,
      projectId: projectId,
      items: items,
      journeys: journeys,
      unmapped: unmapped,
      moments: ordered,
    );
  }

  /// One character's route across this map, in story order.
  Future<MapJourney?> journeyFor(String mapId, String characterId) async {
    final data = await loadOverlays(mapId);
    return data.journeys
        .where((journey) => journey.characterId == characterId)
        .firstOrNull;
  }

  /// The place a story entity is linked to, if that place is on this map.
  ///
  /// Both directions are consulted, because the canonical vocabulary does not
  /// guarantee which end of a `locatedAt` a given Studio wrote. Ties are broken
  /// by link id so the same data always yields the same overlay.
  Future<String?> _linkedPlace(
    String entityId,
    Set<String> linkTypes,
    Set<String> placeIds,
  ) async {
    final links = await repository.backlinks(entityId);
    final candidates = <String>[];
    for (final link in links) {
      if (!linkTypes.contains(link.typeId)) continue;
      if (link.scopeId != projectId) continue;
      final other = link.sourceId == entityId ? link.targetId : link.sourceId;
      if (placeIds.contains(other)) candidates.add(other);
    }
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }

  /// Builds a character's journey from dated events they appear in.
  ///
  /// Only stops the data actually supports: an event must name this character,
  /// carry a date, and occur at a location that is on this map. Missing any of
  /// those, the stop is skipped — never estimated, never interpolated.
  Future<MapJourney> _journeyFor(
    AuthorRecord character,
    Map<String, AuthorRecord> placed,
    MapPosition? Function(String) positionOf,
    String Function(String) nameOf,
  ) async {
    final links = await repository.backlinks(character.id);
    final eventIds = <String>{};
    for (final link in links) {
      if (link.scopeId != projectId) continue;
      if (!MapOverlayLinks.characterToEvent.contains(link.typeId)) continue;
      eventIds.add(link.sourceId == character.id ? link.targetId : link.sourceId);
    }

    final stops = <MapJourneyStop>[];
    for (final eventId in eventIds) {
      final event = await repository.recordById(eventId);
      if (event == null) continue;
      if (!MapOverlayTypes.events.contains(event.typeId)) continue;
      if (event.status != AuthorRecordStatus.active) continue;
      if (!_belongsToProject(event)) continue;
      final moment = MapStoryMoment.fromEventFields(event.fields);
      if (moment == null) continue;
      final locationId = await _linkedPlace(
        event.id,
        MapOverlayLinks.eventToPlace,
        placed.keys.toSet(),
      );
      if (locationId == null) continue;
      final position = positionOf(locationId);
      if (position == null) continue;
      stops.add(
        MapJourneyStop(
          position: position,
          locationId: locationId,
          locationName: nameOf(locationId),
          eventId: event.id,
          eventName: event.title,
          moment: moment,
        ),
      );
    }

    stops.sort((a, b) {
      final byMoment = a.moment.compareTo(b.moment);
      return byMoment != 0 ? byMoment : a.eventId.compareTo(b.eventId);
    });

    return MapJourney(
      characterId: character.id,
      characterName: character.title,
      stops: stops,
    );
  }

  bool _belongsToProject(AuthorRecord record) =>
      record.projectId == projectId || record.scopeId == projectId;

  static String _string(Object? value) => value is String ? value.trim() : '';
}
