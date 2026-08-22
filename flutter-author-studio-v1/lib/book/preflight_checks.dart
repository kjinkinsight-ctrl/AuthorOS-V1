/// Book Studio Phase 5 — the built-in preflight checks.
///
/// Each one answers a question the master plan's M7 exit gate asks literally:
/// font embedding, margins, page order, and blank-page rules. They are separate
/// classes rather than one long function so that a finding can always be traced
/// to the rule that produced it — the same property the proofing engine has,
/// and the same reason: AuthorOS is deliberately AI-free, and there is nowhere
/// in this file for a judgement call to hide.
library;

import 'book_export_targets.dart';
import 'book_fonts.dart';
import 'book_format.dart';
import 'book_layout.dart';
import 'preflight.dart';
import 'proofing.dart';

class BuiltInPreflightChecks {
  const BuiltInPreflightChecks._();

  static const List<PreflightCheck> all = [
    FontEmbeddingCheck(),
    MarginMinimumCheck(),
    GutterSettledCheck(),
    PageOrderCheck(),
    BlankPageCheck(),
    SignatureCheck(),
    CoverPresentCheck(),
    EmptyContentCheck(),
    LayoutIssueCheck(),
  ];
}

/// Is every face the book is set in actually going to be embedded?
///
/// This is the check the whole engine was worth building for. Until now a face
/// the build does not ship was substituted **silently** in two separate places,
/// so a book could be exported entirely in the wrong font with nothing
/// anywhere reporting it.
///
/// It is `critical` because it is not a matter of taste: the file will be
/// wrong, and the author will not find out until they open it.
class FontEmbeddingCheck extends PreflightCheck {
  const FontEmbeddingCheck();

  @override
  String get id => 'fontEmbedding';

  @override
  String get label => 'Fonts are embedded';

  @override
  String get description =>
      'Every face the book is set in has to travel inside the file, or it will '
      'be set in something else on a machine that does not have it.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final book = context.paginated;
    final assets = context.assets;
    if (book == null || assets == null) return;

    // An EPUB only embeds fonts when the author asks it to; otherwise the
    // reading system supplies them, which is the format working as intended.
    if (context.target == BookExportFormat.epub && !context.epub.embedFonts) {
      return;
    }

    final missing = requestedFaces(book)
        .where((face) => !assets.has(face))
        .toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));

    for (final face in missing) {
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.critical,
        title: '${_name(face)} is not bundled',
        message:
            'The book asks for ${_name(face)}, which this build does not ship. '
            'It will be set in ${_name(BookFontAssets.fallbackFace)} instead, '
            'and the exported file will not match the preview.',
        where: 'Fonts',
      );
    }
  }

  static String _name(BookFontFace face) {
    final family = switch (face.family) {
      BookFontFamilyId.merriweather => 'Merriweather',
      BookFontFamilyId.inter => 'Inter',
    };
    final style = switch (face.style) {
      BookFontStyleId.regular => 'Regular',
      BookFontStyleId.bold => 'Bold',
      BookFontStyleId.italic => 'Italic',
      BookFontStyleId.boldItalic => 'Bold Italic',
    };
    return '$family $style';
  }
}

/// Is any margin tighter than a printer will accept?
///
/// The floor is half an inch, which is the most permissive figure the major
/// print-on-demand services publish. Anything under it is reliably trimmed off,
/// so this is about text being physically cut from the page rather than about
/// how the page looks.
class MarginMinimumCheck extends PreflightCheck {
  const MarginMinimumCheck();

  /// Half an inch, in points.
  static const floorPt = 36.0;

  @override
  String get id => 'marginMinimum';

  @override
  String get label => 'Margins clear the trim';

  @override
  String get description =>
      'A printer cuts the page to size with a tolerance. Text closer to the '
      'edge than half an inch can be cut off.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    if (!context.isPrint) return;
    final margins = context.format.margins;

    final tight = <String, double>{
      'top': margins.topPt,
      'bottom': margins.bottomPt,
      'outside': margins.outsidePt,
      'inside': margins.insidePt,
    }..removeWhere((_, value) => value >= floorPt);

    for (final entry in tight.entries) {
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.warning,
        title: 'The ${entry.key} margin is ${_inches(entry.value)}',
        message:
            'Most printers want at least half an inch. Below that, the trim '
            'tolerance can take text off the page.',
        where: 'Margins',
      );
    }
  }

  static String _inches(double points) =>
      '${(points / 72).toStringAsFixed(2)} in';
}

/// Did the print-on-demand binding allowance settle?
///
/// The gutter grows with the page count, which changes the measure, which
/// changes the page count. The engine re-flows within a bounded pass count and
/// reports `gutterDrift` if it never converged — at which point the exported
/// gutter can be one band too narrow, and the inside margin of a thick book is
/// exactly where that shows.
class GutterSettledCheck extends PreflightCheck {
  const GutterSettledCheck();

  @override
  String get id => 'gutterSettled';

  @override
  String get label => 'Binding allowance settled';

  @override
  String get description =>
      'A thicker book needs more of the inside edge given up to the binding, '
      'and adding it makes the book thicker again.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final book = context.paginated;
    if (book == null || !context.isPrint) return;

    for (final issue in book.issues.where((i) => i.code == 'gutterDrift')) {
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.warning,
        title: 'The binding allowance did not settle',
        message: '${issue.message} Setting the gutter by hand in the Design '
            'stage will pin it.',
        where: 'Margins',
      );
    }
  }
}

/// Does every chapter open on the side its rule requires?
///
/// A book set to open chapters on a right-hand page and then not doing so is
/// the kind of error nobody catches in a preview and everybody notices in a
/// printed copy. It is `critical` because the rule is the author's own stated
/// intent and the file breaks it.
class PageOrderCheck extends PreflightCheck {
  const PageOrderCheck();

  @override
  String get id => 'pageOrder';

  @override
  String get label => 'Chapters open on the right side';

  @override
  String get description =>
      'A right-hand page is a recto. When a book opens its chapters there, '
      'every one of them has to.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final book = context.paginated;
    if (book == null || !context.isPrint) return;
    if (context.format.chapter.startRule != ChapterStartRule.recto) return;

    for (final page in book.pages) {
      if (page.role != BookPageRole.chapterOpener &&
          page.role != BookPageRole.partTitle) {
        continue;
      }
      if (page.isRecto) continue;
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.critical,
        title: 'A chapter opens on a left-hand page',
        message:
            'Page ${page.index + 1} opens a chapter on a verso, but this book '
            'is set to start chapters on a right-hand page.',
        where: 'Page ${page.index + 1}',
      );
    }
  }
}

/// How many blank pages will the printer charge for?
///
/// Moved here from the Proofing stage, where it never belonged: this is a
/// question about what a printer does and what it costs, not about how the text
/// is set.
class BlankPageCheck extends PreflightCheck {
  const BlankPageCheck();

  @override
  String get id => 'blankPages';

  @override
  String get label => 'Blank pages';

  @override
  String get description =>
      'Blank pages exist so chapters open on a right-hand page. Print-on-'
      'demand charges for them.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final book = context.paginated;
    if (book == null || !context.isPrint) return;
    final blanks = book.stats.blankPageCount;
    if (blanks == 0) return;

    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.notice,
      title: '$blanks blank page${blanks == 1 ? '' : 's'}',
      message: 'These exist so chapters open on a right-hand page, which is '
          'how a printed book reads. Print-on-demand charges for them, so if '
          'that matters, let chapters start on any new page instead.',
      where: 'Layout',
    );
  }
}

/// Is the extent a multiple of four?
///
/// Also moved from Proofing, for the same reason: a printer folds paper in
/// fours, and this is about the fold.
class SignatureCheck extends PreflightCheck {
  const SignatureCheck();

  @override
  String get id => 'signature';

  @override
  String get label => 'Page count folds evenly';

  @override
  String get description =>
      'A printer folds paper in fours, so a book that is not a multiple of '
      'four gets blank leaves added at the back.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final book = context.paginated;
    if (book == null || !context.isPrint) return;
    if (book.format.reflowable) return;

    final remainder = book.pageCount % 4;
    if (remainder == 0) return;
    final added = 4 - remainder;

    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.notice,
      title: '${book.pageCount} pages is not a multiple of four',
      message: 'A printer folds paper in fours, so $added blank '
          'leaf${added == 1 ? '' : 'ves'} will be added at the back. '
          'Back matter is a good way to use them.',
      where: 'Layout',
    );
  }
}

/// Is there a cover on a format that shows one?
class CoverPresentCheck extends PreflightCheck {
  const CoverPresentCheck();

  @override
  String get id => 'coverPresent';

  @override
  String get label => 'The ebook has a cover';

  @override
  String get description =>
      'A cover is the first thing a reader sees in a library, and an ebook '
      'without one shows a grey placeholder.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    if (context.target != BookExportFormat.epub) return;
    if (context.cover != null) return;

    yield ProofFinding(
      ruleId: id,
      stage: ProofStage.layout,
      severity: ProofSeverity.warning,
      title: 'No cover image',
      message: 'Every store and library shows a cover. Without one this book '
          'appears as a grey placeholder. Add one in the Structure stage.',
      where: 'Cover',
    );
  }
}

/// Is anything empty about to be exported?
///
/// The document builder already notices these; preflight is where they stop
/// being informational, because this is the last moment before they reach a
/// reader.
class EmptyContentCheck extends PreflightCheck {
  const EmptyContentCheck();

  static const _codes = {'emptyManuscript', 'emptySection', 'emptyChapter'};

  @override
  String get id => 'emptyContent';

  @override
  String get label => 'Nothing is empty';

  @override
  String get description =>
      'An empty chapter or section still takes a page, and reads as a mistake.';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    for (final issue in context.document.issues) {
      if (!_codes.contains(issue.code)) continue;
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: issue.code == 'emptyManuscript'
            ? ProofSeverity.critical
            : ProofSeverity.warning,
        title: 'Empty content',
        message: issue.message,
        where: 'Structure',
      );
    }

    for (final issue in context.paginated?.issues ?? const <BookLayoutIssue>[]) {
      if (!_codes.contains(issue.code)) continue;
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.warning,
        title: 'Empty chapter',
        message: issue.message,
        where: issue.pageIndex == null ? 'Layout' : 'Page ${issue.pageIndex! + 1}',
      );
    }
  }
}

/// Anything the engine reported that no other check has claimed.
///
/// A catch-all so that adding a new issue code to the layout engine surfaces it
/// somewhere, rather than it being silently dropped because nobody remembered
/// to write a check for it.
class LayoutIssueCheck extends PreflightCheck {
  const LayoutIssueCheck();

  /// Codes another check reports in its own words.
  static const _claimed = {
    'gutterDrift',
    'emptyChapter',
    'emptyManuscript',
    'emptySection',
    // Preflight derives font substitution from the laid-out book instead, which
    // catches the cases the engine's own map misses.
    'fontSubstituted',
  };

  @override
  String get id => 'layoutIssue';

  @override
  String get label => 'Everything else the layout reported';

  @override
  String get description =>
      'A catch-all, so a problem the engine noticed is never dropped just '
      'because no check was written for it.';

  /// Author-facing names for the codes that reach here.
  ///
  /// An issue code is a developer's word. Putting `incompleteCopyright` in
  /// front of a novelist is the kind of thing that makes a tool feel like it
  /// was built for someone else, so every code that can reach this check has a
  /// title written in the author's terms, and anything new falls back to
  /// something honest rather than to its own identifier.
  static const _titles = {
    'danglingPart': 'A part points at a chapter that is gone',
    'duplicatePartAnchor': 'Two parts start at the same chapter',
    'incompleteCopyright': 'The copyright page is missing something',
    'fontSubstituted': 'A font was substituted',
    'gutterDrift': 'The binding allowance did not settle',
  };

  static String _title(String code) => _titles[code] ?? 'Worth checking';

  @override
  Iterable<ProofFinding> run(PreflightContext context) sync* {
    final issues = [
      ...?context.paginated?.issues.where((i) => !_claimed.contains(i.code)),
    ];
    for (final issue in issues) {
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.warning,
        title: _title(issue.code),
        message: issue.message,
        where: issue.pageIndex == null
            ? 'Layout'
            : 'Page ${issue.pageIndex! + 1}',
      );
    }

    for (final issue in context.document.issues.where(
        (i) => !EmptyContentCheck._codes.contains(i.code))) {
      yield ProofFinding(
        ruleId: id,
        stage: ProofStage.layout,
        severity: ProofSeverity.warning,
        title: _title(issue.code),
        message: issue.message,
        where: 'Structure',
      );
    }
  }
}
