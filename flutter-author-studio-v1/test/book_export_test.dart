import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_pdf_renderer.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

class _MemoryBookFileSaver implements BookFileSaver {
  String? name;
  Uint8List? bytes;
  BookExportFormat? format;

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
    required BookExportFormat format,
  }) async {
    name = suggestedName;
    this.bytes = bytes;
    this.format = format;
    return 'C:/Exports/$suggestedName';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookFontAssets assets;

  setUpAll(() async {
    BookFontAssets.resetCache();
    assets = await BookFontAssets.load();
  });

  PaginatedBook paginate({BookFormat? format}) {
    final book = bookFixture(format: format);
    final document = const BookDocumentBuilder().build(
      manuscript: manuscriptFixture(),
      book: book,
      profileAuthorName: 'Kali Vale',
    );
    return BookLayoutEngine(PdfBookFontMetrics(assets))
        .layout(document, format ?? book.format);
  }

  group('font loading', () {
    test('every bundled face loads and measures', () {
      final metrics = PdfBookFontMetrics(assets);
      for (final face in assets.availableFaces) {
        expect(metrics.advanceEm('The quick brown fox', face),
            greaterThan(0));
        expect(metrics.ascentEm(face), greaterThan(0));
        expect(metrics.descentEm(face), greaterThan(0));
      }
    });

    test('an unshipped face degrades instead of failing', () {
      final metrics = PdfBookFontMetrics(assets);
      const italic = BookFontFace.merriweatherItalic;

      final resolved = metrics.resolve(italic);
      expect(resolved, BookFontFace.merriweatherRegular,
          reason: 'italic is not bundled, so the upright face stands in');
      expect(metrics.substitutions, contains(italic));
      expect(metrics.advanceEm('text', italic), greaterThan(0));
    });

    test('a glyph advance scales linearly with point size', () {
      final metrics = PdfBookFontMetrics(assets);
      const face = BookFontFace.merriweatherRegular;
      final at11 = metrics.advancePt('measure', face, 11);
      final at22 = metrics.advancePt('measure', face, 22);
      expect(at22, closeTo(at11 * 2, 0.0001));
    });
  });

  group('pdf rendering', () {
    test('produces a real PDF document', () async {
      final book = paginate();
      final bytes = await const BookPdfRenderer().render(book, assets);

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(String.fromCharCodes(bytes.sublist(bytes.length - 512))
          .contains('%%EOF'), isTrue);
    });

    test('writes exactly one page per laid-out page', () async {
      final book = paginate();
      final bytes = await const BookPdfRenderer().render(book, assets);

      // Every page object the renderer writes carries /Type /Page.
      final text = String.fromCharCodes(bytes);
      final pageObjects = RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
      expect(pageObjects, book.pageCount,
          reason: 'the PDF must have the same number of pages as the preview');
    });

    test('carries the book metadata', () async {
      final book = paginate();
      final bytes = await const BookPdfRenderer().render(book, assets);
      final text = String.fromCharCodes(bytes);

      expect(text, contains('The Widow Knife'));
      expect(text, contains('Kali Vale'));
    });

    test('every paginated preset renders', () async {
      for (final preset in BookFormatPresets.paginated) {
        final book = paginate(format: preset);
        final bytes = await const BookPdfRenderer().render(book, assets);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
            reason: '${preset.label} did not render');
      }
    });

    test('the print preset emits the blank pages a printer expects', () async {
      final book = paginate(format: BookFormatPresets.printOnDemand);
      expect(book.stats.blankPageCount, greaterThan(0));

      // A blank page is still a page in the file: dropping it would put every
      // later chapter on the wrong side of the paper.
      final bytes = await const BookPdfRenderer().render(book, assets);
      final pageObjects = RegExp(r'/Type\s*/Page[^s]')
          .allMatches(String.fromCharCodes(bytes))
          .length;
      expect(pageObjects, book.pageCount);
    });

    test('the ebook preset produces no blank pages', () async {
      final book = paginate(format: BookFormatPresets.ebook);
      expect(book.stats.blankPageCount, 0,
          reason: 'a blank verso is a print artefact and reads as a bug on a '
              'screen');
    });
  });

  group('file saving', () {
    test('an export reaches the saver with the right name and type', () async {
      final saver = _MemoryBookFileSaver();
      final book = paginate();
      final bytes = await const BookPdfRenderer().render(book, assets);
      final name = suggestedBookFilename(
        title: book.metadata.title,
        format: BookExportFormat.printPdf,
      );

      final path = await saver.save(
        suggestedName: name,
        bytes: bytes,
        format: BookExportFormat.printPdf,
      );

      expect(path, 'C:/Exports/the-widow-knife-print.pdf');
      expect(saver.name, 'the-widow-knife-print.pdf');
      expect(saver.format, BookExportFormat.printPdf);
      expect(saver.bytes, isNotNull);
    });

    test('filenames are slugified and distinguish print from digital', () {
      expect(
        suggestedBookFilename(
            title: 'The Widow Knife', format: BookExportFormat.digitalPdf),
        'the-widow-knife.pdf',
      );
      expect(
        suggestedBookFilename(title: '  ', format: BookExportFormat.printPdf),
        'book-print.pdf',
      );
    });
  });
}
