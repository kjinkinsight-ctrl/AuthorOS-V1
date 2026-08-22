import 'dart:io';

import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/writing_goals_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late WritingGoalsStore store;

  setUp(() {
    // Saving a goal now also queues it for other devices, and the queue lives
    // in SharedPreferences. Without the mock every save would hit an
    // unregistered plugin — the recorder swallows the error, so the tests
    // would still pass, which is exactly the kind of green that hides a bug.
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = WritingGoalsStore(repository: repository);
  });

  tearDown(() async {
    await database.close();
  });

  group('defaults', () {
    test('a project with no stored goals loads the seeded targets', () async {
      final goals = await store.load('project-a');

      expect(goals.projectId, 'project-a');
      expect(goals.dailyWords, 2000);
      expect(goals.weeklyWords, 10000);
      expect(goals.monthlyWords, 40000);
      expect(goals.updatedAt, isNull);
    });

    test('loading never writes a row', () async {
      await store.load('project-a');

      expect(await repository.writingGoalsForProject('project-a'), isNull);
    });

    test('the repository reports absence rather than inventing defaults',
        () async {
      expect(await repository.writingGoalsForProject('project-a'), isNull);
    });
  });

  group('saving', () {
    test('stored goals come back with every target', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(
          dailyWords: 1500,
          weeklyWords: 9000,
          monthlyWords: 30000,
        ),
      );

      final reloaded = await store.load('project-a');

      expect(reloaded.dailyWords, 1500);
      expect(reloaded.weeklyWords, 9000);
      expect(reloaded.monthlyWords, 30000);
    });

    test('saving stamps an edit instant even when none was supplied', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );

      expect((await store.load('project-a')).updatedAt, isNotNull);
    });

    test('saving twice overwrites rather than appending', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 2500),
      );

      final reloaded = await store.load('project-a');

      expect(reloaded.dailyWords, 2500);
      final rows = await database.select(database.writingGoalRows).get();
      expect(rows, hasLength(1));
    });

    test('save returns exactly what was stored', () async {
      final returned = await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: -500),
      );

      expect(returned.dailyWords, 0);
      expect((await store.load('project-a')).dailyWords, 0);
    });

    test('a negative target is floored before it reaches the database',
        () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(
          dailyWords: -500,
          weeklyWords: -1,
        ),
      );

      final reloaded = await store.load('project-a');

      expect(reloaded.dailyWords, 0);
      expect(reloaded.weeklyWords, 0);
    });

    test('an absurd target is capped before it reaches the database',
        () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 50000000),
      );

      expect(
        (await store.load('project-a')).dailyWords,
        WritingGoals.maximumWords,
      );
    });
  });

  group('restoring defaults', () {
    test('drops the row so the project reads as never customized', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );

      final restored = await store.restoreDefaults('project-a');

      expect(restored.dailyWords, 2000);
      expect(await repository.writingGoalsForProject('project-a'), isNull);
      expect((await store.load('project-a')).updatedAt, isNull);
    });

    test('restoring a project that was never customized is harmless',
        () async {
      final restored = await store.restoreDefaults('project-a');

      expect(restored, WritingGoals.defaultsFor('project-a'));
    });
  });

  group('project isolation', () {
    test('one project never sees another project\'s goals', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );
      await store.save(
        WritingGoals.defaultsFor('project-b').copyWith(dailyWords: 3000),
      );

      expect((await store.load('project-a')).dailyWords, 1500);
      expect((await store.load('project-b')).dailyWords, 3000);
    });

    test('deleting one project\'s goals leaves the other intact', () async {
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );
      await store.save(
        WritingGoals.defaultsFor('project-b').copyWith(dailyWords: 3000),
      );

      final removed =
          await repository.deleteWritingGoalsForProject('project-a');

      expect(removed, 1);
      expect((await store.load('project-a')).dailyWords, 2000);
      expect((await store.load('project-b')).dailyWords, 3000);
    });
  });

  group('durability', () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('authoros-goals-');
      databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}authoros.sqlite',
      );
    });

    tearDown(() async {
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('goals survive closing and reopening the database', () async {
      final first = AuthorOsDatabase(NativeDatabase(databaseFile));
      await WritingGoalsStore(
        repository: DriftConnectedDomainRepository(first),
      ).save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );
      await first.close();

      final second = AuthorOsDatabase(NativeDatabase(databaseFile));
      final reopened = await WritingGoalsStore(
        repository: DriftConnectedDomainRepository(second),
      ).load('project-a');

      expect(reopened.dailyWords, 1500);
      await second.close();
    });

    test('a database created before writing goals migrates forward', () async {
      final legacy = AuthorOsDatabase(
        NativeDatabase(databaseFile),
        schemaVersion: 9,
      );
      // Touch the database so onCreate really runs and stamps it at v9.
      await legacy.customSelect('SELECT 1').get();
      // onCreate builds every table this build declares, so drop the goals
      // table to leave a file genuinely shaped the way v9 shipped. Without
      // this the reopen below would find the table already there and the
      // migration branch would never be the thing under test.
      await legacy.customStatement('DROP TABLE IF EXISTS writing_goal_rows');
      await legacy.close();

      final upgraded = AuthorOsDatabase(NativeDatabase(databaseFile));
      final store = WritingGoalsStore(
        repository: DriftConnectedDomainRepository(upgraded),
      );

      // The v9 -> v10 branch created the table on open.
      final tables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'writing_goal_rows'",
          )
          .get();
      expect(tables, hasLength(1));

      expect((await store.load('project-a')).dailyWords, 2000);
      await store.save(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500),
      );
      expect((await store.load('project-a')).dailyWords, 1500);

      await upgraded.close();
    });

    test('the schema carries the writing-goals table', () {
      expect(
        AuthorOsDatabase.currentSchemaVersion,
        greaterThanOrEqualTo(10),
      );
    });
  });

  group('architecture', () {
    test('writing goals live in the canonical AuthorOS database', () {
      final source =
          File('lib/persistence/authoros_database.dart').readAsStringSync();

      expect(source, contains('class WritingGoalRows extends Table'));
      expect(source, contains('writingGoalsForProject'));
      expect(source, contains('putWritingGoals'));
      expect(source, isNot(contains('SharedPreferences')));
    });

    test('goals are not stored in preferences anywhere', () {
      final libraries = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libraries) {
        final source = file.readAsStringSync();
        if (!source.contains('SharedPreferences')) continue;
        expect(
          source,
          isNot(contains('WritingGoals')),
          reason: '${file.path} must not store goals in preferences',
        );
      }
    });

    test('the store owns the defaults, and nothing else decides them', () {
      final store = File('lib/writing_goals_store.dart').readAsStringSync();
      final model = File('lib/core/writing_goals.dart').readAsStringSync();

      expect(store, contains('WritingGoals.defaultsFor'));
      // The seeded numbers are written down once, in the domain model.
      expect(model, contains('dailyWords: 2000'));
      expect(store, isNot(contains('2000')));
    });
  });
}
