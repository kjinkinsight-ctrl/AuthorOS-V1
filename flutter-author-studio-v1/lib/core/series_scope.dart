import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'record_service.dart';
import 'scope_resolver.dart';
import 'writing_series.dart';

export 'scope_resolver.dart'
    show
        ScopeChain,
        ScopeResolver,
        kProjectRecordTypeId,
        kScopeContainerTypeIds,
        kSeriesRecordTypeId;

/// Moves records between a book's own scope and its series' shared scope.
///
/// It does **not** create, name, rename or delete a series, and it does not
/// decide which books are in one. Those belong to the project roster, which owns
/// series identity (Q-S1) — a series exists in `series_rows` and nowhere else.
/// This service only answers "is this record the book's, or the series'?".
///
/// Every write goes through [RecordService]. Promotion and demotion delegate to
/// [RecordService.changeScope], the only path in the application that may change
/// a record's ownership: [AuthorRecord.copyWith] deliberately cannot change scope
/// fields, and [RecordService.updateRecord] throws if they differ. This service
/// adds no second door.
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

  /// The series this book belongs to, or null when it stands alone.
  ///
  /// Read from the roster, which owns series identity (Q-S1). This service does
  /// not create, rename or delete a series and does not decide membership —
  /// those are the Projects Studio's, and duplicating them here is what put two
  /// ids behind one word in the first place.
  Future<WritingSeries?> currentSeries() async {
    final chain = await scopes.chain();
    final seriesId = chain.seriesId;
    return seriesId == null ? null : repository.seriesById(seriesId);
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
      // deliberately rather than by omission — and an omitted column is
      // preserved, so saying so takes `clearBookId` rather than a null.
      clearBookId: true,
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
      // `changeScope` preserves a scope column it is not told about, so
      // returning a record to one book has to say that the series column goes,
      // not merely decline to re-supply it. Passing `seriesId: null` reads as
      // "leave it alone" and would leave a project-scoped record still
      // claiming series membership.
      clearSeriesId: true,
      bookId: existing.bookId,
      branchId: existing.branchId,
      timestamp: timestamp,
    );
  }

  /// Returns every record shared with [seriesId] to the book that authored it.
  ///
  /// Called before a series is deleted. Without it, deleting a series would
  /// leave its shared canon pointing at a scope that no longer exists —
  /// unreachable from any book, though not lost. Demotion runs through
  /// [demoteToProject], so each record keeps its id, fields, tags and links.
  ///
  /// A record whose provenance book is gone is left alone rather than guessed
  /// at; it is reported so the caller can say so.
  Future<List<String>> releaseSeries(
    String seriesId, {
    DateTime? timestamp,
  }) async {
    final stranded = <String>[];
    for (final record in await repository.recordsInSeriesScope(seriesId)) {
      final home = record.projectId;
      if (home == null || home.trim().isEmpty) {
        stranded.add(record.id);
        continue;
      }
      await SeriesScopeService(projectId: home, repository: repository)
          .demoteToProject(record.id, timestamp: timestamp);
    }
    return stranded;
  }
}

