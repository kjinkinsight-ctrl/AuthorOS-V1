import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  StarterProject project(String id) => StarterProject(
        id: id,
        title: 'Timeline Test',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 80000,
        acts: const ['Act I'],
        chapters: const [
          StarterChapter(title: 'Chapter 1', prompt: 'Begin'),
        ],
        characterSheets: const [
          StarterCharacterSheet(name: 'Mara', role: 'Protagonist'),
        ],
        beatChecklist: const ['Opening Image', 'Inciting Incident'],
        firstSceneTitle: 'Opening Scene',
      );

  test('starter state uses project characters and beats', () async {
    final state = await const TimelineStore().load(project('project-a'));

    expect(state.events, hasLength(2));
    expect(state.events.first.presentCharacters, ['Mara']);
    expect(state.events.first.plotBeat, 'Opening Image');
    expect(state.events.last.plotBeat, 'Inciting Incident');
  });

  test('state round trips and preserves orphaned references', () async {
    const store = TimelineStore();
    final currentProject = project('project-a');
    final initial = await store.load(currentProject);
    final changed = TimelineState(
      eras: initial.eras,
      sequences: initial.sequences,
      events: [
        initial.events.first.copyWith(
          title: 'Persisted Event',
          eraId: 'missing-era',
          sequenceId: 'missing-sequence',
          startDay: -2,
          endDay: 4,
        ),
      ],
    );

    await store.save(currentProject.id, changed);
    final restored = await store.load(currentProject);

    expect(restored.events.single.title, 'Persisted Event');
    expect(restored.events.single.eraId, 'missing-era');
    expect(restored.events.single.sequenceId, 'missing-sequence');
    expect(restored.events.single.startDay, -2);
    expect(restored.events.single.endDay, 4);
  });

  test('project timeline stores are isolated', () async {
    const store = TimelineStore();
    final first = project('project-a');
    final second = project('project-b');
    final firstState = await store.load(first);

    await store.save(
      first.id,
      TimelineState(
        eras: firstState.eras,
        sequences: firstState.sequences,
        events: [firstState.events.first.copyWith(title: 'Only Project A')],
      ),
    );

    expect((await store.load(first)).events.single.title, 'Only Project A');
    expect((await store.load(second)).events.first.title, 'Opening Catalyst');
  });

  test('legacy missing fields receive safe defaults', () {
    final state = TimelineState.fromJson({
      'events': [
        {'id': 'legacy-event', 'title': 'Legacy'},
      ],
    });

    expect(state.eras, isEmpty);
    expect(state.sequences, isEmpty);
    expect(state.events.single.startDay, 1);
    expect(state.events.single.endDay, 1);
    expect(state.events.single.presentCharacters, isEmpty);
  });
}
