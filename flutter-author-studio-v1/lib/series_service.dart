import 'core/book_scope.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/record_service.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'persistence/authoros_database.dart';

/// The books a project contains, and which entities belong to which of them.
///
/// The project *is* the series: AuthorOS holds one project, so a series is not
/// a container above projects but the project itself, and a book is a record
/// inside it. Everything therefore stays within one project's isolation
/// boundary — `ConnectionEngine`'s endpoint rule, `RelationshipValidator`'s
/// project check and the search index's project filter are all untouched by
/// this Studio.
///
/// Like every other Studio service here, this owns no storage. Records go
/// through [RecordService], links through [ConnectionEngine], deletion analysis
/// through [SafeDeleteService], and manuscript structure stays with
/// `ManuscriptStore`.
class SeriesService {
  const SeriesService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);

  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);

  String get seriesRecordId => 'series-$projectId';

  // ---------------------------------------------------------------- series --

  /// The project's series record, or null if the author has not made one.
  Future<AuthorRecord?> series() => records.getRecord(seriesRecordId);

  /// Creates the project's series record if it does not exist yet.
  ///
  /// A project has at most one. It carries series-level blurb and status, and
  /// is the anchor books hang off; it holds no entity data of its own.
  Future<AuthorRecord> ensureSeries({
    String? title,
    DateTime? timestamp,
  }) async {
    final existing = await series();
    if (existing != null) return existing;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final name = (title ?? '').trim().isEmpty ? 'Series' : title!.trim();
    return records.createRecord(
      AuthorRecord(
        id: seriesRecordId,
        typeId: BookScope.seriesTypeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: name,
        templateId: BookScope.seriesTypeId,
        fields: {'name': name, 'status': 'Planning'},
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // ----------------------------------------------------------------- books --

  /// The project's books, in series order.
  Future<List<AuthorRecord>> books({bool includeArchived = false}) async {
    final rows = await repository.recordsByTypeAndScope(
      typeId: BookScope.bookTypeId,
      scopeId: projectId,
    );
    final visible = rows
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .where((record) =>
            includeArchived || record.status != AuthorRecordStatus.archived)
        .toList()
      ..sort(BookScope.compareBooks);
    return visible;
  }

  Future<AuthorRecord?> book(String bookId) async {
    final record = await records.getRecord(bookId);
    return record?.typeId == BookScope.bookTypeId ? record : null;
  }

  /// Adds a book to the project.
  ///
  /// The record's own `bookId` is its own id (invariant B-2), so
  /// `UniversalSearchService.searchByBook` returns the book itself alongside
  /// everything scoped to it.
  Future<AuthorRecord> createBook({
    required String title,
    String? id,
    int? order,
    String subtitle = '',
    String blurb = '',
    DateTime? timestamp,
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      throw ArgumentError('Book title is required.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final bookId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : 'book-${_slug(name)}-${now.microsecondsSinceEpoch}';
    if (await repository.recordById(bookId) != null) {
      throw StateError('A record with id $bookId already exists.');
    }
    final position = order ?? (await books(includeArchived: true)).length;
    final created = await records.createRecord(
      AuthorRecord(
        id: bookId,
        typeId: BookScope.bookTypeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        bookId: bookId,
        title: name,
        templateId: BookScope.bookTypeId,
        fields: {
          'name': name,
          'order': position,
          'status': 'Planned',
          if (subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
          if (blurb.trim().isNotEmpty) 'blurb': blurb.trim(),
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    final seriesRecord = await series();
    if (seriesRecord != null) {
      await connections.connect(
        sourceId: created.id,
        targetId: seriesRecord.id,
        typeId: BookScope.bookInSeriesTypeId,
        metadata: {'order': position},
        timestamp: now,
      );
    }
    return created;
  }

  Future<AuthorRecord> renameBook(
    String bookId,
    String title, {
    DateTime? timestamp,
  }) async {
    final name = title.trim();
    if (name.isEmpty) {
      throw ArgumentError('Book title is required.');
    }
    final existing = await _requireBook(bookId);
    return records.updateRecord(
      existing.copyWith(
        title: name,
        fields: {...existing.fields, 'name': name},
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  /// Puts the books in [orderedIds] order.
  ///
  /// Order is a field, never an id and never a position in a list, so
  /// reordering changes no identity and breaks no link.
  Future<List<AuthorRecord>> reorderBooks(
    List<String> orderedIds, {
    DateTime? timestamp,
  }) async {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final reordered = <AuthorRecord>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final existing = await _requireBook(orderedIds[index]);
      if (existing.fields['order'] == index) {
        reordered.add(existing);
        continue;
      }
      reordered.add(
        await records.updateRecord(
          existing.copyWith(
            fields: {...existing.fields, 'order': index},
            updatedAt: now,
          ),
        ),
      );
    }
    return reordered;
  }

  /// What removing [bookId] would affect.
  ///
  /// Always call this before [archiveBook]. Deleting a book must never cascade
  /// into the entities that appear in it.
  Future<SafeDeleteAnalysis?> analyzeBookRemoval(String bookId) =>
      safeDelete.analyze(bookId);

  /// Archives a book, leaving every entity that appears in it untouched.
  ///
  /// Records assigned to the book are released to series canon first, so no
  /// record is left pointing at a book the author can no longer see. That is a
  /// deliberate choice over cascading: the entity survives the book.
  Future<AuthorRecord> archiveBook(String bookId, {DateTime? timestamp}) async {
    await _requireBook(bookId);
    final now = (timestamp ?? DateTime.now()).toUtc();
    for (final record in await recordsInBook(bookId)) {
      if (record.id == bookId) continue;
      await records.changeBookAssignment(
        record.id,
        bookId: null,
        timestamp: now,
      );
    }
    return records.archiveRecord(bookId, timestamp: now);
  }

  // ------------------------------------------------------- book membership --

  /// Every record assigned to [bookId], excluding series canon.
  Future<List<AuthorRecord>> recordsInBook(String bookId) async {
    final all = await repository.recordsByProject(projectId);
    return all
        .where((record) => record.id != bookId)
        .where((record) => record.bookId == bookId)
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .toList();
  }

  /// Records visible while reading [bookId]: series canon plus that book's own.
  Future<List<AuthorRecord>> visibleInBook(String? bookId) async {
    final all = await repository.recordsByProject(projectId);
    return all
        .where((record) => record.status != AuthorRecordStatus.deleted)
        .where((record) => BookScope.visibleInBook(record, bookId))
        .toList();
  }

  /// Restricts [recordId] to [bookId].
  Future<AuthorRecord> restrictToBook(
    String recordId,
    String bookId, {
    DateTime? timestamp,
  }) async {
    await _requireBook(bookId);
    return records.changeBookAssignment(
      recordId,
      bookId: bookId,
      timestamp: timestamp,
    );
  }

  /// Releases [recordId] to series canon, visible from every book.
  ///
  /// The inverse of [restrictToBook], and reversible: the record id, every link
  /// and every field value survive the move. Only `bookId`, `revision` and
  /// `updatedAt` change, and the audit trail records both directions.
  Future<AuthorRecord> promoteToSeriesCanon(
    String recordId, {
    DateTime? timestamp,
  }) =>
      records.changeBookAssignment(
        recordId,
        bookId: null,
        timestamp: timestamp,
      );

  Future<AuthorRecord> _requireBook(String bookId) async {
    final record = await book(bookId);
    if (record == null) {
      throw StateError('Book $bookId does not exist in project $projectId.');
    }
    return record;
  }
}

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'book' : slug;
}
