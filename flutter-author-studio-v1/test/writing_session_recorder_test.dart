import 'dart:io';

import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/writing_session_recorder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock the test advances by hand, so session durations are exact instead
/// of whatever the wall clock happened to do between two awaits.
class _TestClock {
  _TestClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration amount) => _now = _now.add(amount);

  set now(DateTime value) => _now = value;
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late _TestClock clock;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    clock = _TestClock(DateTime(2026, 8, 20, 9));
  });

  tearDown(() => database.close());

  WritingSessionRecorder recorderFor(
    String projectId, {
    WritingSessionThresholds thresholds = const WritingSessionThresholds(),
  }) =>
      WritingSessionRecorder(
        projectId: projectId,
        repository: repository,
        thresholds: thresholds,
        clock: clock.call,
      );

  group('start', () {
    test('opening the manuscript starts no session', () async {
      final recorder = recorderFor('project-a');

      recorder.noteBaseline(2400);

      expect(recorder.hasOpenSession, isFalse);
      expect(await recorder.finalizeSession(), isNull);
      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
    });

    test('re-reading the manuscript at the same count starts no session',
        () async {
      final recorder = recorderFor('project-a');

      // Navigating away and back, a rebuild, a reopen: all baselines.
      recorder.noteBaseline(2400);
      recorder.noteBaseline(2400);
      recorder.noteBaseline(2400);

      expect(recorder.hasOpenSession, isFalse);
      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
    });

    test('the first writing activity opens a session', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(2400);

      await recorder.noteActivity(wordCount: 2405);

      expect(recorder.hasOpenSession, isTrue);
    });

    test('activity before any baseline is taken as the baseline', () async {
      final recorder = recorderFor('project-a');

      // Nothing was observed first, so there is no honest starting point and
      // no words can be credited.
      await recorder.noteActivity(wordCount: 2400);

      expect(recorder.hasOpenSession, isFalse);
      expect(recorder.lastObservedWordCount, 2400);
    });

    test('activity that changes nothing never opens a session', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(2400);

      await recorder.noteActivity(wordCount: 2400);
      await recorder.noteActivity(wordCount: 2400);

      expect(recorder.hasOpenSession, isFalse);
    });
  });

  group('finalize', () {
    test('a qualifying session is persisted with its recorded values',
        () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(
        wordCount: 1100,
        chapterId: 'chapter-1',
        sceneId: 'scene-1',
      );
      clock.advance(const Duration(minutes: 4));
      await recorder.noteActivity(wordCount: 1450);
      clock.advance(const Duration(minutes: 10));

      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      expect(session!.projectId, 'project-a');
      expect(session.startingWordCount, 1000);
      expect(session.endingWordCount, 1450);
      expect(session.wordsWritten, 450);
      expect(session.wordsAdded, 450);
      expect(session.wordsRemoved, 0);
      expect(session.chapterId, 'chapter-1');
      expect(session.sceneId, 'scene-1');
      // The session ends at the last writing activity, not ten idle minutes
      // later when the author closed the editor.
      expect(session.duration, const Duration(minutes: 4));

      final stored = await repository.writingSessionsForProject('project-a');
      expect(stored, hasLength(1));
      expect(stored.single.id, session.id);
    });

    test('a session below the threshold is discarded, not recorded', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      // Three words in a few seconds: a typo fix, not a writing session.
      await recorder.noteActivity(wordCount: 1003);
      clock.advance(const Duration(seconds: 5));

      expect(await recorder.finalizeSession(), isNull);
      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
    });

    test('sustained revision at zero net words is still recorded', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 940);
      clock.advance(const Duration(minutes: 3));
      await recorder.noteActivity(wordCount: 1000);

      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      expect(session!.wordsWritten, 0);
      expect(session.wordsAdded, 60);
      expect(session.wordsRemoved, 60);
    });

    test('a net deletion never reports negative words', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(2000);

      await recorder.noteActivity(wordCount: 1400);
      clock.advance(const Duration(minutes: 4));
      await recorder.noteActivity(wordCount: 1500);

      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      expect(session!.netWordDelta, -500);
      expect(session.wordsWritten, 0);
      expect(session.wordsRemoved, 600);
      expect(session.wordsAdded, 100);
    });

    test('the next session starts from where the last one ended', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 5));
      await recorder.finalizeSession();

      clock.advance(const Duration(hours: 2));
      await recorder.noteActivity(wordCount: 1500);
      clock.advance(const Duration(minutes: 5));
      final second = await recorder.finalizeSession();

      expect(second, isNotNull);
      expect(second!.startingWordCount, 1200);
      expect(second.wordsWritten, 300);
      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(2),
      );
    });

    test('a discarded session still re-baselines the next one', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1002);
      expect(await recorder.finalizeSession(), isNull);

      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 2));
      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      expect(session!.startingWordCount, 1002);
      expect(session.wordsWritten, 198);
    });
  });

  group('duplicate protection', () {
    test('finalizing twice records the session exactly once', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 5));

      final first = await recorder.finalizeSession();
      final second = await recorder.finalizeSession();
      final third = await recorder.finalizeSession();

      expect(first, isNotNull);
      expect(second, isNull);
      expect(third, isNull);
      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(1),
      );
    });

    test('concurrent finalize calls cannot both persist a session', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 5));

      final results = await Future.wait([
        recorder.finalizeSession(),
        recorder.finalizeSession(),
        recorder.finalizeSession(),
      ]);

      expect(results.whereType<WritingSession>(), hasLength(1));
      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(1),
      );
    });

    test('a replayed session id can never write a second row', () async {
      var issued = 0;
      final recorder = WritingSessionRecorder(
        projectId: 'project-a',
        repository: repository,
        clock: clock.call,
        // A pathological id source: every session claims the same identity.
        idFactory: () {
          issued++;
          return 'ws-always-the-same';
        },
      );

      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 5));
      await recorder.finalizeSession();

      await recorder.noteActivity(wordCount: 1600);
      clock.advance(const Duration(minutes: 5));
      await recorder.finalizeSession();

      expect(issued, 2);
      final stored = await repository.writingSessionsForProject('project-a');
      expect(stored, hasLength(1));
      // The first recording stands; history is never rewritten.
      expect(stored.single.endingWordCount, 1200);
    });

    test('repeated lifecycle events after disposal record nothing more',
        () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 5));

      await recorder.finalizeSession(); // dispose
      await recorder.finalizeSession(); // app paused
      await recorder.finalizeSession(); // app detached
      await recorder.finalizeSession(); // navigation

      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(1),
      );
    });

    test('autosave-shaped repeat reports do not extend or split a session',
        () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 3));
      // Autosave fires several times with nothing new to report.
      await recorder.noteActivity(wordCount: 1200);
      clock.advance(const Duration(minutes: 3));
      await recorder.noteActivity(wordCount: 1200);

      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      // Duration comes from real activity, not from autosave ticks.
      expect(session!.duration, Duration.zero);
      expect(session.wordsWritten, 200);
      expect(
        await repository.writingSessionsForProject('project-a'),
        hasLength(1),
      );
    });

    test('a widget rebuild that re-reads the manuscript changes nothing',
        () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1200);

      // A rebuild re-reads the manuscript; a baseline must not disturb the
      // session already in progress.
      recorder.noteBaseline(9999);
      clock.advance(const Duration(minutes: 5));

      final session = await recorder.finalizeSession();

      expect(session, isNotNull);
      expect(session!.startingWordCount, 1000);
      expect(session.endingWordCount, 1200);
    });
  });

  group('idle handling', () {
    test('a long idle gap splits the work into two sessions', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1100);
      clock.advance(const Duration(minutes: 10));
      await recorder.noteActivity(wordCount: 1300);
      clock.advance(const Duration(minutes: 10));
      await recorder.finalizeSession();

      final stored = await repository.writingSessionsForProject('project-a');

      expect(stored, hasLength(2));
      expect(stored.first.startingWordCount, 1000);
      expect(stored.first.endingWordCount, 1100);
      expect(stored.last.startingWordCount, 1100);
      expect(stored.last.endingWordCount, 1300);
    });

    test('an editor left open overnight records no fourteen-hour session',
        () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1400);
      clock.advance(const Duration(hours: 14));
      await recorder.noteActivity(wordCount: 1900);
      clock.advance(const Duration(minutes: 2));
      await recorder.finalizeSession();

      final stored = await repository.writingSessionsForProject('project-a');

      expect(stored, hasLength(2));
      for (final session in stored) {
        expect(session.duration, lessThan(const Duration(hours: 1)));
      }
    });

    test('activity inside the idle window keeps one session open', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);

      await recorder.noteActivity(wordCount: 1100);
      clock.advance(const Duration(minutes: 4));
      await recorder.noteActivity(wordCount: 1300);
      clock.advance(const Duration(minutes: 4));
      await recorder.noteActivity(wordCount: 1500);
      await recorder.finalizeSession();

      final stored = await repository.writingSessionsForProject('project-a');

      expect(stored, hasLength(1));
      expect(stored.single.wordsWritten, 500);
      expect(stored.single.duration, const Duration(minutes: 8));
    });
  });

  group('project isolation', () {
    test('two recorders never write into each other\'s history', () async {
      final projectA = recorderFor('project-a');
      final projectB = recorderFor('project-b');

      projectA.noteBaseline(1000);
      projectB.noteBaseline(50);
      await projectA.noteActivity(wordCount: 1500);
      await projectB.noteActivity(wordCount: 130);
      clock.advance(const Duration(minutes: 5));
      await projectA.finalizeSession();
      await projectB.finalizeSession();

      final historyA = await repository.writingSessionsForProject('project-a');
      final historyB = await repository.writingSessionsForProject('project-b');

      expect(historyA, hasLength(1));
      expect(historyA.single.wordsWritten, 500);
      expect(historyB, hasLength(1));
      expect(historyB.single.wordsWritten, 80);
    });
  });

  group('discarding', () {
    test('a discarded session is never persisted', () async {
      final recorder = recorderFor('project-a');
      recorder.noteBaseline(1000);
      await recorder.noteActivity(wordCount: 1500);
      clock.advance(const Duration(minutes: 5));

      recorder.discardOpenSession();

      expect(recorder.hasOpenSession, isFalse);
      expect(await recorder.finalizeSession(), isNull);
      expect(
        await repository.writingSessionsForProject('project-a'),
        isEmpty,
      );
      expect(recorder.lastObservedWordCount, 1500);
    });
  });

  group('architecture', () {
    test('the recorder persists through the canonical repository only', () {
      final source =
          File('lib/writing_session_recorder.dart').readAsStringSync();

      expect(source, contains('DriftConnectedDomainRepository'));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('package:flutter')));
    });

    test('the recorder owns no word-count implementation', () {
      final source =
          File('lib/writing_session_recorder.dart').readAsStringSync();

      expect(source, isNot(contains(r'split(RegExp')));
      expect(source, isNot(contains('.trim().split')));
    });

    test('the Manuscript Studio reports its own canonical word count', () {
      final source = File('lib/manuscript_studio.dart').readAsStringSync();

      expect(source, contains('_sessionRecorder.noteBaseline'));
      expect(source, contains('_sessionRecorder.noteActivity'));
      expect(source, contains('_sessionRecorder.finalizeSession()'));
      expect(source, contains('wordCount: current.wordCount'));
      expect(source, isNot(contains(r'split(RegExp')));
    });
  });
}
