import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/record_validation.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `changeScope` preserves the scope columns you did not ask it to change.
///
/// It used to assign `seriesId`, `bookId` and `branchId` unconditionally from
/// its arguments, so moving a record between scopes silently erased whichever
/// of the three the caller had not thought to re-supply. Every test in the
/// first group here fails against that old behaviour.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late SeriesService series;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    series = SeriesService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> character(
    String id, {
    String? seriesId,
    String? bookId,
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          seriesId: seriesId,
          bookId: bookId,
          title: 'Kali Vale',
          templateId: 'character',
          fields: const {
            'name': 'Kali Vale',
            'identity.fullName': 'Kali Vale',
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  group('columns you did not name are preserved', () {
    test('a scope move keeps a book membership it was never asked about',
        () async {
      // The original bug, in one test: moving a record between scopes had
      // nothing to do with books, and used to drop the book anyway.
      final book = await series.createBook(title: 'Book Two');
      await character('kali', bookId: book.id);

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.series,
        scopeId: 'series-project-a',
        seriesId: 'series-project-a',
      );

      expect(moved.bookId, book.id, reason: 'the book was never mentioned');
      expect(moved.seriesId, 'series-project-a');
      expect(moved.scopeType, RecordScopeType.series);
    });

    test('a scope move keeps a series it was never asked about', () async {
      await character('kali', seriesId: 'series-project-a');

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
      );

      expect(moved.seriesId, 'series-project-a');
    });

    test('passing null preserves, because Dart cannot tell it from omitted',
        () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', bookId: book.id);

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        bookId: null,
      );

      // Passing null is indistinguishable from omitting it in Dart, so this
      // preserves — clearing takes the explicit flag below.
      expect(moved.bookId, book.id);
    });

    test('nothing else about the record moves', () async {
      final created = await character('kali', seriesId: 'series-project-a');

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.series,
        scopeId: 'series-project-a',
        seriesId: 'series-project-a',
      );

      expect(moved.id, created.id);
      expect(moved.typeId, created.typeId);
      expect(moved.title, created.title);
      expect(moved.fields, created.fields);
      expect(moved.tags, created.tags);
      expect(moved.projectId, created.projectId);
      expect(moved.canonStatus, created.canonStatus);
      expect(moved.status, created.status);
      expect(moved.createdAt, created.createdAt);
      expect(moved.revision, created.revision + 1);
    });
  });

  group('losing a column takes an explicit flag', () {
    test('clearBookId drops the book', () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', bookId: book.id);

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        clearBookId: true,
      );

      expect(moved.bookId, isNull);
    });

    test('clearSeriesId drops the series', () async {
      await character('kali', seriesId: 'series-project-a');

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        clearSeriesId: true,
      );

      expect(moved.seriesId, isNull);
    });

    test('a clear flag beats a value passed alongside it', () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', bookId: book.id);

      final moved = await records.changeScope(
        'kali',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        bookId: book.id,
        clearBookId: true,
      );

      expect(moved.bookId, isNull, reason: 'the explicit intent wins');
    });
  });

  group('scope consistency is still enforced', () {
    test('a series scope without its series id is refused', () async {
      await character('kali');

      expect(
        () => records.changeScope(
          'kali',
          scopeType: RecordScopeType.series,
          scopeId: 'series-project-a',
        ),
        throwsA(isA<RecordValidationException>()),
      );
    });

    test('a book scope whose bookId does not match is refused', () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', seriesId: 'series-project-a');

      expect(
        () => records.changeScope(
          'kali',
          scopeType: RecordScopeType.book,
          scopeId: book.id,
          bookId: 'some-other-book',
        ),
        throwsA(isA<RecordValidationException>()),
      );
    });

    test('a refused move leaves the record exactly as it was', () async {
      final book = await series.createBook(title: 'Book Two');
      final created = await character('kali', bookId: book.id);

      await expectLater(
        records.changeScope(
          'kali',
          scopeType: RecordScopeType.series,
          scopeId: 'series-project-a',
          clearSeriesId: true,
        ),
        throwsA(isA<RecordValidationException>()),
      );

      final unchanged = (await records.getRecord('kali'))!;
      expect(unchanged.revision, created.revision);
      expect(unchanged.scopeType, RecordScopeType.project);
      expect(unchanged.bookId, book.id);
    });
  });

  group('the audit trail names what moved', () {
    test('a book change is recorded even inside a scope move', () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', seriesId: 'series-project-a');

      await records.changeScope(
        'kali',
        scopeType: RecordScopeType.book,
        scopeId: book.id,
        bookId: book.id,
      );

      final move = (await records.history.getAuditHistory(
        recordId: 'kali',
        changeType: AuditChangeType.scopeChanged,
      ))
          .single;
      expect(move.metadata['previousBookId'], isNull);
      expect(move.metadata['newBookId'], book.id);
      expect(move.metadata['previousScopeType'], 'project');
      expect(move.metadata['newScopeType'], 'book');
    });

    test('a column that did not move is not reported as if it had', () async {
      await character('kali', seriesId: 'series-project-a');

      await records.changeScope(
        'kali',
        scopeType: RecordScopeType.series,
        scopeId: 'series-project-a',
      );

      final move = (await records.history.getAuditHistory(
        recordId: 'kali',
        changeType: AuditChangeType.scopeChanged,
      ))
          .single;
      expect(move.metadata.containsKey('newSeriesId'), isFalse);
      expect(move.metadata.containsKey('newBookId'), isFalse);
      expect(move.metadata.containsKey('newBranchId'), isFalse);
    });
  });

  test('changeBookAssignment still behaves as its own callers expect',
      () async {
    // It now shares changeScope's write path, so this pins that the sharing
    // did not change what it does.
    final book = await series.createBook(title: 'Book Two');
    final created = await character('kali', seriesId: 'series-project-a');

    final moved = await records.changeBookAssignment('kali', bookId: book.id);

    expect(moved.bookId, book.id);
    expect(moved.seriesId, created.seriesId);
    expect(moved.scopeType, created.scopeType);
    expect(moved.scopeId, created.scopeId);
    expect(moved.projectId, created.projectId);
    expect(moved.branchId, created.branchId);
    expect(moved.fields, created.fields);

    final back = await records.changeBookAssignment('kali', bookId: null);
    expect(back.bookId, isNull);
    expect(back.seriesId, created.seriesId);
  });
}
