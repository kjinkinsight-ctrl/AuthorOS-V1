/// AuthorOS Intelligence Layer — the structural detectors.
///
/// Every detector is a pure function from a [ProjectSurvey] to findings. None
/// of them queries, and none of them writes. That makes each one testable
/// against a hand-built survey with no database at all, and it means the whole
/// analysis costs the same four reads however many detectors exist.
///
/// Where AuthorOS already knows how to find something, these functions call
/// that code rather than restating the rule:
///
/// * Unlinked mentions, location gaps and cast gaps come from
///   [ManuscriptContinuityIntelligence], which the Manuscript workspace
///   already runs one scene at a time. This rolls it over every scene.
/// * Timeline conflicts come from [ContinuityAnalyzer.analyze], which has
///   implemented overlap, travel, range and sequence checking all along and,
///   until now, had no production caller at all.
/// * Unresolved plot structure comes from Plot Studio's own definition of
///   "resolved", read off the same `plotStatus` field `PlotService` uses.
library;

import '../continuity.dart';
import '../core/connected_domain.dart';
import '../core/prose_mentions.dart';
import '../core/research_record_types.dart';
import '../core/timeline_record_types.dart';
import '../manuscript_continuity.dart';
import '../timeline_domain.dart';
import '../timeline_service.dart';
import 'intelligence_models.dart';
import 'project_survey.dart';

/// The character-to-character connection types Characters Studio treats as a
/// relationship, taken from `CharacterService.getCharacterRelationships` so
/// the two never drift apart.
const relationshipConnectionTypeIds = <String>{
  'relatedTo',
  'parentOf',
  'guardianOf',
  'friendOf',
  'enemyOf',
  'alliedWith',
  'rivalOf',
  'mentors',
  'partnerOf',
  'knows',
};

/// Plot types that carry a storyline a scene can belong to.
const plotlineTypeIds = <String>{
  'plotline',
  'subplot',
  'arc',
  'character-arc',
  'relationship-arc',
  'world-arc',
  'political-arc',
  'romance-arc',
  'mystery-arc',
};

/// The connection types that put a scene inside a plotline.
const plotSceneConnectionTypeIds = <String>{
  'appearsIn',
  'plannedFor',
  'fulfilledBy',
  'resolvesIn',
  'depicts',
};

/// Names shorter than this are never treated as a prose mention, so common
/// short words do not manufacture findings. Matches the Manuscript workspace's
/// own threshold.
const minimumMentionLength = 4;

/// Runs every detector and returns the findings in report order.
List<StructuralFinding> detectAll(ProjectSurvey survey) => [
      ...detectOrphanEntities(survey),
      ...detectManuscriptGaps(survey),
      ...detectOrphanPlots(survey),
      ...detectUnresolvedRelationships(survey),
      ...detectTimelineConflicts(survey),
      ...detectResearchGaps(survey),
      ...detectUnusedWorldbuilding(survey),
    ]..sort(compareFindings);

// ---------------------------------------------------------------------------
// 1. Orphan entity
// ---------------------------------------------------------------------------

/// Characters that never reach the page at all.
///
/// The rule is deliberately the conjunction of two tests. A character is an
/// orphan only when they have **no** `appearsIn`/`mentionedIn` connection to a
/// live scene or chapter **and** their name appears nowhere in the prose.
///
/// Requiring both matters. A link-only rule would flag every character in a
/// project that has not started connecting things — which is most projects on
/// day one — and the screen would open as a wall of false positives that says
/// nothing. A character the author has written about but not yet connected is
/// a different, more useful, and fixable condition: see
/// [detectManuscriptGaps], which reports it as an unlinked mention.
List<StructuralFinding> detectOrphanEntities(ProjectSurvey survey) {
  if (!survey.hasManuscript) return const [];
  final findings = <StructuralFinding>[];
  final prose = survey.allProse;

  for (final character in survey.characters) {
    if (survey.reachesManuscript(
      character.id,
      typeIds: manuscriptConnectionTypeIds,
    )) {
      continue;
    }
    if (_namesOf(character).any((name) => proseMentions(prose, name))) continue;

    findings.add(StructuralFinding(
      condition: StructuralCondition.orphanEntity,
      severity: ContinuitySeverity.warning,
      title: '${character.title} never appears in the manuscript',
      detail: 'No scene connects to ${character.title}, and no scene names '
          'them either.',
      recommendation: 'Write ${character.title} into a scene, connect them to '
          'the scenes they belong in, or archive the record if they are no '
          'longer part of the story.',
      entityIds: [character.id],
    ));
  }
  return findings;
}

/// A record's title plus any aliases, long enough to match on.
List<String> _namesOf(AuthorRecord record) => [
      record.title,
      ...ManuscriptContinuityIntelligence.aliasesOf(record),
    ]
        .map((name) => name.trim())
        .where((name) => name.length >= minimumMentionLength)
        .toList();

// ---------------------------------------------------------------------------
// 2. Unlinked mention, location gap and cast gap
// ---------------------------------------------------------------------------

/// Rolls the Manuscript workspace's per-scene continuity check across every
/// scene in the project.
///
/// [ManuscriptContinuityIntelligence] already decides all three of these
/// conditions, one scene at a time, and hands back recommendations the existing
/// `ContinuityActionService` can resolve. The only thing missing was anyone
/// asking it the question for the whole book.
///
/// Three of its five rules become project-level findings here. The other two —
/// "POV character is not connected to this scene" and the per-scene chronology
/// check — stay where they are: they are drafting aids that make sense while
/// you are looking at the scene, and repeating them here would duplicate the
/// panel the author already has open.
List<StructuralFinding> detectManuscriptGaps(ProjectSurvey survey) {
  if (survey.scenes.isEmpty) return const [];

  const intelligence = ManuscriptContinuityIntelligence(
    minimumMentionLength: minimumMentionLength,
  );
  final known = ManuscriptContinuityIntelligence.knownNames(survey.records);
  final knownRecords =
      ManuscriptContinuityIntelligence.knownRecords(survey.records);
  final findings = <StructuralFinding>[];

  for (final scene in survey.scenes) {
    final chapter = survey.chapterOfScene(scene.id);
    if (chapter == null) continue;

    final report = intelligence.analyzeScene(
      scene: scene,
      chapter: chapter,
      records: knownRecords,
      connectedIds: survey.connectedIds(scene.id),
      knownNames: known,
    );

    for (var index = 0; index < report.findings.length; index += 1) {
      final finding = report.findings[index];
      final issue = index < report.summary.issues.length
          ? report.summary.issues[index]
          : null;
      if (issue == null) continue;

      switch (finding.warning.type) {
        case ContinuityWarningType.missingRelationship:
          final target = survey.recordById(finding.targetId ?? '');
          if (target == null) break;
          findings.add(StructuralFinding(
            condition: StructuralCondition.unlinkedMention,
            severity: ContinuitySeverity.notice,
            title: '${target.title} is named in "${scene.title}" but not '
                'connected to it',
            detail: 'The prose of "${scene.title}" mentions ${target.title}, '
                'and no connection records it.',
            recommendation: 'Connect ${target.title} to this scene so the rest '
                'of AuthorOS knows they are in it.',
            entityIds: [target.id, scene.id],
            action: StructuralAction.link(
              issue: issue,
              sourceId: target.id,
              targetId: scene.id,
              connectionTypeId: finding.connectionTypeId,
            ),
          ));
        case ContinuityWarningType.unknownLocation:
          findings.add(StructuralFinding(
            condition: StructuralCondition.locationGap,
            severity: ContinuitySeverity.warning,
            title: '"${finding.missingName}" is not in your world',
            detail: 'The scene "${scene.title}" is set in '
                '"${finding.missingName}", and no record of that place exists.',
            recommendation: 'Create the location, or correct the scene so it '
                'points at a place your world already holds.',
            entityIds: [scene.id],
            action: StructuralAction.create(
              issue: issue,
              name: finding.missingName,
            ),
          ));
        case ContinuityWarningType.unknownCharacter:
          findings.add(StructuralFinding(
            condition: StructuralCondition.castGap,
            severity: ContinuitySeverity.warning,
            title: '"${finding.missingName}" has no character record',
            detail: 'The scene "${scene.title}" gives the point of view to '
                '"${finding.missingName}", who does not exist in this project.',
            recommendation: 'Create the character, or correct the scene POV.',
            entityIds: [scene.id],
            action: StructuralAction.create(
              issue: issue,
              name: finding.missingName,
            ),
          ));
        default:
          break;
      }
    }
  }
  return findings;
}

// ---------------------------------------------------------------------------
// 3. Orphan plot
// ---------------------------------------------------------------------------

/// Storylines that hold no scenes.
///
/// Deliberately inverted relative to `PlotService.validatePlot`'s
/// `orphaned-scene` check, which asks the repository for records of type
/// `scene` and always gets none — scenes are manuscript nodes, not records
/// (risk R-5, open until Story Graph Phase 0). Rather than depend on a query
/// that cannot return anything, this walks the plotline's own connections and
/// asks whether any of them lands on a scene that really exists.
List<StructuralFinding> detectOrphanPlots(ProjectSurvey survey) {
  final findings = <StructuralFinding>[];

  for (final plot in survey.recordsOfTypes(plotlineTypeIds)) {
    final connectsToAScene = survey.linksOf(plot.id).any((link) {
      if (!plotSceneConnectionTypeIds.contains(link.typeId)) return false;
      final other = link.sourceId == plot.id ? link.targetId : link.sourceId;
      return survey.sceneNodeIds.contains(other);
    });
    if (connectsToAScene) continue;

    findings.add(StructuralFinding(
      condition: StructuralCondition.orphanPlot,
      severity: ContinuitySeverity.warning,
      title: '${plot.title} contains no scenes',
      detail: 'Nothing in the manuscript belongs to ${plot.title}, so the '
          'storyline exists only as structure.',
      recommendation: 'Connect the scenes that carry ${plot.title}, or fold it '
          'into a storyline that is actually being written.',
      entityIds: [plot.id],
    ));
  }
  return findings;
}

// ---------------------------------------------------------------------------
// 4. Unresolved relationship
// ---------------------------------------------------------------------------

/// Relationships the author established and never closed.
///
/// Two shapes, and they are genuinely different:
///
/// * A `relationship-arc` record that Plot Studio does not consider resolved —
///   the author said this relationship has a shape, and never gave it an
///   ending. "Resolved" is read off the same `plotStatus` field
///   `PlotService` uses, so the two screens cannot disagree.
/// * A relationship *link* between two characters with no relationship arc
///   anywhere near either end — the relationship exists as a fact and has no
///   trajectory at all.
List<StructuralFinding> detectUnresolvedRelationships(ProjectSurvey survey) {
  final findings = <StructuralFinding>[];

  for (final arc in survey.recordsOfTypes(const {'relationship-arc'})) {
    if (_isResolved(arc)) continue;
    findings.add(StructuralFinding(
      condition: StructuralCondition.unresolvedRelationship,
      severity: ContinuitySeverity.notice,
      title: '${arc.title} has no resolution',
      detail: 'The arc is still open: its status is '
          '"${_plotStatusOf(arc).isEmpty ? 'unset' : _plotStatusOf(arc)}".',
      recommendation: 'Give ${arc.title} an ending, or mark it resolved if the '
          'manuscript already provides one.',
      entityIds: [arc.id],
    ));
  }

  final arcSubjects = <String>{
    for (final arc in survey.recordsOfTypes(const {'relationship-arc'}))
      ...survey.connectedIds(arc.id),
  };

  final reported = <String>{};
  for (final link in survey.links) {
    if (!relationshipConnectionTypeIds.contains(link.typeId)) continue;
    final source = survey.recordById(link.sourceId);
    final target = survey.recordById(link.targetId);
    if (source == null || target == null) continue;
    if (survey.categoryFor(source.typeId) != characterCategoryId ||
        survey.categoryFor(target.typeId) != characterCategoryId) {
      continue;
    }
    if (arcSubjects.contains(source.id) || arcSubjects.contains(target.id)) {
      continue;
    }
    // One finding per pair, whichever direction the link runs.
    final pair = ([source.id, target.id]..sort()).join('|');
    if (!reported.add(pair)) continue;

    findings.add(StructuralFinding(
      condition: StructuralCondition.unresolvedRelationship,
      severity: ContinuitySeverity.notice,
      title: '${source.title} and ${target.title} have no arc',
      detail: 'They are connected as "${link.typeId}", and no relationship arc '
          'tracks where that goes.',
      recommendation: 'Create a relationship arc if this pairing should change '
          'across the book, or leave it as a standing fact.',
      entityIds: [source.id, target.id],
    ));
  }
  return findings;
}

String _plotStatusOf(AuthorRecord record) =>
    '${record.fields['plotStatus'] ?? ''}'.toLowerCase();

/// Plot Studio's own definition of resolved — see `PlotService._isResolved`.
bool _isResolved(AuthorRecord record) {
  final status = _plotStatusOf(record);
  return status == 'resolved' || status == 'completed';
}

// ---------------------------------------------------------------------------
// 5. Timeline conflict
// ---------------------------------------------------------------------------

/// Events that cannot both be true as dated.
///
/// This is almost entirely a wiring job. [ContinuityAnalyzer.analyze] already
/// detects character overlap, impossible travel, invalid ranges and backwards
/// sequences, and is covered by `test/continuity_test.dart` — but nothing in
/// the application has ever called it. What was missing is the projection from
/// timeline *records* into the [ContinuityEventSnapshot]s it reads.
///
/// Events with no date, or dated against a calendar the project does not hold,
/// are skipped rather than reported: an undated event is unfinished, not
/// contradictory, and saying otherwise would punish the author for drafting.
List<StructuralFinding> detectTimelineConflicts(ProjectSurvey survey) {
  final snapshots = _timelineSnapshots(survey);
  if (snapshots.length < 2) return const [];

  final warnings = const ContinuityAnalyzer().analyze(snapshots);
  if (warnings.isEmpty) return const [];

  final summary = ContinuityAnalyzer.summaryFor(warnings);
  final titles = {for (final event in snapshots) event.id: event.title};

  return [
    for (final issue in summary.issues)
      StructuralFinding(
        condition: StructuralCondition.timelineConflict,
        severity: issue.severity,
        title: issue.title,
        detail: issue.message,
        recommendation: issue.recommendation,
        entityIds: issue.eventIds
            .where((id) => titles.containsKey(id))
            .toList(),
      ),
  ];
}

/// Projects dated timeline-event records into continuity snapshots.
List<ContinuityEventSnapshot> _timelineSnapshots(ProjectSurvey survey) {
  final calendars = <String, TimelineCalendar>{
    for (final record
        in survey.recordsOfTypes(const {TimelineRecordTypes.calendarTypeId}))
      record.id: TimelineService.calendarFrom(record),
  };

  final events = <_DatedEvent>[];
  for (final record
      in survey.recordsOfTypes(TimelineRecordTypes.recordTypeIds.toSet())) {
    if (record.typeId == TimelineRecordTypes.calendarTypeId) continue;
    final start = timelineDateFrom(record.fields['start']);
    if (start == null || !start.isDated) continue;
    final calendar = calendars[start.calendarId];
    if (calendar == null) continue;

    final end = timelineDateFrom(record.fields['end']);
    final int startDay;
    final int endDay;
    try {
      startDay = calendar.ordinal(start);
      endDay = end != null && end.isDated && end.calendarId == start.calendarId
          ? calendar.ordinal(end)
          : startDay;
    } on ArgumentError {
      // An invalid date for its calendar is a validation problem Timeline
      // Studio already reports; it is not a conflict between two events.
      continue;
    }

    events.add(_DatedEvent(record: record, startDay: startDay, endDay: endDay));
  }

  events.sort((left, right) {
    final byStart = left.startDay.compareTo(right.startDay);
    return byStart != 0 ? byStart : left.record.title.compareTo(right.record.title);
  });

  return [
    for (var index = 0; index < events.length; index += 1)
      ContinuityEventSnapshot(
        id: events[index].record.id,
        title: events[index].record.title,
        startDay: events[index].startDay,
        endDay: events[index].endDay,
        order: index,
        pov: '',
        plotline: _plotlineKeyOf(survey, events[index].record),
        presentCharacters: _presentCharacterNames(survey, events[index].record),
        location: _locationName(survey, events[index].record),
      ),
  ];
}

class _DatedEvent {
  const _DatedEvent({
    required this.record,
    required this.startDay,
    required this.endDay,
  });

  final AuthorRecord record;
  final int startDay;
  final int endDay;
}

/// The plotline an event belongs to, as [ContinuityAnalyzer] compares them.
///
/// The analyzer deliberately does not report two events in the *same* plotline
/// as overlapping — interleaving a single thread is a narrative choice, not a
/// contradiction. That makes the value for an event with no plotline load
/// bearing: leaving it blank would make every unassigned event share one
/// plotline with every other, and the check would never fire at all.
///
/// So an unassigned event gets a key unique to itself. The value is never
/// displayed — the analyzer's warnings quote event titles — so a synthetic key
/// only ever affects the comparison it exists for.
String _plotlineKeyOf(ProjectSurvey survey, AuthorRecord event) {
  for (final link in survey.linksOf(event.id)) {
    if (!const {'partOf', 'appearsIn', 'pursues'}.contains(link.typeId)) {
      continue;
    }
    final other = link.sourceId == event.id ? link.targetId : link.sourceId;
    final record = survey.recordById(other);
    if (record == null) continue;
    if (!plotlineTypeIds.contains(record.typeId)) continue;
    return 'plotline:${record.id}';
  }
  return 'unassigned:${event.id}';
}

/// The characters an event involves, by name — [ContinuityEventSnapshot] reads
/// names, not ids.
List<String> _presentCharacterNames(ProjectSurvey survey, AuthorRecord event) {
  final names = <String>[];
  for (final link in survey.linksOf(event.id)) {
    if (link.typeId != 'involves') continue;
    final other = link.sourceId == event.id ? link.targetId : link.sourceId;
    final record = survey.recordById(other);
    if (record == null) continue;
    if (survey.categoryFor(record.typeId) != characterCategoryId) continue;
    names.add(record.title);
  }
  return names;
}

String _locationName(ProjectSurvey survey, AuthorRecord event) {
  for (final link in survey.linksOf(event.id)) {
    if (link.typeId != 'occursAt') continue;
    final other = link.sourceId == event.id ? link.targetId : link.sourceId;
    final record = survey.recordById(other);
    if (record != null) return record.title;
  }
  return '';
}

// ---------------------------------------------------------------------------
// 6. Research gap
// ---------------------------------------------------------------------------

/// Research the story leans on that cites nothing.
///
/// The condition is specifically research *in use*: the record has a
/// `documents` connection to something in the project, so the author is
/// relying on it, and it carries neither a source URL nor a citation. Research
/// sitting unattached is a note, not a gap.
List<StructuralFinding> detectResearchGaps(ProjectSurvey survey) {
  final findings = <StructuralFinding>[];

  for (final entry
      in survey.recordsOfTypes(ResearchRecordTypes.recordTypeIds.toSet())) {
    final documentsSomething = survey
        .linksOf(entry.id)
        .any((link) => link.typeId == 'documents');
    if (!documentsSomething) continue;

    final hasSource =
        _fieldText(entry, ResearchRecordTypes.sourceUrlFieldId).isNotEmpty ||
            _fieldText(entry, ResearchRecordTypes.citationFieldId).isNotEmpty;
    if (hasSource) continue;

    findings.add(StructuralFinding(
      condition: StructuralCondition.researchGap,
      severity: ContinuitySeverity.notice,
      title: '${entry.title} has no source',
      detail: 'This research is attached to your story and records neither a '
          'source URL nor a citation.',
      recommendation: 'Add where this came from, so it can be checked later.',
      entityIds: [entry.id],
    ));
  }
  return findings;
}

String _fieldText(AuthorRecord record, String fieldId) {
  final value = record.fields[fieldId];
  return value is String ? value.trim() : '';
}

// ---------------------------------------------------------------------------
// 7. Unused worldbuilding
// ---------------------------------------------------------------------------

/// World entities that have never reached the manuscript.
///
/// Reported as one finding, not one per entity. Twenty-seven separate notices
/// saying "this location is unused" would bury every other condition on the
/// screen; the useful form of this observation is the count, which is exactly
/// how the author thinks about it.
List<StructuralFinding> detectUnusedWorldbuilding(ProjectSurvey survey) {
  final unused = unusedWorldEntities(survey);
  if (unused.isEmpty) return const [];

  final sample = unused.take(3).map((record) => record.title).join(', ');
  final remainder = unused.length - 3;

  return [
    StructuralFinding(
      condition: StructuralCondition.unusedWorldbuilding,
      severity: ContinuitySeverity.notice,
      title: unused.length == 1
          ? '1 world entity has no manuscript connections'
          : '${unused.length} world entities have no manuscript connections',
      detail: remainder > 0
          ? 'Including $sample, and $remainder more.'
          : 'Including $sample.',
      recommendation: 'Draw on them in a scene, connect the ones already in '
          'use, or leave them as reference material.',
      entityIds: [for (final record in unused) record.id],
    ),
  ];
}

/// The worldbuilding records with no connection to a live scene or chapter.
List<AuthorRecord> unusedWorldEntities(ProjectSurvey survey) => [
      for (final record in survey.worldEntities)
        if (!survey.reachesManuscript(record.id)) record,
    ];
