/// Scene prose as a stored thing.
///
/// [ProseDocument] says what prose *is*. This library says how one scene's
/// current prose is held: one row per scene in the embedded database, rather
/// than inside the manuscript's `SharedPreferences` blob. That is what lets a
/// save touch only the scene the author actually typed in, instead of
/// re-serialising every chapter and every word of every other scene on each
/// 700ms autosave tick.
///
/// **This library holds current prose only.** It deliberately has no history
/// of its own. Scene revision history is `core/scene_revision.dart` and
/// `scene_revision_service.dart`, and there is exactly one of it: a second
/// history here would be a second answer to "what did this scene used to
/// say?", and the two would diverge the first time one of them was written
/// through a path the other did not know about.
///
/// The division is:
///
/// ```text
/// Scene
///   |
///   +-- scene_prose_rows        current canonical prose  (this library)
///   |
///   +-- scene_revision_rows     bounded history          (scene_revision.dart)
/// ```
///
/// Nothing here imports Flutter or drift. The repository in
/// `persistence/authoros_database.dart` maps these to rows; the manuscript
/// store maps them to and from scenes.
library;

import 'prose_document.dart';

/// The current prose of one scene.
class SceneProse {
  const SceneProse({
    required this.sceneId,
    required this.projectId,
    required this.chapterId,
    required this.document,
    required this.updatedAt,
    this.revision = 1,
  });

  final String sceneId;
  final String projectId;
  final String chapterId;
  final ProseDocument document;
  final DateTime updatedAt;

  /// Advances by one on every write whose text actually changed.
  ///
  /// Metadata-only saves leave it alone, so it counts edits to the prose and
  /// not passes of the autosave timer. It is local bookkeeping: sync has its
  /// own shadow, and history has its own captures.
  final int revision;

  String get plainText => document.plainText;

  int get wordCount => document.wordCount;

  SceneProse copyWith({
    String? chapterId,
    ProseDocument? document,
    DateTime? updatedAt,
    int? revision,
  }) =>
      SceneProse(
        sceneId: sceneId,
        projectId: projectId,
        chapterId: chapterId ?? this.chapterId,
        document: document ?? this.document,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
      );

  /// The portable shape, used by the project archive.
  Map<String, Object?> toJson() => {
        'sceneId': sceneId,
        'projectId': projectId,
        'chapterId': chapterId,
        'revision': revision,
        'document': document.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
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
    );
  }
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

  /// Whether [text] is certainly the same prose this digest describes.
  ///
  /// Answers `false` for a formatted document even when the text matches,
  /// because the marks it carries are invisible to this comparison.
  bool matchesPlainText(String text) => !isFormatted && plainText == text;
}
