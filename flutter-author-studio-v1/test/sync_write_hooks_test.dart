import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:author_studio_v1/sync/project_sync.dart';
import 'package:author_studio_v1/sync/sync_appliers.dart';
import 'package:author_studio_v1/sync/sync_store.dart';
import 'package:author_studio_v1/sync/sync_transport.dart';
import 'package:author_studio_v1/writing_goals_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A transport that is never available, so nothing flushes and the queue
/// itself is what these tests read.
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

StarterProject _project(String id, {String? title, int wordGoal = 80000}) =>
    StarterProject(
      id: id,
      title: title ?? id,
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ProjectRosterStore roster;
  late WritingGoalsStore goals;
  const store = SyncStore();
  const recorder = SyncRecorder(transport: OfflineTransport());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    roster = ProjectRosterStore(repository: repository, recorder: recorder);
    goals = WritingGoalsStore(repository: repository, recorder: recorder);
  });

  tearDown(() => database.close());

  Future<List<String>> queuedOps() async => (await store.loadQueue())
      .map((op) => '${op.action}:${op.recordType}/${op.recordId}')
      .toList()
    ..sort();

  /// Only the project operations. Nothing flushes in these tests, so the queue
  /// keeps everything the set-up enqueued too.
  Future<List<String>> queuedProjectOps() async =>
      (await queuedOps()).where((op) => op.contains(':project/')).toList();

  group('writing goals', () {
    test('saving queues one upsert carrying the stored row', () async {
      final saved = await goals.save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );

      expect(await queuedOps(), ['upsert:writing-goals/book-1']);

      final envelope = ProjectSyncEnvelope.fromJson(
        (await store.loadQueue()).single.payload,
      );
      final payload = WritingGoals.fromJson(
        Map<String, dynamic>.from(envelope.payload),
      );
      expect(payload.dailyWords, 1500);
      expect(
        payload,
        saved,
        reason: 'The payload other devices receive must be the row that was '
            'stored, instant included — not a second stamping of it.',
      );
    });

    test('restoring defaults queues a tombstone, not the default values',
        () async {
      await goals.save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );
      await goals.restoreDefaults('book-1');

      expect(await queuedOps(), ['delete:writing-goals/book-1']);
      expect((await store.loadQueue()).single.deletedAt, isNotNull);
    });

    test('loading queues nothing at all', () async {
      await goals.load('book-1');
      await goals.load('book-1');

      expect(await store.loadQueue(), isEmpty);
    });
  });

  group('the roster', () {
    test('saving a project queues one upsert with its membership', () async {
      await roster.save(_project('book-1'));

      expect(await queuedOps(), ['upsert:project/book-1']);

      final envelope = ProjectSyncEnvelope.fromJson(
        (await store.loadQueue()).single.payload,
      );
      final membership = ProjectSeriesMembership.fromPayload(envelope.payload);
      expect(
        membership,
        isNotNull,
        reason: 'This store knows the roster, so it always states membership '
            'explicitly — silence would mean "preserve" on the far side.',
      );
      expect(membership!.isBook, isFalse);
    });

    test('removing a project queues a tombstone', () async {
      await roster.save(_project('book-1'));
      await roster.remove('book-1');

      expect(await queuedOps(), ['delete:project/book-1']);
    });

    test('saving a series queues one series upsert', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 90000,
        ),
      );

      expect(await queuedOps(), ['upsert:series/series-1']);
    });

    test('deleting a series queues its tombstone and every freed book',
        () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      for (final id in ['book-1', 'book-2']) {
        await roster.save(_project(id));
        await roster.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await roster.deleteSeries('series-1');

      expect(
        await queuedOps(),
        [
          'delete:series/series-1',
          'upsert:project/book-1',
          'upsert:project/book-2',
        ],
        reason: 'A series tombstone alone leaves the other device no way to '
            'know its books are standalone now.',
      );
    });

    test('reordering three books queues three operations, not nine', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await roster.save(_project(id));
        await roster.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await roster.reorderBooks('series-1', ['book-c', 'book-a', 'book-b']);

      expect(await queuedProjectOps(), [
        'upsert:project/book-a',
        'upsert:project/book-b',
        'upsert:project/book-c',
      ]);
    });

    test('reordering twice before going online still queues three', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      for (final id in ['book-a', 'book-b', 'book-c']) {
        await roster.save(_project(id));
        await roster.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await roster.reorderBooks('series-1', ['book-c', 'book-a', 'book-b']);
      await roster.reorderBooks('series-1', ['book-b', 'book-c', 'book-a']);

      expect(
        await queuedProjectOps(),
        hasLength(3),
        reason: 'The queue collapses by record, so dragging books about while '
            'offline never grows it.',
      );

      // And the queued positions are the latest ones, not the first reorder's.
      final byId = {
        for (final op in (await store.loadQueue())
            .where((op) => op.recordType == 'project'))
          op.recordId: ProjectSeriesMembership.fromPayload(
            ProjectSyncEnvelope.fromJson(op.payload).payload,
          )!,
      };
      expect(byId['book-b']!.seriesPosition, 0);
      expect(byId['book-c']!.seriesPosition, 1);
      expect(byId['book-a']!.seriesPosition, 2);
    });

    test('taking a book out of a series queues it as standalone', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      await roster.save(_project('book-1'));
      await roster.addBookToSeries(projectId: 'book-1', seriesId: 'series-1');

      await roster.removeBookFromSeries('book-1');

      final envelope = ProjectSyncEnvelope.fromJson(
        (await store.loadQueue())
            .firstWhere((op) => op.recordId == 'book-1')
            .payload,
      );
      final membership = ProjectSeriesMembership.fromPayload(envelope.payload);
      expect(membership?.seriesId, isNull);
      expect(
        membership,
        isNotNull,
        reason: 'Explicit standalone, not silence: silence would leave the '
            'book in its series on every other device.',
      );
    });

    test('loading queues nothing, adoption included', () async {
      // The pre-roster adoption inside load() writes a row. It goes to the
      // repository rather than through save(), which is what keeps the read
      // path silent — and this is the test that holds it there.
      SharedPreferences.setMockInitialValues({
        'author_studio.starter_project':
            '{"id":"legacy-1","title":"Hidden Draft","genre":"Fantasy",'
            '"projectType":"Novel","wordGoal":80000,"acts":[],"chapters":[],'
            '"characterSheets":[],"beatChecklist":[],'
            '"firstSceneTitle":"Opening Scene"}',
      });

      final adopted = await roster.load();

      expect(adopted, hasLength(1));
      expect(await store.loadQueue(), isEmpty);
    });

    test('reading series and books queues nothing', () async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      final before = await store.loadQueue();

      await roster.allSeries();
      await roster.books('series-1');
      await roster.seriesForProject('book-1');
      await roster.seriesById('series-1');

      expect(await store.loadQueue(), hasLength(before.length));
    });
  });

  group('a queue failure never costs the local write', () {
    test('the goal is still stored even if queuing throws', () async {
      // No preferences plugin at all: the queue cannot be written.
      SharedPreferences.setMockInitialValues({});
      final saved = await goals.save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );

      expect(saved.dailyWords, 1500);
      expect(
        (await repository.writingGoalsForProject('book-1'))?.dailyWords,
        1500,
      );
    });
  });
}
