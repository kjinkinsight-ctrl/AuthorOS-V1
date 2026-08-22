/// Where a scene's current prose lives, and how it got there.
///
/// The architecture these prove, in one picture:
///
/// ```text
/// Scene
///   |
///   +-- scene_prose_rows      current canonical prose
///   |
///   +-- scene_revision_rows   bounded history
/// ```
///
/// One current-prose store, one history store. The tests at the end hold the
/// tree to exactly that, because the failure mode this reconciliation exists
/// to prevent is a second one of either appearing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/scene_revision.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/scene_revision_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _projectId = 'project-a';
final _timestamp = DateTime.utc(2026, 8, 22, 9);

String _studioKey(String p) => 'author_studio.manuscript_studio.$p';
String _proseBackupKey(String p) => 'author_studio.manuscript_prose_backup.$p';

ManuscriptProjectSummary _manuscript({
  String sceneOne = 'Kali crosses the causeway.',
  String sceneTwo = 'Cassian waits at the gate.',
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
                content: index == 0 ? sceneOne : sceneTwo,
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

ManuscriptProjectSummary _withContent(
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

Map<String, Object> _blobWithProse(String prose) => {
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
              'content': prose,
              'status': 'draft',
              'createdAt': _timestamp.toIso8601String(),
              'updatedAt': _timestamp.toIso8601String(),
            },
          ],
        },
      ],
    };

Future<ManuscriptProjectSummary> _reload(ManuscriptStore store) =>
    store.loadStudio(
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

  group('where current prose lives', () {
    test('the structure blob no longer carries a word of prose', () async {
      await store.saveStudio(_manuscript());

      final blob = (await SharedPreferences.getInstance())
          .getString(_studioKey(_projectId))!;
      expect(blob, isNot(contains('Kali crosses the causeway')));
      expect(blob, isNot(contains('Cassian waits at the gate')));
      expect(blob, contains('chapter-1'));
      expect(blob, contains('Scene 01'));
    });

    test('prose comes back with the manuscript that was saved', () async {
      await store.saveStudio(_manuscript());

      final loaded = await _reload(store);
      expect(loaded.chapters.single.scenes.first.content,
          'Kali crosses the causeway.');
      expect(loaded.chapters.single.scenes.last.content,
          'Cassian waits at the gate.');
      expect(loaded.wordCount, 9);
    });

    test('peekStudio hydrates too, and never writes', () async {
      // The sync path reads through peekStudio. If it returned empty scenes,
      // every upload would erase the author's prose on the server.
      await store.saveStudio(_manuscript());
      final before = (await SharedPreferences.getInstance())
          .getString(_studioKey(_projectId));

      final peeked = await store.peekStudio(_projectId);

      expect(peeked!.sceneById('scene-1')!.content,
          'Kali crosses the causeway.');
      expect(
        (await SharedPreferences.getInstance()).getString(_studioKey(_projectId)),
        before,
      );
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
      expect(loaded.chapters.single.scenes.first.content,
          'Kali crosses the causeway.');

      database = AuthorOsDatabase(NativeDatabase.memory());
      addTearDown(() => directory.delete(recursive: true));
    });

    test('an empty scene is not given a row', () async {
      await store.saveStudio(_manuscript(sceneOne: '', sceneTwo: ''));
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
        _withContent(manuscript, 'scene-1', 'Kali turns back.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final after = await repository.sceneProseForProject(_projectId);
      expect(after['scene-1']!.revision, 2);
      expect(after['scene-1']!.plainText, 'Kali turns back.');
      expect(after['scene-2']!.revision, before['scene-2']!.revision);
      expect(after['scene-2']!.updatedAt, before['scene-2']!.updatedAt);
    });

    test('a scene removed from the manuscript takes its prose with it',
        () async {
      await store.saveStudio(_manuscript());
      await store.saveStudio(_manuscript(sceneIds: const ['scene-1']));

      expect(
        (await repository.sceneProseForProject(_projectId)).keys,
        ['scene-1'],
      );
    });
  });

  group('migration', () {
    test('a fresh database creates the prose table', () async {
      // onCreate, not onUpgrade: a new install must land on the same schema an
      // upgraded one reaches.
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          )
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        contains('scene_prose_rows'),
      );
      expect(AuthorOsDatabase.currentSchemaVersion, 13);
    });

    // Every schema the reconciliation has to be reachable from. 9 is the last
    // version before the performance work, 12 is what `main` shipped, and the
    // ones between are what a user mid-upgrade could be sitting on.
    for (final from in const [1, 2, 8, 9, 10, 11, 12]) {
      test('upgrades cleanly from schema $from', () async {
        await database.close();
        final directory =
            await Directory.systemTemp.createTemp('prose-upgrade-$from-');
        final file =
            File('${directory.path}${Platform.pathSeparator}db.sqlite');
        addTearDown(() => directory.delete(recursive: true));

        final old = AuthorOsDatabase(NativeDatabase(file), schemaVersion: from);
        await old.customSelect('SELECT 1').get();
        await old.close();

        final upgraded = AuthorOsDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        final tables = await upgraded
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
        final names = tables.map((row) => row.read<String>('name')).toSet();

        // The new table arrives, and nothing the earlier versions installed is
        // lost on the way past.
        expect(names, contains('scene_prose_rows'));
        expect(names, contains('scene_revision_rows'));
        expect(names, contains('writing_goal_rows'));
        expect(names, contains('writing_session_rows'));

        // And it is usable, not merely present.
        final store = ManuscriptStore(
          repository: DriftConnectedDomainRepository(upgraded),
        );
        await store.saveStudio(_manuscript());
        expect(
          (await _reload(store)).sceneById('scene-1')!.content,
          'Kali crosses the causeway.',
        );

        database = AuthorOsDatabase(NativeDatabase.memory());
      });
    }

    test('an existing manuscript blob moves into scene_prose_rows', () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(_blobWithProse('Prose from before.')),
      });

      final loaded = await _reload(store);

      expect(loaded.sceneById('scene-1')!.content, 'Prose from before.');
      expect(
        (await repository.sceneProseForProject(_projectId))['scene-1']!
            .plainText,
        'Prose from before.',
      );
    });

    test('the pre-migration blob is kept verbatim', () async {
      final encoded = jsonEncode(_blobWithProse('Prose from before.'));
      SharedPreferences.setMockInitialValues({_studioKey(_projectId): encoded});

      await _reload(store);

      expect(
        (await SharedPreferences.getInstance())
            .getString(_proseBackupKey(_projectId)),
        encoded,
      );
    });

    test('a save landing before any load cannot lose the prose', () async {
      // The dangerous ordering: something writes the manuscript -- and its
      // prose-free blob -- before anything has read the prose out of the old
      // one.
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(_blobWithProse('Prose from before.')),
      });

      await store.saveStudio(
        _manuscript(sceneOne: '', sceneIds: const ['scene-1']),
      );

      expect(
        (await SharedPreferences.getInstance())
            .getString(_proseBackupKey(_projectId)),
        contains('Prose from before.'),
      );
    });

    test('is idempotent', () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(_blobWithProse('Prose from before.')),
      });

      await _reload(store);
      final afterFirst =
          (await repository.sceneProseForProject(_projectId))['scene-1']!;
      await _reload(store);
      await _reload(store);
      final afterThird =
          (await repository.sceneProseForProject(_projectId))['scene-1']!;

      expect(afterThird.revision, afterFirst.revision);
      expect(afterThird.plainText, 'Prose from before.');
      expect(afterThird.updatedAt, afterFirst.updatedAt);
    });

    test('revision history taken before the move stays valid after it',
        () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): jsonEncode(_blobWithProse('Prose from before.')),
      });
      final revisions = SceneRevisionService(
        projectId: _projectId,
        repository: repository,
      );
      // A revision captured while prose still lived in the blob.
      final before = await _reload(store);
      await revisions.captureBoundary(before);

      // Now the same project, read again after migration.
      final after = await _reload(store);
      await store.saveStudio(
        _withContent(after, 'scene-1', 'Rewritten after the move.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final history = await revisions.historyFor('scene-1');
      expect(history, isNotEmpty);
      final restored = await revisions.restore(
        manuscript: await _reload(store),
        revisionId: history.last.id,
      );
      expect(restored!.sceneById('scene-1')!.content, 'Prose from before.');
    });

    test('a malformed blob still opens, and prose works from there on',
        () async {
      SharedPreferences.setMockInitialValues({
        _studioKey(_projectId): '{ not json',
      });

      final seeded = await _reload(store);
      expect(seeded.chapters, isNotEmpty);

      final sceneId = seeded.chapters.first.scenes.first.id;
      await store.saveStudio(
        _withContent(seeded, sceneId, 'Written after the repair.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );
      expect(
        (await _reload(store)).sceneById(sceneId)!.content,
        'Written after the repair.',
      );
    });
  });

  group('revisions read and write the canonical prose', () {
    late SceneRevisionService revisions;

    setUp(() {
      revisions = SceneRevisionService(
        projectId: _projectId,
        repository: repository,
      );
    });

    test('capture snapshots what scene_prose_rows holds', () async {
      await store.saveStudio(_manuscript());

      // The manuscript handed to capture is the hydrated one, so what lands in
      // history is what the prose table says -- not a stale blob.
      await revisions.captureBoundary(await _reload(store));

      final history = await revisions.historyFor('scene-1');
      expect(history, hasLength(1));
      final stored = await revisions.revision(history.single.id);
      expect(stored!.content, 'Kali crosses the causeway.');
    });

    test('restore writes back through the canonical prose path', () async {
      await store.saveStudio(_manuscript());
      await revisions.captureBoundary(await _reload(store));
      await store.saveStudio(
        _withContent(await _reload(store), 'scene-1', 'A regretted rewrite.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );

      final history = await revisions.historyFor('scene-1');
      final restored = await revisions.restore(
        manuscript: await _reload(store),
        revisionId: history.last.id,
      );
      await store.saveStudio(
        restored!,
        timestamp: _timestamp.add(const Duration(hours: 2)),
      );

      // The row, not just the returned object: a restore that only changed the
      // in-memory manuscript would be undone by the next load.
      expect(
        (await repository.sceneProseForProject(_projectId))['scene-1']!
            .plainText,
        'Kali crosses the causeway.',
      );
      expect(
        (await _reload(store)).sceneById('scene-1')!.content,
        'Kali crosses the causeway.',
      );
    });

    test('restore keeps what it replaced, so it is reversible', () async {
      await store.saveStudio(_manuscript());
      await revisions.captureBoundary(await _reload(store));
      await store.saveStudio(
        _withContent(await _reload(store), 'scene-1', 'A regretted rewrite.'),
        timestamp: _timestamp.add(const Duration(hours: 1)),
      );
      final history = await revisions.historyFor('scene-1');
      await revisions.restore(
        manuscript: await _reload(store),
        revisionId: history.last.id,
      );

      final after = await revisions.historyFor('scene-1');
      expect(
        after.map((entry) => entry.trigger),
        contains(SceneRevisionTrigger.restore),
      );
    });

    test('a deleted scene loses its prose but keeps its history', () async {
      await store.saveStudio(_manuscript());
      final loaded = await _reload(store);
      await revisions.captureScene(
        loaded.sceneById('scene-2')!,
        trigger: SceneRevisionTrigger.deletion,
      );
      await store.saveStudio(_manuscript(sceneIds: const ['scene-1']));

      expect(
        (await repository.sceneProseForProject(_projectId)).keys,
        ['scene-1'],
      );
      // The whole point of the deletion trigger: the words outlive the scene.
      final history = await revisions.historyFor('scene-2');
      expect(history, hasLength(1));
      expect(
        (await revisions.revision(history.single.id))!.content,
        'Cassian waits at the gate.',
      );
    });

    test('a remote change captures the local prose it is about to replace',
        () async {
      await store.saveStudio(_manuscript());
      final local = await _reload(store);
      final incoming =
          _withContent(local, 'scene-1', 'The version from the other device.');

      await revisions.captureBeforeRemote(local: local, incoming: incoming);
      await store.applyRemote(incoming);

      expect(
        (await _reload(store)).sceneById('scene-1')!.content,
        'The version from the other device.',
      );
      final history = await revisions.historyFor('scene-1');
      expect(history, hasLength(1));
      expect(history.single.trigger, SceneRevisionTrigger.remoteApply);
      expect(
        (await revisions.revision(history.single.id))!.content,
        'Kali crosses the causeway.',
      );
    });
  });

  group('prose in the shared search index', () {
    test('a sentence an author wrote is findable', () async {
      await store.saveStudio(_manuscript());

      final hits = await UniversalSearchService(
        projectId: _projectId,
        repository: repository,
      ).searchAll('causeway');
      expect(hits.map((hit) => hit.recordId), contains('scene-1'));
    });

    test('rewritten prose stops matching its old words', () async {
      await store.saveStudio(_manuscript());
      await store.saveStudio(
        _withContent(_manuscript(), 'scene-1', 'Kali turns back at dawn.'),
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
  });

  group('one of each system', () {
    test('there is exactly one current-prose store', () async {
      final tables = (await database
              .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
              .get())
          .map((row) => row.read<String>('name'))
          .toSet();

      expect(tables, contains('scene_prose_rows'));
      // The duplicate this reconciliation exists to prevent.
      expect(tables, isNot(contains('scene_prose_snapshot_rows')));
    });

    test('there is exactly one revision-history store', () async {
      final tables = (await database
              .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
              .get())
          .map((row) => row.read<String>('name'))
          .toSet();

      expect(
        tables.where((name) => name.contains('revision')),
        {'scene_revision_rows'},
      );
    });

    test('the prose store owns no history API', () {
      // Grepping the source is crude, and deliberately so: the moment this
      // library grows a `snapshot` or a `history`, there are two answers in
      // the tree to what a scene used to say, and they will diverge.
      final source = File('lib/core/scene_prose.dart').readAsStringSync();
      expect(source, isNot(contains('class SceneProseSnapshot')));
      expect(source, isNot(contains('SnapshotPolicy')));
    });
  });
}
