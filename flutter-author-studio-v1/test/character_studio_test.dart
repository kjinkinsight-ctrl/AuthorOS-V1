import 'package:author_studio_v1/character_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deep character record and connections round trip through project store',
      () async {
    const record = CharacterStudioRecord(
      id: 'character-kali',
      template: 'Protagonist',
      status: 'Active',
      fields: {
        'identity.fullName': 'Kali Vale',
        'appearance.eyeColour': 'Grey',
        'personality.coreTraits': 'Resolute, observant',
        'psychology.coreDesire': 'Protect her found family',
        'goals.primaryGoal': 'Expose the Widow Network',
        'arc.startingState': 'Trusts nobody',
        'voice.speechStyle': 'Precise and guarded',
        'notes.continuity': 'Scar is on the left hand.',
      },
      customFields: {'custom.Magic affinity': 'Shadow'},
      connections: {
        'relationships': ['character-cassian'],
        'scenes': ['scene-1', 'scene-8'],
        'timeline': ['event-2'],
      },
      portraitPath: 'portraits/kali.png',
      referenceImages: ['references/kali-coat.png'],
    );
    const store = CharacterStudioStore('project-one');

    await store.save([record]);
    final restored = await store.load();

    expect(restored, hasLength(1));
    expect(restored.single.name, 'Kali Vale');
    expect(restored.single.fields['psychology.coreDesire'],
        'Protect her found family');
    expect(restored.single.customFields['custom.Magic affinity'], 'Shadow');
    expect(restored.single.connections['scenes'], ['scene-1', 'scene-8']);
    expect(restored.single.portraitPath, 'portraits/kali.png');
    expect(restored.single.referenceImages, ['references/kali-coat.png']);
    expect(await const CharacterStudioStore('project-two').load(), isEmpty);
  });

  testWidgets('author can add and persist a structured character',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const project = StarterProject(
      id: 'character-studio-project',
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
      acts: [],
      chapters: [],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Opening',
    );

    await tester.pumpWidget(
      const MaterialApp(
          home: Scaffold(body: CharacterBoardView(project: project))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-character-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('character-name-field')),
      'Kali Vale',
    );
    await tester.tap(find.byKey(const Key('save-character-button')));
    await tester.pumpAndSettle();

    expect(find.text('Kali Vale'), findsWidgets);
    final saved =
        await const CharacterStudioStore('character-studio-project').load();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Kali Vale');
    expect(saved.single.template, 'Standard Character');
  });
}
