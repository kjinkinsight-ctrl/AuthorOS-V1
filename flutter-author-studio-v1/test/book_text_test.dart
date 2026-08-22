import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_text_exporter.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

String exportText({
  TextExportStyle style = TextExportStyle.readable,
  BookFormat? format,
  List<BookPart> parts = const [],
  ManuscriptProjectSummary? manuscript,
}) {
  final project = bookFixture(format: format, parts: parts);
  final document = const BookDocumentBuilder().build(
    manuscript: manuscript ?? manuscriptFixture(),
    book: project,
    profileAuthorName: 'Kali Vale',
  );
  return const BookTextExporter().export(
    document: document,
    style: style,
    format: format ?? BookFormatPresets.paperback,
  );
}

void main() {
  group('the file itself', () {
    test('uses \\n everywhere, on every platform', () {
      expect(exportText(), isNot(contains('\r')),
          reason: 'a CR would make the export differ between platforms');
    });

    test('ends with exactly one newline', () {
      final text = exportText();
      expect(text, endsWith('\n'));
      expect(text, isNot(endsWith('\n\n')));
    });

    test('separates every block with one blank line and no more', () {
      expect(exportText(), isNot(contains('\n\n\n')));
    });

    test('the same book exports the same text', () {
      expect(exportText(), equals(exportText()));
    });

    test('a book with nothing in it is an empty file, not a stray newline', () {
      final document = const BookDocumentBuilder().build(
        manuscript: ManuscriptProjectSummary(
          projectId: 'empty',
          manuscriptTitle: '',
          currentChapterId: '',
          currentSceneId: '',
          createdAt: fixtureTimestamp,
          updatedAt: fixtureTimestamp,
          version: 1,
          chapters: const [],
        ),
        book: const BookProject(projectId: 'empty'),
      );
      expect(
        const BookTextExporter().export(document: document),
        isEmpty,
      );
    });
  });

  group('readable', () {
    test('reads in book order', () {
      final text = exportText(parts: const [
        BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
      ]);

      expect(text, startsWith('The Widow Knife'));
      expect(text.indexOf('Part One'),
          lessThan(text.indexOf('Chapter 1: The Arrival')));
      expect(text.indexOf('Chapter 1: The Arrival'),
          lessThan(text.indexOf('Chapter 2: The Blood Price')));
    });

    test('names a chapter the way the book names it', () {
      expect(exportText(format: BookFormatPresets.paperback),
          contains('Chapter 1: The Arrival'));
      // The hardcover preset spells its chapter numbers out, and the text file
      // has to say the same thing the printed page does.
      expect(exportText(format: BookFormatPresets.hardcover),
          contains('Chapter One: The Arrival'));
    });

    test('a contents page lists the chapters rather than an empty heading', () {
      final text = exportText(parts: const [
        BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
      ]);
      final contents = text.split('Contents\n\n')[1].split('Part One\n\n')[1];

      // Indented under their part, because that is what a contents page does.
      expect(contents, startsWith('  Chapter 1: The Arrival'));
    });

    test('a blank-line scene break is the blank line, not a stray glyph', () {
      final text = exportText(format: BookFormatPresets.paperback);
      expect(BookFormatPresets.paperback.chapter.sceneBreak,
          SceneBreakStyle.blankLine);
      expect(text, isNot(contains('* * *')));
    });

    test('a glyph scene break is printed, because losing it changes the read',
        () {
      final format = BookFormatPresets.paperback.copyWith(
        chapter: BookFormatPresets.paperback.chapter.copyWith(
          sceneBreak: SceneBreakStyle.glyph,
          sceneBreakGlyph: '* * *',
        ),
      );
      expect(exportText(format: format), contains('\n* * *\n'));
    });

    test('an ornament falls back to the glyph, since text cannot draw', () {
      final format = BookFormatPresets.paperback.copyWith(
        chapter: BookFormatPresets.paperback.chapter.copyWith(
          sceneBreak: SceneBreakStyle.ornament,
          sceneBreakGlyph: '',
        ),
      );
      expect(exportText(format: format), contains('* * *'));
    });

    test('the author’s own characters are written through untouched', () {
      final text = exportText(
        manuscript: manuscriptFixtureWithProse(
          'Smith & Sons said "go" <now> — 5 < 6 and it’s done.',
        ),
      );
      expect(text, contains('Smith & Sons said "go" <now> — 5 < 6 and it’s '
          'done.'));
    });
  });

  group('prose only', () {
    test('carries no headings, no matter and no scene marks', () {
      final text = exportText(
        style: TextExportStyle.manuscriptOnly,
        parts: const [
          BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
        ],
      );

      for (final heading in const [
        'The Widow Knife',
        'Copyright',
        'Contents',
        'Part One',
        'The Arrival',
        'ISBN',
      ]) {
        expect(text, isNot(contains(heading)),
            reason: '$heading is not prose');
      }
    });

    test('carries every paragraph of prose, in order', () {
      final text = exportText(
        style: TextExportStyle.manuscriptOnly,
        manuscript: longManuscriptFixture(paragraphs: 5),
      );
      expect(text.trim().split('\n\n'), hasLength(5));
    });

    test('counts the same words the book does', () {
      final document = const BookDocumentBuilder().build(
        manuscript: manuscriptFixture(),
        book: bookFixture(),
        profileAuthorName: 'Kali Vale',
      );
      final words = const BookTextExporter()
          .export(document: document, style: TextExportStyle.manuscriptOnly)
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;

      expect(words, document.wordCount,
          reason: 'a word count taken from this file must match the studio');
    });
  });
}
