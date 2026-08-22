/// Co-occurrence discovery and suggestion ranking.
///
/// Pure: no database, so each rule can be checked in isolation.
library;

import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/codex_intelligence.dart';
import 'package:author_studio_v1/core/story_graph.dart';
import 'package:author_studio_v1/manuscript_continuity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const discovery = CoOccurrenceDiscovery();
  const builder = CodexSuggestionBuilder();

  SceneMentionSet scene(String id, List<String> ids) =>
      SceneMentionSet(sceneId: id, sceneTitle: id, recordIds: ids.toSet());

  group('CoOccurrenceDiscovery', () {
    test('a pair sharing two scenes is discovered', () {
      final edges = discovery.discover(scenes: [
        scene('scene-1', ['kali', 'vale']),
        scene('scene-2', ['kali', 'vale']),
      ]);

      expect(edges, hasLength(1));
      expect(edges.single.sourceId, 'kali');
      expect(edges.single.targetId, 'vale');
      expect(edges.single.derivation, kCoOccurrenceDerivation);
      expect(edges.single.promotable, isTrue);
      expect(edges.single.label, '2 shared scenes');
    });

    test('one shared scene is a coincidence, not a discovery', () {
      final edges = discovery.discover(scenes: [
        scene('scene-1', ['kali', 'vale']),
      ]);

      expect(edges, isEmpty,
          reason: 'the per-scene unlinked-mention rule already covers this');
    });

    test('confidence grows with evidence and is capped at one', () {
      double confidenceFor(int sceneCount) => discovery
          .discover(scenes: [
            for (var i = 0; i < sceneCount; i += 1)
              scene('scene-$i', ['kali', 'vale']),
          ])
          .single
          .confidence;

      expect(confidenceFor(2), closeTo(2 / 3, 0.001));
      expect(confidenceFor(3), 1.0);
      expect(confidenceFor(9), 1.0);
    });

    test('a pair that is already linked is not suggested again', () {
      final edges = discovery.discover(
        scenes: [
          scene('scene-1', ['kali', 'vale']),
          scene('scene-2', ['kali', 'vale']),
        ],
        linkedPairs: {CoOccurrenceDiscovery.pairKey('vale', 'kali')},
      );

      expect(edges, isEmpty,
          reason: 'the pair key must be order-independent');
    });

    test('every pair in a crowded scene is counted', () {
      final edges = discovery.discover(scenes: [
        scene('scene-1', ['kali', 'vale', 'noxmere']),
        scene('scene-2', ['kali', 'vale', 'noxmere']),
      ]);

      expect(edges, hasLength(3));
    });

    test('the most-shared pair is ranked first', () {
      final edges = discovery.discover(scenes: [
        scene('scene-1', ['kali', 'vale']),
        scene('scene-2', ['kali', 'vale']),
        scene('scene-3', ['kali', 'vale']),
        scene('scene-4', ['noxmere', 'vale']),
        scene('scene-5', ['noxmere', 'vale']),
      ]);

      expect(edges.first.label, '3 shared scenes');
    });

    test('output is capped so the inbox stays readable', () {
      const capped = CoOccurrenceDiscovery(maximumPairs: 2);
      final edges = capped.discover(scenes: [
        scene('scene-1', ['a1', 'b2', 'c3', 'd4']),
        scene('scene-2', ['a1', 'b2', 'c3', 'd4']),
      ]);

      expect(edges, hasLength(2));
    });

    test('a derived edge carries no id it could be persisted under', () {
      final edge = discovery.discover(scenes: [
        scene('scene-1', ['kali', 'vale']),
        scene('scene-2', ['kali', 'vale']),
      ]).single;

      // DerivedStoryGraphEdge has no id by design; this asserts the type we
      // return really is that type and not a link in disguise.
      expect(edge, isA<DerivedStoryGraphEdge>());
    });
  });

  group('mentionsIn', () {
    const kali = ManuscriptKnownRecord(
      id: 'kali',
      typeId: 'character',
      title: 'Kali Vale',
      aliases: ['The Red Widow'],
    );
    const endovier = ManuscriptKnownRecord(
      id: 'endovier',
      typeId: 'location',
      title: 'Endovier',
    );

    test('an alias counts as a mention', () {
      final sets = builder.mentionsIn(
        scenes: const [
          SceneProse(
            id: 'scene-1',
            title: 'Arrival',
            prose: 'The Red Widow reached Endovier at dusk.',
          ),
        ],
        records: const [kali, endovier],
      );

      expect(sets.single.recordIds, {'kali', 'endovier'});
    });

    test('a scene naming one record cannot make a pair', () {
      final sets = builder.mentionsIn(
        scenes: const [
          SceneProse(id: 'scene-1', title: 'Alone', prose: 'Endovier was cold.'),
        ],
        records: const [kali, endovier],
      );

      expect(sets, isEmpty);
    });
  });

  group('rank', () {
    CodexSuggestion suggestion({
      required String subjectId,
      required ContinuitySeverity severity,
      String title = 'Recommendation',
      double confidence = 1,
    }) =>
        CodexSuggestion(
          source: CodexSuggestionSource.codexEntry,
          subjectId: subjectId,
          subjectTitle: subjectId,
          actionKind: ContinuityActionKind.link,
          confidence: confidence,
          warning: ContinuityWarning(
            type: ContinuityWarningType.missingRelationship,
            severity: severity,
            title: title,
            message: 'message',
            eventIds: const [],
          ),
        );

    test('the most severe recommendation comes first', () {
      final ranked = builder.rank([
        suggestion(subjectId: 'a', severity: ContinuitySeverity.notice),
        suggestion(subjectId: 'b', severity: ContinuitySeverity.critical),
        suggestion(subjectId: 'c', severity: ContinuitySeverity.warning),
      ]);

      expect(ranked.map((item) => item.subjectId), ['b', 'c', 'a']);
    });

    test('at equal severity the more confident comes first', () {
      final ranked = builder.rank([
        suggestion(
            subjectId: 'a',
            severity: ContinuitySeverity.notice,
            confidence: 0.3),
        suggestion(
            subjectId: 'b',
            severity: ContinuitySeverity.notice,
            confidence: 0.9),
      ]);

      expect(ranked.map((item) => item.subjectId), ['b', 'a']);
    });

    test('the same recommendation found twice is shown once', () {
      final ranked = builder.rank([
        suggestion(subjectId: 'a', severity: ContinuitySeverity.notice),
        suggestion(subjectId: 'a', severity: ContinuitySeverity.notice),
      ]);

      expect(ranked, hasLength(1));
    });

    test('a suggestion id is stable across runs', () {
      final first = suggestion(subjectId: 'a', severity: ContinuitySeverity.notice);
      final second = suggestion(subjectId: 'a', severity: ContinuitySeverity.notice);

      expect(first.id, second.id,
          reason: 'a dismissal has to survive the next sweep');
    });
  });
}
