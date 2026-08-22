import 'dart:io';

import 'package:author_studio_v1/core/scene_revision.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/manuscript_studio.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/scene_revision_service.dart';
import 'package:author_studio_v1/writing_session_recorder.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = StarterProject(
  id: 'revision-project',
  title: 'The Hollow Court',
  genre: 'Fantasy',
  projectType: 'Novel',
  wordGoal: 90000,
  acts: [],
  chapters: [
    StarterChapter(
      title: 'The Beginning',
      prompt: '',
      scenes: ['Arrival', 'Meeting'],
    ),
  ],
  characterSheets: [],
  beatChecklist: [],
  firstSceneTitle: 'Arrival',
);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
    now = DateTime.utc(2026, 8, 22, 9);
  });

  tearDown(() async {
    await database.close();
  });

  SceneRevisionService revisionService() => SceneRevisionService(
        projectId: _project.id,
        repository: repository,
        clock: () => now,
      );

  Future<void> pumpStudio(
    WidgetTester tester, {
    WritingSessionRecorder? sessionRecorder,
  }) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManuscriptStudioView(
            project: _project,
            startSprint: false,
            store: store,
            repository: repository,
            revisionService: revisionService(),
            sessionRecorder: sessionRecorder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<ManuscriptProjectSummary> stored() => store.loadStudio(
        _project.id,
        manuscriptTitle: _project.title,
        defaultChapters: const [],
      );

  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const Key('manuscript-draft-field')),
      text,
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  /// Leaves the scene and comes back — the boundary that captures.
  Future<void> leaveAndReturn(WidgetTester tester) async {
    await tester.tap(find.textContaining('Scene 02 - Meeting').first);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Scene 01 - Arrival').first);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  group('capture', () {
    testWidgets('leaving a scene keeps what it said', (tester) async {
      await pumpStudio(tester);
      await write(tester, 'She opened the door, and the cold came in.');
      await leaveAndReturn(tester);

      final sceneId = (await stored()).chapters.first.scenes.first.id;
      final history = await revisionService().historyFor(sceneId);

      expect(history, hasLength(1));
      final revision = await revisionService().revision(history.single.id);
      expect(revision!.content, 'She opened the door, and the cold came in.');
    });

    testWidgets('opening a manuscript and leaving it again keeps nothing',
        (tester) async {
      // The seeded manuscript has no prose in it. A history that filled with
      // empty revisions before the author had written a word would be worse
      // than no history at all.
      await pumpStudio(tester);
      await leaveAndReturn(tester);

      final manuscript = await stored();
      for (final scene in manuscript.chapters.first.scenes) {
        expect(await revisionService().historyFor(scene.id), isEmpty);
      }
    });

    testWidgets('typing alone never captures', (tester) async {
      // The 700ms autosave must not write history: a snapshot per keystroke
      // burst is a second copy of the novel every few seconds.
      await pumpStudio(tester);
      await write(tester, 'One.');
      await write(tester, 'One. Two.');
      await write(tester, 'One. Two. Three.');

      final sceneId = (await stored()).chapters.first.scenes.first.id;

      expect(await revisionService().historyFor(sceneId), isEmpty);
    });
  });

  group('restore', () {
    testWidgets('the earlier words come back into the editor', (tester) async {
      await pumpStudio(tester);
      await write(tester, 'The line I liked.');
      await leaveAndReturn(tester);

      now = now.add(const Duration(hours: 1));
      await write(tester, 'The line I regret.');

      await tester.tap(find.byKey(const Key('scene-revisions-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scene-revisions-dialog')), findsOneWidget);

      final sceneId = (await stored()).chapters.first.scenes.first.id;
      final history = await revisionService().historyFor(sceneId);
      await tester.tap(find.byKey(Key('scene-revision-${history.single.id}')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('scene-revision-preview')),
          matching: find.text('The line I liked.'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('scene-revision-restore')));
      await tester.pumpAndSettle();

      final editor = tester.widget<TextField>(
        find.byKey(const Key('manuscript-draft-field')),
      );
      expect(editor.controller?.text, 'The line I liked.');
      expect(
        (await stored()).sceneById(sceneId)!.content,
        'The line I liked.',
      );
    });

    testWidgets('a restore is itself recoverable', (tester) async {
      await pumpStudio(tester);
      await write(tester, 'The old line.');
      await leaveAndReturn(tester);

      now = now.add(const Duration(hours: 1));
      await write(tester, 'The new line.');

      final sceneId = (await stored()).chapters.first.scenes.first.id;
      final old = (await revisionService().historyFor(sceneId)).single;

      await tester.tap(find.byKey(const Key('scene-revisions-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('scene-revision-${old.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scene-revision-restore')));
      await tester.pumpAndSettle();

      final history = await revisionService().historyFor(sceneId);
      expect(history, hasLength(2));
      expect(history.first.trigger, SceneRevisionTrigger.restore);
      final kept = await revisionService().revision(history.first.id);
      expect(
        kept!.content,
        'The new line.',
        reason: 'An author who restores the wrong version has not lost the '
            'one they were looking at.',
      );
    });

    testWidgets('restoring records no writing session', (tester) async {
      // The words did not come from the author. Crediting them would put a
      // phantom session into every daily total, streak, velocity and
      // projection the analytics milestone added.
      final recorder = WritingSessionRecorder(
        projectId: _project.id,
        repository: repository,
        clock: () => now,
      );
      await pumpStudio(tester, sessionRecorder: recorder);

      // A long scene, so restoring it moves the count by far more than the
      // ten words that qualify a session on their own.
      final long = List.filled(80, 'word').join(' ');
      await write(tester, long);
      await leaveAndReturn(tester);
      now = now.add(const Duration(hours: 2));
      await write(tester, 'Tiny.');
      now = now.add(const Duration(hours: 2));
      await recorder.finalizeSession();

      final honest =
          await repository.writingSessionsForProject(_project.id);

      final sceneId = (await stored()).chapters.first.scenes.first.id;
      final old = (await revisionService().historyFor(sceneId)).single;

      await tester.tap(find.byKey(const Key('scene-revisions-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('scene-revision-${old.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scene-revision-restore')));
      await tester.pumpAndSettle();

      // The keystroke is the trap, not the restore. Nothing is credited while
      // the editor is being written to; the damage lands on the next thing
      // the author types, when the recorder compares the count it last saw
      // with the one the restore put there.
      await write(tester, '$long!');
      await recorder.finalizeSession();

      final after = await repository.writingSessionsForProject(_project.id);
      final added = after
          .where((session) =>
              honest.every((earlier) => earlier.id != session.id))
          .toList();

      for (final session in added) {
        expect(
          session.wordsAdded,
          lessThan(10),
          reason: 'Restoring ~79 words is a session by word count alone, so a '
              'restore the recorder was not told about qualifies on its first '
              'branch without ever consulting duration.',
        );
      }
    });

    testWidgets('the empty state explains when snapshots happen',
        (tester) async {
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('scene-revisions-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scene-revisions-empty')), findsOneWidget);
      expect(find.byKey(const Key('scene-revisions-list')), findsNothing);
    });
  });

  group('deletion', () {
    testWidgets('deleting a scene keeps its prose', (tester) async {
      // Without this, deleting a scene is the last unrecoverable way to lose
      // words in AuthorOS.
      await pumpStudio(tester);
      await write(tester, 'Everything that happened at the gate.');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      final sceneId = (await stored()).chapters.first.scenes.first.id;
      final service = revisionService();
      final scene = (await stored()).sceneById(sceneId)!;
      await service.captureScene(
        scene,
        trigger: SceneRevisionTrigger.deletion,
      );

      final history = await service.historyFor(sceneId);
      expect(history.single.trigger, SceneRevisionTrigger.deletion);
      final kept = await service.revision(history.single.id);
      expect(kept!.content, 'Everything that happened at the gate.');
    });
  });

  group('architecture', () {
    test('the Studio owns the capture, not the store', () {
      final studio = File('lib/manuscript_studio.dart').readAsStringSync();

      expect(studio, contains('_revisionService.captureBoundary'));
      expect(studio, contains('_revisionService.captureBeforeRemote'));
      expect(studio, contains('_revisionService.restore'));
      // The session-recorder literals an existing test pins stay put.
      expect(studio, contains('_sessionRecorder.noteBaseline'));
      expect(studio, contains('_sessionRecorder.noteActivity'));
      expect(studio, contains('_sessionRecorder.finalizeSession()'));
      expect(studio, contains('wordCount: current.wordCount'));
    });

    test('a pull keeps the local words before it adopts the arriving ones',
        () {
      // The ordering is the whole guarantee. `_manuscript` is only still this
      // device's version until `_adoptManuscript` runs, so a capture placed
      // after it would faithfully snapshot the prose that just replaced the
      // prose it was meant to save.
      final studio = File('lib/manuscript_studio.dart').readAsStringSync();
      final start = studio.indexOf('Future<void> _adoptRemoteManuscript(');
      final adopt = studio.substring(
        start,
        studio.indexOf('void didChangeAppLifecycleState', start),
      );

      final capture = adopt.indexOf('captureBeforeRemote');
      final apply = adopt.indexOf('_adoptManuscript(manuscript)');
      expect(capture, greaterThan(-1));
      expect(apply, greaterThan(-1));
      expect(capture, lessThan(apply));
      // And the right way round: the local manuscript is what is preserved.
      expect(adopt, contains('local: local'));
      expect(adopt, contains('incoming: manuscript'));
    });

    test('a restore is held behind the same guard a remote apply is', () {
      // Setting the editor text fires the change listener, and these are not
      // words the author typed.
      final studio = File('lib/manuscript_studio.dart').readAsStringSync();
      final start = studio.indexOf('Future<void> _restoreRevision(');
      final restore = studio.substring(start, studio.indexOf('void _report('));

      expect(restore, contains('_applyingRemote = true'));
      expect(restore, contains('noteRemoteChange'));
    });
  });
}
