/// Inline emphasis, from the author's keystroke to every format that ships.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/book/book_docx_exporter.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_epub_exporter.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_text_exporter.dart';
import 'package:author_studio_v1/book/epub_settings.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'fixtures/book_studio_fixture.dart';

const _prose = 'She read _The Kestrel_ twice before the light went.';

ManuscriptProjectSummary emphasised([String prose = _prose]) =>
    manuscriptFixtureWithProse(prose);

BookFormat withMarkup(BookFormat base, BookInlineMarkup markup) =>
    base.copyWith(
      typography: base.typography.copyWith(inlineMarkup: markup),
    );

BookDocument document({
  BookInlineMarkup markup = BookInlineMarkup.underscoreItalic,
  BookFormat? base,
  String prose = _prose,
}) {
  final format = withMarkup(base ?? BookFormatPresets.paperback, markup);
  return const BookDocumentBuilder().build(
    manuscript: emphasised(prose),
    book: bookFixture(format: format),
    profileAuthorName: 'Kali Vale',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookFontAssets assets;

  setUpAll(() async {
    BookFontAssets.resetCache();
    assets = await BookFontAssets.load();
  });

  group('the printed page', () {
    PaginatedBook lay({
      BookInlineMarkup markup = BookInlineMarkup.underscoreItalic,
      BookFontMetrics? metrics,
      String prose = _prose,
      BookFormat? base,
    }) {
      final format = withMarkup(base ?? BookFormatPresets.paperback, markup);
      return BookLayoutEngine(metrics ?? PdfBookFontMetrics(assets))
          .layout(document(markup: markup, base: base, prose: prose), format);
    }

    /// Body prose only. Chapter titles are set bold by the chapter style and
    /// have nothing to do with the author's emphasis.
    List<LayoutTextRun> runsOf(PaginatedBook book) => [
          for (final page in book.pages)
            for (final line in page.elements.whereType<LayoutTextLine>())
              if (line.paragraphId.isNotEmpty) ...line.runs,
        ];

    test('emphasis is set in a real italic face', () {
      final italic = runsOf(lay())
          .where((run) => run.face.style == BookFontStyleId.italic)
          .toList();

      expect(italic, isNotEmpty, reason: 'nothing was set in italic at all');
      expect(italic.map((run) => run.text).join(), contains('Kestrel'));
    });

    test('the markers themselves never reach the page', () {
      final text = runsOf(lay()).map((run) => run.text).join();
      expect(text, isNot(contains('_')));
      expect(text, contains('The Kestrel'));
    });

    test('with the convention off, the underscores are the prose', () {
      final runs = runsOf(lay(markup: BookInlineMarkup.none));
      expect(runs.map((r) => r.text).join(), contains('_The Kestrel_'));
      expect(runs.every((r) => r.face.style == BookFontStyleId.regular),
          isTrue);
    });

    test('the width of an emphasised span is really measured in its own face',
        () {
      // With a fake that makes italic three times as wide, a paragraph with
      // emphasis in it must break differently from the same paragraph without.
      // If the breaker measured everything as roman these would match.
      const long = 'A _very much longer emphasised stretch of prose here_ end '
          'of it and then some more words to force a second line or two.';

      int linesWith(double factor) => lay(
            metrics: FakeBookFontMetrics(italicFactor: factor),
            prose: long,
          ).pages.fold<int>(
              0,
              (sum, page) =>
                  sum + page.elements.whereType<LayoutTextLine>().length);

      expect(linesWith(3.0), greaterThan(linesWith(1.0)),
          reason: 'a wider italic must take more lines');
    });

    test('a line is one run when nothing in it is emphasised', () {
      // The unjustified single-run case, which is what the golden fixtures
      // pin. Segments must not fragment a line that has one face.
      final book = lay(
        markup: BookInlineMarkup.none,
        base: BookFormatPresets.paperback.copyWith(
          typography: BookFormatPresets.paperback.typography
              .copyWith(alignment: BookAlignment.left),
        ),
      );
      final body = [
        for (final page in book.pages)
          for (final line in page.elements.whereType<LayoutTextLine>())
            if (line.paragraphId.isNotEmpty) line,
      ];

      expect(body, isNotEmpty);
      expect(body.every((line) => line.runs.length == 1), isTrue,
          reason: 'an unemphasised line must still be a single run');
    });

    test('a drop cap is a letter, never an emphasis marker', () {
      final format = withMarkup(
        BookFormatPresets.paperback.copyWith(
          chapter: BookFormatPresets.paperback.chapter.copyWith(dropCap: true),
        ),
        BookInlineMarkup.underscoreItalic,
      );
      final book = BookLayoutEngine(PdfBookFontMetrics(assets)).layout(
        const BookDocumentBuilder().build(
          manuscript: emphasised('_The Kestrel_ came in on the tide.'),
          book: bookFixture(format: format),
          profileAuthorName: 'Kali Vale',
        ),
        format,
      );

      final caps = [
        for (final page in book.pages) ...page.elements.whereType<LayoutDropCap>(),
      ];
      expect(caps, isNotEmpty);
      expect(caps.first.glyph, 'T',
          reason: 'the paragraph opens with a marker; the cap is the letter');
    });

    test('the line text a reader sees carries no notation', () {
      final book = lay();
      for (final page in book.pages) {
        for (final line in page.elements.whereType<LayoutTextLine>()) {
          expect(line.text, isNot(contains('_')));
        }
      }
    });
  });

  group('EPUB', () {
    XmlDocument chapterOf(BookInlineMarkup markup) {
      final bytes = const BookEpubExporter().export(
        document: document(markup: markup),
        settings: EpubSettings.defaults,
        projectId: 'project-book',
        modified: DateTime.utc(2026),
        fonts: assets,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final file = archive.files.firstWhere(
          (f) => f.name.contains('chapter') && f.name.endsWith('.xhtml'));
      return XmlDocument.parse(utf8.decode(file.readBytes()!));
    }

    test('emphasis is an <em>, which every reading system understands', () {
      final chapter = chapterOf(BookInlineMarkup.underscoreItalic);
      final ems = chapter.findAllElements('em').toList();

      expect(ems, hasLength(1));
      expect(ems.single.innerText, 'The Kestrel');
      expect(chapter.rootElement.innerText, isNot(contains('_')));
    });

    test('with the convention off there is no emphasis and no loss', () {
      final chapter = chapterOf(BookInlineMarkup.none);
      expect(chapter.findAllElements('em'), isEmpty);
      expect(chapter.rootElement.innerText, contains('_The Kestrel_'));
    });
  });

  group('DOCX', () {
    XmlDocument documentXml(BookInlineMarkup markup) {
      final bytes = const BookDocxExporter().export(
        document: document(markup: markup),
        flavour: DocxFlavour.submission,
        modified: DateTime.utc(2026),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      return XmlDocument.parse(
          utf8.decode(archive.findFile('word/document.xml')!.content));
    }

    test('emphasis is a run marked w:i, not a character Word has to guess at',
        () {
      final doc = documentXml(BookInlineMarkup.underscoreItalic);

      final italicRuns = doc
          .findAllElements('w:r')
          .where((run) => run.findElements('w:rPr').any(
              (rPr) => rPr.findElements('w:i').isNotEmpty))
          .toList();

      expect(italicRuns, hasLength(1));
      expect(italicRuns.single.findAllElements('w:t').single.innerText,
          'The Kestrel');
      expect(doc.rootElement.innerText, isNot(contains('_')));
    });

    test('the paragraph still reads as one sentence across its runs', () {
      final doc = documentXml(BookInlineMarkup.underscoreItalic);
      final paragraph = doc.findAllElements('w:p').firstWhere((p) =>
          p.findAllElements('w:t').any((t) => t.innerText.contains('Kestrel')));

      expect(paragraph.findAllElements('w:t').map((t) => t.innerText).join(),
          'She read The Kestrel twice before the light went.');
    });

    test('with the convention off no run is italic', () {
      final doc = documentXml(BookInlineMarkup.none);
      expect(doc.findAllElements('w:i'), isEmpty);
      expect(doc.rootElement.innerText, contains('_The Kestrel_'));
    });
  });

  group('plain text', () {
    test('keeps the author’s own notation, because it is the only emphasis '
        'a text file has', () {
      final text = const BookTextExporter().export(
        document: document(),
        format: withMarkup(
            BookFormatPresets.paperback, BookInlineMarkup.underscoreItalic),
      );
      expect(text, contains('_The Kestrel_'));
    });
  });

  group('reproducibility', () {
    test('a book with the convention off is unchanged by this phase existing',
        () {
      // The whole safety claim of an opt-in default: an author who never turns
      // this on gets exactly the file they got before.
      final off = const BookTextExporter().export(document: document(
          markup: BookInlineMarkup.none));
      expect(off, contains('_The Kestrel_'));

      final bytes = const BookDocxExporter().export(
        document: document(markup: BookInlineMarkup.none),
        flavour: DocxFlavour.submission,
        modified: DateTime.utc(2026),
      );
      final again = const BookDocxExporter().export(
        document: document(markup: BookInlineMarkup.none),
        flavour: DocxFlavour.submission,
        modified: DateTime.utc(2026),
      );
      expect(Uint8List.fromList(bytes), orderedEquals(again));
    });
  });
}
