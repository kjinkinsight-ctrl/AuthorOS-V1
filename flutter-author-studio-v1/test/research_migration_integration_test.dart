import 'package:author_studio_v1/analytics_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/main.dart'
    show AuthorStudioShell, StudioSection;
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/migrations/legacy_research_store.dart';
import 'package:author_studio_v1/migrations/research_migration.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 21, 9);

StarterProject _project(String id) => StarterProject(
      id: id,
      title: 'The Hollow Court',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: const [],
      chapters: const [],
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

  LegacyResearchMigrationService serviceFor(String projectId) =>
      LegacyResearchMigrationService(
        projectId: projectId,
        repository: repository,
      );

  Future<void> saveEmptyManuscript(StarterProject project) =>
      manuscriptStore.saveStudio(
        ManuscriptProjectSummary(
          projectId: project.id,
          manuscriptTitle: project.title,
          chapters: const [],
          currentChapterId: '',
          currentSceneId: '',
          createdAt: timestamp,
          updatedAt: timestamp,
          version: 2,
        ),
        persistLegacyText: false,
      );

  group('analytics', () {
    test('migrated research is counted exactly once', () async {
      final project = _project('an-research');
      await saveEmptyManuscript(project);
      await _seed(project.id, {
        ResearchTab.research: const [
          ResearchReference(title: 'One', detail: '', tag: ''),
          ResearchReference(title: 'Two', detail: '', tag: ''),
        ],
        ResearchTab.notes: const [
          ResearchReference(title: 'Three', detail: '', tag: ''),
        ],
      });

      await serviceFor(project.id).migrate(timestamp: timestamp);
      final summary = await AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      ).getSummary();

      expect(summary.researchItemCount, 3);
    });

    test('re-running the migration does not change the count', () async {
      final project = _project('an-research');
      await saveEmptyManuscript(project);
      await _seed(project.id, {
        ResearchTab.research: const [
          ResearchReference(title: 'One', detail: '', tag: ''),
        ],
      });
      final analytics = AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

      await serviceFor(project.id).migrate(timestamp: timestamp);
      final first = await analytics.getSummary();

      // Both a marker-gated re-run and a marker-less re-run.
      await serviceFor(project.id).migrate(timestamp: timestamp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
        ResearchMigrationState(projectId: project.id).storageKey,
      );
      await serviceFor(project.id).migrate(timestamp: timestamp);
      final second = await analytics.getSummary();

      expect(first.researchItemCount, 1);
      expect(second.researchItemCount, 1);
    });

    test('a legacy entry that is still in SharedPreferences is not '
        'double counted', () async {
      final project = _project('an-research');
      await saveEmptyManuscript(project);
      await _seed(project.id, {
        ResearchTab.research: const [
          ResearchReference(title: 'Kept in both', detail: '', tag: ''),
        ],
      });

      await serviceFor(project.id).migrate(timestamp: timestamp);
      final legacy =
          await ProjectResearchStore(projectId: project.id).load();
      final summary = await AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      ).getSummary();

      // The legacy row still exists — analytics counts the canonical record
      // only, because it reads the record system and nothing else.
      expect(legacy[ResearchTab.research], hasLength(1));
      expect(summary.researchItemCount, 1);
    });
  });

  group('universal search', () {
    test('migrated research is searchable by title and by body', () async {
      await _seed('project-a', {
        ResearchTab.research: const [
          ResearchReference(
            title: 'Ashfall harbour tolls',
            detail: 'Doubled after the flood of the ninth year.',
            tag: 'World',
          ),
        ],
      });
      await serviceFor('project-a').migrate(timestamp: timestamp);
      final search = UniversalSearchService(
        projectId: 'project-a',
        repository: repository,
      );

      final byTitle = await search.searchAll('Ashfall');
      final byBody = await search.searchAll('flood');

      expect(byTitle.map((result) => result.title), ['Ashfall harbour tolls']);
      expect(byBody.map((result) => result.title), ['Ashfall harbour tolls']);
      expect(byTitle.single.recordType, researchRecordTypeId);
      expect(byTitle.single.projectId, 'project-a');
      expect(
        searchDestinationForType(byTitle.single.recordType),
        SearchDestination.storyCodex,
      );
    });

    test('search never returns another project\'s migrated research',
        () async {
      await _seed('project-a', {
        ResearchTab.research: const [
          ResearchReference(title: 'Ledger', detail: 'A side.', tag: ''),
        ],
      });
      await _seed('project-b', {
        ResearchTab.research: const [
          ResearchReference(title: 'Ledger', detail: 'B side.', tag: ''),
        ],
      });
      await serviceFor('project-a').migrate(timestamp: timestamp);
      await serviceFor('project-b').migrate(timestamp: timestamp);

      final results = await UniversalSearchService(
        projectId: 'project-a',
        repository: repository,
      ).searchAll('Ledger');

      expect(results, hasLength(1));
      expect(results.single.projectId, 'project-a');
      expect(results.single.snippet, contains('A side.'));
    });
  });

  group('connections', () {
    test('migrated research connects to the record types it documents',
        () async {
      await _seed('project-a', {
        ResearchTab.research: const [
          ResearchReference(title: 'Field notes', detail: '', tag: ''),
        ],
      });
      await serviceFor('project-a').migrate(timestamp: timestamp);
      final researchId =
          (await serviceFor('project-a').migratedRecords()).single.id;

      final records =
          RecordService(projectId: 'project-a', repository: repository);
      const targets = {
        'character': 'character',
        'location': 'location',
        'plot-thread': 'plot-thread',
        'historical-event': 'historical-event',
        'scene': 'scene',
      };
      for (final entry in targets.entries) {
        await records.createRecord(_record(entry.key, entry.value));
      }

      final engine = ConnectionEngine(
        scopeId: 'project-a',
        repository: repository,
      );
      for (final id in targets.keys) {
        await engine.connect(
          sourceId: researchId,
          targetId: id,
          typeId: 'documents',
          timestamp: timestamp,
        );
      }

      final links = await repository.outgoingLinks(researchId);
      expect(links.map((link) => link.targetId), containsAll(targets.keys));
      expect(links.every((link) => link.typeId == 'documents'), isTrue);
    });

    test('a connection cannot cross a project boundary', () async {
      await _seed('project-a', {
        ResearchTab.research: const [
          ResearchReference(title: 'A research', detail: '', tag: ''),
        ],
      });
      await serviceFor('project-a').migrate(timestamp: timestamp);
      final researchId =
          (await serviceFor('project-a').migratedRecords()).single.id;

      await RecordService(projectId: 'project-b', repository: repository)
          .createRecord(_record('foreign-character', 'character',
              projectId: 'project-b'));

      await expectLater(
        ConnectionEngine(scopeId: 'project-a', repository: repository).connect(
          sourceId: researchId,
          targetId: 'foreign-character',
          typeId: 'documents',
          timestamp: timestamp,
        ),
        throwsStateError,
      );
    });
  });

  group('shell trigger', () {
    testWidgets('opening a project runs the migration once for that project',
        (tester) async {
      final calls = <String>[];
      Future<ResearchMigrationOutcome> runner(String projectId) async {
        calls.add(projectId);
        return ResearchMigrationOutcome.nothingToMigrate(projectId);
      }

      await tester.pumpWidget(_host(_project('project-a'), runner));
      await tester.pump();

      expect(calls, ['project-a']);

      // A rebuild with the same project must not migrate again.
      await tester.pumpWidget(_host(_project('project-a'), runner));
      await tester.pump();
      expect(calls, ['project-a']);

      // Switching projects migrates the newly opened one.
      await tester.pumpWidget(_host(_project('project-b'), runner));
      await tester.pump();
      expect(calls, ['project-a', 'project-b']);
    });

    testWidgets('a failing migration does not stop the project opening',
        (tester) async {
      Future<ResearchMigrationOutcome> runner(String projectId) async =>
          throw StateError('migration exploded');

      await tester.pumpWidget(_host(_project('project-a'), runner));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AuthorStudioShell), findsOneWidget);
    });
  });
}

Widget _host(StarterProject project, ResearchMigrationRunner runner) =>
    MaterialApp(
      home: AuthorStudioShell(
        project: project,
        themeId: 'light',
        accentId: 'default',
        onThemeChanged: (_, __) {},
        themeSelection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
        ),
        onThemeSelectionChanged: (_) {},
        initialSection: StudioSection.settings,
        researchMigration: runner,
      ),
    );

Future<void> _seed(
  String projectId,
  Map<ResearchTab, List<ResearchReference>> references,
) =>
    ProjectResearchStore(projectId: projectId).save(references);

AuthorRecord _record(
  String id,
  String typeId, {
  String projectId = 'project-a',
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: id,
      // Characters require a full name; the other types ignore the field.
      fields: {'name': id, 'identity.displayName': id, 'identity.fullName': id},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
