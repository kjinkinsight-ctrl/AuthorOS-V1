import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/scene_prose.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _projectId = 'project-a';
final _timestamp = DateTime.utc(2026, 8, 21, 9);

String _studioKey(String projectId) =>
    'author_studio.manuscript_studio.$projectId';

String _proseBackupKey(String projectId) =>
    'author_studio.manuscript_prose_backup.$projectId';

ManuscriptProjectSummary _manuscript({
  String sceneOneContent = 'Kali crosses the causeway.',
  String sceneTwoContent = 'Cassian waits at the gate.',
  List<String> sceneIds = const ['scene-1', 'scene-2'],
}) =>
    ManuscriptProjectSummary(
      projectId: _projectId,
      manuscriptTitle: 'Book One',
      chapters: [
        ManuscriptChapter(
          id: 'chapter-1',
          title: 'Chapter 01',
          order: 1,
          status: ManuscriptNodeStatus.draft,
          createdAt: _timestamp,
          updatedAt: _timestamp,
          scenes: [
            for (var index = 0; index < sceneIds.length; index++)
              ManuscriptScene(
                id: sceneIds[index],
                chapterId: 'chapter-1',
                title: 'Scene 0${index + 1}',
                order: index + 1,
                content: index == 0 ? sceneOneContent : sceneTwoContent,
                status: ManuscriptNodeStatus.draft,
                createdAt: _timestamp,
                updatedAt: _timestamp,
              ),
          ],
        ),
      ],
      currentChapterId: 'chapter-1',
      currentSceneId: sceneIds.first,
      createdAt: _timestamp,
      updatedAt: _timestamp,
      version: 2,
    );

ManuscriptProjectSummary _withSceneContent(
  ManuscriptProjectSummary manuscript,
  String sceneId,
  String content,
) =>
    manuscript.copyWith(chapters: [
      for (final chapter in manuscript.chapters)
        chapter.copyWith(scenes: [
          for (final scene in chapter.scenes)
            scene.id == sceneId ? scene.copyWith(content: content) : scene,
        ]),
    ]);

Future<ManuscriptProjectSummary> _reload(ManuscriptStore store) => store.loadStudio(
      _projectId,
      manuscriptTitle: 'Book One',
      defaultChapters: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
  });

  tearDown(() => database.close());

  group('where prose lives', () {
    test('the structure blob no longer carries a single word of prose',
        () async {
      await store.saveStudio(_manuscript());

      final preferences = await SharedPreferences.getInstance();
      final blob = preferences.getString(_studioKey(_projectId))!;
      expect(blob, isNot(contains('Kali crosses the causeway')));
      expect(blob, isNot(contains('Cassian waits at the gate')));
      // The structure is still all there.
      expect(blob, contains('chapter-1'));
      expect(blob, contains('Scene 01'));
    });

    test('prose comes back with the manuscript that was saved', () async {
      await store.saveStudio(_manuscript());

      final loaded = await _reload(store);
      final scenes = loaded.chapters.single.scenes;
      expect(scenes.first.content, 'Kali crosses the causeway.');
      expect(scenes.last.content, 'Cassian waits at the gate.');
      expect(loaded.wordCount, 9);
    });

    test('prose survives closing and reopening the database', () async {
      await database.close();
      final directory =
          await Directory.systemTemp.createTemp('manuscript-prose-');
      final file =
          File('${directory.path}${Platform.pathSeparator}prose.sqlite');

      final first = AuthorOsDatabase(NativeDatabase(file));
      await ManuscriptStore(repository: DriftConnectedDomainRepository(first))
          .saveStudio(_manuscript());
      await first.close();

      final reopened = AuthorOsDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final loaded = await _reload(
        ManuscriptStore(repository: DriftConnectedDomainRepository(reopened)),
      );
      expect(
        loaded.chapters.single.scenes.first.content,
        'Kali crosses the causeway.',
      );

      // Keep the shared teardown happy: it closes `database`.
      database = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(() => directory.delete(recursive: true));
    });

    test('one row per scene, holding the document and its plain projection',
        () async {
      await store.saveStudio(_manuscript());

      final prose = await repository.sceneProseForProject(_projectId);
      expect(prose.keys, containsAll(<String>['scene-1', 'scene-2']));
      expect(prose['scene-1']!.plainText, 'Kali crosses the causeway.');
      expect(prose['scene-1']!.chapterId, 'chapter-1');
      expect(prose['scene-1']!.wordCount, 4);
      expect(prose['scene-1']!.revision, 1);
    });

    test('an empty scene is not given a row', () async {
      await store.saveStudio(
        _manuscript(sceneOneContent: '', sceneTwoContent: ''),
      );
      expect(await repository.sceneProseForProject(_projectId), isEmpty);
    });
  });

  group('saving only what changed', () {
    test('a save that changed no prose advances no revision', () async {
      final manuscript = _manuscript();
      await store.saveStudio(manuscript);
      await store.saveStudio(manuscript);
      await store.saveStudio(manuscript);

      final prose = await repository.sceneProseForProject(_projectId);
      expect(prose['scene-1']!.revision, 1);
      expect(prose['scene-2']!.revision, 1);
    });

    test('editing one scene leaves every other scene untouched', () async {
      final manuscript = _manuscript();
      await store.saveStudio(manuscript);
      final before = await repository.sceneProseForProject(_projectId);

      await store.saveStudio(
        _withSceneContent(manuscript, 'scene-1', 'Kali turns back.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final after = await repository.sceneProseForProject(_projectId);
      expect(after['scene-1']!.revision, 2);
      expect(after['scene-1']!.plainText, 'Kali turns back.');
      // Same revision and same instant: the row was never written.
      expect(after['scene-2']!.revision, before['scene-2']!.revision);
      expect(after['scene-2']!.updatedAt, before['scene-2']!.updatedAt);
    });

    test('a scene removed from the manuscript takes its prose with it',
        () async {
      await store.saveStudio(_manuscript());
      await store.saveStudio(_manuscript(sceneIds: const ['scene-1']));

      final prose = await repository.sceneProseForProject(_projectId);
      expect(prose.keys, ['scene-1']);
      expect(await repository.sceneProseSnapshots('scene-2'), isEmpty);
    });
  });

  group('migrating a manuscript written before the split', () {
    Map<String, Object> legacyBlob() => {
          'projectId': _projectId,
          'manuscriptTitle': 'Book One',
          'currentChapterId': 'chapter-1',
          'currentSceneId': 'scene-1',
          'createdAt': _timestamp.toIso8601String(),
          'updatedAt': _timestamp.toIso8601String(),
          'version': 2,
          'chapters': [
            {
              'id': 'chapter-1',
              'title': 'Chapter 01',
              'order': 1,
              'status': 'draft',
              'scenes': [
                {
                  'id': 'scene-1',
                  'chapterId': 'chapter-1',
                  'title': 'Scene 01',
                  'order': 1,
                  'content': 'Prose written before the split.',
                  'status': 'draft',
                  'createdAt': _timestamp.toIso8601String(),
                  'updatedAt': _timestamp.toIso8601String(),
                },
              ],
            },
          ],
        };

    test('opening it moves the prose into the database, losing nothing',
        () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(legacyBlob()),
      });

      final loaded = await _reload(store);
      expect(
        loaded.chapters.single.scenes.single.content,
        'Prose written before the split.',
      );

      final prose = await repository.sceneProseForProject(_projectId);
      expect(prose['scene-1']!.plainText, 'Prose written before the split.');
    });

    test('the pre-migration blob is kept verbatim', () async {
      final encoded = jsonEncode(legacyBlob());
      SharedPreferences.setMockInitialValues({_studioKey(_projectId): encoded});

      await _reload(store);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_proseBackupKey(_projectId)), encoded);
    });

    test('the state it arrived in is the first entry in its history',
        () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(legacyBlob()),
      });

      await _reload(store);

      final history = await repository.sceneProseSnapshots('scene-1');
      expect(history, hasLength(1));
      expect(history.single.reason, SceneProseSnapshotReason.imported);
      expect(history.single.plainText, 'Prose written before the split.');
    });

    test('a save that lands before any load cannot lose the prose', () async {
      // The dangerous ordering: something writes the manuscript -- and its
      // prose-free blob -- before anything has read the prose out of the old
      // one. The migration therefore runs on the way in as well as on the way
      // out, and what it moved stays recoverable even when the very next save
      // hands back an empty scene.
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(legacyBlob()),
      });

      await store.saveStudio(
        _manuscript(sceneOneContent: '', sceneIds: const ['scene-1']),
      );

      final history = await repository.sceneProseSnapshots('scene-1');
      expect(
        history.map((entry) => entry.plainText),
        contains('Prose written before the split.'),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(_proseBackupKey(_projectId)),
        contains('Prose written before the split.'),
      );
    });

    test('it runs once, not on every save', () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(legacyBlob()),
      });

      final loaded = await _reload(store);
      await store.saveStudio(
        _withSceneContent(loaded, 'scene-1', 'Rewritten after the migration.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );
      final reloaded = await _reload(store);

      expect(
        reloaded.chapters.single.scenes.single.content,
        'Rewritten after the migration.',
      );
      final history = await repository.sceneProseSnapshots('scene-1');
      expect(
        history.where((entry) =>
            entry.reason == SceneProseSnapshotReason.imported),
        hasLength(1),
      );
    });

    test('a malformed blob still opens, and prose works from there on',
        () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): '{ not json',
      });

      // The load falls through to the seed path rather than throwing, and the
      // project is not wrongly recorded as migrated on the way past: nothing
      // was read out of the unreadable blob.
      final seeded = await _reload(store);
      expect(seeded.chapters, isNotEmpty);

      final written = await ManuscriptService(
        projectId: _projectId,
        repository: repository,
        store: store,
      ).save(
        _withSceneContent(
          seeded,
          seeded.chapters.first.scenes.first.id,
          'Written after the repair.',
        ),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final reloaded = await _reload(store);
      expect(
        reloaded.sceneById(written.chapters.first.scenes.first.id)!.content,
        'Written after the repair.',
      );
    });
  });

  group('prose history', () {
    test('routine autosaves do not each leave a snapshot', () async {
      var manuscript = _manuscript();
      await store.saveStudio(manuscript);
      for (var index = 0; index < 10; index++) {
        manuscript = _withSceneContent(manuscript, 'scene-1', 'Draft $index.');
        await store.saveStudio(
          manuscript,
          timestamp: _timestamp.add(Duration(seconds: index)),
        );
      }

      // One: the first edit away from the state the scene was saved in.
      expect(await repository.sceneProseSnapshots('scene-1'), hasLength(1));
    });

    test('a large deletion is kept even between snapshots', () async {
      final long = List.filled(200, 'word').join(' ');
      var manuscript = _withSceneContent(_manuscript(), 'scene-1', long);
      await store.saveStudio(manuscript);
      // Nudge it once so the scene has a snapshot and the interval is fresh.
      manuscript = _withSceneContent(manuscript, 'scene-1', '$long!');
      await store.saveStudio(
        manuscript,
        timestamp: _timestamp.add(const Duration(seconds: 1)),
      );
      manuscript = _withSceneContent(manuscript, 'scene-1', 'oops');
      await store.saveStudio(
        manuscript,
        timestamp: _timestamp.add(const Duration(seconds: 2)),
      );

      final history = await repository.sceneProseSnapshots('scene-1');
      expect(history, hasLength(2));
      expect(history.first.plainText, '$long!');
    });

    test('the history is bounded', () async {
      const policy = SceneProseSnapshotPolicy(retainedPerScene: 3);
      final bounded = ManuscriptStore(
        repository: repository,
        snapshotPolicy: policy,
      );
      var manuscript = _manuscript();
      await bounded.saveStudio(manuscript);
      for (var index = 0; index < 8; index++) {
        manuscript = _withSceneContent(manuscript, 'scene-1', 'Draft $index.');
        // An hour apart, so the policy fires every time.
        await bounded.saveStudio(
          manuscript,
          timestamp: _timestamp.add(Duration(hours: index + 1)),
        );
      }

      final history = await repository.sceneProseSnapshots('scene-1');
      expect(history, hasLength(3));
      expect(history.first.plainText, 'Draft 6.');
    });
  });

  group('restoring prose', () {
    late ManuscriptService service;

    setUp(() {
      service = ManuscriptService(
        projectId: _projectId,
        repository: repository,
        store: store,
      );
    });

    test('puts the words back and keeps the ones it replaced', () async {
      var manuscript = _manuscript();
      await store.saveStudio(manuscript);
      manuscript = _withSceneContent(
        manuscript,
        'scene-1',
        'A rewrite the author regrets.',
      );
      manuscript = await service.save(
        manuscript,
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final history = await service.proseHistoryFor('scene-1');
      expect(history, hasLength(1));

      final restored = await service.restoreSceneProse(
        manuscript,
        sceneId: 'scene-1',
        snapshotId: history.single.id,
        timestamp: _timestamp.add(const Duration(hours: 2)),
      );

      expect(
        restored.sceneById('scene-1')!.content,
        'Kali crosses the causeway.',
      );
      // The restore is itself reversible.
      final after = await service.proseHistoryFor('scene-1');
      expect(after.first.reason, SceneProseSnapshotReason.beforeRestore);
      expect(after.first.plainText, 'A rewrite the author regrets.');
    });

    test('leaves the scene title, status and metadata alone', () async {
      var manuscript = _manuscript();
      await store.saveStudio(manuscript);
      manuscript = _withSceneContent(manuscript, 'scene-1', 'Rewritten.');
      manuscript = manuscript.copyWith(chapters: [
        for (final chapter in manuscript.chapters)
          chapter.copyWith(scenes: [
            for (final scene in chapter.scenes)
              scene.id == 'scene-1'
                  ? scene.copyWith(
                      title: 'The Blood Price',
                      pov: 'kali',
                      status: ManuscriptNodeStatus.revising,
                    )
                  : scene,
          ]),
      ]);
      manuscript = await service.save(
        manuscript,
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final history = await service.proseHistoryFor('scene-1');
      final restored = await service.restoreSceneProse(
        manuscript,
        sceneId: 'scene-1',
        snapshotId: history.first.id,
        timestamp: _timestamp.add(const Duration(hours: 2)),
      );

      final scene = restored.sceneById('scene-1')!;
      expect(scene.content, 'Kali crosses the causeway.');
      expect(scene.title, 'The Blood Price');
      expect(scene.pov, 'kali');
      expect(scene.status, ManuscriptNodeStatus.revising);
    });

    test('refuses a snapshot that belongs to another scene', () async {
      await store.saveStudio(_manuscript());
      final manuscript = await service.save(
        _withSceneContent(_manuscript(), 'scene-1', 'Rewritten.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );
      final history = await service.proseHistoryFor('scene-1');

      expect(
        () => service.restoreSceneProse(
          manuscript,
          sceneId: 'scene-2',
          snapshotId: history.single.id,
        ),
        throwsStateError,
      );
    });

    test('a branch author cannot rewrite Canon prose', () async {
      var manuscript = _manuscript();
      await store.saveStudio(manuscript);
      manuscript = await service.save(
        _withSceneContent(manuscript, 'scene-1', 'Rewritten.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );
      final history = await service.proseHistoryFor('scene-1');

      expect(
        () => service.forBranch('branch-1').restoreSceneProse(
              manuscript,
              sceneId: 'scene-1',
              snapshotId: history.single.id,
            ),
        throwsA(isA<ManuscriptCanonException>()),
      );
    });
  });

  group('prose in the shared search index', () {
    test('a sentence an author wrote is findable', () async {
      await store.saveStudio(_manuscript());

      final search = UniversalSearchService(
        projectId: _projectId,
        repository: repository,
      );
      final hits = await search.searchAll('causeway');
      expect(hits.map((hit) => hit.recordId), contains('scene-1'));
    });

    test('rewritten prose stops matching its old words', () async {
      final manuscript = _manuscript();
      await store.saveStudio(manuscript);
      await store.saveStudio(
        _withSceneContent(manuscript, 'scene-1', 'Kali turns back at dawn.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final search = UniversalSearchService(
        projectId: _projectId,
        repository: repository,
      );
      expect(
        (await search.searchAll('dawn')).map((hit) => hit.recordId),
        contains('scene-1'),
      );
      expect(
        (await search.searchAll('causeway')).map((hit) => hit.recordId),
        isNot(contains('scene-1')),
      );
    });

    test('a deleted scene stops answering searches', () async {
      await store.saveStudio(_manuscript());
      await store.saveStudio(_manuscript(sceneIds: const ['scene-1']));

      final search = UniversalSearchService(
        projectId: _projectId,
        repository: repository,
      );
      expect(
        (await search.searchAll('Cassian')).map((hit) => hit.recordId),
        isNot(contains('scene-2')),
      );
    });
  });

  group('the document behind the string', () {
    test('the stored document round-trips through the manuscript', () async {
      const awkward = 'Line one.\n\nLine three, after a blank.\n';
      await store.saveStudio(
        _withSceneContent(_manuscript(), 'scene-1', awkward),
      );

      final prose = await repository.sceneProseById('scene-1');
      expect(prose!.document, ProseDocument.fromPlainText(awkward));
      final loaded = await _reload(store);
      expect(loaded.sceneById('scene-1')!.content, awkward);
    });
  });
}
