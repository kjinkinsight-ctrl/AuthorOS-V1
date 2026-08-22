import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/analytics_studio_view.dart';
import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:author_studio_v1/series_analytics_service.dart';
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

final today = DateTime(2026, 8, 20, 14, 30);
final timestamp = DateTime.utc(2026, 8, 20, 10);

StarterProject _project(String id, {String? title, int wordGoal = 1000}) =>
    StarterProject(
      id: id,
      title: title ?? id,
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
  late ProjectRosterStore roster;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
    roster = ProjectRosterStore(repository: repository);
  });

  tearDown(() => database.close());

  Future<void> writeManuscript(String projectId, int words) =>
      manuscriptStore.saveStudio(
        ManuscriptProjectSummary(
          projectId: projectId,
          manuscriptTitle: projectId,
          chapters: [
            ManuscriptChapter(
              id: '$projectId-ch-1',
              title: 'Chapter One',
              order: 1,
              status: ManuscriptNodeStatus.draft,
              scenes: [
                ManuscriptScene(
                  id: '$projectId-sc-1',
                  chapterId: '$projectId-ch-1',
                  title: 'Scene',
                  order: 1,
                  content: _words(words),
                  status: ManuscriptNodeStatus.draft,
                  createdAt: timestamp,
                  updatedAt: timestamp,
                ),
              ],
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          ],
          currentChapterId: '$projectId-ch-1',
          currentSceneId: '$projectId-sc-1',
          createdAt: timestamp,
          updatedAt: timestamp,
          version: 2,
        ),
        persistLegacyText: false,
      );

  Future<void> buildSeries(
    List<({String id, String title, int goal})> books, {
    String name = 'Endovier Chronicles',
  }) async {
    await roster.saveSeries(
      WritingSeries(id: 'series-1', name: name, defaultTargetWords: 0),
    );
    for (final book in books) {
      await roster.save(
        _project(book.id, title: book.title, wordGoal: book.goal),
      );
      await roster.addBookToSeries(
          projectId: book.id, seriesId: 'series-1');
    }
  }

  Future<void> pumpView(
    WidgetTester tester,
    String projectId, {
    SeriesAnalyticsService? seriesService,
  }) async {
    tester.view.physicalSize = const Size(1400, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = _project(projectId);
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
                service: AnalyticsService(
                  project: project,
                  repository: repository,
                  manuscriptStore: manuscriptStore,
                  clock: () => today,
                ),
                seriesService: seriesService ??
                    SeriesAnalyticsService(
                      repository: repository,
                      manuscriptStore: manuscriptStore,
                      rosterStore: roster,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Matches inside the keyed widget, or the keyed widget itself: several of
  /// these keys sit directly on the Text being asserted on.
  Finder inKey(String key, Finder finder) => find.descendant(
        of: find.byKey(Key(key)),
        matching: finder,
        matchRoot: true,
      );

  Finder inSeries(Finder finder) =>
      inKey('analytics-series-section', finder);

  group('the spec layout', () {
    testWidgets('three books render as BOOK 1, 2, 3 at 100%, 72% and 31%',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'Throne of Ash', goal: 1000),
        (id: 'book-2', title: 'Crown of Salt', goal: 1000),
        (id: 'book-3', title: 'Court of Embers', goal: 1000),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 720);
      await writeManuscript('book-3', 310);

      await pumpView(tester, 'book-1');

      expect(find.byKey(const Key('analytics-series-section')), findsOneWidget);
      expect(
        inSeries(find.text('ENDOVIER CHRONICLES')),
        findsOneWidget,
      );
      for (final (index, id) in ['book-1', 'book-2', 'book-3'].indexed) {
        expect(
          inKey('analytics-series-book-label-$id', find.text('BOOK ${index + 1}')),
          findsOneWidget,
        );
      }
      expect(inKey('analytics-series-book-percent-book-1', find.text('100%')),
          findsOneWidget);
      expect(inKey('analytics-series-book-percent-book-2', find.text('72%')),
          findsOneWidget);
      expect(inKey('analytics-series-book-percent-book-3', find.text('31%')),
          findsOneWidget);
    });

    testWidgets('each book draws a bar at its own progress', (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 1000),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 720);

      await pumpView(tester, 'book-1');

      final bars = tester
          .widgetList<LinearProgressIndicator>(
            inSeries(find.byType(LinearProgressIndicator)),
          )
          .toList();
      // Two books plus the series roll-up.
      expect(bars, hasLength(3));
      expect(bars[0].value, 1.0);
      expect(bars[1].value, closeTo(0.72, 0.0001));
    });

    testWidgets('book titles and word counts render', (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'Throne of Ash', goal: 1000),
      ]);
      await writeManuscript('book-1', 720);

      await pumpView(tester, 'book-1');

      expect(inSeries(find.text('Throne of Ash')), findsOneWidget);
      expect(
        inKey('analytics-series-book-words-book-1', find.text('720 words')),
        findsOneWidget,
      );
    });
  });

  group('honest empty and partial states', () {
    testWidgets('a standalone project is told it is not in a series',
        (tester) async {
      await roster.save(_project('solo'));

      await pumpView(tester, 'solo');

      expect(find.byKey(const Key('analytics-series-empty')), findsOneWidget);
      expect(
        find.textContaining('not part of a series'),
        findsOneWidget,
      );
      expect(inSeries(find.byType(LinearProgressIndicator)), findsNothing);
    });

    testWidgets('an unstarted book reads Not started, not a fake zero',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 1000),
      ]);
      await writeManuscript('book-1', 500);

      await pumpView(tester, 'book-1');

      expect(
        inKey('analytics-series-book-words-book-2', find.text('Not started')),
        findsOneWidget,
      );
      expect(inKey('analytics-series-book-percent-book-2', find.text('0%')),
          findsOneWidget);
    });

    testWidgets('a book with no goal gets no bar and no percentage',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 0),
      ]);
      await writeManuscript('book-1', 500);
      await writeManuscript('book-2', 900);

      await pumpView(tester, 'book-1');

      expect(
        find.byKey(const Key('analytics-series-book-no-target-book-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-series-book-bar-book-2')),
        findsNothing,
      );
      expect(inKey('analytics-series-book-percent-book-2', find.text('—')),
          findsOneWidget);
      // Its words are still shown: they are real.
      expect(
        inKey('analytics-series-book-words-book-2', find.text('900 words')),
        findsOneWidget,
      );
    });

    testWidgets('a mixed series says its bar covers only part of it',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 0),
      ]);

      await pumpView(tester, 'book-1');

      expect(
        find.byKey(const Key('analytics-series-partial-targets')),
        findsOneWidget,
      );
      expect(find.textContaining('1 of 2 books have a word goal'),
          findsOneWidget);
    });

    testWidgets('a fully targeted series makes no partial claim',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 1000),
      ]);

      await pumpView(tester, 'book-1');

      expect(
        find.byKey(const Key('analytics-series-partial-targets')),
        findsNothing,
      );
    });

    testWidgets('a series with no goals anywhere draws no series bar',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 0),
        (id: 'book-2', title: 'Two', goal: 0),
      ]);
      await writeManuscript('book-1', 500);

      await pumpView(tester, 'book-1');

      expect(
        find.byKey(const Key('analytics-series-total-bar')),
        findsNothing,
      );
      expect(inKey('analytics-series-total-percent', find.text('—')),
          findsOneWidget);
      expect(inSeries(find.byType(LinearProgressIndicator)), findsNothing);
    });
  });

  group('the series roll-up', () {
    testWidgets('totals the words and counts the completed books',
        (tester) async {
      await buildSeries([
        (id: 'book-1', title: 'One', goal: 1000),
        (id: 'book-2', title: 'Two', goal: 1000),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 500);

      await pumpView(tester, 'book-1');

      expect(inKey('analytics-series-total-percent', find.text('75%')),
          findsOneWidget);
      expect(
        find.textContaining('1,500 words across 2 books'),
        findsOneWidget,
      );
      expect(find.textContaining('1 complete'), findsOneWidget);
    });
  });

  group('failure', () {
    testWidgets('a series failure stays inside its own card', (tester) async {
      await roster.save(_project('book-1'));

      await pumpView(
        tester,
        'book-1',
        seriesService: _ThrowingSeriesService(
          repository: repository,
          manuscriptStore: manuscriptStore,
        ),
      );

      expect(find.byKey(const Key('analytics-series-error')), findsOneWidget);
      // The rest of the page is unharmed.
      expect(find.byKey(const Key('analytics-studio')), findsOneWidget);
      expect(find.byKey(const Key('analytics-word-count-card')), findsOneWidget);
      expect(
        find.byKey(const Key('analytics-progress-section')),
        findsOneWidget,
      );
    });
  });

  group('architecture', () {
    test('the Analytics view still reaches no database and owns no palette',
        () {
      final source = File('lib/analytics_studio_view.dart').readAsStringSync();

      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'package:drift")));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('ThemeData(')));
      // The series card reads through the service, never the roster tables.
      expect(source, isNot(contains('projectRoster')));
      expect(source, isNot(contains('booksInSeries')));
      expect(source, isNot(contains('peekStudio')));
    });

    test('the series card added no charting dependency', () {
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

/// A series service that fails, so the card's own error path can be tested
/// without breaking the repository underneath it.
class _ThrowingSeriesService extends SeriesAnalyticsService {
  const _ThrowingSeriesService({
    required DriftConnectedDomainRepository super.repository,
    required super.manuscriptStore,
  });

  @override
  Future<SeriesAnalytics?> forProject(String projectId) async =>
      throw StateError('the roster is unreadable');
}
