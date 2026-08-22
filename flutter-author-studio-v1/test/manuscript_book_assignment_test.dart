import 'package:author_studio_v1/core/book_scope.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chapters belong to books, and a scene inherits its chapter's book.
///
/// Book membership is stored on the chapter and projected into its manuscript
/// node, mirroring the `chapterId` a scene node already carries. It is
/// deliberately not an edge: manuscript nodes are upsert-only and never
/// deleted, so an edge here would outlive the chapter it describes.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;
  late ManuscriptService manuscripts;
  late SeriesService series;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
    manuscripts = ManuscriptService(
      projectId: 'project-a',
      repository: repository,
      store: store,
    );
    series = SeriesService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  Future<ManuscriptProjectSummary> seeded() => manuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
          ManuscriptChapterSeed(title: 'Chapter 02', scenes: ['Scene 02']),
        ],
      );

  test('a chapter with no book is valid and reads as unassigned', () async {
    // Every project that existed before books keeps working untouched.
    final manuscript = await seeded();
    for (final chapter in manuscript.chapters) {
      expect(chapter.bookId, isNull);
    }
    expect(
      manuscripts.chaptersForBook(manuscript, null).length,
      manuscript.chapters.length,
    );
  });

  test('a chapter is filed under a book and released again', () async {
    final book = await series.createBook(title: 'Book One');
    var manuscript = await seeded();
    final chapterId = manuscript.chapters.first.id;

    manuscript =
        await manuscripts.assignChapterToBook(manuscript, chapterId, book.id);
    expect(manuscript.chapterById(chapterId)!.bookId, book.id);
    expect(
      manuscripts.chaptersForBook(manuscript, book.id).map((each) => each.id),
      [chapterId],
    );

    manuscript =
        await manuscripts.assignChapterToBook(manuscript, chapterId, null);
    expect(manuscript.chapterById(chapterId)!.bookId, isNull);
    expect(manuscripts.chaptersForBook(manuscript, book.id), isEmpty);
  });

  test('a scene inherits its chapter\'s book', () async {
    // Stored once, on the chapter, so the two can never disagree.
    final book = await series.createBook(title: 'Book One');
    var manuscript = await seeded();
    final chapter = manuscript.chapters.first;
    final sceneId = chapter.scenes.first.id;

    manuscript =
        await manuscripts.assignChapterToBook(manuscript, chapter.id, book.id);

    expect(manuscripts.bookForNode(manuscript, sceneId), book.id);
    expect(manuscripts.bookForNode(manuscript, chapter.id), book.id);
    expect(
      manuscripts.bookForNode(manuscript, manuscript.chapters[1].scenes.first.id),
      isNull,
    );
  });

  test('the chapter node carries its book, and a scene resolves through it',
      () async {
    final book = await series.createBook(title: 'Book One');
    var manuscript = await seeded();
    final chapter = manuscript.chapters.first;
    manuscript =
        await manuscripts.assignChapterToBook(manuscript, chapter.id, book.id);

    final nodes = await repository.manuscriptNodesByProject('project-a');
    final byId = {for (final node in nodes) node.id: node};

    final chapterNode = byId[chapter.id]!;
    expect(chapterNode.extensionData[BookScope.chapterBookKey], book.id);

    final sceneNode = byId[chapter.scenes.first.id]!;
    expect(sceneNode.extensionData[BookScope.chapterBookKey], isNull);
    expect(BookScope.bookOfNode(sceneNode, byId), book.id);
  });

  test('reading manuscript nodes never seeds a manuscript', () async {
    // ManuscriptStore.loadStudio creates a starter manuscript on a project
    // nobody has opened. Anything that only wants to look at structure reads
    // the table instead, so a read can never invent a chapter.
    final nodes = await repository.manuscriptNodesByProject('untouched');
    expect(nodes, isEmpty);
  });

  group('persistence', () {
    test('a book assignment survives a save and reload', () async {
      final book = await series.createBook(title: 'Book One');
      var manuscript = await seeded();
      final chapterId = manuscript.chapters.first.id;
      manuscript =
          await manuscripts.assignChapterToBook(manuscript, chapterId, book.id);

      final reloaded = await manuscripts.load(manuscriptTitle: 'Endovier');
      expect(reloaded.chapterById(chapterId)!.bookId, book.id);
    });

    test('a manuscript saved before books existed still loads', () async {
      // The stored blob simply has no `bookId` key. Absent must read as null,
      // not as an error and not as an empty string.
      final manuscript = await seeded();
      final json = manuscript.chapters.first.toJson();
      expect(json.containsKey('bookId'), isFalse);

      final restored = ManuscriptChapter.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(restored.bookId, isNull);
    });

    test('a blank stored value reads as unassigned, not as a book', () async {
      final manuscript = await seeded();
      final json = Map<String, dynamic>.from(
        manuscript.chapters.first.toJson(),
      )..['bookId'] = '   ';
      expect(ManuscriptChapter.fromJson(json).bookId, isNull);
    });

    test('an assigned chapter round-trips through its own JSON', () async {
      var manuscript = await seeded();
      final book = await series.createBook(title: 'Book One');
      manuscript = await manuscripts.assignChapterToBook(
        manuscript,
        manuscript.chapters.first.id,
        book.id,
      );
      final json = manuscript.chapters.first.toJson();
      expect(json['bookId'], book.id);
      expect(
        ManuscriptChapter.fromJson(Map<String, dynamic>.from(json)).bookId,
        book.id,
      );
    });
  });

  test('assigning an unknown chapter is refused', () async {
    final manuscript = await seeded();
    final book = await series.createBook(title: 'Book One');
    expect(
      () => manuscripts.assignChapterToBook(manuscript, 'nope', book.id),
      throwsStateError,
    );
  });
}
