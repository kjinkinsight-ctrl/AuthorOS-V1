import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/world_service.dart';

class WorldPhase1Fixture {
  const WorldPhase1Fixture._();

  static const projectId = 'world-phase-1-fixture';
  static final timestamp = DateTime.utc(2026, 8, 20);

  static Future<void> seed(WorldService worlds) async {
    for (final record in const [
      ('universe-one', 'universe', 'The Loom'),
      ('world-one', 'world', 'Endovier'),
      ('continent-one', 'continent', 'Edrath'),
      ('region-north', 'region', 'Northern Reach'),
      ('region-south', 'region', 'Sunward Reach'),
      ('country-nox', 'country', 'Nox'),
      ('country-vale', 'country', 'Vale Republic'),
      ('city-noxmere', 'city', 'Noxmere'),
      ('city-greyhaven', 'city', 'Greyhaven'),
      ('city-solport', 'city', 'Solport'),
      ('keep-black', 'building', 'Black Keep'),
      ('inn-lantern', 'building', 'Lantern Inn'),
      ('harbour-mist', 'district', 'Mist Harbour'),
    ]) {
      await worlds.createWorldRecord(
        id: record.$1,
        typeId: record.$2,
        title: record.$3,
        canonState: 'Canon',
        canonStatus: CanonStatus.canon,
        timestamp: timestamp,
      );
    }

    for (final relation in const [
      ('world-one', 'universe-one'),
      ('continent-one', 'world-one'),
      ('region-north', 'continent-one'),
      ('region-south', 'continent-one'),
      ('country-nox', 'region-north'),
      ('country-vale', 'region-south'),
      ('city-noxmere', 'country-nox'),
      ('city-greyhaven', 'country-nox'),
      ('city-solport', 'country-vale'),
      ('keep-black', 'city-noxmere'),
      ('inn-lantern', 'city-greyhaven'),
      ('harbour-mist', 'city-solport'),
    ]) {
      await worlds.setParent(childId: relation.$1, parentId: relation.$2);
    }

    for (final record in [
      _record('character-ruler', 'character', 'Queen Mara', {
        'identity.fullName': 'Queen Mara',
      }),
      _record('character-resident', 'character', 'Tomas Reed', {
        'identity.fullName': 'Tomas Reed',
      }),
      _record('character-traveller', 'character', 'Kali Vale', {
        'identity.fullName': 'Kali Vale',
      }),
      _record('government-crown', 'government', 'The Nox Crown'),
      _record('faction-rebels', 'faction', 'Lantern Rebellion'),
      _record('culture-northern', 'culture', 'Northern Reach Culture'),
      _record('religion-tides', 'religion', 'Faith of the Tides'),
      _record('magic-veil', 'magic-system', 'Veilcraft'),
      _record('artifact-crown', 'artefact', 'The Glass Crown'),
      _record('event-founding', 'historical-event', 'Founding of Noxmere'),
      _record('event-uprising', 'historical-event', 'Lantern Uprising'),
      _record('event-eclipse', 'historical-event', 'The Long Eclipse'),
      _record('book-one', 'book', 'Ash and Lanterns'),
      _record('chapter-one', 'chapter', 'The Black Keep'),
      _record('chapter-two', 'chapter', 'Mist Harbour'),
      _record('scene-throne', 'scene', 'The Throne Room'),
      _record('scene-road', 'scene', 'The Mist Road'),
      _record('scene-revolt', 'scene', 'Lanterns Rise'),
    ]) {
      await worlds.records.createRecord(record);
    }

    for (final link in const [
      ('character-ruler', 'city-noxmere', 'homeAt'),
      ('character-resident', 'city-greyhaven', 'livesIn'),
      ('character-traveller', 'city-solport', 'currentlyAt'),
      ('government-crown', 'country-nox', 'rules'),
      ('faction-rebels', 'region-north', 'controls'),
      ('city-noxmere', 'culture-northern', 'hasCulture'),
      ('city-solport', 'religion-tides', 'associatedWith'),
      ('region-north', 'magic-veil', 'associatedWith'),
      ('keep-black', 'artifact-crown', 'associatedWith'),
      ('event-founding', 'city-noxmere', 'occursAt'),
      ('event-uprising', 'region-north', 'occursAt'),
      ('event-eclipse', 'world-one', 'occursAt'),
      ('chapter-one', 'book-one', 'partOf'),
      ('chapter-two', 'book-one', 'partOf'),
      ('scene-throne', 'chapter-one', 'partOf'),
      ('scene-road', 'chapter-one', 'partOf'),
      ('scene-revolt', 'chapter-two', 'partOf'),
      ('city-noxmere', 'scene-throne', 'appearsIn'),
      ('city-solport', 'scene-road', 'appearsIn'),
      ('region-north', 'scene-revolt', 'appearsIn'),
      ('character-ruler', 'scene-throne', 'appearsIn'),
      ('character-traveller', 'scene-road', 'appearsIn'),
      ('faction-rebels', 'scene-revolt', 'appearsIn'),
    ]) {
      await worlds.connections.connect(
        sourceId: link.$1,
        targetId: link.$2,
        typeId: link.$3,
        timestamp: timestamp,
      );
    }
  }

  static AuthorRecord _record(
    String id,
    String typeId,
    String title, [
    Map<String, Object?> fields = const {},
  ]) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        canonStatus: CanonStatus.canon,
        title: title,
        fields: fields,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
}
