/// Integration tests for the Intelligence Layer against a real database.
///
/// The detector unit tests prove each rule in isolation. These prove the
/// service reads the project correctly: that it sees what the Studios wrote,
/// that soft-deleted records and ghost manuscript nodes stay out of the report,
/// and — in the read-only group — that analysing a project changes nothing.
library;

import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/intelligence/intelligence_models.dart';
import 'package:author_studio_v1/intelligence/intelligence_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 3, 1);

StarterProject _project(String id) => StarterProject(
      id: id,
      title: 'House of Shadows and Saints',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: const ['Act I'],
      chapters: const [
        StarterChapter(title: 'Chapter 1', prompt: 'Begin', scenes: ['Opening']),
      ],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

ManuscriptScene _scene(
  String chapterId,
  String id, {
  required String title,
  required String content,
  String location = '',
  String pov = '',
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: 0,
      content: content,
      status: ManuscriptNodeStatus.draft,
      location: location,
      pov: pov,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

ManuscriptChapter _chapter(
  String id, {
  required String title,
  List<ManuscriptScene> scenes = const [],
}) =>
    ManuscriptChapter(
      id: id,
      title: title,
      order: 0,
      status: ManuscriptNodeStatus.draft,
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

  IntelligenceService serviceFor(StarterProject project) =>
      IntelligenceService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

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

  group('reading the project', () {
    test('finds a character who never reaches the page', () async {
      final project = _project('int-orphan');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1',
              title: 'Arrival', content: 'The harbour lay under fog.'),
        ]),
      ]);
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      final report = await serviceFor(project).analyze();

      final orphans = report.forCondition(StructuralCondition.orphanEntity);
      expect(orphans, hasLength(1));
      expect(orphans.single.title, contains('Mara Voss'));
    });

    test('a character written into the prose is an unlinked mention, not an '
        'orphan', () async {
      final project = _project('int-mention');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1',
              title: 'Arrival', content: 'Mara Voss walked the seawall.'),
        ]),
      ]);
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      final report = await serviceFor(project).analyze();

      expect(report.forCondition(StructuralCondition.orphanEntity), isEmpty);
      expect(
        report.forCondition(StructuralCondition.unlinkedMention),
        hasLength(1),
      );
    });

    test('counts world entities that have no manuscript connection', () async {
      final project = _project('int-world');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);
      final world = WorldService(projectId: project.id, repository: repository);
      await world.createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');
      await world.createWorldRecord(id: 'loc-2', title: 'The Drowned Gate');

      final report = await serviceFor(project).analyze();

      expect(report.totalWorldEntities, 2);
      expect(report.connectedWorldEntities, 0);
      expect(report.unusedWorldEntities, 2);
      expect(
        report.forCondition(StructuralCondition.unusedWorldbuilding).single
            .title,
        '2 world entities have no manuscript connections',
      );
    });

    test('a connected world entity counts as reaching the manuscript',
        () async {
      final project = _project('int-world-linked');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);
      final world = WorldService(projectId: project.id, repository: repository);
      await world.createWorldRecord(id: 'loc-1', title: 'Ashfall Harbor');
      await ConnectionEngine(scopeId: project.id, repository: repository)
          .connect(sourceId: 'loc-1', targetId: 'sc-1', typeId: 'appearsIn');

      final report = await serviceFor(project).analyze();

      expect(report.connectedWorldEntities, 1);
      expect(report.unusedWorldEntities, 0);
    });

    test('finds a plotline that holds no scenes', () async {
      final project = _project('int-plot');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);
      await PlotService(projectId: project.id, repository: repository)
          .createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'plotline',
        name: 'The Glass Crown',
        fields: {'plotStatus': 'active'},
      ));

      final report = await serviceFor(project).analyze();

      final orphaned = report.forCondition(StructuralCondition.orphanPlot);
      expect(orphaned, hasLength(1));
      expect(orphaned.single.title, contains('The Glass Crown'));
    });

    test('an empty project reports nothing', () async {
      final project = _project('int-empty');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'Chapter One'),
      ]);

      final report = await serviceFor(project).analyze();

      expect(report.isClean, isTrue);
      expect(report.hasManuscript, isFalse);
    });

    test('a soft-deleted character is not reported', () async {
      final project = _project('int-deleted');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog rolled in.'),
        ]),
      ]);
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await RecordService(projectId: project.id, repository: repository)
          .deleteRecord('char-1');

      final report = await serviceFor(project).analyze();

      expect(report.forCondition(StructuralCondition.orphanEntity), isEmpty);
    });

    test('a ghost manuscript node cannot satisfy a connection', () async {
      // Deleting a scene leaves its node row and every link pointing at it
      // (risk R-1). A plotline connected only to a deleted scene is still
      // orphaned, and the survey must see that.
      final project = _project('int-ghost');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
          _scene('ch-1', 'sc-2', title: 'The Bell', content: 'Bells.'),
        ]),
      ]);
      await PlotService(projectId: project.id, repository: repository)
          .createPlotRecord(const PlotRecordDraft(
        id: 'plot-1',
        typeId: 'plotline',
        name: 'The Glass Crown',
        fields: {'plotStatus': 'active'},
      ));
      await ConnectionEngine(scopeId: project.id, repository: repository)
          .connect(sourceId: 'plot-1', targetId: 'sc-2', typeId: 'appearsIn');

      // Before the deletion the plotline holds a scene.
      var report = await serviceFor(project).analyze();
      expect(report.forCondition(StructuralCondition.orphanPlot), isEmpty);

      // Remove the scene from the manuscript. Its node row and its link
      // survive; the prose does not.
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);

      expect(await repository.manuscriptNodeById('sc-2'), isNotNull,
          reason: 'the ghost node is expected to survive; that is risk R-1');

      report = await serviceFor(project).analyze();
      expect(report.forCondition(StructuralCondition.orphanPlot), hasLength(1));
    });

    test('finds research in use with no source', () async {
      final project = _project('int-research');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);
      final records =
          RecordService(projectId: project.id, repository: repository);
      await records.createRecord(AuthorRecord(
        id: 'res-1',
        typeId: 'research-entry',
        scopeType: RecordScopeType.project,
        scopeId: project.id,
        projectId: project.id,
        title: 'Venetian glassmaking',
        createdAt: timestamp,
        updatedAt: timestamp,
      ));
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await ConnectionEngine(scopeId: project.id, repository: repository)
          .connect(
              sourceId: 'res-1', targetId: 'char-1', typeId: 'documents');

      final report = await serviceFor(project).analyze();

      expect(
        report.forCondition(StructuralCondition.researchGap),
        hasLength(1),
      );
    });
  });

  group('read-only', () {
    test('analysing a project writes nothing', () async {
      final project = _project('int-readonly');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1',
              title: 'Arrival',
              content: 'Mara Voss walked the seawall.',
              location: 'Ashfall Harbor'),
        ]),
      ]);
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');
      await WorldService(projectId: project.id, repository: repository)
          .createWorldRecord(id: 'loc-1', title: 'The Drowned Gate');

      final recordsBefore = (await repository.recordsByProject(project.id))
          .map((record) => record.id)
          .toList();
      final linksBefore = (await repository.linksByScope(project.id))
          .map((link) => link.id)
          .toList();
      final snapshotBefore = await repository.snapshot();
      final auditBefore = snapshotBefore.auditEvents.length;
      final versionsBefore = snapshotBefore.versions.length;
      final nodesBefore = snapshotBefore.manuscriptNodes.length;
      final preferences = await SharedPreferences.getInstance();
      final keysBefore = preferences.getKeys().toSet();
      final manuscriptBefore = preferences
          .getString('author_studio.manuscript_studio.${project.id}');

      await serviceFor(project).analyze();
      await serviceFor(project).analyze();

      final snapshotAfter = await repository.snapshot();

      expect(
        (await repository.recordsByProject(project.id))
            .map((record) => record.id)
            .toList(),
        recordsBefore,
      );
      expect(
        (await repository.linksByScope(project.id))
            .map((link) => link.id)
            .toList(),
        linksBefore,
      );
      expect(snapshotAfter.auditEvents.length, auditBefore);
      expect(snapshotAfter.versions.length, versionsBefore);
      expect(snapshotAfter.manuscriptNodes.length, nodesBefore);
      expect(preferences.getKeys().toSet(), keysBefore);
      expect(
        preferences.getString('author_studio.manuscript_studio.${project.id}'),
        manuscriptBefore,
      );
    });

    test('no intelligence state is persisted anywhere', () async {
      final project = _project('int-no-state');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1', title: 'Arrival', content: 'Fog.'),
        ]),
      ]);

      await serviceFor(project).analyze();

      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys()) {
        final lower = key.toLowerCase();
        expect(lower, isNot(contains('intelligence')));
        expect(lower, isNot(contains('finding')));
        expect(lower, isNot(contains('structural')));
      }
    });

    test('a finding is never promoted to a link', () async {
      // Invariant I-9: a derived relationship must never masquerade as a
      // persisted one. An unlinked mention is exactly such a relationship, and
      // reporting it must not create the connection it is reporting the
      // absence of.
      final project = _project('int-no-promotion');
      await saveManuscript(project, [
        _chapter('ch-1', title: 'The Drowned Gate', scenes: [
          _scene('ch-1', 'sc-1',
              title: 'Arrival', content: 'Mara Voss walked the seawall.'),
        ]),
      ]);
      await CharacterService(projectId: project.id, repository: repository)
          .createCharacter(id: 'char-1', displayName: 'Mara Voss');

      final report = await serviceFor(project).analyze();
      expect(
        report.forCondition(StructuralCondition.unlinkedMention),
        hasLength(1),
      );

      expect(await repository.linksByScope(project.id), isEmpty);
    });
  });
}
