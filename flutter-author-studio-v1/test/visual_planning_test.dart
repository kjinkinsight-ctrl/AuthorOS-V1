import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/visual_planning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  StarterProject project() => NovelStarterKit.create(
        title: 'Planning Test',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 80000,
      );

  test('overlay persistence does not mutate scene board state', () async {
    const store = VisualPlanningStore();
    final currentProject = project();
    final initial = await store.load(currentProject);
    final sceneSnapshot =
        initial.scenes.map((scene) => scene.toJson()).toList();

    await store.save(
      currentProject.id,
      initial.copyWith(overlay: StructureOverlay.heroesJourney),
    );
    final restored = await store.load(currentProject);

    expect(restored.overlay, StructureOverlay.heroesJourney);
    expect(
        restored.scenes.map((scene) => scene.toJson()).toList(), sceneSnapshot);
    expect(StructureOverlay.threeAct.stages, [
      'Act I · Setup',
      'Act II · Confrontation',
      'Act III · Resolution',
    ]);
    expect(StructureOverlay.heroesJourney.stages, hasLength(12));
  });

  testWidgets('overlays and status POV arc filters update the board',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final currentProject = project();
    final initialPlanning =
        await const VisualPlanningStore().load(currentProject);
    final filteredScene = initialPlanning.scenes.firstWhere(
      (scene) =>
          scene.status == SceneStatus.outlining && scene.pov == 'Protagonist',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: VisualPlanningView(project: currentProject),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6 of 6 scenes'), findsOneWidget);
    expect(find.byKey(const Key('scene-overlay-${''}')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('scene-search-field')),
      'Opening Scene',
    );
    await tester.pump();
    expect(find.text('1 of 6 scenes'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('scene-search-field')), '');
    await tester.pump();
    expect(find.text('6 of 6 scenes'), findsOneWidget);

    await tester.tap(find.text("Hero's Journey"));
    await tester.pumpAndSettle();
    expect(find.text('Ordinary World'), findsWidgets);

    await tester.tap(find.text('Three-Act'));
    await tester.pumpAndSettle();
    expect(find.text('Act I · Setup'), findsWidgets);

    await tester.tap(find.byKey(const Key('status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outlining').last);
    await tester.pumpAndSettle();
    expect(find.text('2 of 6 scenes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pov-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Protagonist').last);
    await tester.pumpAndSettle();
    expect(find.text('1 of 6 scenes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('arc-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(filteredScene.arc).last);
    await tester.pumpAndSettle();
    expect(find.text('1 of 6 scenes'), findsOneWidget);
  });
}
