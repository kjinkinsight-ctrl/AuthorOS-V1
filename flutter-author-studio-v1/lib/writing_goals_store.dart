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

/// Reads and writes one project's writing goals.
class WritingGoalsStore {
  const WritingGoalsStore({DriftConnectedDomainRepository? repository})
      : _repository = repository;

  final DriftConnectedDomainRepository? _repository;

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
    final normalized = goals.normalized();
    await repository.putWritingGoals(normalized);
    return normalized;
  }

  /// Drops the stored row so the project reverts to the seeded defaults.
  ///
  /// Deleting rather than writing the defaults back keeps [load] able to
  /// report the project as never customized.
  Future<WritingGoals> restoreDefaults(String projectId) async {
    await repository.deleteWritingGoalsForProject(projectId);
    return WritingGoals.defaultsFor(projectId);
  }
}
