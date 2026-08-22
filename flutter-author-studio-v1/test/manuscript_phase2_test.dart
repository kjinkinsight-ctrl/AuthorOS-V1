import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/continuity_actions.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manuscript Studio Phase 2 behaviour, exercised through the same services
/// the workspace UI calls.
void main() {
  const projectId = 'project-manuscript-2';
  final timestamp = DateTime.utc(2026, 8, 20, 9);

  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore store;
  late ManuscriptService manuscriptService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    store = ManuscriptStore(repository: repository);
    manuscriptService = ManuscriptService(
      projectId: projectId,
      repository: repository,
      store: store,
    );
  });

  tearDown(() => database.close());

  Future<ManuscriptProjectSummary> seedManuscript() => manuscriptService.load(
        manuscriptTitle: 'The Blood Price',
        defaultChapters: const [
          ManuscriptChapterSeed(
            title: 'Chapter 01',
            scenes: ['Arrival', 'The Warning'],
          ),
          ManuscriptChapterSeed(
            title: 'Chapter 02',
            scenes: ['The Crossing'],
          ),
        ],
        firstSceneTitle: 'Arrival',
      );

  Future<AuthorRecord> seedCharacter(String id, String name) =>
      CharacterService(projectId: projectId, repository: repository)
          .createCharacter(
        id: id,
        displayName: name,
        timestamp: timestamp,
      );

  Future<AuthorRecord> seedLocation(String id, String name) =>
      WorldService(projectId: projectId, repository: repository)
          .createWorldRecord(
        id: id,
        title: name,
        typeId: 'location',
        timestamp: timestamp,
      );

  group('workspace structure and ordering', () {
    test('chapters and scenes are created through the shared entity store',
        () async {
      var manuscript = await seedManuscript();
      manuscript = await manuscriptService.createChapter(
        manuscript,
        title: 'Chapter 03',
        firstSceneTitle: 'The Blood Moon',
        id: 'chapter-03',
        sceneId: 'scene-blood-moon',
        timestamp: timestamp,
      );

      expect(manuscript.chapters, hasLength(3));
      expect(manuscript.chapters.last.order, 3);

      final node = await repository.manuscriptNodeById('chapter-03');
      expect(node?.nodeType, 'chapter');
      expect(node?.projectId, projectId);

      final sceneNode = await repository.manuscriptNodeById('scene-blood-moon');
      expect(sceneNode?.nodeType, 'scene');
      expect(sceneNode?.extensionData['chapterId'], 'chapter-03');
      expect(sceneNode?.extensionData, isNot(contains('content')));
    });

    test('reordering renumbers scenes and preserves prose', () async {
      var manuscript = await seedManuscript();
      final chapter = manuscript.chapters.first;
      final second = chapter.scenes[1];
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        second.id,
        'The rain had been falling since dawn.',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.moveScene(
        manuscript,
        second.id,
        -1,
        timestamp: timestamp,
      );

      expect(manuscript.chapters.first.scenes.first.id, second.id);
      expect(manuscript.chapters.first.scenes.first.order, 1);
      expect(
        manuscript.chapters.first.scenes.first.content,
        'The rain had been falling since dawn.',
      );

      final reloaded = await seedManuscript();
      expect(reloaded.chapters.first.scenes.first.id, second.id);
      expect(
        reloaded.chapters.first.scenes.first.content,
        'The rain had been falling since dawn.',
      );
    });

    test('a scene moves between chapters and keeps one parent', () async {
      var manuscript = await seedManuscript();
      final sceneId = manuscript.chapters.first.scenes.last.id;
      final targetChapterId = manuscript.chapters.last.id;

      manuscript = await manuscriptService.moveSceneToChapter(
        manuscript,
        sceneId,
        targetChapterId,
        timestamp: timestamp,
      );

      expect(manuscript.chapters.first.scenes, hasLength(1));
      expect(manuscript.chapters.last.scenes, hasLength(2));
      expect(manuscript.chapterOfScene(sceneId)?.id, targetChapterId);
      final node = await repository.manuscriptNodeById(sceneId);
      expect(node?.extensionData['chapterId'], targetChapterId);
    });

    test('word counts and writing progress read from the manuscript store',
        () async {
      var manuscript = await seedManuscript();
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        sceneId,
        'One two three four five.',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.setSceneStatus(
        manuscript,
        sceneId,
        ManuscriptNodeStatus.complete,
        timestamp: timestamp,
      );

      final progress = manuscriptService.progressFor(
        manuscript,
        goalWords: 10,
        today: timestamp,
      );
      expect(progress.wordCount, 5);
      expect(progress.goalProgress, closeTo(0.5, 0.001));
      expect(progress.sceneCount, 3);
      expect(progress.completedScenes, 1);
      expect(progress.wordsWrittenToday, 5);
      expect(progress.remainingWords, 5);

      final chapterProgress = manuscriptService.progressFor(
        manuscript,
        chapter: manuscript.chapters.last,
        goalWords: 10,
        today: timestamp,
      );
      expect(chapterProgress.wordCount, 0);
      expect(chapterProgress.sceneCount, 1);
    });
  });

  group('connected records', () {
    test('a character connects to a scene through the shared engine',
        () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');

      final link = await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: kali.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );

      expect(link.sourceId, kali.id);
      expect(link.targetId, scene.id);

      final connections = await manuscriptService.connectionsFor(scene.id);
      expect(connections, hasLength(1));
      expect(connections.single.recordId, kali.id);
      expect(connections.single.title, 'Kali Vale');
      expect(connections.single.incoming, isTrue);
      // Read from the scene's side the edge is incoming, so the label is the
      // connection type's inverse: this scene *features* Kali. The forward
      // name would read "this scene appears in Kali Vale", which inverts the
      // relationship the author actually recorded.
      expect(connections.single.displayName, 'Features');

      final audits = await manuscriptService.auditFor(kali.id);
      expect(
        audits.where(
          (event) => event.changeType == AuditChangeType.connectionAdded,
        ),
        hasLength(1),
      );
    });

    test('connections reach every connected Studio', () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final character = await seedCharacter('character-cassian', 'Cassian');
      final location = await seedLocation('location-endovier', 'Endovier');
      final plot = await PlotService(
        projectId: projectId,
        repository: repository,
      ).createPlotRecord(
        const PlotRecordDraft(
          id: 'plot-red-widow',
          typeId: 'plotline',
          name: 'Red Widow',
        ),
        timestamp: timestamp,
      );
      final event = await TimelineService(
        projectId: projectId,
        repository: repository,
      ).createEvent(
        const TimelineEventDraft(id: 'event-blood-moon', name: 'Blood Moon'),
        timestamp: timestamp,
      );

      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: character.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: location.id,
        typeId: 'occursAt',
        timestamp: timestamp,
      );
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: plot.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: event.id,
        typeId: 'relatedTo',
        timestamp: timestamp,
      );

      final connections = await manuscriptService.connectionsFor(scene.id);
      expect(
        connections.map((item) => item.recordId),
        containsAll([character.id, location.id, plot.id, event.id]),
      );
      expect(connections.every((item) => item.exists), isTrue);
    });

    test('connection types are offered from the shared registry', () async {
      final types = await manuscriptService.connectionTypesFor(
        nodeKind: ManuscriptNodeKind.scene,
        recordTypeId: 'character',
      );
      expect(types.map((type) => type.id), contains('appearsIn'));
      expect(types.map((type) => type.id), contains('mentionedIn'));
    });

    test('a connection is removed without touching the connected record',
        () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      final link = await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: kali.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );

      await manuscriptService.disconnectNode(link.id, timestamp: timestamp);

      expect(await manuscriptService.connectionsFor(scene.id), isEmpty);
      expect(await repository.recordById(kali.id), isNotNull);
    });

    test('a connection cannot cross projects', () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      await CharacterService(projectId: 'other-project', repository: repository)
          .createCharacter(
        id: 'character-outsider',
        displayName: 'Outsider',
        timestamp: timestamp,
      );

      expect(
        () => manuscriptService.connectNode(
          nodeId: scene.id,
          recordId: 'character-outsider',
          typeId: 'appearsIn',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('search and filtering', () {
    test('a text query is answered by the universal search service', () async {
      var manuscript = await seedManuscript();
      manuscript = await manuscriptService.renameScene(
        manuscript,
        manuscript.chapters.first.scenes.first.id,
        'Nightfall at Endovier',
        timestamp: timestamp,
      );

      final results = await manuscriptService.searchManuscript('Endovier');
      expect(results, isNotEmpty);
      expect(results.first.title, 'Nightfall at Endovier');
      expect(results.first.recordType, 'scene');
    });

    test('filters narrow scenes by status, POV, chapter and prose', () async {
      var manuscript = await seedManuscript();
      final first = manuscript.chapters.first.scenes.first;
      final second = manuscript.chapters.first.scenes.last;
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        first.id,
        pov: 'Kali',
        status: ManuscriptNodeStatus.complete,
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        first.id,
        'The harbour smelled of salt and iron.',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        second.id,
        pov: 'Cassian',
        timestamp: timestamp,
      );

      final byStatus = await manuscriptService.filterScenes(
        manuscript,
        const ManuscriptFilter(statuses: {ManuscriptNodeStatus.complete}),
      );
      expect(byStatus.map((match) => match.scene.id), [first.id]);

      final byPov = await manuscriptService.filterScenes(
        manuscript,
        const ManuscriptFilter(pov: 'Cassian'),
      );
      expect(byPov.map((match) => match.scene.id), [second.id]);

      final byChapter = await manuscriptService.filterScenes(
        manuscript,
        ManuscriptFilter(chapterIds: {manuscript.chapters.last.id}),
      );
      expect(byChapter, hasLength(1));

      final byProse = await manuscriptService.filterScenes(
        manuscript,
        const ManuscriptFilter(query: 'salt and iron'),
      );
      expect(byProse.map((match) => match.scene.id), [first.id]);
      expect(byProse.single.snippet, contains('salt and iron'));

      final empties = await manuscriptService.filterScenes(
        manuscript,
        const ManuscriptFilter(onlyEmpty: true),
      );
      expect(empties.map((match) => match.scene.id), isNot(contains(first.id)));
    });

    test('unconnected and connected filters use the shared link store',
        () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: kali.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );

      final unconnected = await manuscriptService.filterScenes(
        manuscript,
        const ManuscriptFilter(onlyUnconnected: true),
      );
      expect(
        unconnected.map((match) => match.scene.id),
        isNot(contains(scene.id)),
      );

      final connected = await manuscriptService.filterScenes(
        manuscript,
        ManuscriptFilter(connectedRecordId: kali.id),
      );
      expect(connected.map((match) => match.scene.id), [scene.id]);
    });
  });

  group('inspector, history and safe delete', () {
    test('the inspector reports connections, history and validation',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: kali.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.renameScene(
        manuscript,
        scene.id,
        'Arrival at Endovier',
        timestamp: timestamp,
      );

      final inspection = await manuscriptService.inspectNode(
        manuscript,
        scene.id,
      );
      expect(inspection, isNotNull);
      expect(inspection!.nodeKind, ManuscriptNodeKind.scene);
      expect(inspection.title, 'Arrival at Endovier');
      expect(inspection.incomingConnections, hasLength(1));
      expect(inspection.incomingConnections.single.valid, isTrue);
      expect(inspection.references.single.entity.title, 'Kali Vale');
      expect(inspection.references.single.kind, ReferenceKind.universalRecord);
      expect(inspection.history.versionCount, greaterThan(0));
      expect(inspection.validation.state, InspectionValidationState.valid);
      expect(inspection.scope.canonStatus, CanonStatus.canon);
      expect(inspection.safeDelete.knownReferenceCount, 1);
    });

    test('history records every structural change through the shared system',
        () async {
      var manuscript = await seedManuscript();
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await manuscriptService.renameScene(
        manuscript,
        sceneId,
        'Arrival at Dusk',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.setSceneStatus(
        manuscript,
        sceneId,
        ManuscriptNodeStatus.revising,
        timestamp: timestamp.add(const Duration(minutes: 1)),
      );

      final versions = await manuscriptService.historyFor(sceneId);
      expect(versions, hasLength(2));
      expect(versions.first.changeType, AuditChangeType.renamed);
      expect(versions.first.metadata['newTitle'], 'Arrival at Dusk');
      expect(versions.last.changeType, AuditChangeType.statusChanged);
      expect(versions.last.recordType, 'scene');
      expect(versions.last.projectId, projectId);
      expect(versions.last.snapshot, isNot(contains('content')));
    });

    test('a version restores metadata without rewriting prose', () async {
      var manuscript = await seedManuscript();
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await manuscriptService.renameScene(
        manuscript,
        sceneId,
        'First Title',
        timestamp: timestamp,
      );
      final firstVersion = (await manuscriptService.historyFor(sceneId)).last;
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        sceneId,
        'Prose that must survive the rollback.',
        timestamp: timestamp.add(const Duration(minutes: 1)),
      );
      manuscript = await manuscriptService.renameScene(
        manuscript,
        sceneId,
        'Second Title',
        timestamp: timestamp.add(const Duration(minutes: 2)),
      );

      manuscript = await manuscriptService.restoreVersion(
        manuscript,
        firstVersion.id,
        timestamp: timestamp.add(const Duration(minutes: 3)),
      );

      expect(manuscript.sceneById(sceneId)?.title, 'First Title');
      expect(
        manuscript.sceneById(sceneId)?.content,
        'Prose that must survive the rollback.',
      );
    });

    test('deleting a scene is impact-aware and never cascades into records',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        scene.id,
        'Three words here.',
        timestamp: timestamp,
      );
      await manuscriptService.connectNode(
        nodeId: scene.id,
        recordId: kali.id,
        typeId: 'appearsIn',
        timestamp: timestamp,
      );

      final analysis = await manuscriptService.analyzeDelete(
        manuscript,
        scene.id,
      );
      expect(analysis, isNotNull);
      expect(analysis!.disposition, SafeDeleteDisposition.safeWithWarnings);
      expect(analysis.warnings, isNotEmpty);
      expect(analysis.affectedRecords, [kali.id]);
      expect(analysis.canDelete, isTrue);

      final unconfirmed = await manuscriptService.deleteScene(
        manuscript,
        scene.id,
        confirmed: false,
        timestamp: timestamp,
      );
      expect(unconfirmed.sceneById(scene.id), isNotNull);

      manuscript = await manuscriptService.deleteScene(
        manuscript,
        scene.id,
        confirmed: true,
        timestamp: timestamp,
      );

      expect(manuscript.sceneById(scene.id), isNull);
      expect(await repository.recordById(kali.id), isNotNull);
      expect(await repository.backlinks(kali.id), isEmpty);
      final deletions = (await manuscriptService.auditFor(scene.id))
          .where((event) => event.changeType == AuditChangeType.deleted);
      expect(deletions, hasLength(1));
    });

    test('the last chapter cannot be deleted', () async {
      var manuscript = await seedManuscript();
      manuscript = await manuscriptService.deleteChapter(
        manuscript,
        manuscript.chapters.last.id,
        confirmed: true,
        timestamp: timestamp,
      );
      final analysis = await manuscriptService.analyzeDelete(
        manuscript,
        manuscript.chapters.single.id,
      );
      expect(analysis?.disposition, SafeDeleteDisposition.blocked);
      expect(
        () => manuscriptService.deleteChapter(
          manuscript,
          manuscript.chapters.single.id,
          confirmed: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('validation', () {
    test('structural problems are reported per node', () async {
      var manuscript = await seedManuscript();
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await manuscriptService.setSceneStatus(
        manuscript,
        sceneId,
        ManuscriptNodeStatus.complete,
        timestamp: timestamp,
      );

      final issues = await manuscriptService.validateManuscript(manuscript);
      expect(
        issues.where((issue) => issue.code == 'empty-complete-scene'),
        hasLength(1),
      );
      expect(
        issues.firstWhere((issue) => issue.code == 'empty-complete-scene')
            .nodeId,
        sceneId,
      );
    });

    test('a broken scene reference is an error', () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      manuscript = await manuscriptService.save(
        manuscript.copyWith(chapters: [
          for (final chapter in manuscript.chapters)
            chapter.copyWith(scenes: [
              for (final item in chapter.scenes)
                item.id == scene.id
                    ? item.copyWith(relationships: const [
                        SceneRelationship(
                          id: 'relationship-1',
                          type: SceneRelationshipType.character,
                          targetId: 'character-missing',
                          label: 'Ghost',
                        ),
                      ])
                    : item,
            ]),
        ]),
        timestamp: timestamp,
      );

      final issues = await manuscriptService.validateManuscript(manuscript);
      final broken =
          issues.where((issue) => issue.code == 'broken-reference').toList();
      expect(broken, hasLength(1));
      expect(broken.single.isError, isTrue);
      expect(broken.single.message, contains('Ghost'));
    });

    test('a chapter linked to a removed chapter is reported', () async {
      var manuscript = await seedManuscript();
      final first = manuscript.chapters.first;
      final second = manuscript.chapters.last;
      manuscript = await manuscriptService.updateChapterMetadata(
        manuscript,
        first.id,
        linkedChapterIds: [second.id],
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.save(
        manuscript.copyWith(
          chapters: manuscript.chapters
              .where((chapter) => chapter.id != second.id)
              .toList(),
        ),
        timestamp: timestamp,
      );

      final issues = await manuscriptService.validateManuscript(manuscript);
      expect(
        issues.where((issue) => issue.code == 'broken-reference'),
        hasLength(1),
      );
    });
  });

  group('canon and branch protection', () {
    test('canon is read-only while a branch is active', () async {
      final manuscript = await seedManuscript();
      final branched = manuscriptService.forBranch('branch-alt');
      expect(branched.canEditCanon, isFalse);

      final sceneId = manuscript.chapters.first.scenes.first.id;
      expect(
        () => branched.writeSceneBody(manuscript, sceneId, 'Alternate prose.'),
        throwsA(isA<ManuscriptCanonException>()),
      );
      expect(
        () => branched.renameScene(manuscript, sceneId, 'Alternate title'),
        throwsA(isA<ManuscriptCanonException>()),
      );
      expect(
        () => branched.createChapter(manuscript, title: 'Branch chapter'),
        throwsA(isA<ManuscriptCanonException>()),
      );
      expect(
        () => branched.deleteScene(manuscript, sceneId, confirmed: true),
        throwsA(isA<ManuscriptCanonException>()),
      );
    });

    test('branch mode refuses to connect canon to a record', () async {
      final manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      final branched = manuscriptService.forBranch('branch-alt');

      expect(
        () => branched.connectNode(
          nodeId: scene.id,
          recordId: kali.id,
          typeId: 'appearsIn',
        ),
        throwsA(isA<ManuscriptCanonException>()),
      );
      expect(await manuscriptService.connectionsFor(scene.id), isEmpty);
    });

    test('reading stays available while a branch is active', () async {
      final manuscript = await seedManuscript();
      final branched = manuscriptService.forBranch('branch-alt');
      final scene = manuscript.chapters.first.scenes.first;

      final inspection = await branched.inspectNode(manuscript, scene.id);
      expect(inspection?.branchId, 'branch-alt');
      expect(
        await branched.filterScenes(manuscript, const ManuscriptFilter()),
        hasLength(3),
      );
    });
  });

  group('continuity intelligence', () {
    test('an unlinked mention becomes a resolvable link recommendation',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        scene.id,
        'Kali Vale stepped onto the pier without looking back.',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      expect(report.isClean, isFalse);
      final issue = report.summary.issues.single;
      expect(issue.actionKind, ContinuityActionKind.link);
      final finding = report.findingFor(issue)!;
      expect(finding.targetId, kali.id);

      final result = await manuscriptService.resolveContinuity(
        manuscript,
        issue,
        finding,
        confirmed: true,
        timestamp: timestamp,
      );
      expect(result.status, ContinuityActionStatus.resolved);

      final after = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      expect(after.isClean, isTrue);
      expect(await manuscriptService.connectionsFor(scene.id), hasLength(1));
    });

    test('an unknown POV name becomes a create recommendation', () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        scene.id,
        pov: 'Seraphine',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      final issue = report.summary.issues.single;
      expect(issue.type, ContinuityWarningType.unknownCharacter);
      expect(issue.actionKind, ContinuityActionKind.create);

      final result = await manuscriptService.resolveContinuity(
        manuscript,
        issue,
        report.findingFor(issue)!,
        confirmed: true,
        timestamp: timestamp,
      );
      expect(result.status, ContinuityActionStatus.warningRemains);
      expect(result.recordId, isNotNull);

      final created = await repository.recordById(result.recordId!);
      expect(created?.title, 'Seraphine');
      expect(created?.typeId, 'character');
    });

    test('an unknown scene location becomes a create recommendation',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        scene.id,
        location: 'Noxmere Harbor',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      final issue = report.summary.issues.single;
      expect(issue.type, ContinuityWarningType.unknownLocation);
      expect(issue.actionKind, ContinuityActionKind.create);
    });

    test('a POV character who is not connected becomes a review action',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      final kali = await seedCharacter('character-kali', 'Kali Vale');
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        scene.id,
        pov: 'Kali Vale',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      final issue = report.summary.issues.single;
      expect(issue.type, ContinuityWarningType.missingPovPresence);
      expect(issue.actionKind, ContinuityActionKind.review);

      final cancelled = await manuscriptService.resolveContinuity(
        manuscript,
        issue,
        report.findingFor(issue)!,
        confirmed: false,
        timestamp: timestamp,
      );
      expect(cancelled.status, ContinuityActionStatus.cancelled);
      expect(await manuscriptService.connectionsFor(scene.id), isEmpty);

      final applied = await manuscriptService.resolveContinuity(
        manuscript,
        issue,
        report.findingFor(issue)!,
        confirmed: true,
        timestamp: timestamp,
      );
      expect(applied.status, ContinuityActionStatus.resolved);
      final connections = await manuscriptService.connectionsFor(scene.id);
      expect(connections.single.recordId, kali.id);
    });

    test('a name owned by another Studio is never reported as missing',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      await seedLocation('location-endovier', 'Endovier');
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        scene.id,
        location: 'Endovier',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      expect(
        report.summary.issues
            .where((issue) => issue.type == ContinuityWarningType.unknownLocation),
        isEmpty,
      );
    });

    test('continuity recommendations are refused while a branch is active',
        () async {
      var manuscript = await seedManuscript();
      final scene = manuscript.chapters.first.scenes.first;
      await seedCharacter('character-kali', 'Kali Vale');
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        scene.id,
        'Kali Vale waited at the gate.',
        timestamp: timestamp,
      );
      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        scene.id,
      );
      final issue = report.summary.issues.single;

      final result = await manuscriptService.forBranch('branch-alt')
          .resolveContinuity(
        manuscript,
        issue,
        report.findingFor(issue)!,
        confirmed: true,
        timestamp: timestamp,
      );
      expect(result.status, ContinuityActionStatus.failed);
      expect(result.message, contains('branch-alt'));
      expect(await manuscriptService.connectionsFor(scene.id), isEmpty);
    });

    test('a chapter report folds every scene finding together', () async {
      var manuscript = await seedManuscript();
      final chapter = manuscript.chapters.first;
      await seedCharacter('character-kali', 'Kali Vale');
      manuscript = await manuscriptService.writeSceneBody(
        manuscript,
        chapter.scenes.first.id,
        'Kali Vale climbed the stair.',
        timestamp: timestamp,
      );
      manuscript = await manuscriptService.updateSceneMetadata(
        manuscript,
        chapter.scenes.last.id,
        location: 'Noxmere Harbor',
        timestamp: timestamp,
      );

      final report = await manuscriptService.analyzeContinuity(
        manuscript,
        chapter.id,
      );
      expect(report.summary.issues, hasLength(2));
      expect(
        report.summary.issues.map((issue) => issue.type),
        containsAll([
          ContinuityWarningType.missingRelationship,
          ContinuityWarningType.unknownLocation,
        ]),
      );
      expect(report.summary.score, lessThan(100));
    });
  });
}
