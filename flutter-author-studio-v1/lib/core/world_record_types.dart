import 'record_types.dart';

class WorldRecordTypes {
  const WorldRecordTypes._();

  static const locationTypeIds = <String>{
    'location',
    'basic-location',
    'continent',
    'region',
    'country',
    'nation',
    'province',
    'state',
    'territory',
    'city',
    'town',
    'village',
    'settlement',
    'district',
    'neighbourhood',
    'building',
    'structure',
    'room',
    'interior-location',
    'landmark',
    'natural-feature',
    'mountain',
    'river',
    'lake',
    'ocean',
    'sea',
    'forest',
    'desert',
    'island',
    'cave',
    'ruin',
    'battlefield',
    'road',
    'route-location',
    'border',
    'other-custom-location',
  };

  static const cosmicTypeIds = <String>{
    'universe',
    'world',
    'planet',
    'moon',
    'star',
    'solar-system',
    'galaxy',
    'dimension',
    'realm',
    'plane',
  };

  static const spatialTypeIds = <String>{
    ...locationTypeIds,
    ...cosmicTypeIds,
    'place',
  };

  static const mapTypeIds = <String>{
    'map',
    'world-map',
    'regional-map',
    'country-map',
    'city-map',
    'building-map',
    'dungeon-map',
    'battle-map',
    'custom-map',
  };

  static const routeTypeIds = <String>{
    'travel-route',
    'road-route',
    'path-route',
    'portal-route',
    'gate-route',
    'ferry-route',
    'bridge-route',
    'tunnel-route',
    'flight-path',
    'space-route',
    'magical-route',
  };

  static const worldDomainTypeIds = <String>{
    ...locationTypeIds,
    ...cosmicTypeIds,
    ...mapTypeIds,
    ...routeTypeIds,
    'map-marker',
  };

  static final definitions = <RecordTypeDefinition>[
    _world,
    _location,
    ..._locationTemplates,
    ..._cosmicTemplates,
    _map,
    ..._derived(mapTypeIds.difference(const {'map'}), 'map', 'maps'),
    _mapMarker,
    _travelRoute,
    ..._derived(
      routeTypeIds.difference(const {'travel-route'}),
      'travel-route',
      'routes',
    ),
  ];

  static bool isBuiltInWorldType(String typeId) =>
      worldDomainTypeIds.contains(typeId);
}

const _identityFields = <RecordFieldDefinition>[
  RecordFieldDefinition(
      id: 'primaryName',
      label: 'Primary Name',
      type: RecordFieldType.shortText,
      order: 10),
  RecordFieldDefinition(
      id: 'alternateNames',
      label: 'Alternate Names',
      type: RecordFieldType.list,
      order: 11,
      extensionData: {'searchable': true, 'aliasKind': 'alternate'}),
  RecordFieldDefinition(
      id: 'historicalNames',
      label: 'Historical Names',
      type: RecordFieldType.list,
      order: 12,
      extensionData: {'searchable': true, 'aliasKind': 'historical'}),
  RecordFieldDefinition(
      id: 'localNames',
      label: 'Local Names',
      type: RecordFieldType.list,
      order: 13,
      extensionData: {'searchable': true, 'aliasKind': 'local'}),
  RecordFieldDefinition(
      id: 'translations',
      label: 'Translations',
      type: RecordFieldType.table,
      order: 14,
      extensionData: {'searchable': true}),
  RecordFieldDefinition(
      id: 'nicknames',
      label: 'Nicknames',
      type: RecordFieldType.list,
      order: 15,
      extensionData: {'searchable': true, 'aliasKind': 'nickname'}),
  RecordFieldDefinition(
      id: 'locationType',
      label: 'Type',
      type: RecordFieldType.shortText,
      order: 16),
  RecordFieldDefinition(
      id: 'summary',
      label: 'Summary',
      type: RecordFieldType.longText,
      order: 17),
  RecordFieldDefinition(
      id: 'description',
      label: 'Description',
      type: RecordFieldType.richText,
      order: 18),
  RecordFieldDefinition(
      id: 'notes', label: 'Notes', type: RecordFieldType.longText, order: 19),
];

const _environmentFields = <RecordFieldDefinition>[
  RecordFieldDefinition(
      id: 'geography',
      label: 'Geography',
      type: RecordFieldType.richText,
      order: 100),
  RecordFieldDefinition(
      id: 'climate',
      label: 'Climate',
      type: RecordFieldType.longText,
      order: 101),
  RecordFieldDefinition(
      id: 'terrain',
      label: 'Terrain',
      type: RecordFieldType.longText,
      order: 102),
  RecordFieldDefinition(
      id: 'elevation',
      label: 'Elevation',
      type: RecordFieldType.shortText,
      order: 103),
  RecordFieldDefinition(
      id: 'size', label: 'Size', type: RecordFieldType.shortText, order: 104),
  RecordFieldDefinition(
      id: 'population',
      label: 'Population',
      type: RecordFieldType.number,
      order: 105),
  RecordFieldDefinition(
      id: 'density',
      label: 'Density',
      type: RecordFieldType.shortText,
      order: 106),
  RecordFieldDefinition(
      id: 'naturalResources',
      label: 'Natural Resources',
      type: RecordFieldType.list,
      order: 107),
  RecordFieldDefinition(
      id: 'water', label: 'Water', type: RecordFieldType.longText, order: 108),
  RecordFieldDefinition(
      id: 'wildlife',
      label: 'Wildlife',
      type: RecordFieldType.list,
      order: 109),
  RecordFieldDefinition(
      id: 'flora', label: 'Flora', type: RecordFieldType.list, order: 110),
  RecordFieldDefinition(
      id: 'fauna', label: 'Fauna', type: RecordFieldType.list, order: 111),
  RecordFieldDefinition(
      id: 'weather',
      label: 'Weather',
      type: RecordFieldType.longText,
      order: 112),
  RecordFieldDefinition(
      id: 'seasons', label: 'Seasons', type: RecordFieldType.list, order: 113),
  RecordFieldDefinition(
      id: 'hazards', label: 'Hazards', type: RecordFieldType.list, order: 114),
  RecordFieldDefinition(
      id: 'naturalPhenomena',
      label: 'Natural Phenomena',
      type: RecordFieldType.list,
      order: 115),
];

const _societyFields = <RecordFieldDefinition>[
  RecordFieldDefinition(
      id: 'architecture',
      label: 'Architecture',
      type: RecordFieldType.richText,
      order: 200),
  RecordFieldDefinition(
      id: 'infrastructure',
      label: 'Infrastructure',
      type: RecordFieldType.richText,
      order: 201),
  RecordFieldDefinition(
      id: 'economy',
      label: 'Economy',
      type: RecordFieldType.richText,
      order: 202),
  RecordFieldDefinition(
      id: 'transportation',
      label: 'Transportation',
      type: RecordFieldType.richText,
      order: 203),
  RecordFieldDefinition(
      id: 'technology',
      label: 'Technology',
      type: RecordFieldType.recordReference,
      order: 204),
  RecordFieldDefinition(
      id: 'magic',
      label: 'Magic',
      type: RecordFieldType.recordReference,
      order: 205),
  RecordFieldDefinition(
      id: 'culture',
      label: 'Culture',
      type: RecordFieldType.recordReference,
      order: 206),
  RecordFieldDefinition(
      id: 'religion',
      label: 'Religion',
      type: RecordFieldType.recordReference,
      order: 207),
  RecordFieldDefinition(
      id: 'politics',
      label: 'Politics',
      type: RecordFieldType.richText,
      order: 208),
  RecordFieldDefinition(
      id: 'military',
      label: 'Military',
      type: RecordFieldType.richText,
      order: 209),
  RecordFieldDefinition(
      id: 'laws', label: 'Laws', type: RecordFieldType.list, order: 210),
  RecordFieldDefinition(
      id: 'customs', label: 'Customs', type: RecordFieldType.list, order: 211),
  RecordFieldDefinition(
      id: 'history',
      label: 'History',
      type: RecordFieldType.richText,
      order: 212),
  RecordFieldDefinition(
      id: 'secrets',
      label: 'Secrets',
      type: RecordFieldType.table,
      order: 213,
      extensionData: {'visibility': 'author'}),
];

const _world = RecordTypeDefinition(
  id: 'world',
  name: 'World',
  categoryId: 'world',
  baseTypeId: 'general-lore',
  fields: [..._identityFields, ..._environmentFields, ..._societyFields],
  sections: [
    RecordTemplateSection(
        id: 'worldIdentity',
        title: 'Identity',
        order: 10,
        fieldIds: [
          'primaryName',
          'alternateNames',
          'historicalNames',
          'localNames',
          'translations',
          'nicknames',
          'summary',
          'description',
          'notes'
        ]),
    RecordTemplateSection(
        id: 'worldEnvironment',
        title: 'Environment',
        order: 20,
        fieldIds: [
          'geography',
          'climate',
          'terrain',
          'elevation',
          'size',
          'population',
          'density',
          'naturalResources',
          'water',
          'wildlife',
          'flora',
          'fauna',
          'weather',
          'seasons',
          'hazards',
          'naturalPhenomena'
        ]),
    RecordTemplateSection(
        id: 'worldSociety',
        title: 'Society',
        order: 30,
        fieldIds: [
          'architecture',
          'infrastructure',
          'economy',
          'transportation',
          'technology',
          'magic',
          'culture',
          'religion',
          'politics',
          'military',
          'laws',
          'customs',
          'history',
          'secrets'
        ]),
  ],
  suggestedLinkTypeIds: ['contains', 'locatedIn', 'associatedWith'],
  builtIn: true,
  sourcePackId: 'authoros-world-core',
  extensionData: {'worldDomain': true, 'worldTemplate': true},
);

const _location = RecordTypeDefinition(
  id: 'location',
  name: 'Basic Location',
  categoryId: 'locations',
  baseTypeId: 'general-lore',
  fields: [..._identityFields, ..._environmentFields, ..._societyFields],
  sections: [
    RecordTemplateSection(
        id: 'locationIdentity',
        title: 'Identity',
        order: 10,
        fieldIds: [
          'primaryName',
          'alternateNames',
          'historicalNames',
          'localNames',
          'translations',
          'nicknames',
          'locationType',
          'summary',
          'description',
          'notes'
        ]),
    RecordTemplateSection(
        id: 'environment',
        title: 'Environment',
        order: 20,
        fieldIds: [
          'geography',
          'climate',
          'terrain',
          'elevation',
          'size',
          'population',
          'density',
          'naturalResources',
          'water',
          'wildlife',
          'flora',
          'fauna',
          'weather',
          'seasons',
          'hazards',
          'naturalPhenomena'
        ]),
    RecordTemplateSection(
        id: 'society',
        title: 'Society',
        order: 30,
        fieldIds: [
          'architecture',
          'infrastructure',
          'economy',
          'transportation',
          'technology',
          'magic',
          'culture',
          'religion',
          'politics',
          'military',
          'laws',
          'customs',
          'history',
          'secrets'
        ]),
  ],
  suggestedLinkTypeIds: ['locatedIn', 'contains', 'adjacentTo', 'borders'],
  builtIn: true,
  sourcePackId: 'authoros-world-core',
  extensionData: {'worldDomain': true, 'worldTemplate': true},
);

final _locationTemplates = <RecordTypeDefinition>[
  ..._derived(
    WorldRecordTypes.locationTypeIds.difference(const {
      'location',
      'city',
      'country',
      'nation',
      'region',
      'building',
      'natural-feature',
    }),
    'location',
    'locations',
  ),
  _specialized('city', 'City', const [
    ('government', 'Government', RecordFieldType.recordReference),
    ('districts', 'Districts', RecordFieldType.list),
    ('landmarks', 'Landmarks', RecordFieldType.list),
    ('factions', 'Factions', RecordFieldType.list),
    ('importantCharacters', 'Important Characters', RecordFieldType.list),
  ]),
  _specialized('country', 'Country / Nation', const [
    ('government', 'Government', RecordFieldType.recordReference),
    ('capital', 'Capital', RecordFieldType.locationReference),
    ('borders', 'Borders', RecordFieldType.list),
    ('language', 'Language', RecordFieldType.recordReference),
    ('factions', 'Factions', RecordFieldType.list),
  ]),
  _specialized('nation', 'Nation', const [], baseTypeId: 'country'),
  _specialized('region', 'Region', const [
    ('settlements', 'Settlements', RecordFieldType.list),
    ('factions', 'Factions', RecordFieldType.list),
  ]),
  _specialized('building', 'Building', const [
    ('owner', 'Owner', RecordFieldType.recordReference),
    ('purpose', 'Purpose', RecordFieldType.longText),
    ('rooms', 'Rooms', RecordFieldType.list),
    ('security', 'Security', RecordFieldType.richText),
    ('importantPeople', 'Important People', RecordFieldType.list),
  ]),
  _specialized('natural-feature', 'Natural Feature', const [
    ('culturalSignificance', 'Cultural Significance', RecordFieldType.richText),
  ]),
];

final _cosmicTemplates = <RecordTypeDefinition>[
  _specialized('universe', 'Universe', const [],
      baseTypeId: 'world', categoryId: 'world'),
  ..._derived(
    WorldRecordTypes.cosmicTypeIds.difference(const {'world', 'universe'}),
    'world',
    'world',
  ),
];

const _map = RecordTypeDefinition(
  id: 'map',
  name: 'Map',
  categoryId: 'maps',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
        id: 'mapType',
        label: 'Map Type',
        type: RecordFieldType.shortText,
        order: 100),
    RecordFieldDefinition(
        id: 'coordinateSystem',
        label: 'Coordinate System',
        type: RecordFieldType.shortText,
        order: 101),
    RecordFieldDefinition(
        id: 'width', label: 'Width', type: RecordFieldType.number, order: 102),
    RecordFieldDefinition(
        id: 'height',
        label: 'Height',
        type: RecordFieldType.number,
        order: 103),
    RecordFieldDefinition(
        id: 'scale',
        label: 'Scale',
        type: RecordFieldType.shortText,
        order: 104),
    RecordFieldDefinition(
        id: 'centerPoint',
        label: 'Center Point',
        type: RecordFieldType.table,
        order: 105),
    RecordFieldDefinition(
        id: 'backgroundReference',
        label: 'Background Reference',
        type: RecordFieldType.fileReference,
        order: 106),
    RecordFieldDefinition(
        id: 'projection',
        label: 'Map Projection',
        type: RecordFieldType.shortText,
        order: 107),
    RecordFieldDefinition(
        id: 'mapMetadata',
        label: 'Map Metadata',
        type: RecordFieldType.table,
        order: 108),
  ],
  sections: [
    RecordTemplateSection(
        id: 'mapData',
        title: 'Map Data',
        order: 10,
        fieldIds: [
          'mapType',
          'coordinateSystem',
          'width',
          'height',
          'scale',
          'centerPoint',
          'backgroundReference',
          'projection',
          'mapMetadata'
        ])
  ],
  suggestedLinkTypeIds: ['maps'],
  builtIn: true,
  sourcePackId: 'authoros-world-core',
  extensionData: {'worldDomain': true, 'mapFoundation': true},
);

const _mapMarker = RecordTypeDefinition(
  id: 'map-marker',
  name: 'Map Marker',
  categoryId: 'maps',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
        id: 'mapId',
        label: 'Map',
        type: RecordFieldType.recordReference,
        order: 100,
        required: true),
    // Optional on purpose: a Map Studio marker may stand alone before it is
    // pointed at a character, location, plot thread or timeline event.
    RecordFieldDefinition(
        id: 'recordId',
        label: 'Record',
        type: RecordFieldType.recordReference,
        order: 101),
    RecordFieldDefinition(
        id: 'x',
        label: 'X',
        type: RecordFieldType.number,
        order: 102,
        required: true),
    RecordFieldDefinition(
        id: 'y',
        label: 'Y',
        type: RecordFieldType.number,
        order: 103,
        required: true),
    RecordFieldDefinition(
        id: 'label',
        label: 'Label',
        type: RecordFieldType.shortText,
        order: 104),
    RecordFieldDefinition(
        id: 'icon', label: 'Icon', type: RecordFieldType.shortText, order: 105),
    RecordFieldDefinition(
        id: 'category',
        label: 'Category',
        type: RecordFieldType.shortText,
        order: 106),
    RecordFieldDefinition(
        id: 'visibility',
        label: 'Visibility',
        type: RecordFieldType.shortText,
        order: 107),
    RecordFieldDefinition(
        id: 'markerNotes',
        label: 'Notes',
        type: RecordFieldType.longText,
        order: 108),
  ],
  sections: [
    RecordTemplateSection(
        id: 'markerData',
        title: 'Marker Data',
        order: 10,
        fieldIds: [
          'mapId',
          'recordId',
          'x',
          'y',
          'label',
          'icon',
          'category',
          'visibility',
          'markerNotes'
        ])
  ],
  suggestedLinkTypeIds: ['onMap', 'represents'],
  builtIn: true,
  sourcePackId: 'authoros-world-core',
  extensionData: {'worldDomain': true, 'mapMarkerFoundation': true},
);

const _travelRoute = RecordTypeDefinition(
  id: 'travel-route',
  name: 'Travel Route',
  categoryId: 'routes',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
        id: 'routeType',
        label: 'Route Type',
        type: RecordFieldType.shortText,
        order: 100),
    RecordFieldDefinition(
        id: 'startId',
        label: 'Start',
        type: RecordFieldType.locationReference,
        order: 101,
        required: true),
    RecordFieldDefinition(
        id: 'endId',
        label: 'End',
        type: RecordFieldType.locationReference,
        order: 102,
        required: true),
    RecordFieldDefinition(
        id: 'distance',
        label: 'Distance',
        type: RecordFieldType.shortText,
        order: 103),
    RecordFieldDefinition(
        id: 'travelTime',
        label: 'Travel Time',
        type: RecordFieldType.shortText,
        order: 104),
    RecordFieldDefinition(
        id: 'difficulty',
        label: 'Difficulty',
        type: RecordFieldType.shortText,
        order: 105),
    RecordFieldDefinition(
        id: 'cost', label: 'Cost', type: RecordFieldType.shortText, order: 106),
    RecordFieldDefinition(
        id: 'danger',
        label: 'Danger',
        type: RecordFieldType.shortText,
        order: 107),
    RecordFieldDefinition(
        id: 'restrictions',
        label: 'Restrictions',
        type: RecordFieldType.list,
        order: 108),
    RecordFieldDefinition(
        id: 'conditions',
        label: 'Conditions',
        type: RecordFieldType.list,
        order: 109),
  ],
  sections: [
    RecordTemplateSection(
        id: 'routeData',
        title: 'Route Data',
        order: 10,
        fieldIds: [
          'routeType',
          'startId',
          'endId',
          'distance',
          'travelTime',
          'difficulty',
          'cost',
          'danger',
          'restrictions',
          'conditions'
        ])
  ],
  suggestedLinkTypeIds: ['routeFrom', 'routeTo', 'passesThrough'],
  builtIn: true,
  sourcePackId: 'authoros-world-core',
  extensionData: {'worldDomain': true, 'routeFoundation': true},
);

RecordTypeDefinition _specialized(
  String id,
  String name,
  List<(String, String, RecordFieldType)> fields, {
  String baseTypeId = 'location',
  String categoryId = 'locations',
}) =>
    RecordTypeDefinition(
      id: id,
      name: name,
      categoryId: categoryId,
      baseTypeId: baseTypeId,
      fields: [
        for (var index = 0; index < fields.length; index++)
          RecordFieldDefinition(
              id: fields[index].$1,
              label: fields[index].$2,
              type: fields[index].$3,
              order: 300 + index),
      ],
      sections: const [],
      builtIn: true,
      sourcePackId: 'authoros-world-core',
      extensionData: const {'worldDomain': true, 'worldTemplate': true},
    );

Iterable<RecordTypeDefinition> _derived(
  Iterable<String> ids,
  String baseTypeId,
  String categoryId,
) =>
    ids.map(
      (id) => RecordTypeDefinition(
        id: id,
        name: _title(id),
        categoryId: categoryId,
        baseTypeId: baseTypeId,
        fields: const [],
        sections: const [],
        builtIn: true,
        sourcePackId: 'authoros-world-core',
        extensionData: const {'worldDomain': true, 'worldTemplate': true},
      ),
    );

String _title(String id) => id
    .split('-')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
