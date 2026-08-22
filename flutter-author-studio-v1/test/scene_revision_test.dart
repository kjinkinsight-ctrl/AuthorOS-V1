import 'dart:io';

import 'package:author_studio_v1/core/scene_revision.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/scene_revision_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 22, 9);

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
      createdAt: _timestamp,
      updatedAt: updatedAt ?? _timestamp,
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
          createdAt: _timestamp,
          updatedAt: _timestamp,
        ),
      ],
      currentChapterId: 'ch-1',
      currentSceneId: scenes.isEmpty ? '' : scenes.first.id,
      createdAt: _timestamp,
      updatedAt: _timestamp,
      version: 2,
    );

SceneRevisionSummary _summary(String id, DateTime capturedAt) =>
    SceneRevisionSummary(
      id: id,
      projectId: 'book-1',
      sceneId: 'sc-1',
      chapterId: 'ch-1',
      title: 'The Blood Price',
      wordCount: 100,
      capturedAt: capturedAt,
      trigger: SceneRevisionTrigger.boundary,
      contentDigest: 'digest-$id',
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  /// A service whose clock the test drives, so a month of history can be built
  /// without waiting a month for it.
  SceneRevisionService serviceAt(
    DateTime Function() clock, {
    SceneRevisionRetention retention = const SceneRevisionRetention(),
  }) =>
      SceneRevisionService(
        projectId: 'book-1',
        repository: repository,
        retention: retention,
        clock: clock,
      );

  group('capture', () {
    test('the first snapshot of a written scene is kept', () async {
      var now = _timestamp;
      final service = serviceAt(() => now);

      final written = await service.captureBoundary(
        _manuscript([_scene('sc-1', content: 'She opened the door.')]),
      );

      expect(written, hasLength(1));
      final history = await service.historyFor('sc-1');
      expect(history.single.wordCount, 4);
      expect(history.single.title, 'The Blood Price');
      expect(history.single.trigger, SceneRevisionTrigger.boundary);
    });

    test('an unchanged scene is never snapshotted twice', () async {
      var now = _timestamp;
      final service = serviceAt(() => now);
      final manuscript =
          _manuscript([_scene('sc-1', content: 'She opened the door.')]);

      for (var boundary = 0; boundary < 5; boundary++) {
        now = now.add(const Duration(minutes: 10));
        await service.captureBoundary(manuscript);
      }

      expect(
        await service.historyFor('sc-1'),
        hasLength(1),
        reason: 'Leaving and re-entering a scene without typing is not a '
            'revision, and a history full of identical entries would be '
            'unreadable.',
      );
    });

    test('an empty scene is not snapshotted', () async {
      // Otherwise opening a freshly seeded manuscript writes an empty
      // revision for every scene in it, on the very first boundary.
      final service = serviceAt(() => _timestamp);

      final written = await service.captureBoundary(
        _manuscript([
          _scene('sc-1', content: ''),
          _scene('sc-2', content: '   \n  '),
        ]),
      );

      expect(written, isEmpty);
      expect(await service.historyFor('sc-1'), isEmpty);
    });

    test('only the scene that changed is snapshotted', () async {
      var now = _timestamp;
      final service = serviceAt(() => now);
      await service.captureBoundary(_manuscript([
        _scene('sc-1', content: 'One.'),
        _scene('sc-2', chapterId: 'ch-1', content: 'Two.'),
      ]));

      now = now.add(const Duration(minutes: 20));
      final written = await service.captureBoundary(_manuscript([
        _scene('sc-1', content: 'One.'),
        _scene('sc-2', chapterId: 'ch-1', content: 'Two, rewritten.'),
      ]));

      expect(written.map((revision) => revision.sceneId), ['sc-2']);
      expect(await service.historyFor('sc-1'), hasLength(1));
      expect(await service.historyFor('sc-2'), hasLength(2));
    });

    test('the newest snapshot is first', () async {
      var now = _timestamp;
      final service = serviceAt(() => now);
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'First draft.')]));
      now = now.add(const Duration(hours: 1));
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'Second draft.')]));

      final history = await service.historyFor('sc-1');

      expect(history.first.capturedAt.isAfter(history.last.capturedAt), isTrue);
    });
  });

  group('before a sync overwrites prose', () {
    test('the local words are kept', () async {
      final service = serviceAt(() => _timestamp);
      final local =
          _manuscript([_scene('sc-1', content: 'What I wrote on the train.')]);
      final incoming =
          _manuscript([_scene('sc-1', content: 'What I wrote at home.')]);

      await service.captureBeforeRemote(local: local, incoming: incoming);

      final history = await service.historyFor('sc-1');
      expect(history.single.trigger, SceneRevisionTrigger.remoteApply);
      final stored = await service.revision(history.single.id);
      expect(stored!.content, 'What I wrote on the train.');
    });

    test('a scene the pull does not change is left alone', () async {
      final service = serviceAt(() => _timestamp);
      final scene = _scene('sc-1', content: 'Unchanged either side.');

      await service.captureBeforeRemote(
        local: _manuscript([scene]),
        incoming: _manuscript([scene]),
      );

      expect(await service.historyFor('sc-1'), isEmpty);
    });

    test('a first pull into an unwritten manuscript keeps nothing', () async {
      // There is no prose to preserve, and a revision per empty scene would
      // be the noisiest possible way to say so.
      final service = serviceAt(() => _timestamp);

      await service.captureBeforeRemote(
        local: _manuscript([_scene('sc-1', content: '')]),
        incoming: _manuscript([_scene('sc-1', content: 'Words from away.')]),
      );

      expect(await service.historyFor('sc-1'), isEmpty);
    });

    test('a scene absent from the arriving manuscript is not captured',
        () async {
      // Absent means untouched by this pull. Treating it as a loss would
      // snapshot the whole book every time one scene arrived.
      final service = serviceAt(() => _timestamp);

      await service.captureBeforeRemote(
        local: _manuscript([
          _scene('sc-1', content: 'Here.'),
          _scene('sc-2', content: 'Also here.'),
        ]),
        incoming: _manuscript([_scene('sc-1', content: 'Changed.')]),
      );

      expect(await service.historyFor('sc-2'), isEmpty);
    });
  });

  group('restore', () {
    test('the older words come back', () async {
      var now = _timestamp;
      final service = serviceAt(() => now);
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'The line I liked.')]));

      now = now.add(const Duration(hours: 1));
      final current =
          _manuscript([_scene('sc-1', content: 'The line I regret.')]);
      final history = await service.historyFor('sc-1');

      final restored = await service.restore(
        manuscript: current,
        revisionId: history.single.id,
      );

      expect(restored!.sceneById('sc-1')!.content, 'The line I liked.');
    });

    test('a restore is itself undoable', () async {
      // The whole reason restore captures before it replaces: an author who
      // restores the wrong version has not lost the one they were looking at.
      var now = _timestamp;
      final service = serviceAt(() => now);
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'The old line.')]));

      now = now.add(const Duration(hours: 1));
      final current = _manuscript([_scene('sc-1', content: 'The new line.')]);
      final old = (await service.historyFor('sc-1')).single;

      await service.restore(manuscript: current, revisionId: old.id);

      final history = await service.historyFor('sc-1');
      expect(history, hasLength(2));
      expect(history.first.trigger, SceneRevisionTrigger.restore);
      final kept = await service.revision(history.first.id);
      expect(kept!.content, 'The new line.');
    });

    test('a scene that has moved chapter is restored where it lives now',
        () async {
      var now = _timestamp;
      final service = serviceAt(() => now);
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'Original words.')]));

      now = now.add(const Duration(hours: 1));
      final moved = ManuscriptProjectSummary(
        projectId: 'book-1',
        manuscriptTitle: 'The Hollow Court',
        chapters: [
          ManuscriptChapter(
            id: 'ch-2',
            title: 'Chapter Two',
            order: 1,
            status: ManuscriptNodeStatus.draft,
            scenes: [
              _scene('sc-1', chapterId: 'ch-2', content: 'Rewritten words.'),
            ],
            createdAt: _timestamp,
            updatedAt: _timestamp,
          ),
        ],
        currentChapterId: 'ch-2',
        currentSceneId: 'sc-1',
        createdAt: _timestamp,
        updatedAt: _timestamp,
        version: 2,
      );
      final old = (await service.historyFor('sc-1')).last;

      final restored =
          await service.restore(manuscript: moved, revisionId: old.id);

      expect(restored!.chapters.single.id, 'ch-2');
      expect(restored.sceneById('sc-1')!.content, 'Original words.');
      expect(
        restored.sceneById('sc-1')!.chapterId,
        'ch-2',
        reason: 'The author moved the scene deliberately; recovering its prose '
            'has no business undoing that.',
      );
    });

    test('restoring a scene that no longer exists reports failure', () async {
      final service = serviceAt(() => _timestamp);
      await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'Words.')]));
      final old = (await service.historyFor('sc-1')).single;

      final restored = await service.restore(
        manuscript: _manuscript([_scene('sc-9', content: 'Elsewhere.')]),
        revisionId: old.id,
      );

      expect(restored, isNull);
    });

    test('restoring identical text writes no revision', () async {
      final service = serviceAt(() => _timestamp);
      final manuscript = _manuscript([_scene('sc-1', content: 'Same words.')]);
      await service.captureBoundary(manuscript);
      final only = (await service.historyFor('sc-1')).single;

      final restored =
          await service.restore(manuscript: manuscript, revisionId: only.id);

      expect(restored, same(manuscript));
      expect(await service.historyFor('sc-1'), hasLength(1));
    });
  });

  group('retention', () {
    const retention = SceneRevisionRetention();

    test('a scene always keeps its newest revision', () {
      final ancient =
          _summary('r-1', _timestamp.subtract(const Duration(days: 400)));

      expect(retention.idsToPrune([ancient], _timestamp), isEmpty);
    });

    test('the last few minutes of editing survive intact', () {
      // Undo territory: the snapshots an author reaches for minutes after
      // realising they cut the wrong paragraph.
      final recent = [
        for (var minutes = 0; minutes < 10; minutes++)
          _summary(
            'r-$minutes',
            _timestamp.subtract(Duration(minutes: minutes)),
          ),
      ];

      expect(retention.idsToPrune(recent, _timestamp), isEmpty);
    });

    test('a morning draft is still there at bedtime', () {
      // The case a plain "keep the newest N" cap fails: an author writing all
      // day pushes the morning out of history by lunchtime. One hourly bucket
      // holds it for the price of a single row.
      final morning = _timestamp.subtract(const Duration(hours: 12));
      final revisions = [
        for (var index = 0; index <= 80; index++)
          _summary('r-$index', morning.add(Duration(minutes: index * 8))),
      ];

      final pruned = retention.idsToPrune(revisions, _timestamp).toSet();
      final kept = revisions
          .where((revision) => !pruned.contains(revision.id))
          .toList()
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

      expect(
        kept.first.capturedAt.difference(morning),
        lessThan(const Duration(hours: 1)),
        reason: 'The oldest surviving snapshot should still be from the hour '
            'the author started, not from the afternoon.',
      );
      expect(kept.length, lessThan(revisions.length));
    });

    test('a day of dense editing thins to one revision an hour', () {
      final start = _timestamp.subtract(const Duration(hours: 20));
      final revisions = [
        for (var index = 0; index < 120; index++)
          _summary('r-$index', start.add(Duration(minutes: index * 5))),
      ];

      final pruned = retention.idsToPrune(revisions, _timestamp).toSet();
      final kept =
          revisions.where((revision) => !pruned.contains(revision.id)).toList();

      // Ten hours of writing, plus whatever the recent budget covers.
      expect(kept.length, lessThan(30));
      expect(
        kept.map((revision) => revision.capturedAt.hour).toSet().length,
        kept.length,
        reason: 'One survivor per hour, so scanning the list reads as a '
            'timeline rather than as a burst.',
      );
    });

    test('last month is still legible after a hard afternoon', () {
      // The second failure of a flat cap: a scene rewritten hard for one
      // afternoon loses every trace of what it said weeks ago.
      final revisions = [
        for (var day = 1; day <= 25; day++)
          _summary('day-$day', _timestamp.subtract(Duration(days: day))),
        for (var index = 0; index < 60; index++)
          _summary(
            'today-$index',
            _timestamp.subtract(Duration(minutes: index * 3)),
          ),
      ];

      final pruned = retention.idsToPrune(revisions, _timestamp).toSet();

      for (var day = 1; day <= 25; day++) {
        expect(pruned, isNot(contains('day-$day')), reason: 'day-$day');
      }
    });

    test('the recent budget never crowds out the older buckets', () {
      // Without a budget on the working window, a dense burst of editing
      // fills the ceiling with the last twenty minutes and the tiers below it
      // never get used.
      final revisions = [
        for (var index = 0; index < 200; index++)
          _summary(
            'burst-$index',
            _timestamp.subtract(Duration(seconds: index * 20)),
          ),
        for (var day = 1; day <= 10; day++)
          _summary('day-$day', _timestamp.subtract(Duration(days: day))),
      ];

      final pruned = retention.idsToPrune(revisions, _timestamp).toSet();

      for (var day = 1; day <= 10; day++) {
        expect(pruned, isNot(contains('day-$day')), reason: 'day-$day');
      }
    });

    test('the ceiling bounds what survives bucketing', () {
      const small = SceneRevisionRetention(
        maximumRecent: 2,
        maximumPerScene: 3,
      );
      final revisions = [
        for (var day = 0; day < 40; day++)
          _summary('r-$day', _timestamp.subtract(Duration(days: day))),
      ];

      final kept =
          revisions.length - small.idsToPrune(revisions, _timestamp).length;

      expect(kept, 3);
    });

    test('the database enforces the policy as it writes', () async {
      var now = _timestamp;
      final service = serviceAt(
        () => now,
        retention: const SceneRevisionRetention(
          workingWindow: Duration(minutes: 10),
          maximumRecent: 2,
          maximumPerScene: 3,
        ),
      );

      for (var index = 0; index < 10; index++) {
        now = now.add(const Duration(hours: 3));
        await service.captureBoundary(
          _manuscript([_scene('sc-1', content: 'Draft $index.')]),
        );
      }

      final history = await service.historyFor('sc-1');
      expect(history, hasLength(lessThanOrEqualTo(3)));
      final newest = await service.revision(history.first.id);
      expect(
        newest!.content,
        'Draft 9.',
        reason: 'Pruning must never take the latest thing that happened to a '
            'scene.',
      );
    });
  });

  group('architecture', () {
    test('history is device-local and never a synced record type', () {
      // Syncing revisions would multiply every prose upload by the retention
      // depth to guard against a loss the conflict-copy rule already handles.
      final service = File('lib/scene_revision_service.dart').readAsStringSync();
      final model = File('lib/core/scene_revision.dart').readAsStringSync();

      for (final source in [service, model]) {
        expect(source, isNot(contains('SyncRecordTypes')));
        expect(source, isNot(contains('enqueue')));
        expect(source, isNot(contains('SupabaseSyncTransport')));
      }
      for (final path in const [
        'lib/sync/manuscript_sync.dart',
        'lib/sync/manuscript_appliers.dart',
        'lib/sync/sync_appliers.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('SceneRevision')),
          reason: path,
        );
      }
    });

    test('capture is never wired into the manuscript store', () {
      // Same trap the sync recorder had to avoid: loadStudio saves when it
      // seeds a manuscript, so a hook in the store would write history during
      // a read.
      final source = File('lib/manuscript_store.dart').readAsStringSync();

      expect(source, isNot(contains('SceneRevision')));
    });

    test('prose history lives in drift, never in preferences', () {
      final source = File('lib/scene_revision_service.dart').readAsStringSync();

      expect(source, isNot(contains('SharedPreferences')));
      expect(
        File('lib/persistence/authoros_database.dart').readAsStringSync(),
        contains('class SceneRevisionRows extends Table'),
      );
    });

    test('the schema carries the revision table', () {
      expect(
        AuthorOsDatabase.currentSchemaVersion,
        greaterThanOrEqualTo(12),
      );
    });
  });
}
