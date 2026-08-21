import 'dart:io';

import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

WritingSession _session(
  String id, {
  String projectId = 'project-a',
  required DateTime startedAt,
  Duration duration = const Duration(minutes: 30),
  int startingWordCount = 0,
  int endingWordCount = 500,
  int wordsAdded = 500,
  int wordsRemoved = 0,
  String? chapterId,
  String? sceneId,
}) =>
    WritingSession(
      id: id,
      projectId: projectId,
      startedAt: startedAt,
      endedAt: startedAt.add(duration),
      duration: duration,
      startingWordCount: startingWordCount,
      endingWordCount: endingWordCount,
      wordsAdded: wordsAdded,
      wordsRemoved: wordsRemoved,
      chapterId: chapterId,
      sceneId: sceneId,
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  group('save and reload', () {
    test('a saved session comes back with every recorded value', () async {
      final session = _session(
        'ws-1',
        startedAt: DateTime(2026, 8, 20, 9, 15),
        duration: const Duration(minutes: 47),
        startingWordCount: 1200,
        endingWordCount: 1975,
        wordsAdded: 820,
        wordsRemoved: 45,
        chapterId: 'chapter-3',
        sceneId: 'scene-9',
      );

      await repository.putWritingSession(session);
      final loaded = await repository.writingSessionsForProject('project-a');

      expect(loaded, hasLength(1));
      final restored = loaded.single;
      expect(restored.id, 'ws-1');
      expect(restored.projectId, 'project-a');
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
      expect(restored.duration, const Duration(minutes: 47));
      expect(restored.startingWordCount, 1200);
      expect(restored.endingWordCount, 1975);
      expect(restored.wordsWritten, 775);
      expect(restored.wordsAdded, 820);
      expect(restored.wordsRemoved, 45);
      expect(restored.chapterId, 'chapter-3');
      expect(restored.sceneId, 'scene-9');
    });

    test('a session with no chapter or scene reloads with nulls', () async {
      await repository.putWritingSession(
        _session('ws-loose', startedAt: DateTime(2026, 8, 20, 9)),
      );

      final restored =
          (await repository.writingSessionsForProject('project-a')).single;

      expect(restored.chapterId, isNull);
      expect(restored.sceneId, isNull);
    });

    test('a project with no history reloads as an empty list', () async {
      expect(
        await repository.writingSessionsForProject('project-untouched'),
        isEmpty,
      );
    });
  });

  group('multiple sessions', () {
    test('are returned oldest first regardless of insertion order', () async {
      await repository.putWritingSession(
        _session('ws-c', startedAt: DateTime(2026, 8, 20, 16)),
      );
      await repository.putWritingSession(
        _session('ws-a', startedAt: DateTime(2026, 8, 18, 9)),
      );
      await repository.putWritingSession(
        _session('ws-b', startedAt: DateTime(2026, 8, 19, 11)),
      );

      final loaded = await repository.writingSessionsForProject('project-a');

      expect(loaded.map((session) => session.id), ['ws-a', 'ws-b', 'ws-c']);
    });

    test('a batch write persists every session in one transaction', () async {
      await repository.putWritingSessions([
        _session('ws-1', startedAt: DateTime(2026, 8, 18, 9)),
        _session('ws-2', startedAt: DateTime(2026, 8, 19, 9)),
        _session('ws-3', startedAt: DateTime(2026, 8, 20, 9)),
      ]);

      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(3),
      );
    });

    test('an empty batch write is a no-op', () async {
      await repository.putWritingSessions(const []);

      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
    });

    test('a date window narrows the query by start instant', () async {
      await repository.putWritingSessions([
        _session('ws-old', startedAt: DateTime(2026, 8, 1, 9)),
        _session('ws-mid', startedAt: DateTime(2026, 8, 15, 9)),
        _session('ws-new', startedAt: DateTime(2026, 8, 28, 9)),
      ]);

      final windowed = await repository.writingSessionsForProject(
        'project-a',
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 20),
      );

      expect(windowed.map((session) => session.id), ['ws-mid']);
    });
  });

  group('project isolation', () {
    test('one project never sees another project\'s sessions', () async {
      await repository.putWritingSessions([
        _session('ws-a1',
            projectId: 'project-a', startedAt: DateTime(2026, 8, 18, 9)),
        _session('ws-a2',
            projectId: 'project-a', startedAt: DateTime(2026, 8, 19, 9)),
        _session('ws-b1',
            projectId: 'project-b', startedAt: DateTime(2026, 8, 18, 9)),
      ]);

      final projectA = await repository.writingSessionsForProject('project-a');
      final projectB = await repository.writingSessionsForProject('project-b');

      expect(projectA.map((session) => session.id), ['ws-a1', 'ws-a2']);
      expect(projectB.map((session) => session.id), ['ws-b1']);
      expect(
        projectA.every((session) => session.projectId == 'project-a'),
        isTrue,
      );
    });

    test('deleting one project\'s history leaves the other intact', () async {
      await repository.putWritingSessions([
        _session('ws-a1',
            projectId: 'project-a', startedAt: DateTime(2026, 8, 18, 9)),
        _session('ws-b1',
            projectId: 'project-b', startedAt: DateTime(2026, 8, 18, 9)),
      ]);

      final removed =
          await repository.deleteWritingSessionsForProject('project-a');

      expect(removed, 1);
      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
      expect(
        await repository.writingSessionsForProject('project-b'),
        hasLength(1),
      );
    });
  });

  group('immutability', () {
    test('re-saving the same id never rewrites the recorded session', () async {
      final original = _session(
        'ws-fixed',
        startedAt: DateTime(2026, 8, 20, 9),
        endingWordCount: 500,
        wordsAdded: 500,
      );
      await repository.putWritingSession(original);

      // The manuscript changed later; history must not follow it.
      await repository.putWritingSession(
        original.copyWith(endingWordCount: 12000, wordsAdded: 12000),
      );

      final loaded = await repository.writingSessionsForProject('project-a');

      expect(loaded, hasLength(1));
      expect(loaded.single.endingWordCount, 500);
      expect(loaded.single.wordsWritten, 500);
    });

    test('a duplicated id can never create a second row', () async {
      final session =
          _session('ws-duplicate', startedAt: DateTime(2026, 8, 20, 9));

      await repository.putWritingSession(session);
      await repository.putWritingSession(session);
      await repository.putWritingSessions([session, session]);

      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(1),
      );
    });
  });

  group('durability', () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('authoros-sessions-');
      databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}authoros.sqlite',
      );
    });

    tearDown(() async {
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('sessions survive closing and reopening the database', () async {
      final first = AuthorOsDatabase(NativeDatabase(databaseFile));
      await DriftConnectedDomainRepository(first).putWritingSessions([
        _session('ws-1', startedAt: DateTime(2026, 8, 18, 9)),
        _session('ws-2',
            projectId: 'project-b', startedAt: DateTime(2026, 8, 19, 9)),
      ]);
      await first.close();

      final second = AuthorOsDatabase(NativeDatabase(databaseFile));
      final reopened = DriftConnectedDomainRepository(second);

      expect(
        (await reopened.writingSessionsForProject('project-a'))
            .map((session) => session.id),
        ['ws-1'],
      );
      expect(
        (await reopened.writingSessionsForProject('project-b'))
            .map((session) => session.id),
        ['ws-2'],
      );
      await second.close();
    });

    test('a database created before writing history migrates forward',
        () async {
      final legacy = AuthorOsDatabase(
        NativeDatabase(databaseFile),
        schemaVersion: 8,
      );
      // Touch the legacy database so the file is really created at v8.
      await DriftConnectedDomainRepository(legacy)
          .writingSessionsForProject('project-a')
          .catchError((Object _) => <WritingSession>[]);
      await legacy.close();

      final upgraded = AuthorOsDatabase(NativeDatabase(databaseFile));
      final repository = DriftConnectedDomainRepository(upgraded);

      await repository.putWritingSession(
        _session('ws-after-upgrade', startedAt: DateTime(2026, 8, 20, 9)),
      );

      expect(
        (await repository.writingSessionsForProject('project-a'))
            .map((session) => session.id),
        ['ws-after-upgrade'],
      );
      await upgraded.close();
    });
  });

  group('architecture', () {
    test('writing history lives in the canonical AuthorOS database', () {
      final source =
          File('lib/persistence/authoros_database.dart').readAsStringSync();

      expect(source, contains('class WritingSessionRows extends Table'));
      expect(source, contains('writingSessionsForProject'));
      expect(source, isNot(contains('SharedPreferences')));
    });

    test('no analytics-specific store or repository was introduced', () {
      final libraries = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libraries) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('class AnalyticsDatabase')),
            reason: file.path);
        expect(source, isNot(contains('class AnalyticsStore')),
            reason: file.path);
        expect(source, isNot(contains('class AnalyticsRepository')),
            reason: file.path);
      }
    });

    test('the writing-session schema version is the database\'s own', () {
      expect(AuthorOsDatabase.currentSchemaVersion, greaterThanOrEqualTo(9));
    });
  });
}
