/// Sync — what each record type means locally.
///
/// One applier per `record_type`, plus the [SyncRecorder] the stores use to
/// queue their own changes going the other way.
///
/// Every applier writes through [DriftConnectedDomainRepository] rather than
/// through a store. The stores enqueue on write — that is how a local change
/// reaches the server — so an applier that called one would queue an upload of
/// the change it had just received, and two devices would trade the same
/// record back and forth forever.
library;

import 'package:flutter/foundation.dart';

import '../core/project_roster_entry.dart';
import '../core/writing_goals.dart';
import '../core/writing_series.dart';
import '../persistence/authoros_database.dart';
import 'project_sync.dart';
import 'sync_engine.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

/// Record type ids, written down once.
class SyncRecordTypes {
  const SyncRecordTypes._();

  /// A project, and — when the sender knew about it — its place in a series.
  static const project = 'project';

  /// One project's daily, weekly and monthly word targets.
  static const writingGoals = 'writing-goals';

  /// A named series.
  static const series = 'series';
}

/// Queues a local change for upload, and pushes what it can.
///
/// The stores call this after their local write has already committed, so a
/// sync failure can never cost the author their save — the rule
/// `OnboardingStore.saveProject` already states in a comment. Every method
/// swallows its errors for that reason.
class SyncRecorder {
  const SyncRecorder({
    SyncStore store = const SyncStore(),
    SyncTransport transport = const SupabaseSyncTransport(),
  })  : _store = store,
        _transport = transport;

  final SyncStore _store;
  final SyncTransport _transport;

  /// Queues an upsert. Does not push — see [flush].
  Future<void> recordUpsert({
    required String recordType,
    required String recordId,
    required Map<String, dynamic> payload,
  }) =>
      _record(
        recordType: recordType,
        recordId: recordId,
        action: 'upsert',
        payload: payload,
      );

  /// Queues a tombstone.
  ///
  /// A tombstone rather than "push the defaults back", because for goals those
  /// are different facts: a project with no stored row has never been
  /// customized, and one storing 2,000/10,000/40,000 has been customized to
  /// exactly the defaults. Pushing values would destroy that distinction on
  /// the receiving device.
  Future<void> recordDelete({
    required String recordType,
    required String recordId,
  }) =>
      _record(
        recordType: recordType,
        recordId: recordId,
        action: 'delete',
        payload: const {},
        deletedAt: DateTime.now().toUtc(),
      );

  Future<void> _record({
    required String recordType,
    required String recordId,
    required String action,
    required Map<String, dynamic> payload,
    DateTime? deletedAt,
  }) async {
    try {
      final baseRevision = await _store.loadRevision(recordType, recordId);
      final envelope = ProjectSyncEnvelope(
        recordId: recordId,
        recordType: recordType,
        revision: baseRevision + 1,
        baseRevision: baseRevision,
        deviceId: await _store.getOrCreateDeviceId(),
        updatedAt: DateTime.now().toUtc(),
        deletedAt: deletedAt,
        payload: payload,
        extensions: const {'source': 'flutter'},
      );
      await _store.enqueue(
        recordType: recordType,
        recordId: recordId,
        action: action,
        baseRevision: baseRevision,
        payload: envelope.toJson(),
        deletedAt: deletedAt,
      );
    } catch (error) {
      // The local write is already committed. Losing a queue entry costs a
      // sync; failing here would cost the author their work.
      debugPrint('Could not queue $recordType/$recordId for sync: $error');
    }
  }

  /// Uploads whatever is queued, if anything can be uploaded right now.
  ///
  /// Called once at the end of a store operation rather than per record, so
  /// reordering a five-book series is one round of five upserts and not five
  /// rounds of one.
  Future<void> flush() async {
    if (!_transport.isAvailable) return;
    try {
      await SyncEngine(store: _store, transport: _transport).flush();
    } catch (error) {
      debugPrint('Could not flush the sync queue: $error');
    }
  }
}

/// Applies a project — and, when the sender carried it, its series membership.
class ProjectRecordApplier extends SyncApplier {
  const ProjectRecordApplier({
    required this.repository,
    this.adapter = const StarterProjectSyncAdapter(),
  });

  final DriftConnectedDomainRepository repository;
  final StarterProjectSyncAdapter adapter;

  @override
  String get recordType => SyncRecordTypes.project;

  @override
  Future<void> applyUpsert(ProjectSyncEnvelope envelope) async {
    final synced = adapter.fromEnvelope(envelope);
    final existing = await repository.projectRosterEntry(envelope.recordId);
    final membership = synced.membership;

    await repository.putProjectRosterEntry(
      ProjectRosterEntry(
        project: synced.project,
        // No membership on the wire means the sender did not know about
        // series — an onboarding save, or an older client. Preserve what this
        // device already has rather than quietly making the book standalone.
        seriesId: membership == null ? existing?.seriesId : membership.seriesId,
        seriesPosition: membership == null
            ? existing?.seriesPosition
            : membership.seriesPosition,
        createdAt: existing?.createdAt,
        updatedAt: envelope.updatedAt,
      ),
    );
  }

  @override
  Future<void> applyDelete(String recordId) async {
    // Roster-only, exactly as a local removal is: the manuscript, the records
    // and the writing history all stay where they are. A deletion that arrived
    // from another device is no licence to destroy an author's writing.
    await repository.deleteProjectRosterEntry(recordId);
  }
}

/// Applies one project's writing goals.
class WritingGoalsApplier extends SyncApplier {
  const WritingGoalsApplier({required this.repository});

  final DriftConnectedDomainRepository repository;

  @override
  String get recordType => SyncRecordTypes.writingGoals;

  @override
  Future<void> applyUpsert(ProjectSyncEnvelope envelope) async {
    final goals = WritingGoals.fromJson(
      Map<String, dynamic>.from(envelope.payload),
    );
    // Normalized on the way in as well as on the way out: a remote client is
    // not owed the benefit of the doubt about a negative or absurd target.
    await repository.putWritingGoals(
      goals.copyWith(projectId: envelope.recordId).normalized(),
    );
  }

  @override
  Future<void> applyDelete(String recordId) async {
    // Restores "never customized", which is what the sending device meant.
    await repository.deleteWritingGoalsForProject(recordId);
  }
}

/// Applies a series.
class SeriesApplier extends SyncApplier {
  const SeriesApplier({required this.repository});

  final DriftConnectedDomainRepository repository;

  @override
  String get recordType => SyncRecordTypes.series;

  @override
  Future<void> applyUpsert(ProjectSyncEnvelope envelope) async {
    final series = WritingSeries.fromJson(
      Map<String, dynamic>.from(envelope.payload),
    );
    await repository.putSeries(
      series.copyWith(id: envelope.recordId).normalized(),
    );
  }

  @override
  Future<void> applyDelete(String recordId) async {
    // Releases the series' books in a transaction and then removes it. The
    // books survive as standalone projects — deleting a series has never been
    // a way to delete books, and that does not change because the instruction
    // came over the wire.
    await repository.deleteSeries(recordId);
  }
}

/// The engine as the running app wires it: every applier, over one repository.
SyncEngine buildSyncEngine({
  DriftConnectedDomainRepository? repository,
  SyncStore store = const SyncStore(),
  SyncTransport transport = const SupabaseSyncTransport(),
}) {
  final resolved = repository ?? authorOsRepository;
  return SyncEngine(
    store: store,
    transport: transport,
    appliers: [
      ProjectRecordApplier(repository: resolved),
      WritingGoalsApplier(repository: resolved),
      SeriesApplier(repository: resolved),
    ],
  );
}
