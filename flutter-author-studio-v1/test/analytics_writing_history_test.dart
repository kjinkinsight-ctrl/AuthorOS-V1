import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
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
  int wordsRemoved = 0,
}) =>
    WritingSession(
      id: id,
      projectId: projectId,
      startedAt: startedAt,
      endedAt: startedAt.add(duration),
      duration: duration,
      startingWordCount: 0,
      endingWordCount: words,
      wordsAdded: words + wordsRemoved,
      wordsRemoved: wordsRemoved,
    );

AnalyticsWritingHistory _history(
  List<WritingSession> sessions, {
  DateTime? now,
}) =>
    AnalyticsWritingHistory.fromSessions(sessions, now: now ?? today);

void main() {
  group('empty history', () {
    test('reports no sessions rather than a zeroed day', () {
      const history = AnalyticsWritingHistory.empty();

      expect(history.hasSessions, isFalse);
      expect(history.totalSessions, 0);
      expect(history.totalWordsWritten, 0);
      expect(history.totalWritingTime, Duration.zero);
      expect(history.currentStreakDays, 0);
      expect(history.longestStreakDays, 0);
      expect(history.firstSessionAt, isNull);
      expect(history.lastSessionAt, isNull);
      // No bars: a new project must not render a fabricated chart.
      expect(history.dailyTotals, isEmpty);
    });

    test('an empty session list folds to the empty history', () {
      final history = _history(const []);

      expect(history.hasSessions, isFalse);
      expect(history.averageSessionDuration, Duration.zero);
      expect(history.averageWordsPerSession, 0);
      expect(history.averageWordsPerHour, isNull);
      expect(history.bestDayThisWeek, isNull);
    });
  });

  group('totals', () {
    test('sums sessions, words, and writing time', () {
      final history = _history([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 18, 9),
          duration: const Duration(minutes: 45),
          words: 900,
        ),
        _session(
          id: 'ws-2',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 15),
          words: 300,
        ),
      ]);

      expect(history.totalSessions, 2);
      expect(history.totalWordsWritten, 1200);
      expect(history.totalWritingTime, const Duration(hours: 1));
      expect(history.hasSessions, isTrue);
    });

    test('reports the longest and the most productive session', () {
      final history = _history([
        _session(
          id: 'ws-long',
          startedAt: DateTime(2026, 8, 18, 9),
          duration: const Duration(hours: 2),
          words: 400,
        ),
        _session(
          id: 'ws-productive',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 25),
          words: 1600,
        ),
      ]);

      expect(history.longestSessionDuration, const Duration(hours: 2));
      expect(history.mostProductiveSessionWords, 1600);
    });

    test('records the first and last recorded instants', () {
      final history = _history([
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 19, 9)),
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 17, 9)),
      ]);

      expect(history.firstSessionAt, DateTime(2026, 8, 17, 9));
      expect(
        history.lastSessionAt,
        DateTime(2026, 8, 19, 9).add(const Duration(minutes: 30)),
      );
    });
  });

  group('averages', () {
    test('average session duration and words per session', () {
      final history = _history([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 18, 9),
          duration: const Duration(minutes: 40),
          words: 1000,
        ),
        _session(
          id: 'ws-2',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 20),
          words: 500,
        ),
      ]);

      expect(history.averageSessionDuration, const Duration(minutes: 30));
      expect(history.averageWordsPerSession, 750);
    });

    test('words per hour spans the whole recorded writing time', () {
      final history = _history([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 18, 9),
          duration: const Duration(minutes: 30),
          words: 600,
        ),
        _session(
          id: 'ws-2',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 30),
          words: 400,
        ),
      ]);

      expect(history.averageWordsPerHour, closeTo(1000, 0.001));
    });

    test('words per hour is null when no measurable time was recorded', () {
      final history = _history([
        _session(
          id: 'ws-instant',
          startedAt: DateTime(2026, 8, 18, 9),
          duration: Duration.zero,
          words: 400,
        ),
      ]);

      expect(history.totalWordsWritten, 400);
      expect(history.averageWordsPerHour, isNull);
    });
  });

  group('daily totals', () {
    test('words, sessions, and time written today', () {
      final history = _history([
        _session(
          id: 'ws-today-1',
          startedAt: DateTime(2026, 8, 20, 8),
          duration: const Duration(minutes: 25),
          words: 700,
        ),
        _session(
          id: 'ws-today-2',
          startedAt: DateTime(2026, 8, 20, 13),
          duration: const Duration(minutes: 17),
          words: 540,
        ),
        _session(
          id: 'ws-yesterday',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 30),
          words: 900,
        ),
      ]);

      expect(history.wordsToday, 1240);
      expect(history.sessionsToday, 2);
      expect(history.writingTimeToday, const Duration(minutes: 42));
    });

    test('a session that crossed midnight counts for the day it began', () {
      final history = _history([
        _session(
          id: 'ws-late',
          startedAt: DateTime(2026, 8, 19, 23, 30),
          duration: const Duration(hours: 1, minutes: 30),
          words: 800,
        ),
      ]);

      expect(history.wordsToday, 0);
      expect(history.sessionsToday, 0);
      final wednesday = history.dailyTotals
          .firstWhere((day) => day.day == DateTime(2026, 8, 19));
      expect(wednesday.wordsWritten, 800);
      expect(wednesday.sessionCount, 1);
    });

    test('a day with no writing is reported, not omitted', () {
      final history = _history([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 17, 9), words: 400),
      ]);

      expect(history.dailyTotals, hasLength(7));
      final tuesday = history.dailyTotals
          .firstWhere((day) => day.day == DateTime(2026, 8, 18));
      expect(tuesday.hasWriting, isFalse);
      expect(tuesday.wordsWritten, 0);
      expect(tuesday.sessionCount, 0);
      expect(tuesday.writingTime, Duration.zero);
    });

    test('a zero-word session still counts as a session on its day', () {
      final history = _history([
        _session(
          id: 'ws-revision',
          startedAt: DateTime(2026, 8, 20, 9),
          duration: const Duration(minutes: 25),
          words: 0,
          wordsRemoved: 300,
        ),
      ]);

      expect(history.wordsToday, 0);
      expect(history.sessionsToday, 1);
      expect(history.writingTimeToday, const Duration(minutes: 25));
      // A writing day means a qualifying session happened, not a word quota.
      expect(history.currentStreakDays, 1);
    });
  });

  group('weekly totals', () {
    test('covers Monday through Sunday of the local week', () {
      final history = _history([
        _session(id: 'ws-mon', startedAt: DateTime(2026, 8, 17, 9), words: 100),
        _session(id: 'ws-sun', startedAt: DateTime(2026, 8, 23, 9), words: 200),
      ]);

      expect(history.dailyTotals.first.day, DateTime(2026, 8, 17));
      expect(history.dailyTotals.last.day, DateTime(2026, 8, 23));
      expect(history.wordsThisWeek, 300);
      expect(history.sessionsThisWeek, 2);
    });

    test('excludes sessions from the previous week', () {
      final history = _history([
        _session(
          id: 'ws-last-week',
          startedAt: DateTime(2026, 8, 16, 9),
          words: 5000,
        ),
        _session(
          id: 'ws-this-week',
          startedAt: DateTime(2026, 8, 18, 9),
          words: 700,
        ),
      ]);

      expect(history.wordsThisWeek, 700);
      expect(history.sessionsThisWeek, 1);
      expect(history.totalWordsWritten, 5700);
    });

    test('sums weekly writing time and names the best day', () {
      final history = _history([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 17, 9),
          duration: const Duration(hours: 2),
          words: 1200,
        ),
        _session(
          id: 'ws-2',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(hours: 2, minutes: 12),
          words: 5620,
        ),
      ]);

      expect(
          history.writingTimeThisWeek, const Duration(hours: 4, minutes: 12));
      expect(history.wordsThisWeek, 6820);
      expect(history.bestDayThisWeek?.day, DateTime(2026, 8, 19));
      expect(history.bestDayThisWeek?.wordsWritten, 5620);
    });
  });

  group('monthly totals', () {
    test('sums only the current local month', () {
      final history = _history([
        _session(
          id: 'ws-july',
          startedAt: DateTime(2026, 7, 30, 9),
          duration: const Duration(hours: 1),
          words: 4000,
        ),
        _session(
          id: 'ws-aug-1',
          startedAt: DateTime(2026, 8, 2, 9),
          duration: const Duration(minutes: 30),
          words: 800,
        ),
        _session(
          id: 'ws-aug-2',
          startedAt: DateTime(2026, 8, 20, 9),
          duration: const Duration(minutes: 30),
          words: 600,
        ),
      ]);

      expect(history.wordsThisMonth, 1400);
      expect(history.sessionsThisMonth, 2);
      expect(history.writingTimeThisMonth, const Duration(hours: 1));
      expect(history.totalWordsWritten, 5400);
    });

    test('the same day number in another month never leaks in', () {
      final history = _history([
        _session(id: 'ws-a', startedAt: DateTime(2025, 8, 20, 9), words: 9000),
        _session(id: 'ws-b', startedAt: DateTime(2026, 8, 20, 9), words: 300),
      ]);

      expect(history.wordsThisMonth, 300);
      expect(history.sessionsThisMonth, 1);
    });
  });

  group('streaks', () {
    test('consecutive days ending today', () {
      final history = _history([
        for (final day in [18, 19, 20])
          _session(id: 'ws-$day', startedAt: DateTime(2026, 8, day, 9)),
      ]);

      expect(history.currentStreakDays, 3);
      expect(history.longestStreakDays, 3);
    });

    test('survives a day where the author has not written yet', () {
      final history = _history([
        for (final day in [17, 18, 19])
          _session(id: 'ws-$day', startedAt: DateTime(2026, 8, day, 9)),
      ]);

      // Nothing today yet — the streak is not lost until a full day is missed.
      expect(history.currentStreakDays, 3);
    });

    test('is broken by a missed day', () {
      final history = _history([
        for (final day in [15, 16, 17])
          _session(id: 'ws-$day', startedAt: DateTime(2026, 8, day, 9)),
      ]);

      expect(history.currentStreakDays, 0);
      expect(history.longestStreakDays, 3);
    });

    test('two sessions on one day count as one writing day', () {
      final history = _history([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9)),
        _session(id: 'ws-2', startedAt: DateTime(2026, 8, 20, 15)),
      ]);

      expect(history.currentStreakDays, 1);
      expect(history.longestStreakDays, 1);
      expect(history.sessionsToday, 2);
    });

    test('the longest streak is found anywhere in the history', () {
      final history = _history([
        for (final day in [1, 2, 3, 4, 5])
          _session(id: 'ws-early-$day', startedAt: DateTime(2026, 8, day, 9)),
        for (final day in [19, 20])
          _session(id: 'ws-late-$day', startedAt: DateTime(2026, 8, day, 9)),
      ]);

      expect(history.longestStreakDays, 5);
      expect(history.currentStreakDays, 2);
    });

    test('a streak spans a month boundary', () {
      final history = _history([
        _session(id: 'ws-jul-31', startedAt: DateTime(2026, 7, 31, 9)),
        _session(id: 'ws-aug-01', startedAt: DateTime(2026, 8, 1, 9)),
        _session(id: 'ws-aug-02', startedAt: DateTime(2026, 8, 2, 9)),
      ], now: DateTime(2026, 8, 2, 20));

      expect(history.currentStreakDays, 3);
      expect(history.longestStreakDays, 3);
    });

    test('a single session today is a one-day streak', () {
      final history = _history([
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9)),
      ]);

      expect(history.currentStreakDays, 1);
      expect(history.longestStreakDays, 1);
    });
  });

  group('deletions', () {
    test('a net deletion contributes zero words, never negative ones', () {
      final history = _history([
        WritingSession(
          id: 'ws-cut',
          projectId: 'project-a',
          startedAt: DateTime(2026, 8, 20, 9),
          endedAt: DateTime(2026, 8, 20, 9, 40),
          startingWordCount: 5000,
          endingWordCount: 4200,
          wordsAdded: 100,
          wordsRemoved: 900,
        ),
        _session(
            id: 'ws-write', startedAt: DateTime(2026, 8, 20, 11), words: 600),
      ]);

      expect(history.wordsToday, 600);
      expect(history.totalWordsWritten, 600);
      expect(history.sessionsToday, 2);
      expect(history.averageWordsPerSession, 300);
    });
  });

  group('through the Analytics Service', () {
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

    test('a project with no sessions reports an empty history', () async {
      final summary = await serviceFor(_project('project-a')).getSummary();

      expect(summary.writingHistory.hasSessions, isFalse);
      expect(summary.writingHistory.totalSessions, 0);
      expect(summary.writingHistory.currentStreakDays, 0);
    });

    test('recorded sessions surface on the summary', () async {
      await repository.putWritingSessions([
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 19, 9),
          duration: const Duration(minutes: 30),
          words: 900,
        ),
        _session(
          id: 'ws-2',
          startedAt: DateTime(2026, 8, 20, 9),
          duration: const Duration(minutes: 30),
          words: 600,
        ),
      ]);

      final summary = await serviceFor(_project('project-a')).getSummary();
      final history = summary.writingHistory;

      expect(history.hasSessions, isTrue);
      expect(history.totalSessions, 2);
      expect(history.totalWordsWritten, 1500);
      expect(history.wordsToday, 600);
      expect(history.currentStreakDays, 2);
      expect(history.averageWordsPerSession, 750);
    });

    test('one project\'s history never appears in another\'s analytics',
        () async {
      await repository.putWritingSessions([
        _session(
          id: 'ws-a',
          projectId: 'project-a',
          startedAt: DateTime(2026, 8, 20, 9),
          words: 500,
        ),
        _session(
          id: 'ws-b',
          projectId: 'project-b',
          startedAt: DateTime(2026, 8, 20, 9),
          words: 4200,
        ),
      ]);

      final summaryA = await serviceFor(_project('project-a')).getSummary();
      final summaryB = await serviceFor(_project('project-b')).getSummary();

      expect(summaryA.writingHistory.totalSessions, 1);
      expect(summaryA.writingHistory.totalWordsWritten, 500);
      expect(summaryB.writingHistory.totalSessions, 1);
      expect(summaryB.writingHistory.totalWordsWritten, 4200);
    });

    test('history does not disturb the existing current-state metrics',
        () async {
      await repository.putWritingSession(
        _session(
          id: 'ws-1',
          startedAt: DateTime(2026, 8, 20, 9),
          words: 500,
        ),
      );

      final summary =
          await serviceFor(_project('project-a', wordGoal: 1000)).getSummary();

      // Historical words written and the manuscript's current word count are
      // different questions: history never overwrites the live totals.
      expect(summary.writingHistory.totalWordsWritten, 500);
      expect(summary.totalWordCount, 0);
      expect(summary.targetWordCount, 1000);
      expect(summary.wordsRemaining, 1000);
      expect(summary.manuscriptStatus, isNotEmpty);
    });

    test('a summary is a snapshot: reading twice never changes history',
        () async {
      await repository.putWritingSession(
        _session(id: 'ws-1', startedAt: DateTime(2026, 8, 20, 9), words: 500),
      );
      final service = serviceFor(_project('project-a'));

      final first = await service.getSummary();
      final second = await service.getSummary();

      expect(first.writingHistory.totalSessions, 1);
      expect(second.writingHistory.totalSessions, 1);
      expect(
        second.writingHistory.totalWordsWritten,
        first.writingHistory.totalWordsWritten,
      );
    });

    test('the empty summary carries the empty history', () {
      final summary = AnalyticsSummary.empty(
        projectId: 'project-a',
        projectName: 'The Hollow Court',
      );

      expect(summary.writingHistory.hasSessions, isFalse);
      expect(summary.writingHistory.dailyTotals, isEmpty);
    });
  });
}
