import 'package:author_studio_v1/book/book_cover.dart';
import 'package:author_studio_v1/book/book_document.dart';
import 'package:author_studio_v1/book/book_fonts.dart';
import 'package:author_studio_v1/book/book_layout.dart';
import 'package:author_studio_v1/book/book_pdf_renderer.dart';
import 'package:author_studio_v1/book/book_snapshot.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthorOsDatabase database;
  late BookSnapshotStore store;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    store = BookSnapshotStore(database: database);
  });

  tearDown(() => database.close());

  ManuscriptProjectSummary edited(String extra) {
    final base = manuscriptFixture();
    final first = base.chapters.first;
    return ManuscriptProjectSummary(
      projectId: base.projectId,
      manuscriptTitle: base.manuscriptTitle,
      currentChapterId: base.currentChapterId,
      currentSceneId: base.currentSceneId,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      version: base.version,
      chapters: [
        chapter(
          id: first.id,
          title: first.title,
          order: first.order,
          scenes: [
            scene(
              id: first.scenes.first.id,
              chapterId: first.id,
              title: first.scenes.first.title,
              order: first.scenes.first.order,
              content: '${first.scenes.first.content} $extra',
            ),
          ],
        ),
        ...base.chapters.skip(1),
      ],
    );
  }

  group('capturing', () {
    test('a manuscript round-trips through the store intact', () async {
      final manuscript = manuscriptFixture();
      final hash = await store.capture('p1', manuscript);
      final loaded = await store.load('p1', hash);

      expect(loaded, isNotNull);
      expect(loaded!.manuscript.toJson(), manuscript.toJson(),
          reason: 'a snapshot that comes back different cannot reproduce an '
              'export');
    });

    test('the same manuscript is stored once, not once per export', () async {
      final manuscript = manuscriptFixture();
      final a = await store.capture('p1', manuscript);
      final b = await store.capture('p1', manuscript);
      final c = await store.capture('p1', manuscript);

      expect({a, b, c}, hasLength(1));
      expect(await store.hashes('p1'), hasLength(1),
          reason: 'exporting one book to three formats stores one snapshot');
    });

    test('a changed manuscript gets its own snapshot', () async {
      final first = await store.capture('p1', manuscriptFixture());
      final second = await store.capture('p1', edited('and then more'));

      expect(first, isNot(second));
      expect(await store.hashes('p1'), hasLength(2));
    });

    test('the hash is stable across runs, not a fresh id each time', () {
      expect(BookSnapshot.hashOf(manuscriptFixture()),
          BookSnapshot.hashOf(manuscriptFixture()));
      expect(BookSnapshot.hashOf(manuscriptFixture()), hasLength(16));
    });

    test('projects do not see each other’s snapshots', () async {
      await store.capture('p1', manuscriptFixture());
      expect(await store.hashes('p2'), isEmpty);
    });

    test('an unknown hash is absent rather than an error', () async {
      expect(await store.load('p1', 'deadbeefdeadbeef'), isNull);
    });
  });

  group('pruning', () {
    test('drops a snapshot no export refers to any more', () async {
      final kept = await store.capture('p1', manuscriptFixture());
      await store.capture('p1', edited('one'));
      await store.capture('p1', edited('two'));

      final removed = await store.prune('p1', {kept});

      expect(removed, 2);
      expect(await store.hashes('p1'), [kept]);
      expect(await store.load('p1', kept), isNotNull);
    });

    test('keeps at most the retained count, newest first', () async {
      final hashes = <String>[];
      for (var i = 0; i < BookSnapshotStore.retained + 3; i++) {
        hashes.add(await store.capture('p1', edited('draft $i'),
            timestamp: DateTime.utc(2026, 1, 1 + i)));
      }

      await store.prune('p1', hashes.toSet());
      final left = await store.hashes('p1');

      expect(left, hasLength(BookSnapshotStore.retained));
      expect(left.first, hashes.last, reason: 'the newest is kept');
      expect(left, isNot(contains(hashes.first)),
          reason: 'the oldest is evicted');
    });

    test('re-capturing an old manuscript saves it from eviction', () async {
      final oldest = await store.capture('p1', manuscriptFixture(),
          timestamp: DateTime.utc(2026, 1, 1));
      for (var i = 0; i < BookSnapshotStore.retained; i++) {
        await store.capture('p1', edited('draft $i'),
            timestamp: DateTime.utc(2026, 2, 1 + i));
      }

      // Exporting that older draft again makes it recent, which is what the
      // timestamp refresh on a duplicate capture is for.
      await store.capture('p1', manuscriptFixture(),
          timestamp: DateTime.utc(2026, 3, 1));
      await store.prune('p1', (await store.hashes('p1')).toSet());

      expect(await store.hashes('p1'), contains(oldest));
    });
  });

  group('living alongside the cover', () {
    test('a snapshot never disturbs the cover, and clearing leaves it', () async {
      final covers = BookCoverStore(database: database);
      await covers.save(
        'p1',
        BookCover(
          bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00]),
          mediaType: 'image/jpeg',
          updatedAt: DateTime.utc(2026),
        ),
      );

      await store.capture('p1', manuscriptFixture());
      expect(await covers.load('p1'), isNotNull);

      await store.clear('p1');
      expect(await store.hashes('p1'), isEmpty);
      expect(await covers.load('p1'), isNotNull,
          reason: 'clearing snapshots must not take the cover with it');
    });
  });

  group('export history', () {
    test('round-trips through the book settings', () {
      final project = BookProject(
        projectId: 'p1',
        exportHistory: [
          ExportRecord(
            exportedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
            format: 'printPdf',
            variant: '',
            snapshotHash: 'abc123abc123abc1',
            manuscriptVersion: 4,
            pageCount: 212,
            wordCount: 64000,
          ),
        ],
      );

      final decoded = BookProject.fromJson(
          Map<String, dynamic>.from(project.toJson()));

      expect(decoded.exportHistory, hasLength(1));
      final record = decoded.exportHistory.single;
      expect(record.format, 'printPdf');
      expect(record.snapshotHash, 'abc123abc123abc1');
      expect(record.pageCount, 212);
      expect(record.exportedAt, DateTime.utc(2026, 3, 4, 5, 6, 7));
    });

    test('settings saved before this feature existed still load', () {
      // No `exportHistory` key at all, as every stored blob has today.
      final decoded = BookProject.fromJson({'projectId': 'p1'});
      expect(decoded.exportHistory, isEmpty);
    });
  });
  group('the gate this exists for', () {
    // M7's exit gate asks that "exports are reproducible from a frozen
    // manuscript snapshot". Every other test here checks a piece of that. This
    // one checks the sentence.
    test('an export is reproducible from its snapshot after more writing',
        () async {
      final assets = await BookFontAssets.load();
      final project = bookFixture();

      Future<List<int>> renderFrom(ManuscriptProjectSummary m) async {
        final document = const BookDocumentBuilder()
            .build(manuscript: m, book: project, profileAuthorName: 'Kali Vale');
        final book = BookLayoutEngine(PdfBookFontMetrics(assets))
            .layout(document, project.format);
        return const BookPdfRenderer()
            .render(book, assets, modified: m.updatedAt);
      }

      // Monday: export the book, freezing what it said at the time.
      final monday = manuscriptFixture();
      final original = await renderFrom(monday);
      final hash = await store.capture('p1', monday);

      // Tuesday: the author keeps writing, so the live manuscript has moved on.
      expect(await renderFrom(longManuscriptFixture(paragraphs: 40)),
          isNot(orderedEquals(original)),
          reason: 'the fixture must actually differ for this to prove '
              'anything');

      // Next month: produce Monday's file again from what was frozen.
      final snapshot = await store.load('p1', hash);
      expect(snapshot, isNotNull);

      expect(await renderFrom(snapshot!.manuscript), orderedEquals(original),
          reason: 'byte for byte, or the snapshot cannot reproduce anything');
    });
  });

}
