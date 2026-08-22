/// AuthorOS Intelligence Layer — the value objects.
///
/// The Intelligence Layer answers a question statistics cannot: *what is
/// structurally wrong with this book?* It detects conditions — an orphaned
/// character, a plotline with no scenes, a scene set somewhere the world
/// database has never heard of — by reading what the Studios already own.
///
/// Two rules govern everything in this file.
///
/// **Nothing here is persisted.** A [StructuralFinding] is a view-layer object
/// with no id, computed on demand and discarded. It is never written back as a
/// [RecordLink], which would turn a derived observation into canon the author
/// never asserted (invariant I-9 in `docs/universal-story-graph-architecture.md`).
///
/// **There is one severity scale in AuthorOS.** [ContinuitySeverity] comes from
/// `lib/continuity.dart` and is imported, not redeclared, so a critical finding
/// means the same thing on this screen as it does inside a character panel.
library;

import '../continuity.dart';

/// The structural conditions the layer can detect.
///
/// Canon Conflict is deliberately absent. "Two records contain contradictory
/// information" cannot be decided without reading meaning, and AuthorOS does
/// not use AI. The structurally decidable subset — duplicate-name records, an
/// appearance after a death event, contradictory single-valued fields — is
/// recorded as follow-up work rather than shipped half-right.
enum StructuralCondition {
  /// A character exists but has no presence in the manuscript at all.
  orphanEntity,

  /// A character is named in the prose, but nothing connects them to it.
  unlinkedMention,

  /// A plotline, subplot or arc that no scene belongs to.
  orphanPlot,

  /// A relationship the author established and never resolved.
  unresolvedRelationship,

  /// Two events that cannot both be true of the same character at once.
  timelineConflict,

  /// A scene set in a location the world database does not hold.
  locationGap,

  /// A scene whose point of view belongs to nobody in the project.
  ///
  /// Not in the original eight conditions, but the exact mirror of
  /// [locationGap] — the same analyzer pass decides both, so reporting the
  /// place and discarding the person would be throwing away a correct finding
  /// for no reason.
  castGap,

  /// Research attached to the story that cites no source.
  researchGap,

  /// World entities with no connection to the manuscript.
  unusedWorldbuilding,
}

extension StructuralConditionData on StructuralCondition {
  /// The condition's name, as the author reads it.
  String get label => switch (this) {
        StructuralCondition.orphanEntity => 'Orphan entity',
        StructuralCondition.unlinkedMention => 'Unlinked mention',
        StructuralCondition.orphanPlot => 'Orphan plot',
        StructuralCondition.unresolvedRelationship => 'Unresolved relationship',
        StructuralCondition.timelineConflict => 'Timeline conflict',
        StructuralCondition.locationGap => 'Location gap',
        StructuralCondition.castGap => 'Cast gap',
        StructuralCondition.researchGap => 'Research gap',
        StructuralCondition.unusedWorldbuilding => 'Unused worldbuilding',
      };

  /// One line explaining what the condition means, shown under the group
  /// heading so the author never has to guess what a finding is claiming.
  String get description => switch (this) {
        StructuralCondition.orphanEntity =>
          'Exists in your world, but never reaches the page.',
        StructuralCondition.unlinkedMention =>
          'Written into the prose, but not connected to it.',
        StructuralCondition.orphanPlot =>
          'Story structure that no scene belongs to.',
        StructuralCondition.unresolvedRelationship =>
          'Established, and never brought to a close.',
        StructuralCondition.timelineConflict =>
          'Events that cannot both be true as dated.',
        StructuralCondition.locationGap =>
          'Places your scenes use that your world does not hold.',
        StructuralCondition.castGap =>
          'People your scenes name that your project does not hold.',
        StructuralCondition.researchGap =>
          'Research in use with nothing to cite.',
        StructuralCondition.unusedWorldbuilding =>
          'Built, and not yet drawn on.',
      };

  /// The Studio that owns the records this condition is about.
  IntelligenceDestination get destination => switch (this) {
        StructuralCondition.orphanEntity ||
        StructuralCondition.unlinkedMention ||
        StructuralCondition.unresolvedRelationship =>
          IntelligenceDestination.characters,
        StructuralCondition.orphanPlot => IntelligenceDestination.plot,
        StructuralCondition.timelineConflict =>
          IntelligenceDestination.timeline,
        StructuralCondition.locationGap ||
        StructuralCondition.unusedWorldbuilding =>
          IntelligenceDestination.world,
        StructuralCondition.castGap => IntelligenceDestination.characters,
        StructuralCondition.researchGap => IntelligenceDestination.research,
      };
}

/// Where a finding can send the author.
///
/// The layer never names the shell's section enum directly — routing belongs
/// to the shell, exactly as it does for `WorldBoardDestination` and
/// `SearchDestination`.
enum IntelligenceDestination {
  characters,
  world,
  plot,
  timeline,
  research,
  manuscript,
}

/// A resolution the author can apply without leaving the Intelligence Studio.
///
/// This is deliberately thin. It carries the [ContinuityIntegrityIssue] the
/// existing `ContinuityActionService` already knows how to resolve, plus the
/// identifiers that service needs — no new write path, no second action model.
/// A finding with no [StructuralAction] is informational, and says so.
class StructuralAction {
  const StructuralAction.create({
    required this.issue,
    required this.name,
  })  : sourceId = null,
        targetId = null,
        connectionTypeId = null;

  const StructuralAction.link({
    required this.issue,
    required String this.sourceId,
    required String this.targetId,
    required String this.connectionTypeId,
  }) : name = '';

  /// The recommendation `ContinuityActionService` resolves.
  final ContinuityIntegrityIssue issue;

  /// The name a `create` action gives the record it creates.
  final String name;

  /// The endpoints and type a `link` action connects.
  final String? sourceId;
  final String? targetId;
  final String? connectionTypeId;

  ContinuityActionKind get kind => issue.actionKind;

  /// The button the author sees.
  String get label => switch (kind) {
        ContinuityActionKind.create => 'Create "$name"',
        ContinuityActionKind.link => 'Connect',
        ContinuityActionKind.review => 'Review',
      };
}

/// One structural condition, found once, about one part of the project.
class StructuralFinding {
  const StructuralFinding({
    required this.condition,
    required this.severity,
    required this.title,
    required this.detail,
    required this.recommendation,
    required this.entityIds,
    this.action,
  });

  final StructuralCondition condition;

  /// The shared AuthorOS severity scale — see `lib/continuity.dart`.
  final ContinuitySeverity severity;

  /// What was found, in the author's own vocabulary: "Kali never appears in
  /// the manuscript."
  final String title;

  /// Why the layer believes it.
  final String detail;

  /// What to do about it.
  final String recommendation;

  /// The records and live manuscript nodes this finding is about. Never names
  /// a scene the author cannot see: the survey builds its node set from the
  /// loaded manuscript, not from the node table.
  final List<String> entityIds;

  /// Set only where an existing continuity action already fits.
  final StructuralAction? action;

  IntelligenceDestination get destination => condition.destination;
}

/// Every finding in one project, grouped and counted.
///
/// The report carries **no score**. `ContinuityAnalyzer.summaryFor` scores
/// `100 − 25·critical − 10·warning − 4·notice`, which is right for a single
/// record and saturates to zero across a whole project — four criticals, or
/// twenty-five notices, and every book reads 0 out of 100. A project-level
/// number that is always 0 tells the author nothing, so this reports coverage
/// instead: how many findings there are, and how much of the world actually
/// reaches the page.
class IntelligenceReport {
  const IntelligenceReport({
    required this.projectId,
    required this.projectTitle,
    required this.findings,
    required this.connectedWorldEntities,
    required this.totalWorldEntities,
    required this.hasManuscript,
  });

  static const empty = IntelligenceReport(
    projectId: '',
    projectTitle: '',
    findings: [],
    connectedWorldEntities: 0,
    totalWorldEntities: 0,
    hasManuscript: false,
  );

  final String projectId;
  final String projectTitle;

  /// Ordered most severe first, then by condition, then by title, so the list
  /// is stable across reloads and a test can assert on it.
  final List<StructuralFinding> findings;

  /// World entities that reach the manuscript, and how many there are in all.
  final int connectedWorldEntities;
  final int totalWorldEntities;

  /// False when the project has no prose yet. Several conditions cannot be
  /// judged without a manuscript, and a brand-new project should not open to
  /// a wall of findings that only say "you have not written anything."
  final bool hasManuscript;

  bool get isClean => findings.isEmpty;

  int get criticalCount => _countOf(ContinuitySeverity.critical);
  int get warningCount => _countOf(ContinuitySeverity.warning);
  int get noticeCount => _countOf(ContinuitySeverity.notice);

  int _countOf(ContinuitySeverity severity) =>
      findings.where((finding) => finding.severity == severity).length;

  /// Findings for one condition, in report order.
  List<StructuralFinding> forCondition(StructuralCondition condition) =>
      findings.where((finding) => finding.condition == condition).toList();

  /// The conditions that actually fired, in report order — the empty ones are
  /// not worth a heading.
  List<StructuralCondition> get activeConditions => [
        for (final condition in StructuralCondition.values)
          if (findings.any((finding) => finding.condition == condition))
            condition,
      ];

  /// World entities with no manuscript connection.
  int get unusedWorldEntities => totalWorldEntities - connectedWorldEntities;
}

/// Orders findings so the most serious reach the author first, and so two runs
/// over unchanged data produce the same list.
int compareFindings(StructuralFinding left, StructuralFinding right) {
  final bySeverity =
      _severityRank(right.severity).compareTo(_severityRank(left.severity));
  if (bySeverity != 0) return bySeverity;
  final byCondition = left.condition.index.compareTo(right.condition.index);
  if (byCondition != 0) return byCondition;
  return left.title.compareTo(right.title);
}

int _severityRank(ContinuitySeverity severity) => switch (severity) {
      ContinuitySeverity.critical => 3,
      ContinuitySeverity.warning => 2,
      ContinuitySeverity.notice => 1,
    };
