import 'dart:convert';

import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book_studio_view.dart';
import 'package:author_studio_v1/book/book_preview_painter.dart';
import 'package:author_studio_v1/book/book_cover.dart';
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
    await tester.tap(find.byKey(const Key('book-export-button')));
    await tester.pumpAndSettle();

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife-print.pdf');
    expect(saver.bytes, isNotNull);
    expect(String.fromCharCodes(saver.bytes!.take(5)), '%PDF-');
  });

  testWidgets('the export stage marks unbuilt targets rather than hiding them',
      (tester) async {
    await pumpStudio(tester);

    await tester.tap(find.byKey(const Key('book-stage-export')));
    await tester.pumpAndSettle();

    for (final format in BookExportFormat.values) {
      expect(find.byKey(Key('book-export-${format.name}')), findsOneWidget);
    }
    expect(find.text('later'), findsWidgets);
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
    await tester.tap(find.byKey(const Key('book-export-button')));
    await tester.pumpAndSettle();

    expect(saver.calls, 1);
    expect(saver.name, 'the-widow-knife.epub');
    // A zip, and the mimetype right where the specification wants it.
    expect(saver.bytes!.take(2), orderedEquals([0x50, 0x4B]));
    expect(String.fromCharCodes(saver.bytes!.sublist(30, 38)), 'mimetype');
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
