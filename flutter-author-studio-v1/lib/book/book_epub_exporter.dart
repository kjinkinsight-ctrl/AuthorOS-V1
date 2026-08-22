/// Book Studio Phase 2 — EPUB 3 output.
///
/// This consumes a [BookDocument] and **never** a `PaginatedBook`. That is the
/// rule ADR-0006 records and the reason the two derived shapes exist: a reader
/// reflows an EPUB to their own screen, type size and margins, so a print
/// layout's page breaks are not merely unnecessary here, they would be wrong.
/// `test/book_layout_fidelity_test.dart` fails the build if this file ever
/// reaches for the layout engine.
///
/// Every document is written with `XmlBuilder` rather than assembled from
/// strings. XHTML content documents are XML, not HTML, and they carry author
/// prose: a manuscript containing "Smith & Sons", or a `<` in dialogue, must
/// not be able to produce a package that will not parse. Escaping is not a
/// detail to remember at each call site — it is handed to the writer.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'book_cover.dart';
import 'book_document.dart';
import 'book_fonts.dart';
import 'book_format.dart';
import 'inline_markup.dart';
import 'epub_settings.dart';

/// Where each part of the package lives inside the container.
class _Paths {
  static const root = 'OEBPS';
  static const opf = '$root/content.opf';
  static const nav = '$root/nav.xhtml';
  static const ncx = '$root/toc.ncx';
  static const css = '$root/styles/book.css';
  static const images = '$root/images';
  static const fonts = '$root/fonts';
}

/// One document in the reading order.
class _Item {
  _Item({
    required this.id,
    required this.href,
    required this.title,
    required this.xhtml,
    this.inNav = true,
    this.navLevel = 0,
    this.properties,
  });

  final String id;

  /// Relative to the package document, which sits in `OEBPS/`.
  final String href;

  final String title;
  final String xhtml;
  final bool inNav;

  /// 0 for a top-level entry, 1 for a chapter nested under a part.
  final int navLevel;

  final String? properties;
}

/// Builds an EPUB 3 package.
class BookEpubExporter {
  const BookEpubExporter();

  /// The namespaces the package uses.
  static const _opfNs = 'http://www.idpf.org/2007/opf';
  static const _dcNs = 'http://purl.org/dc/elements/1.1/';
  static const _xhtmlNs = 'http://www.w3.org/1999/xhtml';
  static const _epubNs = 'http://www.idpf.org/2007/ops';
  static const _ncxNs = 'http://www.daisy.org/z3986/2005/ncx/';
  static const _containerNs =
      'urn:oasis:names:tc:opendocument:xmlns:container';

  /// Renders [document] as a complete `.epub`.
  ///
  /// [modified] fills the `dcterms:modified` the specification requires. Pass
  /// the manuscript's own `updatedAt`: it is meaningful *and* deterministic,
  /// where `DateTime.now()` would make every export of an unchanged book a
  /// different file.
  ///
  /// [projectId] seeds the identifier when the book has no ISBN — see
  /// [deterministicUuid].
  Uint8List export({
    required BookDocument document,
    required EpubSettings settings,
    required String projectId,
    required DateTime modified,
    BookCover? cover,
    BookFontAssets? fonts,
  }) {
    final items = <_Item>[];
    var order = 0;
    String nextId(String prefix) => '$prefix-${(++order).toString().padLeft(3, '0')}';

    // The cover opens the book, so it is the first thing a reader sees.
    if (cover != null) {
      items.add(_Item(
        id: 'cover-page',
        href: 'text/cover.xhtml',
        title: 'Cover',
        xhtml: _coverXhtml(document.metadata, cover, settings),
        inNav: false,
        properties: null,
      ));
    }

    final wantsContents = document.frontMatter
        .any((page) => page.layout == BookMatterLayout.contents);

    for (final page in document.frontMatter) {
      // The contents is the navigation document itself. Generating a second,
      // separate contents page would mean two tables of contents that can
      // disagree with each other.
      if (page.layout == BookMatterLayout.contents) continue;
      items.add(_Item(
        id: nextId('front'),
        href: 'text/front-${_slug(page.kind.name)}.xhtml',
        title: page.title.isEmpty ? page.kind.label : page.title,
        xhtml: _matterXhtml(page, document.metadata, settings,
            markup: document.inlineMarkup),
        inNav: page.layout != BookMatterLayout.titlePage,
      ));
    }

    for (final element in document.body) {
      switch (element) {
        case BookPartElement(:final heading):
          items.add(_Item(
            id: nextId('part'),
            href: 'text/part-${_slug(heading.id)}.xhtml',
            title: heading.displayTitle,
            xhtml: _partXhtml(heading, settings),
          ));
        case BookChapterElement(:final chapter):
          items.add(_Item(
            id: nextId('chapter'),
            href: 'text/chapter-${_slug(chapter.id)}.xhtml',
            title: _chapterNavTitle(chapter, settings),
            xhtml: _chapterXhtml(chapter, settings,
                markup: document.inlineMarkup),
            // Chapters nest under a part when the book has any.
            navLevel: document.body.whereType<BookPartElement>().isEmpty ? 0 : 1,
          ));
      }
    }

    for (final page in document.backMatter) {
      items.add(_Item(
        id: nextId('back'),
        href: 'text/back-${_slug(page.kind.name)}.xhtml',
        title: page.title.isEmpty ? page.kind.label : page.title,
        xhtml: _matterXhtml(page, document.metadata, settings,
            markup: document.inlineMarkup),
      ));
    }

    final identifier = _identifier(document.metadata, projectId);
    final embeddedFonts = settings.embedFonts && fonts != null
        ? _fontEntries(fonts)
        : const <String, Uint8List>{};

    final archive = Archive();

    // The mimetype must be the first entry and must be stored uncompressed.
    // This is the classic reason an otherwise-correct EPUB is rejected.
    archive.add(
      ArchiveFile.string('mimetype', 'application/epub+zip')
        ..compression = CompressionType.none,
    );

    archive.add(ArchiveFile.string(
      'META-INF/container.xml',
      _containerXml(),
    ));
    archive.add(ArchiveFile.string(
      _Paths.opf,
      _opf(
        document: document,
        settings: settings,
        items: items,
        identifier: identifier,
        modified: modified,
        cover: cover,
        fontFiles: embeddedFonts.keys.toList(),
        includeNavInSpine: wantsContents,
      ),
    ));
    archive.add(ArchiveFile.string(
      _Paths.nav,
      _navXhtml(document, settings, items, cover: cover),
    ));
    archive.add(ArchiveFile.string(
      _Paths.ncx,
      _ncx(document, items, identifier),
    ));
    archive.add(ArchiveFile.string(_Paths.css, _css(settings)));

    if (cover != null) {
      archive.add(ArchiveFile.bytes(
        '${_Paths.images}/${cover.fileName}',
        cover.bytes,
      ));
    }

    for (final item in items) {
      archive.add(ArchiveFile.string('${_Paths.root}/${item.href}', item.xhtml));
    }

    for (final entry in embeddedFonts.entries) {
      archive.add(ArchiveFile.bytes('${_Paths.fonts}/${entry.key}', entry.value));
    }
    if (embeddedFonts.isNotEmpty) {
      archive.add(ArchiveFile.string('${_Paths.fonts}/OFL.txt', _oflNotice));
    }

    // Entry timestamps are pinned, matching `lib/archive/authoros_archive.dart`,
    // so an unchanged book exports byte for byte the same file.
    return ZipEncoder().encodeBytes(archive, modified: DateTime.utc(2000));
  }

  // --- identity ----------------------------------------------------------

  String _identifier(BookMetadata metadata, String projectId) =>
      metadata.isbn.trim().isNotEmpty
          ? 'urn:isbn:${metadata.isbn.trim().replaceAll(RegExp(r'[^0-9Xx]'), '')}'
          : 'urn:uuid:${deterministicUuid(projectId)}';

  /// A stable UUID for a book that has no ISBN.
  ///
  /// Derived from the project id rather than generated, for two reasons: it
  /// keeps an export reproducible, and `dc:identifier` names the *work*. A
  /// reading system uses it to recognise that a newly sideloaded file is a
  /// newer copy of a book already on the shelf; a fresh identifier each time
  /// would leave the reader with duplicates instead of an update.
  static String deterministicUuid(String seed) {
    final digest = sha256.convert(utf8.encode('authoros.book:$seed')).bytes;
    final hex = digest
        .take(16)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    // Stamped as a version 4 variant 1 UUID so it is well-formed.
    final version = '4${hex.substring(13, 16)}';
    final variantNibble =
        ((int.parse(hex.substring(16, 17), radix: 16) & 0x3) | 0x8)
            .toRadixString(16);
    final variant = '$variantNibble${hex.substring(17, 20)}';
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-$version-'
        '$variant-${hex.substring(20, 32)}';
  }

  /// `dcterms:modified` must be UTC with no fractional seconds.
  static String epubTimestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }

  // --- package documents --------------------------------------------------

  String _containerXml() {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.element('container', namespaceUris: {null: _containerNs}, attributes: {
      'version': '1.0',
    }, nest: () {
      builder.element('rootfiles', nest: () {
        builder.element('rootfile', attributes: {
          'full-path': _Paths.opf,
          'media-type': 'application/oebps-package+xml',
        });
      });
    });
    return _serialise(builder.buildDocument());
  }

  String _opf({
    required BookDocument document,
    required EpubSettings settings,
    required List<_Item> items,
    required String identifier,
    required DateTime modified,
    required List<String> fontFiles,
    required bool includeNavInSpine,
    BookCover? cover,
  }) {
    final metadata = document.metadata;
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');

    builder.element('package', namespaceUris: {null: _opfNs}, attributes: {
      'version': '3.0',
      'unique-identifier': 'pub-id',
      'xml:lang': settings.language,
    }, nest: () {
      builder.element('metadata',
          namespaceUris: {'dc': _dcNs}, nest: () {
        builder.element('dc:identifier',
            attributes: {'id': 'pub-id'}, nest: identifier);
        builder.element('dc:title', attributes: {'id': 'title'},
            nest: metadata.title);
        builder.element('dc:language', nest: settings.language);

        if (metadata.authorName.isNotEmpty) {
          builder.element('dc:creator',
              attributes: {'id': 'creator'}, nest: metadata.authorName);
          // `marc` is a reserved prefix in EPUB 3, so no declaration is needed.
          builder.element('meta', attributes: {
            'refines': '#creator',
            'property': 'role',
            'scheme': 'marc:relators',
          }, nest: 'aut');
        }
        if (metadata.subtitle.isNotEmpty) {
          builder.element('meta', attributes: {
            'refines': '#title',
            'property': 'title-type',
          }, nest: 'main');
          builder.element('dc:title', attributes: {'id': 'subtitle'},
              nest: metadata.subtitle);
          builder.element('meta', attributes: {
            'refines': '#subtitle',
            'property': 'title-type',
          }, nest: 'subtitle');
        }
        if (metadata.publisher.isNotEmpty) {
          builder.element('dc:publisher', nest: metadata.publisher);
        }
        if (metadata.seriesName.isNotEmpty) {
          builder.element('meta', attributes: {
            'property': 'belongs-to-collection',
            'id': 'series',
          }, nest: metadata.seriesName);
          builder.element('meta', attributes: {
            'refines': '#series',
            'property': 'collection-type',
          }, nest: 'series');
          if (metadata.seriesNumber.isNotEmpty) {
            builder.element('meta', attributes: {
              'refines': '#series',
              'property': 'group-position',
            }, nest: metadata.seriesNumber);
          }
        }
        final rights = metadata.rightsStatement.isNotEmpty
            ? metadata.rightsStatement
            : (metadata.copyrightHolder.isNotEmpty
                ? 'Copyright © ${metadata.copyrightYear} '
                    '${metadata.copyrightHolder}'.trim()
                : '');
        if (rights.isNotEmpty) {
          builder.element('dc:rights', nest: rights);
        }

        builder.element('meta',
            attributes: {'property': 'dcterms:modified'},
            nest: epubTimestamp(modified));

        if (cover != null) {
          // The legacy hook EPUB 2 reading systems still look for.
          builder.element('meta',
              attributes: {'name': 'cover', 'content': 'cover-image'});
        }
      });

      builder.element('manifest', nest: () {
        builder.element('item', attributes: {
          'id': 'nav',
          'href': 'nav.xhtml',
          'media-type': 'application/xhtml+xml',
          'properties': 'nav',
        });
        builder.element('item', attributes: {
          'id': 'ncx',
          'href': 'toc.ncx',
          'media-type': 'application/x-dtbncx+xml',
        });
        builder.element('item', attributes: {
          'id': 'css',
          'href': 'styles/book.css',
          'media-type': 'text/css',
        });
        if (cover != null) {
          builder.element('item', attributes: {
            'id': 'cover-image',
            'href': 'images/${cover.fileName}',
            'media-type': cover.mediaType,
            'properties': 'cover-image',
          });
        }
        for (final item in items) {
          builder.element('item', attributes: {
            'id': item.id,
            'href': item.href,
            'media-type': 'application/xhtml+xml',
            if (item.properties != null) 'properties': item.properties!,
          });
        }
        for (var i = 0; i < fontFiles.length; i++) {
          final name = fontFiles[i];
          builder.element('item', attributes: {
            'id': 'font-$i',
            'href': 'fonts/$name',
            'media-type': 'font/ttf',
          });
        }
        if (fontFiles.isNotEmpty) {
          builder.element('item', attributes: {
            'id': 'font-licence',
            'href': 'fonts/OFL.txt',
            'media-type': 'text/plain',
          });
        }
      });

      builder.element('spine', attributes: {'toc': 'ncx'}, nest: () {
        for (final item in items) {
          builder.element('itemref', attributes: {'idref': item.id});
          // The navigation document doubles as the visible contents, so it is
          // placed where the author put the Contents section: after the front
          // matter, before the body.
          if (includeNavInSpine && item.id.startsWith('front') &&
              item == items.lastWhere((i) => i.id.startsWith('front'),
                  orElse: () => item)) {
            builder.element('itemref', attributes: {'idref': 'nav'});
          }
        }
        if (includeNavInSpine &&
            !items.any((item) => item.id.startsWith('front'))) {
          builder.element('itemref', attributes: {'idref': 'nav'});
        }
      });
    });

    return _serialise(builder.buildDocument());
  }

  String _navXhtml(
    BookDocument document,
    EpubSettings settings,
    List<_Item> items, {
    BookCover? cover,
  }) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.doctype('html');
    builder.element('html', namespaceUris: {
      null: _xhtmlNs,
      'epub': _epubNs,
    }, attributes: {
      'xml:lang': settings.language,
      'lang': settings.language,
    }, nest: () {
      _head(builder, 'Contents', depth: 0);
      builder.element('body', nest: () {
        builder.element('nav', attributes: {
          'epub:type': 'toc',
          'id': 'toc',
        }, nest: () {
          builder.element('h1', nest: 'Contents');
          _navList(builder, items.where((item) => item.inNav).toList());
        });

        builder.element('nav', attributes: {
          'epub:type': 'landmarks',
          'hidden': 'hidden',
        }, nest: () {
          builder.element('h2', nest: 'Guide');
          builder.element('ol', nest: () {
            if (cover != null) {
              _landmark(builder, 'cover', 'text/cover.xhtml', 'Cover');
            }
            final firstBody = items.firstWhere(
              (item) => item.id.startsWith('chapter') ||
                  item.id.startsWith('part'),
              orElse: () => items.first,
            );
            _landmark(builder, 'bodymatter', firstBody.href, 'Beginning');
          });
        });
      });
    });
    return _serialise(builder.buildDocument());
  }

  void _landmark(
      XmlBuilder builder, String type, String href, String label) {
    builder.element('li', nest: () {
      builder.element('a',
          attributes: {'epub:type': type, 'href': href}, nest: label);
    });
  }

  /// Writes the contents, nesting chapters beneath the part they belong to.
  void _navList(XmlBuilder builder, List<_Item> items) {
    builder.element('ol', nest: () {
      var index = 0;
      while (index < items.length) {
        final item = items[index];
        final children = <_Item>[];
        var next = index + 1;
        while (next < items.length && items[next].navLevel > item.navLevel) {
          children.add(items[next]);
          next++;
        }
        builder.element('li', nest: () {
          builder.element('a',
              attributes: {'href': item.href}, nest: item.title);
          if (children.isNotEmpty) _navList(builder, children);
        });
        index = next;
      }
    });
  }

  String _ncx(BookDocument document, List<_Item> items, String identifier) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.element('ncx', namespaceUris: {null: _ncxNs}, attributes: {
      'version': '2005-1',
    }, nest: () {
      builder.element('head', nest: () {
        for (final meta in <List<String>>[
          ['dtb:uid', identifier],
          ['dtb:depth', '2'],
          ['dtb:totalPageCount', '0'],
          ['dtb:maxPageNumber', '0'],
        ]) {
          builder.element('meta',
              attributes: {'name': meta[0], 'content': meta[1]});
        }
      });
      builder.element('docTitle', nest: () {
        builder.element('text', nest: document.metadata.title);
      });
      if (document.metadata.authorName.isNotEmpty) {
        builder.element('docAuthor', nest: () {
          builder.element('text', nest: document.metadata.authorName);
        });
      }
      builder.element('navMap', nest: () {
        var play = 0;
        for (final item in items.where((item) => item.inNav)) {
          play += 1;
          builder.element('navPoint', attributes: {
            'id': 'navpoint-$play',
            'playOrder': '$play',
          }, nest: () {
            builder.element('navLabel', nest: () {
              builder.element('text', nest: item.title);
            });
            builder.element('content', attributes: {'src': item.href});
          });
        }
      });
    });
    return _serialise(builder.buildDocument());
  }

  // --- content documents --------------------------------------------------

  /// The shared `<head>`. [depth] is how many directories deep the document is,
  /// so the stylesheet link resolves from `OEBPS/` or `OEBPS/text/`.
  void _head(XmlBuilder builder, String title, {int depth = 1}) {
    builder.element('head', nest: () {
      // A content document must have a non-empty title; a validator rejects it
      // otherwise, and a reader shows the filename instead.
      builder.element('title', nest: title.isEmpty ? 'Untitled' : title);
      builder.element('meta', attributes: {'charset': 'utf-8'});
      builder.element('link', attributes: {
        'rel': 'stylesheet',
        'type': 'text/css',
        'href': '${'../' * depth}styles/book.css',
      });
    });
  }

  String _document(
    String title,
    EpubSettings settings,
    void Function(XmlBuilder) body, {
    int depth = 1,
  }) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.doctype('html');
    builder.element('html', namespaceUris: {
      null: _xhtmlNs,
      'epub': _epubNs,
    }, attributes: {
      'xml:lang': settings.language,
      'lang': settings.language,
    }, nest: () {
      _head(builder, title, depth: depth);
      builder.element('body', nest: () => body(builder));
    });
    return _serialise(builder.buildDocument());
  }

  String _coverXhtml(
      BookMetadata metadata, BookCover cover, EpubSettings settings) =>
      _document('Cover', settings, (builder) {
        builder.element('section', attributes: {
          'epub:type': 'cover',
          'class': 'cover',
        }, nest: () {
          builder.element('img', attributes: {
            'src': '../images/${cover.fileName}',
            'alt': '${metadata.title}, cover',
            'class': 'cover-image',
          });
        });
      });

  String _matterXhtml(
    BookMatterPage page,
    BookMetadata metadata,
    EpubSettings settings, {
    BookInlineMarkup markup = BookInlineMarkup.none,
  }) {
    final epubType = switch (page.kind) {
      BookSectionKind.halfTitle => 'halftitlepage',
      BookSectionKind.titlePage => 'titlepage',
      BookSectionKind.copyright => 'copyright-page',
      BookSectionKind.dedication => 'dedication',
      BookSectionKind.epigraph => 'epigraph',
      BookSectionKind.acknowledgements => 'acknowledgments',
      BookSectionKind.aboutAuthor => 'other-credits',
      _ => 'frontmatter',
    };
    final title = page.title.isEmpty ? page.kind.label : page.title;

    return _document(title, settings, (builder) {
      builder.element('section', attributes: {
        'epub:type': epubType,
        'class': _matterClass(page.layout),
      }, nest: () {
        switch (page.layout) {
          case BookMatterLayout.titlePage:
            for (var i = 0; i < page.paragraphs.length; i++) {
              builder.element(i == 0 ? 'h1' : 'p',
                  attributes: {'class': i == 0 ? 'book-title' : 'title-line'},
                  nest: page.paragraphs[i]);
            }
          case BookMatterLayout.centredBlock:
            if (page.title.isNotEmpty) {
              builder.element('h1', nest: page.title);
            }
            for (final paragraph in page.paragraphs) {
              builder.element('p', attributes: {'class': 'centred'},
                  nest: () => _writeSpans(
                      builder, parseProse(paragraph, markup)));
            }
          case BookMatterLayout.copyrightBlock:
            for (final paragraph in page.paragraphs) {
              builder.element('p',
                  attributes: {'class': 'copyright'}, nest: paragraph);
            }
          case BookMatterLayout.flowingText:
          case BookMatterLayout.contents:
            if (page.title.isNotEmpty) {
              builder.element('h1', nest: page.title);
            }
            for (var i = 0; i < page.paragraphs.length; i++) {
              builder.element('p',
                  attributes: {'class': i == 0 ? 'first' : 'body'},
                  nest: () => _writeSpans(
                      builder, parseProse(page.paragraphs[i], markup)));
            }
        }
      });
    });
  }

  String _matterClass(BookMatterLayout layout) => switch (layout) {
        BookMatterLayout.titlePage => 'titlepage',
        BookMatterLayout.centredBlock => 'centred-block',
        BookMatterLayout.copyrightBlock => 'copyright-block',
        _ => 'matter',
      };

  String _partXhtml(BookPartHeading heading, EpubSettings settings) =>
      _document(heading.displayTitle, settings, (builder) {
        builder.element('section', attributes: {
          'epub:type': 'part',
          'class': 'part',
        }, nest: () {
          builder.element('h1',
              attributes: {'class': 'part-title'}, nest: heading.displayTitle);
          if (heading.subtitle.trim().isNotEmpty) {
            builder.element('p',
                attributes: {'class': 'part-subtitle'},
                nest: heading.subtitle.trim());
          }
        });
      });

  String _chapterXhtml(
    BookChapterContent chapter,
    EpubSettings settings, {
    BookInlineMarkup markup = BookInlineMarkup.none,
  }) {
    final number = _chapterNumber(chapter.number, settings);
    final title = chapter.title.trim();

    return _document(_chapterNavTitle(chapter, settings), settings, (builder) {
      builder.element('section', attributes: {
        'epub:type': 'chapter',
        'class': 'chapter',
        'id': 'ch-${_slug(chapter.id)}',
      }, nest: () {
        builder.element('header', attributes: {'class': 'chapter-opener'},
            nest: () {
          if (number.isNotEmpty) {
            builder.element('p',
                attributes: {'class': 'chapter-number'}, nest: number);
          }
          // A chapter always carries an h1 so the document outline is sound,
          // even when the author left the title blank.
          builder.element('h1', attributes: {'class': 'chapter-title'},
              nest: title.isEmpty ? number.isEmpty
                  ? 'Chapter ${chapter.number}'
                  : number : title);
        });

        var isFirstParagraph = true;
        for (var s = 0; s < chapter.scenes.length; s++) {
          if (s > 0) _sceneBreak(builder, settings);
          final scene = chapter.scenes[s];
          for (var p = 0; p < scene.paragraphs.length; p++) {
            final afterBreak = isFirstParagraph || (p == 0 && s > 0);
            final indent = afterBreak && !settings.indentAfterBreak
                ? 'no-indent'
                : 'body';
            final spans = scene.paragraphs[p].resolve(markup);
            final plain = spans.map((span) => span.text).join();

            if (isFirstParagraph && settings.dropCap && plain.isNotEmpty) {
              builder.element('p', attributes: {'class': '$indent dropcap-line'},
                  nest: () {
                builder.element('span',
                    attributes: {'class': 'dropcap'}, nest: plain[0]);
                // The cap has already taken the first character, so the rest is
                // written from the spans with that one letter removed.
                _writeSpans(builder, _withoutFirstCharacter(spans));
              });
            } else {
              builder.element('p', attributes: {'class': indent},
                  nest: () => _writeSpans(builder, spans));
            }
            isFirstParagraph = false;
          }
        }
      });
    });
  }

  /// Writes prose with its emphasis resolved into `<em>`.
  ///
  /// `<em>` rather than `<i>` or a CSS class: it is what the reading system
  /// already knows how to slant, in whatever face the reader has chosen, and it
  /// carries the meaning to a screen reader as well. An EPUB that pinned a
  /// bundled italic here would be fighting the format.
  void _writeSpans(XmlBuilder builder, List<ProseSpan> spans) {
    for (final span in spans) {
      if (span.text.isEmpty) continue;
      if (span.italic) {
        builder.element('em', nest: span.text);
      } else {
        builder.text(span.text);
      }
    }
  }

  /// The same spans with the opening character removed, for a drop cap.
  static List<ProseSpan> _withoutFirstCharacter(List<ProseSpan> spans) {
    for (var i = 0; i < spans.length; i++) {
      if (spans[i].text.isEmpty) continue;
      return [
        ProseSpan(spans[i].text.substring(1), marks: spans[i].marks),
        ...spans.skip(i + 1),
      ];
    }
    return spans;
  }

  /// The mark between two scenes.
  ///
  /// Unlike the PDF, this may use a real ornament character. The tofu risk in
  /// print came from embedding only two faces; a reading system has full
  /// Unicode coverage, so the ornament can simply be typeset.
  void _sceneBreak(XmlBuilder builder, EpubSettings settings) {
    switch (settings.sceneBreak) {
      case SceneBreakStyle.blankLine:
        builder.element('p',
            attributes: {'class': 'scene-break-blank'}, nest: ' ');
      case SceneBreakStyle.glyph:
        builder.element('p',
            attributes: {'class': 'scene-break'},
            nest: settings.sceneBreakGlyph);
      case SceneBreakStyle.ornament:
        final glyph = switch (settings.ornament) {
          BookOrnamentId.none => '',
          BookOrnamentId.asterism => '⁂',
          BookOrnamentId.diamond => '◆',
          BookOrnamentId.leaf => '❧',
          BookOrnamentId.rule => '',
        };
        if (settings.ornament == BookOrnamentId.rule || glyph.isEmpty) {
          builder.element('hr', attributes: {'class': 'scene-rule'});
        } else {
          builder.element('p',
              attributes: {'class': 'scene-break'}, nest: glyph);
        }
    }
  }

  String _chapterNavTitle(BookChapterContent chapter, EpubSettings settings) {
    final number = _chapterNumber(chapter.number, settings);
    final title = chapter.title.trim();
    if (number.isEmpty) {
      return title.isEmpty ? 'Chapter ${chapter.number}' : title;
    }
    return title.isEmpty ? number : '$number: $title';
  }

  String _chapterNumber(int number, EpubSettings settings) =>
      chapterNumberLabel(number,
          style: settings.chapterNumberStyle,
          prefix: settings.chapterNumberPrefix);

  // --- stylesheet ---------------------------------------------------------

  String _css(EpubSettings settings) {
    final indent = settings.firstLineIndentEm;
    final spacing = settings.paragraphSpacingEm;
    final buffer = StringBuffer()
      ..writeln('/* Generated by AuthorOS Book Studio. */')
      ..writeln('/* Sizes are relative on purpose: the reader owns the type')
      ..writeln('   size, and an absolute value here would fight them. */');

    if (settings.embedFonts) {
      buffer
        ..writeln('@font-face {')
        ..writeln('  font-family: "${_familyName(settings.bodyFamily)}";')
        ..writeln('  font-weight: normal;')
        ..writeln('  src: url("../fonts/${_fontFile(settings.bodyFamily, false)}");')
        ..writeln('}')
        ..writeln('@font-face {')
        ..writeln('  font-family: "${_familyName(settings.bodyFamily)}";')
        ..writeln('  font-weight: bold;')
        ..writeln('  src: url("../fonts/${_fontFile(settings.bodyFamily, true)}");')
        ..writeln('}');
    }

    buffer
      ..writeln('html { font-size: 100%; }')
      ..writeln('body {')
      ..writeln('  font-family: ${settings.fontFamilyStack};')
      ..writeln('  font-size: 1em;')
      ..writeln('  line-height: ${settings.lineHeight};')
      ..writeln('  margin: 0 5%;')
      ..writeln('  widows: 2; orphans: 2;')
      ..writeln('}')
      ..writeln('p {')
      ..writeln('  margin: 0 0 ${spacing}em 0;')
      ..writeln('  text-indent: ${indent}em;')
      ..writeln('  text-align: ${settings.cssTextAlign};')
      ..writeln('}')
      ..writeln('p.no-indent, p.first { text-indent: 0; }')
      ..writeln('p.centred { text-indent: 0; text-align: center; }')
      ..writeln('p.copyright { text-indent: 0; text-align: left; '
          'font-size: 0.85em; margin-bottom: 0.8em; }')
      ..writeln('h1, h2 { text-align: left; line-height: 1.2; '
          'page-break-after: avoid; break-after: avoid; }')
      ..writeln('section.chapter > header { margin: 2em 0 1.5em 0; }')
      ..writeln('p.chapter-number { text-indent: 0; margin: 0 0 0.3em 0; '
          'font-size: 0.9em; letter-spacing: 0.08em; text-transform: uppercase; }')
      ..writeln('h1.chapter-title { margin: 0; font-size: 1.6em; }')
      ..writeln('section.part, section.titlepage, section.centred-block '
          '{ text-align: center; margin-top: 20%; }')
      ..writeln('h1.part-title { text-align: center; font-size: 2em; }')
      ..writeln('p.part-subtitle { text-indent: 0; text-align: center; }')
      ..writeln('h1.book-title { text-align: center; font-size: 2.2em; '
          'margin-bottom: 0.6em; }')
      ..writeln('p.title-line { text-indent: 0; text-align: center; '
          'margin: 0.4em 0; }')
      ..writeln('p.scene-break { text-indent: 0; text-align: center; '
          'margin: 1.2em 0; }')
      ..writeln('p.scene-break-blank { text-indent: 0; margin: 1.2em 0; }')
      ..writeln('hr.scene-rule { border: 0; border-top: 1px solid currentColor; '
          'width: 20%; margin: 1.4em auto; }')
      ..writeln('section.cover { margin: 0; padding: 0; text-align: center; }')
      ..writeln('img.cover-image { max-width: 100%; max-height: 100%; }')
      ..writeln('nav[epub|type~="toc"] ol { list-style: none; padding-left: 0; }')
      ..writeln('nav ol ol { padding-left: 1.2em; }');

    if (settings.dropCap) {
      buffer
        ..writeln('span.dropcap {')
        ..writeln('  float: left;')
        ..writeln('  font-size: 3em;')
        ..writeln('  line-height: 0.8;')
        ..writeln('  padding-right: 0.06em;')
        ..writeln('}')
        ..writeln('p.dropcap-line { text-indent: 0; }');
    }

    return buffer.toString();
  }

  // --- fonts --------------------------------------------------------------

  Map<String, Uint8List> _fontEntries(BookFontAssets fonts) {
    final entries = <String, Uint8List>{};
    for (final face in fonts.availableFaces) {
      final data = fonts.bytesFor(face);
      if (data == null) continue;
      entries[_fileNameForFace(face)] =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    return entries;
  }

  static String _familyName(BookFontFamilyId family) => switch (family) {
        BookFontFamilyId.merriweather => 'Merriweather',
        BookFontFamilyId.inter => 'Inter',
      };

  static String _fontFile(BookFontFamilyId family, bool bold) =>
      '${_familyName(family)}-${bold ? '700' : '400'}.ttf';

  static String _fileNameForFace(BookFontFace face) => _fontFile(
        face.family,
        face.style == BookFontStyleId.bold ||
            face.style == BookFontStyleId.boldItalic,
      );

  static const _oflNotice = '''
The fonts embedded in this publication (Merriweather and Inter) are licensed
under the SIL Open Font License, Version 1.1.

The full licence text is available at https://scripts.sil.org/OFL

Under that licence these fonts may be embedded in a document. They may not be
sold on their own, and this notice must travel with them.
''';

  // --- helpers ------------------------------------------------------------

  /// Serialises without pretty-printing.
  ///
  /// Indentation inside a content document would add whitespace text nodes to
  /// the author's prose, which a reading system renders.
  String _serialise(XmlDocument document) => document.toXmlString();

  static String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'item' : slug;
  }
}
