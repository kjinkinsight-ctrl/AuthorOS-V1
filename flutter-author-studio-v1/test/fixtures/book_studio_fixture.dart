/// Fixtures for Book Studio tests.
///
/// The prose is deliberately made of fixed-length words. Paired with
/// `FakeBookFontMetrics`, that makes every line break arithmetic rather than
/// guesswork, so a layout assertion can say exactly which words land on which
/// line.
library;

import 'dart:typed_data';

import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/manuscript_store.dart';

final DateTime fixtureTimestamp = DateTime.utc(2026, 1, 1);

ManuscriptScene scene({
  required String id,
  required String chapterId,
  required String title,
  required int order,
  required String content,
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: order,
      content: content,
      status: ManuscriptNodeStatus.complete,
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
    );

ManuscriptChapter chapter({
  required String id,
  required String title,
  required int order,
  required List<ManuscriptScene> scenes,
}) =>
    ManuscriptChapter(
      id: id,
      title: title,
      order: order,
      status: ManuscriptNodeStatus.complete,
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      scenes: scenes,
    );

/// Builds a paragraph of [words] words, each four characters long.
///
/// With `FakeBookFontMetrics(perCharacterEm: 0.5)` at 10 pt, a four-letter word
/// is 20 pt wide and a space is 5 pt, so N words occupy `25N - 5` points.
String words(int count, {String word = 'abcd'}) =>
    List.filled(count, word).join(' ');

/// A three-chapter manuscript with two scenes in the middle chapter.
ManuscriptProjectSummary manuscriptFixture() => ManuscriptProjectSummary(
      projectId: 'project-book',
      manuscriptTitle: 'The Widow Knife',
      currentChapterId: 'ch-1',
      currentSceneId: 'sc-1',
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      version: 1,
      chapters: [
        chapter(
          id: 'ch-1',
          title: 'The Arrival',
          order: 1,
          scenes: [
            scene(
              id: 'sc-1',
              chapterId: 'ch-1',
              title: 'Opening',
              order: 1,
              content: words(40),
            ),
          ],
        ),
        chapter(
          id: 'ch-2',
          title: 'The Blood Price',
          order: 2,
          scenes: [
            scene(
              id: 'sc-2',
              chapterId: 'ch-2',
              title: 'Before',
              order: 1,
              content: words(30),
            ),
            scene(
              id: 'sc-3',
              chapterId: 'ch-2',
              title: 'After',
              order: 2,
              content: words(30),
            ),
          ],
        ),
        chapter(
          id: 'ch-3',
          title: 'Endovier',
          order: 3,
          scenes: [
            scene(
              id: 'sc-4',
              chapterId: 'ch-3',
              title: 'Closing',
              order: 1,
              content: words(50),
            ),
          ],
        ),
      ],
    );

/// A book with a title page, a copyright page and a contents page.
BookProject bookFixture({
  BookFormat? format,
  List<BookPart> parts = const [],
}) =>
    BookProject(
      projectId: 'project-book',
      authorOverride: 'Kali Vale',
      copyrightYear: '2026',
      copyrightHolder: 'Kali Vale',
      isbn: '978-1-0000-0000-0',
      publisher: 'Ink & Insight',
      parts: parts,
      format: format ?? BookFormatPresets.paperback,
      frontMatter: BookProject.defaultFrontMatter(),
      backMatter: BookProject.defaultBackMatter(),
    );

/// A deliberately simple format whose geometry divides evenly, so expected line
/// and page counts can be worked out by hand.
///
/// The text block is 200 pt wide and 200 pt tall, the body is 10 pt on 20 pt
/// leading, so exactly ten lines fit on a page.
BookFormat arithmeticFormat({
  ChapterStartRule startRule = ChapterStartRule.anyPage,
  BookAlignment alignment = BookAlignment.justified,
  int minLinesAtPageBottom = 2,
  int minLinesAtPageTop = 2,
  double firstLineIndentPt = 0,
}) =>
    BookFormat(
      id: 'test-arithmetic',
      label: 'Arithmetic',
      trim: const TrimSize('test', 'Test', 300, 300),
      margins: const BookMargins(
        topPt: 50,
        bottomPt: 50,
        outsidePt: 30,
        insidePt: 70,
      ),
      typography: BookTypography(
        bodySizePt: 10,
        leadingMultiple: 2.0,
        firstLineIndentPt: firstLineIndentPt,
        alignment: alignment,
      ),
      chapter: ChapterStyle(
        startRule: startRule,
        sinkFraction: 0,
        numberStyle: ChapterNumberStyle.none,
        titleSizePt: 10,
        titleGapPt: 0,
        bodyGapPt: 0,
      ),
      runningHead: const RunningHead(
        verso: RunningHeadContent.none,
        recto: RunningHeadContent.none,
      ),
      numbering: const PageNumbering(position: PageNumberPosition.none),
      breaks: BookBreakRules(
        minLinesAtPageBottom: minLinesAtPageBottom,
        minLinesAtPageTop: minLinesAtPageTop,
      ),
    );

/// A single-chapter manuscript long enough to fill several pages at any preset.
///
/// Used where a test needs body pages that are genuinely full; the three-chapter
/// fixture above is deliberately short and never fills one.
ManuscriptProjectSummary longManuscriptFixture({int paragraphs = 30}) =>
    ManuscriptProjectSummary(
      projectId: 'project-book',
      manuscriptTitle: 'The Long Road',
      currentChapterId: 'ch-1',
      currentSceneId: 'sc-1',
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      version: 1,
      chapters: [
        chapter(
          id: 'ch-1',
          title: 'The Only Chapter',
          order: 1,
          scenes: [
            scene(
              id: 'sc-1',
              chapterId: 'ch-1',
              title: 'Opening',
              order: 1,
              content: List.generate(paragraphs, (_) => words(60)).join('\n'),
            ),
          ],
        ),
      ],
    );

/// A real PNG the image decoder will accept.
///
/// Built rather than checked in so the test carries its own fixture: a solid
/// block of the requested size, encoded by hand.
Uint8List testPng(int width, int height) {
  final chunks = <int>[];

  void beInt(List<int> into, int value) => into.addAll([
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);

  int crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  void chunk(String type, List<int> data) {
    beInt(chunks, data.length);
    final body = <int>[...type.codeUnits, ...data];
    chunks.addAll(body);
    beInt(chunks, crc32(body));
  }

  chunks.addAll([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final header = <int>[];
  beInt(header, width);
  beInt(header, height);
  header.addAll([8, 2, 0, 0, 0]); // 8-bit truecolour
  chunk('IHDR', header);

  // One filter byte plus three bytes a pixel, per row.
  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0);
    for (var x = 0; x < width; x++) {
      raw.addAll([0x2A, 0x18, 0x30]);
    }
  }
  chunk('IDAT', _testZlibStore(raw));
  chunk('IEND', const []);

  return Uint8List.fromList(chunks);
}

/// Wraps [data] in a zlib stream using stored (uncompressed) deflate blocks,
/// so the fixture needs no compression library.
List<int> _testZlibStore(List<int> data) {
  final out = <int>[0x78, 0x01];
  var offset = 0;
  while (offset < data.length) {
    final take = (data.length - offset).clamp(0, 65535);
    final last = offset + take >= data.length;
    out
      ..add(last ? 1 : 0)
      ..add(take & 0xFF)
      ..add((take >> 8) & 0xFF)
      ..add((~take) & 0xFF)
      ..add(((~take) >> 8) & 0xFF)
      ..addAll(data.sublist(offset, offset + take));
    offset += take;
  }
  var a = 1, b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  final adler = (b << 16) | a;
  out.addAll([
    (adler >> 24) & 0xFF,
    (adler >> 16) & 0xFF,
    (adler >> 8) & 0xFF,
    adler & 0xFF,
  ]);
  return out;
}


/// A manuscript with something for every editing rule to find.
///
/// Deliberately the kind of mess a real draft accumulates: an indent typed by
/// hand, a double space, a space before a comma, straight quotes and a doubled
/// word.
ManuscriptProjectSummary messyManuscriptFixture() => ManuscriptProjectSummary(
      projectId: 'project-book',
      manuscriptTitle: 'The Widow Knife',
      currentChapterId: 'ch-1',
      currentSceneId: 'sc-1',
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      version: 1,
      chapters: [
        chapter(id: 'ch-1', title: 'The Arrival', order: 1, scenes: [
          scene(
            id: 'sc-1',
            chapterId: 'ch-1',
            title: 'Opening',
            order: 1,
            content: '\tThe knife was  old , and she said "go" twice.\n'
                'She went to to the door and waited.',
          ),
        ]),
      ],
    );

/// A manuscript whose prose has nothing for any rule to find.
///
/// The ordinary fixture repeats one word, which the repeated-word rule quite
/// correctly objects to.
ManuscriptProjectSummary cleanManuscriptFixture() => ManuscriptProjectSummary(
      projectId: 'project-book',
      manuscriptTitle: 'The Widow Knife',
      currentChapterId: 'ch-1',
      currentSceneId: 'sc-1',
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
      version: 1,
      chapters: [
        chapter(id: 'ch-1', title: 'The Arrival', order: 1, scenes: [
          scene(
            id: 'sc-1',
            chapterId: 'ch-1',
            title: 'Opening',
            order: 1,
            content: 'The knife was old before the house was old.\n'
                'She turned it against the light of the window.',
          ),
        ]),
      ],
    );
