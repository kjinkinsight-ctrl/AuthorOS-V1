/// Deterministic Codex intelligence: one inbox over the analyzers that already
/// exist, plus co-occurrence discovery.
///
/// This file adds no second engine and no second recogniser.
/// `CodexContinuityIntelligence` and `ManuscriptContinuityIntelligence` keep
/// producing findings exactly as they did, and both now match names through the
/// shared `entity_recognition.dart`. [CodexSuggestion] is the shape those two
/// finding types have in common, so one list can carry both and one accept path
/// can resolve both.
///
/// Nothing here is generative and nothing reaches the network.
library;

import '../codex_continuity.dart';
import '../continuity.dart';
import '../manuscript_continuity.dart';
import 'entity_recognition.dart';
import 'story_codex_domain.dart';
import 'story_graph.dart';

/// Where a suggestion came from, so the inbox can say why it is being shown.
enum CodexSuggestionSource { codexEntry, manuscriptScene, coOccurrence }

String codexSuggestionSourceLabel(CodexSuggestionSource source) =>
    switch (source) {
      CodexSuggestionSource.codexEntry => 'Codex',
      CodexSuggestionSource.manuscriptScene => 'Manuscript',
      CodexSuggestionSource.coOccurrence => 'Appears together',
    };

/// One deterministic recommendation, ready to accept or dismiss.
class CodexSuggestion {
  const CodexSuggestion({
    required this.source,
    required this.subjectId,
    required this.subjectTitle,
    required this.warning,
    required this.actionKind,
    this.targetId,
    this.targetTitle = '',
    this.missingName = '',
    this.connectionTypeId = 'relatedTo',
    this.confidence = 1,
  });

  final CodexSuggestionSource source;

  /// The entry or scene the recommendation is anchored to.
  final String subjectId;
  final String subjectTitle;
  final ContinuityWarning warning;
  final ContinuityActionKind actionKind;

  /// The record a `link` recommendation should connect [subjectId] to.
  final String? targetId;
  final String targetTitle;

  /// The name a `create` recommendation should use.
  final String missingName;
  final String connectionTypeId;

  /// 0..1. A recommendation is a suggestion, never a fact.
  final double confidence;

  /// Stable across runs: the same recommendation keeps the same id.
  ///
  /// Derived from content rather than from a counter, which is what lets a
  /// dismissal stick without storing the suggestion itself. A dismissed
  /// suggestion stays dismissed until the prose changes enough to produce a
  /// different recommendation.
  String get id => [
        source.name,
        actionKind.name,
        subjectId,
        targetId ?? '',
        missingName.toLowerCase(),
        connectionTypeId,
      ].join('|');

  String get title => warning.title;

  String get message => warning.message;

  ContinuitySeverity get severity => warning.severity;

  /// The issue shape the existing accept path expects.
  ContinuityIntegrityIssue get issue =>
      ContinuityAnalyzer.summaryFor([warning]).issues.single;
}

/// A scene, flattened to the two things discovery needs from it.
class SceneMentionSet {
  const SceneMentionSet({
    required this.sceneId,
    required this.sceneTitle,
    required this.recordIds,
  });

  final String sceneId;
  final String sceneTitle;

  /// The records whose name or alias appears in this scene's prose.
  final Set<String> recordIds;
}

/// One scene's prose, flattened so discovery never reaches into the manuscript
/// store itself.
class SceneProse {
  const SceneProse({
    required this.id,
    required this.title,
    required this.prose,
  });

  final String id;
  final String title;
  final String prose;
}

/// Stamped onto any link promoted from a co-occurrence suggestion, so a reader
/// of the graph can tell an inference's origin from a hand-drawn edge.
const String kCoOccurrenceDerivation = 'co-occurrence';

/// Finds records that keep appearing together but are not connected.
///
/// This is a *derived* read. It never writes a `RecordLink` — it returns
/// [DerivedStoryGraphEdge], the type the Story Graph already defines for
/// inferences, which carries a derivation and a confidence, has no id, and so
/// cannot be mistaken for something the author recorded. An author accepting a
/// suggestion is what creates a real link, through the ordinary connection
/// path. That is the Story Graph's own exit criterion for derived edges: not
/// one reaches `record_link_rows` without a button being pressed.
class CoOccurrenceDiscovery {
  const CoOccurrenceDiscovery({
    this.minimumScenes = 2,
    this.maximumPairs = 25,
  });

  /// How many shared scenes it takes before a pair is worth mentioning.
  ///
  /// One shared scene is a coincidence, and the unlinked-mention rule already
  /// reports that case per scene. Repeating it here would be noise.
  final int minimumScenes;

  final int maximumPairs;

  /// Pairs sharing at least [minimumScenes] scenes and having no link.
  ///
  /// [linkedPairs] holds the pairs already connected, keyed by [pairKey].
  List<DerivedStoryGraphEdge> discover({
    required Iterable<SceneMentionSet> scenes,
    Set<String> linkedPairs = const {},
  }) {
    final shared = <String, Set<String>>{};
    for (final scene in scenes) {
      final ids = scene.recordIds.toList()..sort();
      for (var i = 0; i < ids.length; i += 1) {
        for (var j = i + 1; j < ids.length; j += 1) {
          shared
              .putIfAbsent(pairKey(ids[i], ids[j]), () => <String>{})
              .add(scene.sceneId);
        }
      }
    }
    final ranked = shared.entries
        .where((entry) => entry.value.length >= minimumScenes)
        .where((entry) => !linkedPairs.contains(entry.key))
        .toList()
      ..sort((left, right) {
        final byCount = right.value.length.compareTo(left.value.length);
        return byCount != 0 ? byCount : left.key.compareTo(right.key);
      });
    return [
      for (final entry in ranked.take(maximumPairs))
        DerivedStoryGraphEdge(
          sourceId: _partsOf(entry.key).first,
          targetId: _partsOf(entry.key).last,
          derivation: kCoOccurrenceDerivation,
          // Three shared scenes is as confident as counting gets; past that the
          // evidence is the same kind, only more of it.
          confidence: (entry.value.length / 3).clamp(0.0, 1.0).toDouble(),
          promotable: true,
          label: '${entry.value.length} shared scenes',
        ),
    ];
  }

  /// Order-independent key for an unordered pair.
  static String pairKey(String a, String b) {
    final ordered = [a, b]..sort();
    return ordered.join(_separator);
  }

  static List<String> _partsOf(String key) => key.split(_separator);

  /// Record ids are slugs, so a vertical bar cannot appear inside one and
  /// cannot forge a pair boundary.
  static const _separator = '|';
}

/// Turns the existing analyzers' findings into one ranked suggestion list.
///
/// Deliberately pure: it takes flattened inputs and returns suggestions, so it
/// is testable without a database and cannot acquire a storage path of its own.
class CodexSuggestionBuilder {
  const CodexSuggestionBuilder();

  /// Suggestions from one Codex entry's findings.
  List<CodexSuggestion> fromCodexReport({
    required CodexEntry entry,
    required CodexContinuityReport report,
    Map<String, String> titles = const {},
  }) =>
      [
        for (final finding in report.findings)
          CodexSuggestion(
            source: CodexSuggestionSource.codexEntry,
            subjectId: finding.entryId,
            subjectTitle: entry.title,
            warning: finding.warning,
            actionKind: finding.actionKind,
            targetId: finding.targetId,
            targetTitle: titles[finding.targetId] ?? '',
            missingName: finding.missingName,
            connectionTypeId: finding.connectionTypeId,
          ),
      ];

  /// Suggestions from one scene's findings.
  ///
  /// Review findings are dropped: resolving one edits manuscript metadata,
  /// which belongs to the Manuscript workspace and not to a Codex inbox.
  List<CodexSuggestion> fromManuscriptReport({
    required String sceneTitle,
    required ManuscriptContinuityReport report,
    Map<String, String> titles = const {},
  }) =>
      [
        for (final finding in report.findings)
          if (finding.actionKind != ContinuityActionKind.review)
            CodexSuggestion(
              source: CodexSuggestionSource.manuscriptScene,
              subjectId: finding.nodeId,
              subjectTitle: sceneTitle,
              warning: finding.warning,
              actionKind: finding.actionKind,
              targetId: finding.targetId,
              targetTitle: titles[finding.targetId] ?? '',
              missingName: finding.missingName,
              connectionTypeId: finding.connectionTypeId,
            ),
      ];

  /// Suggestions from derived co-occurrence edges.
  ///
  /// An edge whose endpoints are not both known records is dropped rather than
  /// rendered with a blank name.
  List<CodexSuggestion> fromDerivedEdges({
    required Iterable<DerivedStoryGraphEdge> edges,
    required Map<String, String> titles,
  }) =>
      [
        for (final edge in edges)
          if (titles.containsKey(edge.sourceId) &&
              titles.containsKey(edge.targetId))
            CodexSuggestion(
              source: CodexSuggestionSource.coOccurrence,
              subjectId: edge.sourceId,
              subjectTitle: titles[edge.sourceId]!,
              targetId: edge.targetId,
              targetTitle: titles[edge.targetId]!,
              actionKind: ContinuityActionKind.link,
              connectionTypeId: 'relatedTo',
              confidence: edge.confidence,
              warning: ContinuityWarning(
                type: ContinuityWarningType.missingRelationship,
                severity: ContinuitySeverity.notice,
                title: '${titles[edge.sourceId]} and '
                    '${titles[edge.targetId]} appear together',
                message: 'They share ${edge.label}, but no connection records '
                    'a relationship.',
                eventIds: [edge.sourceId, edge.targetId],
              ),
            ),
      ];

  /// Orders an inbox: most severe first, then most confident, then by title.
  ///
  /// Deduplicates by [CodexSuggestion.id], so a pair surfaced by two rules is
  /// shown once rather than twice.
  List<CodexSuggestion> rank(Iterable<CodexSuggestion> suggestions) {
    final seen = <String>{};
    final unique = <CodexSuggestion>[];
    for (final suggestion in suggestions) {
      if (seen.add(suggestion.id)) unique.add(suggestion);
    }
    unique.sort((left, right) {
      final bySeverity = right.severity.index.compareTo(left.severity.index);
      if (bySeverity != 0) return bySeverity;
      final byConfidence = right.confidence.compareTo(left.confidence);
      if (byConfidence != 0) return byConfidence;
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return unique;
  }

  /// Which records each scene mentions, for [CoOccurrenceDiscovery].
  ///
  /// Uses the shared recogniser, so discovery and per-scene recognition can
  /// never disagree about what counts as a mention. A scene mentioning fewer
  /// than two records cannot produce a pair and is dropped early.
  List<SceneMentionSet> mentionsIn({
    required Iterable<SceneProse> scenes,
    required Iterable<ManuscriptKnownRecord> records,
    int minimumLength = kMinimumMentionLength,
  }) {
    final sets = <SceneMentionSet>[];
    for (final scene in scenes) {
      final prose = scene.prose.toLowerCase();
      final ids = <String>{
        for (final record in records)
          if (firstMention(prose, record.names, minimumLength: minimumLength) !=
              null)
            record.id,
      };
      if (ids.length >= 2) {
        sets.add(SceneMentionSet(
          sceneId: scene.id,
          sceneTitle: scene.title,
          recordIds: ids,
        ));
      }
    }
    return sets;
  }
}
