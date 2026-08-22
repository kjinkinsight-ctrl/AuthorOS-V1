import 'dart:io';

import 'package:author_studio_v1/character_service.dart';
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

StarterProject _project(String id, {int wordGoal = 80000}) => StarterProject(
      id: id,
      title: 'House of Shadows and Saints',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const ['Act I'],
      chapters: const [
        StarterChapter(title: 'Chapter 1', prompt: 'Begin', scenes: ['Opening']),
      ],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
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

  WorldBoardService serviceFor(StarterProject project) => WorldBoardService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  group('data', () {
    test('reports the active project as the author world context', () async {
      final project = _project('wb-context');

      final snapshot = await serviceFor(project).load();

      expect(snapshot.project.projectId, project.id);
      expect(snapshot.project.title, 'House of Shadows and Saints');
      expect(snapshot.project.genre, 'Fantasy');
      expect(snapshot.project.projectType, 'Novel');
      expect(snapshot.project.wordGoal, 80000);
      expect(snapshot.metric(WorldBoardSection.projects).count, 1);
    });

    test('manuscript figures come from the Manuscript Studio store', () async {
      final project = _project('wb-manuscript');

      // The manuscript is created first, deliberately. Loading the board used
      // to seed one as a side effect, so this test could read the board first
      // and still find chapters — which meant it was also, silently, asserting
      // that a dashboard read creates a manuscript. It no longer does (R-21),
      // and the claim under test is unchanged: the board's figures come from
      // the Manuscript Studio store rather than from a second source.
      final manuscript = await manuscriptStore.loadStudio(
        project.id,
        manuscriptTitle: project.title,
        defaultChapters: const [],
        firstSceneTitle: project.firstSceneTitle,
      );

      final snapshot = await serviceFor(project).load();

      expect(snapshot.project.wordCount, manuscript.wordCount);
      expect(snapshot.project.chapterCount, manuscript.chapterCount);
      expect(snapshot.project.sceneCount, manuscript.sceneCount);
      expect(snapshot.project.chapterCount, greaterThan(0));
    });

    test('a project with no manuscript reports zero, and stays untouched',
        () async {
      final project = _project('wb-no-manuscript');

      final snapshot = await serviceFor(project).load();

      expect(snapshot.project.chapterCount, 0);
      expect(snapshot.project.sceneCount, 0);
      expect(snapshot.project.wordCount, 0);
      expect(
        (await repository.snapshot()).manuscriptNodes,
        isEmpty,
        reason: 'Loading the World Board created manuscript nodes. Opening a '
            'dashboard must not be the same action as creating a manuscript.',
      );
    });

    test('character count matches the Characters Studio record query',
        () async {
      final project = _project('wb-characters');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');

      final snapshot = await serviceFor(project).load();
      final direct = await repository.recordsByTypeAndScope(
        typeId: WorldBoardService.characterTypeId,
        scopeId: project.id,
      );

      expect(snapshot.metric(WorldBoardSection.characters).count, 2);
      expect(snapshot.metric(WorldBoardSection.characters).count, direct.length);
      expect(snapshot.metric(WorldBoardSection.characters).value, '2');
    });

    test('timeline information comes from the existing TimelineService',
        () async {
      final project = _project('wb-timeline');
      final timeline =
          TimelineService(projectId: project.id, repository: repository);
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-1', name: 'Battle of Dawn'),
      );
      await timeline.createEvent(
        const TimelineEventDraft(id: 'tl-2', name: 'Council at Sunset'),
      );

      final snapshot = await serviceFor(project).load();

      expect(snapshot.metric(WorldBoardSection.timelines).count, 2);
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.timelines);
      expect(branch.leaves, containsAll(['Battle of Dawn', 'Council at Sunset']));
    });

    test('plot information comes from the existing PlotService', () async {
      final project = _project('wb-plot');
      final plot = PlotService(projectId: project.id, repository: repository);
      await plot.createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'story',
        name: 'The Glass Crown',
        fields: {'plotStatus': 'active'},
      ));

      final snapshot = await serviceFor(project).load();

      expect(snapshot.metric(WorldBoardSection.plot).count, 1);
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.plot);
      expect(branch.leaves, ['The Glass Crown']);
    });

    test('world information comes from the existing WorldService', () async {
      final project = _project('wb-world');
      final world =
          WorldService(projectId: project.id, repository: repository);
      await world.createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');

      final snapshot = await serviceFor(project).load();

      expect(snapshot.metric(WorldBoardSection.worlds).count, 1);
      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.worlds);
      expect(branch.leaves, ['Ashfall Harbor']);
    });

    test('deleted records leave the board, matching every other Studio',
        () async {
      final project = _project('wb-deleted');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');
      await characters.softDeleteCharacter('char-2');

      final snapshot = await serviceFor(project).load();

      expect(snapshot.metric(WorldBoardSection.characters).count, 1);
    });

    test('recent activity is the shared audit history, newest first', () async {
      final project = _project('wb-activity');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      await characters.createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await characters.createCharacter(id: 'char-2', displayName: 'Edrin Vale');

      final snapshot = await serviceFor(project).load();

      expect(snapshot.activity, isNotEmpty);
      expect(snapshot.activity.first.summary, contains('Edrin Vale'));
      expect(snapshot.activity.first.changeLabel, 'Created');
      for (var index = 1; index < snapshot.activity.length; index += 1) {
        expect(
          snapshot.activity[index].occurredAt.isAfter(
            snapshot.activity[index - 1].occurredAt,
          ),
          isFalse,
          reason: 'activity must read newest first',
        );
      }
    });

    test('branches sample real titles and report what they hide', () async {
      final project = _project('wb-branch-sample');
      final characters =
          CharacterService(projectId: project.id, repository: repository);
      for (var index = 0; index < 5; index += 1) {
        await characters.createCharacter(
          id: 'char-$index',
          displayName: 'Character $index',
        );
      }

      final snapshot = await WorldBoardService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
        branchSampleSize: 3,
      ).load();

      final branch = snapshot.branches
          .firstWhere((entry) => entry.section == WorldBoardSection.characters);
      expect(branch.count, 5);
      expect(branch.leaves, hasLength(3));
      expect(branch.hiddenCount, 2);
      for (final leaf in branch.leaves) {
        expect(leaf, startsWith('Character '));
      }
    });

    test('one project is isolated from another project world', () async {
      final mine = _project('wb-mine');
      final theirs = _project('wb-theirs');
      await CharacterService(projectId: mine.id, repository: repository)
          .createCharacter(id: 'char-mine', displayName: 'Mara Voss');

      final theirSnapshot = await serviceFor(theirs).load();

      expect(theirSnapshot.metric(WorldBoardSection.characters).count, 0);
      expect(theirSnapshot.metric(WorldBoardSection.characters).isEmpty, isTrue);
    });
  });

  group('empty states', () {
    test('every category reports empty for a brand new world', () async {
      final project = _project('wb-empty');

      final snapshot = await serviceFor(project).load();

      for (final section in const [
        WorldBoardSection.characters,
        WorldBoardSection.worlds,
        WorldBoardSection.timelines,
        WorldBoardSection.plot,
      ]) {
        expect(snapshot.metric(section).isEmpty, isTrue,
            reason: '${section.name} must report empty');
        expect(snapshot.metric(section).count, 0);
      }
      expect(snapshot.activity, isEmpty);
    });

    test('every section carries an empty headline, body, and way out', () {
      for (final section in WorldBoardSection.values) {
        expect(section.emptyTitle, isNotEmpty);
        expect(section.emptyBody, isNotEmpty);
        expect(section.openLabel, isNotEmpty);
        expect(section.label, isNotEmpty);
      }
    });

    test('a project with no goal reports no progress rather than a false 100%',
        () async {
      final project = _project('wb-no-goal', wordGoal: 0);

      final snapshot = await serviceFor(project).load();

      expect(snapshot.project.progress, 0);
      expect(snapshot.project.progressPercent, 0);
      expect(snapshot.project.wordsRemaining, 0);
    });
  });

  group('formatting', () {
    test('counts group into thousands', () {
      expect(formatWorldBoardCount(0), '0');
      expect(formatWorldBoardCount(42), '42');
      expect(formatWorldBoardCount(1000), '1,000');
      expect(formatWorldBoardCount(18420), '18,420');
      expect(formatWorldBoardCount(1234567), '1,234,567');
    });

    test('moments read as relative time', () {
      final now = DateTime.utc(2026, 8, 21, 12);
      expect(formatWorldBoardMoment(now, now: now), 'Just now');
      expect(
        formatWorldBoardMoment(now.subtract(const Duration(minutes: 5)),
            now: now),
        '5m ago',
      );
      expect(
        formatWorldBoardMoment(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        formatWorldBoardMoment(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
      expect(
        formatWorldBoardMoment(now.subtract(const Duration(days: 21)), now: now),
        '3w ago',
      );
    });

    test('a percentage is the analytics progress, rounded for the label', () {
      const context = WorldBoardProjectContext(
        projectId: 'p',
        title: 'T',
        genre: 'G',
        projectType: 'Novel',
        wordCount: 40000,
        wordGoal: 80000,
        chapterCount: 4,
        sceneCount: 9,
        // Handed in by the service from AnalyticsSummary; the context clamps
        // nothing itself, so overshoot is proven against the summary in
        // world_board_analytics_integration_test.dart instead.
        progress: 0.5,
        wordsRemaining: 40000,
      );

      expect(context.progressPercent, 50);
    });
  });

  group('architecture', () {
    // The board is a presentation layer over AuthorOS. These are the
    // guarantees that keep it one: no second store, no second schema, no
    // second definition of a character, a timeline event, or a plot record.
    List<File> worldBoardSources() => Directory('lib/world_board')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    /// The file's code with comment lines removed, so prose describing a
    /// forbidden construct is never mistaken for using one.
    String codeOf(File file) => file
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('the World Board ships the files it is supposed to', () {
      final sources = worldBoardSources();
      expect(sources, hasLength(4));
    });

    test('the World Board creates no database and no persistence layer', () {
      for (final file in worldBoardSources()) {
        final source = codeOf(file);
        for (final forbidden in const [
          'SharedPreferences',
          'DriftDatabase',
          'extends Table',
          'GeneratedDatabase',
          'NativeDatabase',
          'driftDatabase',
          'openConnection',
          'jsonEncode',
        ]) {
          expect(source, isNot(contains(forbidden)),
              reason: '${file.path} must not contain $forbidden');
        }
      }
    });

    test('the World Board declares no record types or models of its own', () {
      for (final file in worldBoardSources()) {
        final source = codeOf(file);
        for (final forbidden in const [
          'class AuthorRecord',
          'RecordTypeDefinition(',
          'class TimelineDate',
          'class PlotRecordDraft',
          'class TimelineEventDraft',
          'createRecord(',
          'putRecord',
        ]) {
          expect(source, isNot(contains(forbidden)),
              reason: '${file.path} must not contain $forbidden');
        }
      }
    });

    test('the World Board owns no theme system', () {
      for (final file in worldBoardSources()) {
        final source = codeOf(file);
        expect(source, isNot(contains('ThemeData(')),
            reason: '${file.path} must not build ThemeData');
        expect(source, isNot(contains('Colors.')),
            reason: '${file.path} must not use Colors.*');
        expect(source, isNot(contains('Color(0x')),
            reason: '${file.path} must not hardcode a colour');
        expect(source, isNot(contains('Theme.of(')),
            reason: '${file.path} must resolve tokens through '
                'StudioThemeScope, not Theme.of');
      }
    });

    test('the aggregation layer declares no Flutter imports of its own', () {
      for (final path in const [
        'lib/world_board/world_board_models.dart',
        'lib/world_board/world_board_service.dart',
      ]) {
        final source = codeOf(File(path));
        expect(source, isNot(contains('package:flutter/')),
            reason: '$path must stay free of Flutter');
      }
    });

    test('loading the board writes no records of its own', () async {
      final project = _project('wb-readonly');
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');
      final before = await repository.recordsByProject(project.id);
      final auditBefore = (await repository.snapshot()).auditEvents.length;

      await serviceFor(project).load();
      await serviceFor(project).load();

      final after = await repository.recordsByProject(project.id);
      final auditAfter = (await repository.snapshot()).auditEvents.length;
      expect(after.map((record) => record.id), before.map((r) => r.id));
      expect(auditAfter, auditBefore);
    });

    test('the board stores nothing under a namespace of its own', () async {
      final project = _project('wb-no-namespace');

      await serviceFor(project).load();

      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys()) {
        expect(key.toLowerCase(), isNot(contains('world_board')));
        expect(key.toLowerCase(), isNot(contains('worldboard')));
      }
    });

    test('character identity is the Characters Studio type, not a new one', () {
      expect(WorldBoardService.characterTypeId, 'character');
    });
  });
}
