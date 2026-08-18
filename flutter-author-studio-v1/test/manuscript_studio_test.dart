import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('scene text and reordered scenes persist after navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const project = StarterProject(
      id: 'studio-project',
      title: 'Studio Project',
      genre: 'Fiction',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: [],
      chapters: [
        StarterChapter(
          title: 'The Beginning',
          prompt: '',
          scenes: ['Arrival', 'Meeting', 'Warning'],
        ),
        StarterChapter(
          title: 'The Crossing',
          prompt: '',
          scenes: ['Departure'],
        ),
      ],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Arrival',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ManuscriptStudioView(
            project: project,
            startSprint: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Scene 02 - Meeting').first);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('manuscript-draft-field')),
      'The rain had been falling since dawn.',
    );
    await tester.tap(find.textContaining('Scene 01 - Arrival').first);
    await tester.pump();
    await tester.tap(find.textContaining('Scene 02 - Meeting').first);
    await tester.pump();

    final editor = tester.widget<TextField>(
      find.byKey(const Key('manuscript-draft-field')),
    );
    expect(editor.controller?.text, 'The rain had been falling since dawn.');

    final meetingTile = find.ancestor(
      of: find.textContaining('Scene 02 - Meeting').first,
      matching: find.byType(ListTile),
    );
    final storedBeforeMove = await const ManuscriptStore().loadStudio(
      project.id,
      manuscriptTitle: project.title,
      defaultChapters: const [],
    );
    final meetingId = storedBeforeMove.chapters.first.scenes[1].id;
    await tester.tap(
      find.descendant(
        of: meetingTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scene-move-up-$meetingId')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    final stored = await const ManuscriptStore().loadStudio(
      project.id,
      manuscriptTitle: project.title,
      defaultChapters: const [],
    );
    expect(stored.chapters.first.scenes.first.title, 'Meeting');
    expect(stored.chapters.first.scenes.first.order, 1);
    expect(stored.chapters.first.scenes.first.content,
        'The rain had been falling since dawn.');
  });
}
