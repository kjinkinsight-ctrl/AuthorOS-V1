import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'record_service.dart';
import 'scope_resolver.dart';
import 'version_audit.dart';

export 'scope_resolver.dart'
    show
        ScopeChain,
        ScopeResolver,
        kProjectRecordTypeId,
        kScopeContainerTypeIds,
        kSeriesRecordTypeId;

/// Field keys a series record owns, namespaced so a series field can never be
/// mistaken for a template field an author defined.
class SeriesFields {
  const SeriesFields._();

  static const prefix = '_series.';

  /// Free-text description of the series.
  static const summary = 'summary';
}

/// A series: shared canon that outlives any one book.
///
/// A series is an ordinary [AuthorRecord] of type `series`, owning the scope it
/// names. It is not a table and not a second identity model, so it inherits
/// validation, versioning, audit, safe-delete and graph node-hood for free.
class SeriesScope {
  const SeriesScope(this.record);

  final AuthorRecord record;

  String get id => record.id;

  String get title => record.title;

  String get summary {
    final value = record.fields[SeriesFields.summary];
    final normalized = value is String ? value.trim() : '';
    return normalized;
  }

  bool get isArchived => record.status == AuthorRecordStatus.archived;

  bool get isDeleted => record.status == AuthorRecordStatus.deleted;
}

/// Creates series, enrols books in them, and moves records between a book's
/// own scope and its series' shared scope.
///
/// Every write here goes through [RecordService]. In particular, promotion and
/// demotion delegate to [RecordService.changeScope], which is the only path in
/// the application that may change a record's ownership: [AuthorRecord.copyWith]
/// deliberately cannot change scope fields, and [RecordService.updateRecord]
/// throws if they differ. This service adds no second door.
class SeriesScopeService {
  const SeriesScopeService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  ScopeResolver get scopes =>
      ScopeResolver(projectId: projectId, repository: repository);

  /// Every series in the store.
  ///
  /// The enrol flow needs these: a book joins a series that may already exist.
  Future<List<SeriesScope>> allSeries() async {
    final rows = await repository.recordsByType(kSeriesRecordTypeId);
    return rows
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .map(SeriesScope.new)
        .toList();
  }

  Future<SeriesScope?> getSeries(String seriesId) async {
    final record = await repository.recordById(seriesId);
    if (record == null || record.typeId != kSeriesRecordTypeId) return null;
    return SeriesScope(record);
  }

  /// The series this project belongs to, if any.
  Future<SeriesScope?> currentSeries() async {
    final chain = await scopes.chain();
    final seriesId = chain.seriesId;
    return seriesId == null ? null : getSeries(seriesId);
  }

  /// Creates a series and enrols this project in it.
  Future<SeriesScope> createSeries({
    required String title,
    String? id,
    String summary = '',
    String projectTitle = '',
    DateTime? timestamp,
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      throw ArgumentError('A series needs a name.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final seriesId = id != null && id.trim().isNotEmpty
        ? id.trim()
        : 'series-${_slug(name)}-${now.microsecondsSinceEpoch}';
    if (await repository.recordById(seriesId) != null) {
      throw StateError('A record with id $seriesId already exists.');
    }
    final record = AuthorRecord(
      id: seriesId,
      typeId: kSeriesRecordTypeId,
      // A series owns the scope it names. RecordScope.validate requires exactly
      // this: for a series scope, the scope id and the series id are one value.
      scopeType: RecordScopeType.series,
      scopeId: seriesId,
      seriesId: seriesId,
      // The founding book stays on the record as provenance. It is also what
      // keeps the series editable from here: every ownership check accepts a
      // record whose projectId matches, whatever its scope.
      projectId: projectId,
      title: name,
      canonStatus: CanonStatus.canon,
      templateId: kSeriesRecordTypeId,
      fields: {
        'name': name,
        if (summary.trim().isNotEmpty) SeriesFields.summary: summary.trim(),
      },
      createdAt: now,
      updatedAt: now,
    );
    await records.createRecord(record);
    await enrol(seriesId, projectTitle: projectTitle, timestamp: now);
    return SeriesScope(record);
  }

  /// Enrols this project in [seriesId].
  Future<ScopeChain> enrol(
    String seriesId, {
    String projectTitle = '',
    DateTime? timestamp,
  }) async {
    final series = await getSeries(seriesId);
    if (series == null) {
      throw StateError('Series $seriesId does not exist.');
    }
    final project = await scopes.ensureProjectRecord(
      title: projectTitle,
      timestamp: timestamp,
    );
    if (project.seriesId == seriesId) {
      return ScopeChain(projectId: projectId, seriesId: seriesId);
    }
    await records.changeScope(
      project.id,
      scopeType: RecordScopeType.project,
      scopeId: project.scopeId,
      seriesId: seriesId,
      bookId: project.bookId,
      branchId: project.branchId,
      timestamp: timestamp,
    );
    return ScopeChain(projectId: projectId, seriesId: seriesId);
  }

  /// Withdraws this project from its series.
  ///
  /// Records already promoted stay in the series. Withdrawing changes what this
  /// book can see, never what the series holds.
  Future<ScopeChain> withdraw({
    String projectTitle = '',
    DateTime? timestamp,
  }) async {
    final project = await scopes.ensureProjectRecord(
      title: projectTitle,
      timestamp: timestamp,
    );
    if (project.seriesId == null) return ScopeChain(projectId: projectId);
    await records.changeScope(
      project.id,
      scopeType: RecordScopeType.project,
      scopeId: project.scopeId,
      seriesId: null,
      bookId: project.bookId,
      branchId: project.branchId,
      timestamp: timestamp,
    );
    return ScopeChain(projectId: projectId);
  }

  /// Moves a record from this book's scope into the series' shared scope.
  ///
  /// The record keeps its id, its creation time, its fields, its tags and its
  /// relationships. Promotion moves the node, not its edges: a link created in
  /// book one is a book-one fact, and stays owned by book one.
  Future<AuthorRecord> promoteToSeries(
    String recordId, {
    String? seriesId,
    DateTime? timestamp,
  }) async {
    final chain = await scopes.chain();
    final target = seriesId ?? chain.seriesId;
    if (target == null) {
      throw StateError('This book does not belong to a series.');
    }
    final existing = await records.getRecord(recordId);
    if (existing == null) {
      throw StateError('Record $recordId does not belong to $projectId.');
    }
    if (existing.scopeType == RecordScopeType.series &&
        existing.scopeId == target) {
      return existing;
    }
    return records.changeScope(
      recordId,
      scopeType: RecordScopeType.series,
      scopeId: target,
      seriesId: target,
      // A shared record is not a book's record, so the book id is cleared
      // deliberately rather than by omission.
      bookId: null,
      branchId: existing.branchId,
      timestamp: timestamp,
    );
  }

  /// Returns a shared record to the book that authored it.
  ///
  /// Only the provenance book may do this, which is what stops book three
  /// quietly removing a character book one shared.
  Future<AuthorRecord> demoteToProject(
    String recordId, {
    DateTime? timestamp,
  }) async {
    final existing = await records.getRecord(recordId);
    if (existing == null) {
      throw StateError('Record $recordId does not belong to $projectId.');
    }
    final home = existing.projectId;
    if (home == null || home.trim().isEmpty) {
      throw StateError('Record $recordId has no book to return to.');
    }
    if (home != projectId) {
      throw StateError(
        'Only $home can return ${existing.title} to a single book.',
      );
    }
    if (existing.scopeType == RecordScopeType.project) return existing;
    return records.changeScope(
      recordId,
      scopeType: RecordScopeType.project,
      scopeId: home,
      seriesId: null,
      bookId: existing.bookId,
      branchId: existing.branchId,
      timestamp: timestamp,
    );
  }

  /// Moves a series' provenance to another book.
  ///
  /// Without this a series whose founding book is deleted becomes uneditable,
  /// because every ownership check resolves through the record's projectId.
  Future<AuthorRecord> rehomeSeries(
    String seriesId, {
    required String toProjectId,
    DateTime? timestamp,
  }) async {
    final series = await getSeries(seriesId);
    if (series == null) {
      throw StateError('Series $seriesId does not exist.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final rehomed = AuthorRecord(
      id: series.record.id,
      typeId: series.record.typeId,
      scopeType: series.record.scopeType,
      scopeId: series.record.scopeId,
      projectId: toProjectId,
      seriesId: series.record.seriesId,
      bookId: series.record.bookId,
      branchId: series.record.branchId,
      canonStatus: series.record.canonStatus,
      title: series.record.title,
      status: series.record.status,
      schemaVersion: series.record.schemaVersion,
      templateId: series.record.templateId,
      templateVersion: series.record.templateVersion,
      revision: series.record.revision + 1,
      fields: series.record.fields,
      tags: series.record.tags,
      createdAt: series.record.createdAt,
      updatedAt: now,
      extensionData: series.record.extensionData,
    );
    final entry = await records.history.forRecord(
      rehomed,
      changeType: AuditChangeType.scopeChanged,
      summary: 'Moved ${rehomed.title} to $toProjectId',
      timestamp: now,
      metadata: {
        'previousProjectId': series.record.projectId,
        'newProjectId': toProjectId,
      },
    );
    await repository.putRecordWithHistory(
      record: rehomed,
      links: const [],
      version: entry.version,
      auditEvent: entry.audit,
    );
    return rehomed;
  }
}

String _slug(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'series' : normalized;
}
