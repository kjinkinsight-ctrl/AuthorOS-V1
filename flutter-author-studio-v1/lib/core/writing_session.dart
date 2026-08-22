/// Writing session history — the domain layer.
///
/// A [WritingSession] is an immutable historical record of one stretch of
/// meaningful writing activity in one project. Sessions are what make
/// longitudinal analytics — daily totals, weekly totals, streaks, averages —
/// possible at all: AuthorOS otherwise knows only the manuscript's *current*
/// state, never how it got there.
///
/// Two rules govern this file:
///
/// * It is presentation-independent. Nothing here imports Flutter, and
///   nothing here formats a value for a screen.
/// * It owns no word-count algorithm. Word counts arrive from the Manuscript
///   Studio's canonical `ManuscriptProjectSummary.wordCount`; this layer only
///   subtracts one observation from another.
library;

/// Identity for writing sessions.
///
/// Mirrors `ManuscriptId` so ids stay recognisable across the codebase:
/// a prefix, the creation instant in microseconds, and a monotonic counter so
/// two sessions created inside the same microsecond can never collide.
class WritingSessionId {
  WritingSessionId._();

  static int _sequence = 0;

  static String create([DateTime? at]) =>
      'writing_session_${(at ?? DateTime.now()).microsecondsSinceEpoch}'
      '_${_sequence++}';
}

/// The single place the "is this a real writing session?" question is answered.
///
/// Recording every keystroke burst would produce thousands of meaningless
/// one-word rows and make every historical metric noise. These three values
/// are the only thresholds in the feature; nothing else in the codebase may
/// hard-code a session cutoff.
class WritingSessionThresholds {
  const WritingSessionThresholds({
    this.minimumWordsWritten = 10,
    this.minimumDuration = const Duration(minutes: 1),
    this.idleTimeout = const Duration(minutes: 5),
  });

  /// Net words that qualify a session on their own, however short it was.
  ///
  /// Ten words is roughly one sentence: below that an edit is a typo fix or a
  /// name change, not a writing session worth remembering.
  final int minimumWordsWritten;

  /// Active writing time that qualifies a session that changed the manuscript
  /// but produced few or no net new words.
  ///
  /// This is what keeps honest revision sessions — a minute of rewriting that
  /// ends level or shorter — in the history instead of discarding them.
  final Duration minimumDuration;

  /// How long a session may sit without any writing activity before the next
  /// keystroke is treated as the start of a new session rather than a
  /// continuation of the old one.
  ///
  /// Without this, an editor left open overnight would report a fourteen-hour
  /// "session" and destroy every duration average.
  final Duration idleTimeout;

  /// Whether a finished session is worth persisting.
  ///
  /// Qualifying takes either enough words, or enough active time paired with
  /// *some* change to the manuscript. A session that changed nothing never
  /// qualifies, however long the editor stayed open.
  bool qualifies({
    required int wordsWritten,
    required int wordsAdded,
    required int wordsRemoved,
    required Duration duration,
  }) {
    if (wordsWritten >= minimumWordsWritten) return true;
    final changed = wordsAdded > 0 || wordsRemoved > 0;
    return changed && duration >= minimumDuration;
  }
}

/// Local-calendar arithmetic for writing history.
///
/// Every user-facing boundary — today, this week, this month, a streak — is
/// the author's own calendar day, not UTC. A session that lands at 23:40 local
/// time belongs to that local day even where UTC has already rolled over.
class WritingCalendar {
  WritingCalendar._();

  /// Midnight, in local time, of the calendar day [instant] falls on.
  static DateTime dayOf(DateTime instant) {
    final local = instant.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Midnight local time on the Monday of [instant]'s week (ISO-8601 weeks).
  static DateTime weekStart(DateTime instant) {
    final day = dayOf(instant);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Midnight local time on the first day of [instant]'s month.
  static DateTime monthStart(DateTime instant) {
    final local = instant.toLocal();
    return DateTime(local.year, local.month);
  }

  /// Whether two instants fall on the same local calendar day.
  static bool isSameDay(DateTime a, DateTime b) => dayOf(a) == dayOf(b);

  /// Whole calendar days from [from]'s local day to [to]'s local day.
  ///
  /// Counted between UTC-normalized midnights rather than by subtracting the
  /// two instants: a daylight-saving day is 23 or 25 hours long, and
  /// `difference().inDays` would truncate one of those to the wrong count.
  /// Negative when [to] falls before [from].
  static int daysBetween(DateTime from, DateTime to) {
    final start = dayOf(from);
    final end = dayOf(to);
    return DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
  }

  /// The local calendar day [days] after [day].
  ///
  /// Built through the calendar constructor rather than [Duration] arithmetic
  /// so a daylight-saving transition still advances exactly one day.
  static DateTime addDays(DateTime day, int days) {
    final local = dayOf(day);
    return DateTime(local.year, local.month, local.day + days);
  }
}

/// One recorded stretch of writing activity in one project.
///
/// Immutable by construction and immutable by intent: a session says what
/// happened at the time it was recorded. Later manuscript edits, chapter
/// moves, or project-setting changes never rewrite it.
class WritingSession {
  /// Creates a session from its recorded endpoints.
  ///
  /// [wordsWritten] is derived, never supplied: it is the net word delta with
  /// deletions floored at zero, so a session can never report negative
  /// productivity and can never report words the author did not write.
  WritingSession({
    required this.id,
    required this.projectId,
    required this.startedAt,
    required this.endedAt,
    required this.startingWordCount,
    required this.endingWordCount,
    required this.wordsAdded,
    required this.wordsRemoved,
    this.chapterId,
    this.sceneId,
    Duration? duration,
  }) : duration = duration ?? endedAt.difference(startedAt);

  final String id;
  final String projectId;

  /// When meaningful writing activity began.
  final DateTime startedAt;

  /// When the session was finalized — the moment of its last writing
  /// activity, not the moment the author closed the editor. Idle time at the
  /// end of a session is not writing time.
  final DateTime endedAt;

  /// Active session length. Stored rather than always re-derived so a
  /// persisted session reports exactly the duration it was recorded with.
  final Duration duration;

  /// The manuscript's canonical word count when the session began.
  final int startingWordCount;

  /// The manuscript's canonical word count when the session was finalized.
  final int endingWordCount;

  /// Words observed appearing across the session, summed over every
  /// observation. Revision that replaces a paragraph shows up here even when
  /// the net delta is zero.
  final int wordsAdded;

  /// Words observed disappearing across the session, summed the same way.
  final int wordsRemoved;

  /// Where the author was writing when the session started, when known.
  final String? chapterId;
  final String? sceneId;

  /// The raw signed delta, deletions included. Kept because it is the honest
  /// arithmetic; [wordsWritten] is the number safe to show an author.
  int get netWordDelta => endingWordCount - startingWordCount;

  /// Words written, never negative.
  int get wordsWritten => netWordDelta < 0 ? 0 : netWordDelta;

  /// Whether the session ended with fewer words than it started with.
  bool get isNetDeletion => netWordDelta < 0;

  /// The author's local calendar day this session belongs to, taken from
  /// [startedAt]. A session that crosses midnight counts for the day it
  /// started on, so one continuous sitting is never split across two days.
  DateTime get localDay => WritingCalendar.dayOf(startedAt);

  /// Words per hour for this session, or `null` when the session recorded no
  /// measurable duration — a rate over zero time is not a rate.
  double? get wordsPerHour {
    final seconds = duration.inMilliseconds / 1000;
    if (seconds <= 0) return null;
    return wordsWritten / (seconds / 3600);
  }

  WritingSession copyWith({
    String? id,
    String? projectId,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    int? startingWordCount,
    int? endingWordCount,
    int? wordsAdded,
    int? wordsRemoved,
    String? chapterId,
    String? sceneId,
  }) =>
      WritingSession(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        duration: duration ?? this.duration,
        startingWordCount: startingWordCount ?? this.startingWordCount,
        endingWordCount: endingWordCount ?? this.endingWordCount,
        wordsAdded: wordsAdded ?? this.wordsAdded,
        wordsRemoved: wordsRemoved ?? this.wordsRemoved,
        chapterId: chapterId ?? this.chapterId,
        sceneId: sceneId ?? this.sceneId,
      );

  /// Timestamps serialize as UTC ISO-8601, matching every other AuthorOS
  /// record, and are converted back to local time only for calendar
  /// questions.
  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'startingWordCount': startingWordCount,
        'endingWordCount': endingWordCount,
        'wordsWritten': wordsWritten,
        'wordsAdded': wordsAdded,
        'wordsRemoved': wordsRemoved,
        'chapterId': chapterId,
        'sceneId': sceneId,
      };

  factory WritingSession.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['startedAt'] as String).toLocal();
    final endedAt = DateTime.parse(json['endedAt'] as String).toLocal();
    final seconds = json['durationSeconds'] as int?;
    return WritingSession(
      id: (json['id'] as String?) ?? '',
      projectId: (json['projectId'] as String?) ?? '',
      startedAt: startedAt,
      endedAt: endedAt,
      duration: seconds == null ? null : Duration(seconds: seconds),
      startingWordCount: (json['startingWordCount'] as int?) ?? 0,
      endingWordCount: (json['endingWordCount'] as int?) ?? 0,
      wordsAdded: (json['wordsAdded'] as int?) ?? 0,
      wordsRemoved: (json['wordsRemoved'] as int?) ?? 0,
      chapterId: json['chapterId'] as String?,
      sceneId: json['sceneId'] as String?,
    );
  }

  @override
  String toString() => 'WritingSession($id, $projectId, '
      '${startedAt.toIso8601String()}, ${wordsWritten}w, $duration)';
}
