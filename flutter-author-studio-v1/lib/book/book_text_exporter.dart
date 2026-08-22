/// Book Studio Phase 4 — plain text.
///
/// Like EPUB and DOCX this consumes a [BookDocument] and never a
/// `PaginatedBook`. Plain text has no pages at all, so inheriting a print
/// layout's breaks would be nonsense; the fidelity test fails the build if this
/// file reaches for the layout engine.
///
/// **Why a book still needs a text export.** It is the format nothing can
/// refuse. Diff tools, word-count scripts, submission portals that only take a
/// paste box, backup that has to still be readable in twenty years — none of
/// them open a `.docx`, and all of them open this. It is also the only export
/// an author can read with their own eyes and confirm nothing was lost.
///
/// **What it deliberately does not do.** No box drawing, no centred headings
/// padded with spaces, no ASCII rules across a fixed column. Those assume a
/// monospaced font at a known width, and the moment the file is opened in
/// anything proportional they turn a clean manuscript into ragged debris.
library;

import 'book_document.dart';
import 'book_format.dart';

/// How much structure the text file carries.
enum TextExportStyle {
  /// The book as prose: headings, scene breaks, blank lines between
  /// paragraphs. What a person reads.
  readable,

  /// Prose only, with no headings or matter at all. What a word-count or a
  /// diff wants.
  manuscriptOnly,
}

extension TextExportStyleX on TextExportStyle {
  String get label => switch (this) {
        TextExportStyle.readable => 'Readable',
        TextExportStyle.manuscriptOnly => 'Prose only',
      };

  String get description => switch (this) {
        TextExportStyle.readable =>
          'Front matter, chapter headings and scene breaks, laid out with '
              'blank lines. The whole book, as a person would read it.',
        TextExportStyle.manuscriptOnly =>
          'Nothing but the prose, in reading order — for word counts, diffs '
              'and anything that would rather not skip past headings.',
      };
}

/// Renders a book as plain text.
class BookTextExporter {
  const BookTextExporter();

  /// Line endings.
  ///
  /// `\n` throughout, including on Windows. A file written with `\r\n` reads
  /// correctly nearly everywhere, but a file written with `\n` reads correctly
  /// everywhere including Notepad since 2018, and it is the only choice that
  /// keeps the export byte-identical across the platforms AuthorOS runs on.
  static const _newline = '\n';

  String export({
    required BookDocument document,
    TextExportStyle style = TextExportStyle.readable,
    BookFormat? format,
  }) {
    final blocks = <String>[];
    final sceneBreak = _sceneBreakFor(format);

    if (style == TextExportStyle.readable) {
      for (final page in document.frontMatter) {
        blocks.addAll(_matter(page, document, format));
      }
    }

    for (final element in document.body) {
      switch (element) {
        case BookPartElement(:final heading):
          if (style == TextExportStyle.readable) {
            blocks.add(heading.displayTitle);
            if (heading.subtitle.trim().isNotEmpty) {
              blocks.add(heading.subtitle.trim());
            }
          }
        case BookChapterElement(:final chapter):
          blocks.addAll(_chapter(chapter, style, sceneBreak, format));
      }
    }

    if (style == TextExportStyle.readable) {
      for (final page in document.backMatter) {
        blocks.addAll(_matter(page, document, format));
      }
    }

    // One blank line between blocks, and a trailing newline: a text file
    // without one is the kind of thing that makes `cat` run two files
    // together, and every tool that reads lines expects it.
    final body = blocks.where((block) => block.isNotEmpty).join(
          '$_newline$_newline',
        );
    return body.isEmpty ? '' : '$body$_newline';
  }

  Iterable<String> _chapter(
    BookChapterContent chapter,
    TextExportStyle style,
    String sceneBreak,
    BookFormat? format,
  ) sync* {
    if (style == TextExportStyle.readable) {
      final heading = _chapterHeading(chapter, format);
      if (heading.isNotEmpty) yield heading;
    }

    for (var s = 0; s < chapter.scenes.length; s++) {
      if (s > 0 && style == TextExportStyle.readable) {
        // A blank-line break is already the blank line between two blocks,
        // so printing nothing is the break.
        if (sceneBreak.isNotEmpty) yield sceneBreak;
      }
      for (final paragraph in chapter.scenes[s].paragraphs) {
        final text = paragraph.trim();
        if (text.isNotEmpty) yield text;
      }
    }
  }

  Iterable<String> _matter(
    BookMatterPage page,
    BookDocument document,
    BookFormat? format,
  ) sync* {
    if (page.title.trim().isNotEmpty) yield page.title.trim();

    // A contents page is built during pagination, from page numbers a text
    // file does not have. Rather than print the heading over nothing, the
    // chapters are listed by name — which is the part of a contents page that
    // survives into a format with no pages.
    if (page.layout == BookMatterLayout.contents) {
      // Chapters sit under their part, as they do on a real contents page.
      // Two spaces, not a padded column: an indent reads correctly in any
      // font, and a column only lines up in a monospaced one.
      final hasParts = document.body.any((e) => e is BookPartElement);
      for (final element in document.body) {
        switch (element) {
          case BookPartElement(:final heading):
            yield heading.displayTitle;
          case BookChapterElement(:final chapter):
            final entry = _chapterHeading(chapter, format);
            yield hasParts ? '  $entry' : entry;
        }
      }
      return;
    }

    for (final paragraph in page.paragraphs) {
      final text = paragraph.trim();
      if (text.isNotEmpty) yield text;
    }
  }

  /// `Chapter One: The Crossing`, or as much of it as the book has.
  String _chapterHeading(BookChapterContent chapter, BookFormat? format) {
    final number = _numberLabel(chapter.number, format);
    final title = chapter.title.trim();
    if (number.isEmpty) {
      return title.isEmpty ? 'Chapter ${chapter.number}' : title;
    }
    return title.isEmpty ? number : '$number: $title';
  }

  String _numberLabel(int number, BookFormat? format) {
    final chapterStyle = format?.chapter ?? const ChapterStyle();
    return chapterNumberLabel(number,
        style: chapterStyle.numberStyle, prefix: chapterStyle.numberPrefix);
  }

  /// An ornament is drawn as vector paths in the book, and plain text has no
  /// way to draw. It falls back to the glyph rather than printing nothing,
  /// because a lost scene break changes how the prose reads.
  String _sceneBreakFor(BookFormat? format) {
    final chapterStyle = format?.chapter ?? const ChapterStyle();
    return switch (chapterStyle.sceneBreak) {
      SceneBreakStyle.blankLine => '',
      SceneBreakStyle.glyph || SceneBreakStyle.ornament =>
        chapterStyle.sceneBreakGlyph.trim().isEmpty
            ? '* * *'
            : chapterStyle.sceneBreakGlyph.trim(),
    };
  }
}
