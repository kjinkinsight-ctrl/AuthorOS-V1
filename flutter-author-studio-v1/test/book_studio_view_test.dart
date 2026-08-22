import 'dart:convert';

import 'package:author_studio_v1/book/book_export_targets.dart';
import 'package:author_studio_v1/book_studio_view.dart';
import 'package:author_studio_v1/book/book_preview_painter.dart';
import 'package:author_studio_v1/book/book_store.dart';
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

  Future<void> pumpStudio(
    WidgetTester tester, {
    BookFileSaver? saver,
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

  testWidgets('shows every pipeline stage, with the later ones disabled',
      (tester) async {
    await pumpStudio(tester);

    for (final stage in BookStage.values) {
      expect(find.byKey(Key('book-stage-${stage.name}')), findsOneWidget,
          reason: '${stage.label} is missing from the pipeline');
    }

    // Editing and proofing are visible so the pipeline reads whole, but they
    // must not pretend to work: tapping one leaves the studio where it was.
    await tester.tap(find.byKey(const Key('book-stage-editing')));
    await tester.pumpAndSettle();
    expect(find.text('Front matter'), findsOneWidget,
        reason: 'a disabled stage must not navigate anywhere');
    expect(find.text('later'), findsNothing);
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
}
