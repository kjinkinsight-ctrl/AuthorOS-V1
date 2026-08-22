/// Writing session history — the recording layer.
///
/// The recorder sits between the Manuscript Studio and the canonical
/// repository. The Studio tells it two things and nothing else:
///
/// * `noteBaseline` — the manuscript's canonical word count, observed without
///   any writing having happened. Opening a manuscript, focusing the editor,
///   navigating to a scene, or rebuilding a widget are baselines, never
///   activity, and never start a session.
/// * `noteActivity` — the author changed scene text, with the manuscript's
///   canonical word count at that moment. This, and only this, starts and
///   extends a session.
///
/// The recorder owns no word-count algorithm. Every count it receives is the
/// Manuscript Studio's own `ManuscriptProjectSummary.wordCount`.
library;

import 'core/writing_session.dart';
import 'persistence/authoros_database.dart';

/// Drives one project's writing sessions from editor activity and persists
/// the ones that qualify.
///
/// One recorder belongs to one open Manuscript Studio for one project. It is
/// deliberately not a store: it holds only the session currently in progress,
/// and the durable history lives in the app's canonical repository.
class WritingSessionRecorder {
  WritingSessionRecorder({
    required this.projectId,
    DriftConnectedDomainRepository? repository,
    this.thresholds = const WritingSessionThresholds(),
    DateTime Function()? clock,
    String Function()? idFactory,
  })  : _repository = repository,
        _clock = clock ?? DateTime.now,
        _idFactory = idFactory;

  final String projectId;
  final DriftConnectedDomainRepository? _repository;

  /// The one place session qualification is decided.
  final WritingSessionThresholds thresholds;

  final DateTime Function() _clock;
  final String Function()? _idFactory;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The last canonical word count observed, from a baseline or an activity
  /// report. `null` until the manuscript has been read at least once — until
  /// then there is no honest starting point to measure a session against.
  int? _lastObservedWordCount;

  _OpenSession? _open;

  /// Whether a session is currently in progress.
  bool get hasOpenSession => _open != null;

  /// The last canonical word count the recorder was told about.
  int? get lastObservedWordCount => _lastObservedWordCount;

  /// Records the manuscript's word count without treating it as writing.
  ///
  /// Called when the manuscript loads and whenever the Studio observes a word
  /// count that did not come from the author typing. Never starts a session,
  /// and never disturbs one already in progress: re-baselining mid-session
  /// would silently rewrite what the session started from.
  void noteBaseline(int wordCount) {
    if (_open != null) return;
    _lastObservedWordCount = wordCount < 0 ? 0 : wordCount;
  }

  /// Records meaningful writing activity at the manuscript's current
  /// canonical word count.
  ///
  /// The first activity report after a baseline opens a session; later
  /// reports extend it. A report that leaves the word count unchanged is
  /// ignored, so autosave ticks, widget rebuilds, and repeated lifecycle
  /// events cannot manufacture or extend a session on their own.
  ///
  /// If more than [WritingSessionThresholds.idleTimeout] passed since the
  /// last activity, the open session is finalized first and this report
  /// begins a new one — an editor left open is not a writing session.
  Future<void> noteActivity({
    required int wordCount,
    String? chapterId,
    String? sceneId,
  }) async {
    final count = wordCount < 0 ? 0 : wordCount;
    final now = _clock();

    final previous = _lastObservedWordCount;
    if (previous == null) {
      // Nothing has been observed yet: this report is the starting point, not
      // words the author is credited with writing.
      _lastObservedWordCount = count;
      return;
    }

    if (count == previous) return;

    final open = _open;
    final idle = open != null &&
        now.difference(open.lastActivityAt) > thresholds.idleTimeout;
    if (idle) {
      await finalizeSession();
    }

    _startAndExtend(
      count: count,
      // finalizeSession leaves the ended session's word count as the
      // baseline the next session starts from.
      previous: idle ? (_lastObservedWordCount ?? count) : previous,
      now: now,
      chapterId: chapterId,
      sceneId: sceneId,
    );
  }

  void _startAndExtend({
    required int count,
    required int previous,
    required DateTime now,
    String? chapterId,
    String? sceneId,
  }) {
    final delta = count - previous;
    if (delta == 0) {
      _lastObservedWordCount = count;
      return;
    }

    final open = _open ??= _OpenSession(
      id: (_idFactory ?? () => WritingSessionId.create(now))(),
      startedAt: now,
      startingWordCount: previous,
      chapterId: chapterId,
      sceneId: sceneId,
    );

    if (delta > 0) {
      open.wordsAdded += delta;
    } else {
      open.wordsRemoved += -delta;
    }
    open.endingWordCount = count;
    open.lastActivityAt = now;
    open.chapterId ??= chapterId;
    open.sceneId ??= sceneId;
    _lastObservedWordCount = count;
  }

  /// Ends the session in progress and persists it if it qualifies.
  ///
  /// Idempotent in three independent ways, because finalization arrives from
  /// several directions at once — an explicit end, navigating away, widget
  /// disposal, app lifecycle:
  ///
  /// * the open session is detached before the first `await`, so a re-entrant
  ///   call finds nothing to finalize;
  /// * with no session open the call is a no-op returning `null`;
  /// * the repository appends by insert-or-ignore, so even a replayed id can
  ///   never write a second row or rewrite the first.
  ///
  /// Returns the persisted session, or `null` when nothing was open or the
  /// session did not meet [thresholds].
  Future<WritingSession?> finalizeSession() async {
    final open = _open;
    if (open == null) return null;
    // Detach first: everything below is async, and a second caller must not
    // find this session still open.
    _open = null;

    // A session ends at its last writing activity, not when the author
    // happened to close the editor — idle time is not writing time.
    final session = WritingSession(
      id: open.id,
      projectId: projectId,
      startedAt: open.startedAt,
      endedAt: open.lastActivityAt,
      startingWordCount: open.startingWordCount,
      endingWordCount: open.endingWordCount,
      wordsAdded: open.wordsAdded,
      wordsRemoved: open.wordsRemoved,
      chapterId: open.chapterId,
      sceneId: open.sceneId,
    );

    // The next session starts from where this one ended, whether or not this
    // one was worth keeping.
    _lastObservedWordCount = session.endingWordCount;

    if (!thresholds.qualifies(
      wordsWritten: session.wordsWritten,
      wordsAdded: session.wordsAdded,
      wordsRemoved: session.wordsRemoved,
      duration: session.duration,
    )) {
      return null;
    }

    await repository.putWritingSession(session);
    return session;
  }

  /// The manuscript changed underneath the author, and they did not do it.
  ///
  /// A sync applying prose from another device moves the canonical word count
  /// while the editor is open. Left alone, the next keystroke would credit the
  /// whole arriving jump to the author: 5,000 words locally, 12,000 after the
  /// pull, one character typed, and [noteActivity] opens a session reporting
  /// 7,001 words written. It would qualify on the word count alone — the
  /// duration is never consulted once the words clear the threshold — and land
  /// in the history as a several-thousand-word session lasting no time at all,
  /// poisoning every daily total, streak and velocity derived from it.
  ///
  /// [noteBaseline] cannot fix this on its own: it is deliberately a no-op
  /// while a session is open, so an author who typed in the last few minutes
  /// would keep the stale baseline and inflate anyway. [discardOpenSession]
  /// cannot either — it re-baselines to the pre-arrival count.
  ///
  /// So this ends the session in progress first, which records what the author
  /// genuinely did write up to this moment, and only then re-baselines to the
  /// count the manuscript now has. The arriving words belong to whoever wrote
  /// them on the other device.
  Future<WritingSession?> noteRemoteChange(int wordCount) async {
    final finalized = await finalizeSession();
    // Succeeds now: finalizeSession detached the open session above.
    noteBaseline(wordCount);
    return finalized;
  }

  /// Abandons the session in progress without persisting it.
  ///
  /// For teardown paths that must not record anything — never a substitute
  /// for [finalizeSession].
  void discardOpenSession() {
    final open = _open;
    if (open == null) return;
    _open = null;
    _lastObservedWordCount = open.endingWordCount;
  }
}

/// The mutable in-progress half of a session. Never leaves this file: what
/// escapes the recorder is the immutable [WritingSession].
class _OpenSession {
  _OpenSession({
    required this.id,
    required this.startedAt,
    required this.startingWordCount,
    this.chapterId,
    this.sceneId,
  })  : lastActivityAt = startedAt,
        endingWordCount = startingWordCount;

  final String id;
  final DateTime startedAt;
  final int startingWordCount;

  DateTime lastActivityAt;
  int endingWordCount;
  int wordsAdded = 0;
  int wordsRemoved = 0;
  String? chapterId;
  String? sceneId;
}
