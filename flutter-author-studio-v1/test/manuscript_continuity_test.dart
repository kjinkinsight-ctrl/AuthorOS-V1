import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/manuscript_continuity.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Manuscript continuity rules, exercised without a database so each rule
/// can be checked in isolation.
void main() {
  const intelligence = ManuscriptContinuityIntelligence();
  final now = DateTime.utc(2026, 8, 20);

  ManuscriptScene scene({
    String id = 'scene-1',
    String title = 'Arrival',
    int order = 1,
    String content = '',
    String pov = '',
    String location = '',
    String notes = '',
  }) =>
      ManuscriptScene(
        id: id,
        chapterId: 'chapter-1',
        title: title,
        order: order,
        content: content,
        status: ManuscriptNodeStatus.draft,
        pov: pov,
        location: location,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

  ManuscriptChapter chapter({
    String pov = '',
    List<ManuscriptScene> scenes = const [],
  }) =>
      ManuscriptChapter(
        id: 'chapter-1',
        title: 'Chapter 01',
        order: 1,
        status: ManuscriptNodeStatus.draft,
        pov: pov,
        scenes: scenes,
        createdAt: now,
        updatedAt: now,
      );

  const kali = ManuscriptKnownRecord(
    id: 'character-kali',
    typeId: 'character',
    title: 'Kali Vale',
    aliases: ['The Red Widow'],
  );
  const endovier = ManuscriptKnownRecord(
    id: 'location-endovier',
    typeId: 'location',
    title: 'Endovier',
  );

  test('a mention with no connection becomes a link recommendation', () {
    final report = intelligence.analyzeScene(
      scene: scene(content: 'Kali Vale waited on the pier.'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    expect(report.summary.issues, hasLength(1));
    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.missingRelationship);
    expect(issue.actionKind, ContinuityActionKind.link);
    expect(report.findingFor(issue)!.targetId, kali.id);
    expect(report.findingFor(issue)!.connectionTypeId, 'appearsIn');
  });

  test('an alias counts as a mention', () {
    final report = intelligence.analyzeScene(
      scene: scene(content: 'They still called her the Red Widow.'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    expect(report.summary.issues, hasLength(1));
    expect(report.summary.issues.single.title, contains('Kali Vale'));
  });

  test('an already connected record is never reported', () {
    final report = intelligence.analyzeScene(
      scene: scene(content: 'Kali Vale waited on the pier.'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {'character-kali'},
      knownNames: const {'Kali Vale'},
    );

    expect(report.isClean, isTrue);
  });

  test('a substring match is not a mention', () {
    final report = intelligence.analyzeScene(
      scene: scene(content: 'The endovierian road was long.'),
      chapter: chapter(),
      records: const [endovier],
      connectedIds: const {},
      knownNames: const {'Endovier'},
    );

    expect(report.isClean, isTrue);
  });

  test('a short name is ignored so common words produce no noise', () {
    const ash = ManuscriptKnownRecord(
      id: 'character-ash',
      typeId: 'character',
      title: 'Ash',
    );
    final report = intelligence.analyzeScene(
      scene: scene(content: 'Ash fell from the sky.'),
      chapter: chapter(),
      records: const [ash],
      connectedIds: const {},
      knownNames: const {'Ash'},
    );

    expect(report.isClean, isTrue);
  });

  test('an unknown POV name becomes a create recommendation', () {
    final report = intelligence.analyzeScene(
      scene: scene(pov: 'Seraphine'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.unknownCharacter);
    expect(issue.actionKind, ContinuityActionKind.create);
    expect(report.findingFor(issue)!.missingName, 'Seraphine');
  });

  test('the chapter POV is used when the scene does not set one', () {
    final report = intelligence.analyzeScene(
      scene: scene(),
      chapter: chapter(pov: 'Seraphine'),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    expect(
      report.summary.issues.single.type,
      ContinuityWarningType.unknownCharacter,
    );
  });

  test('a known POV who is not connected becomes a review recommendation', () {
    final report = intelligence.analyzeScene(
      scene: scene(pov: 'Kali Vale'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.missingPovPresence);
    expect(issue.actionKind, ContinuityActionKind.review);
    final finding = report.findingFor(issue)!;
    expect(finding.targetId, kali.id);
    expect(finding.reviewField, 'pov');
    expect(finding.reviewValue, 'Kali Vale');
  });

  test('a connected POV raises nothing', () {
    final report = intelligence.analyzeScene(
      scene: scene(pov: 'Kali Vale'),
      chapter: chapter(),
      records: const [kali],
      connectedIds: const {'character-kali'},
      knownNames: const {'Kali Vale'},
    );

    expect(report.isClean, isTrue);
  });

  test('an unknown location becomes a create recommendation', () {
    final report = intelligence.analyzeScene(
      scene: scene(location: 'Noxmere Harbor'),
      chapter: chapter(),
      records: const [],
      connectedIds: const {},
      knownNames: const {},
    );

    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.unknownLocation);
    expect(issue.actionKind, ContinuityActionKind.create);
    expect(report.findingFor(issue)!.missingName, 'Noxmere Harbor');
  });

  test('a location owned by another Studio is never reported as missing', () {
    final report = intelligence.analyzeScene(
      scene: scene(location: 'Endovier'),
      chapter: chapter(),
      records: const [endovier],
      connectedIds: const {'location-endovier'},
      knownNames: const {'Endovier'},
    );

    expect(report.isClean, isTrue);
  });

  test('a chronology conflict against the previous scene is critical', () {
    final first = scene(id: 'scene-1', title: 'Arrival', order: 1);
    final second = scene(id: 'scene-2', title: 'The Warning', order: 2);
    final report = intelligence.analyzeScene(
      scene: second,
      chapter: chapter(scenes: [first, second]),
      records: const [],
      connectedIds: const {},
      knownNames: const {},
      previousScene: first,
      chronology: const {'scene-1': 400, 'scene-2': 100},
    );

    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.impossibleSequence);
    expect(issue.severity, ContinuitySeverity.critical);
    expect(issue.actionKind, ContinuityActionKind.review);
    expect(report.summary.criticalCount, 1);
    expect(report.summary.score, 75);
  });

  test('scenes in chronological order raise nothing', () {
    final first = scene(id: 'scene-1', order: 1);
    final second = scene(id: 'scene-2', order: 2);
    final report = intelligence.analyzeScene(
      scene: second,
      chapter: chapter(scenes: [first, second]),
      records: const [],
      connectedIds: const {},
      knownNames: const {},
      previousScene: first,
      chronology: const {'scene-1': 100, 'scene-2': 400},
    );

    expect(report.isClean, isTrue);
  });

  test('a chapter report folds each scene report together in order', () {
    final first = scene(
      id: 'scene-1',
      title: 'Arrival',
      order: 1,
      content: 'Kali Vale waited on the pier.',
    );
    final second = scene(
      id: 'scene-2',
      title: 'The Warning',
      order: 2,
      location: 'Noxmere Harbor',
    );
    final report = intelligence.analyzeChapter(
      chapter: chapter(scenes: [second, first]),
      records: const [kali],
      connectedIds: const {},
      knownNames: const {'Kali Vale'},
    );

    expect(report.summary.issues, hasLength(2));
    expect(
      report.summary.issues.first.type,
      ContinuityWarningType.missingRelationship,
    );
    expect(
      report.summary.issues.last.type,
      ContinuityWarningType.unknownLocation,
    );
    expect(report.findings.first.nodeId, 'scene-1');
    expect(report.findings.last.nodeId, 'scene-2');
  });

  test('findings are capped so one scene cannot flood the panel', () {
    const capped = ManuscriptContinuityIntelligence(maxFindingsPerScene: 2);
    final records = [
      for (var index = 0; index < 5; index++)
        ManuscriptKnownRecord(
          id: 'character-$index',
          typeId: 'character',
          title: 'Character$index',
        ),
    ];
    final report = capped.analyzeScene(
      scene: scene(
        content: 'Character0 Character1 Character2 Character3 Character4',
      ),
      chapter: chapter(),
      records: records,
      connectedIds: const {},
      knownNames: const {},
    );

    expect(report.summary.issues, hasLength(2));
  });

  test('known names read titles and aliases from raw records', () {
    final record = AuthorRecord(
      id: 'character-kali',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'project-1',
      projectId: 'project-1',
      title: 'Kali Vale',
      fields: const {'aliases': ['The Red Widow', 'Kali']},
      createdAt: now,
      updatedAt: now,
    );

    expect(
      ManuscriptContinuityIntelligence.knownNames([record]),
      containsAll(['Kali Vale', 'The Red Widow', 'Kali']),
    );
    final known = ManuscriptContinuityIntelligence.knownRecords([record]);
    expect(known.single.aliases, ['The Red Widow', 'Kali']);
    expect(known.single.isCharacter, isTrue);
  });

  test('aliases stored as a delimited string are still recognised', () {
    final record = AuthorRecord(
      id: 'location-endovier',
      typeId: 'location',
      scopeType: RecordScopeType.project,
      scopeId: 'project-1',
      projectId: 'project-1',
      title: 'Endovier',
      fields: const {'aliases': 'The Salt Mines; The Pit'},
      createdAt: now,
      updatedAt: now,
    );

    expect(
      ManuscriptContinuityIntelligence.aliasesOf(record),
      ['The Salt Mines', 'The Pit'],
    );
    expect(
      ManuscriptContinuityIntelligence.knownRecords([record]).single.isPlace,
      isTrue,
    );
  });
}
