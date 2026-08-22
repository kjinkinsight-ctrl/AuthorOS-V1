import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/map_overlays.dart';
import 'package:author_studio_v1/map_presentation_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/map_world.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Studio Phase 6 — reader maps and spoiler filtering.
///
/// The rule under test throughout: a reader view holds only what the level
/// permits, so a renderer handed one cannot leak what it was never given.
const projectId = 'project-map';
final timestamp = DateTime.utc(2026, 8, 22, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;
  late RecordService records;
  late ConnectionEngine connections;
  late MapPresentationService presentations;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    records = RecordService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    presentations = MapPresentationService(
      projectId: projectId,
      repository: repository,
    );
  });

  tearDown(() => database.close());

  MapRevealPoint chapter(int order, {String id = '', String title = ''}) =>
      MapRevealPoint(
        nodeId: id.isEmpty ? 'chapter-$order' : id,
        nodeType: 'chapter',
        label: title.isEmpty ? 'Chapter $order' : title,
        chapterOrder: order,
      );

  group('reveal points and levels', () {
    test('a scene sorts inside its chapter', () {
      const early = MapRevealPoint(
        nodeId: 'scene-a',
        nodeType: 'scene',
        label: 'The First Bell',
        chapterOrder: 3,
        sceneOrder: 1,
      );
      const late_ = MapRevealPoint(
        nodeId: 'scene-b',
        nodeType: 'scene',
        label: 'The Second Bell',
        chapterOrder: 3,
        sceneOrder: 2,
      );

      expect(early.compareTo(late_), lessThan(0));
      expect(early.compareTo(chapter(4)), lessThan(0));
      expect(chapter(2).compareTo(early), lessThan(0));
    });

    test('public shows nothing, full story shows everything', () {
      expect(MapSpoilerLevel.public.allows(chapter(1)), isFalse);
      expect(MapSpoilerLevel.public.allows(null), isFalse);
      expect(MapSpoilerLevel.everything.allows(null), isTrue);
      expect(MapSpoilerLevel.everything.allows(chapter(99)), isTrue);
      expect(MapSpoilerLevel.public.isPublic, isTrue);
    });

    test('a level allows what is revealed up to and including it', () {
      final level = MapSpoilerLevel.through(chapter(7));

      expect(level.allows(chapter(1)), isTrue);
      expect(level.allows(chapter(7)), isTrue);
      expect(level.allows(chapter(8)), isFalse);
      expect(level.allows(null), isFalse,
          reason: 'never said to be revealed is not the same as safe to show');
    });
  });

  group('the reader view withholds by construction', () {
    MapCanvasData canvasWith(List<String> placeIds) => MapCanvasData(
          map: MapSummary(
            record: AuthorRecord(
              id: 'map-kingdom',
              typeId: 'map',
              templateId: 'map',
              scopeType: RecordScopeType.project,
              scopeId: projectId,
              projectId: projectId,
              canonStatus: CanonStatus.canon,
              title: 'Kingdom Map',
              fields: const {},
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          ),
          locations: [
            for (final id in placeIds)
              MapLocationView(
                record: AuthorRecord(
                  id: id,
                  typeId: 'location',
                  templateId: 'location',
                  scopeType: RecordScopeType.project,
                  scopeId: projectId,
                  projectId: projectId,
                  canonStatus: CanonStatus.canon,
                  title: id,
                  fields: {
                    MapFields.mapId: 'map-kingdom',
                    MapFields.x: 100.0,
                    MapFields.y: 100.0,
                  },
                  createdAt: timestamp,
                  updatedAt: timestamp,
                ),
                mapId: 'map-kingdom',
              ),
          ],
          regions: const [],
          markers: const [],
        );

    MapOverlayData overlaysAt(String placeId, String characterId) =>
        MapOverlayData(
          mapId: 'map-kingdom',
          projectId: projectId,
          items: [
            MapOverlayItem(
              id: 'character-$characterId',
              projectId: projectId,
              kind: MapOverlayKind.character,
              position: const MapPosition(100, 100),
              label: characterId,
              sourceId: characterId,
              sourceType: 'character',
              locationId: placeId,
            ),
          ],
        );

    MapWorldState worldWith(List<String> settlementIds) => MapWorldState(
          mapId: 'map-kingdom',
          projectId: projectId,
          kind: MapWorldStateKind.current,
          settlements: [
            for (final id in settlementIds)
              MapSettlement(
                id: id,
                name: id,
                kind: MapSettlementKind.city,
                position: const MapPosition(100, 100),
              ),
          ],
          routes: [
            MapWorldRoute(
              id: 'route-secret',
              name: 'The Smugglers Way',
              kind: MapRouteKind.hidden,
              fromId: settlementIds.first,
              toId: settlementIds.last,
              fromPosition: const MapPosition(100, 100),
              toPosition: const MapPosition(400, 400),
            ),
          ],
        );

    test('an unrevealed place is not in the view at all', () {
      final view = MapReaderProjection.apply(
        level: MapSpoilerLevel.through(chapter(3)),
        canvas: canvasWith(['city-known', 'city-secret']),
        overlays: const MapOverlayData(mapId: 'map-kingdom', projectId: projectId),
        world: worldWith(['city-known', 'city-secret']),
        revealed: {'city-known': chapter(1)},
      );

      expect(
        view.canvas.locations.map((item) => item.record.id),
        ['city-known'],
      );
      expect(view.world.settlements.map((item) => item.id), ['city-known']);
      expect(view.hidden['places'], 1);
      expect(view.hiddenTotal, greaterThan(0));
    });

    test('a revealed character standing in a hidden city stays hidden', () {
      final view = MapReaderProjection.apply(
        level: MapSpoilerLevel.through(chapter(3)),
        canvas: canvasWith(['city-secret']),
        overlays: overlaysAt('city-secret', 'character-mara'),
        world: worldWith(['city-secret']),
        revealed: {'character-mara': chapter(1)},
      );

      expect(view.canvas.locations, isEmpty);
      expect(view.overlays.items, isEmpty,
          reason: 'the character would give away where the city is');
    });

    test('a route is shown only when both of its ends are', () {
      final view = MapReaderProjection.apply(
        level: MapSpoilerLevel.through(chapter(3)),
        canvas: canvasWith(['city-known', 'city-secret']),
        overlays: const MapOverlayData(mapId: 'map-kingdom', projectId: projectId),
        world: worldWith(['city-known', 'city-secret']),
        revealed: {
          'city-known': chapter(1),
          'route-secret': chapter(1),
        },
      );

      expect(view.world.routes, isEmpty,
          reason: 'half a road pointing off the map is itself a spoiler');
    });

    test('the author view is the unfiltered projection', () {
      final canvas = canvasWith(['city-known', 'city-secret']);
      final view = MapReaderProjection.apply(
        level: MapSpoilerLevel.everything,
        canvas: canvas,
        overlays: const MapOverlayData(mapId: 'map-kingdom', projectId: projectId),
        world: worldWith(['city-known', 'city-secret']),
        revealed: const {},
      );

      expect(view.canvas.locations, hasLength(2));
      expect(view.hidden, isEmpty);
      expect(view.notice, isEmpty);
    });

    test('a project with no reveal points says why the map is empty', () {
      final view = MapReaderProjection.apply(
        level: MapSpoilerLevel.public,
        canvas: canvasWith(['city-known']),
        overlays: const MapOverlayData(mapId: 'map-kingdom', projectId: projectId),
        world: worldWith(['city-known']),
        revealed: const {},
      );

      expect(view.isEmpty, isTrue);
      expect(view.unrevealed, 1);
      expect(view.notice, contains('marked as revealed'));
      expect(view.notice, contains('revealedIn'),
          reason: 'the author is told which link is missing, not just that the '
              'map is empty');
    });
  });

  group('the presentation service reads canonical sources', () {
    Future<void> seedManuscript() async {
      await repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'book-one',
          projectId: projectId,
          nodeType: 'book',
          title: 'House of Shadows & Saints',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
        ManuscriptNodeReference(
          id: 'chapter-one',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'The Bell',
          createdAt: timestamp,
          updatedAt: timestamp,
          extensionData: const {'order': 1},
        ),
        ManuscriptNodeReference(
          id: 'chapter-seven',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'The Siege',
          createdAt: timestamp,
          updatedAt: timestamp,
          extensionData: const {'order': 7},
        ),
        ManuscriptNodeReference(
          id: 'scene-bell',
          projectId: projectId,
          nodeType: 'scene',
          title: 'The First Bell',
          createdAt: timestamp,
          updatedAt: timestamp,
          extensionData: const {'chapterId': 'chapter-one', 'order': 2},
        ),
      ]);
    }

    Future<MapSummary> seedMap() => maps.createMap(
          const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
          timestamp: timestamp,
        );

    test('reveal points come from revealedIn links, earliest winning',
        () async {
      await seedManuscript();
      await seedMap();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-aurel',
          mapId: 'map-kingdom',
          name: 'Aurel',
          locationType: 'City',
          position: MapPosition(200, 200),
        ),
        timestamp: timestamp,
      );
      await connections.connect(
        sourceId: 'city-aurel',
        targetId: 'chapter-seven',
        typeId: 'revealedIn',
        timestamp: timestamp,
      );
      await connections.connect(
        sourceId: 'city-aurel',
        targetId: 'scene-bell',
        typeId: 'revealedIn',
        timestamp: timestamp,
      );

      final points = await presentations.revealPoints();

      expect(points.keys, contains('city-aurel'));
      expect(points['city-aurel']!.nodeId, 'scene-bell',
          reason: 'a thing is known from the first time the reader meets it');
      expect(points['city-aurel']!.chapterOrder, 1);
    });

    test('spoiler levels are the chapters, in reading order', () async {
      await seedManuscript();

      final levels = await presentations.spoilerLevels();

      expect(levels.first.isPublic, isTrue);
      expect(levels.last.isEverything, isTrue);
      expect(
        levels.map((level) => level.label).toList(),
        ['Public', 'Through The Bell', 'Through The Siege', 'Full story'],
      );
    });

    test('metadata reads the canonical sources and reports what is missing',
        () async {
      await seedManuscript();
      final map = await seedMap();

      final metadata = await presentations.metadataFor(
        map,
        projectTitle: 'A Crown of Ash',
        eraLabel: '412 A.E.',
      );

      expect(metadata.mapTitle, 'Kingdom Map');
      expect(metadata.bookTitle, 'House of Shadows & Saints');
      expect(metadata.eraLabel, '412 A.E.');
      expect(metadata.revision, greaterThan(0));
      expect(metadata.seriesTitle, isEmpty);
      expect(
        metadata.gaps.map((gap) => gap.element),
        contains('Series title'),
        reason: "'series' is a declared type nothing creates — reported, not "
            'invented',
      );
    });

    test('a series record, once one exists, is used', () async {
      await seedManuscript();
      final map = await seedMap();
      await records.createRecord(
        AuthorRecord(
          id: 'series-ash',
          typeId: 'series',
          templateId: 'series',
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          canonStatus: CanonStatus.canon,
          title: 'The Ashes Cycle',
          fields: const {},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

      final metadata = await presentations.metadataFor(
        map,
        projectTitle: 'A Crown of Ash',
      );

      expect(metadata.seriesTitle, 'The Ashes Cycle');
      expect(
        metadata.gaps.map((gap) => gap.element),
        isNot(contains('Series title')),
      );
    });

    test('reading for presentation writes nothing', () async {
      await seedManuscript();
      final map = await seedMap();

      final before = (await repository.snapshot()).toJson();
      await presentations.revealPoints();
      await presentations.spoilerLevels();
      await presentations.metadataFor(map, projectTitle: 'A Crown of Ash');
      presentations.scaleBarFor(map);
      final after = (await repository.snapshot()).toJson();

      expect(after, before);
    });
  });
}
