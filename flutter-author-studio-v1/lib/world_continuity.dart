import 'continuity.dart';
import 'core/connected_domain.dart';
import 'core/prose_mentions.dart';
import 'core/world_record_types.dart';
import 'world_service.dart';

/// World-side inputs and resolution parameters for one Continuity
/// Intelligence recommendation.
///
/// World Studio does not implement a second continuity engine. It derives
/// [ContinuityWarning]s from Universal Record data, hands them to the existing
/// [ContinuityAnalyzer], and hands resolution back to the existing
/// `ContinuityActionService`. This class only carries the extra identifiers
/// those services need.
class WorldContinuityFinding {
  const WorldContinuityFinding({
    required this.warning,
    required this.recordId,
    this.targetId,
    this.missingName = '',
    this.connectionTypeId = 'relatedTo',
  });

  final ContinuityWarning warning;

  /// The World record the recommendation is anchored to.
  final String recordId;

  /// The record a `link` recommendation should connect [recordId] to.
  final String? targetId;

  /// The name a `create` recommendation should use.
  final String missingName;

  /// The connection type a `link` recommendation should create.
  final String connectionTypeId;

  ContinuityActionKind get actionKind => switch (warning.type) {
        ContinuityWarningType.unknownCharacter ||
        ContinuityWarningType.unknownLocation =>
          ContinuityActionKind.create,
        ContinuityWarningType.missingRelationship => ContinuityActionKind.link,
        _ => ContinuityActionKind.review,
      };
}

/// A World record's continuity findings plus the integrity summary produced by
/// the existing [ContinuityAnalyzer].
class WorldContinuityReport {
  const WorldContinuityReport({
    required this.summary,
    required this.findings,
  });

  static const empty = WorldContinuityReport(
    summary: ContinuityIntegritySummary(
      score: 100,
      criticalCount: 0,
      warningCount: 0,
      noticeCount: 0,
      issues: [],
    ),
    findings: [],
  );

  final ContinuityIntegritySummary summary;

  /// Parallel to [ContinuityIntegritySummary.issues]: index `i` of one matches
  /// index `i` of the other, because `summaryFor` maps warnings in order.
  final List<WorldContinuityFinding> findings;

  bool get isClean => findings.isEmpty;

  WorldContinuityFinding? findingFor(ContinuityIntegrityIssue issue) {
    final index = summary.issues.indexOf(issue);
    return index >= 0 && index < findings.length ? findings[index] : null;
  }
}

/// Derives the Continuity Intelligence recommendations that apply to World
/// records.
///
/// Four rules apply to a world model:
///
/// * **Unlinked mention** - a record names another record in its prose but no
///   connection records the relationship. Resolved with a `link` action.
/// * **Missing place** - a location-reference or place roster field names a
///   place that has no record. Resolved with a `create` action.
/// * **Missing person** - a people roster field names someone with no record.
///   Resolved with a `create` action.
/// * **Detached route** - a route's endpoints are missing, identical, or sit
///   under different root worlds, so the journey cannot be travelled. Resolved
///   by review.
class WorldContinuityIntelligence {
  const WorldContinuityIntelligence({
    this.maxFindingsPerRecord = 6,
    this.minimumMentionLength = 4,
  });

  final int maxFindingsPerRecord;

  /// Names shorter than this are ignored so common words produce no noise.
  final int minimumMentionLength;

  static const characterRosterFields = <String>{
    'importantPeople',
    'notableResidents',
    'rulers',
    'leadership',
    'members',
    'founders',
  };

  static const locationRosterFields = <String>{
    'nearbyLocations',
    'territory',
    'borders',
    'capital',
    'majorCities',
    'landmarks',
  };

  /// Analyses [record] against the rest of the project.
  ///
  /// [records] is the visible World record set used for mention matching,
  /// [links] the connections already recorded for [record], and [knownNames]
  /// every record title and alias in the project (Characters, Codex, Timeline,
  /// Plot and Manuscript included) so a name owned by another Studio is never
  /// reported as missing. [hierarchy] lets the route rule check that both
  /// endpoints share a root world; pass null to skip that rule.
  /// [locationFieldIds] adds template-declared location references to the
  /// static place roster.
  WorldContinuityReport analyze({
    required AuthorRecord record,
    required List<AuthorRecord> records,
    required List<RecordLink> links,
    required Set<String> knownNames,
    WorldHierarchy? hierarchy,
    Set<String> locationFieldIds = const {},
  }) {
    final findings = <WorldContinuityFinding>[];
    final connectedIds = <String>{
      for (final link in links)
        link.sourceId == record.id ? link.targetId : link.sourceId,
    };
    final prose = [
      for (final value in record.fields.entries)
        if (!value.key.startsWith('_') && value.value is String)
          value.value as String,
    ].join('\n').toLowerCase();
    final normalizedKnown = <String>{
      for (final name in knownNames) name.trim().toLowerCase(),
    }..remove('');

    for (final candidate in records) {
      if (findings.length >= maxFindingsPerRecord) break;
      if (candidate.id == record.id ||
          candidate.status != AuthorRecordStatus.active) {
        continue;
      }
      if (connectedIds.contains(candidate.id)) continue;
      final mention = [candidate.title, ..._aliases(candidate)]
          .map((name) => name.trim())
          .where((name) => name.length >= minimumMentionLength)
          .where((name) => proseMentions(prose, name))
          .firstOrNull;
      if (mention == null) continue;
      findings.add(WorldContinuityFinding(
        recordId: record.id,
        targetId: candidate.id,
        warning: ContinuityWarning(
          type: ContinuityWarningType.missingRelationship,
          severity: ContinuitySeverity.notice,
          title: 'Unlinked mention of ${candidate.title}',
          message: '${record.title} refers to "$mention" but no connection '
              'records the relationship.',
          eventIds: [record.id, candidate.id],
        ),
      ));
    }

    final placeFields = {...locationRosterFields, ...locationFieldIds};
    for (final field in record.fields.entries) {
      if (findings.length >= maxFindingsPerRecord) break;
      if (field.key.startsWith('_')) continue;
      final isPlaceRoster = placeFields.contains(field.key);
      final isPeopleRoster = characterRosterFields.contains(field.key);
      if (!isPlaceRoster && !isPeopleRoster) continue;
      for (final name in _names(field.value)) {
        if (findings.length >= maxFindingsPerRecord) break;
        if (name.length < minimumMentionLength) continue;
        if (normalizedKnown.contains(name.toLowerCase())) continue;
        findings.add(WorldContinuityFinding(
          recordId: record.id,
          missingName: name,
          warning: ContinuityWarning(
            type: isPeopleRoster
                ? ContinuityWarningType.unknownCharacter
                : ContinuityWarningType.unknownLocation,
            severity: ContinuitySeverity.warning,
            title: 'Missing record for $name',
            message: '${record.title} lists "$name" under ${field.key}, but no '
                'record with that name exists in this project.',
            eventIds: [record.id],
          ),
        ));
      }
    }

    if (WorldRecordTypes.routeTypeIds.contains(record.typeId)) {
      final detached = _routeProblem(record, records, hierarchy);
      if (detached != null && findings.length < maxFindingsPerRecord) {
        findings.add(WorldContinuityFinding(
          recordId: record.id,
          warning: ContinuityWarning(
            type: ContinuityWarningType.impossibleTravel,
            severity: ContinuitySeverity.critical,
            title: 'Route ${record.title} cannot be travelled',
            message: detached,
            eventIds: [record.id],
          ),
        ));
      }
    }

    if (findings.isEmpty) return WorldContinuityReport.empty;
    return WorldContinuityReport(
      summary: ContinuityAnalyzer.summaryFor(
        findings.map((finding) => finding.warning).toList(),
      ),
      findings: findings,
    );
  }

  /// Every title and alias in the project, for missing-record checks. Accepts
  /// raw Universal Records so a name owned by another Studio counts as known.
  static Set<String> knownNames(Iterable<AuthorRecord> records) => <String>{
        for (final record in records) ...[
          record.title.trim(),
          ..._aliases(record).map((alias) => alias.trim()),
        ],
      }..remove('');

  String? _routeProblem(
    AuthorRecord route,
    List<AuthorRecord> records,
    WorldHierarchy? hierarchy,
  ) {
    final startId = _string(route.fields['startId']);
    final endId = _string(route.fields['endId']);
    if (startId.isEmpty || endId.isEmpty) {
      return 'The route does not name both endpoints, so no journey can be '
          'planned along it.';
    }
    if (startId == endId) {
      return 'The route starts and ends at the same place.';
    }
    final byId = {for (final record in records) record.id: record};
    final start = byId[startId];
    final end = byId[endId];
    if (start == null || end == null) {
      return 'One endpoint of this route no longer has a record.';
    }
    if (hierarchy == null) return null;
    final startRoot = hierarchy.rootWorldOf(startId) ?? hierarchy.rootOf(startId);
    final endRoot = hierarchy.rootWorldOf(endId) ?? hierarchy.rootOf(endId);
    if (startRoot != null && endRoot != null && startRoot.id != endRoot.id) {
      return '${start.title} sits under ${startRoot.title} while ${end.title} '
          'sits under ${endRoot.title}, so the two ends are not connected.';
    }
    return null;
  }
}

List<String> _aliases(AuthorRecord record) => <String>[
      ..._names(record.fields['aliases']),
      ..._names(record.fields['alternateNames']),
      ..._names(record.fields['historicalNames']),
      ..._names(record.fields['localNames']),
      ..._names(record.fields['nicknames']),
    ];


List<String> _names(Object? value) {
  if (value is String) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

String _string(Object? value) => value is String ? value.trim() : '';
