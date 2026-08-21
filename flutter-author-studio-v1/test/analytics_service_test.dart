import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 20, 10);

StarterProject _project(
  String id, {
  int wordGoal = 80000,
}) =>
    StarterProject(
      id: id,
      title: 'The Hollow Court',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

/// `count` words of scene content, so word totals are exact by construction.
String _words(int count) =>
    List<String>.generate(count, (index) => 'word${index + 1}').join(' ');

ManuscriptScene _scene(
  String chapterId,
  String id, {
  String title = 'Scene',
  String content = '',
  ManuscriptNodeStatus status = ManuscriptNodeStatus.draft,
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: 1,
      content: content,
      status: status,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

ManuscriptChapter _chapter(
  String id, {
  required String title,
  required List<ManuscriptScene> scenes,
  ManuscriptNodeStatus status = ManuscriptNodeStatus.draft,
}) =>
    ManuscriptChapter(
      id: id,
      title: title,
      order: 1,
      status: status,
      scenes: scenes,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
  });

  tearDown(() => database.close());

  AnalyticsService serviceFor(StarterProject project) => AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  /// Persists a manuscript through the Manuscript Studio's own store so the
  /// analytics read exactly what that Studio owns.
  Future<void> saveManuscript(
    StarterProject project,
    List<ManuscriptChapter> chapters,
  ) =>
      manuscriptStore.saveStudio(
        ManuscriptProjectSummary(
          projectId: project.id,
          manuscriptTitle: project.title,
          chapters: chapters,
          currentChapterId: chapters.isEmpty ? '' : chapters.first.id,
          currentSceneId:
              chapters.isEmpty || chapters.first.scenes.isEmpty
                  ? ''
                  : chapters.first.scenes.first.id,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: 2,
        ),
        persistLegacyText: false,
      );

  AuthorRecord researchRecord(String id, String typeId, String projectId) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        title: id,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  group('empty project', () {
    test('an empty project reports zeros and does not crash', () async {
      final project = _project('an-empty', wordGoal: 0);
      await saveManuscript(project, const []);

      final summary = await serviceFor(project).getSummary();

      expect(summary.projectId, project.id);
      expect(summary.projectName, project.title);
      expect(summary.manuscriptStatus, 'Not started');
      expect(summary.totalWordCount, 0);
      expect(summary.chapterCount, 0);
      expect(summary.sceneCount, 0);
      expect(summary.characterCount, 0);
      expect(summary.timelineEventCount, 0);
      expect(summary.plotRecordCount, 0);
      expect(summary.researchItemCount, 0);
      expect(summary.longestChapter, isNull);
      expect(summary.shortestChapter, isNull);
      expect(summary.chaptersByStatus, isEmpty);
      expect(summary.charactersWithProfiles, 0);
      expect(summary.charactersWithRelationships, 0);
      expect(summary.charactersReferencedInManuscript, 0);
      expect(summary.activePlotThreadCount, 0);
      expect(summary.completedPlotThreadCount, 0);
    });

    test('averages divide by zero safely on an empty manuscript', () async {
      final project = _project('an-zero-div', wordGoal: 0);
      await saveManuscript(project, const []);

      final summary = await serviceFor(project).getSummary();

      expect(summary.averageWordsPerChapter, 0);
      expect(summary.averageWordsPerScene, 0);
      expect(summary.averageChapterLength, 0);
      expect(summary.percentTowardTarget, isNull);
      expect(summary.wordsRemaining, isNull);
    });
  });

  group('writing progress', () {
    test('word count comes from the Manuscript Studio store', () async {
      final project = _project('an-words');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(120)),
          _scene('ch-1', 'sc-2', content: _words(80)),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();
      final manuscript = await manuscriptStore.loadStudio(
        project.id,
        manuscriptTitle: project.title,
        defaultChapters: const [],
      );

      expect(summary.totalWordCount, 200);
      expect(summary.totalWordCount, manuscript.wordCount);
    });

    test('target, percentage, and words remaining derive from the goal',
        () async {
      final project = _project('an-target', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.targetWordCount, 1000);
      expect(summary.hasWritingTarget, isTrue);
      expect(summary.progressTowardTarget, 0.25);
      expect(summary.percentTowardTarget, 25.0);
      expect(summary.wordsRemaining, 750);
      expect(summary.completionPercent, 25.0);
    });

    test('a missing target yields no percentages instead of 0%', () async {
      final project = _project('an-no-target', wordGoal: 0);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.hasWritingTarget, isFalse);
      expect(summary.progressTowardTarget, isNull);
      expect(summary.percentTowardTarget, isNull);
      expect(summary.wordsRemaining, isNull);
      expect(summary.completionPercent, isNull);
    });

    test('a zero-word project with a target reports 0% safely', () async {
      final project = _project('an-zero-words', wordGoal: 5000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [_scene('ch-1', 'sc-1')]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.totalWordCount, 0);
      expect(summary.percentTowardTarget, 0.0);
      expect(summary.wordsRemaining, 5000);
    });

    test('overshooting the goal clamps progress and remaining work', () async {
      final project = _project('an-overshoot', wordGoal: 100);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(150)),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.percentTowardTarget, 100.0);
      expect(summary.wordsRemaining, 0);
    });
  });

  group('chapter analytics', () {
    test('chapter, scene, and average calculations match the manuscript',
        () async {
      final project = _project('an-chapters');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Long One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(300)),
          _scene('ch-1', 'sc-2', content: _words(100)),
        ]),
        _chapter('ch-2', title: 'The Short One', scenes: [
          _scene('ch-2', 'sc-3', content: _words(50)),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.chapterCount, 2);
      expect(summary.sceneCount, 3);
      expect(summary.totalWordCount, 450);
      expect(summary.averageWordsPerChapter, 225);
      expect(summary.averageChapterLength, 225);
      expect(summary.averageWordsPerScene, 150);
      expect(summary.longestChapter?.title, 'The Long One');
      expect(summary.longestChapter?.wordCount, 400);
      expect(summary.shortestChapter?.title, 'The Short One');
      expect(summary.shortestChapter?.wordCount, 50);
    });

    test('chapters bucket by status and drive the manuscript status',
        () async {
      final project = _project('an-status');
      await saveManuscript(project, [
        _chapter('ch-1',
            title: 'Done',
            status: ManuscriptNodeStatus.complete,
            scenes: [_scene('ch-1', 'sc-1', content: _words(10))]),
        _chapter('ch-2',
            title: 'Working',
            status: ManuscriptNodeStatus.draft,
            scenes: [_scene('ch-2', 'sc-2')]),
        _chapter('ch-3',
            title: 'Planned',
            status: ManuscriptNodeStatus.planned,
            scenes: [_scene('ch-3', 'sc-3')]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.chaptersByStatus, {
        'complete': 1,
        'draft': 1,
        'planned': 1,
      });
      expect(summary.completedChapterCount, 1);
      expect(summary.draftChapterCount, 1);
      expect(summary.manuscriptStatus, 'Drafting');
    });

    test('all chapters complete marks the manuscript Complete', () async {
      final project = _project('an-complete');
      await saveManuscript(project, [
        _chapter('ch-1',
            title: 'One',
            status: ManuscriptNodeStatus.complete,
            scenes: [_scene('ch-1', 'sc-1', content: _words(10))]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.manuscriptStatus, 'Complete');
    });

    test('any revising chapter marks the manuscript Revising', () async {
      final project = _project('an-revising');
      await saveManuscript(project, [
        _chapter('ch-1',
            title: 'One',
            status: ManuscriptNodeStatus.revising,
            scenes: [_scene('ch-1', 'sc-1', content: _words(10))]),
        _chapter('ch-2', title: 'Two', scenes: [_scene('ch-2', 'sc-2')]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.manuscriptStatus, 'Revising');
    });
  });

  group('story ecosystem', () {
    test('character count matches the Characters Studio query and skips '
        'deleted records', () async {
      final project = _project('an-characters');
      await saveManuscript(project, const []);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin');
      await characters.createCharacter(id: 'char-3', displayName: 'Ghost');
      await characters.records.deleteRecord('char-3');

      final summary = await serviceFor(project).getSummary();

      expect(summary.characterCount, 2);
    });

    test('characters with profiles need data beyond the identity seed',
        () async {
      final project = _project('an-profiles');
      await saveManuscript(project, const []);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(
        id: 'char-full',
        displayName: 'Mara Voss',
        fields: {'identity.role': 'Protagonist'},
      );
      await characters.createCharacter(id: 'char-bare', displayName: 'Edrin');

      final summary = await serviceFor(project).getSummary();

      expect(summary.characterCount, 2);
      expect(summary.charactersWithProfiles, 1);
    });

    test('characters with relationships come from the connection engine',
        () async {
      final project = _project('an-relationships');
      await saveManuscript(project, const []);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin');
      await characters.createCharacter(id: 'char-3', displayName: 'Loner');
      await characters.connectCharacter(
        characterId: 'char-1',
        targetId: 'char-2',
        typeId: 'friendOf',
        direction: RecordLinkDirection.undirected,
      );

      final summary = await serviceFor(project).getSummary();

      expect(summary.charactersWithRelationships, 2);
    });

    test('characters referenced by the manuscript match scene content',
        () async {
      final project = _project('an-references');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: 'Mara walked into the hall.'),
        ]),
      ]);

      final summary = await serviceFor(project).getSummary();

      expect(summary.charactersReferencedInManuscript, 1);
    });

    test('plot counts split threads by their Plot Studio status', () async {
      final project = _project('an-plot');
      await saveManuscript(project, const []);
      final plot = PlotService(projectId: project.id, repository: repository);
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-active',
        typeId: 'plotline',
        name: 'The Rebellion',
        fields: {'plotStatus': 'active'},
      ));
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-resolved',
        typeId: 'plotline',
        name: 'The Betrayal',
        fields: {'plotStatus': 'resolved'},
      ));
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-abandoned',
        typeId: 'plotline',
        name: 'The Cut Subplot',
        fields: {'plotStatus': 'abandoned'},
      ));

      final summary = await serviceFor(project).getSummary();

      expect(summary.plotRecordCount, 3);
      expect(summary.activePlotThreadCount, 1);
      expect(summary.completedPlotThreadCount, 1);
    });

    test('timeline events come from the TimelineService and exclude '
        'calendars', () async {
      final project = _project('an-timeline');
      await saveManuscript(project, const []);
      final timeline =
          TimelineService(projectId: project.id, repository: repository);
      await timeline.createCalendar(
        const TimelineCalendar(
          id: 'cal-1',
          name: 'Court Calendar',
          months: [TimelineCalendarMonth(name: 'Ember', length: 30)],
        ),
      );
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-1', name: 'The Fall'),
      );
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-2', name: 'The Coronation'),
      );

      final summary = await serviceFor(project).getSummary();

      expect(summary.timelineEventCount, 2);
    });

    test('research counts records of both research type ids', () async {
      final project = _project('an-research');
      await saveManuscript(project, const []);
      final records =
          RecordService(projectId: project.id, repository: repository);
      await records
          .createRecord(researchRecord('res-1', 'research-entry', project.id));
      await records
          .createRecord(researchRecord('res-2', 'research', project.id));
      await records
          .createRecord(researchRecord('res-3', 'research-entry', project.id));
      await records.deleteRecord('res-3');

      final summary = await serviceFor(project).getSummary();

      expect(summary.researchItemCount, 2);
    });

    test('records from other projects never leak into the summary', () async {
      final project = _project('an-isolated');
      final other = _project('an-other');
      await saveManuscript(project, const []);
      await saveManuscript(other, const []);
      final characters =
          CharacterService(projectId: other.id, repository: repository);
      await characters.createCharacter(id: 'char-x', displayName: 'Elsewhere');

      final summary = await serviceFor(project).getSummary();

      expect(summary.characterCount, 0);
    });
  });

  group('data safety', () {
    test('calculating analytics does not modify source records', () async {
      final project = _project('an-immutability');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(42)),
        ]),
      ]);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara');
      final plot = PlotService(projectId: project.id, repository: repository);
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'plotline',
        name: 'The Rebellion',
      ));

      final recordsBefore = jsonEncode(
        (await repository.recordsByProject(project.id))
            .map((record) => record.toJson())
            .toList(),
      );
      final preferences = await SharedPreferences.getInstance();
      final manuscriptBefore =
          preferences.getString('author_studio.manuscript_studio.${project.id}');

      await serviceFor(project).getSummary();

      final recordsAfter = jsonEncode(
        (await repository.recordsByProject(project.id))
            .map((record) => record.toJson())
            .toList(),
      );
      final manuscriptAfter =
          preferences.getString('author_studio.manuscript_studio.${project.id}');

      expect(recordsAfter, recordsBefore);
      expect(manuscriptAfter, manuscriptBefore);
    });

    test('repeated calculations return consistent results', () async {
      final project = _project('an-repeatable', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara');

      final service = serviceFor(project);
      final first = await service.getSummary();
      final second = await service.getSummary();

      expect(second.totalWordCount, first.totalWordCount);
      expect(second.chapterCount, first.chapterCount);
      expect(second.sceneCount, first.sceneCount);
      expect(second.characterCount, first.characterCount);
      expect(second.percentTowardTarget, first.percentTowardTarget);
      expect(second.wordsRemaining, first.wordsRemaining);
      expect(second.manuscriptStatus, first.manuscriptStatus);
    });
  });

  group('architecture', () {
    test('analytics is a derivation layer over existing services', () {
      final source = File('lib/analytics_service.dart').readAsStringSync();
      // Reuses the canonical sources.
      expect(source, contains('ManuscriptStore'));
      expect(source, contains('CharacterService'));
      expect(source, contains('PlotService'));
      expect(source, contains('TimelineService'));
      expect(source, contains('DriftConnectedDomainRepository'));
      // Owns no storage of its own.
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'package:drift")));
      expect(source, isNot(contains('sqlite')));
      // Defines no duplicate domain models.
      expect(source, isNot(contains('class ManuscriptChapter ')));
      expect(source, isNot(contains('class ManuscriptScene ')));
      expect(source, isNot(contains('class AuthorRecord ')));
      expect(source, isNot(contains('class StarterProject ')));
      // Never writes: derivation only.
      expect(source, isNot(contains('createRecord')));
      expect(source, isNot(contains('updateRecord')));
      expect(source, isNot(contains('deleteRecord')));
      expect(source, isNot(contains('saveStudio')));
      expect(source, isNot(contains('.save(')));
    });

    test('the summary is reproducible: nothing analytics-shaped persists',
        () async {
      final project = _project('an-no-persist');
      await saveManuscript(project, const []);
      final preferences = await SharedPreferences.getInstance();
      final keysBefore = preferences.getKeys();

      await serviceFor(project).getSummary();

      expect(preferences.getKeys(), keysBefore);
      expect(
        preferences.getKeys().where((key) => key.contains('analytics')),
        isEmpty,
      );
    });
  });
}
