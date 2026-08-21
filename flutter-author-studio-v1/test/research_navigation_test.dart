import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigation through the real AuthorOS shell, not the Studio in isolation.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService researchService;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDisableAuroraAnimation = true;
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    researchService = ResearchService(
      projectId: 'northstar-research',
      repository: repository,
    );
    manuscriptStore = ManuscriptStore(repository: repository);
  });

  tearDown(() {
    database.close();
    debugDisableAuroraAnimation = false;
  });

  StarterProject project() => NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );

  ResolvedTheme resolved() {
    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    return engine.resolveSelection(
      selection: const ThemeSelection(
        themeId: 'light',
        mode: AuthorOsThemeMode.light,
      ),
      hostBrightness: ThemeBrightness.light,
    );
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required StarterProject starterProject,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1500, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final theme = resolved();
    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: AuthorStudioShell(
            project: starterProject,
            manuscriptStore: manuscriptStore,
            researchService: researchService,
            themeId: 'light',
            accentId: 'default',
            onThemeChanged: (_, __) {},
            initialSection: StudioSection.dashboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the shell lists Research beside the other story Studios',
      (tester) async {
    await pumpShell(tester, starterProject: project());

    expect(StudioSection.research.label, 'Research');
    expect(StudioSection.research.icon, Icons.travel_explore_outlined);
    expect(find.text('Research'), findsOneWidget);
  });

  testWidgets('Dashboard -> Research Studio -> Dashboard', (tester) async {
    final starterProject = project();
    final service = ResearchService(
      projectId: starterProject.id,
      repository: repository,
    );
    await service.createResearch(
      const ResearchDraft(
        id: 'research-tide',
        title: 'Tidal lock records',
        summary: 'Harbour tide tables for the siege chapters.',
      ),
    );
    researchService = service;

    await pumpShell(tester, starterProject: starterProject);

    // Dashboard is the starting section.
    expect(find.byKey(const Key('dashboard-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('research-studio')), findsNothing);

    // Forward: the Dashboard tile opens Research Studio.
    final tile = find.byKey(const ValueKey('dashboard-tile-Research Studio'));
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('research-studio')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-hero')), findsNothing);
    // The Studio is service-backed inside the shell, not an empty shell view.
    expect(
      find.byKey(const ValueKey('research-item-tile-research-tide')),
      findsOneWidget,
    );

    // Return: the Dashboard navigation entry comes back.
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('research-studio')), findsNothing);
  });

  testWidgets('the Research navigation entry opens the Studio too',
      (tester) async {
    final starterProject = project();
    researchService = ResearchService(
      projectId: starterProject.id,
      repository: repository,
    );

    await pumpShell(tester, starterProject: starterProject);

    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('research-studio')), findsOneWidget);
    expect(find.text('Research Studio'), findsWidgets);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-hero')), findsOneWidget);
  });

  testWidgets('research created in the shell is read back from the database',
      (tester) async {
    final starterProject = project();
    researchService = ResearchService(
      projectId: starterProject.id,
      repository: repository,
    );

    await pumpShell(tester, starterProject: starterProject);
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('research-new-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('research-editor-title')),
      'Lighthouse rotation',
    );
    await tester.tap(find.byKey(const ValueKey('research-editor-save')));
    await tester.pumpAndSettle();

    // A fresh service over the same repository sees the record.
    final reader = ResearchService(
      projectId: starterProject.id,
      repository: repository,
    );
    final stored = await reader.listResearch();
    expect(stored, hasLength(1));
    expect(stored.single.title, 'Lighthouse rotation');
    expect(stored.single.record.typeId, ResearchRecordTypes.entryTypeId);
    expect(stored.single.canonStatus, CodexCanonStatus.draft);
  });
}
