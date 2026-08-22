/// Relationship writes for the Story Graph.
///
/// Every method here is a **delegation to [ConnectionEngine]** and nothing
/// more. It deliberately adds no validation, no id scheme, no audit entry and
/// no storage of its own: a second relationship system does not get built on
/// purpose, it gets built by a helper that "just" re-checks one thing, and then
/// another, until two code paths disagree about what a valid edge is.
///
/// The guardrail in `test/story_graph_architecture_test.dart` pins this — a
/// mutation made through here must produce the same link and the same audit
/// trail as calling [ConnectionEngine] directly.
library;

import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'connection_engine.dart';
import 'record_service.dart';

class StoryGraphMutations {
  StoryGraphMutations({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  Future<ConnectionEngine> _engine() async => ConnectionEngine(
        scopeId: projectId,
        repository: repository,
        registry: await RecordService(
          projectId: projectId,
          repository: repository,
        ).connectionRegistry(),
      );

  /// Relates two nodes. Idempotent for a given
  /// (project, source, type, target) — [ConnectionEngine] derives the link id
  /// from that tuple, so connecting twice returns the existing link.
  Future<RecordLink> connect({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async =>
      (await _engine()).connect(
        sourceId: sourceId,
        targetId: targetId,
        typeId: typeId,
        label: label,
        direction: direction,
        metadata: metadata,
        timestamp: timestamp,
      );

  /// Retypes, relabels or re-metadata-s an existing link.
  Future<RecordLink> updateConnection(
    String linkId, {
    String? typeId,
    String? label,
    Map<String, Object?>? metadata,
    DateTime? timestamp,
  }) async =>
      (await _engine()).updateConnection(
        linkId,
        typeId: typeId,
        label: label,
        metadata: metadata,
        timestamp: timestamp,
      );

  /// Removes a link. Hard delete plus a `connectionRemoved` audit event —
  /// there is no soft-deleted edge state, and this does not invent one.
  Future<void> disconnect(String linkId, {DateTime? timestamp}) async =>
      (await _engine()).disconnect(linkId, timestamp: timestamp);
}
