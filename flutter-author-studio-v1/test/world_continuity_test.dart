import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/continuity_actions.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/world_continuity.dart';
import 'package:author_studio_v1/world_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectId = 'project-world-continuity';
  final timestamp = DateTime.utc(2026, 8, 20);
  const intelligence = WorldContinuityIntelligence();

  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late WorldService worlds;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    worlds = WorldService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> place({
    required String id,
    required String title,
    String typeId = 'city',
    Map<String, Object?> fields = const {},
  }) =>
      worlds.createWorldRecord(
        id: id,
        title: title,
        typeId: typeId,
        fields: fields,
        timestamp: timestamp,
      );

  Future<WorldContinuityReport> analyze(String id) async {
    final record = (await worlds.getWorldRecord(id))!;
    return intelligence.analyze(
      record: record,
      records: await worlds.worldRecords(),
      links: await worlds.connectionsFor(id),
      knownNames: WorldContinuityIntelligence.knownNames(
        await worlds.connectableRecords(),
      ),
      hierarchy: await worlds.hierarchy(),
      locationFieldIds: await worlds.locationReferenceFieldIds(record),
    );
  }

  test('an unlinked mention becomes a link recommendation', () async {
    await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Salt caravans leave Noxmere for Ashfall each week.'},
    );

    final report = await analyze('noxmere');
    expect(report.findings, hasLength(1));
    final finding = report.findings.single;
    expect(finding.actionKind, ContinuityActionKind.link);
    expect(finding.targetId, 'ashfall');
    expect(finding.warning.severity, ContinuitySeverity.notice);
    expect(report.summary.issues.single.recommendation, isNotEmpty);
    expect(report.findingFor(report.summary.issues.single), same(finding));
  });

  test('an existing connection resolves the mention recommendation', () async {
    await place(id: 'ashfall', title: 'Ashfall', typeId: 'region');
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Salt caravans leave Noxmere for Ashfall each week.'},
    );
    await worlds.connectRecord(
      sourceId: 'noxmere',
      targetId: 'ashfall',
      typeId: 'relatedTo',
    );

    expect((await analyze('noxmere')).isClean, isTrue);
  });

  test('aliases are matched and archived records are ignored', () async {
    await place(
      id: 'ashfall',
      title: 'Ashfall',
      typeId: 'region',
      fields: {
        'alternateNames': ['The Burned Plain'],
      },
    );
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Caravans cross The Burned Plain in summer.'},
    );

    expect((await analyze('noxmere')).findings.single.targetId, 'ashfall');

    await worlds.archiveWorldRecord('ashfall');
    expect((await analyze('noxmere')).isClean, isTrue);
  });

  test('short and partial-word mentions produce no noise', () async {
    await place(id: 'ash', title: 'Ash', typeId: 'region');
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {'summary': 'Ashfall smoke drifts over the harbour.'},
    );

    expect((await analyze('noxmere')).isClean, isTrue);
  });

  test('a roster field naming a missing person becomes a create action',
      () async {
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {
        'importantPeople': ['Serrin Vale'],
      },
    );

    final report = await analyze('noxmere');
    expect(report.findings, hasLength(1));
    expect(report.findings.single.actionKind, ContinuityActionKind.create);
    expect(report.findings.single.missingName, 'Serrin Vale');
    expect(
      report.findings.single.warning.type,
      ContinuityWarningType.unknownCharacter,
    );
    expect(report.summary.score, lessThan(100));
  });

  test('a place roster field naming a missing place becomes a create action',
      () async {
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {
        'nearbyLocations': ['Grey Quay'],
      },
    );

    final report = await analyze('noxmere');
    expect(report.findings.single.actionKind, ContinuityActionKind.create);
    expect(
      report.findings.single.warning.type,
      ContinuityWarningType.unknownLocation,
    );

    final actions = ContinuityActionService(
      projectId: projectId,
      repository: repository,
    );
    final result = await actions.createForRecommendation(
      report.summary.issues.single,
      name: 'Grey Quay',
      confirmed: true,
      recheck: () async => (await analyze('noxmere')).findings.any(
            (finding) => finding.missingName == 'Grey Quay',
          ),
    );
    expect(result.status, ContinuityActionStatus.resolved);
    expect(
      (await worlds.worldRecords()).map((record) => record.title),
      contains('Grey Quay'),
    );
  });

  test('a name owned by another studio is never reported as missing',
      () async {
    await repository.putRecord(AuthorRecord(
      id: 'serrin',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: 'Serrin Vale',
      templateId: 'character',
      createdAt: timestamp,
      updatedAt: timestamp,
    ));
    await place(
      id: 'noxmere',
      title: 'Noxmere',
      fields: {
        'importantPeople': ['Serrin Vale'],
      },
    );

    final report = await analyze('noxmere');
    expect(
      report.findings.where((finding) =>
          finding.warning.type == ContinuityWarningType.unknownCharacter),
      isEmpty,
    );
  });

  test('a template-declared location reference is checked too', () async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await place(
      id: 'kingdom',
      title: 'Kingdom of Ash',
      typeId: 'country',
      fields: {'capital': 'Emberhold'},
    );

    final report = await analyze('kingdom');
    expect(
      report.findings.map((finding) => finding.missingName),
      contains('Emberhold'),
    );
  });

  test('a route with detached endpoints is flagged as impossible travel',
      () async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await place(id: 'vaeryn', title: 'Vaeryn', typeId: 'world');
    await place(id: 'noxmere', title: 'Noxmere');
    await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
    await worlds.setParent(childId: 'noxmere', parentId: 'aethel');
    await worlds.setParent(childId: 'greyquay', parentId: 'vaeryn');
    await worlds.createRoute(
      id: 'salt-road',
      title: 'Salt Road',
      startId: 'noxmere',
      endId: 'greyquay',
    );

    final report = await analyze('salt-road');
    final travel = report.findings.where((finding) =>
        finding.warning.type == ContinuityWarningType.impossibleTravel);
    expect(travel, hasLength(1));
    expect(travel.single.actionKind, ContinuityActionKind.review);
    expect(travel.single.warning.severity, ContinuitySeverity.critical);
    expect(travel.single.warning.message, contains('Aethel'));
    expect(travel.single.warning.message, contains('Vaeryn'));
  });

  test('a route inside one world raises no travel warning', () async {
    await place(id: 'aethel', title: 'Aethel', typeId: 'world');
    await place(id: 'noxmere', title: 'Noxmere');
    await place(id: 'greyquay', title: 'Grey Quay', typeId: 'town');
    await worlds.setParent(childId: 'noxmere', parentId: 'aethel');
    await worlds.setParent(childId: 'greyquay', parentId: 'aethel');
    await worlds.createRoute(
      id: 'salt-road',
      title: 'Salt Road',
      startId: 'noxmere',
      endId: 'greyquay',
    );

    final report = await analyze('salt-road');
    expect(
      report.findings.where((finding) =>
          finding.warning.type == ContinuityWarningType.impossibleTravel),
      isEmpty,
    );
  });

  test('findings are capped so the panel stays readable', () async {
    const capped = WorldContinuityIntelligence(maxFindingsPerRecord: 2);
    for (var index = 0; index < 5; index += 1) {
      await place(
        id: 'place-$index',
        title: 'Distinct Place $index',
        typeId: 'town',
      );
    }
    final record = await place(
      id: 'hub',
      title: 'Hub',
      fields: {
        'summary': [
          for (var index = 0; index < 5; index += 1) 'Distinct Place $index',
        ].join(', '),
      },
    );

    final report = capped.analyze(
      record: record,
      records: await worlds.worldRecords(),
      links: const [],
      knownNames: const {},
    );
    expect(report.findings, hasLength(2));
    expect(report.summary.issues, hasLength(2));
  });
}
