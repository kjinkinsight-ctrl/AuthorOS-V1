/// Scene prose as a stored thing — records, snapshots, and the policy that
/// decides when a snapshot is worth keeping.
///
/// [ProseDocument] says what prose *is*. This library says how one scene's
/// prose is held: a current row per scene, and a bounded history of what that
/// row used to say. Both live in the embedded database rather than in the
/// manuscript's `SharedPreferences` blob, which is what lets a save touch only
/// the scene the author actually typed in.
///
/// Nothing here imports Flutter or drift. The repository in
/// `persistence/authoros_database.dart` maps these to rows; the manuscript
/// store maps them to and from scenes.
library;

import 'prose_document.dart';

/// Identity for prose snapshots.
///
/// Mirrors `ManuscriptId` and the session-history ids — a prefix, the creation
/// instant in microseconds, and a monotonic counter so two snapshots taken
/// inside the same microsecond cannot collide.
class SceneProseId {
  SceneProseId._();

  static int _sequence = 0;

  static String create([DateTime? at]) =>
      'scene_prose_${(at ?? DateTime.now()).microsecondsSinceEpoch}'
      '_${_sequence++}';
}

/// The current prose of one scene.
class SceneProse {
  const SceneProse({
    required this.sceneId,
    required this.projectId,
    required this.chapterId,
    required this.document,
    required this.updatedAt,
    this.revision = 1,
    this.lastSnapshotAt,
  });

  final String sceneId;
  final String projectId;
  final String chapterId;
  final ProseDocument document;
  final DateTime updatedAt;

  /// Advances by one on every write whose text actually changed.
  ///
  /// Metadata-only saves leave it alone, so the revision counts edits to the
  /// prose and not passes of the autosave timer.
  final int revision;

  /// When this scene's prose was last copied into the snapshot history.
  ///
  /// Held on the current row rather than derived from the history table so a
  /// save needs one read, not one read per scene plus an aggregate.
  final DateTime? lastSnapshotAt;

  String get plainText => document.plainText;

  int get wordCount => document.wordCount;

  SceneProse copyWith({
    String? chapterId,
    ProseDocument? document,
    DateTime? updatedAt,
    int? revision,
    DateTime? lastSnapshotAt,
  }) =>
      SceneProse(
        sceneId: sceneId,
        projectId: projectId,
        chapterId: chapterId ?? this.chapterId,
        document: document ?? this.document,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
        lastSnapshotAt: lastSnapshotAt ?? this.lastSnapshotAt,
      );

  /// The portable shape, used by the project archive.
  ///
  /// The snapshot history is deliberately absent: it is local recovery
  /// scratch, not part of the work, and carrying twenty-five copies of every
  /// scene would multiply the size of an archive for no gain to the author who
  /// restores it.
  Map<String, Object?> toJson() => {
        'sceneId': sceneId,
        'projectId': projectId,
        'chapterId': chapterId,
        'revision': revision,
        'document': document.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (lastSnapshotAt != null)
          'lastSnapshotAt': lastSnapshotAt!.toUtc().toIso8601String(),
      };

  factory SceneProse.fromJson(Map<String, dynamic> json) {
    final rawDocument = json['document'];
    return SceneProse(
      sceneId: (json['sceneId'] as String?) ?? '',
      projectId: (json['projectId'] as String?) ?? '',
      chapterId: (json['chapterId'] as String?) ?? '',
      revision: (json['revision'] as int?) ?? 1,
      document: rawDocument is Map
          ? ProseDocument.fromJson(Map<String, dynamic>.from(rawDocument))
          : ProseDocument.empty,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSnapshotAt:
          DateTime.tryParse((json['lastSnapshotAt'] as String?) ?? '')?.toUtc(),
    );
  }

  /// A snapshot of this prose as it stands.
  SceneProseSnapshot snapshot({
    required DateTime capturedAt,
    SceneProseSnapshotReason reason = SceneProseSnapshotReason.autosave,
    String? id,
  }) =>
      SceneProseSnapshot(
        id: id ?? SceneProseId.create(capturedAt),
        sceneId: sceneId,
        projectId: projectId,
        document: document,
        revision: revision,
        capturedAt: capturedAt,
        reason: reason,
      );
}

/// A scene's prose without the prose.
///
/// What a save needs to answer "did this scene change?" -- and nothing more.
/// Reading the documents themselves would mean decoding every scene in the
/// project on every autosave tick, which is the whole-manuscript cost this
/// separation exists to remove; a digest read touches no JSON at all.
class SceneProseDigest {
  const SceneProseDigest({
    required this.sceneId,
    required this.chapterId,
    required this.plainText,
    required this.wordCount,
    required this.revision,
    required this.updatedAt,
    required this.isFormatted,
    this.lastSnapshotAt,
  });

  final String sceneId;
  final String chapterId;

  /// The stored document's plain-text projection.
  final String plainText;

  final int wordCount;
  final int revision;
  final DateTime updatedAt;

  /// Whether the stored document carries anything the plain text does not --
  /// a mark, a heading, a scene break.
  ///
  /// When it does, [plainText] is no longer enough to tell two documents
  /// apart, and the caller has to read the document itself. Keeping this on
  /// the digest is what lets the cheap comparison stay exact rather than
  /// merely usually right.
  final bool isFormatted;

  final DateTime? lastSnapshotAt;

  /// Whether [text] is certainly the same prose this digest describes.
  ///
  /// Answers `false` for a formatted document even when the text matches,
  /// because the marks it carries are invisible to this comparison.
  bool matchesPlainText(String text) => !isFormatted && plainText == text;
}

/// Why a snapshot was taken.
///
/// Recorded so the recovery UI can tell an automatic checkpoint from a
/// deliberate one, and so the copy taken immediately before a restore — the
/// undo for the restore itself — is never mistaken for routine autosave noise.
enum SceneProseSnapshotReason { autosave, manual, beforeRestore, imported }

/// Resolves persisted reasons without throwing on an unknown value.
extension SceneProseSnapshotReasonX on SceneProseSnapshotReason {
  String get id => name;

  static SceneProseSnapshotReason fromId(String? id) {
    for (final reason in SceneProseSnapshotReason.values) {
      if (reason.name == id) return reason;
    }
    return SceneProseSnapshotReason.autosave;
  }
}

/// One historical state of one scene's prose.
///
/// Immutable by construction and by intent: a snapshot says what the scene
/// said at the moment it was taken. Later edits, chapter moves, or renames
/// never rewrite it.
class SceneProseSnapshot {
  const SceneProseSnapshot({
    required this.id,
    required this.sceneId,
    required this.projectId,
    required this.document,
    required this.revision,
    required this.capturedAt,
    this.reason = SceneProseSnapshotReason.autosave,
  });

  final String id;
  final String sceneId;
  final String projectId;
  final ProseDocument document;
  final int revision;
  final DateTime capturedAt;
  final SceneProseSnapshotReason reason;

  int get wordCount => document.wordCount;

  String get plainText => document.plainText;
}

/// The single place the "is this worth keeping?" question is answered for
/// prose history.
///
/// Snapshotting every autosave would store a copy of the scene roughly twice a
/// second while the author types, which is neither useful history nor a
/// database anyone wants to open. Snapshotting too rarely loses the accidental
/// select-all-and-type that history exists to undo. These three values are the
/// only thresholds in the feature; nothing else may hard-code one.
class SceneProseSnapshotPolicy {
  const SceneProseSnapshotPolicy({
    this.minimumInterval = const Duration(minutes: 5),
    this.significantWordDelta = 25,
    this.retainedPerScene = 25,
  });

  /// How long a scene's prose must have gone unsnapshotted before a routine
  /// save takes another copy.
  final Duration minimumInterval;

  /// A change in word count large enough to snapshot immediately, whatever
  /// the interval says.
  ///
  /// This is the safety net: it is what preserves the scene when the author
  /// selects the chapter and types over it, an event the interval alone would
  /// happily miss.
  final int significantWordDelta;

  /// How many snapshots one scene keeps before the oldest are dropped.
  final int retainedPerScene;

  /// Whether [outgoing] — the prose about to be replaced by [incoming] —
  /// should be copied into history first.
  ///
  /// Empty outgoing prose is never snapshotted: there is nothing to recover,
  /// and a new scene would otherwise open its history with a blank entry.
  bool shouldCapture({
    required SceneProse outgoing,
    required ProseDocument incoming,
    required DateTime now,
  }) {
    if (outgoing.document.isEmpty) return false;
    if (outgoing.document == incoming) return false;
    final last = outgoing.lastSnapshotAt;
    if (last == null) return true;
    if (!now.isBefore(last.add(minimumInterval))) return true;
    final delta = (outgoing.wordCount - incoming.wordCount).abs();
    return delta >= significantWordDelta;
  }
}
