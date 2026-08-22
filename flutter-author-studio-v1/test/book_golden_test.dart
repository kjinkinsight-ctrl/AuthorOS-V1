/// Golden fixtures for the layout engine.
///
/// Five representative books, pinned as text. M7's exit gate asks that "golden
/// fixtures validate representative books"; this is that check.
///
/// Each fixture is a `bookDigest` of a laid-out book: every page with its role,
/// side, folio and running head, and every line with its position and text.
/// They are built with the **real** `PdfBookFontMetrics`, not the fake ones the
/// arithmetic tests use — a golden built on invented metrics validates
/// arithmetic rather than books.
///
/// **When one of these fails**, look at the diff before regenerating. A change
/// to a preset, to the break rules, or to the engine *should* rewrite these
/// files, and the diff is how a reviewer sees exactly what moved. Regenerating
/// without reading it throws away the only thing the fixture was for.
///
///     bash tool/update-book-goldens.sh
library;

import 'dart:io';

import 'package:author_studio_v1/book/book_digest.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

/// One pinned book.
class GoldenBook {
  const GoldenBook(this.name, this.covers, this.build);

  final String name;

  /// What this book is here to catch, in one line.
  final String covers;

  final BookProject Function() build;

  ManuscriptProjectSummary manuscript() => switch (name) {
        'pod-long' => longManuscriptFixture(paragraphs: 24),
        'bare' => longManuscriptFixture(paragraphs: 6),
        _ => manuscriptFixture(),
      };
}

/// The set. Chosen for the shapes that actually break, not for coverage.
final goldenBooks = <GoldenBook>[
  GoldenBook(
    'paperback-novel',
    'parts, full front and back matter, chapters opening on a recto',
    () => bookFixture(
      format: BookFormatPresets.paperback,
      parts: const [
        BookPart(id: 'p1', title: 'Part One', startsAtChapterId: 'ch-1'),
        BookPart(id: 'p2', title: '', startsAtChapterId: 'ch-3'),
      ],
    ),
  ),
  GoldenBook(
    'pod-long',
    'the print-on-demand gutter, which changes the measure that changes it',
    () => bookFixture(format: BookFormatPresets.printOnDemand),
  ),
  GoldenBook(
    'large-print',
    'a different trim and type scale',
    () => bookFixture(format: BookFormatPresets.largePrint),
  ),
  GoldenBook(
    'ebook-fixed',
    'unmirrored margins and no blank versos',
    () => bookFixture(format: BookFormatPresets.ebook),
  ),
  GoldenBook(
    'bare',
    'no front matter, no back matter, no author',
    () => BookProject(
      projectId: 'project-book',
      frontMatter: const [],
      backMatter: const [],
      format: BookFormatPresets.paperback,
    ),
  ),
];

const goldenDirectory = 'test/fixtures/books';

String goldenPath(String name) => '$goldenDirectory/$name.golden';

/// Lays a fixture out and renders its digest. Shared with the update script.
String renderGolden(GoldenBook book, BookFontAssets assets) {
  final project = book.build();
  final document = const BookDocumentBuilder().build(
    manuscript: book.manuscript(),
    book: project,
    profileAuthorName: project.frontMatter.isEmpty ? '' : 'Kali Vale',
  );
  return bookDigest(
    BookLayoutEngine(PdfBookFontMetrics(assets))
        .layout(document, project.format),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookFontAssets assets;

  setUpAll(() async {
    BookFontAssets.resetCache();
    assets = await BookFontAssets.load();
  });

  group('the fixture set', () {
    test('every pinned book has a file, and every file a pinned book', () {
      final onDisk = Directory(goldenDirectory)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.golden'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.golden', ''))
          .toSet();

      expect(onDisk, goldenBooks.map((b) => b.name).toSet(),
          reason: 'a fixture with no book, or a book with no fixture, means '
              'something is going unchecked');
    });

    test('names are unique and each says what it is for', () {
      final names = goldenBooks.map((b) => b.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final book in goldenBooks) {
        expect(book.covers.trim(), isNotEmpty,
            reason: '${book.name} does not say why it exists');
      }
    });

    test('every fixture declares the digest version it was written at', () {
      for (final book in goldenBooks) {
        final text = File(goldenPath(book.name)).readAsStringSync();
        expect(text, startsWith('# bookDigestVersion: $bookDigestVersion'),
            reason: '${book.name} was written by an older digest format; '
                'regenerate it');
      }
    });
  });

  group('representative books lay out the same way they did', () {
    for (final book in goldenBooks) {
      test('${book.name} — ${book.covers}', () {
        final file = File(goldenPath(book.name));
        expect(file.existsSync(), isTrue,
            reason: 'missing ${file.path}; run tool/update-book-goldens.sh');

        expect(renderGolden(book, assets), file.readAsStringSync(),
            reason: 'the layout of ${book.name} changed. Read the diff: if the '
                'change was intended, regenerate with '
                'tool/update-book-goldens.sh');
      });
    }
  });

  test('laying the same book out twice gives the same digest', () {
    // The fixtures are worthless if the engine is not deterministic to begin
    // with; this proves a failure above is a real change and not noise.
    for (final book in goldenBooks) {
      expect(renderGolden(book, assets), renderGolden(book, assets));
    }
  });
}
