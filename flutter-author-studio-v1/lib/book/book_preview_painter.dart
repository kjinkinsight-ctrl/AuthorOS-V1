/// Book Studio Phase 1 — the on-screen page.
///
/// This paints a [LaidOutPage] and nothing more. It performs no line breaking,
/// no measurement and no pagination: every glyph position was decided by
/// [BookLayoutEngine], which measured with the same TrueType files the PDF
/// exporter embeds. That is the whole reason the preview can be trusted —
/// what an author sees here is the page they will get, not a similar-looking
/// approximation.
///
/// `TextPainter` appears below only to *draw* a line the engine already broke,
/// and to find the drawn ascent so the glyphs sit on the engine's baseline.
library;

import 'package:flutter/material.dart';

import 'book_format.dart';
import 'book_layout.dart';

/// Maps a book face onto the families `pubspec.yaml` registers.
///
/// The same TrueType files back both this and the PDF, so a line drawn here
/// occupies the same width it will occupy in the export.
TextStyle bookTextStyle(
  BookFontFace face,
  double sizePt, {
  required Color color,
}) {
  final resolved = face.style;
  return TextStyle(
    fontFamily: switch (face.family) {
      BookFontFamilyId.merriweather => 'Merriweather',
      BookFontFamilyId.inter => 'Inter',
    },
    fontWeight: switch (resolved) {
      BookFontStyleId.bold || BookFontStyleId.boldItalic => FontWeight.w700,
      _ => FontWeight.w400,
    },
    // Italic is not bundled; the engine has already substituted the upright
    // face, so asking for a synthetic slant here would misrepresent the export.
    fontSize: sizePt,
    height: 1.0,
    color: color,
  );
}

/// Paints one page of a laid-out book.
class BookPagePainter extends CustomPainter {
  const BookPagePainter({
    required this.page,
    required this.inkColor,
    required this.paperColor,
    required this.marginaliaColor,
    this.showTextBlockGuide = false,
    this.guideColor,
  });

  final LaidOutPage page;
  final Color inkColor;
  final Color paperColor;
  final Color marginaliaColor;

  /// Draws the text block outline, so an author can see their margins.
  final bool showTextBlockGuide;
  final Color? guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    // One point maps to this many logical pixels.
    final scale = size.width / page.trimWidthPt;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = paperColor,
    );

    if (showTextBlockGuide && guideColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          page.textBlockLeftPt * scale,
          page.textBlockTopPt * scale,
          page.textBlockWidthPt * scale,
          page.textBlockHeightPt * scale,
        ),
        Paint()
          ..color = guideColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    if (page.isBlank) return;

    for (final element in page.elements) {
      switch (element) {
        case LayoutTextLine():
          _paintLine(
            canvas,
            element,
            scale,
            originX: page.textBlockLeftPt,
            originY: page.textBlockTopPt,
            color: inkColor,
          );
        case LayoutDropCap():
          _paintText(
            canvas,
            element.glyph,
            bookTextStyle(element.face, element.sizePt * scale,
                color: inkColor),
            x: (page.textBlockLeftPt + element.x) * scale,
            baselineY: (page.textBlockTopPt + element.baselineY) * scale,
          );
        case LayoutRule():
          final y = (page.textBlockTopPt + element.y) * scale;
          canvas.drawLine(
            Offset((page.textBlockLeftPt + element.x) * scale, y),
            Offset(
              (page.textBlockLeftPt + element.x + element.widthPt) * scale,
              y,
            ),
            Paint()
              ..color = inkColor
              ..strokeWidth = element.thicknessPt * scale,
          );
        case LayoutOrnament():
          _paintOrnament(canvas, element, scale);
      }
    }

    // Page furniture carries absolute coordinates, not text-block-relative ones.
    for (final line in page.marginalia) {
      _paintLine(
        canvas,
        line,
        scale,
        originX: 0,
        originY: 0,
        color: marginaliaColor,
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    LayoutTextLine line,
    double scale, {
    required double originX,
    required double originY,
    required Color color,
  }) {
    // A line is one run when set ragged, and one run per word when justified.
    // Every run arrives already placed, so this only draws — which is why the
    // preview cannot disagree with the export about where a word sits.
    for (final run in line.runs) {
      _paintText(
        canvas,
        run.text,
        bookTextStyle(run.face, run.sizePt * scale, color: color),
        x: (originX + line.x + run.xOffsetPt) * scale,
        baselineY: (originY + line.baselineY) * scale,
      );
    }
  }

  /// Draws [text] so its alphabetic baseline lands exactly on [baselineY].
  ///
  /// The line is never re-wrapped: `maxLines: 1` with soft wrapping off means
  /// this can only draw the run the engine produced.
  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style, {
    required double x,
    required double baselineY,
  }) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final ascent =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.paint(canvas, Offset(x, baselineY - ascent));
    painter.dispose();
  }

  void _paintOrnament(Canvas canvas, LayoutOrnament ornament, double scale) {
    final width = ornament.widthPt * scale;
    final unit = width / 12;
    final cx = (page.textBlockLeftPt + ornament.x) * scale + width / 2;
    final cy = (page.textBlockTopPt + ornament.y) * scale;
    final paint = Paint()..color = inkColor;

    void diamond(double x, double y, double radius) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y - radius)
          ..lineTo(x + radius, y)
          ..lineTo(x, y + radius)
          ..lineTo(x - radius, y)
          ..close(),
        paint,
      );
    }

    switch (ornament.ornament) {
      case BookOrnamentId.none:
        return;
      case BookOrnamentId.rule:
        canvas.drawLine(
          Offset(cx - width / 2, cy),
          Offset(cx + width / 2, cy),
          Paint()
            ..color = inkColor
            ..strokeWidth = 0.6 * scale,
        );
      case BookOrnamentId.diamond:
        diamond(cx, cy, unit * 1.4);
      case BookOrnamentId.asterism:
        diamond(cx, cy - unit * 1.6, unit);
        diamond(cx - unit * 2.2, cy + unit * 0.8, unit);
        diamond(cx + unit * 2.2, cy + unit * 0.8, unit);
      case BookOrnamentId.leaf:
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - unit * 2)
            ..cubicTo(cx + unit * 2.4, cy - unit * 1.2, cx + unit * 2.4,
                cy + unit * 1.2, cx, cy + unit * 2)
            ..cubicTo(cx - unit * 2.4, cy + unit * 1.2, cx - unit * 2.4,
                cy - unit * 1.2, cx, cy - unit * 2)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(BookPagePainter oldDelegate) =>
      oldDelegate.page != page ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.paperColor != paperColor ||
      oldDelegate.showTextBlockGuide != showTextBlockGuide;
}

/// One page, drawn at its true aspect ratio with a paper shadow.
class BookPageView extends StatelessWidget {
  const BookPageView({
    super.key,
    required this.page,
    this.width = 320,
    this.showTextBlockGuide = false,
  });

  final LaidOutPage page;
  final double width;
  final bool showTextBlockGuide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = width * (page.trimHeightPt / page.trimWidthPt);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(width, height),
        painter: BookPagePainter(
          page: page,
          // Book pages are ink on paper whatever the app theme is: showing an
          // author a dark-mode page would misrepresent what gets printed.
          inkColor: const Color(0xFF141414),
          paperColor: const Color(0xFFFCFBF7),
          marginaliaColor: const Color(0xFF5A5A5A),
          showTextBlockGuide: showTextBlockGuide,
          guideColor: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// The preview surface: single pages or facing pairs, with zoom.
class BookPreviewSurface extends StatelessWidget {
  const BookPreviewSurface({
    super.key,
    required this.book,
    required this.pageIndex,
    this.spread = false,
    this.pageWidth = 320,
    this.showTextBlockGuide = false,
  });

  final PaginatedBook book;
  final int pageIndex;

  /// Show the recto and verso an open book would present together.
  final bool spread;

  final double pageWidth;
  final bool showTextBlockGuide;

  @override
  Widget build(BuildContext context) {
    if (book.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = pageIndex.clamp(0, book.pages.length - 1);

    if (!spread) {
      return BookPageView(
        page: book.pages[index],
        width: pageWidth,
        showTextBlockGuide: showTextBlockGuide,
      );
    }

    // A spread pairs a verso on the left with the recto that faces it, so the
    // left page of a spread is always the even-indexed one.
    final leftIndex = index.isEven ? index - 1 : index;
    final rightIndex = leftIndex + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leftIndex >= 0)
          BookPageView(
            page: book.pages[leftIndex],
            width: pageWidth,
            showTextBlockGuide: showTextBlockGuide,
          )
        else
          SizedBox(
            width: pageWidth,
            height: pageWidth *
                (book.pages[index].trimHeightPt /
                    book.pages[index].trimWidthPt),
          ),
        const SizedBox(width: 2),
        if (rightIndex < book.pages.length)
          BookPageView(
            page: book.pages[rightIndex],
            width: pageWidth,
            showTextBlockGuide: showTextBlockGuide,
          ),
      ],
    );
  }
}
