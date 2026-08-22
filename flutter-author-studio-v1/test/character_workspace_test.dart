import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/character_studio.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/character_record_types.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late CharacterService characters;
  const project = StarterProject(
    id: 'workspace-project',
    title: 'Northstar',
    genre: 'Fantasy',
    projectType: 'Novel',
    wordGoal: 90000,
    acts: [],
    chapters: [],
    characterSheets: [],
    beatChecklist: [],
    firstSceneTitle: 'Opening',
  );
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    characters = CharacterService(
      projectId: project.id,
      repository: repository,
    );
  });

  tearDown(() => database.close());

  Future<void> pumpWorkspace(
    WidgetTester tester, {
    ValueChanged<CharacterNavigationRequest>? onNavigate,
    String? branchId,
    String? branchName,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterBoardView(
          project: project,
          repository: repository,
          onNavigate: onNavigate,
          branchId: branchId,
          branchName: branchName,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectSection(WidgetTester tester, String sectionId) async {
    final section = find.byKey(Key('character-section-$sectionId'));
    final rail = find.descendant(
      of: find.byKey(const Key('character-section-navigation')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      section,
      180,
      scrollable: rail,
    );
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    await tester.tap(section);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'workspace renders Basic, Main, Antagonist, POV, and custom templates',
      (tester) async {
    final custom = CharacterRecordTypes.customTemplate(
      id: 'workspace-detective',
      name: 'Detective',
      projectId: project.id,
      fields: const [
        RecordFieldDefinition(
          id: 'case.currentLead',
          label: 'Current lead',
          type: RecordFieldType.longText,
          order: 1500,
        ),
      ],
      sections: const [
        RecordTemplateSection(
          id: 'case',
          title: 'Case Work',
          order: 1500,
          fieldIds: ['case.currentLead'],
        ),
      ],
    );
    await characters.registerCustomTemplate(custom);
    for (final entry in const [
      ('a-basic', 'A Basic', 'character-basic'),
      ('b-main', 'B Main', 'character-main'),
      ('c-antagonist', 'C Antagonist', 'character-antagonist'),
      ('d-pov', 'D POV', 'character-pov'),
      ('e-custom', 'E Detective', 'workspace-detective'),
    ]) {
      await characters.createCharacter(
        id: entry.$1,
        displayName: entry.$2,
        templateId: entry.$3,
        fields: entry.$3 == 'workspace-detective'
            ? const {'case.currentLead': 'The flooded gate'}
            : const {},
        timestamp: timestamp,
      );
    }

    await pumpWorkspace(tester);

    expect(find.text('Character Studio'), findsOneWidget);
    expect(find.byKey(const Key('character-completion-indicator')),
        findsOneWidget);
    expect(find.text('Identity'), findsWidgets);
    expect(find.text('Psychology'), findsNothing);

    await tester.tap(find.text('B Main').first);
    await tester.pumpAndSettle();
    expect(find.text('Psychology'), findsWidgets);
    final mainPresentation = await characters
        .presentationFor((await characters.getCharacter('b-main'))!);
    expect(mainPresentation.sections.map((section) => section.id),
        containsAll(['psychology', 'relationships', 'arcs']));

    await tester.tap(find.text('C Antagonist').first);
    await tester.pumpAndSettle();
    final antagonistPresentation = await characters.presentationFor(
      (await characters.getCharacter('c-antagonist'))!,
    );
    expect(antagonistPresentation.sections.map((section) => section.id),
        contains('arcs'));

    await tester.tap(find.text('D POV').first);
    await tester.pumpAndSettle();
    final povPresentation = await characters
        .presentationFor((await characters.getCharacter('d-pov'))!);
    expect(
        povPresentation.sections.map((section) => section.id), contains('pov'));

    await tester.tap(find.text('E Detective').first);
    await tester.pumpAndSettle();
    await selectSection(tester, 'case');
    expect(find.byKey(const Key('character-field-case.currentLead')),
        findsOneWidget);
  });

  testWidgets('dynamic field edits autosave and show validation and save state',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await pumpWorkspace(tester);

    expect(find.text('Saved'), findsOneWidget);
    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();
    final eyeField =
        find.byKey(const Key('character-field-appearance.eyeColour'));
    expect(eyeField, findsOneWidget);
    await tester.enterText(eyeField, 'Grey');
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(
        (await characters.getCharacter('kali'))?.fields['appearance.eyeColour'],
        'Grey');
    expect(find.byKey(const Key('character-validation-indicator')),
        findsOneWidget);
  });

  testWidgets('goals workspace adds structured items and autosaves',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await pumpWorkspace(tester);
    await selectSection(tester, 'goals');

    await tester.tap(find.byKey(const Key('add-goals.entries')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('structured-character-item-title')),
      'Expose the Widow Network',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final record = await characters.getCharacter('kali');
    expect(record?.fields['goals.entries'], isA<List>());
    expect(
      (record?.fields['goals.entries'] as List).single['goal'],
      'Expose the Widow Network',
    );
  });

  testWidgets('smaller browser widths use compact section navigation',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await tester.binding.setSurfaceSize(const Size(820, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterBoardView(
          project: project,
          repository: repository,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('character-section-navigation')),
      findsOneWidget,
    );
    expect(find.text('Section'), findsOneWidget);
  });

  testWidgets('relationship workspace uses search and shared connections',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'A Kali',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await characters.createCharacter(
      id: 'cassian',
      displayName: 'Z Cassian',
      templateId: 'character-supporting',
      timestamp: timestamp,
    );
    await pumpWorkspace(tester);

    await selectSection(tester, 'relationships');
    expect(find.textContaining('No relationships'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-relationship-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('relationship-target-search')),
      'Cassian',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z Cassian').last);
    await tester.tap(find.byKey(const Key('save-relationship-button')));
    await tester.pumpAndSettle();

    final links = await characters.getCharacterRelationships('kali');
    expect(links, hasLength(1));
    expect(links.single.typeId, 'friendOf');
    expect(find.text('Z Cassian'), findsWidgets);

    await tester.tap(find.byKey(Key('relationship-link-${links.single.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Status'), 'Trusted');
    await tester.tap(find.byKey(const Key('save-relationship-button')));
    await tester.pumpAndSettle();
    expect(
      (await characters.getCharacterRelationships('kali'))
          .single
          .metadata['status'],
      'Trusted',
    );
  });

  testWidgets('Inspector and History actions open shared service views',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await pumpWorkspace(tester);

    await tester.tap(find.byTooltip('Character actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('character-action-inspector')));
    await tester.pumpAndSettle();
    expect(find.text('Inspector: Kali Vale'), findsOneWidget);
    expect(find.text('VALID'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Character actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('character-action-history')));
    await tester.pumpAndSettle();
    expect(find.text('History: Kali Vale'), findsOneWidget);
    expect(find.textContaining('created'), findsWidgets);
  });

  testWidgets('connected manuscript record navigates through host callback',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      timestamp: timestamp,
    );
    await characters.records.createRecord(AuthorRecord(
      id: 'scene-opening',
      typeId: 'scene',
      scopeType: RecordScopeType.project,
      scopeId: project.id,
      projectId: project.id,
      title: 'Opening Scene',
      createdAt: timestamp,
      updatedAt: timestamp,
    ));
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'scene-opening',
      typeId: 'appearsIn',
      timestamp: timestamp,
    );
    CharacterNavigationRequest? request;
    await pumpWorkspace(tester, onNavigate: (value) => request = value);

    await selectSection(tester, 'manuscript');
    await tester.tap(find.text('Opening Scene'));

    expect(request?.destination, CharacterWorkspaceDestination.manuscript);
    // The id is what makes the connection followable. Character Studio used to
    // emit the destination alone, so this click opened Manuscript Studio on
    // whatever happened to be selected there rather than on this scene.
    expect(request?.recordId, 'scene-opening');
  });

  testWidgets('branch editing creates override and preserves Canon',
      (tester) async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      canonStatus: CanonStatus.canon,
      timestamp: timestamp,
    );
    await characters.branches.createBranch(StoryBranch(
      id: 'what-if',
      projectId: project.id,
      name: 'What If',
      createdAt: timestamp,
    ));
    await pumpWorkspace(
      tester,
      branchId: 'what-if',
      branchName: 'What If',
    );

    expect(
        find.byKey(const Key('character-branch-edit-notice')), findsOneWidget);
    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('character-field-appearance.eyeColour')),
      'Silver',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final canonical = await characters.getCharacter('kali');
    final branch =
        await characters.inspectCharacter('kali', branchId: 'what-if');
    expect(canonical?.fields['appearance.eyeColour'], isNull);
    expect(branch?.scope.branchState, BranchRecordState.overridden);
  });
}
