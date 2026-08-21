import 'dart:io';

import 'package:author_studio_v1/core/writing_session.dart';
import 'package:flutter_test/flutter_test.dart';

WritingSession _session({
  String id = 'ws-1',
  String projectId = 'project-a',
  DateTime? startedAt,
  DateTime? endedAt,
  int startingWordCount = 100,
  int endingWordCount = 400,
  int wordsAdded = 300,
  int wordsRemoved = 0,
  Duration? duration,
  String? chapterId,
  String? sceneId,
}) =>
    WritingSession(
      id: id,
      projectId: projectId,
      startedAt: startedAt ?? DateTime(2026, 8, 20, 9),
      endedAt: endedAt ?? DateTime(2026, 8, 20, 10),
      startingWordCount: startingWordCount,
      endingWordCount: endingWordCount,
      wordsAdded: wordsAdded,
      wordsRemoved: wordsRemoved,
      duration: duration,
      chapterId: chapterId,
      sceneId: sceneId,
    );

void main() {
  group('creation', () {
    test('records both endpoints and the words between them', () {
      final session = _session(
        chapterId: 'chapter-1',
        sceneId: 'scene-1',
      );

      expect(session.id, 'ws-1');
      expect(session.projectId, 'project-a');
      expect(session.startingWordCount, 100);
      expect(session.endingWordCount, 400);
      expect(session.wordsWritten, 300);
      expect(session.netWordDelta, 300);
      expect(session.wordsAdded, 300);
      expect(session.wordsRemoved, 0);
      expect(session.chapterId, 'chapter-1');
      expect(session.sceneId, 'scene-1');
    });

    test('derives duration from its endpoints when none is supplied', () {
      final session = _session(
        startedAt: DateTime(2026, 8, 20, 9),
        endedAt: DateTime(2026, 8, 20, 9, 42),
      );

      expect(session.duration, const Duration(minutes: 42));
    });

    test('keeps an explicitly recorded duration over the endpoint gap', () {
      final session = _session(duration: const Duration(minutes: 12));

      expect(session.duration, const Duration(minutes: 12));
    });

    test('is immutable: copyWith produces a new record, never a mutation', () {
      final original = _session();
      final revised = original.copyWith(endingWordCount: 500);

      expect(original.endingWordCount, 400);
      expect(original.wordsWritten, 300);
      expect(revised.endingWordCount, 500);
      expect(revised.wordsWritten, 400);
      expect(identical(original, revised), isFalse);
    });

    test('generated ids are unique even within the same instant', () {
      final at = DateTime(2026, 8, 20, 9);
      final ids = {
        for (var index = 0; index < 500; index++) WritingSessionId.create(at),
      };

      expect(ids, hasLength(500));
    });
  });

  group('word delta', () {
    test('never reports negative words when the author deleted text', () {
      final session = _session(
        startingWordCount: 900,
        endingWordCount: 600,
        wordsAdded: 40,
        wordsRemoved: 340,
      );

      expect(session.netWordDelta, -300);
      expect(session.wordsWritten, 0);
      expect(session.isNetDeletion, isTrue);
    });

    test('keeps additions and removals separately from the net delta', () {
      final session = _session(
        startingWordCount: 500,
        endingWordCount: 500,
        wordsAdded: 220,
        wordsRemoved: 220,
      );

      expect(session.wordsWritten, 0);
      expect(session.wordsAdded, 220);
      expect(session.wordsRemoved, 220);
      expect(session.isNetDeletion, isFalse);
    });

    test('a zero-word session reports zero, never a fabricated positive', () {
      final session = _session(
        startingWordCount: 300,
        endingWordCount: 300,
        wordsAdded: 0,
        wordsRemoved: 0,
      );

      expect(session.wordsWritten, 0);
      expect(session.netWordDelta, 0);
    });

    test('words per hour is null when no measurable time was recorded', () {
      final instant = DateTime(2026, 8, 20, 9);
      final session = _session(startedAt: instant, endedAt: instant);

      expect(session.duration, Duration.zero);
      expect(session.wordsPerHour, isNull);
    });

    test('words per hour scales the words over the recorded duration', () {
      final session = _session(
        startingWordCount: 0,
        endingWordCount: 600,
        duration: const Duration(minutes: 30),
      );

      expect(session.wordsPerHour, closeTo(1200, 0.001));
    });
  });

  group('local calendar day', () {
    test('a session belongs to the local day it started on', () {
      final session = _session(
        startedAt: DateTime(2026, 8, 20, 23, 40),
        endedAt: DateTime(2026, 8, 21, 0, 25),
      );

      expect(session.localDay, DateTime(2026, 8, 20));
    });

    test('a session crossing midnight is not split across two days', () {
      final session = _session(
        startedAt: DateTime(2026, 8, 20, 23, 30),
        endedAt: DateTime(2026, 8, 21, 1, 30),
      );

      expect(session.localDay, DateTime(2026, 8, 20));
      expect(session.duration, const Duration(hours: 2));
    });

    test('week start is the local Monday of that week', () {
      // 2026-08-20 is a Thursday.
      expect(
        WritingCalendar.weekStart(DateTime(2026, 8, 20, 15)),
        DateTime(2026, 8, 17),
      );
      // Sunday still belongs to the week that began on Monday the 17th.
      expect(
        WritingCalendar.weekStart(DateTime(2026, 8, 23, 23, 59)),
        DateTime(2026, 8, 17),
      );
      // Monday is its own week start.
      expect(
        WritingCalendar.weekStart(DateTime(2026, 8, 24)),
        DateTime(2026, 8, 24),
      );
    });

    test('month start is local midnight on the first of the month', () {
      expect(
        WritingCalendar.monthStart(DateTime(2026, 8, 20, 15)),
        DateTime(2026, 8, 1),
      );
    });

    test('adding days walks the calendar, including across months', () {
      expect(
        WritingCalendar.addDays(DateTime(2026, 8, 31), 1),
        DateTime(2026, 9, 1),
      );
      expect(
        WritingCalendar.addDays(DateTime(2026, 3, 1), -1),
        DateTime(2026, 2, 28),
      );
    });

    test('a UTC instant is bucketed by the author\'s local day', () {
      final instant = DateTime.utc(2026, 8, 20, 22);
      expect(
        WritingCalendar.dayOf(instant),
        WritingCalendar.dayOf(instant.toLocal()),
      );
    });
  });

  group('serialization', () {
    test('round-trips through JSON without losing a recorded value', () {
      final session = _session(
        id: 'ws-round-trip',
        startedAt: DateTime(2026, 8, 20, 9, 5),
        endedAt: DateTime(2026, 8, 20, 9, 47),
        startingWordCount: 1200,
        endingWordCount: 1975,
        wordsAdded: 820,
        wordsRemoved: 45,
        chapterId: 'chapter-3',
        sceneId: 'scene-9',
      );

      final restored = WritingSession.fromJson(session.toJson());

      expect(restored.id, session.id);
      expect(restored.projectId, session.projectId);
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
      expect(restored.duration, session.duration);
      expect(restored.startingWordCount, session.startingWordCount);
      expect(restored.endingWordCount, session.endingWordCount);
      expect(restored.wordsWritten, session.wordsWritten);
      expect(restored.wordsAdded, session.wordsAdded);
      expect(restored.wordsRemoved, session.wordsRemoved);
      expect(restored.chapterId, session.chapterId);
      expect(restored.sceneId, session.sceneId);
      expect(restored.localDay, session.localDay);
    });

    test('timestamps serialize as UTC ISO-8601', () {
      final json = _session().toJson();

      expect(json['startedAt'], endsWith('Z'));
      expect(json['endedAt'], endsWith('Z'));
      expect(json['durationSeconds'], 3600);
    });
  });

  group('thresholds', () {
    const thresholds = WritingSessionThresholds();

    test('enough words qualify a session however short it was', () {
      expect(
        thresholds.qualifies(
          wordsWritten: 10,
          wordsAdded: 10,
          wordsRemoved: 0,
          duration: Duration.zero,
        ),
        isTrue,
      );
    });

    test('a handful of words below the minimum does not qualify', () {
      expect(
        thresholds.qualifies(
          wordsWritten: 3,
          wordsAdded: 3,
          wordsRemoved: 0,
          duration: const Duration(seconds: 4),
        ),
        isFalse,
      );
    });

    test('sustained revision qualifies even at zero net words', () {
      expect(
        thresholds.qualifies(
          wordsWritten: 0,
          wordsAdded: 180,
          wordsRemoved: 180,
          duration: const Duration(minutes: 4),
        ),
        isTrue,
      );
    });

    test('time alone never qualifies without a change to the manuscript', () {
      expect(
        thresholds.qualifies(
          wordsWritten: 0,
          wordsAdded: 0,
          wordsRemoved: 0,
          duration: const Duration(hours: 3),
        ),
        isFalse,
      );
    });

    test('the thresholds are configurable in exactly one place', () {
      const relaxed = WritingSessionThresholds(
        minimumWordsWritten: 1,
        minimumDuration: Duration(seconds: 1),
      );

      expect(
        relaxed.qualifies(
          wordsWritten: 1,
          wordsAdded: 1,
          wordsRemoved: 0,
          duration: Duration.zero,
        ),
        isTrue,
      );
      expect(thresholds.minimumWordsWritten, 10);
      expect(thresholds.minimumDuration, const Duration(minutes: 1));
      expect(thresholds.idleTimeout, const Duration(minutes: 5));
    });
  });

  group('architecture', () {
    test('the domain model stays presentation-independent', () {
      final source = File('lib/core/writing_session.dart').readAsStringSync();

      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('SharedPreferences')));
    });

    test('the domain owns no second word-count implementation', () {
      final source = File('lib/core/writing_session.dart').readAsStringSync();

      expect(source, isNot(contains(r'split(RegExp')));
      expect(source, isNot(contains('wordCount =>')));
    });
  });
}
