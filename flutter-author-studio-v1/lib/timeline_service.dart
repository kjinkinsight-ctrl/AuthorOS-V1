import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/search_models.dart';
import 'core/timeline_record_types.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';
import 'timeline_domain.dart';

class TimelineEventDraft {
  const TimelineEventDraft({
    required this.id,
    required this.name,
    this.typeId = TimelineRecordTypes.eventTypeId,
    this.summary = '',
    this.description = '',
    this.start,
    this.end,
    this.relativeDate,
    this.dateRepresentations = const [],
    this.narrativeTime = const {},
    this.duration = const {},
    this.status = 'draft',
    this.importance = 'normal',
    this.scope = 'project',
    this.notes = '',
    this.tags = const [],
    this.fields = const {},
    this.seriesId,
    this.bookId,
    this.branchId,
    this.canonStatus = CanonStatus.draft,
  });

  final String id;
  final String name;
  final String typeId;
  final String summary;
  final String description;
  final TimelineDate? start;
  final TimelineDate? end;
  final RelativeTimelineDate? relativeDate;
  final List<TimelineDate> dateRepresentations;
  final Map<String, Object?> narrativeTime;
  final Map<String, Object?> duration;
  final String status;
  final String importance;
  final String scope;
  final String notes;
  final List<String> tags;
  final Map<String, Object?> fields;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
}

class TimelineService {
  const TimelineService({required this.projectId, required this.repository});

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
  TimelineQueryService get query => TimelineQueryService(this);

  Future<AuthorRecord> createCalendar(
    TimelineCalendar calendar, {
    bool primary = false,
    DateTime? timestamp,
  }) async {
    if (calendar.id.trim().isEmpty || calendar.name.trim().isEmpty) {
      throw ArgumentError('Calendar id and name are required.');
    }
    if (calendar.months.isEmpty ||
        calendar.months.any((month) => month.length <= 0)) {
      throw ArgumentError('A calendar requires positive-length months.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    return records.createRecord(AuthorRecord(
      id: calendar.id,
      typeId: TimelineRecordTypes.calendarTypeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      canonStatus: CanonStatus.canon,
      title: calendar.name.trim(),
      schemaVersion: 1,
      fields: {'name': calendar.name.trim(), ...calendar.toFields()},
      createdAt: now,
      updatedAt: now,
      extensionData: {
        'timelineStudio': true,
        'primaryCalendar': primary,
      },
    ));
  }

  Future<AuthorRecord> createEvent(
    TimelineEventDraft draft, {
    Iterable<RecordLink> links = const [],
    DateTime? timestamp,
  }) async {
    final name = draft.name.trim();
    if (draft.id.trim().isEmpty || name.isEmpty) {
      throw ArgumentError('Event id and name are required.');
    }
    await _requireTimelineType(draft.typeId);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = AuthorRecord(
      id: draft.id,
      typeId: draft.typeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      seriesId: draft.seriesId,
      bookId: draft.bookId,
      branchId: draft.branchId,
      canonStatus: draft.canonStatus,
      title: name,
      schemaVersion: 1,
      fields: _eventFields(draft, name),
      tags: draft.tags,
      createdAt: now,
      updatedAt: now,
      extensionData: const {'timelineStudio': true},
    );
    final issues = await validateTemporal(record);
    if (issues.any((issue) => issue.isError)) {
      throw TimelineValidationException(issues);
    }
    return records.createRecord(record, links: links);
  }

  /// Rewrites the canonical temporal fields of an existing Timeline record.
  ///
  /// The draft owns the same field shaping as [createEvent], so an event edited
  /// in Timeline Studio keeps the identical Universal Record layout it was
  /// created with. Identity, scope and ownership stay on the stored record.
  Future<AuthorRecord> updateEvent(
    TimelineEventDraft draft, {
    AuditChangeType? changeType,
    String? summary,
    DateTime? timestamp,
  }) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Event name is required.');
    }
    final existing = await _requireTimelineId(draft.id);
    if (draft.typeId != existing.typeId) {
      // The shared record service forbids type changes on update; surface the
      // rule here with Timeline wording instead of failing deeper down.
      throw ArgumentError(
        'A timeline record keeps its type; duplicate it to change type.',
      );
    }
    final updated = AuthorRecord(
      id: existing.id,
      typeId: existing.typeId,
      scopeType: existing.scopeType,
      scopeId: existing.scopeId,
      projectId: existing.projectId,
      seriesId: draft.seriesId ?? existing.seriesId,
      bookId: draft.bookId ?? existing.bookId,
      branchId: draft.branchId ?? existing.branchId,
      canonStatus: draft.canonStatus,
      title: name,
      status: existing.status,
      schemaVersion: existing.schemaVersion,
      templateId: existing.templateId,
      templateVersion: existing.templateVersion,
      revision: existing.revision,
      fields: _eventFields(draft, name),
      tags: draft.tags,
      createdAt: existing.createdAt,
      updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      extensionData: existing.extensionData,
    );
    return updateTimelineRecord(
      updated,
      changeType: changeType,
      summary: summary,
    );
  }

  Future<AuthorRecord?> getTimelineRecord(String id) async {
    final record = await records.getRecord(id);
    return record != null && await isTimelineRecord(record) ? record : null;
  }

  Future<AuthorRecord> updateTimelineRecord(
    AuthorRecord record, {
    AuditChangeType? changeType,
    String? summary,
  }) async {
    await _requireTimelineRecord(record);
    final issues = await validateTemporal(record);
    if (issues.any((issue) => issue.isError)) {
      throw TimelineValidationException(issues);
    }
    return records.updateRecord(
      record,
      changeType: changeType,
      summary: summary,
    );
  }

  Future<AuthorRecord> archiveTimelineRecord(String id,
      {DateTime? timestamp}) async {
    await _requireTimelineId(id);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> restoreTimelineRecord(String id,
      {DateTime? timestamp}) async {
    await _requireTimelineId(id);
    return records.restoreRecord(id, timestamp: timestamp);
  }

  /// Soft-deletes a Timeline record through the shared record lifecycle.
  ///
  /// This is the same reversible `deleted` state every other Studio uses. Links,
  /// versions and audit entries stay intact so [analyzeDelete] and the version
  /// history keep working after the record leaves the Studio.
  Future<AuthorRecord> deleteTimelineRecord(String id,
      {DateTime? timestamp}) async {
    await _requireTimelineId(id);
    return records.deleteRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> duplicateTimelineRecord(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    await _requireTimelineId(id);
    return records.duplicateRecord(
      id,
      newId: newId,
      title: title,
      timestamp: timestamp,
    );
  }

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) async {
    await _requireTimelineId(id);
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
      throw StateError('Timeline connections require stable record IDs.');
    }
    if ((source.projectId ?? source.scopeId) != projectId ||
        (target.projectId ?? target.scopeId) != projectId) {
      throw StateError('Timeline connections cannot cross projects.');
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
    await _requireTimelineId(id);
    return connections.connections(id);
  }

  Future<List<SearchResult>> searchTimeline(String queryText) async {
    final results = await search.searchAll(queryText);
    final registry = await records.registry();
    return results.where((result) {
      try {
        return registry.isTemplateCompatible(
          result.recordType,
          TimelineRecordTypes.baseTypeId,
        );
      } on StateError {
        return false;
      }
    }).toList();
  }

  Future<UniversalRecordInspection?> inspectTimelineRecord(
    String id, {
    String? branchId,
  }) async {
    final record = await _requireTimelineId(id);
    return inspector.inspectRecord(
      id,
      recordType: record.typeId,
      branchId: branchId,
    );
  }

  Future<List<RecordVersion>> getTimelineHistory(
    String id, {
    String? branchId,
  }) async {
    await _requireTimelineId(id);
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
    await _requireTimelineId(recordId);
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

  Future<void> registerCustomType(RecordTypeDefinition definition) async {
    if (definition.baseTypeId != TimelineRecordTypes.baseTypeId ||
        definition.scopeType != RecordScopeType.project ||
        definition.scopeId != projectId) {
      throw StateError(
        'Custom timeline types must extend timeline-record in $projectId.',
      );
    }
    await repository.putRecordTypeDefinition(definition);
  }

  Future<List<TimelineValidationIssue>> validateTemporal(
    AuthorRecord record,
  ) async {
    final issues = <TimelineValidationIssue>[];
    if ((record.projectId ?? record.scopeId) != projectId) {
      issues.add(const TimelineValidationIssue(
        code: 'cross-project',
        message: 'Timeline record belongs to another project.',
      ));
      return issues;
    }
    final shared = await records.validateRecord(record);
    issues.addAll(shared.issues.map((issue) => TimelineValidationIssue(
          code: issue.code,
          message: issue.message,
          isError: issue.severity == RecordValidationSeverity.error,
        )));
    final start = _dateFrom(record.fields['start']);
    final end = _dateFrom(record.fields['end']);
    if (start != null) issues.addAll(await _validateDate(start));
    if (end != null) issues.addAll(await _validateDate(end));
    for (final representation in _objectList(
      record.fields['dateRepresentations'],
    ).map(TimelineDate.fromJson)) {
      issues.addAll(await _validateDate(representation));
    }
    if (start != null && end != null && start.calendarId == end.calendarId) {
      final calendar = await getCalendar(start.calendarId);
      if (calendar != null &&
          start.isDated &&
          end.isDated &&
          calendar.ordinal(end) < calendar.ordinal(start)) {
        issues.add(const TimelineValidationIssue(
          code: 'end-before-start',
          message: 'Event end cannot precede its start.',
        ));
      }
    }
    final relative = _firstObject(record.fields['relativeDate']);
    final anchorId = relative?['anchorRecordId'] as String?;
    if (anchorId != null && await getTimelineRecord(anchorId) == null) {
      issues.add(TimelineValidationIssue(
        code: 'broken-relative-anchor',
        message: 'Relative date anchor $anchorId does not exist.',
      ));
    }
    return issues;
  }

  Future<List<TimelineValidationIssue>> validateDependencyCycles() async {
    final timelineRecords = await query.all();
    final ids = timelineRecords.map((record) => record.id).toSet();
    final snapshot = await repository.snapshot();
    final graph = <String, Set<String>>{};
    for (final link in snapshot.links.where((link) =>
        ids.contains(link.sourceId) &&
        ids.contains(link.targetId) &&
        const {'before', 'precedes', 'causedBy'}.contains(link.typeId))) {
      graph.putIfAbsent(link.sourceId, () => <String>{}).add(link.targetId);
    }
    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String id) {
      if (visiting.contains(id)) return true;
      if (!visited.add(id)) return false;
      visiting.add(id);
      for (final target in graph[id] ?? const <String>{}) {
        if (visit(target)) return true;
      }
      visiting.remove(id);
      return false;
    }

    return ids.any(visit)
        ? const [
            TimelineValidationIssue(
              code: 'circular-temporal-dependency',
              message: 'Timeline contains a circular temporal dependency.',
            ),
          ]
        : const [];
  }

  Future<TimelineCalendar?> getCalendar(String id) async {
    final record = await records.getRecord(id);
    if (record?.typeId != TimelineRecordTypes.calendarTypeId) return null;
    return _calendarFrom(record!);
  }

  /// Every calendar definition this project owns, name-ordered.
  ///
  /// Calendars are ordinary project-scoped Universal Records, so the Studio
  /// reads them through the same repository as everything else.
  Future<List<TimelineCalendar>> calendars() async {
    final records = await repository.recordsByProject(projectId);
    final calendars = [
      for (final record in records)
        if (record.typeId == TimelineRecordTypes.calendarTypeId &&
            record.status == AuthorRecordStatus.active)
          _calendarFrom(record),
    ];
    calendars.sort((left, right) => left.name.compareTo(right.name));
    return calendars;
  }

  /// The calendar flagged primary when it was created, else the first one.
  Future<TimelineCalendar?> primaryCalendar() async {
    final records = await repository.recordsByProject(projectId);
    final calendarRecords = records
        .where((record) =>
            record.typeId == TimelineRecordTypes.calendarTypeId &&
            record.status == AuthorRecordStatus.active)
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));
    if (calendarRecords.isEmpty) return null;
    final primary = calendarRecords.firstWhere(
      (record) => record.extensionData['primaryCalendar'] == true,
      orElse: () => calendarRecords.first,
    );
    return _calendarFrom(primary);
  }

  TimelineCalendar _calendarFrom(AuthorRecord record) => TimelineCalendar(
        id: record.id,
        name: record.title,
        months: _objectList(record.fields['months'])
            .map((month) => TimelineCalendarMonth(
                  name: month['name'] as String? ?? '',
                  length: month['length'] as int? ?? 0,
                ))
            .toList(),
        weekDays: _strings(record.fields['weekStructure']),
        eraNames: _strings(record.fields['eraNames']),
        epoch: _firstObject(record.fields['epoch']) ?? const {},
        dateFormat:
            record.fields['dateFormat'] as String? ?? '{year}-{month}-{day}',
        hasYearZero: record.fields['hasYearZero'] as bool? ?? true,
        yearsCountBackward: record.fields['yearDirection'] == 'backward',
        conversionMetadata:
            _firstObject(record.fields['conversionMetadata']) ?? const {},
      );

  Map<String, Object?> _eventFields(TimelineEventDraft draft, String name) => {
        'name': name,
        'eventType': draft.typeId,
        'summary': draft.summary,
        'description': draft.description,
        'start': [if (draft.start != null) draft.start!.toJson()],
        'end': [if (draft.end != null) draft.end!.toJson()],
        'duration': [if (draft.duration.isNotEmpty) draft.duration],
        'precision': (draft.start?.precision ?? TimelinePrecision.unknown).name,
        'temporalStatus': draft.status,
        'importance': draft.importance,
        'temporalScope': draft.scope,
        'notes': draft.notes,
        'dateRepresentations': [
          ...draft.dateRepresentations.map((date) => date.toJson()),
        ],
        'relativeDate': [
          if (draft.relativeDate != null) draft.relativeDate!.toJson(),
        ],
        'narrativeTime': [
          if (draft.narrativeTime.isNotEmpty) draft.narrativeTime,
        ],
        ...draft.fields,
      };

  Future<int?> ageAt({
    required String birthEventId,
    required String eventId,
  }) async {
    final birth = await _requireTimelineId(birthEventId);
    final event = await _requireTimelineId(eventId);
    final birthDate = _dateFrom(birth.fields['start']);
    final eventDate = _dateFrom(event.fields['start']);
    if (birthDate == null ||
        eventDate == null ||
        !birthDate.isDated ||
        !eventDate.isDated ||
        birthDate.calendarId != eventDate.calendarId) {
      return null;
    }
    final calendar = await getCalendar(birthDate.calendarId);
    if (calendar == null) return null;
    return (calendar.ordinal(eventDate) - calendar.ordinal(birthDate)) ~/
        calendar.yearLength;
  }

  Future<bool> isTimelineRecord(AuthorRecord record) async {
    if (record.typeId == TimelineRecordTypes.calendarTypeId) return false;
    try {
      return (await records.registry()).isTemplateCompatible(
        record.typeId,
        TimelineRecordTypes.baseTypeId,
      );
    } on StateError {
      return false;
    }
  }

  Future<List<TimelineValidationIssue>> _validateDate(
    TimelineDate date,
  ) async {
    final calendar = await getCalendar(date.calendarId);
    if (calendar == null) {
      return [
        TimelineValidationIssue(
          code: 'invalid-calendar',
          message: 'Calendar ${date.calendarId} does not exist.',
        ),
      ];
    }
    try {
      calendar.validate(date);
      return const [];
    } on ArgumentError catch (error) {
      return [
        TimelineValidationIssue(
          code: 'invalid-date',
          message: error.message?.toString() ?? 'Invalid date.',
        ),
      ];
    }
  }

  Future<void> _requireTimelineType(String typeId) async {
    final registry = await records.registry();
    if (!registry.isTemplateCompatible(
      typeId,
      TimelineRecordTypes.baseTypeId,
    )) {
      throw StateError('$typeId is not a Timeline record type.');
    }
  }

  Future<AuthorRecord> _requireTimelineId(String id) async {
    final record = await getTimelineRecord(id);
    if (record == null) {
      throw StateError('$id is not a Timeline record in $projectId.');
    }
    return record;
  }

  Future<void> _requireTimelineRecord(AuthorRecord record) async {
    if (!await isTimelineRecord(record) ||
        (record.projectId ?? record.scopeId) != projectId) {
      throw StateError('${record.id} is not a Timeline record in $projectId.');
    }
  }
}

class TimelineQueryService {
  const TimelineQueryService(this.timeline);

  final TimelineService timeline;

  Future<List<AuthorRecord>> all({
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus? canonStatus,
    String? tag,
    String? typeId,
    AuthorRecordStatus? status,
  }) async {
    final source = branchId == null
        ? await timeline.repository.recordsByProject(timeline.projectId)
        : await timeline.branches.recordsForBranch(branchId);
    final output = <AuthorRecord>[];
    for (final record in source) {
      if (!await timeline.isTimelineRecord(record)) continue;
      if (seriesId != null && record.seriesId != seriesId) continue;
      if (bookId != null && record.bookId != bookId) continue;
      if (canonStatus != null && record.canonStatus != canonStatus) continue;
      if (tag != null && !record.tags.contains(tag)) continue;
      if (typeId != null && record.typeId != typeId) continue;
      if (status != null && record.status != status) continue;
      output.add(record);
    }
    output.sort((left, right) => left.title.compareTo(right.title));
    return output;
  }

  /// Timeline records ordered by the calendar their start date belongs to.
  ///
  /// Dated records sort by calendar ordinal. Records whose start date is
  /// missing, undated or written in an unknown calendar keep their stable
  /// alphabetical order and follow the dated ones, because the service never
  /// invents a date it was not given.
  ///
  /// Ordinals from different calendars are not comparable without conversion
  /// metadata, so records group by calendar id first and sort by ordinal
  /// inside that group. A project on one calendar therefore reads as a single
  /// chronological run.
  Future<List<AuthorRecord>> chronological({
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus? canonStatus,
    String? tag,
    String? typeId,
    AuthorRecordStatus? status,
    bool descending = false,
  }) async {
    final records = await all(
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      tag: tag,
      typeId: typeId,
      status: status,
    );
    final calendars = <String, TimelineCalendar?>{};
    final ordinals = <String, int>{};
    final calendarIds = <String, String>{};
    for (final record in records) {
      final date = _dateFrom(record.fields['start']);
      if (date == null || !date.isDated) continue;
      if (!calendars.containsKey(date.calendarId)) {
        calendars[date.calendarId] =
            await timeline.getCalendar(date.calendarId);
      }
      final calendar = calendars[date.calendarId];
      if (calendar == null) continue;
      try {
        ordinals[record.id] = calendar.ordinal(date);
        calendarIds[record.id] = calendar.id;
      } on ArgumentError {
        // An invalid stored date stays undated rather than guessing a slot.
      }
    }
    final dated = records.where((record) => ordinals.containsKey(record.id))
        .toList()
      ..sort((left, right) {
        final calendar =
            calendarIds[left.id]!.compareTo(calendarIds[right.id]!);
        if (calendar != 0) return calendar;
        final ordinal = ordinals[left.id]!.compareTo(ordinals[right.id]!);
        return ordinal != 0 ? ordinal : left.title.compareTo(right.title);
      });
    return [
      ...descending ? dated.reversed : dated,
      ...records.where((record) => !ordinals.containsKey(record.id)),
    ];
  }

  /// The calendar ordinal of a record's start date, or `null` when undated.
  Future<int?> startOrdinal(AuthorRecord record) async {
    final date = _dateFrom(record.fields['start']);
    if (date == null || !date.isDated) return null;
    final calendar = await timeline.getCalendar(date.calendarId);
    if (calendar == null) return null;
    try {
      return calendar.ordinal(date);
    } on ArgumentError {
      return null;
    }
  }

  Future<List<AuthorRecord>> involving(String recordId) async {
    final links = await timeline.repository.backlinks(recordId);
    final timelineIds = <String>{};
    for (final link in links) {
      timelineIds
          .add(link.sourceId == recordId ? link.targetId : link.sourceId);
    }
    final results = <AuthorRecord>[];
    for (final id in timelineIds) {
      final record = await timeline.getTimelineRecord(id);
      if (record != null) results.add(record);
    }
    return results;
  }

  Future<List<AuthorRecord>> involvingCharacter(String characterId) =>
      involving(characterId);

  Future<List<AuthorRecord>> involvingLocation(String locationId) =>
      involving(locationId);

  Future<List<AuthorRecord>> involvingFaction(String factionId) =>
      involving(factionId);

  Future<List<AuthorRecord>> inBook(String bookId) => all(bookId: bookId);

  Future<List<AuthorRecord>> inChapter(String chapterId) =>
      involving(chapterId);

  Future<List<AuthorRecord>> inBranch(String branchId) =>
      all(branchId: branchId);

  Future<List<AuthorRecord>> byCanon(CanonStatus status) =>
      all(canonStatus: status);

  Future<List<AuthorRecord>> byTag(String tag) => all(tag: tag);

  Future<List<AuthorRecord>> byType(String typeId) => all(typeId: typeId);

  Future<List<AuthorRecord>> between(
    TimelineDate start,
    TimelineDate end,
  ) async {
    if (start.calendarId != end.calendarId) {
      throw ArgumentError('Date range must use one calendar.');
    }
    final calendar = await timeline.getCalendar(start.calendarId);
    if (calendar == null)
      throw StateError('Unknown calendar ${start.calendarId}.');
    final lower = calendar.ordinal(start);
    final upper = calendar.ordinal(end);
    final results = <AuthorRecord>[];
    for (final record in await all()) {
      final eventStart = _dateFrom(record.fields['start']);
      if (eventStart == null ||
          !eventStart.isDated ||
          eventStart.calendarId != calendar.id) {
        continue;
      }
      final value = calendar.ordinal(eventStart);
      if (value >= lower && value <= upper) results.add(record);
    }
    return results;
  }

  Future<List<AuthorRecord>> before(String eventId) =>
      _relativeTo(eventId, before: true);

  Future<List<AuthorRecord>> after(String eventId) =>
      _relativeTo(eventId, before: false);

  Future<List<AuthorRecord>> overlapping(String eventId) async {
    final anchor = await timeline._requireTimelineId(eventId);
    final anchorStart = _dateFrom(anchor.fields['start']);
    final anchorEnd = _dateFrom(anchor.fields['end']) ?? anchorStart;
    if (anchorStart == null || anchorEnd == null || !anchorStart.isDated) {
      return const [];
    }
    final calendar = await timeline.getCalendar(anchorStart.calendarId);
    if (calendar == null) return const [];
    final lower = calendar.ordinal(anchorStart);
    final upper = calendar.ordinal(anchorEnd);
    final results = <AuthorRecord>[];
    for (final record in await all()) {
      if (record.id == eventId) continue;
      final start = _dateFrom(record.fields['start']);
      final end = _dateFrom(record.fields['end']) ?? start;
      if (start == null ||
          end == null ||
          !start.isDated ||
          start.calendarId != calendar.id ||
          end.calendarId != calendar.id) {
        continue;
      }
      if (calendar.ordinal(start) <= upper && calendar.ordinal(end) >= lower) {
        results.add(record);
      }
    }
    return results;
  }

  Future<List<AuthorRecord>> _relativeTo(
    String eventId, {
    required bool before,
  }) async {
    final anchor = await timeline._requireTimelineId(eventId);
    final anchorDate = _dateFrom(anchor.fields['start']);
    if (anchorDate == null || !anchorDate.isDated) return const [];
    final calendar = await timeline.getCalendar(anchorDate.calendarId);
    if (calendar == null) return const [];
    final anchorOrdinal = calendar.ordinal(anchorDate);
    final results = <AuthorRecord>[];
    for (final record in await all()) {
      if (record.id == eventId) continue;
      final date = _dateFrom(record.fields['start']);
      if (date == null || !date.isDated || date.calendarId != calendar.id) {
        continue;
      }
      final comparison = calendar.ordinal(date).compareTo(anchorOrdinal);
      if ((before && comparison < 0) || (!before && comparison > 0)) {
        results.add(record);
      }
    }
    return results;
  }
}

class TimelineLaneViewModel {
  const TimelineLaneViewModel({
    required this.id,
    required this.label,
    required this.kind,
    required this.events,
    this.branchId,
  });

  final String id;
  final String label;
  final String kind;
  final List<TimelineEventCardViewModel> events;
  final String? branchId;
}

class TimelineEventCardViewModel {
  const TimelineEventCardViewModel({
    required this.recordId,
    required this.title,
    required this.typeId,
    required this.dateLabel,
    required this.importance,
  });

  final String recordId;
  final String title;
  final String typeId;
  final String dateLabel;
  final String importance;
}

class TimelineDateMarkerViewModel {
  const TimelineDateMarkerViewModel({
    required this.id,
    required this.label,
    required this.date,
  });

  final String id;
  final String label;
  final TimelineDate date;
}

class TimelinePeriodHeaderViewModel {
  const TimelinePeriodHeaderViewModel({
    required this.recordId,
    required this.title,
    required this.depth,
  });

  final String recordId;
  final String title;
  final int depth;
}

class TimelineRelationshipMarkerViewModel {
  const TimelineRelationshipMarkerViewModel({
    required this.sourceId,
    required this.targetId,
    required this.typeId,
  });

  final String sourceId;
  final String targetId;
  final String typeId;
}

class TimelineValidationException implements Exception {
  const TimelineValidationException(this.issues);

  final List<TimelineValidationIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.message).join('; ');
}

TimelineDate? _dateFrom(Object? value) {
  final json = _firstObject(value);
  return json == null || (json['calendarId'] as String? ?? '').isEmpty
      ? null
      : TimelineDate.fromJson(json);
}

Map<String, Object?>? _objectMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : null;

Map<String, Object?>? _firstObject(Object? value) =>
    value is List && value.isNotEmpty
        ? _objectMap(value.first)
        : _objectMap(value);

List<Map<String, Object?>> _objectList(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList()
    : const [];

List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];
