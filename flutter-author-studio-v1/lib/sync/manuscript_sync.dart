/// Manuscript sync — what travels, and how a device knows what changed.
///
/// Prose is the one data set where the shared last-writer-wins rule would be
/// unacceptable. Losing a writing goal costs three numbers; losing a scene
/// costs an afternoon of an author's work, and the product has no prose
/// history to recover it from. `docs/authoros-2-master-plan.md` already says
/// so: "manuscript text conflicts preserve both versions and require user
/// resolution."
///
/// Two record types travel, because prose and structure change at different
/// rates and for different reasons. Typing churns scenes constantly; the
/// outline changes when the author adds, moves or renames something. Splitting
/// them means writing does not re-upload the outline, and reordering does not
/// re-upload the book.
library;

import '../manuscript_store.dart';

/// Record type ids for the manuscript, alongside `SyncRecordTypes`.
class ManuscriptRecordTypes {
  const ManuscriptRecordTypes._();

  /// One scene's prose and its own metadata. Keyed by scene id.
  static const scene = 'scene';

  /// A project's chapter list and the order of scenes within it. Keyed by
  /// project id.
  ///
  /// Order lives here and nowhere else: `ManuscriptProjectSummary.fromJson`
  /// recomputes every `order` field densely on load, so a scene's stored
  /// position is derived rather than authoritative and must never be the thing
  /// two devices argue over.
  static const structure = 'manuscript-structure';
}

/// One scene as it crosses the wire.
///
/// Deliberately not `ManuscriptScene.toJson()`: that carries `order`, which is
/// recomputed locally on every load, and `relationships`, which belong to the
/// graph rather than to the prose.
class SceneSyncPayload {
  const SceneSyncPayload({
    required this.projectId,
    required this.sceneId,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.status,
    required this.updatedAt,
    this.pov = '',
    this.location = '',
    this.timeLabel = '',
    this.notes = '',
  });

  final String projectId;
  final String sceneId;
  final String chapterId;
  final String title;
  final String content;
  final String status;
  final DateTime updatedAt;
  final String pov;
  final String location;
  final String timeLabel;
  final String notes;

  factory SceneSyncPayload.fromScene(String projectId, ManuscriptScene scene) =>
      SceneSyncPayload(
        projectId: projectId,
        sceneId: scene.id,
        chapterId: scene.chapterId,
        title: scene.title,
        content: scene.content,
        status: scene.status.id,
        updatedAt: scene.updatedAt,
        pov: scene.pov,
        location: scene.location,
        timeLabel: scene.timeLabel,
        notes: scene.notes,
      );

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'sceneId': sceneId,
        'chapterId': chapterId,
        'title': title,
        'content': content,
        'status': status,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'pov': pov,
        'location': location,
        'timeLabel': timeLabel,
        'notes': notes,
      };

  factory SceneSyncPayload.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    return SceneSyncPayload(
      projectId: (json['projectId'] as String?) ?? '',
      sceneId: (json['sceneId'] as String?) ?? '',
      chapterId: (json['chapterId'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled Scene',
      content: (json['content'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'draft',
      updatedAt: updatedAt is String
          ? DateTime.parse(updatedAt).toLocal()
          : DateTime.fromMillisecondsSinceEpoch(0),
      pov: (json['pov'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      timeLabel: (json['timeLabel'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  /// The scene this payload describes, applied over [existing] when the device
  /// already has it so nothing outside the synced fields is disturbed.
  ManuscriptScene toScene({ManuscriptScene? existing}) {
    final base = existing ??
        ManuscriptScene(
          id: sceneId,
          chapterId: chapterId,
          title: title,
          order: 0,
          content: content,
          status: ManuscriptNodeStatusX.fromId(status),
          createdAt: updatedAt,
          updatedAt: updatedAt,
        );
    return base.copyWith(
      chapterId: chapterId,
      title: title,
      content: content,
      status: ManuscriptNodeStatusX.fromId(status),
      pov: pov,
      location: location,
      timeLabel: timeLabel,
      notes: notes,
      updatedAt: updatedAt,
    );
  }
}

/// Which scenes on this device have changed since they last reached the server.
///
/// A save carries the whole manuscript — typing one character in one scene
/// rewrites all of them — so the sync layer has to work out the delta itself.
///
/// The signal is `ManuscriptScene.updatedAt`, which the editor stamps exactly
/// when a scene's content changes and the service mutators stamp on a
/// structural edit. Chapter timestamps are not usable for this: the editor
/// touches a scene's parent chapter on every keystroke.
///
/// Timestamps rather than content hashes because hashing roughly a megabyte on
/// a 700ms save cadence is real CPU for no extra fidelity.
class ManuscriptSyncShadow {
  const ManuscriptSyncShadow(this.entries);

  const ManuscriptSyncShadow.empty() : entries = const {};

  /// Scene id to the `updatedAt` that scene carried when it last synced.
  final Map<String, DateTime> entries;

  Map<String, dynamic> toJson() => {
        for (final entry in entries.entries)
          entry.key: entry.value.toUtc().toIso8601String(),
      };

  factory ManuscriptSyncShadow.fromJson(Map<String, dynamic> json) {
    final entries = <String, DateTime>{};
    for (final entry in json.entries) {
      final parsed = DateTime.tryParse('${entry.value}');
      if (parsed != null) entries[entry.key] = parsed.toLocal();
    }
    return ManuscriptSyncShadow(entries);
  }

  /// The shadow that describes [manuscript] exactly — every scene synced as it
  /// currently stands. Written after a successful enqueue.
  factory ManuscriptSyncShadow.of(ManuscriptProjectSummary manuscript) =>
      ManuscriptSyncShadow({
        for (final chapter in manuscript.chapters)
          for (final scene in chapter.scenes) scene.id: scene.updatedAt,
      });

  /// Whether [scene] carries changes this device has not sent.
  ///
  /// A scene the shadow has never seen is dirty: it is new. One whose
  /// `updatedAt` has moved on is dirty. Anything else is level with the server
  /// as far as this device knows.
  bool isDirty(ManuscriptScene scene) {
    final synced = entries[scene.id];
    if (synced == null) return true;
    return scene.updatedAt.isAfter(synced);
  }

  /// The scenes of [manuscript] that need sending.
  List<ManuscriptScene> dirtyScenes(ManuscriptProjectSummary manuscript) => [
        for (final chapter in manuscript.chapters)
          for (final scene in chapter.scenes)
            if (isDirty(scene)) scene,
      ];

  /// Scene ids the shadow knows about that [manuscript] no longer contains —
  /// scenes deleted on this device, which other devices must be told about.
  List<String> deletedSceneIds(ManuscriptProjectSummary manuscript) {
    final present = {
      for (final chapter in manuscript.chapters)
        for (final scene in chapter.scenes) scene.id,
    };
    return entries.keys.where((id) => !present.contains(id)).toList();
  }
}

/// A project's chapter list and scene ordering, as it crosses the wire.
class ManuscriptStructurePayload {
  const ManuscriptStructurePayload({
    required this.projectId,
    required this.manuscriptTitle,
    required this.chapters,
  });

  final String projectId;
  final String manuscriptTitle;
  final List<ManuscriptChapterOutline> chapters;

  factory ManuscriptStructurePayload.of(
    ManuscriptProjectSummary manuscript,
  ) =>
      ManuscriptStructurePayload(
        projectId: manuscript.projectId,
        manuscriptTitle: manuscript.manuscriptTitle,
        chapters: [
          for (final chapter in manuscript.chapters)
            ManuscriptChapterOutline(
              id: chapter.id,
              title: chapter.title,
              status: chapter.status.id,
              summary: chapter.summary,
              prompt: chapter.prompt,
              pov: chapter.pov,
              sceneIds: chapter.scenes.map((scene) => scene.id).toList(),
            ),
        ],
      );

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'manuscriptTitle': manuscriptTitle,
        'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      };

  factory ManuscriptStructurePayload.fromJson(Map<String, dynamic> json) =>
      ManuscriptStructurePayload(
        projectId: (json['projectId'] as String?) ?? '',
        manuscriptTitle:
            (json['manuscriptTitle'] as String?) ?? 'Untitled Manuscript',
        chapters: (json['chapters'] as List? ?? const [])
            .whereType<Map>()
            .map((chapter) => ManuscriptChapterOutline.fromJson(
                  Map<String, dynamic>.from(chapter),
                ))
            .toList(),
      );

  /// A stable fingerprint of the outline, so a save that changed only prose
  /// does not re-send the structure.
  String get fingerprint => chapters
      .map((chapter) => '${chapter.id}|${chapter.title}|${chapter.status}|'
          '${chapter.summary}|${chapter.prompt}|${chapter.pov}|'
          '${chapter.sceneIds.join(",")}')
      .join(';');
}

/// One chapter's identity, metadata and scene order.
class ManuscriptChapterOutline {
  const ManuscriptChapterOutline({
    required this.id,
    required this.title,
    required this.status,
    required this.summary,
    required this.prompt,
    required this.pov,
    required this.sceneIds,
  });

  final String id;
  final String title;
  final String status;
  final String summary;
  final String prompt;
  final String pov;

  /// The scenes of this chapter, in reading order. The order lives here rather
  /// than on the scenes themselves.
  final List<String> sceneIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'summary': summary,
        'prompt': prompt,
        'pov': pov,
        'sceneIds': sceneIds,
      };

  factory ManuscriptChapterOutline.fromJson(Map<String, dynamic> json) =>
      ManuscriptChapterOutline(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? 'Untitled Chapter',
        status: (json['status'] as String?) ?? 'draft',
        summary: (json['summary'] as String?) ?? '',
        prompt: (json['prompt'] as String?) ?? '',
        pov: (json['pov'] as String?) ?? '',
        sceneIds: (json['sceneIds'] as List? ?? const [])
            .map((id) => '$id')
            .toList(),
      );
}
