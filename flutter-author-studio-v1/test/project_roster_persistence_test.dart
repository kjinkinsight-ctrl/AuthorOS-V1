import 'dart:io';

import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

StarterProject _project(
  String id, {
  String title = 'The Hollow Court',
  int wordGoal = 80000,
}) =>
    StarterProject(
      id: id,
      title: title,
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

WritingSeries _series(
  String id, {
  String name = 'Endovier Chronicles',
  int defaultTargetWords = 90000,
}) =>
    WritingSeries(
      id: id,
      name: name,
      defaultTargetWords: defaultTargetWords,
    );

WritingSession _sessionFor(String projectId) => WritingSession(
      id: 'ws-$projectId',
      projectId: projectId,
      startedAt: DateTime(2026, 8, 20, 9),
      endedAt: DateTime(2026, 8, 20, 10),
      startingWordCount: 0,
      endingWordCount: 500,
      wordsAdded: 500,
      wordsRemoved: 0,
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ProjectRosterStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ProjectRosterStore(repository: repository);
  });

  tearDown(() async {
    await database.close();
  });

  group('the roster holds more than one project', () {
    test('two projects coexist, which was impossible before the roster',
        () async {
      await store.save(_project('book-1', title: 'Book One'));
      await store.save(_project('book-2', title: 'Book Two'));

      final roster = await store.load();

      expect(roster, hasLength(2));
      expect(
        roster.map((entry) => entry.title),
        containsAll(['Book One', 'Book Two']),
      );
    });

    test('saving the same id updates rather than duplicating', () async {
      await store.save(_project('book-1', title: 'Working Title'));
      await store.save(_project('book-1', title: 'Real Title'));

      final roster = await store.load();

      expect(roster, hasLength(1));
      expect(roster.single.title, 'Real Title');
    });

    test('a saved project keeps its series membership', () async {
      await store.saveSeries(_series('series-1'));
      await store.save(_project('book-1'));
      await store.addBookToSeries(projectId: 'book-1', seriesId: 'series-1');

      await store.save(_project('book-1', title: 'Renamed'));

      final entry = await repository.projectRosterEntry('book-1');
      expect(entry?.seriesId, 'series-1');
      expect(entry?.seriesPosition, 0);
      expect(entry?.title, 'Renamed');
    });

    test('removing a project is roster-only and touches no writing', () async {
      await store.save(_project('book-1'));
      await repository.putWritingSession(
        // A recorded session for the project being removed.
        _sessionFor('book-1'),
      );

      await store.remove('book-1');

      expect(await store.load(), isEmpty);
      expect(
        await repository.writingSessionsForProject('book-1'),
        hasLength(1),
        reason: 'Removing a roster entry must never destroy writing history.',
      );
    });
  });

  group('legacy adoption', () {
    test('the pre-roster project is adopted on first load', () async {
      const onboarding = OnboardingStoreDouble('legacy-1', 'Hidden Draft');
      final store = ProjectRosterStore(
        repository: repository,
        onboardingStore: onboarding,
      );

      final roster = await store.load();

      expect(roster, hasLength(1));
      expect(roster.single.projectId, 'legacy-1');
      expect(roster.single.title, 'Hidden Draft');
      expect(roster.single.isBook, isFalse);
    });

    test('adoption never duplicates across repeated loads', () async {
      const onboarding = OnboardingStoreDouble('legacy-1', 'Hidden Draft');
      final store = ProjectRosterStore(
        repository: repository,
        onboardingStore: onboarding,
      );

      await store.load();
      await store.load();
      await store.load();

      expect(await store.load(), hasLength(1));
    });

    test('adoption does not fire once the roster has any project', () async {
      const onboarding = OnboardingStoreDouble('legacy-1', 'Hidden Draft');
      final store = ProjectRosterStore(
        repository: repository,
        onboardingStore: onboarding,
      );
      await store.save(_project('book-1'));

      final roster = await store.load();

      expect(roster.map((entry) => entry.projectId), ['book-1']);
    });

    test('an install with no project at all adopts nothing', () async {
      final roster = await store.load();

      expect(roster, isEmpty);
    });
  });

  group('series membership', () {
    setUp(() async {
      await store.saveSeries(_series('series-1'));
    });

    test('books are ordered by position, not by insertion', () async {
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      final books = await store.books('series-1');

      expect(books.map((book) => book.projectId),
          ['book-a', 'book-b', 'book-c']);
      expect(books.map((book) => book.seriesPosition), [0, 1, 2]);
      expect(books.map((book) => book.bookNumber), [1, 2, 3]);
    });

    test('a book can be inserted at a position', () async {
      for (final id in ['book-a', 'book-c']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }
      await store.save(_project('book-b', title: 'book-b'));
      await store.addBookToSeries(
        projectId: 'book-b',
        seriesId: 'series-1',
        position: 1,
      );

      expect(
        (await store.books('series-1')).map((book) => book.projectId),
        ['book-a', 'book-b', 'book-c'],
      );
    });

    test('reordering rewrites positions densely from zero', () async {
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await store.reorderBooks('series-1', ['book-c', 'book-a', 'book-b']);

      final books = await store.books('series-1');
      expect(books.map((book) => book.projectId),
          ['book-c', 'book-a', 'book-b']);
      expect(books.map((book) => book.seriesPosition), [0, 1, 2]);
    });

    test('a reorder that omits a book keeps it, rather than dropping it',
        () async {
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      // A stale screen sends only two of the three ids.
      await store.reorderBooks('series-1', ['book-c', 'book-a']);

      final books = await store.books('series-1');
      expect(books.map((book) => book.projectId),
          ['book-c', 'book-a', 'book-b']);
      expect(books, hasLength(3));
    });

    test('removing a book closes the gap behind it', () async {
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await store.removeBookFromSeries('book-a');

      final books = await store.books('series-1');
      expect(books.map((book) => book.projectId), ['book-b', 'book-c']);
      expect(books.map((book) => book.seriesPosition), [0, 1]);

      final released = await repository.projectRosterEntry('book-a');
      expect(released, isNotNull, reason: 'The project stays on the roster.');
      expect(released!.isBook, isFalse);
    });

    test('deleting a series releases its books without deleting them',
        () async {
      for (final id in ['book-a', 'book-b']) {
        await store.save(_project(id, title: id));
        await store.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await store.deleteSeries('series-1');

      expect(await store.seriesById('series-1'), isNull);
      final roster = await store.load();
      expect(roster, hasLength(2));
      expect(roster.every((entry) => !entry.isBook), isTrue);
    });

    test('seriesForProject finds the series, or null when standalone',
        () async {
      await store.save(_project('book-a'));
      await store.save(_project('solo'));
      await store.addBookToSeries(projectId: 'book-a', seriesId: 'series-1');

      expect((await store.seriesForProject('book-a'))?.id, 'series-1');
      expect(await store.seriesForProject('solo'), isNull);
    });

    test('adding an unknown project or an unknown series is refused',
        () async {
      await store.save(_project('book-a'));

      expect(
        () => store.addBookToSeries(
            projectId: 'nope', seriesId: 'series-1'),
        throwsStateError,
      );
      expect(
        () => store.addBookToSeries(
            projectId: 'book-a', seriesId: 'nope'),
        throwsStateError,
      );
    });
  });

  group('targets', () {
    test('a book with no target inherits the series default', () async {
      await store.saveSeries(_series('series-1', defaultTargetWords: 90000));
      await store.save(_project('book-a', wordGoal: 0));

      final book = await store.addBookToSeries(
        projectId: 'book-a',
        seriesId: 'series-1',
      );

      expect(book.targetWords, 90000);
      expect(book.project.wordGoal, 90000);
    });

    test('a book that already has a target keeps it', () async {
      await store.saveSeries(_series('series-1', defaultTargetWords: 90000));
      await store.save(_project('book-a', wordGoal: 120000));

      final book = await store.addBookToSeries(
        projectId: 'book-a',
        seriesId: 'series-1',
      );

      expect(
        book.targetWords,
        120000,
        reason: 'Joining a series must not rewrite a target the author chose.',
      );
    });

    test('a series with no default leaves an untargeted book untargeted',
        () async {
      await store.saveSeries(_series('series-1', defaultTargetWords: 0));
      await store.save(_project('book-a', wordGoal: 0));

      final book = await store.addBookToSeries(
        projectId: 'book-a',
        seriesId: 'series-1',
      );

      expect(book.targetWords, 0);
    });

    test('books in one series can hold different targets', () async {
      await store.saveSeries(_series('series-1', defaultTargetWords: 90000));
      await store.save(_project('book-a', wordGoal: 0));
      await store.save(_project('book-b', wordGoal: 120000));
      await store.addBookToSeries(projectId: 'book-a', seriesId: 'series-1');
      await store.addBookToSeries(projectId: 'book-b', seriesId: 'series-1');

      final books = await store.books('series-1');

      expect(books.map((book) => book.targetWords), [90000, 120000]);
    });

    test('a negative project goal reads as no target', () async {
      await store.save(_project('book-a', wordGoal: -1));

      final entry = await repository.projectRosterEntry('book-a');

      expect(entry!.targetWords, 0);
    });
  });

  group('series storage', () {
    test('a series round-trips', () async {
      await store.saveSeries(_series('series-1', name: 'Endovier Chronicles'));

      final loaded = await store.seriesById('series-1');

      expect(loaded?.name, 'Endovier Chronicles');
      expect(loaded?.defaultTargetWords, 90000);
      expect(loaded?.updatedAt, isNotNull);
    });

    test('saving normalizes the name and the target', () async {
      final saved = await store.saveSeries(
        _series('series-1', name: '  Spaced  ', defaultTargetWords: -5),
      );

      expect(saved.name, 'Spaced');
      expect(saved.defaultTargetWords, 0);
      expect((await store.seriesById('series-1'))?.name, 'Spaced');
    });

    test('an absurd default target is capped', () async {
      final saved = await store.saveSeries(
        _series('series-1', defaultTargetWords: 50000000),
      );

      expect(saved.defaultTargetWords, WritingSeries.maximumTargetWords);
    });

    test('several series coexist', () async {
      await store.saveSeries(_series('series-1', name: 'One'));
      await store.saveSeries(_series('series-2', name: 'Two'));

      expect(await store.allSeries(), hasLength(2));
    });
  });

  group('durability', () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('authoros-roster-');
      databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}authoros.sqlite',
      );
    });

    tearDown(() async {
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('the roster survives closing and reopening the database', () async {
      final first = AuthorOsDatabase(NativeDatabase(databaseFile));
      final firstStore = ProjectRosterStore(
        repository: DriftConnectedDomainRepository(first),
      );
      await firstStore.saveSeries(_series('series-1'));
      await firstStore.save(_project('book-a', title: 'Book A'));
      await firstStore.addBookToSeries(
          projectId: 'book-a', seriesId: 'series-1');
      await first.close();

      final second = AuthorOsDatabase(NativeDatabase(databaseFile));
      final secondStore = ProjectRosterStore(
        repository: DriftConnectedDomainRepository(second),
      );

      final books = await secondStore.books('series-1');
      expect(books.single.title, 'Book A');
      expect(books.single.seriesPosition, 0);
      await second.close();
    });

    test('a database created before the roster migrates forward', () async {
      final legacy = AuthorOsDatabase(
        NativeDatabase(databaseFile),
        schemaVersion: 10,
      );
      // Touch the database so onCreate really runs and stamps it at v10.
      await legacy.customSelect('SELECT 1').get();
      // onCreate builds every table this build declares, so drop the roster
      // tables to leave a file genuinely shaped the way v10 shipped. Without
      // this the reopen below would find them already there and the migration
      // branch would never be the thing under test.
      await legacy.customStatement('DROP TABLE IF EXISTS project_rows');
      await legacy.customStatement('DROP TABLE IF EXISTS series_rows');
      await legacy.close();

      final upgraded = AuthorOsDatabase(NativeDatabase(databaseFile));
      final upgradedStore = ProjectRosterStore(
        repository: DriftConnectedDomainRepository(upgraded),
      );

      // The v10 -> v11 branch created both tables on open.
      final tables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('series_rows', 'project_rows')",
          )
          .get();
      expect(tables, hasLength(2));

      await upgradedStore.saveSeries(_series('series-1'));
      await upgradedStore.save(_project('book-a'));
      expect(await upgradedStore.load(), hasLength(1));

      await upgraded.close();
    });

    test('the schema carries the roster tables', () {
      expect(
        AuthorOsDatabase.currentSchemaVersion,
        greaterThanOrEqualTo(11),
      );
    });
  });

  group('architecture', () {
    test('the roster lives in the canonical AuthorOS database', () {
      final source =
          File('lib/persistence/authoros_database.dart').readAsStringSync();

      expect(source, contains('class SeriesRows extends Table'));
      expect(source, contains('class ProjectRows extends Table'));
      expect(source, contains('booksInSeries'));
      expect(source, isNot(contains('SharedPreferences')));
    });

    test('the roster is additive: the legacy key is still the pointer', () {
      final source = File('lib/onboarding.dart').readAsStringSync();

      expect(
        source,
        contains("_projectKey = 'author_studio.starter_project'"),
        reason: 'The pre-roster key is the active-project pointer and two '
            'existing tests depend on it surviving.',
      );
    });

    test('project seed data is Flutter-free so persistence can store it', () {
      final source = File('lib/core/starter_project.dart').readAsStringSync();

      expect(source, contains('class StarterProject'));
      expect(source, isNot(contains("import 'package:flutter")));
      expect(
        File('lib/onboarding.dart').readAsStringSync(),
        contains("export 'core/starter_project.dart';"),
        reason: 'Every existing import of onboarding.dart must keep resolving '
            'StarterProject.',
      );
    });
  });
}

/// A stand-in for the pre-roster [OnboardingStore], so adoption can be tested
/// without reaching for real preferences.
class OnboardingStoreDouble implements OnboardingStore {
  const OnboardingStoreDouble(this.id, this.title);

  final String id;
  final String title;

  @override
  Future<StarterProject?> loadProject() async => _project(id, title: title);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
