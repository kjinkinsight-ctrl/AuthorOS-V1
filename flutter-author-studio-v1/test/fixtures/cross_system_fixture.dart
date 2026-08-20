import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/branch_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/core/record_inspector.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete_service.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/core/version_audit_service.dart';
import 'package:author_studio_v1/migrations/legacy_reference_migration.dart';
import 'package:author_studio_v1/migrations/legacy_reference_models.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';

class CrossSystemFixture {
  const CrossSystemFixture._();

  static const projectA = 'project-endovier';
  static const projectB = 'project-other';
  static const seriesId = 'series-endovier';
  static const bookId = 'book-one';
  static const branchId = 'branch-what-if';

  static const kaliId = 'character-kali';
  static const endovierId = 'location-endovier';
  static const widowNetworkId = 'faction-widow-network';
  static const houseNoxmereId = 'organisation-house-noxmere';
  static const knifeId = 'item-red-knife';
  static const codexId = 'codex-house-noxmere';
  static const timelineId = 'timeline-fall-noxmere';
  static const plotId = 'plot-red-widow';
  static const characterArcId = 'character-arc-kali';
  static const firstBeatId = 'beat-return-to-endovier';
  static const secondBeatId = 'beat-confront-house-noxmere';
  static const sceneId = 'scene-three';
  static const chapterId = 'chapter-fourteen';
  static const bookNodeId = 'book-one-record';
  static const branchItemId = 'item-branch-relic';
  static const hiddenRecordId = houseNoxmereId;
  static const legacyOwnerId = 'codex-legacy-owner';
  static const safeRecordId = 'author-note-safe';
  static const warningRecordId = 'author-note-warning';

  static final timestamp = DateTime.utc(2026, 8, 20, 12);

  static Future<CrossSystemFixtureContext> build(
    DriftConnectedDomainRepository repository,
  ) async {
    final recordsA = RecordService(projectId: projectA, repository: repository);
    final branchesA =
        BranchService(projectId: projectA, repository: repository);
    final connectionsA = ConnectionEngine(
      scopeId: projectA,
      repository: repository,
    );
    final historyA = VersionAuditService(
      projectId: projectA,
      repository: repository,
    );
    final manuscriptA = ManuscriptStore(repository: repository);

    await repository.putRecordTypeDefinition(const RecordTypeDefinition(
      id: 'protagonist',
      name: 'Protagonist',
      categoryId: 'characters',
      baseTypeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectA,
      fields: [
        RecordFieldDefinition(
          id: 'centralGoal',
          label: 'Central goal',
          type: RecordFieldType.longText,
          order: 200,
        ),
      ],
      sections: [],
      templateVersion: 2,
    ));

    final kali = await recordsA.createRecord(_record(
      kaliId,
      'character',
      'Kali Vale',
      timestamp,
      seriesId: seriesId,
      bookId: bookId,
      templateId: 'protagonist',
      templateVersion: 1,
      tags: const ['protagonist', 'red-widow'],
      fields: const {
        'identity.fullName': 'Kali Vale',
        'centralGoal': 'Escape Endovier',
        'summary': 'A cartographer tied to House Noxmere.',
      },
    ));
    final initialKaliVersion =
        (await historyA.getVersionHistory(recordId: kaliId)).single;
    await recordsA.createRecord(_record(
      endovierId,
      'location',
      'Endovier',
      timestamp.add(const Duration(seconds: 1)),
      scopeType: RecordScopeType.series,
      scopeId: seriesId,
      seriesId: seriesId,
      fields: const {'summary': 'The northern realm around House Noxmere.'},
    ));
    await recordsA.createRecord(_record(
      widowNetworkId,
      'faction',
      'Widow Network',
      timestamp.add(const Duration(seconds: 2)),
      seriesId: seriesId,
      fields: const {'summary': 'A covert Endovier faction.'},
    ));
    await recordsA.createRecord(_record(
      houseNoxmereId,
      'organisation',
      'House Noxmere',
      timestamp.add(const Duration(seconds: 3)),
      seriesId: seriesId,
      fields: const {'summary': 'An old Endovier house.'},
    ));
    await recordsA.createRecord(_record(
      knifeId,
      'item',
      "Kali's Red Knife",
      timestamp.add(const Duration(seconds: 4)),
      scopeType: RecordScopeType.book,
      scopeId: bookId,
      seriesId: seriesId,
      bookId: bookId,
      fields: const {'summary': 'A knife carried through Chapter 14.'},
    ));
    await recordsA.createRecord(_record(
      codexId,
      'research-entry',
      'House Noxmere Codex',
      timestamp.add(const Duration(seconds: 5)),
      seriesId: seriesId,
      fields: const {
        'summary': 'House Noxmere history, Endovier holdings, and Kali Vale.'
      },
    ));
    await recordsA.createRecord(_record(
      timelineId,
      'historical-event',
      'The Fall of House Noxmere',
      timestamp.add(const Duration(seconds: 6)),
      seriesId: seriesId,
      fields: const {'summary': 'The Endovier event that changes Kali Vale.'},
    ));
    await recordsA.createRecord(_record(
      plotId,
      'plotline',
      'The Red Widow Arc',
      timestamp.add(const Duration(seconds: 7)),
      bookId: bookId,
      fields: const {'summary': 'Kali confronts House Noxmere in Scene 3.'},
    ));
    await recordsA.createRecord(_record(
      characterArcId,
      'character-arc',
      "Kali's Return",
      timestamp.add(const Duration(seconds: 8)),
      bookId: bookId,
      fields: const {
        'purpose': 'Kali chooses responsibility over escape.',
        'plotStatus': 'active',
      },
    ));
    await recordsA.createRecord(_record(
      firstBeatId,
      'beat',
      'Return to Endovier',
      timestamp.add(const Duration(seconds: 9)),
      bookId: bookId,
      fields: const {
        'purpose': 'Kali crosses back into Endovier.',
        'planningOrder': 1,
        'narrativeOrder': 1,
      },
    ));
    await recordsA.createRecord(_record(
      secondBeatId,
      'beat',
      'Confront House Noxmere',
      timestamp.add(const Duration(seconds: 10)),
      bookId: bookId,
      fields: const {
        'purpose': 'Kali confronts the house with the red knife.',
        'planningOrder': 2,
        'narrativeOrder': 2,
        'dependencies': [firstBeatId],
      },
    ));
    await recordsA.createRecord(_record(
      legacyOwnerId,
      'general-lore',
      'Legacy Character Notes',
      timestamp.add(const Duration(seconds: 11)),
      fields: const {
        'legacyRelationships': {'protagonist': 'Kali Vale'},
        'unknownLegacyData': {'preserve': true},
      },
    ));
    await recordsA.createRecord(_record(
      warningRecordId,
      'author-note',
      'Historical Note',
      timestamp.add(const Duration(seconds: 12)),
    ));
    await repository.putRecord(_record(
      safeRecordId,
      'author-note',
      'Archived Empty Note',
      timestamp.add(const Duration(seconds: 13)),
      status: AuthorRecordStatus.archived,
    ));
    await recordsA.createRecord(_record(
      seriesId,
      'series',
      'Endovier Chronicles',
      timestamp.add(const Duration(seconds: 14)),
      scopeType: RecordScopeType.series,
      scopeId: seriesId,
      seriesId: seriesId,
      fields: const {'summary': 'The Endovier series.'},
    ));
    await recordsA.createRecord(_record(
      bookNodeId,
      'book',
      'Book One',
      timestamp.add(const Duration(seconds: 15)),
      scopeType: RecordScopeType.book,
      scopeId: bookId,
      seriesId: seriesId,
      bookId: bookId,
      fields: const {'summary': 'The first Endovier book.'},
    ));
    await recordsA.createRecord(_record(
      chapterId,
      'chapter',
      'Chapter 14',
      timestamp.add(const Duration(seconds: 16)),
      scopeType: RecordScopeType.book,
      scopeId: bookId,
      seriesId: seriesId,
      bookId: bookId,
      fields: const {'content': 'Kali returns to House Noxmere.'},
    ));
    await recordsA.createRecord(_record(
      sceneId,
      'scene',
      'Scene 3: The Red Knife',
      timestamp.add(const Duration(seconds: 17)),
      scopeType: RecordScopeType.book,
      scopeId: bookId,
      seriesId: seriesId,
      bookId: bookId,
      fields: const {'content': 'Kali enters Endovier carrying the red knife.'},
    ));
    await manuscriptA.saveStudio(ManuscriptProjectSummary(
      projectId: projectA,
      manuscriptTitle: 'Book One',
      chapters: [
        ManuscriptChapter(
          id: chapterId,
          title: 'Chapter 14',
          order: 14,
          status: ManuscriptNodeStatus.draft,
          createdAt: timestamp,
          updatedAt: timestamp,
          scenes: [
            ManuscriptScene(
              id: sceneId,
              chapterId: chapterId,
              title: 'Scene 3: The Red Knife',
              order: 3,
              content: 'Kali enters Endovier carrying the red knife.',
              status: ManuscriptNodeStatus.draft,
              pov: kaliId,
              location: endovierId,
              relationships: const [
                SceneRelationship(
                  id: 'scene-kali',
                  type: SceneRelationshipType.character,
                  targetId: kaliId,
                ),
                SceneRelationship(
                  id: 'scene-endovier',
                  type: SceneRelationshipType.location,
                  targetId: endovierId,
                ),
                SceneRelationship(
                  id: 'scene-timeline',
                  type: SceneRelationshipType.timelineEvent,
                  targetId: timelineId,
                ),
                SceneRelationship(
                  id: 'scene-plot',
                  type: SceneRelationshipType.plotPoint,
                  targetId: secondBeatId,
                ),
              ],
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          ],
        ),
      ],
      currentChapterId: chapterId,
      currentSceneId: sceneId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: 1,
    ));

    final links = <String, RecordLink>{};
    Future<void> connect(
      String key,
      String source,
      String target,
      String type, {
      RecordLinkDirection direction = RecordLinkDirection.directed,
      Map<String, Object?> metadata = const {},
      int minute = 1,
    }) async {
      links[key] = await connectionsA.connect(
        sourceId: source,
        targetId: target,
        typeId: type,
        direction: direction,
        metadata: metadata,
        timestamp: timestamp.add(Duration(minutes: minute)),
      );
    }

    await connect(
      'characterFaction',
      kaliId,
      widowNetworkId,
      'memberOf',
      metadata: const {'rank': 'Founder'},
      minute: 1,
    );
    await connect('characterLocation', kaliId, endovierId, 'livesIn',
        minute: 2);
    await connect('characterItem', kaliId, knifeId, 'owns', minute: 3);
    await connect('characterScene', kaliId, sceneId, 'appearsIn', minute: 4);
    await connect('sceneChapter', sceneId, chapterId, 'partOf', minute: 5);
    await connect('chapterBook', chapterId, bookNodeId, 'partOf', minute: 6);
    await connect('codexCharacter', codexId, kaliId, 'documents', minute: 7);
    await connect('codexLocation', codexId, endovierId, 'documents', minute: 8);
    await connect('timelineCharacter', timelineId, kaliId, 'involves',
        minute: 9);
    await connect('timelineLocation', timelineId, endovierId, 'occursAt',
        minute: 10);
    await connect(
      'plotCharacter',
      plotId,
      kaliId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 11,
    );
    await connect(
      'plotScene',
      plotId,
      sceneId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 12,
    );
    await connect(
      'plotLocation',
      plotId,
      endovierId,
      'occursAt',
      minute: 13,
    );
    await connect(
      'codexTimeline',
      codexId,
      timelineId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 14,
    );
    await connect(
      'codexPlot',
      codexId,
      plotId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 15,
    );
    await connect(
      'timelinePlot',
      timelineId,
      plotId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 16,
    );
    await connect('sceneLocation', sceneId, endovierId, 'occursAt', minute: 17);
    await connect(
      'sceneTimeline',
      sceneId,
      timelineId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 18,
    );
    await connect('characterArc', kaliId, characterArcId, 'hasArc', minute: 19);
    await connect('arcPlot', characterArcId, plotId, 'partOf', minute: 20);
    await connect('firstBeatPlot', firstBeatId, plotId, 'partOf', minute: 21);
    await connect('secondBeatPlot', secondBeatId, plotId, 'partOf', minute: 22);
    await connect(
      'secondBeatScene',
      secondBeatId,
      sceneId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 23,
    );
    await connect(
      'organisationFaction',
      houseNoxmereId,
      widowNetworkId,
      'relatedTo',
      direction: RecordLinkDirection.undirected,
      minute: 24,
    );

    await branchesA.createBranch(StoryBranch(
      id: branchId,
      projectId: projectA,
      name: 'What if Kali never left Endovier?',
      kind: BranchKind.whatIf,
      createdAt: timestamp.add(const Duration(minutes: 20)),
    ));
    await branchesA.overrideRecord(
      branchId,
      kaliId,
      title: 'Kali Remained',
      fields: const {'centralGoal': 'Remain in Endovier'},
      canonStatus: CanonStatus.alternate,
      timestamp: timestamp.add(const Duration(minutes: 21)),
    );
    await branchesA.createRecord(
      branchId,
      _record(
        branchItemId,
        'item',
        'Alternate Red Knife',
        timestamp.add(const Duration(minutes: 22)),
        scopeType: RecordScopeType.branch,
        scopeId: branchId,
        branchId: branchId,
        canonStatus: CanonStatus.alternate,
        fields: const {'summary': 'A branch-only relic.'},
      ),
      timestamp: timestamp.add(const Duration(minutes: 22)),
    );
    await branchesA.hideRecord(
      branchId,
      hiddenRecordId,
      timestamp: timestamp.add(const Duration(minutes: 23)),
    );
    await branchesA.hideConnection(
      branchId,
      links['characterItem']!.id,
      timestamp: timestamp.add(const Duration(minutes: 24)),
    );
    await branchesA.addConnection(
      branchId,
      RecordLink(
        id: 'branch-kali-alternate-knife',
        sourceId: kaliId,
        targetId: branchItemId,
        typeId: 'owns',
        scopeId: projectA,
        createdAt: timestamp.add(const Duration(minutes: 25)),
        updatedAt: timestamp.add(const Duration(minutes: 25)),
      ),
    );

    final recordsB = RecordService(projectId: projectB, repository: repository);
    await recordsB.createRecord(_record(
      'project-b-kali',
      'character',
      'Kali Vale',
      timestamp,
      projectId: projectB,
      fields: const {'identity.fullName': 'Kali Vale'},
    ));
    await recordsB.createRecord(_record(
      'project-b-endovier',
      'location',
      'Endovier',
      timestamp.add(const Duration(seconds: 1)),
      projectId: projectB,
    ));

    return CrossSystemFixtureContext(
      repository: repository,
      records: recordsA,
      branches: branchesA,
      connections: connectionsA,
      manuscript: manuscriptA,
      search:
          UniversalSearchService(projectId: projectA, repository: repository),
      history: historyA,
      inspector:
          UniversalRecordInspector(projectId: projectA, repository: repository),
      safeDelete:
          SafeDeleteService(projectId: projectA, repository: repository),
      migration: LegacyReferenceMigrationService(
        projectId: projectA,
        repository: repository,
      ),
      initialKaliVersionId: initialKaliVersion.id,
      links: Map.unmodifiable(links),
    );
  }

  static AuthorRecord _record(
    String id,
    String typeId,
    String title,
    DateTime createdAt, {
    String projectId = projectA,
    RecordScopeType scopeType = RecordScopeType.project,
    String? scopeId,
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus canonStatus = CanonStatus.canon,
    AuthorRecordStatus status = AuthorRecordStatus.active,
    String? templateId,
    int? templateVersion,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: scopeType,
        scopeId: scopeId ?? projectId,
        projectId: projectId,
        seriesId: seriesId,
        bookId: bookId,
        branchId: branchId,
        canonStatus: canonStatus,
        status: status,
        title: title,
        templateId: templateId,
        templateVersion: templateVersion,
        fields: fields,
        tags: tags,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
}

class CrossSystemFixtureContext {
  const CrossSystemFixtureContext({
    required this.repository,
    required this.records,
    required this.branches,
    required this.connections,
    required this.manuscript,
    required this.search,
    required this.history,
    required this.inspector,
    required this.safeDelete,
    required this.migration,
    required this.initialKaliVersionId,
    required this.links,
  });

  final DriftConnectedDomainRepository repository;
  final RecordService records;
  final BranchService branches;
  final ConnectionEngine connections;
  final ManuscriptStore manuscript;
  final UniversalSearchService search;
  final VersionAuditService history;
  final UniversalRecordInspector inspector;
  final SafeDeleteService safeDelete;
  final LegacyReferenceMigrationService migration;
  final String initialKaliVersionId;
  final Map<String, RecordLink> links;

  static Future<CrossSystemFixtureContext> fromRepository(
    DriftConnectedDomainRepository repository,
  ) async {
    final history = VersionAuditService(
      projectId: CrossSystemFixture.projectA,
      repository: repository,
    );
    final versions = await history.getVersionHistory(
      recordId: CrossSystemFixture.kaliId,
    );
    return CrossSystemFixtureContext(
      repository: repository,
      records: RecordService(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      branches: BranchService(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      connections: ConnectionEngine(
        scopeId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      manuscript: ManuscriptStore(repository: repository),
      search: UniversalSearchService(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      history: history,
      inspector: UniversalRecordInspector(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      safeDelete: SafeDeleteService(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      migration: LegacyReferenceMigrationService(
        projectId: CrossSystemFixture.projectA,
        repository: repository,
      ),
      initialKaliVersionId: versions.first.id,
      links: const {},
    );
  }
}
