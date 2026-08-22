/// Manuscript sync — recording local prose, and applying everyone else's.
///
/// The conflict rule here is deliberately stricter than the one the rest of
/// the sync uses. For a writing goal, last-writer-wins costs three numbers.
/// For a scene it costs an author's afternoon. `restoreVersion` explicitly
/// does not roll back scene text, and the only prose backup in the product
/// before this was written once during the v1 migration.
///
/// `scene_revision.dart` now keeps a local copy of a scene before a pull
/// overwrites it, which is a second net under this one. It is not a
/// replacement: revision history is device-local and pruned, so a device that
/// has never opened a project has no history for it. Applying prose still has
/// to be non-destructive in its own right.
///
/// So nothing here ever destroys prose. When two devices have both changed a
/// scene, the arriving version is applied and the local one is kept beside it
/// as a conflict copy — in the manuscript, in the same chapter, where the
/// author will actually find it. That is what
/// `docs/authoros-2-master-plan.md` asks for: "manuscript text conflicts
/// preserve both versions and require user resolution."
library;

import 'package:flutter/foundation.dart';

import '../manuscript_store.dart';
import 'manuscript_sync.dart';
import 'project_sync.dart';
import 'sync_appliers.dart';
import 'sync_engine.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

/// Queues the scenes this device has changed.
///
/// Called from the Manuscript Studio at natural boundaries — leaving a scene,
/// closing the manuscript, the app going to the background — and never from
/// [ManuscriptStore.saveStudio].
///
/// That distinction is not fussiness. `loadStudio` calls `saveStudio` when it
/// seeds a manuscript that has never been opened, so a hook inside the save
/// would enqueue during a *read*, creating sync preference keys where a read
/// should create none. Four tests snapshot the preference keys across a read
/// specifically to catch that.
class ManuscriptSyncRecorder {
  const ManuscriptSyncRecorder({
    this.store = const ManuscriptStore(),
    this.recorder = const SyncRecorder(),
  });

  final ManuscriptStore store;
  final SyncRecorder recorder;

  /// Enqueues every scene that has changed since this device last synced, plus
  /// the outline when it has moved, and updates the shadow to match.
  ///
  /// Returns the number of operations queued, so a caller can tell whether
  /// anything is waiting.
  Future<int> recordChanges(ManuscriptProjectSummary manuscript) async {
    try {
      final shadow = await store.loadSyncShadow(manuscript.projectId);
      final dirty = shadow.dirtyScenes(manuscript);
      final deleted = shadow.deletedSceneIds(manuscript);

      for (final scene in dirty) {
        // A reference, not the prose. The text is read again at flush time —
        // see SyncPayloadResolver — so the queue never holds a second copy of
        // the manuscript, and what uploads is current rather than whatever was
        // true when the author last paused typing.
        await recorder.recordUpsert(
          recordType: ManuscriptRecordTypes.scene,
          recordId: scene.id,
          payload: {
            'projectId': manuscript.projectId,
            'sceneId': scene.id,
          },
        );
      }

      for (final sceneId in deleted) {
        await recorder.recordDelete(
          recordType: ManuscriptRecordTypes.scene,
          recordId: sceneId,
        );
      }

      // The outline travels separately, and only when it has actually moved:
      // typing must not re-upload the chapter list.
      final structure = ManuscriptStructurePayload.of(manuscript);
      final previous = await store.loadStructureFingerprint(
        manuscript.projectId,
      );
      final changed = previous != structure.fingerprint;
      if (changed) {
        await recorder.recordUpsert(
          recordType: ManuscriptRecordTypes.structure,
          recordId: manuscript.projectId,
          payload: structure.toJson(),
        );
        await store.saveStructureFingerprint(
          manuscript.projectId,
          structure.fingerprint,
        );
      }

      await store.saveSyncShadow(
        manuscript.projectId,
        ManuscriptSyncShadow.of(manuscript),
      );

      return dirty.length + deleted.length + (changed ? 1 : 0);
    } catch (error) {
      // The manuscript is already saved. A queueing failure costs a sync;
      // letting it propagate could cost the author their work.
      debugPrint('Could not queue manuscript changes for sync: $error');
      return 0;
    }
  }

  /// Uploads whatever is queued. Called at the same boundaries.
  Future<void> flush() => recorder.flush();
}

/// Reads a queued scene's current prose immediately before it uploads.
class SceneSyncPayloadResolver extends SyncPayloadResolver {
  const SceneSyncPayloadResolver({
    required this.projectId,
    this.store = const ManuscriptStore(),
  });

  /// Which project's manuscript to read the scene out of. A scene reference
  /// carries its own project id, but the resolver is built per open project.
  final String projectId;
  final ManuscriptStore store;

  @override
  String get recordType => ManuscriptRecordTypes.scene;

  @override
  Future<Map<String, dynamic>?> resolve(String recordId) async {
    // peekStudio, never loadStudio: resolving a payload must not seed a
    // manuscript for a project that has never been opened.
    final manuscript = await store.peekStudio(projectId);
    if (manuscript == null) return null;
    final scene = manuscript.sceneById(recordId);
    // Deleted between queueing and flushing. The operation is dropped; a
    // tombstone was queued separately when the scene actually went.
    if (scene == null) return null;
    return SceneSyncPayload.fromScene(projectId, scene).toJson();
  }
}

/// The outcome of applying one remote scene, so a caller can tell the author
/// something true about what just happened.
class SceneApplyOutcome {
  const SceneApplyOutcome({
    required this.manuscript,
    this.conflictCopyId,
  });

  final ManuscriptProjectSummary manuscript;

  /// The id of the scene holding this device's version, when the arriving one
  /// collided with unsynced local changes. Null when there was no conflict.
  final String? conflictCopyId;

  bool get hadConflict => conflictCopyId != null;
}

/// Applies scenes from other devices, without ever destroying prose.
class SceneApplier extends SyncApplier {
  const SceneApplier({
    required this.projectId,
    this.store = const ManuscriptStore(),
    this.onManuscriptChanged,
  });

  final String projectId;
  final ManuscriptStore store;

  /// Told after prose changed underneath the author, so the open Studio can
  /// adopt the new manuscript and re-baseline its writing session.
  ///
  /// Without this the Studio keeps a stale manuscript in memory and writes it
  /// straight back over the arriving prose on its next save — and its session
  /// recorder credits the arriving words to the author.
  final Future<void> Function(ManuscriptProjectSummary)? onManuscriptChanged;

  @override
  String get recordType => ManuscriptRecordTypes.scene;

  @override
  Future<void> applyUpsert(ProjectSyncEnvelope envelope) async {
    final payload = SceneSyncPayload.fromJson(
      Map<String, dynamic>.from(envelope.payload),
    );
    if (payload.projectId.isNotEmpty && payload.projectId != projectId) return;

    final manuscript = await store.peekStudio(projectId);
    if (manuscript == null) return;

    final outcome = applyScene(
      manuscript: manuscript,
      payload: payload,
      shadow: await store.loadSyncShadow(projectId),
    );
    if (identical(outcome.manuscript, manuscript)) return;

    await store.applyRemote(outcome.manuscript);
    await onManuscriptChanged?.call(outcome.manuscript);
  }

  @override
  Future<void> applyDelete(String recordId) async {
    final manuscript = await store.peekStudio(projectId);
    if (manuscript == null) return;

    final chapters = [
      for (final chapter in manuscript.chapters)
        chapter.copyWith(
          scenes:
              chapter.scenes.where((scene) => scene.id != recordId).toList(),
        ),
    ];
    final updated = manuscript.copyWith(chapters: chapters);
    await store.applyRemote(updated);
    await onManuscriptChanged?.call(updated);
  }

  /// The conflict rule, pure so it can be reasoned about and tested directly.
  ///
  /// * a scene this device does not have — insert it;
  /// * a scene this device has not touched since it last synced — replace it,
  ///   because there is nothing local to lose;
  /// * identical text — replace it, because there is no conflict to have;
  /// * otherwise — apply the arriving version **and** keep this device's
  ///   version beside it as a new scene, one below, titled
  ///   "<title> (conflict copy)".
  ///
  /// The copy goes in the manuscript rather than a hidden store because that
  /// is where the author will find it. It is an ordinary scene, so it syncs
  /// onward and both devices end up holding both versions.
  static SceneApplyOutcome applyScene({
    required ManuscriptProjectSummary manuscript,
    required SceneSyncPayload payload,
    required ManuscriptSyncShadow shadow,
    DateTime Function()? clock,
    String Function()? idFactory,
  }) {
    final now = (clock ?? DateTime.now)();
    final existing = manuscript.sceneById(payload.sceneId);

    // A scene this device has never seen: place it in the chapter it names.
    if (existing == null) {
      final chapters = [
        for (final chapter in manuscript.chapters)
          if (chapter.id == payload.chapterId)
            chapter.copyWith(
              scenes: [...chapter.scenes, payload.toScene()],
            )
          else
            chapter,
      ];
      return SceneApplyOutcome(manuscript: manuscript.copyWith(chapters: chapters));
    }

    final dirty = shadow.isDirty(existing);
    final sameText = existing.content == payload.content;

    // Nothing local at risk, or nothing to argue about.
    if (!dirty || sameText) {
      return SceneApplyOutcome(
        manuscript: _replaceScene(
          manuscript,
          payload.toScene(existing: existing),
        ),
      );
    }

    // Both changed. Neither version is expendable.
    final copyId = (idFactory ?? () => ManuscriptId.create('scene'))();
    final conflictCopy = existing.copyWith(
      id: copyId,
      title: '${existing.title} (conflict copy)',
      createdAt: now,
      updatedAt: now,
    );

    final chapters = <ManuscriptChapter>[];
    for (final chapter in manuscript.chapters) {
      final index =
          chapter.scenes.indexWhere((scene) => scene.id == payload.sceneId);
      if (index < 0) {
        chapters.add(chapter);
        continue;
      }
      final scenes = [...chapter.scenes];
      scenes[index] = payload.toScene(existing: existing);
      scenes.insert(index + 1, conflictCopy);
      chapters.add(chapter.copyWith(scenes: scenes));
    }

    return SceneApplyOutcome(
      manuscript: manuscript.copyWith(chapters: chapters),
      conflictCopyId: copyId,
    );
  }

  static ManuscriptProjectSummary _replaceScene(
    ManuscriptProjectSummary manuscript,
    ManuscriptScene scene,
  ) =>
      manuscript.copyWith(
        chapters: [
          for (final chapter in manuscript.chapters)
            chapter.copyWith(
              scenes: [
                for (final existing in chapter.scenes)
                  if (existing.id == scene.id) scene else existing,
              ],
            ),
        ],
      );
}

/// Applies a project's chapter list and scene ordering.
///
/// Structure is where order lives. Scenes deliberately do not carry it: a
/// scene's `order` is recomputed densely on every load, so it is derived
/// rather than authoritative and must never be what two devices disagree over.
class ManuscriptStructureApplier extends SyncApplier {
  const ManuscriptStructureApplier({
    required this.projectId,
    this.store = const ManuscriptStore(),
    this.onManuscriptChanged,
  });

  final String projectId;
  final ManuscriptStore store;
  final Future<void> Function(ManuscriptProjectSummary)? onManuscriptChanged;

  @override
  String get recordType => ManuscriptRecordTypes.structure;

  @override
  Future<void> applyUpsert(ProjectSyncEnvelope envelope) async {
    final payload = ManuscriptStructurePayload.fromJson(
      Map<String, dynamic>.from(envelope.payload),
    );
    if (payload.projectId.isNotEmpty && payload.projectId != projectId) return;

    final manuscript = await store.peekStudio(projectId);
    if (manuscript == null) return;

    // Every scene this device holds, so the outline can be rebuilt without
    // losing prose that the arriving structure happens not to mention.
    final scenesById = <String, ManuscriptScene>{
      for (final chapter in manuscript.chapters)
        for (final scene in chapter.scenes) scene.id: scene,
    };
    final placed = <String>{};

    final chapters = <ManuscriptChapter>[];
    for (final outline in payload.chapters) {
      final existing = manuscript.chapterById(outline.id);
      final scenes = <ManuscriptScene>[];
      for (final sceneId in outline.sceneIds) {
        final scene = scenesById[sceneId];
        // A scene named by the outline that has not arrived yet. Skipped
        // rather than invented; its own record will place it.
        if (scene == null) continue;
        scenes.add(scene.copyWith(chapterId: outline.id));
        placed.add(sceneId);
      }
      chapters.add(
        (existing ??
                ManuscriptChapter(
                  id: outline.id,
                  title: outline.title,
                  order: chapters.length + 1,
                  status: ManuscriptNodeStatusX.fromId(outline.status),
                  scenes: const [],
                  createdAt: envelope.updatedAt,
                  updatedAt: envelope.updatedAt,
                ))
            .copyWith(
          title: outline.title,
          status: ManuscriptNodeStatusX.fromId(outline.status),
          summary: outline.summary,
          prompt: outline.prompt,
          pov: outline.pov,
          scenes: scenes,
          updatedAt: envelope.updatedAt,
        ),
      );
    }

    // Anything the arriving outline did not account for stays, in the chapter
    // it was already in. An outline from a device that had not yet seen a new
    // scene must not delete it — only a tombstone deletes.
    final orphans =
        scenesById.keys.where((id) => !placed.contains(id)).toList();
    if (orphans.isNotEmpty) {
      for (final chapter in manuscript.chapters) {
        final keep = chapter.scenes
            .where((scene) => orphans.contains(scene.id))
            .toList();
        if (keep.isEmpty) continue;
        final index = chapters.indexWhere((built) => built.id == chapter.id);
        if (index >= 0) {
          chapters[index] = chapters[index].copyWith(
            scenes: [...chapters[index].scenes, ...keep],
          );
        } else {
          chapters.add(chapter.copyWith(scenes: keep));
        }
      }
    }

    final updated = manuscript.copyWith(
      manuscriptTitle: payload.manuscriptTitle,
      chapters: chapters,
    );
    await store.applyRemote(updated);
    await onManuscriptChanged?.call(updated);
  }

  @override
  Future<void> applyDelete(String recordId) async {
    // A structure record is never deleted on its own: a project going away is
    // a `project` tombstone, and that deliberately does not cascade to prose.
  }
}

/// The manuscript half of the engine, for one open project.
///
/// Built per project because prose is stored per project and both appliers and
/// the resolver need to know which one is open.
SyncEngine buildManuscriptSyncEngine({
  required String projectId,
  ManuscriptStore store = const ManuscriptStore(),
  SyncStore syncStore = const SyncStore(),
  SyncTransport transport = const SupabaseSyncTransport(),
  Future<void> Function(ManuscriptProjectSummary)? onManuscriptChanged,
}) =>
    SyncEngine(
      store: syncStore,
      transport: transport,
      appliers: [
        SceneApplier(
          projectId: projectId,
          store: store,
          onManuscriptChanged: onManuscriptChanged,
        ),
        ManuscriptStructureApplier(
          projectId: projectId,
          store: store,
          onManuscriptChanged: onManuscriptChanged,
        ),
      ],
      resolvers: [
        SceneSyncPayloadResolver(projectId: projectId, store: store),
      ],
    );
