import 'record_scope.dart';
import 'record_types.dart';

class PlotRecordTypes {
  const PlotRecordTypes._();

  static const baseTypeId = 'plot-record';
  static const beatTypeId = 'beat';

  static const List<String> recordTypeIds = [
    'story',
    'act',
    'sequence',
    'plot',
    'plotline',
    'subplot',
    'arc',
    'character-arc',
    'relationship-arc',
    'world-arc',
    'political-arc',
    'romance-arc',
    'mystery-arc',
    'conflict',
    'goal',
    'motivation',
    'obstacle',
    'stake',
    'turning-point',
    beatTypeId,
    'arc-beat',
    'story-event',
    'reveal',
    'foreshadowing',
    'payoff',
    'set-piece',
    'climax',
    'resolution',
    'scene-plan',
    'chapter-plan',
  ];

  static final List<RecordTypeDefinition> definitions = [
    _base,
    ...recordTypeIds.map(_definition),
  ];

  static RecordTypeDefinition customType({
    required String id,
    required String name,
    required String projectId,
    List<RecordFieldDefinition> fields = const [],
    List<RecordTemplateSection> sections = const [],
  }) =>
      RecordTypeDefinition(
        id: id,
        name: name,
        categoryId: 'plot',
        baseTypeId: baseTypeId,
        fields: fields,
        sections: sections,
        suggestedLinkTypeIds: _plotLinks,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        sourcePackId: 'project:$projectId',
        extensionData: const {'plotStudio': true, 'custom': true},
      );

  static RecordTypeDefinition _definition(String id) {
    final fields = _fieldsByType[id] ?? const <RecordFieldDefinition>[];
    return RecordTypeDefinition(
      id: id,
      name: _names[id]!,
      description: '${_names[id]} represented in Plot Studio.',
      icon: _icons[id] ?? 'account_tree',
      categoryId: 'plot',
      baseTypeId: _baseTypes[id] ?? baseTypeId,
      fields: fields,
      sections: fields.isEmpty
          ? const []
          : [
              RecordTemplateSection(
                id: 'plotDetails',
                title: 'Plot details',
                order: 20,
                fieldIds: fields.map((field) => field.id).toList(),
              ),
            ],
      suggestedLinkTypeIds: _plotLinks,
      builtIn: true,
      sourcePackId: 'authoros-core',
      permissions: const {'editableDefinition': false},
      extensionData: const {'plotStudio': true},
    );
  }
}

const _base = RecordTypeDefinition(
  id: PlotRecordTypes.baseTypeId,
  name: 'Plot Record',
  description: 'A story architecture record shared across AuthorOS studios.',
  icon: 'account_tree',
  categoryId: 'plot',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
      id: 'purpose',
      label: 'Purpose',
      type: RecordFieldType.longText,
      order: 100,
    ),
    RecordFieldDefinition(
      id: 'plotStatus',
      label: 'Status',
      type: RecordFieldType.singleChoice,
      order: 101,
      options: ['planned', 'active', 'resolved', 'abandoned'],
    ),
    RecordFieldDefinition(
      id: 'planningOrder',
      label: 'Planning order',
      type: RecordFieldType.number,
      order: 102,
    ),
    RecordFieldDefinition(
      id: 'narrativeOrder',
      label: 'Narrative order',
      type: RecordFieldType.number,
      order: 103,
    ),
    RecordFieldDefinition(
      id: 'chronologicalOrder',
      label: 'Chronological order',
      type: RecordFieldType.number,
      order: 104,
    ),
    RecordFieldDefinition(
      id: 'dependencies',
      label: 'Dependencies',
      type: RecordFieldType.list,
      order: 105,
      extensionData: {'stableIds': true},
    ),
  ],
  sections: [
    RecordTemplateSection(
      id: 'architecture',
      title: 'Architecture',
      order: 10,
      fieldIds: [
        'purpose',
        'plotStatus',
        'planningOrder',
        'narrativeOrder',
        'chronologicalOrder',
        'dependencies',
      ],
    ),
  ],
  suggestedLinkTypeIds: _plotLinks,
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
  extensionData: {'plotStudio': true, 'abstract': true},
);

const _plotLinks = [
  'partOf',
  'contains',
  'appearsIn',
  'hasArc',
  'pursues',
  'involves',
  'relatedTo',
  'causes',
  'changes',
  'leadsTo',
  'paidOffBy',
  'plannedFor',
  'fulfilledBy',
  'occursDuring',
  'depicts',
  'resolvesIn',
  'dependsOn',
  'opposes',
  'motivatedBy',
  'hasStake',
];

const _names = <String, String>{
  'story': 'Story',
  'act': 'Act',
  'sequence': 'Sequence',
  'plot': 'Plot',
  'plotline': 'Plotline',
  'subplot': 'Subplot',
  'arc': 'Arc',
  'character-arc': 'Character Arc',
  'relationship-arc': 'Relationship Arc',
  'world-arc': 'World Arc',
  'political-arc': 'Political Arc',
  'romance-arc': 'Romance Arc',
  'mystery-arc': 'Mystery Arc',
  'conflict': 'Conflict',
  'goal': 'Goal',
  'motivation': 'Motivation',
  'obstacle': 'Obstacle',
  'stake': 'Stake',
  'turning-point': 'Turning Point',
  'beat': 'Beat',
  'arc-beat': 'Arc Beat',
  'story-event': 'Story Event',
  'reveal': 'Reveal',
  'foreshadowing': 'Foreshadowing',
  'payoff': 'Payoff',
  'set-piece': 'Set Piece',
  'climax': 'Climax',
  'resolution': 'Resolution',
  'scene-plan': 'Scene Plan',
  'chapter-plan': 'Chapter Plan',
};

const _icons = <String, String>{
  'story': 'auto_stories',
  'act': 'view_agenda',
  'sequence': 'reorder',
  'plotline': 'route',
  'beat': 'music_note',
  'turning-point': 'turn_sharp_right',
  'reveal': 'visibility',
  'foreshadowing': 'lightbulb',
  'payoff': 'task_alt',
  'climax': 'landscape',
  'resolution': 'flag',
};

const _baseTypes = <String, String>{
  'subplot': 'plotline',
  'character-arc': 'arc',
  'relationship-arc': 'arc',
  'world-arc': 'arc',
  'political-arc': 'arc',
  'romance-arc': 'arc',
  'mystery-arc': 'arc',
  'arc-beat': 'beat',
  'climax': 'turning-point',
  'resolution': 'turning-point',
};

const _fieldsByType = <String, List<RecordFieldDefinition>>{
  'act': [
    RecordFieldDefinition(
        id: 'openingState',
        label: 'Opening state',
        type: RecordFieldType.longText,
        order: 200),
    RecordFieldDefinition(
        id: 'closingState',
        label: 'Closing state',
        type: RecordFieldType.longText,
        order: 201),
  ],
  'sequence': [
    RecordFieldDefinition(
        id: 'goal',
        label: 'Goal',
        type: RecordFieldType.recordReference,
        order: 200),
    RecordFieldDefinition(
        id: 'conflict',
        label: 'Conflict',
        type: RecordFieldType.recordReference,
        order: 201),
    RecordFieldDefinition(
        id: 'outcome',
        label: 'Outcome',
        type: RecordFieldType.longText,
        order: 202),
  ],
  'plotline': [
    RecordFieldDefinition(
        id: 'plotlineType',
        label: 'Type',
        type: RecordFieldType.singleChoice,
        order: 200,
        options: [
          'main',
          'subplot',
          'character',
          'romance',
          'mystery',
          'political',
          'world',
          'conflict',
          'investigation',
          'survival',
          'quest',
          'custom'
        ]),
    RecordFieldDefinition(
        id: 'priority',
        label: 'Priority',
        type: RecordFieldType.number,
        order: 201),
    RecordFieldDefinition(
        id: 'start',
        label: 'Start',
        type: RecordFieldType.shortText,
        order: 202),
    RecordFieldDefinition(
        id: 'targetResolution',
        label: 'Target resolution',
        type: RecordFieldType.longText,
        order: 203),
    RecordFieldDefinition(
        id: 'actualResolution',
        label: 'Actual resolution',
        type: RecordFieldType.longText,
        order: 204),
  ],
  'arc': [
    RecordFieldDefinition(
        id: 'beginningState',
        label: 'Beginning state',
        type: RecordFieldType.longText,
        order: 200),
    RecordFieldDefinition(
        id: 'desiredEndState',
        label: 'Desired end state',
        type: RecordFieldType.longText,
        order: 201),
    RecordFieldDefinition(
        id: 'currentState',
        label: 'Current state',
        type: RecordFieldType.longText,
        order: 202),
    RecordFieldDefinition(
        id: 'progression',
        label: 'Progression',
        type: RecordFieldType.table,
        order: 203),
    RecordFieldDefinition(
        id: 'resolution',
        label: 'Resolution',
        type: RecordFieldType.longText,
        order: 204),
  ],
  'character-arc': [
    RecordFieldDefinition(
        id: 'startingState',
        label: 'Starting state',
        type: RecordFieldType.longText,
        order: 200),
    RecordFieldDefinition(
        id: 'goal',
        label: 'Goal',
        type: RecordFieldType.recordReference,
        order: 201),
    RecordFieldDefinition(
        id: 'motivation',
        label: 'Motivation',
        type: RecordFieldType.recordReference,
        order: 202),
    RecordFieldDefinition(
        id: 'falseBelief',
        label: 'False belief',
        type: RecordFieldType.longText,
        order: 203),
    RecordFieldDefinition(
        id: 'internalConflict',
        label: 'Internal conflict',
        type: RecordFieldType.longText,
        order: 204),
    RecordFieldDefinition(
        id: 'externalConflict',
        label: 'External conflict',
        type: RecordFieldType.longText,
        order: 205),
    RecordFieldDefinition(
        id: 'truth',
        label: 'Truth',
        type: RecordFieldType.longText,
        order: 206),
    RecordFieldDefinition(
        id: 'transformation',
        label: 'Transformation',
        type: RecordFieldType.longText,
        order: 207),
    RecordFieldDefinition(
        id: 'endingState',
        label: 'Ending state',
        type: RecordFieldType.longText,
        order: 208),
  ],
  'relationship-arc': [
    RecordFieldDefinition(
        id: 'initialRelationship',
        label: 'Initial relationship',
        type: RecordFieldType.longText,
        order: 200),
    RecordFieldDefinition(
        id: 'progression',
        label: 'Progression',
        type: RecordFieldType.table,
        order: 201),
    RecordFieldDefinition(
        id: 'finalState',
        label: 'Final state',
        type: RecordFieldType.longText,
        order: 202),
  ],
  'goal': [
    RecordFieldDefinition(
        id: 'owner',
        label: 'Owner',
        type: RecordFieldType.recordReference,
        order: 200),
    RecordFieldDefinition(
        id: 'successCondition',
        label: 'Success condition',
        type: RecordFieldType.longText,
        order: 201),
    RecordFieldDefinition(
        id: 'failureCondition',
        label: 'Failure condition',
        type: RecordFieldType.longText,
        order: 202),
    RecordFieldDefinition(
        id: 'deadline',
        label: 'Deadline',
        type: RecordFieldType.shortText,
        order: 203),
  ],
  'motivation': [
    RecordFieldDefinition(
        id: 'motivationType',
        label: 'Type',
        type: RecordFieldType.singleChoice,
        order: 200,
        options: [
          'survival',
          'love',
          'revenge',
          'freedom',
          'power',
          'belonging',
          'duty',
          'protection',
          'truth',
          'redemption',
          'fear',
          'ambition',
          'custom'
        ]),
  ],
  'obstacle': [
    RecordFieldDefinition(
        id: 'obstacleType',
        label: 'Type',
        type: RecordFieldType.shortText,
        order: 200),
    RecordFieldDefinition(
        id: 'source',
        label: 'Source',
        type: RecordFieldType.recordReference,
        order: 201),
    RecordFieldDefinition(
        id: 'target',
        label: 'Target',
        type: RecordFieldType.recordReference,
        order: 202),
    RecordFieldDefinition(
        id: 'escalation',
        label: 'Escalation',
        type: RecordFieldType.longText,
        order: 203),
    RecordFieldDefinition(
        id: 'resolution',
        label: 'Resolution',
        type: RecordFieldType.longText,
        order: 204),
    RecordFieldDefinition(
        id: 'consequence',
        label: 'Consequence',
        type: RecordFieldType.longText,
        order: 205),
  ],
  'conflict': [
    RecordFieldDefinition(
        id: 'conflictType',
        label: 'Type',
        type: RecordFieldType.singleChoice,
        order: 200,
        options: [
          'character-vs-character',
          'character-vs-self',
          'character-vs-society',
          'character-vs-nature',
          'character-vs-system',
          'character-vs-supernatural',
          'character-vs-faction',
          'character-vs-world',
          'custom'
        ]),
    RecordFieldDefinition(
        id: 'source',
        label: 'Source',
        type: RecordFieldType.recordReference,
        order: 201),
    RecordFieldDefinition(
        id: 'target',
        label: 'Target',
        type: RecordFieldType.recordReference,
        order: 202),
    RecordFieldDefinition(
        id: 'escalation',
        label: 'Escalation',
        type: RecordFieldType.longText,
        order: 203),
    RecordFieldDefinition(
        id: 'outcome',
        label: 'Outcome',
        type: RecordFieldType.longText,
        order: 204),
    RecordFieldDefinition(
        id: 'consequences',
        label: 'Consequences',
        type: RecordFieldType.list,
        order: 205),
  ],
  'stake': [
    RecordFieldDefinition(
        id: 'stakeType',
        label: 'Type',
        type: RecordFieldType.singleChoice,
        order: 200,
        options: [
          'personal',
          'emotional',
          'relationship',
          'physical',
          'moral',
          'political',
          'social',
          'world',
          'existential',
          'custom'
        ]),
  ],
  'beat': [
    RecordFieldDefinition(
        id: 'beatType',
        label: 'Type',
        type: RecordFieldType.shortText,
        order: 200),
    RecordFieldDefinition(
        id: 'importance',
        label: 'Importance',
        type: RecordFieldType.singleChoice,
        order: 201,
        options: ['minor', 'normal', 'major', 'critical']),
    RecordFieldDefinition(
        id: 'consequence',
        label: 'Consequence',
        type: RecordFieldType.longText,
        order: 202),
  ],
  'turning-point': [
    RecordFieldDefinition(
        id: 'turningPointType',
        label: 'Type',
        type: RecordFieldType.singleChoice,
        order: 200,
        options: [
          'inciting-incident',
          'first-major-decision',
          'midpoint',
          'reversal',
          'crisis',
          'climax',
          'resolution',
          'custom'
        ]),
  ],
  'reveal': [
    RecordFieldDefinition(
        id: 'secret',
        label: 'Secret',
        type: RecordFieldType.recordReference,
        order: 200),
    RecordFieldDefinition(
        id: 'revealedInformation',
        label: 'Revealed information',
        type: RecordFieldType.longText,
        order: 201),
    RecordFieldDefinition(
        id: 'revealedTo',
        label: 'Revealed to',
        type: RecordFieldType.list,
        order: 202),
    RecordFieldDefinition(
        id: 'revealedBy',
        label: 'Revealed by',
        type: RecordFieldType.recordReference,
        order: 203),
    RecordFieldDefinition(
        id: 'intendedRevealPoint',
        label: 'Intended reveal point',
        type: RecordFieldType.recordReference,
        order: 204),
    RecordFieldDefinition(
        id: 'actualRevealPoint',
        label: 'Actual reveal point',
        type: RecordFieldType.recordReference,
        order: 205),
    RecordFieldDefinition(
        id: 'authorKnowledge',
        label: 'Author knowledge',
        type: RecordFieldType.longText,
        order: 206),
    RecordFieldDefinition(
        id: 'characterKnowledge',
        label: 'Character knowledge',
        type: RecordFieldType.table,
        order: 207),
    RecordFieldDefinition(
        id: 'readerKnowledge',
        label: 'Reader knowledge',
        type: RecordFieldType.longText,
        order: 208),
  ],
  'foreshadowing': [
    RecordFieldDefinition(
        id: 'plant',
        label: 'Plant',
        type: RecordFieldType.longText,
        order: 200),
    RecordFieldDefinition(
        id: 'characterAwareness',
        label: 'Character awareness',
        type: RecordFieldType.table,
        order: 201),
    RecordFieldDefinition(
        id: 'readerAwareness',
        label: 'Reader awareness',
        type: RecordFieldType.longText,
        order: 202),
  ],
  'payoff': [
    RecordFieldDefinition(
        id: 'setup',
        label: 'Setup',
        type: RecordFieldType.recordReference,
        order: 200),
    RecordFieldDefinition(
        id: 'payoff',
        label: 'Payoff',
        type: RecordFieldType.longText,
        order: 201),
    RecordFieldDefinition(
        id: 'expectedTiming',
        label: 'Expected timing',
        type: RecordFieldType.shortText,
        order: 202),
    RecordFieldDefinition(
        id: 'actualTiming',
        label: 'Actual timing',
        type: RecordFieldType.shortText,
        order: 203),
  ],
};

class PlotStructureTemplate {
  const PlotStructureTemplate({
    required this.id,
    required this.name,
    required this.stages,
    this.hierarchical = false,
  });

  final String id;
  final String name;
  final List<String> stages;
  final bool hierarchical;
}

class PlotStructureTemplates {
  const PlotStructureTemplates._();

  static const templates = [
    PlotStructureTemplate(id: 'three-act', name: 'Three Act', stages: [
      'Setup',
      'Inciting Incident',
      'Rising Action',
      'Midpoint',
      'Crisis',
      'Climax',
      'Resolution'
    ]),
    PlotStructureTemplate(id: 'five-act', name: 'Five Act', stages: [
      'Exposition',
      'Rising Action',
      'Climax',
      'Falling Action',
      'Resolution'
    ]),
    PlotStructureTemplate(id: 'heros-journey', name: "Hero's Journey", stages: [
      'Ordinary World',
      'Call to Adventure',
      'Refusal of the Call',
      'Meeting the Mentor',
      'Crossing the Threshold',
      'Tests, Allies, and Enemies',
      'Approach to the Inmost Cave',
      'Ordeal',
      'Reward',
      'The Road Back',
      'Resurrection',
      'Return with the Elixir'
    ]),
    PlotStructureTemplate(id: 'save-the-cat', name: 'Save the Cat', stages: [
      'Opening Image',
      'Theme Stated',
      'Setup',
      'Catalyst',
      'Debate',
      'Break into Two',
      'B Story',
      'Fun and Games',
      'Midpoint',
      'Bad Guys Close In',
      'All Is Lost',
      'Dark Night of the Soul',
      'Break into Three',
      'Finale',
      'Final Image'
    ]),
    PlotStructureTemplate(id: 'seven-point', name: 'Seven Point', stages: [
      'Hook',
      'Plot Turn 1',
      'Pinch Point 1',
      'Midpoint',
      'Pinch Point 2',
      'Plot Turn 2',
      'Resolution'
    ]),
    PlotStructureTemplate(
        id: 'snowflake',
        name: 'Snowflake',
        stages: [
          'One-sentence summary',
          'One-paragraph summary',
          'Character summaries',
          'Expanded synopsis',
          'Character charts',
          'Scene list'
        ],
        hierarchical: true),
    PlotStructureTemplate(id: 'custom', name: 'Custom', stages: []),
  ];
}
