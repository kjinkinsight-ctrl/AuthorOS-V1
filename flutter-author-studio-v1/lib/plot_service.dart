import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/plot_record_types.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/search_models.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';

class PlotRecordDraft {
  const PlotRecordDraft({
    required this.id,
    required this.typeId,
    required this.name,
    this.fields = const {},
    this.tags = const [],
    this.scopeType = RecordScopeType.project,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.canonStatus = CanonStatus.draft,
  });

  final String id;
  final String typeId;
  final String name;
  final Map<String, Object?> fields;
  final List<String> tags;
  final RecordScopeType scopeType;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
}

class PlotValidationIssue {
  const PlotValidationIssue({
    required this.code,
    required this.message,
    this.recordId,
    this.isError = false,
  });

  final String code;
  final String message;
  final String? recordId;
  final bool isError;
}

enum PlotViewKind {
  plotTree,
  beatBoard,
  arcLane,
  plotlineLane,
  characterArcLane,
  timelineOverlay,
  chapterMap,
  sceneMap,
  dependencyGraph,
}

class PlotViewItem {
  const PlotViewItem({
    required this.recordId,
    required this.typeId,
    required this.title,
    this.planningOrder,
    this.narrativeOrder,
    this.chronologicalOrder,
    this.connectionIds = const [],
  });

  final String recordId;
  final String typeId;
  final String title;
  final num? planningOrder;
  final num? narrativeOrder;
  final num? chronologicalOrder;
  final List<String> connectionIds;

  factory PlotViewItem.fromRecord(
    AuthorRecord record, {
    Iterable<RecordLink> connections = const [],
  }) =>
      PlotViewItem(
        recordId: record.id,
        typeId: record.typeId,
        title: record.title,
        planningOrder: record.fields['planningOrder'] as num?,
        narrativeOrder: record.fields['narrativeOrder'] as num?,
        chronologicalOrder: record.fields['chronologicalOrder'] as num?,
        connectionIds: connections.map((link) => link.id).toList(),
      );
}

class PlotService {
  const PlotService({required this.projectId, required this.repository});

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);
  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);
  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);
  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);
  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);
  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);
  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);
  PlotQueryService get query => PlotQueryService(this);

  Future<AuthorRecord> createPlotRecord(
    PlotRecordDraft draft, {
    Iterable<RecordLink> links = const [],
    DateTime? timestamp,
  }) async {
    final name = draft.name.trim();
    if (draft.id.trim().isEmpty || name.isEmpty) {
      throw ArgumentError('Plot record id and name are required.');
    }
    final definition = await _requirePlotType(draft.typeId);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final branchCreated = draft.scopeType == RecordScopeType.branch;
    if (branchCreated && draft.branchId == null) {
      throw StateError('Branch-created Plot records require a branch id.');
    }
    final record = AuthorRecord(
      id: draft.id,
      typeId: draft.typeId,
      templateId: draft.typeId,
      templateVersion: definition.templateVersion,
      scopeType: draft.scopeType,
      scopeId: branchCreated ? draft.branchId! : projectId,
      projectId: projectId,
      seriesId: draft.seriesId,
      bookId: draft.bookId,
      branchId: draft.branchId,
      canonStatus: draft.canonStatus,
      title: name,
      schemaVersion: definition.templateVersion,
      fields: {'name': name, ...draft.fields},
      tags: draft.tags,
      createdAt: now,
      updatedAt: now,
      extensionData: const {'plotStudio': true},
    );
    if (branchCreated) {
      await branches.createRecord(draft.branchId!, record, timestamp: now);
      return record;
    }
    return records.createRecord(record, links: links);
  }

  Future<AuthorRecord?> getPlotRecord(String id) async {
    final record = await records.getRecord(id);
    return record != null && await isPlotRecord(record) ? record : null;
  }

  Future<AuthorRecord> updatePlotRecord(
    AuthorRecord record, {
    AuditChangeType? changeType,
    String? summary,
  }) async {
    await _requirePlotRecord(record);
    return records.updateRecord(
      record,
      changeType: changeType,
      summary: summary,
    );
  }

  Future<AuthorRecord> archivePlotRecord(String id,
      {DateTime? timestamp}) async {
    await _requirePlotId(id);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> restorePlotRecord(String id,
      {DateTime? timestamp}) async {
    await _requirePlotId(id);
    return records.restoreRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> duplicatePlotRecord(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    await _requirePlotId(id);
    return records.duplicateRecord(
      id,
      newId: newId,
      title: title,
      timestamp: timestamp,
    );
  }

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) async {
    await _requirePlotId(id);
    return safeDelete.analyze(id);
  }

  Future<RecordLink> connect({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    final source = await repository.recordById(sourceId);
    final target = await repository.recordById(targetId);
    if (source == null || target == null) {
      throw StateError('Plot connections require stable Universal Record IDs.');
    }
    if ((source.projectId ?? source.scopeId) != projectId ||
        (target.projectId ?? target.scopeId) != projectId) {
      throw StateError('Plot connections cannot cross projects.');
    }
    if (!await isPlotRecord(source) && !await isPlotRecord(target)) {
      throw StateError(
          'At least one connection endpoint must be a Plot record.');
    }
    return connections.connect(
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      label: label,
      direction: direction,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<List<RecordLink>> connectionsFor(String id) async {
    await _requirePlotId(id);
    return connections.connections(id);
  }

  Future<List<SearchResult>> searchPlot(String queryText) async {
    final results = await search.searchAll(queryText);
    final registry = await records.registry();
    return results.where((result) {
      try {
        return registry.isTemplateCompatible(
          result.recordType,
          PlotRecordTypes.baseTypeId,
        );
      } on StateError {
        return false;
      }
    }).toList();
  }

  Future<UniversalRecordInspection?> inspectPlotRecord(
    String id, {
    String? branchId,
  }) async {
    final record = await _requirePlotId(id);
    return inspector.inspectRecord(
      id,
      recordType: record.typeId,
      branchId: branchId,
    );
  }

  Future<List<RecordVersion>> getPlotHistory(
    String id, {
    String? branchId,
  }) async {
    await _requirePlotId(id);
    return history.getVersionHistory(recordId: id, branchId: branchId);
  }

  Future<void> overrideInBranch(
    String branchId,
    String recordId, {
    String? title,
    Map<String, Object?> fields = const {},
    List<String> removedFieldIds = const [],
    List<String>? tags,
    CanonStatus? canonStatus,
    DateTime? timestamp,
  }) async {
    await _requirePlotId(recordId);
    return branches.overrideRecord(
      branchId,
      recordId,
      title: title,
      fields: fields,
      removedFieldIds: removedFieldIds,
      tags: tags,
      canonStatus: canonStatus,
      timestamp: timestamp,
    );
  }

  Future<void> hideInBranch(
    String branchId,
    String recordId, {
    DateTime? timestamp,
  }) async {
    await _requirePlotId(recordId);
    return branches.hideRecord(branchId, recordId, timestamp: timestamp);
  }

  Future<void> registerCustomType(RecordTypeDefinition definition) async {
    if (definition.baseTypeId != PlotRecordTypes.baseTypeId ||
        definition.scopeType != RecordScopeType.project ||
        definition.scopeId != projectId) {
      throw StateError(
        'Custom Plot types must extend plot-record in $projectId.',
      );
    }
    await repository.putRecordTypeDefinition(definition);
  }

  /// Concrete Plot types a writer can create, resolved so a derived type such
  /// as `subplot` carries the fields it inherits from `plotline`.
  ///
  /// Read from the registry rather than `PlotRecordTypes.definitions`, so a
  /// project type registered through [registerCustomType] is offered too. The
  /// abstract `plot-record` base is never offered.
  Future<List<RecordTypeDefinition>> plotTemplates() async {
    final registry = await records.registry();
    final resolved = <RecordTypeDefinition>[];
    for (final definition in registry.definitions) {
      if (definition.id == PlotRecordTypes.baseTypeId) continue;
      if (definition.extensionData['selectableForNewRecords'] == false) {
        continue;
      }
      if (definition.extensionData['archived'] == true) continue;
      try {
        if (!registry.isTemplateCompatible(
          definition.id,
          PlotRecordTypes.baseTypeId,
        )) {
          continue;
        }
        resolved.add(registry.resolve(definition.id));
      } on StateError {
        continue;
      }
    }
    return resolved..sort((left, right) => left.name.compareTo(right.name));
  }

  Future<List<PlotValidationIssue>> validatePlot() async {
    final issues = <PlotValidationIssue>[];
    final plotRecords = await query.all();
    final plotIds = plotRecords.map((record) => record.id).toSet();
    for (final record in plotRecords) {
      final shared = await records.validateRecord(record);
      issues.addAll(shared.issues.map((issue) => PlotValidationIssue(
            code: issue.code,
            message: issue.message,
            recordId: record.id,
            isError: issue.severity == RecordValidationSeverity.error,
          )));
      for (final dependencyId in _strings(record.fields['dependencies'])) {
        if (await repository.recordById(dependencyId) == null) {
          issues.add(PlotValidationIssue(
            code: 'broken-reference',
            message: '${record.title} depends on missing record $dependencyId.',
            recordId: record.id,
          ));
        }
      }
    }
    for (final beat in plotRecords.where(
        (record) => record.typeId == 'beat' || record.typeId == 'arc-beat')) {
      final links = await connections.connections(beat.id);
      if (!links.any((link) => plotIds.contains(
          link.sourceId == beat.id ? link.targetId : link.sourceId))) {
        issues.add(PlotValidationIssue(
          code: 'orphaned-beat',
          message: '${beat.title} is not connected to story structure.',
          recordId: beat.id,
        ));
      }
      if (!links.any((link) => link.typeId == 'fulfilledBy')) {
        issues.add(PlotValidationIssue(
          code: 'unfulfilled-beat',
          message: '${beat.title} has not been fulfilled by a scene.',
          recordId: beat.id,
        ));
      }
    }
    for (final plotline in await query.unresolvedPlotlines()) {
      issues.add(PlotValidationIssue(
        code: 'unresolved-plotline',
        message: '${plotline.title} has not been resolved.',
        recordId: plotline.id,
      ));
    }
    for (final arc in await query.unresolvedArcs()) {
      issues.add(PlotValidationIssue(
        code: 'unresolved-arc',
        message: '${arc.title} has not been resolved.',
        recordId: arc.id,
      ));
    }
    for (final setup in await query.unresolvedSetups()) {
      issues.add(PlotValidationIssue(
        code: 'missing-payoff',
        message: '${setup.title} does not have a payoff.',
        recordId: setup.id,
      ));
    }
    for (final reveal in await query.pendingReveals()) {
      issues.add(PlotValidationIssue(
        code: 'unresolved-reveal',
        message: '${reveal.title} is still pending.',
        recordId: reveal.id,
      ));
    }
    for (final payoff in await query.byType('payoff')) {
      final links = await connections.connections(payoff.id);
      final setupId = payoff.fields['setup'];
      if ((setupId is! String || setupId.trim().isEmpty) &&
          !links.any((link) => link.typeId == 'paidOffBy')) {
        issues.add(PlotValidationIssue(
          code: 'missing-setup',
          message: '${payoff.title} does not identify its setup.',
          recordId: payoff.id,
        ));
      }
    }
    for (final scene in await repository.recordsByTypeAndScope(
      typeId: 'scene',
      scopeId: projectId,
    )) {
      final links = await connections.connections(scene.id);
      if (!links.any((link) =>
          link.typeId == 'plannedFor' ||
          link.typeId == 'fulfilledBy' ||
          link.typeId == 'appearsIn' ||
          link.typeId == 'resolvesIn')) {
        issues.add(PlotValidationIssue(
          code: 'orphaned-scene',
          message: '${scene.title} is not connected to Plot structure.',
          recordId: scene.id,
        ));
      }
    }
    final narrativePositions = <num, AuthorRecord>{};
    for (final beat in plotRecords.where(
        (record) => record.typeId == 'beat' || record.typeId == 'arc-beat')) {
      final position = beat.fields['narrativeOrder'];
      if (position is! num) continue;
      final existing = narrativePositions[position];
      if (existing != null) {
        issues.add(PlotValidationIssue(
          code: 'duplicate-narrative-position',
          message:
              '${existing.title} and ${beat.title} share narrative position $position.',
          recordId: beat.id,
        ));
      } else {
        narrativePositions[position] = beat;
      }
    }
    if ((await query.byType('climax')).isEmpty) {
      issues.add(const PlotValidationIssue(
        code: 'missing-climax',
        message: 'The current Plot has no climax record.',
      ));
    }
    if ((await query.byType('resolution')).isEmpty) {
      issues.add(const PlotValidationIssue(
        code: 'missing-resolution',
        message: 'The current Plot has no resolution record.',
      ));
    }
    issues.addAll(await _dependencyCycleWarnings(plotRecords));
    return issues;
  }

  Future<List<PlotValidationIssue>> _dependencyCycleWarnings(
    List<AuthorRecord> records,
  ) async {
    final ids = records.map((record) => record.id).toSet();
    final graph = <String, Set<String>>{};
    for (final record in records) {
      graph[record.id] = {
        ..._strings(record.fields['dependencies']).where(ids.contains),
        ...(await connections.outgoing(record.id))
            .where((link) => link.typeId == 'dependsOn')
            .map((link) => link.targetId)
            .where(ids.contains),
      };
    }
    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String id) {
      if (visiting.contains(id)) return true;
      if (!visited.add(id)) return false;
      visiting.add(id);
      for (final next in graph[id] ?? const <String>{}) {
        if (visit(next)) return true;
      }
      visiting.remove(id);
      return false;
    }

    return graph.keys.any(visit)
        ? const [
            PlotValidationIssue(
              code: 'circular-dependency',
              message: 'Plot dependencies contain a cycle.',
            ),
          ]
        : const [];
  }

  Future<bool> isPlotRecord(AuthorRecord record) async {
    if ((record.projectId ?? record.scopeId) != projectId) return false;
    final registry = await records.registry();
    return registry.isTemplateCompatible(
      record.typeId,
      PlotRecordTypes.baseTypeId,
    );
  }

  Future<RecordTypeDefinition> _requirePlotType(String typeId) async {
    final registry = await records.registry();
    if (!registry.isTemplateCompatible(typeId, PlotRecordTypes.baseTypeId)) {
      throw StateError('$typeId is not a Plot record type.');
    }
    return registry.resolve(typeId);
  }

  Future<AuthorRecord> _requirePlotId(String id) async {
    final record = await getPlotRecord(id);
    if (record == null) {
      throw StateError('$id is not a Plot record in $projectId.');
    }
    return record;
  }

  Future<void> _requirePlotRecord(AuthorRecord record) async {
    if (!await isPlotRecord(record)) {
      throw StateError('${record.id} is not a Plot record in $projectId.');
    }
  }
}

class PlotQueryService {
  const PlotQueryService(this.plot);

  final PlotService plot;

  Future<List<AuthorRecord>> byType(String typeId) =>
      plot.repository.recordsByTypeAndScope(
        typeId: typeId,
        scopeId: plot.projectId,
      );

  Future<List<AuthorRecord>> all() async {
    final registry = await plot.records.registry();
    final typeIds = registry.definitions
        .where((definition) => registry.isTemplateCompatible(
              definition.id,
              PlotRecordTypes.baseTypeId,
            ))
        .map((definition) => definition.id);
    final result = <AuthorRecord>[];
    for (final typeId in typeIds) {
      result.addAll(await byType(typeId));
    }
    return result..sort(_byTitle);
  }

  Future<List<AuthorRecord>> beatsByBook(String bookId) =>
      _beatsWhere((record) => record.bookId == bookId);

  Future<List<AuthorRecord>> beatsByChapter(String chapterId) =>
      _linkedBeats(chapterId);

  Future<List<AuthorRecord>> beatsByScene(String sceneId) =>
      _linkedBeats(sceneId);

  Future<List<AuthorRecord>> beatsByPlotline(String plotlineId) =>
      _linkedBeats(plotlineId);

  Future<List<AuthorRecord>> beatsByArc(String arcId) => _linkedBeats(arcId);

  Future<List<AuthorRecord>> beatsByCharacter(String characterId) =>
      _linkedBeats(characterId);

  Future<List<AuthorRecord>> unresolvedPlotlines() async => [
        ...await byType('plotline'),
        ...await byType('subplot'),
      ].where(_isUnresolved).toList();

  Future<List<AuthorRecord>> unresolvedArcs() async {
    final result = <AuthorRecord>[];
    for (final typeId in const [
      'arc',
      'character-arc',
      'relationship-arc',
      'world-arc',
      'political-arc',
      'romance-arc',
      'mystery-arc',
    ]) {
      result.addAll((await byType(typeId)).where(_isUnresolved));
    }
    return result;
  }

  Future<List<AuthorRecord>> unresolvedSetups() async {
    final setups = await byType('foreshadowing');
    final result = <AuthorRecord>[];
    for (final setup in setups) {
      final links = await plot.connections.outgoing(setup.id);
      if (!links.any(
          (link) => link.typeId == 'paidOffBy' || link.typeId == 'leadsTo')) {
        result.add(setup);
      }
    }
    return result;
  }

  Future<List<AuthorRecord>> missingPayoffs() => unresolvedSetups();

  Future<List<AuthorRecord>> pendingReveals() async =>
      (await byType('reveal')).where(_isUnresolved).toList();

  Future<List<AuthorRecord>> activeConflicts() async =>
      (await byType('conflict')).where(_isActive).toList();

  Future<List<AuthorRecord>> activeGoals() async =>
      (await byType('goal')).where(_isActive).toList();

  Future<List<AuthorRecord>> completedGoals() async =>
      (await byType('goal')).where(_isResolved).toList();

  Future<List<AuthorRecord>> characterArcProgression(String characterId) =>
      _linkedRecordsOfTypes(characterId, const {'character-arc', 'arc-beat'});

  Future<List<AuthorRecord>> worldArcProgression(String worldRecordId) =>
      _linkedRecordsOfTypes(worldRecordId, const {'world-arc', 'arc-beat'});

  Future<List<AuthorRecord>> branchSpecific(String branchId) async {
    final records = await plot.branches.recordsForBranch(branchId);
    final result = <AuthorRecord>[];
    for (final record in records) {
      if (await plot.isPlotRecord(record)) result.add(record);
    }
    return result..sort(_byTitle);
  }

  Future<List<AuthorRecord>> canonOnly() async => (await all())
      .where((record) => record.canonStatus == CanonStatus.canon)
      .toList();

  Future<List<AuthorRecord>> timelineLinked() async {
    final result = <AuthorRecord>[];
    for (final record in await all()) {
      final links = await plot.connections.connections(record.id);
      for (final link in links) {
        final otherId =
            link.sourceId == record.id ? link.targetId : link.sourceId;
        final other = await plot.repository.recordById(otherId);
        if (other != null &&
            (other.typeId.startsWith('timeline-') ||
                other.typeId == 'historical-event')) {
          result.add(record);
          break;
        }
      }
    }
    return result;
  }

  Future<List<PlotViewItem>> viewItems() async {
    final result = <PlotViewItem>[];
    for (final record in await all()) {
      result.add(PlotViewItem.fromRecord(
        record,
        connections: await plot.connections.connections(record.id),
      ));
    }
    return result;
  }

  Future<List<AuthorRecord>> _beatsWhere(
    bool Function(AuthorRecord record) predicate,
  ) async =>
      [...await byType('beat'), ...await byType('arc-beat')]
          .where(predicate)
          .toList();

  Future<List<AuthorRecord>> _linkedBeats(String targetId) =>
      _linkedRecordsOfTypes(targetId, const {'beat', 'arc-beat'});

  Future<List<AuthorRecord>> _linkedRecordsOfTypes(
    String targetId,
    Set<String> typeIds,
  ) async {
    final links = await plot.connections.connections(targetId);
    final result = <String, AuthorRecord>{};
    for (final link in links) {
      final id = link.sourceId == targetId ? link.targetId : link.sourceId;
      final record = await plot.repository.recordById(id);
      if (record != null &&
          typeIds.contains(record.typeId) &&
          (record.projectId ?? record.scopeId) == plot.projectId) {
        result[record.id] = record;
      }
    }
    return result.values.toList()..sort(_byTitle);
  }
}

bool _isUnresolved(AuthorRecord record) => !_isResolved(record);

bool _isResolved(AuthorRecord record) {
  final status = '${record.fields['plotStatus'] ?? ''}'.toLowerCase();
  return status == 'resolved' || status == 'completed';
}

bool _isActive(AuthorRecord record) {
  final status = '${record.fields['plotStatus'] ?? ''}'.toLowerCase();
  return record.status == AuthorRecordStatus.active &&
      status != 'resolved' &&
      status != 'completed' &&
      status != 'abandoned';
}

List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

int _byTitle(AuthorRecord left, AuthorRecord right) =>
    left.title.toLowerCase().compareTo(right.title.toLowerCase());
