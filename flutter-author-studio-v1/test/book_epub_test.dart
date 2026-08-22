import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_epub_exporter.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/epub_settings.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'fixtures/book_studio_fixture.dart';

/// The fixed timestamp every export in this file is stamped with, so
/// `dcterms:modified` is a value the tests can name.
final DateTime _modified = DateTime.utc(2026, 3, 4, 5, 6, 7);

Uint8List exportEpub({
  EpubSettings settings = EpubSettings.defaults,
  List<BookPart> parts = const [],
  BookProject? book,
  DateTime? modified,
}) {
  final project = book ?? bookFixture(parts: parts);
  final document = const BookDocumentBuilder().build(
    manuscript: manuscriptFixture(),
    book: project,
    profileAuthorName: 'Kali Vale',
  );
  return const BookEpubExporter().export(
    document: document,
    settings: settings,
    projectId: 'project-book',
    modified: modified ?? _modified,
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

void main() {
  group('the container', () {
    test('mimetype is the first entry and is stored, not deflated', () {
      final archive = open(exportEpub());

      // The single most common reason an otherwise-correct EPUB is rejected.
      expect(archive.files.first.name, 'mimetype',
          reason: 'mimetype must be the first entry in the zip');
      expect(archive.files.first.compression, CompressionType.none,
          reason: 'mimetype must be stored uncompressed');
      expect(utf8.decode(archive.files.first.readBytes()!),
          'application/epub+zip');
    });

    test('container.xml points at the package document', () {
      final archive = open(exportEpub());
      final container = xmlOf(archive, 'META-INF/container.xml');

      final rootfile = container.findAllElements('rootfile').single;
      expect(rootfile.getAttribute('full-path'), 'OEBPS/content.opf');
      expect(rootfile.getAttribute('media-type'),
          'application/oebps-package+xml');
      expect(archive.find('OEBPS/content.opf'), isNotNull);
    });

    test('every entry the manifest names really exists', () {
      final archive = open(exportEpub());
      final opf = xmlOf(archive, 'OEBPS/content.opf');

      for (final item in opf.findAllElements('item')) {
        final href = item.getAttribute('href')!;
        expect(archive.find('OEBPS/$href'), isNotNull,
            reason: 'the manifest names $href but the package has no such '
                'file');
      }
    });
  });

  group('the package document', () {
    test('carries the metadata EPUB 3 requires', () {
      final opf = xmlOf(open(exportEpub()), 'OEBPS/content.opf');
      final metadata = opf.findAllElements('metadata').single;

      expect(metadata.findElements('dc:title').first.innerText,
          'The Widow Knife');
      expect(metadata.findElements('dc:creator').first.innerText, 'Kali Vale');
      expect(metadata.findElements('dc:language').first.innerText, 'en');

      final identifier = metadata.findElements('dc:identifier').single;
      expect(identifier.getAttribute('id'), 'pub-id');
      expect(opf.rootElement.getAttribute('unique-identifier'), 'pub-id');

      final modified = metadata
          .findElements('meta')
          .firstWhere((e) => e.getAttribute('property') == 'dcterms:modified');
      expect(modified.innerText, '2026-03-04T05:06:07Z',
          reason: 'the spec requires UTC with no fractional seconds');
    });

    test('an ISBN becomes the identifier when the author set one', () {
      final opf = xmlOf(open(exportEpub()), 'OEBPS/content.opf');
      expect(opf.findAllElements('dc:identifier').single.innerText,
          'urn:isbn:9781000000000');
    });

    test('a book with no ISBN gets a stable identifier, not a fresh one', () {
      final withoutIsbn = bookFixture().copyWith(isbn: '');
      final first = xmlOf(open(exportEpub(book: withoutIsbn)),
              'OEBPS/content.opf')
          .findAllElements('dc:identifier')
          .single
          .innerText;
      final second = xmlOf(open(exportEpub(book: withoutIsbn)),
              'OEBPS/content.opf')
          .findAllElements('dc:identifier')
          .single
          .innerText;

      expect(first, startsWith('urn:uuid:'));
      expect(first, second,
          reason: 'dc:identifier names the work; a new one each export would '
              'leave a reader with duplicates instead of an update');
      expect(
        first,
        matches(RegExp(
            r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
        reason: 'it must still be a well-formed UUID',
      );
    });

    test('every spine idref resolves to a manifest item', () {
      final opf = xmlOf(open(exportEpub()), 'OEBPS/content.opf');
      final ids = opf
          .findAllElements('item')
          .map((item) => item.getAttribute('id'))
          .toSet();

      final refs = opf
          .findAllElements('itemref')
          .map((ref) => ref.getAttribute('idref'))
          .toList();
      expect(refs, isNotEmpty);
      for (final ref in refs) {
        expect(ids, contains(ref),
            reason: 'the spine references $ref, which nothing in the manifest '
                'declares');
      }
    });

    test('manifest ids are unique', () {
      final opf = xmlOf(open(exportEpub()), 'OEBPS/content.opf');
      final ids = opf
          .findAllElements('item')
          .map((item) => item.getAttribute('id')!)
          .toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('the navigation document is declared and reachable', () {
      final opf = xmlOf(open(exportEpub()), 'OEBPS/content.opf');
      final nav = opf.findAllElements('item').firstWhere(
          (item) => item.getAttribute('properties') == 'nav');
      expect(nav.getAttribute('href'), 'nav.xhtml');
      expect(opf.findAllElements('spine').single.getAttribute('toc'), 'ncx');
    });
  });

  group('structure', () {
    test('one document per chapter, in the book\'s own order', () {
      final archive = open(exportEpub());
      final opf = xmlOf(archive, 'OEBPS/content.opf');

      final manifest = {
        for (final item in opf.findAllElements('item'))
          item.getAttribute('id')!: item.getAttribute('href')!,
      };
      final spineHrefs = opf
          .findAllElements('itemref')
          .map((ref) => manifest[ref.getAttribute('idref')]!)
          .toList();

      final chapters =
          spineHrefs.where((href) => href.startsWith('text/chapter-')).toList();
      expect(chapters, hasLength(3),
          reason: 'the fixture has three chapters');
      expect(chapters, [
        'text/chapter-ch-1.xhtml',
        'text/chapter-ch-2.xhtml',
        'text/chapter-ch-3.xhtml',
      ]);
    });

    test('the contents is the navigation document, not a second page', () {
      final archive = open(exportEpub());
      final names = archive.files.map((file) => file.name).toList();

      expect(names, contains('OEBPS/nav.xhtml'));
      expect(names.where((name) => name.contains('contents')), isEmpty,
          reason: 'a separate contents page would be a second table of '
              'contents that can disagree with the navigation document');

      final opf = xmlOf(archive, 'OEBPS/content.opf');
      expect(
        opf.findAllElements('itemref').map((r) => r.getAttribute('idref')),
        contains('nav'),
        reason: 'the author enabled Contents, so the nav is a readable page',
      );
    });

    test('parts nest their chapters in the navigation', () {
      final archive = open(exportEpub(parts: const [
        BookPart(
            id: 'part-1',
            startsAtChapterId: 'ch-1',
            title: 'Part One',
            order: 0),
        BookPart(
            id: 'part-2',
            startsAtChapterId: 'ch-3',
            title: 'Part Two',
            order: 1),
      ]));
      final nav = xmlOf(archive, 'OEBPS/nav.xhtml');

      final toc = nav.findAllElements('nav').firstWhere(
          (node) => node.getAttribute('epub:type') == 'toc');
      final topLevel = toc.findElements('ol').single.findElements('li');

      final partItems = topLevel.where(
          (li) => li.findElements('a').first.innerText.startsWith('Part'));
      expect(partItems, hasLength(2));
      for (final part in partItems) {
        expect(part.findElements('ol'), isNotEmpty,
            reason: 'a part must contain its chapters');
      }
    });

    test('the navigation and the ncx describe the same book', () {
      final archive = open(exportEpub());
      final nav = xmlOf(archive, 'OEBPS/nav.xhtml');
      final ncx = xmlOf(archive, 'OEBPS/toc.ncx');

      final toc = nav.findAllElements('nav').firstWhere(
          (node) => node.getAttribute('epub:type') == 'toc');
      final navTargets = toc
          .findAllElements('a')
          .map((a) => a.getAttribute('href'))
          .toList();
      final ncxTargets = ncx
          .findAllElements('content')
          .map((c) => c.getAttribute('src'))
          .toList();

      expect(ncxTargets, navTargets,
          reason: 'the EPUB 2 fallback must not point somewhere else');
    });

    test('landmarks name the cover and the start of the body', () {
      final nav = xmlOf(open(exportEpub()), 'OEBPS/nav.xhtml');
      final landmarks = nav.findAllElements('nav').firstWhere(
          (node) => node.getAttribute('epub:type') == 'landmarks');
      expect(
        landmarks
            .findAllElements('a')
            .map((a) => a.getAttribute('epub:type')),
        contains('bodymatter'),
      );
    });
  });

  group('content documents', () {
    test('every one is well-formed XML with a non-empty title', () {
      final archive = open(exportEpub());

      final documents = archive.files
          .where((file) => file.name.endsWith('.xhtml'))
          .toList();
      expect(documents, isNotEmpty);

      for (final file in documents) {
        final parsed = XmlDocument.parse(utf8.decode(file.readBytes()!));
        final title = parsed.findAllElements('title').first.innerText;
        expect(title.trim(), isNotEmpty,
            reason: '${file.name} has an empty <title>, which a validator '
                'rejects and a reader shows as a filename');
      }
    });

    test('prose that would break XML survives intact', () {
      // The reason documents are built with a writer rather than with string
      // templates: an author writing "Smith & Sons" must not produce a package
      // that will not parse.
      const hostile = 'Smith & Sons said "go" — 3 < 5 > 2 & <not a tag>';
      final manuscript = manuscriptFixture();
      final book = bookFixture().copyWith(
        backMatter: [
          const BookSection(
            id: 'back-note',
            kind: BookSectionKind.acknowledgements,
            title: 'Thanks & Praise',
            body: hostile,
            included: true,
          ),
        ],
      );
      final document = const BookDocumentBuilder()
          .build(manuscript: manuscript, book: book);
      final bytes = const BookEpubExporter().export(
        document: document,
        settings: EpubSettings.defaults,
        projectId: 'project-book',
        modified: _modified,
      );

      final archive = open(bytes);
      final page = archive.files
          .firstWhere((file) => file.name.contains('back-acknowledgements'));
      final parsed = XmlDocument.parse(utf8.decode(page.readBytes()!));

      expect(parsed.findAllElements('p').first.innerText, hostile,
          reason: 'the text must come back exactly as the author wrote it');
      expect(parsed.findAllElements('h1').first.innerText, 'Thanks & Praise');
    });

    test('a chapter always carries a heading, even when untitled', () {
      final archive = open(exportEpub(
        settings: const EpubSettings(
            chapterNumberStyle: ChapterNumberStyle.none),
      ));
      final chapter = xmlOf(archive, 'OEBPS/text/chapter-ch-1.xhtml');
      expect(chapter.findAllElements('h1'), isNotEmpty);
    });

    test('a drop cap splits the first letter into its own span', () {
      final archive = open(exportEpub(
        settings: const EpubSettings(dropCap: true),
      ));
      final chapter = xmlOf(archive, 'OEBPS/text/chapter-ch-1.xhtml');
      final caps = chapter
          .findAllElements('span')
          .where((span) => span.getAttribute('class') == 'dropcap');
      expect(caps, hasLength(1));
      expect(caps.first.innerText.length, 1);
    });

    test('an ornament scene break is typeset, not drawn', () {
      // Unlike the PDF, which embeds only two faces and would render an
      // ornament as tofu, a reading system has full Unicode coverage.
      final archive = open(exportEpub(
        settings: const EpubSettings(
          sceneBreak: SceneBreakStyle.ornament,
          ornament: BookOrnamentId.asterism,
        ),
      ));
      final chapter = xmlOf(archive, 'OEBPS/text/chapter-ch-2.xhtml');
      final breaks = chapter
          .findAllElements('p')
          .where((p) => p.getAttribute('class') == 'scene-break');
      expect(breaks, hasLength(1),
          reason: 'chapter two has two scenes, so exactly one break');
      expect(breaks.first.innerText, '⁂');
    });
  });

  group('fonts', () {
    test('nothing is embedded by default', () {
      final archive = open(exportEpub());
      expect(archive.files.where((f) => f.name.contains('fonts/')), isEmpty);
      expect(textOf(archive, 'OEBPS/styles/book.css'),
          isNot(contains('@font-face')));
    });
  });

  group('reproducibility', () {
    test('the same book exports byte for byte the same file', () {
      final first = exportEpub();
      final second = exportEpub();
      expect(second, orderedEquals(first),
          reason: 'an unchanged book must not produce a different file');
    });

    test('a changed setting changes the output', () {
      final justified = exportEpub();
      final ragged = exportEpub(
        settings: const EpubSettings(alignment: BookAlignment.left),
      );
      expect(ragged, isNot(orderedEquals(justified)));
    });
  });

  group('settings', () {
    test('survive a JSON round trip', () {
      const settings = EpubSettings(
        lineHeight: 1.7,
        firstLineIndentEm: 0,
        alignment: BookAlignment.left,
        dropCap: true,
        embedFonts: true,
        language: 'en-GB',
        sceneBreak: SceneBreakStyle.glyph,
      );
      final restored = EpubSettings.fromJson(settings.toJson());

      expect(restored.lineHeight, 1.7);
      expect(restored.firstLineIndentEm, 0);
      expect(restored.alignment, BookAlignment.left);
      expect(restored.dropCap, isTrue);
      expect(restored.embedFonts, isTrue);
      expect(restored.language, 'en-GB');
      expect(restored.sceneBreak, SceneBreakStyle.glyph);
    });

    test('a nonsense language falls back rather than reaching the package', () {
      // A reading system can refuse a book whose dc:language is malformed.
      expect(EpubSettings.fromJson(const {'language': 'not a tag'}).language,
          'en');
      expect(EpubSettings.fromJson(const {'language': ''}).language, 'en');
      expect(EpubSettings.fromJson(const {'language': 'pt-BR'}).language,
          'pt-BR');
      expect(EpubSettings.isValidLanguage('en-GB'), isTrue);
      expect(EpubSettings.isValidLanguage('nope nope'), isFalse);
    });

    test('the stylesheet is written in relative units', () {
      final css = textOf(open(exportEpub()), 'OEBPS/styles/book.css');
      expect(css, contains('font-size: 1em'),
          reason: 'the reader owns the type size');
      expect(css, isNot(contains('pt;')),
          reason: 'points are a print unit and mean nothing in a reflowable '
              'book');
    });
  });
}
