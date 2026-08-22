import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/sync/manuscript_appliers.dart';
import 'package:author_studio_v1/sync/manuscript_sync.dart';
import 'package:flutter_test/flutter_test.dart';

final timestamp = DateTime.utc(2026, 8, 22, 9);

ManuscriptScene _scene(
  String id, {
  String chapterId = 'ch-1',
  String title = 'The Blood Price',
  required String content,
  DateTime? updatedAt,
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: 1,
      content: content,
      status: ManuscriptNodeStatus.draft,
      createdAt: timestamp,
      updatedAt: updatedAt ?? timestamp,
    );

ManuscriptProjectSummary _manuscript(List<ManuscriptScene> scenes) =>
    ManuscriptProjectSummary(
      projectId: 'book-1',
      manuscriptTitle: 'The Hollow Court',
      chapters: [
        ManuscriptChapter(
          id: 'ch-1',
          title: 'Chapter One',
          order: 1,
          status: ManuscriptNodeStatus.draft,
          scenes: scenes,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ],
      currentChapterId: 'ch-1',
      currentSceneId: scenes.isEmpty ? '' : scenes.first.id,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: 2,
    );

SceneSyncPayload _remote(
  String sceneId, {
  required String content,
  String title = 'The Blood Price',
  DateTime? updatedAt,
}) =>
    SceneSyncPayload(
      projectId: 'book-1',
      sceneId: sceneId,
      chapterId: 'ch-1',
      title: title,
      content: content,
      status: 'draft',
      updatedAt: updatedAt ?? timestamp.add(const Duration(hours: 1)),
    );

/// A shadow in which [syncedIds] are level with the server as of [at].
ManuscriptSyncShadow _shadow(
  Map<String, DateTime> synced,
) =>
    ManuscriptSyncShadow(synced);

void main() {
  group('nothing local at risk', () {
    test('a scene this device has never seen is inserted', () {
      final manuscript = _manuscript([]);

      final outcome = SceneApplier.applyScene(
        manuscript: manuscript,
        payload: _remote('sc-1', content: 'Words from elsewhere.'),
        shadow: const ManuscriptSyncShadow.empty(),
      );

      expect(outcome.hadConflict, isFalse);
      expect(outcome.manuscript.sceneById('sc-1')?.content,
          'Words from elsewhere.');
    });

    test('a clean scene is replaced outright', () {
      final local = _scene('sc-1', content: 'The original line.');
      final manuscript = _manuscript([local]);

      final outcome = SceneApplier.applyScene(
        manuscript: manuscript,
        payload: _remote('sc-1', content: 'The revised line.'),
        // Level with the server: nothing unsent here.
        shadow: _shadow({'sc-1': local.updatedAt}),
      );

      expect(outcome.hadConflict, isFalse);
      expect(outcome.manuscript.sceneById('sc-1')?.content,
          'The revised line.');
      expect(outcome.manuscript.sceneCount, 1);
    });

    test('identical text is not a conflict even when the scene is dirty', () {
      final local = _scene(
        'sc-1',
        content: 'The same words.',
        updatedAt: timestamp.add(const Duration(minutes: 5)),
      );
      final manuscript = _manuscript([local]);

      final outcome = SceneApplier.applyScene(
        manuscript: manuscript,
        payload: _remote('sc-1', content: 'The same words.'),
        shadow: _shadow({'sc-1': timestamp}),
      );

      expect(outcome.hadConflict, isFalse);
      expect(outcome.manuscript.sceneCount, 1);
    });
  });

  group('both devices changed the scene', () {
    test('the arriving version applies and the local one survives beside it',
        () {
      final local = _scene(
        'sc-1',
        content: 'What I wrote on the train.',
        updatedAt: timestamp.add(const Duration(minutes: 30)),
      );
      final manuscript = _manuscript([local]);

      final outcome = SceneApplier.applyScene(
        manuscript: manuscript,
        payload: _remote('sc-1', content: 'What I wrote at home.'),
        // Last synced before the train.
        shadow: _shadow({'sc-1': timestamp}),
        clock: () => timestamp.add(const Duration(hours: 2)),
        idFactory: () => 'sc-conflict',
      );

      expect(outcome.hadConflict, isTrue);
      expect(outcome.conflictCopyId, 'sc-conflict');

      // The arriving version is in place.
      expect(outcome.manuscript.sceneById('sc-1')?.content,
          'What I wrote at home.');

      // And not one word of the local version was destroyed.
      final copy = outcome.manuscript.sceneById('sc-conflict');
      expect(copy, isNotNull);
      expect(copy!.content, 'What I wrote on the train.');
      expect(copy.title, 'The Blood Price (conflict copy)');
    });

    test('the copy sits directly below the scene it came from', () {
      final manuscript = _manuscript([
        _scene('sc-1', content: 'One.'),
        _scene(
          'sc-2',
          content: 'Local two.',
          updatedAt: timestamp.add(const Duration(minutes: 30)),
        ),
        _scene('sc-3', content: 'Three.'),
      ]);

      final outcome = SceneApplier.applyScene(
        manuscript: manuscript,
        payload: _remote('sc-2', content: 'Remote two.'),
        shadow: _shadow({
          'sc-1': timestamp,
          'sc-2': timestamp,
          'sc-3': timestamp,
        }),
        idFactory: () => 'sc-conflict',
      );

      expect(
        outcome.manuscript.chapters.single.scenes.map((scene) => scene.id),
        ['sc-1', 'sc-2', 'sc-conflict', 'sc-3'],
        reason: 'The author should find their version next to the one that '
            'replaced it, not at the end of the book.',
      );
    });

    test('the copy keeps the local status and metadata', () {
      final local = ManuscriptScene(
        id: 'sc-1',
        chapterId: 'ch-1',
        title: 'The Blood Price',
        order: 1,
        content: 'Local words.',
        status: ManuscriptNodeStatus.revising,
        pov: 'Kali',
        location: 'Endovier',
        notes: 'Check the timeline.',
        createdAt: timestamp,
        updatedAt: timestamp.add(const Duration(minutes: 30)),
      );

      final outcome = SceneApplier.applyScene(
        manuscript: _manuscript([local]),
        payload: _remote('sc-1', content: 'Remote words.'),
        shadow: _shadow({'sc-1': timestamp}),
        idFactory: () => 'sc-conflict',
      );

      final copy = outcome.manuscript.sceneById('sc-conflict')!;
      expect(copy.status, ManuscriptNodeStatus.revising);
      expect(copy.pov, 'Kali');
      expect(copy.location, 'Endovier');
      expect(copy.notes, 'Check the timeline.');
    });

    test('an untouched scene never produces a copy on an ordinary pull', () {
      // The rule that stops a routine sync littering the manuscript.
      final manuscript = _manuscript([
        _scene('sc-1', content: 'Unchanged here.'),
      ]);

      for (var pull = 0; pull < 3; pull++) {
        final outcome = SceneApplier.applyScene(
          manuscript: manuscript,
          payload: _remote('sc-1', content: 'Changed elsewhere.'),
          shadow: _shadow({'sc-1': timestamp}),
        );
        expect(outcome.hadConflict, isFalse);
        expect(outcome.manuscript.sceneCount, 1);
      }
    });
  });

  group('two devices, both writing', () {
    test('neither device loses a word', () {
      // The whole point of the feature, end to end on the pure rule.
      //
      // Both start from the synced original. The laptop writes on the train,
      // the desktop writes at home, and the desktop's version reaches the
      // server first.
      const original = 'She opened the door.';
      const laptopText = 'She opened the door, and the cold came in.';
      const desktopText = 'She hesitated, then opened the door.';

      final laptop = _manuscript([
        _scene(
          'sc-1',
          content: laptopText,
          updatedAt: timestamp.add(const Duration(minutes: 30)),
        ),
      ]);

      // The laptop pulls the desktop's version.
      final outcome = SceneApplier.applyScene(
        manuscript: laptop,
        payload: _remote('sc-1', content: desktopText),
        shadow: _shadow({'sc-1': timestamp}),
        idFactory: () => 'sc-conflict',
      );

      final texts = outcome.manuscript.chapters.single.scenes
          .map((scene) => scene.content)
          .toList();

      expect(texts, contains(desktopText));
      expect(texts, contains(laptopText));
      expect(
        texts,
        isNot(contains(original)),
        reason: 'Both devices moved on from the original; only their two '
            'versions should remain.',
      );
    });

    test('the conflict copy is an ordinary scene, so it syncs onward', () {
      final outcome = SceneApplier.applyScene(
        manuscript: _manuscript([
          _scene(
            'sc-1',
            content: 'Local.',
            updatedAt: timestamp.add(const Duration(minutes: 30)),
          ),
        ]),
        payload: _remote('sc-1', content: 'Remote.'),
        shadow: _shadow({'sc-1': timestamp}),
        idFactory: () => 'sc-conflict',
      );

      // Nothing in the shadow, so the diff sees it as new and queues it — the
      // other device gets the copy too, and both end up whole.
      final shadow = _shadow({'sc-1': timestamp});
      final dirty = shadow.dirtyScenes(outcome.manuscript);

      expect(dirty.map((scene) => scene.id), contains('sc-conflict'));
    });
  });

  group('deletions', () {
    test('a scene the outline does not mention is kept, not deleted', () {
      // Only a tombstone deletes. An outline written by a device that had not
      // yet seen a new scene must not take it away.
      final shadow = _shadow({'sc-1': timestamp});
      final manuscript = _manuscript([
        _scene('sc-1', content: 'One.'),
        _scene('sc-2', content: 'Written here, not yet sent.'),
      ]);

      expect(shadow.deletedSceneIds(manuscript), isEmpty);
      expect(
        shadow.dirtyScenes(manuscript).map((scene) => scene.id),
        ['sc-2'],
      );
    });

    test('a scene removed locally is reported for a tombstone', () {
      final shadow = _shadow({'sc-1': timestamp, 'sc-2': timestamp});
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);

      expect(shadow.deletedSceneIds(manuscript), ['sc-2']);
    });
  });
}
