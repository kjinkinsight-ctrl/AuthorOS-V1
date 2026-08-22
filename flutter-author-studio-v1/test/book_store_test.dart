import 'dart:convert';

import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/book_studio_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = BookStore();
  const projectId = 'project-book';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('first open', () {
    test('seeds a title page, a copyright page and a contents page', () async {
      final book = await store.load(projectId);

      expect(book.projectId, projectId);
      expect(
        book.frontMatter.map((section) => section.kind),
        containsAll(<BookSectionKind>[
          BookSectionKind.titlePage,
          BookSectionKind.copyright,
          BookSectionKind.contents,
        ]),
      );
      expect(book.format.id, BookFormatPresets.paperback.id);
    });

    test('optional sections start switched off but present', () async {
      final book = await store.load(projectId);
      final dedication = book.frontMatter
          .firstWhere((s) => s.kind == BookSectionKind.dedication);
      expect(dedication.included, isFalse,
          reason: 'an empty dedication would print as a blank page');
    });
  });

  group('round trip', () {
    test('everything the author set comes back', () async {
      final original = bookFixture(
        format: BookFormatPresets.hardcover,
        parts: const [
          BookPart(
            id: 'part-1',
            startsAtChapterId: 'ch-1',
            title: 'Part One',
            order: 0,
          ),
        ],
      ).copyWith(
        titleOverride: 'A Different Title',
        subtitle: 'A Novel',
      );

      await store.save(original);
      final restored = await store.load(projectId);

      expect(restored.titleOverride, 'A Different Title');
      expect(restored.subtitle, 'A Novel');
      expect(restored.isbn, original.isbn);
      expect(restored.copyrightHolder, original.copyrightHolder);
      expect(restored.format.id, BookFormatPresets.hardcover.id);
      expect(restored.parts, hasLength(1));
      expect(restored.parts.single.startsAtChapterId, 'ch-1');
      expect(restored.frontMatter.length, original.frontMatter.length);
    });

    test('a customised format survives with its provenance', () async {
      final custom = BookFormatPresets.paperback
          .customise()
          .copyWith(trim: TrimSize.sixByNine);
      await store.save(bookFixture().copyWith(format: custom));

      final restored = await store.load(projectId);
      expect(restored.format.basePresetId, 'paperback');
      expect(restored.format.trim, TrimSize.sixByNine);
      expect(restored.format.isCustomised, isTrue);
    });
  });

  group('resilience', () {
    test('a malformed blob opens as a new book rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        BookStore.storageKey(projectId): '{ this is not json',
      });

      final book = await store.load(projectId);
      expect(book.projectId, projectId);
      expect(book.frontMatter, isNotEmpty);
    });

    test('settings copied from another project are re-homed', () async {
      final foreign = bookFixture().copyWith(titleOverride: 'Borrowed');
      SharedPreferences.setMockInitialValues({
        BookStore.storageKey('other-project'):
            jsonEncode(foreign.toJson()),
        BookStore.storageKey('other-project-2'):
            jsonEncode(foreign.toJson()),
      });

      // Load under a project id the blob does not name.
      SharedPreferences.setMockInitialValues({
        BookStore.storageKey('new-project'): jsonEncode(foreign.toJson()),
      });
      final book = await store.load('new-project');

      expect(book.projectId, 'new-project');
      expect(book.titleOverride, 'Borrowed',
          reason: 're-homing keeps the settings, it does not discard them');
    });

    test('the first overwrite keeps a backup', () async {
      await store.save(bookFixture().copyWith(titleOverride: 'First'));
      await store.save(bookFixture().copyWith(titleOverride: 'Second'));

      final preferences = await SharedPreferences.getInstance();
      final backup = preferences.getString(BookStore.backupKey(projectId));
      expect(backup, isNotNull);
      expect(backup, contains('First'));
      expect((await store.load(projectId)).titleOverride, 'Second');
    });
  });

  group('the manuscript is never written', () {
    test('saving a book touches no manuscript key', () async {
      SharedPreferences.setMockInitialValues({
        'author_studio.manuscript_studio.$projectId': '{"untouched":true}',
        'author_studio.manuscript.$projectId': 'untouched',
      });

      await store.save(bookFixture().copyWith(titleOverride: 'New'));

      final preferences = await SharedPreferences.getInstance();
      // Book Studio consumes a manuscript snapshot; it must never write one
      // back while laying a book out.
      expect(preferences.getString('author_studio.manuscript_studio.$projectId'),
          '{"untouched":true}');
      expect(preferences.getString('author_studio.manuscript.$projectId'),
          'untouched');
    });

    test('the storage key is the book\'s own, beside the manuscript\'s',
        () async {
      expect(BookStore.storageKey(projectId),
          'author_studio.book_studio.$projectId');
      expect(BookStore.storageKey(projectId),
          isNot(contains('manuscript')));
    });
  });

  group('title and author resolution', () {
    test('an unset title follows the manuscript when it is renamed', () {
      final manuscript = manuscriptFixture();
      final book = bookFixture().copyWith(titleOverride: '');

      final before = const BookDocumentBuilder()
          .resolveMetadata(manuscript: manuscript, book: book);
      expect(before.title, 'The Widow Knife');

      final renamed = manuscript.copyWith(manuscriptTitle: 'Renamed');
      final after = const BookDocumentBuilder()
          .resolveMetadata(manuscript: renamed, book: book);
      expect(after.title, 'Renamed',
          reason: 'storing a copy would keep printing the old title on the '
              'title page and in every running head');
    });

    test('an explicit override wins over the manuscript title', () {
      final metadata = const BookDocumentBuilder().resolveMetadata(
        manuscript: manuscriptFixture(),
        book: bookFixture().copyWith(titleOverride: 'Chosen'),
      );
      expect(metadata.title, 'Chosen');
    });

    test('an unset author falls back to the profile name', () {
      final metadata = const BookDocumentBuilder().resolveMetadata(
        manuscript: manuscriptFixture(),
        book: bookFixture().copyWith(authorOverride: ''),
        profileAuthorName: 'Profile Name',
      );
      expect(metadata.authorName, 'Profile Name');
    });
  });
}
