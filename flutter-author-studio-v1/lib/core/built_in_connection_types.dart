import 'connection_types.dart';
import 'plot_record_types.dart';
import 'record_types.dart';
import 'research_record_types.dart';
import 'timeline_record_types.dart';
import 'world_record_types.dart';

class BuiltInConnectionTypes {
  const BuiltInConnectionTypes._();

  static final definitions = <ConnectionTypeDefinition>[
    _characterRelationship('friendOf', 'Friend', undirected: true),
    _characterRelationship('enemyOf', 'Enemy', undirected: true),
    _characterRelationship('alliedWith', 'Ally', undirected: true),
    _characterRelationship('rivalOf', 'Rival', undirected: true),
    _characterRelationship('partnerOf', 'Partner', undirected: true),
    _characterRelationship('parentOf', 'Parent of', inverseLabel: 'Child of'),
    _characterRelationship(
      'guardianOf',
      'Guardian of',
      inverseLabel: 'Ward of',
    ),
    _characterRelationship('mentors', 'Mentor of', inverseLabel: 'Student of'),
    _characterRelationship(
      'protects',
      'Protects',
      inverseLabel: 'Protected by',
    ),
    _characterRelationship(
      'employs',
      'Employs',
      inverseLabel: 'Employed by',
    ),
    _characterRelationship('trusts', 'Trusts', inverseLabel: 'Trusted by'),
    _characterRelationship(
      'distrusts',
      'Distrusts',
      inverseLabel: 'Distrusted by',
    ),
    ConnectionTypeDefinition(
      id: 'memberOf',
      displayName: 'Member of',
      sourceTypeIds: ['character'],
      targetTypeIds: ['faction', 'organisation'],
      inverseLabel: 'Has member',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
      metadataFields: [
        RecordFieldDefinition(
          id: 'rank',
          label: 'Rank',
          type: RecordFieldType.shortText,
          order: 0,
        ),
        RecordFieldDefinition(
          id: 'joinedDate',
          label: 'Joined date',
          type: RecordFieldType.date,
          order: 1,
        ),
        RecordFieldDefinition(
          id: 'leftDate',
          label: 'Left date',
          type: RecordFieldType.date,
          order: 2,
        ),
        RecordFieldDefinition(
          id: 'status',
          label: 'Status',
          type: RecordFieldType.shortText,
          order: 3,
        ),
      ],
    ),
    ConnectionTypeDefinition(
      id: 'livesIn',
      displayName: 'Lives in',
      sourceTypeIds: ['character'],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Has resident',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'controls',
      displayName: 'Controls',
      sourceTypeIds: ['character', 'faction', 'organisation', 'government'],
      targetTypeIds: [
        ...WorldRecordTypes.spatialTypeIds,
        'faction',
        'organisation',
        'resource',
      ],
      inverseLabel: 'Controlled by',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'locatedIn',
      displayName: 'Located in',
      sourceTypeIds: [
        ...WorldRecordTypes.spatialTypeIds,
        'item',
        'artefact',
        'faction',
      ],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Contains',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'owns',
      displayName: 'Owns',
      sourceTypeIds: ['character', 'faction', 'organisation'],
      targetTypeIds: ['item', 'artefact', 'weapon'],
      inverseLabel: 'Owned by',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'uses',
      displayName: 'Uses',
      sourceTypeIds: ['character', 'faction', 'organisation'],
      targetTypeIds: ['item', 'artefact', 'weapon', 'technology'],
      inverseLabel: 'Used by',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'appearsIn',
      displayName: 'Appears in',
      sourceTypeIds: [
        'character',
        'location',
        'place',
        'region',
        'country',
        'city',
        'settlement',
        'district',
        'building',
        'faction',
        'item',
        'artefact',
        ...PlotRecordTypes.recordTypeIds,
      ],
      targetTypeIds: ['scene', 'chapter', 'book'],
      inverseLabel: 'Features',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    const ConnectionTypeDefinition(
      id: 'mentionedIn',
      displayName: 'Mentioned in',
      sourceTypeIds: ['character'],
      targetTypeIds: ['scene', 'chapter', 'book'],
      inverseLabel: 'Mentions',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'bornIn',
      displayName: 'Born in',
      sourceTypeIds: ['character'],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Birthplace of',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'worksIn',
      displayName: 'Works in',
      sourceTypeIds: ['character'],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Workplace of',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'visits',
      displayName: 'Visits',
      sourceTypeIds: ['character'],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Visited by',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    const ConnectionTypeDefinition(
      id: 'carries',
      displayName: 'Carries',
      sourceTypeIds: ['character'],
      targetTypeIds: ['item', 'artefact', 'weapon'],
      inverseLabel: 'Carried by',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'pursues',
      displayName: 'Pursues',
      sourceTypeIds: const [
        'character',
        'faction',
        'plotline',
        'story',
        'world',
      ],
      targetTypeIds: const ['goal', 'plot-thread'],
      inverseLabel: 'Pursued by',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'hasArc',
      displayName: 'Has arc',
      sourceTypeIds: const ['character', 'story', 'plotline', 'relationship'],
      targetTypeIds: const [
        'plot-thread',
        'arc',
        'character-arc',
        'relationship-arc',
        'world-arc',
        'political-arc',
        'romance-arc',
        'mystery-arc',
      ],
      inverseLabel: 'Character arc for',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    const ConnectionTypeDefinition(
      id: 'knows',
      displayName: 'Knows',
      sourceTypeIds: ['character'],
      targetTypeIds: ['*'],
      inverseLabel: 'Known by',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
      metadataFields: [
        RecordFieldDefinition(
          id: 'knowledgeState',
          label: 'Knowledge state',
          type: RecordFieldType.singleChoice,
          order: 0,
          options: [
            'Knows',
            "Doesn't Know",
            'Suspects',
            'Believes',
            'Misunderstands',
            'Has Forgotten',
          ],
        ),
        RecordFieldDefinition(
          id: 'private',
          label: 'Private knowledge',
          type: RecordFieldType.boolean,
          order: 1,
        ),
      ],
    ),
    ConnectionTypeDefinition(
      id: 'occursAt',
      displayName: 'Occurs at',
      sourceTypeIds: [
        ...TimelineRecordTypes.recordTypeIds,
        'historical-event',
        'scene',
        ...PlotRecordTypes.recordTypeIds,
      ],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      inverseLabel: 'Hosts event',
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'involves',
      displayName: 'Involves',
      sourceTypeIds: [
        ...TimelineRecordTypes.recordTypeIds,
        'historical-event',
        'scene',
      ],
      targetTypeIds: ['character', 'faction', 'organisation'],
      inverseLabel: 'Involved in',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'represents',
      displayName: 'Represents',
      sourceTypeIds: ['map-marker'],
      targetTypeIds: ['*'],
      inverseLabel: 'Represented by',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'documents',
      displayName: 'Documents',
      sourceTypeIds: [
        'codex-entry',
        'reference',
        ...ResearchRecordTypes.recordTypeIds,
      ],
      targetTypeIds: ['*'],
      inverseLabel: 'Documented by',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'partOf',
      displayName: 'Part of',
      sourceTypeIds: ['*'],
      targetTypeIds: ['*'],
      inverseLabel: 'Contains',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ConnectionTypeDefinition(
      id: 'relatedTo',
      displayName: 'Related to',
      sourceTypeIds: ['*'],
      targetTypeIds: ['*'],
      direction: ConnectionDirection.undirected,
      inverseLabel: 'Related to',
      builtIn: true,
      sourcePackId: 'authoros-core',
    ),
    ..._foundationRelationships,
    ..._worldRelationships,
    ..._timelineRelationships(const {
      'before': ('Before', 'After'),
      'after': ('After', 'Before'),
      'during': ('During', 'Contains'),
      'overlaps': ('Overlaps', 'Overlaps'),
      'concurrentWith': ('Concurrent with', 'Concurrent with'),
      'causedBy': ('Caused by', 'Caused'),
      'repeats': ('Repeats', 'Repeated by'),
      'changed': ('Changed', 'Changed by'),
      'founded': ('Founded', 'Founded by'),
      'destroyed': ('Destroyed', 'Destroyed by'),
      'changedBordersOf': ('Changed borders of', 'Borders changed by'),
      'tookPlaceIn': ('Took place in', 'Hosted'),
      'depictedIn': ('Depicted in', 'Depicts'),
      'occursDuring': ('Occurs during', 'Includes'),
      'witnessed': ('Witnessed', 'Witnessed by'),
      'changedDuring': ('Changed during', 'Changed'),
      'presentAt': ('Present at', 'Had present'),
      'established': ('Established', 'Established by'),
      'created': ('Created', 'Created by'),
      'introduced': ('Introduced', 'Introduced by'),
      'signed': ('Signed', 'Signed by'),
      'lost': ('Lost', 'Lost by'),
      'covers': ('Covers', 'Covered by'),
    }),
    ..._codexRelationships(const {
      'ruledBy': ('Ruled by', 'Rules'),
      'foundedBy': ('Founded by', 'Founded'),
      'influences': ('Influences', 'Influenced by'),
      'worships': ('Worships', 'Worshipped by'),
      'belongsTo': ('Belongs to', 'Has member'),
      'createdBy': ('Created by', 'Created'),
      'ownedBy': ('Owned by', 'Owns'),
      'usedBy': ('Used by', 'Uses'),
      'originatedFrom': ('Originated from', 'Origin of'),
      'caused': ('Caused', 'Caused by'),
      'resultedIn': ('Resulted in', 'Result of'),
      'precedes': ('Precedes', 'Follows'),
      'follows': ('Follows', 'Precedes'),
      'requires': ('Requires', 'Required by'),
      'contradicts': ('Contradicts', 'Contradicted by'),
      'supports': ('Supports', 'Supported by'),
      'inspired': ('Inspired', 'Inspired by'),
      'associatedWith': ('Associated with', 'Associated with'),
      'connectedTo': ('Connected to', 'Connected to'),
      'speaks': ('Speaks', 'Spoken by'),
      'participatedIn': ('Participated in', 'Had participant'),
      'practices': ('Practices', 'Practised by'),
      'revealedIn': ('Revealed in', 'Reveals'),
      'introducedIn': ('Introduced in', 'Introduces'),
      'explainedIn': ('Explained in', 'Explains'),
      'foreshadowedIn': ('Foreshadowed in', 'Foreshadows'),
      'confirmedIn': ('Confirmed in', 'Confirms'),
    }),
    ..._plotRelationships,
  ];

  /// The architectural relationship primitives every Studio may rely on.
  ///
  /// Studio-specific relationship types stay in [definitions] alongside these;
  /// this list only names the foundation vocabulary so a future Studio can
  /// assert its presence without hard-coding the whole registry.
  static const List<String> foundationTypeIds = [
    'appearsIn',
    'belongsTo',
    'childOf',
    'contains',
    'follows',
    'involves',
    'locatedAt',
    'memberOf',
    'occursAt',
    'parentOf',
    'partOf',
    'precedes',
    'references',
    'relatedTo',
  ];

  static ConnectionTypeRegistry registry({
    Iterable<ConnectionTypeDefinition> additionalDefinitions = const [],
  }) =>
      ConnectionTypeRegistry([...definitions, ...additionalDefinitions]);
}

/// Relationship primitives that belong to no single Studio.
///
/// They carry no metadata fields on purpose: a foundation edge should stay
/// cheap to create and strict about what it accepts, while richer Studio
/// relationship types keep their own metadata schemas.
final _foundationRelationships = <ConnectionTypeDefinition>[
  _foundationRelationship('childOf', 'Child of', 'Parent of'),
  _foundationRelationship('locatedAt', 'Located at', 'Location of'),
  _foundationRelationship('references', 'References', 'Referenced by'),
];

ConnectionTypeDefinition _foundationRelationship(
  String id,
  String displayName,
  String inverseLabel,
) =>
    ConnectionTypeDefinition(
      id: id,
      displayName: displayName,
      sourceTypeIds: const ['*'],
      targetTypeIds: const ['*'],
      inverseLabel: inverseLabel,
      builtIn: true,
      sourcePackId: 'authoros-core',
    );

final _plotRelationships = <ConnectionTypeDefinition>[
  ..._plotLinkDefinitions(const {
    'causes': ('Causes', 'Caused by'),
    'changes': ('Changes', 'Changed by'),
    'paidOffBy': ('Paid off by', 'Pays off'),
    'plannedFor': ('Planned for', 'Has planned beat'),
    'fulfilledBy': ('Fulfilled by', 'Fulfils'),
    'depicts': ('Depicts', 'Depicted by'),
    'resolvesIn': ('Resolves in', 'Resolves'),
    'dependsOn': ('Depends on', 'Required by'),
    'opposes': ('Opposes', 'Opposed by'),
    'motivatedBy': ('Motivated by', 'Motivates'),
    'hasStake': ('Has stake', 'Stake in'),
  }),
];

List<ConnectionTypeDefinition> _plotLinkDefinitions(
  Map<String, (String, String)> definitions,
) =>
    definitions.entries
        .map(
          (entry) => ConnectionTypeDefinition(
            id: entry.key,
            displayName: entry.value.$1,
            sourceTypeIds: const ['*'],
            targetTypeIds: const ['*'],
            inverseLabel: entry.value.$2,
            builtIn: true,
            sourcePackId: 'authoros-core',
            extensionData: const {'plotStudio': true},
          ),
        )
        .toList(growable: false);

final _worldRelationships = <ConnectionTypeDefinition>[
  _openRelationship('contains', 'Contains', 'Contained by'),
  _spatial('inside', 'Inside', 'Contains'),
  _spatial('outside', 'Outside', 'Inside'),
  _spatial('surrounds', 'Surrounds', 'Surrounded by'),
  _spatial('crosses', 'Crosses', 'Crossed by'),
  _spatial('passesThrough', 'Passes through', 'Passed through by'),
  _openRelationship('leadsTo', 'Leads to', 'Led from'),
  _spatial('accessibleFrom', 'Accessible from', 'Provides access to'),
  _spatial('inaccessibleFrom', 'Inaccessible from', 'Cannot access'),
  _spatial('above', 'Above', 'Below'),
  _spatial('below', 'Below', 'Above'),
  _spatial('northOf', 'North of', 'South of'),
  _spatial('southOf', 'South of', 'North of'),
  _spatial('adjacentTo', 'Adjacent to', 'Adjacent to', undirected: true),
  _spatial('borders', 'Borders', 'Borders', undirected: true),
  _spatial('near', 'Near', 'Near', undirected: true),
  _spatial('farFrom', 'Far from', 'Far from', undirected: true),
  ConnectionTypeDefinition(
    id: 'maps',
    displayName: 'Maps',
    sourceTypeIds: [...WorldRecordTypes.mapTypeIds],
    targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
    inverseLabel: 'Mapped by',
    builtIn: true,
    sourcePackId: 'authoros-world-core',
  ),
  ConnectionTypeDefinition(
    id: 'onMap',
    displayName: 'On map',
    sourceTypeIds: const ['map-marker'],
    targetTypeIds: [...WorldRecordTypes.mapTypeIds],
    inverseLabel: 'Has marker',
    builtIn: true,
    sourcePackId: 'authoros-world-core',
  ),
  ConnectionTypeDefinition(
    id: 'routeFrom',
    displayName: 'Route from',
    sourceTypeIds: [...WorldRecordTypes.routeTypeIds],
    targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
    inverseLabel: 'Starts route',
    builtIn: true,
    sourcePackId: 'authoros-world-core',
  ),
  ConnectionTypeDefinition(
    id: 'routeTo',
    displayName: 'Route to',
    sourceTypeIds: [...WorldRecordTypes.routeTypeIds],
    targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
    inverseLabel: 'Ends route',
    builtIn: true,
    sourcePackId: 'authoros-world-core',
  ),
  ..._characterLocationRelationships(const {
    'currentlyAt': ('Currently at', 'Current location of'),
    'previouslyAt': ('Previously at', 'Previous location of'),
    'homeAt': ('Home', 'Home of'),
    'safehouseAt': ('Safehouse', 'Safehouse of'),
    'favouriteLocation': ('Favourite location', 'Favoured by'),
    'forbiddenFrom': ('Forbidden from', 'Forbidden to'),
    'fromLocation': ('From', 'Origin of'),
  }),
  _openRelationship('headquartersAt', 'Headquarters at', 'Headquarters of'),
  _openRelationship('rules', 'Rules', 'Ruled by'),
  _openRelationship('governedBy', 'Governed by', 'Governs'),
  _openRelationship('hasCulture', 'Has culture', 'Culture of'),
  _openRelationship('knownFor', 'Known for', 'Associated location'),
];

ConnectionTypeDefinition _spatial(
  String id,
  String displayName,
  String inverseLabel, {
  bool undirected = false,
}) =>
    ConnectionTypeDefinition(
      id: id,
      displayName: displayName,
      sourceTypeIds: [...WorldRecordTypes.spatialTypeIds],
      targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
      direction: undirected
          ? ConnectionDirection.undirected
          : ConnectionDirection.directed,
      inverseLabel: inverseLabel,
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-world-core',
      metadataFields: _worldRelationshipMetadata,
    );

Iterable<ConnectionTypeDefinition> _characterLocationRelationships(
  Map<String, (String, String)> definitions,
) =>
    definitions.entries.map(
      (entry) => ConnectionTypeDefinition(
        id: entry.key,
        displayName: entry.value.$1,
        sourceTypeIds: const ['character'],
        targetTypeIds: [...WorldRecordTypes.spatialTypeIds],
        inverseLabel: entry.value.$2,
        temporalSupport: true,
        builtIn: true,
        sourcePackId: 'authoros-world-core',
        metadataFields: _worldRelationshipMetadata,
      ),
    );

ConnectionTypeDefinition _openRelationship(
  String id,
  String displayName,
  String inverseLabel,
) =>
    ConnectionTypeDefinition(
      id: id,
      displayName: displayName,
      sourceTypeIds: const ['*'],
      targetTypeIds: const ['*'],
      inverseLabel: inverseLabel,
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-world-core',
      metadataFields: _worldRelationshipMetadata,
    );

const _worldRelationshipMetadata = <RecordFieldDefinition>[
  RecordFieldDefinition(
      id: 'startDate',
      label: 'Start date',
      type: RecordFieldType.date,
      order: 0),
  RecordFieldDefinition(
      id: 'endDate', label: 'End date', type: RecordFieldType.date, order: 1),
  RecordFieldDefinition(
      id: 'distance',
      label: 'Distance',
      type: RecordFieldType.shortText,
      order: 2),
  RecordFieldDefinition(
      id: 'travelTime',
      label: 'Travel time',
      type: RecordFieldType.shortText,
      order: 3),
  RecordFieldDefinition(
      id: 'difficulty',
      label: 'Difficulty',
      type: RecordFieldType.shortText,
      order: 4),
  RecordFieldDefinition(
      id: 'cost', label: 'Cost', type: RecordFieldType.shortText, order: 5),
  RecordFieldDefinition(
      id: 'danger', label: 'Danger', type: RecordFieldType.shortText, order: 6),
  RecordFieldDefinition(
      id: 'restrictions',
      label: 'Restrictions',
      type: RecordFieldType.longText,
      order: 7),
  RecordFieldDefinition(
      id: 'conditions',
      label: 'Conditions',
      type: RecordFieldType.longText,
      order: 8),
  RecordFieldDefinition(
      id: 'notes', label: 'Notes', type: RecordFieldType.longText, order: 9),
];

Iterable<ConnectionTypeDefinition> _timelineRelationships(
  Map<String, (String, String)> definitions,
) =>
    definitions.entries.map(
      (entry) => ConnectionTypeDefinition(
        id: entry.key,
        displayName: entry.value.$1,
        sourceTypeIds: const ['*'],
        targetTypeIds: const ['*'],
        inverseLabel: entry.value.$2,
        temporalSupport: true,
        builtIn: true,
        sourcePackId: 'authoros-timeline-core',
        metadataFields: _timelineRelationshipMetadata,
      ),
    );

const _timelineRelationshipMetadata = <RecordFieldDefinition>[
  RecordFieldDefinition(
    id: 'offset',
    label: 'Offset',
    type: RecordFieldType.number,
    order: 0,
  ),
  RecordFieldDefinition(
    id: 'unit',
    label: 'Unit',
    type: RecordFieldType.shortText,
    order: 1,
  ),
  RecordFieldDefinition(
    id: 'description',
    label: 'Description',
    type: RecordFieldType.longText,
    order: 2,
  ),
];

Iterable<ConnectionTypeDefinition> _codexRelationships(
  Map<String, (String, String)> definitions,
) =>
    definitions.entries.map(
      (entry) => ConnectionTypeDefinition(
        id: entry.key,
        displayName: entry.value.$1,
        sourceTypeIds: const ['*'],
        targetTypeIds: const ['*'],
        inverseLabel: entry.value.$2,
        temporalSupport: true,
        builtIn: true,
        sourcePackId: 'authoros-codex-core',
        metadataFields: _codexMetadataFields,
      ),
    );

const _codexMetadataFields = <RecordFieldDefinition>[
  RecordFieldDefinition(
    id: 'strength',
    label: 'Relationship strength',
    type: RecordFieldType.rating,
    order: 0,
  ),
  RecordFieldDefinition(
    id: 'startDate',
    label: 'Start date',
    type: RecordFieldType.date,
    order: 1,
  ),
  RecordFieldDefinition(
    id: 'endDate',
    label: 'End date',
    type: RecordFieldType.date,
    order: 2,
  ),
  RecordFieldDefinition(
    id: 'status',
    label: 'Status',
    type: RecordFieldType.shortText,
    order: 3,
  ),
  RecordFieldDefinition(
    id: 'private',
    label: 'Private',
    type: RecordFieldType.boolean,
    order: 4,
  ),
  RecordFieldDefinition(
    id: 'secret',
    label: 'Secret',
    type: RecordFieldType.boolean,
    order: 5,
  ),
  RecordFieldDefinition(
    id: 'notes',
    label: 'Notes',
    type: RecordFieldType.longText,
    order: 6,
  ),
  RecordFieldDefinition(
    id: 'context',
    label: 'Context',
    type: RecordFieldType.longText,
    order: 7,
  ),
  RecordFieldDefinition(
    id: 'source',
    label: 'Source',
    type: RecordFieldType.shortText,
    order: 8,
  ),
  RecordFieldDefinition(
    id: 'confidence',
    label: 'Confidence',
    type: RecordFieldType.rating,
    order: 9,
  ),
];

ConnectionTypeDefinition _characterRelationship(
  String id,
  String displayName, {
  String? inverseLabel,
  bool undirected = false,
}) =>
    ConnectionTypeDefinition(
      id: id,
      displayName: displayName,
      sourceTypeIds: const ['character'],
      targetTypeIds: const ['character'],
      direction: undirected
          ? ConnectionDirection.undirected
          : ConnectionDirection.directed,
      inverseLabel: inverseLabel ?? displayName,
      temporalSupport: true,
      builtIn: true,
      sourcePackId: 'authoros-character-core',
      metadataFields: const [
        RecordFieldDefinition(
          id: 'strength',
          label: 'Strength',
          type: RecordFieldType.rating,
          order: 0,
        ),
        RecordFieldDefinition(
          id: 'status',
          label: 'Status',
          type: RecordFieldType.shortText,
          order: 1,
        ),
        RecordFieldDefinition(
          id: 'beginning',
          label: 'Beginning',
          type: RecordFieldType.date,
          order: 2,
        ),
        RecordFieldDefinition(
          id: 'ending',
          label: 'Ending',
          type: RecordFieldType.date,
          order: 3,
        ),
        RecordFieldDefinition(
          id: 'mutuality',
          label: 'Mutuality',
          type: RecordFieldType.shortText,
          order: 4,
        ),
        RecordFieldDefinition(
          id: 'publicKnowledge',
          label: 'Public knowledge',
          type: RecordFieldType.boolean,
          order: 5,
        ),
        RecordFieldDefinition(
          id: 'secret',
          label: 'Secret',
          type: RecordFieldType.boolean,
          order: 6,
        ),
        RecordFieldDefinition(
          id: 'trust',
          label: 'Trust',
          type: RecordFieldType.rating,
          order: 7,
        ),
        RecordFieldDefinition(
          id: 'conflict',
          label: 'Conflict',
          type: RecordFieldType.longText,
          order: 8,
        ),
        RecordFieldDefinition(
          id: 'history',
          label: 'History',
          type: RecordFieldType.longText,
          order: 9,
        ),
        RecordFieldDefinition(
          id: 'notes',
          label: 'Notes',
          type: RecordFieldType.longText,
          order: 10,
        ),
      ],
    );
