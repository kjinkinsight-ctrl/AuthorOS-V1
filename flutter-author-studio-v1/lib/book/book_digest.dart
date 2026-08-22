/// Book Studio Phase 5 — a laid-out book as reviewable text.
///
/// M7's exit gate asks that *"golden fixtures validate representative books"*.
/// This is the serialization those fixtures are written in.
///
/// **Why text and not a PDF or a PNG.** A binary golden for a PDF is
/// unreviewable — a diff says "these 40 kilobytes changed" and a human learns
/// nothing — and it would be rewritten by any change inside `package:pdf` that
/// has nothing to do with this book. What is actually under test is the
/// *layout*: where every line landed, on which page, with what folio and
/// running head. That is text, it diffs legibly, and a reviewer can see at a
/// glance whether a change was intended.
///
/// **What it deliberately leaves out.** Elapsed time and pass counts, which are
/// machine-dependent, and font objects, which are not layout. Coordinates are
/// rounded to two decimal places so that floating-point noise cannot fail a
/// build over a difference no reader could see.
///
/// **What it deliberately keeps.** Folios and running heads. Page furniture is
/// exactly where an off-by-one in the front matter shows up, and it is the part
/// a page-count assertion cannot see.
library;

import 'book_layout.dart';

/// The version of this format, written into every fixture.
///
/// Following `test/legacy_fixture_contract_test.dart`, which pins the same way:
/// if the digest ever needs to change shape, the version is how a stale fixture
/// announces itself rather than failing as a mysterious mismatch.
const bookDigestVersion = 1;

/// Renders [book] as the text a golden fixture holds.
String bookDigest(PaginatedBook book) {
  final buffer = StringBuffer()
    ..writeln('# bookDigestVersion: $bookDigestVersion')
    ..writeln('# format: ${book.format.id}')
    ..writeln('# trim: ${_n(book.format.trim.widthPt)}'
        'x${_n(book.format.trim.heightPt)}pt')
    ..writeln('# pages: ${book.pageCount}')
    ..writeln('# words: ${book.stats.wordCount}')
    ..writeln('# blanks: ${book.stats.blankPageCount}')
    ..writeln('# front: ${book.stats.frontMatterPageCount}'
        '  body: ${book.stats.bodyPageCount}'
        '  back: ${book.stats.backMatterPageCount}');

  for (final issue in book.issues) {
    buffer.writeln('# issue: ${issue.code}');
  }

  for (final entry in book.toc) {
    buffer.writeln('T ${entry.level} ${entry.folio} ${entry.title}');
  }

  for (final page in book.pages) {
    buffer.writeln(
      'P${page.index} ${page.role.name} ${page.isRecto ? 'recto' : 'verso'}'
      '${page.isBlank ? ' blank' : ''}'
      ' folio=${page.folio ?? ''}'
      ' head=${page.runningHead ?? ''}'
      ' block=${_n(page.textBlockLeftPt)},${_n(page.textBlockTopPt)}'
      ' ${_n(page.textBlockWidthPt)}x${_n(page.textBlockHeightPt)}',
    );

    for (final element in page.elements) {
      buffer.writeln('  ${_element(element)}');
    }
    for (final line in page.marginalia) {
      buffer.writeln('  M ${_n(line.x)} ${_n(line.baselineY)} ${line.text}');
    }
  }

  return buffer.toString();
}

String _element(LayoutElement element) => switch (element) {
      LayoutTextLine(:final x, :final baselineY, :final text) =>
        'L ${_n(x)} ${_n(baselineY)} $text',
      LayoutDropCap(:final x, :final baselineY, :final glyph, :final sizePt) =>
        'C ${_n(x)} ${_n(baselineY)} ${_n(sizePt)} $glyph',
      LayoutRule(:final x, :final y, :final widthPt) =>
        'R ${_n(x)} ${_n(y)} ${_n(widthPt)}',
      LayoutOrnament(:final x, :final y, :final ornament) =>
        'O ${_n(x)} ${_n(y)} ${ornament.name}',
    };

/// Two decimal places, so float noise cannot fail a build.
String _n(double value) => value.toStringAsFixed(2);
