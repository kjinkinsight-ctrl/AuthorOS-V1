/// What the author marks in the editor is what the book sets.
///
/// Book Studio grew its own emphasis convention — `_like this_` — while
/// Manuscript Studio grew a real formatting toolbar writing real
/// [ProseMark]s. Two answers to one question is the drift this codebase keeps
/// finding and keeps deleting, and the resolution is that the marks win: they
/// are what the author actually pressed a button to say.
///
/// These tests pin that seam from both sides. A mark applied in the editor must
/// reach the PDF, the ebook and the Word file. A manuscript written before the
/// toolbar existed must keep working exactly as it did, because there are far
/// more of those.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/book/book_docx_exporter.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_epub_exporter.dart';
import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_text_exporter.dart';
import 'package:author_studio_v1/book/epub_settings.dart';
import 'package:author_studio_v1/book/inline_markup.dart';
import 'package:author_studio_v1/book/preflight.dart';
import 'package:author_studio_v1/book/preflight_checks.dart';
import 'package:author_studio_v1/book/proofing.dart';
import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

/// `She read The Kestrel twice.` with the title marked, as the toolbar writes
/// it: three spans, the middle one carrying [ProseMark.italic].
ProseDocument marked({Set<ProseMark> marks = const {ProseMark.italic}}) =>
    ProseDocument([
      ProseBlock(spans: [
        const ProseSpan('She read '),
        ProseSpan('The Kestrel', marks: marks),
        const ProseSpan(' twice.'),
      ]),
    ]);

BookDocument build(
  ManuscriptProjectSummary manuscript, {
  BookInlineMarkup markup = BookInlineMarkup.none,
}) {
  final format = BookFormatPresets.paperback.copyWith(
    typography: BookFormatPresets.paperback.typography
        .copyWith(inlineMarkup: markup),
  );
  return const BookDocumentBuilder().build(
    manuscript: manuscript,
    book: bookFixture(format: format),
    profileAuthorName: 'Kali Vale',
  );
}

/// The first chapter's XHTML, out of a real exported EPUB.
String chapterXhtml(BookDocument document) {
  final bytes = const BookEpubExporter().export(
    document: document,
    settings: EpubSettings.defaults,
    projectId: 'project-book',
    modified: DateTime.utc(2026),
  );
  final archive = ZipDecoder().decodeBytes(bytes);
  return utf8.decode(archive.files
      .firstWhere((file) =>
          file.name.contains('chapter') && file.name.endsWith('.xhtml'))
      .content as List<int>);
}

BookParagraph firstParagraph(BookDocument document) =>
    document.chapters.first.scenes.first.paragraphs.first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookFontAssets assets;

  setUpAll(() async {
    BookFontAssets.resetCache();
    assets = await BookFontAssets.load();
  });

  group('reading the marks', () {
    test('a mark applied in the editor is emphasis, convention or not', () {
      // The convention is off. Before this seam existed that meant no emphasis
      // at all, and the italic the author applied vanished on the way out.
      final document = build(manuscriptFixtureWithDocument(marked()));
      final spans = firstParagraph(document).resolve(BookInlineMarkup.none);

      expect(spans.map((span) => span.text).join(),
          'She read The Kestrel twice.');
      expect(spans.where((span) => span.italic).map((span) => span.text),
          ['The Kestrel']);
    });

    test('a paragraph carrying no marks still reads the typed convention', () {
      // The two coexist. Marking one paragraph with the toolbar must not stop
      // every other paragraph in the manuscript honouring the underscores it
      // was written with — otherwise adopting the toolbar silently
      // un-italicises the book above it.
      final prose = ProseDocument([
        ProseBlock(spans: [
          const ProseSpan('She read '),
          const ProseSpan('The Kestrel', marks: {ProseMark.italic}),
          const ProseSpan(' twice.'),
        ]),
        ProseBlock.paragraph('The light went out on _The Ravel_ after.'),
      ]);
      final document = build(manuscriptFixtureWithDocument(prose),
          markup: BookInlineMarkup.underscoreItalic);
      final paragraphs = document.chapters.first.scenes.first.paragraphs;

      expect(paragraphs, hasLength(2));
      expect(paragraphs.first.marked, isNotNull);
      expect(paragraphs.last.marked, isNull,
          reason: 'an unmarked paragraph is left to the convention');
      expect(
        paragraphs.last
            .resolve(BookInlineMarkup.underscoreItalic)
            .where((span) => span.italic)
            .map((span) => span.text),
        ['The Ravel'],
      );
    });

    test('where the author marked, an underscore stays an underscore', () {
      final prose = ProseDocument([
        ProseBlock(spans: [
          const ProseSpan('The file is '),
          const ProseSpan('read_me', marks: {ProseMark.italic}),
          const ProseSpan(' and _this_ is not emphasis.'),
        ]),
      ]);
      final spans = firstParagraph(build(manuscriptFixtureWithDocument(prose),
              markup: BookInlineMarkup.underscoreItalic))
          .resolve(BookInlineMarkup.underscoreItalic);

      expect(spans.map((span) => span.text).join(),
          'The file is read_me and _this_ is not emphasis.',
          reason: 'the author said what they meant with the toolbar; re-reading '
              'their prose for a second opinion is how a file name becomes an '
              'italic by accident');
    });

    test('a document that has drifted from its scene is ignored', () {
      // Something wrote the string without the document. Its span boundaries
      // now point at the wrong words, so the marks would land on the wrong
      // prose — worse than having none.
      final document = build(
        manuscriptFixtureWithDocument(marked(),
            content: 'Something else entirely was written here.'),
      );
      final paragraph = firstParagraph(document);

      expect(paragraph.text, 'Something else entirely was written here.');
      expect(paragraph.marked, isNull);
    });

    test('marks survive the trim that makes a line a paragraph', () {
      final prose = ProseDocument([
        ProseBlock(spans: [
          const ProseSpan('   She read '),
          const ProseSpan('The Kestrel', marks: {ProseMark.italic}),
          const ProseSpan(' twice.   '),
        ]),
      ]);
      final paragraph =
          firstParagraph(build(manuscriptFixtureWithDocument(prose)));

      expect(paragraph.text, 'She read The Kestrel twice.');
      expect(paragraph.marked!.map((span) => span.text).join(),
          paragraph.text,
          reason: 'spans that still carried the indent would set the marks one '
              'character out from the text beside them');
    });

    test('a manuscript with no documents at all is untouched', () {
      final document = build(
          manuscriptFixtureWithProse('She read _The Kestrel_ twice.'),
          markup: BookInlineMarkup.underscoreItalic);
      final paragraph = firstParagraph(document);

      expect(paragraph.marked, isNull);
      expect(
        paragraph
            .resolve(BookInlineMarkup.underscoreItalic)
            .where((span) => span.italic)
            .map((span) => span.text),
        ['The Kestrel'],
      );
    });
  });

  group('the marks reach every format', () {
    late BookDocument document;

    setUp(() => document = build(manuscriptFixtureWithDocument(marked())));

    test('the page sets the marked words in a real italic face', () {
      final book = BookLayoutEngine(PdfBookFontMetrics(assets))
          .layout(document, BookFormatPresets.paperback);

      final italic = <String>[];
      for (final page in book.pages) {
        for (final line in page.elements.whereType<LayoutTextLine>()) {
          for (final run in line.runs) {
            if (run.face.style == BookFontStyleId.italic) italic.add(run.text);
          }
        }
      }
      expect(italic.join(' '), contains('Kestrel'));
      expect(italic.join(' '), isNot(contains('twice')));
    });

    test('the ebook writes an <em> around them', () {
      final xhtml = chapterXhtml(document);
      expect(xhtml, contains('<em>The Kestrel</em>'));
    });

    test('the Word file writes a run with w:i on it', () {
      final bytes = const BookDocxExporter().export(
        document: document,
        flavour: DocxFlavour.submission,
        modified: DateTime.utc(2026),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(archive.files
          .firstWhere((file) => file.name == 'word/document.xml')
          .content as List<int>);

      final run = RegExp(r'<w:r><w:rPr><w:i\s*/><w:iCs\s*/></w:rPr>'
              r'<w:t[^>]*>([^<]*)</w:t></w:r>')
          .allMatches(xml)
          .map((match) => match.group(1))
          .toList();
      expect(run, contains('The Kestrel'));
    });

    test('plain text sets nothing, because plain text cannot', () {
      final text = const BookTextExporter().export(document: document);

      // The author typed no underscores, so there are none to keep. A text
      // export inventing them would be putting words in their mouth.
      expect(text, contains('She read The Kestrel twice.'));
      expect(text, isNot(contains('_')));
    });
  });

  group('marks a book cannot set', () {
    PreflightReport check(Set<ProseMark> marks) {
      final document = build(manuscriptFixtureWithDocument(marked(marks: marks)));
      return const PreflightEngine().run(
        PreflightContext(
          document: document,
          target: BookExportFormat.printPdf,
          format: BookFormatPresets.paperback,
        ),
      );
    }

    test('an italic passes without comment', () {
      expect(
        check({ProseMark.italic})
            .findings
            .where((finding) => finding.ruleId == 'unsettableMark'),
        isEmpty,
      );
    });

    test('a bold is reported rather than dropped in silence', () {
      final findings = check({ProseMark.bold})
          .findings
          .where((finding) => finding.ruleId == 'unsettableMark')
          .toList();

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('Bold'));
      expect(findings.single.severity, ProofSeverity.warning,
          reason: 'the file is not wrong, it is only less than the manuscript');
    });

    test('every unsettable mark is named, in a stable order', () {
      final findings = check({
        ProseMark.strikethrough,
        ProseMark.bold,
        ProseMark.underline,
      })
          .findings
          .where((finding) => finding.ruleId == 'unsettableMark')
          .map((finding) => finding.title)
          .toList();

      expect(findings, hasLength(3));
      expect(findings[0], contains('Bold'));
      expect(findings[1], contains('Underlined'));
      expect(findings[2], contains('Struck-through'));
    });

    test('a mark the book cannot set still exports the words', () {
      final xhtml = chapterXhtml(
          build(manuscriptFixtureWithDocument(marked(marks: {ProseMark.bold}))));

      expect(xhtml, contains('The Kestrel'));
      expect(xhtml, isNot(contains('<em>')));
    });
  });

  group('the count the author is shown', () {
    test('counts real marks whether the convention is on or off', () {
      final document = build(manuscriptFixtureWithDocument(marked()));

      expect(countEmphasis(document, BookInlineMarkup.none), 1);
      expect(countEmphasis(document, BookInlineMarkup.underscoreItalic), 1,
          reason: 'switching the convention on adds nothing here, because '
              'nothing in this prose is typed with underscores');
    });

    test('counts both kinds when a book holds both', () {
      final prose = ProseDocument([
        ProseBlock(spans: [
          const ProseSpan('She read '),
          const ProseSpan('The Kestrel', marks: {ProseMark.italic}),
          const ProseSpan(' twice.'),
        ]),
        ProseBlock.paragraph('The light went out on _The Ravel_ after.'),
      ]);
      final document = build(manuscriptFixtureWithDocument(prose));

      expect(countEmphasis(document, BookInlineMarkup.none), 1);
      expect(countEmphasis(document, BookInlineMarkup.underscoreItalic), 2);
    });
  });

  group('nothing else changed', () {
    test('a book with no marks exports exactly as it did', () {
      // The whole safety claim. Every manuscript in existence is this one.
      final withoutMarks = const BookTextExporter().export(
          document: build(manuscriptFixtureWithProse('She read it twice.')));
      final asDocument = const BookTextExporter().export(
          document: build(manuscriptFixtureWithDocument(
              ProseDocument.fromPlainText('She read it twice.'))));

      expect(asDocument, withoutMarks,
          reason: 'a document holding no marks is the same book as the string '
              'it came from');
    });
  });
}
