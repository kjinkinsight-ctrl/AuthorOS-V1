import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/analytics_studio_view.dart';
import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/writing_goals_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Thursday, so the Monday-based week has days on both sides of it.
final today = DateTime(2026, 8, 20, 14, 30);
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

/// `count` words of scene content, so word totals are exact by construction.
String _words(int count) =>
    List<String>.generate(count, (index) => 'word${index + 1}').join(' ');

WritingSession _session({
  required String id,
  required String projectId,
  required DateTime startedAt,
  Duration duration = const Duration(minutes: 30),
  int words = 500,
}) =>
    WritingSession(
      id: id,
      projectId: projectId,
      startedAt: startedAt,
      endedAt: startedAt.add(duration),
      duration: duration,
      startingWordCount: 0,
      endingWordCount: words,
      wordsAdded: words,
      wordsRemoved: 0,
    );

ManuscriptScene _scene(
  String chapterId,
  String id, {
  String content = '',
  ManuscriptNodeStatus status = ManuscriptNodeStatus.draft,
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: 'Scene',
      order: 1,
      content: content,
      status: status,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

ManuscriptChapter _chapter(
  String id, {
  required String title,
  required List<ManuscriptScene> scenes,
  ManuscriptNodeStatus status = ManuscriptNodeStatus.draft,
}) =>
    ManuscriptChapter(
      id: id,
      title: title,
      order: 1,
      status: status,
      scenes: scenes,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

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
  late WritingGoalsStore goalsStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
    goalsStore = WritingGoalsStore(repository: repository);
  });

  tearDown(() => database.close());

  AnalyticsService serviceFor(StarterProject project) => AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
        clock: () => today,
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

  Future<void> pumpView(WidgetTester tester, StarterProject project) async {
    tester.view.physicalSize = const Size(1400, 4200);
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
                goalsStore: goalsStore,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inKey(String key, Finder finder) =>
      find.descendant(of: find.byKey(Key(key)), matching: finder);

  group('basic metrics', () {
    testWidgets('the six spec metrics render', (tester) async {
      final project = _project('ap-metrics', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1',
            title: 'One',
            status: ManuscriptNodeStatus.complete,
            scenes: [
              _scene('ch-1', 'sc-1',
                  content: _words(250),
                  status: ManuscriptNodeStatus.complete),
              _scene('ch-1', 'sc-2', status: ManuscriptNodeStatus.draft),
            ]),
      ]);

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-basic-metrics-section')),
        findsOneWidget,
      );
      expect(inKey('analytics-metric-words-written', find.text('250')),
          findsOneWidget);
      expect(inKey('analytics-metric-words-remaining', find.text('750')),
          findsOneWidget);
      expect(inKey('analytics-metric-chapters-complete', find.text('1 / 1')),
          findsOneWidget);
      expect(inKey('analytics-metric-scenes-complete', find.text('1 / 2')),
          findsOneWidget);
      expect(inKey('analytics-metric-writing-sessions', find.text('0')),
          findsOneWidget);
      expect(inKey('analytics-metric-session-time', find.text('0m')),
          findsOneWidget);
    });

    testWidgets('words remaining shows a dash without a target',
        (tester) async {
      final project = _project('ap-metrics-no-target', wordGoal: 0);
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      expect(
        inKey('analytics-metric-words-remaining', find.text('—')),
        findsOneWidget,
      );
    });

    testWidgets('session totals reflect recorded sessions', (tester) async {
      final project = _project('ap-metrics-sessions');
      await saveManuscript(project, const []);
      await repository.putWritingSessions([
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(hours: 1),
        ),
        _session(
          id: 'ws-2',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          duration: const Duration(minutes: 30),
        ),
      ]);

      await pumpView(tester, project);

      expect(inKey('analytics-metric-writing-sessions', find.text('2')),
          findsOneWidget);
      expect(inKey('analytics-metric-session-time', find.text('1h 30m')),
          findsOneWidget);
    });
  });

  group('goals', () {
    testWidgets('a fresh project shows the seeded targets', (tester) async {
      final project = _project('ap-goals-default');
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      expect(find.byKey(const Key('analytics-goals-section')), findsOneWidget);
      expect(find.text('Default targets'), findsOneWidget);
      expect(
        inKey('analytics-goal-daily', find.text('0 / 2,000 words')),
        findsOneWidget,
      );
      expect(
        inKey('analytics-goal-weekly', find.text('0 / 10,000 words')),
        findsOneWidget,
      );
      expect(
        inKey('analytics-goal-monthly', find.text('0 / 40,000 words')),
        findsOneWidget,
      );
    });

    testWidgets('progress and the words left both show', (tester) async {
      final project = _project('ap-goals-progress');
      await saveManuscript(project, const []);
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          words: 1240,
        ),
      );

      await pumpView(tester, project);

      expect(
        inKey('analytics-goal-daily', find.text('1,240 / 2,000 words')),
        findsOneWidget,
      );
      expect(
        inKey('analytics-goal-daily', find.text('760 to go')),
        findsOneWidget,
      );
    });

    testWidgets('a met goal says so rather than counting down to zero',
        (tester) async {
      final project = _project('ap-goals-met');
      await saveManuscript(project, const []);
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          words: 2500,
        ),
      );

      await pumpView(tester, project);

      expect(
        inKey('analytics-goal-daily', find.text('Goal met')),
        findsOneWidget,
      );
    });

    testWidgets('a goal of zero draws no bar and says it is unset',
        (tester) async {
      final project = _project('ap-goals-off');
      await saveManuscript(project, const []);
      await goalsStore.save(
        WritingGoals.defaultsFor(project.id).copyWith(dailyWords: 0),
      );

      await pumpView(tester, project);

      expect(
        inKey('analytics-goal-daily', find.text('No daily goal set')),
        findsOneWidget,
      );
      expect(
        inKey('analytics-goal-daily', find.byType(LinearProgressIndicator)),
        findsNothing,
      );
      expect(
        inKey('analytics-goals-section', find.byType(LinearProgressIndicator)),
        findsNWidgets(2),
      );
    });

    testWidgets('customized targets are badged as the author\'s own',
        (tester) async {
      final project = _project('ap-goals-custom');
      await saveManuscript(project, const []);
      await goalsStore.save(
        WritingGoals.defaultsFor(project.id).copyWith(dailyWords: 1500),
      );

      await pumpView(tester, project);

      expect(find.text('Your targets'), findsOneWidget);
      expect(
        inKey('analytics-goal-daily', find.text('0 / 1,500 words')),
        findsOneWidget,
      );
    });
  });

  group('editing goals', () {
    testWidgets('saving new targets persists them and refreshes the card',
        (tester) async {
      final project = _project('ap-goals-edit');
      await saveManuscript(project, const []);

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analytics-goals-dialog')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('analytics-goal-daily-field')), '1500');
      await tester.enterText(
          find.byKey(const Key('analytics-goal-weekly-field')), '9000');
      await tester.enterText(
          find.byKey(const Key('analytics-goal-monthly-field')), '30000');
      await tester.tap(find.byKey(const Key('analytics-goals-save')));
      await tester.pumpAndSettle();

      final stored = await repository.writingGoalsForProject(project.id);
      expect(stored?.dailyWords, 1500);
      expect(stored?.weeklyWords, 9000);
      expect(stored?.monthlyWords, 30000);

      expect(find.byKey(const Key('analytics-goals-dialog')), findsNothing);
      expect(
        inKey('analytics-goal-daily', find.text('0 / 1,500 words')),
        findsOneWidget,
      );
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final project = _project('ap-goals-cancel');
      await saveManuscript(project, const []);

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('analytics-goal-daily-field')), '1500');
      await tester.tap(find.byKey(const Key('analytics-goals-cancel')));
      await tester.pumpAndSettle();

      expect(await repository.writingGoalsForProject(project.id), isNull);
      expect(
        inKey('analytics-goal-daily', find.text('0 / 2,000 words')),
        findsOneWidget,
      );
    });

    testWidgets('a target that is not a number keeps the dialog open',
        (tester) async {
      final project = _project('ap-goals-invalid');
      await saveManuscript(project, const []);

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('analytics-goal-daily-field')), 'abc');
      await tester.tap(find.byKey(const Key('analytics-goals-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('analytics-goals-dialog')), findsOneWidget);
      expect(find.text('Enter a whole number of words.'), findsOneWidget);
      expect(await repository.writingGoalsForProject(project.id), isNull);
    });

    testWidgets('a negative target is refused', (tester) async {
      final project = _project('ap-goals-negative');
      await saveManuscript(project, const []);

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('analytics-goal-daily-field')), '-5');
      await tester.tap(find.byKey(const Key('analytics-goals-save')));
      await tester.pumpAndSettle();

      expect(find.text('A goal cannot be negative.'), findsOneWidget);
      expect(await repository.writingGoalsForProject(project.id), isNull);
    });

    testWidgets('zero is accepted and turns that goal off', (tester) async {
      final project = _project('ap-goals-zero');
      await saveManuscript(project, const []);

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('analytics-goal-daily-field')), '0');
      await tester.tap(find.byKey(const Key('analytics-goals-save')));
      await tester.pumpAndSettle();

      expect(
        inKey('analytics-goal-daily', find.text('No daily goal set')),
        findsOneWidget,
      );
    });

    testWidgets('restoring defaults drops the stored row', (tester) async {
      final project = _project('ap-goals-restore');
      await saveManuscript(project, const []);
      await goalsStore.save(
        WritingGoals.defaultsFor(project.id).copyWith(dailyWords: 1500),
      );

      await pumpView(tester, project);
      await tester.tap(find.byKey(const Key('analytics-goals-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('analytics-goals-restore')));
      await tester.pumpAndSettle();

      expect(await repository.writingGoalsForProject(project.id), isNull);
      expect(
        inKey('analytics-goal-daily', find.text('0 / 2,000 words')),
        findsOneWidget,
      );
      expect(find.text('Default targets'), findsOneWidget);
    });
  });

  group('velocity', () {
    testWidgets('a project with no sessions explains itself', (tester) async {
      final project = _project('ap-velocity-empty');
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-velocity-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('No pace to measure yet'), findsOneWidget);
    });

    testWidgets('both daily figures render, and differ when days were missed',
        (tester) async {
      final project = _project('ap-velocity');
      await saveManuscript(project, const []);
      // 1,000 words on two of the twenty days since 1 August: 50 a day
      // overall, 500 on the days actually written.
      await repository.putWritingSessions([
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 1, 9),
          duration: const Duration(hours: 1),
          words: 500,
        ),
        _session(
          id: 'ws-2',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          duration: const Duration(hours: 1),
          words: 500,
        ),
      ]);

      await pumpView(tester, project);

      expect(inKey('analytics-velocity-daily', find.text('50')), findsOneWidget);
      expect(inKey('analytics-velocity-writing-day', find.text('500')),
          findsOneWidget);
      expect(inKey('analytics-velocity-session', find.text('500')),
          findsOneWidget);
      expect(inKey('analytics-velocity-hourly', find.text('500')),
          findsOneWidget);
      // 50 a day is 350 a week and 1,522 across a mean month.
      expect(inKey('analytics-velocity-weekly', find.text('350')),
          findsOneWidget);
      expect(inKey('analytics-velocity-monthly', find.text('1,522')),
          findsOneWidget);
    });

    testWidgets('a session with no measurable time shows a dash, not a zero',
        (tester) async {
      final project = _project('ap-velocity-no-time');
      await saveManuscript(project, const []);
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          duration: Duration.zero,
        ),
      );

      await pumpView(tester, project);

      expect(inKey('analytics-velocity-hourly', find.text('—')), findsOneWidget);
      expect(
        inKey('analytics-velocity-hourly',
            find.text('No measurable writing time yet')),
        findsOneWidget,
      );
    });
  });

  group('manuscript projection', () {
    testWidgets('the spec sentence renders with the projected day',
        (tester) async {
      final project = _project('ap-projection', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(500)),
        ]),
      ]);
      // 500 words over the ten days from 11 August: 50 a day. The 500 that
      // remain are ten more days, landing on 30 August.
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 11, 9),
          duration: const Duration(hours: 1),
          words: 500,
        ),
      );

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-projection-section')),
        findsOneWidget,
      );
      expect(
        find.text(
          "At your current pace, you'll complete this manuscript in "
          'approximately 10 days.',
        ),
        findsOneWidget,
      );
      expect(inKey('analytics-projection-current', find.text('500')),
          findsOneWidget);
      expect(inKey('analytics-projection-target', find.text('1,000')),
          findsOneWidget);
      expect(inKey('analytics-projection-remaining', find.text('500')),
          findsOneWidget);
      expect(
        inKey('analytics-projection-velocity', find.text('50 words/day')),
        findsOneWidget,
      );
      expect(
        inKey('analytics-projection-date', find.text('30 August 2026')),
        findsOneWidget,
      );
    });

    testWidgets('no target means the card asks for one', (tester) async {
      final project = _project('ap-projection-no-target', wordGoal: 0);
      await saveManuscript(project, const []);

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-projection-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-projection-sentence')),
        findsNothing,
      );
    });

    testWidgets('a target with no recorded pace names no day', (tester) async {
      final project = _project('ap-projection-no-pace', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-projection-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-projection-sentence')),
        findsNothing,
      );
      expect(
        inKey('analytics-projection-date', find.text('—')),
        findsOneWidget,
      );
    });

    testWidgets('a finished manuscript projects nothing', (tester) async {
      final project = _project('ap-projection-complete', wordGoal: 100);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          words: 250,
        ),
      );

      await pumpView(tester, project);

      expect(
        find.byKey(const Key('analytics-projection-complete')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-projection-sentence')),
        findsNothing,
      );
    });

    testWidgets('one day left is written in the singular', (tester) async {
      final project = _project('ap-projection-one-day', wordGoal: 550);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(500)),
        ]),
      ]);
      // 500 words written today: 500 a day, with 50 to go.
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          projectId: project.id,
          startedAt: DateTime(2026, 8, 20, 9),
          words: 500,
        ),
      );

      await pumpView(tester, project);

      expect(
        find.text(
          "At your current pace, you'll complete this manuscript in "
          'approximately 1 day.',
        ),
        findsOneWidget,
      );
    });
  });

  group('architecture', () {
    test('the Analytics view reaches no goal table and no preferences', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();

      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'package:drift")));
      expect(source, isNot(contains('writingGoalRows')));
      expect(source, isNot(contains('putWritingGoals')));
      expect(source, isNot(contains('writingGoalsForProject')));
      // It writes goals through the store, and only through the store.
      expect(source, contains('WritingGoalsStore'));
    });

    test('the view owns no palette and no second theme system', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();

      expect(source, contains('StudioThemeScope'));
      expect(source, contains('StudioId.analytics'));
      expect(source, isNot(contains('ThemeData(')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
    });

    test('analytics still derives goals and never writes them', () {
      final source = File('lib/analytics_service.dart').readAsStringSync();

      expect(source, contains('goalsStore.load'));
      expect(source, isNot(contains('putWritingGoals')));
      expect(source, isNot(contains('.save(')));
    });

    test('the performance sections introduced no charting dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      for (final package in const [
        'fl_chart',
        'charts_flutter',
        'syncfusion_flutter_charts',
        'graphic',
      ]) {
        expect(pubspec, isNot(contains(package)));
      }
    });
  });
}
