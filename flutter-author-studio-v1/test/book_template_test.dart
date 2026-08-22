import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_template.dart';
import 'package:author_studio_v1/book/epub_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

final DateTime _when = DateTime.utc(2026, 3, 4);

/// A fully-filled book, so that anything a template wrongly carries shows up.
BookProject bookOne() => BookProject(
      projectId: 'book-one',
      titleOverride: 'The Widow Knife',
      authorOverride: 'Kali Vale',
      subtitle: 'A Novel',
      seriesName: 'The Ash Cycle',
      seriesNumber: '1',
      isbn: '978-1-0000-0000-0',
      publisher: 'Ink & Insight',
      copyrightYear: '2026',
      copyrightHolder: 'Kali Vale',
      edition: 'First Edition',
      rightsStatement: 'All rights reserved.',
      frontMatter: [
        ...BookProject.defaultFrontMatter().map(
          (s) => s.id == 'front-dedication'
              ? s.copyWith(body: 'For Ana, who read it first.', included: true)
              : s,
        ),
      ],
      backMatter: BookProject.defaultBackMatter(),
      parts: const [
        BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
      ],
      format: BookFormatPresets.hardcover,
      epub: const EpubSettings(dropCap: true, language: 'en-GB'),
    );

void main() {
  group('capturing a look', () {
    test('takes the format and the ebook settings', () {
      final template =
          BookTemplate.from(bookOne(), name: 'Ash Cycle', createdAt: _when);

      expect(template.format.id, BookFormatPresets.hardcover.id);
      expect(template.epub.dropCap, isTrue);
      expect(template.epub.language, 'en-GB');
    });

    test('takes which sections exist, and never what they say', () {
      final template =
          BookTemplate.from(bookOne(), name: 'Ash Cycle', createdAt: _when);

      expect(template.frontMatter.map((s) => s.kind),
          containsAll(BookProject.defaultFrontMatter().map((s) => s.kind)));
      expect(template.frontMatter.every((s) => s.body.isEmpty), isTrue,
          reason: 'a dedication belongs to one book');
      expect(template.backMatter.every((s) => s.body.isEmpty), isTrue);
    });

    test('names itself by a stable slug, so saving over a name replaces it', () {
      final a = BookTemplate.from(bookOne(), name: 'Ash Cycle', createdAt: _when);
      final b = BookTemplate.from(bookOne(), name: 'Ash Cycle', createdAt: _when);
      expect(a.id, b.id);
      expect(a.id, 'ash-cycle');
    });
  });

  group('what a template must never carry', () {
    // The whole risk of this feature in one test. Every one of these, silently
    // copied into book two, is a way to publish something wrong.
    test('no field that identifies a particular book', () {
      final json = BookTemplate.from(bookOne(),
              name: 'Ash Cycle', createdAt: _when)
          .toJson()
          .toString();

      for (final identity in const [
        '978-1-0000-0000-0', // isbn
        'The Widow Knife', // title
        'Kali Vale', // author and copyright holder
        'First Edition',
        'For Ana, who read it first.', // the dedication's prose
      ]) {
        expect(json, isNot(contains(identity)),
            reason: '$identity must not travel between books');
      }
    });

    test('no parts, because they name another project’s chapters', () {
      final applied = BookTemplate.from(bookOne(),
              name: 'Ash Cycle', createdAt: _when)
          .applyTo(BookProject(projectId: 'book-two'));

      expect(applied.parts, isEmpty,
          reason: 'a part anchored to ch-1 of book one is a dangling part in '
              'book two');
    });
  });

  group('applying a look', () {
    BookProject bookTwo() => BookProject(
          projectId: 'book-two',
          titleOverride: 'The Second Blade',
          isbn: '978-1-1111-1111-1',
          copyrightYear: '2027',
          frontMatter: [
            ...BookProject.defaultFrontMatter().map(
              (s) => s.id == 'front-dedication'
                  ? s.copyWith(body: 'For Rowan.')
                  : s,
            ),
          ],
          format: BookFormatPresets.paperback,
        );

    test('changes the design and leaves the book’s identity alone', () {
      final applied = BookTemplate.from(bookOne(),
              name: 'Ash Cycle', createdAt: _when)
          .applyTo(bookTwo());

      expect(applied.format.id, BookFormatPresets.hardcover.id);
      expect(applied.epub.dropCap, isTrue);

      expect(applied.projectId, 'book-two');
      expect(applied.titleOverride, 'The Second Blade');
      expect(applied.isbn, '978-1-1111-1111-1');
      expect(applied.copyrightYear, '2027');
    });

    test('keeps prose the second book had already written', () {
      final applied = BookTemplate.from(bookOne(),
              name: 'Ash Cycle', createdAt: _when)
          .applyTo(bookTwo());

      final dedication = applied.frontMatter
          .firstWhere((s) => s.id == 'front-dedication');
      expect(dedication.body, 'For Rowan.',
          reason: 'applying a design must not delete the author’s writing');
    });

    test('carries which sections are switched on', () {
      final source = bookOne().copyWith(
        frontMatter: BookProject.defaultFrontMatter()
            .map((s) =>
                s.id == 'front-contents' ? s.copyWith(included: false) : s)
            .toList(),
      );
      final applied = BookTemplate.from(source, name: 'x', createdAt: _when)
          .applyTo(bookTwo());

      expect(
          applied.frontMatter
              .firstWhere((s) => s.id == 'front-contents')
              .included,
          isFalse);
    });

    test('a template with no matter leaves the book’s own alone', () {
      final bare = BookTemplate(
          id: 'bare', name: 'Bare', createdAt: _when,
          format: BookFormatPresets.largePrint);
      final applied = bare.applyTo(bookTwo());

      expect(applied.format.id, BookFormatPresets.largePrint.id);
      expect(applied.frontMatter, hasLength(bookTwo().frontMatter.length));
    });
  });

  group('storage', () {
    test('round-trips through JSON', () {
      final template = BookTemplate.from(
          bookFixture(format: BookFormatPresets.largePrint),
          name: 'Large Print House Style',
          createdAt: _when);

      final decoded =
          BookTemplate.fromJson(Map<String, dynamic>.from(template.toJson()));

      expect(decoded.id, template.id);
      expect(decoded.name, 'Large Print House Style');
      expect(decoded.createdAt, _when);
      expect(decoded.format.toJson(), template.format.toJson());
      expect(decoded.frontMatter.map((s) => s.kind),
          template.frontMatter.map((s) => s.kind));
    });

    test('a mangled blob decodes to defaults rather than throwing', () {
      final decoded = BookTemplate.fromJson({'name': 'Half a template'});
      expect(decoded.name, 'Half a template');
      expect(decoded.format.id, BookFormatPresets.paperback.id);
      expect(decoded.epub.language, EpubSettings.defaults.language);
    });

    test('the key is global, because a per-project template is useless', () {
      expect(BookTemplateStore.storageKey, 'author_studio.book_templates');
      expect(BookTemplateStore.storageKey, isNot(contains(r'$')));
    });
  });
}
