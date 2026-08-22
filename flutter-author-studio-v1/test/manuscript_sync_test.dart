import 'dart:io';

import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/sync/manuscript_appliers.dart';
import 'package:author_studio_v1/sync/manuscript_sync.dart';
import 'package:author_studio_v1/sync/sync_appliers.dart';
import 'package:author_studio_v1/sync/sync_store.dart';
import 'package:author_studio_v1/sync/sync_transport.dart';
import 'package:author_studio_v1/writing_session_recorder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 22, 9);

/// Never available, so nothing flushes and the queue is the assertion surface.
class OfflineTransport extends SyncTransport {
  const OfflineTransport();

  @override
  bool get isAvailable => false;

  @override
  Future<void> push({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required int revision,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) async =>
      throw StateError('offline');

  @override
  Future<List<RemoteSyncRecord>> pull({DateTime? since, int limit = 500}) async
      => const [];
}

String _words(int count) =>
    List<String>.generate(count, (index) => 'word${index + 1}').join(' ');

ManuscriptScene _scene(
  String id, {
  String chapterId = 'ch-1',
  required String content,
  DateTime? updatedAt,
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: 'Scene $id',
      order: 1,
      content: content,
      status: ManuscriptNodeStatus.draft,
      createdAt: timestamp,
      updatedAt: updatedAt ?? timestamp,
    );

ManuscriptProjectSummary _manuscript(
  List<ManuscriptScene> scenes, {
  String title = 'The Hollow Court',
  String chapterTitle = 'Chapter One',
}) =>
    ManuscriptProjectSummary(
      projectId: 'book-1',
      manuscriptTitle: title,
      chapters: [
        ManuscriptChapter(
          id: 'ch-1',
          title: chapterTitle,
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

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;
  late ManuscriptSyncRecorder recorder;
  const syncStore = SyncStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
    recorder = ManuscriptSyncRecorder(
      store: store,
      recorder: const SyncRecorder(transport: OfflineTransport()),
    );
  });

  tearDown(() => database.close());

  Future<List<String>> queued() async => (await syncStore.loadQueue())
      .map((op) => '${op.action}:${op.recordType}/${op.recordId}')
      .toList()
    ..sort();

  /// Empties the queue. Nothing flushes in these tests, so without this each
  /// assertion would also see everything the set-up queued.
  Future<void> drain() async {
    for (final operation in await syncStore.loadQueue()) {
      await syncStore.acknowledge(operation.operationId);
    }
  }

  group('only what changed is queued', () {
    test('a first sync queues every scene and the outline once', () async {
      await store.saveStudio(
        _manuscript([
          _scene('sc-1', content: 'One.'),
          _scene('sc-2', content: 'Two.'),
        ]),
        persistLegacyText: false,
      );

      final count = await recorder.recordChanges(
        (await store.peekStudio('book-1'))!,
      );

      expect(count, 3);
      expect(await queued(), [
        'upsert:manuscript-structure/book-1',
        'upsert:scene/sc-1',
        'upsert:scene/sc-2',
      ]);
    });

    test('a second pass with nothing changed queues nothing', () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);

      final again = await recorder.recordChanges(manuscript);

      expect(again, 0);
    });

    test('editing one scene of many queues only that scene', () async {
      final scenes = [
        for (var index = 0; index < 20; index++)
          _scene('sc-$index', content: 'Scene $index.'),
      ];
      final manuscript = _manuscript(scenes);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);
      await drain();

      final edited = manuscript.copyWith(
        chapters: [
          manuscript.chapters.single.copyWith(
            scenes: [
              for (final scene in scenes)
                if (scene.id == 'sc-7')
                  scene.copyWith(
                    content: 'Rewritten.',
                    updatedAt: timestamp.add(const Duration(minutes: 10)),
                  )
                else
                  scene,
            ],
          ),
        ],
      );
      await store.saveStudio(edited, persistLegacyText: false);

      final count = await recorder.recordChanges(edited);

      expect(count, 1);
      expect(await queued(), ['upsert:scene/sc-7']);
    });

    test('prose changes do not re-send the outline', () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);
      await drain();

      final edited = manuscript.copyWith(
        chapters: [
          manuscript.chapters.single.copyWith(
            scenes: [
              _scene(
                'sc-1',
                content: 'One, rewritten.',
                updatedAt: timestamp.add(const Duration(minutes: 5)),
              ),
            ],
          ),
        ],
      );
      await store.saveStudio(edited, persistLegacyText: false);
      await recorder.recordChanges(edited);

      expect(await queued(), ['upsert:scene/sc-1']);
    });

    test('renaming a chapter sends the outline and no prose', () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);
      await drain();

      final renamed = manuscript.copyWith(
        chapters: [
          manuscript.chapters.single.copyWith(title: 'Chapter One, Revised'),
        ],
      );
      await store.saveStudio(renamed, persistLegacyText: false);
      await recorder.recordChanges(renamed);

      expect(await queued(), ['upsert:manuscript-structure/book-1']);
    });

    test('a deleted scene queues a tombstone', () async {
      final manuscript = _manuscript([
        _scene('sc-1', content: 'One.'),
        _scene('sc-2', content: 'Two.'),
      ]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);
      await drain();

      final trimmed = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.saveStudio(trimmed, persistLegacyText: false);
      await recorder.recordChanges(trimmed);

      expect(await queued(), contains('delete:scene/sc-2'));
    });

    test('editing the same scene repeatedly leaves one queued operation',
        () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);
      await drain();

      for (var pass = 1; pass <= 5; pass++) {
        final edited = manuscript.copyWith(
          chapters: [
            manuscript.chapters.single.copyWith(
              scenes: [
                _scene(
                  'sc-1',
                  content: 'Draft $pass.',
                  updatedAt: timestamp.add(Duration(minutes: pass)),
                ),
              ],
            ),
          ],
        );
        await store.saveStudio(edited, persistLegacyText: false);
        await recorder.recordChanges(edited);
      }

      expect(await queued(), ['upsert:scene/sc-1']);
    });
  });

  group('the queue never holds a second copy of the novel', () {
    test('a queued scene carries a reference, not its prose', () async {
      final manuscript = _manuscript([
        _scene('sc-1', content: _words(2000)),
      ]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);

      final operation = (await syncStore.loadQueue())
          .firstWhere((op) => op.recordId == 'sc-1');
      final encoded = '${operation.payload}';

      expect(encoded, contains('sc-1'));
      expect(
        encoded.length,
        lessThan(500),
        reason: 'The prose is read again at flush time; putting it in the '
            'queue would store the manuscript twice.',
      );
    });

    test('the resolver supplies the current text at flush time', () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'First draft.')]);
      await store.saveStudio(manuscript, persistLegacyText: false);
      await recorder.recordChanges(manuscript);

      // The author keeps writing after queueing.
      await store.saveStudio(
        manuscript.copyWith(
          chapters: [
            manuscript.chapters.single.copyWith(
              scenes: [
                _scene(
                  'sc-1',
                  content: 'Second draft.',
                  updatedAt: timestamp.add(const Duration(minutes: 5)),
                ),
              ],
            ),
          ],
        ),
        persistLegacyText: false,
      );

      final resolved = await SceneSyncPayloadResolver(
        projectId: 'book-1',
        store: store,
      ).resolve('sc-1');

      expect(
        SceneSyncPayload.fromJson(resolved!).content,
        'Second draft.',
        reason: 'What uploads should be the scene as it stands, not a snapshot '
            'from whenever the author last paused.',
      );
    });

    test('a scene deleted before the flush resolves to nothing', () async {
      await store.saveStudio(
        _manuscript([_scene('sc-1', content: 'One.')]),
        persistLegacyText: false,
      );

      final resolved = await SceneSyncPayloadResolver(
        projectId: 'book-1',
        store: store,
      ).resolve('sc-gone');

      expect(resolved, isNull);
    });
  });

  group('applying remote prose is not the author writing', () {
    test('a word count that jumps because of a sync records no session',
        () async {
      final recorder = WritingSessionRecorder(
        projectId: 'book-1',
        repository: repository,
      );

      // The author has been writing: a session is open.
      recorder.noteBaseline(5000);
      await recorder.noteActivity(wordCount: 5200);
      expect(recorder.hasOpenSession, isTrue);

      // A pull brings 7,000 words from another device.
      await recorder.noteRemoteChange(12200);

      // The genuine 200 words were recorded; the arriving 7,000 were not.
      final sessions = await repository.writingSessionsForProject('book-1');
      expect(sessions, hasLength(1));
      expect(sessions.single.wordsWritten, 200);

      // And the next keystroke is measured from the new count, not the old.
      await recorder.noteActivity(wordCount: 12250);
      await recorder.finalizeSession();

      final after = await repository.writingSessionsForProject('book-1');
      expect(after, hasLength(2));
      expect(
        after.last.wordsWritten,
        50,
        reason: 'Without noteRemoteChange this would be 7,250 — the pulled '
            'words credited to the author.',
      );
    });

    test('it works when no session is open', () async {
      final recorder = WritingSessionRecorder(
        projectId: 'book-1',
        repository: repository,
      );
      recorder.noteBaseline(5000);

      await recorder.noteRemoteChange(12000);
      await recorder.noteActivity(wordCount: 12010);
      await recorder.finalizeSession();

      final sessions = await repository.writingSessionsForProject('book-1');
      expect(sessions, hasLength(1));
      expect(sessions.single.wordsWritten, 10);
    });

    test('a plain baseline would not have been enough', () async {
      // Why noteRemoteChange exists at all: noteBaseline is deliberately a
      // no-op while a session is open, so it cannot fix this on its own.
      final recorder = WritingSessionRecorder(
        projectId: 'book-1',
        repository: repository,
      );
      recorder.noteBaseline(5000);
      await recorder.noteActivity(wordCount: 5200);

      recorder.noteBaseline(12200);

      expect(
        recorder.lastObservedWordCount,
        5200,
        reason: 'The baseline was dropped because a session was open — which '
            'is exactly the case noteRemoteChange handles.',
      );
    });
  });

  group('applying does not re-queue', () {
    test('applyRemote leaves nothing to send', () async {
      final manuscript = _manuscript([_scene('sc-1', content: 'One.')]);
      await store.applyRemote(manuscript);

      final count = await recorder.recordChanges(manuscript);

      expect(
        count,
        0,
        reason: 'A scene that arrived from another device must not be queued '
            'straight back, or two devices trade it forever.',
      );
    });
  });

  group('architecture', () {
    test('the manuscript store keeps its read-only peek and its R-21 note', () {
      final source = File('lib/manuscript_store.dart').readAsStringSync();

      expect(source, contains('Future<ManuscriptProjectSummary?> peekStudio'));
      expect(source, contains('R-21'));
    });

    test('the store never mentions writing sessions', () {
      // It contains SharedPreferences, and an existing architecture rule
      // forbids any one file from holding both.
      final source = File('lib/manuscript_store.dart').readAsStringSync();

      expect(source, contains('SharedPreferences'));
      expect(source, isNot(contains('WritingSession')));
    });

    test('recording is never wired into saveStudio', () {
      // loadStudio calls saveStudio when it seeds a manuscript, so a hook
      // there would enqueue during a read — which four preference-key
      // snapshots exist to catch.
      final source = File('lib/manuscript_store.dart').readAsStringSync();
      final start = source.indexOf('Future<void> saveStudio(');
      final saveStudio = source.substring(start, start + 900);

      expect(saveStudio, isNot(contains('recordChanges')));
      expect(saveStudio, isNot(contains('SyncRecorder')));
      // And the whole store stays clear of the recorder that queues changes.
      expect(source, isNot(contains('ManuscriptSyncRecorder')));
    });

    test('the resolver reads through the non-seeding peek', () {
      final source =
          File('lib/sync/manuscript_appliers.dart').readAsStringSync();
      final resolver = source.substring(
        source.indexOf('class SceneSyncPayloadResolver'),
        source.indexOf('class SceneApplyOutcome'),
      );

      expect(resolver, contains('peekStudio('));
      expect(resolver, isNot(contains('loadStudio(')));
    });
  });
}
