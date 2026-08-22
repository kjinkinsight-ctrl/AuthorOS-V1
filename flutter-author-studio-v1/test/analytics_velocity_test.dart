import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Thursday, so the Monday-based week has days on both sides of it.
final today = DateTime(2026, 8, 20, 14, 30);

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

AnalyticsVelocity _velocity(
  List<WritingSession> sessions, {
  DateTime? now,
}) =>
    AnalyticsVelocity.fromHistory(
      AnalyticsWritingHistory.fromSessions(sessions, now: now ?? today),
      now: now ?? today,
    );

void main() {
  group('no history', () {
    test('an empty history yields no pace at all', () {
      final velocity = _velocity(const []);

      expect(velocity.hasVelocity, isFalse);
      expect(velocity.daysElapsed, 0);
      expect(velocity.averageDailyWords, isNull);
      expect(velocity.averageWordsPerWritingDay, isNull);
      expect(velocity.weeklyVelocity, isNull);
      expect(velocity.monthlyVelocity, isNull);
    });

    test('the empty constant reports itself as having no velocity', () {
      const velocity = AnalyticsVelocity.empty();

      expect(velocity.hasVelocity, isFalse);
      expect(velocity.averageDailyWords, isNull);
      expect(velocity.averageSessionWords, 0);
    });
  });

  group('elapsed days', () {
    test('a single session today spans one day, not zero', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 500),
      ]);

      expect(velocity.daysElapsed, 1);
      expect(velocity.averageDailyWords, 500.0);
    });

    test('the span runs from the first session through today, inclusive', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 1, 9), words: 5000),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 20, 9), words: 5000),
      ]);

      // 1 August through 20 August inclusive is 20 days.
      expect(velocity.daysElapsed, 20);
      expect(velocity.averageDailyWords, 10000 / 20);
    });
  });

  group('two honest denominators', () {
    test('daily words counts rest days, writing-day words does not', () {
      // Wrote on three days out of the twenty since starting.
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 1, 9), words: 1000),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 10, 9), words: 1000),
        _session(id: 'ws-3', startedAt: DateTime(2026, 8, 20, 9), words: 1000),
      ]);

      expect(velocity.daysElapsed, 20);
      expect(velocity.daysWritten, 3);
      expect(velocity.averageDailyWords, 3000 / 20);
      expect(velocity.averageWordsPerWritingDay, 3000 / 3);
    });

    test('writing-day words is the higher number whenever days were missed',
        () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 1, 9), words: 1000),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 20, 9), words: 1000),
      ]);

      expect(
        velocity.averageWordsPerWritingDay!,
        greaterThan(velocity.averageDailyWords!),
      );
    });

    test('two sessions on one day count as one writing day', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 300),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 20, 16), words: 200),
      ]);

      expect(velocity.daysWritten, 1);
      expect(velocity.averageWordsPerWritingDay, 500.0);
    });
  });

  group('forwarded rates keep one definition', () {
    test('session words and words per hour come from the history itself', () {
      final history = AnalyticsWritingHistory.fromSessions(
        [
          _session(
            id: 'ws-1',
            startedAt: DateTime(2026, 8, 20, 9),
            duration: const Duration(hours: 1),
            words: 600,
          ),
        ],
        now: today,
      );
      final velocity = AnalyticsVelocity.fromHistory(history, now: today);

      expect(velocity.averageSessionWords, history.averageWordsPerSession);
      expect(velocity.averageWordsPerHour, history.averageWordsPerHour);
      expect(velocity.averageWordsPerHour, 600.0);
    });

    test('a session with no measurable time yields no hourly rate', () {
      final velocity = _velocity([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 20, 9),
          duration: Duration.zero,
          words: 500,
        ),
      ]);

      expect(velocity.averageWordsPerHour, isNull);
      // Still a daily pace: the day happened even if the stopwatch did not.
      expect(velocity.averageDailyWords, 500.0);
    });
  });

  group('weekly and monthly scale from the daily rate', () {
    test('a week is seven days of the current daily pace', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 500),
      ]);

      expect(velocity.weeklyVelocity, 500.0 * 7);
    });

    test('a month is the mean Gregorian month of the same pace', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 500),
      ]);

      expect(velocity.monthlyVelocity, 500.0 * 30.436875);
    });

    test('the three velocities are consistent with one another', () {
      final velocity = _velocity([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 1, 9), words: 4000),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 15, 9), words: 6000),
      ]);

      final daily = velocity.averageDailyWords!;
      expect(velocity.weeklyVelocity, daily * AnalyticsVelocity.daysPerWeek);
      expect(velocity.monthlyVelocity, daily * AnalyticsVelocity.daysPerMonth);
    });
  });

  group('completion projection', () {
    test('the spec\'s own manuscript projects to 47 days', () {
      final projection = AnalyticsProjection.from(
        currentWords: 78412,
        targetWords: 150000,
        wordsRemaining: 71588,
        averageDailyWords: 1523,
        now: today,
      );

      expect(projection.hasProjection, isTrue);
      expect(projection.estimatedDaysToCompletion, 47);
      expect(projection.projectedCompletionDate, DateTime(2026, 10, 6));
      expect(projection.wordsRemaining, 71588);
    });

    test('the estimate is the nearest whole day', () {
      final projection = AnalyticsProjection.from(
        currentWords: 100,
        targetWords: 1000,
        wordsRemaining: 900,
        averageDailyWords: 400,
        now: today,
      );

      // 2.25 days rounds to 2, the same way the spec's 47.006 reads as 47.
      expect(projection.estimatedDaysToCompletion, 2);
      expect(projection.projectedCompletionDate, DateTime(2026, 8, 22));
    });

    test('a nearly finished manuscript still takes a day, never zero', () {
      final projection = AnalyticsProjection.from(
        currentWords: 79990,
        targetWords: 80000,
        wordsRemaining: 10,
        averageDailyWords: 400,
        now: today,
      );

      // 0.025 days is not "approximately 0 days" — it is one more sitting.
      expect(projection.estimatedDaysToCompletion, 1);
      expect(projection.projectedCompletionDate, DateTime(2026, 8, 21));
    });

    test('no target means no projection, not zero days', () {
      final projection = AnalyticsProjection.from(
        currentWords: 5000,
        targetWords: 0,
        wordsRemaining: null,
        averageDailyWords: 500,
        now: today,
      );

      expect(projection.hasTarget, isFalse);
      expect(projection.hasProjection, isFalse);
      expect(projection.estimatedDaysToCompletion, isNull);
      expect(projection.projectedCompletionDate, isNull);
    });

    test('a null target is treated the same as none', () {
      final projection = AnalyticsProjection.from(
        currentWords: 5000,
        targetWords: null,
        wordsRemaining: null,
        averageDailyWords: 500,
        now: today,
      );

      expect(projection.hasTarget, isFalse);
      expect(projection.hasProjection, isFalse);
    });

    test('no measured pace means no date is named', () {
      final projection = AnalyticsProjection.from(
        currentWords: 5000,
        targetWords: 80000,
        wordsRemaining: 75000,
        averageDailyWords: null,
        now: today,
      );

      expect(projection.hasTarget, isTrue);
      expect(projection.hasProjection, isFalse);
      expect(projection.wordsRemaining, 75000);
    });

    test('a zero pace never becomes an infinite estimate', () {
      final projection = AnalyticsProjection.from(
        currentWords: 5000,
        targetWords: 80000,
        wordsRemaining: 75000,
        averageDailyWords: 0,
        now: today,
      );

      expect(projection.hasProjection, isFalse);
      expect(projection.estimatedDaysToCompletion, isNull);
    });

    test('a pace slower than a decade of writing names no date', () {
      final projection = AnalyticsProjection.from(
        currentWords: 0,
        targetWords: 80000,
        wordsRemaining: 80000,
        averageDailyWords: 1,
        now: today,
      );

      // 80,000 days is past the horizon AuthorOS is willing to promise.
      expect(projection.hasProjection, isFalse);
    });

    test('a manuscript past its target reports completion, not a date', () {
      final projection = AnalyticsProjection.from(
        currentWords: 90000,
        targetWords: 80000,
        wordsRemaining: 0,
        averageDailyWords: 500,
        now: today,
      );

      expect(projection.isComplete, isTrue);
      expect(projection.hasProjection, isFalse);
      expect(projection.wordsRemaining, 0);
    });

    test('the unavailable constant claims nothing', () {
      const projection = AnalyticsProjection.unavailable();

      expect(projection.hasTarget, isFalse);
      expect(projection.isComplete, isFalse);
      expect(projection.hasProjection, isFalse);
    });
  });

  group('goal progress', () {
    AnalyticsGoalProgress progressWith({
      required int today,
      required int week,
      required int month,
      WritingGoals? goals,
    }) =>
        AnalyticsGoalProgress(
          goals: goals ?? WritingGoals.defaultsFor('project-a'),
          wordsToday: today,
          wordsThisWeek: week,
          wordsThisMonth: month,
        );

    test('partial progress is a fraction of the goal', () {
      final progress = progressWith(today: 1240, week: 5000, month: 20000);

      expect(progress.dailyProgress, 1240 / 2000);
      expect(progress.weeklyProgress, 5000 / 10000);
      expect(progress.monthlyProgress, 20000 / 40000);
    });

    test('remaining words never go negative', () {
      final progress = progressWith(today: 1240, week: 5000, month: 20000);

      expect(progress.dailyWordsRemaining, 760);
      expect(progress.weeklyWordsRemaining, 5000);
      expect(progress.monthlyWordsRemaining, 20000);
    });

    test('overshooting a goal clamps progress and reports it met', () {
      final progress = progressWith(today: 3000, week: 5000, month: 20000);

      expect(progress.dailyProgress, 1.0);
      expect(progress.dailyWordsRemaining, 0);
      expect(progress.dailyGoalMet, isTrue);
    });

    test('a goal of zero yields no percentage and is never met', () {
      final progress = progressWith(
        today: 500,
        week: 0,
        month: 0,
        goals: WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 0),
      );

      expect(progress.dailyProgress, isNull);
      expect(progress.dailyWordsRemaining, isNull);
      expect(progress.dailyGoalMet, isFalse);
    });

    test('a day with no writing is zero progress, not absent progress', () {
      final progress = progressWith(today: 0, week: 0, month: 0);

      expect(progress.dailyProgress, 0.0);
      expect(progress.dailyWordsRemaining, 2000);
      expect(progress.dailyGoalMet, isFalse);
    });

    test('progress reads its actuals straight from the history', () {
      final history = AnalyticsWritingHistory.fromSessions(
        [
          _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 750),
        ],
        now: today,
      );

      final progress = AnalyticsGoalProgress.from(
        goals: WritingGoals.defaultsFor('project-a'),
        history: history,
      );

      expect(progress.wordsToday, history.wordsToday);
      expect(progress.wordsThisWeek, history.wordsThisWeek);
      expect(progress.wordsThisMonth, history.wordsThisMonth);
    });

    test('the empty constant carries the seeded goals and no words', () {
      const progress = AnalyticsGoalProgress.empty();

      expect(progress.goals.dailyWords, 2000);
      expect(progress.wordsToday, 0);
      expect(progress.dailyProgress, 0.0);
    });
  });

  group('calendar arithmetic', () {
    test('days between two local days counts whole days', () {
      expect(
        WritingCalendar.daysBetween(
          DateTime(2026, 8, 1, 23, 40),
          DateTime(2026, 8, 20, 0, 10),
        ),
        19,
      );
    });

    test('the same day is zero days apart, whatever the hour', () {
      expect(
        WritingCalendar.daysBetween(
          DateTime(2026, 8, 20, 0, 1),
          DateTime(2026, 8, 20, 23, 59),
        ),
        0,
      );
    });

    test('a day counted backwards is negative', () {
      expect(
        WritingCalendar.daysBetween(
          DateTime(2026, 8, 20),
          DateTime(2026, 8, 19),
        ),
        -1,
      );
    });

    test('a month boundary is counted by the calendar, not by hours', () {
      expect(
        WritingCalendar.daysBetween(
          DateTime(2026, 2, 27),
          DateTime(2026, 3, 2),
        ),
        3,
      );
    });
  });
}
