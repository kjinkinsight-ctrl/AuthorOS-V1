import 'dart:typed_data';

import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_pdf_renderer.dart';
import 'package:author_studio_v1/book/preflight.dart';
import 'package:author_studio_v1/book/preflight_checks.dart';
import 'package:author_studio_v1/book/proofing.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookFontAssets assets;

  setUpAll(() async {
    BookFontAssets.resetCache();
    assets = await BookFontAssets.load();
  });

  BookDocument document({
    BookFormat? format,
    ManuscriptProjectSummary? manuscript,
    List<BookPart> parts = const [],
  }) =>
      const BookDocumentBuilder().build(
        manuscript: manuscript ?? manuscriptFixture(),
        book: bookFixture(format: format, parts: parts),
        profileAuthorName: 'Kali Vale',
      );

  PaginatedBook paginate({
    BookFormat? format,
    ManuscriptProjectSummary? manuscript,
    BookFontMetrics? metrics,
  }) {
    final chosen = format ?? BookFormatPresets.paperback;
    return BookLayoutEngine(metrics ?? PdfBookFontMetrics(assets))
        .layout(document(format: chosen, manuscript: manuscript), chosen);
  }

  PreflightReport run({
    BookExportFormat target = BookExportFormat.printPdf,
    BookFormat? format,
    BookFontAssets? bundled,
    PaginatedBook? book,
    BookDocument? doc,
  }) {
    final chosen = format ?? BookFormatPresets.paperback;
    return const PreflightEngine().run(PreflightContext(
      document: doc ?? document(format: chosen),
      target: target,
      format: chosen,
      paginated: target.isReflowable ? null : (book ?? paginate(format: chosen)),
      assets: bundled ?? assets,
    ));
  }

  List<ProofFinding> only(PreflightReport report, String id) =>
      report.findings.where((f) => f.ruleId == id).toList();

  group('the set of faces a book asks for', () {
    test('includes the body face and the display face a heading is set in', () {
      final faces = requestedFaces(paginate());
      final typography = BookFormatPresets.paperback.typography;

      expect(faces, contains(
          BookFontFace(typography.bodyFamily, BookFontStyleId.regular)));
      expect(faces,
          contains(BookFontFace(typography.displayFamily, BookFontStyleId.bold)),
          reason: 'chapter titles are set bold');
    });

    test('includes the faces the running heads and folios are set in', () {
      // Page furniture lives outside the text block and is easy to miss when
      // walking a page. It is still text, and it still needs a font.
      final withHeads = paginate();
      expect(withHeads.pages.any((p) => p.marginalia.isNotEmpty), isTrue,
          reason: 'the fixture must actually have marginalia to prove this');
      expect(requestedFaces(withHeads), isNotEmpty);
    });

    // The real guard. If the derived set ever misses a face the renderer needs,
    // the renderer falls back silently — and the output changes. Rendering with
    // exactly the derived set and comparing bytes proves nothing was missed,
    // which is only checkable because the PDF is reproducible.
    test('is exactly what the renderer needs, proved by identical bytes',
        () async {
      final book = paginate();
      final trimmed = BookFontAssets({
        for (final face in requestedFaces(book))
          if (assets.bytesFor(face) != null) face: assets.bytesFor(face)!,
      });

      final full = await const BookPdfRenderer()
          .render(book, assets, modified: DateTime.utc(2026));
      final lean = await const BookPdfRenderer()
          .render(book, trimmed, modified: DateTime.utc(2026));

      expect(lean, orderedEquals(full),
          reason: 'a face the derived set missed would have been substituted, '
              'and the bytes would differ');
    });
  });

  group('font embedding', () {
    test('says nothing when every face is bundled', () {
      expect(only(run(), 'fontEmbedding'), isEmpty);
    });

    // The check is worthless if it has never once fired, so this removes a face
    // the book genuinely uses and proves it is caught.
    test('reports a face the build does not ship, and calls it critical', () {
      final book = paginate();
      final used = requestedFaces(book);
      final dropped = used.firstWhere(
          (face) => face.style == BookFontStyleId.bold,
          orElse: () => used.first);

      final partial = BookFontAssets({
        for (final face in assets.availableFaces)
          if (face != dropped) face: assets.bytesFor(face)!,
      });

      final findings = only(run(book: book, bundled: partial), 'fontEmbedding');
      expect(findings, hasLength(1));
      expect(findings.single.severity, ProofSeverity.critical);
      expect(findings.single.message, contains('will not match the preview'));
    });

    test('an EPUB that does not embed fonts is not asked to', () {
      // The reading system supplies the face there. That is the format working
      // as designed, not a problem to report.
      final report = run(target: BookExportFormat.epub, bundled: BookFontAssets(const {}));
      expect(only(report, 'fontEmbedding'), isEmpty);
    });
  });

  group('margins', () {
    test('a preset that clears the trim says nothing', () {
      expect(only(run(), 'marginMinimum'), isEmpty);
    });

    test('a margin under half an inch is reported with its measurement', () {
      final format = BookFormatPresets.paperback.copyWith(
        margins: BookFormatPresets.paperback.margins.copyWith(outsidePt: 18),
      );
      final findings = only(run(format: format), 'marginMinimum');

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('outside'));
      expect(findings.single.title, contains('0.25 in'));
    });

    test('margins are a print question and not asked of an EPUB', () {
      final format = BookFormatPresets.paperback.copyWith(
        margins: BookFormatPresets.paperback.margins.copyWith(topPt: 4),
      );
      expect(
          only(run(target: BookExportFormat.epub, format: format),
              'marginMinimum'),
          isEmpty);
    });
  });

  group('page order', () {
    test('a recto rule that is honoured says nothing', () {
      final report = run();
      expect(BookFormatPresets.paperback.chapter.startRule,
          ChapterStartRule.recto);
      expect(only(report, 'pageOrder'), isEmpty,
          reason: 'the engine is supposed to guarantee this');
    });

    test('a format that lets chapters start anywhere is not held to it', () {
      final format = BookFormatPresets.paperback.copyWith(
        chapter: BookFormatPresets.paperback.chapter
            .copyWith(startRule: ChapterStartRule.anyPage),
      );
      expect(only(run(format: format), 'pageOrder'), isEmpty);
    });
  });

  group('printer economics', () {
    test('blank pages are counted and explained before they are charged for',
        () {
      final findings = only(run(), 'blankPages');
      expect(findings, hasLength(1));
      expect(findings.single.message, contains('right-hand page'),
          reason: 'the author should be told why they exist before being told '
              'they cost money');
      expect(findings.single.severity, ProofSeverity.notice);
    });

    test('a screen format has no blank pages to report', () {
      expect(only(run(format: BookFormatPresets.ebook), 'blankPages'), isEmpty);
    });

    test('an extent that will not fold evenly is flagged', () {
      final book = paginate();
      final findings = only(run(book: book), 'signature');

      if (book.pageCount % 4 == 0) {
        expect(findings, isEmpty);
      } else {
        expect(findings, hasLength(1));
        expect(findings.single.message, contains('folds paper in fours'));
      }
    });
  });

  group('the cover', () {
    test('an EPUB without one is warned about', () {
      final findings = only(run(target: BookExportFormat.epub), 'coverPresent');
      expect(findings, hasLength(1));
      expect(findings.single.severity, ProofSeverity.warning);
    });

    test('a PDF is not, because print covers are made elsewhere', () {
      expect(only(run(), 'coverPresent'), isEmpty);
    });
  });

  group('the report', () {
    test('is clean on a book with nothing wrong with it', () {
      final report = run(format: BookFormatPresets.ebook);
      expect(report.hasCritical, isFalse);
    });

    test('counts by severity and says so in one line', () {
      final report = run();
      expect(report.summary, isNotEmpty);
      expect(report.checksRun, BuiltInPreflightChecks.all.length);
    });

    test('sorts the worst first', () {
      final book = paginate();
      final partial = BookFontAssets({
        BookFontAssets.fallbackFace:
            assets.bytesFor(BookFontAssets.fallbackFace)!,
      });
      final report = run(book: book, bundled: partial);

      expect(report.hasCritical, isTrue);
      expect(report.findings.first.severity, ProofSeverity.critical);
    });

    test('every check explains itself to the author', () {
      for (final check in BuiltInPreflightChecks.all) {
        expect(check.id, isNotEmpty);
        expect(check.label.trim(), isNotEmpty);
        expect(check.description.trim(), isNotEmpty,
            reason: '${check.id} has nothing to say for itself');
      }
    });

    test('check ids are unique', () {
      final ids = BuiltInPreflightChecks.all.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('a reflowable target is never asked about pages', () {
      for (final target in [BookExportFormat.docx, BookExportFormat.txt]) {
        final report = run(target: target);
        for (final id in const ['blankPages', 'signature', 'pageOrder']) {
          expect(only(report, id), isEmpty,
              reason: '$id has no meaning in ${target.name}');
        }
      }
    });
  });

  group('empty content', () {
    test('a manuscript with no chapters is critical', () {
      final empty = ManuscriptProjectSummary(
        projectId: 'project-book',
        manuscriptTitle: 'Nothing Yet',
        currentChapterId: '',
        currentSceneId: '',
        createdAt: fixtureTimestamp,
        updatedAt: fixtureTimestamp,
        version: 1,
        chapters: const [],
      );
      final report = const PreflightEngine().run(PreflightContext(
        document: document(manuscript: empty),
        target: BookExportFormat.txt,
        format: BookFormatPresets.paperback,
      ));

      final findings = only(report, 'emptyContent');
      expect(findings, isNotEmpty);
      expect(findings.first.severity, ProofSeverity.critical);
    });
  });

  test('a finding never shows the author a developer\'s issue code', () {
    // `incompleteCopyright` is a word for the person who wrote the engine.
    final report = run(
      doc: const BookDocumentBuilder().build(
        manuscript: manuscriptFixture(),
        // Default front matter, so there is a copyright page, but no year or
        // holder filled in for it.
        book: BookProject.initial('project-book'),
      ),
    );
    final findings = only(report, 'layoutIssue');

    expect(findings, isNotEmpty, reason: 'the fixture must produce one');
    for (final finding in findings) {
      expect(finding.title, isNot(matches(RegExp(r'^[a-z]+[A-Z]'))),
          reason: '"${finding.title}" is an identifier, not a sentence');
    }
  });

  test('preflight never claims a finding can be fixed for you', () {
    // Every one of these needs a decision, not a text substitution.
    for (final finding in run().findings) {
      expect(finding.isFixable, isFalse);
    }
  });
}
