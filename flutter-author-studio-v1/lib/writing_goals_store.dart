/// Writing goals — the storage layer.
///
/// Mirrors [ManuscriptStore]: it owns no goal arithmetic and no screen, it
/// only moves [WritingGoals] between the canonical repository and its callers.
///
/// It exists for two reasons:
///
/// * The Analytics Studio must stay a derivation layer. It reads goals through
///   this store and never writes them, so "analytics derives, it does not
///   persist" survives the addition of an editable setting.
/// * The one rule that matters — a project with no stored row has the seeded
///   defaults — needs exactly one implementation, not one per caller.
library;

import 'core/writing_goals.dart';
import 'persistence/authoros_database.dart';
import 'sync/sync_appliers.dart';

/// Reads and writes one project's writing goals.
class WritingGoalsStore {
  const WritingGoalsStore({
    DriftConnectedDomainRepository? repository,
    this.recorder = const SyncRecorder(),
  }) : _repository = repository;

  final DriftConnectedDomainRepository? _repository;

  /// Queues goal changes for other devices. Write path only: [load] must never
  /// reach it, or reading a dashboard would start writing.
  final SyncRecorder recorder;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The project's goals, seeded with the defaults when none were stored.
  ///
  /// Reading never writes: a project that has never had its goals edited
  /// stays that way, so the difference between the seeded defaults and the
  /// author having chosen those same numbers is never lost.
  Future<WritingGoals> load(String projectId) async =>
      await repository.writingGoalsForProject(projectId) ??
      WritingGoals.defaultsFor(projectId);

  /// Normalizes and stores the author's goals, returning exactly what was
  /// stored so no caller renders a target the database did not accept.
  Future<WritingGoals> save(WritingGoals goals) async {
    // Stamped here rather than left to the persistence layer, which would
    // stamp its own instant on the way in. The row and the payload queued for
    // other devices have to be the same fact, and the only way to be sure is
    // to decide the instant once, before either.
    final normalized = goals.normalized().copyWith(updatedAt: DateTime.now());
    await repository.putWritingGoals(normalized);
    await recorder.recordUpsert(
      recordType: SyncRecordTypes.writingGoals,
      recordId: normalized.projectId,
      payload: Map<String, dynamic>.from(normalized.toJson()),
    );
    await recorder.flush();
    return normalized;
  }

  /// Drops the stored row so the project reverts to the seeded defaults.
  ///
  /// Deleting rather than writing the defaults back keeps [load] able to
  /// report the project as never customized.
  Future<WritingGoals> restoreDefaults(String projectId) async {
    await repository.deleteWritingGoalsForProject(projectId);
    // A tombstone, not a push of the default values: another device must end
    // up with no row at all, or it would read as "customized to exactly the
    // defaults" rather than "never customized".
    await recorder.recordDelete(
      recordType: SyncRecordTypes.writingGoals,
      recordId: projectId,
    );
    await recorder.flush();
    return WritingGoals.defaultsFor(projectId);
  }
}
