import 'continuity.dart';
import 'core/connected_domain.dart';
import 'core/story_codex_domain.dart';
import 'core/entity_recognition.dart';

/// Codex-side inputs and resolution parameters for one Continuity
/// Intelligence recommendation.
///
/// The Codex workspace does not implement a second continuity engine. It
/// derives [ContinuityWarning]s from Universal Record data, hands them to the
/// existing [ContinuityAnalyzer], and hands resolution back to the existing
/// `ContinuityActionService`. This class only carries the extra identifiers
/// those services need.
class CodexContinuityFinding {
  const CodexContinuityFinding({
    required this.warning,
    required this.entryId,
    this.targetId,
    this.missingName = '',
    this.connectionTypeId = 'relatedTo',
  });

  final ContinuityWarning warning;

  /// The Codex entry the recommendation is anchored to.
  final String entryId;

  /// The record a `link` recommendation should connect [entryId] to.
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

/// A Codex entry's continuity findings plus the integrity summary produced by
/// the existing [ContinuityAnalyzer].
class CodexContinuityReport {
  const CodexContinuityReport({
    required this.summary,
    required this.findings,
  });

  static const empty = CodexContinuityReport(
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
  final List<CodexContinuityFinding> findings;

  bool get isClean => findings.isEmpty;

  CodexContinuityFinding? findingFor(ContinuityIntegrityIssue issue) {
    final index = summary.issues.indexOf(issue);
    return index >= 0 && index < findings.length ? findings[index] : null;
  }
}

/// Derives the Continuity Intelligence recommendations that apply to Codex
/// knowledge records.
///
/// Two rules apply to a knowledge base:
///
/// * **Unlinked mention** - an entry names another entry in its prose but no
///   connection records the relationship. Resolved with a `link` action.
/// * **Missing referenced record** - a roster-style field names a person or
///   place that has no record at all. Resolved with a `create` action.
class CodexContinuityIntelligence {
  const CodexContinuityIntelligence({
    this.maxFindingsPerEntry = 6,
    this.minimumMentionLength = 4,
  });

  final int maxFindingsPerEntry;

  /// Names shorter than this are ignored so common words produce no noise.
  final int minimumMentionLength;

  static const characterRosterFields = <String>{
    'importantPeople',
    'members',
    'leadership',
  };

  static const locationRosterFields = <String>{
    'nearbyLocations',
    'territory',
  };

  /// Analyses [entry] against the rest of the project.
  ///
  /// [entries] is the visible Codex entry set, [links] the connections already
  /// recorded for [entry], and [knownNames] every record title and alias in the
  /// project (Characters, World, Timeline, Plot and Manuscript included) so a
  /// name owned by another Studio is never reported as missing.
  CodexContinuityReport analyze({
    required CodexEntry entry,
    required List<CodexEntry> entries,
    required List<RecordLink> links,
    required Set<String> knownNames,
  }) {
    final findings = <CodexContinuityFinding>[];
    final connectedIds = <String>{
      for (final link in links)
        link.sourceId == entry.id ? link.targetId : link.sourceId,
    };
    final prose = [
      entry.summary,
      entry.content,
      for (final value in entry.structuredFields.values)
        if (value is String) value,
    ].join('\n').toLowerCase();
    final normalizedKnown = <String>{
      for (final name in knownNames) name.trim().toLowerCase(),
    }..remove('');

    for (final candidate in entries) {
      if (findings.length >= maxFindingsPerEntry) break;
      if (candidate.id == entry.id ||
          candidate.isArchived ||
          candidate.isDeleted) {
        continue;
      }
      if (connectedIds.contains(candidate.id)) continue;
      final mention = [candidate.title, ...candidate.aliases]
          .map((name) => name.trim())
          .where((name) => name.length >= minimumMentionLength)
          .where((name) => mentionsName(prose, name))
          .firstOrNull;
      if (mention == null) continue;
      findings.add(CodexContinuityFinding(
        entryId: entry.id,
        targetId: candidate.id,
        warning: ContinuityWarning(
          type: ContinuityWarningType.missingRelationship,
          severity: ContinuitySeverity.notice,
          title: 'Unlinked mention of ${candidate.title}',
          message: '${entry.title} refers to "$mention" but no connection '
              'records the relationship.',
          eventIds: [entry.id, candidate.id],
        ),
      ));
    }

    for (final field in entry.structuredFields.entries) {
      if (findings.length >= maxFindingsPerEntry) break;
      final isCharacterRoster = characterRosterFields.contains(field.key);
      final isLocationRoster = locationRosterFields.contains(field.key);
      if (!isCharacterRoster && !isLocationRoster) continue;
      for (final name in _names(field.value)) {
        if (findings.length >= maxFindingsPerEntry) break;
        if (name.length < minimumMentionLength) continue;
        if (normalizedKnown.contains(name.toLowerCase())) continue;
        findings.add(CodexContinuityFinding(
          entryId: entry.id,
          missingName: name,
          warning: ContinuityWarning(
            type: isCharacterRoster
                ? ContinuityWarningType.unknownCharacter
                : ContinuityWarningType.unknownLocation,
            severity: ContinuitySeverity.warning,
            title: 'Missing record for $name',
            message: '${entry.title} lists "$name" under ${field.key}, but no '
                'record with that name exists in this project.',
            eventIds: [entry.id],
          ),
        ));
      }
    }

    if (findings.isEmpty) return CodexContinuityReport.empty;
    return CodexContinuityReport(
      summary: ContinuityAnalyzer.summaryFor(
        findings.map((finding) => finding.warning).toList(),
      ),
      findings: findings,
    );
  }

  /// Every title and alias that exists in the project, for missing-record
  /// checks. Accepts raw Universal Records so a name owned by another Studio
  /// counts as known.
  static Set<String> knownNames(Iterable<AuthorRecord> records) => <String>{
        for (final record in records) ...[
          record.title.trim(),
          ...CodexEntry(record).aliases.map((alias) => alias.trim()),
        ],
      }..remove('');
}


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
