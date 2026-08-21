import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:author_studio_v1/world_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const projectId = 'project-world';
final timestamp = DateTime.utc(2026, 8, 20, 10);

void main() {
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
  }) =>
      worlds.createWorldRecord(
        id: id,
        title: title,
        typeId: typeId,
        fields: fields,
        canonState: canonState,
        timestamp: timestamp,
      );

  Future<void> seedHierarchy() async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await place(id: 'north', title: 'The North', typeId: 'region');
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Smugglers move salt beneath the cliffs.'},
    );
    await worlds.setParent(childId: 'north', parentId: 'aethel');
    await worlds.setParent(childId: 'noxmere', parentId: 'north');
  }

  testWidgets('the empty world explains itself and creates a first record',
      (tester) async {
    await _pump(tester, repository);

    expect(find.byKey(const Key('world-workspace')), findsOneWidget);
    expect(find.byKey(const Key('world-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('world-detail-empty-state')), findsOneWidget);

    await _tap(tester, const Key('world-new-record-button'));
    expect(find.byKey(const Key('world-create-dialog')), findsOneWidget);
    _choose<String>(
        tester, const Key('world-create-template-field'), 'continent');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-create-title-field')),
      'Aethel',
    );
    await tester.enterText(
      find.byKey(const Key('world-create-summary-field')),
      'The first continent.',
    );
    await _tap(tester, const Key('world-create-confirm'));

    final records = await worlds.worldRecords();
    expect(records, hasLength(1));
    final created = records.single;
    expect(created.title, 'Aethel');
    expect(created.typeId, 'continent');
    expect(created.fields['summary'], 'The first continent.');
    expect(created.fields['primaryName'], 'Aethel');
    expect(created.extensionData['worldStudio'], isTrue);

    expect(find.byKey(const Key('world-empty-state')), findsNothing);
    expect(find.byKey(Key('world-tree-node-${created.id}')), findsOneWidget);
    expect(find.byKey(const Key('world-record-pane')), findsOneWidget);
    expect(find.byKey(const Key('world-canon-chip')), findsOneWidget);
  });

  testWidgets('a blank name is refused before anything is written',
      (tester) async {
    await _pump(tester, repository);
    await _tap(tester, const Key('world-new-record-button'));
    await _tap(tester, const Key('world-create-confirm'));

    expect(find.byKey(const Key('world-create-error')), findsOneWidget);
    expect(find.byKey(const Key('world-create-dialog')), findsOneWidget);
    expect(await worlds.worldRecords(), isEmpty);
  });

  testWidgets('a new record can be nested under an existing place',
      (tester) async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await _pump(tester, repository);

    await _tap(tester, const Key('world-new-record-button'));
    _choose<String>(tester, const Key('world-create-template-field'), 'region');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-create-title-field')),
      'The North',
    );
    _choose<String>(tester, const Key('world-create-parent-field'), 'aethel');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-create-confirm'));

    final children = await worlds.getChildren('aethel');
    expect(children.map((record) => record.title), ['The North']);
    final tree = await worlds.hierarchyTree();
    expect(tree.single.children.single.record.title, 'The North');
  });

  testWidgets('the hierarchy tree browses, collapses, and selects',
      (tester) async {
    await seedHierarchy();
    await _pump(tester, repository);

    expect(find.byKey(const Key('world-tree-node-aethel')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-north')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsOneWidget);

    await _tap(tester, const Key('world-tree-toggle-north'));
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsNothing);
    await _tap(tester, const Key('world-tree-toggle-north'));
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsOneWidget);

    await _tap(tester, const Key('world-tree-select-noxmere'));
    expect(find.byKey(const Key('world-record-pane')), findsOneWidget);
    expect(find.text('Noxmere'), findsWidgets);
  });

  testWidgets('search narrows the tree and keeps the path to the match',
      (tester) async {
    await seedHierarchy();
    await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('world-search-field')),
      'smugglers',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world-tree-node-noxmere')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-aethel')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-greyquay')), findsNothing);

    await _tap(tester, const Key('world-clear-filters-button'));
    expect(find.byKey(const Key('world-tree-node-greyquay')), findsOneWidget);

    await _tap(tester, const Key('world-canon-filter-canon'));
    expect(find.byKey(const Key('world-no-results-state')), findsOneWidget);
    expect(find.byKey(const Key('world-empty-state')), findsNothing);
  });

  testWidgets('the group facet switches between places, maps and routes',
      (tester) async {
    await seedHierarchy();
    await worlds.createMap(
      id: 'map-north',
      title: 'Map of the North',
      mappedRecordId: 'north',
    );
    await worlds.createRoute(
      id: 'salt-road',
      title: 'Salt Road',
      startId: 'noxmere',
      endId: 'north',
    );
    await _pump(tester, repository);

    await _tap(tester, const Key('world-group-filter-maps'));
    expect(find.byKey(const Key('world-record-tile-map-north')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsNothing);

    await _tap(tester, const Key('world-group-filter-routes'));
    expect(find.byKey(const Key('world-record-tile-salt-road')), findsOneWidget);

    await _tap(tester, const Key('world-group-filter-spatial'));
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsOneWidget);
  });

  testWidgets('overview edits save and preserve unknown fields',
      (tester) async {
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'legacyNote': 'written by an older release'},
    );
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));

    expect(find.text('No pending changes'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('world-summary-input')),
      'A cold harbour beneath the northern cliffs.',
    );
    await tester.enterText(
      find.byKey(const Key('world-aliases-input')),
      'The Salt Gate, Noxmere Harbour',
    );
    await tester.enterText(
      find.byKey(const Key('world-tags-input')),
      'capital, coastal',
    );
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await _tap(tester, const Key('world-save-record-button'));

    final saved = (await worlds.getWorldRecord('noxmere'))!;
    expect(saved.fields['summary'], 'A cold harbour beneath the northern cliffs.');
    expect(saved.fields['aliases'], ['The Salt Gate', 'Noxmere Harbour']);
    expect(saved.tags, ['capital', 'coastal']);
    expect(saved.fields['legacyNote'], 'written by an older release');
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets('an empty name is reported and never reaches the record',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));

    await tester.enterText(find.byKey(const Key('world-title-input')), '   ');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-save-record-button'));

    expect(find.byKey(const Key('world-save-error')), findsOneWidget);
    expect(find.byKey(const Key('world-validation-panel')), findsOneWidget);
    expect((await worlds.getWorldRecord('noxmere'))!.title, 'Noxmere');

    await _tap(tester, const Key('world-discard-button'));
    expect(find.byKey(const Key('world-save-error')), findsNothing);
  });

  testWidgets('deep mode edits template fields and keeps unknown fields',
      (tester) async {
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'legacyNote': 'written by an older release'},
    );
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-fields'));

    // Long-form fields stay out of the way in simple mode.
    expect(find.byKey(const Key('world-field-geography')), findsNothing);

    _select<WorldEditorMode>(
      tester,
      const Key('world-editor-mode-selector'),
      {WorldEditorMode.deep},
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world-field-geography')), findsOneWidget);
    expect(find.byKey(const Key('world-field-legacyNote')), findsOneWidget);
    expect(find.byKey(const Key('world-section-additional')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('world-field-geography')),
      'Black cliffs enclose a deep-water bay.',
    );
    await tester.enterText(
      find.byKey(const Key('world-field-alternateNames')),
      'Grey Quay, Salt Reach',
    );
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-save-record-button'));

    final saved = (await worlds.getWorldRecord('noxmere'))!;
    expect(saved.fields['geography'], 'Black cliffs enclose a deep-water bay.');
    expect(saved.fields['alternateNames'], ['Grey Quay', 'Salt Reach']);
    expect(saved.fields['legacyNote'], 'written by an older release');
  });

  testWidgets('a custom field is added and saved alongside template fields',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-fields'));
    _select<WorldEditorMode>(
      tester,
      const Key('world-editor-mode-selector'),
      {WorldEditorMode.deep},
    );
    await tester.pumpAndSettle();

    await _tap(tester, const Key('world-add-custom-field-button'));
    await tester.enterText(
      find.byKey(const Key('world-custom-field-label')),
      'Harbour depth',
    );
    await _tap(tester, const Key('world-custom-field-confirm'));

    expect(find.byKey(const Key('world-field-harbour_depth')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('world-field-harbour_depth')),
      '30 fathoms',
    );
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-save-record-button'));

    final saved = (await worlds.getWorldRecord('noxmere'))!;
    expect(saved.fields['harbour_depth'], '30 fathoms');
    expect(
      WorldService.customFieldLabels(saved)['harbour_depth'],
      'Harbour depth',
    );
  });

  testWidgets('the hierarchy tab moves, detaches and opens children',
      (tester) async {
    await seedHierarchy();
    await place(id: 'south', title: 'The South', typeId: 'region');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-hierarchy'));

    expect(find.byKey(const Key('world-breadcrumb')), findsOneWidget);
    expect(find.byKey(const Key('world-breadcrumb-aethel')), findsOneWidget);
    expect(find.byKey(const Key('world-breadcrumb-north')), findsOneWidget);
    expect(
      find.byKey(const Key('world-hierarchy-empty-state')),
      findsOneWidget,
    );

    await _tap(tester, const Key('world-set-parent-button'));
    _choose<String>(tester, const Key('world-parent-field'), 'south');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-parent-confirm'));
    expect((await worlds.getParent('noxmere'))?.id, 'south');

    await _tap(tester, const Key('world-tab-hierarchy'));
    await _tap(tester, const Key('world-clear-parent-button'));
    await _tap(tester, const Key('world-confirm-button'));
    expect(await worlds.getParent('noxmere'), isNull);
    expect(await worlds.getWorldRecord('south'), isNotNull);

    await _tap(tester, const Key('world-tree-select-north'));
    await _tap(tester, const Key('world-tab-hierarchy'));
    expect(find.byKey(const Key('world-hierarchy-empty-state')), findsOneWidget);
  });

  testWidgets('connections group by studio, navigate, retype and unlink',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await _putCharacter(repository, 'character-kalis', 'Kalis Ardent');

    final navigations = <WorldNavigationRequest>[];
    await _pump(tester, repository, navigations: navigations);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-connections'));
    expect(
      find.byKey(const Key('world-connections-empty-state')),
      findsOneWidget,
    );

    await _tap(tester, const Key('world-add-connection-button'));
    _choose<String>(
      tester,
      const Key('world-connection-target-field'),
      'character-kalis',
    );
    await tester.pumpAndSettle();
    _choose<String>(
        tester, const Key('world-connection-type-field'), 'partOf');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-connection-confirm'));

    var links = await worlds.connectionsFor('noxmere');
    expect(links, hasLength(1));
    final linkId = links.single.id;
    expect(find.byKey(Key('world-connection-$linkId')), findsOneWidget);
    expect(
      find.byKey(const Key('world-connection-group-characters')),
      findsOneWidget,
    );

    await _tap(tester, Key('world-open-connection-$linkId'));
    expect(navigations, hasLength(1));
    expect(navigations.single.recordId, 'character-kalis');
    expect(navigations.single.destination, SearchDestination.characterStudio);

    await _tap(tester, const Key('world-tab-connections'));
    await _tap(tester, Key('world-edit-connection-$linkId'));
    _choose<String>(
      tester,
      const Key('world-connection-edit-type-field'),
      'contains',
    );
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-connection-type-confirm'));
    links = await worlds.connectionsFor('noxmere');
    expect(links.single.typeId, 'contains');

    await _tap(tester, const Key('world-tab-connections'));
    await _tap(tester, Key('world-remove-connection-${links.single.id}'));
    await _tap(tester, const Key('world-confirm-button'));
    expect(await worlds.connectionsFor('noxmere'), isEmpty);
    expect(await repository.recordById('character-kalis'), isNotNull);
  });

  testWidgets('maps are created from a place and their metadata is edited',
      (tester) async {
    await place(id: 'north', title: 'The North', typeId: 'region');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-north'));
    await _tap(tester, const Key('world-tab-maps'));
    expect(find.byKey(const Key('world-maps-empty-state')), findsOneWidget);

    await _tap(tester, const Key('world-add-map-button'));
    await tester.enterText(
      find.byKey(const Key('world-map-name-field')),
      'Map of the North',
    );
    await _tap(tester, const Key('world-map-name-confirm'));

    final maps = await worlds.mapsFor('north');
    expect(maps, hasLength(1));
    final mapId = maps.single.id;
    await _tap(tester, const Key('world-tab-maps'));
    expect(find.byKey(Key('world-map-$mapId')), findsOneWidget);

    await _tap(tester, const Key('world-group-filter-maps'));
    await _tap(tester, Key('world-record-tile-$mapId'));
    await _tap(tester, const Key('world-tab-maps'));
    expect(find.byKey(const Key('world-map-metadata-panel')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('world-map-width-field')),
      '100',
    );
    await tester.enterText(
      find.byKey(const Key('world-map-height-field')),
      '80',
    );
    await tester.enterText(
      find.byKey(const Key('world-map-scale-field')),
      '1cm = 10 leagues',
    );
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-save-map-metadata-button'));

    final metadata =
        WorldMapMetadata.fromRecord((await worlds.getWorldRecord(mapId))!);
    expect(metadata.width, 100);
    expect(metadata.height, 80);
    expect(metadata.scale, '1cm = 10 leagues');
  });

  testWidgets('markers are placed, flagged out of bounds, edited and archived',
      (tester) async {
    await place(id: 'north', title: 'The North', typeId: 'region');
    await place(id: 'noxmere', title: 'Noxmere');
    await worlds.createMap(
      id: 'map-north',
      title: 'Map of the North',
      mappedRecordId: 'north',
      metadata: const {'width': 100, 'height': 80},
    );
    await _pump(tester, repository);
    await _tap(tester, const Key('world-group-filter-maps'));
    await _tap(tester, const Key('world-record-tile-map-north'));
    await _tap(tester, const Key('world-tab-markers'));
    expect(find.byKey(const Key('world-markers-empty-state')), findsOneWidget);

    await _tap(tester, const Key('world-add-marker-button'));
    _choose<String>(tester, const Key('world-marker-target-field'), 'noxmere');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-marker-label-field')),
      'Noxmere',
    );
    await tester.enterText(find.byKey(const Key('world-marker-x-field')), '500');
    await tester.enterText(find.byKey(const Key('world-marker-y-field')), '500');
    await _tap(tester, const Key('world-marker-confirm'));

    var markers = await worlds.markersForMap('map-north');
    expect(markers, hasLength(1));
    final markerId = markers.single.id;
    expect(markers.single.targetId, 'noxmere');
    expect(markers.single.withinBounds, isFalse);
    await _tap(tester, const Key('world-tab-markers'));
    expect(
      find.byKey(Key('world-marker-out-of-bounds-$markerId')),
      findsOneWidget,
    );

    await _tap(tester, Key('world-edit-marker-$markerId'));
    await tester.enterText(find.byKey(const Key('world-marker-x-field')), '20');
    await tester.enterText(find.byKey(const Key('world-marker-y-field')), '20');
    await _tap(tester, const Key('world-marker-confirm'));

    markers = await worlds.markersForMap('map-north');
    expect(markers.single.withinBounds, isTrue);
    expect(markers.single.x, 20);

    await _tap(tester, const Key('world-tab-markers'));
    await _tap(tester, Key('world-remove-marker-$markerId'));
    await _tap(tester, const Key('world-confirm-button'));
    expect(await worlds.markersForMap('map-north'), isEmpty);
    // Archived, not deleted: its links survive.
    expect(await worlds.connectionsFor(markerId), hasLength(2));
  });

  testWidgets('routes are drawn between two places and re-routed',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
    await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-routes'));
    expect(find.byKey(const Key('world-routes-empty-state')), findsOneWidget);

    await _tap(tester, const Key('world-add-route-button'));
    await tester.enterText(
      find.byKey(const Key('world-route-title-field')),
      'Salt Road',
    );
    _choose<String>(tester, const Key('world-route-start-field'), 'noxmere');
    await tester.pumpAndSettle();
    _choose<String>(tester, const Key('world-route-end-field'), 'greyquay');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-route-time-field')),
      '4 days',
    );
    await _tap(tester, const Key('world-route-confirm'));

    var routes = await worlds.routesFor('noxmere');
    expect(routes, hasLength(1));
    final routeId = routes.single.id;
    expect(routes.single.startId, 'noxmere');
    expect(routes.single.endId, 'greyquay');
    expect(routes.single.travelTime, '4 days');

    await _tap(tester, const Key('world-tab-routes'));
    expect(find.byKey(Key('world-route-$routeId')), findsOneWidget);
    await _tap(tester, Key('world-edit-route-$routeId'));
    _choose<String>(tester, const Key('world-route-end-field'), 'ashfall');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-route-confirm'));

    routes = await worlds.routesFor('noxmere');
    expect(routes.single.endId, 'ashfall');
    final links = await worlds.connectionsFor(routeId);
    expect(
      links.where((link) => link.typeId == 'routeTo').single.targetId,
      'ashfall',
    );
  });

  testWidgets('a route dialog refuses identical endpoints', (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-routes'));
    await _tap(tester, const Key('world-add-route-button'));
    await tester.enterText(
      find.byKey(const Key('world-route-title-field')),
      'Loop',
    );
    _choose<String>(tester, const Key('world-route-end-field'), 'noxmere');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-route-confirm'));

    expect(find.byKey(const Key('world-route-error')), findsOneWidget);
    expect(await worlds.routesFor('noxmere'), isEmpty);
  });

  testWidgets('inspector and history read and restore through the services',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    await worlds.saveWorldRecord(
      'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Second revision.'},
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));

    await _tap(tester, const Key('world-tab-inspector'));
    expect(find.byKey(const Key('world-inspector-panel')), findsOneWidget);
    expect(find.text('city'), findsWidgets);

    await _tap(tester, const Key('world-tab-history'));
    expect(find.byKey(const Key('world-history-panel')), findsOneWidget);
    final versions = await worlds.getWorldHistory('noxmere');
    expect(versions.length, greaterThanOrEqualTo(2));
    expect(
      find.byKey(Key('world-history-${versions.first.id}')),
      findsOneWidget,
    );

    await _tap(tester, Key('world-restore-version-${versions.first.id}'));
    await _tap(tester, const Key('world-confirm-button'));
    expect((await worlds.getWorldRecord('noxmere'))!.fields['summary'], isNull);
  });

  testWidgets('archiving asks first, shows safe delete, and restores',
      (tester) async {
    await seedHierarchy();
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-north'));

    await _tap(tester, const Key('world-record-actions'));
    await _tapText(tester, 'Archive record');
    expect(find.byKey(const Key('world-archive-dialog')), findsOneWidget);
    expect(find.byKey(const Key('world-safe-delete-summary')), findsOneWidget);
    await _tap(tester, const Key('world-archive-confirm'));

    expect(
      (await worlds.getWorldRecord('north'))!.status,
      AuthorRecordStatus.archived,
    );
    expect(find.byKey(const Key('world-tree-node-north')), findsNothing);
    expect(find.byKey(const Key('world-archived-chip')), findsOneWidget);

    await _tap(tester, const Key('world-include-archived-toggle'));
    expect(find.byKey(const Key('world-tree-node-north')), findsOneWidget);

    await _tap(tester, const Key('world-record-actions'));
    await _tapText(tester, 'Restore record');
    expect(
      (await worlds.getWorldRecord('north'))!.status,
      AuthorRecordStatus.active,
    );
    expect((await worlds.getChildren('north')).single.id, 'noxmere');
  });

  testWidgets('the safe delete analysis is available on demand',
      (tester) async {
    await seedHierarchy();
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-north'));

    await _tap(tester, const Key('world-record-actions'));
    await _tapText(tester, 'Safe delete analysis');
    expect(find.byKey(const Key('world-safe-delete-dialog')), findsOneWidget);
    expect(find.textContaining('Disposition:'), findsOneWidget);
  });

  testWidgets('canon state is editable on canon and locked on a branch',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    const branchId = 'branch-ash';
    await worlds.branches.createBranch(StoryBranch(
      id: branchId,
      projectId: projectId,
      name: 'Ash Victory',
      kind: BranchKind.alternateTimeline,
      createdAt: timestamp,
    ));
    await _pump(tester, repository);

    await _tap(tester, const Key('world-tree-select-noxmere'));
    _choose<String>(tester, const Key('world-canon-state-field'), 'Canon');
    await tester.pumpAndSettle();
    expect(
      worldCanonState((await worlds.getWorldRecord('noxmere'))!),
      'Canon',
    );

    expect(find.byKey(const Key('world-branch-banner')), findsNothing);
    _choose<String>(tester, const Key('world-branch-selector'), branchId);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-branch-banner')), findsOneWidget);

    await _tap(tester, const Key('world-tree-select-noxmere'));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('world-canon-state-field')),
          )
          .onChanged,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('world-summary-input')),
      'Branch summary.',
    );
    await tester.pumpAndSettle();
    await _tap(tester, const Key('world-save-record-button'));

    expect(
      (await worlds.getWorldRecord('noxmere'))!.fields['summary'],
      isNull,
    );
    final branchRecord = (await worlds.branches.recordsForBranch(branchId))
        .firstWhere((record) => record.id == 'noxmere');
    expect(branchRecord.fields['summary'], 'Branch summary.');
  });

  testWidgets('validation problems are flagged in the tree and the pane',
      (tester) async {
    await place(id: 'noxmere', title: 'Noxmere');
    final record = (await worlds.getWorldRecord('noxmere'))!;
    await repository.putRecord(record.copyWith(
      fields: {...record.fields, 'population': 'not-a-number'},
      revision: record.revision + 1,
    ));
    await _pump(tester, repository);

    expect(
      find.byKey(const Key('world-validation-badge-noxmere')),
      findsOneWidget,
    );
    await _tap(tester, const Key('world-tree-select-noxmere'));
    expect(find.byKey(const Key('world-validation-panel')), findsOneWidget);

    await _tap(tester, const Key('world-needs-attention-toggle'));
    expect(find.byKey(const Key('world-tree-node-noxmere')), findsOneWidget);
  });

  testWidgets('continuity recommendations are shown and resolvable',
      (tester) async {
    await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Caravans leave Noxmere for Ashfall each week.'},
    );
    await _pump(tester, repository);
    await _tap(tester, const Key('world-tree-select-noxmere'));
    await _tap(tester, const Key('world-tab-continuity'));

    expect(find.byKey(const Key('world-continuity-panel')), findsOneWidget);
    expect(find.byKey(const Key('world-continuity-issue-0')), findsOneWidget);

    await _tap(tester, const Key('world-continuity-resolve-0'));
    expect(find.byKey(const Key('world-confirm-dialog')), findsOneWidget);
    await _tap(tester, const Key('world-confirm-button'));

    final links = await worlds.connectionsFor('noxmere');
    expect(links, hasLength(1));
    expect(links.single.typeId, 'relatedTo');

    await _tap(tester, const Key('world-tab-continuity'));
    expect(
      find.byKey(const Key('world-continuity-clean-state')),
      findsOneWidget,
    );
  });

  testWidgets('the workspace lays out on a narrow browser window',
      (tester) async {
    await seedHierarchy();
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: WorldWorkspace(
            projectId: projectId,
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world-workspace')), findsOneWidget);
    expect(find.byKey(const Key('world-search-field')), findsOneWidget);
    expect(find.byKey(const Key('world-tree-node-aethel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  DriftConnectedDomainRepository repository, {
  List<WorldNavigationRequest>? navigations,
}) async {
  tester.view.physicalSize = const Size(1700, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: WorldWorkspace(
          projectId: projectId,
          repository: repository,
          onNavigate: navigations?.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Drives a dropdown without depending on menu overlays.
void _choose<T>(WidgetTester tester, Key key, T value) {
  final field = tester.widget<DropdownButtonFormField<T>>(find.byKey(key));
  field.onChanged?.call(value);
}

/// Drives a segmented button without hit-testing its segments.
void _select<T>(WidgetTester tester, Key key, Set<T> values) {
  final button = tester.widget<SegmentedButton<T>>(find.byKey(key));
  button.onSelectionChanged?.call(values);
}

Future<void> _putCharacter(
  DriftConnectedDomainRepository repository,
  String id,
  String title,
) =>
    repository.putRecord(AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: title,
      templateId: 'character',
      fields: {'identity.fullName': title},
      createdAt: timestamp,
      updatedAt: timestamp,
    ));
