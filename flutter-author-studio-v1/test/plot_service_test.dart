import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/plot_record_types.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/plot_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/plot_phase_1_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late PlotService plot;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    plot = PlotService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('Plot catalogue and structural templates are data-driven', () async {
    final registry = await plot.records.registry();

    expect(
      PlotRecordTypes.recordTypeIds,
      containsAll(const [
        'story',
        'act',
        'sequence',
        'plotline',
        'subplot',
        'arc',
        'character-arc',
        'relationship-arc',
        'world-arc',
        'goal',
        'motivation',
        'obstacle',
        'stake',
        'conflict',
        'turning-point',
        'beat',
        'reveal',
        'foreshadowing',
        'payoff',
        'climax',
        'resolution',
      ]),
    );
    expect(registry.resolve('act').fields.map((field) => field.id),
        containsAll(['purpose', 'openingState', 'closingState']));
    expect(registry.resolve('beat').fields.map((field) => field.id),
        containsAll(['planningOrder', 'narrativeOrder', 'chronologicalOrder']));
    expect(
      PlotStructureTemplates.templates.map((template) => template.id),
      containsAll(const [
        'three-act',
        'five-act',
        'heros-journey',
        'save-the-cat',
        'seven-point',
        'snowflake',
        'custom',
      ]),
    );
    expect(
      PlotStructureTemplates.templates
          .singleWhere((template) => template.id == 'custom')
          .stages,
      isEmpty,
    );
  });

  test('custom Plot types and story mechanics use Universal Records', () async {
    final custom = PlotRecordTypes.customType(
      id: 'betrayal-beat',
      name: 'Betrayal Beat',
      projectId: 'project-a',
      fields: const [
        RecordFieldDefinition(
          id: 'betrayer',
          label: 'Betrayer',
          type: RecordFieldType.recordReference,
          order: 300,
        ),
      ],
    );
    await plot.registerCustomType(custom);
    final story = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'story',
      typeId: 'story',
      name: 'The Glass Crown',
      fields: {'plotStatus': 'active'},
    ));
    final act = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'act',
      typeId: 'act',
      name: 'Act I',
      fields: {'openingState': 'Peace', 'closingState': 'War'},
    ));
    final sequence = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'sequence',
      typeId: 'sequence',
      name: 'The Broken Treaty',
    ));
    final beat = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'betrayal',
      typeId: 'betrayal-beat',
      name: 'The Adviser Defects',
      fields: {
        'betrayer': 'character-adviser',
        'planningOrder': 2,
        'narrativeOrder': 4,
        'chronologicalOrder': 3,
      },
    ));
    await plot.connect(
        sourceId: story.id, targetId: act.id, typeId: 'contains');
    await plot.connect(
        sourceId: act.id, targetId: sequence.id, typeId: 'contains');
    await plot.connect(
        sourceId: sequence.id, targetId: beat.id, typeId: 'contains');

    expect((await plot.getPlotRecord(beat.id))?.typeId, 'betrayal-beat');
    expect((await plot.query.all()).map((record) => record.id),
        containsAll(['story', 'act', 'sequence', 'betrayal']));
    expect((await plot.getPlotHistory(story.id)), isNotEmpty);
  });

  test(
      'knowledge states, setup payoff, goals, conflicts, and consequences stay distinct',
      () async {
    for (final draft in const [
      PlotRecordDraft(
        id: 'reveal',
        typeId: 'reveal',
        name: 'The Hidden Heir',
        fields: {
          'authorKnowledge': 'The claim is objectively true.',
          'characterKnowledge': [
            {'characterId': 'hero', 'state': 'suspects'}
          ],
          'readerKnowledge': 'The reader saw the sealed letter.',
          'plotStatus': 'active',
        },
      ),
      PlotRecordDraft(
          id: 'plant', typeId: 'foreshadowing', name: 'The Royal Seal'),
      PlotRecordDraft(
          id: 'payoff', typeId: 'payoff', name: 'The Seal Is Opened'),
      PlotRecordDraft(
          id: 'goal',
          typeId: 'goal',
          name: 'Claim the Throne',
          fields: {'plotStatus': 'active'}),
      PlotRecordDraft(
          id: 'motivation',
          typeId: 'motivation',
          name: 'Protect the City',
          fields: {'motivationType': 'protection'}),
      PlotRecordDraft(id: 'obstacle', typeId: 'obstacle', name: 'The Regent'),
      PlotRecordDraft(
          id: 'stakes',
          typeId: 'stake',
          name: 'Civil War',
          fields: {'stakeType': 'political'}),
      PlotRecordDraft(
          id: 'conflict',
          typeId: 'conflict',
          name: 'Heir vs Regent',
          fields: {
            'conflictType': 'character-vs-character',
            'plotStatus': 'active'
          }),
      PlotRecordDraft(
          id: 'event', typeId: 'story-event', name: 'The Gates Open'),
      PlotRecordDraft(
          id: 'resolution', typeId: 'resolution', name: 'The New Council'),
      PlotRecordDraft(id: 'climax', typeId: 'climax', name: 'The Last Vote'),
    ]) {
      await plot.createPlotRecord(draft);
    }
    await plot.connect(
        sourceId: 'plant', targetId: 'reveal', typeId: 'leadsTo');
    await plot.connect(
        sourceId: 'plant', targetId: 'payoff', typeId: 'paidOffBy');
    await plot.connect(
        sourceId: 'goal', targetId: 'motivation', typeId: 'motivatedBy');
    await plot.connect(
        sourceId: 'goal', targetId: 'obstacle', typeId: 'opposes');
    await plot.connect(
        sourceId: 'goal', targetId: 'stakes', typeId: 'hasStake');
    await plot.connect(
        sourceId: 'conflict', targetId: 'event', typeId: 'causes');
    await plot.connect(
        sourceId: 'event', targetId: 'resolution', typeId: 'changes');

    final reveal = await plot.getPlotRecord('reveal');
    expect(reveal?.fields['authorKnowledge'],
        isNot(reveal?.fields['readerKnowledge']));
    expect(reveal?.fields['characterKnowledge'], isA<List>());
    expect(await plot.query.unresolvedSetups(), isEmpty);
    expect((await plot.query.activeGoals()).single.id, 'goal');
    expect((await plot.query.activeConflicts()).single.id, 'conflict');
    expect(
        (await plot.validatePlot()).where((issue) => issue.isError), isEmpty);
  });

  test('cross-system fixture is one connected stable-ID graph', () async {
    final fixturePlot = PlotService(
      projectId: PlotPhase1Fixture.projectId,
      repository: repository,
    );
    await PlotPhase1Fixture.seed(fixturePlot);

    final snapshot = await repository.snapshot();
    final records = snapshot.records
        .where((record) => record.projectId == PlotPhase1Fixture.projectId)
        .toList();
    final links = snapshot.links
        .where((link) => link.scopeId == PlotPhase1Fixture.projectId)
        .toList();

    expect(records.where((record) => record.typeId == 'act'), hasLength(3));
    expect(
        records.where((record) => record.typeId == 'sequence'), hasLength(3));
    expect(
        records.where((record) => record.typeId == 'character'), hasLength(3));
    expect(
        records.where((record) => record.typeId == 'location'), hasLength(2));
    expect(records.where((record) => record.typeId == 'timeline-event'),
        hasLength(3));
    expect(records.where((record) => record.typeId == 'chapter'), hasLength(3));
    expect(records.where((record) => record.typeId == 'scene'), hasLength(3));
    expect(
        links.map((link) => link.typeId),
        containsAll(const [
          'hasArc',
          'appearsIn',
          'plannedFor',
          'fulfilledBy',
          'occursDuring',
          'leadsTo',
          'paidOffBy',
          'causes',
          'changes',
          'resolvesIn',
        ]));
    expect((await fixturePlot.query.beatsByScene('scene-message')).single.id,
        'beat-message');
    expect(
        (await fixturePlot.query.timelineLinked()).map((record) => record.id),
        containsAll(['beat-message', 'reveal-parentage', 'climax-floodgate']));
    expect(
      links.every((link) =>
          records.any((record) => record.id == link.sourceId) &&
          records.any((record) => record.id == link.targetId)),
      isTrue,
    );
  });

  test('search, inspector, audit, validation, and safe delete stay centralized',
      () async {
    final story = await plot.createPlotRecord(PlotRecordDraft(
      id: 'story',
      typeId: 'story',
      name: 'The River Crown',
      fields: const {
        'summary': 'A drowned heir returns.',
        'plotStatus': 'active'
      },
      tags: const ['mystery', 'river'],
      canonStatus: CanonStatus.canon,
    ));
    final beat = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'beat',
      typeId: 'beat',
      name: 'The Crown Surfaces',
    ));
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'orphan-beat',
      typeId: 'beat',
      name: 'Unplaced Beat',
    ));
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'unresolved-plotline',
      typeId: 'plotline',
      name: 'The Missing Envoy',
      fields: {'plotStatus': 'active'},
    ));
    await plot.connect(
        sourceId: story.id, targetId: beat.id, typeId: 'contains');
    final updated = story.copyWith(
      fields: {...story.fields, 'purpose': 'Test the heir'},
      updatedAt: timestamp.add(const Duration(minutes: 1)),
    );
    await plot.updatePlotRecord(updated);

    expect((await plot.searchPlot('drowned')).single.recordId, story.id);
    final inspection = await plot.inspectPlotRecord(story.id);
    expect(inspection, isNotNull);
    expect(inspection!.outgoingConnections.single.typeId, 'contains');
    expect(inspection.history.versionCount, greaterThanOrEqualTo(2));
    expect(
        (await plot.getPlotHistory(story.id)).length, greaterThanOrEqualTo(2));
    final deletion = await plot.analyzeDelete(story.id);
    expect(deletion?.disposition, isNot(SafeDeleteDisposition.safe));
    final warnings = await plot.validatePlot();
    expect(
        warnings.map((issue) => issue.code),
        containsAll([
          'orphaned-beat',
          'unresolved-plotline',
          'missing-climax',
          'missing-resolution'
        ]));
    expect(warnings.where((issue) => issue.isError), isEmpty);
  });

  test(
      'branch overrides, branch-created records, and hidden records preserve Canon',
      () async {
    final canonical = await plot.createPlotRecord(const PlotRecordDraft(
      id: 'ending',
      typeId: 'resolution',
      name: 'The City Survives',
      fields: {'plotStatus': 'resolved'},
      canonStatus: CanonStatus.canon,
    ));
    await plot.branches.createBranch(StoryBranch(
      id: 'alternate-ending',
      projectId: 'project-a',
      name: 'Alternate Ending',
      kind: BranchKind.alternateEnding,
      createdAt: timestamp,
    ));
    await plot.overrideInBranch(
      'alternate-ending',
      canonical.id,
      title: 'The City Falls',
      canonStatus: CanonStatus.alternate,
    );
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'alternate-death',
      typeId: 'story-event',
      name: 'The Heir Dies',
      scopeType: RecordScopeType.branch,
      branchId: 'alternate-ending',
      canonStatus: CanonStatus.alternate,
    ));

    var branchRecords = await plot.query.branchSpecific('alternate-ending');
    expect(branchRecords.singleWhere((record) => record.id == 'ending').title,
        'The City Falls');
    expect(
        branchRecords.map((record) => record.id), contains('alternate-death'));
    expect((await plot.getPlotRecord('ending'))?.title, 'The City Survives');
    await plot.hideInBranch('alternate-ending', 'ending');
    branchRecords = await plot.query.branchSpecific('alternate-ending');
    expect(branchRecords.map((record) => record.id), isNot(contains('ending')));
    expect(
        (await plot.getPlotRecord('ending'))?.canonStatus, CanonStatus.canon);
  });

  test('database reopen and archive restore preserve Plot records and links',
      () async {
    final directory = await Directory.systemTemp.createTemp('plot-phase-1-');
    final file = File('${directory.path}${Platform.pathSeparator}plot.sqlite');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    final firstPlot =
        PlotService(projectId: 'durable-project', repository: firstRepository);
    await firstPlot.createPlotRecord(const PlotRecordDraft(
      id: 'durable-story',
      typeId: 'story',
      name: 'Durable Story',
    ));
    await firstPlot.createPlotRecord(const PlotRecordDraft(
      id: 'durable-beat',
      typeId: 'beat',
      name: 'Durable Beat',
    ));
    await firstPlot.connect(
        sourceId: 'durable-story',
        targetId: 'durable-beat',
        typeId: 'contains');
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopenedPlot = PlotService(
        projectId: 'durable-project', repository: reopenedRepository);
    expect((await reopenedPlot.getPlotRecord('durable-story'))?.title,
        'Durable Story');
    expect((await reopenedPlot.connectionsFor('durable-story')).single.targetId,
        'durable-beat');

    final archive = const AuthorOsArchiveService();
    final bytes = archive.exportSnapshot(
      await reopenedRepository.snapshot(),
      archiveId: 'plot-archive',
      rootId: 'durable-project',
      applicationVersion: '1.0.0',
      platform: 'test',
      createdAt: timestamp,
    );
    final restoredSnapshot = archive.importSnapshot(bytes);
    final restoredDatabase = AuthorOsDatabase(NativeDatabase.memory());
    final restoredRepository = DriftConnectedDomainRepository(restoredDatabase);
    await restoredRepository.replaceSnapshot(restoredSnapshot);
    final restoredPlot = PlotService(
        projectId: 'durable-project', repository: restoredRepository);
    expect((await restoredPlot.getPlotRecord('durable-beat'))?.title,
        'Durable Beat');
    expect((await restoredPlot.connectionsFor('durable-story')), hasLength(1));
    await restoredDatabase.close();
    await reopenedDatabase.close();
  });

  test('project, book, and branch queries remain isolated', () async {
    final other = PlotService(projectId: 'project-b', repository: repository);
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'beat-a1',
      typeId: 'beat',
      name: 'Book A Beat',
      bookId: 'book-a',
      canonStatus: CanonStatus.canon,
    ));
    await plot.createPlotRecord(const PlotRecordDraft(
      id: 'beat-a2',
      typeId: 'beat',
      name: 'Book B Beat',
      bookId: 'book-b',
    ));
    await other.createPlotRecord(const PlotRecordDraft(
      id: 'beat-other',
      typeId: 'beat',
      name: 'Other Project Beat',
      bookId: 'book-a',
    ));

    expect((await plot.query.beatsByBook('book-a')).single.id, 'beat-a1');
    expect((await plot.query.canonOnly()).single.id, 'beat-a1');
    expect((await plot.query.all()).map((record) => record.id),
        isNot(contains('beat-other')));
    expect((await other.query.all()).single.id, 'beat-other');
  });
}
