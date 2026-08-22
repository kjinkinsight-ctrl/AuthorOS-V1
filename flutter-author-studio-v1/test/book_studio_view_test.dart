import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book_studio_view.dart';
import 'package:author_studio_v1/book/book_preview_painter.dart';
import 'package:author_studio_v1/book/book_cover.dart';
import 'package:author_studio_v1/book/book_snapshot.dart';
import 'package:author_studio_v1/book/book_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/book_studio_fixture.dart';

class _MemoryBookFileSaver implements BookFileSaver {
  String? name;
  Uint8List? bytes;
  int calls = 0;

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
    required BookExportFormat format,
  }) async {
    calls += 1;
    name = suggestedName;
    this.bytes = bytes;
    return 'C:/Exports/$suggestedName';
  }
}

StarterProject _project() => const StarterProject(
      id: 'project-book',
      title: 'The Widow Knife',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: [],
      chapters: [],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Opening',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // A manuscript the studio can lay out, and no book settings yet.
    SharedPreferences.setMockInitialValues({
      'author_studio.manuscript_studio.project-book':
          jsonEncode(manuscriptFixture().toJson()),
    });
  });

  late AuthorOsDatabase database;

  setUp(() => database = AuthorOsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  /// Seeds a manuscript whose prose has something for the rules to find.
  void seedManuscript(ManuscriptProjectSummary manuscript) {
    SharedPreferences.setMockInitialValues({
      'author_studio.manuscript_studio.project-book':
          jsonEncode(manuscript.toJson()),
    });
  }

  Future<void> pumpStudio(
    WidgetTester tester, {
    BookFileSaver? saver,
    Future<Uint8List?> Function()? coverPicker,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BookStudioView(
              project: _project(),
              fileSaver: saver ?? _MemoryBookFileSaver(),
              coverStore: BookCoverStore(database: database),
              snapshotStore: BookSnapshotStore(database: database),
              coverPicker: coverPicker ?? () async => null,
              database: database,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the structure stage with the book already laid out',
      (tester) async {
    await pumpStudio(tester);

    expect(find.text('The Widow Knife'), findsWidgets);
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('Structure'), findsWidgets);
  });

  testWidgets('every pipeline stage is present and reachable', (tester) async {
    await pumpStudio(tester);

    for (final stage in BookStage.values) {
      expect(find.byKey(Key('book-stage-${stage.name}')), findsOneWidget,
          reason: '${stage.label} is missing from the pipeline');
      expect(stage.isAvailable, isTrue,
          reason: '${stage.label} is still a placeholder');
    }

    // Every stage now navigates somewhere real.
    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();
    expect(find.text('Front matter'), findsNothing);
    expect(find.text('Editing'), findsWidgets);
  });

  testWidgets('the preview paints real pages', (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('book-preview-surface')), findsOneWidget);
    expect(find.byType(BookPageView), findsWidgets);
    expect(find.textContaining('Page 1 of'), findsOneWidget);
  });

  testWidgets('changing the preset repaginates the book', (tester) async {
    await pumpStudio(tester);

    String pageCountText() {
      final finder = find.descendant(
        of: find.byType(BookStudioView),
        matching: find.textContaining(RegExp(r'^\d+$')),
      );
      return (tester.widgetList<Text>(finder).first).data ?? '';
    }

    final before = pageCountText();

    await tester.tap(find.byKey(const Key('book-stage-formatting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-preset-large-print')));
    await tester.pumpAndSettle();

    expect(find.text('Large Print'), findsWidgets);
    expect(pageCountText(), isNot(before),
        reason: 'a different preset must reflow the book, not just relabel it');
  });

  testWidgets('a format tweak is persisted', (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-formatting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-preset-hardcover')));
    await tester.pumpAndSettle();

    final stored = await const BookStore().load('project-book');
    expect(stored.format.id, 'hardcover');
  });

  testWidgets('switching a front-matter section off is persisted',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-section-front-contents')));
    await tester.pumpAndSettle();

    final stored = await const BookStore().load('project-book');
    final contents =
        stored.frontMatter.firstWhere((s) => s.id == 'front-contents');
    expect(contents.included, isFalse);
  });

  testWidgets('exporting reaches the file saver with real PDF bytes',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Exporting now freezes the manuscript into the database, which is
      // real asynchronous work the fake clock does not advance.
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife-print.pdf');
    expect(saver.bytes, isNotNull);
    expect(String.fromCharCodes(saver.bytes!.take(5)), '%PDF-');
  });

  testWidgets('every export target is offered, and all of them are built now',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();

    for (final format in BookExportFormat.values) {
      expect(find.byKey(Key('book-export-${format.name}')), findsOneWidget);
    }
    // Phase 4 was the last of them; nothing is marked as still to come.
    expect(find.text('later'), findsNothing);
  });

  testWidgets('a project with no manuscript still opens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpStudio(tester);

    expect(find.byType(BookStudioView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EPUB can be selected and exports a real package',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-export-epub')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Exporting now freezes the manuscript into the database, which is
      // real asynchronous work the fake clock does not advance.
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife.epub');
    // A zip, and the mimetype right where the specification wants it.
    expect(saver.bytes!.take(2), orderedEquals([0x50, 0x4B]));
    expect(String.fromCharCodes(saver.bytes!.sublist(30, 38)), 'mimetype');
  });

  testWidgets('Word exports a real package, in the flavour that was chosen',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-export-docx')));
    await tester.pumpAndSettle();

    // The flavours only appear once Word is the chosen format: they are a
    // property of that choice, not a sixth format.
    expect(find.byKey(const Key('book-docx-submission')), findsOneWidget);
    expect(find.byKey(const Key('book-docx-typeset')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-docx-typeset')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Exporting now freezes the manuscript into the database, which is
      // real asynchronous work the fake clock does not advance.
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife.docx');
    expect(saver.bytes!.take(2), orderedEquals([0x50, 0x4B]));

    final archive = ZipDecoder().decodeBytes(saver.bytes!);
    expect(archive.find('word/document.xml'), isNotNull);
    // Typeset carries no running header; submission would.
    expect(archive.find('word/header1.xml'), isNull);
  });

  testWidgets('plain text exports the prose the author actually wrote',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-export-txt')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('book-txt-readable')), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-txt-manuscriptOnly')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Exporting now freezes the manuscript into the database, which is
      // real asynchronous work the fake clock does not advance.
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife.txt');

    final text = utf8.decode(saver.bytes!);
    expect(text, contains('abcd'));
    expect(text, isNot(contains('The Arrival')),
        reason: 'prose only carries no headings');
  });

  testWidgets('a reflowable export never promises a page count', (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pages at'), findsOneWidget);

    // Word repaginates on whatever paper it is opened with, so a page count
    // here would simply be untrue.
    await tester.tap(find.byKey(const Key('book-export-docx')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pages at'), findsNothing);
    expect(find.textContaining('repaginates'), findsOneWidget);
  });

  testWidgets('the ebook has its own settings, kept apart from print',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-design')));
    await tester.pumpAndSettle();

    final embedSwitch =
        find.byKey(const Key('book-epub-embed-fonts-switch'));
    await tester.ensureVisible(embedSwitch);
    await tester.pumpAndSettle();
    await tester.tap(embedSwitch);
    await tester.pumpAndSettle();

    final stored = await const BookStore().load('project-book');
    expect(stored.epub.embedFonts, isTrue);
    // The print format must be untouched by an ebook setting.
    expect(stored.format.id, 'paperback');
  });

  testWidgets('preflight reports before the export, and never blocks it',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();

    // The paperback fixture starts chapters on a recto, so it has blank pages
    // to report — the panel should be showing rather than the clean line.
    expect(find.byKey(const Key('book-preflight-panel')), findsOneWidget);
    expect(find.textContaining('You can still export'), findsOneWidget);

    // And the button is live regardless of what preflight said.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });
    expect(saver.calls, 1);
  });

  testWidgets('preflight changes its mind when the target does',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();

    // Matched on the finding's own wording, not on "blank pages" — the
    // print-PDF option's description says that too.
    expect(find.textContaining('Print-on-demand charges'), findsOneWidget);

    // Blank pages and signatures are print questions. A text file has neither,
    // and preflight should stop asking.
    await tester.tap(find.byKey(const Key('book-export-txt')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Print-on-demand charges'), findsNothing);
    expect(find.textContaining('not a multiple of four'), findsNothing,
        reason: 'a text file has no signatures either');
  });

  testWidgets('an export is remembered, with the manuscript it came from',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    final stored = await const BookStore().load('project-book');
    expect(stored.exportHistory, hasLength(1));
    final record = stored.exportHistory.single;
    expect(record.format, 'printPdf');
    expect(record.snapshotHash, hasLength(16));
    expect(record.pageCount, greaterThan(0));

    // And the manuscript behind it is actually recoverable, which is the whole
    // point of recording the hash.
    final snapshot = await BookSnapshotStore(database: database)
        .load('project-book', record.snapshotHash);
    expect(snapshot, isNotNull);
    expect(snapshot!.manuscript.chapters, isNotEmpty);
  });

  testWidgets('exporting twice from one manuscript keeps one snapshot',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    for (final format in const ['printPdf', 'epub']) {
      await tester.tap(find.byKey(Key('book-export-$format')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('book-export-button')));
        await tester.pumpAndSettle();
      });
    }

    final stored = await const BookStore().load('project-book');
    expect(stored.exportHistory, hasLength(2), reason: 'two exports happened');
    expect(
        await BookSnapshotStore(database: database).hashes('project-book'),
        hasLength(1),
        reason: 'but from one manuscript, so one snapshot');
  });

  testWidgets('an earlier export can be made again, byte for byte',
      (tester) async {
    final saver = _MemoryBookFileSaver();
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });
    final original = Uint8List.fromList(saver.bytes!);

    // The author changes the whole design afterwards.
    await tester.tap(find.byKey(const Key('book-stage-formatting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-preset-hardcover')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });
    expect(saver.bytes, isNot(orderedEquals(original)),
        reason: 'the fixture must actually differ for this to prove anything');

    // Now reach back to the first one. The oldest row is the last.
    final rows = find.byKey(const Key('book-history-1'));
    expect(rows, findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.descendant(
          of: rows, matching: find.text('Export again')));
      await tester.pumpAndSettle();
    });

    expect(saver.bytes, orderedEquals(original),
        reason: 'exporting an earlier draft again must produce that file, not '
            'the old words in the new design');
  });

  testWidgets('the history says what each file was and where it came from',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Once you export'), findsOneWidget,
        reason: 'an empty history should explain what will appear here');

    await tester.tap(find.byKey(const Key('book-export-docx')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-docx-typeset')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    final row = find.byKey(const Key('book-history-0'));
    expect(row, findsOneWidget);
    expect(
        find.descendant(of: row, matching: find.textContaining('Word (DOCX)')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('typeset')),
        findsOneWidget,
        reason: 'the flavour is part of what that file was');
    expect(find.descendant(of: row, matching: find.textContaining('words')),
        findsOneWidget);
  });

  testWidgets('a row whose draft has been evicted says so instead of failing',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    // Evict it behind the studio's back, as retention eventually would.
    await tester.runAsync(() async {
      await BookSnapshotStore(database: database).clear('project-book');
    });

    // Re-open so the studio reads what is actually there. Pumping a different
    // tree first forces a real remount — Flutter reuses the State of a
    // same-type widget in the same position, so `_load` would not run again.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await pumpStudio(tester);
    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('book-history-0'));
    expect(row, findsOneWidget, reason: 'the row is still true history');
    expect(
        find.descendant(
            of: row, matching: find.textContaining('no longer stored')),
        findsOneWidget);

    final button = tester.widget<TextButton>(find.descendant(
        of: row, matching: find.byType(TextButton)));
    expect(button.onPressed, isNull,
        reason: 'a button that cannot work must not look like it can');
  });

  testWidgets('a look can be saved as a template and put on again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-formatting')));
    await tester.pumpAndSettle();

    // Change the look away from the default first, so applying it later is
    // provably doing something.
    await tester.tap(find.byKey(const Key('book-preset-large-print')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('book-save-template-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('book-template-name-field')), 'House Style');
    await tester.tap(find.byKey(const Key('book-template-name-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('book-template-house-style')), findsOneWidget);

    // Move away from it, then put the template back on.
    await tester.tap(find.byKey(const Key('book-preset-paperback')));
    await tester.pumpAndSettle();
    expect((await const BookStore().load('project-book')).format.id,
        BookFormatPresets.paperback.id);

    await tester.tap(find.byKey(const Key('book-template-house-style')));
    await tester.pumpAndSettle();

    final restored = await const BookStore().load('project-book');
    expect(restored.format.id, BookFormatPresets.largePrint.id);
    // The book is still this book.
    expect(restored.projectId, 'project-book');
  });

  testWidgets('the italics convention says what it would do before it does it',
      (tester) async {
    seedManuscript(manuscriptFixtureWithProse(
        'She read _The Kestrel_ twice, then _left_.'));
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-design')));
    await tester.pumpAndSettle();

    // Off by default, and it counts what switching it on would change rather
    // than asking the author to switch it on and go looking.
    expect(find.textContaining('would set 2 phrases in italic'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('book-emphasis-switch')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Set in italic in 2 places'), findsOneWidget);
    expect((await const BookStore().load('project-book'))
        .format.typography.inlineMarkup, BookInlineMarkup.underscoreItalic);
  });

  testWidgets('switching italics on reaches the exported book', (tester) async {
    final saver = _MemoryBookFileSaver();
    seedManuscript(
        manuscriptFixtureWithProse('She read _The Kestrel_ twice.'));
    await pumpStudio(tester, saver: saver);

    await tester.tap(find.byKey(const Key('book-stage-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-emphasis-switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-export-txt')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-export-button')));
      await tester.pumpAndSettle();
    });

    // Plain text keeps the author's own notation, because it is the only
    // emphasis a text file has.
    expect(utf8.decode(saver.bytes!), contains('_The Kestrel_'));
  });

  testWidgets('turning it off leaves the writing exactly as it was',
      (tester) async {
    const prose = 'She read _The Kestrel_ twice.';
    seedManuscript(manuscriptFixtureWithProse(prose));
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-emphasis-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-emphasis-switch')));
    await tester.pumpAndSettle();

    // The convention is a reading of the prose, never a rewrite of it.
    final manuscript =
        await const ManuscriptStore().readStudio('project-book');
    expect(manuscript!.chapters.first.scenes.first.content, prose);
  });

  testWidgets('a chosen cover is validated, stored and shown', (tester) async {
    await pumpStudio(tester, coverPicker: () async => testPng(420, 640));

    // Decoding an image is genuinely asynchronous, and the test harness's fake
    // clock will not advance it, so the tap has to run against a real one.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-choose-cover-button')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Cover set.'), findsOneWidget);
    final stored = await BookCoverStore(database: database).load('project-book');
    expect(stored, isNotNull);
    expect(stored!.width, 420);
    expect(find.byKey(const Key('book-remove-cover-button')), findsOneWidget);
  });

  testWidgets('a file that is not a usable cover is refused with a reason',
      (tester) async {
    await pumpStudio(
      tester,
      coverPicker: () async => Uint8List.fromList('GIF89a nope'.codeUnits),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-choose-cover-button')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // The refusal says why, in the snackbar rather than in the panel's own
    // standing help text.
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('JPEG'),
      ),
      findsOneWidget,
    );
    expect(await BookCoverStore(database: database).load('project-book'),
        isNull);
  });

  testWidgets('the editing stage lists what it found and can fix it',
      (tester) async {
    seedManuscript(messyManuscriptFixture());
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();

    expect(find.text('Editing'), findsWidgets);
    expect(find.textContaining('Fix all'), findsOneWidget);
    // The rules that fire on this fixture, each grouped under its own heading.
    expect(find.textContaining('Double spaces'), findsOneWidget);
    expect(find.textContaining('Indentation typed by hand'), findsOneWidget);
  });

  testWidgets('fixing writes the corrected prose back to the manuscript',
      (tester) async {
    seedManuscript(messyManuscriptFixture());
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();

    // Writing prose back goes through the manuscript's own service, which does
    // real asynchronous work; the harness's fake clock will not advance it.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-fix-all-editing')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final stored = await const ManuscriptStore().readStudio('project-book');
    final prose = stored!.chapters.first.scenes.first.content;

    expect(prose, isNot(startsWith('\t')),
        reason: 'the hand-typed indent should be gone');
    expect(prose, isNot(contains('  ')),
        reason: 'double spaces should be collapsed');
    expect(prose, contains('“'),
        reason: 'straight quotes should have been curled');
    expect(prose, isNot(contains(' ,')),
        reason: 'the space before the comma should be closed up');
  });

  testWidgets('fixing twice leaves nothing left to fix', (tester) async {
    seedManuscript(messyManuscriptFixture());
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('book-fix-all-editing')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // The report is recomputed after a fix, so the button should be gone.
    expect(find.byKey(const Key('book-fix-all-editing')), findsNothing);
    expect(find.textContaining('The text is clean'), findsOneWidget);
  });

  testWidgets('clean prose reports nothing rather than nothing at all',
      (tester) async {
    seedManuscript(cleanManuscriptFixture());
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();

    expect(find.textContaining('The text is clean'), findsOneWidget);
  });

  testWidgets('the proofing stage says whether spelling was checked',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-proofing')));
    await tester.pumpAndSettle();

    // The dictionary loads on demand, and until it has, the studio says so
    // rather than implying the book is clean.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Spelling checked against'), findsOneWidget);
  });
}
