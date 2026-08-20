import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/manuscript_workspace.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manuscript Studio Phase 2 workspace behaviour, driven through the widgets a
/// writer actually touches.
void main() {
  const projectId = 'studio-project';
  const project = StarterProject(
    id: projectId,
    title: 'The Blood Price',
    genre: 'Fantasy',
    projectType: 'Novel',
    wordGoal: 80000,
    acts: [],
    chapters: [
      StarterChapter(
        title: 'The Beginning',
        prompt: '',
        scenes: ['Arrival', 'Meeting'],
      ),
      StarterChapter(
        title: 'The Crossing',
        prompt: '',
        scenes: ['Departure'],
      ),
    ],
    characterSheets: [],
    beatChecklist: [],
    firstSceneTitle: 'Arrival',
  );

  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;
  late ManuscriptService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
    service = ManuscriptService(
      projectId: projectId,
      repository: repository,
      store: store,
    );
  });

  tearDown(() => database.close());

  Future<ManuscriptProjectSummary> loadManuscript() => service.load(
        manuscriptTitle: project.title,
        defaultChapters: const [
          ManuscriptChapterSeed(
            title: 'The Beginning',
            scenes: ['Arrival', 'Meeting'],
          ),
          ManuscriptChapterSeed(title: 'The Crossing', scenes: ['Departure']),
        ],
        firstSceneTitle: 'Arrival',
      );

  Future<void> pumpStudio(
    WidgetTester tester, {
    String? activeBranchId,
    List<ManuscriptNavigationRequest>? navigations,
  }) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManuscriptStudioView(
            project: project,
            startSprint: false,
            store: store,
            repository: repository,
            activeBranchId: activeBranchId,
            onNavigate: navigations == null ? null : navigations.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openConnectedPane(WidgetTester tester) async {
    final toggle = find.byKey(const Key('manuscript-details-mode'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    final segmented = tester.widget<SegmentedButton<bool>>(toggle);
    segmented.onSelectionChanged!({true});
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, ManuscriptPanelTab tab) async {
    await tester.tap(find.byKey(Key('manuscript-tab-${tab.name}')));
    await tester.pumpAndSettle();
  }

  testWidgets('the workspace shows word counts and writing progress',
      (tester) async {
    final manuscript = await loadManuscript();
    await service.writeSceneBody(
      manuscript,
      manuscript.chapters.first.scenes.first.id,
      'One two three four five six.',
    );

    await pumpStudio(tester);

    expect(find.byKey(const Key('manuscript-progress')), findsOneWidget);
    expect(
      find.byKey(const Key('manuscript-progress-words')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manuscript-progress-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected records are listed and open in their own Studio',
      (tester) async {
    final manuscript = await loadManuscript();
    final scene = manuscript.chapters.first.scenes.first;
    final kali =
        await CharacterService(projectId: projectId, repository: repository)
            .createCharacter(id: 'character-kali', displayName: 'Kali Vale');
    await service.connectNode(
      nodeId: scene.id,
      recordId: kali.id,
      typeId: 'appearsIn',
    );

    final navigations = <ManuscriptNavigationRequest>[];
    await pumpStudio(tester, navigations: navigations);
    await openConnectedPane(tester);

    expect(find.byKey(const Key('manuscript-connected-panel')), findsOneWidget);
    expect(find.text('Kali Vale'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manuscript-open-character-kali')));
    await tester.pumpAndSettle();

    expect(navigations, hasLength(1));
    expect(navigations.single.recordId, 'character-kali');
    expect(
      navigations.single.destination,
      SearchDestination.characterStudio,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a connection is added through the shared connection registry',
      (tester) async {
    final manuscript = await loadManuscript();
    await WorldService(projectId: projectId, repository: repository)
        .createWorldRecord(
      id: 'location-endovier',
      title: 'Endovier',
      typeId: 'location',
    );

    await pumpStudio(tester);
    await openConnectedPane(tester);

    await tester.tap(find.byKey(const Key('manuscript-add-connection')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('manuscript-candidate-location-endovier')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manuscript-connect-confirm')));
    await tester.pumpAndSettle();

    final sceneId = manuscript.chapters.first.scenes.first.id;
    final connections = await service.connectionsFor(sceneId);
    expect(connections.single.recordId, 'location-endovier');
    expect(tester.takeException(), isNull);
  });

  testWidgets('continuity recommendations are shown and resolvable',
      (tester) async {
    var manuscript = await loadManuscript();
    final scene = manuscript.chapters.first.scenes.first;
    await CharacterService(projectId: projectId, repository: repository)
        .createCharacter(id: 'character-kali', displayName: 'Kali Vale');
    manuscript = await service.writeSceneBody(
      manuscript,
      scene.id,
      'Kali Vale stepped onto the pier without looking back.',
    );

    await pumpStudio(tester);
    await openConnectedPane(tester);
    await openTab(tester, ManuscriptPanelTab.continuity);

    expect(
      find.byKey(const Key('manuscript-continuity-score')),
      findsOneWidget,
    );
    final resolve = find.byKey(
      const Key('manuscript-resolve-Unlinked mention of Kali Vale'),
    );
    expect(resolve, findsOneWidget);

    await tester.tap(resolve);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manuscript-confirm')));
    await tester.pumpAndSettle();

    final connections = await service.connectionsFor(scene.id);
    expect(connections.single.recordId, 'character-kali');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Inspector and History panes read the shared services',
      (tester) async {
    var manuscript = await loadManuscript();
    final scene = manuscript.chapters.first.scenes.first;
    manuscript = await service.renameScene(
      manuscript,
      scene.id,
      'Arrival at Endovier',
    );

    await pumpStudio(tester);
    await openConnectedPane(tester);

    await openTab(tester, ManuscriptPanelTab.inspector);
    expect(find.byKey(const Key('manuscript-inspector-list')), findsOneWidget);
    expect(find.text('Scene'), findsWidgets);

    await openTab(tester, ManuscriptPanelTab.history);
    expect(find.byKey(const Key('manuscript-history-list')), findsOneWidget);
    expect(find.textContaining('renamed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and filtering narrow the navigator to matching scenes',
      (tester) async {
    var manuscript = await loadManuscript();
    manuscript = await service.writeSceneBody(
      manuscript,
      manuscript.chapters.first.scenes.first.id,
      'The harbour smelled of salt and iron.',
    );

    await pumpStudio(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('manuscript-filter-query')),
      'salt and iron',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manuscript-filter-results')), findsOneWidget);
    expect(find.byKey(const Key('manuscript-filter-count')), findsOneWidget);
    expect(
      find.byKey(
        Key('manuscript-match-${manuscript.chapters.first.scenes.first.id}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a branch makes the manuscript read-only and blocks editing',
      (tester) async {
    await loadManuscript();
    await pumpStudio(tester, activeBranchId: 'branch-alt');

    expect(find.byKey(const Key('manuscript-branch-banner')), findsOneWidget);

    final newChapter = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'New Chapter'),
    );
    expect(newChapter.onPressed, isNull);

    final editor = tester.widget<TextField>(
      find.byKey(const Key('manuscript-draft-field')),
    );
    expect(editor.readOnly, isTrue);

    await openConnectedPane(tester);
    expect(find.byKey(const Key('manuscript-canon-banner')), findsOneWidget);
    final connect = tester.widget<TextButton>(
      find.byKey(const Key('manuscript-add-connection')),
    );
    expect(connect.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing while an autosave is in flight never loses keystrokes',
      (tester) async {
    final manuscript = await loadManuscript();
    final sceneId = manuscript.chapters.first.scenes.first.id;

    await pumpStudio(tester);

    await tester.enterText(
      find.byKey(const Key('manuscript-draft-field')),
      'The rain had been falling',
    );
    // Let the debounced autosave start, then keep writing before it lands.
    await tester.pump(const Duration(milliseconds: 750));
    await tester.enterText(
      find.byKey(const Key('manuscript-draft-field')),
      'The rain had been falling since dawn.',
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final reloaded = await service.load(manuscriptTitle: project.title);
    expect(
      reloaded.sceneById(sceneId)?.content,
      'The rain had been falling since dawn.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a connected scene warns about the impact first',
      (tester) async {
    final manuscript = await loadManuscript();
    final scene = manuscript.chapters.first.scenes.first;
    final kali =
        await CharacterService(projectId: projectId, repository: repository)
            .createCharacter(id: 'character-kali', displayName: 'Kali Vale');
    await service.connectNode(
      nodeId: scene.id,
      recordId: kali.id,
      typeId: 'appearsIn',
    );

    await pumpStudio(tester);

    final tile = find.ancestor(
      of: find.textContaining('Scene 01 - Arrival').first,
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scene-delete-${scene.id}')));
    await tester.pumpAndSettle();

    expect(find.textContaining('connected record'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await service.connectionsFor(scene.id), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
