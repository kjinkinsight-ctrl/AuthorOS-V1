/// Analytics Studio — the derivation layer.
///
/// This service owns no storage and no models of its own. It asks the Studios
/// that already own each domain — manuscript, characters, plot, timeline,
/// research — for what they hold, and folds the answers into one immutable
/// [AnalyticsSummary]. Every number it reports has to come back from one of
/// those services; nothing here invents a record, a count, or a second
/// definition of "what a chapter is".
///
/// Analytics is reproducible from source data: nothing calculated here is
/// persisted, and calculating never mutates a source record.
library;

import 'character_service.dart';
import 'core/connected_domain.dart';
import 'core/writing_goals.dart';
import 'core/writing_session.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';
import 'timeline_service.dart';
import 'writing_goals_store.dart';

/// A chapter highlighted by the analytics (longest or shortest).
class AnalyticsChapterStat {
  const AnalyticsChapterStat({required this.title, required this.wordCount});

  final String title;
  final int wordCount;
}

/// One local calendar day of writing history.
///
/// Days with no writing are represented explicitly rather than omitted, so a
/// weekly view can show the gaps that a streak cares about.
class AnalyticsWritingDay {
  const AnalyticsWritingDay({
    required this.day,
    required this.wordsWritten,
    required this.sessionCount,
    required this.writingTime,
  });

  /// Local midnight of the day described.
  final DateTime day;
  final int wordsWritten;
  final int sessionCount;
  final Duration writingTime;

  /// Whether the author wrote at all on this day. A writing day is one with
  /// at least one qualifying session — no word quota is imposed here.
  bool get hasWriting => sessionCount > 0;
}

/// Longitudinal writing metrics derived from recorded [WritingSession]s.
///
/// A dedicated, immutable section of [AnalyticsSummary]: it adds history
/// without disturbing the current-state metrics beside it. Everything here is
/// derived from one already-loaded list of sessions — no metric issues a
/// query of its own.
///
/// Every calendar boundary is the author's own local day, week (Monday-based,
/// ISO-8601), and month.
class AnalyticsWritingHistory {
  const AnalyticsWritingHistory({
    required this.totalSessions,
    required this.totalWordsWritten,
    required this.totalWritingTime,
    required this.longestSessionDuration,
    required this.mostProductiveSessionWords,
    required this.wordsToday,
    required this.sessionsToday,
    required this.writingTimeToday,
    required this.wordsThisWeek,
    required this.sessionsThisWeek,
    required this.writingTimeThisWeek,
    required this.dailyTotals,
    required this.writingDayCount,
    required this.wordsThisMonth,
    required this.sessionsThisMonth,
    required this.writingTimeThisMonth,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.firstSessionAt,
    required this.lastSessionAt,
  });

  /// A project with no recorded history: every total zero, no session dates,
  /// and no daily bars to draw. Consumers must render an empty state rather
  /// than a zeroed chart.
  const AnalyticsWritingHistory.empty()
      : totalSessions = 0,
        totalWordsWritten = 0,
        totalWritingTime = Duration.zero,
        longestSessionDuration = Duration.zero,
        mostProductiveSessionWords = 0,
        wordsToday = 0,
        sessionsToday = 0,
        writingTimeToday = Duration.zero,
        wordsThisWeek = 0,
        sessionsThisWeek = 0,
        writingTimeThisWeek = Duration.zero,
        dailyTotals = const [],
        writingDayCount = 0,
        wordsThisMonth = 0,
        sessionsThisMonth = 0,
        writingTimeThisMonth = Duration.zero,
        currentStreakDays = 0,
        longestStreakDays = 0,
        firstSessionAt = null,
        lastSessionAt = null;

  /// Folds recorded sessions into history metrics.
  ///
  /// [now] is the instant "today" is measured against; it defaults to the
  /// wall clock and exists so tests can pin a calendar. Sessions from other
  /// projects must never reach here: the repository query is project-scoped.
  factory AnalyticsWritingHistory.fromSessions(
    List<WritingSession> sessions, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    if (sessions.isEmpty) return const AnalyticsWritingHistory.empty();

    final ordered = [...sessions]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    var totalWords = 0;
    var totalTime = Duration.zero;
    var longest = Duration.zero;
    var mostProductive = 0;

    // One pass builds the per-day index every calendar metric reads from.
    final byDay = <DateTime, _DayAccumulator>{};
    for (final session in ordered) {
      totalWords += session.wordsWritten;
      totalTime += session.duration;
      if (session.duration > longest) longest = session.duration;
      if (session.wordsWritten > mostProductive) {
        mostProductive = session.wordsWritten;
      }
      byDay.putIfAbsent(session.localDay, _DayAccumulator.new).add(session);
    }

    final today = WritingCalendar.dayOf(at);
    final weekStart = WritingCalendar.weekStart(at);
    final monthStart = WritingCalendar.monthStart(at);

    final todayTotals = byDay[today] ?? _DayAccumulator();

    var weekWords = 0;
    var weekSessions = 0;
    var weekTime = Duration.zero;
    final dailyTotals = <AnalyticsWritingDay>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = WritingCalendar.addDays(weekStart, offset);
      final totals = byDay[day] ?? _DayAccumulator();
      weekWords += totals.words;
      weekSessions += totals.sessions;
      weekTime += totals.time;
      dailyTotals.add(
        AnalyticsWritingDay(
          day: day,
          wordsWritten: totals.words,
          sessionCount: totals.sessions,
          writingTime: totals.time,
        ),
      );
    }

    var monthWords = 0;
    var monthSessions = 0;
    var monthTime = Duration.zero;
    for (final entry in byDay.entries) {
      final day = entry.key;
      if (day.year == monthStart.year && day.month == monthStart.month) {
        monthWords += entry.value.words;
        monthSessions += entry.value.sessions;
        monthTime += entry.value.time;
      }
    }

    final writingDays = byDay.keys.toList()..sort();

    return AnalyticsWritingHistory(
      totalSessions: ordered.length,
      totalWordsWritten: totalWords,
      totalWritingTime: totalTime,
      longestSessionDuration: longest,
      mostProductiveSessionWords: mostProductive,
      wordsToday: todayTotals.words,
      sessionsToday: todayTotals.sessions,
      writingTimeToday: todayTotals.time,
      wordsThisWeek: weekWords,
      sessionsThisWeek: weekSessions,
      writingTimeThisWeek: weekTime,
      dailyTotals: List.unmodifiable(dailyTotals),
      writingDayCount: byDay.length,
      wordsThisMonth: monthWords,
      sessionsThisMonth: monthSessions,
      writingTimeThisMonth: monthTime,
      currentStreakDays: _currentStreak(writingDays.toSet(), today),
      longestStreakDays: _longestStreak(writingDays),
      firstSessionAt: ordered.first.startedAt,
      lastSessionAt: ordered.last.endedAt,
    );
  }

  // All time.
  final int totalSessions;
  final int totalWordsWritten;
  final Duration totalWritingTime;
  final Duration longestSessionDuration;
  final int mostProductiveSessionWords;

  // Today.
  final int wordsToday;
  final int sessionsToday;
  final Duration writingTimeToday;

  // This week (Monday-based, local).
  final int wordsThisWeek;
  final int sessionsThisWeek;
  final Duration writingTimeThisWeek;

  /// Monday through Sunday of the current local week, gaps included.
  final List<AnalyticsWritingDay> dailyTotals;

  /// Distinct local days carrying at least one recorded session, across the
  /// whole history. The denominator for "words on the days you write", kept
  /// beside the totals it shares a source with.
  final int writingDayCount;

  // This month (local).
  final int wordsThisMonth;
  final int sessionsThisMonth;
  final Duration writingTimeThisMonth;

  // Streaks.

  /// Consecutive local writing days ending today, or ending yesterday when
  /// the author has not written yet today. A streak is only broken by a full
  /// missed day, so it does not read as lost at every midnight.
  final int currentStreakDays;

  /// The longest consecutive run of writing days in the whole history.
  final int longestStreakDays;

  final DateTime? firstSessionAt;
  final DateTime? lastSessionAt;

  /// Whether anything has been recorded. False means "no history yet", which
  /// is not the same as "zero words written" and must not be shown as one.
  bool get hasSessions => totalSessions > 0;

  /// Mean session length, `Duration.zero` with no sessions.
  Duration get averageSessionDuration => totalSessions == 0
      ? Duration.zero
      : Duration(
          milliseconds: totalWritingTime.inMilliseconds ~/ totalSessions,
        );

  /// Mean words per session, `0` with no sessions.
  int get averageWordsPerSession =>
      totalSessions == 0 ? 0 : totalWordsWritten ~/ totalSessions;

  /// Words per hour across all recorded writing time, or `null` when no
  /// measurable time was recorded — a rate over zero time is not a rate.
  double? get averageWordsPerHour {
    final hours = totalWritingTime.inMilliseconds / 3600000;
    if (hours <= 0) return null;
    return totalWordsWritten / hours;
  }

  /// The busiest recorded day in the current week, or `null` when nothing was
  /// written this week.
  AnalyticsWritingDay? get bestDayThisWeek {
    AnalyticsWritingDay? best;
    for (final day in dailyTotals) {
      if (!day.hasWriting) continue;
      if (best == null || day.wordsWritten > best.wordsWritten) best = day;
    }
    return best;
  }

  static int _currentStreak(Set<DateTime> writingDays, DateTime today) {
    if (writingDays.isEmpty) return 0;
    var cursor = writingDays.contains(today)
        ? today
        : WritingCalendar.addDays(today, -1);
    if (!writingDays.contains(cursor)) return 0;
    var streak = 0;
    while (writingDays.contains(cursor)) {
      streak++;
      cursor = WritingCalendar.addDays(cursor, -1);
    }
    return streak;
  }

  static int _longestStreak(List<DateTime> sortedWritingDays) {
    if (sortedWritingDays.isEmpty) return 0;
    var longest = 1;
    var run = 1;
    for (var index = 1; index < sortedWritingDays.length; index++) {
      final expected = WritingCalendar.addDays(sortedWritingDays[index - 1], 1);
      run = sortedWritingDays[index] == expected ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    return longest;
  }
}

/// Writing pace, derived from the same folded history the totals come from.
///
/// It holds the [AnalyticsWritingHistory] rather than copying numbers out of
/// it, so "average session words" here and on the history card are one value
/// rather than two definitions free to drift apart.
///
/// Every rate is `null` rather than `0` when its denominator is zero. A pace
/// over no days is not a pace, and showing it as zero would be a claim the
/// author's history does not support.
class AnalyticsVelocity {
  const AnalyticsVelocity({required this.history, required this.daysElapsed});

  /// A project with nothing recorded: no history, no elapsed span, no rates.
  const AnalyticsVelocity.empty()
      : history = const AnalyticsWritingHistory.empty(),
        daysElapsed = 0;

  /// Measures pace against [now], the same instant the history was folded at.
  factory AnalyticsVelocity.fromHistory(
    AnalyticsWritingHistory history, {
    required DateTime now,
  }) {
    final first = history.firstSessionAt;
    if (!history.hasSessions || first == null) {
      return const AnalyticsVelocity.empty();
    }
    // Inclusive of both ends: writing 500 words this afternoon is 500 words
    // in one day, not 500 words in zero days.
    final spanned = WritingCalendar.daysBetween(first, now) + 1;
    return AnalyticsVelocity(
      history: history,
      // A clock behind the first session still describes one day of writing.
      daysElapsed: spanned < 1 ? 1 : spanned,
    );
  }

  final AnalyticsWritingHistory history;

  /// Calendar days from the first recorded session through today, inclusive.
  final int daysElapsed;

  static const daysPerWeek = 7.0;

  /// The mean Gregorian month, 365.2425 / 12. One constant, so weekly and
  /// monthly velocity can never be scaled by two different ideas of a month.
  static const daysPerMonth = 30.436875;

  bool get hasVelocity => history.hasSessions && daysElapsed > 0;

  /// Days the author actually wrote on, as against [daysElapsed].
  int get daysWritten => history.writingDayCount;

  /// Words per elapsed calendar day — the pace actually sustained, rest days
  /// included.
  ///
  /// This is the honest denominator for a finish date: dividing by the days
  /// the author wrote on would quietly assume they write every day, and would
  /// promise a completion date to anyone who takes weekends that they cannot
  /// meet.
  double? get averageDailyWords =>
      hasVelocity ? history.totalWordsWritten / daysElapsed : null;

  /// Words per day *on the days the author writes*. Deliberately a different,
  /// higher number than [averageDailyWords], and never used for prediction.
  double? get averageWordsPerWritingDay =>
      daysWritten == 0 ? null : history.totalWordsWritten / daysWritten;

  /// Forwarded from the history, not recomputed: one definition per number.
  int get averageSessionWords => history.averageWordsPerSession;

  /// Forwarded from the history, `null` when no measurable time was recorded.
  double? get averageWordsPerHour => history.averageWordsPerHour;

  /// The daily pace projected across a week. Scaled from [averageDailyWords]
  /// rather than measured against its own elapsed-weeks denominator, so the
  /// three velocities on one screen can never contradict each other.
  double? get weeklyVelocity {
    final daily = averageDailyWords;
    return daily == null ? null : daily * daysPerWeek;
  }

  /// The daily pace projected across a mean month. Scaled the same way, from
  /// the same daily rate.
  double? get monthlyVelocity {
    final daily = averageDailyWords;
    return daily == null ? null : daily * daysPerMonth;
  }
}

/// When the manuscript reaches its target at the pace the author is keeping.
///
/// The one place AuthorOS makes a forward-looking claim, so it is deliberately
/// reluctant: without a target, without a measured pace, or past the target
/// there is no projection at all, and the consumer must say so rather than
/// render a zero.
class AnalyticsProjection {
  const AnalyticsProjection({
    required this.currentWords,
    required this.targetWords,
    required this.wordsRemaining,
    required this.averageDailyWords,
    required this.estimatedDaysToCompletion,
    required this.projectedCompletionDate,
  });

  /// No target, no pace, or nothing recorded: every projected value absent.
  const AnalyticsProjection.unavailable()
      : currentWords = 0,
        targetWords = null,
        wordsRemaining = null,
        averageDailyWords = null,
        estimatedDaysToCompletion = null,
        projectedCompletionDate = null;

  /// Beyond a decade out, the honest answer is "not enough history to say"
  /// rather than a date. Also the guard that keeps a non-finite estimate away
  /// from [double.ceil], which throws on infinity.
  static const maximumProjectedDays = 3650;

  /// Builds a projection from values the summary has already settled.
  ///
  /// [wordsRemaining] is passed in rather than recomputed so the projection
  /// panel and the progress card can never print different remainders.
  factory AnalyticsProjection.from({
    required int currentWords,
    required int? targetWords,
    required int? wordsRemaining,
    required double? averageDailyWords,
    required DateTime now,
  }) {
    // No target set: there is nothing to finish, so nothing to project.
    if (targetWords == null || targetWords <= 0) {
      return const AnalyticsProjection.unavailable();
    }

    // Past the target already. Report the state, not a date.
    if (wordsRemaining == null || wordsRemaining <= 0) {
      return AnalyticsProjection(
        currentWords: currentWords,
        targetWords: targetWords,
        wordsRemaining: 0,
        averageDailyWords: averageDailyWords,
        estimatedDaysToCompletion: null,
        projectedCompletionDate: null,
      );
    }

    // A target and words to go, but no measured pace: say the words remain,
    // and refuse to name a day.
    if (averageDailyWords == null || averageDailyWords <= 0) {
      return AnalyticsProjection(
        currentWords: currentWords,
        targetWords: targetWords,
        wordsRemaining: wordsRemaining,
        averageDailyWords: averageDailyWords,
        estimatedDaysToCompletion: null,
        projectedCompletionDate: null,
      );
    }

    final estimate = wordsRemaining / averageDailyWords;
    if (!estimate.isFinite || estimate > maximumProjectedDays) {
      return AnalyticsProjection(
        currentWords: currentWords,
        targetWords: targetWords,
        wordsRemaining: wordsRemaining,
        averageDailyWords: averageDailyWords,
        estimatedDaysToCompletion: null,
        projectedCompletionDate: null,
      );
    }

    // Rounded to the nearest whole day, because the sentence this feeds says
    // "approximately" — and floored at one, because however few words are
    // left, finishing them still takes a day of writing.
    final rounded = estimate.round();
    final days = rounded < 1 ? 1 : rounded;
    return AnalyticsProjection(
      currentWords: currentWords,
      targetWords: targetWords,
      wordsRemaining: wordsRemaining,
      averageDailyWords: averageDailyWords,
      estimatedDaysToCompletion: days,
      projectedCompletionDate:
          WritingCalendar.addDays(WritingCalendar.dayOf(now), days),
    );
  }

  final int currentWords;

  /// The manuscript's word target, or `null` when none is set.
  final int? targetWords;

  /// Words left to write, `0` once the target is reached, `null` without one.
  final int? wordsRemaining;

  /// The pace the projection was built from, carried so the panel can show
  /// the author what the estimate rests on.
  final double? averageDailyWords;

  /// Whole days of writing left at the current pace, rounded to the nearest
  /// day and never below one. `null` when no honest estimate exists.
  final int? estimatedDaysToCompletion;

  /// Local midnight of the projected finishing day, or `null` with no estimate.
  final DateTime? projectedCompletionDate;

  bool get hasTarget => (targetWords ?? 0) > 0;

  /// Whether the manuscript has already reached its target.
  bool get isComplete => hasTarget && (wordsRemaining ?? 0) <= 0;

  /// Whether a finishing day can be named. False is a legitimate, common
  /// answer, and consumers must render it as such.
  bool get hasProjection =>
      estimatedDaysToCompletion != null && projectedCompletionDate != null;
}

/// Progress against the author's own daily, weekly, and monthly goals.
///
/// The actuals are the history's own today/week/month totals: this class
/// compares, it does not count. A goal of `0` yields `null` rather than a
/// percentage, mirroring the manuscript target's "no target, no percentage"
/// rule.
class AnalyticsGoalProgress {
  const AnalyticsGoalProgress({
    required this.goals,
    required this.wordsToday,
    required this.wordsThisWeek,
    required this.wordsThisMonth,
  });

  /// The seeded goals with nothing yet written against them.
  const AnalyticsGoalProgress.empty()
      : goals = WritingGoals.seedDefaults,
        wordsToday = 0,
        wordsThisWeek = 0,
        wordsThisMonth = 0;

  factory AnalyticsGoalProgress.from({
    required WritingGoals goals,
    required AnalyticsWritingHistory history,
  }) =>
      AnalyticsGoalProgress(
        goals: goals,
        wordsToday: history.wordsToday,
        wordsThisWeek: history.wordsThisWeek,
        wordsThisMonth: history.wordsThisMonth,
      );

  final WritingGoals goals;
  final int wordsToday;
  final int wordsThisWeek;
  final int wordsThisMonth;

  double? get dailyProgress => _progress(wordsToday, goals.dailyWords);
  double? get weeklyProgress => _progress(wordsThisWeek, goals.weeklyWords);
  double? get monthlyProgress => _progress(wordsThisMonth, goals.monthlyWords);

  int? get dailyWordsRemaining => _remaining(wordsToday, goals.dailyWords);
  int? get weeklyWordsRemaining => _remaining(wordsThisWeek, goals.weeklyWords);
  int? get monthlyWordsRemaining =>
      _remaining(wordsThisMonth, goals.monthlyWords);

  /// A goal that is not set is never "met" — there was nothing to meet.
  bool get dailyGoalMet => goals.hasDailyGoal && wordsToday >= goals.dailyWords;
  bool get weeklyGoalMet =>
      goals.hasWeeklyGoal && wordsThisWeek >= goals.weeklyWords;
  bool get monthlyGoalMet =>
      goals.hasMonthlyGoal && wordsThisMonth >= goals.monthlyWords;

  static double? _progress(int written, int goal) =>
      goal <= 0 ? null : (written / goal).clamp(0.0, 1.0);

  static int? _remaining(int written, int goal) =>
      goal <= 0 ? null : (goal - written).clamp(0, goal);
}

/// Per-day running totals used while folding sessions. Private on purpose:
/// what leaves this file is the immutable [AnalyticsWritingDay].
class _DayAccumulator {
  int words = 0;
  int sessions = 0;
  Duration time = Duration.zero;

  void add(WritingSession session) {
    words += session.wordsWritten;
    sessions++;
    time += session.duration;
  }
}

/// Stable, presentation-independent analytics for one project.
///
/// The summary stores only source-derived values; ratios are computed from
/// those values so repeated reads can never disagree with each other. Optional
/// data stays optional: when no writing target exists the target-relative
/// getters return `null` rather than a misleading `0%`.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.projectId,
    required this.projectName,
    required this.manuscriptStatus,
    required this.totalWordCount,
    required this.chapterCount,
    required this.sceneCount,
    required this.characterCount,
    required this.timelineEventCount,
    required this.plotRecordCount,
    required this.researchItemCount,
    required this.targetWordCount,
    required this.chaptersByStatus,
    required this.longestChapter,
    required this.shortestChapter,
    required this.charactersWithProfiles,
    required this.charactersWithRelationships,
    required this.charactersReferencedInManuscript,
    required this.activePlotThreadCount,
    required this.completedPlotThreadCount,
    this.scenesByStatus = const {},
    this.writingHistory = const AnalyticsWritingHistory.empty(),
    this.goalProgress = const AnalyticsGoalProgress.empty(),
    this.velocity = const AnalyticsVelocity.empty(),
    this.projection = const AnalyticsProjection.unavailable(),
  });

  /// An empty project: every count zero, every optional value absent.
  factory AnalyticsSummary.empty({
    required String projectId,
    required String projectName,
    int targetWordCount = 0,
  }) =>
      AnalyticsSummary(
        projectId: projectId,
        projectName: projectName,
        manuscriptStatus: 'Not started',
        totalWordCount: 0,
        chapterCount: 0,
        sceneCount: 0,
        characterCount: 0,
        timelineEventCount: 0,
        plotRecordCount: 0,
        researchItemCount: 0,
        targetWordCount: targetWordCount,
        chaptersByStatus: const {},
        longestChapter: null,
        shortestChapter: null,
        charactersWithProfiles: 0,
        charactersWithRelationships: 0,
        charactersReferencedInManuscript: 0,
        activePlotThreadCount: 0,
        completedPlotThreadCount: 0,
        scenesByStatus: const {},
        writingHistory: const AnalyticsWritingHistory.empty(),
        goalProgress: const AnalyticsGoalProgress.empty(),
        velocity: const AnalyticsVelocity.empty(),
        projection: const AnalyticsProjection.unavailable(),
      );

  // Project overview.
  final String projectId;
  final String projectName;

  /// Derived manuscript status label: `Not started`, `Drafting`, `Revising`,
  /// or `Complete`. Derived from chapter statuses, never stored.
  final String manuscriptStatus;

  final int totalWordCount;
  final int chapterCount;
  final int sceneCount;
  final int characterCount;
  final int timelineEventCount;
  final int plotRecordCount;
  final int researchItemCount;

  // Writing progress.

  /// The project's writing goal in words. `0` means no target was set.
  final int targetWordCount;

  /// Whether the author set a writing target. Consumers must not render a
  /// percentage when this is false.
  bool get hasWritingTarget => targetWordCount > 0;

  /// Progress toward the target in `0.0..1.0`, or `null` without a target.
  double? get progressTowardTarget => hasWritingTarget
      ? (totalWordCount / targetWordCount).clamp(0.0, 1.0)
      : null;

  /// Progress toward the target in `0..100`, or `null` without a target.
  double? get percentTowardTarget {
    final progress = progressTowardTarget;
    return progress == null ? null : progress * 100;
  }

  /// Words left before the target is reached, or `null` without a target.
  /// Never negative: overshooting the goal leaves zero words remaining.
  int? get wordsRemaining => hasWritingTarget
      ? (targetWordCount - totalWordCount).clamp(0, targetWordCount)
      : null;

  /// Whole words per chapter, `0` when the manuscript has no chapters.
  int get averageWordsPerChapter =>
      chapterCount == 0 ? 0 : totalWordCount ~/ chapterCount;

  /// Whole words per scene, `0` when the manuscript has no scenes.
  int get averageWordsPerScene =>
      sceneCount == 0 ? 0 : totalWordCount ~/ sceneCount;

  final AnalyticsChapterStat? longestChapter;
  final AnalyticsChapterStat? shortestChapter;

  // Chapter analytics.

  /// Chapter counts keyed by [ManuscriptNodeStatus.id]
  /// (`planned`, `draft`, `revising`, `complete`).
  final Map<String, int> chaptersByStatus;

  int get completedChapterCount =>
      chaptersByStatus[ManuscriptNodeStatus.complete.id] ?? 0;

  int get draftChapterCount =>
      chaptersByStatus[ManuscriptNodeStatus.draft.id] ?? 0;

  /// Scene counts keyed by [ManuscriptNodeStatus.id], the same shape and the
  /// same keys as [chaptersByStatus]. Empty when the manuscript has no
  /// scenes — an empty map, never a zero-filled one, so "no scenes" stays
  /// distinguishable from "no scenes finished".
  final Map<String, int> scenesByStatus;

  int get completedSceneCount =>
      scenesByStatus[ManuscriptNodeStatus.complete.id] ?? 0;

  int get draftSceneCount =>
      scenesByStatus[ManuscriptNodeStatus.draft.id] ?? 0;

  /// Alias for [averageWordsPerChapter], the chapter panel's vocabulary.
  int get averageChapterLength => averageWordsPerChapter;

  // Character analytics.

  /// Characters with at least one profile field filled in beyond the
  /// identity fields every character record is created with.
  final int charactersWithProfiles;

  /// Characters with at least one relationship connection to another record.
  final int charactersWithRelationships;

  /// Characters whose name appears in the manuscript's scene content.
  final int charactersReferencedInManuscript;

  // Story analytics.

  /// Plot records that are being actively worked (not resolved or abandoned).
  final int activePlotThreadCount;

  /// Plot records marked resolved or completed.
  final int completedPlotThreadCount;

  // Writing history.

  /// Longitudinal metrics derived from recorded writing sessions.
  ///
  /// Presentation-independent like the rest of the summary, so any consumer —
  /// Analytics Studio today, the World Board later — reads the same numbers.
  /// A project with no recorded sessions carries
  /// [AnalyticsWritingHistory.empty]; consumers must show that as "no history
  /// yet" rather than as a failed writing day.
  final AnalyticsWritingHistory writingHistory;

  /// The author's daily, weekly, and monthly goals and how far through them
  /// this project's recorded writing has got.
  final AnalyticsGoalProgress goalProgress;

  /// Writing pace over the recorded history. Holds the same
  /// [AnalyticsWritingHistory] instance as [writingHistory], so the pace and
  /// the totals it derives from can never disagree.
  final AnalyticsVelocity velocity;

  /// When the manuscript reaches its target at the current pace.
  final AnalyticsProjection projection;

  /// The author's goals for this project, seeded with the defaults when they
  /// have never been edited. Carried here so every consumer reads one set of
  /// targets.
  WritingGoals get writingGoals => goalProgress.goals;

  /// Overall completion toward the writing target; `null` without a target.
  double? get completionPercent => percentTowardTarget;
}

/// Derives [AnalyticsSummary] from the existing AuthorOS services.
///
/// Mirrors [WorldBoardService]'s shape so the two aggregation layers stay
/// interchangeable: the project comes from the shell, the repository defaults
/// to the app-wide [authorOsRepository], and the manuscript is read through
/// the Manuscript Studio's own store.
class AnalyticsService {
  const AnalyticsService({
    required this.project,
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
    WritingGoalsStore? goalsStore,
    DateTime Function()? clock,
  })  : _repository = repository,
        _goalsStore = goalsStore,
        _clock = clock;

  /// The project the shell currently has open.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;

  final WritingGoalsStore? _goalsStore;

  /// The instant "today", "this week", and "this month" are measured against.
  /// Defaults to the wall clock; injectable so tests can pin a calendar.
  final DateTime Function()? _clock;

  /// Reused rather than re-implemented: word, chapter, and scene counts are
  /// the Manuscript Studio's to define.
  final ManuscriptStore manuscriptStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The goals collaborator, resolved against this service's own repository
  /// so an injected test database is used for goals too.
  ///
  /// Read here and written elsewhere: analytics derives, it does not persist.
  /// The Analytics Studio edits goals through its own store, never through
  /// this one.
  WritingGoalsStore get goalsStore =>
      _goalsStore ?? WritingGoalsStore(repository: repository);

  DateTime get _now => (_clock ?? DateTime.now)();

  /// The character record type, as the Characters Studio defines it.
  static const characterTypeId = 'character';

  /// Research lives in the record system under two type ids: the built-in
  /// `research-entry` type and its selectable `research` alias. Both resolve
  /// to the Codex `research` category, so counting both matches the Codex.
  static const researchTypeIds = ['research-entry', 'research'];

  CharacterService get characters =>
      CharacterService(projectId: project.id, repository: repository);

  TimelineService get timeline =>
      TimelineService(projectId: project.id, repository: repository);

  PlotService get plot =>
      PlotService(projectId: project.id, repository: repository);

  /// Loads every source once and folds it into one summary.
  ///
  /// The record queries run in turn: they share one database connection, and
  /// a dashboard that opens in a few milliseconds does not need to race them.
  /// The manuscript is read separately because it does not live in the record
  /// repository.
  Future<AnalyticsSummary> getSummary() async {
    final manuscript = await loadManuscript();

    final characterRecords = await _activeCharacters();
    final timelineRecords = _active(await timeline.query.all());
    final plotRecords = _active(await plot.query.all());
    final researchRecords = await _activeResearch();

    // One query for the whole history. Every historical metric is folded out
    // of this immutable list, so no card costs a database round trip.
    final sessions = await repository.writingSessionsForProject(project.id);

    // The author's own pace targets, seeded with the defaults when they have
    // never been edited. Read only — the Studio owns the write path.
    final goals = await goalsStore.load(project.id);

    final chapters = manuscript.chapters;
    final chaptersByStatus = <String, int>{};
    final scenesByStatus = <String, int>{};
    for (final chapter in chapters) {
      chaptersByStatus.update(
        chapter.status.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      for (final scene in chapter.scenes) {
        scenesByStatus.update(
          scene.status.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    ManuscriptChapter? longest;
    ManuscriptChapter? shortest;
    for (final chapter in chapters) {
      if (longest == null || chapter.wordCount > longest.wordCount) {
        longest = chapter;
      }
      if (shortest == null || chapter.wordCount < shortest.wordCount) {
        shortest = chapter;
      }
    }

    final charactersWithRelationships =
        await _countCharactersWithRelationships(characterRecords);

    // One folded history feeds the totals, the pace, and the goal progress,
    // so the three sections of the dashboard cannot disagree.
    final at = _now;
    final history = AnalyticsWritingHistory.fromSessions(sessions, now: at);
    final velocity = AnalyticsVelocity.fromHistory(history, now: at);

    final targetWordCount = project.wordGoal < 0 ? 0 : project.wordGoal;
    final wordsRemaining = targetWordCount > 0
        ? (targetWordCount - manuscript.wordCount).clamp(0, targetWordCount)
        : null;

    return AnalyticsSummary(
      projectId: project.id,
      projectName: project.title,
      manuscriptStatus: _manuscriptStatus(manuscript),
      totalWordCount: manuscript.wordCount,
      chapterCount: manuscript.chapterCount,
      sceneCount: manuscript.sceneCount,
      characterCount: characterRecords.length,
      timelineEventCount: timelineRecords.length,
      plotRecordCount: plotRecords.length,
      researchItemCount: researchRecords.length,
      targetWordCount: targetWordCount,
      chaptersByStatus: Map.unmodifiable(chaptersByStatus),
      scenesByStatus: Map.unmodifiable(scenesByStatus),
      longestChapter: longest == null
          ? null
          : AnalyticsChapterStat(
              title: longest.title,
              wordCount: longest.wordCount,
            ),
      shortestChapter: shortest == null
          ? null
          : AnalyticsChapterStat(
              title: shortest.title,
              wordCount: shortest.wordCount,
            ),
      charactersWithProfiles: characterRecords
          .where(_hasProfileBeyondIdentity)
          .length,
      charactersWithRelationships: charactersWithRelationships,
      charactersReferencedInManuscript:
          _countCharactersReferenced(characterRecords, manuscript),
      activePlotThreadCount:
          plotRecords.where(_isActivePlotThread).length,
      completedPlotThreadCount:
          plotRecords.where(_isCompletedPlotThread).length,
      writingHistory: history,
      goalProgress: AnalyticsGoalProgress.from(
        goals: goals,
        history: history,
      ),
      velocity: velocity,
      projection: AnalyticsProjection.from(
        currentWords: manuscript.wordCount,
        targetWords: targetWordCount,
        wordsRemaining: wordsRemaining,
        averageDailyWords: velocity.averageDailyWords,
        now: at,
      ),
    );
  }

  /// Reads the manuscript through the Manuscript Studio's own store, seeded
  /// exactly the way the Statistics Studio seeds it, so every screen reports
  /// the same word count for the same project.
  ///
  /// Public because the World Board needs the same manuscript to name its
  /// chapters, and a second seeding routine over there would be a second way
  /// for a project to have chapters.
  ///
  /// It reads; it never writes. That is now true. It previously called
  /// `ManuscriptStore.loadStudio`, which seeds a starter manuscript and saves
  /// it when a project has none — and saving projects chapter and scene nodes
  /// into `connected_entities` and `manuscript_node_rows`. Opening the
  /// Analytics dashboard or the World Board on a fresh project therefore
  /// created graph nodes, with version and audit entries describing edits the
  /// author never made.
  ///
  /// A project with no manuscript now reports an empty one. Seeding stays with
  /// Manuscript Studio, where the author opening the manuscript is the act
  /// that should create it.
  Future<ManuscriptProjectSummary> loadManuscript() async =>
      await manuscriptStore.peekStudio(project.id) ?? _emptyManuscript();

  ManuscriptProjectSummary _emptyManuscript() => ManuscriptProjectSummary(
        projectId: project.id,
        manuscriptTitle: project.title,
        chapters: const [],
        currentChapterId: '',
        currentSceneId: '',
        // A manuscript that does not exist has no meaningful timestamps. The
        // epoch is the honest stand-in; inventing "now" would make an absent
        // manuscript look freshly edited in every report that reads it.
        createdAt: DateTime.utc(1970),
        updatedAt: DateTime.utc(1970),
        version: 1,
      );

  /// Characters as the Characters Studio lists them: project-scoped records
  /// of the character type that have not been deleted.
  Future<List<AuthorRecord>> _activeCharacters() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: characterTypeId,
      scopeId: project.id,
    );
    return _active(records);
  }

  Future<List<AuthorRecord>> _activeResearch() async {
    final records = <AuthorRecord>[];
    for (final typeId in researchTypeIds) {
      records.addAll(
        await repository.recordsByTypeAndScope(
          typeId: typeId,
          scopeId: project.id,
        ),
      );
    }
    return _active(records);
  }

  Future<int> _countCharactersWithRelationships(
    List<AuthorRecord> characterRecords,
  ) async {
    var count = 0;
    for (final record in characterRecords) {
      final relationships =
          await characters.getCharacterRelationships(record.id);
      if (relationships.isNotEmpty) count++;
    }
    return count;
  }

  /// The manuscript status label the dashboard shows. A manuscript with no
  /// chapters and no words has not been started; one whose chapters are all
  /// complete is complete; revision anywhere outranks drafting.
  String _manuscriptStatus(ManuscriptProjectSummary manuscript) {
    final chapters = manuscript.chapters;
    if (chapters.isEmpty && manuscript.wordCount == 0) return 'Not started';
    if (chapters.isNotEmpty &&
        chapters.every(
          (chapter) => chapter.status == ManuscriptNodeStatus.complete,
        )) {
      return 'Complete';
    }
    if (chapters.any(
      (chapter) => chapter.status == ManuscriptNodeStatus.revising,
    )) {
      return 'Revising';
    }
    return 'Drafting';
  }

  /// Whether a character record carries profile data beyond the identity
  /// fields [CharacterService.createCharacter] seeds on every record.
  bool _hasProfileBeyondIdentity(AuthorRecord record) {
    for (final entry in record.fields.entries) {
      if (entry.key == 'identity.displayName' ||
          entry.key == 'identity.fullName') {
        continue;
      }
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is Iterable && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      return true;
    }
    return false;
  }

  int _countCharactersReferenced(
    List<AuthorRecord> characterRecords,
    ManuscriptProjectSummary manuscript,
  ) {
    if (characterRecords.isEmpty) return 0;
    final buffer = StringBuffer();
    for (final chapter in manuscript.chapters) {
      for (final scene in chapter.scenes) {
        buffer
          ..write(scene.content)
          ..write('\n');
      }
    }
    final content = buffer.toString().toLowerCase();
    if (content.trim().isEmpty) return 0;
    var count = 0;
    for (final record in characterRecords) {
      final name = record.title.trim().toLowerCase();
      if (name.isEmpty) continue;
      if (content.contains(name)) count++;
    }
    return count;
  }

  /// Mirrors the Plot Studio's own status semantics: `plotStatus` defaults to
  /// `planned`, and a thread is active while its record is active and it has
  /// not been resolved, completed, or abandoned.
  String _plotStatus(AuthorRecord record) =>
      '${record.fields['plotStatus'] ?? ''}'.trim().toLowerCase();

  bool _isCompletedPlotThread(AuthorRecord record) {
    final status = _plotStatus(record);
    return status == 'resolved' || status == 'completed';
  }

  bool _isActivePlotThread(AuthorRecord record) {
    final status = _plotStatus(record);
    return record.status == AuthorRecordStatus.active &&
        status != 'resolved' &&
        status != 'completed' &&
        status != 'abandoned';
  }

  List<AuthorRecord> _active(List<AuthorRecord> records) => records
      .where((record) => record.status != AuthorRecordStatus.deleted)
      .toList();
}
