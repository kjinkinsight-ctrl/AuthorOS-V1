/// The formatting UI, from the model up to the widgets an author touches.
library;

import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/prose_markup.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/prose_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProseEditingController', () {
    test('starts plain and stays plain until something is marked', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali waited.';

      expect(controller.markup.isPlain, isTrue);
      expect(controller.document, ProseDocument.fromPlainText('Kali waited.'));
    });

    test('toggling over a selection marks exactly that selection', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali waited.';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);

      controller.toggleMark(ProseMark.bold);

      expect(controller.markup.marksIn(0, 4), {ProseMark.bold});
      expect(controller.markup.marksIn(4, 12), isEmpty);
      expect(controller.text, 'Kali waited.', reason: 'text is untouched');
    });

    test('marks survive the author typing afterwards', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali waited.';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      controller.toggleMark(ProseMark.bold);

      controller.value = const TextEditingValue(
        text: 'Kali waited a long time.',
        selection: TextSelection.collapsed(offset: 24),
      );

      expect(controller.markup.marksIn(0, 4), {ProseMark.bold});
    });

    test('choosing a mark with no selection formats what is typed next', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali ';
      controller.selection = const TextSelection.collapsed(offset: 5);

      controller.toggleMark(ProseMark.italic);
      // The button must look pressed before a character exists to carry it.
      expect(controller.activeMarks, {ProseMark.italic});

      controller.value = const TextEditingValue(
        text: 'Kali ran',
        selection: TextSelection.collapsed(offset: 8),
      );

      expect(controller.markup.marksIn(5, 8), {ProseMark.italic});
      expect(controller.markup.marksIn(0, 5), isEmpty);
    });

    test('moving the caret abandons a pending choice', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali waited.';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.toggleMark(ProseMark.bold);

      controller.selection = const TextSelection.collapsed(offset: 2);

      expect(controller.activeMarks, isEmpty);
    });

    test('active marks follow the caret into a marked run', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.markup = ProseMarkup(
        text: 'Kali waited.',
        ranges: [
          const MarkedRange(start: 0, end: 4, marks: {ProseMark.bold}),
        ],
      );

      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.activeMarks, {ProseMark.bold});

      controller.selection = const TextSelection.collapsed(offset: 9);
      expect(controller.activeMarks, isEmpty);
    });

    test('replacing the markup does not leave the old scene marks behind', () {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.markup = ProseMarkup(
        text: 'Kali waited.',
        ranges: [
          const MarkedRange(start: 0, end: 4, marks: {ProseMark.bold}),
        ],
      );

      controller.markup =
          ProseMarkup.fromDocument(ProseDocument.fromPlainText('A new scene.'));

      expect(controller.markup.isPlain, isTrue);
      expect(controller.markup.ranges, isEmpty);
      expect(controller.selection.baseOffset, 0);
    });

    testWidgets('renders marked runs with the style they mean', (tester) async {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.markup = ProseMarkup(
        text: 'Kali waited.',
        ranges: [
          const MarkedRange(
            start: 0,
            end: 4,
            marks: {ProseMark.bold, ProseMark.underline},
          ),
        ],
      );

      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 14),
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final marked = span.children!.first as TextSpan;
      expect(marked.text, 'Kali');
      expect(marked.style!.fontWeight, FontWeight.w700);
      expect(marked.style!.decoration, TextDecoration.underline);

      final plain = span.children![1] as TextSpan;
      expect(plain.text, ' waited.');
      expect(plain.style?.fontWeight, isNot(FontWeight.w700));
    });
  });

  group('the toolbar', () {
    Future<ProseEditingController> pumpToolbar(
      WidgetTester tester, {
      bool enabled = true,
    }) async {
      final controller = ProseEditingController();
      addTearDown(controller.dispose);
      controller.text = 'Kali waited.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProseFormattingToolbar(
              controller: controller,
              enabled: enabled,
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('offers every mark the document can store', (tester) async {
      await pumpToolbar(tester);
      for (final mark in ProseMark.values) {
        expect(
          find.byKey(Key('prose-mark-${mark.name}')),
          findsOneWidget,
          reason: '${mark.name} has nowhere to be turned on',
        );
      }
    });

    testWidgets('marks the selection when pressed', (tester) async {
      final controller = await pumpToolbar(tester);
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);

      await tester.tap(find.byKey(const Key('prose-mark-bold')));
      await tester.pumpAndSettle();

      expect(controller.markup.marksIn(0, 4), {ProseMark.bold});
    });

    testWidgets('shows which marks the selection already has', (tester) async {
      final controller = await pumpToolbar(tester);
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      await tester.tap(find.byKey(const Key('prose-mark-italic')));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.byKey(const Key('prose-mark-italic')),
      );
      expect(button.isSelected, isTrue);

      final bold = tester.widget<IconButton>(
        find.byKey(const Key('prose-mark-bold')),
      );
      expect(bold.isSelected, isFalse);
    });

    testWidgets('is visibly unavailable rather than silently inert',
        (tester) async {
      // Canon with a branch active: the editor is read-only, and the toolbar
      // has to say so rather than accept presses that do nothing.
      await pumpToolbar(tester, enabled: false);

      final button = tester.widget<IconButton>(
        find.byKey(const Key('prose-mark-bold')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('in the Studio', () {
    const projectId = 'formatting-project';
    const project = StarterProject(
      id: projectId,
      title: 'The Blood Price',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: [],
      chapters: [
        StarterChapter(title: 'Chapter One', prompt: '', scenes: ['Arrival']),
      ],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Arrival',
    );

    late AuthorOsDatabase database;
    late DriftConnectedDomainRepository repository;
    late ManuscriptStore store;
    late ManuscriptService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = AuthorOsDatabase(NativeDatabase.memory());
      repository = DriftConnectedDomainRepository(database);
      store = ManuscriptStore(repository: repository);
      service = ManuscriptService(
        projectId: projectId,
        repository: repository,
        store: store,
      );
    });

    tearDown(() => database.close());

    Future<void> pumpStudio(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManuscriptStudioView(
              project: project,
              startSprint: false,
              store: store,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the editor offers formatting', (tester) async {
      await pumpStudio(tester);
      expect(find.byKey(const Key('prose-formatting-toolbar')), findsWidgets);
    });

    testWidgets('formatting reaches the database and comes back', (tester) async {
      var manuscript = await service.load(
        manuscriptTitle: project.title,
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter One', scenes: ['Arrival']),
        ],
        firstSceneTitle: 'Arrival',
      );
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await service.writeSceneBody(
        manuscript,
        sceneId,
        'Kali waited.',
      );

      await pumpStudio(tester);

      final field = find.byKey(const Key('manuscript-draft-field'));
      await tester.tap(field);
      await tester.pumpAndSettle();

      final controller = tester
          .widget<TextField>(field.first)
          .controller as ProseEditingController;
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 4);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prose-mark-bold')).first);
      await tester.pumpAndSettle();
      // Let the debounced autosave land.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final stored = await repository.sceneProseById(sceneId);
      expect(stored, isNotNull);
      expect(stored!.plainText, 'Kali waited.');
      expect(
        stored.document.blocks.single.spans.first.marks,
        {ProseMark.bold},
        reason: 'the mark never reached scene_prose_rows',
      );
      // The row must now declare itself formatted, or the next save's cheap
      // plain-text comparison would decide nothing had changed.
      final digests = await repository.sceneProseDigestsForProject(projectId);
      expect(digests[sceneId]!.isFormatted, isTrue);
    });

    testWidgets('a formatted scene reopens formatted', (tester) async {
      var manuscript = await service.load(
        manuscriptTitle: project.title,
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter One', scenes: ['Arrival']),
        ],
        firstSceneTitle: 'Arrival',
      );
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await service.writeSceneBody(
        manuscript,
        sceneId,
        'Kali waited.',
      );
      // Store a formatted document directly, as a previous session would have.
      await store.saveStudio(
        manuscript.copyWith(chapters: [
          for (final chapter in manuscript.chapters)
            chapter.copyWith(scenes: [
              for (final scene in chapter.scenes)
                scene.copyWith(
                  content: 'Kali waited.',
                  document: const ProseDocument([
                    ProseBlock(spans: [
                      ProseSpan('Kali', marks: {ProseMark.bold}),
                      ProseSpan(' waited.'),
                    ]),
                  ]),
                ),
            ]),
        ]),
      );

      await pumpStudio(tester);

      final controller = tester
          .widget<TextField>(
            find.byKey(const Key('manuscript-draft-field')).first,
          )
          .controller as ProseEditingController;

      expect(controller.text, 'Kali waited.');
      expect(controller.markup.marksIn(0, 4), {ProseMark.bold});
    });
  });
}
