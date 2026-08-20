import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/plot_service.dart';

class PlotPhase1Fixture {
  const PlotPhase1Fixture._();

  static const projectId = 'plot-phase-1-fixture';
  static final timestamp = DateTime.utc(2026, 8, 20);

  static Future<void> seed(PlotService plot) async {
    for (final record in const [
      ('series-ember', 'series', 'The Ember Archive'),
      ('book-ashes', 'book', 'A Crown of Ashes'),
      ('character-protagonist', 'character', 'Mara Voss'),
      ('character-antagonist', 'character', 'Regent Vale'),
      ('character-supporting', 'character', 'Ilya Quill'),
      ('location-harbor', 'location', 'Ashfall Harbor'),
      ('location-palace', 'location', 'The Glass Palace'),
      ('faction-reliquary', 'faction', 'The Iron Reliquary'),
      ('government-regency', 'government', 'The Regency'),
      ('codex-culture', 'culture', 'Riverborn Culture'),
      ('codex-religion', 'religion', 'The Lantern Faith'),
      ('codex-magic', 'magic-system', 'River Memory'),
      ('codex-history', 'historical-event', 'The First Drowning'),
      ('timeline-uprising', 'timeline-event', 'Harbor Uprising'),
      ('timeline-coronation', 'timeline-event', 'False Coronation'),
      ('timeline-flashback', 'timeline-event', 'The Night Mara Forgot'),
      ('chapter-1', 'chapter', 'Chapter 1'),
      ('chapter-2', 'chapter', 'Chapter 2'),
      ('chapter-3', 'chapter', 'Chapter 3'),
      ('scene-message', 'scene', 'The River Message'),
      ('scene-ball', 'scene', 'The Masked Ball'),
      ('scene-climax', 'scene', 'The Floodgate'),
    ]) {
      await plot.records.createRecord(_externalRecord(
        id: record.$1,
        typeId: record.$2,
        title: record.$3,
      ));
    }

    for (final draft in [
      const PlotRecordDraft(
          id: 'story-ashes',
          typeId: 'story',
          name: 'A Crown of Ashes',
          fields: {'plotStatus': 'active'}),
      const PlotRecordDraft(id: 'act-1', typeId: 'act', name: 'Act I', fields: {
        'purpose': 'Disrupt the false peace',
        'openingState': 'Mara is hidden',
        'closingState': 'Mara chooses rebellion'
      }),
      const PlotRecordDraft(
          id: 'act-2',
          typeId: 'act',
          name: 'Act II',
          fields: {'purpose': 'Escalate the uprising'}),
      const PlotRecordDraft(
          id: 'act-3',
          typeId: 'act',
          name: 'Act III',
          fields: {'purpose': 'Resolve the succession war'}),
      const PlotRecordDraft(
          id: 'sequence-harbor', typeId: 'sequence', name: 'Harbor Sequence'),
      const PlotRecordDraft(
          id: 'sequence-palace', typeId: 'sequence', name: 'Palace Sequence'),
      const PlotRecordDraft(
          id: 'sequence-siege', typeId: 'sequence', name: 'Siege Sequence'),
      const PlotRecordDraft(
          id: 'main-plot',
          typeId: 'plotline',
          name: 'Restore the River Crown',
          fields: {'plotlineType': 'main', 'plotStatus': 'active'}),
      const PlotRecordDraft(
          id: 'subplot-romance',
          typeId: 'subplot',
          name: 'Mara and Ilya',
          fields: {'plotStatus': 'active'}),
      const PlotRecordDraft(
          id: 'subplot-mystery',
          typeId: 'subplot',
          name: 'The Stolen Memory',
          fields: {'plotStatus': 'active'}),
      const PlotRecordDraft(
          id: 'arc-mara',
          typeId: 'character-arc',
          name: 'Mara Claims Her Name',
          fields: {
            'startingState': 'Self-erasure',
            'goal': 'goal-crown',
            'motivation': 'motivation-truth',
            'falseBelief': 'Memory makes her dangerous',
            'truth': 'Memory makes choice possible',
            'endingState': 'Integrated',
            'plotStatus': 'active'
          }),
      const PlotRecordDraft(
          id: 'arc-relationship',
          typeId: 'relationship-arc',
          name: 'Mara and Ilya Learn Trust',
          fields: {
            'initialRelationship': 'Mutual suspicion',
            'progression': <Object?>[],
            'finalState': 'Committed allies'
          }),
      const PlotRecordDraft(
          id: 'arc-world',
          typeId: 'world-arc',
          name: 'The Regency Falls',
          fields: {
            'beginningState': 'Authoritarian rule',
            'desiredEndState': 'Harbor council'
          }),
      const PlotRecordDraft(
          id: 'conflict-regent',
          typeId: 'conflict',
          name: 'Mara vs Regent Vale',
          fields: {
            'conflictType': 'character-vs-character',
            'source': 'character-protagonist',
            'target': 'character-antagonist',
            'plotStatus': 'active'
          }),
      const PlotRecordDraft(
          id: 'goal-crown',
          typeId: 'goal',
          name: 'Restore the River Crown',
          fields: {
            'owner': 'character-protagonist',
            'successCondition': 'Expose the false coronation',
            'failureCondition': 'The harbor is purged',
            'plotStatus': 'active'
          }),
      const PlotRecordDraft(
          id: 'motivation-truth',
          typeId: 'motivation',
          name: 'Recover the Truth',
          fields: {'motivationType': 'truth'}),
      const PlotRecordDraft(
          id: 'obstacle-memory',
          typeId: 'obstacle',
          name: 'Fractured Memory',
          fields: {
            'obstacleType': 'internal',
            'source': 'codex-magic',
            'target': 'character-protagonist'
          }),
      const PlotRecordDraft(
          id: 'stakes-harbor',
          typeId: 'stake',
          name: 'The Harbor Survives',
          fields: {'stakeType': 'world'}),
      const PlotRecordDraft(
          id: 'turn-midpoint',
          typeId: 'turning-point',
          name: 'The Regent Is Mara’s Father',
          fields: {'turningPointType': 'midpoint'}),
      const PlotRecordDraft(
          id: 'beat-message',
          typeId: 'beat',
          name: 'The River Delivers a Message',
          bookId: 'book-ashes',
          fields: {
            'beatType': 'inciting-incident',
            'planningOrder': 1,
            'narrativeOrder': 1,
            'chronologicalOrder': 3
          }),
      const PlotRecordDraft(
          id: 'arc-beat-choice',
          typeId: 'arc-beat',
          name: 'Mara Chooses to Remember'),
      const PlotRecordDraft(
          id: 'reveal-parentage',
          typeId: 'reveal',
          name: 'The Regent’s Secret',
          fields: {
            'secret': 'codex-history',
            'revealedInformation': 'The Regent is Mara’s father',
            'revealedTo': ['character-protagonist'],
            'authorKnowledge': 'True in Canon',
            'characterKnowledge': <Object?>[],
            'readerKnowledge': 'Foreshadowed but unconfirmed',
            'plotStatus': 'active'
          }),
      const PlotRecordDraft(
          id: 'foreshadow-ring',
          typeId: 'foreshadowing',
          name: 'The Regent’s Signet',
          fields: {
            'plant': 'Mara recognizes the signet',
            'characterAwareness': <Object?>[],
            'readerAwareness': 'Visible in chapter one'
          }),
      const PlotRecordDraft(
          id: 'payoff-ring',
          typeId: 'payoff',
          name: 'The Signet Opens the Archive',
          fields: {
            'setup': 'foreshadow-ring',
            'payoff': 'The archive confirms Mara’s parentage'
          }),
      const PlotRecordDraft(
          id: 'climax-floodgate', typeId: 'climax', name: 'Open the Floodgate'),
      const PlotRecordDraft(
          id: 'resolution-council',
          typeId: 'resolution',
          name: 'The Harbor Council'),
    ]) {
      await plot.createPlotRecord(draft, timestamp: timestamp);
    }

    for (final link in const [
      ('book-ashes', 'story-ashes', 'contains'),
      ('story-ashes', 'act-1', 'contains'),
      ('story-ashes', 'act-2', 'contains'),
      ('story-ashes', 'act-3', 'contains'),
      ('act-1', 'sequence-harbor', 'contains'),
      ('act-2', 'sequence-palace', 'contains'),
      ('act-3', 'sequence-siege', 'contains'),
      ('story-ashes', 'main-plot', 'contains'),
      ('story-ashes', 'subplot-romance', 'contains'),
      ('story-ashes', 'subplot-mystery', 'contains'),
      ('character-protagonist', 'arc-mara', 'hasArc'),
      ('arc-mara', 'arc-beat-choice', 'contains'),
      ('arc-beat-choice', 'scene-climax', 'appearsIn'),
      ('beat-message', 'scene-message', 'plannedFor'),
      ('beat-message', 'scene-message', 'fulfilledBy'),
      ('beat-message', 'timeline-uprising', 'occursDuring'),
      ('main-plot', 'chapter-1', 'appearsIn'),
      ('arc-mara', 'scene-climax', 'resolvesIn'),
      ('foreshadow-ring', 'reveal-parentage', 'leadsTo'),
      ('foreshadow-ring', 'payoff-ring', 'paidOffBy'),
      ('goal-crown', 'obstacle-memory', 'opposes'),
      ('goal-crown', 'motivation-truth', 'motivatedBy'),
      ('goal-crown', 'stakes-harbor', 'hasStake'),
      ('turn-midpoint', 'reveal-parentage', 'causes'),
      ('climax-floodgate', 'timeline-coronation', 'causes'),
      ('climax-floodgate', 'arc-world', 'changes'),
      ('main-plot', 'location-harbor', 'relatedTo'),
      ('main-plot', 'faction-reliquary', 'relatedTo'),
      ('main-plot', 'codex-magic', 'relatedTo'),
      ('reveal-parentage', 'timeline-flashback', 'occursDuring'),
      ('resolution-council', 'scene-climax', 'fulfilledBy'),
    ]) {
      await plot.connect(
        sourceId: link.$1,
        targetId: link.$2,
        typeId: link.$3,
        direction: link.$3 == 'relatedTo'
            ? RecordLinkDirection.undirected
            : RecordLinkDirection.directed,
        timestamp: timestamp,
      );
    }
  }

  static AuthorRecord _externalRecord({
    required String id,
    required String typeId,
    required String title,
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        canonStatus: CanonStatus.canon,
        title: title,
        fields: {
          'name': title,
          'summary': '$title fixture record',
          if (typeId == 'character') 'identity.displayName': title,
          if (typeId == 'character') 'identity.fullName': title,
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      );
}
