/// Map Studio Phase 6 — authoring reveal points.
///
/// Phase 6 landed read-only: it could *read* `revealedIn` and filter a reader
/// map by it, but nothing in AuthorOS wrote one, so every reader level below
/// the author's own was empty on every project. These cover the one write that
/// closes that gap, and the rules it has to obey.
///
/// The rules, restated so a failure here reads as what it is:
///
/// 1. A reveal exists **only** because an author asked for it. Nothing infers
///    one, and nothing creates one as a side effect of drawing, exporting,
///    opening a map or reading a reader view.
/// 2. It is the **canonical** relationship, written through the **existing**
///    [ConnectionEngine] — versioned and audited like any other link. No second
///    spoiler system, no Map-owned reveal store.
/// 3. It is **reversible**, and removing one returns the record to hidden.
/// 4. A project nobody has authored reveals on stays **spoiler-safe**.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/map_presentation_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const projectId = 'project-map';
const otherProjectId = 'project-other';
final timestamp = DateTime.utc(2026, 8, 22, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;
  late MapPresentationService presentations;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    presentations = MapPresentationService(
      projectId: projectId,
      repository: repository,
    );
  });

  tearDown(() => database.close());

  ManuscriptNodeReference node(
    String id,
    String type,
    String title, {
    String scope = projectId,
    Map<String, Object?> extensionData = const {},
  }) =>
      ManuscriptNodeReference(
        id: id,
        projectId: scope,
        nodeType: type,
        title: title,
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: extensionData,
      );

  Future<void> seedManuscript() => repository.putManuscriptNodes([
        node('chapter-one', 'chapter', 'The Bell',
            extensionData: const {'order': 1}),
        node('chapter-seven', 'chapter', 'The Siege',
            extensionData: const {'order': 7}),
        node('scene-bell', 'scene', 'The First Bell',
            extensionData: const {'chapterId': 'chapter-one', 'order': 2}),
        node('book-one', 'book', 'House of Shadows'),
      ]);

  Future<void> seedCity() async {
    await maps.createMap(
      const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
      timestamp: timestamp,
    );
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
  }

  Future<void> seedAll() async {
    await seedManuscript();
    await seedCity();
  }

  group('a reveal point is written, and only on purpose', () {
    test('writes the canonical relationship in the readable direction',
        () async {
      await seedAll();

      final link = await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      // "Aurel is revealed in The Siege" — source is the thing revealed, which
      // is the direction the relationship's own label reads in.
      expect(link.typeId, 'revealedIn');
      expect(link.sourceId, 'city-aurel');
      expect(link.targetId, 'chapter-seven');
      expect(link.scopeId, projectId);
    });

    test('the type is the one AuthorOS already defines, not a new one',
        () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      // The whole point of the locked decision: no new relationship type was
      // invented for spoilers. If this ever resolves to something Map Studio
      // declared for itself, there are two spoiler systems.
      final registry = BuiltInConnectionTypes.registry();
      final definition = registry.resolve('revealedIn');
      expect(definition.builtIn, isTrue);
      expect(definition.displayName, 'Revealed in');
      expect(definition.inverseLabel, 'Reveals');
    });

    test('it goes through the ConnectionEngine, so it is versioned and audited',
        () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      final snapshot = await repository.snapshot();
      final audit = snapshot.auditEvents.where(
        (event) => event.changeType == AuditChangeType.connectionAdded,
      );

      // A reveal is an editorial decision about the reader's experience. It
      // leaves the same trail as any other canonical edit, because it is one.
      expect(audit, isNotEmpty);
      expect(
        snapshot.versions.any((version) => version.recordId == 'city-aurel'),
        isTrue,
      );
    });

    test('the same reveal twice does not duplicate', () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      expect(await maps.revealPointsFor('city-aurel'), hasLength(1));
    });

    test('a scene and a book are both acceptable reveal points', () async {
      await seedAll();

      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'scene-bell',
        timestamp: timestamp,
      );
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'book-one',
        timestamp: timestamp,
      );

      expect(await maps.revealPointsFor('city-aurel'), hasLength(2));
    });
  });

  group('endpoints are disciplined here, because the registry is not', () {
    test('a reveal cannot point at a record', () async {
      await seedAll();
      await maps.createLocation(
        const MapLocationDraft(
          id: 'city-vale',
          mapId: 'map-kingdom',
          name: 'Vale',
          locationType: 'City',
          position: MapPosition(300, 300),
        ),
        timestamp: timestamp,
      );

      // `revealedIn` is registered with wildcard endpoints, so the registry
      // would happily accept city -> city. A reveal that names no position in
      // reading order orders by nothing and filters by nothing.
      await expectLater(
        maps.addRevealPoint(recordId: 'city-aurel', nodeId: 'city-vale'),
        throwsA(isA<MapStudioException>()),
      );
      expect(await maps.revealPointsFor('city-aurel'), isEmpty);
    });

    test('a reveal cannot cross projects', () async {
      await seedAll();
      await repository.putManuscriptNodes([
        node('foreign-chapter', 'chapter', 'Someone Else\'s Book',
            scope: otherProjectId),
      ]);

      await expectLater(
        maps.addRevealPoint(
          recordId: 'city-aurel',
          nodeId: 'foreign-chapter',
        ),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('an unknown record and an unknown node are both refused', () async {
      await seedAll();

      await expectLater(
        maps.addRevealPoint(recordId: 'nobody', nodeId: 'chapter-one'),
        throwsA(isA<MapStudioException>()),
      );
      await expectLater(
        maps.addRevealPoint(recordId: 'city-aurel', nodeId: 'nowhere'),
        throwsA(isA<MapStudioException>()),
      );
    });

    test('the refusal names the type, so the author can act on it', () async {
      await seedAll();
      await repository.putManuscriptNodes([
        node('part-one', 'part', 'Part One'),
      ]);

      await expectLater(
        maps.addRevealPoint(recordId: 'city-aurel', nodeId: 'part-one'),
        throwsA(
          isA<MapStudioException>().having(
            (error) => error.toString(),
            'message',
            contains('part'),
          ),
        ),
      );
    });
  });

  group('a reveal point is reversible', () {
    test('removing one takes it out of the canonical store', () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      final removed = await maps.removeRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      expect(removed, isTrue);
      expect(await maps.revealPointsFor('city-aurel'), isEmpty);
      final snapshot = await repository.snapshot();
      expect(
        snapshot.links.where((link) => link.typeId == 'revealedIn'),
        isEmpty,
      );
    });

    test('removing one the author never made is not an error', () async {
      await seedAll();

      expect(
        await maps.removeRevealPoint(
          recordId: 'city-aurel',
          nodeId: 'chapter-seven',
        ),
        isFalse,
      );
    });

    test('removing one leaves the others standing', () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      await maps.removeRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );

      final left = await maps.revealPointsFor('city-aurel');
      expect(left, hasLength(1));
      expect(left.single.nodeId, 'chapter-seven');
    });

    test('unrevealing returns the record to hidden', () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );
      expect((await presentations.revealPoints()).keys, contains('city-aurel'));

      await maps.removeRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );

      // Back to "the author has not said when this becomes known", which every
      // level below the author's own treats as hidden. Unrevealing is safe by
      // the same rule that makes an untouched project safe.
      expect(await presentations.revealPoints(), isEmpty);
    });

    test('the removal is audited too', () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );
      await maps.removeRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
        timestamp: timestamp,
      );

      final snapshot = await repository.snapshot();
      expect(
        snapshot.auditEvents.any(
          (event) => event.changeType == AuditChangeType.connectionRemoved,
        ),
        isTrue,
      );
    });
  });

  group('what is written is what the reader layer reads', () {
    test('an authored reveal reaches the presentation service', () async {
      await seedAll();

      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      // The two halves have to meet: the write is pointless if the read layer
      // built in Phase 6 cannot see it.
      final points = await presentations.revealPoints();
      expect(points['city-aurel']!.nodeId, 'chapter-seven');
      expect(points['city-aurel']!.chapterOrder, 7);
    });

    test('the earliest reveal still wins after a later one is added',
        () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'scene-bell',
        timestamp: timestamp,
      );

      final points = await presentations.revealPoints();
      expect(points['city-aurel']!.nodeId, 'scene-bell');
    });

    test('the listing carries what the author needs to see and undo it',
        () async {
      await seedAll();
      await maps.addRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-seven',
        timestamp: timestamp,
      );

      final reveals = await maps.revealPointsFor('city-aurel');

      expect(reveals.single.nodeTitle, 'The Siege');
      expect(reveals.single.nodeType, 'chapter');
      expect(reveals.single.label, 'Revealed in The Siege');
      expect(reveals.single.link.typeId, 'revealedIn');
    });
  });

  group('a project nobody has authored reveals on stays spoiler-safe', () {
    test('reading, listing and removing all write nothing', () async {
      await seedAll();
      final before = await repository.snapshot();

      await presentations.revealPoints();
      await presentations.spoilerLevels();
      await maps.revealPointsFor('city-aurel');
      await maps.removeRevealPoint(
        recordId: 'city-aurel',
        nodeId: 'chapter-one',
      );

      // The rule that makes every existing project safe: nothing on the read
      // path can bring a reveal into existence, so a map nobody has annotated
      // shows nothing to a reader.
      final after = await repository.snapshot();
      expect(after.links.length, before.links.length);
      expect(after.records.length, before.records.length);
      expect(after.versions.length, before.versions.length);
      expect(after.auditEvents.length, before.auditEvents.length);
    });

    test('with no reveals at all, the reveal index is empty', () async {
      await seedAll();

      expect(await presentations.revealPoints(), isEmpty);
    });
  });
}
