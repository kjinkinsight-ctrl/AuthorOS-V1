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

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:pdf/pdf.dart';

import 'book_fonts.dart';
import 'book_format.dart';
import 'book_layout.dart';

class BookPdfRenderer {
  const BookPdfRenderer();

  /// Renders [book] to PDF bytes.
  ///
  /// [assets] supplies the TrueType data. The fonts are rebuilt against this
  /// document — a `PdfFont` belongs to the document it was created in — but they
  /// are parsed from the same bytes the measurement pass used, so the metrics
  /// are identical and nothing shifts.
  Future<Uint8List> render(
    PaginatedBook book,
    BookFontAssets assets, {
    String producer = 'AuthorOS Book Studio',
  }) async {
    final document = PdfDocument();
    PdfInfo(
      document,
      title: book.metadata.title,
      author: book.metadata.authorName.isEmpty
          ? null
          : book.metadata.authorName,
      creator: producer,
      subject: book.format.label,
      producer: producer,
    );

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
