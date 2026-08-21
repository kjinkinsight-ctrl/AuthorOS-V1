import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// World Studio Phase 2 workspace behaviour, exercised through the same
/// services the workspace UI calls.
void main() {
  const projectId = 'project-world-2';
  final timestamp = DateTime.utc(2026, 8, 20);
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late WorldService worlds;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    worlds = WorldService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> place({
    required String id,
    required String title,
    String typeId = 'city',
    String canonState = 'Draft',
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
  }) =>
      worlds.createWorldRecord(
        id: id,
        title: title,
        typeId: typeId,
        fields: fields,
        tags: tags,
        canonState: canonState,
        timestamp: timestamp,
      );

  /// world > region > city, so hierarchy assertions have real depth.
  Future<void> seedHierarchy() async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await place(id: 'north', title: 'The North', typeId: 'region');
    await place(id: 'noxmere', title: 'Noxmere', typeId: 'city');
    await worlds.setParent(childId: 'north', parentId: 'aethel');
    await worlds.setParent(childId: 'noxmere', parentId: 'north');
  }

  group('hierarchy tree', () {
    test('nests places and keeps the path to a filtered match', () async {
      await seedHierarchy();

      final tree = await worlds.hierarchyTree();
      expect(tree, hasLength(1));
      expect(tree.single.record.id, 'aethel');
      expect(tree.single.depth, 0);
      expect(tree.single.children.single.record.id, 'north');
      expect(tree.single.children.single.depth, 1);
      expect(
        tree.single.children.single.children.single.record.id,
        'noxmere',
      );
      expect(tree.single.allIds, ['aethel', 'north', 'noxmere']);

      final flat = tree.single.flatten({'aethel', 'north'});
      expect(flat.map((node) => node.id), ['aethel', 'north', 'noxmere']);
      expect(
        tree.single.flatten({'aethel'}).map((node) => node.id),
        ['aethel', 'north'],
      );

      // A filtered tree keeps ancestors as context rows.
      final filtered = await worlds.hierarchyTree(visibleIds: {'noxmere'});
      expect(filtered.single.record.id, 'aethel');
      expect(filtered.single.matchesFilter, isFalse);
      expect(
        filtered.single.children.single.children.single.matchesFilter,
        isTrue,
      );
    });

    test('parents can be set, moved, and detached without deleting records',
        () async {
      await seedHierarchy();
      await place(id: 'south', title: 'The South', typeId: 'region');

      expect((await worlds.getParent('noxmere'))?.id, 'north');
      await worlds.setParent(childId: 'noxmere', parentId: 'south');
      expect((await worlds.getParent('noxmere'))?.id, 'south');
      expect(await worlds.getChildren('north'), isEmpty);

      await worlds.clearParent('noxmere');
      expect(await worlds.getParent('noxmere'), isNull);
      expect(await worlds.getWorldRecord('noxmere'), isNotNull);
      expect(await worlds.getWorldRecord('south'), isNotNull);

      final roots = await worlds.hierarchyTree();
      expect(roots.map((node) => node.id), containsAll(['aethel', 'noxmere']));
    });

    test('a cycle is refused', () async {
      await seedHierarchy();
      await expectLater(
        worlds.setParent(childId: 'aethel', parentId: 'noxmere'),
        throwsA(isA<WorldHierarchyException>()),
      );
      await expectLater(
        worlds.setParent(childId: 'aethel', parentId: 'aethel'),
        throwsA(isA<WorldHierarchyException>()),
      );
    });
  });

  group('search and filtering', () {
    setUp(() async {
      await place(
        id: 'noxmere',
        title: 'Noxmere',
        typeId: 'city',
        canonState: 'Canon',
        fields: {'summary': 'Smugglers move salt beneath the cliffs.'},
        tags: ['capital'],
      );
      await place(
        id: 'ashfall',
        title: 'Ashfall',
        typeId: 'region',
        fields: {'summary': 'A burned plain.'},
      );
      await place(id: 'retired', title: 'Old Quarter', typeId: 'district');
      await worlds.archiveWorldRecord('retired');
    });

    test('a text query is answered by the universal search service', () async {
      final results =
          await worlds.filterWorldRecords(const WorldFilter(query: 'salt'));
      expect(results.map((record) => record.id), ['noxmere']);

      final none = await worlds
          .filterWorldRecords(const WorldFilter(query: 'zzzznothing'));
      expect(none, isEmpty);
    });

    test('facets narrow the list and archived records stay hidden', () async {
      expect(
        (await worlds.filterWorldRecords(WorldFilter.empty))
            .map((record) => record.id),
        unorderedEquals(['noxmere', 'ashfall']),
      );
      expect(
        (await worlds.filterWorldRecords(
          const WorldFilter(typeIds: {'city'}),
        ))
            .map((record) => record.id),
        ['noxmere'],
      );
      expect(
        (await worlds.filterWorldRecords(
          const WorldFilter(canonStates: {'Canon'}),
        ))
            .map((record) => record.id),
        ['noxmere'],
      );
      expect(
        (await worlds.filterWorldRecords(
          const WorldFilter(tagIds: {'capital'}),
        ))
            .map((record) => record.id),
        ['noxmere'],
      );
      expect(
        (await worlds.filterWorldRecords(
          const WorldFilter(includeArchived: true),
        ))
            .map((record) => record.id),
        contains('retired'),
      );
    });

    test('the group facet splits places, maps, markers, and routes', () async {
      await worlds.createMap(
        id: 'map-north',
        title: 'Map of the North',
        mappedRecordId: 'ashfall',
      );
      await worlds.createRoute(
        id: 'salt-road',
        title: 'Salt Road',
        startId: 'noxmere',
        endId: 'ashfall',
      );
      await worlds.createMapMarker(
        markerId: 'marker-nox',
        mapId: 'map-north',
        recordId: 'noxmere',
        x: 10,
        y: 12,
        label: 'Noxmere',
      );

      Future<List<String>> ids(WorldRecordGroup group) async =>
          (await worlds.filterWorldRecords(WorldFilter(group: group)))
              .map((record) => record.id)
              .toList();

      expect(await ids(WorldRecordGroup.spatial),
          unorderedEquals(['noxmere', 'ashfall']));
      expect(await ids(WorldRecordGroup.maps), ['map-north']);
      expect(await ids(WorldRecordGroup.routes), ['salt-road']);
      expect(await ids(WorldRecordGroup.markers), ['marker-nox']);
    });

    test('needs-attention surfaces records that fail validation', () async {
      final broken = (await worlds.getWorldRecord('ashfall'))!;
      await repository.putRecord(broken.copyWith(
        fields: {...broken.fields, 'population': 'not-a-number'},
        revision: broken.revision + 1,
      ));

      final flagged = await worlds
          .filterWorldRecords(const WorldFilter(onlyInvalid: true));
      expect(flagged.map((record) => record.id), contains('ashfall'));
    });
  });

  group('templates and dynamic fields', () {
    test('world templates include built-ins and registered custom templates',
        () async {
      const capital = RecordTypeDefinition(
        id: 'capital-city',
        name: 'Capital City',
        categoryId: 'locations',
        baseTypeId: 'city',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
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
      await worlds.registerCustomTemplate(capital);

      final templates = await worlds.worldTemplates();
      final ids = templates.map((definition) => definition.id).toSet();
      expect(ids, containsAll(['world', 'city', 'map', 'travel-route']));
      expect(ids, contains('capital-city'));
      expect(ids, isNot(contains('character')));
    });

    test('an edit preserves unknown fields, tags, and extension data',
        () async {
      await place(
        id: 'noxmere',
        title: 'Noxmere',
        fields: {'legacyNote': 'written by an older release'},
        tags: ['capital'],
      );

      await worlds.saveWorldRecord(
        'noxmere',
        title: 'Noxmere',
        fields: {'summary': 'Reworked summary.', 'climate': 'Cold and wet'},
        tags: ['capital', 'coastal'],
        timestamp: timestamp.add(const Duration(minutes: 1)),
      );

      final saved = (await worlds.getWorldRecord('noxmere'))!;
      expect(saved.fields['summary'], 'Reworked summary.');
      expect(saved.fields['climate'], 'Cold and wet');
      expect(saved.fields['legacyNote'], 'written by an older release');
      expect(saved.fields['primaryName'], 'Noxmere');
      expect(saved.tags, ['capital', 'coastal']);
      expect(saved.extensionData['worldStudio'], isTrue);
    });

    test('a custom field round-trips with its author-facing label', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await worlds.setCustomField(
        'noxmere',
        'harbour_depth',
        'Harbour depth',
        '30 fathoms',
      );

      final record = (await worlds.getWorldRecord('noxmere'))!;
      expect(record.fields['harbour_depth'], '30 fathoms');
      expect(
        WorldService.customFieldLabels(record)['harbour_depth'],
        'Harbour depth',
      );
      expect(
        () => worlds.setCustomField('noxmere', '_world.sneaky', 'x', 'y'),
        throwsArgumentError,
      );
    });

    test('template drift is reported per record', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      final record = (await worlds.getWorldRecord('noxmere'))!;
      final reports = await worlds.templateReports([record]);
      expect(
        reports['noxmere']!.status,
        TemplateCompatibilityStatus.current,
      );
    });
  });

  group('connections', () {
    test('connections reach every studio and stay reversible', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await repository.putRecord(AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: 'Kali Ardent',
        templateId: 'character',
        fields: const {'identity.fullName': 'Kali Ardent'},
        createdAt: timestamp,
        updatedAt: timestamp,
      ));

      final permitted = await worlds.connectionTypesBetween(
        sourceTypeId: 'city',
        targetTypeId: 'character',
      );
      expect(permitted.map((item) => item.id), contains('relatedTo'));

      final link = await worlds.connectRecord(
        sourceId: 'noxmere',
        targetId: 'kali',
        typeId: 'relatedTo',
      );
      expect(link.direction, RecordLinkDirection.undirected);
      expect(
        (await worlds.connectionsFor('noxmere')).map((item) => item.id),
        [link.id],
      );
      expect((await worlds.getConnectedCharacters('noxmere')).single.id, 'kali');

      final updated =
          await worlds.updateRecordConnection(link.id, label: 'Home of');
      expect(updated.label, 'Home of');

      await worlds.disconnectRecord(link.id);
      expect(await worlds.connectionsFor('noxmere'), isEmpty);
      expect(await worlds.getWorldRecord('noxmere'), isNotNull);
      expect(await repository.recordById('kali'), isNotNull);
    });

    test('connectable records span the whole project', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await repository.putRecord(AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: 'Kali Ardent',
        templateId: 'character',
        createdAt: timestamp,
        updatedAt: timestamp,
      ));

      final connectable = await worlds.connectableRecords();
      expect(
        connectable.map((record) => record.id),
        containsAll(['noxmere', 'kali']),
      );
    });
  });

  group('maps, markers, and routes', () {
    setUp(() async {
      await place(id: 'noxmere', title: 'Noxmere');
      await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
      await worlds.createMap(
        id: 'map-north',
        title: 'Map of the North',
        mappedRecordId: 'noxmere',
        metadata: const {'width': 100, 'height': 80, 'mapType': 'regional'},
      );
    });

    test('map metadata is read and written through the record', () async {
      final map = (await worlds.getWorldRecord('map-north'))!;
      final metadata = WorldMapMetadata.fromRecord(map);
      expect(metadata.width, 100);
      expect(metadata.height, 80);
      expect(metadata.mapType, 'regional');
      expect(metadata.hasBounds, isTrue);

      await worlds.updateMapMetadata(
        'map-north',
        const WorldMapMetadata(
          mapType: 'world',
          coordinateSystem: 'cartesian',
          width: 200,
          height: 160,
          scale: '1cm = 10 leagues',
          projection: 'flat',
        ),
      );
      final saved = WorldMapMetadata.fromRecord(
        (await worlds.getWorldRecord('map-north'))!,
      );
      expect(saved.width, 200);
      expect(saved.scale, '1cm = 10 leagues');
      expect(saved.coordinateSystem, 'cartesian');

      expect((await worlds.mapsFor('noxmere')).single.id, 'map-north');
    });

    test('markers resolve their target and flag out-of-bounds placement',
        () async {
      await worlds.createMapMarker(
        markerId: 'marker-nox',
        mapId: 'map-north',
        recordId: 'noxmere',
        x: 10,
        y: 12,
        label: 'Noxmere',
        category: 'settlement',
      );
      await worlds.createMapMarker(
        markerId: 'marker-far',
        mapId: 'map-north',
        recordId: 'ashfall',
        x: 500,
        y: 500,
        label: 'Far Field',
      );

      final markers = await worlds.markersForMap('map-north');
      expect(markers, hasLength(2));
      final inside =
          markers.firstWhere((marker) => marker.id == 'marker-nox');
      expect(inside.targetTitle, 'Noxmere');
      expect(inside.targetTypeId, 'city');
      expect(inside.category, 'settlement');
      expect(inside.withinBounds, isTrue);
      final outside =
          markers.firstWhere((marker) => marker.id == 'marker-far');
      expect(outside.withinBounds, isFalse);

      await worlds.updateMapMarker(
        'marker-far',
        x: 20,
        y: 20,
        label: 'Ash Field',
        notes: 'Moved onto the map.',
      );
      final moved = (await worlds.markersForMap('map-north'))
          .firstWhere((marker) => marker.id == 'marker-far');
      expect(moved.withinBounds, isTrue);
      expect(moved.displayLabel, 'Ash Field');
      expect(moved.notes, 'Moved onto the map.');

      await worlds.archiveWorldRecord('marker-far');
      expect(await worlds.markersForMap('map-north'), hasLength(1));
      expect(
        await worlds.markersForMap('map-north', includeArchived: true),
        hasLength(2),
      );
      // Archiving keeps the marker's links to the map and the record.
      expect(await worlds.connectionsFor('marker-far'), hasLength(2));
    });

    test('routes resolve endpoints and moving one rewires its links',
        () async {
      await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
      await worlds.createRoute(
        id: 'salt-road',
        title: 'Salt Road',
        startId: 'noxmere',
        endId: 'ashfall',
        metadata: const {'travelTime': '4 days'},
      );

      final fromCity = await worlds.routesFor('noxmere');
      expect(fromCity, hasLength(1));
      expect(fromCity.single.startTitle, 'Noxmere');
      expect(fromCity.single.endTitle, 'Ashfall');
      expect(fromCity.single.travelTime, '4 days');
      expect(fromCity.single.endpointsResolved, isTrue);

      await worlds.updateRoute(
        'salt-road',
        endId: 'greyquay',
        distance: '90 leagues',
      );
      final rerouted = (await worlds.routesFor('greyquay')).single;
      expect(rerouted.endId, 'greyquay');
      expect(rerouted.distance, '90 leagues');
      expect(await worlds.routesFor('ashfall'), isEmpty);

      final links = await worlds.connectionsFor('salt-road');
      final routeTo = links.where((link) => link.typeId == 'routeTo');
      expect(routeTo, hasLength(1));
      expect(routeTo.single.targetId, 'greyquay');

      await expectLater(
        worlds.updateRoute('salt-road', endId: 'noxmere'),
        throwsArgumentError,
      );
    });
  });

  group('canon, branches, archive, and safe delete', () {
    test('canon state changes are refused while a branch is active', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      const branchId = 'branch-ash';
      await worlds.branches.createBranch(StoryBranch(
        id: branchId,
        projectId: projectId,
        name: 'Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: timestamp,
      ));

      await expectLater(
        worlds.setCanonState('noxmere', 'Canon', activeBranchId: branchId),
        throwsStateError,
      );
      expect(
        worldCanonState((await worlds.getWorldRecord('noxmere'))!),
        'Draft',
      );

      await worlds.setCanonState('noxmere', 'Canon');
      final promoted = (await worlds.getWorldRecord('noxmere'))!;
      expect(worldCanonState(promoted), 'Canon');
      expect(promoted.canonStatus, CanonStatus.canon);
    });

    test('map, marker, and route edits are refused on a branch', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
      await worlds.createMap(
        id: 'map-north',
        title: 'Map of the North',
        mappedRecordId: 'noxmere',
      );
      await worlds.createMapMarker(
        markerId: 'marker-nox',
        mapId: 'map-north',
        recordId: 'noxmere',
        x: 1,
        y: 1,
      );
      await worlds.createRoute(
        id: 'salt-road',
        title: 'Salt Road',
        startId: 'noxmere',
        endId: 'ashfall',
      );

      await expectLater(
        worlds.updateMapMetadata(
          'map-north',
          const WorldMapMetadata(width: 10, height: 10),
          activeBranchId: 'branch-ash',
        ),
        throwsStateError,
      );
      await expectLater(
        worlds.updateMapMarker('marker-nox',
            x: 5, activeBranchId: 'branch-ash'),
        throwsStateError,
      );
      await expectLater(
        worlds.updateRoute('salt-road',
            distance: '1', activeBranchId: 'branch-ash'),
        throwsStateError,
      );
    });

    test('a branch edit overlays canon instead of replacing it', () async {
      await place(
        id: 'noxmere',
        title: 'Noxmere',
        fields: {'summary': 'Canon summary.'},
      );
      const branchId = 'branch-ash';
      await worlds.branches.createBranch(StoryBranch(
        id: branchId,
        projectId: projectId,
        name: 'Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: timestamp,
      ));

      await worlds.saveWorldRecord(
        'noxmere',
        title: 'Ashen Noxmere',
        fields: {'summary': 'Branch summary.'},
        activeBranchId: branchId,
      );

      final canonical = (await worlds.getWorldRecord('noxmere'))!;
      expect(canonical.title, 'Noxmere');
      expect(canonical.fields['summary'], 'Canon summary.');

      final branchRecord = (await worlds.branches.recordsForBranch(branchId))
          .firstWhere((record) => record.id == 'noxmere');
      expect(branchRecord.title, 'Ashen Noxmere');
      expect(branchRecord.fields['summary'], 'Branch summary.');

      await expectLater(
        worlds.saveWorldRecord(
          'noxmere',
          title: 'Ashen Noxmere',
          canonState: 'Canon',
          activeBranchId: branchId,
        ),
        throwsStateError,
      );
    });

    test('a branch hierarchy move leaves the canonical parent intact',
        () async {
      await seedHierarchy();
      await place(id: 'south', title: 'The South', typeId: 'region');
      const branchId = 'branch-ash';
      await worlds.branches.createBranch(StoryBranch(
        id: branchId,
        projectId: projectId,
        name: 'Ash Victory',
        kind: BranchKind.alternateTimeline,
        createdAt: timestamp,
      ));

      await worlds.setParent(
        childId: 'noxmere',
        parentId: 'south',
        branchId: branchId,
      );

      expect((await worlds.getParent('noxmere'))?.id, 'north');
      expect(
        (await worlds.getParent('noxmere', branchId: branchId))?.id,
        'south',
      );
    });

    test('archive and restore are reversible and keep the hierarchy',
        () async {
      await seedHierarchy();

      final analysis = await worlds.analyzeDelete('north');
      expect(analysis, isNotNull);
      expect(analysis!.disposition, SafeDeleteDisposition.blocked);
      expect(analysis.blockingReasons, isNotEmpty);
      expect(analysis.affectedRecords, isNotEmpty);

      await worlds.archiveWorldRecord('north');
      expect(
        (await worlds.getWorldRecord('north'))!.status,
        AuthorRecordStatus.archived,
      );
      expect((await worlds.getParent('noxmere'))?.id, 'north');

      await worlds.restoreWorldRecord('north');
      expect(
        (await worlds.getWorldRecord('north'))!.status,
        AuthorRecordStatus.active,
      );
      expect((await worlds.getChildren('north')).single.id, 'noxmere');
    });

    test('inspector and history read through the shared services', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await worlds.saveWorldRecord(
        'noxmere',
        title: 'Noxmere',
        fields: {'summary': 'Rewritten.'},
        timestamp: timestamp.add(const Duration(minutes: 1)),
      );

      final inspection = await worlds.inspectWorldRecord('noxmere');
      expect(inspection?.recordId, 'noxmere');
      expect(inspection?.recordType, 'city');

      final history = await worlds.getWorldHistory('noxmere');
      expect(history.length, greaterThanOrEqualTo(2));

      await worlds.records.restoreVersion(history.first.id);
      final restored = (await worlds.getWorldRecord('noxmere'))!;
      expect(restored.fields['summary'], isNull);
    });
  });

  group('validation', () {
    test('missing required values are reported per record', () async {
      await place(id: 'noxmere', title: 'Noxmere');
      final record = (await worlds.getWorldRecord('noxmere'))!;
      expect((await worlds.validateRecords([record]))['noxmere']!.isValid,
          isTrue);

      final broken = record.copyWith(title: '');
      final rechecked = await worlds.validateRecords([broken]);
      expect(rechecked['noxmere']!.isValid, isFalse);
      expect(
        rechecked['noxmere']!.errors.map((issue) => issue.code),
        contains('missing-title'),
      );
    });

    test('a route saved without endpoints fails template validation',
        () async {
      await place(id: 'noxmere', title: 'Noxmere');
      await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
      await worlds.createRoute(
        id: 'salt-road',
        title: 'Salt Road',
        startId: 'noxmere',
        endId: 'ashfall',
      );
      final route = (await worlds.getWorldRecord('salt-road'))!;
      final stripped = route.copyWith(
        fields: {...route.fields}..remove('endId'),
      );
      final results = await worlds.validateRecords([stripped]);
      expect(results['salt-road']!.isValid, isFalse);
      expect(
        results['salt-road']!.errors.map((issue) => issue.fieldId),
        contains('endId'),
      );
    });
  });
}
