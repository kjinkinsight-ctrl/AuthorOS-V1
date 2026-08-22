import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:author_studio_v1/world_board/world_board_models.dart';
import 'package:author_studio_v1/world_board/world_board_sections.dart';
import 'package:author_studio_v1/world_board/world_board_view.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ResolvedTheme _theme({
  String themeId = 'light',
  AuthorOsThemeMode mode = AuthorOsThemeMode.light,
  ThemeBrightness hostBrightness = ThemeBrightness.light,
  ThemeAccessibility accessibility = ThemeAccessibility.none,
}) {
  final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
  return engine.resolveSelection(
    selection: ThemeSelection(
      themeId: themeId,
      mode: mode,
      accessibility: accessibility,
    ),
    hostBrightness: hostBrightness,
  );
}

StarterProject _project(String id, {int wordGoal = 80000}) => StarterProject(
      id: id,
      title: 'House of Shadows and Saints',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
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

  Future<void> pumpBoard(
    WidgetTester tester, {
    required StarterProject project,
    ResolvedTheme? theme,
    ValueChanged<WorldBoardDestination>? onNavigate,
    DateTime? now,
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
            theme: theme ?? _theme(),
            studio: StudioId.shell,
            child: SingleChildScrollView(
              child: WorldBoardView(
                project: project,
                repository: repository,
                manuscriptStore: manuscriptStore,
                onNavigate: onNavigate,
                now: now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('renders the command centre over real project data',
        (tester) async {
      final project = _project('wb-view-populated');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');
      await TimelineService(projectId: project.id, repository: repository)
          .createEvent(const TimelineEventDraft(id: 'tl-1', name: 'Battle of Dawn'));
      await PlotService(projectId: project.id, repository: repository)
          .createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'story',
        name: 'The Glass Crown',
        fields: {'plotStatus': 'active'},
      ));
      await WorldService(projectId: project.id, repository: repository)
          .createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');

      await pumpBoard(tester, project: project);

      expect(find.byKey(const ValueKey('world-board')), findsOneWidget);
      expect(find.text('My AuthorOS World'), findsOneWidget);
      expect(
        find.text('Your entire creative ecosystem in one place.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('world-board-project-title')),
          findsOneWidget);
      expect(find.text('House of Shadows and Saints'), findsWidgets);

      // Every ecosystem tile is present, and the populated ones show counts.
      for (final section in WorldBoardSection.values) {
        expect(find.byKey(ValueKey('world-board-metric-${section.name}')),
            findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('world-board-value-characters')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('world-board-value-characters')))
            .data,
        '2',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('world-board-value-plot')))
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('world-board-value-worlds')))
            .data,
        '1',
      );
    });

    testWidgets('the relationship map shows the project and its branches',
        (tester) async {
      final project = _project('wb-view-map');
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      await pumpBoard(tester, project: project);

      expect(find.byKey(const ValueKey('world-board-relationship-map')),
          findsOneWidget);
      expect(find.text('HOW YOUR WORLD CONNECTS'), findsOneWidget);
      // A real record title appears as a leaf on the character branch.
      expect(find.text('Mara Voss'), findsWidgets);
      expect(
        find.byKey(const ValueKey('world-board-branch-count-characters')),
        findsOneWidget,
      );
    });

    testWidgets('draft progress reads against the project word goal',
        (tester) async {
      final project = _project('wb-view-progress');
      // The manuscript is created explicitly. Rendering the board used to seed
      // one as a side effect, so this test passed without ever saying a
      // manuscript should exist. Opening a dashboard no longer creates one
      // (R-21), and progress against a word goal is only meaningful once there
      // is a draft to measure.
      await manuscriptStore.loadStudio(
        project.id,
        manuscriptTitle: project.title,
        defaultChapters: const [],
        firstSceneTitle: project.firstSceneTitle,
      );

      await pumpBoard(tester, project: project);

      expect(find.byKey(const ValueKey('world-board-progress')), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('world-board-progress')),
      );
      expect(bar.value, isNotNull);
      expect(bar.value, inInclusiveRange(0.0, 1.0));
      expect(find.textContaining('words remaining'), findsOneWidget);
    });

    testWidgets('recent activity lists real audit entries', (tester) async {
      final project = _project('wb-view-activity');
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      await pumpBoard(tester, project: project, now: DateTime.now().toUtc());

      expect(find.byKey(const ValueKey('world-board-activity')), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.textContaining('Mara Voss'), findsWidgets);
      expect(find.byKey(const ValueKey('world-board-activity-empty')),
          findsNothing);
    });

    testWidgets('the grid reflows to one column on a narrow viewport',
        (tester) async {
      // The shell shows every Studio at phone width too, so the board has to
      // compose inside a scroll view without demanding a height.
      final project = _project('wb-view-narrow');
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      await pumpBoard(
        tester,
        project: project,
        size: const Size(420, 3600),
      );

      expect(tester.takeException(), isNull);
      for (final section in WorldBoardSection.values) {
        expect(find.byKey(ValueKey('world-board-metric-${section.name}')),
            findsOneWidget);
      }
      expect(find.byKey(const ValueKey('world-board-project-panel')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('world-board-activity')), findsOneWidget);
    });

    testWidgets('refreshing picks up work done in another Studio',
        (tester) async {
      final project = _project('wb-view-refresh');
      final characters =
          CharacterService(projectId: project.id, repository: repository);

      await pumpBoard(tester, project: project);
      expect(find.byKey(const ValueKey('world-board-empty-characters')),
          findsOneWidget);

      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await tester.tap(find.byKey(const ValueKey('world-board-refresh')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('world-board-value-characters')),
          findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('a brand new world shows an empty state for every category',
        (tester) async {
      final project = _project('wb-view-empty');

      await pumpBoard(tester, project: project);

      for (final section in const [
        WorldBoardSection.characters,
        WorldBoardSection.worlds,
        WorldBoardSection.timelines,
        WorldBoardSection.plot,
      ]) {
        expect(
          find.byKey(ValueKey('world-board-empty-${section.name}')),
          findsOneWidget,
          reason: '${section.name} must show its empty headline',
        );
      }

      expect(find.text('No characters yet'), findsWidgets);
      expect(find.text('Build your cast in Characters Studio.'), findsWidgets);
      expect(find.text('No world yet'), findsWidgets);
      expect(
        find.text('Your world-building workspace will live here.'),
        findsWidgets,
      );
      expect(find.text('No timeline yet'), findsWidgets);
      expect(find.text('Start organising your story chronology.'), findsWidgets);
      expect(find.text('No plot records yet'), findsWidgets);
      expect(
        find.text('Build your story structure in Plot Studio.'),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('world-board-activity-empty')),
          findsOneWidget);
    });

    testWidgets('an empty branch offers a way into the owning Studio',
        (tester) async {
      final project = _project('wb-view-empty-branch');
      WorldBoardDestination? requested;

      await pumpBoard(
        tester,
        project: project,
        onNavigate: (destination) => requested = destination,
      );

      final action =
          find.byKey(const ValueKey('world-board-branch-open-characters'));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(requested, WorldBoardDestination.characters);
    });
  });

  group('navigation', () {
    testWidgets('each populated tile opens its Studio', (tester) async {
      final project = _project('wb-view-nav');
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');
      final requested = <WorldBoardDestination>[];

      await pumpBoard(
        tester,
        project: project,
        onNavigate: requested.add,
      );

      for (final section in WorldBoardSection.values) {
        final tile = find.byKey(ValueKey('world-board-metric-${section.name}'));
        await tester.ensureVisible(tile);
        await tester.tap(tile, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(requested, [
        WorldBoardDestination.projects,
        WorldBoardDestination.manuscript,
        WorldBoardDestination.characters,
        WorldBoardDestination.world,
        WorldBoardDestination.timeline,
        WorldBoardDestination.plot,
      ]);
    });

    testWidgets('a board with no navigation handler stays inert',
        (tester) async {
      final project = _project('wb-view-inert');

      await pumpBoard(tester, project: project);

      final tile =
          find.byKey(const ValueKey('world-board-metric-characters'));
      await tester.ensureVisible(tile);
      await tester.tap(tile, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('world-board')), findsOneWidget);
    });
  });

  group('theme', () {
    /// Reads the colour the board actually painted on its header.
    Color headerColour(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('world-board-header')),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('light mode paints light tokens', (tester) async {
      final theme = _theme();
      await pumpBoard(tester, project: _project('wb-theme-light'), theme: theme);

      expect(theme.brightness, ThemeBrightness.light);
      expect(
        headerColour(tester),
        AuthorOsTheme.color(
          theme.colorFor(StudioId.worldBoard, ThemeColorRef.surfaceContainer),
        ),
      );
    });

    testWidgets('dark mode paints dark tokens', (tester) async {
      final theme = _theme(
        themeId: 'dark',
        mode: AuthorOsThemeMode.dark,
        hostBrightness: ThemeBrightness.dark,
      );
      await pumpBoard(tester, project: _project('wb-theme-dark'), theme: theme);

      expect(theme.brightness, ThemeBrightness.dark);
      expect(
        headerColour(tester),
        AuthorOsTheme.color(
          theme.colorFor(StudioId.worldBoard, ThemeColorRef.surfaceContainer),
        ),
      );
    });

    testWidgets('system mode follows the host brightness', (tester) async {
      final theme = _theme(
        themeId: 'dark',
        mode: AuthorOsThemeMode.system,
        hostBrightness: ThemeBrightness.dark,
      );
      await pumpBoard(
        tester,
        project: _project('wb-theme-system'),
        theme: theme,
      );

      expect(theme.requestedMode, AuthorOsThemeMode.system);
      expect(theme.brightness, ThemeBrightness.dark);
      expect(
        headerColour(tester),
        AuthorOsTheme.color(
          theme.colorFor(StudioId.worldBoard, ThemeColorRef.surfaceContainer),
        ),
      );
    });

    testWidgets('high contrast reaches the board through the engine',
        (tester) async {
      final plain = _theme();
      final contrast = _theme(
        accessibility: const ThemeAccessibility(highContrast: true),
      );
      await pumpBoard(
        tester,
        project: _project('wb-theme-contrast'),
        theme: contrast,
      );

      expect(contrast.accessibility.highContrast, isTrue);
      expect(
        headerColour(tester),
        AuthorOsTheme.color(
          contrast.colorFor(StudioId.worldBoard, ThemeColorRef.surfaceContainer),
        ),
      );
      // The transformation is the engine's, and the board renders its result.
      expect(
        contrast.color(ThemeColorRef.onSurface),
        isNot(plain.color(ThemeColorRef.onSurface)),
      );
    });

    testWidgets('reduced intensity reaches the board through the engine',
        (tester) async {
      final plain = _theme();
      final reduced = _theme(
        accessibility: const ThemeAccessibility(reduceIntensity: true),
      );
      await pumpBoard(
        tester,
        project: _project('wb-theme-reduced'),
        theme: reduced,
      );

      expect(reduced.accessibility.reduceIntensity, isTrue);
      expect(
        headerColour(tester),
        AuthorOsTheme.color(
          reduced.colorFor(StudioId.worldBoard, ThemeColorRef.surfaceContainer),
        ),
      );
      expect(
        reduced.color(ThemeColorRef.primary),
        isNot(plain.color(ThemeColorRef.primary)),
      );
    });

    testWidgets('a Studio palette override reaches the board', (tester) async {
      // Proves the board resolves through its Studio identity rather than
      // holding colours of its own, so a future theme can accent it.
      final base = _theme();
      const accent = ThemeColor(0xFF123456);
      final overridden = ResolvedTheme(
        themeId: base.themeId,
        name: base.name,
        requestedMode: base.requestedMode,
        brightness: base.brightness,
        palette: base.palette,
        typography: base.typography,
        metrics: base.metrics,
        accessibility: base.accessibility,
        fallbackApplied: base.fallbackApplied,
        requestedBrightness: base.requestedBrightness,
        studioOverrides: {
          StudioId.worldBoard: const {ThemeColorRef.surfaceContainer: accent},
        },
      );

      await pumpBoard(
        tester,
        project: _project('wb-theme-override'),
        theme: overridden,
      );

      expect(headerColour(tester), AuthorOsTheme.color(accent));
    });

    testWidgets('the board reuses the shell iconography for each section',
        (tester) async {
      await pumpBoard(tester, project: _project('wb-theme-icons'));

      expect(WorldBoardSection.characters.icon, Icons.groups_outlined);
      expect(WorldBoardSection.worlds.icon, Icons.public_outlined);
      expect(WorldBoardSection.timelines.icon, Icons.timeline_outlined);
      expect(WorldBoardSection.plot.icon, Icons.route_outlined);
      expect(find.byIcon(Icons.groups_outlined), findsWidgets);
    });
  });
}
