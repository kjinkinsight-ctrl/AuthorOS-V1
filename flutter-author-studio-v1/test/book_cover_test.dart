import 'dart:io';
import 'dart:typed_data';

import 'package:author_studio_v1/book/book_cover.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/book_studio_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sniffing the type', () {
    test('recognises PNG and JPEG from their magic bytes, not a filename', () {
      expect(BookCover.sniffMediaType(testPng(8, 8)), 'image/png');
      expect(
        BookCover.sniffMediaType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
    });

    test('refuses anything else', () {
      expect(BookCover.sniffMediaType(Uint8List.fromList('GIF89a'.codeUnits)),
          isNull);
      expect(BookCover.sniffMediaType(Uint8List.fromList([1, 2, 3])), isNull);
      expect(BookCover.sniffMediaType(Uint8List(0)), isNull);
    });
  });

  group('import', () {
    test('accepts a real image and reads its dimensions', () async {
      final result = await BookCover.fromBytes(testPng(420, 640));

      expect(result.isAccepted, isTrue, reason: result.message);
      expect(result.cover!.mediaType, 'image/png');
      expect(result.cover!.width, 420);
      expect(result.cover!.height, 640);
      expect(result.cover!.fileName, 'cover.png');
    });

    test('refuses an empty file', () async {
      final result = await BookCover.fromBytes(Uint8List(0));
      expect(result.isAccepted, isFalse);
      expect(result.rejection, BookCoverRejection.empty);
    });

    test('refuses a format no reading system understands', () async {
      final result =
          await BookCover.fromBytes(Uint8List.fromList('GIF89a....'.codeUnits));
      expect(result.rejection, BookCoverRejection.unsupportedType);
      expect(result.message, contains('JPEG'));
    });

    test('refuses a file that only claims to be an image', () async {
      // A JPEG magic number in front of nothing decodable.
      final liar = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 0, 0, 0, 0]);
      final result = await BookCover.fromBytes(liar);
      expect(result.rejection, BookCoverRejection.notAnImage);
    });

    test('refuses an image too small to look right on a screen', () async {
      final result = await BookCover.fromBytes(testPng(120, 180));
      expect(result.rejection, BookCoverRejection.tooSmall);
    });

    test('refuses a file above the size cap', () async {
      final huge = Uint8List(BookCover.maxBytes + 1)
        ..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      final result = await BookCover.fromBytes(huge);
      expect(result.rejection, BookCoverRejection.tooLarge);
    });

    test('nothing throws — a bad file is an answer, not an error', () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([0]),
        Uint8List.fromList('not an image at all'.codeUnits),
      ]) {
        final result = await BookCover.fromBytes(bytes);
        expect(result.isAccepted, isFalse);
        expect(result.message, isNotNull);
      }
    });
  });

  group('storage', () {
    late AuthorOsDatabase database;
    late BookCoverStore store;

    setUp(() {
      database = AuthorOsDatabase(NativeDatabase.memory());
      store = BookCoverStore(database: database);
    });

    tearDown(() => database.close());

    test('round-trips the bytes exactly', () async {
      final imported = await BookCover.fromBytes(testPng(420, 640));
      await store.save('project-book', imported.cover!,
          timestamp: DateTime.utc(2026));

      final loaded = await store.load('project-book');
      expect(loaded, isNotNull);
      expect(loaded!.bytes, orderedEquals(imported.cover!.bytes),
          reason: 'the author\'s own file is stored, never re-encoded');
      expect(loaded.mediaType, 'image/png');
      expect(loaded.width, 420);
      expect(loaded.height, 640);
    });

    test('a project with no cover simply has none', () async {
      expect(await store.load('never-set'), isNull);
    });

    test('replacing a cover overwrites rather than accumulates', () async {
      final first = await BookCover.fromBytes(testPng(420, 640));
      final second = await BookCover.fromBytes(testPng(500, 700));
      await store.save('project-book', first.cover!);
      await store.save('project-book', second.cover!);

      final loaded = await store.load('project-book');
      expect(loaded!.width, 500);

      final rows = await database.select(database.bookAssetRows).get();
      expect(rows, hasLength(1));
    });

    test('removing leaves the project without one', () async {
      final imported = await BookCover.fromBytes(testPng(420, 640));
      await store.save('project-book', imported.cover!);
      await store.remove('project-book');
      expect(await store.load('project-book'), isNull);
    });

    test('two projects keep their own covers', () async {
      final a = await BookCover.fromBytes(testPng(420, 640));
      final b = await BookCover.fromBytes(testPng(500, 700));
      await store.save('project-a', a.cover!);
      await store.save('project-b', b.cover!);

      expect((await store.load('project-a'))!.width, 420);
      expect((await store.load('project-b'))!.width, 500);
    });
  });

  group('migration', () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() {
      temporaryDirectory =
          Directory.systemTemp.createTempSync('authoros_book_asset');
      databaseFile = File('${temporaryDirectory.path}/authoros.sqlite');
    });

    tearDown(() {
      if (temporaryDirectory.existsSync()) {
        temporaryDirectory.deleteSync(recursive: true);
      }
    });

    test('a version 9 file gains the asset table and keeps its data', () async {
      // A database as it stood before covers existed. A fresh drift database
      // creates every declared table whatever its version, so the table is
      // dropped to give the file the shape a real version 9 install has.
      final versionNine = AuthorOsDatabase(
        NativeDatabase(databaseFile),
        schemaVersion: 9,
      );
      await versionNine.customStatement('DROP TABLE book_asset_rows');
      await versionNine
          .customStatement("INSERT INTO connected_entities (id, kind, scope_id) "
              "VALUES ('kept', 'record', 'project-book')");
      await versionNine.close();

      // Reopening at the current version runs the upgrade.
      final current = AuthorOsDatabase(NativeDatabase(databaseFile));
      addTearDown(current.close);

      final tables = await current
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        contains('book_asset_rows'),
        reason: 'the 9 to 10 step must create the table',
      );

      final survived = await current
          .customSelect('SELECT id FROM connected_entities')
          .get();
      expect(survived.map((row) => row.read<String>('id')), ['kept'],
          reason: 'an additive migration must not disturb existing data');

      // And the new table is genuinely usable afterwards.
      final store = BookCoverStore(database: current);
      final imported = await BookCover.fromBytes(testPng(420, 640));
      await store.save('project-book', imported.cover!);
      expect((await store.load('project-book'))!.width, 420);
    });

    test('the schema version was bumped alongside the table', () {
      expect(AuthorOsDatabase.currentSchemaVersion, 10);
    });
  });
}
