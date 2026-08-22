/// Book Studio Phase 1 — PDF output.
///
/// This renderer makes no layout decisions. Every line has already been broken,
/// justified and positioned by [BookLayoutEngine]; all that happens here is a
/// coordinate flip from the engine's top-left origin to the PDF's bottom-left
/// one, and a `drawString` per element.
///
/// That division is what keeps the on-screen preview honest. If this file ever
/// starts measuring text, the preview and the export can disagree about where a
/// page ends — so `test/book_layout_fidelity_test.dart` fails the build if it
/// does.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:pdf/pdf.dart';
import 'package:xml/xml.dart';

import 'book_fonts.dart';
import 'book_format.dart';
import 'book_layout.dart';

class BookPdfRenderer {
  const BookPdfRenderer();

  /// The creation date written when the caller names none.
  ///
  /// The same pinned instant `lib/archive/authoros_archive.dart` and the EPUB
  /// exporter use. A book exported twice has to be the same file both times,
  /// and a wall clock is the one thing guaranteed to differ.
  static final DateTime epoch = DateTime.utc(2000);

  /// Renders [book] to PDF bytes.
  ///
  /// [assets] supplies the TrueType data. The fonts are rebuilt against this
  /// document — a `PdfFont` belongs to the document it was created in — but they
  /// are parsed from the same bytes the measurement pass used, so the metrics
  /// are identical and nothing shifts.
  ///
  /// [modified] fills the document's creation date. Pass the manuscript's own
  /// `updatedAt`, as the EPUB and DOCX exporters are passed, so that an
  /// unchanged book exports the same bytes twice.
  Future<Uint8List> render(
    PaginatedBook book,
    BookFontAssets assets, {
    String producer = 'AuthorOS Book Studio',
    DateTime? modified,
  }) async {
    final document = _DeterministicPdfDocument(
      _documentId(book, producer, (modified ?? epoch).toUtc()),
    );
    final info = PdfInfo(
      document,
      title: book.metadata.title,
      author: book.metadata.authorName.isEmpty
          ? null
          : book.metadata.authorName,
      creator: producer,
      subject: book.format.label,
      producer: producer,
    );

    // `PdfInfo` hardcodes `'/CreationDate': PdfString.fromDate(DateTime.now())`
    // with no way to override it, so two exports of an unchanged book differ by
    // a timestamp alone. `PdfString` is not exported from `package:pdf`, so the
    // entry cannot be rewritten without reaching into the package's `src/`.
    // It is dropped instead — the key is optional in the specification — and
    // the date is written into the XMP packet below, which is the channel a
    // reader, a library catalogue and PDF/A all prefer anyway.
    //
    // The other `DateTime.now()` in `package:pdf` sits in the xref table behind
    // `assert(() { if (settings.verbose) ... })`, and verbose defaults off, so
    // it never reaches the output.
    info.params.values.remove('/CreationDate');
    PdfMetadata(document, _xmp(book, producer, (modified ?? epoch).toUtc()));

    final fonts = <BookFontFace, PdfFont>{};
    PdfFont fontFor(BookFontFace face) => fonts.putIfAbsent(face, () {
          final bytes = assets.bytesFor(face) ??
              assets.bytesFor(BookFontAssets.fallbackFace);
          if (bytes == null) {
            throw StateError(
              'No font available for $face and no fallback is bundled.',
            );
          }
          return PdfTtfFont(document, bytes);
        });

    for (final page in book.pages) {
      _renderPage(document, page, fontFor);
    }

    return document.save();
  }

  /// The XMP packet, which carries the metadata `/CreationDate` used to.
  ///
  /// Built with `XmlBuilder` rather than a string template for the same reason
  /// the EPUB and DOCX exporters are: this carries the author's own title and
  /// name, and a book called "Smith & Sons" must not produce a file that fails
  /// to parse.
  XmlDocument _xmp(PaginatedBook book, String producer, DateTime modified) {
    final stamp = _timestamp(modified);
    final builder = XmlBuilder();

    // The magic id is fixed by the XMP specification; it is how a reader finds
    // the packet by scanning raw bytes.
    builder.processing(
      'xpacket',
      'begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"',
    );
    builder.element('x:xmpmeta', namespaceUris: {
      'x': 'adobe:ns:meta/',
    }, nest: () {
      builder.element('rdf:RDF', namespaceUris: {
        'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      }, nest: () {
        builder.element('rdf:Description', namespaceUris: {
          'dc': 'http://purl.org/dc/elements/1.1/',
          'xmp': 'http://ns.adobe.com/xap/1.0/',
          'pdf': 'http://ns.adobe.com/pdf/1.3/',
        }, nest: () {
          builder.attribute('rdf:about', '');

          if (book.metadata.title.trim().isNotEmpty) {
            // A title is a language alternative in XMP, not a bare string.
            builder.element('dc:title', nest: () {
              builder.element('rdf:Alt', nest: () {
                builder.element('rdf:li', nest: () {
                  builder.attribute('xml:lang', 'x-default');
                  builder.text(book.metadata.title.trim());
                });
              });
            });
          }
          if (book.metadata.authorName.trim().isNotEmpty) {
            // And a creator is an ordered sequence, because a book can have
            // more than one author.
            builder.element('dc:creator', nest: () {
              builder.element('rdf:Seq', nest: () {
                builder.element('rdf:li',
                    nest: book.metadata.authorName.trim());
              });
            });
          }
          builder.element('dc:format', nest: 'application/pdf');
          builder.element('xmp:CreateDate', nest: stamp);
          builder.element('xmp:ModifyDate', nest: stamp);
          builder.element('xmp:MetadataDate', nest: stamp);
          builder.element('xmp:CreatorTool', nest: producer);
          builder.element('pdf:Producer', nest: producer);
        });
      });
    });
    // 'w' marks the packet writable in place, which is what a reader that
    // rewrites metadata without re-encoding the file expects to find.
    builder.processing('xpacket', 'end="w"');

    return builder.buildDocument();
  }

  /// `CCYY-MM-DDThh:mm:ssZ`, as XMP wants it and with no fractional seconds.
  static String _timestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }

  void _renderPage(
    PdfDocument document,
    LaidOutPage page,
    PdfFont Function(BookFontFace) fontFor,
  ) {
    final pdfPage = PdfPage(
      document,
      pageFormat: PdfPageFormat(page.trimWidthPt, page.trimHeightPt),
    );
    final canvas = pdfPage.getGraphics();
    canvas.setFillColor(PdfColors.black);

    /// The engine measures down from the top of the text block; PDF measures up
    /// from the foot of the page.
    double flip(double y) => page.trimHeightPt - (page.textBlockTopPt + y);

    for (final element in page.elements) {
      switch (element) {
        case LayoutTextLine():
          _drawLine(canvas, page, element, fontFor, flip);
        case LayoutDropCap():
          canvas.drawString(
            fontFor(element.face),
            element.sizePt,
            element.glyph,
            page.textBlockLeftPt + element.x,
            flip(element.baselineY),
          );
        case LayoutRule():
          canvas
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(element.thicknessPt)
            ..moveTo(page.textBlockLeftPt + element.x, flip(element.y))
            ..lineTo(
              page.textBlockLeftPt + element.x + element.widthPt,
              flip(element.y),
            )
            ..strokePath();
        case LayoutOrnament():
          _drawOrnament(canvas, page, element, flip);
      }
    }

    _drawMarginalia(canvas, page, fontFor);
  }

  void _drawLine(
    PdfGraphics canvas,
    LaidOutPage page,
    LayoutTextLine line,
    PdfFont Function(BookFontFace) fontFor,
    double Function(double) flip,
  ) {
    // A line is one run when set ragged, and one run per word when justified.
    // Either way every run arrives already placed, so this only draws.
    for (final run in line.runs) {
      canvas.drawString(
        fontFor(run.face),
        run.sizePt,
        run.text,
        page.textBlockLeftPt + line.x + run.xOffsetPt,
        flip(line.baselineY),
      );
    }
  }

  /// Ornaments are drawn as paths because neither bundled face carries ornament
  /// glyphs — a character like U+2767 would render as tofu.
  void _drawOrnament(
    PdfGraphics canvas,
    LaidOutPage page,
    LayoutOrnament ornament,
    double Function(double) flip,
  ) {
    final left = page.textBlockLeftPt + ornament.x;
    final y = flip(ornament.y);
    final width = ornament.widthPt;
    final unit = width / 12;
    canvas.setFillColor(PdfColors.black);

    switch (ornament.ornament) {
      case BookOrnamentId.none:
        return;
      case BookOrnamentId.rule:
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(0.6)
          ..moveTo(left, y)
          ..lineTo(left + width, y)
          ..strokePath();
      case BookOrnamentId.diamond:
        _diamond(canvas, left + width / 2, y, unit * 1.4);
        canvas.fillPath();
      case BookOrnamentId.asterism:
        // Three diamonds in a triangle, the classic section mark.
        _diamond(canvas, left + width / 2, y + unit * 1.6, unit);
        _diamond(canvas, left + width / 2 - unit * 2.2, y - unit * 0.8, unit);
        _diamond(canvas, left + width / 2 + unit * 2.2, y - unit * 0.8, unit);
        canvas.fillPath();
      case BookOrnamentId.leaf:
        canvas
          ..moveTo(left + width / 2, y + unit * 2)
          ..curveTo(
            left + width / 2 + unit * 2.4, y + unit * 1.2,
            left + width / 2 + unit * 2.4, y - unit * 1.2,
            left + width / 2, y - unit * 2,
          )
          ..curveTo(
            left + width / 2 - unit * 2.4, y - unit * 1.2,
            left + width / 2 - unit * 2.4, y + unit * 1.2,
            left + width / 2, y + unit * 2,
          )
          ..fillPath();
    }
  }

  void _diamond(PdfGraphics canvas, double cx, double cy, double radius) {
    canvas
      ..moveTo(cx, cy + radius)
      ..lineTo(cx + radius, cy)
      ..lineTo(cx, cy - radius)
      ..lineTo(cx - radius, cy)
      ..lineTo(cx, cy + radius);
  }

  /// Paints the running head and folio the engine already positioned.
  ///
  /// Their coordinates are absolute from the page's top-left corner, so they use
  /// the page flip rather than the text block's.
  void _drawMarginalia(
    PdfGraphics canvas,
    LaidOutPage page,
    PdfFont Function(BookFontFace) fontFor,
  ) {
    for (final line in page.marginalia) {
      canvas.setFillColor(PdfColors.grey800);
      for (final run in line.runs) {
        canvas.drawString(
          fontFor(run.face),
          run.sizePt,
          run.text,
          line.x + run.xOffsetPt,
          page.trimHeightPt - line.baselineY,
        );
      }
      canvas.setFillColor(PdfColors.black);
    }
  }
}

/// A document whose `/ID` is derived from the book rather than from the clock.
///
/// `PdfDocument.documentID` is `sha256(DateTime.now() + 32 random bytes)`,
/// which alone would make every export of an unchanged book a different file.
/// The trailer `/ID` exists to identify a particular file, so it should differ
/// between two different books and match between two exports of one — which is
/// exactly what deriving it from the book's own content gives.
class _DeterministicPdfDocument extends PdfDocument {
  _DeterministicPdfDocument(this._id);

  final Uint8List _id;

  @override
  Uint8List get documentID => _id;
}

Uint8List _documentId(PaginatedBook book, String producer, DateTime modified) {
  final seed = [
    book.metadata.title,
    book.metadata.authorName,
    book.metadata.isbn,
    book.format.id,
    '${book.pageCount}',
    producer,
    modified.toIso8601String(),
  ].join('\u0000');
  return Uint8List.fromList(sha256.convert(utf8.encode(seed)).bytes);
}
