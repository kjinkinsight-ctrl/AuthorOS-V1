import 'package:author_studio_v1/character_studio.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

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
    final store = CharacterStudioStore('project-one', repository: repository);
    final timestamp = DateTime.utc(2026, 8, 18);
    for (final targetId in [
      'character-cassian',
      'scene-1',
      'scene-8',
      'event-2',
    ]) {
      await repository.putRecord(AuthorRecord(
        id: targetId,
        typeId: 'connection-target',
        scopeType: RecordScopeType.project,
        scopeId: 'project-one',
        title: targetId,
        createdAt: timestamp,
        updatedAt: timestamp,
      ));
    }

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
    expect(
      await CharacterStudioStore('project-two', repository: repository).load(),
      isEmpty,
    );
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
      MaterialApp(
        home: Scaffold(
          body: CharacterBoardView(
            project: project,
            repository: repository,
          ),
        ),
      ),
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
    final saved = await CharacterStudioStore(
      'character-studio-project',
      repository: repository,
    ).load();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Kali Vale');
    expect(saved.single.template, 'Standard Character');
  });
}
