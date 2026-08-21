/// World Board ↔ Analytics Studio — the integration contract.
///
/// Analytics is the canonical aggregation layer. The World Board renders the
/// summary it produces. These tests exist to make that one-way arrow provable
/// rather than aspirational: if a future change lets the board work a number
/// out for itself, the numbers here stop matching and the guards below stop
/// holding.
library;

import 'dart:io';

import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:author_studio_v1/world_board/world_board_models.dart';
import 'package:author_studio_v1/world_board/world_board_service.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 20, 10);

StarterProject _project(String id, {int wordGoal = 80000}) => StarterProject(
      id: id,
      title: 'House of Shadows and Saints',
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
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: 1,
      content: content,
      status: ManuscriptNodeStatus.draft,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

ManuscriptChapter _chapter(
  String id, {
  required String title,
  required List<ManuscriptScene> scenes,
}) =>
    ManuscriptChapter(
      id: id,
      title: title,
      order: 1,
      status: ManuscriptNodeStatus.draft,
      scenes: scenes,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

/// An [AnalyticsService] that records how it was used, so a test can prove the
/// board went through it rather than around it.
class _RecordingAnalyticsService extends AnalyticsService {
  _RecordingAnalyticsService({
    required super.project,
    required super.repository,
    required super.manuscriptStore,
  });

  int summaryCalls = 0;

  @override
  Future<AnalyticsSummary> getSummary() {
    summaryCalls += 1;
    return super.getSummary();
  }
}

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

  AnalyticsService analyticsFor(StarterProject project) => AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  WorldBoardService boardFor(StarterProject project) => WorldBoardService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  /// Persists a manuscript through the Manuscript Studio's own store, so both
  /// layers read exactly what that Studio owns.
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
          currentSceneId: chapters.isEmpty || chapters.first.scenes.isEmpty
              ? ''
              : chapters.first.scenes.first.id,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: 2,
        ),
        persistLegacyText: false,
      );

  /// A project with something in every domain both layers can see.
  Future<void> seedEcosystem(StarterProject project) async {
    await saveManuscript(project, [
      _chapter('ch-1', title: 'The Drowned Gate', scenes: [
        _scene('ch-1', 'sc-1', title: 'Arrival', content: _words(400)),
        _scene('ch-1', 'sc-2', title: 'The Bell', content: _words(350)),
      ]),
      _chapter('ch-2', title: 'Ashfall', scenes: [
        _scene('ch-2', 'sc-3', title: 'Smoke', content: _words(250)),
      ]),
    ]);

    final characters =
        CharacterService(projectId: project.id, repository: repository);
    await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
    await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');
    await characters.createCharacter(id: 'char-3', displayName: 'Sena Bright');

    final timeline =
        TimelineService(projectId: project.id, repository: repository);
    await timeline.createEvent(
      const TimelineEventDraft(id: 'tl-1', name: 'Battle of Dawn'),
    );
    await timeline.createEvent(
      const TimelineEventDraft(id: 'tl-2', name: 'Council at Sunset'),
    );

    final plot = PlotService(projectId: project.id, repository: repository);
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'plot-1',
      typeId: 'story',
      name: 'The Glass Crown',
      fields: {'plotStatus': 'active'},
    ));
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'plot-2',
      typeId: 'story',
      name: 'The Long Silence',
      fields: {'plotStatus': 'resolved'},
    ));

    final world = WorldService(projectId: project.id, repository: repository);
    await world.createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');

    await RecordService(projectId: project.id, repository: repository)
        .createRecord(
      AuthorRecord(
        id: 'res-1',
        typeId: 'research-entry',
        scopeType: RecordScopeType.project,
        scopeId: project.id,
        projectId: project.id,
        title: 'Harbour trade routes',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  group('the board consumes the analytics summary', () {
    test('loading the board goes through AnalyticsService', () async {
      final project = _project('wba-consumes');
      await seedEcosystem(project);
      final analytics = _RecordingAnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

      final snapshot = await WorldBoardService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
        analytics: analytics,
      ).load();

      expect(analytics.summaryCalls, 1,
          reason: 'the board must ask analytics for the summary, exactly once');
      expect(snapshot.project.wordCount, 1000);
    });

    test('the board builds its own analytics service for its own project', () {
      final project = _project('wba-default-analytics');

      final analytics = boardFor(project).analytics;

      expect(analytics.project.id, project.id);
      expect(analytics.repository, same(repository));
      expect(analytics.manuscriptStore, same(manuscriptStore));
    });

    test('an analytics service for another project is rejected outright', () {
      expect(
        () => WorldBoardService(
          project: _project('wba-mine'),
          repository: repository,
          manuscriptStore: manuscriptStore,
          analytics: analyticsFor(_project('wba-theirs')),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('shared metrics match exactly', () {
    test('every metric both layers report carries the same value', () async {
      final project = _project('wba-parity');
      await seedEcosystem(project);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      // Project overview.
      expect(snapshot.project.projectId, summary.projectId);
      expect(snapshot.project.title, summary.projectName);

      // Manuscript.
      expect(snapshot.project.wordCount, summary.totalWordCount);
      expect(snapshot.project.chapterCount, summary.chapterCount);
      expect(snapshot.project.sceneCount, summary.sceneCount);
      expect(
        snapshot.metric(WorldBoardSection.manuscript).value,
        formatWorldBoardCount(summary.totalWordCount),
      );

      // Writing progress.
      expect(snapshot.project.wordGoal, summary.targetWordCount);
      expect(snapshot.project.progress, summary.progressTowardTarget);
      expect(snapshot.project.wordsRemaining, summary.wordsRemaining);
      expect(
        snapshot.project.progressPercent,
        summary.percentTowardTarget!.round(),
      );

      // Record-backed sections.
      expect(
        snapshot.metric(WorldBoardSection.characters).count,
        summary.characterCount,
      );
      expect(
        snapshot.metric(WorldBoardSection.timelines).count,
        summary.timelineEventCount,
      );
      expect(
        snapshot.metric(WorldBoardSection.plot).count,
        summary.plotRecordCount,
      );
    });

    test('chapter counts match', () async {
      final project = _project('wba-chapters');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [_scene('ch-1', 'sc-1')]),
        _chapter('ch-2', title: 'Two', scenes: [_scene('ch-2', 'sc-2')]),
        _chapter('ch-3', title: 'Three', scenes: [_scene('ch-3', 'sc-3')]),
      ]);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.chapterCount, 3);
      expect(snapshot.project.chapterCount, summary.chapterCount);
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.manuscript);
      expect(branch.count, summary.chapterCount);
    });

    test('scene counts match', () async {
      final project = _project('wba-scenes');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1'),
          _scene('ch-1', 'sc-2'),
        ]),
        _chapter('ch-2', title: 'Two', scenes: [_scene('ch-2', 'sc-3')]),
      ]);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.sceneCount, 3);
      expect(snapshot.project.sceneCount, summary.sceneCount);
      expect(
        snapshot.metric(WorldBoardSection.manuscript).caption,
        '2 chapters · 3 scenes',
      );
    });

    test('character counts match, deletions included', () async {
      final project = _project('wba-characters');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');
      await characters.softDeleteCharacter('char-2');

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.characterCount, 1);
      expect(
        snapshot.metric(WorldBoardSection.characters).count,
        summary.characterCount,
      );
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.characters);
      expect(branch.count, summary.characterCount);
    });

    test('timeline counts match', () async {
      final project = _project('wba-timeline');
      final timeline =
          TimelineService(projectId: project.id, repository: repository);
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-1', name: 'Battle of Dawn'),
      );
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-2', name: 'Council at Sunset'),
      );

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.timelineEventCount, 2);
      expect(
        snapshot.metric(WorldBoardSection.timelines).count,
        summary.timelineEventCount,
      );
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.timelines);
      expect(branch.count, summary.timelineEventCount);
    });

    test('plot counts match', () async {
      final project = _project('wba-plot');
      final plot = PlotService(projectId: project.id, repository: repository);
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'story',
        name: 'The Glass Crown',
        fields: {'plotStatus': 'active'},
      ));
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-2',
        typeId: 'story',
        name: 'The Long Silence',
        fields: {'plotStatus': 'resolved'},
      ));

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.plotRecordCount, 2);
      expect(
        snapshot.metric(WorldBoardSection.plot).count,
        summary.plotRecordCount,
      );
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.plot);
      expect(branch.count, summary.plotRecordCount);
    });

    test('research stays analytics-only, so there is nothing to disagree about',
        () async {
      final project = _project('wba-research');
      await seedEcosystem(project);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      // Analytics counts research; the board has no research tile to show it
      // in, and adding one would be a Phase 2 UI change. What matters here is
      // that the board never derives a research count of its own.
      expect(summary.researchItemCount, 1);
      expect(
        WorldBoardSection.values.map((section) => section.name),
        isNot(contains('research')),
      );
      expect(snapshot.metrics.keys, WorldBoardSection.values);
    });

    test("worlds stay the board's own metric, read from the World Studio",
        () async {
      final project = _project('wba-worlds');
      final world = WorldService(projectId: project.id, repository: repository);
      await world.createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');
      await world.createWorldRecord(id: 'loc-2', title: 'The Drowned Gate');

      final snapshot = await boardFor(project).load();
      final direct = await world.worldRecords(includeArchived: false);

      // AnalyticsSummary has no world-building metric, so this one is left
      // where it was rather than invented into analytics.
      expect(snapshot.metric(WorldBoardSection.worlds).count, direct.length);
      expect(snapshot.metric(WorldBoardSection.worlds).count, 2);
    });
  });

  group('the two layers move together', () {
    test('changing the manuscript word count changes both', () async {
      final project = _project('wba-word-change', wordGoal: 10000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(500)),
        ]),
      ]);

      final firstSummary = await analyticsFor(project).getSummary();
      final firstBoard = await boardFor(project).load();
      expect(firstBoard.project.wordCount, firstSummary.totalWordCount);
      expect(firstSummary.totalWordCount, 500);

      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(1500)),
        ]),
      ]);

      final secondSummary = await analyticsFor(project).getSummary();
      final secondBoard = await boardFor(project).load();

      expect(secondSummary.totalWordCount, 1500);
      expect(secondBoard.project.wordCount, secondSummary.totalWordCount);
      expect(secondBoard.project.progress, secondSummary.progressTowardTarget);
      expect(secondBoard.project.wordsRemaining, secondSummary.wordsRemaining);
      expect(
        secondBoard.metric(WorldBoardSection.manuscript).value,
        formatWorldBoardCount(secondSummary.totalWordCount),
      );
    });

    test('changing the word goal changes both', () async {
      final project = _project('wba-goal-change', wordGoal: 1000);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);

      final tight = _project('wba-goal-change', wordGoal: 1000);
      final loose = _project('wba-goal-change', wordGoal: 5000);

      final tightSummary = await analyticsFor(tight).getSummary();
      final tightBoard = await boardFor(tight).load();
      final looseSummary = await analyticsFor(loose).getSummary();
      final looseBoard = await boardFor(loose).load();

      expect(tightBoard.project.wordGoal, tightSummary.targetWordCount);
      expect(tightBoard.project.progress, tightSummary.progressTowardTarget);
      expect(tightBoard.project.wordsRemaining, tightSummary.wordsRemaining);
      expect(tightBoard.project.progressPercent, 25);

      expect(looseBoard.project.wordGoal, looseSummary.targetWordCount);
      expect(looseBoard.project.progress, looseSummary.progressTowardTarget);
      expect(looseBoard.project.wordsRemaining, looseSummary.wordsRemaining);
      expect(looseBoard.project.progressPercent, 5);
    });

    test('overshooting the goal clamps on the board exactly as in analytics',
        () async {
      final project = _project('wba-overshot', wordGoal: 500);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(1200)),
        ]),
      ]);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.progressTowardTarget, 1.0);
      expect(summary.wordsRemaining, 0);
      expect(snapshot.project.progress, summary.progressTowardTarget);
      expect(snapshot.project.progressPercent, 100);
      expect(snapshot.project.wordsRemaining, summary.wordsRemaining);
    });
  });

  group('project isolation', () {
    test("one project's analytics never reach another project's board",
        () async {
      final mine = _project('wba-iso-mine');
      final theirs = _project('wba-iso-theirs');
      await seedEcosystem(mine);
      await saveManuscript(theirs, const []);

      final mineSummary = await analyticsFor(mine).getSummary();
      final theirsSummary = await analyticsFor(theirs).getSummary();
      final mineBoard = await boardFor(mine).load();
      final theirsBoard = await boardFor(theirs).load();

      expect(mineSummary.totalWordCount, 1000);
      expect(theirsSummary.totalWordCount, 0);

      expect(mineBoard.project.wordCount, mineSummary.totalWordCount);
      expect(theirsBoard.project.wordCount, theirsSummary.totalWordCount);

      expect(theirsBoard.project.projectId, theirs.id);
      expect(theirsBoard.project.chapterCount, 0);
      expect(theirsBoard.project.sceneCount, 0);
      for (final section in const [
        WorldBoardSection.characters,
        WorldBoardSection.worlds,
        WorldBoardSection.timelines,
        WorldBoardSection.plot,
      ]) {
        expect(theirsBoard.metric(section).count, 0,
            reason: '${section.name} must not cross the project boundary');
      }
      expect(theirsBoard.activity, isEmpty);
      expect(theirsBoard.isNewWorld, isTrue);
    });

    test('loading one board does not cache anything for the next', () async {
      final mine = _project('wba-cache-mine');
      final theirs = _project('wba-cache-theirs');
      await seedEcosystem(mine);
      await saveManuscript(theirs, const []);

      // Load the busy project first: a global cache would leak into the next.
      await boardFor(mine).load();
      final theirsBoard = await boardFor(theirs).load();
      final mineAgain = await boardFor(mine).load();

      expect(theirsBoard.project.wordCount, 0);
      expect(theirsBoard.metric(WorldBoardSection.characters).count, 0);
      expect(mineAgain.project.wordCount, 1000);
      expect(mineAgain.metric(WorldBoardSection.characters).count, 3);
    });
  });

  group('safe edges', () {
    test('an empty project is safe on both layers', () async {
      final project = _project('wba-empty', wordGoal: 0);
      await saveManuscript(project, const []);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.totalWordCount, 0);
      expect(snapshot.project.wordCount, 0);
      expect(snapshot.project.chapterCount, 0);
      expect(snapshot.project.sceneCount, 0);
      expect(snapshot.project.hasManuscript, isFalse);
      expect(snapshot.metric(WorldBoardSection.manuscript).isEmpty, isTrue);
      expect(snapshot.metric(WorldBoardSection.manuscript).caption, '');
      expect(snapshot.isNewWorld, isTrue);
    });

    test('a missing word goal reports no progress rather than a false 100%',
        () async {
      final project = _project('wba-no-goal', wordGoal: 0);
      await saveManuscript(project, [
        _chapter('ch-1', title: 'One', scenes: [
          _scene('ch-1', 'sc-1', content: _words(250)),
        ]),
      ]);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.hasWritingTarget, isFalse);
      expect(summary.progressTowardTarget, isNull);
      expect(summary.wordsRemaining, isNull);

      expect(snapshot.project.wordGoal, 0);
      expect(snapshot.project.progress, 0);
      expect(snapshot.project.progressPercent, 0);
      expect(snapshot.project.wordsRemaining, 0);
      expect(snapshot.project.wordCount, 250);
    });

    test('a negative word goal is normalised the way analytics normalises it',
        () async {
      final project = _project('wba-negative-goal', wordGoal: -5000);
      await saveManuscript(project, const []);

      final summary = await analyticsFor(project).getSummary();
      final snapshot = await boardFor(project).load();

      expect(summary.targetWordCount, 0);
      expect(snapshot.project.wordGoal, summary.targetWordCount);
      expect(snapshot.project.progress, 0);
      expect(snapshot.project.wordsRemaining, 0);
    });
  });

  group('read-only', () {
    test('loading the board through analytics writes nothing', () async {
      final project = _project('wba-readonly');
      await seedEcosystem(project);

      final recordsBefore = (await repository.recordsByProject(project.id))
          .map((record) => record.id)
          .toList();
      final auditBefore = (await repository.snapshot()).auditEvents.length;
      final preferences = await SharedPreferences.getInstance();
      final keysBefore = preferences.getKeys().toSet();
      final manuscriptBefore = preferences
          .getString('author_studio.manuscript_studio.${project.id}');

      await boardFor(project).load();
      await boardFor(project).load();

      final recordsAfter = (await repository.recordsByProject(project.id))
          .map((record) => record.id)
          .toList();
      final auditAfter = (await repository.snapshot()).auditEvents.length;

      expect(recordsAfter, recordsBefore);
      expect(auditAfter, auditBefore);
      expect(preferences.getKeys().toSet(), keysBefore);
      expect(
        preferences
            .getString('author_studio.manuscript_studio.${project.id}'),
        manuscriptBefore,
      );
    });

    test('no analytics history is written anywhere', () async {
      final project = _project('wba-no-history');
      await seedEcosystem(project);

      await boardFor(project).load();

      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys()) {
        final lower = key.toLowerCase();
        expect(lower, isNot(contains('analytics')));
        expect(lower, isNot(contains('session')));
        expect(lower, isNot(contains('world_board')));
        expect(lower, isNot(contains('worldboard')));
      }
    });
  });

  group('architecture guardrails', () {
    /// The file's code with comment lines removed, so prose describing a
    /// forbidden construct is never mistaken for using one.
    String codeOf(String path) => File(path)
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n');

    List<String> worldBoardSourcePaths() => Directory('lib/world_board')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.dart'))
        .toList();

    test('the board reaches analytics for its aggregates', () {
      final source = codeOf('lib/world_board/world_board_service.dart');
      expect(source, contains('AnalyticsService'));
      expect(source, contains('getSummary()'));
      expect(source, contains('summary.totalWordCount'));
      expect(source, contains('summary.chapterCount'));
      expect(source, contains('summary.sceneCount'));
      expect(source, contains('summary.characterCount'));
      expect(source, contains('summary.timelineEventCount'));
      expect(source, contains('summary.plotRecordCount'));
      expect(source, contains('summary.targetWordCount'));
    });

    test('the board carries no second word-count implementation', () {
      for (final path in worldBoardSourcePaths()) {
        final source = codeOf(path);
        for (final forbidden in const [
          // Counting words is the Manuscript Studio's job and the analytics
          // layer's to aggregate.
          '.split(',
          'RegExp(',
          'wordCount +=',
          'countWords',
          'words.length',
          // Re-reading and re-seeding the manuscript would be a second way for
          // a project to have chapters, scenes, and words.
          'loadStudio(',
          'loadLegacyChapterSeeds',
          'ManuscriptChapterSeed',
        ]) {
          expect(source, isNot(contains(forbidden)),
              reason: '$path must not contain $forbidden');
        }
      }
    });

    test('the board calculates no analytics ratio of its own', () {
      for (final path in worldBoardSourcePaths()) {
        final source = codeOf(path);
        for (final forbidden in const [
          '/ wordGoal',
          '/ targetWordCount',
          'wordGoal -',
          'targetWordCount -',
          '.clamp(',
          'hasWritingTarget',
          'progressTowardTarget =',
          'percentTowardTarget',
        ]) {
          expect(source, isNot(contains(forbidden)),
              reason: '$path must not contain $forbidden');
        }
      }
    });

    test('AnalyticsService remains the canonical calculation layer', () {
      final source = codeOf('lib/analytics_service.dart');
      // The formulas live here, and only here.
      expect(source, contains('progressTowardTarget'));
      expect(source, contains('int? get wordsRemaining'));
      expect(source, contains('.clamp('));
      expect(source, contains('totalWordCount / targetWordCount'));

      for (final path in worldBoardSourcePaths()) {
        final board = codeOf(path);
        expect(board, isNot(contains('totalWordCount / targetWordCount')));
        expect(board, isNot(contains('double? get progressTowardTarget')));
      }
    });

    test('the integration introduced no duplicate analytics model', () {
      final declarations = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('class AnalyticsSummary {') ||
            source.contains('class AnalyticsSummary extends') ||
            source.contains('class AnalyticsChapterStat {')) {
          declarations.add(entity.path);
        }
      }
      expect(declarations, ['lib/analytics_service.dart']);

      for (final path in worldBoardSourcePaths()) {
        final source = codeOf(path);
        expect(source, isNot(contains('class AnalyticsSummary')));
        expect(source, isNot(contains('class AnalyticsChapterStat')));
      }
    });

    test('the integration introduced no persistence of any kind', () {
      final sources = [
        'lib/analytics_service.dart',
        ...worldBoardSourcePaths(),
      ];
      for (final path in sources) {
        final source = codeOf(path);
        for (final forbidden in const [
          'SharedPreferences',
          'DriftDatabase',
          'extends Table',
          'GeneratedDatabase',
          'NativeDatabase',
          'driftDatabase',
          'saveRecord(',
          'createRecord(',
          'updateRecord(',
          'deleteRecord(',
          'saveStudio(',
        ]) {
          expect(source, isNot(contains(forbidden)),
              reason: '$path must not contain $forbidden');
        }
      }
    });

    test('no new database table was introduced', () {
      final declared = database.allTables
          .map((table) => table.actualTableName.toLowerCase())
          .toList();
      for (final name in declared) {
        expect(name, isNot(contains('analytic')));
        expect(name, isNot(contains('world_board')));
        expect(name, isNot(contains('worldboard')));
        expect(name, isNot(contains('session_history')));
      }

      // Tables are declared by the persistence layer alone.
      for (final path in [
        'lib/analytics_service.dart',
        ...worldBoardSourcePaths(),
      ]) {
        expect(codeOf(path), isNot(contains('@DriftDatabase')));
      }
    });
  });
}
