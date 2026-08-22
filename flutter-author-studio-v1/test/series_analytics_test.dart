import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:author_studio_v1/series_analytics_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// `count` words of scene content, so word totals are exact by construction.
String _words(int count) =>
    List<String>.generate(count, (index) => 'word${index + 1}').join(' ');

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore manuscriptStore;
  late ProjectRosterStore roster;
  late SeriesAnalyticsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
    roster = ProjectRosterStore(repository: repository);
    service = SeriesAnalyticsService(
      repository: repository,
      manuscriptStore: manuscriptStore,
      rosterStore: roster,
    );
  });

  tearDown(() => database.close());

  /// Stores a manuscript of exactly [words] words for [projectId].
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

  /// A series of books with the given goals, in order.
  Future<void> buildSeries(
    List<({String id, int goal})> books, {
    String seriesId = 'series-1',
    String name = 'Endovier Chronicles',
    int defaultTarget = 0,
  }) async {
    await roster.saveSeries(
      WritingSeries(
        id: seriesId,
        name: name,
        defaultTargetWords: defaultTarget,
      ),
    );
    for (final book in books) {
      await roster.save(_project(book.id, wordGoal: book.goal));
      await roster.addBookToSeries(projectId: book.id, seriesId: seriesId);
    }
  }

  group('the spec\'s own series', () {
    test('three books read 100%, 72% and 31%', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
        (id: 'book-3', goal: 1000),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 720);
      await writeManuscript('book-3', 310);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.series.name, 'Endovier Chronicles');
      expect(analytics.books.map((book) => book.bookNumber), [1, 2, 3]);
      expect(
        analytics.books.map((book) => book.percent!.round()),
        [100, 72, 31],
      );
    });

    test('a book never opened still appears, at nothing written', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
      ]);
      await writeManuscript('book-1', 500);

      final analytics = (await service.forProject('book-1'))!;
      final unwritten = analytics.books.last;

      expect(analytics.bookCount, 2);
      expect(unwritten.hasManuscript, isFalse);
      expect(unwritten.wordCount, 0);
      expect(unwritten.isStarted, isFalse);
      expect(unwritten.progress, 0.0);
      expect(analytics.startedBookCount, 1);
    });
  });

  group('book progress', () {
    test('a book with no target has no percentage at all', () async {
      await buildSeries([(id: 'book-1', goal: 0)]);
      await writeManuscript('book-1', 500);

      final book = (await service.forProject('book-1'))!.books.single;

      expect(book.hasTarget, isFalse);
      expect(book.progress, isNull);
      expect(book.percent, isNull);
      expect(book.wordsRemaining, isNull);
      expect(book.isComplete, isFalse);
      expect(book.wordCount, 500, reason: 'The words are still real.');
    });

    test('a negative goal reads as no target', () async {
      await buildSeries([(id: 'book-1', goal: -1)]);

      expect((await service.forProject('book-1'))!.books.single.hasTarget,
          isFalse);
    });

    test('overshooting a target clamps at 100% and completes', () async {
      await buildSeries([(id: 'book-1', goal: 1000)]);
      await writeManuscript('book-1', 1500);

      final book = (await service.forProject('book-1'))!.books.single;

      expect(book.progress, 1.0);
      expect(book.percent, 100.0);
      expect(book.wordsRemaining, 0);
      expect(book.isComplete, isTrue);
    });

    test('words remaining counts down and never goes negative', () async {
      await buildSeries([(id: 'book-1', goal: 1000)]);
      await writeManuscript('book-1', 400);

      expect(
        (await service.forProject('book-1'))!.books.single.wordsRemaining,
        600,
      );
    });

    test('book numbers are the reading order, whatever is stored', () async {
      await buildSeries([
        (id: 'book-a', goal: 1000),
        (id: 'book-b', goal: 1000),
        (id: 'book-c', goal: 1000),
      ]);
      await roster.reorderBooks('series-1', ['book-c', 'book-a', 'book-b']);

      final analytics = (await service.forProject('book-a'))!;

      expect(analytics.books.map((book) => book.projectId),
          ['book-c', 'book-a', 'book-b']);
      expect(analytics.books.map((book) => book.bookNumber), [1, 2, 3]);
    });

    test('a book carries the title its project has', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier Chronicles',
          defaultTargetWords: 0,
        ),
      );
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.addBookToSeries(
          projectId: 'book-1', seriesId: 'series-1');

      expect(
        (await service.forProject('book-1'))!.books.single.title,
        'Throne of Ash',
      );
    });
  });

  group('the series as a whole', () {
    test('totals count every book, targets only the targeted ones', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 0),
      ]);
      await writeManuscript('book-1', 400);
      await writeManuscript('book-2', 600);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.totalWords, 1000, reason: 'Every word is real.');
      expect(analytics.totalTargetWords, 1000);
      expect(analytics.targetedWords, 400);
      expect(analytics.seriesProgress, 0.4);
    });

    test('an untargeted book never pushes the series past 100%', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 0),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 5000);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.seriesProgress, 1.0);
      expect(analytics.seriesPercent, 100.0);
    });

    test('a mixed series reports that its bar covers only part of it',
        () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 0),
      ]);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.hasPartialTargets, isTrue);
      expect(analytics.targetedBookCount, 1);
      expect(analytics.untargetedBookCount, 1);
    });

    test('a fully targeted series does not claim partial coverage', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
      ]);

      expect(
        (await service.forProject('book-1'))!.hasPartialTargets,
        isFalse,
      );
    });

    test('a series with no targets anywhere has no percentage', () async {
      await buildSeries([
        (id: 'book-1', goal: 0),
        (id: 'book-2', goal: 0),
      ]);
      await writeManuscript('book-1', 500);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.hasTargets, isFalse);
      expect(analytics.seriesProgress, isNull);
      expect(analytics.seriesPercent, isNull);
      expect(analytics.wordsRemaining, isNull);
      expect(analytics.hasPartialTargets, isFalse);
    });

    test('completed books are counted', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
        (id: 'book-3', goal: 1000),
      ]);
      await writeManuscript('book-1', 1000);
      await writeManuscript('book-2', 720);

      final analytics = (await service.forProject('book-1'))!;

      expect(analytics.completedBookCount, 1);
      expect(analytics.startedBookCount, 2);
    });

    test('words remaining across the series counts down', () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
      ]);
      await writeManuscript('book-1', 400);

      expect((await service.forProject('book-1'))!.wordsRemaining, 1600);
    });
  });

  group('standalone projects', () {
    test('a project in no series reports no series at all', () async {
      await roster.save(_project('solo'));

      expect(await service.forProject('solo'), isNull);
    });

    test('a project not even on the roster reports no series', () async {
      expect(await service.forProject('unknown'), isNull);
    });
  });

  group('reading a series writes nothing', () {
    test('surveying a series seeds no manuscript for an unstarted book',
        () async {
      await buildSeries([
        (id: 'book-1', goal: 1000),
        (id: 'book-2', goal: 1000),
        (id: 'book-3', goal: 1000),
      ]);
      await writeManuscript('book-1', 500);

      final preferences = await SharedPreferences.getInstance();
      Future<Map<String, int>> graphTruth() async {
        final snapshot = await repository.snapshot();
        return {
          'records': snapshot.records.length,
          'links': snapshot.links.length,
          'versions': snapshot.versions.length,
          'auditEvents': snapshot.auditEvents.length,
          'manuscriptNodes': snapshot.manuscriptNodes.length,
        };
      }

      final keysBefore = preferences.getKeys().toSet();
      final truthBefore = await graphTruth();
      final rosterBefore =
          (await repository.projectRoster()).map((e) => e.projectId).toList();

      // Twice: nothing settles after the first read, because nothing writes.
      await service.forProject('book-1');
      await service.forProject('book-1');

      expect(preferences.getKeys().toSet(), keysBefore);
      expect(await graphTruth(), truthBefore);
      expect(
        (await repository.projectRoster()).map((e) => e.projectId).toList(),
        rosterBefore,
      );
      expect(
        preferences.getString('author_studio.manuscript_studio.book-2'),
        isNull,
        reason: 'Drawing a progress bar must not bring a manuscript into '
            'existence for a book the author has not begun.',
      );
    });

    test('the same read through AnalyticsService does seed — which is why '
        'peekStudio exists', () async {
      // The contrast that makes the guard above load-bearing. This is risk
      // R-21: AnalyticsService goes through loadStudio, which seeds a starter
      // manuscript for a project that has never been opened. That is
      // acceptable for the one project the author just opened, and is exactly
      // what must not happen once per book across a whole series.
      await buildSeries([(id: 'book-2', goal: 1000)]);
      final preferences = await SharedPreferences.getInstance();

      expect(
        preferences.getString('author_studio.manuscript_studio.book-2'),
        isNull,
      );

      await AnalyticsService(
        project: _project('book-2'),
        repository: repository,
        manuscriptStore: manuscriptStore,
      ).getSummary();

      expect(
        preferences.getString('author_studio.manuscript_studio.book-2'),
        isNotNull,
        reason: 'If this ever stops seeding, the peekStudio guard is no '
            'longer load-bearing and this whole pair of tests can go.',
      );
    });

    test('a malformed manuscript reads as unstarted rather than throwing',
        () async {
      await buildSeries([(id: 'book-1', goal: 1000)]);
      SharedPreferences.setMockInitialValues({
        'author_studio.manuscript_studio.book-1': '{not json',
      });

      final book = (await service.forProject('book-1'))!.books.single;

      expect(book.hasManuscript, isFalse);
      expect(book.wordCount, 0);
    });
  });

  group('architecture', () {
    /// Source with comments stripped, so a rule can be described in prose
    /// without the prose tripping the rule.
    String codeOf(String path) => File(path)
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('///'))
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('series analytics reads manuscripts without ever writing one', () {
      final source = codeOf('lib/series_analytics_service.dart');

      expect(source, contains('peekStudio('));
      expect(source, isNot(contains('loadStudio(')));
      expect(source, isNot(contains('saveStudio(')));
      expect(source, isNot(contains('loadLegacyChapterSeeds')));
    });

    test('series analytics owns no storage and writes no records', () {
      final source = codeOf('lib/series_analytics_service.dart');

      for (final forbidden in const [
        'SharedPreferences',
        'extends Table',
        '@DriftDatabase',
        'NativeDatabase',
        'createRecord(',
        'updateRecord(',
        'deleteRecord(',
        'putRecord',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('the peek is the read-only counterpart, and says so', () {
      final source = File('lib/manuscript_store.dart').readAsStringSync();

      expect(source, contains('Future<ManuscriptProjectSummary?> peekStudio'));
      expect(source, contains('R-21'));
    });

    test('the per-project summary is still declared in one place only', () {
      final declarations = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('class AnalyticsSummary {') ||
            source.contains('class AnalyticsChapterStat {')) {
          declarations.add(entity.path);
        }
      }

      expect(declarations, ['lib/analytics_service.dart']);
    });
  });
}
