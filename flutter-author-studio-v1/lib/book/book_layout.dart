/// Book Studio Phase 1 — the layout engine.
///
/// This is the only place in the app that decides where a line breaks or where
/// a page ends. Both the on-screen preview and the PDF exporter consume the
/// [PaginatedBook] this produces and do nothing but paint it, so they cannot
/// disagree about the shape of the book. That is what makes the preview an
/// honest answer to "what will my finished book look like" rather than a guess.
///
/// [BookLayoutEngine.layout] is a pure function: the same document and format
/// always produce the same [PaginatedBook]. Reproducibility is the property the
/// export milestone is defined against, so it is asserted directly in tests.
library;

import 'book_document.dart';
import 'book_format.dart';
import 'book_fonts.dart';

/// What a page is for.
enum BookPageRole {
  frontMatter,
  partTitle,
  chapterOpener,
  body,
  backMatter,
  blank,
}

/// A run of text in one face at one size.
///
/// Lines hold runs rather than a plain string so that inline emphasis can be
/// introduced later without rewriting the line breaker, both renderers, and the
/// fidelity test. Phase 1 emits a single run per line.
class LayoutTextRun {
  const LayoutTextRun(this.text, this.face, this.sizePt, {this.xOffsetPt = 0});

  final String text;
  final BookFontFace face;
  final double sizePt;

  /// Where this run starts, in points from the line's own x.
  ///
  /// A justified line is emitted as one run per word, each already placed.
  /// The alternative — handing a renderer a single string plus a word-spacing
  /// value — does not survive the trip: the embedded fonts are composite
  /// (`/Type0`), and PDF ignores the `Tw` word-spacing operator for composite
  /// fonts. The preview would have honoured it and the export would have
  /// dropped it, which is exactly the divergence this engine exists to prevent.
  final double xOffsetPt;
}

/// Something to paint, positioned relative to the page's text block.
sealed class LayoutElement {
  const LayoutElement();

  /// Offset from the left edge of the text block, in points.
  double get x;

  /// Offset from the top edge of the text block, in points.
  double get y;
}

/// One fully positioned line of type.
class LayoutTextLine extends LayoutElement {
  const LayoutTextLine({
    required this.runs,
    required this.text,
    required this.x,
    required this.baselineY,
    this.wordSpacingPt = 0,
    this.isLastOfParagraph = false,
    this.paragraphId = '',
    this.widthPt = 0,
  });

  final List<LayoutTextRun> runs;

  @override
  final double x;

  /// The baseline, offset from the top of the text block.
  final double baselineY;

  @override
  double get y => baselineY;

  /// Extra advance added to every space, to justify the line.
  final double wordSpacingPt;

  final bool isLastOfParagraph;

  /// Identifies the paragraph this line came from, for widow and orphan rules.
  final String paragraphId;

  /// The measured width of the set line. Renderers use it for alignment so they
  /// never have to measure text themselves.
  final double widthPt;

  /// The line as written.
  ///
  /// Held directly rather than rebuilt from [runs], because a justified line's
  /// runs are individual words and joining them would lose the spaces.
  final String text;
}

/// A horizontal rule.
class LayoutRule extends LayoutElement {
  const LayoutRule({
    required this.x,
    required this.y,
    required this.widthPt,
    this.thicknessPt = 0.5,
  });

  @override
  final double x;
  @override
  final double y;
  final double widthPt;
  final double thicknessPt;
}

/// A vector ornament.
///
/// Drawn as paths rather than typeset, because the bundled faces carry no
/// ornament glyphs and a character like U+2767 would render as tofu.
class LayoutOrnament extends LayoutElement {
  const LayoutOrnament({
    required this.ornament,
    required this.x,
    required this.y,
    required this.widthPt,
  });

  final BookOrnamentId ornament;
  @override
  final double x;
  @override
  final double y;
  final double widthPt;
}

/// An oversized initial capital.
class LayoutDropCap extends LayoutElement {
  const LayoutDropCap({
    required this.glyph,
    required this.x,
    required this.baselineY,
    required this.sizePt,
    required this.face,
  });

  final String glyph;
  @override
  final double x;
  final double baselineY;
  @override
  double get y => baselineY;
  final double sizePt;
  final BookFontFace face;
}

/// One page of the laid-out book.
///
/// Element coordinates are relative to the text block, and the page carries the
/// text block's absolute position, so a renderer only has to add an offset. The
/// engine works that way because a page's side — and therefore which physical
/// edge the binding margin lands on — is not known until the whole book has
/// been paginated.
class LaidOutPage {
  const LaidOutPage({
    required this.index,
    required this.role,
    required this.elements,
    required this.trimWidthPt,
    required this.trimHeightPt,
    required this.textBlockLeftPt,
    required this.textBlockTopPt,
    required this.textBlockWidthPt,
    required this.textBlockHeightPt,
    required this.isRecto,
    this.folio,
    this.runningHead,
    this.marginalia = const [],
    this.anchorChapterId,
    this.isBlank = false,
  });

  /// 0-based physical position in the book. Page 1 is index 0 and is a recto.
  final int index;

  final BookPageRole role;
  final List<LayoutElement> elements;

  final double trimWidthPt;
  final double trimHeightPt;
  final double textBlockLeftPt;
  final double textBlockTopPt;
  final double textBlockWidthPt;
  final double textBlockHeightPt;

  final bool isRecto;
  bool get isVerso => !isRecto;

  /// The rendered folio, or null when this page carries none.
  final String? folio;

  /// The running head text, or null when this page carries none.
  final String? runningHead;

  /// The running head and folio, already positioned.
  ///
  /// Unlike [elements], these coordinates are absolute from the page's top-left
  /// corner, because page furniture sits outside the text block. The engine
  /// positions them so that no renderer has to measure a string.
  final List<LayoutTextLine> marginalia;

  final String? anchorChapterId;
  final bool isBlank;

  double get textBlockRightPt => textBlockLeftPt + textBlockWidthPt;
  double get textBlockBottomPt => textBlockTopPt + textBlockHeightPt;
}

/// One line of the table of contents.
class TocEntry {
  const TocEntry({
    required this.title,
    required this.folio,
    required this.level,
    this.chapterId,
    this.pageIndex = 0,
  });

  final String title;

  /// The folio as printed, which is not the physical page index.
  final String folio;

  /// 0 for a part, 1 for a chapter.
  final int level;

  final String? chapterId;
  final int pageIndex;
}

/// Something the engine noticed while laying the book out.
class BookLayoutIssue {
  const BookLayoutIssue(this.code, this.message, {this.pageIndex});

  final String code;
  final String message;
  final int? pageIndex;

  @override
  String toString() =>
      '[$code]${pageIndex == null ? '' : ' p${pageIndex! + 1}'} $message';
}

/// Counts worth showing the author, and worth watching in tests.
class BookLayoutStats {
  const BookLayoutStats({
    required this.pageCount,
    required this.blankPageCount,
    required this.frontMatterPageCount,
    required this.bodyPageCount,
    required this.backMatterPageCount,
    required this.wordCount,
    required this.riverCount,
    required this.passes,
    this.elapsed = Duration.zero,
  });

  final int pageCount;
  final int blankPageCount;
  final int frontMatterPageCount;
  final int bodyPageCount;
  final int backMatterPageCount;
  final int wordCount;
  final int riverCount;

  /// How many times the engine had to paginate. More than one means the binding
  /// allowance changed the measure and the book had to be re-flowed.
  final int passes;

  final Duration elapsed;

  BookLayoutStats withElapsed(Duration value) => BookLayoutStats(
        pageCount: pageCount,
        blankPageCount: blankPageCount,
        frontMatterPageCount: frontMatterPageCount,
        bodyPageCount: bodyPageCount,
        backMatterPageCount: backMatterPageCount,
        wordCount: wordCount,
        riverCount: riverCount,
        passes: passes,
        elapsed: value,
      );
}

/// A book, fully paginated.
class PaginatedBook {
  const PaginatedBook({
    required this.pages,
    required this.toc,
    required this.stats,
    required this.metadata,
    required this.format,
    this.issues = const [],
  });

  final List<LaidOutPage> pages;
  final List<TocEntry> toc;
  final BookLayoutStats stats;
  final BookMetadata metadata;
  final BookFormat format;
  final List<BookLayoutIssue> issues;

  int get pageCount => pages.length;

  /// The physical index of the page a chapter opens on.
  int? pageIndexForChapter(String chapterId) {
    for (final page in pages) {
      if (page.anchorChapterId == chapterId &&
          page.role == BookPageRole.chapterOpener) {
        return page.index;
      }
    }
    return null;
  }
}

/// Paginates a [BookDocument] against a [BookFormat].
class BookLayoutEngine {
  const BookLayoutEngine(this.metrics);

  final BookFontMetrics metrics;

  /// The most times the engine will re-flow to settle the binding allowance.
  static const maxPasses = 3;

  /// Lays the whole book out.
  ///
  /// The order of work is what makes the table of contents correct on the first
  /// pass. The body is paginated first, in its own arabic sequence, so every
  /// chapter has a final page number; the contents page is built from those
  /// numbers; and only then is the front matter paginated, in its own roman
  /// sequence. Because the two sequences are independent, laying out the front
  /// matter cannot move the body and there is no fixed point to chase.
  ///
  /// When the author turns that split off, the front matter and body share one
  /// sequence and the contents can shift the pages it points at. The engine then
  /// re-flows, bounded by [maxPasses], and reports if it has not settled.
  PaginatedBook layout(BookDocument document, BookFormat format) {
    final stopwatch = Stopwatch()..start();
    final issues = <BookLayoutIssue>[];

    var gutterPageEstimate = _estimatePageCount(document, format);
    _LayoutResult? result;
    var passes = 0;

    for (var pass = 0; pass < maxPasses; pass++) {
      passes = pass + 1;
      result = _layoutOnce(document, format, gutterPageEstimate, issues);
      final settled = !format.margins.scaleGutterByExtent ||
          BookMargins.podGutter(result.pages.length) ==
              BookMargins.podGutter(gutterPageEstimate);
      if (settled) break;
      gutterPageEstimate = result.pages.length;
      issues.clear();
    }

    final settled = result!;
    if (format.margins.scaleGutterByExtent &&
        BookMargins.podGutter(settled.pages.length) !=
            BookMargins.podGutter(gutterPageEstimate)) {
      issues.add(const BookLayoutIssue(
        'gutterDrift',
        'The binding allowance did not settle within the pass limit. The '
            'exported gutter may be one band narrower than the final page '
            'count requires.',
      ));
    }

    for (final entry in metrics.substitutions.entries) {
      issues.add(BookLayoutIssue(
        'fontSubstituted',
        'This build does not ship ${entry.key}; ${entry.value} was used '
            'instead.',
      ));
    }

    final stats = BookLayoutStats(
      pageCount: settled.pages.length,
      blankPageCount: settled.pages.where((page) => page.isBlank).length,
      frontMatterPageCount: settled.frontCount,
      bodyPageCount: settled.bodyCount,
      backMatterPageCount: settled.backCount,
      wordCount: document.wordCount,
      riverCount: settled.riverCount,
      passes: passes,
    ).withElapsed(stopwatch.elapsed);

    return PaginatedBook(
      pages: settled.pages,
      toc: settled.toc,
      stats: stats,
      metadata: document.metadata,
      format: format,
      issues: issues,
    );
  }

  // --- one full pass -----------------------------------------------------

  _LayoutResult _layoutOnce(
    BookDocument document,
    BookFormat format,
    int gutterPageEstimate,
    List<BookLayoutIssue> issues,
  ) {
    final geometry = _Geometry.of(format, gutterPageEstimate, metrics);

    // 1. The body, in its own sequence starting at 1.
    final body = _layoutBody(document, format, geometry, issues);

    // 2. The contents, from the numbers the body just produced.
    final tocEntries = body.toc;

    // 3. The front matter, in its own sequence, padded so the body opens recto.
    final front = _layoutFrontMatter(
      document,
      format,
      geometry,
      tocEntries,
      issues,
    );
    // The body's recto rule assumes it begins at an even physical index, so
    // the front matter is padded to an even length. Only a format that aligns
    // openers to a recto needs that; a screen format gets no blank pages at all.
    final frontPages = [...front];
    if (format.requiresRectoStarts && frontPages.length.isOdd) {
      frontPages.add(_BuiltPage.blank(BookPageRole.frontMatter));
    }

    // 4. The back matter, continuing the body's sequence.
    final back = _layoutBackMatter(document, format, geometry, issues);

    final ordered = <_BuiltPage>[...frontPages, ...body.pages, ...back];
    final pages = _finalise(
      ordered,
      format,
      geometry,
      frontCount: frontPages.length,
      bodyCount: body.pages.length,
      document: document,
    );

    // The folios the contents points at are the body's, which are already
    // final: the front matter cannot move them when it has its own sequence.
    final toc = format.numbering.countFrontMatterSeparately
        ? tocEntries
        : _renumberToc(tocEntries, frontPages.length, format);

    return _LayoutResult(
      pages: pages,
      toc: toc,
      frontCount: frontPages.length,
      bodyCount: body.pages.length,
      backCount: back.length,
      riverCount: body.riverCount,
    );
  }

  List<TocEntry> _renumberToc(
    List<TocEntry> entries,
    int frontCount,
    BookFormat format,
  ) =>
      entries
          .map((entry) => TocEntry(
                title: entry.title,
                folio: _numeral(
                  entry.pageIndex + frontCount + 1,
                  format.numbering.bodyStyle,
                ),
                level: entry.level,
                chapterId: entry.chapterId,
                pageIndex: entry.pageIndex + frontCount,
              ))
          .toList(growable: false);

  // --- body --------------------------------------------------------------

  _BodyResult _layoutBody(
    BookDocument document,
    BookFormat format,
    _Geometry geometry,
    List<BookLayoutIssue> issues,
  ) {
    final pages = <_BuiltPage>[];
    final toc = <TocEntry>[];
    var rivers = 0;

    _BuiltPage? current;

    void commit() {
      if (current != null) {
        pages.add(current!);
        current = null;
      }
    }

    /// Starts a new page, inserting a blank verso first when the format says a
    /// chapter must open on a recto.
    _BuiltPage openPage(BookPageRole role, {bool requireRecto = false}) {
      commit();
      if (requireRecto && pages.length.isOdd) {
        // The body always begins on a recto, so an odd count here means the
        // next page would be a verso.
        pages.add(_BuiltPage.blank(BookPageRole.blank));
      }
      current = _BuiltPage(role);
      return current!;
    }

    for (final element in document.body) {
      switch (element) {
        case BookPartElement(:final heading):
          final page = openPage(
            BookPageRole.partTitle,
            requireRecto: format.chapter.startRule == ChapterStartRule.recto,
          );
          _composePartTitle(page, heading, format, geometry);
          toc.add(TocEntry(
            title: heading.displayTitle,
            folio: _numeral(pages.length + 1, format.numbering.bodyStyle),
            level: 0,
            pageIndex: pages.length,
          ));

        case BookChapterElement(:final chapter):
          final page = openPage(
            BookPageRole.chapterOpener,
            requireRecto: format.chapter.startRule == ChapterStartRule.recto ||
                format.breaks.blankVersoBeforeChapter,
          );
          page.anchorChapterId = chapter.id;
          toc.add(TocEntry(
            title: _chapterTocTitle(chapter, format),
            folio: _numeral(pages.length + 1, format.numbering.bodyStyle),
            level: 1,
            chapterId: chapter.id,
            pageIndex: pages.length,
          ));

          _composeChapterOpener(page, chapter, format, geometry);

          // Flow the chapter's prose, spilling onto new pages as needed.
          var isFirstParagraphOfChapter = true;
          for (var s = 0; s < chapter.scenes.length; s++) {
            final scene = chapter.scenes[s];
            if (s > 0) {
              _composeSceneBreak(
                current ?? openPage(BookPageRole.body),
                format,
                geometry,
                () => openPage(BookPageRole.body),
              );
            }
            for (var p = 0; p < scene.paragraphs.length; p++) {
              final isFirst = isFirstParagraphOfChapter;
              final afterBreak = isFirst || (p == 0 && s > 0);
              final indent = afterBreak && !format.typography.indentAfterBreak
                  ? 0.0
                  : format.typography.firstLineIndentPt;
              final dropCap = isFirst && format.chapter.dropCap;

              rivers += _flowParagraph(
                text: scene.paragraphs[p],
                paragraphId: '${scene.id}:$p',
                format: format,
                geometry: geometry,
                indentPt: indent,
                dropCap: dropCap,
                page: () => current ?? openPage(BookPageRole.body),
                nextPage: () => openPage(BookPageRole.body),
              );
              isFirstParagraphOfChapter = false;
            }
          }

          if (chapter.isEmpty) {
            issues.add(BookLayoutIssue(
              'emptyChapter',
              '"${chapter.title}" has no prose, so it prints as an opener and '
                  'nothing else.',
              pageIndex: pages.length,
            ));
          }
      }
    }
    commit();

    return _BodyResult(pages: pages, toc: toc, riverCount: rivers);
  }

  String _chapterTocTitle(BookChapterContent chapter, BookFormat format) {
    final number = _chapterNumber(chapter.number, format.chapter);
    final title = chapter.title.trim();
    if (number.isEmpty) return title.isEmpty ? 'Chapter ${chapter.number}' : title;
    if (title.isEmpty) return number;
    return '$number: $title';
  }

  // --- front and back matter ---------------------------------------------

  List<_BuiltPage> _layoutFrontMatter(
    BookDocument document,
    BookFormat format,
    _Geometry geometry,
    List<TocEntry> toc,
    List<BookLayoutIssue> issues,
  ) {
    final pages = <_BuiltPage>[];
    for (final matter in document.frontMatter) {
      pages.addAll(_layoutMatterPage(
        matter,
        format,
        geometry,
        BookPageRole.frontMatter,
        toc,
        document,
      ));
      // Print convention: each front-matter section opens on a recto. Skipped
      // for screen formats, which never want a blank page.
      if (format.requiresRectoStarts &&
          pages.length.isOdd &&
          matter != document.frontMatter.last) {
        pages.add(_BuiltPage.blank(BookPageRole.frontMatter));
      }
    }
    return pages;
  }

  List<_BuiltPage> _layoutBackMatter(
    BookDocument document,
    BookFormat format,
    _Geometry geometry,
    List<BookLayoutIssue> issues,
  ) {
    final pages = <_BuiltPage>[];
    for (final matter in document.backMatter) {
      pages.addAll(_layoutMatterPage(
        matter,
        format,
        geometry,
        BookPageRole.backMatter,
        const [],
        document,
      ));
    }
    return pages;
  }

  List<_BuiltPage> _layoutMatterPage(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
    List<TocEntry> toc,
    BookDocument document,
  ) {
    switch (matter.layout) {
      case BookMatterLayout.titlePage:
        return [_composeTitlePage(matter, format, geometry, role)];
      case BookMatterLayout.centredBlock:
        return [_composeCentredBlock(matter, format, geometry, role)];
      case BookMatterLayout.copyrightBlock:
        return [_composeCopyright(matter, format, geometry, role)];
      case BookMatterLayout.contents:
        return _composeContents(matter, format, geometry, role, toc);
      case BookMatterLayout.flowingText:
        return _composeFlowingText(matter, format, geometry, role);
    }
  }

  _BuiltPage _composeTitlePage(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
  ) {
    final page = _BuiltPage(role)..suppressFolio = true..suppressHead = true;
    final display = BookFontFace(
        format.typography.displayFamily, BookFontStyleId.bold);
    final body = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);

    var y = geometry.textHeightPt * 0.28;
    final lines = matter.paragraphs;
    if (lines.isEmpty) return page;

    // The first line is the title, set large; the rest step down in size.
    final sizes = <double>[
      format.chapter.titleSizePt * 1.7,
      for (var i = 1; i < lines.length; i++)
        i == lines.length - 1 && format.typography.bodySizePt > 0
            ? format.typography.bodySizePt * 1.1
            : format.typography.bodySizePt * 1.25,
    ];

    for (var i = 0; i < lines.length; i++) {
      final size = sizes[i];
      final face = i == 0 ? display : body;
      y += metrics.ascentPt(face, size);
      page.elements.add(_centredLine(lines[i], face, size, y, geometry));
      y += metrics.descentPt(face, size) + size * (i == 0 ? 1.4 : 0.9);
    }
    return page;
  }

  _BuiltPage _composeCentredBlock(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
  ) {
    final page = _BuiltPage(role)..suppressFolio = true..suppressHead = true;
    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final size = format.typography.bodySizePt;
    final leading = format.typography.leadingPt;

    var y = geometry.textHeightPt * 0.3;
    if (matter.title.isNotEmpty) {
      final titleFace = BookFontFace(
          format.typography.displayFamily, BookFontStyleId.bold);
      final titleSize = format.chapter.titleSizePt;
      y += metrics.ascentPt(titleFace, titleSize);
      page.elements
          .add(_centredLine(matter.title, titleFace, titleSize, y, geometry));
      y += metrics.descentPt(titleFace, titleSize) + titleSize * 1.6;
    }
    for (final paragraph in matter.paragraphs) {
      for (final line in _breakLines(
        paragraph,
        face,
        size,
        geometry.textWidthPt,
        0,
      )) {
        y += metrics.ascentPt(face, size);
        page.elements.add(_centredLine(line.text, face, size, y, geometry));
        y += leading - metrics.ascentPt(face, size);
      }
      y += leading * 0.5;
    }
    return page;
  }

  _BuiltPage _composeCopyright(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
  ) {
    final page = _BuiltPage(role)..suppressFolio = true..suppressHead = true;
    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final size = format.typography.bodySizePt * 0.82;
    final leading = size * 1.4;

    // A copyright page is conventionally set low on the page.
    var y = geometry.textHeightPt * 0.45;
    for (final paragraph in matter.paragraphs) {
      for (final line in _breakLines(
        paragraph,
        face,
        size,
        geometry.textWidthPt,
        0,
      )) {
        y += metrics.ascentPt(face, size);
        page.elements.add(LayoutTextLine(
          runs: [LayoutTextRun(line.text, face, size)],
          text: line.text,
          x: 0,
          baselineY: y,
          isLastOfParagraph: line.isLast,
        ));
        y += leading - metrics.ascentPt(face, size);
      }
      y += leading * 0.6;
    }
    return page;
  }

  List<_BuiltPage> _composeContents(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
    List<TocEntry> toc,
  ) {
    final pages = <_BuiltPage>[];
    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final partFace = BookFontFace(
        format.typography.displayFamily, BookFontStyleId.bold);
    final size = format.typography.bodySizePt;
    final leading = format.typography.leadingPt * 1.15;

    var page = _BuiltPage(role)..suppressHead = true;
    var y = 0.0;

    if (matter.title.isNotEmpty) {
      final titleFace = BookFontFace(
          format.typography.displayFamily, BookFontStyleId.bold);
      final titleSize = format.chapter.titleSizePt;
      y += metrics.ascentPt(titleFace, titleSize);
      page.elements.add(LayoutTextLine(
        runs: [LayoutTextRun(matter.title, titleFace, titleSize)],
        text: matter.title,
        x: 0,
        baselineY: y,
        isLastOfParagraph: true,
      ));
      y += metrics.descentPt(titleFace, titleSize) + titleSize * 1.4;
    }

    for (final entry in toc) {
      if (y + leading > geometry.textHeightPt) {
        pages.add(page);
        page = _BuiltPage(role)..suppressHead = true;
        y = 0;
      }
      final entryFace = entry.level == 0 ? partFace : face;
      final indent = entry.level == 0 ? 0.0 : size * 0.8;
      y += metrics.ascentPt(entryFace, size);
      page.elements.add(LayoutTextLine(
        runs: [LayoutTextRun(entry.title, entryFace, size)],
        text: entry.title,
        x: indent,
        baselineY: y,
        isLastOfParagraph: true,
      ));
      // The folio sits flush against the outside edge of the measure.
      final folioWidth = metrics.advancePt(entry.folio, face, size);
      page.elements.add(LayoutTextLine(
        runs: [LayoutTextRun(entry.folio, face, size)],
        text: entry.folio,
        x: geometry.textWidthPt - folioWidth,
        baselineY: y,
        isLastOfParagraph: true,
      ));
      y += leading - metrics.ascentPt(entryFace, size);
    }
    pages.add(page);
    return pages;
  }

  List<_BuiltPage> _composeFlowingText(
    BookMatterPage matter,
    BookFormat format,
    _Geometry geometry,
    BookPageRole role,
  ) {
    final pages = <_BuiltPage>[];
    var page = _BuiltPage(role);
    var y = 0.0;

    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final size = format.typography.bodySizePt;
    final leading = format.typography.leadingPt;

    if (matter.title.isNotEmpty) {
      final titleFace = BookFontFace(
          format.typography.displayFamily, BookFontStyleId.bold);
      final titleSize = format.chapter.titleSizePt;
      y = geometry.textHeightPt * format.chapter.sinkFraction;
      y += metrics.ascentPt(titleFace, titleSize);
      page.elements.add(LayoutTextLine(
        runs: [LayoutTextRun(matter.title, titleFace, titleSize)],
        text: matter.title,
        x: 0,
        baselineY: y,
        isLastOfParagraph: true,
      ));
      y += metrics.descentPt(titleFace, titleSize) + format.chapter.bodyGapPt;
      page.suppressHead = true;
    }

    for (var i = 0; i < matter.paragraphs.length; i++) {
      final indent =
          i == 0 && !format.typography.indentAfterBreak
              ? 0.0
              : format.typography.firstLineIndentPt;
      final lines = _breakLines(
        matter.paragraphs[i],
        face,
        size,
        geometry.textWidthPt,
        indent,
      );
      for (final line in lines) {
        if (y + leading > geometry.textHeightPt) {
          pages.add(page);
          page = _BuiltPage(role);
          y = 0;
        }
        y += metrics.ascentPt(face, size);
        page.elements.add(_composeLine(
          line,
          face,
          size,
          geometry.textWidthPt,
          format,
          'matter:${matter.id}:$i',
          baselineY: y,
        ));
        y += leading - metrics.ascentPt(face, size);
      }
      y += format.typography.paragraphSpacingPt;
    }
    pages.add(page);
    return pages;
  }

  // --- composition helpers ------------------------------------------------

  LayoutTextLine _centredLine(
    String text,
    BookFontFace face,
    double sizePt,
    double baselineY,
    _Geometry geometry,
  ) {
    final width = metrics.advancePt(text, face, sizePt);
    return LayoutTextLine(
      runs: [LayoutTextRun(text, face, sizePt)],
      text: text,
      x: (geometry.textWidthPt - width) / 2,
      baselineY: baselineY,
      isLastOfParagraph: true,
      widthPt: width,
    );
  }

  void _composePartTitle(
    _BuiltPage page,
    BookPartHeading heading,
    BookFormat format,
    _Geometry geometry,
  ) {
    page.suppressHead = true;
    final face = BookFontFace(
        format.typography.displayFamily, BookFontStyleId.bold);
    final size = format.chapter.titleSizePt * 1.3;
    var y = geometry.textHeightPt * 0.35 + metrics.ascentPt(face, size);
    page.elements.add(_centredLine(heading.displayTitle, face, size, y, geometry));
    if (heading.subtitle.trim().isNotEmpty) {
      final subFace = BookFontFace(
          format.typography.bodyFamily, BookFontStyleId.regular);
      final subSize = format.typography.bodySizePt * 1.1;
      y += metrics.descentPt(face, size) + size * 1.1;
      y += metrics.ascentPt(subFace, subSize);
      page.elements
          .add(_centredLine(heading.subtitle.trim(), subFace, subSize, y, geometry));
    }
  }

  /// Lays the chapter opener out and leaves the page cursor below it.
  void _composeChapterOpener(
    _BuiltPage page,
    BookChapterContent chapter,
    BookFormat format,
    _Geometry geometry,
  ) {
    final style = format.chapter;
    final numberFace = BookFontFace(
        format.typography.displayFamily, BookFontStyleId.regular);
    final titleFace = BookFontFace(
        format.typography.displayFamily, BookFontStyleId.bold);

    var y = geometry.textHeightPt * style.sinkFraction;

    final number = _chapterNumber(chapter.number, style);
    if (number.isNotEmpty) {
      y += metrics.ascentPt(numberFace, style.numberSizePt);
      page.elements.add(_alignedLine(
        number,
        numberFace,
        style.numberSizePt,
        y,
        geometry,
        style.headingAlignment,
      ));
      y += metrics.descentPt(numberFace, style.numberSizePt) + style.titleGapPt;
    }

    final title = chapter.title.trim();
    if (title.isNotEmpty) {
      y += metrics.ascentPt(titleFace, style.titleSizePt);
      page.elements.add(_alignedLine(
        title,
        titleFace,
        style.titleSizePt,
        y,
        geometry,
        style.headingAlignment,
      ));
      y += metrics.descentPt(titleFace, style.titleSizePt);
    }

    page.cursorY = y + style.bodyGapPt;
  }

  LayoutTextLine _alignedLine(
    String text,
    BookFontFace face,
    double sizePt,
    double baselineY,
    _Geometry geometry,
    BookAlignment alignment,
  ) {
    if (alignment == BookAlignment.left) {
      return LayoutTextLine(
        runs: [LayoutTextRun(text, face, sizePt)],
        text: text,
        x: 0,
        baselineY: baselineY,
        isLastOfParagraph: true,
      );
    }
    return _centredLine(text, face, sizePt, baselineY, geometry);
  }

  void _composeSceneBreak(
    _BuiltPage page,
    BookFormat format,
    _Geometry geometry,
    _BuiltPage Function() nextPage,
  ) {
    final leading = format.typography.leadingPt;
    var target = page;
    if (target.cursorY + leading * 2 > geometry.textHeightPt) {
      // A break at the foot of a page is invisible; the page turn is the break.
      target = nextPage();
      return;
    }
    switch (format.chapter.sceneBreak) {
      case SceneBreakStyle.blankLine:
        target.cursorY += leading;
      case SceneBreakStyle.glyph:
        final face = BookFontFace(
            format.typography.bodyFamily, BookFontStyleId.regular);
        final size = format.typography.bodySizePt;
        target.cursorY += leading * 0.5 + metrics.ascentPt(face, size);
        target.elements.add(_centredLine(
          format.chapter.sceneBreakGlyph,
          face,
          size,
          target.cursorY,
          geometry,
        ));
        target.cursorY += leading;
      case SceneBreakStyle.ornament:
        target.cursorY += leading * 0.6;
        final width = format.typography.bodySizePt * 3.5;
        target.elements.add(LayoutOrnament(
          ornament: format.chapter.ornament == BookOrnamentId.none
              ? BookOrnamentId.asterism
              : format.chapter.ornament,
          x: (geometry.textWidthPt - width) / 2,
          y: target.cursorY,
          widthPt: width,
        ));
        target.cursorY += leading * 1.2;
    }
  }

  /// Places one paragraph, spilling to new pages and honouring widow and orphan
  /// rules.
  ///
  /// The whole paragraph is broken into lines first, then split across pages.
  /// Deciding the split with every line already measured is what lets both rules
  /// be applied in one place instead of being chased with a reflow afterwards.
  ///
  /// Returns the number of rivers found.
  int _flowParagraph({
    required String text,
    required String paragraphId,
    required BookFormat format,
    required _Geometry geometry,
    required double indentPt,
    required bool dropCap,
    required _BuiltPage Function() page,
    required _BuiltPage Function() nextPage,
  }) {
    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final size = format.typography.bodySizePt;
    final leading = format.typography.leadingPt;
    var rivers = 0;

    final dropCapLines = dropCap ? format.chapter.dropCapLines : 0;
    final dropCapGlyph = dropCap && text.isNotEmpty ? text[0] : '';
    final dropCapSize = dropCapLines > 0 ? leading * dropCapLines * 0.86 : 0.0;
    final dropCapWidth = dropCapLines > 0
        ? metrics.advancePt(dropCapGlyph, face, dropCapSize) + size * 0.12
        : 0.0;
    final bodyText = dropCapLines > 0 ? text.substring(1) : text;

    final lines = _breakLines(
      bodyText,
      face,
      size,
      geometry.textWidthPt,
      dropCapLines > 0 ? 0 : indentPt,
      narrowedWidth: dropCapLines > 0
          ? geometry.textWidthPt - dropCapWidth
          : null,
      narrowedCount: dropCapLines,
    );

    var target = page();
    var placed = 0;
    var first = true;

    while (placed < lines.length) {
      final available =
          ((geometry.textHeightPt - target.cursorY) / leading).floor();
      if (available <= 0) {
        target = nextPage();
        continue;
      }

      final remaining = lines.length - placed;
      var take = available < remaining ? available : remaining;

      if (take < remaining) {
        // Orphan: too few lines left at the foot to be worth starting here.
        if (take < format.breaks.minLinesAtPageBottom) {
          take = 0;
        } else if (remaining - take < format.breaks.minLinesAtPageTop) {
          // Widow: too few lines would carry to the next page.
          take = remaining - format.breaks.minLinesAtPageTop;
          if (take < format.breaks.minLinesAtPageBottom) take = 0;
        }
      }

      if (take <= 0) {
        target = nextPage();
        continue;
      }

      for (var i = 0; i < take; i++) {
        final line = lines[placed + i];
        final index = placed + i;
        final isNarrow = dropCapLines > 0 && index < dropCapLines;
        final measure = isNarrow
            ? geometry.textWidthPt - dropCapWidth
            : geometry.textWidthPt;
        final xOffset = isNarrow ? dropCapWidth : 0.0;

        target.cursorY += metrics.ascentPt(face, size);

        if (first && dropCapLines > 0) {
          target.elements.add(LayoutDropCap(
            glyph: dropCapGlyph,
            x: 0,
            baselineY: target.cursorY + leading * (dropCapLines - 1),
            sizePt: dropCapSize,
            face: face,
          ));
        }

        final composed = _composeLine(
          line,
          face,
          size,
          measure,
          format,
          paragraphId,
          baselineY: target.cursorY,
          xOffset: xOffset,
          indentPt: index == 0 && dropCapLines == 0 ? indentPt : 0,
        );
        if (composed.wordSpacingPt >
            metrics.spacePt(face, size) *
                (format.breaks.maxWordSpaceMultiple - 1)) {
          rivers += 1;
        }
        target.elements.add(composed);
        target.cursorY += leading - metrics.ascentPt(face, size);
        first = false;
      }

      placed += take;
      if (placed < lines.length) target = nextPage();
    }

    target.cursorY += format.typography.paragraphSpacingPt;
    return rivers;
  }

  /// Turns a measured line into a positioned one, justifying when asked.
  LayoutTextLine _composeLine(
    _MeasuredLine line,
    BookFontFace face,
    double sizePt,
    double measurePt,
    BookFormat format,
    String paragraphId, {
    required double baselineY,
    double xOffset = 0,
    double indentPt = 0,
  }) {
    final justify = format.typography.alignment == BookAlignment.justified &&
        !line.isLast &&
        line.wordCount > 1;

    var wordSpacing = 0.0;
    if (justify) {
      final slack = measurePt - indentPt - line.widthPt;
      if (slack > 0) wordSpacing = slack / (line.wordCount - 1);
    }

    // A justified line is placed word by word here, in the engine, rather than
    // handed to a renderer as a string plus a spacing value. See
    // [LayoutTextRun.xOffsetPt] for why that spacing value cannot be trusted to
    // survive into a PDF.
    final runs = <LayoutTextRun>[];
    if (wordSpacing == 0) {
      runs.add(LayoutTextRun(line.text, face, sizePt));
    } else {
      final space = metrics.advancePt(' ', face, sizePt) + wordSpacing;
      var cursor = 0.0;
      for (final word in line.words) {
        runs.add(LayoutTextRun(word, face, sizePt, xOffsetPt: cursor));
        cursor += metrics.advancePt(word, face, sizePt) + space;
      }
    }

    return LayoutTextLine(
      runs: runs,
      text: line.text,
      x: xOffset + indentPt,
      baselineY: baselineY,
      wordSpacingPt: wordSpacing,
      isLastOfParagraph: line.isLast,
      paragraphId: paragraphId,
      widthPt: line.widthPt + wordSpacing * (line.wordCount - 1),
    );
  }

  // --- line breaking ------------------------------------------------------

  /// Greedy first-fit line breaking.
  ///
  /// Breaks at spaces only; there is no hyphenation, which would need a
  /// pattern table the app does not ship. Greedy rather than an optimal-fit
  /// algorithm: the difference in colour is invisible at preview zoom, and a
  /// greedy break is far easier to assert in a test.
  List<_MeasuredLine> _breakLines(
    String text,
    BookFontFace face,
    double sizePt,
    double measurePt,
    double firstIndentPt, {
    double? narrowedWidth,
    int narrowedCount = 0,
  }) {
    final words = text.trim().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) return const [];

    final spaceWidth = metrics.spacePt(face, sizePt);
    final lines = <_MeasuredLine>[];
    var current = <String>[];
    var currentWidth = 0.0;

    double limitFor(int lineIndex) {
      final base = (narrowedWidth != null && lineIndex < narrowedCount)
          ? narrowedWidth
          : measurePt;
      return lineIndex == 0 ? base - firstIndentPt : base;
    }

    for (final word in words) {
      final wordWidth = metrics.advancePt(word, face, sizePt);
      final candidate = current.isEmpty
          ? wordWidth
          : currentWidth + spaceWidth + wordWidth;
      if (current.isNotEmpty && candidate > limitFor(lines.length)) {
        lines.add(_MeasuredLine(
          words: List.of(current),
          widthPt: currentWidth,
          isLast: false,
        ));
        current = [word];
        currentWidth = wordWidth;
      } else {
        current.add(word);
        currentWidth = candidate;
      }
    }
    if (current.isNotEmpty) {
      lines.add(_MeasuredLine(
        words: List.of(current),
        widthPt: currentWidth,
        isLast: true,
      ));
    }
    return lines;
  }

  // --- finalisation -------------------------------------------------------

  /// Assigns sides, folios and running heads once the whole book is known.
  List<LaidOutPage> _finalise(
    List<_BuiltPage> built,
    BookFormat format,
    _Geometry geometry,
    {
    required int frontCount,
    required int bodyCount,
    required BookDocument document,
  }) {
    final pages = <LaidOutPage>[];
    final numbering = format.numbering;

    var frontFolio = 0;
    var bodyFolio = numbering.restartAtBody ? 0 : frontCount;

    String? currentChapterTitle;
    String? currentPartTitle;

    for (var index = 0; index < built.length; index++) {
      final source = built[index];
      final isRecto = index.isEven;
      final isFront = index < frontCount;
      final margins = format.margins.resolve(
        isRecto: isRecto,
        totalPages: geometry.gutterPageEstimate,
      );

      if (source.anchorChapterId != null) {
        currentChapterTitle = _chapterTitleFor(document, source.anchorChapterId!);
      }
      if (source.role == BookPageRole.partTitle) {
        currentPartTitle = _firstLineText(source);
      }

      String? folio;
      if (!numbering.isEmpty &&
          !(source.isBlank && numbering.suppressOnBlank) &&
          !source.suppressFolio &&
          !(source.role == BookPageRole.chapterOpener &&
              numbering.suppressOnChapterOpener)) {
        if (isFront && numbering.countFrontMatterSeparately) {
          frontFolio += 1;
          folio = _numeral(frontFolio, numbering.frontMatterStyle);
        } else {
          bodyFolio += 1;
          folio = _numeral(bodyFolio, numbering.bodyStyle);
        }
      } else {
        // A suppressed folio still consumes a number.
        if (isFront && numbering.countFrontMatterSeparately) {
          frontFolio += 1;
        } else {
          bodyFolio += 1;
        }
      }

      String? head;
      final headStyle = format.runningHead;
      final suppressed = source.isBlank && headStyle.suppressOnBlank ||
          source.suppressHead ||
          (isFront && headStyle.suppressInFrontMatter) ||
          (source.role == BookPageRole.chapterOpener &&
              headStyle.suppressOnChapterOpener) ||
          source.role == BookPageRole.partTitle;
      if (!suppressed && !headStyle.isEmpty) {
        head = _runningHeadText(
          isRecto ? headStyle.recto : headStyle.verso,
          document,
          currentChapterTitle,
          currentPartTitle,
        );
      }

      final marginalia = _marginalia(
        format: format,
        geometry: geometry,
        margins: margins,
        isRecto: isRecto,
        folio: folio,
        head: head == null || head.isEmpty ? null : head,
      );

      pages.add(LaidOutPage(
        index: index,
        role: source.role,
        elements: List.unmodifiable(source.elements),
        trimWidthPt: format.trim.widthPt,
        trimHeightPt: format.trim.heightPt,
        textBlockLeftPt: margins.leftPt,
        textBlockTopPt: margins.topPt + format.runningHead.reservedPt,
        textBlockWidthPt: geometry.textWidthPt,
        textBlockHeightPt: geometry.textHeightPt,
        isRecto: isRecto,
        folio: folio,
        runningHead: head == null || head.isEmpty ? null : head,
        marginalia: marginalia,
        anchorChapterId: source.anchorChapterId,
        isBlank: source.isBlank,
      ));
    }
    return pages;
  }

  /// Positions the running head and the folio.
  ///
  /// This lives in the engine, not in a renderer, so that neither renderer has
  /// any reason to measure a string. Coordinates are absolute from the page's
  /// top-left corner.
  List<LayoutTextLine> _marginalia({
    required BookFormat format,
    required _Geometry geometry,
    required BookPageMargins margins,
    required bool isRecto,
    required String? folio,
    required String? head,
  }) {
    final lines = <LayoutTextLine>[];
    final face = BookFontFace(
        format.typography.bodyFamily, BookFontStyleId.regular);
    final textLeft = margins.leftPt;
    final textRight = margins.leftPt + geometry.textWidthPt;
    final textTop = margins.topPt + format.runningHead.reservedPt;
    final textBottom = textTop + geometry.textHeightPt;

    if (head != null) {
      final style = format.runningHead;
      final width = metrics.advancePt(head, face, style.sizePt);
      lines.add(LayoutTextLine(
        runs: [LayoutTextRun(head, face, style.sizePt)],
        text: head,
        // The head sits against the fore edge, which swaps with the page side.
        x: isRecto ? textRight - width : textLeft,
        baselineY: textTop - style.gapPt,
        isLastOfParagraph: true,
        widthPt: width,
      ));
    }

    if (folio != null && folio.isNotEmpty) {
      final numbering = format.numbering;
      final width = metrics.advancePt(folio, face, numbering.sizePt);
      double? x;
      double? y;
      switch (numbering.position) {
        case PageNumberPosition.none:
          break;
        case PageNumberPosition.footerCentre:
          x = textLeft + (geometry.textWidthPt - width) / 2;
          y = textBottom + numbering.gapPt;
        case PageNumberPosition.footerOutside:
          x = isRecto ? textRight - width : textLeft;
          y = textBottom + numbering.gapPt;
        case PageNumberPosition.headerOutside:
          x = isRecto ? textRight - width : textLeft;
          y = textTop - numbering.gapPt;
      }
      if (x != null && y != null) {
        lines.add(LayoutTextLine(
          runs: [LayoutTextRun(folio, face, numbering.sizePt)],
          text: folio,
          x: x,
          baselineY: y,
          isLastOfParagraph: true,
          widthPt: width,
        ));
      }
    }
    return lines;
  }

  String? _chapterTitleFor(BookDocument document, String chapterId) {
    for (final chapter in document.chapters) {
      if (chapter.id == chapterId) {
        return chapter.title.trim().isEmpty
            ? 'Chapter ${chapter.number}'
            : chapter.title.trim();
      }
    }
    return null;
  }

  String? _firstLineText(_BuiltPage page) {
    for (final element in page.elements) {
      if (element is LayoutTextLine) return element.text;
    }
    return null;
  }

  String? _runningHeadText(
    RunningHeadContent content,
    BookDocument document,
    String? chapterTitle,
    String? partTitle,
  ) =>
      switch (content) {
        RunningHeadContent.none => null,
        RunningHeadContent.bookTitle => document.metadata.title,
        RunningHeadContent.authorName => document.metadata.authorName,
        RunningHeadContent.chapterTitle => chapterTitle,
        RunningHeadContent.partTitle => partTitle,
      };

  int _estimatePageCount(BookDocument document, BookFormat format) {
    // Only used to seed the binding allowance, which is then settled by
    // re-flowing. About 300 words to a page is close enough to land in the
    // right band almost always.
    final pages = (document.wordCount / 300).ceil();
    return pages < 24 ? 24 : pages;
  }

  static String _chapterNumber(int number, ChapterStyle style) =>
      switch (style.numberStyle) {
        ChapterNumberStyle.none => '',
        ChapterNumberStyle.arabic => '${style.numberPrefix}$number',
        ChapterNumberStyle.romanUpper =>
          '${style.numberPrefix}${romanUpper(number)}',
        ChapterNumberStyle.word => '${style.numberPrefix}${numberWord(number)}',
      };

  static String _numeral(int value, PageNumeralStyle style) =>
      switch (style) {
        PageNumeralStyle.arabic => '$value',
        PageNumeralStyle.romanLower => romanUpper(value).toLowerCase(),
        PageNumeralStyle.romanUpper => romanUpper(value),
      };
}

/// The text block, which is the same size on every page of a book.
///
/// Mirrored margins swap which physical edge the binding allowance sits on, but
/// the measure is `trim - inside - outside` either way. That is why line
/// breaking does not depend on whether a page is a recto, and why the engine can
/// paginate before it knows how long the front matter is.
class _Geometry {
  const _Geometry({
    required this.textWidthPt,
    required this.textHeightPt,
    required this.gutterPageEstimate,
  });

  final double textWidthPt;
  final double textHeightPt;
  final int gutterPageEstimate;

  factory _Geometry.of(
    BookFormat format,
    int gutterPageEstimate,
    BookFontMetrics metrics,
  ) {
    final margins = format.margins;
    final gutter = margins.gutterFor(gutterPageEstimate);
    final width = format.trim.widthPt -
        margins.insidePt -
        gutter -
        margins.outsidePt;
    final height = format.trim.heightPt -
        margins.topPt -
        margins.bottomPt -
        format.runningHead.reservedPt -
        format.numbering.reservedPt;
    return _Geometry(
      textWidthPt: width < 36 ? 36 : width,
      textHeightPt: height < 36 ? 36 : height,
      gutterPageEstimate: gutterPageEstimate,
    );
  }
}

/// A page under construction.
class _BuiltPage {
  _BuiltPage(this.role);

  factory _BuiltPage.blank(BookPageRole role) =>
      _BuiltPage(role)..isBlank = true;

  final BookPageRole role;
  final List<LayoutElement> elements = [];

  /// Distance from the top of the text block to the next available baseline.
  double cursorY = 0;

  bool isBlank = false;
  bool suppressFolio = false;
  bool suppressHead = false;
  String? anchorChapterId;
}

/// A line that has been broken and measured but not yet positioned.
class _MeasuredLine {
  const _MeasuredLine({
    required this.words,
    required this.widthPt,
    required this.isLast,
  });

  final List<String> words;
  final double widthPt;
  final bool isLast;

  int get wordCount => words.length;
  String get text => words.join(' ');
}

class _BodyResult {
  const _BodyResult({
    required this.pages,
    required this.toc,
    required this.riverCount,
  });

  final List<_BuiltPage> pages;
  final List<TocEntry> toc;
  final int riverCount;
}

class _LayoutResult {
  const _LayoutResult({
    required this.pages,
    required this.toc,
    required this.frontCount,
    required this.bodyCount,
    required this.backCount,
    required this.riverCount,
  });

  final List<LaidOutPage> pages;
  final List<TocEntry> toc;
  final int frontCount;
  final int bodyCount;
  final int backCount;
  final int riverCount;
}
