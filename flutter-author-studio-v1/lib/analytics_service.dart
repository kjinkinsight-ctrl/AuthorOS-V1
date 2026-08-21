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
import 'core/writing_session.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';
import 'timeline_service.dart';

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
    this.writingHistory = const AnalyticsWritingHistory.empty(),
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
        writingHistory: const AnalyticsWritingHistory.empty(),
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
    DateTime Function()? clock,
  })  : _repository = repository,
        _clock = clock;

  /// The project the shell currently has open.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;

  /// The instant "today", "this week", and "this month" are measured against.
  /// Defaults to the wall clock; injectable so tests can pin a calendar.
  final DateTime Function()? _clock;

  /// Reused rather than re-implemented: word, chapter, and scene counts are
  /// the Manuscript Studio's to define.
  final ManuscriptStore manuscriptStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

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
    final manuscript = await _loadManuscript();

    final characterRecords = await _activeCharacters();
    final timelineRecords = _active(await timeline.query.all());
    final plotRecords = _active(await plot.query.all());
    final researchRecords = await _activeResearch();

    // One query for the whole history. Every historical metric is folded out
    // of this immutable list, so no card costs a database round trip.
    final sessions = await repository.writingSessionsForProject(project.id);

    final chapters = manuscript.chapters;
    final chaptersByStatus = <String, int>{};
    for (final chapter in chapters) {
      chaptersByStatus.update(
        chapter.status.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
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
      targetWordCount: project.wordGoal < 0 ? 0 : project.wordGoal,
      chaptersByStatus: Map.unmodifiable(chaptersByStatus),
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
      writingHistory: AnalyticsWritingHistory.fromSessions(
        sessions,
        now: _now,
      ),
    );
  }

  /// Reads the manuscript through the Manuscript Studio's own store, seeded
  /// exactly the way the Statistics Studio and World Board seed it, so every
  /// screen reports the same word count for the same project.
  Future<ManuscriptProjectSummary> _loadManuscript() async {
    final migrated = await manuscriptStore.loadLegacyChapterSeeds(project.id);
    final seeds = migrated.isNotEmpty
        ? migrated
        : project.chapters
            .map(
              (chapter) => ManuscriptChapterSeed(
                title: chapter.title,
                prompt: chapter.prompt,
                status: chapter.status,
                scenes: chapter.scenes,
                linkedChapterIds: chapter.linkedChapterIds,
              ),
            )
            .toList();
    return manuscriptStore.loadStudio(
      project.id,
      manuscriptTitle: project.title,
      defaultChapters: seeds,
      firstSceneTitle: project.firstSceneTitle,
    );
  }

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
