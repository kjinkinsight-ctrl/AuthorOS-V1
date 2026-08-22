/// Unit tests for the Intelligence Layer's structural detectors.
///
/// Every detector is a pure function over a [ProjectSurvey], so these tests
/// build a survey by hand and never open a database. Each detector gets a true
/// positive, a true negative, and the edge case that most plausibly makes it
/// wrong.
library;

import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/research_record_types.dart';
import 'package:author_studio_v1/intelligence/detectors.dart';
import 'package:author_studio_v1/intelligence/intelligence_models.dart';
import 'package:author_studio_v1/intelligence/project_survey.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 1, 1);

AuthorRecord _record(
  String id,
  String typeId,
  String title, {
  Map<String, Object?> fields = const {},
  AuthorRecordStatus status = AuthorRecordStatus.active,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: 'p1',
      projectId: 'p1',
      title: title,
      fields: fields,
      status: status,
      createdAt: _now,
      updatedAt: _now,
    );

RecordLink _link(String source, String type, String target) => RecordLink(
      id: 'link-$source-$type-$target',
      sourceId: source,
      targetId: target,
      typeId: type,
      scopeId: 'p1',
      createdAt: _now,
      updatedAt: _now,
    );

ManuscriptScene _scene(
  String id,
  String title,
  String content, {
  String chapterId = 'ch1',
  String pov = '',
  String location = '',
}) =>
    ManuscriptScene(
      id: id,
      chapterId: chapterId,
      title: title,
      order: 0,
      content: content,
      status: ManuscriptNodeStatus.draft,
      pov: pov,
      location: location,
      createdAt: _now,
      updatedAt: _now,
    );

ManuscriptProjectSummary _manuscript(List<ManuscriptScene> scenes) =>
    ManuscriptProjectSummary(
      projectId: 'p1',
      manuscriptTitle: 'The Blood Price',
      chapters: [
        ManuscriptChapter(
          id: 'ch1',
          title: 'Chapter One',
          order: 0,
          status: ManuscriptNodeStatus.draft,
          scenes: scenes,
          createdAt: _now,
          updatedAt: _now,
        ),
      ],
      currentChapterId: 'ch1',
      currentSceneId: scenes.isEmpty ? '' : scenes.first.id,
      createdAt: _now,
      updatedAt: _now,
      version: 1,
    );

/// Minimal type definitions, so records resolve to a real category without
/// dragging the whole built-in registry into a unit test.
RecordTypeDefinition _type(String id, String categoryId) =>
    RecordTypeDefinition(
      id: id,
      name: id,
      categoryId: categoryId,
      fields: const [],
      sections: const [],
      scopeType: RecordScopeType.project,
      scopeId: 'p1',
    );

final _types = <RecordTypeDefinition>[
  _type('character', 'characters'),
  _type('character-villain', 'characters'),
  _type('location', 'locations'),
  _type('faction', 'factions'),
  _type('map', 'maps'),
  _type('plotline', 'plot'),
  _type('relationship-arc', 'plot'),
  _type('research-entry', 'research'),
  _type('timeline-event', 'timeline'),
  _type('calendar-definition', 'timeline'),
];

ProjectSurvey _survey({
  List<AuthorRecord> records = const [],
  List<RecordLink> links = const [],
  List<ManuscriptScene> scenes = const [],
}) =>
    ProjectSurvey.from(
      projectId: 'p1',
      projectTitle: 'The Blood Price',
      manuscript: _manuscript(scenes),
      records: records,
      links: links,
      typeDefinitions: _types,
    );

List<StructuralFinding> _of(
  List<StructuralFinding> findings,
  StructuralCondition condition,
) =>
    findings.where((finding) => finding.condition == condition).toList();

void main() {
  group('orphan entity', () {
    test('reports a character with no link and no mention in the prose', () {
      final findings = detectOrphanEntities(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        scenes: [_scene('s1', 'Opening', 'The city burned before dawn.')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('Cassian'));
      expect(findings.single.severity, ContinuitySeverity.warning);
      expect(findings.single.entityIds, ['c1']);
    });

    test('a connected character is not an orphan', () {
      final findings = detectOrphanEntities(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        links: [_link('c1', 'appearsIn', 's1')],
        scenes: [_scene('s1', 'Opening', 'The city burned.')],
      ));

      expect(findings, isEmpty);
    });

    test('a character named in the prose is not an orphan, even unlinked', () {
      // This is the whole reason the rule is a conjunction: a link-only rule
      // would call Cassian an orphan here, which is plainly wrong.
      final findings = detectOrphanEntities(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        scenes: [_scene('s1', 'Opening', 'Cassian drew his blade.')],
      ));

      expect(findings, isEmpty);
    });

    test('an alias counts as an appearance', () {
      final findings = detectOrphanEntities(_survey(
        records: [
          _record('c1', 'character', 'Cassian', fields: {
            'aliases': ['The Blade'],
          }),
        ],
        scenes: [_scene('s1', 'Opening', 'The Blade drew steel.')],
      ));

      expect(findings, isEmpty);
    });

    test('a substring is not a mention', () {
      // "Cass" appears inside "Cassian", but the boundary rule must not treat
      // that as naming a different character called Cass.
      final findings = detectOrphanEntities(_survey(
        records: [_record('c2', 'character', 'Cass')],
        scenes: [_scene('s1', 'Opening', 'Cassian drew his blade.')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('Cass'));
    });

    test('nothing is reported before the author has written anything', () {
      final findings = detectOrphanEntities(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        scenes: [_scene('s1', 'Opening', '   ')],
      ));

      expect(findings, isEmpty);
    });

    test('a soft-deleted character is not reported', () {
      final findings = detectOrphanEntities(_survey(
        records: [
          _record(
            'c1',
            'character',
            'Cassian',
            status: AuthorRecordStatus.deleted,
          ),
        ],
        scenes: [_scene('s1', 'Opening', 'The city burned.')],
      ));

      expect(findings, isEmpty);
    });

    test('a character saved under a template still counts as a character', () {
      final findings = detectOrphanEntities(_survey(
        records: [_record('c1', 'character-villain', 'Noxmere')],
        scenes: [_scene('s1', 'Opening', 'The city burned.')],
      ));

      expect(findings, hasLength(1));
    });
  });

  group('unlinked mention and gaps', () {
    test('reports a character named in a scene it is not connected to', () {
      final findings = detectManuscriptGaps(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        scenes: [_scene('s1', 'Opening', 'Cassian drew his blade.')],
      ));

      final mentions = _of(findings, StructuralCondition.unlinkedMention);
      expect(mentions, hasLength(1));
      expect(mentions.single.entityIds, containsAll(['c1', 's1']));
      expect(mentions.single.action, isNotNull);
      expect(mentions.single.action!.kind, ContinuityActionKind.link);
    });

    test('a connected character produces no unlinked mention', () {
      final findings = detectManuscriptGaps(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        links: [_link('c1', 'appearsIn', 's1')],
        scenes: [_scene('s1', 'Opening', 'Cassian drew his blade.')],
      ));

      expect(_of(findings, StructuralCondition.unlinkedMention), isEmpty);
    });

    test('reports a scene location that has no record', () {
      final findings = detectManuscriptGaps(_survey(
        records: [_record('c1', 'character', 'Cassian')],
        scenes: [
          _scene('s1', 'Opening', 'Cassian drew.', location: 'Endovier'),
        ],
      ));

      final gaps = _of(findings, StructuralCondition.locationGap);
      expect(gaps, hasLength(1));
      expect(gaps.single.title, contains('Endovier'));
      expect(gaps.single.action!.kind, ContinuityActionKind.create);
      expect(gaps.single.action!.name, 'Endovier');
    });

    test('a location that exists is not a gap', () {
      final findings = detectManuscriptGaps(_survey(
        records: [_record('l1', 'location', 'Endovier')],
        scenes: [_scene('s1', 'Opening', 'Cold.', location: 'Endovier')],
      ));

      expect(_of(findings, StructuralCondition.locationGap), isEmpty);
    });

    test('reports a POV that belongs to nobody', () {
      final findings = detectManuscriptGaps(_survey(
        scenes: [_scene('s1', 'Opening', 'Snow fell.', pov: 'Vincenzo')],
      ));

      final gaps = _of(findings, StructuralCondition.castGap);
      expect(gaps, hasLength(1));
      expect(gaps.single.title, contains('Vincenzo'));
    });
  });

  group('orphan plot', () {
    test('reports a plotline with no scenes', () {
      final findings = detectOrphanPlots(_survey(
        records: [_record('pl1', 'plotline', 'The Red Widow')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('The Red Widow'));
    });

    test('a plotline connected to a real scene is not orphaned', () {
      final findings = detectOrphanPlots(_survey(
        records: [_record('pl1', 'plotline', 'The Red Widow')],
        links: [_link('pl1', 'appearsIn', 's1')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, isEmpty);
    });

    test('a link to a scene that no longer exists does not save it', () {
      // A link naming a scene that is not in the manuscript. Phase 0 now
      // deletes a scene's edges with it, so this state should not arise in
      // practice — but the detector must not depend on that to be right.
      final findings = detectOrphanPlots(_survey(
        records: [_record('pl1', 'plotline', 'The Red Widow')],
        links: [_link('pl1', 'appearsIn', 'deleted-scene')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, hasLength(1));
    });
  });

  group('unresolved relationship', () {
    test('reports a relationship arc with no resolution', () {
      final findings = detectUnresolvedRelationships(_survey(
        records: [
          _record('a1', 'relationship-arc', 'Kali and Cassian',
              fields: {'plotStatus': 'active'}),
        ],
      ));

      expect(_of(findings, StructuralCondition.unresolvedRelationship),
          hasLength(1));
    });

    test('a resolved arc is not reported', () {
      final findings = detectUnresolvedRelationships(_survey(
        records: [
          _record('a1', 'relationship-arc', 'Kali and Cassian',
              fields: {'plotStatus': 'resolved'}),
        ],
      ));

      expect(findings, isEmpty);
    });

    test('reports a character relationship with no arc at all', () {
      final findings = detectUnresolvedRelationships(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('c2', 'character', 'Cassian'),
        ],
        links: [_link('c1', 'rivalOf', 'c2')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.entityIds, containsAll(['c1', 'c2']));
    });

    test('a pair covered by an arc is not reported twice over', () {
      final findings = detectUnresolvedRelationships(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('c2', 'character', 'Cassian'),
          _record('a1', 'relationship-arc', 'Kali and Cassian',
              fields: {'plotStatus': 'resolved'}),
        ],
        links: [
          _link('c1', 'rivalOf', 'c2'),
          _link('a1', 'relatedTo', 'c1'),
        ],
      ));

      expect(findings, isEmpty);
    });

    test('one finding per pair however many links join them', () {
      final findings = detectUnresolvedRelationships(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('c2', 'character', 'Cassian'),
        ],
        links: [
          _link('c1', 'rivalOf', 'c2'),
          _link('c2', 'knows', 'c1'),
        ],
      ));

      expect(findings, hasLength(1));
    });
  });

  group('timeline conflict', () {
    AuthorRecord calendar() => _record(
          'cal',
          'calendar-definition',
          'Imperial Calendar',
          fields: {
            'months': [
              {'name': 'First', 'length': 30},
              {'name': 'Second', 'length': 30},
            ],
          },
        );

    Map<String, Object?> date(int year, int month, int day) => {
          'calendarId': 'cal',
          'year': year,
          'month': month,
          'day': day,
          'precision': TimelinePrecision.exact.name,
        };

    test('reports a character in two events at the same time', () {
      final findings = detectTimelineConflicts(_survey(
        records: [
          calendar(),
          _record('c1', 'character', 'Kali'),
          _record('e1', 'timeline-event', 'Battle of Endovier', fields: {
            'start': [date(1, 1, 10)],
            'end': [date(1, 1, 12)],
          }),
          _record('e2', 'timeline-event', 'Council at Noxmere', fields: {
            'start': [date(1, 1, 11)],
            'end': [date(1, 1, 13)],
          }),
        ],
        links: [
          _link('e1', 'involves', 'c1'),
          _link('e2', 'involves', 'c1'),
        ],
      ));

      expect(findings, isNotEmpty);
      expect(
        findings.any((finding) => finding.detail.contains('Kali')),
        isTrue,
      );
    });

    test('events that do not overlap produce no conflict', () {
      final findings = detectTimelineConflicts(_survey(
        records: [
          calendar(),
          _record('c1', 'character', 'Kali'),
          _record('e1', 'timeline-event', 'Battle', fields: {
            'start': [date(1, 1, 10)],
            'end': [date(1, 1, 11)],
          }),
          _record('e2', 'timeline-event', 'Council', fields: {
            'start': [date(1, 2, 1)],
            'end': [date(1, 2, 2)],
          }),
        ],
        links: [
          _link('e1', 'involves', 'c1'),
          _link('e2', 'involves', 'c1'),
        ],
      ));

      expect(findings, isEmpty);
    });

    test('undated events are skipped, not reported', () {
      final findings = detectTimelineConflicts(_survey(
        records: [
          calendar(),
          _record('e1', 'timeline-event', 'Someday'),
          _record('e2', 'timeline-event', 'Sometime'),
        ],
      ));

      expect(findings, isEmpty);
    });

    test('an event dated against an unknown calendar is skipped', () {
      final findings = detectTimelineConflicts(_survey(
        records: [
          _record('e1', 'timeline-event', 'Battle', fields: {
            'start': [date(1, 1, 10)],
          }),
          _record('e2', 'timeline-event', 'Council', fields: {
            'start': [date(1, 1, 10)],
          }),
        ],
      ));

      expect(findings, isEmpty);
    });
  });

  group('research gap', () {
    test('reports research in use that cites nothing', () {
      final findings = detectResearchGaps(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('r1', 'research-entry', 'Venetian glassmaking'),
        ],
        links: [_link('r1', 'documents', 'c1')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.title, contains('Venetian glassmaking'));
    });

    test('research with a source URL is not a gap', () {
      final findings = detectResearchGaps(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('r1', 'research-entry', 'Venetian glassmaking', fields: {
            ResearchRecordTypes.sourceUrlFieldId: 'https://example.org',
          }),
        ],
        links: [_link('r1', 'documents', 'c1')],
      ));

      expect(findings, isEmpty);
    });

    test('research with a citation is not a gap', () {
      final findings = detectResearchGaps(_survey(
        records: [
          _record('c1', 'character', 'Kali'),
          _record('r1', 'research-entry', 'Venetian glassmaking', fields: {
            ResearchRecordTypes.citationFieldId: 'Trivellato, 2009',
          }),
        ],
        links: [_link('r1', 'documents', 'c1')],
      ));

      expect(findings, isEmpty);
    });

    test('unattached research is a note, not a gap', () {
      final findings = detectResearchGaps(_survey(
        records: [_record('r1', 'research-entry', 'Venetian glassmaking')],
      ));

      expect(findings, isEmpty);
    });
  });

  group('unused worldbuilding', () {
    test('reports one finding carrying the count', () {
      final findings = detectUnusedWorldbuilding(_survey(
        records: [
          _record('l1', 'location', 'Endovier'),
          _record('l2', 'location', 'Noxmere'),
          _record('f1', 'faction', 'House Noxmere'),
        ],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, hasLength(1));
      expect(findings.single.title, '3 world entities have no manuscript '
          'connections');
      expect(findings.single.entityIds, hasLength(3));
    });

    test('singular reads as singular', () {
      final findings = detectUnusedWorldbuilding(_survey(
        records: [_record('l1', 'location', 'Endovier')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings.single.title, '1 world entity has no manuscript '
          'connections');
    });

    test('a connected world entity is not counted', () {
      final findings = detectUnusedWorldbuilding(_survey(
        records: [_record('l1', 'location', 'Endovier')],
        links: [_link('l1', 'appearsIn', 's1')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, isEmpty);
    });

    test('maps are not worldbuilding for this purpose', () {
      // An unconnected map marker is a normal map marker, not a finding.
      final findings = detectUnusedWorldbuilding(_survey(
        records: [_record('m1', 'map', 'The Northern Reach')],
        scenes: [_scene('s1', 'Opening', 'Words.')],
      ));

      expect(findings, isEmpty);
    });
  });

  group('report ordering', () {
    test('findings come back most severe first', () {
      final findings = detectAll(_survey(
        records: [
          _record('c1', 'character', 'Cassian'),
          _record('l1', 'location', 'Endovier'),
          _record('r1', 'research-entry', 'Glass'),
        ],
        links: [_link('r1', 'documents', 'c1')],
        scenes: [
          _scene('s1', 'Opening', 'Snow fell.', location: 'Perrington'),
        ],
      ));

      final ranks = findings.map((finding) => finding.severity.index).toList();
      expect(
        findings.map((finding) => finding.condition),
        contains(StructuralCondition.locationGap),
      );
      expect(ranks, isNotEmpty);
      for (var index = 1; index < findings.length; index += 1) {
        expect(
          compareFindings(findings[index - 1], findings[index]),
          lessThanOrEqualTo(0),
        );
      }
    });
  });
}
