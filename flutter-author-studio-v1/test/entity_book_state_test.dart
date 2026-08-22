import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/book_scope.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One canonical entity, appearing across books, differing in some of them.
///
/// This is the shape the directive asks for: Series Canon, Book Usage, Scene
/// Usage, and Version/State — with exactly one Kali, never four copies.
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

  Future<AuthorRecord> kali() => records.createRecord(
        AuthorRecord(
          id: 'kali',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          title: 'Kali Vale',
          templateId: 'character',
          fields: const {
            'name': 'Kali Vale',
            'identity.fullName': 'Kali Vale',
            'identity.age': 27,
            'summary': 'The Red Widow.',
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  group('book usage', () {
    test('one entity appears across four books', () async {
      final books = [
        for (final title in const ['One', 'Two', 'Three', 'Four'])
          await series.createBook(title: 'Book $title'),
      ];
      await kali();
      for (final book in books) {
        await series.recordBookAppearance('kali', book.id, role: 'protagonist');
      }

      final appearances = await series.booksFor('kali');
      expect(appearances.map((book) => book.title),
          ['Book One', 'Book Two', 'Book Three', 'Book Four']);

      // Still exactly one Kali.
      final all = await repository.recordsByProject('project-a');
      expect(all.where((record) => record.typeId == 'character'), hasLength(1));
    });

    test('an appearance carries its usage detail', () async {
      final book = await series.createBook(title: 'Book One');
      await kali();
      await series.recordBookAppearance(
        'kali',
        book.id,
        role: 'protagonist',
        status: 'alive',
        firstAppearance: 'chapter-1',
        notes: 'Carries the Red Widow arc.',
      );

      final link = await series.bookAppearance('kali', book.id);
      expect(link!.metadata['role'], 'protagonist');
      expect(link.metadata['status'], 'alive');
      expect(link.metadata['firstAppearance'], 'chapter-1');
    });

    test('an undeclared usage key is refused, not silently stored', () async {
      final book = await series.createBook(title: 'Book One');
      await kali();
      expect(
        () => series.connections.connect(
          sourceId: 'kali',
          targetId: book.id,
          typeId: 'appearsIn',
          metadata: const {'mood': 'ominous'},
        ),
        throwsStateError,
      );
    });

    test('removing an appearance leaves the entity alone', () async {
      final book = await series.createBook(title: 'Book One');
      await kali();
      await series.recordBookAppearance('kali', book.id);

      await series.removeBookAppearance('kali', book.id);

      expect(await series.booksFor('kali'), isEmpty);
      expect(await records.getRecord('kali'), isNotNull);
    });
  });

  group('book state', () {
    test('a state records only what differs', () async {
      final two = await series.createBook(title: 'Book Two');
      await kali();

      final state = await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
        reason: 'Two years pass between books.',
      );

      expect(BookScope.overridesOf(state), {'identity.age': 29});
      expect(BookScope.canonicalIdOf(state), 'kali');
      expect(state.bookId, two.id);
      expect(state.fields['changeReason'], 'Two years pass between books.');
    });

    test('canon shows through wherever a book does not override', () async {
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      await kali();
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      final inOne = await series.effectiveFieldsFor('kali', bookId: one.id);
      expect(inOne!.fields['identity.age'], 27);
      expect(inOne.isCanon, isTrue);

      final inTwo = await series.effectiveFieldsFor('kali', bookId: two.id);
      expect(inTwo!.fields['identity.age'], 29);
      expect(inTwo.fields['summary'], 'The Red Widow.', reason: 'from canon');
      expect(inTwo.overriddenFieldIds, {'identity.age'});
      expect(inTwo.isCanon, isFalse);

      final canon = await series.effectiveFieldsFor('kali');
      expect(canon!.fields['identity.age'], 27);
    });

    test('editing canon still reaches every book that does not override',
        () async {
      // The point of a difference rather than a copy.
      final one = await series.createBook(title: 'Book One');
      final two = await series.createBook(title: 'Book Two');
      final canon = await kali();
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      await records.updateRecord(
        canon.copyWith(
          fields: {...canon.fields, 'summary': 'The Widow of Endovier.'},
          updatedAt: timestamp,
        ),
      );

      for (final book in [one, two]) {
        final effective = await series.effectiveFieldsFor(
          'kali',
          bookId: book.id,
        );
        expect(effective!.fields['summary'], 'The Widow of Endovier.');
      }
      // ...and the override still stands.
      expect(
        (await series.effectiveFieldsFor('kali', bookId: two.id))!
            .fields['identity.age'],
        29,
      );
    });

    test('a book can drop a field entirely', () async {
      final two = await series.createBook(title: 'Book Two');
      await kali();
      await series.setEntityState(
        'kali',
        two.id,
        removedFieldIds: const ['summary'],
      );

      final inTwo = await series.effectiveFieldsFor('kali', bookId: two.id);
      expect(inTwo!.fields.containsKey('summary'), isFalse);
      expect(inTwo.removedFieldIds, {'summary'});
      // Dropped for this book only; canon keeps it.
      expect((await records.getRecord('kali'))!.fields['summary'],
          'The Red Widow.');
    });

    test('setting a state twice updates instead of duplicating', () async {
      final two = await series.createBook(title: 'Book Two');
      await kali();
      final first = await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 28},
      );
      final second = await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      expect(second.id, first.id);
      expect(await series.entityStatesFor('kali'), hasLength(1));
      expect(BookScope.overridesOf(second), {'identity.age': 29});
    });

    test('a state is tied to its entity and its book by typed edges', () async {
      final two = await series.createBook(title: 'Book Two');
      await kali();
      final state = await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      final links = await repository.outgoingLinks(state.id);
      expect(
        links.map((link) => '${link.typeId}->${link.targetId}'),
        containsAll(<String>{'documents->kali', 'stateInBook->${two.id}'}),
      );
    });

    test('clearing a state returns the book to canon', () async {
      final two = await series.createBook(title: 'Book Two');
      await kali();
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      await series.clearEntityState('kali', two.id);

      final inTwo = await series.effectiveFieldsFor('kali', bookId: two.id);
      expect(inTwo!.fields['identity.age'], 27);
      expect(inTwo.isCanon, isTrue);
      expect(await records.getRecord('kali'), isNotNull);
    });

    test('an entity with no state costs nothing to resolve', () async {
      final one = await series.createBook(title: 'Book One');
      final canon = await kali();

      final effective = await series.effectiveFieldsFor('kali', bookId: one.id);
      expect(effective!.fields, canon.fields);
      expect(effective.stateRecordId, isNull);
      expect(effective.isCanon, isTrue);
    });
  });

  test('a series survives an archive round trip with every id intact',
      () async {
    // Books and states are ordinary records, so the portable archive carries
    // them with no format change — which is the other half of why a book state
    // is a record rather than an overlay row.
    final two = await series.createBook(title: 'Book Two');
    await series.ensureSeries(title: 'Endovier Chronicles');
    await kali();
    await series.recordBookAppearance('kali', two.id, role: 'protagonist');
    final state = await series.setEntityState(
      'kali',
      two.id,
      overrides: const {'identity.age': 29},
    );

    const archive = AuthorOsArchiveService();
    final restored = archive.importSnapshot(
      archive.exportSnapshot(
        await repository.snapshot(),
        archiveId: 'archive-series',
        rootId: 'project-a',
        applicationVersion: '2.0.0',
        platform: 'linux',
        createdAt: timestamp,
      ),
    );

    final ids = restored.records.map((record) => record.id).toSet();
    expect(ids, containsAll(<String>{'kali', two.id, state.id}));

    final restoredBook =
        restored.records.firstWhere((record) => record.id == two.id);
    expect(restoredBook.bookId, two.id);

    final restoredState =
        restored.records.firstWhere((record) => record.id == state.id);
    expect(restoredState.bookId, two.id);
    expect(BookScope.overridesOf(restoredState), {'identity.age': 29});

    final appearance = restored.links.firstWhere(
      (link) => link.typeId == 'appearsIn' && link.targetId == two.id,
    );
    expect(appearance.metadata['role'], 'protagonist');
  });

  test('states are searchable, versioned records like anything else', () async {
    // The reason a book state is a record and not an overlay row: it is canon
    // at a point in the series, so it has to behave like canon.
    final two = await series.createBook(title: 'Book Two');
    await kali();
    final state = await series.setEntityState(
      'kali',
      two.id,
      overrides: const {'identity.age': 29},
    );

    final versions = await records.history.getVersionHistory(
      recordId: state.id,
    );
    expect(versions, isNotEmpty);
    expect(await repository.recordById(state.id), isNotNull);
  });
}
