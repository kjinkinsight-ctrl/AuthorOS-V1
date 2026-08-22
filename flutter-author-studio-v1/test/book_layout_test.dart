import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

/// The fixture format gives a 200 x 200 pt text block, 10 pt type on 20 pt
/// leading, and four-letter words. So: eight words to a line, ten lines to a
/// page, and every assertion below is arithmetic rather than a guess.
const wordsPerLine = 8;
const linesPerPage = 10;

PaginatedBook layout(
  BookProject book, {
  BookFormat? format,
  ManuscriptProjectSummary? manuscript,
}) {
  final document = const BookDocumentBuilder().build(
    manuscript: manuscript ?? manuscriptFixture(),
    book: book,
    profileAuthorName: 'Kali Vale',
  );
  return BookLayoutEngine(FakeBookFontMetrics())
      .layout(document, format ?? book.format);
}

List<LayoutTextLine> linesOf(LaidOutPage page) =>
    page.elements.whereType<LayoutTextLine>().toList();

void main() {
  group('line breaking', () {
    test('breaks greedily at the measure', () {
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format).copyWith(
          frontMatter: const [],
          backMatter: const [],
        ),
        format: format,
      );

      final opener = result.pages
          .firstWhere((page) => page.anchorChapterId == 'ch-1');
      // The opener carries the chapter title plus the prose that fits after it.
      final prose = linesOf(opener)
          .where((line) => line.text.startsWith('abcd'))
          .toList();

      expect(prose, isNotEmpty);
      for (final line in prose.take(prose.length - 1)) {
        expect(
          line.text.split(' ').length,
          wordsPerLine,
          reason: 'a full line should hold exactly $wordsPerLine words',
        );
      }
    });

    test('never justifies the last line of a paragraph', () {
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      final prose = result.pages
          .expand(linesOf)
          .where((line) => line.text.startsWith('abcd'))
          .toList();

      final last = prose.where((line) => line.isLastOfParagraph);
      expect(last, isNotEmpty);
      for (final line in last) {
        expect(line.wordSpacingPt, 0,
            reason: 'a paragraph\'s last line is set ragged, never stretched');
      }
    });

    test('distributes justification slack across the gaps', () {
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      final stretched = result.pages
          .expand(linesOf)
          .where((line) =>
              line.text.startsWith('abcd') && !line.isLastOfParagraph)
          .toList();

      expect(stretched, isNotEmpty);
      // Eight four-letter words measure 195 pt in a 200 pt measure, so 5 pt of
      // slack is shared by seven interword gaps.
      for (final line in stretched) {
        expect(line.wordSpacingPt, closeTo(5 / 7, 0.0001));
      }
    });

    test('a justified line is placed word by word, flush to the measure', () {
      // Not a style question: the embedded fonts are composite, and PDF ignores
      // the Tw word-spacing operator for composite fonts. A line handed over as
      // one string plus a spacing value renders justified in the preview and
      // ragged in the export. The engine therefore places each word itself.
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      final stretched = result.pages
          .expand(linesOf)
          .where((line) =>
              line.text.startsWith('abcd') &&
              !line.isLastOfParagraph &&
              line.wordSpacingPt > 0)
          .toList();
      expect(stretched, isNotEmpty);

      for (final line in stretched) {
        expect(line.runs, hasLength(line.text.split(' ').length),
            reason: 'a justified line must carry one placed run per word');

        // The offsets must march left to right, and the set line must fill the
        // measure.
        var previous = -1.0;
        for (final run in line.runs) {
          expect(run.xOffsetPt, greaterThan(previous));
          previous = run.xOffsetPt;
        }
        expect(line.widthPt, closeTo(200, 0.001),
            reason: 'a justified line fills the 200 pt measure exactly');
      }
    });

    test('ragged setting leaves every line unstretched', () {
      final format = arithmeticFormat(alignment: BookAlignment.left);
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      for (final line in result.pages.expand(linesOf)) {
        expect(line.wordSpacingPt, 0);
        expect(line.runs, hasLength(1),
            reason: 'an unstretched line needs no per-word placement');
      }
    });
  });

  group('page breaking', () {
    test('fills a page to its line capacity before starting another', () {
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      for (final page in result.pages.where((p) => !p.isBlank)) {
        expect(linesOf(page).length, lessThanOrEqualTo(linesPerPage));
        for (final line in linesOf(page)) {
          expect(line.baselineY, lessThanOrEqualTo(page.textBlockHeightPt),
              reason: 'no line may sit below the text block');
        }
      }
    });

    test('a chapter set to open on a recto never opens on a verso', () {
      final format = arithmeticFormat(startRule: ChapterStartRule.recto);
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );

      final openers = result.pages
          .where((page) => page.role == BookPageRole.chapterOpener);
      expect(openers, hasLength(3));
      for (final opener in openers) {
        expect(opener.isRecto, isTrue,
            reason: 'page ${opener.index + 1} opens a chapter on a verso');
      }
      expect(result.stats.blankPageCount, greaterThan(0),
          reason: 'forcing recto openers must produce blank versos');
    });

    test('a chapter set to open on any page inserts no blanks', () {
      final format = arithmeticFormat();
      final result = layout(
        bookFixture(format: format)
            .copyWith(frontMatter: const [], backMatter: const []),
        format: format,
      );
      expect(
        result.pages.where((page) => page.role == BookPageRole.blank),
        isEmpty,
      );
    });
  });

  group('widow and orphan control', () {
    test('a paragraph never leaves a single line at the foot of a page', () {
      final format = arithmeticFormat(startRule: ChapterStartRule.anyPage);
      final book = bookFixture(format: format)
          .copyWith(frontMatter: const [], backMatter: const []);
      final result = layout(book, format: format);

      final byParagraph = <String, List<int>>{};
      for (final page in result.pages) {
        for (final line in linesOf(page)) {
          if (line.paragraphId.isEmpty) continue;
          (byParagraph[line.paragraphId] ??= []).add(page.index);
        }
      }

      for (final entry in byParagraph.entries) {
        final pages = entry.value.toSet().toList()..sort();
        if (pages.length < 2) continue;
        for (final pageIndex in pages) {
          final onThisPage =
              entry.value.where((index) => index == pageIndex).length;
          expect(onThisPage, greaterThanOrEqualTo(2),
              reason: 'paragraph ${entry.key} leaves $onThisPage line(s) '
                  'stranded on page ${pageIndex + 1}');
        }
      }
    });
  });

  group('front matter and folios', () {
    test('front matter is roman and the body restarts in arabic', () {
      final result = layout(bookFixture());

      final front = result.pages
          .where((page) => page.role == BookPageRole.frontMatter)
          .toList();
      expect(front, isNotEmpty);

      final firstBody = result.pages
          .firstWhere((page) => page.role == BookPageRole.chapterOpener);
      expect(firstBody.folio, '1',
          reason: 'the body opens at arabic 1, not at the physical page number');

      final contents = front.where((page) => page.folio != null);
      for (final page in contents) {
        expect(page.folio, matches(RegExp(r'^[ivxlcdm]+$')),
            reason: 'front matter folios are lower-case roman');
      }
    });

    test('the body always opens on a recto', () {
      final result = layout(bookFixture());
      final firstBody = result.pages
          .firstWhere((page) => page.role == BookPageRole.chapterOpener);
      expect(firstBody.isRecto, isTrue);
      expect(result.stats.frontMatterPageCount.isEven, isTrue,
          reason: 'front matter is padded so the body starts on a recto');
    });

    test('the contents lists the folio each chapter really opens on', () {
      final result = layout(bookFixture());

      expect(result.toc, isNotEmpty);
      for (final entry in result.toc.where((e) => e.chapterId != null)) {
        final pageIndex = result.pageIndexForChapter(entry.chapterId!);
        expect(pageIndex, isNotNull,
            reason: '${entry.chapterId} has no opener page');
        expect(result.pages[pageIndex!].folio, entry.folio,
            reason: 'the contents points at the wrong page for '
                '${entry.title}');
      }
    });

    test('a title page carries neither folio nor running head', () {
      final result = layout(bookFixture());
      final title = result.pages.first;
      expect(title.role, BookPageRole.frontMatter);
      expect(title.folio, isNull);
      expect(title.runningHead, isNull);
    });
  });

  group('mirrored margins', () {
    test('the binding allowance swaps edges between recto and verso', () {
      final result = layout(bookFixture());
      final recto = result.pages.firstWhere((page) => page.isRecto);
      final verso = result.pages.firstWhere((page) => page.isVerso);

      expect(recto.textBlockLeftPt, greaterThan(recto.trimWidthPt -
          recto.textBlockRightPt));
      expect(verso.textBlockLeftPt, lessThan(recto.textBlockLeftPt));
      expect(recto.textBlockWidthPt, verso.textBlockWidthPt,
          reason: 'the measure is the same on both sides, which is why line '
              'breaking does not depend on which side a page is');
    });
  });

  group('parts', () {
    test('a part heading opens its own page before its first chapter', () {
      final book = bookFixture(parts: const [
        BookPart(
          id: 'part-1',
          startsAtChapterId: 'ch-1',
          title: 'Part One',
          order: 0,
        ),
        BookPart(
          id: 'part-2',
          startsAtChapterId: 'ch-3',
          title: 'Part Two',
          order: 1,
        ),
      ]);
      final result = layout(book);

      final partPages = result.pages
          .where((page) => page.role == BookPageRole.partTitle)
          .toList();
      expect(partPages, hasLength(2));

      final firstPart = partPages.first.index;
      final firstChapter = result.pageIndexForChapter('ch-1')!;
      expect(firstPart, lessThan(firstChapter));
    });

    test('a part anchored to a deleted chapter is reported, not dropped '
        'silently', () {
      final manuscript = manuscriptFixture();
      final book = bookFixture(parts: const [
        BookPart(
          id: 'part-ghost',
          startsAtChapterId: 'ch-deleted',
          title: 'Ghost',
          order: 0,
        ),
      ]);
      final document = const BookDocumentBuilder()
          .build(manuscript: manuscript, book: book);

      expect(
        document.issues.map((issue) => issue.code),
        contains('danglingPart'),
      );
      expect(
        document.body.whereType<BookPartElement>(),
        isEmpty,
        reason: 'a part with no anchor must not be rendered',
      );
    });
  });

  group('reproducibility', () {
    test('the same document and format always lay out identically', () {
      final book = bookFixture();
      final first = layout(book);
      final second = layout(book);

      expect(second.pageCount, first.pageCount);
      expect(second.toc.map((e) => '${e.title}|${e.folio}'),
          first.toc.map((e) => '${e.title}|${e.folio}'));

      for (var i = 0; i < first.pageCount; i++) {
        final a = first.pages[i];
        final b = second.pages[i];
        expect(b.folio, a.folio);
        expect(b.isRecto, a.isRecto);
        expect(b.role, a.role);
        expect(linesOf(b).map((l) => '${l.x}|${l.baselineY}|${l.text}'),
            linesOf(a).map((l) => '${l.x}|${l.baselineY}|${l.text}'));
      }
    });
  });

  group('presets', () {
    test('every paginated preset lays the fixture book out', () {
      for (final preset in BookFormatPresets.paginated) {
        final result = layout(bookFixture(format: preset), format: preset);
        expect(result.pageCount, greaterThan(0),
            reason: '${preset.label} produced no pages');
        expect(result.stats.wordCount, greaterThan(0));
      }
    });

    test('large print sets fewer lines to a page than paperback', () {
      // Compared by lines to a page, not by total pages: paperback opens its
      // chapters on a recto and so pads the book with blank versos, which would
      // swamp the comparison on a three-chapter fixture.
      // Measured on full body pages only. The contents page packs two short
      // lines per entry and would otherwise be the densest page in the book.
      int densestBodyPage(PaginatedBook book) => book.pages
          .where((page) => page.role == BookPageRole.body)
          .map((page) => linesOf(page).length)
          .fold<int>(0, (a, b) => a > b ? a : b);

      final long = longManuscriptFixture();
      final paperback = layout(
          bookFixture(format: BookFormatPresets.paperback),
          format: BookFormatPresets.paperback,
          manuscript: long);
      final large = layout(bookFixture(format: BookFormatPresets.largePrint),
          format: BookFormatPresets.largePrint, manuscript: long);

      expect(densestBodyPage(paperback), greaterThan(0),
          reason: 'the long fixture must produce full body pages');
      expect(densestBodyPage(large), lessThan(densestBodyPage(paperback)),
          reason: 'larger type on looser leading must fit fewer lines');
    });

    test('the print-on-demand gutter settles within the pass limit', () {
      final result = layout(
        bookFixture(format: BookFormatPresets.printOnDemand),
        format: BookFormatPresets.printOnDemand,
      );
      expect(result.stats.passes, lessThanOrEqualTo(BookLayoutEngine.maxPasses));
      expect(
        result.issues.map((issue) => issue.code),
        isNot(contains('gutterDrift')),
      );
    });
  });
}
