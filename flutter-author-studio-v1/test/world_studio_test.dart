import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/world_studio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late WorldStudioService studio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    studio = WorldStudioService(
      scopeId: 'project-endovier',
      repository: DriftConnectedDomainRepository(database),
      templates: WorldTemplateRegistry(),
    );
  });

  tearDown(() => database.close());

  test('official templates include deep systems and inherited locations', () {
    final registry = WorldTemplateRegistry();
    final city = registry.resolve('city');

    expect(
      registry.templates.map((template) => template.id),
      containsAll(<String>[
        'world',
        'location',
        'faction',
        'culture',
        'religion',
        'language',
        'magicSystem',
        'magicRule',
        'technology',
        'species',
        'creature',
        'historicalEvent',
        'item',
      ]),
    );
    expect(city.fields.map((field) => field.key), contains('location.climate'));
    expect(city.suggestedRelationships, contains('locatedIn'));
  });

  test('custom templates inherit fields without duplicating the parent schema',
      () {
    final registry = WorldTemplateRegistry(customTemplates: const [
      WorldRecordTemplate(
        id: 'capital',
        label: 'Capital',
        category: 'Geography',
        icon: 'location_city',
        parentId: 'city',
        fields: [
          WorldFieldDefinition(
            key: 'capital.seatOfPower',
            label: 'Seat of power',
            section: 'Politics',
          ),
        ],
      ),
    ]);

    final capital = registry.resolve('capital');
    expect(
        capital.fields.map((field) => field.key), contains('location.climate'));
    expect(capital.fields.map((field) => field.key),
        contains('capital.seatOfPower'));
  });

  test('canonical world records persist hierarchy and reverse connections',
      () async {
    final timestamp = DateTime.utc(2026, 8, 18);
    await studio.save(
      const WorldRecordDraft(
        id: 'world-endovier',
        title: 'Endovier',
        templateId: 'world',
        fields: {'identity.description': 'A realm divided by old houses.'},
      ),
      timestamp: timestamp,
    );
    await studio.save(
      const WorldRecordDraft(
        id: 'city-noxmere',
        title: 'Noxmere',
        templateId: 'city',
        fields: {'location.climate': 'Cold coastal fog'},
        tags: ['book1', 'politics'],
      ),
      links: [
        studio.link(
          sourceId: 'city-noxmere',
          targetId: 'world-endovier',
          typeId: 'locatedIn',
          label: 'Located in',
          timestamp: timestamp,
        ),
      ],
      timestamp: timestamp,
    );
    await studio.save(
      const WorldRecordDraft(
        id: 'faction-house-noxmere',
        title: 'House Noxmere',
        templateId: 'faction',
        fields: {'organisation.purpose': 'Guard the northern passage.'},
      ),
      links: [
        studio.link(
          sourceId: 'faction-house-noxmere',
          targetId: 'city-noxmere',
          typeId: 'controls',
          label: 'Controls',
          timestamp: timestamp,
        ),
      ],
      timestamp: timestamp,
    );

    final records = await studio.loadRecords();
    final city = await studio.recordById('city-noxmere');
    final cityConnections = await studio.connections('city-noxmere');

    expect(records, hasLength(3));
    expect(city?.fields[WorldStudioService.templateField], 'city');
    expect(city?.fields['location.climate'], 'Cold coastal fog');
    expect(cityConnections.map((link) => link.typeId),
        containsAll(<String>['locatedIn', 'controls']));
    expect(
      await studio.repository.searchEntityIds('coastal'),
      ['city-noxmere'],
    );
  });

  testWidgets('dashboard creates a canonical record from a template',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorldStudioView(
            projectId: 'project-endovier',
            repository: studio.repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-world-record-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-record-title-field')),
      'Endovier',
    );
    await tester.tap(find.byKey(const Key('save-world-record-button')));
    await tester.pumpAndSettle();

    expect(find.text('Endovier'), findsOneWidget);
    final stored = await studio.loadRecords();
    expect(stored, hasLength(1));
    expect(stored.single.typeId, 'world');
    expect(stored.single.fields[WorldStudioService.templateField], 'world');
  });

  test('World Studio and Story Codex edit one canonical faction record',
      () async {
    final codex = StoryCodexService(
      projectId: 'project-endovier',
      repository: studio.repository,
    );
    final created = await codex.createCodexEntry(const CodexEntryDraft(
      id: 'house-noxmere',
      title: 'House Noxmere',
      templateId: 'faction',
      categoryId: 'factions',
      summary: 'An old northern house.',
      canonStatus: CodexCanonStatus.canon,
    ));

    final worldRecord = (await studio.loadRecords()).single;
    expect(worldRecord.id, created.id);
    expect(worldRecord.typeId, 'faction');

    await studio.save(WorldRecordDraft(
      id: worldRecord.id,
      title: 'House Noxmere Revised',
      templateId: 'faction',
      fields: {
        ...worldRecord.fields,
        'organisation.purpose': 'Guard the northern passage.',
      },
      canonStatus: WorldCanonStatus.canon,
    ));

    final fromCodex = await codex.getCodexEntry(created.id);
    expect(fromCodex?.title, 'House Noxmere Revised');
    expect(
      fromCodex?.structuredFields['organisation.purpose'],
      'Guard the northern passage.',
    );
    expect((await studio.loadRecords()).single.id, created.id);
  });

  testWidgets('workspace shows one canonical record in World and Codex views',
      (tester) async {
    await studio.save(const WorldRecordDraft(
      id: 'endovier',
      title: 'Endovier',
      templateId: 'world',
      canonStatus: WorldCanonStatus.canon,
    ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorldStudioWorkspace(
            projectId: 'project-endovier',
            repository: studio.repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('World Studio'), findsOneWidget);
    expect(find.text('Endovier'), findsOneWidget);
    await tester.tap(find.text('Codex reference'));
    await tester.pumpAndSettle();

    expect(find.text('Story Codex'), findsOneWidget);
    expect(find.text('Endovier'), findsWidgets);
  });
}
