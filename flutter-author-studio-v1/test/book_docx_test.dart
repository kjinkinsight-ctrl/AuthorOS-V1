import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_docx_exporter.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'fixtures/book_studio_fixture.dart';

/// The fixed timestamp every export here is stamped with.
final DateTime _modified = DateTime.utc(2026, 3, 4, 5, 6, 7);

Uint8List exportDocx({
  DocxFlavour flavour = DocxFlavour.submission,
  BookFormat? format,
  List<BookPart> parts = const [],
  ManuscriptProjectSummary? manuscript,
  DateTime? modified,
}) {
  final project = bookFixture(format: format, parts: parts);
  final document = const BookDocumentBuilder().build(
    manuscript: manuscript ?? manuscriptFixture(),
    book: project,
    profileAuthorName: 'Kali Vale',
  );
  return const BookDocxExporter().export(
    document: document,
    flavour: flavour,
    modified: modified ?? _modified,
    format: format ?? BookFormatPresets.paperback,
  );
}

Archive open(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

String textOf(Archive archive, String name) {
  final file = archive.find(name);
  expect(file, isNotNull, reason: '$name is missing from the package');
  return utf8.decode(file!.readBytes()!);
}

XmlDocument xmlOf(Archive archive, String name) =>
    XmlDocument.parse(textOf(archive, name));

/// Every `w:p` in reading order, as (style id, text).
List<({String style, String text})> paragraphsOf(XmlDocument document) {
  final result = <({String style, String text})>[];
  for (final p in document.findAllElements('w:p')) {
    final style = p
            .findAllElements('w:pStyle')
            .firstOrNull
            ?.getAttribute('w:val') ??
        '';
    final text =
        p.findAllElements('w:t').map((node) => node.innerText).join();
    result.add((style: style, text: text));
  }
  return result;
}

void main() {
  group('the package', () {
    test('carries every part a Word document is required to have', () {
      final archive = open(exportDocx());

      for (final required in const [
        '[Content_Types].xml',
        '_rels/.rels',
        'docProps/core.xml',
        'docProps/app.xml',
        'word/_rels/document.xml.rels',
        'word/document.xml',
        'word/styles.xml',
        'word/settings.xml',
      ]) {
        expect(archive.find(required), isNotNull,
            reason: '$required is missing; Word will refuse the file');
      }
    });

    test('every part is declared in [Content_Types].xml', () {
      final archive = open(exportDocx());
      final types = xmlOf(archive, '[Content_Types].xml');

      final defaults = {
        for (final node in types.findAllElements('Default'))
          node.getAttribute('Extension')!,
      };
      final overrides = {
        for (final node in types.findAllElements('Override'))
          node.getAttribute('PartName')!,
      };

      for (final file in archive.files) {
        final extension = file.name.split('.').last;
        if (defaults.contains(extension)) continue;
        expect(overrides, contains('/${file.name}'),
            reason: '${file.name} has no content type; Word rejects the file');
      }
    });

    test('every relationship target resolves to a real part', () {
      final archive = open(exportDocx());

      for (final relsName in const [
        '_rels/.rels',
        'word/_rels/document.xml.rels',
      ]) {
        final base = relsName == '_rels/.rels' ? '' : 'word/';
        for (final rel in xmlOf(archive, relsName).findAllElements(
          'Relationship',
        )) {
          final target = rel.getAttribute('Target')!;
          final path = target.startsWith('/')
              ? target.substring(1)
              : '$base$target';
          expect(archive.find(path), isNotNull,
              reason: '$relsName points at $path, which is not in the package');
        }
      }
    });

    test('the same book exports byte for byte the same file', () {
      expect(exportDocx(), equals(exportDocx()));
    });

    test('a different modified time is the only thing that changes', () {
      final first = exportDocx();
      final later = exportDocx(modified: DateTime.utc(2027));
      expect(first, isNot(equals(later)));
    });
  });

  group('the document', () {
    test('reads in book order: front matter, body, back matter', () {
      final archive = open(exportDocx(parts: const [
        BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
      ]));
      final paragraphs = paragraphsOf(xmlOf(archive, 'word/document.xml'));
      final text = paragraphs.map((p) => p.text).toList();

      expect(text.first, 'The Widow Knife', reason: 'the title page is first');
      expect(text, contains('Part One'));
      expect(text, contains('The Arrival'));
      expect(text.indexOf('Part One'), lessThan(text.indexOf('The Arrival')));
      expect(text.indexOf('The Arrival'),
          lessThan(text.indexOf('The Blood Price')));
    });

    test('every paragraph is a named style, never direct formatting', () {
      final archive = open(exportDocx());
      final document = xmlOf(archive, 'word/document.xml');

      for (final paragraph in paragraphsOf(document)) {
        expect(paragraph.style, isNotEmpty,
            reason: 'a paragraph carries no style: ${paragraph.text}');
      }

      // Direct run formatting would defeat the point of named styles: an
      // editor could no longer restyle the manuscript in one action.
      expect(document.findAllElements('w:rPr'), isEmpty,
          reason: 'the body carries direct run formatting');
    });

    test('every style the body names is defined in styles.xml', () {
      final archive = open(exportDocx());
      final defined = {
        for (final style in xmlOf(archive, 'word/styles.xml')
            .findAllElements('w:style'))
          style.getAttribute('w:styleId')!,
      };

      for (final paragraph
          in paragraphsOf(xmlOf(archive, 'word/document.xml'))) {
        expect(defined, contains(paragraph.style),
            reason: '${paragraph.style} is used but never defined');
      }
    });

    test('chapter titles are Heading 1, so Word can navigate the book', () {
      final archive = open(exportDocx());
      final paragraphs = paragraphsOf(xmlOf(archive, 'word/document.xml'));
      final headings = paragraphs
          .where((p) => p.style == 'Heading1')
          .map((p) => p.text)
          .toList();

      expect(headings, containsAll(<String>[
        'The Arrival',
        'The Blood Price',
        'Endovier',
      ]));

      // The built-in name is what puts it in the navigation pane; a custom
      // name would look identical and do nothing.
      final heading1 = xmlOf(archive, 'word/styles.xml')
          .findAllElements('w:style')
          .firstWhere((s) => s.getAttribute('w:styleId') == 'Heading1');
      expect(heading1.findAllElements('w:name').single.getAttribute('w:val'),
          'heading 1');
    });

    test('the chapter number carries the break, and the title does not', () {
      final archive = open(exportDocx());
      final paragraphs =
          xmlOf(archive, 'word/document.xml').findAllElements('w:p').toList();

      final numberIndex = paragraphs.indexWhere((p) =>
          p.findAllElements('w:pStyle').firstOrNull?.getAttribute('w:val') ==
          'ChapterNumber');
      expect(numberIndex, greaterThan(-1));

      final title = paragraphs[numberIndex + 1];
      expect(
          title.findAllElements('w:pStyle').single.getAttribute('w:val'),
          'Heading1',
          reason: 'the title must follow its number');

      // Without this the number is stranded alone at the top of a page and the
      // title lands a third of a page below it.
      final breakBefore =
          title.findAllElements('w:pageBreakBefore').single;
      expect(breakBefore.getAttribute('w:val'), 'false');
      expect(
          title
              .findAllElements('w:spacing')
              .single
              .getAttribute('w:before'),
          '0',
          reason: 'the sink is on the number; the title must not sink again');
    });

    test('the first paragraph never breaks the page', () {
      final first = xmlOf(open(exportDocx()), 'word/document.xml')
          .findAllElements('w:p')
          .first;
      expect(first.findAllElements('w:pageBreakBefore').single
          .getAttribute('w:val'), 'false',
          reason: 'a break here opens the document on a blank page');
    });

    test('the opening paragraph of a scene is not indented', () {
      final archive = open(exportDocx(
        manuscript: longManuscriptFixture(paragraphs: 4),
      ));
      final body = paragraphsOf(xmlOf(archive, 'word/document.xml'))
          .where((p) => p.style.startsWith('BodyText'))
          .toList();

      expect(body.first.style, 'BodyTextFirst');
      expect(body.skip(1).map((p) => p.style), everyElement('BodyText'));
    });

    test('the contents page is a TOC field, not numbers that would be wrong',
        () {
      final document = xmlOf(open(exportDocx()), 'word/document.xml');
      final instructions = document
          .findAllElements('w:instrText')
          .map((node) => node.innerText)
          .toList();

      expect(instructions.single, contains('TOC'));
      expect(instructions.single, contains(r'\o "1-1"'),
          reason: 'the contents is built from Heading 1 alone');

      // Word evaluates the field on open, so the author never sees the
      // placeholder; a reader that does not gets the placeholder rather than
      // a blank page.
      expect(xmlOf(open(exportDocx()), 'word/settings.xml')
          .findAllElements('w:updateFields'), isNotEmpty);
    });
  });

  group('the two flavours', () {
    test('submission is double-spaced on one-inch letter paper', () {
      final archive = open(exportDocx(flavour: DocxFlavour.submission));
      final section = xmlOf(archive, 'word/document.xml')
          .findAllElements('w:sectPr')
          .single;

      expect(section.findAllElements('w:pgSz').single.getAttribute('w:w'),
          '12240');
      expect(section.findAllElements('w:pgSz').single.getAttribute('w:h'),
          '15840');
      final margins = section.findAllElements('w:pgMar').single;
      for (final edge in const ['w:top', 'w:right', 'w:bottom', 'w:left']) {
        expect(margins.getAttribute(edge), '1440', reason: '$edge is not 1 in');
      }

      final bodyText = xmlOf(archive, 'word/styles.xml')
          .findAllElements('w:style')
          .firstWhere((s) => s.getAttribute('w:styleId') == 'BodyText');
      expect(bodyText.findAllElements('w:spacing').single.getAttribute('w:line'),
          '480', reason: 'submission format is double-spaced');
      expect(bodyText.findAllElements('w:jc').single.getAttribute('w:val'),
          'left', reason: 'a working copy is set ragged right');
    });

    test('submission carries the Surname / TITLE / page header', () {
      final archive = open(exportDocx(flavour: DocxFlavour.submission));
      final header = xmlOf(archive, 'word/header1.xml');

      expect(header.findAllElements('w:t').first.innerText,
          startsWith('Vale / THE WIDOW KNIFE'));
      // A live field, so it stays right as the document is edited.
      expect(header.findAllElements('w:fldSimple').single
          .getAttribute('w:instr'), ' PAGE ');
    });

    test('typeset follows the book it was set from', () {
      final format = BookFormatPresets.paperback;
      final archive = open(exportDocx(
        flavour: DocxFlavour.typeset,
        format: format,
      ));
      final section = xmlOf(archive, 'word/document.xml')
          .findAllElements('w:sectPr')
          .single;

      expect(section.findAllElements('w:pgSz').single.getAttribute('w:w'),
          '${(format.trim.widthPt * 20).round()}');
      expect(section.findAllElements('w:pgSz').single.getAttribute('w:h'),
          '${(format.trim.heightPt * 20).round()}');

      // No running header: the book carries its own, and Word would print
      // both.
      expect(section.findAllElements('w:headerReference'), isEmpty);
      expect(archive.find('word/header1.xml'), isNull);
    });

    test('typeset sinks a chapter by the same fraction the book does', () {
      final format = BookFormatPresets.paperback;
      final archive = open(exportDocx(
        flavour: DocxFlavour.typeset,
        format: format,
      ));
      final heading1 = xmlOf(archive, 'word/styles.xml')
          .findAllElements('w:style')
          .firstWhere((s) => s.getAttribute('w:styleId') == 'Heading1');

      // Measured against the text block, as the layout engine measures it —
      // not against the trim, which would sink it too far.
      final textHeight = format.trim.heightPt -
          format.margins.topPt -
          format.margins.bottomPt;
      expect(
        heading1.findAllElements('w:spacing').single.getAttribute('w:before'),
        '${(textHeight * format.chapter.sinkFraction * 20).round()}',
      );
    });

    test('a display style never inherits the body’s pinned leading', () {
      // With lineRule="exact" a larger run is clipped, so every style that
      // sets its own size overrides the leading back to automatic.
      final styles = xmlOf(
        open(exportDocx(flavour: DocxFlavour.typeset)),
        'word/styles.xml',
      );

      for (final id in const [
        'Heading1',
        'PartTitle',
        'ChapterNumber',
        'BookTitle',
        'BookSubtitle',
        'FrontMatter',
        'SceneBreak',
      ]) {
        final style = styles
            .findAllElements('w:style')
            .firstWhere((s) => s.getAttribute('w:styleId') == id);
        expect(
            style.findAllElements('w:spacing').single.getAttribute('w:lineRule'),
            'auto',
            reason: '$id would be clipped by the body leading');
      }
    });
  });

  group('the author’s prose survives', () {
    test('characters that would break XML round-trip through a real parse', () {
      final archive = open(exportDocx(
        manuscript: manuscriptFixtureWithProse(
          'Smith & Sons said "go" <now> — 5 < 6 and it’s done.',
        ),
      ));

      final text = paragraphsOf(xmlOf(archive, 'word/document.xml'))
          .map((p) => p.text)
          .join('\n');
      expect(text, contains('Smith & Sons said "go" <now> — 5 < 6'));
    });

    test('leading and trailing spaces are preserved, not trimmed by Word', () {
      final document = xmlOf(open(exportDocx()), 'word/document.xml');
      for (final run in document.findAllElements('w:t')) {
        expect(run.getAttribute('xml:space'), 'preserve',
            reason: 'Word silently trims a run without this');
      }
    });

    test('the metadata Word shows in File > Properties is the book’s', () {
      final core = xmlOf(open(exportDocx()), 'docProps/core.xml');
      expect(core.findAllElements('dc:title').single.innerText,
          'The Widow Knife');
      expect(core.findAllElements('dc:creator').single.innerText, 'Kali Vale');
      expect(core.findAllElements('dcterms:modified').single.innerText,
          '2026-03-04T05:06:07Z');
    });
  });
}
