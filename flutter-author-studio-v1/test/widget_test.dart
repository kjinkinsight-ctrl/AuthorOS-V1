import 'dart:convert';

import 'package:author_studio_v1/app_updater.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:author_studio_v1/timeline.dart';
import 'package:author_studio_v1/visual_planning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVersionClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({'version': '1.0.1+2'});
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('version checker flags a newer remote app version', () async {
    final checker = AppVersionChecker(
      latestVersionUrl: 'https://example.com/latest-version.json',
      httpClient: _FakeVersionClient(),
    );

    final result = await checker.checkForUpdate(currentVersion: '1.0.0+1');

    expect(result.updateAvailable, isTrue);
    expect(result.latestVersion, '1.0.1+2');
  });

  test('novel starter kit includes every onboarding deliverable', () {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    expect(project.acts, hasLength(3));
    expect(project.chapters, hasLength(3));
    expect(project.characterSheets, hasLength(3));
    expect(project.beatChecklist, hasLength(8));
    expect(project.firstSceneTitle, 'Opening Scene');
  });

  test('screenplay starter kit provides production-ready structure', () {
    final project = ScreenplayStarterKit.create(
      title: 'Signal Fire',
      genre: 'Thriller',
      wordGoal: 20000,
    );

    expect(project.projectType, 'Screenplay');
    expect(project.acts, hasLength(3));
    expect(project.chapters, hasLength(6));
    expect(project.chapters.first.title, contains('Sequence'));
    expect(project.characterSheets, hasLength(3));
    expect(project.beatChecklist, contains('Midpoint reversal'));
    expect(project.firstSceneTitle, startsWith('INT./EXT.'));
  });

  test('template library offers genre-specific starting structures', () {
    final romance = StoryTemplateLibrary.templateFor('Romance');
    final thriller = StoryTemplateLibrary.templateFor('Thriller');
    final mystery = StoryTemplateLibrary.templateFor('Mystery');

    expect(
        StoryTemplateLibrary.templates.map((template) => template.name),
        containsAll(
            ['Romance', 'Thriller', 'Fantasy', 'Mystery', 'Literary Fiction']));
    expect(romance, isNotNull);
    expect(romance!.beatChecklist, contains('Meet-cute'));
    expect(thriller!.sceneSuggestions, isNotEmpty);
    expect(mystery!.arcNames, contains('False Solution'));
  });

  test('genre templates generate scene scaffolding and tone-aware beats', () {
    final project = NovelStarterKit.create(
      title: 'Velvet Signal',
      genre: 'Thriller',
      projectType: 'Novel',
      wordGoal: 90000,
      templateName: 'Thriller',
    );

    expect(project.templateName, 'Thriller');
    expect(project.acts.first, contains('Setup'));
    expect(project.beatChecklist, contains('False lead'));
    expect(project.firstSceneTitle, contains('Signal'));
  });

  test('template-driven suggestions power the planning board and timeline seed',
      () {
    final project = NovelStarterKit.create(
      title: 'Velvet Signal',
      genre: 'Thriller',
      projectType: 'Novel',
      wordGoal: 90000,
      templateName: 'Thriller',
    );

    final scenes = const VisualPlanningStore().createStarterScenes(project);
    final timeline = const TimelineStore().createStarterState(project);

    expect(scenes[1].title, 'The False Lead');
    expect(scenes[1].arc, 'Pressure Arc');
    expect(timeline.events.first.plotline, 'Main Plot');
    expect(timeline.events.last.plotline, 'Pressure Arc');
  });

  test('onboarding store restores saved project state for post-login use',
      () async {
    const store = OnboardingStore();
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await store.saveProject(project);
    final restored = await store.loadProject();

    expect(restored, isNotNull);
    expect(restored!.id, project.id);
    expect(restored.title, project.title);
    expect(await SharedPreferences.getInstance(), isNotNull);
  });

  testWidgets('shell exposes focus mode and a collapsible app bar',
      (tester) async {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthorStudioShell(
        project: project,
        themeId: 'paper',
        accentId: 'default',
        onThemeChanged: (_, __) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-mode-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('focus-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.byType(SliverAppBar), findsOneWidget);
  });

  testWidgets(
      'focus mode includes a research side panel with notes and timeline tabs',
      (tester) async {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthorStudioShell(
        project: project,
        themeId: 'paper',
        accentId: 'default',
        onThemeChanged: (_, __) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Research'), findsWidgets);
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Pinned references'), findsOneWidget);
  });

  testWidgets(
      'settings exposes an in-app update action only when newer version exists',
      (tester) async {
    final versionChecker = AppVersionChecker(
      latestVersionUrl: 'https://example.com/latest-version.json',
      httpClient: _FakeVersionClient(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsStudioView(
          themeId: 'paper',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          versionChecker: versionChecker,
          currentVersion: '1.0.0+1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update available: 1.0.1+2'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets(
      'first launch shows the profile gate before the writing workspace',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AuthorStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('Login / Profile Selection'), findsOneWidget);
    expect(find.text('Create new profile'), findsOneWidget);
    expect(find.text('Reset app state'), findsOneWidget);
    expect(find.text('Continue with selected profile'), findsNothing);
    expect(find.text('Start your writing workspace'), findsNothing);
  });

  testWidgets('previous saved state never bypasses the login screen on startup',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'author_studio.profile_setup_complete': true,
      'author_studio.profile.name': 'Old Name',
      'author_studio.profile.email': 'old@example.com',
      'author_studio.starter_project': '{"title":"Old Project"}',
      'author_studio.onboarding_complete': true,
    });

    await tester.pumpWidget(const AuthorStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('Continue with selected profile'), findsOneWidget);
    expect(find.text('Old Name'), findsOneWidget);
    expect(find.text('Create new profile'), findsOneWidget);
    expect(find.text('Start your writing workspace'), findsNothing);
  });

  testWidgets('first run opens the first scene with an optional sprint',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AuthorStudioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create new profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Northstar',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email-field')),
      'writer@example.com',
    );
    await tester.tap(find.text('Continue to workspace setup'));
    await tester.pumpAndSettle();

    expect(find.text('Start your writing workspace'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('project-title-field')),
      'Northstar',
    );
    await tester.enterText(find.byKey(const Key('word-goal-field')), '90000');

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Three-act structure'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Start a 15-minute writing sprint'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Open first scene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Northstar'), findsWidgets);
    expect(find.text('Opening Scene'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('story codex entry keeps aliases, references, and relationship metadata',
      () {
    const entry = StoryCodexEntry(
      id: 'char-1',
      title: 'Mara Voss',
      type: StoryCodexType.character,
      aliases: ['Mara', 'The River Witch'],
      summary: 'A cartographer with a dangerous memory.',
      tags: ['protagonist', 'magic'],
      relationships: {'mentor': 'Edrin Vale', 'rival': 'Joss Quill'},
      mentions: ['scene-1', 'scene-7', 'chapter-3'],
    );

    final json = entry.toJson();
    final restored = StoryCodexEntry.fromJson(json);

    expect(entry.aliases, contains('The River Witch'));
    expect(restored.relationships['mentor'], 'Edrin Vale');
    expect(restored.mentions, contains('scene-7'));
    expect(restored.type, StoryCodexType.character);
  });

  test('archived codex entries hide relationship links until restored', () {
    const active = StoryCodexEntry(
      id: 'char-1',
      title: 'Mara Voss',
      type: StoryCodexType.character,
      relationships: {'mentor': 'Edrin Vale'},
    );
    const archived = StoryCodexEntry(
      id: 'char-2',
      title: 'Edrin Vale',
      type: StoryCodexType.character,
      status: 'Archived',
    );

    expect(active.visibleRelationships([active, archived]), isEmpty);

    final restored = archived.copyWith(status: 'Active');
    expect(
      active.visibleRelationships([active, restored]),
      {'mentor': 'Edrin Vale'},
    );
  });

  test('project world memory keeps entries isolated per project', () async {
    SharedPreferences.setMockInitialValues({});

    const projectStore = StoryCodexStore(projectId: 'northstar');
    await projectStore.save([
      const StoryCodexEntry(
        id: 'char-1',
        title: 'Mara Voss',
        type: StoryCodexType.character,
        summary: 'A cartographer with a fractured memory.',
      ),
      const StoryCodexEntry(
        id: 'loc-1',
        title: 'Ashfall Harbor',
        type: StoryCodexType.place,
        summary: 'A storm-worn port city.',
      ),
    ]);

    final loaded = await projectStore.load();
    final otherProject =
        await const StoryCodexStore(projectId: 'other-project').load();

    expect(loaded, hasLength(2));
    expect(otherProject, isEmpty);
  });

  test('project research panel stores pinned references per project', () async {
    SharedPreferences.setMockInitialValues({});

    const store = ProjectResearchStore(projectId: 'northstar');
    await store.save({
      ResearchTab.research: const [
        ResearchReference(
          title: 'Bridge district lore',
          detail: 'Lanterns and rain on slate roads.',
          tag: 'World',
        ),
      ],
      ResearchTab.notes: const [
        ResearchReference(
          title: 'Mara timeline',
          detail: 'She returns to the river before every lie.',
          tag: 'Character',
        ),
      ],
    });

    final loaded = await store.load();
    final otherProject =
        await const ProjectResearchStore(projectId: 'other').load();

    expect(loaded[ResearchTab.research]!, hasLength(1));
    expect(otherProject, isEmpty);
  });

  test('codex aliases and world entries feed continuity checks automatically',
      () {
    final codex = [
      const StoryCodexEntry(
        id: 'char-1',
        title: 'Mara Voss',
        type: StoryCodexType.character,
        aliases: ['Mara', 'The River Witch'],
        summary: 'A cartographer with a dangerous memory.',
      ),
      const StoryCodexEntry(
        id: 'loc-1',
        title: 'Ashfall Harbor',
        type: StoryCodexType.place,
        aliases: ['Harbor', 'The Ash Reaches'],
        summary: 'Stormy port city at the river mouth.',
      ),
    ];

    final warnings = const ContinuityAnalyzer().analyze(
      [
        const ContinuityEventSnapshot(
          id: 'event-1',
          title: 'The harbor market',
          startDay: 5,
          endDay: 6,
          order: 1,
          pov: 'Mara',
          plotline: 'Main Plot',
          presentCharacters: ['Mara'],
          location: 'Harbor',
          travelDaysFromPrevious: 0,
        ),
      ],
      knownCharacters: StoryCodexReferenceIndex.characterNames(codex),
      knownLocations: StoryCodexReferenceIndex.locationNames(codex),
    );

    expect(
      warnings.any(
          (warning) => warning.type == ContinuityWarningType.unknownCharacter),
      isFalse,
    );
    expect(
      warnings.any(
          (warning) => warning.type == ContinuityWarningType.unknownLocation),
      isFalse,
    );
  });

  testWidgets('story codex view renders searchable world and character records',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StoryCodexView(
            projectId: 'northstar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Story Codex'), findsOneWidget);
    expect(find.text('Search world and character knowledge'), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
  });

  testWidgets('screenplay selection previews and opens the screenplay kit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AuthorStudioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create new profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Signal Fire',
    );
    await tester.tap(find.text('Continue to workspace setup'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('project-title-field')),
      'Signal Fire',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Screenplay'));
    await tester.pumpAndSettle();

    expect(find.text('Six sequence placeholders'), findsOneWidget);
    expect(find.text('Ten screenplay beats'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your screenplay will open in Sequence 1 at the first scene heading.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'onboarding teaches the continuity-first workflow before opening the project',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AuthorStudioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create new profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Northstar',
    );
    await tester.tap(find.text('Continue to workspace setup'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('project-title-field')),
      'Northstar',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Continuity-first workflow'), findsOneWidget);
    expect(find.text('Build the cast'), findsOneWidget);
    expect(find.text('Map the timeline'), findsOneWidget);
    expect(find.text('Run continuity checks'), findsOneWidget);
  });

  testWidgets('chapter studio supports creating and editing chapter plans',
      (tester) async {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(MaterialApp(
      home: ChapterStudioView(project: project),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chapter 1 - The Opening'), findsWidgets);
    expect(find.text('Add Chapter'), findsOneWidget);

    await tester.tap(find.text('Add Chapter'));
    await tester.pumpAndSettle();

    expect(find.text('New chapter'), findsWidgets);

    await tester.enterText(
        find.byKey(const Key('chapter-title-field')), 'Chapter 4');
    await tester.enterText(
      find.byKey(const Key('chapter-prompt-field')),
      'The final cost of the choice.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter 4'), findsWidgets);
    expect(find.text('The final cost of the choice.'), findsWidgets);
  });

  testWidgets('chapter studio persists archive, scene, and link metadata',
      (tester) async {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(MaterialApp(
      home: ChapterStudioView(project: project),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Chapter'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chapter-title-field')),
      'Chapter 4',
    );
    await tester.enterText(
      find.byKey(const Key('chapter-prompt-field')),
      'The final cost of the choice.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('author_studio.chapters.${project.id}');

    expect(raw, isNotEmpty);
    final lastEntry = jsonDecode(raw!.last) as Map<String, dynamic>;
    expect(lastEntry['status'], 'Active');
    expect(lastEntry['scenes'], isA<List>());
    expect(lastEntry['linkedChapterIds'], isA<List>());
  });

  testWidgets('character board renders cast cards with archive-aware status',
      (tester) async {
    final project = NovelStarterKit.create(
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );

    await tester.pumpWidget(MaterialApp(
      home: CharacterBoardView(project: project),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cast'), findsWidgets);
    expect(find.text('Protagonist'), findsWidgets);
    expect(find.text('Primary Opposition'), findsWidgets);
    expect(find.text('Key Ally'), findsWidgets);
  });
}
