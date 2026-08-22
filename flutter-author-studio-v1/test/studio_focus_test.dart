/// Following a connection has to land on the thing that was followed.
///
/// Every Studio built a navigation request carrying the target's id, and the
/// shell switched on `destination` and dropped the rest — so the app knew
/// "Manuscript Studio, chapter X, scene Y" and said only "Manuscript Studio".
/// These prove the identity survives the trip, and that an id naming nothing
/// leaves the Studio in a sane default rather than blank.
library;

import 'package:author_studio_v1/character_studio.dart';
import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = StarterProject(
  id: 'focus-project',
  title: 'Focus Project',
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
  ],
  characterSheets: [],
  beatChecklist: [],
  firstSceneTitle: 'Arrival',
);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  void sizeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Manuscript Studio', () {
    /// Seeds the manuscript the way the Studio itself does on first open, so
    /// the ids under test are the real ones the widget will resolve.
    Future<ManuscriptProjectSummary> seedManuscript(
      ManuscriptStore store,
    ) async =>
        store.loadStudio(
          _project.id,
          manuscriptTitle: _project.title,
          defaultChapters: [
            for (final chapter in _project.chapters)
              ManuscriptChapterSeed(
                title: chapter.title,
                prompt: chapter.prompt,
                status: chapter.status,
                scenes: chapter.scenes,
                linkedChapterIds: chapter.linkedChapterIds,
              ),
          ],
          firstSceneTitle: _project.firstSceneTitle,
        );

    Future<void> pumpManuscript(
      WidgetTester tester,
      ManuscriptStore store, {
      String? focusNodeId,
    }) async {
      sizeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManuscriptStudioView(
              project: _project,
              startSprint: false,
              store: store,
              focusNodeId: focusNodeId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the scene it was told to open on', (tester) async {
      final store = ManuscriptStore(repository: repository);
      final manuscript = await seedManuscript(store);
      // The third scene, so landing on it cannot be confused with the default
      // selection, which is the first.
      final target = manuscript.chapters.first.scenes[2];

      await pumpManuscript(tester, store, focusNodeId: target.id);

      final editor = tester.widget<TextField>(
        find.byKey(const Key('manuscript-draft-field')),
      );
      expect(editor.controller!.text, target.content);
      expect(find.textContaining(target.title), findsWidgets);
    });

    testWidgets('opens on a chapter it was told to open on', (tester) async {
      final store = ManuscriptStore(repository: repository);
      final manuscript = await seedManuscript(store);

      await pumpManuscript(
        tester,
        store,
        focusNodeId: manuscript.chapters.first.id,
      );

      expect(find.textContaining('The Beginning'), findsWidgets);
    });

    testWidgets('an unknown id falls back rather than blanking the editor',
        (tester) async {
      final store = ManuscriptStore(repository: repository);
      await seedManuscript(store);

      await pumpManuscript(tester, store, focusNodeId: 'not-a-real-node');

      // Focus is a request, not a guarantee. The manuscript's own stored
      // selection still applies.
      expect(
        find.byKey(const Key('manuscript-draft-field')),
        findsOneWidget,
      );
    });

    testWidgets('a second target re-focuses without a rebuild', (tester) async {
      final store = ManuscriptStore(repository: repository);
      final manuscript = await seedManuscript(store);
      final first = manuscript.chapters.first.scenes[0];
      final third = manuscript.chapters.first.scenes[2];

      await pumpManuscript(tester, store, focusNodeId: first.id);
      // Same widget, new target — this is what happens when the author follows
      // a connection while already in Manuscript Studio. Without
      // didUpdateWidget the second click would be ignored.
      await pumpManuscript(tester, store, focusNodeId: third.id);

      final editor = tester.widget<TextField>(
        find.byKey(const Key('manuscript-draft-field')),
      );
      expect(editor.controller!.text, third.content);
    });
  });

  group('Character Studio', () {
    testWidgets('opens on the character it was told to open on',
        (tester) async {
      final characters =
          CharacterService(projectId: _project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');

      sizeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterBoardView(
              project: _project,
              repository: repository,
              // Not the roster's default, which is the first non-archived
              // character.
              focusRecordId: 'char-2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edrin Vale'), findsWidgets);
    });

    testWidgets('an unknown id falls back to the default selection',
        (tester) async {
      final characters =
          CharacterService(projectId: _project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');

      sizeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterBoardView(
              project: _project,
              repository: repository,
              focusRecordId: 'nobody',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mara Voss'), findsWidgets);
    });
  });
}
