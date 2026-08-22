import 'dart:io';

import 'package:author_studio_v1/core/book_scope.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late SeriesService series;
  late RecordService records;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    series = SeriesService(projectId: 'project-a', repository: repository);
    records = RecordService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> character(String id, String name) => records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          title: name,
          templateId: 'character',
          fields: {'name': name, 'identity.fullName': name},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  group('books', () {
    test('a project holds an ordered list of books', () async {
      await series.ensureSeries(title: 'Endovier Chronicles');
      for (final title in const ['Book One', 'Book Two', 'Book Three']) {
        await series.createBook(title: title, timestamp: timestamp);
      }

      final books = await series.books();
      expect(books.map((book) => book.title),
          ['Book One', 'Book Two', 'Book Three']);
      expect(books.map((book) => book.fields['order']), [0, 1, 2]);
    });

    test("a book's own bookId is its own id", () async {
      // Invariant B-2. It is what makes `bookId == null` mean "series canon"
      // rather than "nobody has filed this yet".
      final book = await series.createBook(title: 'Book One');
      expect(book.bookId, book.id);
      expect(BookScope.bookIdOf(book), book.id);
      expect(BookScope.isSeriesCanon(book), isFalse);
    });

    test('a book is linked to its series with a typed edge', () async {
      final seriesRecord = await series.ensureSeries(title: 'Endovier');
      final book = await series.createBook(title: 'Book One');

      final links = await repository.outgoingLinks(book.id);
      final spine = links.singleWhere(
        (link) => link.typeId == BookScope.bookInSeriesTypeId,
      );
      expect(spine.targetId, seriesRecord.id);
      expect(spine.metadata['order'], 0);
    });

    test('reordering changes no id and breaks no link', () async {
      await series.ensureSeries();
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      final linksBefore = await repository.backlinks(one.id);

      await series.reorderBooks([two.id, one.id]);

      final books = await series.books();
      expect(books.map((book) => book.id), [two.id, one.id]);
      expect(books.map((book) => book.title), ['Book Two', 'Book One']);
      expect(
        (await repository.backlinks(one.id)).map((link) => link.id),
        linksBefore.map((link) => link.id),
      );
    });

    test('renaming a book keeps its id and its place', () async {
      final book = await series.createBook(title: 'Book One');
      final renamed = await series.renameBook(book.id, 'The Blood Price');

      expect(renamed.id, book.id);
      expect(renamed.title, 'The Blood Price');
      expect(renamed.fields['name'], 'The Blood Price');
      expect(renamed.fields['order'], book.fields['order']);
    });
  });

  group('book membership', () {
    test('series canon is visible from every book', () async {
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      final kali = await character('kali', 'Kali Vale');

      expect(BookScope.isSeriesCanon(kali), isTrue);
      expect(BookScope.visibleInBook(kali, one.id), isTrue);
      expect(BookScope.visibleInBook(kali, two.id), isTrue);
      expect(
        (await series.visibleInBook(two.id)).map((record) => record.id),
        contains('kali'),
      );
    });

    test('a book-specific record is invisible from other books', () async {
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      await character('cameo', 'Harbour Boy');
      await series.restrictToBook('cameo', one.id);

      final inTwo = await series.visibleInBook(two.id);
      expect(inTwo.map((record) => record.id), isNot(contains('cameo')));

      final inOne = await series.visibleInBook(one.id);
      expect(inOne.map((record) => record.id), contains('cameo'));
    });

    test('restrict then promote is reversible and lossless', () async {
      // The whole reason book membership is a column and not a scope change:
      // moving a record between books must cost it nothing.
      final book = await series.createBook(title: 'Book Two');
      final kali = await character('kali', 'Kali Vale');
      await character('vincenzo', 'Vincenzo');
      final engine =
          ConnectionEngine(scopeId: 'project-a', repository: repository);
      final link = await engine.connect(
        sourceId: 'kali',
        targetId: 'vincenzo',
        typeId: 'rivalOf',
        direction: RecordLinkDirection.undirected,
      );

      final restricted = await series.restrictToBook('kali', book.id);
      expect(restricted.id, kali.id);
      expect(restricted.bookId, book.id);

      final promoted = await series.promoteToSeriesCanon('kali');

      expect(promoted.id, kali.id);
      expect(promoted.bookId, isNull);
      expect(promoted.fields, kali.fields);
      expect(promoted.title, kali.title);
      expect(promoted.scopeType, kali.scopeType);
      expect(promoted.scopeId, kali.scopeId);
      expect(promoted.projectId, kali.projectId);
      expect(promoted.seriesId, kali.seriesId);
      expect(promoted.branchId, kali.branchId);
      expect(
        (await repository.backlinks('kali')).map((each) => each.id),
        contains(link.id),
      );
    });

    test('the move is audited in both directions', () async {
      final book = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale');

      await series.restrictToBook('kali', book.id);
      await series.promoteToSeriesCanon('kali');

      final moves = await records.history.getAuditHistory(
        recordId: 'kali',
        changeType: AuditChangeType.scopeChanged,
      );
      expect(moves, hasLength(2));
      expect(moves.map((event) => event.metadata['newBookId']),
          containsAll(<Object?>[book.id, null]));
    });

    test('assigning to a book that does not exist is refused', () async {
      await character('kali', 'Kali Vale');
      expect(
        () => records.changeBookAssignment('kali', bookId: 'no-such-book'),
        throwsStateError,
      );
    });

    test('a book assignment preserves every other ownership column', () async {
      // Both scope paths preserve the columns a caller did not name. This pins
      // it from the book-assignment side; record_scope_change_test.dart pins
      // the general changeScope case.
      final book = await series.createBook(title: 'Book One');
      final scoped = await records.createRecord(
        AuthorRecord(
          id: 'scoped',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          seriesId: 'series-project-a',
          title: 'Scoped',
          templateId: 'character',
          fields: const {'name': 'Scoped', 'identity.fullName': 'Scoped'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

      final moved = await records.changeBookAssignment(
        'scoped',
        bookId: book.id,
      );

      expect(moved.seriesId, scoped.seriesId);
      expect(moved.scopeType, scoped.scopeType);
      expect(moved.scopeId, scoped.scopeId);
      expect(moved.projectId, scoped.projectId);
      expect(moved.branchId, scoped.branchId);
      expect(moved.bookId, book.id);
    });
  });

  group('book search', () {
    test('searchByBook finally returns something', () async {
      // The whole book-filter path — the bookId column, the composite index,
      // the FTS book_id field and searchByBook — was already built. It
      // returned nothing only because no service had ever set the column.
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      await character('kali', 'Kali Vale');
      await character('harbour-boy', 'Kali Harbour Boy');
      await series.restrictToBook('harbour-boy', two.id);

      final search =
          UniversalSearchService(projectId: 'project-a', repository: repository);

      final inTwo = await search.searchByBook('Kali', two.id);
      expect(inTwo.map((hit) => hit.recordId), contains('harbour-boy'));

      final inOne = await search.searchByBook('Kali', one.id);
      expect(inOne.map((hit) => hit.recordId), isNot(contains('harbour-boy')));

      final everywhere = await search.searchAll('Kali');
      expect(
        everywhere.map((hit) => hit.recordId),
        containsAll(<String>{'kali', 'harbour-boy'}),
      );
    });

    test('a book is found by its own book filter', () async {
      final book = await series.createBook(title: 'Endovier Rising');
      final search =
          UniversalSearchService(projectId: 'project-a', repository: repository);

      final hits = await search.searchByBook('Endovier', book.id);
      expect(hits.map((hit) => hit.recordId), contains(book.id));
    });

    test('the search filter carries the book through', () {
      const filter = UniversalSearchFilter(projectId: 'project-a');
      expect(filter.copyWith(bookId: 'book-1').bookId, 'book-1');
    });
  });

  group('removing a book', () {
    test('archiving a book releases its records instead of taking them',
        () async {
      // A book is a container, not an owner. The entities outlive it.
      final book = await series.createBook(title: 'Book One');
      await character('cameo', 'Harbour Boy');
      await series.restrictToBook('cameo', book.id);

      await series.archiveBook(book.id);

      final cameo = await records.getRecord('cameo');
      expect(cameo, isNotNull);
      expect(cameo!.status, AuthorRecordStatus.active);
      expect(cameo.bookId, isNull, reason: 'released to series canon');
      expect((await series.books()).map((each) => each.id),
          isNot(contains(book.id)));
    });

    test('removal analysis reports what the book touches', () async {
      final seriesRecord = await series.ensureSeries();
      final book = await series.createBook(title: 'Book One');

      final analysis = await series.analyzeBookRemoval(book.id);
      expect(analysis, isNotNull);
      expect(
        analysis!.outgoingConnections.map((each) => each.target.id),
        contains(seriesRecord.id),
      );
    });
  });

  test('books and membership survive close and reopen', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('series-service-');
    final file =
        File('${directory.path}${Platform.pathSeparator}series.sqlite');

    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final first = SeriesService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(firstDatabase),
    );
    await first.ensureSeries(title: 'Endovier Chronicles');
    final two = await first.createBook(title: 'Book Two');
    await RecordService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(firstDatabase),
    ).createRecord(
      AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'durable-project',
        projectId: 'durable-project',
        title: 'Kali Vale',
        templateId: 'character',
        fields: const {'name': 'Kali Vale', 'identity.fullName': 'Kali Vale'},
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await first.restrictToBook('kali', two.id);
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    addTearDown(reopenedDatabase.close);
    final reopened = SeriesService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(reopenedDatabase),
    );

    final books = await reopened.books();
    expect(books.map((book) => book.title), ['Book Two']);
    expect(books.single.bookId, books.single.id);
    expect((await reopened.series())?.title, 'Endovier Chronicles');
    expect((await reopened.recordsInBook(two.id)).map((each) => each.id),
        ['kali']);

    // The whole point: the book filter answers correctly after a reopen.
    final search = UniversalSearchService(
      projectId: 'durable-project',
      repository: DriftConnectedDomainRepository(reopenedDatabase),
    );
    expect(
      (await search.searchByBook('Kali', two.id)).map((hit) => hit.recordId),
      contains('kali'),
    );
  });
}
