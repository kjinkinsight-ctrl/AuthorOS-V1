import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/analytics_studio_view.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/writing_session_recorder.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Thursday, so the Monday-based week has days on both sides of it.
final today = DateTime(2026, 8, 20, 14, 30);

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

WritingSession _session({
  required String id,
  String projectId = 'project-a',
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
        clock: () => today,
      );

  Future<void> pumpView(WidgetTester tester, StarterProject project) async {
    tester.view.physicalSize = const Size(1400, 3200);
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

  Finder inHistory(Finder finder) => find.descendant(
        of: find.byKey(const Key('analytics-writing-history-section')),
        matching: finder,
      );

  Finder inTile(String key, Finder finder) =>
      find.descendant(of: find.byKey(Key(key)), matching: finder);

  group('empty state', () {
    testWidgets('a new project says no sessions were recorded yet',
        (tester) async {
      await pumpView(tester, _project('history-empty'));

      expect(
        find.byKey(const Key('analytics-writing-history-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-writing-history-empty')),
        findsOneWidget,
      );
      expect(find.text('No writing sessions recorded yet.'), findsOneWidget);
      expect(
        find.textContaining('once you write in Manuscript Studio'),
        findsOneWidget,
      );
    });

    testWidgets('no streak, tiles, or chart is fabricated with no history',
        (tester) async {
      await pumpView(tester, _project('history-empty-2'));

      expect(find.byKey(const Key('analytics-history-streak')), findsNothing);
      expect(find.byKey(const Key('analytics-history-today')), findsNothing);
      expect(
        find.byKey(const Key('analytics-history-week-chart')),
        findsNothing,
      );
      expect(find.textContaining('🔥'), findsNothing);
    });
  });

  group('recorded history', () {
    Future<void> seedWeek() => repository.putWritingSessions([
          _session(
            id: 'ws-mon',
            startedAt: DateTime(2026, 8, 17, 9),
            duration: const Duration(hours: 2),
            words: 1200,
          ),
          _session(
            id: 'ws-tue',
            startedAt: DateTime(2026, 8, 18, 9),
            duration: const Duration(minutes: 40),
            words: 1500,
          ),
          _session(
            id: 'ws-wed',
            startedAt: DateTime(2026, 8, 19, 9),
            duration: const Duration(minutes: 50),
            words: 2880,
          ),
          _session(
            id: 'ws-thu-1',
            startedAt: DateTime(2026, 8, 20, 8),
            duration: const Duration(minutes: 25),
            words: 700,
          ),
          _session(
            id: 'ws-thu-2',
            startedAt: DateTime(2026, 8, 20, 13),
            duration: const Duration(minutes: 17),
            words: 540,
          ),
        ]);

    testWidgets(
        'the Writing History section renders instead of the empty '
        'state', (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(
        find.byKey(const Key('analytics-writing-history-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-writing-history-empty')),
        findsNothing,
      );
      expect(inHistory(find.text('Writing History')), findsOneWidget);
      expect(inHistory(find.text('Recorded sessions')), findsOneWidget);
    });

    testWidgets('today shows words, writing time, and session count',
        (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(find.byKey(const Key('analytics-history-today')), findsOneWidget);
      const tile = 'analytics-history-today';
      expect(inTile(tile, find.text('Today')), findsOneWidget);
      expect(inTile(tile, find.text('1,240 words')), findsOneWidget);
      expect(inTile(tile, find.text('42m')), findsOneWidget);
      expect(inTile(tile, find.text('2 sessions')), findsOneWidget);
    });

    testWidgets('the current streak is shown with its longest run',
        (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(find.byKey(const Key('analytics-history-streak')), findsOneWidget);
      const tile = 'analytics-history-streak';
      expect(inTile(tile, find.text('Current streak')), findsOneWidget);
      expect(inTile(tile, find.text('🔥 4 days')), findsOneWidget);
      expect(inTile(tile, find.text('Longest 4 days')), findsOneWidget);
    });

    testWidgets('this week shows words, writing time, and sessions',
        (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(find.byKey(const Key('analytics-history-week')), findsOneWidget);
      const tile = 'analytics-history-week';
      expect(inTile(tile, find.text('This week')), findsOneWidget);
      expect(inTile(tile, find.text('6,820 words')), findsOneWidget);
      expect(inTile(tile, find.text('4h 12m')), findsOneWidget);
      expect(inTile(tile, find.text('5 sessions')), findsOneWidget);
    });

    testWidgets('the average session shows duration and words', (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(
        find.byKey(const Key('analytics-history-average')),
        findsOneWidget,
      );
      const tile = 'analytics-history-average';
      expect(inTile(tile, find.text('Average session')), findsOneWidget);
      // 4h 12m across five sessions.
      expect(inTile(tile, find.text('50m')), findsOneWidget);
      expect(inTile(tile, find.text('1,364 words')), findsOneWidget);
    });

    testWidgets('the week renders as seven daily bars', (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(
        find.byKey(const Key('analytics-history-week-chart')),
        findsOneWidget,
      );
      const chart = 'analytics-history-week-chart';
      expect(inTile(chart, find.text('Words this week')), findsOneWidget);
      // Monday through Sunday: four days written, three still empty.
      expect(inTile(chart, find.text('0')), findsNWidgets(3));
      expect(inTile(chart, find.text('2,880')), findsOneWidget);
      expect(inTile(chart, find.text('1,240')), findsOneWidget);
    });

    testWidgets('all-time totals accompany the current week', (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      const totals = 'analytics-history-totals';
      expect(find.byKey(const Key(totals)), findsOneWidget);
      expect(inTile(totals, find.text('Sessions')), findsOneWidget);
      expect(inTile(totals, find.text('Sessions This Month')), findsOneWidget);
      // Five sessions all time, and — this week being August — five this
      // month too.
      expect(inTile(totals, find.text('5')), findsNWidgets(2));
      expect(inTile(totals, find.text('Words Written')), findsOneWidget);
      expect(inTile(totals, find.text('6,820')), findsOneWidget);
      expect(inTile(totals, find.text('Writing Time')), findsOneWidget);
      expect(inTile(totals, find.text('4h 12m')), findsOneWidget);
      expect(inTile(totals, find.text('Longest Session')), findsOneWidget);
      expect(inTile(totals, find.text('2h')), findsOneWidget);
      expect(inTile(totals, find.text('Best Session')), findsOneWidget);
      expect(inTile(totals, find.text('2,880 words')), findsOneWidget);
      expect(inTile(totals, find.text('This Month')), findsOneWidget);
      expect(inTile(totals, find.text('6,820 words')), findsOneWidget);
    });

    testWidgets('history is project-specific in the rendered Studio',
        (tester) async {
      await seedWeek();
      await repository.putWritingSession(
        _session(
          id: 'ws-other-project',
          projectId: 'project-b',
          startedAt: DateTime(2026, 8, 20, 9),
          words: 99999,
        ),
      );

      await pumpView(tester, _project('project-b'));

      expect(
        inTile('analytics-history-today', find.text('99,999 words')),
        findsOneWidget,
      );
      expect(inHistory(find.text('6,820 words')), findsNothing);
      expect(
        inTile('analytics-history-streak', find.text('🔥 1 day')),
        findsOneWidget,
      );
    });

    testWidgets('the existing Analytics sections still render alongside it',
        (tester) async {
      await seedWeek();
      await pumpView(tester, _project('project-a'));

      expect(find.byKey(const Key('analytics-studio')), findsOneWidget);
      expect(
        find.byKey(const Key('analytics-word-count-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-progress-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-manuscript-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-ecosystem-section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('analytics-progress-panel')), findsOneWidget);
      expect(find.byKey(const Key('analytics-refresh')), findsOneWidget);
    });

    testWidgets('refreshing recalculates the history in place', (tester) async {
      await pumpView(tester, _project('project-a'));
      expect(
        find.byKey(const Key('analytics-writing-history-empty')),
        findsOneWidget,
      );

      await seedWeek();
      await tester.tap(find.byKey(const Key('analytics-refresh')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('analytics-writing-history-empty')),
        findsNothing,
      );
      expect(
        inTile('analytics-history-today', find.text('1,240 words')),
        findsOneWidget,
      );
    });
  });

  group('duration formatting', () {
    test('renders compact hours and minutes', () {
      expect(formatWritingDuration(Duration.zero), '0m');
      expect(formatWritingDuration(const Duration(seconds: 30)), '0m');
      expect(formatWritingDuration(const Duration(minutes: 42)), '42m');
      expect(formatWritingDuration(const Duration(hours: 2)), '2h');
      expect(
        formatWritingDuration(const Duration(hours: 4, minutes: 12)),
        '4h 12m',
      );
    });
  });

  group('theme engine', () {
    testWidgets('the history section resolves through StudioId.analytics',
        (tester) async {
      await repository.putWritingSession(
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9)),
      );
      await pumpView(tester, _project('project-a'));

      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(
        scopes.any((scope) => scope.studio == StudioId.analytics),
        isTrue,
      );
    });

    testWidgets('every history text style comes from Theme.of(context)',
        (tester) async {
      await repository.putWritingSession(
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9)),
      );
      await pumpView(tester, _project('project-a'));

      final texts =
          tester.widgetList<Text>(inHistory(find.byType(Text))).toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(
          text.style?.color,
          isNot(const Color(0xFFFFFFFF)),
          reason: 'history text must not carry a hard-coded colour',
        );
      }
    });
  });

  group('the Manuscript Studio records what it observes', () {
    const project = StarterProject(
      id: 'recording-project',
      title: 'Recording Project',
      genre: 'Fiction',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: [],
      chapters: [
        StarterChapter(
          title: 'The Beginning',
          prompt: '',
          scenes: ['Arrival', 'Meeting'],
        ),
      ],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Arrival',
    );

    Future<void> pumpStudio(
      WidgetTester tester,
      WritingSessionRecorder recorder,
    ) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManuscriptStudioView(
              project: project,
              startSprint: false,
              store: manuscriptStore,
              sessionRecorder: recorder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opening the Studio records no session', (tester) async {
      final recorder = WritingSessionRecorder(
        projectId: project.id,
        repository: repository,
      );

      await pumpStudio(tester, recorder);

      expect(recorder.hasOpenSession, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        await repository.writingSessionsForProject(project.id),
        isEmpty,
      );
    });

    testWidgets('writing then leaving the editor records one session',
        (tester) async {
      final recorder = WritingSessionRecorder(
        projectId: project.id,
        repository: repository,
        thresholds: const WritingSessionThresholds(minimumWordsWritten: 3),
      );

      await pumpStudio(tester, recorder);
      await tester.enterText(
        find.byKey(const Key('manuscript-draft-field')),
        'The rain had been falling since dawn and had not stopped.',
      );
      await tester.pumpAndSettle();

      expect(recorder.hasOpenSession, isTrue);

      // Leaving Manuscript Studio unmounts it, which finalizes the session.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final stored = await repository.writingSessionsForProject(project.id);
      expect(stored, hasLength(1));
      expect(stored.single.wordsWritten, 11);
      expect(stored.single.projectId, project.id);
      expect(stored.single.sceneId, isNotNull);
    });

    testWidgets('autosave and navigation never duplicate a session',
        (tester) async {
      final recorder = WritingSessionRecorder(
        projectId: project.id,
        repository: repository,
        thresholds: const WritingSessionThresholds(minimumWordsWritten: 3),
      );

      await pumpStudio(tester, recorder);
      await tester.enterText(
        find.byKey(const Key('manuscript-draft-field')),
        'The rain had been falling since dawn.',
      );
      // Let the autosave debounce fire, several times over.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Navigate between scenes and back; selection changes are not writing.
      await tester.tap(find.textContaining('Scene 02 - Meeting').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Scene 01 - Arrival').first);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final stored = await repository.writingSessionsForProject(project.id);
      expect(stored, hasLength(1));
      expect(stored.single.wordsWritten, 7);
    });

    testWidgets('a one-word edit falls below the threshold and is discarded',
        (tester) async {
      final recorder = WritingSessionRecorder(
        projectId: project.id,
        repository: repository,
      );

      await pumpStudio(tester, recorder);
      await tester.enterText(
        find.byKey(const Key('manuscript-draft-field')),
        'Rain.',
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(
        await repository.writingSessionsForProject(project.id),
        isEmpty,
      );
    });
  });

  group('architecture', () {
    test('the Analytics view owns no palette and no second theme system', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();

      expect(source, contains('StudioThemeScope'));
      expect(source, contains('StudioId.analytics'));
      expect(source, contains('Theme.of(context)'));
      expect(source, isNot(contains('ThemeData(')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('AnalyticsTheme')));
      expect(source, isNot(contains('AnalyticsColors')));
    });

    test('the Analytics view reaches no database and no preferences', () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();

      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'package:drift")));
      expect(source, isNot(contains('writingSessionsForProject')));
      expect(source, contains('summary.writingHistory'));
    });

    test('the history section does not introduce a charting dependency', () {
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

    test(
        'the history model lives beside AnalyticsSummary, not in a new '
        'model layer', () {
      final source = File('lib/analytics_service.dart').readAsStringSync();

      expect(source, contains('class AnalyticsWritingHistory'));
      expect(source, contains('class AnalyticsWritingDay'));
      expect(source, contains('final AnalyticsWritingHistory writingHistory'));
      expect(source, contains('class AnalyticsSummary'));
      // The service still folds one summary; no parallel analytics model.
      expect(source, contains('class AnalyticsService'));
    });

    test('no writing-session storage was put in SharedPreferences', () {
      final libraries = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libraries) {
        final source = file.readAsStringSync();
        if (!source.contains('SharedPreferences')) continue;
        expect(
          source,
          isNot(contains('WritingSession')),
          reason: '${file.path} must not store sessions in preferences',
        );
      }
    });

    test('widgets never reach the writing-session tables directly', () {
      for (final path in const [
        'lib/analytics_studio_view.dart',
        'lib/manuscript_studio.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('writingSessionRows')), reason: path);
        expect(
          source,
          isNot(contains('writingSessionsForProject')),
          reason: path,
        );
        expect(source, isNot(contains('putWritingSession')), reason: path);
      }
    });

    test('the World Board was not modified for this milestone', () {
      final view =
          File('lib/world_board/world_board_view.dart').readAsStringSync();
      final service =
          File('lib/world_board/world_board_service.dart').readAsStringSync();
      final models =
          File('lib/world_board/world_board_models.dart').readAsStringSync();

      for (final source in [view, service, models]) {
        expect(source, isNot(contains('WritingSession')));
        expect(source, isNot(contains('writingHistory')));
      }
    });
  });
}
