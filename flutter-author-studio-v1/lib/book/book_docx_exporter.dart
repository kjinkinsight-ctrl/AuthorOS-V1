/// Book Studio Phase 4 — Word output.
///
/// Like EPUB, this consumes a [BookDocument] and never a `PaginatedBook`: Word
/// paginates the document itself, on whatever paper and printer the reader has,
/// so imposing this app's page breaks would be meaningless at best. The fidelity
/// test fails the build if this file reaches for the layout engine.
///
/// A DOCX is a zip of OOXML parts, so `archive` covers it with no new
/// dependency, and `XmlBuilder` keeps author prose from breaking the XML.
///
/// **Two flavours, because a DOCX is asked to do two different jobs.**
/// [DocxFlavour.submission] is the format an editor, proofreader or agent
/// expects: double-spaced, one-inch margins, a running header, hash marks for
/// scene breaks. [DocxFlavour.typeset] is an editable copy of the book as
/// formatted, following its own trim size and typography. They are the same
/// document with different metrics, which is why they share one exporter.
///
/// **Everything is a named Word style.** Direct formatting would look identical
/// on open and be useless afterwards: with real styles an editor restyles the
/// whole manuscript in one click, Word's navigation pane shows the chapter
/// tree, and a table of contents can be generated from the headings.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'book_document.dart';
import 'book_format.dart';
import 'inline_markup.dart';

/// What the document is for.
enum DocxFlavour {
  /// Standard manuscript format, as an editor or agent expects to receive it.
  submission,

  /// An editable copy of the book as it is typeset.
  typeset,
}

extension DocxFlavourX on DocxFlavour {
  String get label => switch (this) {
        DocxFlavour.submission => 'Submission manuscript',
        DocxFlavour.typeset => 'Typeset copy',
      };

  String get description => switch (this) {
        DocxFlavour.submission =>
          'Double-spaced on one-inch margins with a running header — what an '
              'editor, proofreader or agent expects to be sent.',
        DocxFlavour.typeset =>
          'An editable Word version of the book as you have formatted it, at '
              'its own trim size.',
      };
}

/// Twips: twentieths of a point, and the unit most of OOXML is written in.
int _twips(double points) => (points * 20).round();

/// Word writes type sizes in half-points.
int _halfPoints(double points) => (points * 2).round();

/// The measurements one flavour is set in.
class _Metrics {
  const _Metrics({
    required this.pageWidth,
    required this.pageHeight,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.bodyFont,
    required this.displayFont,
    required this.bodySizeHalfPoints,
    required this.lineSpacing,
    required this.lineRule,
    required this.firstLineIndent,
    required this.justified,
    required this.runningHeader,
    required this.sceneBreak,
    required this.chapterSink,
    required this.numberStyle,
    required this.numberPrefix,
    required this.headingAlignment,
    required this.titleGap,
    required this.bodyGap,
  });

  final int pageWidth;
  final int pageHeight;
  final int marginTop;
  final int marginBottom;
  final int marginLeft;
  final int marginRight;

  final String bodyFont;
  final String displayFont;
  final int bodySizeHalfPoints;

  /// `w:line`, in twips.
  final int lineSpacing;

  /// `auto` scales with the type size; `exact` pins the leading.
  final String lineRule;

  final int firstLineIndent;
  final bool justified;

  /// Whether a `Surname / TITLE / page` header runs across the top.
  final bool runningHeader;

  /// The mark between two scenes.
  final String sceneBreak;

  /// Space above a chapter heading, in twips.
  final int chapterSink;

  /// Space between the chapter number and the chapter title, in twips.
  final int titleGap;

  /// Space between the chapter opener and the first line of prose, in twips.
  final int bodyGap;

  /// How a chapter names its number, matching what the book itself does.
  final ChapterNumberStyle numberStyle;
  final String numberPrefix;

  /// `w:jc` for chapter and part headings.
  final String headingAlignment;

  /// The chapter number as it is written out, empty when the book shows none.
  String numberLabel(int number) =>
      chapterNumberLabel(number, style: numberStyle, prefix: numberPrefix);

  /// Standard manuscript format, near enough to satisfy anyone who asked for it.
  static const submission = _Metrics(
    pageWidth: 12240, // 8.5 in
    pageHeight: 15840, // 11 in
    marginTop: 1440,
    marginBottom: 1440,
    marginLeft: 1440,
    marginRight: 1440,
    bodyFont: 'Times New Roman',
    displayFont: 'Times New Roman',
    bodySizeHalfPoints: 24, // 12 pt
    lineSpacing: 480, // double
    lineRule: 'auto',
    firstLineIndent: 720, // half an inch
    // Submission format is set ragged right: it is a working copy, and
    // justification hides how much has actually been written on a line.
    justified: false,
    runningHeader: true,
    sceneBreak: '#',
    chapterSink: 2880, // a third of the way down
    // Standard manuscript format numbers chapters plainly, whatever the book
    // does with them once it is typeset.
    numberStyle: ChapterNumberStyle.arabic,
    numberPrefix: 'Chapter ',
    headingAlignment: 'center',
    titleGap: 480,
    bodyGap: 480,
  );

  /// Derived from the book's own print format.
  factory _Metrics.fromFormat(BookFormat format) {
    final margins = format.margins;
    final typography = format.typography;
    return _Metrics(
      pageWidth: _twips(format.trim.widthPt),
      pageHeight: _twips(format.trim.heightPt),
      marginTop: _twips(margins.topPt),
      marginBottom: _twips(margins.bottomPt),
      // Word mirrors margins only with facing pages switched on, which an
      // editable copy does not want; the binding allowance is folded into the
      // left margin so the measure still matches the book.
      marginLeft: _twips(margins.insidePt + margins.gutterPt),
      marginRight: _twips(margins.outsidePt),
      bodyFont: _fontName(typography.bodyFamily),
      displayFont: _fontName(typography.displayFamily),
      bodySizeHalfPoints: _halfPoints(typography.bodySizePt),
      lineSpacing: _twips(typography.leadingPt),
      lineRule: 'exact',
      firstLineIndent: _twips(typography.firstLineIndentPt),
      justified: typography.alignment == BookAlignment.justified,
      runningHeader: false,
      // A blank-line break prints nothing: an empty paragraph is the break.
      // An ornament is drawn as vector paths in the book, which Word has no
      // way to reproduce, so it falls back to the glyph.
      sceneBreak: format.chapter.sceneBreak == SceneBreakStyle.blankLine
          ? ''
          : format.chapter.sceneBreakGlyph,
      // Measured against the text block, not the trim, because that is what
      // the layout engine sinks a chapter opener by. The typeset flavour is
      // the book as it is formatted, so the two have to agree.
      chapterSink: _twips(
        (format.trim.heightPt - margins.topPt - margins.bottomPt) *
            format.chapter.sinkFraction,
      ),
      numberStyle: format.chapter.numberStyle,
      numberPrefix: format.chapter.numberPrefix,
      headingAlignment: switch (format.chapter.headingAlignment) {
        BookAlignment.justified => 'both',
        BookAlignment.left => 'left',
      },
      titleGap: _twips(format.chapter.titleGapPt),
      bodyGap: _twips(format.chapter.bodyGapPt),
    );
  }

  static String _fontName(BookFontFamilyId family) => switch (family) {
        BookFontFamilyId.merriweather => 'Merriweather',
        BookFontFamilyId.inter => 'Inter',
      };
}

class BookDocxExporter {
  const BookDocxExporter();

  static const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _ct =
      'http://schemas.openxmlformats.org/package/2006/content-types';
  static const _pkgRel =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _cp = 'http://schemas.openxmlformats.org/package/2006/metadata/'
      'core-properties';
  static const _dc = 'http://purl.org/dc/elements/1.1/';
  static const _dcterms = 'http://purl.org/dc/terms/';
  static const _xsi = 'http://www.w3.org/2001/XMLSchema-instance';
  static const _ep = 'http://schemas.openxmlformats.org/officeDocument/2006/'
      'extended-properties';

  /// Renders [document] as a `.docx`.
  ///
  /// [modified] fills the document properties. Pass the manuscript's own
  /// `updatedAt` so an unchanged book exports the same bytes twice, matching
  /// the reproducibility the other exporters have.
  Uint8List export({
    required BookDocument document,
    required DocxFlavour flavour,
    required DateTime modified,
    BookFormat? format,
  }) {
    final metrics = flavour == DocxFlavour.submission
        ? _Metrics.submission
        : _Metrics.fromFormat(format ?? BookFormatPresets.paperback);

    final archive = Archive()
      ..add(ArchiveFile.string('[Content_Types].xml',
          _contentTypes(header: metrics.runningHeader)))
      ..add(ArchiveFile.string('_rels/.rels', _packageRels()))
      ..add(ArchiveFile.string('docProps/core.xml',
          _coreProperties(document.metadata, modified)))
      ..add(ArchiveFile.string('docProps/app.xml', _appProperties(document)))
      ..add(ArchiveFile.string('word/_rels/document.xml.rels',
          _documentRels(header: metrics.runningHeader)))
      ..add(ArchiveFile.string('word/styles.xml', _styles(metrics)))
      ..add(ArchiveFile.string('word/settings.xml', _settings()))
      ..add(ArchiveFile.string(
          'word/document.xml', _document(document, metrics)));

    if (metrics.runningHeader) {
      archive.add(ArchiveFile.string(
          'word/header1.xml', _header(document.metadata)));
    }

    // Pinned, as the archive service and the EPUB exporter both do, so an
    // unchanged book produces an unchanged file.
    return ZipEncoder().encodeBytes(archive, modified: DateTime.utc(2000));
  }

  // --- package parts ------------------------------------------------------

  String _contentTypes({required bool header}) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('Types', namespaceUris: {null: _ct}, nest: () {
      builder.element('Default', attributes: {
        'Extension': 'rels',
        'ContentType':
            'application/vnd.openxmlformats-package.relationships+xml',
      });
      builder.element('Default',
          attributes: {'Extension': 'xml', 'ContentType': 'application/xml'});

      void override(String part, String type) => builder.element('Override',
          attributes: {'PartName': part, 'ContentType': type});

      const word = 'application/vnd.openxmlformats-officedocument.'
          'wordprocessingml';
      override('/word/document.xml', '$word.document.main+xml');
      override('/word/styles.xml', '$word.styles+xml');
      override('/word/settings.xml', '$word.settings+xml');
      if (header) override('/word/header1.xml', '$word.header+xml');
      override('/docProps/core.xml',
          'application/vnd.openxmlformats-package.core-properties+xml');
      override(
          '/docProps/app.xml',
          'application/vnd.openxmlformats-officedocument.'
              'extended-properties+xml');
    });
    return builder.buildDocument().toXmlString();
  }

  String _packageRels() {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('Relationships', namespaceUris: {null: _pkgRel}, nest: () {
      void rel(String id, String type, String target) =>
          builder.element('Relationship',
              attributes: {'Id': id, 'Type': type, 'Target': target});

      rel('rId1', '$_r/officeDocument', 'word/document.xml');
      rel(
          'rId2',
          'http://schemas.openxmlformats.org/package/2006/relationships/'
              'metadata/core-properties',
          'docProps/core.xml');
      rel('rId3', '$_r/extended-properties', 'docProps/app.xml');
    });
    return builder.buildDocument().toXmlString();
  }

  String _documentRels({required bool header}) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('Relationships', namespaceUris: {null: _pkgRel}, nest: () {
      void rel(String id, String type, String target) =>
          builder.element('Relationship',
              attributes: {'Id': id, 'Type': type, 'Target': target});

      rel('rId1', '$_r/styles', 'styles.xml');
      rel('rId2', '$_r/settings', 'settings.xml');
      if (header) rel('rId3', '$_r/header', 'header1.xml');
    });
    return builder.buildDocument().toXmlString();
  }

  String _coreProperties(BookMetadata metadata, DateTime modified) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    final stamp = _timestamp(modified);
    builder.element('cp:coreProperties', namespaceUris: {
      'cp': _cp,
      'dc': _dc,
      'dcterms': _dcterms,
      'xsi': _xsi,
    }, nest: () {
      builder.element('dc:title', nest: metadata.title);
      if (metadata.authorName.isNotEmpty) {
        builder.element('dc:creator', nest: metadata.authorName);
        builder.element('cp:lastModifiedBy', nest: metadata.authorName);
      }
      builder.element('dcterms:created',
          attributes: {'xsi:type': 'dcterms:W3CDTF'}, nest: stamp);
      builder.element('dcterms:modified',
          attributes: {'xsi:type': 'dcterms:W3CDTF'}, nest: stamp);
    });
    return builder.buildDocument().toXmlString();
  }

  String _appProperties(BookDocument document) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('Properties', namespaceUris: {null: _ep}, nest: () {
      builder.element('Application', nest: 'AuthorOS Book Studio');
      builder.element('Words', nest: '${document.wordCount}');
    });
    return builder.buildDocument().toXmlString();
  }

  String _settings() {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('w:settings', namespaceUris: {'w': _w}, nest: () {
      builder.element('w:defaultTabStop', attributes: {'w:val': '720'});
      // Deliberately no `w:evenAndOddHeaders`: only a default header part is
      // written, and switching odd and even apart would leave every left-hand
      // page bare.
      // Prompts Word to evaluate the contents field on open, so the author
      // does not have to know to refresh it themselves.
      builder.element('w:updateFields', attributes: {'w:val': 'true'});
    });
    return builder.buildDocument().toXmlString();
  }

  // --- styles -------------------------------------------------------------

  /// The named styles the document is built from.
  ///
  /// Style *ids* are what the document references; the `w:name` is what Word
  /// shows and, for the built-in names, what makes a paragraph a real heading —
  /// which is what fills the navigation pane and lets Word build a contents.
  /// Automatic line spacing, for any style that sets its own type size.
  ///
  /// The typeset flavour pins the body's leading with `lineRule="exact"` so the
  /// measure matches the printed book. Anything set larger than the body — a
  /// title, a chapter number — would then be clipped by that pinned leading,
  /// so every display style overrides it back to automatic.
  static const _autoLeading = {'w:line': '240', 'w:lineRule': 'auto'};

  String _styles(_Metrics metrics) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('w:styles', namespaceUris: {'w': _w}, nest: () {
      builder.element('w:docDefaults', nest: () {
        builder.element('w:rPrDefault', nest: () {
          builder.element('w:rPr', nest: () {
            _fonts(builder, metrics.bodyFont);
            builder.element('w:sz',
                attributes: {'w:val': '${metrics.bodySizeHalfPoints}'});
            builder.element('w:szCs',
                attributes: {'w:val': '${metrics.bodySizeHalfPoints}'});
          });
        });
        builder.element('w:pPrDefault', nest: () {
          builder.element('w:pPr', nest: () {
            builder.element('w:spacing', attributes: {
              'w:after': '0',
              'w:line': '${metrics.lineSpacing}',
              'w:lineRule': metrics.lineRule,
            });
          });
        });
      });

      void style(
        String id,
        String name, {
        String? basedOn,
        String? next,
        void Function()? paragraph,
        void Function()? run,
        bool quickFormat = true,
      }) {
        builder.element('w:style', attributes: {
          'w:type': 'paragraph',
          'w:styleId': id,
        }, nest: () {
          // CT_Style has a fixed child order; this is it.
          builder.element('w:name', attributes: {'w:val': name});
          if (basedOn != null) {
            builder.element('w:basedOn', attributes: {'w:val': basedOn});
          }
          if (next != null) {
            builder.element('w:next', attributes: {'w:val': next});
          }
          if (quickFormat) builder.element('w:qFormat');
          if (paragraph != null) {
            builder.element('w:pPr', nest: paragraph);
          }
          if (run != null) {
            builder.element('w:rPr', nest: run);
          }
        });
      }

      style('Normal', 'Normal');

      style('BodyText', 'Body Text', basedOn: 'Normal', paragraph: () {
        builder.element('w:spacing', attributes: {
          'w:after': '0',
          'w:line': '${metrics.lineSpacing}',
          'w:lineRule': metrics.lineRule,
        });
        builder.element('w:ind',
            attributes: {'w:firstLine': '${metrics.firstLineIndent}'});
        builder.element('w:jc',
            attributes: {'w:val': metrics.justified ? 'both' : 'left'});
      });

      // The paragraph that opens a chapter or follows a break takes no indent:
      // there is nothing above it to be set apart from.
      style('BodyTextFirst', 'Body Text First Indent',
          basedOn: 'BodyText', next: 'BodyText', paragraph: () {
        builder.element('w:ind', attributes: {'w:firstLine': '0'});
      });

      // "heading 1" is the built-in name. It is what puts the chapter into
      // Word's navigation pane and into a generated table of contents.
      style('Heading1', 'heading 1',
          basedOn: 'Normal', next: 'BodyTextFirst', paragraph: () {
        builder.element('w:keepNext');
        builder.element('w:pageBreakBefore');
        builder.element('w:spacing', attributes: {
          'w:before': '${metrics.chapterSink}',
          'w:after': '${metrics.bodyGap}',
          ..._autoLeading,
        });
        builder.element('w:jc', attributes: {'w:val': metrics.headingAlignment});
        builder.element('w:outlineLvl', attributes: {'w:val': '0'});
      }, run: () {
        _fonts(builder, metrics.displayFont);
        builder.element('w:b');
        builder.element('w:sz',
            attributes: {'w:val': '${metrics.bodySizeHalfPoints + 8}'});
      });

      style('PartTitle', 'Part Title',
          basedOn: 'Normal', next: 'BodyTextFirst', paragraph: () {
        builder.element('w:keepNext');
        builder.element('w:pageBreakBefore');
        builder.element('w:spacing', attributes: {
          'w:before': '${metrics.chapterSink}',
          'w:after': '${metrics.bodyGap}',
          ..._autoLeading,
        });
        builder.element('w:jc', attributes: {'w:val': 'center'});
        builder.element('w:outlineLvl', attributes: {'w:val': '0'});
      }, run: () {
        _fonts(builder, metrics.displayFont);
        builder.element('w:b');
        builder.element('w:sz',
            attributes: {'w:val': '${metrics.bodySizeHalfPoints + 16}'});
      });

      // The number carries the chapter's sink and its page break, because it
      // is the first thing on the page. The title that follows it is written
      // with the sink overridden away, or the opener would be split in two by
      // a third of a page of white.
      style('ChapterNumber', 'Chapter Number',
          basedOn: 'Normal', next: 'Heading1', paragraph: () {
        builder.element('w:keepNext');
        builder.element('w:pageBreakBefore');
        builder.element('w:spacing', attributes: {
          'w:before': '${metrics.chapterSink}',
          'w:after': '${metrics.titleGap}',
          ..._autoLeading,
        });
        builder.element('w:jc', attributes: {'w:val': metrics.headingAlignment});
      }, run: () {
        _fonts(builder, metrics.displayFont);
        builder.element('w:caps');
      });

      style('SceneBreak', 'Scene Break',
          basedOn: 'Normal', next: 'BodyTextFirst', paragraph: () {
        builder.element('w:keepNext');
        builder.element('w:spacing', attributes: {
          'w:before': '240',
          'w:after': '240',
          ..._autoLeading,
        });
        builder.element('w:jc', attributes: {'w:val': 'center'});
      });

      style('BookTitle', 'Title', basedOn: 'Normal', next: 'BodyText',
          paragraph: () {
        builder.element('w:spacing',
            attributes: {'w:after': '240', ..._autoLeading});
        builder.element('w:jc', attributes: {'w:val': 'center'});
      }, run: () {
        _fonts(builder, metrics.displayFont);
        builder.element('w:b');
        builder.element('w:sz',
            attributes: {'w:val': '${metrics.bodySizeHalfPoints + 20}'});
      });

      style('BookSubtitle', 'Subtitle', basedOn: 'Normal', next: 'BodyText',
          paragraph: () {
        builder.element('w:spacing',
            attributes: {'w:after': '240', ..._autoLeading});
        builder.element('w:jc', attributes: {'w:val': 'center'});
      });

      style('FrontMatter', 'Front Matter', basedOn: 'Normal', paragraph: () {
        builder.element('w:spacing',
            attributes: {'w:after': '120', ..._autoLeading});
        builder.element('w:jc', attributes: {'w:val': 'center'});
      });

      style('Copyright', 'Copyright', basedOn: 'Normal', paragraph: () {
        builder.element('w:spacing', attributes: {
          'w:after': '120',
          'w:line': '240',
          'w:lineRule': 'auto',
        });
        builder.element('w:jc', attributes: {'w:val': 'left'});
      }, run: () {
        builder.element('w:sz',
            attributes: {'w:val': '${metrics.bodySizeHalfPoints - 4}'});
      });

      style('RunningHeader', 'header', basedOn: 'Normal', paragraph: () {
        builder.element('w:spacing',
            attributes: {'w:after': '0', 'w:line': '240', 'w:lineRule': 'auto'});
        builder.element('w:jc', attributes: {'w:val': 'right'});
      }, quickFormat: false);
    });
    return builder.buildDocument().toXmlString();
  }

  void _fonts(XmlBuilder builder, String name) {
    builder.element('w:rFonts', attributes: {
      'w:ascii': name,
      'w:hAnsi': name,
      'w:cs': name,
    });
  }

  // --- the document -------------------------------------------------------

  String _document(BookDocument document, _Metrics metrics) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    builder.element('w:document',
        namespaceUris: {'w': _w, 'r': _r}, nest: () {
      builder.element('w:body', nest: () {
        // Whether nothing has been written yet. The first paragraph in the
        // document must suppress its style's page break, or Word opens on a
        // blank page.
        var atStart = true;

        for (final page in document.frontMatter) {
          _matter(builder, page,
              atStart: atStart, markup: document.inlineMarkup);
          atStart = false;
        }

        for (final element in document.body) {
          switch (element) {
            case BookPartElement(:final heading):
              _paragraph(builder, 'PartTitle', heading.displayTitle,
                  pageBreakBefore: atStart ? false : null);
              if (heading.subtitle.trim().isNotEmpty) {
                _paragraph(builder, 'FrontMatter', heading.subtitle.trim());
              }
            case BookChapterElement(:final chapter):
              _chapter(builder, chapter, metrics,
                  atStart: atStart, markup: document.inlineMarkup);
          }
          atStart = false;
        }

        for (final page in document.backMatter) {
          _matter(builder, page,
              atStart: atStart, markup: document.inlineMarkup);
          atStart = false;
        }

        _sectionProperties(builder, metrics);
      });
    });
    return builder.buildDocument().toXmlString();
  }

  /// A chapter: its opener, then its scenes separated by breaks.
  void _chapter(
    XmlBuilder builder,
    BookChapterContent chapter,
    _Metrics metrics, {
    required bool atStart,
    required BookInlineMarkup markup,
  }) {
    final number = metrics.numberLabel(chapter.number);
    final title = chapter.title.trim();

    // The number and the title are separate paragraphs, as they are in the
    // EPUB and in the book itself. Only the title is a Heading 1, so Word's
    // navigation pane and any generated contents list the chapter once.
    if (number.isNotEmpty) {
      _paragraph(builder, 'ChapterNumber', number,
          pageBreakBefore: atStart ? false : null);
    }
    _paragraph(
      builder,
      'Heading1',
      title.isEmpty
          ? (number.isEmpty ? 'Chapter ${chapter.number}' : number)
          : title,
      // The number above already carried both the page break and the sink. A
      // second of either would strand the number alone at the top of the page
      // with the title a third of a page below it.
      pageBreakBefore: number.isNotEmpty ? false : (atStart ? false : null),
      spaceBefore: number.isNotEmpty ? 0 : null,
    );

    var isFirstParagraph = true;
    for (var s = 0; s < chapter.scenes.length; s++) {
      if (s > 0) _paragraph(builder, 'SceneBreak', metrics.sceneBreak);
      final scene = chapter.scenes[s];
      for (var p = 0; p < scene.paragraphs.length; p++) {
        final afterBreak = isFirstParagraph || (p == 0 && s > 0);
        _paragraph(
          builder,
          afterBreak ? 'BodyTextFirst' : 'BodyText',
          scene.paragraphs[p].text,
          spans: scene.paragraphs[p].resolve(markup),
        );
        isFirstParagraph = false;
      }
    }
  }

  /// One front- or back-matter section.
  void _matter(
    XmlBuilder builder,
    BookMatterPage page, {
    required bool atStart,
    required BookInlineMarkup markup,
  }) {
    // A title page is set as a title and its subordinate lines; everything
    // else is a heading over a block of text.
    if (page.layout == BookMatterLayout.titlePage) {
      if (page.paragraphs.isEmpty) return;
      _paragraph(builder, 'BookTitle', page.paragraphs.first,
          pageBreakBefore: !atStart);
      for (final line in page.paragraphs.skip(1)) {
        _paragraph(builder, 'BookSubtitle', line);
      }
      return;
    }

    final style = page.layout == BookMatterLayout.copyrightBlock
        ? 'Copyright'
        : 'FrontMatter';

    var broken = atStart;
    if (page.title.isNotEmpty) {
      _paragraph(builder, 'Heading1', page.title,
          pageBreakBefore: atStart ? false : null);
      broken = true;
    }

    // A contents page is built during pagination, from page numbers this file
    // does not have — Word repaginates on whatever paper it is opened with, so
    // any number written here would be wrong. Instead it gets Word's own TOC
    // field, which reads the Heading 1 styles the chapters are set in and
    // fills itself in with the page numbers Word has just worked out. This is
    // the whole reason the headings are real named styles.
    if (page.layout == BookMatterLayout.contents) {
      _tableOfContents(builder);
      return;
    }

    for (final paragraph in page.paragraphs) {
      _paragraph(builder, style, paragraph,
          pageBreakBefore: broken ? null : true, markup: markup);
      broken = true;
    }
  }

  /// A `TOC` field, switched to build from Heading 1 only and to hyperlink.
  ///
  /// Written as a five-run field rather than `w:fldSimple` because the
  /// placeholder text has to sit between `separate` and `end`: a reader that
  /// does not evaluate fields then shows that line instead of a blank page,
  /// and Word replaces it as soon as the field is updated.
  void _tableOfContents(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', attributes: {'w:val': 'FrontMatter'});
      });
      builder.element('w:r', nest: () {
        builder.element('w:fldChar', attributes: {'w:fldCharType': 'begin'});
      });
      builder.element('w:r', nest: () {
        builder.element('w:instrText',
            attributes: {'xml:space': 'preserve'},
            nest: ' TOC \\o "1-1" \\h \\z \\u ');
      });
      builder.element('w:r', nest: () {
        builder.element('w:fldChar', attributes: {'w:fldCharType': 'separate'});
      });
      builder.element('w:r', nest: () {
        builder.element('w:t',
            attributes: {'xml:space': 'preserve'},
            nest: 'Right-click and choose Update Field to build the contents.');
      });
      builder.element('w:r', nest: () {
        builder.element('w:fldChar', attributes: {'w:fldCharType': 'end'});
      });
    });
  }

  /// One paragraph.
  ///
  /// `w:pPr` children have a fixed schema order — style, break, spacing,
  /// indent, alignment — and Word rejects a document that gets it wrong, so it
  /// is written in one place rather than at each call site.
  ///
  /// [pageBreakBefore] is three-valued on purpose. Null leaves the named style
  /// to decide, which is what an editor wants: inserting a chapter heading
  /// should start a page without them having to know that. True and false
  /// override the style, and the false case earns its keep twice — the first
  /// paragraph of the document must not break, or Word opens on a blank page,
  /// and a chapter number carries the break for the title that follows it.
  void _paragraph(
    XmlBuilder builder,
    String style,
    String text, {
    bool? pageBreakBefore,
    int? spaceBefore,
    int? spaceAfter,
    BookInlineMarkup markup = BookInlineMarkup.none,

    /// Emphasis already resolved by the caller.
    ///
    /// Scene prose passes this because its marks may come from the editor
    /// rather than from the typed convention; generated matter, which has no
    /// marks to carry, still resolves from [text] and [markup].
    List<ProseSpan>? spans,
  }) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', attributes: {'w:val': style});
        if (pageBreakBefore != null) {
          builder.element('w:pageBreakBefore',
              attributes: pageBreakBefore ? const {} : {'w:val': 'false'});
        }
        if (spaceBefore != null || spaceAfter != null) {
          builder.element('w:spacing', attributes: {
            if (spaceBefore != null) 'w:before': '$spaceBefore',
            if (spaceAfter != null) 'w:after': '$spaceAfter',
            ..._autoLeading,
          });
        }
      });
      // One `w:r` per stretch of a single style. With no emphasis in the
      // paragraph that is a single run, exactly as it was before.
      for (final span in spans ?? parseProse(text, markup)) {
        if (span.text.isEmpty) continue;
        builder.element('w:r', nest: () {
          if (span.italic) {
            // Direct run formatting, and the one place this file uses it. A
            // named character style would be tidier in principle and would
            // stop an editor italicising a word by hand, which is exactly what
            // an editor is for.
            builder.element('w:rPr', nest: () {
              builder.element('w:i');
              builder.element('w:iCs');
            });
          }
          builder.element('w:t', attributes: {
            // Without this Word trims leading and trailing spaces, which in
            // prose is a silent change to what the author wrote.
            'xml:space': 'preserve',
          }, nest: span.text);
        });
      }
    });
  }

  void _sectionProperties(XmlBuilder builder, _Metrics metrics) {
    builder.element('w:sectPr', nest: () {
      // CT_SectPr order puts references before the page description.
      if (metrics.runningHeader) {
        builder.element('w:headerReference',
            attributes: {'w:type': 'default', 'r:id': 'rId3'});
      }
      builder.element('w:pgSz', attributes: {
        'w:w': '${metrics.pageWidth}',
        'w:h': '${metrics.pageHeight}',
      });
      builder.element('w:pgMar', attributes: {
        'w:top': '${metrics.marginTop}',
        'w:right': '${metrics.marginRight}',
        'w:bottom': '${metrics.marginBottom}',
        'w:left': '${metrics.marginLeft}',
        'w:header': '720',
        'w:footer': '720',
        'w:gutter': '0',
      });
    });
  }

  /// `Surname / TITLE / page`, which is what standard manuscript format means.
  String _header(BookMetadata metadata) {
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8', attributes: {'standalone': 'yes'});
    final surname = metadata.authorName.trim().isEmpty
        ? ''
        : metadata.authorName.trim().split(RegExp(r'\s+')).last;
    final prefix = [
      if (surname.isNotEmpty) surname,
      metadata.title.toUpperCase(),
    ].join(' / ');

    builder.element('w:hdr', namespaceUris: {'w': _w, 'r': _r}, nest: () {
      builder.element('w:p', nest: () {
        builder.element('w:pPr', nest: () {
          builder.element('w:pStyle', attributes: {'w:val': 'RunningHeader'});
        });
        builder.element('w:r', nest: () {
          builder.element('w:t',
              attributes: {'xml:space': 'preserve'}, nest: '$prefix / ');
        });
        // A page-number field, so Word keeps it right as the document changes.
        builder.element('w:fldSimple',
            attributes: {'w:instr': ' PAGE '}, nest: () {
          builder.element('w:r', nest: () {
            builder.element('w:t', nest: '1');
          });
        });
      });
    });
    return builder.buildDocument().toXmlString();
  }

  static String _timestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }
}
