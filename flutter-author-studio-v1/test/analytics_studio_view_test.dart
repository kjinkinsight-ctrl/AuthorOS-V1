import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/analytics_studio_view.dart';
import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
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
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 20, 10);

StarterProject _project(String id, {int wordGoal = 80000}) => StarterProject(
      id: id,
      title: 'The Hollow Court',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

String _words(int count) =>
    List<String>.generate(count, (index) => 'word${index + 1}').join(' ');

Future<ResolvedTheme> _resolvedTheme() async {
  final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
  return engine.resolveSelection(
    selection:
        const ThemeSelection(themeId: 'light', mode: AuthorOsThemeMode.light),
    hostBrightness: ThemeBrightness.light,
  );
}

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

  AnalyticsService serviceFor(StarterProject project) => AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

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

  ManuscriptChapter chapterOf(
    String id,
    String title,
    int words, {
    ManuscriptNodeStatus status = ManuscriptNodeStatus.draft,
  }) =>
      ManuscriptChapter(
        id: id,
        title: title,
        order: 1,
        status: status,
        createdAt: timestamp,
        updatedAt: timestamp,
        scenes: [
          ManuscriptScene(
            id: '$id-scene',
            chapterId: id,
            title: 'Scene',
            order: 1,
            content: _words(words),
            status: status,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        ],
      );

  Future<void> pumpView(
    WidgetTester tester,
    StarterProject project,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = await _resolvedTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: Scaffold(
          body: StudioThemeScope(
            theme: theme,
            studio: StudioId.shell,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnalyticsStudioView(
                project: project,
                service: serviceFor(project),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('renders the Analytics Studio from canonical data',
        (tester) async {
      final project = _project('av-renders', wordGoal: 1000);
      await saveManuscript(project, [chapterOf('ch-1', 'Chapter One', 250)]);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-studio')), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(
        find.text('Project performance and writing progress'),
        findsOneWidget,
      );
    });

    testWidgets('the word count card shows progress against the target',
        (tester) async {
      final project = _project('av-words', wordGoal: 1000);
      await saveManuscript(project, [chapterOf('ch-1', 'Chapter One', 250)]);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-word-count-card')), findsOneWidget);
      expect(find.text('250 / 1,000'), findsOneWidget);
      expect(find.text('25.0%'), findsWidgets);
    });

    testWidgets('writing progress reports current, target, and remaining',
        (tester) async {
      final project = _project('av-progress', wordGoal: 1000);
      await saveManuscript(project, [chapterOf('ch-1', 'Chapter One', 250)]);

      await pumpView(tester, project);

      final section = find.byKey(const Key('analytics-progress-section'));
      expect(section, findsOneWidget);
      // Scoped to the section under test: the Manuscript Projection panel
      // shows its own Current Words and Target, and the remainder appears in
      // the Writing Metrics tiles too. Those are the same numbers by design,
      // so what this test means is "the progress card reports them", not
      // "only one card on the page may".
      Finder inProgress(Finder finder) =>
          find.descendant(of: section, matching: finder);
      expect(inProgress(find.text('Current Words')), findsOneWidget);
      expect(inProgress(find.text('Target')), findsOneWidget);
      expect(inProgress(find.text('Words Remaining')), findsOneWidget);
      expect(inProgress(find.text('750')), findsOneWidget);
      expect(
        inProgress(find.byType(LinearProgressIndicator)),
        findsOneWidget,
      );
    });

    testWidgets('chapter statistics list counts and extremes', (tester) async {
      final project = _project('av-chapters');
      await saveManuscript(project, [
        chapterOf('ch-1', 'The Long One', 400),
        chapterOf('ch-2', 'The Short One', 50,
            status: ManuscriptNodeStatus.complete),
      ]);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-manuscript-section')), findsOneWidget);
      expect(find.text('Manuscript'), findsOneWidget);
      expect(find.text('Longest Chapter'), findsOneWidget);
      expect(find.text('The Long One · 400 words'), findsOneWidget);
      expect(find.text('Shortest Chapter'), findsOneWidget);
      expect(find.text('The Short One · 50 words'), findsOneWidget);
      expect(find.text('Avg Chapter'), findsOneWidget);
      expect(find.text('225 words'), findsOneWidget);
    });

    testWidgets('the story ecosystem panel reports record counts',
        (tester) async {
      final project = _project('av-ecosystem');
      await saveManuscript(project, const []);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara');
      final plot = PlotService(projectId: project.id, repository: repository);
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'plotline',
        name: 'The Rebellion',
        fields: {'plotStatus': 'active'},
      ));
      final timeline =
          TimelineService(projectId: project.id, repository: repository);
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-1', name: 'The Fall'),
      );

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-ecosystem-section')), findsOneWidget);
      expect(find.text('Story Ecosystem'), findsOneWidget);
      final ecosystem = find.byKey(const Key('analytics-ecosystem-section'));
      expect(
        find.descendant(of: ecosystem, matching: find.text('Characters')),
        findsOneWidget,
      );
      expect(find.text('Plot Records'), findsOneWidget);
      expect(find.text('Timeline Events'), findsOneWidget);
      expect(find.text('Research Items'), findsOneWidget);
    });

    testWidgets('the progress panel shows completion and status',
        (tester) async {
      final project = _project('av-completion', wordGoal: 1000);
      await saveManuscript(project, [chapterOf('ch-1', 'Chapter One', 250)]);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-progress-panel')), findsOneWidget);
      expect(find.text('Completion'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Drafting'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('a project without a target never shows 0%', (tester) async {
      final project = _project('av-no-target', wordGoal: 0);
      await saveManuscript(project, [chapterOf('ch-1', 'Chapter One', 250)]);

      await pumpView(tester, project);

      expect(find.textContaining('No writing target set'), findsWidgets);
      // Still global: no card anywhere may invent a percentage of a target
      // that was never set.
      expect(find.textContaining('0%'), findsNothing);

      // The manuscript-target cards draw no bar without a target.
      for (final section in const [
        'analytics-progress-section',
        'analytics-projection-section',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(section)),
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
          reason: '$section must not draw progress against no target',
        );
      }

      // The goal bars do render: a daily word goal exists independently of
      // the manuscript target, and 0 of 2,000 words today is a true statement
      // about a target the author really has.
      expect(
        find.descendant(
          of: find.byKey(const Key('analytics-goals-section')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('an empty project explains itself instead of showing zeros',
        (tester) async {
      final project = _project('av-empty', wordGoal: 0);
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-studio')), findsOneWidget);
      expect(
        find.textContaining('No chapters yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No story records yet'),
        findsOneWidget,
      );
      expect(find.text('Not started'), findsOneWidget);
    });
  });

  group('theme integration', () {
    testWidgets('the studio layers its own StudioId over the shell theme',
        (tester) async {
      final project = _project('av-theme');
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(
        scopes.any((scope) => scope.studio == StudioId.analytics),
        isTrue,
        reason: 'Analytics must resolve tokens through StudioId.analytics',
      );
    });

    test('the view owns no second theme system and no hard-coded colours', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();
      expect(source, contains('StudioThemeScope'));
      expect(source, contains('StudioId.analytics'));
      expect(source, contains('Theme.of(context)'));
      expect(source, isNot(contains('ThemeData(')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
    });

    test('the view does not use duplicate persistence', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();
      expect(source, contains('AnalyticsService'));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'package:drift")));
    });
  });

  group('navigation', () {
    test('the shell registers Analytics as a section', () {
      expect(StudioSection.values, contains(StudioSection.analytics));
    });

    test('Analytics carries its own label and navigation icon', () {
      expect(StudioSection.analytics.label, 'Analytics');
      expect(StudioSection.analytics.icon, Icons.insights_outlined);
      expect(
        StudioSection.analytics.icon,
        isNot(StudioSection.statistics.icon),
      );
    });

    test('every existing studio stays addressable and uniquely labelled', () {
      for (final section in const [
        StudioSection.dashboard,
        StudioSection.worldBoard,
        StudioSection.statistics,
        StudioSection.manuscript,
        StudioSection.characters,
        StudioSection.codex,
        StudioSection.world,
        StudioSection.plot,
        StudioSection.timeline,
        StudioSection.settings,
      ]) {
        expect(StudioSection.values, contains(section));
      }
      final labels = StudioSection.values.map((section) => section.label);
      expect(labels.toSet(), hasLength(StudioSection.values.length));
    });

    testWidgets('selecting Analytics in the shell renders the studio',
        (tester) async {
      // The shell hands every Studio the production repository, and opening
      // it schedules work this test must not adopt. Construct it in real
      // async so its lazy open leaves no pending timer behind at teardown.
      await tester.runAsync(() async {
        expect(authorOsRepository, isNotNull);
      });

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDisableAuroraAnimation = true;
      addTearDown(() => debugDisableAuroraAnimation = false);

      final theme = await _resolvedTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: AuthorOsTheme.toThemeData(theme),
          home: StudioThemeScope(
            theme: theme,
            studio: StudioId.shell,
            child: AuthorStudioShell(
              project: _project('av-navigation'),
              manuscriptStore: manuscriptStore,
              themeId: 'light',
              accentId: 'default',
              onThemeChanged: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsStudioView), findsNothing);
      expect(find.text('Analytics'), findsWidgets);

      await tester.tap(find.text('Analytics').first);
      // One frame proves the shell routed here: the studio is mounted and
      // loading. The tree is deliberately not settled — the production
      // database does not open inside a widget test, which is the same
      // limitation the World Board's navigation test runs into.
      await tester.pump();

      expect(find.byType(AnalyticsStudioView), findsOneWidget);

      // Unmount before anything the load scheduled can outlive the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
