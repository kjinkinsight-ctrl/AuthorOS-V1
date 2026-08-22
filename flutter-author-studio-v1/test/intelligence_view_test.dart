/// Widget tests for the Intelligence Studio.
///
/// The view performs no analysis of its own, so these test what it is
/// responsible for: the three load states, grouping findings by condition, the
/// clean state, and handing a destination back to the shell.
library;

import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/intelligence/intelligence_models.dart';
import 'package:author_studio_v1/intelligence/intelligence_sections.dart';
import 'package:author_studio_v1/intelligence/intelligence_view.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 3, 1);

ResolvedTheme _theme() {
  final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
  return engine.resolveSelection(
    selection: const ThemeSelection(
      themeId: 'light',
      mode: AuthorOsThemeMode.light,
      accessibility: ThemeAccessibility.none,
    ),
    hostBrightness: ThemeBrightness.light,
  );
}

StarterProject _project(String id) => StarterProject(
      id: id,
      title: 'House of Shadows and Saints',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: const ['Act I'],
      chapters: const [
        StarterChapter(title: 'Chapter 1', prompt: 'Begin', scenes: ['Opening']),
      ],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
  });

  tearDown(() => database.close());

  Future<void> saveManuscript(
    StarterProject project,
    List<ManuscriptChapter> chapters,
  ) =>
      manuscriptStore.saveStudio(
        ManuscriptProjectSummary(
          projectId: project.id,
          manuscriptTitle: project.title,
          chapters: chapters,
          currentChapterId: chapters.isEmpty ? '' : chapters.first.id,
          currentSceneId: chapters.isEmpty || chapters.first.scenes.isEmpty
              ? ''
              : chapters.first.scenes.first.id,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: 2,
        ),
        persistLegacyText: false,
      );

  Future<void> seedChapterWithScene(StarterProject project) => saveManuscript(
        project,
        [
          ManuscriptChapter(
            id: 'ch-1',
            title: 'The Drowned Gate',
            order: 0,
            status: ManuscriptNodeStatus.draft,
            createdAt: timestamp,
            updatedAt: timestamp,
            scenes: [
              ManuscriptScene(
                id: 'sc-1',
                chapterId: 'ch-1',
                title: 'Arrival',
                order: 0,
                content: 'The harbour lay under fog.',
                status: ManuscriptNodeStatus.draft,
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            ],
          ),
        ],
      );

  Future<void> pumpStudio(
    WidgetTester tester, {
    required StarterProject project,
    ValueChanged<IntelligenceDestination>? onNavigate,
    Size size = const Size(1400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioThemeScope(
            theme: _theme(),
            studio: StudioId.shell,
            child: SingleChildScrollView(
              child: IntelligenceStudioView(
                project: project,
                repository: repository,
                manuscriptStore: manuscriptStore,
                onNavigate: onNavigate,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner before the report arrives', (tester) async {
    final project = _project('view-loading');
    await seedChapterWithScene(project);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioThemeScope(
            theme: _theme(),
            studio: StudioId.shell,
            child: IntelligenceStudioView(
              project: project,
              repository: repository,
              manuscriptStore: manuscriptStore,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('intelligence-loading')), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('renders the studio once the report arrives', (tester) async {
    final project = _project('view-loaded');
    await seedChapterWithScene(project);

    await pumpStudio(tester, project: project);

    expect(find.byKey(const ValueKey('intelligence-studio')), findsOneWidget);
    expect(find.byKey(const ValueKey('intelligence-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('intelligence-coverage')), findsOneWidget);
  });

  testWidgets('shows the clean state when nothing is wrong', (tester) async {
    final project = _project('view-clean');
    await seedChapterWithScene(project);

    await pumpStudio(tester, project: project);

    expect(find.byKey(const ValueKey('intelligence-clean')), findsOneWidget);
  });

  testWidgets('groups findings under their condition', (tester) async {
    final project = _project('view-findings');
    await seedChapterWithScene(project);
    await CharacterService(projectId: project.id, repository: repository)
        .createCharacter(id: 'char-1', displayName: 'Mara Voss');
    await WorldService(projectId: project.id, repository: repository)
        .createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');

    await pumpStudio(tester, project: project);

    expect(
      find.byKey(const ValueKey('intelligence-condition-orphanEntity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('intelligence-condition-unusedWorldbuilding')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('intelligence-clean')), findsNothing);
    expect(find.textContaining('Mara Voss'), findsWidgets);
  });

  testWidgets('hands a destination back to the shell', (tester) async {
    final project = _project('view-navigate');
    await seedChapterWithScene(project);
    await CharacterService(projectId: project.id, repository: repository)
        .createCharacter(id: 'char-1', displayName: 'Mara Voss');

    final opened = <IntelligenceDestination>[];
    await pumpStudio(tester, project: project, onNavigate: opened.add);

    await tester.tap(find.text('Open Studio').first);
    await tester.pumpAndSettle();

    expect(opened, [IntelligenceDestination.characters]);
  });

  testWidgets('the refresh control re-runs the analysis', (tester) async {
    final project = _project('view-refresh');
    await seedChapterWithScene(project);

    await pumpStudio(tester, project: project);
    expect(find.byKey(const ValueKey('intelligence-clean')), findsOneWidget);

    // A character created after the first load only appears on a refresh.
    await CharacterService(projectId: project.id, repository: repository)
        .createCharacter(id: 'char-1', displayName: 'Mara Voss');

    await tester.tap(find.byKey(const ValueKey('intelligence-refresh')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('intelligence-condition-orphanEntity')),
      findsOneWidget,
    );
  });

  group('world board tile', () {
    Future<void> pumpTile(
      WidgetTester tester,
      IntelligenceReport report, {
      VoidCallback? onOpen,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioThemeScope(
              theme: _theme(),
              studio: StudioId.worldBoard,
              child: IntelligenceHealthTile(report: report, onOpen: onOpen),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('reads all clear when there is nothing to report',
        (tester) async {
      await pumpTile(tester, IntelligenceReport.empty);

      expect(find.text('All clear'), findsOneWidget);
    });

    testWidgets('shows the finding count and opens the studio',
        (tester) async {
      var opened = 0;
      await pumpTile(
        tester,
        const IntelligenceReport(
          projectId: 'p1',
          projectTitle: 'House of Shadows and Saints',
          findings: [
            StructuralFinding(
              condition: StructuralCondition.orphanEntity,
              severity: ContinuitySeverity.warning,
              title: 'Mara Voss never appears in the manuscript',
              detail: '',
              recommendation: '',
              entityIds: ['char-1'],
            ),
          ],
          connectedWorldEntities: 0,
          totalWorldEntities: 3,
          hasManuscript: true,
        ),
        onOpen: () => opened += 1,
      );

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intelligence-health-tile')));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });
}
