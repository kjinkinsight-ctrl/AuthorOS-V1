import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/world_record_types.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/world_phase_1_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late WorldService worlds;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    worlds = WorldService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('World catalogue exposes all location families and built-in templates',
      () async {
    final registry = await worlds.records.registry();

    expect(
      WorldRecordTypes.locationTypeIds,
      containsAll(const {
        'continent',
        'country',
        'city',
        'building',
        'room',
        'natural-feature',
        'river',
        'ocean',
        'cave',
        'road',
        'border',
        'other-custom-location',
      }),
    );
    for (final templateId in const [
      'basic-location',
      'city',
      'country',
      'region',
      'building',
      'natural-feature',
      'world',
    ]) {
      expect(
          registry.resolve(templateId).extensionData['worldTemplate'], isTrue);
    }
    expect(registry.resolve('city').fields.map((field) => field.id),
        containsAll(['population', 'government', 'districts', 'secrets']));
  });

  test(
      'World CRUD, custom templates, audit, search, and inspection share core services',
      () async {
    const capitalTemplate = RecordTypeDefinition(
      id: 'capital-city',
      name: 'Capital City',
      categoryId: 'locations',
      baseTypeId: 'city',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      fields: [
        RecordFieldDefinition(
          id: 'seatOfPower',
          label: 'Seat of Power',
          type: RecordFieldType.shortText,
          order: 400,
        ),
      ],
      sections: [],
    );
    await worlds.registerCustomTemplate(capitalTemplate);
    final created = await worlds.createWorldRecord(
      id: 'noxmere',
      title: 'Noxmere',
      typeId: 'city',
      fields: const {
        'alternateNames': ['City of Mists'],
        'population': 84000,
      },
      tags: const ['Capital', 'Dangerous'],
      canonState: 'Canon',
      canonStatus: CanonStatus.canon,
      timestamp: timestamp,
    );
    final templated = await worlds.changeTemplate(
      created.id,
      templateId: 'capital-city',
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );
    final updated = await worlds.updateWorldRecord(
      templated.copyWith(
        fields: {...templated.fields, 'seatOfPower': 'Black Keep'},
        updatedAt: timestamp.add(const Duration(minutes: 2)),
      ),
    );
    final duplicate = await worlds.duplicateWorldRecord(
      updated.id,
      newId: 'noxmere-copy',
      timestamp: timestamp.add(const Duration(minutes: 3)),
    );
    final archived = await worlds.archiveWorldRecord(
      duplicate.id,
      timestamp: timestamp.add(const Duration(minutes: 4)),
    );
    final restored = await worlds.restoreWorldRecord(
      duplicate.id,
      timestamp: timestamp.add(const Duration(minutes: 5)),
    );

    expect((await worlds.getWorldRecord(created.id))?.fields['seatOfPower'],
        'Black Keep');
    expect(archived.status, AuthorRecordStatus.archived);
    expect(restored.status, AuthorRecordStatus.active);
    expect(
        (await worlds.searchWorldRecords('Noxmere')).map((hit) => hit.recordId),
        containsAll(['noxmere', 'noxmere-copy']));
    expect(
        (await worlds.searchWorldRecords('Mists')).map((hit) => hit.recordId),
        containsAll(['noxmere', 'noxmere-copy']));
    expect((await worlds.getWorldHistory(created.id)).length,
        greaterThanOrEqualTo(3));
    final inspection = await worlds.inspectWorldRecord(created.id);
    expect(inspection, isNotNull);
    expect(inspection!.template.id, 'capital-city');
    expect(inspection.validation.state.name, isNot('error'));
  });

  test(
      'hierarchy returns relatives and rejects cycles and cross-project parents',
      () async {
    for (final record in const [
      ('universe', 'universe', 'The Loom'),
      ('world', 'world', 'Endovier'),
      ('continent', 'continent', 'Edrath'),
      ('country', 'country', 'Nox'),
      ('city', 'city', 'Noxmere'),
      ('building', 'building', 'Black Keep'),
    ]) {
      await worlds.createWorldRecord(
        id: record.$1,
        typeId: record.$2,
        title: record.$3,
        timestamp: timestamp,
      );
    }
    await worlds.setParent(childId: 'world', parentId: 'universe');
    await worlds.setParent(childId: 'continent', parentId: 'world');
    await worlds.setParent(childId: 'country', parentId: 'continent');
    await worlds.setParent(childId: 'city', parentId: 'country');
    await worlds.setParent(childId: 'building', parentId: 'city');
    await worlds.createWorldRecord(
        id: 'sibling-city', typeId: 'city', title: 'Greyhaven');
    await worlds.setParent(childId: 'sibling-city', parentId: 'country');

    expect((await worlds.getParent('city'))?.id, 'country');
    expect((await worlds.getChildren('country')).map((record) => record.id),
        containsAll(['city', 'sibling-city']));
    expect((await worlds.getSiblings('city')).single.id, 'sibling-city');
    expect((await worlds.getAncestors('building')).map((record) => record.id),
        ['city', 'country', 'continent', 'world', 'universe']);
    expect((await worlds.getDescendants('world')).map((record) => record.id),
        containsAll(['continent', 'country', 'city', 'building']));
    expect((await worlds.getRoot('building'))?.id, 'universe');
    expect((await worlds.getRootWorld('building'))?.id, 'world');
    expect((await worlds.getRootUniverse('building'))?.id, 'universe');

    await expectLater(
      worlds.setParent(childId: 'universe', parentId: 'building'),
      throwsA(isA<WorldHierarchyException>()),
    );
    await expectLater(
      worlds.setParent(childId: 'city', parentId: 'city'),
      throwsA(isA<WorldHierarchyException>()),
    );

    final other = WorldService(projectId: 'project-b', repository: repository);
    await other.createWorldRecord(
        id: 'other-world', typeId: 'world', title: 'Other');
    await expectLater(
      worlds.setParent(childId: 'city', parentId: 'other-world'),
      throwsStateError,
    );
  });

  test(
      'maps, markers, routes, integrations, and safe delete use stable records and links',
      () async {
    final city = await worlds.createWorldRecord(
        id: 'city', typeId: 'city', title: 'Noxmere');
    final port = await worlds.createWorldRecord(
        id: 'port', typeId: 'district', title: 'Mistport');
    final character = AuthorRecord(
      id: 'traveller',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: 'Kali Vale',
      fields: const {'identity.fullName': 'Kali Vale'},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await worlds.records.createRecord(character);
    await worlds.connectWorldRecord(
      sourceId: character.id,
      targetId: city.id,
      typeId: 'currentlyAt',
      metadata: const {'startDate': '2026-08-20'},
    );
    final map = await worlds.createMap(
      id: 'city-map',
      title: 'Noxmere Map',
      typeId: 'city-map',
      mappedRecordId: city.id,
      metadata: const {
        'width': 2000,
        'height': 1200,
        'coordinateSystem': 'local'
      },
    );
    final marker = await worlds.createMapMarker(
      markerId: 'marker-palace',
      mapId: map.id,
      recordId: city.id,
      x: 315.5,
      y: 440,
      label: 'Black Keep',
    );
    final route = await worlds.createRoute(
      id: 'mist-road',
      title: 'Mist Road',
      typeId: 'road-route',
      startId: city.id,
      endId: port.id,
      metadata: const {
        'distance': '12 km',
        'travelTime': '3 hours',
        'danger': 'Moderate',
      },
    );

    expect(marker.fields, containsPair('recordId', city.id));
    expect((await worlds.getMaps(city.id)).single.id, map.id);
    expect((await worlds.getRoutes(city.id)).single.id, route.id);
    expect(
        (await worlds.getConnectedCharacters(city.id)).single.id, character.id);
    final markerLinks = await worlds.connections.connections(marker.id);
    expect(markerLinks.map((link) => link.typeId),
        containsAll(['onMap', 'represents']));
    final routeLinks = await worlds.connections.connections(route.id);
    expect(routeLinks.map((link) => link.typeId),
        containsAll(['routeFrom', 'routeTo']));

    final deletion = await worlds.analyzeDelete(city.id);
    expect(deletion, isNotNull);
    expect(deletion!.disposition, isNot(SafeDeleteDisposition.safe));
    expect(deletion.affectedRecords,
        containsAll([character.id, map.id, marker.id, route.id]));
  });

  test('branch overrides are sparse and leave canonical World data unchanged',
      () async {
    final canonical = await worlds.createWorldRecord(
      id: 'city',
      typeId: 'city',
      title: 'Noxmere',
      fields: const {'population': 84000},
      canonState: 'Canon',
      canonStatus: CanonStatus.canon,
      timestamp: timestamp,
    );
    await worlds.branches.createBranch(StoryBranch(
      id: 'alternate',
      projectId: 'project-a',
      name: 'Alternate Noxmere',
      kind: BranchKind.alternateUniverse,
      createdAt: timestamp,
    ));
    await worlds.overrideWorldRecordInBranch(
      'alternate',
      canonical.id,
      title: 'Free Noxmere',
      fields: const {'population': 91000},
      canonStatus: CanonStatus.alternate,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );

    final branchRecord = (await worlds.branches.recordsForBranch('alternate'))
        .singleWhere((record) => record.id == canonical.id);
    final reloadedCanon = await worlds.getWorldRecord(canonical.id);

    expect(branchRecord.title, 'Free Noxmere');
    expect(branchRecord.fields['population'], 91000);
    expect(branchRecord.branchId, 'alternate');
    expect(reloadedCanon?.title, 'Noxmere');
    expect(reloadedCanon?.fields['population'], 84000);
  });

  test('cross-system fixture forms one stable universal-record graph',
      () async {
    final fixtureWorlds = WorldService(
      projectId: WorldPhase1Fixture.projectId,
      repository: repository,
    );
    await WorldPhase1Fixture.seed(fixtureWorlds);

    final snapshot = await repository.snapshot();
    final fixtureRecords = snapshot.records
        .where((record) => record.projectId == WorldPhase1Fixture.projectId)
        .toList();
    final fixtureLinks = snapshot.links
        .where((link) => link.scopeId == WorldPhase1Fixture.projectId)
        .toList();

    expect(fixtureRecords.where((record) => record.typeId == 'universe'),
        hasLength(1));
    expect(fixtureRecords.where((record) => record.typeId == 'world'),
        hasLength(1));
    expect(fixtureRecords.where((record) => record.typeId == 'region'),
        hasLength(2));
    expect(fixtureRecords.where((record) => record.typeId == 'country'),
        hasLength(2));
    expect(fixtureRecords.where((record) => record.typeId == 'city'),
        hasLength(3));
    expect(fixtureRecords.where((record) => record.typeId == 'character'),
        hasLength(3));
    expect(
        fixtureRecords.where((record) => record.typeId == 'historical-event'),
        hasLength(3));
    expect(fixtureRecords.where((record) => record.typeId == 'chapter'),
        hasLength(2));
    expect(fixtureRecords.where((record) => record.typeId == 'scene'),
        hasLength(3));
    expect(
        fixtureLinks.map((link) => link.typeId),
        containsAll([
          'locatedIn',
          'currentlyAt',
          'controls',
          'hasCulture',
          'occursAt',
          'appearsIn'
        ]));
    expect(
      fixtureLinks.every((link) =>
          fixtureRecords.any((record) => record.id == link.sourceId) &&
          fixtureRecords.any((record) => record.id == link.targetId)),
      isTrue,
    );
  });
}
