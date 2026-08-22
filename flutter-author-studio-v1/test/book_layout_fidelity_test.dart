/// Guards the one property Book Studio's promise rests on: what the author
/// sees in the preview is what comes out of the exporter.
///
/// That holds only while a single engine owns every line break and every page
/// break, and both renderers do nothing but paint its output. The moment a
/// renderer starts measuring text or splitting it, the two can disagree about
/// where a page ends — silently, and only visibly in a proof copy. These tests
/// fail the build instead.
library;

import 'dart:io';

import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_pdf_renderer.dart';
import 'package:author_studio_v1/book/book_preview_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

/// The two files that are allowed to draw a book, and forbidden to lay one out.
const _rendererSources = <String>[
  'lib/book/book_pdf_renderer.dart',
  'lib/book/book_preview_painter.dart',
];

/// Symbols that would mean a renderer had started deciding layout for itself.
const _bannedInRenderers = <String, String>{
  'BookLayoutEngine':
      'a renderer must consume a PaginatedBook, never produce one',
  'advanceEm': 'measuring text in a renderer lets it disagree with the engine',
  'advancePt': 'measuring text in a renderer lets it disagree with the engine',
  'stringMetrics':
      'measuring text in a renderer lets it disagree with the engine',
  'BookFontMetrics':
      'the engine owns measurement; a renderer only paints what it produced',
  'RegExp': 'splitting text in a renderer means it is re-breaking lines',
  'wordSpace':
      'PDF ignores Tw for the composite fonts this app embeds, so a renderer '
          'that leans on word spacing justifies on screen and not on paper; '
          'the engine places each word instead',
  'wordSpacing':
      'the engine places justified words itself, so a renderer must not apply '
          'its own word spacing on top',
};

/// Strips comments so the scan reads code, not prose.
///
/// The renderers document what they must not do, and naming the engine in a doc
/// comment is exactly how that rule stays discoverable.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reflowable output never inherits print pagination', () {
    test('the EPUB exporter builds from the book, not from its pages', () {
      final source =
          _withoutComments(File('lib/book/book_epub_exporter.dart')
              .readAsStringSync());

      // An EPUB reflows to the reader's own screen and type size, so a print
      // layout's page breaks are not merely unnecessary there — they are wrong.
      // That is why BookDocument exists as a stage of its own.
      for (final banned in const [
        'PaginatedBook',
        'LaidOutPage',
        'BookLayoutEngine',
        'book_layout.dart',
      ]) {
        expect(source.contains(banned), isFalse,
            reason: 'book_epub_exporter.dart references $banned; a reflowable '
                'format must consume BookDocument only');
      }
      expect(source, contains('BookDocument'));
    });
  });

  group('the engine is the only thing that lays a book out', () {
    test('no renderer measures or breaks text', () {
      for (final path in _rendererSources) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        final source = _withoutComments(file.readAsStringSync());

        for (final entry in _bannedInRenderers.entries) {
          expect(
            source.contains(entry.key),
            isFalse,
            reason: '$path references ${entry.key}: ${entry.value}',
          );
        }
      }
    });

    test('the preview never re-wraps a line it is given', () {
      final source =
          File('lib/book/book_preview_painter.dart').readAsStringSync();
      // A TextPainter that could wrap is a TextPainter that could disagree with
      // the engine about how many lines a paragraph takes.
      final code = _withoutComments(source);
      expect(code, contains('maxLines: 1'));
      expect(code, isNot(contains('softWrap: true')));
    });
  });

  group('preview and export describe the same book', () {
    late BookFontAssets assets;

    setUpAll(() async {
      BookFontAssets.resetCache();
      assets = await BookFontAssets.load();
    });

    PaginatedBook paginate(BookFormat format) {
      final book = bookFixture(format: format);
      final document = const BookDocumentBuilder().build(
        manuscript: longManuscriptFixture(paragraphs: 12),
        book: book,
        profileAuthorName: 'Kali Vale',
      );
      return BookLayoutEngine(PdfBookFontMetrics(assets))
          .layout(document, format);
    }

    testWidgets('every laid-out page is one preview page and one PDF page',
        (tester) async {
      final book = paginate(BookFormatPresets.paperback);
      expect(book.pageCount, greaterThan(2));

      // The exporter writes one PDF page per laid-out page.
      final bytes = await const BookPdfRenderer().render(book, assets);
      final pdfPages = RegExp(r'/Type\s*/Page[^s]')
          .allMatches(String.fromCharCodes(bytes))
          .length;
      expect(pdfPages, book.pageCount);

      // The preview builds one page widget per laid-out page.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final page in book.pages)
                    BookPageView(page: page, width: 200),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BookPageView), findsNWidgets(book.pageCount));
    });

    testWidgets('a preview page keeps the trim size the PDF will use',
        (tester) async {
      final book = paginate(BookFormatPresets.hardcover);
      final page = book.pages.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: BookPageView(page: page, width: 216)),
          ),
        ),
      );

      // Scoped to the page widget: Material draws with CustomPaint too.
      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(BookPageView),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(size.width, closeTo(216, 0.5));
      expect(
        size.height / size.width,
        closeTo(page.trimHeightPt / page.trimWidthPt, 0.001),
        reason: 'the preview page must have the trim size aspect ratio',
      );
    });

    testWidgets('the preview renders without throwing on every preset',
        (tester) async {
      for (final preset in BookFormatPresets.paginated) {
        final book = paginate(preset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BookPreviewSurface(
                  book: book,
                  pageIndex: book.pageCount ~/ 2,
                  spread: true,
                  pageWidth: 180,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${preset.label} failed to preview');
      }
    });
  });
}
