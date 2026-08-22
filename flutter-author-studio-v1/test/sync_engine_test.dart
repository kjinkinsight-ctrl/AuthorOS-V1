import 'dart:io';

import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/core/writing_session.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:author_studio_v1/sync/project_sync.dart';
import 'package:author_studio_v1/sync/sync_appliers.dart';
import 'package:author_studio_v1/sync/sync_engine.dart';
import 'package:author_studio_v1/sync/sync_store.dart';
import 'package:author_studio_v1/sync/sync_transport.dart';
import 'package:author_studio_v1/writing_goals_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory stand-in for Supabase.
///
/// The reason this file can exist at all: `AppSupabase` is a set of statics
/// whose `hasCredentials` is always false under test, so before the transport
/// seam neither the upload nor the download path could be exercised by a
/// single test.
class FakeSyncTransport extends SyncTransport {
  FakeSyncTransport({this.available = true});

  bool available;

  /// Makes the next push throw, so the queue-survives-failure path is real.
  bool failNextPush = false;

  /// Rows the server holds, keyed the way Supabase keys them.
  final Map<String, RemoteSyncRecord> rows = {};

  final List<String> pushed = [];

  /// Advances per push so rows have distinct, ordered timestamps unless a test
  /// deliberately pins them together.
  DateTime clock = DateTime.utc(2026, 8, 22, 10);

  @override
  bool get isAvailable => available;

  @override
  Future<void> push({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required int revision,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) async {
    if (failNextPush) {
      failNextPush = false;
      throw StateError('network is down');
    }
    clock = clock.add(const Duration(seconds: 1));
    pushed.add('$recordType/$recordId');
    rows['$recordType:$recordId'] = RemoteSyncRecord(
      recordType: recordType,
      recordId: recordId,
      action: action,
      baseRevision: baseRevision,
      revision: revision,
      payload: payload,
      updatedAt: clock,
      deviceId: deviceId,
    );
  }

  @override
  Future<List<RemoteSyncRecord>> pull({DateTime? since, int limit = 500}) async {
    final all = rows.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    // At-or-after, exactly as the real query does.
    final window = since == null
        ? all
        : all.where((row) => !row.updatedAt.isBefore(since)).toList();
    return window.take(limit).toList();
  }

  /// Seeds a row as if another device had written it.
  void seed({
    required String recordType,
    required String recordId,
    required Map<String, dynamic> payload,
    int revision = 1,
    String action = 'upsert',
    String deviceId = 'device-other',
    DateTime? updatedAt,
  }) {
    clock = updatedAt ?? clock.add(const Duration(seconds: 1));
    rows['$recordType:$recordId'] = RemoteSyncRecord(
      recordType: recordType,
      recordId: recordId,
      action: action,
      baseRevision: revision - 1,
      revision: revision,
      payload: ProjectSyncEnvelope(
        recordId: recordId,
        recordType: recordType,
        revision: revision,
        baseRevision: revision - 1,
        deviceId: deviceId,
        updatedAt: clock,
        payload: payload,
      ).toJson(),
      updatedAt: clock,
      deviceId: deviceId,
    );
  }
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
  late FakeSyncTransport transport;
  late SyncEngine engine;
  const store = SyncStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    transport = FakeSyncTransport();
    engine = buildSyncEngine(repository: repository, transport: transport);
  });

  tearDown(() => database.close());

  /// The roster and goals stores wired to this test's transport.
  ProjectRosterStore rosterStore() => ProjectRosterStore(
        repository: repository,
        recorder: SyncRecorder(transport: transport),
      );

  WritingGoalsStore goalsStore() => WritingGoalsStore(
        repository: repository,
        recorder: SyncRecorder(transport: transport),
      );

  group('push', () {
    test('a saved goal reaches the server', () async {
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );

      expect(transport.pushed, ['writing-goals/book-1']);
      final row = transport.rows['writing-goals:book-1']!;
      expect(row.revision, 1);
      expect(row.action, 'upsert');
      expect(await store.loadRevision('writing-goals', 'book-1'), 1);
      expect(await store.loadQueue(), isEmpty);
    });

    test('a failed upload stays queued and does not advance the revision',
        () async {
      transport.failNextPush = true;

      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );

      expect(transport.pushed, isEmpty);
      expect(await store.loadQueue(), hasLength(1));
      expect(await store.loadRevision('writing-goals', 'book-1'), 0);

      // The next flush picks it up.
      await engine.flush();
      expect(transport.pushed, ['writing-goals/book-1']);
      expect(await store.loadQueue(), isEmpty);
    });

    test('an unreadable operation is dropped rather than blocking the queue',
        () async {
      await store.enqueue(
        recordType: 'writing-goals',
        recordId: 'broken',
        action: 'upsert',
        baseRevision: 0,
        payload: const {'not': 'an envelope'},
      );
      await goalsStore().save(WritingGoals.defaultsFor('book-1'));

      await engine.flush();

      expect(await store.loadQueue(), isEmpty);
      expect(transport.pushed, contains('writing-goals/book-1'));
    });

    test('nothing is pushed, and no key written, while unavailable', () async {
      transport.available = false;
      final preferences = await SharedPreferences.getInstance();
      final keysBefore = preferences.getKeys().toSet();

      final result = await engine.sync();

      expect(result.ranOffline, isTrue);
      expect(transport.pushed, isEmpty);
      expect(
        preferences.getKeys().toSet(),
        keysBefore,
        reason: 'A signed-out app must not even mint a device id.',
      );
    });
  });

  group('pull', () {
    test('a goal from another device is applied', () async {
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 3000).toJson(),
        ),
      );

      final result = await engine.pull();

      expect(result.applied, 1);
      expect(
        (await repository.writingGoalsForProject('book-1'))?.dailyWords,
        3000,
      );
      expect(await store.loadRevision('writing-goals', 'book-1'), 1);
    });

    test('a series and a project from another device are applied', () async {
      transport.seed(
        recordType: 'series',
        recordId: 'series-1',
        payload: Map<String, dynamic>.from(
          const WritingSeries(
            id: 'series-1',
            name: 'Endovier Chronicles',
            defaultTargetWords: 90000,
          ).toJson(),
        ),
      );
      transport.seed(
        recordType: 'project',
        recordId: 'book-1',
        payload: Map<String, dynamic>.from(
          const StarterProjectSyncAdapter()
              .toEnvelope(
                _project('book-1', title: 'Throne of Ash'),
                deviceId: 'device-other',
                revision: 1,
                baseRevision: 0,
                updatedAt: DateTime.utc(2026, 8, 22),
                membership: const ProjectSeriesMembership(
                  seriesId: 'series-1',
                  seriesPosition: 0,
                ),
              )
              .payload,
        ),
      );

      await engine.pull();

      expect((await repository.seriesById('series-1'))?.name,
          'Endovier Chronicles');
      final entry = await repository.projectRosterEntry('book-1');
      expect(entry?.title, 'Throne of Ash');
      expect(entry?.seriesId, 'series-1');
      expect(entry?.seriesPosition, 0);
    });

    test('our own echo is skipped', () async {
      final deviceId = await store.getOrCreateDeviceId();
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );
      // The server now holds our row, written by us.
      expect(transport.rows['writing-goals:book-1']!.deviceId, deviceId);

      final result = await engine.pull();

      expect(result.applied, 0);
      expect(result.skipped, 1);
    });

    test('a strictly older revision is skipped', () async {
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 2500),
      );
      expect(await store.loadRevision('writing-goals', 'book-1'), 2);

      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        revision: 1,
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 999).toJson(),
        ),
      );

      final result = await engine.pull();

      expect(result.applied, 0);
      expect(
        (await repository.writingGoalsForProject('book-1'))?.dailyWords,
        2500,
        reason: 'An older revision must never overwrite a newer local one.',
      );
    });

    test('a tie from another device applies, so the two converge', () async {
      // The case that documents last-writer-wins. Both devices reached
      // revision 1; the server holds the other one's copy. Skipping on a tie
      // would leave this device holding a version nobody else will ever see.
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        revision: 1,
        deviceId: 'device-other',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 4000).toJson(),
        ),
      );

      final result = await engine.pull();

      expect(result.applied, 1);
      expect(
        (await repository.writingGoalsForProject('book-1'))?.dailyWords,
        4000,
      );
    });

    test('a record type this build does not know is stepped over', () async {
      transport.seed(
        recordType: 'universe',
        recordId: 'universe-1',
        payload: const {'name': 'Something newer'},
      );

      final result = await engine.pull();

      expect(result.unknownTypes, 1);
      expect(result.applied, 0);
      expect(
        await store.loadCursor(),
        isNotNull,
        reason: 'The cursor must still advance, or every later record queues '
            'up behind something this build will never understand.',
      );
    });

    test('applying a pull never enqueues anything back', () async {
      // The anti-ping-pong guarantee: appliers write through the repository,
      // not the stores, so a received change is not immediately re-sent.
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 3000).toJson(),
        ),
      );
      transport.seed(
        recordType: 'series',
        recordId: 'series-1',
        payload: Map<String, dynamic>.from(
          const WritingSeries(
            id: 'series-1',
            name: 'Endovier',
            defaultTargetWords: 90000,
          ).toJson(),
        ),
      );

      await engine.pull();

      expect(await store.loadQueue(), isEmpty);
    });
  });

  group('the cursor', () {
    test('advances to the newest row seen', () async {
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').toJson(),
        ),
        updatedAt: DateTime.utc(2026, 8, 22, 12),
      );

      await engine.pull();

      expect(
        DateTime.parse((await store.loadCursor())!),
        DateTime.utc(2026, 8, 22, 12),
      );
    });

    test('re-pulling a row at the cursor changes nothing', () async {
      // Two rows sharing one instant, which a multi-book reorder really does
      // produce. The query is at-or-after the cursor, so the boundary row
      // comes back every time — and must be harmless.
      final shared = DateTime.utc(2026, 8, 22, 12);
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1111).toJson(),
        ),
        updatedAt: shared,
      );
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-2',
        payload: Map<String, dynamic>.from(
          WritingGoals.defaultsFor('book-2').copyWith(dailyWords: 2222).toJson(),
        ),
        updatedAt: shared,
      );

      final first = await engine.pull();
      final second = await engine.pull();

      expect(first.applied, 2, reason: 'Neither row may be lost to the tie.');
      expect(second.applied, 0);
      expect(
        (await repository.writingGoalsForProject('book-1'))?.dailyWords,
        1111,
      );
      expect(
        (await repository.writingGoalsForProject('book-2'))?.dailyWords,
        2222,
      );
    });
  });

  group('tombstones', () {
    test('a goals tombstone restores never-customized, not the defaults',
        () async {
      await goalsStore().save(
        WritingGoals.defaultsFor('book-1').copyWith(dailyWords: 1500),
      );
      transport.seed(
        recordType: 'writing-goals',
        recordId: 'book-1',
        revision: 9,
        action: 'delete',
        payload: const {},
      );

      await engine.pull();

      expect(await repository.writingGoalsForProject('book-1'), isNull);
      expect(
        (await goalsStore().load('book-1')).updatedAt,
        isNull,
        reason: 'No row means never customized, which is what was deleted.',
      );
    });

    test('a project tombstone leaves the manuscript and history untouched',
        () async {
      final roster = rosterStore();
      await roster.save(_project('book-1'));
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'author_studio.manuscript_studio.book-1',
        '{"projectId":"book-1"}',
      );
      await repository.putWritingSession(
        WritingSession(
          id: 'ws-1',
          projectId: 'book-1',
          startedAt: DateTime(2026, 8, 20, 9),
          endedAt: DateTime(2026, 8, 20, 10),
          startingWordCount: 0,
          endingWordCount: 500,
          wordsAdded: 500,
          wordsRemoved: 0,
        ),
      );

      transport.seed(
        recordType: 'project',
        recordId: 'book-1',
        revision: 9,
        action: 'delete',
        payload: const {},
      );
      await engine.pull();

      expect(await repository.projectRosterEntry('book-1'), isNull);
      expect(
        preferences.getString('author_studio.manuscript_studio.book-1'),
        isNotNull,
        reason: 'A roster deletion from another device is still roster-only.',
      );
      expect(
        await repository.writingSessionsForProject('book-1'),
        hasLength(1),
      );
    });

    test('a series tombstone releases its books rather than deleting them',
        () async {
      final roster = rosterStore();
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

      transport.seed(
        recordType: 'series',
        recordId: 'series-1',
        revision: 9,
        action: 'delete',
        payload: const {},
      );
      await engine.pull();

      expect(await repository.seriesById('series-1'), isNull);
      final surviving = await repository.projectRoster();
      expect(surviving, hasLength(2));
      expect(surviving.every((entry) => !entry.isBook), isTrue);
    });
  });

  group('roster membership on the wire', () {
    test('absent membership preserves what this device already has', () async {
      final roster = rosterStore();
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      await roster.save(_project('book-1'));
      await roster.addBookToSeries(projectId: 'book-1', seriesId: 'series-1');

      // An onboarding save has no roster to consult, so it sends none.
      transport.seed(
        recordType: 'project',
        recordId: 'book-1',
        revision: 99,
        payload: Map<String, dynamic>.from(
          const StarterProjectSyncAdapter()
              .toEnvelope(
                _project('book-1', title: 'Renamed Elsewhere'),
                deviceId: 'device-other',
                revision: 99,
                baseRevision: 98,
                updatedAt: DateTime.utc(2026, 8, 22),
              )
              .payload,
        ),
      );
      await engine.pull();

      final entry = await repository.projectRosterEntry('book-1');
      expect(entry?.title, 'Renamed Elsewhere');
      expect(
        entry?.seriesId,
        'series-1',
        reason: 'A sender that knows nothing about series must not be able to '
            'knock a book out of one.',
      );
    });

    test('explicit standalone membership takes the book out of its series',
        () async {
      final roster = rosterStore();
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier',
          defaultTargetWords: 0,
        ),
      );
      await roster.save(_project('book-1'));
      await roster.addBookToSeries(projectId: 'book-1', seriesId: 'series-1');

      transport.seed(
        recordType: 'project',
        recordId: 'book-1',
        revision: 99,
        payload: Map<String, dynamic>.from(
          const StarterProjectSyncAdapter()
              .toEnvelope(
                _project('book-1'),
                deviceId: 'device-other',
                revision: 99,
                baseRevision: 98,
                updatedAt: DateTime.utc(2026, 8, 22),
                membership: const ProjectSeriesMembership.standalone(),
              )
              .payload,
        ),
      );
      await engine.pull();

      expect((await repository.projectRosterEntry('book-1'))?.isBook, isFalse);
    });
  });

  group('architecture', () {
    test('appliers write through the repository, never through a store', () {
      final source =
          File('lib/sync/sync_appliers.dart').readAsStringSync();
      final appliers = source.substring(
        source.indexOf('class ProjectRecordApplier'),
      );

      for (final forbidden in const [
        'ProjectRosterStore',
        'WritingGoalsStore',
        'recorder.',
      ]) {
        expect(
          appliers,
          isNot(contains(forbidden)),
          reason: 'An applier calling a store would enqueue the change it just '
              'received, and two devices would trade it forever.',
        );
      }
    });

    test('the goals store still keeps preferences at arm\'s length', () {
      expect(
        File('lib/writing_goals_store.dart').readAsStringSync(),
        isNot(contains('SharedPreferences')),
      );
    });

    test('no library mentions both preferences and writing goals', () {
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (!source.contains('SharedPreferences')) continue;
        expect(source, isNot(contains('WritingGoals')), reason: file.path);
      }
    });
  });
}
