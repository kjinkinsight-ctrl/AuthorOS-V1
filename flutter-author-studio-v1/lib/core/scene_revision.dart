/// Scene revision history — the domain layer.
///
/// A [SceneRevision] is an immutable snapshot of one scene's prose as it stood
/// at a moment in time. Until this existed, AuthorOS could not hand an author
/// back a single word it had overwritten: node history stores metadata and
/// `restoreVersion` says so in its own doc comment, and the manuscript's only
/// prose backup was written once, during the v1 migration. Every 700ms autosave
/// destroyed what was there before it.
///
/// Two rules govern this file, mirroring `writing_session.dart`:
///
/// * It is presentation-independent. Nothing here imports Flutter, and nothing
///   here formats a value for a screen.
/// * It owns no word-count algorithm. Counts arrive from the Manuscript
///   Studio's canonical `ManuscriptScene.wordCount`; this layer stores what it
///   is given.
///
/// Revisions are deliberately **device-local**. They are not a synced record
/// type and never travel: a synced history would multiply every prose upload by
/// the retention depth to protect against a loss the conflict-copy rule in
/// `sync/manuscript_appliers.dart` already handles. Local history answers the
/// other question — "I overwrote my own scene an hour ago" — which no amount of
/// syncing ever could.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Identity for scene revisions, mirroring `ManuscriptId` and
/// `WritingSessionId`.
class SceneRevisionId {
  SceneRevisionId._();

  static int _sequence = 0;

  static String create([DateTime? at]) =>
      'scene_revision_${(at ?? DateTime.now()).microsecondsSinceEpoch}'
      '_${_sequence++}';
}

/// Why a snapshot exists.
///
/// Recorded rather than inferred, because it is the difference between "you
/// left this scene" and "a sync was about to replace these words" — and the
/// second is the one an author scanning the list is looking for.
enum SceneRevisionTrigger {
  /// The author left the scene, closed the manuscript, or backgrounded the
  /// app: the ordinary rhythm of the history.
  boundary,

  /// Prose from another device was about to be written over this text.
  remoteApply,

  /// The author restored an older revision, and this is what they restored
  /// over — which is what makes a restore undoable.
  restore,

  /// The scene was deleted. The only snapshot for prose that no longer has a
  /// scene to live in.
  deletion,
}

extension SceneRevisionTriggerX on SceneRevisionTrigger {
  String get id => name;

  /// How the reason reads in the history list.
  String get label => switch (this) {
        SceneRevisionTrigger.boundary => 'Autosaved',
        SceneRevisionTrigger.remoteApply => 'Before sync applied other changes',
        SceneRevisionTrigger.restore => 'Replaced by a restore',
        SceneRevisionTrigger.deletion => 'Scene deleted',
      };

  static SceneRevisionTrigger fromId(String? value) {
    for (final trigger in SceneRevisionTrigger.values) {
      if (trigger.name == value) return trigger;
    }
    return SceneRevisionTrigger.boundary;
  }
}

/// A stable digest of a scene's prose.
///
/// Stored on every revision so the recorder can answer "has this scene changed
/// since its last snapshot?" without reading a single stored body back out of
/// the database. `String.hashCode` would not do: Dart makes no promise it is
/// stable across runs, and a history that silently stopped deduplicating after
/// a restart would grow without bound.
String sceneContentDigest(String content) =>
    sha1.convert(utf8.encode(content)).toString();

/// One scene's prose as it stood at [capturedAt].
class SceneRevision {
  SceneRevision({
    required this.id,
    required this.projectId,
    required this.sceneId,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.capturedAt,
    required this.trigger,
    String? contentDigest,
  }) : contentDigest = contentDigest ?? sceneContentDigest(content);

  final String id;
  final String projectId;
  final String sceneId;

  /// The chapter the scene sat in when the snapshot was taken. Kept for the
  /// history list, never for restoring: a scene that has since moved is
  /// restored where it lives now, not dragged back to where it was.
  final String chapterId;

  /// The scene's title at capture time, so a renamed scene's history still
  /// shows what it used to be called.
  final String title;

  final String content;
  final int wordCount;
  final DateTime capturedAt;
  final SceneRevisionTrigger trigger;
  final String contentDigest;

  /// This revision without its prose — what the history list needs.
  SceneRevisionSummary get summary => SceneRevisionSummary(
        id: id,
        projectId: projectId,
        sceneId: sceneId,
        chapterId: chapterId,
        title: title,
        wordCount: wordCount,
        capturedAt: capturedAt,
        trigger: trigger,
        contentDigest: contentDigest,
      );
}

/// A revision's metadata, without the words.
///
/// The history list shows time, size and reason for every snapshot of a scene.
/// Loading [SceneRevision]s to draw it would pull every stored copy of the
/// prose into memory to display none of it — on a heavily revised scene, a
/// megabyte to render twenty rows. So the list is built from these, and a body
/// is read only when the author opens one.
class SceneRevisionSummary {
  const SceneRevisionSummary({
    required this.id,
    required this.projectId,
    required this.sceneId,
    required this.chapterId,
    required this.title,
    required this.wordCount,
    required this.capturedAt,
    required this.trigger,
    required this.contentDigest,
  });

  final String id;
  final String projectId;
  final String sceneId;
  final String chapterId;
  final String title;
  final int wordCount;
  final DateTime capturedAt;
  final SceneRevisionTrigger trigger;
  final String contentDigest;
}

/// How much history a scene keeps.
///
/// Unbounded history is not an option: a 600-scene novel snapshotted at every
/// boundary would eventually hold more prose in its history than in its
/// manuscript. Every retention rule loses something, so this one is built to
/// lose the least useful thing first.
///
/// The shape is the one time-machine backups settled on, tightened at the
/// recent end because prose changes far faster than a filesystem does. Working
/// newest-first, a revision survives if it is one of the newest
/// [maximumRecent], or if it is the first one seen in its bucket — an hour
/// within [hourlyWindow], a day within [dailyWindow], a week beyond that.
/// Whatever survives is capped at [maximumPerScene].
///
/// Two failures this is shaped against, both of which a plain "keep the newest
/// N" cap walks straight into:
///
/// * **A long writing day erases its own morning.** Fifty snapshots between
///   nine and six is an ordinary day's work, and a flat cap would have spent
///   the whole budget on the afternoon before the author thought to look for
///   the 9am draft. Hourly bucketing keeps that morning at the cost of one row.
/// * **Long-term history evaporates.** Anything older than the cap's reach is
///   simply gone, so a scene rewritten hard for one afternoon loses every
///   trace of what it said last month. Daily and weekly buckets hold that
///   shape for a few dozen rows.
///
/// [maximumRecent] is what keeps the two ideas from fighting. Without it a
/// dense burst of editing fills the ceiling with the last twenty minutes and
/// prunes every older bucket underneath it — the tiers would exist and never
/// get used.
class SceneRevisionRetention {
  const SceneRevisionRetention({
    this.workingWindow = const Duration(hours: 6),
    this.hourlyWindow = const Duration(days: 1),
    this.dailyWindow = const Duration(days: 30),
    this.maximumRecent = 15,
    this.maximumPerScene = 50,
  });

  /// How recent a revision has to be to survive on age alone, as long as it is
  /// also within [maximumRecent]. This is undo territory — the snapshots an
  /// author reaches for minutes after realising they cut the wrong paragraph.
  final Duration workingWindow;

  /// How far back one revision per hour is kept.
  final Duration hourlyWindow;

  /// How far back one revision per calendar day is kept. Beyond it, one per
  /// week.
  final Duration dailyWindow;

  /// How many of the newest revisions survive unconditionally.
  final int maximumRecent;

  /// The hard ceiling on revisions kept for one scene, after bucketing.
  final int maximumPerScene;

  /// The ids of [revisions] to delete, given [now].
  ///
  /// [revisions] may arrive in any order. The newest revision is never
  /// returned, whatever the rules say: a scene always keeps at least the last
  /// thing that happened to it.
  List<String> idsToPrune(
    Iterable<SceneRevisionSummary> revisions,
    DateTime now,
  ) {
    final ordered = revisions.toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    if (ordered.length <= 1) return const [];

    final kept = <SceneRevisionSummary>[];
    final pruned = <String>[];
    final buckets = <String>{};

    for (var index = 0; index < ordered.length; index++) {
      final revision = ordered[index];
      final age = now.difference(revision.capturedAt);
      // The newest revision always survives, and so does anything inside the
      // working window that the recent allowance still covers.
      final unconditional = index == 0 ||
          (age <= workingWindow && index < maximumRecent);
      // Claimed even by unconditional keeps, so a revision just outside the
      // allowance cannot survive as a near-duplicate of one just inside it.
      final unclaimed = buckets.add(_bucketFor(revision.capturedAt, age));
      if (unconditional || unclaimed) {
        kept.add(revision);
        continue;
      }
      pruned.add(revision.id);
    }

    // The ceiling, applied to what survived bucketing. Newest first, so what
    // goes is the far end of the history rather than this afternoon's work.
    if (kept.length > maximumPerScene) {
      pruned.addAll(
        kept.sublist(maximumPerScene).map((revision) => revision.id),
      );
    }
    return pruned;
  }

  /// The bucket [at] competes in, given its [age].
  ///
  /// Newest-first iteration means the survivor of a bucket is the last
  /// revision taken in it — the state the scene reached by the end of that
  /// hour, day or week, which is what an author asking "what did this say
  /// yesterday?" means.
  String _bucketFor(DateTime at, Duration age) {
    final local = at.toLocal();
    final day = '${local.year}-${local.month}-${local.day}';
    if (age <= hourlyWindow) return 'hour:$day:${local.hour}';
    if (age <= dailyWindow) return 'day:$day';
    // Calendar weeks, counted from the Monday of the revision's own week so a
    // week's bucket does not shift as `now` moves.
    final monday = local.subtract(Duration(days: local.weekday - 1));
    return 'week:${monday.year}-${monday.month}-${monday.day}';
  }
}
