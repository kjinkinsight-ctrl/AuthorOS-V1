import 'continuity.dart';
import 'core/book_scope.dart';
import 'core/canon_facts.dart';
import 'core/connected_domain.dart';
import 'core/entity_recognition.dart';
import 'core/record_service.dart';
import 'persistence/authoros_database.dart';

/// One contradiction, and both sides of it.
///
/// Carries the ids the author needs to look at each side, because a
/// contradiction the author cannot inspect is just an accusation.
class CanonConflictFinding {
  const CanonConflictFinding({
    required this.warning,
    required this.recordId,
    required this.fieldId,
    this.canonValue,
    this.otherValue,
    this.otherRecordId,
    this.bookId,
  });

  final ContinuityWarning warning;

  /// The entity the conflict is about.
  final String recordId;

  /// The field that disagrees, or empty when the conflict is not field-level.
  final String fieldId;

  final Object? canonValue;
  final Object? otherValue;

  /// The record holding the other side — a book state, or a duplicate.
  final String? otherRecordId;

  final String? bookId;

  /// Contradictions are always reviewed. There is no resolve action, by
  /// design: choosing which side is canon is the author's judgement.
  ContinuityActionKind get actionKind => ContinuityActionKind.review;
}

/// A record's contradictions, plus the shared integrity summary.
class CanonConflictReport {
  const CanonConflictReport({
    required this.summary,
    required this.findings,
  });

  static const empty = CanonConflictReport(
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
  final List<CanonConflictFinding> findings;

  bool get isClean => findings.isEmpty;

  CanonConflictFinding? findingFor(ContinuityIntegrityIssue issue) {
    final index = summary.issues.indexOf(issue);
    return index >= 0 && index < findings.length ? findings[index] : null;
  }

  List<CanonConflictFinding> forField(String fieldId) =>
      findings.where((finding) => finding.fieldId == fieldId).toList();
}

/// Finds contradictions between typed facts.
///
/// **AuthorOS never silently decides canon.** This analyzer writes nothing: it
/// points at two records that disagree and leaves the decision to the author.
/// Resolving a conflict is an ordinary record edit, versioned and audited like
/// any other.
///
/// Every rule reads structured data — record fields, per-book states, and typed
/// relationships. **Prose is never parsed for facts.** A rule that guessed at a
/// number in a sentence would produce contradictions the author has to argue
/// with, and the first false accusation is the one that gets the whole feature
/// switched off.
class CanonConflictAnalyzer {
  const CanonConflictAnalyzer({
    required this.projectId,
    required this.repository,
    this.monotonicFieldIds = defaultMonotonicFieldIds,
    this.singleValuedConnectionTypeIds = defaultSingleValuedConnectionTypeIds,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// Numeric fields that cannot decrease as a series advances.
  ///
  /// A character does not get younger between Book 2 and Book 3. Declared
  /// rather than inferred, because "which numbers only go up" is a fact about
  /// the story, not something to guess.
  final Set<String> monotonicFieldIds;

  /// Relationships an entity can only have one of.
  ///
  /// Two different birthplaces is a contradiction; two friends is not.
  final Set<String> singleValuedConnectionTypeIds;

  static const defaultMonotonicFieldIds = <String>{
    'identity.age',
    'age',
  };

  static const defaultSingleValuedConnectionTypeIds = <String>{
    'bornIn',
    'parentOf',
  };

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  /// Every contradiction involving [recordId].
  Future<CanonConflictReport> analyze(String recordId) async {
    final canon = await records.getRecord(recordId);
    if (canon == null) return CanonConflictReport.empty;

    final all = await repository.recordsByProject(projectId);
    final active = all
        .where((record) => record.status == AuthorRecordStatus.active)
        .toList();
    final states = active
        .where((record) => record.typeId == BookScope.entityStateTypeId)
        .where((record) => BookScope.canonicalIdOf(record) == recordId)
        .toList();
    final books = {
      for (final record in active)
        if (record.typeId == BookScope.bookTypeId) record.id: record,
    };

    final findings = <CanonConflictFinding>[
      ..._canonVersusState(canon, states, books),
      ..._monotonicAcrossBooks(canon, states, books),
      ..._duplicateCanon(canon, active),
      ...await _singleValuedRelationships(canon, active),
    ];

    if (findings.isEmpty) return CanonConflictReport.empty;
    return CanonConflictReport(
      summary: ContinuityAnalyzer.summaryFor(
        findings.map((finding) => finding.warning).toList(),
      ),
      findings: findings,
    );
  }

  /// How much to trust one of [recordId]'s fields right now.
  Future<CanonFact> factFor(
    String recordId,
    String fieldId, {
    CanonConflictReport? report,
  }) async {
    final canon = await records.getRecord(recordId);
    if (canon == null) {
      return CanonFact(
        recordId: recordId,
        fieldId: fieldId,
        value: null,
        status: CanonFactStatus.unknown,
        sourceCount: 0,
        agreeingStateCount: 0,
        contradictionCount: 0,
      );
    }
    final conflicts = report ?? await analyze(recordId);
    final sources = EntityNames.split(canon.fields['sourceReferences']).length +
        await _documentingSourceCount(recordId);
    final states = await _statesFor(recordId);
    final agreeing = states
        .where((state) =>
            BookScope.overridesOf(state)[fieldId] == canon.fields[fieldId])
        .length;

    return CanonFact(
      recordId: recordId,
      fieldId: fieldId,
      value: canon.fields[fieldId],
      status: CanonFields.statusFor(canon, fieldId),
      sourceCount: sources,
      agreeingStateCount: agreeing,
      contradictionCount: conflicts.forField(fieldId).length,
    );
  }

  /// [factFor]'s confidence, from 0 to 1.
  Future<double> confidenceFor(
    String recordId,
    String fieldId, {
    CanonConflictReport? report,
  }) async =>
      canonConfidence(await factFor(recordId, fieldId, report: report));

  // ---------------------------------------------------------------- rules --

  /// A book asserts a different value from canon, and calls it canon.
  ///
  /// The directive's example: the profile says 27, Book 3 says 29. Both are
  /// typed values the author entered; neither was scraped from a sentence.
  Iterable<CanonConflictFinding> _canonVersusState(
    AuthorRecord canon,
    List<AuthorRecord> states,
    Map<String, AuthorRecord> books,
  ) sync* {
    for (final state in states) {
      final bookTitle = books[state.bookId]?.title ?? 'another book';
      for (final entry in BookScope.overridesOf(state).entries) {
        final canonValue = canon.fields[entry.key];
        if (canonValue == null || entry.value == null) continue;
        if (canonValue == entry.value) continue;
        if (CanonFields.statusFor(state, entry.key) != CanonFactStatus.canon &&
            CanonFields.statusFor(canon, entry.key) != CanonFactStatus.canon) {
          // Neither side claims to be canon, so they are alternatives rather
          // than a contradiction.
          continue;
        }
        yield CanonConflictFinding(
          recordId: canon.id,
          fieldId: entry.key,
          canonValue: canonValue,
          otherValue: entry.value,
          otherRecordId: state.id,
          bookId: state.bookId,
          warning: ContinuityWarning(
            type: ContinuityWarningType.canonContradiction,
            severity: ContinuitySeverity.warning,
            title: '${canon.title}: ${entry.key} disagrees across books',
            message: 'Series canon says "$canonValue" but $bookTitle says '
                '"${entry.value}".',
            eventIds: [canon.id, state.id],
          ),
        );
      }
    }
  }

  /// A number that can only rise goes down as the series advances.
  Iterable<CanonConflictFinding> _monotonicAcrossBooks(
    AuthorRecord canon,
    List<AuthorRecord> states,
    Map<String, AuthorRecord> books,
  ) sync* {
    for (final fieldId in monotonicFieldIds) {
      final points = <({num order, num value, AuthorRecord state})>[];
      for (final state in states) {
        final value = BookScope.overridesOf(state)[fieldId];
        final book = books[state.bookId];
        if (value is! num || book == null) continue;
        final order = book.fields['order'];
        points.add((
          order: order is num ? order : 0,
          value: value,
          state: state,
        ));
      }
      if (points.length < 2) continue;
      points.sort((a, b) => a.order.compareTo(b.order));
      for (var i = 1; i < points.length; i++) {
        final earlier = points[i - 1];
        final later = points[i];
        if (later.value >= earlier.value) continue;
        yield CanonConflictFinding(
          recordId: canon.id,
          fieldId: fieldId,
          canonValue: earlier.value,
          otherValue: later.value,
          otherRecordId: later.state.id,
          bookId: later.state.bookId,
          warning: ContinuityWarning(
            type: ContinuityWarningType.canonContradiction,
            severity: ContinuitySeverity.critical,
            title: '${canon.title}: $fieldId goes backwards',
            message: '${books[earlier.state.bookId]?.title ?? "An earlier book"} '
                'says "${earlier.value}" but '
                '${books[later.state.bookId]?.title ?? "a later book"} says '
                '"${later.value}", and $fieldId cannot decrease.',
            eventIds: [canon.id, later.state.id],
          ),
        );
      }
    }
  }

  /// Two active records claim canon under the same name.
  Iterable<CanonConflictFinding> _duplicateCanon(
    AuthorRecord canon,
    List<AuthorRecord> active,
  ) sync* {
    if (canon.canonStatus != CanonStatus.canon) return;
    final names = EntityNames.namesOf(canon)
        .map((name) => name.toLowerCase())
        .toSet();
    for (final other in active) {
      if (other.id == canon.id) continue;
      if (other.canonStatus != CanonStatus.canon) continue;
      if (other.typeId == BookScope.entityStateTypeId) continue;
      final shared = EntityNames.namesOf(other)
          .map((name) => name.toLowerCase())
          .where(names.contains)
          .toList();
      if (shared.isEmpty) continue;
      yield CanonConflictFinding(
        recordId: canon.id,
        fieldId: '',
        otherRecordId: other.id,
        warning: ContinuityWarning(
          type: ContinuityWarningType.canonContradiction,
          severity: ContinuitySeverity.notice,
          title: 'Two canon records answer to "${shared.first}"',
          message: '${canon.title} and ${other.title} are both canon and share '
              'the name "${shared.first}". A reader — and the recogniser — '
              'cannot tell which one the manuscript means.',
          eventIds: [canon.id, other.id],
        ),
      );
    }
  }

  /// An entity has two of something it can only have one of.
  Future<List<CanonConflictFinding>> _singleValuedRelationships(
    AuthorRecord canon,
    List<AuthorRecord> active,
  ) async {
    final titles = {for (final record in active) record.id: record.title};
    final byType = <String, List<String>>{};
    for (final link in await repository.outgoingLinks(canon.id)) {
      if (!singleValuedConnectionTypeIds.contains(link.typeId)) continue;
      (byType[link.typeId] ??= <String>[]).add(link.targetId);
    }
    final findings = <CanonConflictFinding>[];
    for (final entry in byType.entries) {
      final targets = entry.value.toSet().toList();
      if (targets.length < 2) continue;
      findings.add(CanonConflictFinding(
        recordId: canon.id,
        fieldId: '',
        otherRecordId: targets[1],
        warning: ContinuityWarning(
          type: ContinuityWarningType.canonContradiction,
          severity: ContinuitySeverity.warning,
          title: '${canon.title} has ${targets.length} "${entry.key}" targets',
          message: '${canon.title} is "${entry.key}" to '
              '${targets.map((id) => titles[id] ?? id).join(" and ")}, but only '
              'one of those can be true.',
          eventIds: [canon.id, ...targets],
        ),
      ));
    }
    return findings;
  }

  /// How many live sources document [recordId].
  ///
  /// A `documents` link from a research entry is a source. One from a book
  /// state is not — that is the state pointing back at its own canon, and
  /// counting it would let an entity vouch for itself. Archived and deleted
  /// sources do not count either: a source the author has retired should stop
  /// propping the fact up.
  Future<int> _documentingSourceCount(String recordId) async {
    var count = 0;
    for (final link in await repository.incomingLinks(recordId)) {
      if (link.typeId != BookScope.documentsTypeId) continue;
      final source = await repository.recordById(link.sourceId);
      if (source == null) continue;
      if (source.status != AuthorRecordStatus.active) continue;
      if (source.typeId == BookScope.entityStateTypeId) continue;
      count++;
    }
    return count;
  }

  Future<List<AuthorRecord>> _statesFor(String recordId) async {
    final states = await repository.recordsByTypeAndScope(
      typeId: BookScope.entityStateTypeId,
      scopeId: projectId,
    );
    return states
        .where((state) => BookScope.canonicalIdOf(state) == recordId)
        .where((state) => state.status == AuthorRecordStatus.active)
        .toList();
  }
}
