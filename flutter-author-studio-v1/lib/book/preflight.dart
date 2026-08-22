/// Book Studio Phase 5 — preflight.
///
/// Preflight is the last thing between a book and a printer. It answers one
/// question the Proofing stage cannot: *will this come out right in the format
/// I am about to export?*
///
/// That is why it is a separate engine from [ProofRule] rather than more
/// [LayoutProofRule]s. A proof rule asks whether the text is well set and is
/// blind to where the book is going — a river is a river whether the file ends
/// up a PDF or an EPUB. A preflight check cannot answer anything without
/// knowing the target: a missing italic face matters enormously in a PDF, where
/// this app embeds the fonts, and not at all in an EPUB, where the reading
/// system supplies them. The target is in the signature because it is in the
/// question.
///
/// **It reports; it never blocks.** Export always proceeds. An author has
/// context this engine does not — a proof copy, a printer with its own rules, a
/// deliberate choice — and a tool that refuses to produce a file is a tool that
/// gets worked around rather than read.
///
/// Findings are [ProofFinding]s, deliberately: the studio already knows how to
/// display them, and an author should not have to learn a second word for
/// "warning". Preflight is the first thing in Book Studio that legitimately
/// emits [ProofSeverity.critical] — no layout rule does, because no layout rule
/// describes something that will actually come out broken.
library;

import 'book_cover.dart';
import 'book_document.dart';
import 'book_export_targets.dart';
import 'book_fonts.dart';
import 'book_format.dart';
import 'book_layout.dart';
import 'epub_settings.dart';
import 'preflight_checks.dart';
import 'proofing.dart';

/// Everything a check is allowed to look at.
class PreflightContext {
  const PreflightContext({
    required this.document,
    required this.target,
    required this.format,
    this.paginated,
    this.epub = EpubSettings.defaults,
    this.assets,
    this.cover,
  });

  final BookDocument document;

  /// The export about to happen. Every check is allowed to care about this.
  final BookExportFormat target;

  final BookFormat format;

  /// The laid-out book. Null for a reflowable target, which has no pages —
  /// checks about page order and extent simply do not run there.
  final PaginatedBook? paginated;

  final EpubSettings epub;

  /// What the build actually ships. Null when fonts are not loaded, in which
  /// case the embedding check produces nothing rather than guessing.
  final BookFontAssets? assets;

  final BookCover? cover;

  bool get isPrint =>
      target == BookExportFormat.printPdf ||
      target == BookExportFormat.digitalPdf;
}

/// One check.
abstract class PreflightCheck {
  const PreflightCheck();

  /// Stable across releases.
  String get id;

  String get label;
  String get description;

  Iterable<ProofFinding> run(PreflightContext context);
}

/// What preflight found for one export.
class PreflightReport {
  const PreflightReport({
    required this.findings,
    required this.target,
    this.checksRun = 0,
  });

  static const empty =
      PreflightReport(findings: [], target: BookExportFormat.printPdf);

  final List<ProofFinding> findings;
  final BookExportFormat target;
  final int checksRun;

  bool get isClean => findings.isEmpty;

  int countOf(ProofSeverity severity) =>
      findings.where((finding) => finding.severity == severity).length;

  /// True when something will come out visibly wrong.
  ///
  /// Never gates the export — it decides how loudly the panel speaks.
  bool get hasCritical => countOf(ProofSeverity.critical) > 0;

  /// One line for the export button's neighbourhood.
  String get summary {
    if (findings.isEmpty) return 'Preflight found nothing to flag.';
    final critical = countOf(ProofSeverity.critical);
    final warnings = countOf(ProofSeverity.warning);
    final notices = countOf(ProofSeverity.notice);
    final parts = [
      if (critical > 0) '$critical needing attention',
      if (warnings > 0) '$warnings warning${warnings == 1 ? '' : 's'}',
      if (notices > 0) '$notices notice${notices == 1 ? '' : 's'}',
    ];
    return 'Preflight found ${parts.join(', ')}.';
  }
}

/// Runs the checks.
class PreflightEngine {
  const PreflightEngine({this.checks = BuiltInPreflightChecks.all});

  final List<PreflightCheck> checks;

  PreflightReport run(PreflightContext context) {
    final findings = <ProofFinding>[];
    for (final check in checks) {
      findings.addAll(check.run(context));
    }
    findings.sort((a, b) {
      final bySeverity = a.severity.rank.compareTo(b.severity.rank);
      if (bySeverity != 0) return bySeverity;
      return a.ruleId.compareTo(b.ruleId);
    });
    return PreflightReport(
      findings: List.unmodifiable(findings),
      target: context.target,
      checksRun: checks.length,
    );
  }
}

/// Every face the renderer will be asked to embed.
///
/// Derived from the laid-out book rather than from the renderer, so the answer
/// exists *before* an export the author may not have run yet. Only two element
/// kinds carry a face — [LayoutTextLine]'s runs and [LayoutDropCap] — because
/// [LayoutRule] and [LayoutOrnament] are vector paths with no glyphs in them.
/// `LayoutElement` is sealed, so a new kind that carries a face is a compile
/// error here rather than a silent omission.
Set<BookFontFace> requestedFaces(PaginatedBook book) {
  final faces = <BookFontFace>{};

  void collect(Iterable<LayoutElement> elements) {
    for (final element in elements) {
      switch (element) {
        case LayoutTextLine(:final runs):
          for (final run in runs) {
            faces.add(run.face);
          }
        case LayoutDropCap(:final face):
          faces.add(face);
        case LayoutRule():
        case LayoutOrnament():
          break;
      }
    }
  }

  for (final page in book.pages) {
    collect(page.elements);
    // Running heads and folios are set too, and in the display face.
    collect(page.marginalia);
  }
  return faces;
}
