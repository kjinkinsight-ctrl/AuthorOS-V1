/// Scene revision history — capture, read and restore.
///
/// This is the seam between the Manuscript Studio, which knows *when* prose is
/// about to be lost, and the database, which keeps what was there. Everything
/// it does is driven by an explicit call from the Studio at a moment the
/// author would recognise: they left the scene, a sync was about to replace
/// it, they asked for an older version back.
///
/// It is deliberately **not** wired into `ManuscriptStore.saveStudio`, for the
/// reason recorded there and in `sync/manuscript_appliers.dart`: `loadStudio`
/// saves when it seeds a manuscript that has never been opened, so a hook
/// inside the save would write history during a read. That path is risk R-21
/// in the Story Graph audit, and four preference-key snapshot tests exist to
/// catch anything that trips it.
library;

import 'core/scene_revision.dart';
import 'manuscript_store.dart';
import 'persistence/authoros_database.dart';

/// Captures, lists and restores scene prose history for one project.
class SceneRevisionService {
  const SceneRevisionService({
    required this.projectId,
    this.repository,
    this.retention = const SceneRevisionRetention(),
    this.clock,
    this.idFactory,
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;
  final SceneRevisionRetention retention;

  /// Injected in tests so a history can be built across days without waiting
  /// for them.
  final DateTime Function()? clock;
  final String Function()? idFactory;

  DriftConnectedDomainRepository get _repository =>
      repository ?? authorOsRepository;

  DateTime get _now => (clock ?? DateTime.now)();

  String _newId(DateTime at) => (idFactory ?? () => SceneRevisionId.create(at))();

  /// Snapshots every scene of [manuscript] whose prose has changed since it
  /// was last captured.
  ///
  /// Called at the boundaries an author actually pauses at, never on the
  /// 700ms autosave — a snapshot per keystroke burst would be a second copy of
  /// the novel every few seconds, and a history so fine-grained that finding
  /// this morning's draft in it would be impossible.
  ///
  /// Two filters decide what is written, and both matter:
  ///
  /// * **Empty prose is never captured.** There is nothing to preserve, and
  ///   without this rule opening a freshly seeded manuscript would write an
  ///   empty revision for every scene in it.
  /// * **Unchanged prose is never captured**, compared by digest against the
  ///   newest revision of that scene. Leaving and re-entering a scene without
  ///   typing writes nothing at all, which is what keeps the history readable.
  ///
  /// Returns the revisions actually written.
  Future<List<SceneRevision>> captureBoundary(
    ManuscriptProjectSummary manuscript, {
    SceneRevisionTrigger trigger = SceneRevisionTrigger.boundary,
  }) async {
    final scenes = [
      for (final chapter in manuscript.chapters)
        for (final scene in chapter.scenes)
          if (scene.content.trim().isNotEmpty) scene,
    ];
    if (scenes.isEmpty) return const [];

    final digests = await _repository.newestSceneRevisionDigests(projectId);
    final written = <SceneRevision>[];
    for (final scene in scenes) {
      final digest = sceneContentDigest(scene.content);
      if (digests[scene.id] == digest) continue;
      written.add(await _capture(scene, trigger: trigger, digest: digest));
    }
    return written;
  }

  /// Snapshots the local text of every scene [incoming] is about to change.
  ///
  /// The gap this closes is the one the conflict-copy rule leaves open. That
  /// rule protects a scene the author edited since its last sync; this
  /// protects every scene an arriving manuscript overwrites, including the
  /// ones the shadow believes are clean — because "clean" only ever meant
  /// "this device thinks the server has it", and a shadow that drifted would
  /// otherwise take the words with it.
  ///
  /// Scenes with no local prose are skipped: a first pull into a manuscript
  /// that has never been written in has nothing to preserve.
  Future<List<SceneRevision>> captureBeforeRemote({
    required ManuscriptProjectSummary local,
    required ManuscriptProjectSummary incoming,
  }) async {
    final arriving = {
      for (final chapter in incoming.chapters)
        for (final scene in chapter.scenes) scene.id: scene.content,
    };
    final threatened = [
      for (final chapter in local.chapters)
        for (final scene in chapter.scenes)
          // Absent from the arriving manuscript means the scene is untouched
          // by this pull, not that it is being deleted: structure decides
          // deletions, and a tombstone captures those separately.
          if (scene.content.trim().isNotEmpty &&
              arriving.containsKey(scene.id) &&
              arriving[scene.id] != scene.content)
            scene,
    ];
    final written = <SceneRevision>[];
    for (final scene in threatened) {
      written.add(
        await _capture(scene, trigger: SceneRevisionTrigger.remoteApply),
      );
    }
    return written;
  }

  /// Snapshots one scene for a reason the caller names.
  ///
  /// Used where a single scene is about to lose its words — a restore
  /// replacing them, a deletion taking the scene away entirely — and the
  /// manuscript-wide sweep would be the wrong shape.
  Future<SceneRevision?> captureScene(
    ManuscriptScene scene, {
    required SceneRevisionTrigger trigger,
  }) async {
    if (scene.content.trim().isEmpty) return null;
    return _capture(scene, trigger: trigger);
  }

  /// One scene's history, newest first, without the prose.
  Future<List<SceneRevisionSummary>> historyFor(String sceneId) =>
      _repository.sceneRevisionSummaries(projectId, sceneId);

  /// One stored revision, prose included. `null` when it has been pruned since
  /// the list the author is looking at was drawn.
  Future<SceneRevision?> revision(String revisionId) =>
      _repository.sceneRevision(revisionId);

  /// [manuscript] with [revision]'s prose back in its scene, having first kept
  /// what that scene says now.
  ///
  /// Restoring is itself a destructive edit, so it snapshots before it
  /// replaces: the version the author restores over is always recoverable, and
  /// a restore they immediately regret costs them nothing. That capture is
  /// what makes the history a two-way door rather than a trapdoor.
  ///
  /// The scene is restored where it lives *now*. A scene that has since moved
  /// to another chapter is not dragged back to the one it was captured in —
  /// the author moved it deliberately, and prose recovery has no business
  /// undoing structure.
  ///
  /// Returns `null` when the revision or its scene has since gone, which the
  /// caller must render as "no longer available" rather than as a silent
  /// no-op.
  Future<ManuscriptProjectSummary?> restore({
    required ManuscriptProjectSummary manuscript,
    required String revisionId,
  }) async {
    final stored = await revision(revisionId);
    if (stored == null || stored.projectId != projectId) return null;
    final scene = manuscript.sceneById(stored.sceneId);
    if (scene == null) return null;
    if (scene.content == stored.content) return manuscript;

    await captureScene(scene, trigger: SceneRevisionTrigger.restore);

    final now = _now;
    return manuscript.copyWith(
      chapters: [
        for (final chapter in manuscript.chapters)
          if (chapter.scenes.every((candidate) => candidate.id != scene.id))
            chapter
          else
            chapter.copyWith(
              scenes: [
                for (final candidate in chapter.scenes)
                  if (candidate.id == scene.id)
                    candidate.copyWith(content: stored.content, updatedAt: now)
                  else
                    candidate,
              ],
              updatedAt: now,
            ),
      ],
      updatedAt: now,
    );
  }

  Future<SceneRevision> _capture(
    ManuscriptScene scene, {
    required SceneRevisionTrigger trigger,
    String? digest,
  }) async {
    final at = _now;
    final revision = SceneRevision(
      id: _newId(at),
      projectId: projectId,
      sceneId: scene.id,
      chapterId: scene.chapterId,
      title: scene.title,
      content: scene.content,
      contentDigest: digest,
      wordCount: scene.wordCount,
      capturedAt: at,
      trigger: trigger,
    );
    await _repository.putSceneRevision(
      revision,
      retention: retention,
      now: at,
    );
    return revision;
  }
}
