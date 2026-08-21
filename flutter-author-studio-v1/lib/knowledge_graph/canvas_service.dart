/// Reads and writes a Knowledge Canvas.
///
/// This is the **only** write path in the Knowledge Graph besides
/// `StoryGraphMutations`, and like that one it delegates: every write goes
/// through [RecordService], so a canvas is validated, versioned, audited,
/// archived and exported exactly like any other record. It owns no table and
/// no store of its own.
///
/// A canvas holds **positions and entity ids only, never edges.** Relationships
/// are always read live, so an arrangement cannot drift out of step with what
/// the story actually says, and invariant I-13 — one edge table, ever — is
/// never at risk from a stale board.
library;

import 'dart:convert';

import 'package:flutter/painting.dart' show Offset;

import '../core/connected_domain.dart';
import '../core/knowledge_graph_record_types.dart';
import '../core/record_scope.dart';
import '../core/record_service.dart';
import '../core/story_graph.dart';
import '../persistence/authoros_database.dart';

/// One saved arrangement.
class KnowledgeCanvas {
  const KnowledgeCanvas({
    required this.modeId,
    required this.positions,
    this.rootId,
    this.filter,
  });

  final String modeId;
  final Map<String, Offset> positions;
  final String? rootId;
  final StoryGraphFilter? filter;

  bool get isEmpty => positions.isEmpty;
}

class KnowledgeCanvasService {
  KnowledgeCanvasService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get _records =>
      RecordService(projectId: projectId, repository: repository);

  /// The saved arrangement for [modeId], or null if the author has not made
  /// one. A null result means "lay it out for me", not "an empty board".
  Future<KnowledgeCanvas?> load(String modeId) async {
    final record = await _records.getRecord(
      KnowledgeGraphRecordTypes.canvasId(projectId, modeId),
    );
    if (record == null || record.status == AuthorRecordStatus.deleted) {
      return null;
    }

    final raw = record.fields[KnowledgeGraphRecordTypes.nodesFieldId];
    final positions = <String, Offset>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final id = entry['entityId'];
        final x = entry['x'];
        final y = entry['y'];
        if (id is! String || x is! num || y is! num) continue;
        positions[id] = Offset(x.toDouble(), y.toDouble());
      }
    }
    if (positions.isEmpty) return null;

    return KnowledgeCanvas(
      modeId: modeId,
      positions: positions,
      rootId: record.fields[KnowledgeGraphRecordTypes.rootFieldId] as String?,
      filter: _decodeFilter(
        record.fields[KnowledgeGraphRecordTypes.filterFieldId],
      ),
    );
  }

  /// Saves [positions] for [modeId], creating the canvas record on first use.
  ///
  /// One canvas per (project, mode), on a deterministic id — so switching mode
  /// and back returns the arrangement the author left, and nothing accumulates
  /// untitled boards behind them.
  Future<void> save(
    String modeId, {
    required Map<String, Offset> positions,
    String? rootId,
    StoryGraphFilter? filter,
    DateTime? timestamp,
  }) async {
    final id = KnowledgeGraphRecordTypes.canvasId(projectId, modeId);
    final now = timestamp ?? DateTime.now().toUtc();
    final fields = <String, Object?>{
      KnowledgeGraphRecordTypes.modeFieldId: modeId,
      KnowledgeGraphRecordTypes.rootFieldId: rootId,
      KnowledgeGraphRecordTypes.nodesFieldId: [
        for (final entry in positions.entries)
          {'entityId': entry.key, 'x': entry.value.dx, 'y': entry.value.dy},
      ],
      if (filter != null)
        KnowledgeGraphRecordTypes.filterFieldId: jsonEncode(filter.toJson()),
    };

    final existing = await _records.getRecord(id);
    if (existing == null) {
      await _records.createRecord(
        AuthorRecord(
          id: id,
          typeId: KnowledgeGraphRecordTypes.canvasTypeId,
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          title: 'Knowledge Canvas — $modeId',
          fields: fields,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    await _records.updateRecord(
      existing.copyWith(fields: fields, updatedAt: now),
    );
  }

  /// Forgets the arrangement, so the mode returns to its generated layout.
  ///
  /// Soft-deletes rather than erasing: an author who clears a board they spent
  /// time on should be able to get it back out of history.
  Future<void> clear(String modeId, {DateTime? timestamp}) async {
    final id = KnowledgeGraphRecordTypes.canvasId(projectId, modeId);
    if (await _records.getRecord(id) == null) return;
    await _records.deleteRecord(id, timestamp: timestamp);
  }

  StoryGraphFilter? _decodeFilter(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return StoryGraphFilter.fromJson(decoded);
    } on FormatException {
      // A filter that will not decode is not worth failing a canvas load over;
      // the arrangement is the part the author cares about.
      return null;
    }
  }
}
